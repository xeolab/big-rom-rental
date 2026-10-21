import SwiftUI
import RentalKit
#if os(iOS)
import AVFoundation
import UIKit
#endif

/// In-app 「扫一扫」: scans `xeorental://` QR codes (柜机入口 / Rom 激活 / 续租).
/// A paste field is the fallback for the simulator or a device without camera permission.
struct ScannerScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var manual = ""
    @State private var handled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("对准柜机或 Rom 屏幕上的二维码").font(.xeoBody).foregroundStyle(Brand.secondary)
            QRCameraView { code in
                guard !handled else { return }
                handled = true
                model.open(text: code)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: Brand.corner))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Brand.purpleTint, lineWidth: 3).padding(60))
            VStack(alignment: .leading, spacing: 8) {
                Text("无法扫码？粘贴二维码内容").font(.xeoCaption).foregroundStyle(Brand.caption)
                HStack {
                    TextField("xeorental://…", text: $manual).font(.xeoBody)
                    Button("打开") { model.open(text: manual) }.font(.xeoHeadline).disabled(manual.isEmpty)
                }
                .xeoCard()
            }
            Spacer()
        }
        .padding(Brand.gutter)
        .background(Brand.paper)
        .navigationTitle("扫一扫")
        .xeoInlineTitle()
        .onAppear { handled = false }
    }
}

#if os(iOS)
/// AVFoundation QR reader wrapped for SwiftUI.
struct QRCameraView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let c = ScannerController()
        c.onCode = onCode
        return c
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {
        controller.onCode = onCode
    }

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var preview: AVCaptureVideoPreviewLayer?
        private let message = UILabel()

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            message.textColor = .white
            message.font = .systemFont(ofSize: 15)
            message.numberOfLines = 0
            message.textAlignment = .center
            message.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(message)
            NSLayoutConstraint.activate([
                message.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                message.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            ])
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { granted ? self.configure() : self.show("需要相机权限：请在「设置 › XEO 租赁」中允许访问相机") }
            }
        }

        private func show(_ text: String) { message.text = text }

        private func configure() {
            guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { show("此设备没有可用的相机"); return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { show("无法启动扫码"); return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            preview = layer
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() } }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let code = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            session.stopRunning()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCode?(code)
        }
    }
}
#else
struct QRCameraView: View {
    let onCode: (String) -> Void
    var body: some View { Text("相机仅在 iPhone 上可用").foregroundStyle(.white) }
}
#endif
