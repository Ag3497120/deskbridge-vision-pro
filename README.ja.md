# DeskBridge

Apple Vision Pro のパススルー空間で、机上に仮想キーボードとトラックパッドを表示し、Mac を操作する実験的なアプリです。Meta VR Glasses の紹介動画にある机上入力を参考にしています。Meta の製品・ソフトウェアとは無関係です。

通常の Mac 仮想ディスプレイと並べて使える**共有空間モード**を主な方式とします。利用者が机上にボリュームを配置し、visionOS 標準のタップとドラッグを入力として使います。**机の自動検出モード**は ARKit の手・平面追跡を使い、開発者設定が必要です。

## できること

- 共有空間モードでは、ボリュームを机上に手動配置し、標準の直接タップとドラッグで入力
- MacBook 内蔵・外付けコンパクト・外付け幅広の幅と奥行きを個別に保存し、実物を目安に仮想キーボードの大きさを調整
- 共有空間では、配置を確定してから入力モードに切り替える。上部の青い目印は表示専用で、キーとトラックパッドは直接タッチのみ受け付ける
- キー全体を薄い1枚の接触面で判定し、接触点を机上のキー配置に投影する。斜めからの接触で隣のキーの側面を拾う問題を減らす
- 見た目のキーキャップと接触判定を同じ高さに置き、押したキーを短く沈ませる。上部のバーには直近の送信キーを表示
- 必要に応じて水色の接触判定領域を表示し、机とキーの高さを確認
- F/J に異なる音を割り当てる。共有空間ではキーの接触時、手追跡モードではいずれかの指先がキー上方へ近づいた時に鳴る
- 配置した入力面は visionOS のスナップ・ロックとシーン復元で次回起動時に戻せる
- 自動検出モードでは、ARKit で机と指先を追跡し、接触時にキー入力、トラックパッドの移動・クリック・ドラッグ・スクロールを判定
- 自動検出モードの打鍵は絶対高さではなく指ごとの高さの時系列で判定する。下降速度のピーク後に急停止した局所最小を 2 フレーム遅らせて確定し、局所最小から 5mm 上がると次の打鍵を受け付ける。接触位置はキーごとの 2 次元ガウスとタッチタイピングの指の割り当てで最も尤もらしいキーに割り当て、キーの隙間も隣のキーとして扱う
- 「指先を机に置いて高さを記録」で指ごとの机の高さ（0 点）を記録し、以後は打鍵の最下点で少しずつ追従させる
- 実験機能（既定は無効）: 学習なしの打鍵パイプライン。自動検出モードの打鍵を 3 値（確実 / 不確か / なし）で検出して Mac に送り、Mac が語単位の格子デコードと小型 LM の再採点でキーを決める。確認した打鍵からプロファイルが良くなる（[学習なしの打鍵パイプライン](#学習なしの打鍵パイプライン実験)）
- Multipeer Connectivity の暗号化接続で Mac に入力を送信
- Mac 側の接続承認とアクセシビリティ権限、入力の有効化を必須にする
- Mac 側でキーイベントの送信先プロセスを指定できる。対象アプリへの実際の入力反映は実機で検証中
- Full Space の自動検出モードでは、手追跡の各関節と指を半透明の水色で表示できる
- Full Space では5本の指先を個別に追跡し、手が机から離れている間は頭の位置に応じてキーボードの向きと位置を少し補正する。キーボード自体は視線入力を受けない
- 共有空間モードでは開発者モードなしで Apple 純正の Mac 仮想ディスプレイと同時に使う

## 必要な環境

- Apple Vision Pro (visionOS 26 以降) と Apple silicon Mac (macOS 15 以降)
- Xcode 26、Apple Vision Pro 実機、同じローカルネットワーク
- 自動検出モードのみ、Vision Pro の開発者モードと「Mac Virtual Display in Immersive Experiences」設定
- Mac 側でアクセシビリティ権限

## ビルドと起動

```sh
xcodegen generate
open DeskBridge.xcodeproj
```

1. Xcode の Signing & Capabilities で、Mac と Vision の両ターゲットに自分の Team と一意な Bundle ID を設定します。
2. `DeskBridgeMac` を Mac で起動します。ローカルネットワークの許可を与えます。
3. `DeskBridgeVision` を Vision Pro 実機にインストールします。ローカルネットワーク・手の追跡・空間認識を許可します。
4. Vision 側のリストから Mac を選び、Mac 側で接続を許可します。Mac 側でアクセシビリティ権限を与えた後、「入力を有効化」を押します。
5. Vision 側で実物のキーボードに近い種類を選び、入力面を表示します。仮想キーボードを実物に重ね、幅と奥行きのスライダーで大きさを合わせます。内蔵・外付けの設定は個別に保存されます。
6. ボリュームの移動ハンドルで仮想キーボードを実物から机上へ移し、visionOS のスナップ・ロックで固定します。開いたままにすると、次回の起動時に配置が復元されます。位置合わせが難しい場合は「接触判定の位置を水色で表示」をオンにします。「配置を決定して入力開始」を押してから、キーを直接触り、トラックパッドをドラッグします。
7. コントロールセンターから通常どおり Mac 仮想ディスプレイを接続します。

### Mac 側を CLI で動かす

Mac のウィンドウアプリの代わりに、ターミナルで次を実行できます。スクリプトが CLI をこの Mac でビルド・署名して `~/Applications/DeskBridgeCLI.app` に置き、そのまま起動します。CI やアプリのダウンロードは不要です。Mac のウィンドウアプリと CLI は同時に起動しないでください。

```sh
./scripts/run-mac-cli.sh
```

開発用証明書が複数ある場合は `DESKBRIDGE_SIGN_IDENTITY` に使う証明書の SHA-1 または名前を指定します。証明書がない場合はアドホック署名となり、再ビルド後にアクセシビリティ権限を設定し直す場合があります。

CLI では Vision Pro からの接続要求が表示されたら `allow`、続けて `enable` を入力します。`deny` で拒否、`disable` で入力停止、`access` で権限設定を開き、`status` で現在の状態と受信件数、キーの受信件数と投稿件数を確認できます。`apps` で起動中のアプリと Bundle ID を表示し、`target com.apple.TextEdit` のようにキーイベントの送信先を固定できます。対象アプリで入力欄を一度選んでください。`testkey` は Vision Pro を経由せず Mac 内で A キーを投稿する診断コマンドです。`target off` で通常の前面アプリ宛てに戻します。Vision 側にも Mac の入力可否と送信先を通知します。終了は `quit` です。macOS のアクセシビリティ許可は CLI 起動元のターミナルまたは CLI に対して引き続き必要です。CLI 化だけではネットワーク切断や visionOS の表示制限は解消しません。

#### 入力経路の切り替えと計測

Mac 仮想ディスプレイ使用中に visionOS のウィンドウを見ながら操作すると、Mac の入力が visionOS 側へ移る場合があります。どの投稿経路がこの引き渡しの対象外になるかを実機で切り分けるため、CLI と Mac アプリで経路を切り替えられます（Mac アプリでは「入力経路」の Picker）。選んだ経路は次回起動時も引き継ぎます（`fixedPid` を除く）。

- `keypath <hid | session | annotatedSession | frontmostPid | fixedPid>`: キーの投稿経路。既定は `frontmostPid` で、打鍵ごとにその時点の前面アプリの pid へ直接送ります。`hid` は本物のキーボードと同じ HID 層、`session` / `annotatedSession` はその後ろの層です。`fixedPid` は `target <Bundle ID>` で固定した送信先に送ります（`target` を指定すると自動で `fixedPid` になり、`target off` で `frontmostPid` に戻ります）。pid 宛ての経路では Spotlight や Cmd+Tab などのシステムショートカットは効きません。
- `pointerpath <hid | session | warp>`: ポインタの投稿経路。既定は `hid`。`warp` はカーソルを直接動かし（移動イベントは作らない）、クリック・ドラッグ・スクロールはカーソル下の最前面ウィンドウを持つアプリの pid へ送ります。カーソル下にウィンドウがなければ送りません。
- `testkey` / `testmove`: Vision Pro を経由せず、現在の経路で A キー / カーソル移動を投稿します。
- `reset`: 投稿数と観測数を 0 に戻します。
- `status`: 経路、最終送信先、キー・ポインタそれぞれの「投稿数 / session 層で観測した数 / annotated 層で観測した数」を表示します。

観測数は、DeskBridge 自身がセッション層と注釈付きセッション層に置いた listen-only のイベントタップで数えます。DeskBridge が投稿したイベントには `eventSourceUserData` に固有値を入れてあり、その値のイベントだけを数えます（他の入力は記録しません）。pid 宛てのイベントはどちらの層も通らないため、`frontmostPid` / `fixedPid` / `warp` のクリックでは観測数 0 が正常です。`annotatedSession` に投稿したキーは session 層を通りません。観測は投稿から少し遅れて反映されるため、打鍵後に一呼吸おいて `status` を実行してください。タップを作れない場合は `status` に「作成失敗」と出ます。`access` で入力監視の許可を求めます。

システム全体のイベントタップの一覧（層、タップしているプロセス、有効か、listen-only か）は次で確認できます。Mac 仮想ディスプレイの使用中と未使用時で比べると、引き渡しに関わるタップを探す手がかりになります。

```sh
./scripts/list-event-taps.sh
```

#### 実機での切り分け手順

1. Mac で TextEdit を開いて新規書類の入力欄を選び、`./scripts/run-mac-cli.sh` で CLI を起動します。Vision Pro で Mac 仮想ディスプレイを開始し、DeskBridge を共有空間（開発者モードなし）で開いて接続し、`allow`、`enable` を入力します。
2. 必要なら Mac 仮想ディスプレイ使用中に `./scripts/list-event-taps.sh` を実行し、未使用時の出力と比べて記録します。
3. 経路ごとに `reset` → `keypath <経路>`（ポインタは `pointerpath <経路>`）を実行し、次の 3 つの状態でそれぞれ机上キーボードから `abc` を打ちます（ポインタは机上トラックパッドでカーソル移動とクリック）。
   - Mac 画面: Mac 仮想ディスプレイのウィンドウを見ている
   - DeskBridge: DeskBridge のウィンドウを見ている（触れない）
   - タップ直後: DeskBridge のウィンドウを一度タップし、そのまま打つ
4. 各状態で、TextEdit に文字が入ったか（ポインタは Mac のカーソルが動き、クリックが効いたか）と、`status` の投稿数・観測数を記録します。visionOS 側の入力欄に文字が入った場合も書き留めてください。

記録表（○ = Mac に届いた、× = 届かない、V = visionOS 側に入った。括弧内に「投稿 / session / annotated」）:

| 経路 | Mac 画面 | DeskBridge | タップ直後 |
| --- | --- | --- | --- |
| keypath hid | | | |
| keypath session | | | |
| keypath annotatedSession | | | |
| keypath frontmostPid | | | |
| keypath fixedPid（TextEdit） | | | |
| pointerpath hid | | | |
| pointerpath session | | | |
| pointerpath warp | | | |

`hid` だけが × になり pid 宛てが ○ なら、HID 層を通る経路が引き渡しの対象だと分かります。投稿数に対して session 層の観測数が少ない場合は、HID 層とセッション層の間でイベントが取り除かれています。

机を自動検出する方式を試す場合は、Vision Pro の開発者設定で Mac 仮想ディスプレイの没入空間表示を有効にします。「机上表示を開始」を押し、必要に応じて左右・前後・回転・接触判定を調整してください。両手の指先を机（ホームポジション）に置いて「指先を机に置いて高さを記録」を押すと、指ごとの高さのずれを補正します。接触判定のスライダーは、キーボードでは記録した 0 点から打鍵の最下点までの許容高さ、トラックパッドでは従来どおり机からの高さとして使います。

手元で純粋な判定ロジックを検証するには:

```sh
swiftc Shared/DeskProtocol.swift Shared/DeskLayout.swift Tests/DeskLayoutTests.swift -o /tmp/deskbridge-tests
/tmp/deskbridge-tests
swiftc -O Shared/DeskProtocol.swift Shared/TextDecoder*.swift Tests/TextDecoderTests.swift -o /tmp/textdecoder-tests
/tmp/textdecoder-tests
```

学習なしの打鍵パイプライン（次の章）のテストは [テスト](#テストと-fixture) を参照してください。

## 学習なしの打鍵パイプライン（実験）

机上の 10 本指打鍵を、**ニューラルネットの学習なし**で「検出 → キー候補 → 語単位の格子デコード → 語境界の小型 LM による再採点」にかけ、利用者が確認した打鍵が増えるたびにプロファイルが良くなるようにする実験機能です。Python のプロトタイプ（`tools/proto/`、[README](tools/proto/README.md)・[README_LM](tools/proto/README_LM.md)）を Swift に移植したもので、**既定では無効**です（従来の単一しきい値の検出がそのまま動きます）。

> **数字はすべて合成データでの値**です（`tools/synth` の合成器 + `tools/proto/tracking.py`）。実機の ARKit データでは測っていません。しきい値・補正の大きさ・利用者の訂正の仕方は実機で測り直す前提です（[実機で確認すること](#実機で確認すること)）。

### 構成と分担

```
Vision Pro                                       Mac
─────────────────────────────                    ───────────────────────────────────────────────────────────
DeskInteraction (.threeLevel)                    TypingSessionController ─ 台帳 (JSONL, 端末内)
  3 値の検出 sure / maybe / なし                    TypingPipeline
  + キャリブレーション補正 (z)           TapMessage   ① キー候補 (ガウス × 指の事前, 上位 6)  → 台帳 event
  + 指ごとのしきい値 (Mac から)    ───────────▶     ② TextDecoder (wordMode, 格子デコード)
LatticeTypingController                                ③ LMWordBoundaryChooser ◀── WordBoundaryScorer (LM)
                                  ◀───────────      ④ 確定した語 → CGEvent でキー入力 → 台帳 commit / label / text
                                   しきい値・状態       ⑤ TypingProfile = 台帳の畳み込み (fold) → ①②に反映
```

- **検出は Vision Pro、デコードと LM は Mac**。Vision Pro は確定した打鍵（指・接触点・下降量・sure/maybe）だけを `TapMessage`（約 150 バイト）で送ります。打った文字を含む**台帳は Mac の Application Support にだけ**保存し（0600）、Vision Pro や外部には送りません。
- 検出方式は `DeskInteraction.tapMode`（`.legacy` が既定、`.threeLevel` が新方式）。従来の API とキーイベントの出力は変えていません。3 値の方式では `process` はキーイベントを返さず、`onTapDetected` に `DetectedTap` を渡します（トラックパッドは従来どおり）。机の自動検出モード（Full Space の手追跡）専用です。

| ファイル | 内容 |
|---|---|
| `Shared/DeskLayout.swift` | `ThreeLevelTapDetector`（3 値の検出、雑音の推定、手ごとのずれ、連動の抑制、保留と時刻順）、`DeskInteraction.tapMode` / `threeLevel` / `onTapDetected` |
| `Shared/TypingKeyModel.swift` | キー表（文字・シフト・指の事前）、キーごとのガウス × 指の事前 → 上位 k のキー候補（対数尤度）、観測への変換 |
| `Shared/TextDecoder.swift` | 既存のデコーダを拡張: 観測の sure/maybe、シフト、`wordMode`（語単位の確定）、`extraGroups`（n-best の多様化）、確定した文字の来歴。従来の文字単位の確定はそのまま |
| `Shared/TextDecoderLattice.swift` | 語単位モードの型（`WordBoundaryChooser`、`CommittedWord`、`WordBoundaryInfo`） |
| `Shared/TextDecoderMixedModel.swift` | 利用者 n-gram（Witten-Bell）と、基本モデルとの混合 |
| `Shared/TextDecoderLanguageModel.swift` `TextDecoderRomaji.swift` | 英語・ローマ字の基本モデル（モデルの中身は変更なし。倍精度の分布 `fillLogProbsDouble` を追加） |
| `Shared/WordBoundaryScorer.swift` | `WordBoundaryScorer`（プロトコル）、判定規則、`LMWordBoundaryChooser`、`StubWordBoundaryScorer`、`LocalBridgeWordBoundaryScorer` |
| `Shared/TypingProfile.swift` | 台帳（追記専用）、プロファイル（fold）、rollback、JSONL の保存 |
| `Shared/TypingFeedback.swift` | 利用者の反応 → ラベル（explicit / implicit / 安全弁）、訂正前後の語の対応づけ |
| `Shared/TypingPipeline.swift` | 実時間のパイプライン（キー候補 → デコード → 判定 → ラベル）、コマンドキー（⌫ ↵ …）、訂正、CHOICE の選択 |
| `Shared/TypingProtocol.swift` | `TapMessage`（Vision → Mac）、`TypingControlMessage`（しきい値・状態・有効無効） |
| `Mac/TypingSession.swift` `Mac/TypingPanel.swift` | Mac 側の持ち主（直列キュー、台帳の保存・復元、LM 接続、アイドルでの確定）と SwiftUI の操作パネル |
| `Vision/LatticeTypingController.swift` | Vision 側の切り替えと送信 |
| `tools/lmscore/word_server.py` | LM を localhost で提供する Python サーバ（下記） |
| `tools/proto/export_golden.py` `export_unit.py` | テスト用の fixture（Python プロトタイプの数値）を書き出す |

### 3 値の検出とキャリブレーション補正

指ごとの高さの時系列から山 → 局所最小を取り、最小から 2 フレーム後に確定します（従来と同じ状態機械。移植は倍精度）。確定した下降を次の規則で **sure / maybe / なし** に分けます。

| | 下降量 | 下降速度のピーク | 1 フレームの最大下降の割合 | 速度ピークから最下点まで |
|---|---|---|---|---|
| sure | ≥ max(指ごとのしきい値 4.5 mm, 8σh) | ≥ max(0.07 m/s, 5σv) | ≤ 0.7 | ≤ 0.10 s |
| maybe | ≥ max(指ごとのしきい値 3.0 mm, 4σh) | ≥ max(0.05 m/s, 3σv) | ≤ 0.9 | ≤ 0.12 s |

- 最下点の高さが −25 mm〜15 mm の範囲外は捨てます。再アームは 3 mm（従来は 5 mm）。接触点は最下点から確定までの 3 フレームの xy の平均です。
- σh, σv は「指先を机に置いて高さを記録」の 1 秒間の高さと 3 フレーム速度のノイズ（MAD）。ノイズの大きい追跡ではしきい値が自動で上がります。
- **連動の抑制**: maybe は、同じ手の 2 本以内の指の、1.6 倍以上深い打鍵と 60 ms 以内に重なれば捨てます（隣の指が連れて動いただけ）。判定のため、確定した打鍵は 0.16 秒保留してから時刻順に出します。
- **キャリブレーション補正（プロトタイプで最大の効果）**: 同じ 1 秒間の指先の位置とホームキー（F D S A / J K L ;）中心の差を手ごとに平均し、その **z（手前方向）成分の 0.9 倍を接触点から引きます**（x は引かない。ドリフトを拾って悪化したため）。隠れた指先の曲がりすぎが手前にずれる偏りを、打鍵の前に拾えます。プロトタイプの開発セットで最上位キーの正解率 54 → 82 %、評価セットの CER 33 → 15 %（英語、適応なし）。
- 指ごとのしきい値（sure / maybe の下降量）は、プロファイルの正例ラベルの下降量の中央値から更新され、Mac から `TypingControlMessage(.thresholds)` で Vision Pro に送られます。
- 値は `ThreeLevelTapSettings`（`DeskInteraction.threeLevel.settings`）。**合成データ（default 平滑化）で決めた値で、実機のログで再調整します。**

### デコーダ（格子）

`TextDecoderConfiguration.lattice()` が、プロトタイプで選んだ設定です（`wordMode`）。

| 設定 | 値 | メモ |
|---|---|---|
| ビーム幅 / 閾値 | 40 / 12 | 幅 100 に広げても正解が n-best に入る率は 75 → 78 % 止まり（限界は探索でなく格子） |
| `lmWeight` γ | 0.4 | 従来の 0.5 から |
| 観測の捨て方 | sure は捨てられない、maybe は −3.0 | 従来は全観測を −6 で捨てられる |
| 抜け（観測のない文字の挿入） | −2.0、候補 10 | 従来は −4.5、8 |
| 候補キー | 8（最良から −14 まで） | キー候補は 6 個ずつ渡る |
| `extraGroups` | 30（最良から 16 まで） | 先頭語が別の仮説の最良を余分に残し、語候補を平均 約 9 個にする |
| `nbestK` | 10 | 語境界で判定に渡す語候補の最大数 |
| 固定遅延 | 4 打鍵 | 語が完成して 4 打鍵過ぎたら判定 |

シフトキーは「次の 1 文字を大文字・記号にする」候補で、文字は出しません。確定した文字には、どの観測のどのキーから出たか（来歴）が付き、台帳のラベルに使われます。

### 語境界の LM と判定規則

語が完成すると、全仮説の「先頭の語（空白まで）」を語候補にまとめ、判定に渡します。**出力は常に候補の添字で、LM は格子上にない文字列を作れません。**

```
logit_i = w_beam · beam_logp_i + LM_i / T      （LM_i = 候補 + 終端の空白の対数確率の和）
p = softmax(logit)
p_top ≥ tau_commit → commit（ローマ字はさらに「LM の最上位 = ビームの最上位」のときだけ）
そうでなければ CHOICE: 確率の高い順に最大 3 候補、累積 0.98 に達したら打ち切る
```

| | 英語 | ローマ字 |
|---|---|---|
| LM | Qwen3.5-2B 4-bit（0.8B も可） | Qwen3.5-2B 4-bit、文脈・候補を簡易かな変換（`tools/lmscore/kana.py`） |
| w_beam / T | 2.0 / 1.4 | 2.0 / 3.22（README_LM の表の 3.2） |
| tau_commit | 0.95 | 0.99 かつ LM 最上位 = ビーム最上位 |
| 暗黙の承認から学習する条件（安全弁） | p_top ≥ 0.99 の commit のみ | p_top ≥ 0.999 の commit のみ |
| LM なし / 時間切れのとき | w_beam 4.0、tau 0.99 | w_beam 2.0、tau 0.99（安全弁は 0.999 以上） |

設定は `WordBoundarySettings`。LM が 0.4 秒以内に返らない・繋がらないときは LM 項を落とし、ビームの事後確率だけで同じ判定にします。プロトタイプ（合成データ、評価セット 打鍵者 4–9）では、LM で自動確定の CER が英語 14.1 → 11.4 %、ローマ字 19.7 → 17.9 % になり、正解が n-best にある語での commit の誤りは英語 8.5 → 1.7 % でした。残る誤りの大半（英語で約 88 %）は正解が n-best に無い語（打鍵の取りこぼし）で、LM では直せません（README_LM 5 章）。

### 台帳とプロファイル

台帳（`TypingLedger`）は追記専用の JSONL で、プロトタイプの形式と同じです（`results/ledgers/*.jsonl` を Swift でそのまま読めます）。

| type | 内容 |
|---|---|
| `event` | イベント id、指、接触 xy（補正後）、下降量、sure/maybe、デコーダに渡した上位キーと対数尤度 |
| `commit` | 確定した文字（イベント id、CHOICE だったか、確信度 `pTop`、LM の種類） |
| `label` | 正例/負例、キー、出どころ（`explicit` 訂正・選択 / `implicit` 暗黙の承認）、`pTop` |
| `text` | 確認された単語（利用者自身の文章の記憶用） |
| `revoke` | イベント id の範囲（と出どころ）のラベルを取り消す（rollback） |

プロファイル（`TypingProfile`）は台帳の畳み込み（fold）で決まる派生状態です: (a) キーごとのガウス（縮小推定 n0 = 20、指ごとの偏りで階層化、共分散つき）、(b) 指 → キーの事前（擬似カウント κ = 10 に正例を数え足す）、(c) 指ごとの打鍵しきい値、(d) 利用者自身の n-gram（確認した単語だけ）。起動時に保存済みの台帳から復元します。`TypingLedgerFold.rollback` は `revoke` を追記して畳み込み直します（過去のレコードは書き換えません）。

**ラベルの優先順位**: 訂正（バックスペースで消して打ち直した、CHOICE から選んだ）の `explicit` > 暗黙の承認 `implicit`（p_top の安全弁を通った commit だけ）> **未解決の CHOICE の文字からは学習しない**。暗黙の承認は、次の語が確定したときに済みます（`acceptAfterWords`）。語を丸ごと消して打ち直すと、訂正前後の語をレーベンシュタイン距離で対応づけ、打鍵ごとの正しいキーを推定して `explicit` のラベルにします。訂正とみなすのは、消してから 8 秒以内に打った、編集距離が max(2, 語長の半分) 以内の語だけです（無関係な語は訂正とせず、消した語からは何も学習しません）。一部だけ消した語は学習から外します。

### 使い方

1. **Mac**: `./scripts/run-mac-cli.sh`（または Mac アプリ）を起動し、Vision Pro の接続を `allow`、`enable`。
2. **LM を使う場合は** Mac で LM サーバを起動します（下記）。使わない場合は `typing on` だけ（ビームの事後確率で判定）。
3. **Mac の CLI**: `typing on [en | romaji] [lm none | lm 8765]` で開始（Mac アプリは「学習なしの打鍵デコーダ」パネル）。`typing status` / `typing off` / `typing pick <番号>`（直近の CHOICE から選ぶ）/ `typing ledger [wipe]` / `typing rollback <イベント id>`。
4. **Vision Pro**: 「机上表示を開始」→ 両手の指先を机に置いて「指先を机に置いて高さを記録」→「学習なし打鍵デコーダ」をオン。以後、机上のキー入力は Mac でデコードされます。語は完成して 4 打鍵後に確定して入るので、**最後の語は空白か Return（または 1.5 秒のアイドル）まで入りません**。
5. ⌫ と ↵ は、**sure の打鍵で**、全キーに対する事後確率が 0.8 以上のときだけコマンドキーとして扱います（元に戻せないため。maybe は文字の候補として扱う）。⌫ はバックスペース、↵ は文を区切って Return を送ります。Tab・Esc・矢印も同様に、未確定の文字を確定してから送ります。デコーダが消せる文字を知らないとき（Return の直後など）の ⌫ は、キーをそのまま Mac に送ります。

台帳は `~/Library/Application Support/DeskBridge/ledger/mac-en.jsonl`（ローマ字は `mac-romaji.jsonl`）。**打った文字を含む**ので、パスワードなど記録してはいけない入力には使わないでください。`typing ledger wipe` で消せます。

### LM 側の実行（Mac）

LM は `WordBoundaryScorer` プロトコルの向こうにあり、実装は 3 つです。

| 実装 | 状態 |
|---|---|
| `StubWordBoundaryScorer` | 記録した対数確率を返す（テスト、オフライン再生） |
| `LocalBridgeWordBoundaryScorer` | **実装済み**。同じ Mac の `127.0.0.1` の Python サーバに HTTP で問い合わせる（他のホストには繋がない）。時間切れ 0.4 秒 |
| MLX Swift（Qwen3.5 0.8B / 2B 4-bit + 文脈の KV キャッシュ複製） | **未実装**（下記の理由）。プロトコルのまま差し替えられる |

**MLX Swift 版を入れていない理由**: ネットワークを使えないため、Swift パッケージの取得は行いませんでした。この Mac の SwiftPM のキャッシュには `mlx-swift` と `mlx-swift-examples` 2.25.x（MLXLLM）がありますが、`mlx-swift-lm` は無く、MLXLLM に Qwen3.5（線形注意と全注意の混在）のモデル定義がありません。取得できる環境では、`Shared/WordBoundaryScorer.swift` のプロトコルを実装し、プロトタイプの KV キャッシュ手順（文脈を差分だけ prefill、候補はキャッシュをバッチ方向に複製して 1 回の forward。**線形注意の層は trim 不可**なので文脈が書き換わったら作り直す）を移してください。

Python サーバ（プロトタイプの `CachedQwenScorer` をそのまま使う）:

```sh
tools/lmscore/venv/bin/python tools/lmscore/word_server.py --kind 2B --port 8765    # 英語・ローマ字とも 2B。0.8B なら --kind 0.8B
curl -s http://127.0.0.1:8765/health
```

重み（`tools/lmscore/models/Qwen3.5-*-MLX-4bit`、2B は 1.7 GB）は既存のものを使い、ネットワークには出ません（`HF_HUB_OFFLINE=1`）。`tools/lmscore/venv`（mlx-lm と numpy）と `models/` は、worktree `deskbridge-wt/nolearn` にあり、メインのチェックアウトにはコピーしていません（重いため）。メインから動かす場合は venv と重みを同じ相対位置に用意するか、worktree のパスで実行してください。プロトタイプの測定（M1 Max、混雑下、KV キャッシュあり）では 1 語境界あたり、2B で p50 103 ms / p95 160 ms（文の中だけの文脈）、文書文脈 約 140 トークンで p50 166 ms / p95 374 ms、0.8B で p50 40〜55 ms でした。この Mac で 0.8B を `word_server.py` 経由で測ると、往復で 60〜90 ms でした。サーバは打った文字をログに残さず、`Content-Type: application/json` 以外を拒否します。

### テストと fixture

リポジトリのルートで実行します（`-O` で最適化。`Shared/TextDecoder*.swift` は 58,000 行のモデルを含むため、コンパイルに十数秒かかります）。

```sh
SHARED="Shared/DeskProtocol.swift Shared/DeskLayout.swift Shared/TextDecoder*.swift Shared/WordBoundaryScorer.swift Shared/Typing*.swift"
# 部品ごと: Python の数値を固定入力で再現（検出・キー候補・判定規則・n-gram/混合・格子デコーダ）
swiftc -O $SHARED Tests/PrototypeUnitTests.swift -o /tmp/prototype-unit-tests && /tmp/prototype-unit-tests
# golden: Python の記録（打鍵者 2 人 × 10 文 × 英語/ローマ字）を同じ部品に流して、確定した語・CHOICE・台帳・プロファイルが一致
swiftc -O $SHARED Tests/GoldenPipelineTests.swift -o /tmp/golden-tests && /tmp/golden-tests
# 実時間のパイプラインと Mac 側の持ち主（コマンドキー、訂正、CHOICE の選択、台帳の保存）
swiftc -O $SHARED Mac/TypingSession.swift Tests/TypingPipelineTests.swift -o /tmp/typing-pipeline-tests && /tmp/typing-pipeline-tests
# LM サーバとの往復（サーバがなければ未接続の挙動だけ確認）
swiftc -O Shared/DeskProtocol.swift Shared/TextDecoder*.swift Shared/WordBoundaryScorer.swift Tests/LocalBridgeTests.swift -o /tmp/local-bridge-tests
DESKBRIDGE_LM_PORT=8765 /tmp/local-bridge-tests
# 学習データの記録: メッセージ・分割転送（欠落・破損を注入）・時計のずれ・manifest・検出器の記録フック
swiftc -O Shared/DeskProtocol.swift Shared/DeskLayout.swift Shared/RecordingProtocol.swift Shared/RecordingTransfer.swift Vision/RecordingWriter.swift Tests/RecordingProtocolTests.swift -o /tmp/recording-tests && /tmp/recording-tests
# Mac 側の受信・検証・削除（送信側の本物の部品とメモリでつなぐ）
swiftc -O Shared/DeskProtocol.swift Shared/RecordingProtocol.swift Shared/RecordingTransfer.swift Mac/KeyRecorder.swift Tests/MacRecordingTests.swift -o /tmp/mac-recording-tests && /tmp/mac-recording-tests
# 記録の分析ツール（合成セッションで読み込み・時計・分析・変換を確認）
(cd tools/proto && python3 test_recording_tools.py)
```

`scripts/run-typing-tests.sh` はこれらをまとめて実行します。

- `Tests/fixtures/golden_{en,romaji}.json` は `tools/proto/export_golden.py` が、`unit.json` は `tools/proto/export_unit.py` が書きます。golden は、**Python 側も float32 に丸めた同じ追跡データで走らせ**、LM は記録した対数確率（`.cache/lmmemo`）を使うので、モデル本体は要りません。再生成: `cd tools/proto && ../lmscore/venv/bin/python export_golden.py ../../Tests/fixtures 4,5 10 && python3 export_unit.py`。
- Swift の数値は Python と倍精度で一致します（ビームの対数確率は 1e-9、プロファイルの探針は 1e-10）。一致させるために、検出・キーモデル・LM・デコーダを倍精度にし、CPython 3.12 以降の `sum()`（補償付き加算）と同じ和（`CompensatedSum`）を使っています。
- 既存の DeskLayout / TextDecoder のテストは、従来のコマンドのまま通ります。

### 実装していないこと・スタブ

- **MLX Swift の LM**（上記）。Mac 側は `LocalBridgeWordBoundaryScorer` + Python サーバ、またはビームだけ。端末内（Vision Pro）の 0.8B は未実装・未確認です。
- **CHOICE の UI**: Mac アプリのボタンと CLI の `typing pick`、Vision Pro には表示のための状態文字列（`TypingControlMessage(.status)`）まで。Vision Pro 側で 3 候補を見せて選ぶ UI は未実装です。
- **訂正の UI**: 訂正は ⌫ の打鍵で行います。語を丸ごと消した場合だけ学習します（一部だけ消す、カーソル移動、選択範囲の削除は学習しません）。
- Vision Pro 側にも台帳を置く構成（Vision Pro の端末内）は未実装です（`TypingLedgerStore` は Foundation だけなので置けます）。
- 日本語 IME の変換結果（かな漢字）の読み取りはしません。ローマ字は IME の変換前のローマ字をそのまま打ち込みます。LM に渡すかな変換は簡易です（`kana.py`）。
- 修飾キー（⌘ ⌥ ⌃）はこのパイプラインでは扱いません（文字の候補から外します）。

### 実機で確認すること

1. **3 値の検出の P / R**: 実機の ARKit の時系列で、sure / maybe の適合率・再現率（プロトタイプは P 93.5 %、R 93.5 %、sure の R は約 62 %）。しきい値表（上）を実測で再調整する。学習データの記録機能（上の「学習データの記録」）が `tapCand`（評価した全候補の特徴量）と `tapOut` を残し、`tools/proto/analyze_recording.py` が実キーとの照合で P / R と変更案を出す。
2. **キャリブレーション補正が効くか**: 実機の曲がりすぎの偏りの大きさ、試行・指・位置ごとのばらつき。z の 0.9 倍で足りるか、x は引かなくてよいか。
3. **隣の指の連動**（1.6 倍 / 60 ms / 2 本）が妥当か。保留 0.16 秒の体感（後の打鍵ほど遅れて見える）。
4. **訂正の頻度**（⌫ を使う頻度、CHOICE を選ぶ頻度）。プロトタイプの利用者モデル（`p_fix` 0.6〜1.0、CHOICE 1 秒）は仮定です。
5. **確証バイアス**: 実機で implicit ラベルの誤り率（安全弁の 0.99 / 0.999 が適切か）。rollback の運用。
6. **遅延**: 1 打鍵あたりのデコード（Mac で平均 1〜2 ms）と、LM の問い合わせ（localhost で 60〜100 ms、固定遅延 4 打鍵の間に返るか）。MCSession の `reliable` 送信の遅れと順序。
7. **Mac への入力**: 確定した語が TextEdit に正しく入るか、`frontmostPid` / `fixedPid` 経路での ⌫ と Return、Mac 仮想ディスプレイ使用中の挙動、IME（ローマ字）。
8. **LM の精度**: 文書文脈（直前の文）を使うと精度が上がるか（プロトタイプは文の中だけで測定。`contextWordLimit` は 24 語）。0.8B と 2B の差。
9. **実機の打鍵者での学習曲線**: 合成データでは約 1,000 打鍵（約 22 文）で定常になりますが、実機で何文で効くか。
10. **localhost への HTTP**: Mac アプリ / CLI（Info.plist あり）から `127.0.0.1` の LM サーバへの HTTP が、App Transport Security に止められないか（IP リテラルは対象外のはずだが未確認。止められる場合は `NSAllowsLocalNetworking`）。
11. **プライバシー**: 台帳のファイルが端末内だけにあること、`typing ledger wipe` が効くこと、Vision Pro の保存領域に台帳を置かないこと。

## 学習データの記録（実機の ARKit データを集める）

実機の手追跡データを集めて、学習なしの打鍵検出（3 値）のしきい値を調整するための機能です。ファイル形式の定義は [docs/RECORDING_FORMAT.md](docs/RECORDING_FORMAT.md)。

- **モード A（実キーボード）**: Full Space で両手の全関節（ARKit の `HandTrackingProvider`、全 27 関節、最大レート、タイムスタンプつき）を記録しながら、机に置いた **MacBook の実物のキーボード**で普段どおり打ちます。Mac は実キーの keyDown/keyUp の時刻を高精度（HID のタイムスタンプ）で記録します。Vision Pro と Mac の時計は、既存の接続の上で NTP 方式の往復計測（開始時・20 秒ごと・終了時、全サンプル保存）で合わせます。ラベルは「実キーが押された時刻」で、検出器の判断（下降量・速度・sure / maybe）と照らして再現率・精度を出せます。
- **モード B（机上のお題）**: 仮想キーボードを机に出し、ヘッドセットに表示された文章を打ちます。手の関節・検出器の判断・従来の検出が打った文字を記録します。ラベルは文章そのもの（CTC 用）。Mac への接続は不要です。
- 記録中は、検出方式を 3 値に切り替えて判断を特徴量つきで残します（しきい値に届かなかった候補も）。打鍵は Mac に送りません。**「学習なし打鍵デコーダ」はオフにしてから**始めてください（オンだと開始できません）。

### 手順（モード A）

準備（1 回）

1. Mac で CLI を起動します: `./scripts/run-mac-cli.sh`（ウィンドウアプリでも可。同時には起動しない）。ターミナル（CLI の起動元）に **システム設定 > プライバシーとセキュリティ > 入力監視** の許可が要ります。初回は記録の開始時に許可を求められることがあります。許可したら CLI を再起動します。
2. Vision Pro で DeskBridge を開き、Mac に接続して `allow`（CLI）で許可します。入力の有効化（`enable`）は不要です。
3. MacBook を机の上の、普段打つ位置に置きます。TextEdit（など CLI 以外のアプリ）を開き、入力欄を選んでおきます。
4. Vision Pro の「4. 机の自動検出モード」で「机上表示を開始」を押し、仮想キーボードが机に出るのを待ちます。**仮想キーボードを実物の MacBook のキーボードに重ね、幅と奥行きを合わせて**ください（ずれは接触位置の分析にそのまま混ざります）。MacBook の配列が ANSI でない（JIS など）場合は、分析がキーコードを一部読み飛ばします。
5. 「学習データの記録を開く」を押して記録ウィンドウを開き、机の奥に置きます。

試運転（30 秒。初回だけ）

6. モード A で「記録を開始」→ 3 秒のカウントダウンの間に、**10 本の指を実物のキーボードに置きます**（左手 A S D F、右手 J K L ;、両親指をスペースバーの上。**キーは押さない**）。そのまま 1 秒動かさず待ちます。画面に「キャリブレーション 指 10 本」と出ること、「時刻同期」にずれと往復時間（数 ms〜十数 ms）が出ること、「Mac のキー記録: 記録中」になることを確認します。
7. TextEdit に 20〜30 文字打ってから「記録を停止」。Mac の CLI に「Vision Pro の記録を保存しました」と出るのを待ち、`record list` で **検証 OK** になることを確認します。続けて下の「分析」を実行し、実キーの件数が打った数に近いこと、遅れ（検出時刻 − 実キー時刻）が数十 ms の範囲で出ることを見ます。

本番（セッションごとに「記録を開始」→ カウントダウン中に指を置く → 1 秒 → 普段どおり打つ → 「記録を停止」）

8. **普段の打鍵 5 分 × 3 セッション**。メール・メモ・好きな文章・文章の書き写しなど、普段の速さで、ホームポジションを守らなくても構いません。誤字の訂正（Delete）も普段どおり。セッションの間に手を休めて構いません。
9. **意図的な打ち分け 約 1 分 × 1 セッション**。画面の「今の打ち方」のボタンを、次の順に切り替えます（ボタンは視線とピンチで押します。**押す前後 1 秒は打たない**）: 普段どおり 5 秒 → ゆっくり（1 秒に 1 打鍵くらい、はっきり）20 秒 → 速く（できるだけ速く）20 秒 → 手を置く（キーボードに手を置いて打たない）15 秒 → 普段どおり。
10. （任意）**モード B**: 英語 50 文ほど（約 10 分）。文章は画面の指定のものを机の上で打ち、打ち終えたら視線とピンチで「正しく打てた / 間違えた」を押します。押す直前の約 0.5 秒は分析で捨てます。

途中で手が大きくずれたら「指を机に置き直して計測（やり直し）」を押します。Mac 側からも `record start keyboard` / `record stop` で開始・停止を頼めますが、Mac のターミナルで打ったキーも記録に入る点に注意してください（停止は Vision の画面のボタンを勧めます）。

### 保存先と転送

| 場所 | パス |
|---|---|
| Vision Pro | 「ファイル」App > このデバイス内 > DeskBridge > DeskBridgeRecordings > \<セッション ID\> |
| Mac | `~/DeskBridgeRecordings/<セッション ID>/`（`DESKBRIDGE_RECORDINGS_DIR` で変更可） |

停止すると Vision Pro は自動で Mac へ転送します（128 KiB ごとのフレーム。フレームごと・ファイル全体の sha256 を Mac が検証し、不一致は再送）。5 分の記録は約 100 MB（見積もり。実機で確認）です。転送が失敗した時は、Mac で `record fetch`（最後のセッション）か `record fetch <セッション ID>` で再送を頼むか、Vision の記録ウィンドウの「Mac へ送る」を押します。Mac が接続されていなくても記録は Vision Pro に残ります。CLI の `record list` で、Mac にある記録と検証結果を見られます。

### プライバシー

- **A では Mac で打ったキーコードの並び（＝打った文章）が `mac-keys.jsonl` に入ります。** パスワード、秘密の文章、他人の個人情報は打たないでください（記録中は Mac のどのアプリへの入力も記録されます。パスワード欄では macOS のセキュア入力が働くことが多いですが、当てにしないでください）。Mac のキー記録は記録セッション中だけ動き、45 分または Vision Pro との接続が 2 分以上切れた時点で自動的に止まります。
- 手の関節データ（`vision.jsonl`）は Vision Pro の中と、あなた自身の Mac の中だけにあります。外部のサーバには送りません。
- 消し方: Mac は `record wipe <セッション ID>` または `record wipe all yes`（キー記録中は不可）。Vision Pro は記録ウィンドウの「削除」「すべて削除…」、または「ファイル」App から。
- 分析結果（レポート）には打った文章は入りません（キーコードの集計とタイミングだけ）。生のファイル（`mac-keys.jsonl`）は共有しないでください。

### 分析（Mac で）

```sh
cd tools/proto
python3 analyze_recording.py ~/DeskBridgeRecordings/<セッション ID> --out report-<セッション ID>.md --json metrics-<セッション ID>.json
# 複数セッションをまとめて（それぞれ分析してレポートを連結）
python3 analyze_recording.py ~/DeskBridgeRecordings/*-keyboard --out report-all.md
# 実機の A の記録を tools/proto の試行の形式に変換し、proto の検出（従来 B0 と 3 値）に通す
python3 convert_recording.py ~/DeskBridgeRecordings/<セッション ID> --out real.npz --replay
```

依存は `numpy` だけです（`tools/proto/requirements.txt`）。レポートには、manifest の sha256 の検証、時計のずれとドリフト、検出と実キーの系統的な遅れ、sure / sure+maybe の精度・再現率（区間別・指別）、見逃しと誤検出の理由、指ごとの特徴量の分布、接触位置の偏り（指別・キー行別）、`ThreeLevelTapSettings` の変更案（そのまま貼れる Swift 形式）が入ります。変更案は同じデータで探索した値なので、**別のセッションで確かめてから**反映してください。モード B のレポートには、文ごとの検出数と文字数の比、従来の検出が打った文字の誤り率が入ります。

**返してほしいもの**: `report-*.md` と `metrics-*.json`（セッションごと）、それと次の 3 点: ① 使った MacBook の機種と配列（ANSI / JIS）、② 実物に仮想キーボードを重ねた幅・奥行き、③ 気づいたこと（カウントダウン中に指を置けたか、「手を置く」区間の誤検出、転送の成否）。生の `vision.jsonl` はサイズが大きく、必要になったら別途頼みます（`mac-keys.jsonl` は送らない）。

**合成データでの確認**: `python3 make_synthetic_recording.py --out /tmp/syn` で、同じ形式の合成セッションを作って分析・変換を試せます。**合成データの数字は実機の精度ではありません**（レポートの先頭にもそう出ます）。

## 現在の制限

Mac 内でキーボード／マウスをソフトウェアで偽装する案と、DeskBridge 内に他アプリを表示する案は [入力と表示の設計](docs/HID_ARCHITECTURE.md) にまとめています。現在の公開版は `CGEvent` 経路で、仮想HIDとリモート作業空間は未実装です。

共有空間モードは実物のキーボードをカメラで認識・採寸したり、指先の接近座標や手全体の骨格、正確な視線・頭の位置を取得したりできません。サイズは種類別の初期値から手動調整します。青いバーは表示専用の目安とローカルの送信キー履歴で、Mac のアプリに確定した文字や日本語変換結果を読み取るものではありません。目印を見るだけでキー位置を検出するものでもありません。直接タッチ設定は視線とピンチによるキーの誤選択を防ぎますが、visionOS がボリューム自体へフォーカスとカーソルを移す動作を完全には制御できません。Mac の送信先固定による改善は実機で検証中です。キーボードを見ない打鍵が安定して成立するかは実機での検証が必要です。visionOS の標準入力は最大で左右各1点の接触を報告するため、全指での高速なブラインドタッチを保証しません。

手追跡モードは5本の指先と机の位置を取得でき、F/J の上方に指が来た時に音を鳴らし、追跡された手の骨格を水色で描けます。手を入力面から離すと、頭の位置を使って向きと位置を限定的に補正します。キーボード描画自体には入力判定を置かないため、触れてもその表示が直接入力フォーカスを奪いません。ただし Full Space での ARKit が必要で、通常の共有空間ではこの手の描画や自動補正を有効にできません。Mac 仮想ディスプレイとの同時利用には Apple の開発者設定が必要です。Apple Watch への振動は Vision Pro から WatchConnectivity で直接送れません。実装には iPhone 中継アプリと watchOS アプリが別途必要です。

キー配置は ANSI 英語配列で、Shift・Command・Option・Control は一度押すと次のキー一回だけに適用されます。共有空間モードのトラックパッドはドラッグでポインタ移動、タップで左クリックです。自動検出モードは一指の移動・短いタップのクリック・長押し後のドラッグ・二指スクロールに対応します。物理的な打鍵感はありません。精度と遅延は実機での評価が必要です。パスワードや機密情報の入力には使用しないでください。

Mac 側は画面を取得・送信しません。接続は暗号化されますが、Mac 側の入力を有効化した状態で接続相手を常に確認してください。

## 根拠資料

- [Meta VR Glasses 製品ページ](https://www.meta.com/jp/vr-glasses/) — 机上入力の動画と製品紹介
- [Apple: visionOS Group Lab (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/8004/) — 開発者設定で没入空間内の Mac 仮想ディスプレイを使用できる旨
- [Apple: Setting up access to ARKit data](https://developer.apple.com/documentation/visionos/setting-up-access-to-arkit-data) — 手・机の追跡には Full Space と権限が必要
- [Apple: Immersive spaces](https://developer.apple.com/documentation/swiftui/immersive-spaces) — 通常の没入空間では他アプリのウィンドウが非表示
- [Apple: visionOS のアプリ](https://developer.apple.com/visionos/) — 共有空間のボリュームと他アプリの並列表示
- [Apple: Adding 3D content](https://developer.apple.com/documentation/visionos/adding-3d-content-to-your-app) — ボリューム内のエンティティに標準ジェスチャーを適用
- [Apple: InputTargetComponent](https://developer.apple.com/documentation/realitykit/inputtargetcomponent) — 直接タッチだけを受け付ける入力設定
- [Apple: CGEvent.postToPid](https://developer.apple.com/documentation/coregraphics/cgevent/posttopid(_:)) — Mac アプリのプロセスを宛先とするキーイベント
- [Apple: Persistent UI](https://developer.apple.com/documentation/visionos/adopting-best-practices-for-scene-restoration) — 机へのスナップ・ロックと配置復元
- [Apple: Determining whether to bring your app to visionOS](https://developer.apple.com/documentation/visionos/determining-whether-to-bring-your-app-to-visionos) — WatchConnectivity は iPhone と Watch の間だけ
- [Apple: Local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) — Bonjour とローカルネットワーク権限
