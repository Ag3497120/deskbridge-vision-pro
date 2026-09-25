import Foundation
import simd

/// Dimensions are metres in the desk's local XZ plane. Positive Z faces the wearer.
struct DeskKey: Equatable {
    let label: String
    let keyCode: UInt16
    let shiftedLabel: String?
    let centerX: Float
    let centerZ: Float
    let width: Float
    let depth: Float

    func contains(x: Float, z: Float) -> Bool {
        abs(x - centerX) <= width / 2 && abs(z - centerZ) <= depth / 2
    }
}

enum DeskLayout {
    static let keyboardWidth: Float = 0.59
    static let keyboardDepth: Float = 0.23
    static let keyboardCenterX: Float = -0.165
    static let trackpadWidth: Float = 0.28
    static let trackpadDepth: Float = 0.23
    static let trackpadCenterX: Float = 0.31
    static let keyDepth: Float = 0.035
    static let modifierCodes: Set<UInt16> = [56, 60, 55, 54, 58, 61, 59, 62]

    static func normalizedModifier(_ code: UInt16) -> UInt16? {
        guard modifierCodes.contains(code) else { return nil }
        switch code {
        case 60: return 56
        case 54: return 55
        case 61: return 58
        case 62: return 59
        default: return code
        }
    }

    private struct Definition {
        let label: String
        let code: UInt16
        let units: Float
        let shifted: String?

        init(_ label: String, _ code: UInt16, _ units: Float = 1, _ shifted: String? = nil) {
            self.label = label
            self.code = code
            self.units = units
            self.shifted = shifted
        }
    }

    /// ANSI virtual key codes. macOS applies the user's active keyboard input source.
    private static let rows: [[Definition]] = [
        [Definition("esc", 53), Definition("1", 18, 1, "!"), Definition("2", 19, 1, "@"), Definition("3", 20, 1, "#"), Definition("4", 21, 1, "$"), Definition("5", 23, 1, "%"), Definition("6", 22, 1, "^"), Definition("7", 26, 1, "&"), Definition("8", 28, 1, "*"), Definition("9", 25, 1, "("), Definition("0", 29, 1, ")"), Definition("-", 27, 1, "_"), Definition("=", 24, 1, "+"), Definition("⌫", 51, 1.6)],
        [Definition("tab", 48, 1.4), Definition("Q", 12), Definition("W", 13), Definition("E", 14), Definition("R", 15), Definition("T", 17), Definition("Y", 16), Definition("U", 32), Definition("I", 34), Definition("O", 31), Definition("P", 35), Definition("[", 33, 1, "{"), Definition("]", 30, 1, "}"), Definition("\\", 42, 1, "|")],
        [Definition("caps", 57, 1.6), Definition("A", 0), Definition("S", 1), Definition("D", 2), Definition("F", 3), Definition("G", 5), Definition("H", 4), Definition("J", 38), Definition("K", 40), Definition("L", 37), Definition(";", 41, 1, ":"), Definition("'", 39, 1, "\""), Definition("↵", 36, 1.8)],
        [Definition("⇧", 56, 1.8), Definition("Z", 6), Definition("X", 7), Definition("C", 8), Definition("V", 9), Definition("B", 11), Definition("N", 45), Definition("M", 46), Definition(",", 43, 1, "<"), Definition(".", 47, 1, ">"), Definition("/", 44, 1, "?"), Definition("⇧", 60, 1.8)],
        [Definition("ctrl", 59, 1.2), Definition("opt", 58, 1.2), Definition("⌘", 55, 1.4), Definition("space", 49, 5), Definition("⌘", 54, 1.4), Definition("opt", 61, 1.2), Definition("←", 123), Definition("↓", 125), Definition("→", 124)]
    ]

    static let keys: [DeskKey] = {
        let gap: Float = 0.003
        let usableWidth = keyboardWidth - 0.014
        let zCenters: [Float] = [-0.092, -0.046, 0, 0.046, 0.092]
        return rows.enumerated().flatMap { rowIndex, definitions in
            let unit = (usableWidth - gap * Float(definitions.count - 1)) / definitions.reduce(0) { $0 + $1.units }
            var left = keyboardCenterX - usableWidth / 2
            return definitions.map { definition in
                let width = unit * definition.units
                let key = DeskKey(
                    label: definition.label,
                    keyCode: definition.code,
                    shiftedLabel: definition.shifted,
                    centerX: left + width / 2,
                    centerZ: zCenters[rowIndex],
                    width: width,
                    depth: keyDepth
                )
                left += width + gap
                return key
            }
        }
    }()

