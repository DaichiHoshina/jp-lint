#!/usr/bin/env bash
# 文構造の script 検出関数群 (jp-quality-check.sh から抽出)
# source してから使用する。term-extraction.sh の _strip_code_blocks / _extract_term_list に依存する

# 多重 source 防止
if [[ "${_JP_QUALITY_STRUCTURAL_CHECKS_LOADED:-}" == "1" ]]; then
    return 0
fi
_JP_QUALITY_STRUCTURAL_CHECKS_LOADED=1

# shellcheck source=term-extraction.sh
source "${BASH_SOURCE[0]%/*}/term-extraction.sh"

# 構造的可読性の script 検出 (連続漢字≥5 / 読点≥4)。warn-only、block しない。
# PRINCIPLES.md `## 文単位の品質規約` (連続漢字 4 文字上限 / 読点 3 個まで) を script 検出に接続。
# 固有名詞・技術用語で誤検知しうるため warn 止まり。出力: warn 文字列 (検出ゼロなら空)。
# 表示は count + 漢字 sample のみ (UTF-8 truncation による mojibake を避ける)
_check_structural_quality() {
  local text="$1"
  [[ -z "$text" ]] && return 0
  local clean
  clean=$(_strip_code_blocks "$text")
  local out=""
  # 連続漢字 5 文字以上。grep '[一-龯]' は C locale で byte 範囲マッチになるため python3 で Unicode 正確判定。
  # python3 不在なら graceful skip (読点 check は継続)。outward text 時のみ呼ばれるため fork 1 本は許容
  if command -v python3 &>/dev/null; then
    local kanji kc ksample
    kanji=$(printf '%s' "$clean" | python3 -c 'import sys,re
h=sorted(set(re.findall(r"[一-龯]{5,}", sys.stdin.read())))
print(f"{len(h)}\t"+" ".join(h[:3]))' 2>/dev/null || printf '0\t')
    IFS=$'\t' read -r kc ksample <<< "$kanji"
    if [[ "${kc:-0}" =~ ^[0-9]+$ ]] && (( kc > 0 )); then
      out="連続漢字≥5: ${kc}種 (${ksample}) → 助詞挿入/訓読み開く; "
    fi
  fi
  # 読点 4 個以上の文 (。で改行分割してから行=文として数える。byte-safe)
  # macOS awk はマルチバイト RS 非対応のため sed で改行化してから処理する
  # 。を改行へ置換 (BSD/GNU sed 両対応の $'\n' 形式)。SC1003 は誤検出のため抑止
  local tc
  # shellcheck disable=SC1003
  tc=$(printf '%s' "$clean" | sed 's/。/\'$'\n''/g' | awk '{ n=gsub(/、/,"x"); if(n>=4)c++ } END{ print c+0 }')
  [[ "${tc:-0}" -gt 0 ]] && out="${out}読点≥4の文: ${tc}個 → 文分割; "
  [[ -n "$out" ]] && printf '%s' "${out%; }"
  return 0
}

# 文構造の script 検出の count 版。検出数を global 変数にセットする (出力なし)。
# chat 経路 (_chat_quality_check) が矢印チェーンを block 判定に使うため、
# warn 文字列でなく数値で返す。warn 文字列が要る経路は wrapper の _check_sentence_structure を使う。
# 引数: text, polite_check (2 で「〜だ / 〜である」終止を検査 (chat 用)。3 で敬体でない文末を検査 (人に宛てる draft 用、2026-10-02)。外向き doc は default 0),
#       include_readability (1 で連続漢字≥5 / 読点≥4 も同じ python 1 fork で検査。
#       chat 経路用: _check_structural_quality との 2 重 fork を避ける。外向き経路は既存関数のまま)
# python3 不在なら全 count 0 で graceful skip
_check_sentence_structure_counts() {
  local text="$1"
  local polite_check="${2:-0}"
  _SS_POLITE_MODE="$polite_check"
  local include_readability="${3:-0}"
  _SS_KUTEN=0 _SS_ARROW=0 _SS_POLITE=0 _SS_KANJI_CNT=0 _SS_KANJI_SAMPLE="" _SS_TOUTEN=0
  _SS_FLAT=0 _SS_TIME=0 _SS_TIME_SAMPLE="" _SS_STUFF=0 _SS_STUFF_SAMPLE=""
  _SS_PLAIN_DA=0 _SS_PLAIN_DA_SAMPLE="" _SS_ENDING=0 _SS_ENDING_SAMPLE=""
  _SS_BOLD=0 _SS_BOLD_RATE=""
  [[ -z "$text" ]] && return 0
  command -v python3 &>/dev/null || return 0
  local clean
  clean=$(_strip_code_blocks "$text")
  local result
  result=$(printf '%s' "$clean" | POLITE_CHECK="$polite_check" INCLUDE_READABILITY="$include_readability" python3 -c '
import sys, os, re
text = sys.stdin.read()
lines = text.splitlines()

bullet = re.compile(r"^(\s*)([-*・]|\d+\.)\s+(.+)$")

arrow = 0
for ln in lines:
    if any(re.search(r"→.*→", seg) for seg in ln.split("/")):
        arrow += 1

# 改行も文境界に含める。句点なしの行 (commit subject + trailer / bullet 列) が
# 1 文に連結カウントされて 100 字超に誤爆するのを防ぐ (2026-07-18)
sents = [s.strip() for s in re.split(r"[。\n]", text) if s.strip()]

polite = 0
if os.environ.get("POLITE_CHECK") == "3":
    # 人に宛てる draft は敬体で書く (2026-10-02)。見出し・表・引用・ラベルだけの行は数えない
    pol_end = re.compile(r"(です|ます|ました|ません|でした|でしょう|ください|ましょう)$")
    plain_end = re.compile(r"(る|た|ない|だ|である|う)$")
    for ln in lines:
        st = ln.strip()
        if not st or st.startswith(("#", "|", ">")) or re.fullmatch(r"\[[^\]]+\]", st):
            continue
        m = bullet.match(ln)
        body = re.sub(r"^\[[ xX]\]\s*", "", m.group(3) if m else st)
        for part in body.split("。"):
            t = part.strip().rstrip("」』)）")
            if t and plain_end.search(t) and not pol_end.search(t):
                polite += 1
elif os.environ.get("POLITE_CHECK") == "2":
    # chat は敬体規範 (2026-08-28)。逆向きに「〜だ」「〜である」終止を数える
    plain = re.compile(r"(だ|である)$")
    polite = sum(1 for s in sents if plain.search(s))

kanji_cnt = 0
kanji_sample = "-"
touten = 0
if os.environ.get("INCLUDE_READABILITY") == "1":
    runs = sorted(set(re.findall(r"[一-龯]{5,}", text)))
    kanji_cnt = len(runs)
    kanji_sample = " ".join(runs[:3]) or "-"
    touten = sum(1 for s in sents if s.count("、") >= 4)

# 階層 warn: 同一インデント (連続) の bullet が 11 個以上並び、うち 1 個以上に理由語 (〜ので/〜ため/〜だから/〜なので) を含む状態を検出する。
# 閾値 ≥11 で既存 pattern 集 (list of N items) の誤爆を抑える。連続 group で判定するため途中に下位 bullet が入ればリセットする。
# 理由語は文中どこでも match してよい (bullet 末尾に限らない)。code fence 内は _strip_code_blocks で除去済のため考慮しない
reason_re = re.compile(r"(ので|ため|だから|なので)")
flat = 0
cur_indent = None
cur_group = []
def check_group(g):
    if len(g) < 11:
        return 0
    return 1 if any(reason_re.search(b) for b in g) else 0
for ln in lines:
    m = bullet.match(ln)
    if not m:
        if cur_group:
            flat += check_group(cur_group)
            cur_group = []
            cur_indent = None
        continue
    indent = len(m.group(1).replace("\t", "  "))
    body = m.group(3)
    if cur_indent is None or indent != cur_indent:
        if cur_group:
            flat += check_group(cur_group)
        cur_indent = indent
        cur_group = [body]
    else:
        cur_group.append(body)
if cur_group:
    flat += check_group(cur_group)

# 時限マーカー warn: merge / 投稿後の読み手が解決できない時制参照を検出する。誤爆抑制のため保守的 pattern に限定する。
# 対象 pattern は下 time_patterns の 5 種のみ (PR 番号 + 以降 / 「本 PR で新設」等 / 相対日付 + 合意) に限定する。
# code fence 内 pattern (`Depends on #123`) は _strip_code_blocks 済のため素の text だけ match する
time_patterns = [
    r"#\d+\s*以降",
    r"本\s*PR\s*で\s*(新設|追加|導入|削除)",
    r"本\s*commit\s*で\s*(新設|追加|導入|削除)",
    r"本\s*issue\s*で\s*(新設|追加|導入|削除)",
    r"(先週|昨日|一昨日|先月|直近)\s*(合意|決定|議論|の\s*incident)",
]
time_re = re.compile("|".join(time_patterns))
time_hits = list(dict.fromkeys(m.group(0) for m in time_re.finditer(text)))
time_cnt = len(time_hits)
time_sample = " / ".join(time_hits[:3]) or "-"

# 括弧詰め込み warn: 読点 2 個以上 + 動詞なしの括弧は書き手 memo の圧縮で、初読で意味が取れない。
# 「(A、B、C)」の名詞羅列だけを拾い、動詞を含む補足文の括弧は対象外にして誤爆を抑える
paren_verb = re.compile(r"(する|した|して|される|された|とする|になる|使う|返す|できる|残す|だ|です|ない)")
stuff_hits = []
for m in re.finditer(r"[（(]([^（）()]{1,120})[）)]", text):
    inner = m.group(1)
    if inner.count("、") >= 2 and not paren_verb.search(inner):
        stuff_hits.append(inner[:24])
stuff_cnt = len(stuff_hits)
stuff_sample = " / ".join(stuff_hits[:2]) or "-"

# 文末の断定「〜だ」を数える。PRINCIPLES.md 「plain JP の文体」 が chat の敬体と
# 外向き text の常体の両方でこの終止を禁じる。撥音便の過去形 (読んだ / 含んだ) と
# 「〜んだ」の口語は対象から外し、名詞述語と形容動詞の終止だけを拾う
da_re = re.compile(r"(?<!ん)だ$")
da_hits = []
for s in sents:
    t = s.rstrip("」』)）")
    if da_re.search(t):
        da_hits.append(t[-10:])
da_cnt = len(da_hits)
da_sample = " / ".join(da_hits[:2]) or "-"

# 同一文末の 3 連続 (user 指示 2026-09-12)。語尾の文字列だけを差し替える書き直しを
# 招かないよう、対象を地の文と 1 bullet 内の連続に限る。並列した事実を同じ文末で
# 書き並べた bullet 列は行ごとに run を切るため検出しない
ENDINGS = ["ませんでした", "ましょう", "ました", "ません", "でした", "でしょう",
           "ます", "です", "である", "だった", "した", "する", "ある", "いる",
           "なる", "ない"]
def _ending_key(sent):
    t = sent.rstrip("」』)）")
    for e in ENDINGS:
        if t.endswith(e):
            return e
    return None
keys = []
for ln in lines:
    stripped = ln.strip()
    if not stripped or stripped.startswith(("#", "|", ">", "```")):
        keys.append(None)
        continue
    m = bullet.match(ln)
    body = m.group(3) if m else stripped
    if m:
        keys.append(None)
    for part in body.split("。"):
        part = part.strip()
        if part:
            keys.append(_ending_key(part))
    if m:
        keys.append(None)
end_runs = []
run_key = None
run_len = 0
for k in keys + [None]:
    if k is not None and k == run_key:
        run_len += 1
        continue
    if run_key is not None and run_len >= 3:
        end_runs.append(f"{run_key}×{run_len}")
    run_key = k
    run_len = 1 if k is not None else 0
end_cnt = len(end_runs)
end_sample = " / ".join(end_runs[:2]) or "-"

# 太字頻度は外向き文書 (mode 0) だけ検査する。chat は太字を意図して使う
bold_hit = 0
bold_rate = "-"
if os.environ.get("POLITE_CHECK") == "0":
    prose = [ln for ln in lines if ln.strip() and not ln.lstrip().startswith(("#", "|", ">")) and not bullet.match(ln)]
    prose_chars = sum(len(ln.strip()) for ln in prose)
    bold_cnt = len(re.findall(r"\*\*[^*]+\*\*", text))
    if prose_chars > 300 and bold_cnt / prose_chars * 1000 > 3.0:
        bold_hit = 1
        bold_rate = f"{bold_cnt}個/地の文{prose_chars}字"

kuten = text.count("。")

print(f"{kuten}\t{arrow}\t{polite}\t{kanji_cnt}\t{kanji_sample}\t{touten}\t{flat}\t{time_cnt}\t{time_sample}\t{stuff_cnt}\t{stuff_sample}\t{da_cnt}\t{da_sample}\t{end_cnt}\t{end_sample}\t{bold_hit}\t{bold_rate}")
' 2>/dev/null || printf '0\t0\t0\t0\t-\t0\t0\t0\t-\t0\t-\t0\t-\t0\t-\t0\t-')
  local _ku _ar _pl _kc _ks _tt _fl _tc _ts _sc _ss _da _das _ec _es _bh _br
  IFS=$'\t' read -r _ku _ar _pl _kc _ks _tt _fl _tc _ts _sc _ss _da _das _ec _es _bh _br <<< "$result"
  [[ "${_ku:-0}" =~ ^[0-9]+$ ]] && _SS_KUTEN="$_ku"
  [[ "${_ar:-0}" =~ ^[0-9]+$ ]] && _SS_ARROW="$_ar"
  [[ "${_pl:-0}" =~ ^[0-9]+$ ]] && _SS_POLITE="$_pl"
  [[ "${_kc:-0}" =~ ^[0-9]+$ ]] && _SS_KANJI_CNT="$_kc"
  _SS_KANJI_SAMPLE="${_ks:-}"
  [[ "$_SS_KANJI_SAMPLE" == "-" ]] && _SS_KANJI_SAMPLE=""
  [[ "${_tt:-0}" =~ ^[0-9]+$ ]] && _SS_TOUTEN="$_tt"
  [[ "${_fl:-0}" =~ ^[0-9]+$ ]] && _SS_FLAT="$_fl"
  [[ "${_tc:-0}" =~ ^[0-9]+$ ]] && _SS_TIME="$_tc"
  _SS_TIME_SAMPLE="${_ts:-}"
  [[ "$_SS_TIME_SAMPLE" == "-" ]] && _SS_TIME_SAMPLE=""
  [[ "${_sc:-0}" =~ ^[0-9]+$ ]] && _SS_STUFF="$_sc"
  _SS_STUFF_SAMPLE="${_ss:-}"
  [[ "$_SS_STUFF_SAMPLE" == "-" ]] && _SS_STUFF_SAMPLE=""
  [[ "${_da:-0}" =~ ^[0-9]+$ ]] && _SS_PLAIN_DA="$_da"
  _SS_PLAIN_DA_SAMPLE="${_das:-}"
  [[ "$_SS_PLAIN_DA_SAMPLE" == "-" ]] && _SS_PLAIN_DA_SAMPLE=""
  [[ "${_ec:-0}" =~ ^[0-9]+$ ]] && _SS_ENDING="$_ec"
  _SS_ENDING_SAMPLE="${_es:-}"
  [[ "$_SS_ENDING_SAMPLE" == "-" ]] && _SS_ENDING_SAMPLE=""
  [[ "${_bh:-0}" =~ ^[0-9]+$ ]] && _SS_BOLD="$_bh"
  _SS_BOLD_RATE="${_br:-}"
  [[ "$_SS_BOLD_RATE" == "-" ]] && _SS_BOLD_RATE=""
  return 0
}

# _SS_* にセット済の count から warn 文字列を組む。counts 版を呼ばない。
# counts を自前で呼ぶ経路 (CLI) が wrapper と同じ文言を複製せずに済ませるために分けてある。
# 引数: なし。出力: warn 文字列 (検出ゼロなら空)
_format_sentence_structure_warn() {
  local out=""
  (( _SS_KANJI_CNT > 0 )) && out="連続漢字≥5: ${_SS_KANJI_CNT}種 (${_SS_KANJI_SAMPLE}) → 助詞挿入/訓読み開く; "
  (( _SS_TOUTEN > 0 )) && out="${out}読点≥4の文: ${_SS_TOUTEN}個 → 文分割; "
  (( _SS_ARROW > 0 )) && out="${out}矢印チェーン: ${_SS_ARROW}行 → 文章に展開; "
  if (( _SS_POLITE > 0 )); then
    if [[ "${_SS_POLITE_MODE:-0}" == "2" ]]; then
      out="${out}常体終止「〜だ」: ${_SS_POLITE}文 → 敬体 (です・ます) に統一; "
    elif [[ "${_SS_POLITE_MODE:-0}" == "3" ]]; then
      out="${out}敬体でない文末: ${_SS_POLITE}文 → 人に宛てる text は敬体 (です・ます) で書く; "
    fi
  fi
  (( _SS_FLAT > 0 )) && out="${out}平坦 bullet ≥11 + 理由語含み: ${_SS_FLAT}group → 上位と下位の階層に組み替え (PRINCIPLES.md ## 箇条書き階層化); "
  (( _SS_TIME > 0 )) && out="${out}時限マーカー: ${_SS_TIME}件 (${_SS_TIME_SAMPLE}) → 時制中立表現に (pr-description.md ### 時限マーカー禁止); "
  (( _SS_STUFF > 0 )) && out="${out}括弧詰め込み: ${_SS_STUFF}件 (${_SS_STUFF_SAMPLE}) → 括弧の名詞羅列を本文の文に開く (PRINCIPLES.md ### 圧縮文を開く); "
  (( _SS_PLAIN_DA > 0 )) && out="${out}文末の断定「〜だ」: ${_SS_PLAIN_DA}件 (${_SS_PLAIN_DA_SAMPLE}) → 動詞終止 (〜する / 〜した / 〜ある) に開く; "
  (( _SS_ENDING > 0 )) && out="${out}同一文末3連続: ${_SS_ENDING}箇所 (${_SS_ENDING_SAMPLE}) → 文をまとめるか 2 文目以降を下位 bullet に下げる (PRINCIPLES.md ### (3) 文体より意味を優先する); "
  (( _SS_BOLD > 0 )) && out="${out}太字頻度: ${_SS_BOLD_RATE} で 1000 字あたり 3.0 超 → 強調は結論と数値の 1〜2 か所に限定する; "
  [[ -n "$out" ]] && printf '%s' "${out%; }"
  return 0
}

# 文構造の script 検出 (矢印チェーン / 文末の文体 ほか)。warn-only。100字超文は数えるだけで出力しない (2026-08-28 廃止)。
# _check_sentence_structure_counts の wrapper。引数は counts 版と同一。
# 出力: warn 文字列 (検出ゼロなら空)。外向き経路 (_block_if_ai_jargon) はこちらを使う
_check_sentence_structure() {
  _check_sentence_structure_counts "$1" "${2:-0}" "${3:-0}"
  _format_sentence_structure_warn
}
