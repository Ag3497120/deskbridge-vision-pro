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
- F/J に異なる音を割り当てる。共有空間ではキーの接触時、手追跡モードでは人差し指がキー上方へ近づいた時に鳴る
- 配置した入力面は visionOS のスナップ・ロックとシーン復元で次回起動時に戻せる
- 自動検出モードでは、ARKit で机と指先を追跡し、接触時にキー入力、トラックパッドの移動・クリック・ドラッグ・スクロールを判定
- Multipeer Connectivity の暗号化接続で Mac に入力を送信
- Mac 側の接続承認とアクセシビリティ権限、入力の有効化を必須にする
- Mac 側でキー入力の送信先アプリを指定できる。指定時は前面アプリに依存せず、その Mac アプリのプロセスへキーイベントを送る
- Full Space の自動検出モードでは、手追跡の各関節と指を半透明の水色で表示できる
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

CLI では Vision Pro からの接続要求が表示されたら `allow`、続けて `enable` を入力します。`deny` で拒否、`disable` で入力停止、`access` で権限設定を開き、`status` で現在の状態と受信件数を確認できます。`apps` で起動中のアプリと Bundle ID を表示し、`target com.apple.TextEdit` のようにキーの送信先を固定できます。対象アプリで入力欄を一度選んでください。`target off` で通常の前面アプリ宛てに戻します。Vision 側にも Mac の入力可否と送信先を通知します。終了は `quit` です。macOS のアクセシビリティ許可は CLI 起動元のターミナルまたは CLI に対して引き続き必要です。CLI 化だけではネットワーク切断や visionOS の表示制限は解消しません。

机を自動検出する方式を試す場合は、Vision Pro の開発者設定で Mac 仮想ディスプレイの没入空間表示を有効にします。「机上表示を開始」を押し、必要に応じて左右・前後・回転・接触判定を調整してください。

手元で純粋な判定ロジックを検証するには:

```sh
swiftc Shared/DeskProtocol.swift Shared/DeskLayout.swift Tests/DeskLayoutTests.swift -o /tmp/deskbridge-tests
/tmp/deskbridge-tests
```

## 現在の制限

Mac 内でキーボード／マウスをソフトウェアで偽装する案と、DeskBridge 内に他アプリを表示する案は [入力と表示の設計](docs/HID_ARCHITECTURE.md) にまとめています。現在の公開版は `CGEvent` 経路で、仮想HIDとリモート作業空間は未実装です。

共有空間モードは実物のキーボードをカメラで認識・採寸したり、指先の接近座標や手全体の骨格を取得したりできません。サイズは種類別の初期値から手動調整します。青いバーは表示専用の目安とローカルの送信キー履歴で、Mac のアプリに確定した文字や日本語変換結果を読み取るものではありません。目印を見るだけでキー位置を検出するものでもありません。直接タッチ設定は視線とピンチによるキーの誤選択を防ぎますが、visionOS がボリューム自体へフォーカスを移す動作を完全には制御できません。Mac の送信先固定は、この影響を Mac のキー入力経路で軽減するためのものです。キーボードを見ない打鍵が安定して成立するかは実機での検証が必要です。visionOS の標準入力は最大で左右各1点の接触を報告するため、全指での高速なブラインドタッチを保証しません。

手追跡モードは指先と机の位置を取得でき、F/J の上方に指が来た時に音を鳴らし、追跡された手の骨格を水色で描けます。ただし Full Space での ARKit が必要で、通常の共有空間ではこの手の描画を有効にできません。Mac 仮想ディスプレイとの同時利用には Apple の開発者設定が必要です。Apple Watch への振動は Vision Pro から WatchConnectivity で直接送れません。実装には iPhone 中継アプリと watchOS アプリが別途必要です。

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
