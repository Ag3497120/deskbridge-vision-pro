# 入力先を増やすための設計

DeskBridge の机上入力は、入力を検出する部分と入力先を分けて考える。現在の公開版は、Vision Pro アプリから暗号化したローカル接続で Mac アプリへ送り、Mac アプリが macOS の入力イベントを発行する。この経路は Mac 仮想ディスプレイだけでなく、その Mac 上で動く通常のアプリやリモートデスクトップクライアントにも使える。

## Bluetooth HID 経路

```text
机上のキー／ポインタ操作
    → Vision Pro の DeskBridge アプリ（共有空間のボリューム）
    → 認証済みのローカル接続
    → 外付け BLE HID ブリッジ
    → Bluetooth キーボード＋マウスとしてペアリングした入力先
```

Vision Pro アプリ単体を Bluetooth キーボードとして Mac にペアリングする方式は採れない。visionOS の公開 Core Bluetooth API は、アプリが周辺機器としてサービスを広告する機能を提供しない。Mac に「Bluetooth 入力機器」として認識させるなら、BLE HID を広告する外付け機器が必要になる。

ESP32-S3 はブリッジの候補で、Espressif の公式サンプルに BLE HID デバイスがあり、Wi-Fi と BLE の同時利用もサポートされる。ただし DeskBridge のファームウェア、ペアリング手順、遅延、Vision Pro と Mac への接続互換性は未実装・未検証。現段階で特定の基板を購入しても、完成品として動くことは保証できない。

標準 HID の最初の目標はキー入力、相対ポインタ移動、クリック、ドラッグ、ホイールスクロール。写真のような面を描画するのは Vision Pro アプリの役割であり、BLE HID ブリッジが机や指を検出するわけではない。Magic Trackpad と同じ複数指ジェスチャーは、この標準マウス経路の対象外。

## 入力先ごとの成立条件

| 入力先 | 実現経路 | 通常の共有空間 | 条件・未検証点 |
| --- | --- | --- | --- |
| Mac 仮想ディスプレイ | 現在の Mac アプリ、または将来の BLE HID ブリッジを Mac にペアリング | 可 | 現在の Mac アプリ経路も実機での入力検証が必要。 |
| Mac 上の通常のアプリ／リモートデスクトップクライアント | 同上 | 可 | Mac 側で前面・入力先になっているアプリに届く。リモートデスクトップ側が入力を転送する設定も必要。 |
| Vision Pro 上の他社リモートデスクトップアプリ | ブリッジを Vision Pro にペアリングする案、またはリモートホストを直接操作する案 | 一部可能性あり | 他社アプリへ DeskBridge が直接イベントを送る公開 API はない。Vision Pro にペアリングした場合、机上ボリュームに触れた後のフォーカス先を実機で確認する必要がある。ホストへ直接 BLE 接続する案は、ホストがブリッジの Bluetooth 圏内にある場合に限る。 |
| Vision Pro 上の通常の他社アプリ | ブリッジを Vision Pro にペアリングする案 | 一部可能性あり | OS が現在フォーカスしているアプリへ HID 入力を配送する。DeskBridge のボリュームへのタップがフォーカスを移す可能性があり、任意のアプリへの透過的入力は保証できない。 |

Bluetooth HID は入力先の OS へイベントを入れる仕組みで、他社アプリのフォーカスを指定する仕組みではない。離れたクラウドのリモートホストにも BLE 電波だけでは届かない。この二点が「どのリモートデスクトップにも同じ机上入力を送る」という要求の境界になる。

## アプリと機器の分担

1. **Vision Pro アプリ**: 共有空間に机上面を表示し、標準の直接タップ／ドラッグを入力イベントに変える。机・指先の生データを使う自動検出は引き続き没入空間の機能。
2. **Mac アプリ**: 現在のソフトウェア経路。Mac 側の接続承認とアクセシビリティ許可を受けて、Mac 全体に入力する。BLE HID 経路を使う場合は必須ではない。
3. **外付け BLE HID ブリッジ**: 将来の追加経路。Vision Pro から受けたイベントを標準キーボード／マウスの HID レポートへ変換し、明示的にペアリングした一台の入力先へ送る。

任意の visionOS アプリでそのアプリのフォーカスを保ったまま机の打鍵を検出するには、DeskBridge ボリュームへのタップに依存しない独立した物理センサーなど、別の入力検出手段が必要になる可能性が高い。BLE ブリッジだけを足しても Vision Pro の手追跡 API の制約は変わらない。

## 実装前の検証順

1. 実機で現在の共有空間ボリュームと Mac 仮想ディスプレイの同時表示・入力を測る。
2. BLE HID 試作機を Mac にペアリングし、キー、ポインタ、クリック、スクロールを確認する。
3. Vision Pro アプリから認証したローカル接続で試作機を操作し、切断時に押下中のキー／ボタンを解放する。
4. 同じ試作機を Vision Pro にペアリングし、DeskBridge ボリュームを触った直後に他社アプリへ入力が届くかを調べる。
5. 結果に応じ、visionOS アプリ向けの独立センサー、または対応するリモートデスクトップを DeskBridge 内へ統合する方式を判断する。

## 参照

- [Apple: CBPeripheralManager](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager) — visionOS で周辺機器サービスを広告できない。
- [Apple: visionOS render pipeline](https://developer.apple.com/documentation/visionos/understanding-the-visionos-render-pipeline) — OS が操作対象のシーンを所有するアプリへ入力を配送する。
- [Apple: visionOS Get Started](https://developer.apple.com/visionos/get-started/) — 接続したキーボード・ポインティングデバイスの入力配送。
- [Apple: visionOS app availability](https://developer.apple.com/documentation/visionos/determining-whether-to-bring-your-app-to-visionos) — visionOS ではキーボード拡張・ドライバー拡張をロードしない。
- [Apple: Vision Pro Bluetooth accessories](https://support.apple.com/guide/apple-vision-pro/connect-bluetooth-accessories-tanaa651a58d/27/visionos/27) — キーボード／マウスの接続。
- [Espressif: ESP-IDF BLE HID example](https://github.com/espressif/esp-idf/tree/v5.5.1/examples/bluetooth/esp_hid_device) — BLE HID デバイスの実装例。
- [Espressif: ESP32-S3 Wi-Fi/BLE coexistence](https://docs.espressif.com/projects/esp-idf/en/v5.1/esp32s3/api-guides/coexist.html) — 同時利用の条件。
