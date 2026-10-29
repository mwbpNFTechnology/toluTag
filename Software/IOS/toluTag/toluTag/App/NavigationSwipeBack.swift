//
//  NavigationSwipeBack.swift
//  toluTag
//
//  Restores the edge-swipe-to-go-back gesture on every screen. SwiftUI disables
//  the interactive pop gesture whenever the navigation bar is hidden (which every
//  screen here does via `.toolbar(.hidden)`), so we re-attach ourselves as the
//  gesture's delegate and allow it whenever there's something to pop back to.
//

import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
