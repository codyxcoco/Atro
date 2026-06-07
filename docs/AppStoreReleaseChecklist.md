# App Store Release Checklist

This project is close to submission-ready, but a few App Store Connect items still need to be completed outside the codebase.

## Code-side checks already covered

- HealthKit entitlement is present in `Atro/Resources/Atro.entitlements`.
- A valid app privacy manifest is present in `Atro/Resources/PrivacyInfo.xcprivacy`.
- Permission copy in `Info.plist` clearly describes Calendar and Health usage.
- Settings now includes a `Privacy & Support` screen that explains:
  - what data stays local on-device
  - what Atro reads from Apple Health
  - what Atro writes to Health and Calendar
  - release metadata such as version/build

## App Store Connect items still required

- Add a real, public `Support URL`.
- Add a real, public `Privacy Policy URL`.
- Complete the App Privacy questionnaire.
  - Because Atro stores workout, meal, and health-related information only on-device, local-only data should not count as “collected” unless a future release sends it off-device.
- Set the app’s age rating.
- Answer export compliance questions.
  - The app currently declares `ITSAppUsesNonExemptEncryption = NO`.
- Upload App Store screenshots.
- Fill in app review contact details and review notes.
  - No login is required today, so no demo account should be needed.
- Confirm the shipping bundle identifier is the final one.
  - Changing the bundle ID later will break continuity for existing users because iOS treats it as a different app sandbox.

## Recommended before submitting

1. Archive a Release build from Xcode.
2. Run the archive through Xcode validation.
3. Test the release build on a physical iPhone with Health and Calendar permissions.
4. Verify the support and privacy links resolve to live pages with real contact information.
