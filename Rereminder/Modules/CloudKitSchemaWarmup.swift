#if DEBUG
import SwiftData

/// CloudKit 개발 스키마 만들기.
///
/// CloudKit 은 레코드를 처음 내보낼 때 개발 환경에 레코드 타입을 만든다. 빈 저장소로는 아무것도 생기지 않는다.
/// 모델을 더하거나 바꾼 뒤 `-cloudKitSchemaWarmup` 인자로 띄우면 모델마다 표본 하나를 넣었다가 30초 뒤 지운다.
/// 그러면 CloudKit 콘솔(개발 환경) ▸ Record Types 에 CD_… 타입이 생기고, 거기서 "Deploy Schema Changes" 로 프로덕션에 올린다.
/// 프로덕션에 없는 타입은 스토어 빌드에서 조용히 동기화에 실패하므로, 모델이 바뀔 때마다 이 순서를 밟는다.
enum CloudKitSchemaWarmup {
    @MainActor
    static func runIfRequested(_ container: ModelContainer, samples: @MainActor () -> [any PersistentModel]) {
        guard CommandLine.arguments.contains("-cloudKitSchemaWarmup") else { return }
        let context = container.mainContext
        let models = samples()
        for model in models { context.insert(model) }
        do {
            try context.save()
            print("☁️ 스키마 워밍업: 표본 \(models.count)개를 넣었다 — 30초 뒤 지운다")
        } catch {
            print("☁️ 스키마 워밍업 실패: \(error)")
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            for model in models { context.delete(model) }
            try? context.save()
            print("☁️ 스키마 워밍업: 표본을 지웠다")
        }
    }
}
#endif
