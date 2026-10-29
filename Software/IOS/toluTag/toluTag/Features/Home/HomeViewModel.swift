//
//  HomeViewModel.swift
//  toluTag
//
//  Supplies the home screen's two primary actions.
//

import SwiftUI

@Observable
final class HomeViewModel {
    let items: [MenuItem] = [
        MenuItem(
            index: "01",
            title: "write",
            subtitle: "create a key or store data on a tag",
            systemImage: "square.and.pencil",
            accent: Tolu.Palette.lime,
            route: .write
        ),
        MenuItem(
            index: "02",
            title: "read",
            subtitle: "scan a tag to inspect keys and data",
            systemImage: "dot.radiowaves.left.and.right",
            accent: Tolu.Palette.violet,
            route: .read
        )
    ]
}
