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

    /// ⚠️ 줄(`queue`)은 메인 스레드에서만 만진다. 예전에는 넣기만 부른 스레드에서 해서, 메인 밖에서
    ///    부르면 메인이 꺼내는 순간과 겹쳐 배열이 깨질 수 있었다.
    func show(_ toast: Toast) {
        guard isToastEnabled() else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show(toast) }
            return
        }
        queue.append(toast)
        displayNext()
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
