//
//  ToastManager.swift
//  Rereminder
//
//  Created by POS on 8/25/25.
//

import Foundation
import SwiftUI

final class ToastManager: ObservableObject {
    @Published private(set) var current: Toast?
    private var queue: [Toast] = []
    private var isShowing = false

    func show(_ toast: Toast) {
        guard isToastEnabled() else { return }

        queue.append(toast)
        
        if Thread.isMainThread {
            displayNext()
        } else {
            DispatchQueue.main.async { self.displayNext() }
        }
    }

    private func isToastEnabled() -> Bool {
        let d = UserDefaults.standard
        if d.object(forKey: "toastEnabled") == nil { return true }
        return d.bool(forKey: "toastEnabled")
    }
    
    // queue handling
    private func displayNext() {
        guard !isShowing, let next = queue.first else { return }
        isShowing = true
        current = next
        DispatchQueue.main.asyncAfter(deadline: .now() + next.duration) { [weak self] in
            guard let self else { return }
            self.queue.removeFirst()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                self.current = nil
            }
            self.isShowing = false
            self.displayNext()
        }
    }
}
