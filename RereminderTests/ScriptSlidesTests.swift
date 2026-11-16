import XCTest
@testable import Rereminder

final class ScriptSlidesTests: XCTestCase {
    func test_splitsOnBlankLines() {
        let slides = ScriptSlides.split("첫 장\n둘째 줄\n\n   \n두 번째 장\n\n\n세 번째 장\n")
        XCTAssertEqual(slides, ["첫 장\n둘째 줄", "두 번째 장", "세 번째 장"])
    }

    func test_noBlankLineIsOneSlide() {
        XCTAssertEqual(ScriptSlides.split("한 줄\n두 줄").count, 1)
        XCTAssertEqual(ScriptSlides.split("  \n\n").count, 0)
    }

    func test_timeFollowsTextLength() {
        let long = String(repeating: "가", count: 300)
        let short = String(repeating: "나", count: 100)
        let slides = [long, short]
        XCTAssertEqual(ScriptSlides.position(in: slides, progress: 0).index, 0)
        XCTAssertEqual(ScriptSlides.position(in: slides, progress: 0.7).index, 0)
        XCTAssertEqual(ScriptSlides.position(in: slides, progress: 0.8).index, 1)
        XCTAssertEqual(ScriptSlides.position(in: slides, progress: 1).index, 1)
        XCTAssertEqual(ScriptSlides.position(in: slides, progress: 0.375).within, 0.5, accuracy: 0.001)
    }

    func test_veryShortSlideStillGetsTime() {
        let slides = [String(repeating: "가", count: 1000), "끝"]
        // 바닥 몫 20자 — 마지막 2% 가까이는 짧은 장표를 보여 준다
        XCTAssertEqual(ScriptSlides.position(in: slides, progress: 0.99).index, 1)
    }

    func test_manualAheadHoldsUntilTimeCatchesUp() {
        let manual = ManualSlide(index: 3, autoAtOverride: 1)
        XCTAssertEqual(manual.resolved(auto: 1), 3)
        XCTAssertEqual(manual.resolved(auto: 2), 3)
        XCTAssertNil(manual.resolved(auto: 3))
    }

    func test_manualBackHoldsUntilNextSlideChange() {
        let manual = ManualSlide(index: 0, autoAtOverride: 2)
        XCTAssertEqual(manual.resolved(auto: 2), 0)
        XCTAssertNil(manual.resolved(auto: 3))
    }
}
