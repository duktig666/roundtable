#!/usr/bin/env bash
# hooks/session-start 单元测试（slug: hook-workspace-docs-root, issue #127）。
# 纯 bash harness：mktemp -d 造 fixture，python3 校验 JSON 与断言字段。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

PASS=0
FAIL=0
TMP_DIRS=()

cleanup() {
    local d
    for d in "${TMP_DIRS[@]:-}"; do
        if [ -n "$d" ]; then
            rm -rf "$d"
        fi
    done
}
trap cleanup EXIT

# 造临时 fixture 目录（pwd -P 消除符号链接，避免与 git rev-parse 物理路径不一致）
new_tmp() {
    local d
    d="$(cd "$(mktemp -d)" && pwd -P)"
    TMP_DIRS+=("$d")
    printf '%s' "$d"
}

# 在指定目录运行 hook；先清掉运行时 env 保证确定性，额外 KEY=VALUE 参数透传给 env
run_hook() {
    local dir="$1"
    shift
    (cd "$dir" && env -u ROUNDTABLE_DOCS_ROOT -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT -u COPILOT_CLI "$@" bash "$HOOK")
}

# DEC-1 校验：输出须为合法 JSON 且双键齐备、两份 context 一致；打印 context 文本。
# 注意：调用方必须在父 shell 里用 json_ok / json_fail 计数（命令替换是子 shell）。
get_ctx() {
    python3 -c '
import json, sys
out = json.loads(sys.stdin.read())
top = out["additionalContext"]
hso = out["hookSpecificOutput"]
assert hso["hookEventName"] == "SessionStart", "bad hookEventName"
assert hso["additionalContext"] == top, "context mismatch between the two keys"
sys.stdout.write(top)
'
}

pass() {
    PASS=$((PASS + 1))
    printf 'ok   - %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL - %s\n      %s\n' "$1" "$2"
}

json_ok() {
    pass "$1 valid dual-key JSON"
}

