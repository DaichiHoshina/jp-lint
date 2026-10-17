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
for f in thresholds portable-stat log-rotation strip-code ja-byte-class; do cp "$SRC/lib/$f.sh" "$DEST/lib/"; done

# 辞書は個人 path を含む行と、同梱しない PRINCIPLES.md への link を除いて写す
sed -e '/~\/\.claude\//d' -e '/~\/ai-tools\//d' -e '/\[PRINCIPLES\.md\](PRINCIPLES\.md)/d' \
    "$SRC/guidelines/writing/NG-DICTIONARY.md" > "$DEST/references/NG-DICTIONARY.md"

# 文章の規範 (共通原則と、開発チームの文書の種類ごとの書き方) を写す。
# 同梱しない file への link は文字だけにし、個人 path を含む行は除く
GUIDES=(PRINCIPLES.md design-doc-protocol.md pr-description.md gh-issue.md long-form-doc.md)
mkdir -p "$DEST/references/guides"
for g in "${GUIDES[@]}"; do
  perl -ne '
    BEGIN { %keep = map { $_ => 1 } qw(PRINCIPLES.md design-doc-protocol.md pr-description.md gh-issue.md long-form-doc.md NG-DICTIONARY.md) }
    next if m{\x7e/(\.claude|ghq|ai-tools)/|/Users/};
    s{\[([^\]]+)\]\(([^)#\s]+\.md)(#[^)]*)?\)}{ $keep{$2} ? "[$1]($2$3)" : $1 }ge;
    print;
  ' "$SRC/guidelines/writing/$g" > "$DEST/references/guides/$g"
done
# 辞書への link は、guides/ から見た相対 path に合わせる
sed -i.bak 's#](NG-DICTIONARY\.md#](../NG-DICTIONARY.md#g' "$DEST"/references/guides/*.md
rm -f "$DEST"/references/guides/*.bak

# 辞書の場所を、スキル dir からの相対 path に差し替える
sed -i.bak 's#^_principles_file=.*#_principles_file="${BASH_SOURCE[0]%/*}/../../references/NG-DICTIONARY.md"#' \
    "$DEST/lib/jp-quality/term-extraction.sh"
rm -f "$DEST/lib/jp-quality/term-extraction.sh.bak"
# 利用者の差分辞書を重ねる処理は公開 repo だけの仕様なので、取り込んだ script へ差し込む
# (user-overlay.sh は正本に無く、この repo で管理する)
grep -q '_apply_user_overlay' "$DEST/scripts/jp-quality-lint.sh" || \
  sed -i.bak '/^\[\[ -n "\${JP_QUALITY_DICT:-}" \]\]/a\
# 利用者の差分辞書を重ねる (公開 repo だけの処理。export-from-ai-tools.sh が取り込みのたびに差し込む)\
source "${SCRIPT_DIR}/../lib/jp-quality/user-overlay.sh"; _apply_user_overlay
' "$DEST/scripts/jp-quality-lint.sh"
rm -f "$DEST/scripts/jp-quality-lint.sh.bak"
grep -q '_apply_user_overlay' "$DEST/scripts/jp-quality-lint.sh" || { echo "差分辞書の処理を差し込めませんでした" >&2; exit 2; }

chmod +x "$DEST/scripts/jp-quality-lint.sh"

# 写した結果が単独で動くことと、公開できる内容であることを確かめる
printf 'テストです。効果的に実現します。\n' | "$DEST/scripts/jp-quality-lint.sh" >/dev/null || true
"$HERE/scripts/check-public.sh" "$HERE"
echo "写しました: $DEST (元 commit: $(git -C "$SRC" rev-parse --short HEAD))"
