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
        .defaultSize(width: 700, height: 800)

        Window("入力面", id: "DeskSurface") {
            SharedDeskView(bridge: bridge)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.72, height: 0.12, depth: 0.20, in: .meters)
        .volumeWorldAlignment(.gravityAligned)
        .restorationBehavior(.automatic)
        .defaultLaunchBehavior(.presented)

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
    @AppStorage("deskProfile") private var profileRaw = DeskKeyboardProfile.macBook.rawValue
    @AppStorage("deskWidthMacBook") private var macBookWidth = 0.30
    @AppStorage("deskWidthCompact") private var compactWidth = 0.29
    @AppStorage("deskWidthFull") private var fullWidth = 0.42
    @AppStorage("deskDepthMacBook") private var macBookDepth = 0.115
    @AppStorage("deskDepthCompact") private var compactDepth = 0.12
    @AppStorage("deskDepthFull") private var fullDepth = 0.14
    @AppStorage("deskTypingMode") private var typingMode = false
    @AppStorage("deskShowTouchZones") private var showTouchZones = false
    @AppStorage("deskHomeCues") private var homeCues = true

    private var selectedProfile: DeskKeyboardProfile {
        DeskKeyboardProfile(rawValue: profileRaw) ?? .macBook
    }

    private var selectedWidth: Double {
        switch selectedProfile {
        case .macBook: macBookWidth
        case .compactExternal: compactWidth
        case .fullExternal: fullWidth
        }
    }

    private var selectedDepth: Double {
        switch selectedProfile {
        case .macBook: macBookDepth
        case .compactExternal: compactDepth
        case .fullExternal: fullDepth
        }
    }

    private var selectedWidthBinding: Binding<Double> {
        Binding(get: { selectedWidth }, set: { newWidth in
            switch selectedProfile {
            case .macBook: macBookWidth = newWidth
            case .compactExternal: compactWidth = newWidth
            case .fullExternal: fullWidth = newWidth
            }
        })
    }

    private var selectedDepthBinding: Binding<Double> {
        Binding(get: { selectedDepth }, set: { newDepth in
            switch selectedProfile {
            case .macBook: macBookDepth = newDepth
            case .compactExternal: compactDepth = newDepth
            case .fullExternal: fullDepth = newDepth
            }
        })
    }

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
                        Text(bridge.macInputStatus)
                            .font(.caption)
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

                GroupBox("2. 実物に合わせてサイズを決める") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("基準にするキーボード", selection: $profileRaw) {
                            ForEach(DeskKeyboardProfile.allCases) { profile in
                                Text(profile.title).tag(profile.rawValue)
                            }
                        }
                        LabeledContent("仮想キーボードの幅",
                                       value: String(format: "%.1f cm", selectedWidth * 100))
                        Slider(value: selectedWidthBinding, in: selectedProfile.widthRange,
                               step: 0.005)
                        LabeledContent("仮想キーボードの奥行き",
                                       value: String(format: "%.1f cm", selectedDepth * 100))
                        Slider(value: selectedDepthBinding, in: selectedProfile.depthRange,
                               step: 0.005)
                        Button("この種類の大きさを初期値に戻す") {
                            selectedWidthBinding.wrappedValue = selectedProfile.defaultWidth
                            selectedDepthBinding.wrappedValue = selectedProfile.defaultDepth
                        }
                        Text("実物の上に仮想キーボードを重ね、幅と奥行きを合わせます。実物は採寸の目安だけに使います。キー配列は現在 ANSI です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("3. 共有空間の入力面") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mac仮想ディスプレイと同時に使えます。開発者モードは不要です。")
                        Button("入力面を表示・呼び出す") {
                            openWindow(id: "DeskSurface")
                        }
                        .buttonStyle(.borderedProminent)
                        Button("入力面を閉じる") { dismissWindow(id: "DeskSurface") }
                        Button(typingMode ? "配置を調整する（入力停止）" : "配置を決定して入力開始") {
                            typingMode.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        Text(typingMode
                             ? "入力中: 青いバーは表示専用です。キーとトラックパッドは直接触れた時だけ反応します。"
                             : "配置中: 入力は停止しています。幅と奥行きを合わせ、机へ動かしてから入力を開始してください。")
                            .font(.caption)
                        Toggle("接触判定の位置を水色で表示", isOn: $showTouchZones)
                        Toggle("F・J の音を鳴らす", isOn: $homeCues)
                        HStack {
                            Button("F の音を確認") { HomeKeyCuePlayer.shared.play(.f) }
                            Button("J の音を確認") { HomeKeyCuePlayer.shared.play(.j) }
                        }
                        Text("最後に認識したキー: \(bridge.lastRecognizedKey)")
                            .font(.caption.monospaced())
                        Text("Mac への送信: \(bridge.lastKeySendStatus)")
                            .font(.caption.monospaced())
                        Text("青い目印を視野に置き、実物に重ねてサイズを合わせたら、移動ハンドルで仮想キーボードを机へ動かします。配置メニューで机に固定し、上のボタンで入力を開始してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("共有空間では指の接近座標を取得できません。F・J の音はキーが入力として認識された時に鳴ります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("4. 机の自動検出モード（開発者向け）") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(desk.status)
                        Toggle("追跡した手を水色で表示", isOn: $desk.showHandOverlay)
                        Button(isOpen ? "机上表示を終了" : "机上表示を開始") {
                            Task {
                                if isOpen {
                                    await dismissImmersiveSpace()
                                    isOpen = false
                                } else {
                                    desk.keyboardWidth = Float(selectedWidth)
                                    desk.keyboardDepth = Float(selectedDepth)
                                    desk.homeCuesEnabled = homeCues
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
                        Text("F・J に人差し指が近づいた時の音: \(desk.lastHomeCue)")
                            .font(.caption)
                        Text("水色の手は Full Space の手追跡モードでのみ表示できます。共有空間では手全体の形状を取得できません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("5. Mac仮想ディスプレイ") {
                    Text("Vision Pro の開発者設定で「Mac Virtual Display in Immersive Experiences」を有効にし、コントロールセンターから Mac 仮想ディスプレイを接続します。一般向けの通常設定では同時表示できません。")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("入力精度は机の材質・照明・手の追跡状態で変わります。パスワード入力には使用しないでください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(26)
        }
        .onChange(of: selectedWidth) { _, newWidth in
            desk.keyboardWidth = Float(newWidth)
        }
        .onChange(of: selectedDepth) { _, newDepth in
            desk.keyboardDepth = Float(newDepth)
        }
        .onChange(of: homeCues) { _, enabled in
            desk.homeCuesEnabled = enabled
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
