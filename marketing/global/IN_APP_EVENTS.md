# 인앱 이벤트 (In-App Events)

App Store Connect ▸ 앱 ▸ **인앱 이벤트**(In-App Events) ▸ (+) 에 넣는다. DeployBar 는 이것을 올리지 못한다.
이벤트는 앱 버전과 따로 심사에 낼 수 있다. 문구 원본은 `events/copy.json`, 글자 수는
`python3 -I marketing/global/events/count_chars.py` 로 다시 센다(넘치거나 다른 언어에 한글이 섞이면 종료 코드 1).

작성일 2026-10-21

## 확인한 규칙 (공식 문서: https://developer.apple.com/app-store/in-app-events/)

| 항목 | 한도 · 규칙 |
|---|---|
| 이벤트 이름 | 30자, Title Case. 실제 이벤트 이름이어야 한다(행동 유도·태그라인 금지) |
| 짧은 설명 | 50자, 문장형. 이벤트 카드에 보인다 |
| 긴 설명 | 120자, 문장형. 이벤트 상세 페이지에 보인다 |
| 이벤트 카드 그림 | 16:9, .jpg/.png, 1920×1080 ~ 3840×2160 (영상은 같은 비율 .mov/.m4v/.mp4, 30·60fps) |
| 이벤트 상세 그림 | 9:16, .jpg/.png, 1080×1920 ~ 2160×3840 |
| 기간 | 최대 31일. 시작 최대 14일 전부터 홍보 노출 |
| 동시 개수 | 승인 15개, 게시 10개 |
| 우선순위 | 보통 / 높음(높음이 앞에 선다) |
| 목적 | 모든 사용자에게 적합 / 새 사용자 유치 / 활성 사용자에게 알림 / 이탈 사용자 복귀 |
| 거절되는 것 | 매일 반복되는 일, **내용 없는 가격 행사**, 앱 홍보 일반, **메타데이터의 구체적 가격**, 전부 대문자·!!, "최고"·"#1", 그림 속 글자·로고(특히 앱·이벤트 이름), 그림 테두리·그라데이션 |
| 배지 | Challenge · Competition · Live Event · **Major Update** · New Season · Premiere · **Special Event** |

현지화: App Store Connect 에서 이벤트 메타데이터를 앱의 언어마다 넣는다. 아래 표는 `deploy.env` LOCALES 24개 전부다.
App Store Connect 의 언어 이름 대응: ko 한국어, en 영어(미국 — 영국·호주·캐나다에도 같은 영어를 넣는다),
ja 일본어, zh-Hans 중국어(간체), zh-Hant 중국어(번체), de 독일어, fr 프랑스어, es 스페인어(스페인 — 멕시코에도 같은 글),
pt-BR 포르투갈어(브라질), pt-PT 포르투갈어(포르투갈), it 이탈리아어, ru 러시아어, cs 체코어, da 덴마크어, el 그리스어,
fi 핀란드어, id 인도네시아어, nb 노르웨이어, nl 네덜란드어, pl 폴란드어, sv 스웨덴어, th 태국어, tr 튀르키예어, vi 베트남어.

**딥링크**: 없음. 메인 앱에는 URL 스킴도 유니버설 링크도 없다(`onOpenURL`·`CFBundleURLTypes` 없음 — 2026-10-21 코드 확인).
칸을 비워 두면 "열기"가 앱 첫 화면을 연다. 선물 줄은 설정 ▸ Pro 칸 바로 아래에 있으므로 긴 설명에 "설정에서" 라고 적었다.

## 한눈에

| id | 배지 | 시작 | 종료 | 일수 | 우선순위 | 목적 | 인앱 구입 필요 | 거절 위험 |
|---|---|---|---|---|---|---|---|---|
| `gift-update` | Major Update | 2026-11-18 00:00 | 2026-12-14 23:59 | 27 | 높음 | 활성 사용자에게 알림 | 예(선물·Pro) | 낮음 |
| `holiday-gift` | Special Event | 2026-12-15 00:00 | 2027-01-10 23:59 | 27 | 높음 | 모든 사용자에게 적합 | 예(선물) | 중간 |
| `talk-season` | Special Event | 2027-01-06 00:00 | 2027-02-04 23:59 | 30 | 보통 | 새 사용자 유치 | 아니요(무료로 체험 가능) | **높음** |

