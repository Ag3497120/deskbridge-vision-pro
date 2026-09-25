import Foundation
import MultipeerConnectivity

final class VisionBridge: NSObject, ObservableObject {
    @Published private(set) var peers: [MCPeerID] = []
    @Published private(set) var status = "近くの Mac を検索中"
    @Published private(set) var isConnected = false

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

    func send(_ event: InputEvent) {
        guard isConnected, let data = try? JSONEncoder().encode(event) else { return }
        let mode: MCSessionSendDataMode = event.kind == .pointer ? .unreliable : .reliable
        do {
            try session.send(data, toPeers: session.connectedPeers, with: mode)
        } catch {
            status = "送信エラー: \(error.localizedDescription)"
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
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
