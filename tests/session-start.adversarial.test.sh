#!/usr/bin/env bash
# hooks/session-start 对抗测试（slug: hook-workspace-docs-root, issue #127）。
# 与 tests/session-start.test.sh（developer 自带）互补，专攻边界与异常输入：
#   敌意路径名 / .roundtable.json 畸形输入 / sed fallback（无 python3）/
#   workspace 规模与怪名 / git 环境污染 / 输出契约逐 case 强校验。
#
# 已知 bug 的复现断言用 KNOWN-BUG 标记：默认不影响退出码（便于 CI），
# STRICT=1 时计入失败。bug 清单见 docs/testing/hook-workspace-docs-root.md。
# 注意：本测试套件用 ${var@Q} 需 bash ≥ 4.4（仅开发侧；hook 本体兼容 bash 3.2）。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"
PY="$(command -v python3)"   # harness 自身固定用绝对路径，不受 PATH 篡改测试影响

PASS=0
FAIL=0
KNOWN_BUGS=0
TMP_DIRS=()

cleanup() {
    local d
    for d in "${TMP_DIRS[@]:-}"; do
        if [ -n "$d" ]; then
            chmod -R u+rwX "$d" 2>/dev/null || true
            rm -rf "$d"
        fi
    done
}
trap cleanup EXIT

new_tmp() {
    local d
    d="$(cd "$(mktemp -d)" && pwd -P)"
    TMP_DIRS+=("$d")
    printf '%s' "$d"
}

pass() { PASS=$((PASS + 1)); printf 'ok   - %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL - %s\n      %s\n' "$1" "$2"; }
known_bug() {
    KNOWN_BUGS=$((KNOWN_BUGS + 1))
    printf 'KNOWN-BUG - %s\n      %s\n' "$1" "$2"
    if [ "${STRICT:-0}" = "1" ]; then FAIL=$((FAIL + 1)); fi
}

# 运行 hook：捕获 stdout/stderr/退出码到全局 OUT/ERR/RC。
# 默认清掉 ROUNDTABLE_DOCS_ROOT 与 GIT_* 污染源；额外 KEY=VALUE 透传（后者覆盖 -u）。
ERR_FILE=""
run_hook() {
    local dir="$1"
    shift
    RC=0
    OUT="$( (cd "$dir" && env -u ROUNDTABLE_DOCS_ROOT -u CLAUDE_PLUGIN_ROOT \
        -u GIT_DIR -u GIT_WORK_TREE -u GIT_CEILING_DIRECTORIES \
        "$@" bash "$HOOK") 2>"$ERR_FILE" )" || RC=$?
    ERR="$(cat "$ERR_FILE")"
}

# 同上，但以受限 PATH 运行（用于藏掉 python3 / git）
run_hook_path() {
    local dir="$1" path="$2"
    shift 2
    RC=0
    OUT="$( (cd "$dir" && env -u ROUNDTABLE_DOCS_ROOT -u CLAUDE_PLUGIN_ROOT \
        -u GIT_DIR -u GIT_WORK_TREE -u GIT_CEILING_DIRECTORIES \
        PATH="$path" "$@" "$BASH" "$HOOK") 2>"$ERR_FILE" )" || RC=$?
    ERR="$(cat "$ERR_FILE")"
}

# 输出契约（DEC-1 + hook 不得哑火）：退出码 0、stdout 单行非空、stderr 静默、
# 合法 JSON、双键 context 一致、hookEventName 正确。解码后的 context 存入 CTX。
contract() {
    local name="$1"
    if [ "$RC" -eq 0 ]; then
        pass "$name exit code 0"
    else
        fail "$name exit code 0" "rc=$RC stderr=${ERR@Q} out=${OUT@Q}"
    fi
    if [ -n "$OUT" ] && [[ "$OUT" != *$'\n'* ]]; then
        pass "$name single-line non-empty stdout"
    else
        fail "$name single-line non-empty stdout" "out=${OUT@Q}"
    fi
    if [ -z "$ERR" ]; then
        pass "$name silent stderr"
    else
        fail "$name silent stderr" "stderr=${ERR@Q}"
    fi
    if CTX="$(printf '%s' "$OUT" | "$PY" -c '
import json, sys
out = json.loads(sys.stdin.read())
top = out["additionalContext"]
hso = out["hookSpecificOutput"]
assert hso["hookEventName"] == "SessionStart", "bad hookEventName"
assert hso["additionalContext"] == top, "context mismatch between the two keys"
sys.stdout.write(top)
' 2>/dev/null)"; then
        pass "$name valid dual-key JSON"
        return 0
    fi
    fail "$name valid dual-key JSON" "out=${OUT@Q}"
    CTX=""
    return 1
}

