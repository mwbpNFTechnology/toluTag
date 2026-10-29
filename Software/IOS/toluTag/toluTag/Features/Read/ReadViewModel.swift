//
//  ReadViewModel.swift
//  toluTag
//
//  Supplies the read screen's list of actions.
//

import SwiftUI

@Observable
final class ReadViewModel {
    let items: [MenuItem] = [
        MenuItem(
            index: "01",
            title: "scan tag",
            subtitle: "inspect keys, type, origin & data",
            systemImage: "dot.radiowaves.left.and.right",
            accent: Tolu.Palette.violet,
            route: .scanTag
        ),
        MenuItem(
            index: "02",
            title: "read text",
            subtitle: "read a stored string back",
            systemImage: "text.alignleft",
            accent: Tolu.Palette.violet,
            route: .readText
        ),
        MenuItem(
            index: "03",
            title: "sign message",
            subtitle: "eip-191 personal_sign",
            systemImage: "signature",
            accent: Tolu.Palette.sky,
            route: .signMessage
        ),
        MenuItem(
            index: "04",
            title: "sign typed data",
            subtitle: "eip-712 typed data",
            systemImage: "doc.text",
            accent: Tolu.Palette.sky,
            route: .signTypedData
        ),
        MenuItem(
            index: "05",
            title: "collect tags",
            subtitle: "batch-scan addresses to a list",
            systemImage: "list.bullet",
            accent: Tolu.Palette.teal,
            route: .collectTags
        )
    ]
}
