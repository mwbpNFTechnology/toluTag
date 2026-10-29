//
//  CollectMode.swift
//  toluTag
//
//  Whether collect tags starts a new list or adds tags to the end of a
//  saved one.
//

import Foundation

enum CollectMode: CaseIterable, Identifiable {
    case newList
    case savedList

    var id: Self { self }

    var title: String {
        switch self {
        case .newList: "new list"
        case .savedList: "continue a list"
        }
    }
}
