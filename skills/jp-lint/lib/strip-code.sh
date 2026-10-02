#!/usr/bin/env bash
# 文章検査の前処理: code block と inline code を除く。hook の検査 (lib/jp-quality/) と
# scripts/jp-textlint.sh の共通部品
# 多重 source 防止
if [[ "${_STRIP_CODE_LOADED:-}" == "1" ]]; then
    return 0
fi
_STRIP_CODE_LOADED=1

# fence は行頭 0-3 空白の ``` を対象にする。閉じていない fence は開始行を本文として残し、
# 後続も本文として扱う (後続を全部除くと、fence の閉じ忘れ 1 つで以降の行が検査されなくなる)
# shellcheck disable=SC2016
_STRIP_CODE_FENCE_AWK='{lines[NR]=$0} END{
  b=0; last_open=0
  for(i=1;i<=NR;i++){if(lines[i]~/^[[:space:]]{0,3}```/){b=!b;if(b)last_open=i}}
  unclosed_start=(b==1)?last_open:0; b=0
  for(i=1;i<=NR;i++){
    is_fence=(lines[i]~/^[[:space:]]{0,3}```/)
    if(is_fence&&i!=unclosed_start){b=!b}
    else if(i==unclosed_start){b=0;print lines[i]}
    else if(!b){print lines[i]}
  }}'

# 引数の text から fenced code block を除き、inline code を空白に置換して返す (2 連 backtick を単一より先に置換する)
strip_code_blocks() {
  printf '%s' "$1" | awk "$_STRIP_CODE_FENCE_AWK" | sed -E 's/``[^`]*``/ /g; s/`[^`]*`/ /g'
}
