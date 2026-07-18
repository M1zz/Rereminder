//
//  PresentationContainerView.swift
//  Rereminder
//
//  Created by Claude on 2/28/26.
//

import SwiftUI

struct PresentationContainerView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel

    var body: some View {
        Group {
            switch screenVM.state {
            case .idle, .finished:
                PresentationSetupView()
            case .running, .paused, .overtime:
                PresentationDisplayView()
                    // 발표 진행 중에는 몰입을 위해 하단 바 숨김
                    .toolbar(.hidden, for: .bottomBar)
            }
        }
    }
}
