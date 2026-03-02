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
            }
        }
    }
}
