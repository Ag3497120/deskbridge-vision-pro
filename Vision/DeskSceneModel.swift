import ARKit
import Foundation
import QuartzCore
import RealityKit
import simd

@MainActor
final class DeskSceneModel: ObservableObject {
    @Published private(set) var status = "開始すると机を探します"
    @Published var offsetX: Float = 0 { didSet { updatePlacement() } }
    @Published var offsetZ: Float = 0 { didSet { updatePlacement() } }
    @Published var rotationDegrees: Float = 0 { didSet { updatePlacement() } }
    @Published var touchHeight: Float = 0.012 { didSet { interaction.touchHeight = touchHeight } }
    @Published var keyboardWidth: Float = 0.30 { didSet { updatePlacement() } }
    @Published var keyboardDepth: Float = 0.115 { didSet { updatePlacement() } }
    @Published var homeCuesEnabled = true
    @Published var showHandOverlay = true {
        didSet {
            for overlay in handOverlays.values { overlay.root.isEnabled = showHandOverlay }
        }
    }
    @Published private(set) var lastHomeCue = "—"

    let root = Entity()
    var onInput: ((InputEvent) -> Void)?

    private let desk = Entity()
    private let session = ARKitSession()
    private let planeProvider = PlaneDetectionProvider(alignments: [.horizontal])
    private let handProvider = HandTrackingProvider()
    private let worldProvider = WorldTrackingProvider()
    private let interaction = DeskInteraction()
    private var baseTransform: simd_float4x4?
    private var deskTransform = matrix_identity_float4x4
    private var selectedPlaneID: UUID?
    private var tasks: [Task<Void, Never>] = []
    private var hasBuiltGeometry = false
    private var insideHomeZone: [String: Bool] = [:]
    private var lastHomeCueTime: [String: TimeInterval] = [:]
    private struct HandLink {
        let start: HandSkeleton.JointName
        let end: HandSkeleton.JointName
        let model: ModelEntity
    }
    private struct HandOverlay {
        let root: Entity
        let joints: [HandSkeleton.JointName: ModelEntity]
        let links: [HandLink]
        let palm: ModelEntity
    }
    private var handOverlays: [String: HandOverlay] = [:]
    private let handChains: [[HandSkeleton.JointName]] = [
        [.wrist, .thumbKnuckle, .thumbIntermediateBase, .thumbIntermediateTip, .thumbTip],
        [.wrist, .indexFingerMetacarpal, .indexFingerKnuckle,
         .indexFingerIntermediateBase, .indexFingerIntermediateTip, .indexFingerTip],
        [.wrist, .middleFingerMetacarpal, .middleFingerKnuckle,
         .middleFingerIntermediateBase, .middleFingerIntermediateTip, .middleFingerTip],
        [.wrist, .ringFingerMetacarpal, .ringFingerKnuckle,
         .ringFingerIntermediateBase, .ringFingerIntermediateTip, .ringFingerTip],
        [.wrist, .littleFingerMetacarpal, .littleFingerKnuckle,
         .littleFingerIntermediateBase, .littleFingerIntermediateTip, .littleFingerTip]
    ]
    private let fingerNames: [(String, HandSkeleton.JointName)] = [
        ("thumb", .thumbTip),
        ("index", .indexFingerTip),
        ("middle", .middleFingerTip),
        ("ring", .ringFingerTip),
        ("little", .littleFingerTip)
    ]

    func start() async {
        guard tasks.isEmpty else { return }
        if !hasBuiltGeometry {
            desk.addChild(DeskVisualFactory.makeDesk(interactive: false))
            root.addChild(desk)
            hasBuiltGeometry = true
        }
        desk.isEnabled = false
        status = "机と手を追跡する権限を確認しています"
        do {
            try await session.run([planeProvider, handProvider, worldProvider])
        } catch {
            status = "追跡を開始できません: \(error.localizedDescription)"
            return
        }
        status = "平らな机を探しています"
        tasks = [
            Task { [weak self] in
                guard let self else { return }
                for await update in self.planeProvider.anchorUpdates {
                    self.handlePlane(update.anchor, removed: update.event == .removed)
                }
            },
            Task { [weak self] in
                guard let self else { return }
                for await update in self.handProvider.anchorUpdates {
                    self.handleHand(update.anchor, removed: update.event == .removed)
                }
            }
        ]
    }

    func stop() {
        onInput?(InputEvent(kind: .mouseUp))
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        session.stop()
        desk.isEnabled = false
        selectedPlaneID = nil
        baseTransform = nil
        interaction.reset()
        insideHomeZone.removeAll()
        for overlay in handOverlays.values { overlay.root.isEnabled = false }
        status = "開始すると机を探します"
    }