assert_contains() {
    local name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" "expected to contain: ${needle@Q}; actual: ${haystack@Q}"
    fi
}

assert_not_contains() {
    local name="$1" haystack="$2" needle="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$name"
    else
        fail "$name" "expected NOT to contain: ${needle@Q}; actual: ${haystack@Q}"
    fi
}

git_init() { git -C "$1" init -q; }

ERR_FILE="$(new_tmp)/stderr"

# ============================================================
# A. 敌意路径名（project 模式：repo 目录名本身就是攻击载荷）
# ============================================================
hostile_names=(
    'pa th'
    '中文项目'
    "o'brien"
    'x$HOME-y'
    'x$(echo pwned)y'
    'a`id`b'
    'st*ar'
    'br[ack]et'
    'qu"ote'
    'back\slash'
)
i=0
for name in "${hostile_names[@]}"; do
    i=$((i + 1))
    t="$(new_tmp)"
    repo="$t/$name"
    mkdir -p "$repo/docs/design-docs"
    git_init "$repo"
    run_hook "$repo"
    if contract "A$i [$name]"; then
        assert_contains "A$i [$name] docs_root literal" "$CTX" "docs_root: $repo/docs"$'\n'
        assert_contains "A$i [$name] project_id literal" "$CTX" "project_id: $name"$'\n'
        assert_contains "A$i [$name] status=ok" "$CTX" "status: ok"
    fi
done
# 注入哨兵：路径里的 $(echo pwned) / `id` / $HOME 若被求值，输出会失真（上面的
# literal 断言已覆盖）；这里再确认没有产生副作用文件
if [ ! -e "$REPO_ROOT/pwned" ] && [ ! -e "/tmp/pwned" ]; then
    pass "A-inject no side-effect file created"
else
    fail "A-inject no side-effect file created" "pwned file exists"
fi

# A11: 目录名含换行 → \n 已转义，JSON 应合法
t="$(new_tmp)"
repo="$t/nl"$'\n'"name"
mkdir -p "$repo/docs/design-docs"
git_init "$repo"
run_hook "$repo"
if contract "A11 [newline-in-name]"; then
    assert_contains "A11 docs_root spans escaped newline" "$CTX" "docs_root: $repo/docs"
fi

# A12 [BUG-1]: 目录名含未覆盖的控制字符（\x0b vertical tab）→ escape 函数只处理
# \n\r\t\b\f，\x0b 原样进入 JSON 字符串 → 非法 JSON，hook 哑火
t="$(new_tmp)"
repo="$t/ev"$'\x0b'"il"
mkdir -p "$repo/docs/design-docs"
git_init "$repo"
run_hook "$repo"
if printf '%s' "$OUT" | "$PY" -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
    pass "A12 [BUG-1 fixed] control char \\x0b in path yields valid JSON"
else
    known_bug "A12 control char \\x0b in path yields valid JSON" \
        "escape_for_json 未覆盖 <0x20 的其余控制字符，JSON 解析失败 → hook 输出不可用"
fi

# ============================================================
# B. .roundtable.json 畸形输入（repo 均带 docs/analyze 作 walk-up 兜底）
# ============================================================
mk_cfg_repo() {  # $1=tmp 根；stdout 返回 repo 路径
    local t="$1"
    mkdir -p "$t/repo/docs/analyze"
    git_init "$t/repo"
    printf '%s' "$t/repo"
}

# B1 非法 JSON
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
printf '{not json' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B1 [invalid JSON]"; then
    assert_contains "B1 degrades to walk-up" "$CTX" $'docs_root_source: walk-up\n'
    assert_contains "B1 status=ok" "$CTX" "status: ok"
fi

