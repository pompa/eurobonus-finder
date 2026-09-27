import SwiftUI

/// Keeps the swipe-back gesture on a NavigationStack screen that hides the
/// system back button (UIKit switches the gesture off with the button). Put it
/// in the background of every screen of the stack, root included, so the
/// gesture's delegate is always a live one.
struct SwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = self
        }

        /// Never on the root: a pop with nothing to pop leaves UIKit stuck.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
