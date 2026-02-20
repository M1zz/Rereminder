//
//  TimeModel.swift
//  Toki
//
//  Created by 내꺼다 on 8/8/25.
//

import Foundation

struct TimeModel {
    var hour: Int
    var minute: Int
    var second: Int
    
    var convertedSecond: Int {
        return hour * 3600 + minute * 60 + second
    }
    
    static func fromSecond(_ second: Int) -> TimeModel {
        let hour = second / 3600
        let minute = (second % 3600) / 60
        let remainingSecond = second % 60
        return TimeModel(hour: hour, minute: minute, second: remainingSecond)
    }
}

extension Int {
    var formattedTimeString: String {
        let time = TimeModel.fromSecond(self)
        let minuteString = String(format: "%02d", time.minute)
        let secondString = String(format: "%02d", time.second)
        
        return "\(minuteString):\(secondString)"
    }
}






// 시, min, sec 프로퍼티가 필요
// 전부 sec로 변환
