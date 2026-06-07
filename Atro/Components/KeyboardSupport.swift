import SwiftUI
import UIKit

enum Keyboard {
    @MainActor
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(KeyboardTapDismissInstaller())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        Keyboard.dismiss()
                    }
                }
            }
    }
}

private struct KeyboardTapDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostView = uiView

        DispatchQueue.main.async {
            context.coordinator.installGestureIfNeeded()
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.removeGesture()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var hostView: UIView?
        weak var installedView: UIView?

        private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func installGestureIfNeeded() {
            guard let targetView = hostView?.window else {
                return
            }

            guard installedView !== targetView else {
                return
            }

            removeGesture()
            targetView.addGestureRecognizer(tapGestureRecognizer)
            installedView = targetView
        }

        func removeGesture() {
            installedView?.removeGestureRecognizer(tapGestureRecognizer)
            installedView = nil
        }

        @objc
        private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else {
                return
            }

            Task { @MainActor in
                Keyboard.dismiss()
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else {
                return true
            }

            return !touchedView.isWithinTextInput
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIView {
    var isWithinTextInput: Bool {
        sequence(first: self, next: \.superview).contains { view in
            view is UITextField || view is UITextView
        }
    }
}

extension View {
    func liftKeyboardDismissable() -> some View {
        modifier(KeyboardDismissModifier())
    }
}