# B2/B3/B4 docs_root 为数组 / 数字 / null → 非字符串一律忽略
for pair in 'B2-array:{"docs_root": ["a","b"]}' 'B3-number:{"docs_root": 42}' 'B4-null:{"docs_root": null}'; do
    name="${pair%%:*}"; payload="${pair#*:}"
    t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
    printf '%s\n' "$payload" > "$repo/.roundtable.json"
    run_hook "$repo"
    if contract "$name"; then
        assert_contains "$name non-string ignored, walk-up" "$CTX" $'docs_root_source: walk-up\n'
    fi
done

# B5 嵌套对象里有同名键 + 顶层真键 → python3 路径只认顶层
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
mkdir -p "$repo/evil" "$repo/mydocs"
printf '{"o": {"docs_root": "evil"}, "docs_root": "mydocs"}\n' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B5 [nested same-name key]"; then
    assert_contains "B5 top-level key wins" "$CTX" "docs_root: $repo/mydocs"$'\n'
    assert_not_contains "B5 nested key not picked" "$CTX" "$repo/evil"
fi

# B6 空文件
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
: > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B6 [empty file]"; then
    assert_contains "B6 walk-up" "$CTX" $'docs_root_source: walk-up\n'
fi

# B7 无读权限（chmod 000；root 下跳过）
if [ "$(id -u)" -ne 0 ]; then
    t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
    printf '{"docs_root": "docs"}\n' > "$repo/.roundtable.json"
    chmod 000 "$repo/.roundtable.json"
    run_hook "$repo"
    if contract "B7 [unreadable config]"; then
        assert_contains "B7 walk-up" "$CTX" $'docs_root_source: walk-up\n'
    fi
    chmod 644 "$repo/.roundtable.json"
else
    printf 'skip - B7 (running as root)\n'
fi

# B8 超长值（10k 字符）→ warning 不崩、JSON 合法
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
long="$(printf 'x%.0s' $(seq 1 10000))"
printf '{"docs_root": "%s"}\n' "$long" > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B8 [10k-char value]"; then
    assert_contains "B8 warning emitted" "$CTX" "warning:"
    assert_contains "B8 walk-up" "$CTX" $'docs_root_source: walk-up\n'
fi

# B9 值含转义引号 → python 解出 my"docs，不存在 → warning 带引号仍合法 JSON
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
printf '{"docs_root": "my\\"docs"}\n' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B9 [escaped quote in value]"; then
    assert_contains "B9 warning carries raw quote" "$CTX" 'my"docs'
fi

# B10 project_id 含双引号 → 进 context 后仍合法 JSON
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
printf '{"project_id": "pr\\"id"}\n' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B10 [quote in project_id]"; then
    assert_contains "B10 project_id literal" "$CTX" 'project_id: pr"id'$'\n'
fi

# B11 docs_root 为空字符串 → 视为未配置，静默走 walk-up（不应有 warning）
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
printf '{"docs_root": ""}\n' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B11 [empty-string value]"; then
    assert_contains "B11 walk-up" "$CTX" $'docs_root_source: walk-up\n'
    assert_not_contains "B11 no warning" "$CTX" "warning:"
fi

# B12 相对路径 ../ 逃逸出 repo → 显式配置按 DEC-3/DEC-4 信任（特征化）
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
mkdir -p "$t/outside"
printf '{"docs_root": "../outside"}\n' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B12 [../ escape]"; then
    assert_contains "B12 explicit config trusted (characterization)" "$CTX" "docs_root: $repo/../outside"$'\n'
    assert_contains "B12 source=config" "$CTX" $'docs_root_source: config\n'
fi

# B13 .roundtable.json 是目录 → [ -f ] 不命中，无视
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
mkdir "$repo/.roundtable.json"
run_hook "$repo"
if contract "B13 [config is a directory]"; then
    assert_contains "B13 walk-up" "$CTX" $'docs_root_source: walk-up\n'
fi

# B14 值含 $(...) 注入载荷 → 仅字面拼接，不求值、无副作用
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
printf '{"docs_root": "$(touch %s/hacked)"}\n' "$repo" > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B14 [command substitution payload]"; then
    assert_contains "B14 warning carries literal payload" "$CTX" '$(touch'
fi
if [ ! -e "$repo/hacked" ]; then
    pass "B14 no side-effect file"
else
    fail "B14 no side-effect file" "config value was evaluated"
fi

