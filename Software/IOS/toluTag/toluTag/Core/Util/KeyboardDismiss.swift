//
//  KeyboardDismiss.swift
//  toluTag
//

import SwiftUI

extension View {
    /// Dismisses the keyboard by resigning the first responder.
    func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}
