//
//  ToastViewModifier.swift
//  Rereminder
//
//  Created by POS on 8/25/25.
//

import Foundation
import SwiftUI

private struct ToastViewModifier: ViewModifier {
    @ObservedObject var manager: ToastManager

    func body(content: Content) -> some View {
        ZStack {
            content
            if let toast = manager.current {
                VStack {
                    Spacer()
                    HStack {
                        Text(toast.message)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.9))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                            .shadow(radius: 6, y: 3)
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: .infinity)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(
                    .spring(response: 0.35, dampingFraction: 0.9),
                    value: toast.id
                )
            }
        }
    }
}

extension View {
    func toast(_ manager: ToastManager) -> some View {
        modifier(ToastViewModifier(manager: manager))
    }
}
