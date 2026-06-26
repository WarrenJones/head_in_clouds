import SwiftUI

#if os(iOS) && canImport(VisionKit) && canImport(Vision)
import Vision
@preconcurrency import VisionKit

struct BoardingPassScannerView: UIViewControllerRepresentable {
    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    let onResult: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        private let onResult: (String) -> Void
        private let onCancel: () -> Void

        init(onResult: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onResult = onResult
            self.onCancel = onCancel
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            controller.dismiss(animated: true)
            let text = Self.recognizeText(from: scan)
            onResult(text)
        }

        private static func recognizeText(from scan: VNDocumentCameraScan) -> String {
            var lines: [String] = []

            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                guard let cgImage = image.cgImage else { continue }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US", "zh-Hans"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])

                let pageLines = request.results?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
                lines.append(contentsOf: pageLines)
            }

            return lines.joined(separator: "\n")
        }
    }
}
#else
struct BoardingPassScannerView: View {
    static var isSupported: Bool { false }

    let onResult: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        Text("Scanner is unavailable on this platform.")
            .onAppear(perform: onCancel)
    }
}
#endif
