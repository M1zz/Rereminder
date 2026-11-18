import CoreGraphics
import Foundation
let a = CommandLine.arguments
let p = CGPoint(x: Double(a[1])!, y: Double(a[2])!); let total = Int32(a[3])!
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
usleep(200_000)
let steps: Int32 = 12
for _ in 0..<steps {
    CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: total / steps, wheel2: 0, wheel3: 0)!.post(tap: .cghidEventTap)
    usleep(25_000)
}