# B15 值含换行（JSON \n）→ warning 跨行仍合法 JSON
t="$(new_tmp)"; repo="$(mk_cfg_repo "$t")"
printf '{"docs_root": "a\\nb"}\n' > "$repo/.roundtable.json"
run_hook "$repo"
if contract "B15 [newline in value]"; then
    assert_contains "B15 warning emitted" "$CTX" "warning:"
fi

# ============================================================
# C. ROUNDTABLE_DOCS_ROOT 边界
# ============================================================
# C1 相对路径（相对 cwd 存在）→ 基于 cwd 归一化为绝对路径（GAP-1 已修）
t="$(new_tmp)"
mkdir -p "$t/repo/docs/analyze"
git_init "$t/repo"
run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT=docs
if contract "C1 [relative env path]"; then
    assert_contains "C1 [GAP-1 fixed] relative value normalized to absolute" "$CTX" "docs_root: $t/repo/docs"$'\n'
    assert_contains "C1 source=env" "$CTX" $'docs_root_source: env\n'
fi

# C2 尾斜杠 → 原样保留（特征化，纯外观）
t="$(new_tmp)"
mkdir -p "$t/repo" "$t/ext"
git_init "$t/repo"
run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT="$t/ext/"
if contract "C2 [trailing slash]"; then
    assert_contains "C2 kept verbatim" "$CTX" "docs_root: $t/ext/"$'\n'
fi

# C3 指向文件而非目录 → warning + 降级
t="$(new_tmp)"
mkdir -p "$t/repo/docs/reviews"
git_init "$t/repo"
touch "$t/afile"
run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT="$t/afile"
if contract "C3 [env points to file]"; then
    assert_contains "C3 warning" "$CTX" "warning:"
    assert_contains "C3 degraded to walk-up" "$CTX" "docs_root: $t/repo/docs"$'\n'
fi

# C4 空字符串 → 视为未设置，无 warning
t="$(new_tmp)"
mkdir -p "$t/repo/docs/testing"
git_init "$t/repo"
run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT=
if contract "C4 [empty env]"; then
    assert_not_contains "C4 no warning" "$CTX" "warning:"
    assert_contains "C4 walk-up" "$CTX" $'docs_root_source: walk-up\n'
fi

# C5 含空格的绝对路径
t="$(new_tmp)"
mkdir -p "$t/repo" "$t/my docs"
git_init "$t/repo"
run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT="$t/my docs"
if contract "C5 [space in env path]"; then
    assert_contains "C5 docs_root with space" "$CTX" "docs_root: $t/my docs"$'\n'
fi

# ============================================================
# D. sed fallback（PATH 藏掉 python3）
# ============================================================
FAKEBIN="$(new_tmp)/bin"
mkdir -p "$FAKEBIN"
for b in git sed head basename dirname; do
    ln -s "$(command -v "$b")" "$FAKEBIN/$b"
done
# 守卫：确认该 PATH 下 python3 不可见
if env PATH="$FAKEBIN" "$BASH" -c 'command -v python3' >/dev/null 2>&1; then
    fail "D0 guard python3 hidden" "python3 still resolvable in FAKEBIN PATH"
else
    pass "D0 guard python3 hidden"
fi

# D1 平铺 config：sed 提取 docs_root + project_id
t="$(new_tmp)"
mkdir -p "$t/repo/mydocs"
git_init "$t/repo"
printf '{"docs_root": "mydocs", "project_id": "sed-id"}\n' > "$t/repo/.roundtable.json"
run_hook_path "$t/repo" "$FAKEBIN"
if contract "D1 [sed flat config]"; then
    assert_contains "D1 docs_root" "$CTX" "docs_root: $t/repo/mydocs"$'\n'
    assert_contains "D1 source=config" "$CTX" $'docs_root_source: config\n'
    assert_contains "D1 project_id" "$CTX" $'project_id: sed-id\n'
fi

# D2 嵌套键：sed 退化实现会误取嵌套值（DEC-3 注释已声明的限制，特征化以证明
# sed 分支真被执行；python3 路径下 B5 已验证只认顶层）
t="$(new_tmp)"
mkdir -p "$t/repo/docs/analyze" "$t/repo/evil"
git_init "$t/repo"
printf '{"nested": {"docs_root": "evil"}}\n' > "$t/repo/.roundtable.json"
run_hook_path "$t/repo" "$FAKEBIN"
if contract "D2 [sed nested-key limitation]"; then
    assert_contains "D2 sed picks nested value (documented limitation)" "$CTX" "docs_root: $t/repo/evil"$'\n'
