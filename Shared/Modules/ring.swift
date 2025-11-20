//
//  ring.swift
//  Toki
//
//  Created by xa on 8/28/25.
//

import Foundation

enum RingMode: String, CaseIterable, Identifiable {
    case sound = "소리"
    case vibration = "진동"

    var id: String { rawValue }
}
