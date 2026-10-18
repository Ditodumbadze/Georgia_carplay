# CarPlay Demo — სატესტო აპლიკაცია

სატესტო iPhone-აპლიკაცია, რომელშიც CarPlay-ის **დაშვებული** შესაძლებლობებია თავმოყრილი.

## რა არის მანქანის ეკრანზე

| ჩანართი | შაბლონი | რას აკეთებს |
|---|---|---|
| **რადიო** | `CPListTemplate` | რჩეულები + ყველა სადგური, „უკრავს“ ინდიკატორი |
| **ჟანრები** | `CPGridTemplate` | ჟანრების ბადე → სადგურების სია |
| **დამტენები** | `CPPointOfInterestTemplate` | EV დამტენები რუკაზე, ღილაკი „მარშრუტი“ (Apple Maps) |
| **ინფო** | `CPInformationTemplate` | რა უკრავს, პაუზა/ჩართვა, შემთხვევითი სადგური |
| Now Playing | `CPNowPlayingTemplate` | პაუზა, შემდეგი/წინა, ★ რჩეულებში დამატება |
| შეცდომა | `CPAlertTemplate` | თუ ნაკადი ვერ ჩაირთო |

ტელეფონზე: ძებნა, სადგურების სია, რჩეულები, მინი-პლეერი.

> CarPlay-ზე აუდიო-აპლიკაციებს ძებნის შაბლონი (`CPSearchTemplate`) არ ეძლევა — Apple მას მხოლოდ ნავიგაციას აძლევს. ამიტომ ძებნა ტელეფონის ეკრანზეა.

## რა გჭირდება

- **Mac** და **Xcode 15+** (iOS-აპლიკაციის აწყობა Windows-ზე შეუძლებელია).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## გაშვება სიმულატორში

```bash
cd CarPlayDemo
xcodegen generate
open CarPlayDemo.xcodeproj
```

1. Xcode-ში აირჩიე iPhone-ის სიმულატორი და დააჭირე ▶ Run.
2. სიმულატორის მენიუ: **I/O → External Displays → CarPlay**.
3. CarPlay-ის ფანჯარაში გახსენი „CarPlay Demo“.

## სადგურები

`App/stations.json` — სატესტოდ ჩაწერილია SomaFM-ის საჯარო ნაკადები. დაამატე შენი სადგურები იმავე ფორმატით:

```json
{ "id": "unique-id", "name": "სახელი", "genre": "ჟანრი", "url": "https://...stream" }
```

## დამტენები

`App/Models.swift` → `ChargerData.sample` — **გამოგონილი სატესტო წერტილებია**. რეალური მონაცემებით ჩაანაცვლე (მაქს. 12 წერტილი ერთ ეკრანზე).

## რეალურ iPhone-ზე და მანქანაში

`App/CarPlayDemo.entitlements`-ში ორი კატეგორიაა: `carplay-audio` და `carplay-charging`.
რეალურ მოწყობილობაზე ეს მხოლოდ მაშინ იმუშავებს, როცა Apple ნებართვას დაგიმტკიცებს:
ფასიანი Apple Developer ანგარიში → <https://developer.apple.com/contact/carplay/> → მოთხოვნა.
Apple ჩვეულებრივ ერთ აპლიკაციას ერთ კატეგორიას ამტკიცებს, ამიტომ რეალური ვერსიისთვის
შეიძლება ორ აპლიკაციად გაყოფა დაგჭირდეს (რადიო ცალკე, დამტენები ცალკე).

## აწყობა GitHub-ზე (Mac-ის გარეშე)

`.github/workflows/build.yml` ყოველ push-ზე macOS სერვერზე:
1. ააწყობს პროექტს (შეცდომები ჩანს ლოგში),
2. სიმულატორში გაუშვებს და ტელეფონის ეკრანის სურათს გადაიღებს,
3. შექმნის ხელმოუწერელ `CarPlayDemo-unsigned.ipa`-ს.

შედეგები: GitHub → რეპოზიტორი → **Actions** → ბოლო გაშვება → **Artifacts** → `CarPlayDemo-build`.
