#!/bin/bash
# 公開前検査: 個人 path と社内の語・個人名が repo 内に無いことを確かめる
# 使い方: check-public.sh [対象 dir (省略時は cwd)]
# term list が無いか、term が 0 件のときは停止する (fail-closed)
set -euo pipefail

TARGET="${1:-.}"
SOCIAL_HIT_TERM_FILE="${SOCIAL_HIT_TERM_FILE:-$HOME/.claude/references-private/social-hit-terms.txt}"
PRIVATE_TERM_FILE="${PRIVATE_TERM_FILE:-$HOME/.claude/references-private/private-name-list.txt}"
fail=0

terms_of() { [[ -f "$1" ]] && grep -v -E '^[[:space:]]*(#|$)' "$1" || true; }

# 検査 script 自身は個人 path の pattern を含むため対象から外す
scan() {
    grep -r -n -I -i -F -f "$1" "$TARGET" \
        --exclude-dir=.git --exclude=check-public.sh 2>/dev/null || true
}

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

for f in "$SOCIAL_HIT_TERM_FILE" "$PRIVATE_TERM_FILE"; do
    terms_of "$f" > "$tmp"
    if [[ ! -s "$tmp" ]]; then
        echo "停止: term list が無いか 0 件です: $f" >&2
        exit 2
    fi
    hits="$(scan "$tmp")"
    if [[ -n "$hits" ]]; then
        echo "NG: 社内の語か個人名に一致 ($(basename "$f"))" >&2
        echo "$hits" | cut -d: -f1,2 >&2   # 語そのものは表示しない
        fail=1
    fi
done

path_hits="$(grep -r -n -I -E '/Users/[A-Za-z0-9._-]+/|~/\.claude|~/ghq/' "$TARGET" \
    --exclude-dir=.git --exclude=check-public.sh 2>/dev/null || true)"
if [[ -n "$path_hits" ]]; then
    echo "NG: 個人 path を含む" >&2
    echo "$path_hits" >&2
    fail=1
fi

[[ $fail -eq 0 ]] && echo "OK: 公開前検査を通過しました"
exit $fail
