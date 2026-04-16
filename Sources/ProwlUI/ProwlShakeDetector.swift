//
//  ProwlShakeDetector.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI

#if os(iOS)
import UIKit
import ObjectiveC.runtime

public enum ProwlShakeMonitor {
    public static let didShakeNotification = Notification.Name("com.prowl.didShake")

    public static func installIfNeeded() {
        _ = installToken
    }

    private static let installToken: Void = {
        guard
            let originalMethod = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.sendEvent(_:))),
            let swizzledMethod = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.prowl_sendEvent(_:)))
        else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
}

public struct ProwlShakeDetector: View {
    public let onShake: () -> Void

    public init(onShake: @escaping () -> Void) {
        self.onShake = onShake
    }

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ProwlShakeMonitor.installIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: ProwlShakeMonitor.didShakeNotification)) { _ in
                onShake()
            }
    }
} 

private extension UIApplication {
    @objc dynamic func prowl_sendEvent(_ event: UIEvent) {
        prowl_sendEvent(event)
        guard event.type == .motion, event.subtype == .motionShake else { return }
        NotificationCenter.default.post(name: ProwlShakeMonitor.didShakeNotification, object: nil)
    }
}
#else
public struct ProwlShakeDetector: View {
    public let onShake: () -> Void

    public init(onShake: @escaping () -> Void) {
        self.onShake = onShake
    }

    public var body: some View {
        EmptyView()
    }
}
#endif
