import RealityKit
import UIKit
import simd

@MainActor
enum DeskVisualFactory {
    static func makeDesk(interactive: Bool) -> Entity {
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
            addOutline(to: desk, centerX: key.centerX, centerZ: key.centerZ,
                       width: key.width, depth: key.depth,
                       material: soft, thickness: 0.0012)
            let text = ModelEntity(
                mesh: .generateText(key.label, extrusionDepth: 0.0001,
                                    font: .systemFont(ofSize: key.label.count > 3 ? 0.008 : 0.012),
                                    containerFrame: CGRect(x: 0, y: 0,
                                                           width: CGFloat(key.width),
                                                           height: CGFloat(key.depth)),
                                    alignment: .center, lineBreakMode: .byClipping),
                materials: [white]
            )
            text.position = [key.centerX - key.width / 2,
                             0.0018,
                             key.centerZ + key.depth / 2 - 0.002]
            text.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            desk.addChild(text)
            if interactive {
                addHitTarget(to: desk, name: "key:\(index)", x: key.centerX,
                             z: key.centerZ, width: key.width, depth: key.depth)
            }
        }
        if interactive {
            addHitTarget(to: desk, name: "pad", x: DeskLayout.trackpadCenterX,
                         z: 0, width: DeskLayout.trackpadWidth,
                         depth: DeskLayout.trackpadDepth)
        }
        return desk
    }

    private static func addHitTarget(to parent: Entity, name: String,
                                     x: Float, z: Float, width: Float, depth: Float) {
        let target = Entity()
        target.name = name
        target.position = [x, 0.004, z]
        target.components.set(InputTargetComponent())
        var collision = CollisionComponent(shapes: [
            .generateBox(size: [width, 0.012, depth])
        ])
        collision.filter = CollisionFilter(group: [], mask: [])
        target.components.set(collision)
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
