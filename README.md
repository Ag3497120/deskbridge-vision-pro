# DeskBridge

Apple Vision Pro のパススルー空間で、机上に仮想キーボードとトラックパッドを表示し、Mac を操作する実験的なアプリです。Meta VR Glasses の紹介動画にある机上入力を参考にしています。Meta の製品・ソフトウェアとは無関係です。

通常の Mac 仮想ディスプレイと並べて使える**共有空間モード**を主な方式とします。利用者が机上にボリュームを配置し、visionOS 標準のタップとドラッグを入力として使います。**机の自動検出モード**は ARKit の手・平面追跡を使い、開発者設定が必要です。

## できること

- 共有空間モードでは、ボリュームを机上に手動配置し、標準の直接タップとドラッグで入力
- 自動検出モードでは、ARKit で机と指先を追跡し、接触時にキー入力、トラックパッドの移動・クリック・ドラッグ・スクロールを判定
- Multipeer Connectivity の暗号化接続で Mac に入力を送信
- Mac 側の接続承認とアクセシビリティ権限、入力の有効化を必須にする
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
5. 共有空間モードのボタンで入力面を表示し、ボリュームの移動ハンドルで机上に配置します。キーをタップし、トラックパッドをドラッグします。
6. コントロールセンターから通常どおり Mac 仮想ディスプレイを接続します。

机を自動検出する方式を試す場合は、Vision Pro の開発者設定で Mac 仮想ディスプレイの没入空間表示を有効にします。「机上表示を開始」を押し、必要に応じて左右・前後・回転・接触判定を調整してください。

手元で純粋な判定ロジックを検証するには:

```sh
swiftc Shared/DeskProtocol.swift Shared/DeskLayout.swift Tests/DeskLayoutTests.swift -o /tmp/deskbridge-tests
/tmp/deskbridge-tests
```

## 現在の制限

共有空間モードは机の自動認識・指先座標の直接取得を行えません。標準ジェスチャーを使うため、写真のような全指での物理キーボードに近い打鍵は期待できず、キーごとのタップになります。自動検出モードは机と指先の座標を得られますが、Mac 仮想ディスプレイとの同時利用には Apple の開発者設定が必要です。この制限をアプリが解除するものではありません。

キー配置は ANSI 英語配列で、Shift・Command・Option・Control は一度押すと次のキー一回だけに適用されます。共有空間モードのトラックパッドはドラッグでポインタ移動、タップで左クリックです。自動検出モードは一指の移動・短いタップのクリック・長押し後のドラッグ・二指スクロールに対応します。物理的な打鍵感はありません。精度と遅延は実機での評価が必要です。パスワードや機密情報の入力には使用しないでください。

Mac 側は画面を取得・送信しません。接続は暗号化されますが、Mac 側の入力を有効化した状態で接続相手を常に確認してください。

## 根拠資料

- [Meta VR Glasses 製品ページ](https://www.meta.com/jp/vr-glasses/) — 机上入力の動画と製品紹介
- [Apple: visionOS Group Lab (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/8004/) — 開発者設定で没入空間内の Mac 仮想ディスプレイを使用できる旨
- [Apple: Setting up access to ARKit data](https://developer.apple.com/documentation/visionos/setting-up-access-to-arkit-data) — 手・机の追跡には Full Space と権限が必要
- [Apple: Immersive spaces](https://developer.apple.com/documentation/swiftui/immersive-spaces) — 通常の没入空間では他アプリのウィンドウが非表示
- [Apple: visionOS のアプリ](https://developer.apple.com/visionos/) — 共有空間のボリュームと他アプリの並列表示
- [Apple: Adding 3D content](https://developer.apple.com/documentation/visionos/adding-3d-content-to-your-app) — ボリューム内のエンティティに標準ジェスチャーを適用
- [Apple: Local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) — Bonjour とローカルネットワーク権限
