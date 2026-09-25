import Foundation
import MultipeerConnectivity

final class VisionBridge: NSObject, ObservableObject {
    @Published private(set) var peers: [MCPeerID] = []
    @Published private(set) var status = "近くの Mac を検索中"
    @Published private(set) var isConnected = false
    @Published private(set) var lastRecognizedKey = "—"
    @Published private(set) var lastKeySendStatus = "—"
    @Published private(set) var inputPreview = ""
    @Published private(set) var macInputStatus = "Mac の入力状態を取得していません"

    private let peerID = MCPeerID(displayName: "Vision Pro")
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!

    override init() {
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "deskbridge")
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    deinit {
        browser?.stopBrowsingForPeers()
        session?.disconnect()
    }

    func connect(to peer: MCPeerID) {
        guard !isConnected else { return }
        status = "\(peer.displayName) の許可を待っています"
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func noteRecognizedKey(_ key: DeskKey, shift: Bool) {
        lastRecognizedKey = key.label
        if DeskLayout.normalizedModifier(key.keyCode) != nil { return }
        switch key.keyCode {
        case 51: // Delete.
            if !inputPreview.isEmpty { inputPreview.removeLast() }
        case 49: inputPreview.append(" ")
        case 36: inputPreview.append("↵")
        default:
            if key.label.count == 1 {
                inputPreview.append(shift ? (key.shiftedLabel ?? key.label) : key.label.lowercased())
            } else {
                inputPreview.append("〔\(key.label)〕")
            }
        }
        inputPreview = String(inputPreview.suffix(20))
    }

    func send(_ event: InputEvent) {
        guard isConnected, let data = try? JSONEncoder().encode(event) else {
            if event.kind == .key { lastKeySendStatus = "未接続のため送信できません" }
            return
        }
        let mode: MCSessionSendDataMode = event.kind == .pointer ? .unreliable : .reliable
        do {
            try session.send(data, toPeers: session.connectedPeers, with: mode)
            if event.kind == .key { lastKeySendStatus = "送信しました" }
        } catch {
            status = "送信エラー: \(error.localizedDescription)"
            if event.kind == .key { lastKeySendStatus = "送信エラー" }
        }
    }
}

extension VisionBridge: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.peers.contains(peerID) { self.peers.append(peerID) }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.peers.removeAll { $0 == peerID } }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.status = "検索エラー: \(error.localizedDescription)" }
    }
}

extension VisionBridge: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isConnected = state == .connected
            self.status = state == .connected ? "\(peerID.displayName) に接続" : "近くの Mac を検索中"
            if state != .connected {
                self.lastKeySendStatus = "未接続"
                self.macInputStatus = "Mac に未接続"
            } else {
                self.macInputStatus = "Mac の入力状態を確認中"
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(MacInputStatus.self, from: data),
              message.version == 1, message.type == "macInputStatus" else { return }
        DispatchQueue.main.async {
            if !message.accessibilityAllowed {
                self.macInputStatus = "Mac のアクセシビリティ権限が必要"
            } else if !message.inputEnabled {
                self.macInputStatus = "Mac CLI で enable が必要"
            } else {
                self.macInputStatus = message.targetName.map {
                    "Mac の入力は有効・送信先: \($0)"
                } ?? "Mac の入力は有効・送信先: Mac の前面アプリ"
            }
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
