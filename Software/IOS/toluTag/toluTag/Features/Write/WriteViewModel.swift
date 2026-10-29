//
//  WriteViewModel.swift
//  toluTag
//
//  Supplies the write screen's list of actions.
//

import SwiftUI

@Observable
final class WriteViewModel {
    let items: [MenuItem] = [
        MenuItem(
            index: "01",
            title: "create key",
            subtitle: "generate a secp256k1 key, with or without a pin",
            systemImage: "key",
            accent: Tolu.Palette.lime,
            route: .createKey
        ),
        MenuItem(
            index: "02",
            title: "write text",
            subtitle: "store a string on a tag",
            systemImage: "textformat",
            accent: Tolu.Palette.lime,
            route: .writeText
        ),
        MenuItem(
            index: "03",
            title: "delete",
            subtitle: "remove an object from a tag",
            systemImage: "trash",
            accent: Tolu.Palette.coral,
            route: .deleteObject(nil)
        )
    ]
}
