//
//  GuideBookView.swift
//  Rereminder
//
//  설정 ▸ **가이드북.** 첫 실행의 그림·해 보기와 기능 수업을 언제든 다시 본다.
//  여기서 다시 보는 것은 진짜 다이얼을 바꾸지 않는다.
//

import SwiftUI

struct GuideBookView: View {
    private enum Replay: Identifiable {
        case intro, practice, feature(FeatureLesson)

        var id: String {
            switch self {
            case .intro: return "intro"
            case .practice: return "practice"
            case .feature(let lesson): return lesson.rawValue
            }
        }
    }

    @State private var replay: Replay?

    var body: some View {
        List {
            Section(footer: Text("See the animations and try things again anytime.").font(.body)) {
                row(String(localized: "How it works"), symbol: "play.circle.fill", .intro)
                row(String(localized: "Try the dial"), symbol: "hand.draw.fill", .practice)
                ForEach(FeatureLesson.allCases) { lesson in
                    row(lesson.title, symbol: lesson.symbol, .feature(lesson))
                }
            }
        }
        .navigationTitle("How to Use This App")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $replay) { item in
            switch item {
            case .intro:
                BlankStartIntro(buttonTitle: String(localized: "Got it"), onFinish: { replay = nil })
            case .practice:
                BlankStartPractice(onFinish: { _ in replay = nil })
            case .feature(let lesson):
                FeatureLessonView(lesson: lesson, onClose: { replay = nil })
            }
        }
    }

    private func row(_ title: String, symbol: String, _ item: Replay) -> some View {
        Button {
            replay = item
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.primary)
    }
}

/// 첫 실행을 처음부터 다시 본다: 그림 → 해 보기. 고른 자리를 다이얼에 올리지는 않는다(지금 설정을 덮지 않는다).
struct IntroReplayView: View {
    let onClose: () -> Void

    @State private var showPractice = false

    var body: some View {
        Group {
            if showPractice {
                BlankStartPractice(onFinish: { _ in onClose() })
                    .transition(.opacity)
            } else {
                BlankStartIntro(onFinish: {
                    withAnimation(.easeInOut(duration: 0.35)) { showPractice = true }
                })
                .transition(.opacity)
            }
        }
    }
}
