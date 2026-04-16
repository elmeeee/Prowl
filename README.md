# Prowl

See the Unseen Stream.

![Prowl Icon](prowl_icon.png)

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
3. Add the `Prowl` product to your app target

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

### 2) Attach the inspector UI

Attach this to your root view:

```swift
import Prowl

struct ContentView: View {
    var body: some View {
        MainScreen()
            .prowlInspector()
    }
}
```

That gives:

- iOS: shake device to toggle inspector
- macOS (desktop): press `Command + Shift + P` to toggle inspector

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
# Prowl
