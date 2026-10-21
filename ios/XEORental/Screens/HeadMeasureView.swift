import SwiftUI
import RentalKit
#if os(iOS) && canImport(ARKit)
import ARKit
#endif

/// Head-circumference measurement with the TrueDepth front camera (ARKit face tracking).
/// Face-mesh width samples go into `HeadEstimator` (RentalKit), which turns their median into an estimate.
/// Devices without face tracking (or the simulator) fall back to manual input.
struct HeadMeasureView: View {
    /// (centimeters, measured?)
    let onDone: (Int, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var estimator = HeadEstimator()
    @State private var manualCm = 57
    @State private var mode: Mode = FaceTracking.isSupported ? .scanning : .manual

    enum Mode { case scanning, result, manual }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch mode {
                case .scanning: scanning
                case .result: result
                case .manual: manual
                }
            }
            .padding(Brand.gutter)
            .background(Brand.paper)
            .navigationTitle("测量头围")
            .xeoInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private var scanning: some View {
        VStack(spacing: 16) {
            Text("将手机放在面前 30–40 cm，正对屏幕，保持不动几秒钟。").font(.xeoBody).foregroundStyle(Brand.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            FaceTracking.Preview { width in
                guard mode == .scanning else { return }
                estimator.add(faceWidthMeters: width)
                if let cm = estimator.estimateCm { manualCm = cm; mode = .result }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: Brand.corner))
            .overlay(RoundedRectangle(cornerRadius: Brand.corner).stroke(Brand.silver))
            ProgressView(value: estimator.progress).tint(Brand.purple)
            Button("改为手动填写") { mode = .manual }.buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
    }

    private var result: some View {
        VStack(spacing: 18) {
            Text("估算头围").font(.xeoCaption).foregroundStyle(Brand.caption)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(manualCm)").font(.system(size: 64, weight: .bold)).foregroundStyle(Brand.ink)
                Text("cm").font(.xeoTitle).foregroundStyle(Brand.secondary)
            }
            Stepper("微调 ±1 cm", value: $manualCm, in: HeadEstimator.range).font(.xeoBody)
            Text("推荐面罩：\(MaskSize.recommended(forHeadCircumference: manualCm).title)").font(.xeoHeadline).foregroundStyle(Brand.purple)
            Text("基于面部宽度估算，与软尺实测可能有 1–2 cm 差异。").font(.xeoCaption).foregroundStyle(Brand.caption)
            Button("使用这个结果") { onDone(manualCm, true); dismiss() }.buttonStyle(PrimaryButtonStyle())
            Button("重新测量") { estimator = HeadEstimator(); mode = .scanning }.buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
    }

    private var manual: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !FaceTracking.isSupported {
                Text("这台设备不支持原深感面部测量，请用软尺量一下头围（眉骨上方一圈）后填写。")
                    .font(.xeoBody).foregroundStyle(Brand.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(manualCm)").font(.system(size: 56, weight: .bold)).foregroundStyle(Brand.ink)
                Text("cm").font(.xeoTitle).foregroundStyle(Brand.secondary)
                Spacer()
                Stepper("", value: $manualCm, in: HeadEstimator.range).labelsHidden()
            }
            Button("确定") { onDone(manualCm, false); dismiss() }.buttonStyle(PrimaryButtonStyle())
            if FaceTracking.isSupported {
                Button("改用面部测量") { estimator = HeadEstimator(); mode = .scanning }.buttonStyle(SecondaryButtonStyle())
            }
            Spacer()
        }
    }
}

/// ARKit face tracking behind one small surface so the rest of the app has no ARKit dependency.
enum FaceTracking {
    #if os(iOS) && canImport(ARKit)
    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    /// Front-camera preview that reports the face-mesh width (meters) for every tracked frame.
    struct Preview: UIViewRepresentable {
        let onWidth: (Double) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onWidth: onWidth) }

        func makeUIView(context: Context) -> ARSCNView {
            let view = ARSCNView(frame: .zero)
            view.automaticallyUpdatesLighting = true
            view.session.delegate = context.coordinator
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = false
            view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            return view
        }

        func updateUIView(_ uiView: ARSCNView, context: Context) {
            context.coordinator.onWidth = onWidth
        }

        static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
            uiView.session.pause()
        }

        final class Coordinator: NSObject, ARSessionDelegate {
            var onWidth: (Double) -> Void
            init(onWidth: @escaping (Double) -> Void) { self.onWidth = onWidth }

            func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
                guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked else { return }
                // Only sample a roughly frontal face: the face's forward axis must point at the camera.
                let forward = face.transform.columns.2
                guard abs(forward.x) < 0.35, abs(forward.y) < 0.35 else { return }   // loose on purpose; tune on device
                var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
                for v in face.geometry.vertices {
                    minX = min(minX, v.x)
                    maxX = max(maxX, v.x)
                }
                let width = Double(maxX - minX)
                DispatchQueue.main.async { self.onWidth(width) }
            }
        }
    }
    #else
    static var isSupported: Bool { false }

    struct Preview: View {
        let onWidth: (Double) -> Void
        var body: some View { Text("此设备不支持面部测量").foregroundStyle(Brand.caption) }
    }
    #endif
}
