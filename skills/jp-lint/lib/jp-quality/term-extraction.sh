#!/usr/bin/env bash
# NG-DICTIONARY.md 辞書抽出・cache 関数群 (jp-quality-check.sh から抽出)
# source してから使用する

# 多重 source 防止
if [[ "${_JP_QUALITY_TERM_EXTRACTION_LOADED:-}" == "1" ]]; then
    return 0
fi
_JP_QUALITY_TERM_EXTRACTION_LOADED=1

# shellcheck source=../thresholds.sh
source "${BASH_SOURCE[0]%/*}/../thresholds.sh"
# shellcheck source=../portable-stat.sh
source "${BASH_SOURCE[0]%/*}/../portable-stat.sh"
# shellcheck source=../log-rotation.sh
source "${BASH_SOURCE[0]%/*}/../log-rotation.sh"
# shellcheck source=../strip-code.sh
source "${BASH_SOURCE[0]%/*}/../strip-code.sh"

# ====================================
# AI定型語 / カタカナ造語 block 関数
# NG-DICTIONARY.md から動的抽出 → 外向き text に grep → hit で exit 2
# ====================================
_principles_file="${BASH_SOURCE[0]%/*}/../../references/NG-DICTIONARY.md"

# _extract_term_list の per-process cache (同一プロセス内で同 key の grep を1回に削減)
declare -A _term_list_cache=()
_assert_required_keys_done=${_assert_required_keys_done:-0}

# block ログ出力関数
# 引数: tool_name, hit_term, block|warn
_append_jp_quality_log() {
  local tool_name="$1"
  local hit_term="$2"
  local action="$3"
  # bats unit test 実行中はログ汚染を防ぐため skip
  [[ -n "${BATS_TEST_FILENAME:-}" ]] && return 0
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-block.log"
  # mkdir は -p で安全に
  mkdir -p "$log_dir" 2>/dev/null || true
  _rotate_log_if_needed "$log_file" 3
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  printf '%s | %s | %s | %s\n' "$ts" "$tool_name" "$hit_term" "$action" >> "$log_file" 2>/dev/null || true
}

# code block (``` ... ``` および ` ... `) を除去したテキストを返す
_strip_code_blocks() {
  strip_code_blocks "$1"
}

# 指定 key の list を NG-DICTIONARY.md から抽出 (「**<key>**: 語1 / 語2 / ...」行)
# per-process cache: 同 file+key の grep を1回に削減
_extract_term_list() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  local cache_key="${file}::${key}"
  if [[ -v "_term_list_cache[${cache_key}]" ]]; then
    local cached="${_term_list_cache[${cache_key}]}"
    [[ -n "$cached" ]] && printf '%s\n' "${cached}"
    return 0
  fi
  local line
  line=$(grep -m1 "^\*\*${key}\*\*:" "$file" 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    _term_list_cache["${cache_key}"]=""
    return 0
  fi
  local body="${line#*: }"
  local result
  result=$(printf '%s' "$body" | tr '/' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v '^$' || true)
  _term_list_cache["${cache_key}"]="${result}"
  [[ -n "$result" ]] && printf '%s\n' "${result}"
  return 0
}

