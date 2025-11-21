//
//  tokiApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import SwiftUI

@main
struct tokiApp: App {
    init() {
        // WatchConnectivity 초기화
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)

        }
        .modelContainer(for: [Timer.self, TimerRecord.self])
    }
}
