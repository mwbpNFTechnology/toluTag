//
//  ActivityView.swift
//  toluTag
//
//  A thin SwiftUI wrapper over UIActivityViewController for sharing / saving a
//  file (e.g. an exported tags.json).
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
