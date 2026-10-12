#!/usr/bin/env bats
# 利用者の差分辞書 (追加 / 分類指定の除外 / 全分類の除外) の検査

setup() {
  LINT="$BATS_TEST_DIRNAME/../skills/jp-lint/scripts/jp-quality-lint.sh"
  export JP_LINT_USER_DICT="$BATS_TEST_TMPDIR/ng-words.md"
}

@test "差分辞書が無ければ同梱の辞書で検査する" {
  export JP_LINT_USER_DICT="$BATS_TEST_TMPDIR/none.md"
  run bash -c "printf 'シームレスに連携します。\n' | '$LINT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"シームレスに"* ]]
}

@test "追加した語を検出する" {
  printf '## 追加\n**AI定型語**: ぴえん\n' > "$JP_LINT_USER_DICT"
  run bash -c "printf 'これはぴえんです。\n' | '$LINT'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ぴえん"* ]]
}

@test "分類を指定した除外はその分類だけから除く" {
  printf '## 除外\n**AI定型語**: シームレスに\n' > "$JP_LINT_USER_DICT"
  run bash -c "printf 'シームレスに連携します。\n' | '$LINT'"
  [[ "$output" != *"AI定型語: シームレスに"* ]]
  [[ "$output" == *"カタカナ造語禁止"* ]]
}

@test "箇条書きの除外は全分類から除く" {
  printf '## 除外\n- シームレスに\n- シームレス\n' > "$JP_LINT_USER_DICT"
  run bash -c "printf 'シームレスに連携します。\n' | '$LINT'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"シームレス"* ]]
}

@test "取り込み script の差し込み処理が正本の script に効く" {
  orig="$BATS_TEST_TMPDIR/jp-quality-lint.sh"
  git -C "$BATS_TEST_DIRNAME/.." show origin/main:skills/jp-lint/scripts/jp-quality-lint.sh > "$orig"
  # export-from-ai-tools.sh の差し込み部分だけを取り出して、正本相当の script に当てる
  snippet=$(sed -n '/^grep -q .*_apply_user_overlay/,/^grep -q .*_apply_user_overlay/p' \
    "$BATS_TEST_DIRNAME/../scripts/export-from-ai-tools.sh")
  DEST="$BATS_TEST_TMPDIR/dest"; mkdir -p "$DEST/scripts"; cp "$orig" "$DEST/scripts/"
  DEST="$DEST" bash -c "set -e; DEST=\"$DEST\"; $snippet"
  grep -q '^source .*user-overlay.sh"; _apply_user_overlay$' "$DEST/scripts/jp-quality-lint.sh"
}

@test "くだけた話し言葉の分類は同梱しない" {
  run grep -c 'くだけた話し言葉' "$BATS_TEST_DIRNAME/../skills/jp-lint/references/NG-DICTIONARY.md" "$BATS_TEST_DIRNAME/../skills/jp-lint/scripts/jp-quality-lint.sh"
  [[ "$output" != *":1"* ]]
  run bash -c "printf 'やっぱ大事だよ。\n' | '$BATS_TEST_DIRNAME/../skills/jp-lint/scripts/jp-quality-lint.sh'"
  [ "$status" -eq 0 ]
}
