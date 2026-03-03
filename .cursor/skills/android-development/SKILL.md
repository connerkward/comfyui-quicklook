---
name: android-development
description: Build, run, and verify Android apps on device or emulator; monitor adb/logcat. Use when making Android code changes, Kotlin/Java app development, or when working in an Android project.
---

## After code changes

1. **Build and run** on a connected device or emulator.
2. **Monitor logs** via `adb logcat` (or relevant tags/filters); watch for crashes, errors, or prompts for input.
3. **Handle human input**: If logs or UI indicate user action is required (permission, dialog, device selection), tell the user exactly what to do; do not treat as failure. If you can remotely automate this, do so. 
4. **Test generated code**: If no human input is needed, always run and test the changed behavior, UI and or programmatically, rather than only building.

## Commands

- Build + install: `./gradlew installDebug` (or equivalent from project root)
- Run app: `adb shell am start -n <package>/<activity>` or use Run from IDE
- Logs: `adb logcat`; optionally `adb logcat -s TagName` or `adb logcat *:E` for errors only

## Policy

- Never leave code untested after edits. Either run and observe, or explicitly tell the user what input they must provide.

Do not bother humans or await session unless truly necessary.
