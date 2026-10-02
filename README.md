# jp-lint

書き終えた日本語の文書を、NG 語辞書と文の組み立ての検査で点検して直す Claude Code のスキル。

## 構成

| path | 役割 |
|---|---|
| `skills/jp-lint/SKILL.md` | 検査から書き換えまでの手順 |
| `skills/jp-lint/scripts/jp-quality-lint.sh` | 辞書と構造の検査 (bash) |
| `skills/jp-lint/references/NG-DICTIONARY.md` | NG 語辞書 |

## 使い方

`skills/jp-lint/` を Claude Code のスキルの置き場所へ入れ、「この文書を推敲して」と頼む。script だけ使うときは次のとおり。

```bash
bash skills/jp-lint/scripts/jp-quality-lint.sh --strict 対象の file
```

bash 4 以上が必要 (連想配列を使う)。

## 更新

辞書と script の正本は別の repo にあり、この repo は写しになる。直接編集せず、`scripts/export-from-ai-tools.sh` で取り込み直す。

## ライセンス

MIT
