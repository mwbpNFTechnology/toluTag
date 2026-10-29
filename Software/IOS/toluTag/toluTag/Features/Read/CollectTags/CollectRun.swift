//
//  CollectRun.swift
//  toluTag
//
//  What one collecting run fills in, fixed when it starts: a new list, or
//  more tags at the end of a saved one.
//

import Foundation

struct CollectRun {
    let label: String
    let objectId: String
    let format: CollectTagsViewModel.PhraseFormat
    /// The `{count}` the first tag of this run gets.
    let firstCount: Int
    /// The saved list this run adds to; nil when it makes a new one.
    let base: TagCollection?

    /// The index the first tag of this run gets — after the saved list's.
    var firstIndex: Int { base?.nextIndex ?? 0 }
}
