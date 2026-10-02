#!/bin/bash
# ai-tools (正本) から辞書と検査 script を、このスキルの dir へ写す
# 使い方: export-from-ai-tools.sh [ai-tools の claude-code dir]
# 写した後、公開前検査 (check-public.sh) を通す。通らなければ停止する
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC="${1:-$HOME/ghq/github.com/DaichiHoshina/ai-tools/claude-code}"
DEST="$HERE/skills/jp-lint"

[[ -f "$SRC/guidelines/writing/NG-DICTIONARY.md" ]] || { echo "ai-tools が見つかりません: $SRC" >&2; exit 2; }

mkdir -p "$DEST/scripts" "$DEST/lib/jp-quality" "$DEST/references"

cp "$SRC/scripts/jp-quality-lint.sh" "$DEST/scripts/"
cp "$SRC/lib/jp-quality/structural-checks.sh" "$SRC/lib/jp-quality/term-extraction.sh" "$DEST/lib/jp-quality/"
for f in thresholds portable-stat log-rotation strip-code; do cp "$SRC/lib/$f.sh" "$DEST/lib/"; done

# 辞書は個人 path を含む行と、同梱しない PRINCIPLES.md への link を除いて写す
sed -e '/~\/\.claude\//d' -e '/\[PRINCIPLES\.md\](PRINCIPLES\.md)/d' \
    "$SRC/guidelines/writing/NG-DICTIONARY.md" > "$DEST/references/NG-DICTIONARY.md"

# 辞書の場所を、スキル dir からの相対 path に差し替える
sed -i.bak 's#^_principles_file=.*#_principles_file="${BASH_SOURCE[0]%/*}/../../references/NG-DICTIONARY.md"#' \
    "$DEST/lib/jp-quality/term-extraction.sh"
rm -f "$DEST/lib/jp-quality/term-extraction.sh.bak"
chmod +x "$DEST/scripts/jp-quality-lint.sh"

# 写した結果が単独で動くことと、公開できる内容であることを確かめる
printf 'テストです。効果的に実現します。\n' | "$DEST/scripts/jp-quality-lint.sh" >/dev/null || true
"$HERE/scripts/check-public.sh" "$HERE"
echo "写しました: $DEST (元 commit: $(git -C "$SRC" rev-parse --short HEAD))"
