# GitHub issue body 書式

<!-- writing-tree: parent=PRINCIPLES.md role=content -->

共通文章原則は [PRINCIPLES.md](PRINCIPLES.md) 参照。

## 原則

- **簡易 pattern (背景 / やること / 補足) を default にする**
- **bug report / feature request は `external-post.md` 「Issue 起票時の追加規約」を併読する**: 期待 / 実測の section 分離・環境情報の冒頭 1 ブロック・Why/What/How 構成の canonical は同 file に定義する。この file の Canonical format は impl / 調査 / タスク issue 向け
- **開いた文章 (plain JP) 必須**: 箇条書き内も対象・状態・関係が伝わる形で書く。項目名や結果として意味が完結する名詞句は残し、文体調整のために事実・時制・評価を変えない (canonical: `guidelines/writing/PRINCIPLES.md`)
- **階層で結論と根拠を分ける**: 同レベル bullet に「変更」と「変更の理由」を並列に置かない。親 = 変更 1 文、子 = 理由 / 補足 の形にする (詳細 pattern と NG/OK 例は `PRINCIPLES.md` `## 箇条書き階層化` `### checkable pattern` + `pr-description.md` `### 変更 bullet の型`)
- **簡潔ミニマル**: 該当しない section は見出しごと削除する。空 section・「特になし」を記載しない
- template 系 (What / Why / To Do / Acceptance Criteria の 4 節構造) は section 数が多く読みづらい。避ける
- design doc がある場合は背景末尾に doc path を 1 行 link、issue 本文は doc の anchor 指定で詳細を委譲する
- **時限マーカー禁止**: 「この issue で新設」「先週合意した」「#XXX 以降」等、merge / 投稿後の読み手が解決できない時制参照を含めない (canonical: `pr-description.md` `### 時限マーカー禁止`)
- **共有 issue は非エンジニア読者前提で平易化**: CS / PM / QA が読む可能性のある issue は、エンジニア作業語彙 (mount / listener / helper / template / fetch 等) をそのまま用いず日本語化する。判定基準は「reporter や comment 参加者に非エンジニアが含まれているか」。language / stack 固有の置換辞書は project CLAUDE.md 側で管理する。file path / 属性名 / 関数名 / URL / 数値は原形維持し backtick で括る (「(HTML の書き方)」等の括弧付き補足を初出時に添えてよい)
- **やること h3 は挙動視点で書く**: コード視点 (「空 URL 時に no-image を直接 :src に指定する」) でなく、読み手に見える挙動 (「画像 URL が空のときは、最初から no-image 画像を入れる」) で書く。CS / PM が完了確認で使う軸に合わせる
- **図は Mermaid で描く**: issue 本文の構成図・流れ図・順序図は ```` ```mermaid ```` の code fence で書く。GitHub がそのまま描画し、後から編集できる。ASCII の罫線図と画像添付は使わない (canonical: `PRINCIPLES.md` `## 図は Mermaid で描く`)
- **赤字の数式に `_` を使わない**: GitHub の `$\\color{red}{\\textsf{...}}$` は math mode なので、識別子の `_` は地の文か code fence へ出す
- **実装 PR link を補足冒頭に**: 実装 PR がある issue は `## 補足` の冒頭で `実装 PR: #XXXXX` を link する。関連 issue / 上位 issue と同じ扱い

## Canonical format

```markdown
## 背景

(2〜4 段落: 何が問題か / なぜ起きるか / 影響範囲。設計 doc がある場合は path を最後に link)

## やること

### 1. <小タイトル>

(file path + 変更内容を箇条書きで具体的に)

### 2. <小タイトル>

(同上)

### 3. test を追加

(test ケースを箇条書き)

## 補足

- 上位 issue / 関連 issue link
- 起点 doc / 根拠 file path
- 後続 issue (この issue では対応しないもの)
- 完了条件 (build pass / regression なし 等)
```

## 避ける書式 (template 系)

```markdown
# 概要 (What)
# なぜやるのか (Why)
# やってほしいこと (To Do)
# 受け入れ条件 (Acceptance Criteria)
# AI 向け: コンテクスト情報
```

- section 数が多く読みづらい
- 「受け入れ条件」と「やってほしいこと」が冗長
- 「AI 向け」節は共有 issue に不要 (repo の CLAUDE.md / AGENTS.md で cover)

## How to apply

