import CoreGraphics
// 맨 앞 일반 창의 주인과, 그 주인의 가장 큰 창 영역
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
let normal = list.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
if let f = normal.first {
    let owner = f[kCGWindowOwnerName as String] as? String ?? "?"
    let mine = normal.filter { ($0[kCGWindowOwnerName as String] as? String) == owner }
    let big = mine.max { a, b in
        let x = a[kCGWindowBounds as String] as! [String: Double], y = b[kCGWindowBounds as String] as! [String: Double]
        return x["Width"]! * x["Height"]! < y["Width"]! * y["Height"]! }!
    let b = big[kCGWindowBounds as String] as! [String: Double]
    print("\(owner) \(Int(b["X"]!)),\(Int(b["Y"]!)),\(Int(b["Width"]!)),\(Int(b["Height"]!))")
}
