//
//  SettingViewModel.swift
//  Rereminder
//
//  Created by 내꺼다 on 8/8/25.
//

import Foundation

class SettingViewModel: ObservableObject {
    @Published var time: TimeModel
    @Published var timer: Timer?
    
    init(
        time: TimeModel = .init(hour: 0, minute: 0, second: 0),
        timer: Timer? = nil) {
        self.time = time
        self.timer = timer
    }
}
