# App Store Submission Checklist

## Step 0 — Firebase Setup (REQUIRED FIRST — enables push notifications + crash reporting)

1. Go to https://console.firebase.google.com → Create project "SportGod"
2. **Android app:**
   - Add app → package: `com.sportgod.app`
   - Download `google-services.json`
   - Place at: `android/app/google-services.json`
3. **iOS app:**
   - Add app → bundle ID: `com.sportgod.app`
   - Download `GoogleService-Info.plist`
   - Place at: `ios/Runner/GoogleService-Info.plist`
4. In Firebase console → Cloud Messaging → enable
5. Commit both files (they're not secret): `git add android/app/google-services.json ios/Runner/GoogleService-Info.plist && git commit -m "add: Firebase config files"`
- [ ] Firebase project created
- [ ] `google-services.json` added to `android/app/`
- [ ] `GoogleService-Info.plist` added to `ios/Runner/`
- [ ] Committed and pushed

## Pre-Submission

### Apple App Store
- [ ] Apple Developer Account (enroll at https://developer.apple.com/programs/)
- [ ] Create App ID in Apple Developer Portal (com.sportgod.app)
- [ ] Create provisioning profiles (Development + Distribution)
- [ ] Create app in App Store Connect
- [ ] Fill in app metadata (copy from `store_listing/app_store.md`)
- [ ] Upload screenshots:
  - [ ] 6.7" iPhone (1290 x 2796) — at least 3 screenshots
  - [ ] 6.5" iPhone (1242 x 2688) — at least 3 screenshots
  - [ ] 12.9" iPad (2048 x 2732) — optional but recommended
- [ ] Set age rating: 12+ (Frequent/Intense Contests — NOT gambling)
- [ ] In the rating questionnaire, select NO for "Simulated Gambling"
- [ ] Add privacy policy URL: https://www.sportgod.in/privacy
- [ ] Fill data collection questionnaire (email collected for auth)
- [ ] Add Review Notes explaining virtual points system (see app_store.md)
- [ ] Build and upload via `cd ios && fastlane beta`
- [ ] Submit for review

### Google Play Store
- [ ] Google Play Developer Account (register at https://play.google.com/console/)
- [ ] Create app in Play Console
- [ ] Fill in store listing (copy from `store_listing/play_store.md`)
- [ ] Upload screenshots:
  - [ ] Phone (1080 x 1920 minimum) — at least 2 screenshots
  - [ ] 7" Tablet (optional)
  - [ ] 10" Tablet (optional)
- [ ] Upload feature graphic (1024 x 500)
- [ ] Upload app icon (512 x 512)
- [ ] Complete content rating questionnaire — select NO for all gambling questions
- [ ] Complete data safety form — no financial data collected
- [ ] Set target audience: 13+
- [ ] Create signing key: `keytool -genkey -v -keystore sportgod-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sportgod`
- [ ] Configure signing in `android/key.properties`
- [ ] Build AAB: `cd android && fastlane build_aab`
- [ ] Upload to internal testing track first
- [ ] Promote to production after testing

## Key Compliance Points
- NO real money is involved anywhere in the app
- SG Points are virtual, cannot be purchased, redeemed, or exchanged
- No in-app purchases exist
- No gambling — prediction challenges are skill-based knowledge quizzes
- Anti-gambling messaging is displayed in Games and Predictions screens
- Disclaimer is present in profile/points section
- Store listings explicitly state "no real money" and "not gambling"
- Review notes for Apple explain the virtual points system clearly

## Screenshots to Capture
1. Home screen with live matches
2. Match detail with scoreboard
3. Fantasy team builder
4. Prediction challenges (showing "Points-only" disclaimer banner)
5. SportsGPT chat
6. Profile with points balance (showing "No real-money value" text)

## Post-Submission
- [ ] Monitor review status daily
- [ ] Respond to any reviewer feedback within 24 hours
- [ ] Once approved, verify app appears in search
- [ ] Test download and first-launch flow on real device

## Build Commands
```bash
# iOS — build and upload to TestFlight
cd ios && fastlane beta

# Android — build release AAB
cd android && fastlane build_aab

# Android — build and upload to Play Store
cd android && fastlane beta

# Manual builds
flutter build ios --release
flutter build appbundle --release
flutter build apk --release
```
