import RealityKit
import UIKit
import simd

@MainActor
enum DeskVisualFactory {
    static func makeDesk(interactive: Bool, directTouchOnly: Bool = false,
                         showTouchZones: Bool = false) -> Entity {
        let desk = Entity()
        var white = UnlitMaterial(color: .white)
        white.blending = .transparent(opacity: .init(floatLiteral: 0.90))
        var soft = UnlitMaterial(color: .white)
        soft.blending = .transparent(opacity: .init(floatLiteral: 0.45))

        addOutline(to: desk, centerX: DeskLayout.keyboardCenterX, centerZ: 0,
                   width: DeskLayout.keyboardWidth, depth: DeskLayout.keyboardDepth,
                   material: white, thickness: 0.002)
        addOutline(to: desk, centerX: DeskLayout.trackpadCenterX, centerZ: 0,
                   width: DeskLayout.trackpadWidth, depth: DeskLayout.trackpadDepth,
                   material: white, thickness: 0.002)

        for (index, key) in DeskLayout.keys.enumerated() {
            let cap = Entity()
            cap.name = "cap:\(index)"
            cap.position = [key.centerX, 0.001, key.centerZ]
            addOutline(to: cap, centerX: 0, centerZ: 0,
                       width: key.width, depth: key.depth,
                       material: soft, thickness: 0.0012)
            var capMaterial = UnlitMaterial(color: .white)
            capMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.07))
            let surface = ModelEntity(mesh: .generateBox(size: [key.width - 0.001,
                                                                0.001,
                                                                key.depth - 0.001]),
                                      materials: [capMaterial])
            cap.addChild(surface)
            let text = ModelEntity(
                mesh: .generateText(key.label, extrusionDepth: 0.0001,
                                    font: .systemFont(ofSize: key.label.count > 3 ? 0.008 : 0.012),
                                    containerFrame: CGRect(x: 0, y: 0,
                                                           width: CGFloat(key.width),
                                                           height: CGFloat(key.depth)),
                                    alignment: .center, lineBreakMode: .byClipping),
                materials: [white]
            )
            text.position = [-key.width / 2, 0.0018,
                             key.depth / 2 - 0.002]
            text.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            cap.addChild(text)
            if key.label == "F" || key.label == "J" {
                addHomeMarker(to: cap, key: key)
            }
            desk.addChild(cap)
        }
        if interactive {
            // One thin surface avoids the side faces of individual key hit
            // boxes selecting a neighbour when a finger approaches obliquely.
            addHitTarget(to: desk, name: "keyboardSurface",
                         x: DeskLayout.keyboardCenterX, z: 0,
                         width: DeskLayout.keyboardWidth,
                         depth: DeskLayout.keyboardDepth,
                         directTouchOnly: directTouchOnly,
                         showTouchZone: showTouchZones)
            addHitTarget(to: desk, name: "pad", x: DeskLayout.trackpadCenterX,
                         z: 0, width: DeskLayout.trackpadWidth,
                         depth: DeskLayout.trackpadDepth,
                         directTouchOnly: directTouchOnly,
                         showTouchZone: showTouchZones)
            addFocusRail(to: desk)
        }
        return desk
    }

    static func pressKey(_ index: Int, in desk: Entity) {
        guard let cap = desk.findEntity(named: "cap:\(index)") else { return }
        setKeyPressed(index, in: desk, pressed: true)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(75))
            guard cap.parent === desk else { return }
            setKeyPressed(index, in: desk, pressed: false)
        }
    }

    static func setKeyPressed(_ index: Int, in desk: Entity, pressed: Bool) {
        guard let cap = desk.findEntity(named: "cap:\(index)") else { return }
        var transform = cap.transform
        transform.translation.y = pressed ? -0.002 : 0.001
        cap.move(to: transform, relativeTo: desk,
                 duration: pressed ? 0.045 : 0.085)
    }

    private static func addHomeMarker(to cap: Entity, key: DeskKey) {
        let color = key.label == "F"
            ? UIColor(red: 0.20, green: 0.88, blue: 0.90, alpha: 1)
            : UIColor(red: 1.00, green: 0.71, blue: 0.21, alpha: 1)
        let material = UnlitMaterial(color: color)
        let z = -key.depth / 2 + 0.004
        let post = ModelEntity(mesh: .generateBox(size: [0.002, 0.025, 0.002]),
                               materials: [material])
        post.position = [0, 0.013, z]
        cap.addChild(post)
        let markerTop = ModelEntity(mesh: .generateSphere(radius: 0.0045),
                                    materials: [material])
        markerTop.position = [0, 0.027, z]
        cap.addChild(markerTop)
    }

    static func setDirectTouchOnly(_ directTouchOnly: Bool, on desk: Entity) {
        for target in desk.children where target.name == "pad" || target.name == "keyboardSurface" {
            target.components.set(InputTargetComponent(
                allowedInputTypes: directTouchOnly ? .direct : .all))
        }
    }

    static func setTypingMode(_ enabled: Bool, on desk: Entity) {
        for target in desk.children where target.name == "pad" || target.name == "keyboardSurface" {
            target.isEnabled = enabled
        }
    }

    static func setTouchZonesVisible(_ visible: Bool, on desk: Entity) {
        for target in desk.children where target.name == "pad" || target.name == "keyboardSurface" {
            target.findEntity(named: "touchZone")?.isEnabled = visible
        }
    }

    static func updateFocusRailPreview(_ preview: String, on desk: Entity) {
        guard let label = desk.findEntity(named: "focusRailText") as? ModelEntity,
              var model = label.model else { return }
        let visible = preview.isEmpty ? "—" : String(preview.suffix(16))
        model.mesh = .generateText("送信キー: \(visible)", extrusionDepth: 0.0003,
                                   font: .systemFont(ofSize: 0.019, weight: .semibold),
                                   containerFrame: CGRect(x: 0, y: 0,
                                                          width: CGFloat(DeskLayout.keyboardWidth - 0.02),
                                                          height: 0.032),
                                   alignment: .center, lineBreakMode: .byClipping)
        label.model = model
    }

    private static func addFocusRail(to desk: Entity) {
        // This stays above the key plane and provides a place to look while
        // testing direct touch. It doesn't expose gaze or hand coordinates.
        var background = UnlitMaterial(color: UIColor(red: 0.05, green: 0.32,
                                                      blue: 0.60, alpha: 1))
        background.blending = .transparent(opacity: .init(floatLiteral: 0.88))
        let plate = ModelEntity(mesh: .generateBox(size: [DeskLayout.keyboardWidth, 0.045, 0.003]),
                                materials: [background])
        plate.position = [DeskLayout.keyboardCenterX, 0.10, -0.128]
        desk.addChild(plate)

        let label = ModelEntity(
            mesh: .generateText("送信キー: —", extrusionDepth: 0.0003,
                                font: .systemFont(ofSize: 0.019, weight: .semibold),
                                containerFrame: CGRect(x: 0, y: 0, width: CGFloat(DeskLayout.keyboardWidth - 0.02),
                                                       height: 0.032),
                                alignment: .center, lineBreakMode: .byClipping),
            materials: [UnlitMaterial(color: .white)]
        )
        label.name = "focusRailText"
        label.position = [DeskLayout.keyboardCenterX - (DeskLayout.keyboardWidth - 0.02) / 2,
                          0.088, -0.124]
        desk.addChild(label)

        // The rail is only a visual reference. A gaze target here would make
        // the DeskBridge volume active while the user looks at Mac content.
    }

    private static func addHitTarget(to parent: Entity, name: String,
                                     x: Float, z: Float, width: Float, depth: Float,
                                     directTouchOnly: Bool,
                                     showTouchZone: Bool) {
        let target = Entity()
        target.name = name
        target.position = [x, 0.001, z]
        target.components.set(InputTargetComponent(
            allowedInputTypes: directTouchOnly ? .direct : .all))
        var collision = CollisionComponent(shapes: [
            .generateBox(size: [width, 0.003, depth])
        ])
        collision.filter = CollisionFilter(group: [], mask: [])
        target.components.set(collision)
        var zoneMaterial = UnlitMaterial(color: UIColor(red: 0.12, green: 0.85,
                                                        blue: 1.00, alpha: 1))
        zoneMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.16))
        let zone = ModelEntity(mesh: .generateBox(size: [width, 0.003, depth]),
                               materials: [zoneMaterial])
        zone.name = "touchZone"
        zone.isEnabled = showTouchZone
        target.addChild(zone)
        parent.addChild(target)
    }

    private static func addOutline(to parent: Entity, centerX: Float, centerZ: Float,
                                   width: Float, depth: Float, material: UnlitMaterial,
                                   thickness: Float) {
        let height: Float = 0.001
        let horizontal = MeshResource.generateBox(size: [width, height, thickness])
        let vertical = MeshResource.generateBox(size: [thickness, height, depth])
        for z in [centerZ - depth / 2, centerZ + depth / 2] {
            let edge = ModelEntity(mesh: horizontal, materials: [material])
            edge.position = [centerX, 0, z]
            parent.addChild(edge)
        }
        for x in [centerX - width / 2, centerX + width / 2] {
            let edge = ModelEntity(mesh: vertical, materials: [material])
            edge.position = [x, 0, centerZ]
            parent.addChild(edge)
        }
    }
}
