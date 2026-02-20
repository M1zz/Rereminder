//
//  tokiApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import SwiftUI

@main
struct tokiApp: App {
    @StateObject private var storeManager = StoreManager.shared

    init() {
        // WatchConnectivity 초기화
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(storeManager)
        }
        .modelContainer(for: [Timer.self, TimerRecord.self])
    }
}
