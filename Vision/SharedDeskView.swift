import RealityKit
import SwiftUI

enum DeskKeyboardProfile: String, CaseIterable, Identifiable {
    case macBook
    case compactExternal
    case fullExternal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .macBook: "MacBook 内蔵"
        case .compactExternal: "外付け・コンパクト"
        case .fullExternal: "外付け・幅広"
        }
    }

    var widthRange: ClosedRange<Double> {
        switch self {
        case .macBook: 0.25...0.36
        case .compactExternal: 0.25...0.38
        case .fullExternal: 0.36...0.46
        }
    }

    var defaultWidth: Double {
        switch self {
        case .macBook: 0.30
        case .compactExternal: 0.29
        case .fullExternal: 0.42
        }
    }

    var depthRange: ClosedRange<Double> { 0.09...0.19 }

    var defaultDepth: Double {
        switch self {
        case .macBook: 0.115
        case .compactExternal: 0.12
        case .fullExternal: 0.14
        }
    }
}

/// Shared Space version: standard direct-touch gestures work beside Mac Virtual Display.
/// Placement is performed with the system's volume handle, so no raw ARKit data is read.
struct SharedDeskView: View {
    @ObservedObject var bridge: VisionBridge
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
    @State private var modifiers: Set<UInt16> = []
    @State private var pressedKeys: Set<Int> = []
    @State private var dragActive = false
    @State private var lastDragX = 0.0
    @State private var lastDragZ = 0.0

    private var keyboardWidth: Double {
        switch DeskKeyboardProfile(rawValue: profileRaw) ?? .macBook {
        case .macBook: macBookWidth
        case .compactExternal: compactWidth
        case .fullExternal: fullWidth
        }
    }

    private var keyboardDepth: Double {
        switch DeskKeyboardProfile(rawValue: profileRaw) ?? .macBook {
        case .macBook: macBookDepth
        case .compactExternal: compactDepth
        case .fullExternal: fullDepth
        }
    }

    private var deskScale: SIMD3<Float> {
        let x = Float(keyboardWidth) / DeskLayout.keyboardWidth
        let z = Float(keyboardDepth) / DeskLayout.keyboardDepth
        return [x, (x + z) / 2, z]
    }

    var body: some View {
        RealityView { content in
            let desk = DeskVisualFactory.makeDesk(interactive: true,
                                                  directTouchOnly: true,
                                                  showTouchZones: showTouchZones)
            desk.name = "desk"
            desk.scale = deskScale
            // Keep the visible key plane close to the volume's lower face.
            desk.position.y = -0.058
            DeskVisualFactory.setTypingMode(typingMode, on: desk)
            content.add(desk)
        } update: { content in
            guard let desk = content.entities.first(where: { $0.name == "desk" }) else { return }
            desk.scale = deskScale
            DeskVisualFactory.setDirectTouchOnly(true, on: desk)
            DeskVisualFactory.setTypingMode(typingMode, on: desk)
            DeskVisualFactory.setTouchZonesVisible(showTouchZones, on: desk)
            DeskVisualFactory.updateFocusRailPreview(bridge.inputPreview, on: desk)
        }
        .onDisappear {
            pressedKeys.removeAll()
            dragActive = false
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard typingMode else { return }
                    let name = value.entity.name
                    if name == "pad" {
                        bridge.send(InputEvent(kind: .click))
                        return
                    }
                    guard name == "keyboardSurface",
                          let desk = value.entity.parent else { return }
                    let contact = value.convert(value.location3D, from: .local, to: desk)
                    guard let index = DeskLayout.keyIndex(at: [Float(contact.x),
                                                               Float(contact.y),
                                                               Float(contact.z)]) else { return }
                    let key = DeskLayout.keys[index]
                    DeskVisualFactory.pressKey(index, in: desk)
                    bridge.noteRecognizedKey(key, shift: modifiers.contains(56))
                    if homeCues && (key.label == "F" || key.label == "J") {
                        HomeKeyCuePlayer.shared.play(key.label == "F" ? .f : .j)
                    }
                    if let normalized = DeskLayout.normalizedModifier(key.keyCode) {
                        if modifiers.contains(normalized) { modifiers.remove(normalized) }
                        else { modifiers.insert(normalized) }
                    } else {
                        bridge.send(InputEvent(kind: .key, keyCode: key.keyCode,
                                               shift: modifiers.contains(56) ? true : nil,
                                               command: modifiers.contains(55) ? true : nil,
                                               option: modifiers.contains(58) ? true : nil,
                                               control: modifiers.contains(59) ? true : nil))
                        modifiers.removeAll()
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .targetedToAnyEntity()
                .onChanged { value in
                    guard typingMode else { return }
                    if value.entity.name == "keyboardSurface",
                       let desk = value.entity.parent {
                        let contact = value.convert(value.location3D, from: .local, to: desk)
                        guard let index = DeskLayout.keyIndex(at: [Float(contact.x),
                                                                   Float(contact.y),
                                                                   Float(contact.z)]) else { return }
                        if pressedKeys.insert(index).inserted {
                            DeskVisualFactory.setKeyPressed(index, in: desk, pressed: true)
                        }
                        return
                    }
                    guard value.entity.name == "pad" else { return }
                    let translation = value.convert(value.translation3D,
                                                    from: .global, to: .scene)
                    let x = Double(translation.x)
                    let z = Double(translation.z)
                    if dragActive {
                        let dx = (x - lastDragX) * 2600
                        let dz = (z - lastDragZ) * 2600
                        if abs(dx) + abs(dz) > 1.5 {
                            bridge.send(InputEvent(kind: .pointer,
                                                   deltaX: dx, deltaY: dz))
                        }
                    }
                    lastDragX = x
                    lastDragZ = z
                    dragActive = true
                }
                .onEnded { value in
                    if value.entity.name == "keyboardSurface",
                       let desk = value.entity.parent {
                        for index in pressedKeys {
                            DeskVisualFactory.setKeyPressed(index, in: desk, pressed: false)
                        }
                        pressedKeys.removeAll()
                        return
                    }
                    dragActive = false
                    lastDragX = 0
                    lastDragZ = 0
                }
        )
    }
}
