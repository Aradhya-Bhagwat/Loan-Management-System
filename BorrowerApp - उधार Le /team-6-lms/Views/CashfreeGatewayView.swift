import SwiftUI
import WebKit

struct CashfreeGatewayView: View {
    let amount: Double
    let onComplete: (String, String, String) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var paymentSessionId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // IMPORTANT: In a production app, Client ID and Secret should NEVER be hardcoded.
    // They should be handled by your backend.
    private let clientId = "TEST"
    private let clientSecret = "cfsk"

    var body: some View {
        NavigationStack {
            ZStack {
                if let sessionId = paymentSessionId {
                    CashfreeWebView(
                        paymentSessionId: sessionId,
                        onSuccess: { orderId, paymentId in
                            onComplete(orderId, paymentId, "verified_cf")
                            dismiss()
                        },
                        onFailure: {
                            onCancel()
                            dismiss()
                        }
                    )
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Initialization Failed")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            createOrder()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Preparing Secure Checkout...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Cashfree Secure Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            createOrder()
        }
    }

    private func createOrder() {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "https://sandbox.cashfree.com/pg/orders") else {
            self.errorMessage = "Internal Error: Invalid URL"
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-08-01", forHTTPHeaderField: "x-api-version")
        request.setValue(clientId, forHTTPHeaderField: "x-client-id")
        request.setValue(clientSecret, forHTTPHeaderField: "x-client-secret")
        
        let orderId = "ORD_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(4).uppercased())"
        
        // Sandbox logic: If amount is > 50,000, use 10,000 to avoid sandbox limits.
        let amountToRequest = amount > 50000 ? 10000.0 : amount
        
        print("🛠️ Cashfree Order: Original=₹\(amount), Requested=₹\(amountToRequest)")
        
        let body: [String: Any] = [
            "order_amount": Double(String(format: "%.2f", amountToRequest)) ?? amountToRequest,
            "order_currency": "INR",
            "order_id": orderId,
            "customer_details": [
                "customer_id": "cust_\(Int(Date().timeIntervalSince1970))",
                "customer_phone": "9999999999",
                "customer_email": "test@cashfree.com"
            ],
            "order_meta": [
                "return_url": "https://credflow-borrower.com/success?order_id={order_id}"
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Network Error: \(error.localizedDescription)")
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "No response from server"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "Empty response from server"
                    return
                }
                
                let rawResponse = String(data: data, encoding: .utf8) ?? "Unknown"
                print("📩 Cashfree Response (Status \(httpResponse.statusCode)): \(rawResponse)")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                            if let sessionId = json["payment_session_id"] as? String {
                                self.paymentSessionId = sessionId
                            } else {
                                self.errorMessage = "Payment session ID missing in response"
                            }
                        } else {
                            let message = json["message"] as? String ?? "Error \(httpResponse.statusCode)"
                            self.errorMessage = "Cashfree Error: \(message)"
                        }
                    } else {
                        self.errorMessage = "Failed to parse server response"
                    }
                } catch {
                    self.errorMessage = "Parsing Error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct CashfreeWebView: UIViewRepresentable {
    let paymentSessionId: String
    let onSuccess: (String, String) -> Void
    let onFailure: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Load Cashfree Checkout
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
            <style>
                body { margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; background-color: #ffffff; }
                #cf-loader { font-family: -apple-system, BlinkMacSystemFont, sans-serif; color: #666; }
            </style>
        </head>
        <body>
            <div id="cf-loader">Initializing Payment...</div>
            <script>
                window.onload = function() {
                    try {
                        const cashfree = Cashfree({
                            mode: "sandbox"
                        });
                        cashfree.checkout({
                            paymentSessionId: "\(paymentSessionId)",
                            redirectTarget: "_self"
                        });
                        document.getElementById('cf-loader').style.display = 'none';
                    } catch (e) {
                        document.getElementById('cf-loader').innerText = 'SDK Load Error: ' + e.message;
                    }
                };
            </script>
        </body>
        </html>
        """
        // Using nil baseURL or a generic one can sometimes avoid origin issues if the script is absolute
        webView.loadHTMLString(html, baseURL: URL(string: "https://sdk.cashfree.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: CashfreeWebView

        init(_ parent: CashfreeWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                print("🔗 Navigating to: \(url)")
                
                // Detection logic for success redirect
                if url.contains("success") || url.contains("order_id=") {
                    let components = URLComponents(string: url)
                    let orderId = components?.queryItems?.first(where: { $0.name == "order_id" })?.value ?? "CF_ORD_SUCCESS"
                    parent.onSuccess(orderId, "pay_cf_\(UUID().uuidString.prefix(6))")
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
