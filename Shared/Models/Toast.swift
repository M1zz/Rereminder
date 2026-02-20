//
//  Toast.swift
//  Rereminder
//
//  Created by POS on 8/24/25.
//

import Foundation

enum ToastType { case info, success, warning, error }

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval

    init(
        _ message: String,
        type: ToastType = .info,
        duration: TimeInterval = 1.6
    ) {
        self.message = message
        self.type = type
        self.duration = duration
    }
}