시간대는 각 지역 현지 시각(App Store Connect 의 기본). 홍보 시작일은 시작 14일 전(11-04, 12-01, 12-23)으로 두되,
승인이 그보다 늦으면 승인된 날부터 보인다.

## 이벤트별 설명

### `gift-update` — Major Update (2.3.4)

- **무엇이 실제로 일어나나**: 2.3.4 출시로 Pro 선물하기(코드로 보내고 설정에서 받기), 응원(팁), 내 혜택 화면, 앱 안 코드 사용,
  음성 제어 이름 등 접근성 개선이 새로 생긴다. 근거 `76021b0`, `581d541`, `0782f0c`.
- **조건**: 2.3.4 가 2026-11-18 전에 스토어에 나가 있고, `com.xa.toki.gift.pro`·`com.xa.toki.tip.*` 상품이 승인돼 있어야 한다.
  출시가 밀리면 시작일을 출시 다음 날로 옮기고 종료일도 같이 민다(31일 이내).
- **심사에 낼 때**: 2.3.4 가 승인된 뒤에 낸다. 심사자가 앱을 열었을 때 선물 줄이 보여야 한다.
- **인앱 구입 필요**: 예 — 선물을 보내려면 결제가 필요하다(받는 것은 무료).
- **그림**: `events/common/card-1920x1080.png`, `events/common/details-1080x1920.png` (언어 공통, 숫자 말고 글자 없음).
  더 나은 그림: 설정의 선물 화면(`LeeoGiftView`)을 시뮬레이터로 찍어 같은 방식으로 자르면 이 이벤트에 꼭 맞는다 — 아직 그 스크린샷이 레포에 없다.

### `holiday-gift` — Special Event (연말 선물 시즌)

- **무엇이 실제로 일어나나**: 연말 동안 앱 안의 선물하기(새 상품)를 중심에 둔다. 할인은 없다.
- **거절 위험 중간**: Apple 은 Special Event 에 "새 콘텐츠·기능·상품"을 요구한다. 선물은 상품이지만 `gift-update` 와 같은 기능을 다시 쓰는 것이라
  "반복"이나 "일반 홍보"로 볼 수 있다. 거절되면 `gift-update` 기간을 31일로 늘려(11-18 ~ 12-18) 하나로 합친다.
- **인앱 구입 필요**: 예.
- **그림**: `events/common/` 두 장을 같이 쓴다. 선물 화면 스크린샷이 생기면 그것으로 바꾼다.

### `talk-season` — Special Event (발표 시즌 준비)

- **무엇이 실제로 일어나나**: 새해 학회·수업이 시작되는 시기에 세션 모드(구간 이름·구간 대본이 차례에 펼쳐짐)와 끝나기 전 알림,
  Apple Watch 를 소개한다.
- ⚠️ **거절 위험 높음**: 지금 이 기간에만 생기는 새 콘텐츠가 앱 안에 없다. Apple 기준으로는 "앱 인지도 홍보"에 가깝다.
  안전하게 하려면 그 전에 **기간 한정 새 콘텐츠**를 앱에 넣는다 — 예: 발표용 기본 세션 템플릿 묶음(학회 발표 15분, 수업 50분, 워크숍 90분)을
  이 기간에만 설정에서 받을 수 있게. 넣지 못하면 이 이벤트는 내지 말고, 같은 글을 피처링 추천 3번에만 쓴다.
- **인앱 구입 필요**: 아니요 — 세션 모드는 무료 체험 횟수(한 바퀴 5번, `ProGate.gatePolicy`)가 있다.
  (체험만으로는 계속 쓸 수 없으므로 심사자가 "예"를 요구하면 따른다)
- **그림**: 언어마다 따로 — `events/talk-season/<로케일>/card-1920x1080.png`(도는 세션 링 + 구간 대본 카드),
  `events/talk-season/<로케일>/details-1080x1920.png`(세션 구간 목록). 그 언어 앱 화면이라 화면 안 글이 현지어다.
  이벤트·앱 이름은 그림에 없다.

