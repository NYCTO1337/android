# NYCTO'S ADVENTURE

2D პლატფორმერი, **Godot 4** ძრავზე. პირველი სამიზნე — **Android**, არქიტექტურა მზადაა **iOS**-ისთვის.

> სტატუსი: მუშა პროტოტიპის **კოდი და რესურსები**. თამაში ამ გარემოში **არ გაშვებულა** და APK **არ აგებულა**, იხ. `docs/TEST_REPORT.md`.

## რას შეიცავს

- ბნელი, ნისლიანი 2D სამყარო: 5 პარალაქსის ფენა, წინა პლანის გიგანტური ტოტები, ფარნების სინათლე. ფერი მხოლოდ ფარნის ალია.
- გმირი: პატარა ადამიანის სილუეტი (იდლი, სიარული, ხტომა, დაცემა, დაშვება, დაღუპვა).
- 1 დონე: ჩამოშლადი ხიდი, ეკლები, ხვრელები, ამოსაწევი ყუთები, ბერკეტი + კარი, 4 საკონტროლო წერტილი (ფარანი), ფინიშის თაღი.
- მდგომარეობები: MAIN_MENU, PLAYING, PAUSED, SETTINGS, DEAD, LEVEL_COMPLETE (`game_state.gd`).
- მენიუები: მთავარი (გაგრძელება / ახალი თამაში / პარამეტრები / გასვლა), პაუზა (გაგრძელება / ბოლო საკონტროლო წერტილი / პარამეტრები / მთავარი მენიუ), პარამეტრები, დასრულება.
- სენსორული მართვა: მცურავი ჯოისტიკი, ხტომა, კონტექსტური ღილაკი (ჩნდება მხოლოდ ბერკეტთან), პაუზა; მულტი-შეხება; ზომა, გამჭვირვალობა, მგრძნობელობა, მხარეების შებრუნება.
- Android Back: თამაშში აჩერებს/აგრძელებს, პარამეტრებიდან უკან, მთავარ მენიუში გამოდის.
- შენახვა: პარამეტრები + პროგრესი (ბოლო ფარანი, დრო, დაღუპვები, საუკეთესო დრო), უსაფრთხო ჩაწერა backup-ით.
- ხმა: `Music` და `SFX` ბუსები, სლაიდერები რეალურად ცვლის ხმას. ყველა ხმა სინთეზირებულია.

## პროექტის სტრუქტურა

```
project.godot, export_presets.cfg, icon.svg
scenes/main.tscn                   ერთადერთი სცენა; ყველაფერს main.gd აგებს
scripts/autoload/                  game_state, save_system, platform_service, audio_manager, perf_governor
scripts/controls/touch_controls.gd მართვის ცალკე სისტემა (მხოლოდ Input Action-ებს აგზავნის)
scripts/game/                      player, level, background, ui_kit, main_menu, pause_menu,
                                   settings_panel, end_screen, main
assets/art, assets/audio, assets/fonts
tools/                             gen_char.py, gen_env.py, gen_audio.py (რესურსების გენერატორი), check_gd.py
docs/                              AUDIT, ENGINE_CHOICE, IOS_PLAN, TEST_REPORT, LICENSES
```

რესურსების თავიდან დაგენერირება: `python3 tools/gen_char.py assets/art && python3 tools/gen_env.py assets/art && python3 tools/gen_audio.py assets/audio` (საჭიროა Pillow და numpy).

## გაშვება კომპიუტერზე (სწრაფი შემოწმება)

1. დააინსტალირე **Godot 4.3 ან უფრო ახალი** (სტანდარტული, არა .NET).
2. Godot → Import → აირჩიე `project.godot` → გახსნისას დაელოდე იმპორტს.
3. F5. მაუსი ცვლის შეხებას (მხოლოდ სწრაფი შემოწმებისთვის); კლავიატურა: A/D ან ისრები, Space/W — ხტომა, E — ურთიერთქმედება, Esc — პაუზა.

## გაშვება Android მოწყობილობაზე

1. ტელეფონზე ჩართე Developer options → **USB debugging**.
2. Godot-ში (Android-ის გარემო უკვე მორგებულია, იხ. ქვემოთ) მოწყობილობა გამოჩნდება ზედა მარჯვენა კუთხეში (Android ხატულა) → დააჭირე ▶ **Remote Debug**.

## APK-ის შექმნა

**ერთჯერადი მომზადება**

1. დააინსტალირე **JDK 17** და **Android SDK** (Android Studio-ს Command-line Tools-ით): `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`, `cmdline-tools;latest`.
2. Godot → *Editor → Manage Export Templates* → ჩამოტვირთე შაბლონები (ზუსტად ისეთივე ვერსიის, როგორიც Godot-ია).
3. *Editor → Editor Settings → Export → Android*: მიუთითე **Android SDK Path** და **Java SDK Path**.
4. Debug keystore: Godot თვითონ ქმნის ან ხელით:
   `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12`
   და მიუთითე Editor Settings-ში (Debug Keystore, User: `androiddebugkey`, Password: `android`).

**Debug APK (ტესტისთვის)**

- Godot: *Project → Export → Android APK → Export Project* (**Export With Debug** ჩართული) → `build/nyctos-adventure.apk`.
- ან ტერმინალიდან: `godot --headless --export-debug "Android APK" build/nyctos-adventure.apk`
- დაინსტალირება: `adb install -r build/nyctos-adventure.apk`

**Release APK / AAB (გამოსაშვებად)**

1. შექმენი საკუთარი keystore (და **შეინახე უსაფრთხოდ + backup**, დაკარგვის შემთხვევაში განახლებას ვეღარ გამოაქვეყნებ):
   `keytool -genkeypair -v -keystore nyctos-release.keystore -alias nyctos -keyalg RSA -keysize 2048 -validity 10000`
2. Export პრესეტში ჩაწერე Release keystore-ის გზა, alias და პაროლი (ან გარემოს ცვლადებით: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD`).
3. **AAB-ისთვის**: *Project → Install Android Build Template*, პრესეტ "Android AAB"-ში ჩართე *Use Gradle Build* და *Export Format = Export AAB*. ამისთვის საჭიროა დამატებით Android NDK (Godot-ის დოკუმენტაცია მიუთითებს ზუსტ ვერსიას თქვენი Godot-ისთვის).
4. Export → `build/nyctos-adventure.aab` (Google Play-ში ატვირთვისთვის).

## ცნობილი შეზღუდვები

- მხოლოდ **ერთი დონეა**, ამიტომ "შემდეგი დონე" არ არსებობს; დასრულების ეკრანზე არის "თავიდან" და "მთავარი მენიუ".
- გაუშვებელია: პარალაქსის მდებარეობა, განათება და ფიზიკა შეიძლება დაზუსტება მოითხოვდეს.
- არტი დაგენერირებულია კოდით; ხელით დახატულ არტზე გადასვლა მოგვიანებით შეიძლება (ფაილების სახელები იგივე დარჩება).
- iOS არ არის გატესტილი.

## დოკუმენტები

- `docs/AUDIT.md` — რა იყო არასწორი და რა შეიცვალა
- `docs/ENGINE_CHOICE.md` — რატომ Godot
- `docs/IOS_PLAN.md` — iOS-ზე გადატანის გეგმა და შეზღუდვები
- `docs/TEST_REPORT.md` — ტესტირების შედეგები და რისკები
- `docs/LICENSES.md` — რესურსები და ლიცენზიები