fi

# D3 无 python3 时 walk-up / 结构校验 / needs-init 全链路
t="$(new_tmp)"
mkdir -p "$t/repo/docs"
git_init "$t/repo"
run_hook_path "$t/repo" "$FAKEBIN"
if contract "D3 [sed-mode walk-up needs-init]"; then
    assert_contains "D3 docs_root reported" "$CTX" "docs_root: $t/repo/docs"$'\n'
    assert_contains "D3 needs-init" "$CTX" $'status: needs-init\n'
fi

# D4 无 python3 时 workspace 模式
t="$(new_tmp)"
mkdir -p "$t/ws/alpha/.git" "$t/ws/beta/docs"
mkdir -p "$t/ws/beta/.git"
run_hook_path "$t/ws" "$FAKEBIN"
if contract "D4 [sed-mode workspace]"; then
    assert_contains "D4 mode=workspace" "$CTX" $'mode: workspace\n'
    assert_contains "D4 projects" "$CTX" "projects: alpha, beta (docs)"
fi

# D5 非法 JSON 但含合法形态的键值行 → sed 照样提取（特征化退化语义）
t="$(new_tmp)"
mkdir -p "$t/repo/mydocs"
git_init "$t/repo"
printf 'garbage {{{ "docs_root": "mydocs" oops\n' > "$t/repo/.roundtable.json"
run_hook_path "$t/repo" "$FAKEBIN"
if contract "D5 [sed extracts from broken JSON]"; then
    assert_contains "D5 extracted anyway (characterization)" "$CTX" "docs_root: $t/repo/mydocs"$'\n'
fi

# ============================================================
# E. workspace 模式压力与怪名
# ============================================================
# E1: 50 个 git 子项目（.git 目录存在即算，DEC-5）
t="$(new_tmp)"
ws="$t/ws"
for n in $(seq -w 1 50); do
    mkdir -p "$ws/p$n/.git"
done
run_hook "$ws"
if contract "E1 [50 subprojects]"; then
    assert_contains "E1 mode=workspace" "$CTX" $'mode: workspace\n'
    assert_contains "E1 first listed" "$CTX" "projects: p01,"
    assert_contains "E1 last listed" "$CTX" "p49, p50"
    commas="${CTX//[^,]/}"
    if [ "${#commas}" -ge 49 ]; then
        pass "E1 all 50 enumerated"
    else
        fail "E1 all 50 enumerated" "comma count=${#commas}, expected >=49"
    fi
fi

# E2: 子目录名以 - 开头 / 名为 * / 含空格与中文 / .git 是文件（submodule 形态）
t="$(new_tmp)"
ws="$t/ws"
mkdir -p "$ws/-dash/.git" "$ws/*/.git" "$ws/sp ace/.git" "$ws/中文proj/docs"
printf 'gitdir: ../somewhere/.git\n' > "$ws/中文proj/.git"
run_hook "$ws"
if contract "E2 [hostile subdir names]"; then
    assert_contains "E2 -dash listed" "$CTX" "-dash"
    assert_contains "E2 literal * listed" "$CTX" "*"
    assert_contains "E2 space name listed" "$CTX" "sp ace"
    assert_contains "E2 gitfile submodule listed with docs tag" "$CTX" "中文proj (docs)"
fi

# E3: 悬空 symlink 子目录 → 忽略不崩；指向 git 仓的 symlink → 计入（特征化）
t="$(new_tmp)"
ws="$t/ws"
mkdir -p "$ws" "$t/real/.git"
ln -s "$t/nonexistent" "$ws/dangling"
ln -s "$t/real" "$ws/linked"
run_hook "$ws"
if contract "E3 [symlink subdirs]"; then
    assert_not_contains "E3 dangling ignored" "$CTX" "dangling"
    assert_contains "E3 symlink-to-repo listed (characterization)" "$CTX" "linked"
fi

# E4: workspace 根目录名本身含 glob 字符
t="$(new_tmp)"
ws="$t/ws*[1]"
mkdir -p "$ws/proj/.git"
run_hook "$ws"
if contract "E4 [glob chars in workspace root]"; then
    assert_contains "E4 workspace_root literal" "$CTX" "workspace_root: $ws"$'\n'
    assert_contains "E4 project listed" "$CTX" "projects: proj"