# 辞書全 key を 1 pass で cache へ載せる (key 数 × 5 fork → awk 1 fork)
# _extract_term_list と同じ抽出結果になるよう「**key**: 語1 / 語2」行を / 区切りで分解して trim する
_preload_term_lists() {
  [[ -f "$_principles_file" ]] || return 0
  [[ "${_term_lists_preloaded:-0}" == "1" ]] && return 0
  _term_lists_preloaded=1
  # 辞書の解析は awk 1 fork にまとめる。bash の while read で 1 行ずつ解析すると
  # 辞書全体で 30ms を超え、Write / commit の hook 呼び出しごとに待たされる。
  # awk は "key<US>語1<RS>語2" の形で返し、bash 側は cache へ入れるだけにする
  local key words cache_key
  while IFS=$'\x1f' read -r key words; do
    cache_key="${_principles_file}::${key}"
    # grep -m1 相当: 同 key の重複行は先勝ち
    [[ -v "_term_list_cache[${cache_key}]" ]] && continue
    _term_list_cache["${cache_key}"]="${words//$'\x1e'/$'\n'}"
  done < <(LC_ALL=C awk '
    function trim(v) {
      sub(/^[ \t\r\n\v\f]+/, "", v)
      sub(/[ \t\r\n\v\f]+$/, "", v)
      return v
    }
    index($0, "**") == 1 && index(substr($0, 3), "**:") > 0 {
      rest = substr($0, 3)
      key = substr(rest, 1, index(rest, "**") - 1)
      sep = index($0, ": ")
      body = sep ? substr($0, sep + 2) : $0
      n = split(body, parts, "/")
      out = ""
      for (i = 1; i <= n; i++) {
        w = trim(parts[i])
        if (w == "") continue
        out = (out == "" ? w : out "\036" w)
      }
      printf "%s\037%s\n", key, out
    }
  ' "$_principles_file")
  return 0
}

# 置換候補 (頻出) key から word に対応する置換先を返す
# 引数: word (踏襲 / leverage 等)
# 返値: 置換先文字列 (stdout)。対応なしなら空文字
_lookup_suggestion() {
  local word="$1"
  local pairs
  pairs=$(_extract_term_list "$_principles_file" "置換候補 (頻出)" 2>/dev/null || true)
  [[ -z "$pairs" ]] && return 0
  local pair
  while IFS= read -r pair; do
    [[ -z "$pair" ]] && continue
    local src dst
    # split on → (U+2192)
    src="${pair%%→*}"
    dst="${pair#*→}"
    src="${src# }"; src="${src% }"
    dst="${dst# }"; dst="${dst% }"
    if [[ "$src" = "$word" ]]; then
      printf '%s' "$dst"
      return 0
    fi
  done <<< "$pairs"
  return 0
}

# 必須 key sanity check: hook が exact match 参照する key が抽出 0 件なら fail-loud
# NG-DICTIONARY.md key rename / 記法破壊を早期検出して silent pass を防ぐ
# session+mtime 単位 flag file cache: 同セッション内の 7 grep を skip、dict 編集時は mtime 変化で再検査
# SESSION_ID は caller (pre-tool-use.sh) が export して渡す想定、未設定時は $$ で代替
_assert_required_keys() {
  # per-process 変数での早期 return (同一プロセス内の2回目以降)
  [[ "${_assert_required_keys_done:-0}" -eq 1 ]] && return 0

  # session+mtime 単位 flag file: /tmp/claude-ngdict-keys-ok-<SESSION_ID>-<mtime>
  # NG-DICTIONARY.md を同 session 内で編集した場合も mtime 変化で再検査する
  local _dict_mtime
  _dict_mtime=$(portable_stat_mtime "$_principles_file")
  local _flag_path="/tmp/claude-ngdict-keys-ok-${SESSION_ID:-$$}-${_dict_mtime}"
  # 古いキャッシュ (同セッション・異なる mtime) のみ削除 — _flag_path 自体は保持する
  for _old_flag in "/tmp/claude-ngdict-keys-ok-${SESSION_ID:-$$}"-*; do
    [[ -e "$_old_flag" ]] || continue
    [[ "$_old_flag" = "$_flag_path" ]] && continue
    rm -f "$_old_flag" 2>/dev/null || true
  done
  if [[ -f "$_flag_path" ]]; then
    _assert_required_keys_done=1
    return 0
  fi

  _assert_required_keys_done=1
  # NG-DICTIONARY.md 不在時は別経路で既に silent pass → この検査はスキップ
  [[ -f "$_principles_file" ]] || return 0
  local required_keys=("AI定型語" "カタカナ造語禁止" "断定語 (warn-only)" "英語jargon (warn-only)" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)" "AI段取り定型 (block)" "ヘッジ濫用 (block)" "過剰丁寧 (block)" "曖昧な汎用動詞 (block)")
  local key
  for key in "${required_keys[@]}"; do
    local result
    result=$(_extract_term_list "$_principles_file" "$key")
    if [[ -z "$result" ]]; then
      printf '[hook-error] PRINCIPLES.md key '"'"'%s'"'"' 抽出 0 件 — rename or 記法破壊の可能性。silent pass 防止のため exit 2 で fail-loud。\n' "$key" >&2
      exit 2
    fi
  done
  # 検査成功: flag file を touch して次回 session 内 skip を有効化
  touch "$_flag_path" 2>/dev/null || true
}

# inject byte size log 出力関数
# 引数: tool_name, bytes, status(ok|over)
_append_jp_quality_inject_log() {
  local tool_name="$1"
  local bytes="$2"
  local status_str="$3"
  [[ -n "${BATS_TEST_FILENAME:-}" ]] && return 0
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-inject.log"
  mkdir -p "$log_dir" 2>/dev/null || true
  _rotate_log_if_needed "$log_file" 3
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  printf '%s | tool=%s | bytes=%s | threshold=1500 | status=%s\n' \
    "$ts" "$tool_name" "$bytes" "$status_str" >> "$log_file" 2>/dev/null || true
}

# 外向き text に対して指定 key の list を grep し、hit 語を stdout に出力
# 返り値: hit あり=1, なし=0
_check_term_list() {
  local text="$1"
  local key="$2"
  [[ -z "$text" ]] && return 0
  [[ -f "$_principles_file" ]] || return 0
  # code block を除去してからチェック
  local clean_text
  # _block_if_ai_jargon が同じ text を前処理済みなら再利用する (category ごとに 4 fork を省く)
  if [[ -n "${_JPQ_CLEAN_SRC+set}" && "$text" == "$_JPQ_CLEAN_SRC" ]]; then
    clean_text="$_JPQ_CLEAN"
  else
    clean_text=$(_strip_code_blocks "$text")
    # hyphen 連結の ASCII 識別子 (skill / file / branch 名等) を除去する。
    # 例: comprehensive-review が「comprehensive」に部分一致して誤って block するのを防ぐ。
    # 英語 NG 語は識別子内で使われても文章表現ではないため除去して問題ない
    clean_text=$(printf '%s' "$clean_text" | sed -E 's/[A-Za-z0-9_.]+(-[A-Za-z0-9_.]+)+/ /g')
  fi
  # 「し直す」は動作の再実行を指し意味が曖昧にならないため、直す系の判定から除く (user 決定 2026-09-25)
  if [[ "$key" == "曖昧な汎用動詞 (block)" ]]; then
    clean_text=${clean_text//し直/ }
  fi
  # 語リストを配列に収集
  # cache を満たしてから直接読む。process substitution で _extract_term_list を呼ぶと
  # cache 済みでも subshell が 1 fork 増える
  _extract_term_list "$_principles_file" "$key" >/dev/null
  local cached="${_term_list_cache["${_principles_file}::${key}"]-}"
  local words=() word
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    words+=("$word")
  done <<< "$cached"
  [[ ${#words[@]} -eq 0 ]] && return 0

  # 全語を1回の grep -ioFf で hit 語を列挙 (N×fork → 1 fork)
  # -i: 英語 NG 語 (leverage / Leverage / LEVERAGE 等) の大文字小文字差があっても検出する。JP 語は無影響
  local found
  found=$(printf '%s' "$clean_text" | grep -ioFf <(printf '%s\n' "${words[@]}") | sort -u || true)
  [[ -z "$found" ]] && return 0
  if [[ "$key" == "AI段取り定型 (block)" ]]; then
    _filter_dandori_by_position found "$clean_text"
    [[ -z "$found" ]] && return 0
  fi
  if [[ "$key" == "カタカナ造語禁止" ]]; then
    _filter_katakana_by_boundary found "$clean_text"
    [[ -z "$found" ]] && return 0
  fi
  printf '%s\n' "$found"
  return 1
}

# カタカナだけの NG 語は「スクリーンショット」の「クリーン」のように長いカタカナ語に部分一致するため、
# 前後がカタカナでない位置に現れたときだけ hit として残す。漢字を含む語 (直感的 等) はそのまま残す
_filter_katakana_by_boundary() {
  local -n _kb_found="$1"
  local _text="$2" _kept="" _hit
  while IFS= read -r _hit; do
    [[ -z "$_hit" ]] && continue
    if [[ "$_hit" =~ ^[ァ-ヺー]+$ ]] && \
       ! printf '%s' "$_text" | LC_ALL=en_US.UTF-8 grep -qE "(^|[^ァ-ヺー])${_hit}([^ァ-ヺー]|$)"; then
      continue
    fi
    _kept+="${_hit}"$'\n'
  done <<< "$_kb_found"
  _kb_found="${_kept%$'\n'}"
}

# AI 段取り短語 (まず/次に/…) は「気まずい」等に部分一致するため段落 lead 位置のみ block
_filter_dandori_by_position() {
  local -n _found_ref="$1"
  local _text="$2"
  local _leads=("まず" "次に" "最後に" "続いて" "加えて" "さらに" "それでは")
  local _lead_prefix='(^|[。、」』])[[:space:]]*([-*・]|[0-9]+[.)])?[[:space:]]*'
  local _kept="" _hit _is_lead _lead _exclude
  while IFS= read -r _hit; do
    [[ -z "$_hit" ]] && continue
    _is_lead=0
    for _lead in "${_leads[@]}"; do
      [[ "$_hit" == "$_lead" ]] && { _is_lead=1; break; }
    done
    if [[ $_is_lead -eq 0 ]]; then
      _kept="${_kept:+${_kept}$'\n'}${_hit}"
      continue
    fi
    if [[ "$_hit" == "まず" ]]; then
      _exclude="(まずまず|まず[いくかけさそ])"
    else
      _exclude="${_hit}${_hit}"
    fi
    if printf '%s' "$_text" | grep -qE "${_lead_prefix}${_hit}" && \
       ! printf '%s' "$_text" | grep -qE "${_lead_prefix}${_exclude}"; then
      _kept="${_kept:+${_kept}$'\n'}${_hit}"
    fi
  done <<< "$_found_ref"
  _found_ref="$_kept"
}
