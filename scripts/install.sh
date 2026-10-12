#!/usr/bin/env bash
# jp-lint のスキルを、AI エージェントのスキルの置き場所へ symlink で配置する
# 使い方: install.sh [エージェント名...]   (省略時は agents と claude)
#   agents  … $HOME/.agents/skills   (Cursor などが読む共通の置き場所)
#   claude  … $HOME/.claude/skills   (Claude Code。Cursor も互換で読む)
#   cursor  … $HOME/.cursor/skills
#   codex   … $HOME/.codex/skills
#   gemini  … $HOME/.gemini/skills
#   copilot … $HOME/.copilot/skills
# symlink なので、この repo を git pull すれば各エージェントの jp-lint も更新される。
# 環境変数 JP_LINT_INSTALL_HOME で配置先の基点 (既定は $HOME) を変えられる (test 用)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/skills/jp-lint"
BASE="${JP_LINT_INSTALL_HOME:-$HOME}"
[[ $# -eq 0 ]] && set -- agents claude

for agent in "$@"; do
  case "$agent" in
    agents|claude|cursor|codex|gemini|copilot) dir="$BASE/.$agent/skills" ;;
    *) echo "未対応のエージェント名です: $agent (agents / claude / cursor / codex / gemini / copilot)" >&2; exit 2 ;;
  esac
  mkdir -p "$dir"
  dest="$dir/jp-lint"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    echo "既に jp-lint があるため、置き換えずに進みます: $dest (削除してから再実行してください)" >&2
    continue
  fi
  ln -sfn "$SRC" "$dest"
  echo "配置しました: $dest"
done
