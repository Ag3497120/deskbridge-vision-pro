import SwiftUI

@main
struct DeskBridgeMacApp: App {
    @StateObject private var bridge = MacBridge()

    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 18) {
                Text("DeskBridge for Mac")
                    .font(.largeTitle.bold())
                Text("Apple Vision Pro の机上キーボードとトラックパッドから、この Mac を操作します。")
                    .foregroundStyle(.secondary)

                LabeledContent("接続", value: bridge.status)
                LabeledContent("アクセシビリティ", value: bridge.accessibilityAllowed ? "許可済み" : "未許可")

                if let peer = bridge.pendingPeer {
                    HStack {
                        Text("接続を許可: \(peer)")
                        Spacer()
                        Button("拒否") { bridge.rejectInvitation() }
                        Button("許可") { bridge.acceptInvitation() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Button("アクセシビリティ権限を確認") { bridge.requestAccessibility() }
                    Button(bridge.inputEnabled ? "入力を停止" : "入力を有効化") {
                        bridge.setInputEnabled(!bridge.inputEnabled)
                    }
                    .disabled(!bridge.accessibilityAllowed || !bridge.isConnected)
                    .buttonStyle(.borderedProminent)
                }

                Text("同じローカルネットワークの Vision Pro で DeskBridge を開き、この Mac を選択してください。接続は暗号化され、Mac 側で毎回許可します。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("入力中は macOS の現在の入力ソースが使われます。現段階のキー配置は ANSI 英語配列です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(minWidth: 590, minHeight: 340)
            .onAppear { bridge.refreshAccessibility() }
        }
    }
}