## 그림 만들기

`docs/screenshots/raw/<로케일>/` 의 앱 화면(1320×2868)을 잘라 검은 바탕에 놓았다. 테두리·그라데이션·덧붙인 글자 없음.
스크린샷을 다시 찍으면 다시 만든다:

```
python3 marketing/global/events/make_images.py docs/screenshots/raw marketing/global/events
```

| 파일 | 크기 | 쓰는 이벤트 |
|---|---|---|
| `events/common/card-1920x1080.png` | 1920×1080 (16:9) | gift-update, holiday-gift |
| `events/common/details-1080x1920.png` | 1080×1920 (9:16) | gift-update, holiday-gift |
| `events/talk-season/<24개 로케일>/card-1920x1080.png` | 1920×1080 | talk-season |
| `events/talk-season/<24개 로케일>/details-1080x1920.png` | 1080×1920 | talk-season |

없는 것: 선물 화면 스크린샷(선물 두 이벤트용), 이벤트 카드 영상(선택).

## 언어별 문구 (자 = 글자 수, 한도 30 · 50 · 120)

#### `gift-update`

| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |
|---|---|---|---|---|---|---|
| ko | Pro 선물하기 업데이트 | 13 | Pro를 선물하고, 내 혜택을 한눈에 확인하세요 | 26 | 동료에게 코드로 Pro를 선물하고, 받은 코드는 설정에서 바로 쓰세요. 내가 연 혜택도 한눈에 보여요. | 57 |
| en | Gift Pro Update | 15 | Give Pro as a gift and see what your plan unlocks | 49 | Send Pro to a colleague with a code, redeem codes right in Settings, and see everything your plan unlocks at a glance. | 118 |
| ja | Proプレゼント アップデート | 15 | Proを贈って、使える特典もひと目で確認 | 20 | 同僚にコードでProを贈れます。受け取ったコードは設定ですぐ使え、今の特典もひと目でわかります。 | 48 |
| zh-Hans | 赠送 Pro 功能上线 | 11 | 把 Pro 送给朋友，权益一眼看清 | 17 | 用兑换码把 Pro 送给同事；收到的代码可在设置中直接兑换，已解锁的功能也一目了然。 | 42 |
| zh-Hant | 贈送 Pro 功能上線 | 11 | 把 Pro 送給朋友，權益一眼看清 | 17 | 用兌換碼把 Pro 送給同事；收到的代碼可在設定中直接兌換，已解鎖的功能也一目瞭然。 | 42 |
| de | Update: Pro verschenken | 23 | Pro verschenken und Vorteile auf einen Blick | 44 | Verschenke Pro per Code an dein Team. Erhaltene Codes löst du direkt in den Einstellungen ein und siehst, was frei ist. | 119 |
| fr | Mise à jour Offrir Pro | 22 | Offrez Pro et voyez vos avantages d’un coup d’œil | 49 | Offrez Pro à un collègue grâce à un code. Les codes reçus s’utilisent dans Réglages, avec vos avantages en vue. | 111 |
| es | Actualización: regalar Pro | 26 | Regala Pro y mira tus ventajas de un vistazo | 44 | Regala Pro a un compañero con un código. Los códigos recibidos se canjean en Ajustes y ves lo que tienes. | 105 |
| pt-BR | Atualização: presentear o Pro | 29 | Presenteie o Pro e veja seus benefícios | 39 | Presenteie um colega com o Pro usando um código. Códigos recebidos são resgatados em Ajustes, com seus benefícios. | 114 |
| pt-PT | Atualização: oferecer o Pro | 27 | Ofereça o Pro e veja as suas vantagens | 38 | Ofereça o Pro a um colega com um código. Os códigos recebidos resgatam-se nas Definições, com as suas vantagens à vista. | 120 |
| it | Aggiornamento: regala Pro | 25 | Regala Pro e scopri i tuoi vantaggi | 35 | Regala Pro a un collega con un codice. I codici ricevuti si riscattano in Impostazioni, dove vedi i tuoi vantaggi. | 114 |
| ru | Обновление: Pro в подарок | 25 | Дарите Pro и смотрите свои преимущества | 39 | Подарите Pro коллеге с помощью кода. Полученные коды активируются прямо в Настройках, там же видно, что вам доступно. | 117 |
| cs | Aktualizace: darujte Pro | 24 | Darujte Pro a mějte přehled o výhodách | 38 | Darujte Pro kolegovi pomocí kódu. Přijaté kódy uplatníte přímo v Nastavení, kde hned uvidíte i své výhody. | 106 |
| da | Opdatering: Giv Pro i gave | 26 | Giv Pro i gave, og se dine fordele med det samme | 48 | Giv Pro til en kollega med en kode. Koder, du modtager, indløser du under Indstillinger, hvor du også ser dine fordele. | 119 |
| el | Ενημέρωση: Δώρο Pro | 19 | Χάρισε το Pro και δες τα οφέλη σου | 34 | Χάρισε το Pro σε συνάδελφο με έναν κωδικό. Τους κωδικούς που λαμβάνεις τους εξαργυρώνεις στις Ρυθμίσεις. | 104 |
| fi | Päivitys: Anna Pro lahjaksi | 27 | Anna Pro lahjaksi ja näe etusi heti | 35 | Anna Pro kollegalle lahjaksi koodilla. Saamasi koodit lunastat suoraan Asetuksista, ja näet samalla omat etusi. | 111 |
| id | Pembaruan: Hadiahkan Pro | 24 | Hadiahkan Pro dan lihat manfaatmu sekilas | 41 | Hadiahkan Pro kepada rekan kerja lewat kode. Kode yang kamu terima bisa langsung ditukar di Pengaturan. | 103 |
| nb | Oppdatering: Gi Pro i gave | 26 | Gi Pro i gave og se fordelene dine med én gang | 46 | Gi Pro til en kollega med en kode. Koder du får, løser du inn rett i Innstillinger, der du også ser fordelene dine. | 115 |
| nl | Update: Pro cadeau doen | 23 | Doe Pro cadeau en zie meteen je voordelen | 41 | Geef een collega Pro cadeau met een code. Ontvangen codes wissel je in via Instellingen, waar je ook je voordelen ziet. | 119 |
| pl | Aktualizacja: podaruj Pro | 25 | Podaruj Pro i zobacz swoje korzyści | 35 | Podaruj Pro współpracownikowi za pomocą kodu. Otrzymane kody zrealizujesz od razu w Ustawieniach. | 97 |
| sv | Uppdatering: Ge bort Pro | 24 | Ge bort Pro och se dina förmåner direkt | 39 | Ge en kollega Pro i present med en kod. Koder du får löser du in direkt i Inställningar, där du också ser dina förmåner. | 120 |
| th | อัปเดต: มอบ Pro เป็นของขวัญ | 27 | มอบ Pro ให้คนอื่น และดูสิทธิ์ของคุณได้ทันที | 43 | มอบ Pro ให้เพื่อนร่วมงานด้วยโค้ด ส่วนโค้ดที่ได้รับก็ใช้ได้ทันทีในการตั้งค่า พร้อมดูสิทธิ์ที่ปลดล็อกแล้ว | 103 |
| tr | Güncelleme: Pro hediye et | 25 | Pro'yu hediye edin, avantajlarınızı görün | 41 | Pro'yu bir iş arkadaşınıza kodla hediye edin. Aldığınız kodları doğrudan Ayarlar'dan kullanabilirsiniz. | 103 |
| vi | Cập nhật: Tặng Pro | 18 | Tặng Pro và xem quyền lợi của bạn trong nháy mắt | 48 | Tặng Pro cho đồng nghiệp bằng mã. Mã bạn nhận được có thể đổi ngay trong Cài đặt, nơi bạn cũng thấy quyền lợi của mình. | 119 |