json_fail() {
    fail "$1 valid dual-key JSON" "raw output: ${2@Q}"
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

git_init() {
    git -C "$1" init -q
}

# ---------- T1: project 模式，walk-up 命中含结构的 docs/ ----------
t="$(new_tmp)"
mkdir -p "$t/repo/docs/design-docs" "$t/repo/sub"
git_init "$t/repo"
out="$(run_hook "$t/repo/sub")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T1"
    assert_contains "T1 mode=project" "$ctx" $'mode: project\n'
    assert_contains "T1 docs_root" "$ctx" "docs_root: $t/repo/docs"$'\n'
    assert_contains "T1 source=walk-up" "$ctx" $'docs_root_source: walk-up\n'
    assert_contains "T1 project_id" "$ctx" $'project_id: repo\n'
    assert_contains "T1 status=ok" "$ctx" "status: ok"
else
    json_fail "T1" "$out"
fi

# ---------- T2: 越界回归（#127 复现）：git 项目无 docs/，父级有 docs/ → 不越界 ----------
t="$(new_tmp)"
mkdir -p "$t/parent/docs/design-docs" "$t/parent/proj/src"
git_init "$t/parent/proj"
out="$(run_hook "$t/parent/proj")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T2"
    assert_not_contains "T2 no parent escape" "$ctx" "$t/parent/docs"
    assert_contains "T2 docs_root=<none>" "$ctx" $'docs_root: <none>\n'
    assert_contains "T2 status=needs-init" "$ctx" $'status: needs-init\n'
else
    json_fail "T2" "$out"
fi

# ---------- T3: docs/ 存在但无结构 → needs-init 且 docs_root 仍报 ----------
t="$(new_tmp)"
mkdir -p "$t/repo/docs"
git_init "$t/repo"
out="$(run_hook "$t/repo")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T3"
    assert_contains "T3 docs_root reported" "$ctx" "docs_root: $t/repo/docs"$'\n'
    assert_contains "T3 status=needs-init" "$ctx" $'status: needs-init\n'
else
    json_fail "T3" "$out"
fi

# ---------- T4a: env 有效 → source=env，显式配置不做结构校验 ----------
t="$(new_tmp)"
mkdir -p "$t/repo" "$t/ext-docs"
git_init "$t/repo"
out="$(run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT="$t/ext-docs")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T4a"
    assert_contains "T4a docs_root=env value" "$ctx" "docs_root: $t/ext-docs"$'\n'
    assert_contains "T4a source=env" "$ctx" $'docs_root_source: env\n'
    assert_contains "T4a status=ok" "$ctx" "status: ok"
else
    json_fail "T4a" "$out"
fi

# ---------- T4b: env 指向不存在目录 → warning + 降级走 walk-up ----------
t="$(new_tmp)"
mkdir -p "$t/repo/docs/analyze"
git_init "$t/repo"
out="$(run_hook "$t/repo" ROUNDTABLE_DOCS_ROOT="$t/nonexistent")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T4b"
    assert_contains "T4b warning emitted" "$ctx" "warning:"
    assert_contains "T4b degraded to walk-up" "$ctx" "docs_root: $t/repo/docs"$'\n'
    assert_contains "T4b source=walk-up" "$ctx" $'docs_root_source: walk-up\n'
else
    json_fail "T4b" "$out"
fi

# ---------- T5a: .roundtable.json 相对路径 → source=config（显式配置不做结构校验） ----------
t="$(new_tmp)"
mkdir -p "$t/repo/mydocs"
git_init "$t/repo"
printf '{"docs_root": "mydocs"}\n' > "$t/repo/.roundtable.json"
out="$(run_hook "$t/repo")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T5a"
    assert_contains "T5a docs_root resolved" "$ctx" "docs_root: $t/repo/mydocs"$'\n'
    assert_contains "T5a source=config" "$ctx" $'docs_root_source: config\n'
    assert_contains "T5a status=ok" "$ctx" "status: ok"
else
    json_fail "T5a" "$out"
fi

# ---------- T5b: .roundtable.json 绝对路径 + project_id 覆盖 ----------
t="$(new_tmp)"
mkdir -p "$t/repo" "$t/shared-docs"
git_init "$t/repo"
printf '{"docs_root": "%s", "project_id": "custom-id"}\n' "$t/shared-docs" > "$t/repo/.roundtable.json"
out="$(run_hook "$t/repo")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T5b"
    assert_contains "T5b absolute docs_root" "$ctx" "docs_root: $t/shared-docs"$'\n'
    assert_contains "T5b source=config" "$ctx" $'docs_root_source: config\n'
    assert_contains "T5b project_id override" "$ctx" $'project_id: custom-id\n'
else
    json_fail "T5b" "$out"
fi

# ---------- T5c: .roundtable.json 指向不存在目录 → warning + 继续走下一级 ----------
t="$(new_tmp)"
mkdir -p "$t/repo/docs/reviews"
git_init "$t/repo"
printf '{"docs_root": "gone"}\n' > "$t/repo/.roundtable.json"
out="$(run_hook "$t/repo")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T5c"
    assert_contains "T5c warning emitted" "$ctx" "warning:"
    assert_contains "T5c degraded to walk-up" "$ctx" "docs_root: $t/repo/docs"$'\n'
else
    json_fail "T5c" "$out"
fi

# ---------- T6: workspace 模式：非 git 父级 + 2 个 git 子项目（一有 docs 一没有） ----------
t="$(new_tmp)"
mkdir -p "$t/ws/alpha/docs" "$t/ws/beta" "$t/ws/gamma"
git_init "$t/ws/alpha"
git_init "$t/ws/beta"
out="$(run_hook "$t/ws")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T6"
    assert_contains "T6 mode=workspace" "$ctx" $'mode: workspace\n'
    assert_contains "T6 workspace_root" "$ctx" "workspace_root: $t/ws"$'\n'
    assert_contains "T6 project list" "$ctx" "projects: alpha (docs), beta"
    assert_not_contains "T6 non-git dir excluded" "$ctx" "gamma"
    assert_contains "T6 status=ok" "$ctx" $'status: ok\n'
else
    json_fail "T6" "$out"
fi

# ---------- T7: 非 git 且无子项目 → needs-init ----------
t="$(new_tmp)"
mkdir -p "$t/empty"
out="$(run_hook "$t/empty")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T7"
    assert_contains "T7 status=needs-init" "$ctx" $'status: needs-init\n'
    assert_contains "T7 docs_root=<none>" "$ctx" $'docs_root: <none>\n'
else
    json_fail "T7" "$out"
fi

# ---------- T8: git worktree → project_id = 主仓名 ----------
t="$(new_tmp)"
mkdir -p "$t/main/docs/analyze"
git_init "$t/main"
touch "$t/main/docs/analyze/seed.md"
git -C "$t/main" add -A
git -C "$t/main" -c user.email=t@t -c user.name=t commit -q -m init
git -C "$t/main" worktree add -q "$t/wt" -b test-wt
out="$(run_hook "$t/wt")"
if ctx="$(get_ctx <<<"$out" 2>/dev/null)"; then
    json_ok "T8"
    assert_contains "T8 project_id=main repo name" "$ctx" $'project_id: main\n'
    assert_contains "T8 docs_root inside worktree" "$ctx" "docs_root: $t/wt/docs"$'\n'
else
    json_fail "T8" "$out"
fi

# ---------- 汇总 ----------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
