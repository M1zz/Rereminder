import AppKit
// "4:59" 를 시스템 둥근 굵은 글꼴의 윤곽선으로 뽑아 SVG path 로 찍는다(아이콘 레이어는 글꼴을 싣지 못한다).
let text = CommandLine.arguments[1]
let size = CGFloat(Double(CommandLine.arguments[2])!)
let base = NSFont.systemFont(ofSize: size, weight: .bold)
let desc = base.fontDescriptor.withDesign(.rounded)!
let font = NSFont(descriptor: desc, size: size)!
let attr = NSAttributedString(string: text, attributes: [.font: font, .kern: -size * 0.01])
let line = CTLineCreateWithAttributedString(attr)
let path = CGMutablePath()
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let count = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: count)
    var positions = [CGPoint](repeating: .zero, count: count)
    CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
    CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
    let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
    for i in 0..<count {
        if let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
            path.addPath(g, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
        }
    }
}
let box = path.boundingBoxOfPath
// 가운데(512,512)에 놓고 y 를 뒤집는다(SVG 는 아래로 자란다)
var t = CGAffineTransform(translationX: 512 - box.midX, y: 512 + box.midY).scaledBy(x: 1, y: -1)
var d = ""
func f(_ p: CGPoint) -> String { let q = p.applying(t); return String(format: "%.2f %.2f", q.x, q.y) }
path.applyWithBlock { e in
    let p = e.pointee.points
    switch e.pointee.type {
    case .moveToPoint: d += "M\(f(p[0]))"
    case .addLineToPoint: d += "L\(f(p[0]))"
    case .addQuadCurveToPoint: d += "Q\(f(p[0])) \(f(p[1]))"
    case .addCurveToPoint: d += "C\(f(p[0])) \(f(p[1])) \(f(p[2]))"
    case .closeSubpath: d += "Z"
    @unknown default: break
    }
}
FileHandle.standardError.write("width \(box.width) height \(box.height)\n".data(using: .utf8)!)
print(d)
