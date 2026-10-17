//
//  ScreenshotScene.swift
//  Rereminder
//
//  앱스토어 스크린샷용 장면 — **DEBUG 빌드에서만** 존재한다.
//
//  언어 24개 × 화면 여러 장을 손으로 맞춰 찍으면 다음 릴리즈에 똑같이 다시 찍을 수 없다.
//  그래서 실행 인자 하나로 화면 상태를 세운다(`scripts/capture_screenshots.sh` 가 부른다):
//
//      xcrun simctl launch <기기> com.xa.toki -screenshotScene session \
//          -AppleLanguages "(de)" -AppleLocale de_DE -hasSeenOnboarding YES
//
//  - 장면이 걸리면 안내(반복 감지·기기 질문·의견 요청 등)와 알림 권한 요청을 건너뛴다 —
//    스크린샷에 시스템 창이 끼면 다시 찍어야 한다.
//  - 구간 이름·대본은 **사용자가 쓰는 글**이라 문자열 카탈로그가 아니라 여기에 언어별로 둔다
//    (카탈로그에 넣으면 앱에 쓰이지 않는 문구가 번역 게이트에 걸린다).
//

#if DEBUG
import Foundation

enum ScreenshotScene: String {
    /// 대기 중 다이얼 — 30분 + 10·5·1분 전 알림
    case dial
    /// 같은 설정으로 도는 중
    case running
    /// 세션 모드 대기 — 이름 붙인 구간 셋
    case session
    /// 세션 모드로 도는 중 — 지금 구간의 대본이 펴진다
    case sessionRunning

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }

    static var isActive: Bool { current != nil }

    @MainActor
    func apply(to screenVM: TimerScreenViewModel) {
        switch self {
        case .dial, .running:
            screenVM.currentMode = .timer
            screenVM.mainMinutes = 30
            screenVM.mainSeconds = 0
            screenVM.selectedOffsets = [600, 300, 60]
            screenVM.initialConfiguration()
            if self == .running { screenVM.timerVM.start() }

        case .session, .sessionRunning:
            // 30분 발표 = 도입 5 · 본론 20 · 질의응답 5 → 경계는 끝나기 25분·5분 전
            let copy = Self.sessionCopy
            screenVM.currentMode = .presentation
            screenVM.mainMinutes = 30
            screenVM.mainSeconds = 0
            screenVM.selectedOffsets = [1500, 300]
            screenVM.sectionNames = [0: copy.names[0], 1: copy.names[1], 2: copy.names[2]]
            screenVM.sectionScripts = [0: copy.scripts[0], 1: copy.scripts[1], 2: copy.scripts[2]]
            screenVM.syncSectionsFromAlerts()
            screenVM.applyPresentationSections()
            screenVM.initialConfiguration()
            if self == .sessionRunning { screenVM.startPresentation() }
        }
    }

    // MARK: - 언어별 예시 글

    private struct SessionCopy {
        let names: [String]
        let scripts: [String]
    }

    private static var sessionCopy: SessionCopy {
        let language = Locale.preferredLanguages.first ?? "en"
        let key = copies.keys
            .sorted { $0.count > $1.count }   // "zh-Hant" 를 "zh" 보다 먼저 본다
            .first { language.hasPrefix($0) } ?? "en"
        return copies[key]!
    }

    private static let copies: [String: SessionCopy] = [
        "ko": SessionCopy(
            names: ["도입", "본론", "질의응답"],
            scripts: ["오늘 이야기할 세 가지를 먼저 소개합니다.",
                      "사례 두 개로 핵심을 보여 주고, 숫자는 한 장에 모읍니다.",
                      "질문을 받고 마지막 한 문장으로 마무리합니다."]),
        "en": SessionCopy(
            names: ["Intro", "Main talk", "Q&A"],
            scripts: ["Introduce the three things we'll cover today.",
                      "Show the key idea with two examples. Keep the numbers on one slide.",
                      "Take questions, then close with one sentence."]),
        "ja": SessionCopy(
            names: ["導入", "本論", "質疑応答"],
            scripts: ["今日話す3つのポイントを最初に紹介します。",
                      "2つの事例で要点を示し、数字は1枚にまとめます。",
                      "質問を受け、最後のひと言で締めくくります。"]),
        "zh-Hans": SessionCopy(
            names: ["开场", "正文", "问答"],
            scripts: ["先介绍今天要讲的三件事。",
                      "用两个案例讲清重点，数字放在同一页。",
                      "回答提问，用一句话收尾。"]),
        "zh-Hant": SessionCopy(
            names: ["開場", "正文", "問答"],
            scripts: ["先介紹今天要講的三件事。",
                      "用兩個案例講清重點，數字放在同一頁。",
                      "回答提問，用一句話收尾。"]),
        "de": SessionCopy(
            names: ["Einstieg", "Hauptteil", "Fragen"],
            scripts: ["Stelle die drei Punkte vor, um die es heute geht.",
                      "Zeige die Kernidee an zwei Beispielen. Zahlen auf eine Folie.",
                      "Beantworte Fragen und schließe mit einem Satz."]),
        "fr": SessionCopy(
            names: ["Introduction", "Développement", "Questions"],
            scripts: ["Présentez les trois points abordés aujourd'hui.",
                      "Illustrez l'idée clé avec deux exemples. Les chiffres sur une seule diapo.",
                      "Répondez aux questions, puis concluez en une phrase."]),
        "es": SessionCopy(
            names: ["Introducción", "Desarrollo", "Preguntas"],
            scripts: ["Presenta los tres temas de hoy.",
                      "Muestra la idea clave con dos ejemplos. Las cifras, en una sola diapositiva.",
                      "Responde preguntas y cierra con una frase."]),
        "pt": SessionCopy(
            names: ["Abertura", "Desenvolvimento", "Perguntas"],
            scripts: ["Apresente os três pontos de hoje.",
                      "Mostre a ideia principal com dois exemplos. Os números em um só slide.",
                      "Responda às perguntas e encerre com uma frase."]),
        "it": SessionCopy(
            names: ["Introduzione", "Sviluppo", "Domande"],
            scripts: ["Presenta i tre punti di oggi.",
                      "Mostra l'idea chiave con due esempi. I numeri in una sola slide.",
                      "Rispondi alle domande e chiudi con una frase."]),
        "pt-PT": SessionCopy(
            names: ["Introdução", "Tema principal", "Perguntas"],
            scripts: ["Apresente os três pontos de que vamos falar hoje.",
                      "Mostre a ideia principal com dois exemplos. Os números num só diapositivo.",
                      "Responda às perguntas e termine com uma frase."]),
        "ru": SessionCopy(
            names: ["Вступление", "Основная часть", "Вопросы"],
            scripts: ["Назвать три темы, о которых поговорим сегодня.",
                      "Показать главную идею на двух примерах. Все цифры на одном слайде.",
                      "Ответить на вопросы и закончить одной фразой."]),
        "cs": SessionCopy(
            names: ["Úvod", "Hlavní část", "Dotazy"],
            scripts: ["Představte tři věci, kterými dnes projdeme.",
                      "Ukažte hlavní myšlenku na dvou příkladech. Čísla mějte na jednom snímku.",
                      "Odpovězte na dotazy a zakončete jednou větou."]),
        "da": SessionCopy(
            names: ["Intro", "Hoveddel", "Spørgsmål"],
            scripts: ["Præsenter de tre ting, vi kommer omkring i dag.",
                      "Vis hovedpointen med to eksempler. Hold tallene på ét dias.",
                      "Tag imod spørgsmål, og slut af med én sætning."]),
        "el": SessionCopy(
            names: ["Εισαγωγή", "Κυρίως θέμα", "Ερωτήσεις"],
            scripts: ["Παρουσιάστε τα τρία θέματα που θα δούμε σήμερα.",
                      "Δείξτε την κεντρική ιδέα με δύο παραδείγματα. Όλα τα νούμερα σε μία διαφάνεια.",
                      "Απαντήστε σε ερωτήσεις και κλείστε με μία πρόταση."]),
        "fi": SessionCopy(
            names: ["Alku", "Pääosa", "Kysymykset"],
            scripts: ["Esittele kolme asiaa, jotka käymme tänään läpi.",
                      "Näytä pääajatus kahdella esimerkillä. Pidä luvut yhdellä dialla.",
                      "Vastaa kysymyksiin ja päätä yhteen lauseeseen."]),
        "id": SessionCopy(
            names: ["Pembuka", "Materi inti", "Tanya jawab"],
            scripts: ["Perkenalkan tiga hal yang akan kita bahas hari ini.",
                      "Tunjukkan ide utama dengan dua contoh. Taruh angkanya di satu slide.",
                      "Jawab pertanyaan, lalu tutup dengan satu kalimat."]),
        "nb": SessionCopy(
            names: ["Intro", "Hoveddel", "Spørsmål"],
            scripts: ["Presenter de tre tingene vi skal gå gjennom i dag.",
                      "Vis hovedideen med to eksempler. Hold tallene på ett lysbilde.",
                      "Ta imot spørsmål, og avslutt med én setning."]),
        "nl": SessionCopy(
            names: ["Intro", "Kern", "Vragen"],
            scripts: ["Noem de drie dingen die we vandaag bespreken.",
                      "Laat het kernidee zien met twee voorbeelden. Houd de cijfers op één dia.",
                      "Beantwoord vragen en sluit af met één zin."]),
        "pl": SessionCopy(
            names: ["Wstęp", "Główna część", "Pytania"],
            scripts: ["Przedstaw trzy tematy, które dziś omówimy.",
                      "Pokaż główną myśl na dwóch przykładach. Liczby zmieść na jednym slajdzie.",
                      "Odpowiedz na pytania i zakończ jednym zdaniem."]),
        "sv": SessionCopy(
            names: ["Intro", "Huvuddel", "Frågor"],
            scripts: ["Presentera de tre saker vi går igenom i dag.",
                      "Visa huvudidén med två exempel. Håll siffrorna på en bild.",
                      "Ta emot frågor och avsluta med en mening."]),
        "th": SessionCopy(
            names: ["เกริ่นนำ", "เนื้อหาหลัก", "ถามตอบ"],
            scripts: ["บอกสามเรื่องที่เราจะคุยกันวันนี้",
                      "อธิบายแนวคิดหลักด้วยสองตัวอย่าง ใส่ตัวเลขไว้ในสไลด์เดียว",
                      "ตอบคำถาม แล้วปิดท้ายด้วยประโยคเดียว"]),
        "tr": SessionCopy(
            names: ["Giriş", "Ana konu", "Sorular"],
            scripts: ["Bugün konuşacağımız üç konuyu tanıt.",
                      "Ana fikri iki örnekle göster. Rakamları tek slaytta tut.",
                      "Soruları al, tek cümleyle kapat."]),
        "vi": SessionCopy(
            names: ["Mở đầu", "Nội dung chính", "Hỏi đáp"],
            scripts: ["Giới thiệu ba điều chúng ta sẽ nói hôm nay.",
                      "Nêu ý chính bằng hai ví dụ. Gom số liệu vào một trang chiếu.",
                      "Trả lời câu hỏi, rồi khép lại bằng một câu."]),
    ]
}
#endif
