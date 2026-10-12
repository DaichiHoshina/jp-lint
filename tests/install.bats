#!/usr/bin/env bats
# install.sh の配置先と、既存の jp-lint を上書きしない動作の検査

setup() {
  INSTALL="$BATS_TEST_DIRNAME/../scripts/install.sh"
  export JP_LINT_INSTALL_HOME="$BATS_TEST_TMPDIR/home"
}

@test "引数なしなら agents と claude に配置する" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$JP_LINT_INSTALL_HOME/.agents/skills/jp-lint/SKILL.md" ]
  [ -f "$JP_LINT_INSTALL_HOME/.claude/skills/jp-lint/SKILL.md" ]
}

@test "指定したエージェントにだけ配置する" {
  run "$INSTALL" cursor
  [ "$status" -eq 0 ]
  [ -L "$JP_LINT_INSTALL_HOME/.cursor/skills/jp-lint" ]
  [ ! -e "$JP_LINT_INSTALL_HOME/.agents/skills/jp-lint" ]
}

@test "未対応の名前は終了コード 2 で止まる" {
  run "$INSTALL" unknown
  [ "$status" -eq 2 ]
}

@test "symlink でない既存の jp-lint は上書きしない" {
  mkdir -p "$JP_LINT_INSTALL_HOME/.claude/skills/jp-lint"
  touch "$JP_LINT_INSTALL_HOME/.claude/skills/jp-lint/mine"
  run "$INSTALL" claude
  [ "$status" -eq 0 ]
  [ -f "$JP_LINT_INSTALL_HOME/.claude/skills/jp-lint/mine" ]
  [ ! -L "$JP_LINT_INSTALL_HOME/.claude/skills/jp-lint" ]
  [ ! -e "$JP_LINT_INSTALL_HOME/.claude/skills/jp-lint/jp-lint" ]
  [[ "$output" == *"置き換えずに"* ]]
}
