//
//  RingSound.swift
//  Toki
//
//  Created by POS on 7/8/25.
//

import AudioToolbox
import AVFoundation

/// Sound 혹은 Vibration을 재생하는 함수
func ring() {
    let ringMode = UserDefaults.standard.string(forKey: "ringMode") ?? RingMode.sound.rawValue

    if ringMode == RingMode.vibration.rawValue {
        /// Vibration
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    } else {
        /// Sound
        let soundID: SystemSoundID = 1005
        AudioServicesPlaySystemSound(soundID)
    }
}
