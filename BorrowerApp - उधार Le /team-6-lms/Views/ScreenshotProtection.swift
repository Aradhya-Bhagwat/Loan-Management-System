

import SwiftUI
import UIKit

// MARK: - SwiftUI View Modifier

extension View {

    func screenshotProtected() -> some View {
        SecureViewWrapper { self }
    }
}

// MARK: - Secure Wrapper

private struct SecureViewWrapper<Content: View>: View {
    let content: Content

    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SecureRepresentable(content: content)
    }
}

// MARK: - UIViewRepresentable

private struct SecureRepresentable<Content: View>: UIViewRepresentable {
    let content: Content

    func makeUIView(context: Context) -> SecureFieldContainer {
        let container = SecureFieldContainer()
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.embed(view: host.view)
        context.coordinator.host = host
        return container
    }

    func updateUIView(_ uiView: SecureFieldContainer, context: Context) {
        context.coordinator.host?.rootView = content
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var host: UIHostingController<Content>?
    }
}

// MARK: - Secure Container UIView

final class SecureFieldContainer: UIView {

    private let secureField: UITextField = {
        let tf = UITextField()
        tf.isSecureTextEntry = true
        tf.isUserInteractionEnabled = false
        tf.backgroundColor = .clear
        return tf
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSecureField()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSecureField()
    }

    private func setupSecureField() {

        addSubview(secureField)
        secureField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureField.topAnchor.constraint(equalTo: topAnchor),
            secureField.bottomAnchor.constraint(equalTo: bottomAnchor),
            secureField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func embed(view: UIView) {

        guard let protectedLayer = secureField.layer.sublayers?.first else {

            addSubview(view)
            pinToEdges(view)
            DispatchQueue.main.async { [weak self] in
                self?.moveToSecureLayer(view)
            }
            return
        }
        moveIntoLayer(protectedLayer, view: view)
    }

    private func moveToSecureLayer(_ view: UIView) {
        guard let protectedLayer = secureField.layer.sublayers?.first else { return }
        view.removeFromSuperview()
        moveIntoLayer(protectedLayer, view: view)
    }

    private func moveIntoLayer(_ layer: CALayer, view: UIView) {

        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.frame = bounds
        layer.addSublayer(view.layer)

        addSubview(view)
        pinToEdges(view)
    }

    private func pinToEdges(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        secureField.layer.sublayers?.first?.frame = bounds
    }
}
