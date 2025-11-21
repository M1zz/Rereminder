//
//  SetNotiViewModel.swift
//  Toki
//
//  Created by 내꺼다 on 8/8/25.
//

import Foundation

class SetNotiViewModel: ObservableObject {
    @Published var maxTimeInSeconds: Int
    @Published var notiTime: TimeModel
    @Published var selectedMinutes: Set<Int> = []  // 여러 개 선택 가능

    var maxSelectableSeconds: Int {
            return max(0, maxTimeInSeconds - 60)
        }

    var maxSelectableTimeModel: TimeModel {
        return TimeModel.fromSecond(maxSelectableSeconds)
    }

    init(maxTimeInSeconds: Int) {
        self.maxTimeInSeconds = maxTimeInSeconds
        self.notiTime = TimeModel(hour: 0, minute: 0, second: 0)
    }
}





// 타이머 시간 제한
