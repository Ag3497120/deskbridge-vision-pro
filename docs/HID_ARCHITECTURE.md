# 入力機器の偽装とアプリ表示の設計

DeskBridge の現行版は、Vision Pro の机上ボリュームで発生した入力を暗号化したローカル接続で Mac アプリに送り、Mac アプリが `CGEvent` で macOS に入力する。この経路で Mac 仮想ディスプレイ、Mac 上の通常アプリ、Mac 上のリモートデスクトップクライアントを操作する構成になっている。以下は、ソフトウェアで機器を偽装する案と、DeskBridge を visionOS 上の操作レイヤーにする案の成立条件。

## ソフトウェアでキーボード／マウスを偽装する

```text
机上入力 → Vision Pro アプリ → 暗号化したローカル接続
         → Mac アプリ → macOS の仮想HID機器 → 入力先アプリ
```

Apple の macOS `CoreHID.HIDVirtualDevice` は、ソフトウェアで作った HID キーボード／マウスのレポートを OS に送れる。この方式に追加の BLE 機器は要らない。ただし `com.apple.developer.hid.virtual.device` 権限が必要で、配布には Apple による権限付与と署名の確認が必要。手元の Xcode 26 では CoreHID は macOS SDK にあり、visionOS SDK にはない。権限のないローカルプローブで Apple の例と同じキーボード記述子から仮想機器を作ると、生成に失敗した。

これは **Mac の中で HID 機器を偽装する方式**。Mac の Bluetooth 設定に Vision Pro が現れ、無線でペアリングされる方式ではない。Vision Pro 自身が BLE HID の広告・ペアリングを行うには周辺機器機能が要るが、visionOS の公開 `CBPeripheralManager` では広告できない。HID のバイト列だけを送っても Bluetooth の接続にはならない。

Apple は Mac 仮想ディスプレイ中、Mac のキーボード／トラックパッドなどで visionOS アプリも操作できると説明している。したがって **Mac の仮想HID機器が visionOS アプリへの入力共有にも乗る可能性がある**。仮想機器も転送対象になるか、DeskBridge ボリュームを触った直後に目的のアプリが入力先であり続けるかは、Vision Pro 実機での確認が必要。Mac 仮想ディスプレイを接続していない場合、この Mac 経路から visionOS アプリを操作できるとは言えない。

## DeskBridge を visionOS 全体のシールドにする

```text
希望する形: DeskBridge が全アプリの画面を内包し、
            入力を一括で受け取って各アプリに転送する
```

**公開 visionOS API では、既存の任意のネイティブアプリを DeskBridge 内で動かすことはできない。** アプリのウィンドウはそのアプリのシーンであり、OS が複数アプリのシーンを合成する。操作も OS が対象シーンを所有するアプリへ配送する。DeskBridge のウィンドウやボリュームを他アプリと並べて表示することはできるが、他アプリのウィンドウを子画面として取り込んだり、全アプリの入力を横取りして再配送したりする公開経路はない。DeskBridge が没入空間を開くと、通常は他アプリのウィンドウが隠れる。

一方、**遠隔のアプリ画面を DeskBridge 内へ表示する「リモート作業空間」**は構築できる。Mac 側でアプリ画面を配信し、DeskBridge がそれを表示して、机上入力を Mac に戻す。RDP／VNC などのリモート接続を DeskBridge 自身へ統合する方法もある。これは Mac やリモートホストで動くアプリの映像と入力を扱う方式で、Vision Pro にインストール済みの他社ネイティブアプリを再実行する方式ではない。

## 入力先ごとの見通し

| 入力先 | 現実的な経路 | 未検証・制約 |
| --- | --- | --- |
| Mac 仮想ディスプレイと Mac 上のアプリ | 現行の `CGEvent`。仮想HIDへの切り替えも可能性あり | 現行版も Vision Pro 実機での入力確認が必要。仮想HIDには権限が要る。 |
| Mac 上のリモートデスクトップクライアント | Mac へ入力し、クライアントがリモートホストへ転送 | クライアント側の入力転送設定に依存する。 |
| Vision Pro 上の他社アプリ | Mac 仮想ディスプレイ中の入力共有を仮想HID経由で使う案 | 仮想HIDの共有対象判定とフォーカスを実機で確認する。 |
| DeskBridge 内で動くリモート作業空間 | Mac の画面配信、または DeskBridge にリモート接続を統合 | 接続先と表示方式ごとの実装が必要。 |
| DeskBridge 内で動く任意の visionOS ネイティブアプリ | 公開 API に経路なし | OS のアプリ・シーン・入力配送の境界を越える。 |

共有空間のボリュームなら通常時に他アプリと並べて表示できる。ただし現行の入力検出は visionOS 標準のタップ／ドラッグで、写真のような全指の打鍵とは異なる。没入空間でしか得られない ARKit の指先・机の生データを、シールド構成で通常時に取得できるようにはならない。

## 次に確認する順序

1. Vision Pro 実機で、現行の共有空間ボリュームと Mac 仮想ディスプレイを同時に操作する。
2. Mac の仮想HID権限を取得できるか確認し、権限がある環境で仮想キーボード／マウスの入力を試作する。
3. Mac 仮想ディスプレイから visionOS の他アプリへ、その仮想HID入力が共有されるか測る。
4. アプリを DeskBridge 内へ集約したい場合は、まず Mac 画面を DeskBridge 内に表示するリモート作業空間を別機能として実装する。

## 参照

- [Apple: CoreHID 仮想デバイスの作成](https://developer.apple.com/documentation/corehid/creatingvirtualdevices) — macOS 上のソフトウェア HID 機器。
- [Apple: 仮想HID権限](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.hid.virtual.device) — 仮想機器を作るアプリの権限。
- [Apple: Mac と Vision Pro の入力共有](https://support.apple.com/en-au/118521) — Mac 仮想ディスプレイ中に Mac 入力機器で visionOS アプリを操作できる。
- [Apple: CBPeripheralManager](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager) — visionOS は周辺機器サービスを広告できない。
- [Apple: visionOS のシーン](https://developer.apple.com/documentation/visionos/presenting-windows-and-spaces) — アプリ自身のシーンと没入空間の挙動。
- [Apple: visionOS の描画と入力配送](https://developer.apple.com/documentation/visionos/understanding-the-visionos-render-pipeline) — OS がシーンを合成し、所有アプリへ入力を渡す。