fi

# ============================================================
# F. git 环境异常
# ============================================================
# F1 [BUG-2 已修]: GIT_DIR 污染 → hook 开头 unset，git 探测只看 cwd 物理位置，
# 不得把 cwd 报成外部仓的 worktree 顶层（git_top=cwd、project_id 取自外部仓）
t="$(new_tmp)"
mkdir -p "$t/foreign" "$t/plain"
git_init "$t/foreign"
run_hook "$t/plain" GIT_DIR="$t/foreign/.git"
if contract "F1 [GIT_DIR pollution]"; then
    assert_not_contains "F1 [BUG-2 fixed] foreign repo not claimed" "$CTX" "project_id: foreign"
    assert_not_contains "F1 [BUG-2 fixed] cwd not claimed as git_top" "$CTX" "git_top: $t/plain"
    assert_contains "F1 needs-init (non-git path)" "$CTX" $'status: needs-init\n'
fi

# F2: GIT_WORK_TREE 单独污染（无 GIT_DIR）→ git 报错退出，应安全落入非 git 分支
t="$(new_tmp)"
mkdir -p "$t/plain"
run_hook "$t/plain" GIT_WORK_TREE="$t/plain"
if contract "F2 [GIT_WORK_TREE pollution]"; then
    assert_contains "F2 needs-init (non-git path)" "$CTX" $'status: needs-init\n'
fi

# F3: cwd 在 bare repo 内 → rev-parse 失败，落入非 git 分支不崩
t="$(new_tmp)"
git init -q --bare "$t/bare.git"
run_hook "$t/bare.git"
if contract "F3 [bare repo]"; then
    assert_contains "F3 needs-init" "$CTX" $'status: needs-init\n'
    assert_not_contains "F3 no git_top claimed" "$CTX" "git_top: $t/bare.git"
fi

# F4: git 不在 PATH（真 git 仓内）→ 静默降级为非 git 分支，契约不破
NOGIT="$(new_tmp)/bin"
mkdir -p "$NOGIT"
for b in sed head basename dirname python3; do
    ln -s "$(command -v "$b")" "$NOGIT/$b"
done
t="$(new_tmp)"
mkdir -p "$t/repo/docs/analyze"
git_init "$t/repo"
run_hook_path "$t/repo" "$NOGIT"
if contract "F4 [git missing from PATH]"; then
    assert_contains "F4 degrades to non-git docs detection" "$CTX" "docs_root: $t/repo/docs"$'\n'
    assert_contains "F4 status=ok" "$CTX" "status: ok"
fi

# ============================================================
# W. walk-up / 结构校验补充（developer 未覆盖的次序语义）
# ============================================================
# W1: 仅有 documentation/（带结构）→ 也能命中
t="$(new_tmp)"
mkdir -p "$t/repo/documentation/reviews"
git_init "$t/repo"
run_hook "$t/repo"
if contract "W1 [documentation/ only]"; then
    assert_contains "W1 docs_root=documentation" "$CTX" "docs_root: $t/repo/documentation"$'\n'
    assert_contains "W1 status=ok" "$CTX" "status: ok"
fi

# W2: 同级 docs/（无结构）+ documentation/（有结构）→ 结构优先于字面次序
t="$(new_tmp)"
mkdir -p "$t/repo/docs" "$t/repo/documentation/exec-plans"
git_init "$t/repo"
run_hook "$t/repo"
if contract "W2 [structured documentation beats bare docs]"; then
    assert_contains "W2 picks structured" "$CTX" "docs_root: $t/repo/documentation"$'\n'
    assert_contains "W2 status=ok" "$CTX" "status: ok"
fi

# W3: docs 是文件而非目录 → 跳过，needs-init
t="$(new_tmp)"
mkdir -p "$t/repo"
git_init "$t/repo"
touch "$t/repo/docs"
run_hook "$t/repo"
if contract "W3 [docs is a file]"; then
    assert_contains "W3 needs-init" "$CTX" $'status: needs-init\n'
    assert_contains "W3 docs_root=<none>" "$CTX" $'docs_root: <none>\n'
fi

