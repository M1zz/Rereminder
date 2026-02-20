//
//  TimerSetupView.swift
//  Rereminder
//
//  Created by xa on 8/31/25.
//

import Foundation
import SwiftUI

struct TimerSetupView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 20) {
            let mainSeconds = screenVM.mainMinutes * 60 + screenVM.mainSeconds

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Picker(
                        "min",
                        selection: Binding<Int>(
                            get: { screenVM.mainMinutes },
                            set: { screenVM.mainMinutes = $0 }
                        )
                    ) {
                        ForEach(0...60, id: \.self) { m in
                            Text("\(m)").font(.title3)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60)

                    Text("min").font(.title3)
                }
                .frame(height: 180)
            }

            TimerButton(
                state: screenVM.timerVM.state,
                onStart: {
                    screenVM.applyCurrentSettings()
                    screenVM.start()
                },
                onPause: { screenVM.pause() },
                onResume: { screenVM.resume() },
                onCancel: { screenVM.cancel() }
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                let presets = Timer.presetOffsetsSec

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pre-alerts").font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        ForEach(presets, id: \.self) { sec in
                            let isDisabled = sec >= mainSeconds
                            let isSelected = screenVM.selectedOffsets.contains(sec)
                            Toggle(
                                "\(sec/60)min",
                                isOn: Binding(
                                    get: { isSelected },
                                    set: { on in
                                        if on {
                                            if !ProGate.canAddPrealert(currentCount: screenVM.selectedOffsets.count) {
                                                showPaywall = true
                                                return
                                            }
                                            screenVM.selectedOffsets.insert(sec)
                                        } else {
                                            screenVM.selectedOffsets.remove(sec)
                                        }
                                        screenVM.showPrealertToast(for: sec, isEnabled: on)
                                    }
                                )
                            )
                            .toggleStyle(.button)
                            .buttonStyle(.bordered)
                            .disabled(isDisabled)
                        }
                    }
                }
            }
        }
        .paywallGate(isPresented: $showPaywall, feature: .unlimitedPrealerts)
    }
}
