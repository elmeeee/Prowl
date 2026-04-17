# Prowl

<p align="center">
  <img src="Sources/Resource/prowl_icon.png" alt="Prowl Icon" width="220" />
</p>

Prowl is a lightweight, high-performance network debugging library for the Apple ecosystem (`iOS`, `macOS`, `watchOS`, `tvOS`, `visionOS`) built with native `Foundation` + `SwiftUI` and distributed via Swift Package Manager.

## Features

- URL interception via `URLProtocol`
- Thread-safe log storage via `actor`
- FIFO log buffer (default `200`)
- Opt-in sensitive data masking (e.g. `Authorization`, `password`)
- SwiftUI inspector dashboard + detail tabs
- Real-time search and status filtering
- Export logs as formatted text or cURL commands
- Activation shortcuts:
  - iOS shake gesture
  - macOS menu bar popover + `Command + Shift + P`

## Install (SPM)

In Xcode:

1. `File` -> `Add Package Dependencies...`
2. Enter your repository URL for Prowl
3. Select dependency rule version:
   - `Up to Next Major Version` (recommended), example from `0.5.16`
   - `Up to Next Minor Version`
   - `Exact Version` (locked)
4. Add the `Prowl` product to your app target

### Version Strategy Example

- **Stable updates (recommended):** `Up to Next Major` from `0.5.16`
- **Strict lock for CI/release:** `Exact` `0.5.16`

If you use `Package.swift` directly, pin like this:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/Prowl.git", exact: "0.5.16")
]
```

## Quick Start

### 1) Start interception

Call this once at app startup:

```swift
import Prowl

@main
struct DemoApp: App {
    init() {
        Prowl.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2) Ignore Noise URLs (Optional)

If your app heavily pings telemetry or third-party analytics (like Firebase, Mixpanel, etc.), you can cleanly exclude them from cluttering your Prowl logs.

Pass an array of string partials directly when starting:

```swift
Prowl.start(ignoredURLs: [
    "https://firebaselogging.googleapis.com",
    "https://api.mixpanel.com/",
    "https://app-analytics-services.com/"
])
```

Alternatively, you can dynamically ignore URLs later at runtime:

```swift
Prowl.ignoreURL("https://res.cloudinary.com/")
```

## Check Version

You can expose/log the package version in your app:

```swift
import Prowl

print("Prowl version:", Prowl.version)
```

### 3) Open the inspector

No extra view modifier is required.

After `Prowl.start()`:

- iOS: shake device to toggle inspector
- macOS: click the `Prowl` status bar icon and choose inspector actions from the popover panel

You can also control inspector manually (iOS/macOS):

```swift
Prowl.show()
Prowl.hide()
Prowl.toggle()
```

On macOS, `Prowl.start()` automatically installs a menu bar item so you can open/toggle the inspector without embedding a custom debug screen.

## Configure Storage and Masking

```swift
import Prowl
import ProwlCore

let storage = ProwlStorage(limit: 500)
let masker = SensitiveDataMasker(
    sensitiveHeaders: ["authorization", "cookie", "x-api-key"],
    sensitiveJSONKeys: ["password", "token", "accessToken"]
)

Prowl.configure(storage: storage, masker: masker)
Prowl.start()
```

## Custom URLSessionDelegate (Pinning / mTLS)

You can provide your own `URLSessionDelegate` (for certificate pinning, mTLS, or custom trust handling):

```swift
final class MySessionDelegate: NSObject, URLSessionDelegate {
    // Implement trust / challenge handling here
}

Prowl.customSessionDelegate = MySessionDelegate()
Prowl.start()
```

## Export Logs

In the inspector toolbar:

- **Formatted Text** exports readable full entries
- **cURL Commands** exports executable requests for replay/debugging

Platform behavior:

- iOS uses `UIActivityViewController`
- macOS uses `NSSavePanel`

## Manual Inspector View

If you want to present the inspector yourself:

```swift
import SwiftUI
import ProwlUI

struct DebugPanelHost: View {
    var body: some View {
        ProwlInspectorView()
    }
}
```

## Example App

A complete usage example lives in:

```text
Example/Prowl-example
```

It includes:
- iOS tabs with live API traffic
- macOS menu bar inspector integration
- mock/edit flows and export actions

## Stop Interception

```swift
Prowl.stop()
```

## Notes

- Prowl uses native APIs only (no third-party dependencies).
- Log capture is designed to be idempotent and avoid side effects to host networking behavior.
- `URLProtocol` loop prevention is handled internally.
