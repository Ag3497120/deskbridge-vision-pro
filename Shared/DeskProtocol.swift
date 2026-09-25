import Foundation

/// Small, versioned message sent over an encrypted local Multipeer session.
struct InputEvent: Codable, Equatable {
    enum Kind: String, Codable {
        case key
        case pointer
        case click
        case mouseDown
        case mouseUp
        case scroll
    }

    let version: Int
    let kind: Kind
    var keyCode: UInt16?
    var shift: Bool?
    var deltaX: Double?
    var deltaY: Double?

    init(
        kind: Kind,
        keyCode: UInt16? = nil,
        shift: Bool? = nil,
        deltaX: Double? = nil,
        deltaY: Double? = nil
    ) {
        self.version = 1
        self.kind = kind
        self.keyCode = keyCode
        self.shift = shift
        self.deltaX = deltaX
        self.deltaY = deltaY
    }
}
