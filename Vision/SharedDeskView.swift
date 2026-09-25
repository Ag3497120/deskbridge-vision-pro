import RealityKit
import SwiftUI

/// Shared Space version: standard direct-touch gestures work beside Mac Virtual Display.
/// Placement is performed with the system's volume handle, so no raw ARKit data is read.
struct SharedDeskView: View {
    @ObservedObject var bridge: VisionBridge
    @State private var shiftEnabled = false
    @State private var dragActive = false
    @State private var lastDragX = 0.0
    @State private var lastDragZ = 0.0

    var body: some View {
        RealityView { content in
            let desk = DeskVisualFactory.makeDesk(interactive: true)
            // Keep the surface near the volume's bottom so it can sit on a table.
            desk.position.y = -0.025
            content.add(desk)
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let name = value.entity.name
                    if name == "pad" {
                        bridge.send(InputEvent(kind: .click))
                        return
                    }
                    guard name.hasPrefix("key:"),
                          let index = Int(name.dropFirst(4)),
                          DeskLayout.keys.indices.contains(index) else { return }
                    let key = DeskLayout.keys[index]
                    if key.keyCode == 56 || key.keyCode == 60 {
                        shiftEnabled.toggle()
                    } else {
                        bridge.send(InputEvent(kind: .key, keyCode: key.keyCode,
                                               shift: shiftEnabled))
                        shiftEnabled = false
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .targetedToAnyEntity()
                .onChanged { value in
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
                .onEnded { _ in
                    dragActive = false
                    lastDragX = 0
                    lastDragZ = 0
                }
        )
    }
}
