

import SwiftUI

// MARK: - Sensitive Data Masking

extension String {

    func masked(visibleSuffix: Int = 4) -> String {
        guard count > visibleSuffix else { return self }
        let maskCount = count - visibleSuffix
        return String(repeating: "X", count: maskCount) + suffix(visibleSuffix)
    }
}

// MARK: - Light Theme Card
struct CardBackgroundModifier: ViewModifier {
    var backgroundColor: Color = Color.theme.cardBackground

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(background: Color = Color.theme.cardBackground) -> some View {
        self.modifier(CardBackgroundModifier(backgroundColor: background))
    }

    func placeholder<Content: View>(when condition: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .trailing) {
            self
            if condition {
                placeholder()
                    .allowsHitTesting(false)
            }
        }
    }

    func dismissKeyboardOnTap() -> some View {
        self.background(KeyboardDismissGestureView())
    }

    func dismissKeyboardOnPickerTap() -> some View {
        self.background(KeyboardDismissGestureView())
    }
}

private struct KeyboardDismissGestureView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissUIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private class KeyboardDismissUIView: UIView {
    private var tapGesture: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if let tap = tapGesture, let existingWindow = tap.view {
            existingWindow.removeGestureRecognizer(tap)
            tapGesture = nil
        }

        if let window = self.window, tapGesture == nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            window.addGestureRecognizer(tap)
            tapGesture = tap
        }
    }

    override func removeFromSuperview() {
        if let tap = tapGesture, let window = tap.view {
            window.removeGestureRecognizer(tap)
        }
        tapGesture = nil
        super.removeFromSuperview()
    }

    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .cardStyle()
            .padding(.horizontal, 20)
    }
}

// MARK: - Badged Bell Button
struct BadgedBellButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                .font(.title3)
                .foregroundColor(unreadCount > 0 ? Color(uiColor: .systemBlue) : Color.theme.primaryAccent)
        }
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.theme.textSecondary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(Color.theme.textPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Color.theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.theme.primaryAccent)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Badge Status Style
struct StatusBadge: View {
    let status: ApplicationStatus

    var backgroundColor: Color {
        switch status {
        case .submitted, .underReview, .recommended: return Color.theme.warningBackground
        case .approved, .disbursed: return Color.theme.successBackground
        case .rejected: return Color.theme.dangerBackground
        }
    }

    var body: some View {
        Text(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(status.color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}
// MARK: - Payment Success View
struct PaymentSuccessView: View {
    @State private var animateCheckmark = false
    @State private var animateCircle = false
    @State private var animateText = false

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.theme.success.opacity(0.1), lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateCircle ? 1.0 : 0.8)
                    .opacity(animateCircle ? 1.0 : 0.0)

                Circle()
                    .fill(Color.theme.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateCircle ? 1.0 : 0.5)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.theme.success)
                    .scaleEffect(animateCheckmark ? 1.0 : 0.5)
                    .opacity(animateCheckmark ? 1.0 : 0.0)
            }

            VStack(spacing: 12) {
                Text("Payment Successful!")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(Color.theme.textPrimary)

                Text("Your payment has been processed. A receipt has been added to your notifications.")
                    .font(.body)
                    .foregroundStyle(Color.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .offset(y: animateText ? 0 : 20)
            .opacity(animateText ? 1.0 : 0.0)

            Spacer()

            Button("View Notification") {
                onDone()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.theme.appBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                animateCircle = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.4)) {
                animateCheckmark = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                animateText = true
            }
        }
    }
}
// MARK: - System Share Sheet
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Dotted Line Shape
struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        return path
    }
}

