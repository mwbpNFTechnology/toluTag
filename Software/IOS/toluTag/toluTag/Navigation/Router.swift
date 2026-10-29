//
//  Router.swift
//  toluTag
//
//  Owns the app's navigation path. Injected into the environment so any screen
//  can push or pop without owning its own navigation stack.
//

import SwiftUI

@Observable
final class Router {
    var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path.removeAll()
    }
}
