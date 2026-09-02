# GeregeShellKit

Swift Package shared by macOS, iOS and iPadOS native clients.

- `GeregeShellKit`: password/eID API client, ticketed poll state machine and session-cookie model.
- `GeregeShellUI`: SwiftUI native login and origin-scoped `WKWebView` bridge for iOS/iPadOS.
- `Examples/eIDGeregeMNApp.swift`: app scene composition for an Xcode iOS target.

```bash
swift test
xcodebuild -scheme GeregeShellUI -destination 'generic/platform=iOS Simulator' build
```

The shipping app target must add Associated Domains for
`applinks:eid.gerege.mn` and register the example app source as its entry point.