- impl issue 起票時、`gh issue create --template` は使わずこの file の pattern で body を組む
- design doc がある case は背景末尾に doc path を 1 行 link、詳細は doc の section N の anchor で委譲する
- 完了条件 (build / test / regression 確認) は補足末尾に箇条書きで集約、別 section を切らない
- 背景は「状況 → 読み手の結果」の順で段落に記述し、「やること」が対処になるよう対応させる。`不整合がある` のような書き手のラベルでなく、どの入力でどの画面や担当者に何が起きるかを記載する (canonical: `PRINCIPLES.md` 「状況 → 読み手の結果 → 対処」)

## 複数の issue を整理する表 (コメント)

上位の issue へ、Sub-issue の分類・優先度・担当の整理をコメントで投稿するときの形。

- 結論を冒頭の 1〜2 文で言い切る。意向 (「進めたい」「提案」) でなく、確かめた事実で分類する
  - 冒頭の文は、その文だけで意味が分かる具体語で書く。issue 本文の一覧を件数で指す主語 (「4 つの修正と 2 点の確認を」) は、読み手が一覧を覚えていないと意味が取れないので使わない。何をどこで行うかを名詞で書く (「残りの修正は、既存の issue 1 件と新しい Sub-issue 3 件に分けます」)
  - 1 文で述べることは 1 つにする。この issue の扱い (閉じる条件・ここでは修正しない) は、結論の文と分けて別の行にする
- 一覧は箇条書きでなく表にし、issue の表は全部同じ列にする。セルの書き方も列ごとにそろえる (例: 被害は名詞句、修正の範囲は repo 名だけ、前提が無ければ「なし」)
- 同じ内容の表を 2 回置かない。理由やまとめの節で結論を繰り返さない
- 見出しは「結論」「理由」のような型の名前でなく中身が分かる名前にし、分類の見出しには件数を添える
- issue のリンクの文字列は「#番号」と短いタイトルにする (`[#42025 管理画面の注文一覧 API の個人情報](<URL>)`)。リンクの外には「#番号」を記載しない。規則の正本は `external-post.md` 「GitHub auto-link 衝突を避ける」
- 担当の列は推測で埋めない。以前担当した・進行中・CODEOWNERS など、確かめた事実だけを書き、無ければ「なし」にする
- 表の中身は投稿前に最新の code と設定で確かめ、確かめた repo と commit を冒頭に 1 回だけ記載する。確認の状況を行ごとの列にしない
- 分類は上から重要な順に並べ、冒頭でそう書く。調査しないと効果が決まらない分類は一番下に置き、確認を先に進めるならそう一言添える
- 修正の範囲には工数の目安 (小 = 数日、中 = 数週間、大 = 1 人月以上) を添え、定義を分類の基準の表に書く。「修正が小さい」のような分類の基準は工数と一致させる
- 分類の見出しは「未確認の前提」のような抽象語でなく、何を・誰が調べれば決まるかで書く。効果が分からないものと、効果は分かるが方式が決まっていないものを 1 つの分類に混ぜない
- 件数が多いときは、チームの優先度 (project の Priority field など) で範囲を絞るかを最初に考える

## 作業の報告をコメントで投稿する形

作業の報告 (起票した・整理した) を issue へ投稿するときの形。

- 冒頭の 2 行で「何をしたか」と「読み手に何を決めてほしいか」を記載する
- 個々の項目の一覧や経緯は、Sub-issues 欄や既存の一覧で読めるなら記載しない。記載するのは方針と理由までにする
- 複数の対象と理由を並べるときは、親の項目に対象 (issue なら `[現在のタイトル](URL)`)、子の項目に理由を、インデントして記載する。理由は具体的な製品名や手口を抽象化する

## GitHub project field

GitHub project board 上で他 issue と「見た目が違う」と感じたら `Priority` / `Size` 等の field が未設定の可能性が高い。`gh project item-list` で他 issue の field 値を確認して合わせる。本文 pattern と別問題。

## 適用範囲

- 全 repo (組織を問わない)
- impl issue / 調査 issue / タスク issue 起票時
- 上位の issue へ Sub-issue の整理をコメントで投稿するとき (「複数の issue を整理する表」節)

## 参照

- `guidelines/writing/external-post.md` 「Issue 起票時の追加規約」 (bug report / feature request の構造要件)
- `guidelines/writing/pr-description.md`
- `guidelines/writing/design-doc-protocol.md`
- `guidelines/writing/PRINCIPLES.md`
