//
//  WhatsNewView.swift
//  Rereminder
//
//  업데이트 뒤 처음 열 때 **한 번** 뜨는 "새로 생긴 것" 시트. 설정 ▸ Help ▸ What's New 에서 다시 연다.
//
//  ⚠️ **처음 받은 사람에게는 뜨지 않는다.** 그 사람은 온보딩이 맞이하고, 본 것으로 표시만 해 둔다
//     (`WhatsNewAudience`). 새로 온 사람에게 "새로워졌어요"는 무슨 말인지 알 수 없는 말이다.
//  ⚠️ 혜택 변경 안내(창단 후원자·개편 전 무료)가 뜨는 차례면 양보하고 다음 실행에 온다 —
//     그 안내는 그날이 아니면 뜻이 줄지만 이 안내는 아니다(`TimerUnifiedView.setupOnAppear`).
//  ⚠️ 내용은 **이번 버전에 실제로 들어간 사용자 기능**만 적는다. 내용을 바꿀 때 `WhatsNewContent.version` 도
//     같이 올릴 것 — 안 올리면 업데이트한 사람은 이미 본 것으로 기록돼 새 안내를 한 번도 못 본다.
//

import SwiftUI

enum WhatsNewContent {
    /// 이 안내가 소개하는 버전. 무관한 버전 올림에서는 다시 뜨지 않도록 앱 버전이 아니라 내용 기준으로 고정한다.
    static let version = "2.3.4"
    /// 마지막으로 본 안내의 버전.
    static let lastSeenKey = "whatsNew.lastSeenVersion"
}

/// 앱을 연 사람이 어느 쪽인지 — 처음 온 사람인가, 안내를 아직 못 본 쓰던 사람인가. (순수 함수, 테스트 대상)
enum WhatsNewAudience: Equatable {
    /// 오늘 처음 받은 사람. 온보딩이 맞이하고, 안내는 본 것으로 표시만 한다.
    case newcomer
    /// 쓰던 사람인데 이번 안내를 아직 못 봤다.
    case returningNeedsWhatsNew
    /// 쓰던 사람이고 이미 봤다.
    case returning

    static func resolve(hasSeenOnboarding: Bool,
                        lastSeenVersion: String?,
                        currentVersion: String = WhatsNewContent.version) -> WhatsNewAudience {
        guard hasSeenOnboarding else { return .newcomer }
        return lastSeenVersion == currentVersion ? .returning : .returningNeedsWhatsNew
    }
}

struct WhatsNewView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "gift.fill")
                            .font(.system(.largeTitle))
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                            .padding(.top, 28)
                            .accessibilityHidden(true)

                        Text("What's New")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        featureRow(symbol: "checkmark.seal.fill",
                                   title: "See your benefits",
                                   detail: "With Pro or Remember, tap it in Settings to see what is unlocked and how much you use it.")
                        featureRow(symbol: "giftcard",
                                   title: "Redeem a code in the app",
                                   detail: "Got a code? Use it in Settings or on the upgrade screen.")
                        featureRow(symbol: "map",
                                   title: "See what's coming",
                                   detail: "Settings now shows what we plan to build next. Tell us what you want.")
                        featureRow(symbol: "accessibility",
                                   title: "Easier for everyone",
                                   detail: "Numbers roll smoothly, Voice Control knows every timer button, and alerts are clear without color.")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }

            Button {
                onClose()
            } label: {
                Text("Got it")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func featureRow(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
