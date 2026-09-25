import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import MultipeerConnectivity

final class MacBridge: NSObject, ObservableObject {
    @Published private(set) var status = "接続待ち"
    @Published private(set) var pendingPeer: String?
    @Published private(set) var accessibilityAllowed = false
    @Published private(set) var isConnected = false
    @Published private(set) var inputEnabled = false

    private let peerID = MCPeerID(displayName: String(ProcessInfo.processInfo.hostName.prefix(30)))
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var isDragging = false

    override init() {
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "deskbridge")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        refreshAccessibility()
    }

    deinit {
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
    }

    func refreshAccessibility() {
        accessibilityAllowed = AXIsProcessTrusted()
        if !accessibilityAllowed { inputEnabled = false }
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        refreshAccessibility()
    }

    func setInputEnabled(_ enabled: Bool) {
        if !enabled { releaseDrag() }
        refreshAccessibility()
        inputEnabled = enabled && accessibilityAllowed && isConnected
    }

    func acceptInvitation() {
        invitationHandler?(true, session)
        invitationHandler = nil
        pendingPeer = nil
        status = "接続中"
    }

    func rejectInvitation() {
        invitationHandler?(false, nil)
        invitationHandler = nil
        pendingPeer = nil
        status = "接続待ち"
    }

    private func inject(_ event: InputEvent) {
        guard event.version == 1, inputEnabled, AXIsProcessTrusted() else { return }
        switch event.kind {
        case .key:
            guard let code = event.keyCode, code <= 127 else { return }
            var flags: CGEventFlags = []
            if event.shift == true { flags.insert(.maskShift) }
            if event.command == true { flags.insert(.maskCommand) }
            if event.option == true { flags.insert(.maskAlternate) }
            if event.control == true { flags.insert(.maskControl) }
            let modifiers: [(Bool, UInt16)] = [
                (event.control == true, 59), (event.option == true, 58),
                (event.shift == true, 56), (event.command == true, 55)
            ]
            for (active, modifier) in modifiers where active { postKey(modifier, down: true) }
            postKey(code, down: true, flags: flags)
            postKey(code, down: false, flags: flags)
            for (active, modifier) in modifiers.reversed() where active {
                postKey(modifier, down: false)
            }
        case .pointer:
            let dx = max(-100, min(100, event.deltaX ?? 0))
            let dy = max(-100, min(100, event.deltaY ?? 0))
            guard let location = CGEvent(source: eventSource)?.location else { return }
            let newLocation = CGPoint(x: location.x + dx, y: location.y + dy)
            CGEvent(mouseEventSource: eventSource,
                    mouseType: isDragging ? .leftMouseDragged : .mouseMoved,
                    mouseCursorPosition: newLocation, mouseButton: .left)?.post(tap: .cghidEventTap)
        case .click:
            guard let location = CGEvent(source: eventSource)?.location else { return }
            CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown,
                    mouseCursorPosition: location, mouseButton: .left)?.post(tap: .cghidEventTap)
            CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp,
                    mouseCursorPosition: location, mouseButton: .left)?.post(tap: .cghidEventTap)
        case .mouseDown:
            guard !isDragging, let location = CGEvent(source: eventSource)?.location else { return }
            isDragging = true
            CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown,
                    mouseCursorPosition: location, mouseButton: .left)?.post(tap: .cghidEventTap)
        case .mouseUp:
            releaseDrag()
        case .scroll:
            let lines = Int32(max(-10, min(10, event.deltaY ?? 0)))
            CGEvent(scrollWheelEvent2Source: eventSource, units: .line,
                    wheelCount: 1, wheel1: lines, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
        }
    }

    private func postKey(_ code: UInt16, down: Bool, flags: CGEventFlags = []) {
        let event = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }

    private func releaseDrag() {
        guard isDragging, let location = CGEvent(source: eventSource)?.location else { return }
        isDragging = false
        CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp,
                mouseCursorPosition: location, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}

extension MacBridge: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            guard self.pendingPeer == nil, !self.isConnected else {
                invitationHandler(false, nil)
                return
            }
            self.pendingPeer = peerID.displayName
            self.invitationHandler = invitationHandler
            self.status = "接続確認待ち"
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.status = "公開エラー: \(error.localizedDescription)" }
    }
}

extension MacBridge: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isConnected = state == .connected
            self.status = state == .connected ? "\(peerID.displayName) に接続" : "接続待ち"
            if state != .connected {
                self.releaseDrag()
                self.inputEnabled = false
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= 512,
              let event = try? JSONDecoder().decode(InputEvent.self, from: data) else { return }
        DispatchQueue.main.async { self.inject(event) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
