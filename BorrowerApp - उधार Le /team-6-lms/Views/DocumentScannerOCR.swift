

import SwiftUI
import VisionKit
import Vision

// MARK: - OCR Result

enum OCRDocumentType {
    case pan, aadhaar
}

struct OCRScanResult {
    let extractedNumber: String   
    let rawText: String           
}

// MARK: - VisionKit Scanner (UIViewControllerRepresentable)

struct CardScannerView: UIViewControllerRepresentable {

    let documentType: OCRDocumentType
    let onResult: (OCRScanResult?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(documentType: documentType, onResult: onResult)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let documentType: OCRDocumentType
        let onResult: (OCRScanResult?) -> Void

        init(documentType: OCRDocumentType, onResult: @escaping (OCRScanResult?) -> Void) {
            self.documentType = documentType
            self.onResult = onResult
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            controller.dismiss(animated: true)

            guard scan.pageCount > 0 else {
                onResult(nil)
                return
            }
            let image = scan.imageOfPage(at: 0)
            recognizeText(in: image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onResult(nil)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
            print("❌ Card scan failed: \(error)")
            onResult(nil)
        }

        // MARK: - Vision OCR

        private func recognizeText(in image: UIImage) {
            guard let cgImage = image.cgImage else {
                onResult(nil)
                return
            }

            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self else { return }
                if let error {
                    print("❌ OCR error: \(error)")
                    self.onResult(nil)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let allText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                print("📄 OCR raw text: \(allText)")

                let extracted = self.extract(from: allText, type: self.documentType)
                self.onResult(OCRScanResult(extractedNumber: extracted ?? "", rawText: allText))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-IN", "en-US"]
            request.usesLanguageCorrection = false  

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }

        // MARK: - Extraction Regex

        private func extract(from text: String, type: OCRDocumentType) -> String? {
            switch type {
            case .pan:

                return extractPAN(from: text)
            case .aadhaar:

                return extractAadhaar(from: text)
            }
        }

        private func extractPAN(from text: String) -> String? {

            let normalized = text.replacingOccurrences(of: " ", with: "").uppercased()
            let pattern = "[A-Z]{5}[0-9]{4}[A-Z]{1}"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(normalized.startIndex..., in: normalized)
            if let match = regex.firstMatch(in: normalized, range: range),
               let swiftRange = Range(match.range, in: normalized) {
                return String(normalized[swiftRange])
            }
            return nil
        }

        private func extractAadhaar(from text: String) -> String? {

            let pattern = "\\b[0-9]{4}\\s?[0-9]{4}\\s?[0-9]{4}\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let swiftRange = Range(match.range, in: text) {

                return String(text[swiftRange]).replacingOccurrences(of: " ", with: "")
            }
            return nil
        }
    }
}

// MARK: - OCR from URL (for already-uploaded documents)

struct DocumentOCRExtractor {

    static func extractNumber(from urlString: String, type: OCRDocumentType) async -> OCRScanResult? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let image = UIImage(data: data), let cgImage = image.cgImage {
                return await recognizeText(in: cgImage, type: type)
            }

            if let result = await extractFromPDF(data: data, type: type) {
                return result
            }

            return nil
        } catch {
            print("❌ OCR download error: \(error)")
            return nil
        }
    }

    private static func extractFromPDF(data: Data, type: OCRDocumentType) async -> OCRScanResult? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider),
              pdf.numberOfPages > 0,
              let page = pdf.page(at: 1) else { return nil }

        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.drawPDFPage(page)
        }

        guard let cgImage = image.cgImage else { return nil }
        return await recognizeText(in: cgImage, type: type)
    }

    private static func recognizeText(in cgImage: CGImage, type: OCRDocumentType) async -> OCRScanResult {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let allText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                print("📄 OCR from URL raw text: \(allText)")

                let extracted: String?
                switch type {
                case .pan:
                    extracted = extractPAN(from: allText)
                case .aadhaar:
                    extracted = extractAadhaar(from: allText)
                }

                continuation.resume(returning: OCRScanResult(
                    extractedNumber: extracted ?? "",
                    rawText: allText
                ))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-IN", "en-US"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    private static func extractPAN(from text: String) -> String? {
        let normalized = text.replacingOccurrences(of: " ", with: "").uppercased()
        let pattern = "[A-Z]{5}[0-9]{4}[A-Z]{1}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(normalized.startIndex..., in: normalized)
        if let match = regex.firstMatch(in: normalized, range: range),
           let swiftRange = Range(match.range, in: normalized) {
            return String(normalized[swiftRange])
        }
        return nil
    }

    private static func extractAadhaar(from text: String) -> String? {
        let pattern = "\\b[0-9]{4}\\s?[0-9]{4}\\s?[0-9]{4}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range),
           let swiftRange = Range(match.range, in: text) {
            return String(text[swiftRange]).replacingOccurrences(of: " ", with: "")
        }
        return nil
    }
}

struct KYCValidator {

    static func isValidPAN(_ pan: String) -> Bool {
        let pattern = "^[A-Z]{5}[0-9]{4}[A-Z]{1}$"
        return pan.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidAadhaar(_ number: String) -> Bool {
        guard number.count == 12, number.allSatisfy({ $0.isNumber }) else { return false }
        return verhoeffCheck(number)
    }

    private static func verhoeffCheck(_ number: String) -> Bool {
        let d: [[Int]] = [
            [0,1,2,3,4,5,6,7,8,9],
            [1,2,3,4,0,6,7,8,9,5],
            [2,3,4,0,1,7,8,9,5,6],
            [3,4,0,1,2,8,9,5,6,7],
            [4,0,1,2,3,9,5,6,7,8],
            [5,9,8,7,6,0,4,3,2,1],
            [6,5,9,8,7,1,0,4,3,2],
            [7,6,5,9,8,2,1,0,4,3],
            [8,7,6,5,9,3,2,1,0,4],
            [9,8,7,6,5,4,3,2,1,0]
        ]
        let p: [[Int]] = [
            [0,1,2,3,4,5,6,7,8,9],
            [1,5,7,6,2,8,3,0,9,4],
            [5,8,0,3,7,9,6,1,4,2],
            [8,9,1,6,0,4,3,5,2,7],
            [9,4,5,3,1,2,6,8,7,0],
            [4,2,8,6,5,7,3,9,0,1],
            [2,7,9,3,8,0,6,4,1,5],
            [7,0,4,6,9,1,3,2,5,8]
        ]
        let inv = [0,4,3,2,1,5,6,7,8,9]

        var c = 0
        let digits = number.reversed().compactMap { $0.wholeNumberValue }
        for (i, digit) in digits.enumerated() {
            c = d[c][p[i % 8][digit]]
        }
        return inv[c] == 0
    }
}
