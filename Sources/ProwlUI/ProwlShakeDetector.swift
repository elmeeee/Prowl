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

    private static let debounceInterval: TimeInterval = 1.5
    @MainActor
    private static var lastPostedAt: Date?

    public static func installIfNeeded() {
        _ = installToken
    }

    private static let installToken: Void = {
        if
            let originalAppMethod = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.sendEvent(_:))),
            let swizzledAppMethod = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.prowl_sendEvent(_:)))
        {
            method_exchangeImplementations(originalAppMethod, swizzledAppMethod)
        }

        if
            let originalWindowMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.motionEnded(_:with:))),
            let swizzledWindowMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.prowl_motionEnded(_:with:)))
        {
            method_exchangeImplementations(originalWindowMethod, swizzledWindowMethod)
        }
    }()

    static func postShakeDetected() {
        MainActor.assumeIsolated {
            let now = Date()
            if let last = lastPostedAt, now.timeIntervalSince(last) < debounceInterval {
                return
            }
            lastPostedAt = now
            NotificationCenter.default.post(name: didShakeNotification, object: nil)
        }
    }
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
        ProwlShakeMonitor.postShakeDetected()
    }
}

private extension UIWindow {
    @objc dynamic func prowl_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        prowl_motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        ProwlShakeMonitor.postShakeDetected()
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
