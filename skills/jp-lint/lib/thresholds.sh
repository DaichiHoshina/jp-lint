#!/usr/bin/env bash
# =============================================================================
# Canonical threshold definitions for ai-tools hooks.
# Edit here only. All hook / bats references must source this file.
# =============================================================================

# 多重 source 防止
if [[ "${_THRESHOLDS_LOADED:-}" == "1" ]]; then
    return 0
fi
_THRESHOLDS_LOADED=1

readonly _TH_PARALLEL_SEQ=2               # 並列 warn: sequential agent fire
readonly _TH_PARALLEL_SEQ_TTL_NS=600000000000 # 10 min。前回 fire からこれを超えて空いた起動は別作業とみなし、sequential counter を 0 から集計し直す (実測: 約 4 時間空いた別作業を逐次と集計して誤 warn した)
readonly _TH_BUNDLE_HARD_BLOCK_SEQ=3      # bundle 違反 hard block: warn 後の更なる sequential fire (bundle-violation guard)
readonly _TH_DELEGATE_SEQ=3               # 委譲 warn: large-repo 連続 edit
readonly _TH_PARALLEL_WINDOW_NS=30000000000 # 30 sec 並列判定 window (nanosec)。Claude Code は 1 message N tool_use を起動するとき subagent spawn の overhead で各 Agent 起動が 5-25 秒間隔になる実測あり (2026-06-25 bundle-violation-block.log elapsed_ms=23647)。500ms では並列を逐次扱いにして誤って block する。人間は 30 sec 以内に同じ command を連発しないため別 message 逐次の誤判定リスクは低い。
readonly _TH_CONTEXT=200000              # 1 応答の読み込み 200K token で warn。公式 docs: 1 時間 cache で約 200K を超えた idle の会話は自動 compact される (2026-10-27 実測: 200-299 msg の中央値 193K)
readonly _TH_CONTEXT_URGENT=400000       # 400K token で urgent。1 応答の費用が 100K の会話の 4 倍 (2026-10-27 実測: 400 msg 以上の会話が直近 14 日の cache_read の 8 割)
readonly _TH_IDLE_S=3600                  # 60 分 idle で /clear 提案。prompt cache の TTL が 1 時間で、それより短い idle では cache を再利用できる
readonly _TH_TASK_COMPLETED_SEQ=2         # task 完了 warn
readonly _TH_STOP_MEMORY_FILES=3          # stop.sh memory-save 候補 file 数
readonly _TH_STOP_PUSH_MIN_TOOLS=3        # stop.sh 完了通知 guard: turn 内の tool 呼び出しがこの回数以上なら作業 turn とみなす
readonly _TH_STOP_PUSH_MIN_SEC=300        # stop.sh 完了通知 guard: turn の開始からこの秒数未満なら user が画面の前にいるとみなして判定しない (60 秒では 7 日で 110 件が terminal active で不要と判定された)
readonly _TH_LOG_ROTATION_LINES=1000      # subagent-start.sh log rotation
readonly _TH_LOG_MAX_BYTES=1048576        # 1MB、log rotation 閾値
readonly _TH_BLOAT_THROTTLE_S=900         # 15 分、session bloat warn throttle
readonly _TH_BLOAT_THROTTLE_URGENT_S=300  # 5 分、urgent は throttle 短く
readonly _TH_JP_REF_LIST_MAX=10           # block message に併記する語数の上限。比喩・擬人化 (block) は 435 語 2115 文字あり、全語を出力すると hit 語が埋没する (2026-09-14 実測)