#### `holiday-gift`

| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |
|---|---|---|---|---|---|---|
| ko | 연말 선물 시즌 | 8 | 함께 발표하는 동료에게 Pro를 선물하세요 | 23 | 연말 동안 Pro를 선물해 보세요. 받는 분은 설정에서 코드를 입력하면 Pro를 계속 쓸 수 있어요. | 56 |
| en | Holiday Gift Season | 19 | Give Pro to someone who speaks or teaches often | 47 | Over the holidays, send Pro as a gift. Your recipient enters the code in Settings and keeps Pro for good. | 105 |
| ja | 年末のプレゼントシーズン | 12 | 一緒に登壇する仲間にProを贈りましょう | 20 | 年末年始はProを贈ってみませんか。受け取った人は設定でコードを入力するだけで、Proをずっと使えます。 | 52 |
| zh-Hans | 年末礼物季 | 5 | 把 Pro 送给一起上台的伙伴 | 15 | 年末假期，不妨把 Pro 当作礼物。对方在设置中输入兑换码，即可一直使用 Pro。 | 41 |
| zh-Hant | 年末送禮季 | 5 | 把 Pro 送給一起上台的夥伴 | 15 | 年末假期，不妨把 Pro 當作禮物。對方在設定中輸入兌換碼，就能一直使用 Pro。 | 41 |
| de | Geschenkzeit zum Jahresende | 27 | Schenk Pro an Menschen, die oft vortragen | 41 | Über die Feiertage kannst du Pro verschenken. Wer den Code in den Einstellungen einlöst, behält Pro dauerhaft. | 110 |
| fr | La saison des cadeaux | 21 | Offrez Pro à ceux qui prennent souvent la parole | 48 | Pendant les fêtes, offrez Pro. La personne saisit le code dans Réglages et garde Pro pour de bon. | 97 |
| es | Temporada de regalos | 20 | Regala Pro a quien habla en público a menudo | 44 | Durante las fiestas, puedes regalar Pro. Quien lo recibe canjea el código en Ajustes y conserva Pro para siempre. | 113 |
| pt-BR | Temporada de presentes | 22 | Dê o Pro a quem vive falando em público | 39 | Nas festas de fim de ano, presenteie com o Pro. Quem recebe resgata o código em Ajustes e fica com o Pro para sempre. | 117 |
| pt-PT | Época de presentes | 18 | Ofereça o Pro a quem fala muito em público | 42 | Nas festas, ofereça o Pro. Quem o recebe introduz o código nas Definições e fica com o Pro para sempre. | 103 |
| it | La stagione dei regali | 22 | Regala Pro a chi parla spesso in pubblico | 41 | Durante le feste puoi regalare Pro. Chi lo riceve inserisce il codice in Impostazioni e tiene Pro per sempre. | 109 |
| ru | Сезон подарков | 14 | Подарите Pro тем, кто часто выступает | 37 | В праздники можно подарить Pro. Получатель вводит код в Настройках, и Pro остаётся у него навсегда. | 99 |
| cs | Čas dárků | 9 | Darujte Pro těm, kdo často mluví před lidmi | 43 | Během svátků můžete darovat Pro. Obdarovaný zadá kód v Nastavení a Pro mu zůstane natrvalo. | 91 |
| da | Gavesæson | 9 | Giv Pro til dem, der ofte taler foran andre | 43 | Hen over højtiden kan du give Pro i gave. Modtageren indløser koden under Indstillinger og beholder Pro for altid. | 114 |
| el | Εποχή δώρων | 11 | Χάρισε το Pro σε όσους μιλούν συχνά σε κοινό | 44 | Στις γιορτές μπορείς να χαρίσεις το Pro. Ο παραλήπτης βάζει τον κωδικό στις Ρυθμίσεις και κρατά το Pro για πάντα. | 113 |
| fi | Lahjojen aika | 13 | Anna Pro niille, jotka puhuvat usein yleisölle | 46 | Juhlakaudella voit antaa Pron lahjaksi. Saaja lunastaa koodin Asetuksissa, ja Pro jää hänelle pysyvästi. | 104 |
| id | Musim Hadiah Akhir Tahun | 24 | Hadiahkan Pro untuk rekan yang sering presentasi | 48 | Selama liburan akhir tahun, kamu bisa menghadiahkan Pro. Penerima menukar kode di Pengaturan dan memakai Pro selamanya. | 119 |
| nb | Gavesesong | 10 | Gi Pro til dem som ofte snakker foran andre | 43 | I høytiden kan du gi Pro i gave. Mottakeren løser inn koden i Innstillinger og beholder Pro for godt. | 101 |
| nl | Cadeauseizoen | 13 | Geef Pro aan wie vaak voor een groep spreekt | 44 | Tijdens de feestdagen kun je Pro cadeau doen. De ontvanger wisselt de code in via Instellingen en houdt Pro voorgoed. | 117 |
| pl | Sezon prezentów | 15 | Podaruj Pro osobom, które często przemawiają | 44 | W święta możesz podarować Pro. Obdarowana osoba wpisuje kod w Ustawieniach i zachowuje Pro na zawsze. | 101 |
| sv | Julklappssäsong | 15 | Ge Pro till dem som ofta talar inför andra | 42 | Under helgerna kan du ge bort Pro. Mottagaren löser in koden i Inställningar och behåller Pro för alltid. | 105 |
| th | เทศกาลของขวัญปลายปี | 19 | มอบ Pro ให้คนที่ต้องพูดต่อหน้าผู้คนบ่อยๆ | 40 | ช่วงเทศกาลนี้ คุณมอบ Pro เป็นของขวัญได้ ผู้รับแค่ใส่โค้ดในการตั้งค่า ก็ใช้ Pro ได้ตลอดไป | 88 |
| tr | Hediye Sezonu | 13 | Sık konuşma yapanlara Pro hediye edin | 37 | Yılbaşı döneminde Pro'yu hediye edebilirsiniz. Alan kişi kodu Ayarlar'a girer ve Pro'yu kalıcı olarak kullanır. | 111 |
| vi | Mùa quà tặng cuối năm | 21 | Tặng Pro cho người thường xuyên thuyết trình | 44 | Dịp lễ cuối năm, bạn có thể tặng Pro. Người nhận chỉ cần nhập mã trong Cài đặt là dùng Pro mãi mãi. | 99 |

