import Foundation
import simd

@main
enum DeskLayoutTests {
    static func main() {
        assert(DeskLayout.keys.count >= 55)
        for key in DeskLayout.keys {
            assert(key.centerX - key.width / 2 >=
                   DeskLayout.keyboardCenterX - DeskLayout.keyboardWidth / 2)
            assert(key.centerX + key.width / 2 <=
                   DeskLayout.keyboardCenterX + DeskLayout.keyboardWidth / 2)
        }
        let firstKey = DeskLayout.keys[0]
        assert(DeskLayout.key(at: SIMD3<Float>(firstKey.centerX, 0, firstKey.centerZ)) != nil)
        assert(DeskLayout.key(at: SIMD3<Float>(1, 0, 0)) == nil)
        assert(DeskLayout.isOnTrackpad(SIMD3<Float>(DeskLayout.trackpadCenterX, 0, 0)))
        assert(!DeskLayout.isOnTrackpad(SIMD3<Float>(DeskLayout.keyboardCenterX, 0, 0)))

        guard let a = DeskLayout.keys.first(where: { $0.label == "A" }),
              let shift = DeskLayout.keys.first(where: { $0.label == "⇧" }) else {
            fatalError("Required keys are missing")
        }
        let engine = DeskInteraction()
        let aboveA = SIMD3<Float>(a.centerX, 0.06, a.centerZ)
        let onA = SIMD3<Float>(a.centerX, 0.005, a.centerZ)
        assert(engine.process(finger: "index", point: aboveA, time: 0).isEmpty)
        assert(engine.process(finger: "index", point: onA, time: 0.1) ==
               [InputEvent(kind: .key, keyCode: a.keyCode)])
        assert(engine.process(finger: "index", point: onA, time: 0.2).isEmpty)
        assert(engine.process(finger: "index", point: aboveA, time: 0.3).isEmpty)

        let onShift = SIMD3<Float>(shift.centerX, 0.005, shift.centerZ)
        assert(engine.process(finger: "index", point: onShift, time: 0.4).isEmpty)
        assert(engine.shiftEnabled)
        assert(engine.process(finger: "index", point: aboveA, time: 0.5).isEmpty)
        assert(engine.process(finger: "index", point: onA, time: 0.6) ==
               [InputEvent(kind: .key, keyCode: a.keyCode, shift: true)])
        assert(!engine.shiftEnabled)

        guard let command = DeskLayout.keys.first(where: { $0.keyCode == 55 }) else {
            fatalError("Command key is missing")
        }
        let onCommand = SIMD3<Float>(command.centerX, 0.005, command.centerZ)
        assert(engine.process(finger: "index", point: aboveA, time: 0.7).isEmpty)
        assert(engine.process(finger: "index", point: onCommand, time: 0.8).isEmpty)
        assert(engine.process(finger: "index", point: aboveA, time: 0.9).isEmpty)
        assert(engine.process(finger: "index", point: onA, time: 1.0) ==
               [InputEvent(kind: .key, keyCode: a.keyCode, command: true)])

        let pad = SIMD3<Float>(DeskLayout.trackpadCenterX, 0.005, 0)
        let moved = SIMD3<Float>(DeskLayout.trackpadCenterX + 0.01, 0.005, 0)
        assert(engine.process(finger: "pad", point: pad, time: 1).isEmpty)
        let movement = engine.process(finger: "pad", point: moved, time: 1.1)
        assert(movement.count == 1 && movement[0].kind == .pointer)
        assert(engine.process(finger: "pad", point: SIMD3<Float>(moved.x, 0.06, 0), time: 1.2).isEmpty)
        assert(engine.process(finger: "pad", point: pad, time: 2).isEmpty)
        assert(engine.process(finger: "pad", point: SIMD3<Float>(pad.x, 0.06, 0), time: 2.2) ==
               [InputEvent(kind: .click)])
        assert(engine.process(finger: "pad", point: pad, time: 3).isEmpty)
        assert(engine.process(finger: "pad", point: pad, time: 3.6) ==
               [InputEvent(kind: .mouseDown)])
        assert(engine.process(finger: "pad", point: nil, time: 3.7) ==
               [InputEvent(kind: .mouseUp)])

        let encoded = try! JSONEncoder().encode(InputEvent(kind: .key, keyCode: a.keyCode))
        assert(try! JSONDecoder().decode(InputEvent.self, from: encoded) ==
               InputEvent(kind: .key, keyCode: a.keyCode))
        print("DeskLayoutTests: passed")
    }
}
