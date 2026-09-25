import RealityKit
import SwiftUI

@main
struct DeskBridgeVisionApp: App {
    @StateObject private var bridge = VisionBridge()
    @StateObject private var desk = DeskSceneModel()

    var body: some SwiftUI.Scene {
        WindowGroup {
            VisionControls(bridge: bridge, desk: desk)
                .onAppear {
                    desk.onInput = { [weak bridge] event in bridge?.send(event) }
                }
        }
        .defaultSize(width: 660, height: 690)

        WindowGroup(id: "SharedDesk") {
            SharedDeskView(bridge: bridge)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.96, height: 0.08, depth: 0.29, in: .meters)

        ImmersiveSpace(id: "DeskSpace") {
            DeskImmersiveView(desk: desk)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

private struct VisionControls: View {
    @ObservedObject var bridge: VisionBridge
    @ObservedObject var desk: DeskSceneModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var isOpen = false
    @State private var isSharedOpen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("DeskBridge")
                    .font(.largeTitle.bold())
                Text("机を仮想キーボードとトラックパッドに。Mac仮想ディスプレイと組み合わせて使います。")
                    .foregroundStyle(.secondary)

                GroupBox("1. Mac に接続") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(bridge.status)
                        if bridge.peers.isEmpty {
                            Text("Mac アプリを起動するとここに表示されます。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(bridge.peers, id: \.self) { peer in
                            Button("\(peer.displayName) に接続") { bridge.connect(to: peer) }
                                .disabled(bridge.isConnected)
                        }
                        Text("Mac 側で接続を許可し、アクセシビリティ権限と入力を有効にしてください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("2. 共有空間モード（推奨）") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mac仮想ディスプレイと同時に使えます。開発者モードは不要です。")
                        Button(isSharedOpen ? "共有空間の入力面を閉じる" : "共有空間に入力面を表示") {
                            if isSharedOpen {
                                dismissWindow(id: "SharedDesk")
                            } else {
                                openWindow(id: "SharedDesk")
                            }
                            isSharedOpen.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        Text("表示後、ボリュームの移動ハンドルで机上に置きます。キーをタップし、トラックパッドをドラッグします。机は自動検出しません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("3. 机の自動検出モード（開発者向け）") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(desk.status)
                        Button(isOpen ? "机上表示を終了" : "机上表示を開始") {
                            Task {
                                if isOpen {
                                    await dismissImmersiveSpace()
                                    isOpen = false
                                } else {
                                    let result = await openImmersiveSpace(id: "DeskSpace")
                                    if case .opened = result { isOpen = true }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("机を再検出") { desk.recenter() }
                            .disabled(!isOpen)
                        LabeledContent("左右", value: "\(Int(desk.offsetX * 100)) cm")
                        Slider(value: $desk.offsetX, in: -0.25...0.25)
                        LabeledContent("前後", value: "\(Int(desk.offsetZ * 100)) cm")
                        Slider(value: $desk.offsetZ, in: -0.20...0.20)
                        LabeledContent("回転", value: "\(Int(desk.rotationDegrees))°")
                        Slider(value: $desk.rotationDegrees, in: -35...35)
                        LabeledContent("接触判定", value: "\(Int(desk.touchHeight * 1000)) mm")
                        Slider(value: $desk.touchHeight, in: 0.005...0.040)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("4. Mac仮想ディスプレイ") {
                    Text("Vision Pro の開発者設定で「Mac Virtual Display in Immersive Experiences」を有効にし、コントロールセンターから Mac 仮想ディスプレイを接続します。一般向けの通常設定では同時表示できません。")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("入力精度は机の材質・照明・手の追跡状態で変わります。パスワード入力には使用しないでください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(26)
        }
    }
}

private struct DeskImmersiveView: View {
    @ObservedObject var desk: DeskSceneModel

    var body: some View {
        RealityView { content in
            content.add(desk.root)
            await desk.start()
        }
        .onDisappear { desk.stop() }
    }
}
