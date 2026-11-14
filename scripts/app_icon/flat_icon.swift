import AppKit
// 사용: swift scripts/app_icon/flat_icon.swift Rereminder/AppIcon.icon/Assets <out.png> <light|dark|tinted>
// 워치·App Clip 아이콘(appiconset)은 Icon Composer 문서를 못 쓰므로 같은 SVG 로 꽉 찬 사각 PNG 를 만든다. 워치=dark, 클립=light·dark·tinted.
let a = CommandLine.arguments; let dir = a[1], out = a[2], mode = a[3]
let N = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: N, pixelsHigh: N, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = NSRect(x: 0, y: 0, width: N, height: N)
let (top, bottom): (NSColor, NSColor) = mode == "light"
  ? (NSColor(displayP3Red: 1, green: 1, blue: 1, alpha: 1), NSColor(displayP3Red: 0.906, green: 0.922, blue: 0.965, alpha: 1))
  : (NSColor(displayP3Red: 0.078, green: 0.090, blue: 0.157, alpha: 1), NSColor(displayP3Red: 0.016, green: 0.020, blue: 0.043, alpha: 1))
NSGradient(starting: bottom, ending: top)!.draw(in: rect, angle: 90)
let digits = mode == "light" ? "digits.svg" : "digits-dark.svg"
for name in ["ring.svg", "bells.svg", digits] {
  NSImage(contentsOfFile: "\(dir)/\(name)")!.draw(in: rect)
}
NSGraphicsContext.restoreGraphicsState()
var data = rep.representation(using: .png, properties: [:])!
if mode == "tinted" {
  // 틴트 아이콘은 회색조로 둔다(시스템이 색을 입힌다)
  let ci = CIImage(data: data)!.applyingFilter("CIPhotoEffectMono")
  let ctx = CIContext(); data = ctx.pngRepresentation(of: ci, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())!
}
try! data.write(to: URL(fileURLWithPath: out))