#### `talk-season`

| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |
|---|---|---|---|---|---|---|
| ko | 발표 시즌 준비 | 8 | 발표를 구간으로 나누고 끝나기 전에 미리 알림 | 25 | 구간마다 이름과 메모를 적어 두면 차례가 올 때 펼쳐지고, 끝나기 전에 iPhone과 Apple Watch로 알려 줘요. | 67 |
| en | Conference Season Prep | 22 | Split your talk into parts and get warned in time | 49 | Name each part, add notes that open on cue, and get alerts before time runs out on iPhone and Apple Watch. | 106 |
| ja | 発表シーズンの準備 | 9 | 発表をパートに分けて、終わる前に通知 | 18 | パートごとに名前とメモを付けておけば順番が来ると表示され、終わる前にiPhoneとApple Watchで知らせます。 | 59 |
| zh-Hans | 演讲季准备 | 5 | 把演讲分成几段，结束前提前提醒 | 15 | 为每段写好名称和备注，轮到时自动展开；时间结束前，iPhone 和 Apple Watch 会提前提醒你。 | 53 |
| zh-Hant | 演講季準備 | 5 | 把演講分成幾段，結束前先提醒 | 14 | 為每段寫好名稱和備註，輪到時自動展開；時間結束前，iPhone 和 Apple Watch 會提前提醒你。 | 53 |
| de | Bereit für die Vortragssaison | 29 | Teil deinen Vortrag ein und werde früh erinnert | 47 | Benenne jeden Abschnitt, notiere Stichpunkte, die zur rechten Zeit aufklappen, und lass dich vorher erinnern. | 109 |
| fr | Saison des conférences | 22 | Découpez votre exposé et soyez prévenu à temps | 46 | Nommez chaque partie, ajoutez des notes qui s’ouvrent au bon moment et soyez prévenu avant la fin. | 98 |
| es | Temporada de conferencias | 25 | Divide tu charla y recibe avisos a tiempo | 41 | Pon nombre a cada parte, añade notas que se abren en su momento y recibe avisos antes del final en iPhone y Apple Watch. | 120 |
| pt-BR | Temporada de palestras | 22 | Divida sua palestra em partes e seja avisado | 44 | Dê nome a cada parte, anote o que dizer e veja as notas na hora certa. Receba avisos antes do fim. | 98 |
| pt-PT | Época de conferências | 21 | Divida a apresentação em partes e seja avisado | 46 | Dê nome a cada parte, junte notas que abrem na altura certa e receba alertas antes do fim no iPhone e no Apple Watch. | 117 |
| it | Stagione delle conferenze | 25 | Dividi il talk in parti e ricevi avvisi in tempo | 48 | Dai un nome a ogni parte, aggiungi note che si aprono al momento giusto e ricevi avvisi prima della fine. | 105 |
| ru | Сезон конференций | 17 | Разделите доклад на этапы и получайте сигналы | 45 | Назовите каждый этап, добавьте заметки, которые откроются вовремя, и получайте сигналы до конца на iPhone и Apple Watch. | 120 |
| cs | Sezóna konferencí | 17 | Rozdělte přednášku a dostaňte upozornění včas | 45 | Pojmenujte každou část, přidejte poznámky, které se včas otevřou, a před koncem vás upozorní iPhone i Apple Watch. | 114 |
| da | Konferencesæson | 15 | Del dit oplæg op, og få besked i god tid | 40 | Giv hver del et navn, tilføj noter, der åbner på rette tid, og få besked, før tiden er gået, på iPhone og Apple Watch. | 118 |
| el | Εποχή συνεδρίων | 15 | Χώρισε την ομιλία σου και ειδοποιήσου νωρίς | 43 | Δώσε όνομα σε κάθε μέρος, πρόσθεσε σημειώσεις που ανοίγουν την ώρα τους και λάβε ειδοποιήσεις πριν τη λήξη. | 107 |
| fi | Konferenssikausi | 16 | Jaa esitys osiin ja saa muistutus ajoissa | 41 | Nimeä jokainen osa, lisää muistiinpanot, jotka avautuvat oikealla hetkellä, ja saa muistutus ennen loppua. | 106 |
| id | Musim Konferensi | 16 | Bagi presentasi per bagian, dapat pengingat | 43 | Beri nama tiap bagian, tambahkan catatan yang muncul tepat waktu, dan dapatkan pengingat sebelum waktu habis. | 109 |
| nb | Konferansesesong | 16 | Del opp foredraget og få varsel i god tid | 41 | Gi hver del et navn, legg til notater som åpnes til rett tid, og få varsel før tiden er ute på iPhone og Apple Watch. | 117 |
| nl | Congresseizoen | 14 | Deel je talk op en krijg op tijd een seintje | 44 | Geef elk deel een naam, voeg notities toe die op het juiste moment openen en krijg vóór het einde een seintje. | 110 |
| pl | Sezon konferencji | 17 | Podziel wystąpienie i dostawaj przypomnienia | 44 | Nazwij każdą część, dodaj notatki, które otworzą się we właściwej chwili, i dostań przypomnienie przed końcem. | 110 |
| sv | Konferenssäsong | 15 | Dela upp föredraget och få påminnelser i tid | 44 | Namnge varje del, lägg till anteckningar som öppnas i rätt stund och få påminnelser före slutet. | 96 |
| th | เตรียมพร้อมฤดูงานสัมมนา | 23 | แบ่งการบรรยายเป็นช่วง และรับการเตือนก่อนหมดเวลา | 47 | ตั้งชื่อแต่ละช่วง ใส่โน้ตที่จะเปิดขึ้นเมื่อถึงคิว และรับการแจ้งเตือนก่อนหมดเวลาบน iPhone และ Apple Watch | 104 |
| tr | Konferans Sezonu | 16 | Konuşmanızı bölümlere ayırın, zamanında uyarı alın | 50 | Her bölüme ad verin, sırası gelince açılan notlar ekleyin ve süre bitmeden iPhone ile Apple Watch'ta uyarı alın. | 112 |
| vi | Mùa hội thảo | 12 | Chia bài nói thành từng phần, được nhắc đúng lúc | 48 | Đặt tên từng phần, thêm ghi chú tự mở khi đến lượt và nhận nhắc nhở trước khi hết giờ trên iPhone và Apple Watch. | 113 |
