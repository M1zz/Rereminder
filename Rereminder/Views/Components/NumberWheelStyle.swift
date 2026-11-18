import SwiftUI

/// 숫자를 고르는 휠. 아이폰·아이패드·비전에서는 휠이고, **맥에서는 메뉴**다.
///
/// ⚠️ 맥(Mac Catalyst, "Mac에 최적화")에서 `.pickerStyle(.wheel)` 을 쓰지 말 것 — `UIPickerView` 는 그 모드에서
/// 지원되지 않아 화면에 올라가는 순간 예외를 던지고 **앱이 죽는다**(2.3.12 까지 맥에서 가운데 시간을 누르면 죽었다).
/// 휠이 필요한 자리는 `.pickerStyle(.wheel)` 대신 이것을 쓴다.
extension View {
    @ViewBuilder
    func numberWheelStyle(width: CGFloat = 100, height: CGFloat? = nil) -> some View {
        #if targetEnvironment(macCatalyst)
        self.pickerStyle(.menu)
            .labelsHidden()
            .frame(width: width)
        #else
        self.pickerStyle(.wheel)
            .frame(width: width, height: height)
        #endif
    }
}
