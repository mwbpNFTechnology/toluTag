//
//  MenuItem.swift
//  toluTag
//
//  A single selectable action on a menu screen (home / write / read).
//

import SwiftUI

struct MenuItem: Identifiable {
    let id = UUID()
    let index: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let route: AppRoute
}