# W4: 边界变体——repo 内 docs 无结构 + 父级 docs 有结构 → 取 repo 内 + needs-init，
# 绝不越界（比 T2 更强：repo 内存在 fallback 时也不越界）
t="$(new_tmp)"
mkdir -p "$t/parent/docs/design-docs" "$t/parent/repo/docs"
git_init "$t/parent/repo"
run_hook "$t/parent/repo"
if contract "W4 [fallback inside boundary]"; then
    assert_contains "W4 in-repo fallback" "$CTX" "docs_root: $t/parent/repo/docs"$'\n'
    assert_contains "W4 needs-init" "$CTX" $'status: needs-init\n'
    assert_not_contains "W4 parent never touched" "$CTX" "$t/parent/docs"
fi

# W5: cwd 深三层、结构化 docs 离 cwd 更近时优先于 repo 根（就近原则特征化）
t="$(new_tmp)"
mkdir -p "$t/repo/docs/analyze" "$t/repo/sub/docs/testing" "$t/repo/sub/deep"
git_init "$t/repo"
run_hook "$t/repo/sub/deep"
if contract "W5 [nearest structured docs wins]"; then
    assert_contains "W5 picks nearest" "$CTX" "docs_root: $t/repo/sub/docs"$'\n'
fi

# W6: 幂等性——同一 fixture 连跑两次输出完全一致
t="$(new_tmp)"
mkdir -p "$t/repo/docs/bugfixes"
git_init "$t/repo"
run_hook "$t/repo"; out1="$OUT"
run_hook "$t/repo"; out2="$OUT"
if [ "$out1" = "$out2" ] && [ -n "$out1" ]; then
    pass "W6 idempotent output"
else
    fail "W6 idempotent output" "run1=${out1@Q} run2=${out2@Q}"
fi

# ============================================================
# G. hook 声明一致性（Claude hooks/hooks.json vs Codex hooks/hooks-codex.json）
# Codex manifest 显式指向 hooks/hooks-codex.json，避免默认读取 Claude 侧 hooks/hooks.json。
# ============================================================
g_out="$("$PY" - "$REPO_ROOT" <<'PYEOF' 2>&1
import json, os, sys
root = sys.argv[1]
hooks = json.load(open(os.path.join(root, "hooks/hooks.json")))
entries = hooks["hooks"]["SessionStart"]
assert len(entries) == 1, "expect single SessionStart entry"
cmd = entries[0]["hooks"][0]["command"]
assert "hooks/session-start" in cmd, f"hooks.json command: {cmd}"
assert "CLAUDE_PLUGIN_ROOT" in cmd, f"Claude hook command should use CLAUDE_PLUGIN_ROOT: {cmd}"
assert entries[0]["matcher"] == "startup|clear|compact", f"matcher: {entries[0]['matcher']}"
assert "async" not in entries[0]["hooks"][0], "non-standard async leaked back into hooks.json"
manifest = json.load(open(os.path.join(root, ".codex-plugin/plugin.json")))
assert manifest["hooks"] == "./hooks/hooks-codex.json", f"Codex manifest hooks: {manifest.get('hooks')}"
codex = json.load(open(os.path.join(root, "hooks/hooks-codex.json")))
centry = codex["hooks"]["SessionStart"][0]
ccmd = centry["hooks"][0]["command"]
assert centry["matcher"] == "startup|resume|clear|compact", f"Codex matcher: {centry['matcher']}"
assert "PLUGIN_ROOT" in ccmd and "hooks/session-start" in ccmd, f"Codex hook command: {ccmd}"
assert "CLAUDE_PLUGIN_ROOT" not in ccmd, f"Codex hook command should not use CLAUDE_PLUGIN_ROOT: {ccmd}"
print("OK")
PYEOF
)" || true
if [ "$g_out" = "OK" ]; then
    pass "G1 Claude and Codex hook declarations are runtime-specific"
else
    fail "G1 hook declarations consistency" "$g_out"
fi
# G2: hook script remains executable for runtimes that execute it directly
if [ -x "$HOOK" ]; then
    pass "G2 hook file executable (codex direct-exec)"
else
    fail "G2 hook file executable (codex direct-exec)" "$(ls -l "$HOOK")"
fi

# ---------- 汇总 ----------
printf '\n%d passed, %d failed, %d known-bug\n' "$PASS" "$FAIL" "$KNOWN_BUGS"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
