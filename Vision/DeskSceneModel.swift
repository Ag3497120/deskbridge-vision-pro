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
        status = "開始すると机を探します"
    }

    func recenter() {
        onInput?(InputEvent(kind: .mouseUp))
        selectedPlaneID = nil
        baseTransform = nil
        desk.isEnabled = false
        interaction.reset()
        status = "平らな机を再検出しています"
    }

    private func handlePlane(_ anchor: PlaneAnchor, removed: Bool) {
        if removed {
            if anchor.id == selectedPlaneID { recenter() }
            return
        }
        guard selectedPlaneID == nil,
              anchor.surfaceClassification == .table,
              anchor.geometry.extent.width >= 0.65,
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
        deskTransform = baseTransform * translation * rotation
        desk.setTransformMatrix(deskTransform, relativeTo: nil)
    }

    private func handleHand(_ anchor: HandAnchor, removed: Bool) {
        guard desk.isEnabled else { return }
        let side = anchor.chirality == .left ? "left" : "right"
        let inverse = simd_inverse(deskTransform)
        for (name, jointName) in fingerNames {
            let fingerID = "\(side)-\(name)"
            guard !removed, anchor.isTracked,
                  let skeleton = anchor.handSkeleton else {
                for event in interaction.process(finger: fingerID, point: nil,
                                                 time: CACurrentMediaTime()) { onInput?(event) }
                continue
            }
            let joint = skeleton.joint(jointName)
            guard joint.isTracked else {
                for event in interaction.process(finger: fingerID, point: nil,
                                                 time: CACurrentMediaTime()) { onInput?(event) }
                continue
            }
            let world = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
            let local = inverse * world.columns.3
            let point = SIMD3<Float>(local.x, local.y, local.z)
            for event in interaction.process(finger: fingerID, point: point,
                                             time: CACurrentMediaTime()) {
                onInput?(event)
            }
        }
    }

}
