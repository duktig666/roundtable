#!/usr/bin/env bash
# DEC-029: runtime prompt DEC/§/issue# 引用密度回归检查
# Usage: scripts/ref-density-check.sh [--update-baseline]
# Exit: 0 pass / 1 fail（超阈需 audit issue）/ 2 script error

set -euo pipefail
BASELINE="scripts/ref-density.baseline"
ROOTS=(skills agents commands)

# per-file census: DEC § issue#
# 用 grep -oE | wc -l 计总匹配数（非匹配行数），避免同行 N ref 漏计
count() {
  local f=$1
  local dec sec iss
  dec=$(grep -oE "DEC-[0-9]+" "$f" 2>/dev/null | wc -l)
  sec=$(grep -oE "§[0-9]+" "$f" 2>/dev/null | wc -l)
  iss=$(grep -oE "issue #[0-9]+|\bfixes #[0-9]+|\b#[0-9]{2,}\b" "$f" 2>/dev/null | wc -l)
  printf "%s\t%d\t%d\t%d\n" "$f" "$dec" "$sec" "$iss"
}

# collect
current=$(for root in "${ROOTS[@]}"; do
  find "$root" -name '*.md' -not -path '*/node_modules/*'
done | sort | while read -r f; do count "$f"; done)

if [[ ${1:-} == "--update-baseline" ]]; then
  printf "%s\n" "$current" > "$BASELINE"
  echo "baseline updated: $BASELINE"
  exit 0
fi

[[ ! -f "$BASELINE" ]] && { echo "ERROR: $BASELINE missing; run with --update-baseline" >&2; exit 2; }

# W3: baseline 路径去重 pre-check —— 重复行导致 grep -F 匹配不确定（silent 吞）
dup=$(awk -F'\t' 'NF>0 {print $1}' "$BASELINE" | sort | uniq -d)
if [[ -n "$dup" ]]; then
  printf "ERROR: %s has duplicate path entries:\n%s\n" "$BASELINE" "$dup" >&2
  exit 2
fi

# diff check: per-file 新增 ≥3 或 total 净增 ≥10
fail=0
total_delta=0
while IFS=$'\t' read -r f dec sec iss; do
  # W2: 新文件 baseline 缺失 → fallback 0/0/0，仅 NOTE 不 fail；delta 仍累加 total_delta
  if grep -qF "$f	" "$BASELINE"; then
    b=$(grep -F "$f	" "$BASELINE")
  else
    b="$f	0	0	0"
    c_total_note=$((dec + sec + iss))
    printf "NOTE: new file not in baseline: %s (current=%d, treated as baseline=0)\n" "$f" "$c_total_note" >&2
  fi
  b_total=$(echo "$b" | awk -F'\t' '{print $2+$3+$4}')
  c_total=$((dec + sec + iss))
  delta=$((c_total - b_total))
  # new file contributes to total_delta even if per-file delta<3
  total_delta=$((total_delta + delta))
  if (( delta >= 3 )); then
    echo "FAIL: $f DEC/§/issue# ref +$delta（baseline $b_total → current $c_total）" >&2
    fail=1
  fi
done <<< "$current"

if (( total_delta >= 10 )); then
  echo "FAIL: skills+agents+commands 合计 DEC/§/issue# ref 净增 $total_delta ≥ 10" >&2
  fail=1
fi

(( fail == 1 )) && echo "→ 开 follow-up audit issue 走 #22 方法论；或 architect sign-off 后 --update-baseline 重锁" >&2
exit $fail
