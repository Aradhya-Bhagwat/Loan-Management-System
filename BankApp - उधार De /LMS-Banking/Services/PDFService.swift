import Foundation
import UIKit
import WebKit

class PDFService {
    static let shared = PDFService()
    private init() {}

    func generatePDF(fromHTML htmlContent: String, completion: @escaping (Data?) -> Void) {
        DispatchQueue.main.async {
            let webView = WKWebView()

            // Set A4 frame for proper rendering/layout
            webView.frame = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
            webView.loadHTMLString(htmlContent, baseURL: nil)

            let handler = WebViewHandler {
                let renderer = UIPrintPageRenderer()
                renderer.addPrintFormatter(
                    webView.viewPrintFormatter(),
                    startingAtPageAt: 0
                )

                // A4 Size: 8.27 x 11.69 inches (72 points per inch)
                let pageSize = CGSize(width: 595.2, height: 841.8)
                let margin: CGFloat = 20.0

                let printableRect = CGRect(
                    x: margin,
                    y: margin,
                    width: pageSize.width - (margin * 2),
                    height: pageSize.height - (margin * 2)
                )

                let paperRect = CGRect(origin: .zero, size: pageSize)

                renderer.setValue(
                    NSValue(cgRect: paperRect),
                    forKey: "paperRect"
                )

                renderer.setValue(
                    NSValue(cgRect: printableRect),
                    forKey: "printableRect"
                )

                let pdfData = NSMutableData()
                UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)

                for i in 0..<renderer.numberOfPages {
                    UIGraphicsBeginPDFPage()
                    renderer.drawPage(
                        at: i,
                        in: UIGraphicsGetPDFContextBounds()
                    )
                }

                UIGraphicsEndPDFContext()
                completion(pdfData as Data)
            }

            webView.navigationDelegate = handler

            // Keep handler alive
            objc_setAssociatedObject(
                webView,
                "handler",
                handler,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

class WebViewHandler: NSObject, WKNavigationDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Small delay to ensure rendering is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.onFinish()
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        onFinish()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        onFinish()
    }
}
