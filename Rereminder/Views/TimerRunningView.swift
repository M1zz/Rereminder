//
//  TimerRunningView.swift
//  Rereminder
//
//  Created by xa on 8/31/25.
//

import Foundation
import SwiftUI

struct TimerRunningView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel

    private var totalSec: Int { screenVM.configuredMainSeconds }
    private var remaining: TimeInterval { screenVM.remaining }
    private var ratio: CGFloat {
        guard totalSec > 0 else { return 0 }
        return CGFloat(max(0, min(1, remaining / TimeInterval(totalSec))))
    }
    private var markers: [CGFloat] {
        guard totalSec > 0 else { return [] }
        return screenVM.sortedOffsetsDesc.reversed()
            .filter { 0 < $0 && $0 < totalSec }
            .map { CGFloat($0) / CGFloat(totalSec) }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Clock(
                    remaining: screenVM.remaining,
                    total: TimeInterval(totalSec),
                    markers: markers,
                )
                
                Text(screenVM.timeString(from: screenVM.timerVM.remaining))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            TimerButton(
                state: screenVM.timerVM.state,
                onStart: { screenVM.start() },
                onPause: { screenVM.pause() },
                onResume: { screenVM.resume() },
                onCancel: {
                    screenVM.cancel()
                }
            )
        }
    }
}