    static func key(at point: SIMD3<Float>) -> DeskKey? {
        keys.first { $0.contains(x: point.x, z: point.z) }
    }

    static func isOnTrackpad(_ point: SIMD3<Float>) -> Bool {
        abs(point.x - trackpadCenterX) <= trackpadWidth / 2 &&
        abs(point.z) <= trackpadDepth / 2
    }
}

/// Pure input state machine, kept independent of ARKit for deterministic tests.
final class DeskInteraction {
    private var touching: [String: Bool] = [:]
    private var armed: Set<String> = []
    private var lastPadPoint: [String: SIMD3<Float>] = [:]
    private var padStart: [String: (point: SIMD3<Float>, time: TimeInterval)] = [:]
    private var padMoved: Set<String> = []
    private var dragging: Set<String> = []
    private var lastKeyTime: [String: TimeInterval] = [:]
    var touchHeight: Float = 0.012
    private var modifiers: Set<UInt16> = []
    var shiftEnabled: Bool { modifiers.contains(56) }

    func process(finger: String, point: SIMD3<Float>?, time: TimeInterval) -> [InputEvent] {
        guard let point else {
            touching[finger] = false
            lastPadPoint[finger] = nil
            padStart[finger] = nil
            padMoved.remove(finger)
            let wasDragging = dragging.remove(finger) != nil
            armed.remove(finger)
            return wasDragging ? [InputEvent(kind: .mouseUp)] : []
        }
        let wasTouching = touching[finger] ?? false
        if point.y > touchHeight + 0.015 { armed.insert(finger) }
        let isTouching = point.y >= -0.025 &&
            point.y <= touchHeight + (wasTouching ? 0.012 : 0)
        touching[finger] = isTouching

        guard isTouching else {
            let started = padStart.removeValue(forKey: finger)
            let wasDragging = dragging.remove(finger) != nil
            let hadMoved = padMoved.remove(finger) != nil
            lastPadPoint[finger] = nil
            if wasDragging { return [InputEvent(kind: .mouseUp)] }
            if started != nil && !hadMoved && time - started!.time < 0.35 {
                return [InputEvent(kind: .click)]
            }
            return []
        }

        if DeskLayout.isOnTrackpad(point) {
            guard finger.hasSuffix("-index") || finger == "pad" else {
                lastPadPoint[finger] = point
                return []
            }
            let previous = lastPadPoint[finger]
            lastPadPoint[finger] = point
            if padStart[finger] == nil { padStart[finger] = (point, time) }
            let middleID = finger.replacingOccurrences(of: "-index", with: "-middle")
            let isScrolling = finger.hasSuffix("-index") && lastPadPoint[middleID] != nil
            if let start = padStart[finger],
               simd_distance(point, start.point) > 0.008 {
                padMoved.insert(finger)
            }
            if let start = padStart[finger],
               !isScrolling,
               !padMoved.contains(finger),
               !dragging.contains(finger),
               time - start.time > 0.5 {
                dragging.insert(finger)
                return [InputEvent(kind: .mouseDown)]
            }
            guard let previous, wasTouching else { return [] }
            let dx = Double(point.x - previous.x) * 2600
            let dy = Double(point.z - previous.z) * 2600
            guard abs(dx) + abs(dy) > 1.5 else { return [] }
            if isScrolling {
                return [InputEvent(kind: .scroll, deltaY: dy / 15)]
            }
            return [InputEvent(kind: .pointer, deltaX: dx, deltaY: dy)]
        }
        lastPadPoint[finger] = nil
        guard !wasTouching, armed.remove(finger) != nil,
              let key = DeskLayout.key(at: point) else { return [] }
        guard time - (lastKeyTime[finger] ?? -.infinity) > 0.09 else { return [] }
        lastKeyTime[finger] = time
        if let normalized = DeskLayout.normalizedModifier(key.keyCode) {
            if modifiers.contains(normalized) { modifiers.remove(normalized) }
            else { modifiers.insert(normalized) }
            return []
        }
        let active = modifiers
        modifiers.removeAll()
        return [InputEvent(kind: .key, keyCode: key.keyCode,
                           shift: active.contains(56) ? true : nil,
                           command: active.contains(55) ? true : nil,
                           option: active.contains(58) ? true : nil,
                           control: active.contains(59) ? true : nil)]
    }

    func reset() {
        touching.removeAll()
        lastPadPoint.removeAll()
        padStart.removeAll()
        padMoved.removeAll()
        dragging.removeAll()
        armed.removeAll()
        lastKeyTime.removeAll()
        modifiers.removeAll()
    }
}
