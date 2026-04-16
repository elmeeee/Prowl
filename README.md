# Prowl

<p align="center">
  <img src="Sources/prowl_icon.png" alt="Prowl Icon" width="220" />
</p>

Prowl is a lightweight, high-performance network debugging library for the Apple ecosystem (`iOS`, `macOS`, `watchOS`, `tvOS`, `visionOS`) built with native `Foundation` + `SwiftUI` and distributed via Swift Package Manager.

## Features

- URL interception via `URLProtocol`
- Thread-safe log storage via `actor`
- FIFO log buffer (default `200`)
- Sensitive data masking (`Authorization`, `Cookie`, `password`, `token`)
- SwiftUI inspector dashboard + detail tabs
- Real-time search and status filtering
- Export logs as formatted text or cURL commands
- Activation shortcuts:
  - iOS shake gesture
  - macOS `Command + Shift + P`

## Install (SPM)

In Xcode:

1. `File` -> `Add Package Dependencies...`
2. Enter your repository URL for Prowl
3. Select dependency rule version:
   - `Up to Next Major Version` (recommended), example from `0.5.0`
   - `Up to Next Minor Version`
   - `Exact Version` (locked)
4. Add the `Prowl` product to your app target

### Version Strategy Example

- **Stable updates (recommended):** `Up to Next Major` from `0.5.0`
- **Strict lock for CI/release:** `Exact` `0.5.0`

If you use `Package.swift` directly, pin like this:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/Prowl.git", exact: "0.5.0")
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

## Check Version

You can expose/log the package version in your app:

```swift
import Prowl

print("Prowl version:", Prowl.version)
```

### 2) Open the inspector

No extra view modifier is required.

After `Prowl.start()`:

- iOS: shake device to toggle inspector
- macOS: present `ProwlInspectorView()` manually (see Manual Inspector View)

You can also control inspector manually (iOS):

```swift
Prowl.show()
Prowl.hide()
Prowl.toggle()
```

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

## Stop Interception

```swift
Prowl.stop()
```

## Notes

- Prowl uses native APIs only (no third-party dependencies).
- Log capture is designed to be idempotent and avoid side effects to host networking behavior.
- `URLProtocol` loop prevention is handled internally.
