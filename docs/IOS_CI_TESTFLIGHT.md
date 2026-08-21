# iOS CI va TestFlight (Codemagic)

Pipeline `ios-testflight` trong `codemagic.yaml` build IPA tren macOS cua
Codemagic, ky bang App Store profile va upload len TestFlight. Pipeline chay
khi push vao nhanh `main`; co the chay thu cong tu Codemagic tren mot nhanh bat
ky. Khong co chung chi, khoa Apple, hay cau hinh production nao duoc luu trong
GitLab.

## Thiet lap mot lan

1. Dang ky Apple Developer Program. Tao App ID `com.vcloud.vcloud` trong Apple
   Developer Portal va tao app record cung Bundle ID trong App Store Connect.
   Luu **Apple ID** dang so cua app tai App Store Connect > General > App
   Information.
2. Tai App Store Connect > Users and Access > Integrations > App Store Connect
   API, tao mot key rieng cho Codemagic voi quyen `App Manager`. Tai file `.p8`
   ngay luc tao (Apple chi cho tai mot lan) va ghi lai `Issuer ID`, `Key ID`.
3. Dang nhap Codemagic bang tai khoan co quyen vao GitLab, them repository
   `360org_mobiles/vclients`, sau do vao Team settings > Team integrations >
   Developer Portal. Them key tren voi ten chinh xac
   `vcloud_app_store_connect`.
4. Vao Team settings > codemagic.yaml settings > Code signing identities:
   tao/dua len mot **Apple Distribution** certificate, sau do fetch/dua len
   **App Store** provisioning profile cho `com.vcloud.vcloud`. Pipeline se tim
   dung certificate/profile dua theo Bundle ID va `app_store` distribution type.
5. Trong App settings > Environment variables, tao secret group
   `vcloud_ios_release` va them:

   | Bien | Gia tri |
   | --- | --- |
   | `APP_STORE_APPLE_ID` | Apple ID dang so cua app trong App Store Connect |
   | `VCLOUD_ODOO_API_BASE_URL` | URL Odoo production, vi du `https://odoo.example.com` |
   | `VCLOUD_ODOO_DB` | Tuy chon; de trong neu mobile login khong dung DB |
   | `VCLOUD_FIREBASE_API_KEY` | Tuy chon, can neu bat Firebase push |
   | `VCLOUD_FIREBASE_APP_ID` | Tuy chon, can neu bat Firebase push |
   | `VCLOUD_FIREBASE_MESSAGING_SENDER_ID` | Tuy chon, can neu bat Firebase push |
   | `VCLOUD_FIREBASE_PROJECT_ID` | Tuy chon, can neu bat Firebase push |

   Danh dau cac bien la **Secret**. `VCLOUD_FIREBASE_IOS_BUNDLE_ID` da duoc
   co dinh trong pipeline thanh `com.vcloud.vcloud` de luon trung voi app ID.

## Phat hanh TestFlight

1. Commit va push `codemagic.yaml` len `main`.
2. Mo Codemagic, chon workflow **iOS to TestFlight**. Pipeline se chay
   `flutter analyze`, `flutter test`, build IPA ky App Store va upload IPA.
3. Cho Apple xu ly build, sau do vao App Store Connect > TestFlight de them
   internal tester. Build hien tai duoc danh dau **internal testing only**, nen
   internal testers co the dung ngay ma khong can beta review.

Build number duoc lay tu App Store Connect va tu dong tang them 1, vi vay se
khong trung voi build da upload truoc do. Neu day la lan dau tien, hoan thien
metadata bat buoc cua app record (privacy policy, category, screenshots) trong
App Store Connect truoc khi phat hanh cong khai.

## Test ben ngoai va App Store

Pipeline nay co chu y chi phat hanh noi bo de tranh tu dong gui beta review.
Khi san sang test ben ngoai, bo
`--custom-export-options='{"testFlightInternalTestingOnly": true}'` khoi buoc
`Apply App Store signing profile`, sau do them `submit_to_testflight: true` va
`beta_groups` vao `publishing.app_store_connect`. Viec gui App Store review nen
duoc tao thanh workflow rieng va co buoc phe duyet, khong tu dong theo moi push.
