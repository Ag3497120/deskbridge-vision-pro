import AppKit
import Combine
import Foundation

/// Interactive Mac-side companion. It uses the same encrypted connection and
/// input handler as the windowed app, but can be built and run from a terminal.
let bridge = MacBridge()
var subscriptions = Set<AnyCancellable>()

func printStatus() {
    print("接続: \(bridge.status) / アクセシビリティ: \(bridge.accessibilityAllowed ? "許可済み" : "未許可") / 入力: \(bridge.inputEnabled ? "有効" : "停止") / 送信先: \(bridge.targetApplicationName ?? "Mac の前面アプリ") / 受信: \(bridge.receivedInputCount) 件")
}

bridge.$status.removeDuplicates().sink { status in
    print("接続: \(status)")
}.store(in: &subscriptions)

bridge.$pendingPeer.removeDuplicates().sink { peer in
    if let peer {
        print("接続要求: \(peer) — 許可する場合は allow、拒否する場合は deny")
    }
}.store(in: &subscriptions)

bridge.$accessibilityAllowed.removeDuplicates().sink { allowed in
    print("アクセシビリティ: \(allowed ? "許可済み" : "未許可")")
}.store(in: &subscriptions)

bridge.$receivedInputCount.removeDuplicates().sink { count in
    if count > 0 && (count <= 3 || count % 25 == 0) {
        print("Vision Pro からの入力を受信: \(count) 件")
    }
}.store(in: &subscriptions)

print("DeskBridge CLI を開始しました。help で操作を表示します。")

DispatchQueue.global(qos: .userInitiated).async {
    while let line = readLine() {
        let command = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        DispatchQueue.main.async {
            if command == "apps" {
                let apps = NSWorkspace.shared.runningApplications
                    .filter { !$0.isTerminated && $0.activationPolicy == .regular &&
                        $0.bundleIdentifier != nil }
                    .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
                for app in apps {
                    print("\(app.localizedName ?? "不明"): \(app.bundleIdentifier ?? "")")
                }
                return
            }
            if command.hasPrefix("target ") {
                let bundleID = String(command.dropFirst("target ".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if bundleID == "off" {
                    bridge.clearTarget()
                    printStatus()
                } else if bridge.selectTarget(bundleID: bundleID) {
                    printStatus()
                } else {
                    print("その Bundle ID の起動中アプリが見つかりません。apps で確認してください。")
                }
                return
            }
            switch command {
            case "allow":
                if bridge.pendingPeer != nil { bridge.acceptInvitation() }
                else { print("保留中の接続要求はありません。") }
            case "deny":
                if bridge.pendingPeer != nil { bridge.rejectInvitation() }
                else { print("保留中の接続要求はありません。") }
            case "access":
                bridge.requestAccessibility()
                printStatus()
            case "enable":
                bridge.setInputEnabled(true)
                printStatus()
            case "disable":
                bridge.setInputEnabled(false)
                printStatus()
            case "status":
                bridge.refreshAccessibility()
                printStatus()
            case "help":
                print("allow / deny: Vision Pro の接続要求を処理")
                print("access: アクセシビリティ権限の設定を開く")
                print("enable / disable: 入力の有効化・停止")
                print("apps: 起動中の Mac アプリを表示")
                print("target <Bundle ID>: キーの送信先を固定、target off: 固定解除")
                print("status: 現在の状態を表示、quit: 終了")
            case "quit", "exit":
                bridge.setInputEnabled(false)
                exit(EXIT_SUCCESS)
            case "":
                break
            default:
                print("不明なコマンドです。help を入力してください。")
            }
        }
    }
    DispatchQueue.main.async {
        bridge.setInputEnabled(false)
        exit(EXIT_SUCCESS)
    }
}

RunLoop.main.run()