    func recenter() {
        onInput?(InputEvent(kind: .mouseUp))
        selectedPlaneID = nil
        baseTransform = nil
        desk.isEnabled = false
        interaction.reset()
        insideHomeZone.removeAll()
        status = "平らな机を再検出しています"
    }

    private func handlePlane(_ anchor: PlaneAnchor, removed: Bool) {
        if removed {
            if anchor.id == selectedPlaneID { recenter() }
            return
        }
        guard selectedPlaneID == nil,
              anchor.surfaceClassification == .table,
              anchor.geometry.extent.width >= 0.45,
              anchor.geometry.extent.height >= 0.25 else { return }

        let planeTransform = anchor.originFromAnchorTransform *
            anchor.geometry.extent.anchorFromExtentTransform
        let center = SIMD3<Float>(planeTransform.columns.3.x,
                                  planeTransform.columns.3.y,
                                  planeTransform.columns.3.z)
        let head = worldProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        let headPosition = head.map {
            SIMD3<Float>($0.originFromAnchorTransform.columns.3.x,
                         $0.originFromAnchorTransform.columns.3.y,
                         $0.originFromAnchorTransform.columns.3.z)
        } ?? center + SIMD3<Float>(0, 0, 1)

        var towardWearer = SIMD3<Float>(headPosition.x - center.x, 0, headPosition.z - center.z)
        if simd_length(towardWearer) < 0.05 { towardWearer = [0, 0, 1] }
        towardWearer = simd_normalize(towardWearer)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), towardWearer))
        var transform = matrix_identity_float4x4
        transform.columns.0 = SIMD4<Float>(right.x, right.y, right.z, 0)
        transform.columns.1 = SIMD4<Float>(0, 1, 0, 0)
        transform.columns.2 = SIMD4<Float>(towardWearer.x, towardWearer.y, towardWearer.z, 0)
        transform.columns.3 = SIMD4<Float>(center.x, center.y + 0.004, center.z, 1)
        baseTransform = transform
        selectedPlaneID = anchor.id
        desk.isEnabled = true
        updatePlacement()
        status = "机上に配置しました。位置を調整できます"
    }

    private func updatePlacement() {
        guard let baseTransform else { return }
        var translation = matrix_identity_float4x4
        translation.columns.3 = SIMD4<Float>(offsetX, 0, offsetZ, 1)
        let angle = rotationDegrees * .pi / 180
        let rotation = simd_float4x4(simd_quatf(angle: angle, axis: [0, 1, 0]))
        var scale = matrix_identity_float4x4
        scale.columns.0.x = keyboardWidth / DeskLayout.keyboardWidth
        scale.columns.2.z = keyboardDepth / DeskLayout.keyboardDepth
        deskTransform = baseTransform * translation * rotation * scale
        desk.setTransformMatrix(deskTransform, relativeTo: nil)
    }

    private func handleHand(_ anchor: HandAnchor, removed: Bool) {
        let side = anchor.chirality == .left ? "left" : "right"
        updateHandOverlay(anchor, side: side, removed: removed)
        guard desk.isEnabled else { return }
        let inverse = simd_inverse(deskTransform)
        for (name, jointName) in fingerNames {
            let fingerID = "\(side)-\(name)"
            guard !removed, anchor.isTracked,
                  let skeleton = anchor.handSkeleton else {
                if name == "index" { insideHomeZone[side] = false }
                for event in interaction.process(finger: fingerID, point: nil,
                                                 time: CACurrentMediaTime()) { onInput?(event) }
                continue
            }
            let joint = skeleton.joint(jointName)
            guard joint.isTracked else {
                if name == "index" { insideHomeZone[side] = false }
                for event in interaction.process(finger: fingerID, point: nil,
                                                 time: CACurrentMediaTime()) { onInput?(event) }
                continue
            }
            let world = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
            let local = inverse * world.columns.3
            let point = SIMD3<Float>(local.x, local.y, local.z)
            if name == "index" { updateHomeCue(side: side, point: point) }
            for event in interaction.process(finger: fingerID, point: point,
                                             time: CACurrentMediaTime()) {
                onInput?(event)
            }
        }
    }

    private func makeHandOverlay() -> HandOverlay {
        let overlayRoot = Entity()
        root.addChild(overlayRoot)
        var cyan = UnlitMaterial(color: .init(red: 0.32, green: 0.93,
                                              blue: 1.0, alpha: 1))
        cyan.blending = .transparent(opacity: .init(floatLiteral: 0.48))
        var palmMaterial = cyan
        palmMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.22))
        var joints: [HandSkeleton.JointName: ModelEntity] = [:]
        for name in Set(handChains.flatMap { $0 }) {
            let marker = ModelEntity(mesh: .generateSphere(radius: 0.005),
                                     materials: [cyan])
            overlayRoot.addChild(marker)
            joints[name] = marker
        }
        var links: [HandLink] = []
        let linkMesh = MeshResource.generateBox(size: [1, 1, 1])
        for chain in handChains {
            for (start, end) in zip(chain, chain.dropFirst()) {
                let model = ModelEntity(mesh: linkMesh, materials: [cyan])
                overlayRoot.addChild(model)
                links.append(HandLink(start: start, end: end, model: model))
            }
        }
        let palm = ModelEntity(mesh: linkMesh, materials: [palmMaterial])
        overlayRoot.addChild(palm)
        return HandOverlay(root: overlayRoot, joints: joints,
                           links: links, palm: palm)
    }

    private func updateHandOverlay(_ anchor: HandAnchor, side: String, removed: Bool) {
        if handOverlays[side] == nil { handOverlays[side] = makeHandOverlay() }
        guard let overlay = handOverlays[side] else { return }
        guard showHandOverlay, !removed, anchor.isTracked,
              let skeleton = anchor.handSkeleton else {
            overlay.root.isEnabled = false
            return
        }
        overlay.root.isEnabled = true
        var points: [HandSkeleton.JointName: SIMD3<Float>] = [:]
        for (name, marker) in overlay.joints {
            let joint = skeleton.joint(name)
            guard joint.isTracked else {
                marker.isEnabled = false
                continue
            }
            let transform = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
            let point = SIMD3<Float>(transform.columns.3.x,
                                     transform.columns.3.y,
                                     transform.columns.3.z)
            points[name] = point
            marker.isEnabled = true
            marker.position = point
        }
        for link in overlay.links {
            guard let start = points[link.start], let end = points[link.end] else {
                link.model.isEnabled = false
                continue
            }
            let difference = end - start
            let length = simd_length(difference)
            guard length > 0.001 else {
                link.model.isEnabled = false
                continue
            }
            link.model.isEnabled = true
            link.model.position = (start + end) / 2
            link.model.orientation = simd_quatf(from: [0, 1, 0], to: difference / length)
            link.model.scale = [0.009, length, 0.009]
        }
        guard let wrist = points[.wrist],
              let index = points[.indexFingerKnuckle],
              let little = points[.littleFingerKnuckle] else {
            overlay.palm.isEnabled = false
            return
        }
        let knuckleMiddle = (index + little) / 2
        let across = little - index
        let along = wrist - knuckleMiddle
        guard simd_length(across) > 0.01, simd_length(along) > 0.01 else {
            overlay.palm.isEnabled = false
            return
        }
        let x = simd_normalize(across)
        let normal = simd_cross(along, x)
        guard simd_length(normal) > 0.001 else {
            overlay.palm.isEnabled = false
            return
        }
        let y = simd_normalize(normal)
        let z = simd_normalize(simd_cross(x, y))
        overlay.palm.isEnabled = true
        overlay.palm.position = (wrist + knuckleMiddle) / 2
        overlay.palm.orientation = simd_quatf(simd_float3x3(columns: (x, y, z)))
        overlay.palm.scale = [simd_length(across) + 0.018, 0.006,
                              simd_length(along) + 0.018]
    }

    private func updateHomeCue(side: String, point: SIMD3<Float>) {
        let label = side == "left" ? "F" : "J"
        guard let key = DeskLayout.keys.first(where: { $0.label == label }) else { return }
        let inside = abs(point.x - key.centerX) <= key.width / 2 + 0.012 &&
                     abs(point.z - key.centerZ) <= key.depth / 2 + 0.012 &&
                     point.y >= 0.012 && point.y <= 0.065
        let previouslyInside = insideHomeZone[side] ?? false
        insideHomeZone[side] = inside
        guard inside, !previouslyInside, homeCuesEnabled else { return }
        let now = CACurrentMediaTime()
        guard now - (lastHomeCueTime[side] ?? -.infinity) >= 0.4 else { return }
        lastHomeCueTime[side] = now
        lastHomeCue = "\(label) に接近"
        HomeKeyCuePlayer.shared.play(side == "left" ? .f : .j)
    }

}
