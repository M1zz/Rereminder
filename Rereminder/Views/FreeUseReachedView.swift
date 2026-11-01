//
//  FreeUseReachedView.swift
//  Rereminder
//
//  무료 기간의 문턱(`FreeUse`)에 닿았을 때 앱을 열면 **한 번** 뜨는 화면.
//
//  순서가 이 화면의 전부다 — 지금까지 쓴 것 → 그대로인 것 → 여기서부터 값을 받는 것.
//  ⚠️ 주 버튼은 "계속 쓰기"다. 닫아도 잃는 것이 없다는 말이 파는 말보다 앞에 있어야 한다.
//

import SwiftUI

struct FreeUseReachedView: View {
    let onSeePlans: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("You've used Rereminder on \(FreeUse.days) days")
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your timers, pre-alerts, last setup, overtime and everything you've saved stay free.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text("From here, paid plans cover more than \(ProGate.freeSavedSetups) saved setups, older history, and Session Mode after your remaining free runs.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Keep using for free")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onSeePlans()
                    dismiss()
                } label: {
                    Text("See plans")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
        }
    }
}
