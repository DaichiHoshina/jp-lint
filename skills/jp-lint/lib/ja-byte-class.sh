#!/usr/bin/env bash
# 日本語の文字の種類を、UTF-8 の byte の並びとして照合するための正規表現 (ERE)。
# [ァ-ヺー] や [一-龥] のような文字範囲は locale に依存する。C locale では 1 byte ずつ照合して誤一致し、
# Ubuntu の C.UTF-8 (glibc 2.39) では grep が「Invalid collation character」で失敗する。
# byte の並びなら、LC_ALL=C の下で macOS と Linux の grep / sed / bash [[ =~ ]] が同じ結果になる。
# 使う側は照合する処理を LC_ALL=C で実行する (local -x LC_ALL=C)。
# source してから使用する

if [[ "${_JA_BYTE_CLASS_LOADED:-}" == "1" ]]; then
    return 0
fi
_JA_BYTE_CLASS_LOADED=1

# カタカナ 1 文字: ァ (U+30A1, E3 82 A1) から ヺ (U+30FA, E3 83 BA) と、長音 ー (U+30FC, E3 83 BC)
_JA_KATA=$'\xE3(\x82[\xA1-\xBF]|\x83[\x80-\xBA\xBC])'
# 漢字 1 文字: CJK 統合漢字 一 (U+4E00, E4 B8 80) から U+9FFF (E9 BF BF)
_JA_KANJI=$'(\xE4[\xB8-\xBF][\x80-\xBF]|[\xE5-\xE9][\x80-\xBF][\x80-\xBF])'
