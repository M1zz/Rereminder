//
//  NextOccasionSheet.swift
//  Rereminder
//
//  "다음 자리가 언제인가요?" — 날짜 하나만 받는 시트.
//
//  ⚠️ 여기서 더 묻지 않는다. 세션을 막 끝낸 사람은 뒷정리 중이고, 그 자리에서 폼을 채우게 하면
//     그냥 닫는다. 필요한 것은 **날짜 하나**뿐이고 나머지(설정·문구)는 방금 쓴 것을 그대로 쓴다.
//
//  왜 모레부터인가: 알림이 **전날 저녁**에 울리므로 내일 자리는 이미 늦었다
//  (`NextOccasionReminder.earliestSelectableDate`).
//

import SwiftUI

struct NextOccasionSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// 방금 끝낸 설정 — 그대로 실어 보낸다.
    let mainSec: Int
    let offsets: [Int]
    /// 거절 유예를 세는 자(완주 총 횟수).
    let completions: Int

    @State private var date: Date = NextOccasionReminder.earliestSelectableDate()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("When's the next one?")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("We'll remind you the evening before, with this setup ready to go.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DatePicker(
                    selection: $date,
                    in: NextOccasionReminder.earliestSelectableDate()...,
                    displayedComponents: .date
                ) {
                    Text("Date")
                }
                .datePickerStyle(.graphical)

                Spacer(minLength: 0)
            }
            .padding(DSSpacing.xl)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DSSpacing.sm) {
                    Button {
                        NextOccasionReminder.book(occasion: date, mainSec: mainSec, offsets: offsets)
                        AnalyticsManager.log(.nextOccasionBooked)
                        dismiss()
                    } label: {
                        Text("Remind me")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.lg)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        NextOccasionReminder.decline(completions: completions)
                        dismiss()
                    } label: {
                        Text("No next one planned")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DSSpacing.xl)
                .padding(.bottom, DSSpacing.lg)
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        NextOccasionReminder.decline(completions: completions)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
        }
    }
}