// MARK: - Beautiful Payment Receipt View
struct PaymentReceiptView: View {
    let emi: EMISchedule
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var isGenerating = false

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let d = fmt.date(from: emi.dueDate) {
            fmt.dateStyle = .long
            return fmt.string(from: d)
        }
        return emi.dueDate
    }

    private func formatPaidAt(_ paidAt: String?) -> String {
        guard let paidAt = paidAt else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: paidAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return paidAt
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.theme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 24) {

                            ZStack {
                                Circle()
                                    .fill(Color.theme.success.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.theme.success)
                            }
                            .padding(.top, 40)

                            VStack(spacing: 8) {
                                Text("Payment Successful")
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundStyle(Color.theme.textPrimary)
                                Text("Transaction ID: \(emi.id.uuidString.prefix(8).uppercased())")
                                    .font(.caption)
                                    .foregroundStyle(Color.theme.textSecondary)
                            }

                            Text("₹\(Int(emi.amount).formatted())")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(Color.theme.textPrimary)

                            VStack(spacing: 16) {
                                DottedLine()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .frame(height: 1)
                                    .foregroundStyle(Color.theme.textSecondary.opacity(0.3))

                                DetailRow(label: "Paid On", value: formatPaidAt(emi.paidAt))
                                DetailRow(label: "Due Date", value: formattedDate)
                                DetailRow(label: "Status", value: "Success", color: Color.theme.success)
                                DetailRow(label: "Method", value: "Direct Debit")

                                DottedLine()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .frame(height: 1)
                                    .foregroundStyle(Color.theme.textSecondary.opacity(0.3))

                                DetailRow(label: "Total Paid", value: "₹\(Int(emi.amount).formatted())", isBold: true)
                            }
                            .padding(.vertical, 12)

                            Text("Thank you for your timely payment. It helps maintain your excellent credit score.")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(24)
                        .background(Color.theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
                        .padding(20)

                        Button {
                            generateAndSharePDF()
                        } label: {
                            HStack {
                                if isGenerating {
                                    ProgressView().tint(Color.theme.primaryAccent)
                                } else {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Download PDF")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(Color.theme.primaryAccent)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.theme.primaryAccent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isGenerating)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.theme.primaryAccent)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }

    private func generateAndSharePDF() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let url = renderReceiptPDF()
            DispatchQueue.main.async {
                self.pdfURL = url
                self.isGenerating = false
                self.showShareSheet = true
            }
        }
    }

    private func renderReceiptPDF() -> URL {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let fileName = "Receipt_\(emi.id.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let context = ctx.cgContext

            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

            var y: CGFloat = margin

            UIColor(red: 0.18, green: 0.47, blue: 1.0, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 6))

            let appAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ]
            "CredFlow Go".draw(at: CGPoint(x: margin, y: y), withAttributes: appAttrs)
            y += 20

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            "Payment Receipt".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36

            UIColor.lightGray.setStroke()
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: margin, y: y))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            context.strokePath()
            y += 20

            let amountAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .heavy),
                .foregroundColor: UIColor.black
            ]
            let amountStr = "₹\(Int(emi.amount).formatted())"
            let amountSize = amountStr.size(withAttributes: amountAttrs)
            amountStr.draw(at: CGPoint(x: (pageWidth - amountSize.width) / 2, y: y), withAttributes: amountAttrs)
            y += amountSize.height + 6

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let txnStr = "Transaction ID: \(emi.id.uuidString.prefix(8).uppercased())"
            let txnSize = txnStr.size(withAttributes: subAttrs)
            txnStr.draw(at: CGPoint(x: (pageWidth - txnSize.width) / 2, y: y), withAttributes: subAttrs)
            y += 36

            context.move(to: CGPoint(x: margin, y: y))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            context.strokePath()
            y += 20

            func drawRow(label: String, value: String, bold: Bool = false) {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.gray
                ]
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: bold ? UIFont.systemFont(ofSize: 13, weight: .bold) : UIFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: UIColor.black
                ]
                label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
                let valueSize = value.size(withAttributes: valueAttrs)
                value.draw(at: CGPoint(x: pageWidth - margin - valueSize.width, y: y), withAttributes: valueAttrs)
            }

            drawRow(label: "Paid On", value: formatPaidAt(emi.paidAt)); y += 28
            drawRow(label: "Due Date", value: formattedDate); y += 28
            drawRow(label: "Status", value: "Success"); y += 28
            drawRow(label: "Method", value: "Direct Debit"); y += 28

            context.move(to: CGPoint(x: margin, y: y))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            context.strokePath()
            y += 20

            drawRow(label: "Total Paid", value: "₹\(Int(emi.amount).formatted())", bold: true); y += 40

            let noteAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 11),
                .foregroundColor: UIColor.gray
            ]
            let note = "Thank you for your timely payment. This is a system-generated receipt."
            let noteSize = note.size(withAttributes: noteAttrs)
            note.draw(at: CGPoint(x: (pageWidth - noteSize.width) / 2, y: y), withAttributes: noteAttrs)
        }

        return url
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var color: Color = Color.theme.textPrimary
    var isBold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(isBold ? .bold : .medium)
                .foregroundStyle(color)
        }
    }
}
