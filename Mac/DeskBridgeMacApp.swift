import AppKit
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
                LabeledContent("キーの送信先", value: bridge.targetApplicationName ?? "Mac の前面アプリ")
                HStack {
                    Menu("キーの送信先を選ぶ") {
                        ForEach(NSWorkspace.shared.runningApplications
                            .filter { !$0.isTerminated && $0.activationPolicy == .regular &&
                                $0.bundleIdentifier != nil }
                            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") },
                                id: \.processIdentifier) { app in
                            Button("\(app.localizedName ?? "不明") (\(app.bundleIdentifier ?? ""))") {
                                if let id = app.bundleIdentifier { bridge.selectTarget(bundleID: id) }
                            }
                        }
                    }
                    Button("固定を解除") { bridge.clearTarget() }
                        .disabled(bridge.targetApplicationName == nil)
                }

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
                Text("送信先を固定する場合は、その Mac アプリで入力欄を一度選んでください。入力中は macOS の現在の入力ソースが使われます。キー配置は ANSI 英語配列です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(minWidth: 590, minHeight: 340)
            .onAppear { bridge.refreshAccessibility() }
        }
    }
}
