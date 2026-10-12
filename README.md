# jp-lint

書き終えた日本語の文書を、NG 語辞書と文の組み立ての検査で点検して書き換える AI エージェント向けのスキル。Agent Skills の形式 (`SKILL.md` を置いた dir) に対応するエージェントで使える。

## 構成

| path | 役割 |
|---|---|
| `skills/jp-lint/SKILL.md` | 検査から書き換えまでの手順と、失敗したときの対処 |
| `skills/jp-lint/scripts/jp-quality-lint.sh` | 辞書と構造の検査 (bash) |
| `skills/jp-lint/references/NG-DICTIONARY.md` | NG 語辞書 |
| `skills/jp-lint/lib/jp-quality/user-overlay.sh` | 利用者の差分辞書を重ねる処理 (この repo だけの仕様) |
| `scripts/install.sh` | 各エージェントのスキルの置き場所へ symlink で配置する |

## 使い方

repo を clone して `scripts/install.sh` を実行し、エージェントに「この文書を点検して」と頼む。

```bash
git clone https://github.com/DaichiHoshina/jp-lint.git
cd jp-lint
scripts/install.sh                 # $HOME/.agents/skills と $HOME/.claude/skills へ配置する
scripts/install.sh cursor codex    # エージェントを指定して配置する
```

symlink で配置するので、repo を `git pull` すれば各エージェントの jp-lint も更新される。

| 指定する名前 | 配置先 | 主な読み手 |
|---|---|---|
| `agents` | `$HOME/.agents/skills` | Cursor ほか、共通の置き場所を読むエージェント |
| `claude` | `$HOME/.claude/skills` | Claude Code (Cursor も互換で読む) |
| `cursor` | `$HOME/.cursor/skills` | Cursor |
| `codex` | `$HOME/.codex/skills` | Codex |
| `gemini` | `$HOME/.gemini/skills` | Gemini CLI |
| `copilot` | `$HOME/.copilot/skills` | GitHub Copilot |

置き場所はエージェントの版で変わることがある。読み込まれないときは、各エージェントの資料で置き場所を確認する。

スキルに対応していないエージェントでは、`AGENTS.md` などの指示 file に次の 1 行を加える。

```markdown
日本語の文書を書き終えたら、`<jp-lint の dir>/skills/jp-lint/SKILL.md` の手順で点検して書き換える。
```

script だけ使うときは次のとおり。

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
**英語での業界用語 (warn-only)**: fallback
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
