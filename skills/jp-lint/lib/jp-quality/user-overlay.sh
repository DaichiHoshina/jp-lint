#!/usr/bin/env bash
# 利用者の差分辞書を、同梱の辞書に重ねる (公開 repo だけの仕様)
# 差分辞書の場所: JP_LINT_USER_DICT、無ければ ~/.config/jp-lint/ng-words.md
# 書式:
#   ## 追加
#   **AI定型語**: 語A / 語B      … 指定した分類へ語を追加する (無い分類は新設)
#   ## 除外
#   **英語の業界用語 (warn-only)**: fallback   … 指定した分類から語を除く
#   - canonical                            … 全分類から語を除く
# 重ねた結果は一時 file に書き、_principles_file をそこへ向ける。

_apply_user_overlay() {
  local overlay="${JP_LINT_USER_DICT:-$HOME/.config/jp-lint/ng-words.md}"
  [[ -f "$overlay" && -f "$_principles_file" ]] || return 0
  local merged
  merged="$(mktemp "${TMPDIR:-/tmp}/jp-lint-dict.XXXXXX")" || return 0
  # shellcheck disable=SC2064
  trap "rm -f '$merged'" EXIT
  LC_ALL=C awk '
    function trim(v) { sub(/^[ \t\r]+/, "", v); sub(/[ \t\r]+$/, "", v); return v }
    # 1 file 目: 差分辞書
    FNR == NR {
      if ($0 ~ /^##[ \t]*追加/) { sec = "add"; next }
      if ($0 ~ /^##[ \t]*除外/) { sec = "del"; next }
      if ($0 ~ /^##/) { sec = ""; next }
      if (sec == "") next
      if (index($0, "**") == 1 && index(substr($0, 3), "**:") > 0) {
        rest = substr($0, 3); key = substr(rest, 1, index(rest, "**") - 1)
        n = split(substr($0, index($0, ": ") + 2), p, "/")
        for (i = 1; i <= n; i++) {
          w = trim(p[i]); if (w == "") continue
          if (sec == "add") { add[key] = (key in add) ? add[key] " / " w : w; if (!(key in order)) { order[key] = ++nk; keys[nk] = key } }
          else del[key SUBSEP w] = 1
        }
        next
      }
      if (sec == "del" && $0 ~ /^[-*][ \t]+/) { w = trim(substr($0, 3)); if (w != "") delall[w] = 1 }
      next
    }
    # 2 file 目: 同梱の辞書
    index($0, "**") == 1 && index(substr($0, 3), "**:") > 0 {
      rest = substr($0, 3); key = substr(rest, 1, index(rest, "**") - 1)
      sep = index($0, ": ")
      if (sep == 0) { print; next }
      n = split(substr($0, sep + 2), p, "/"); out = ""
      for (i = 1; i <= n; i++) {
        w = trim(p[i]); if (w == "") continue
        if ((w in delall) || ((key SUBSEP w) in del)) continue
        out = (out == "") ? w : out " / " w
      }
      if (key in add) { out = (out == "") ? add[key] : out " / " add[key]; done[key] = 1 }
      print "**" key "**: " out; next
    }
    { print }
    END { for (i = 1; i <= nk; i++) if (!(keys[i] in done)) print "\n**" keys[i] "**: " add[keys[i]] }
  ' "$overlay" "$_principles_file" > "$merged" || { rm -f "$merged"; return 0; }
  _principles_file="$merged"
}
