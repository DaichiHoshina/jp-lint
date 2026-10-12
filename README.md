# jp-lint

書き終えた日本語の文書を、NG 語辞書と文の組み立ての検査で点検して書き換える Claude Code のスキル。

## 構成

| path | 役割 |
|---|---|
| `skills/jp-lint/SKILL.md` | 検査から書き換えまでの手順と、失敗したときの対処 |
| `skills/jp-lint/scripts/jp-quality-lint.sh` | 辞書と構造の検査 (bash) |
| `skills/jp-lint/references/NG-DICTIONARY.md` | NG 語辞書 |
| `skills/jp-lint/lib/jp-quality/user-overlay.sh` | 利用者の差分辞書を重ねる処理 (この repo だけの仕様) |

## 使い方

`skills/jp-lint/` を Claude Code のスキルの置き場所へ入れ、「この文書を点検して」と頼む。script だけ使うときは次のとおり。

```bash
bash skills/jp-lint/scripts/jp-quality-lint.sh --strict 対象の file
```

bash 4 以上が必要 (連想配列を使う)。

## 辞書のカスタマイズ

同梱の辞書が初期設定になる。語を追加したいときや、検出してほしくない語があるときは、差分だけを `~/.config/jp-lint/ng-words.md` に記載する。場所は環境変数 `JP_LINT_USER_DICT` でも指定できる。

```markdown
## 追加
**AI定型語**: させていただきます / 〜な感じ

## 除外
**英語の業界用語 (warn-only)**: fallback
- canonical
```

- `## 追加` の行: 指定した分類に語を追加する。分類名は `references/NG-DICTIONARY.md` の `**分類名**` と同じものを使う
- `## 除外` の分類つきの行: その分類からだけ語を除く
- `## 除外` の箇条書き (`- 語`): 全分類から語を除く

差分だけを管理するので、同梱の辞書が更新されても変更は引き継がれる。辞書を丸ごと差し替えたいときは、環境変数 `JP_QUALITY_DICT` に辞書の path を指定する。

## 更新

正本は別の repo にある。file の種類で更新の方法が違う。

| file | 更新の方法 |
|---|---|
| 辞書と script (`references/` `scripts/` `lib/`) | 直接編集せず、`scripts/export-from-ai-tools.sh` でもう一度取り込む |
| `SKILL.md` | 正本の変更のうち、この repo だけで使えるものを手で書き換えて反映する |
| `user-overlay.sh` と `tests/` | 正本に無いので、この repo で直接編集する。取り込みのたびに、`export-from-ai-tools.sh` が lint script へ呼び出しを差し込む |

どちらも、反映した正本の commit を commit 本文の `ai-tools-sync:` の行に記録する。

## ライセンス

MIT
