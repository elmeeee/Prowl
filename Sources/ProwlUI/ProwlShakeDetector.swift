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

public enum ProwlShakeMonitor: Sendable {
    public static let didShakeNotification = Notification.Name("com.prowl.didShake")

    private static let debounceInterval: TimeInterval = 0.25
    private static let lastPostedLock = NSLock()
    private static var _lastPostedAt: Date?

    public static func installIfNeeded() {
        _ = installToken
    }

    private nonisolated(unsafe) static let installToken: Void = {
        if
            let originalMethod = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.sendEvent(_:))),
            let swizzledMethod = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.prowl_sendEvent(_:)))
        {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        if
            let originalWindowMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.motionEnded(_:with:))),
            let swizzledWindowMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.prowl_motionEnded(_:with:)))
        {
            method_exchangeImplementations(originalWindowMethod, swizzledWindowMethod)
        }

        if
            let originalWindowBeganMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.motionBegan(_:with:))),
            let swizzledWindowBeganMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.prowl_motionBegan(_:with:)))
        {
            method_exchangeImplementations(originalWindowBeganMethod, swizzledWindowBeganMethod)
        }
    }()

    static func postShakeDetected() {
        let now = Date()
        lastPostedLock.lock()
        if let last = _lastPostedAt, now.timeIntervalSince(last) < debounceInterval {
            lastPostedLock.unlock()
            return
        }
        _lastPostedAt = now
        lastPostedLock.unlock()

        DispatchQueue.main.async {
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
    @objc dynamic func prowl_motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        prowl_motionBegan(motion, with: event)
        guard motion == .motionShake else { return }
        ProwlShakeMonitor.postShakeDetected()
    }

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
