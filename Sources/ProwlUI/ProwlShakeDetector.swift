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

    private nonisolated(unsafe) static let installToken: Void = {
        let swizzle: (AnyClass, Selector, Selector) -> Void = { c, original, swizzled in
            guard let originalMethod = class_getInstanceMethod(c, original),
                  let swizzledMethod = class_getInstanceMethod(c, swizzled) else { return }
            
            let didAddMethod = class_addMethod(
                c,
                original,
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
            )
            
            if didAddMethod {
                class_replaceMethod(
                    c,
                    swizzled,
                    method_getImplementation(originalMethod),
                    method_getTypeEncoding(originalMethod)
                )
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }

        swizzle(UIApplication.self, #selector(UIApplication.sendEvent(_:)), #selector(UIApplication.prowl_sendEvent(_:)))
        swizzle(UIWindow.self, #selector(UIWindow.motionEnded(_:with:)), #selector(UIWindow.prowl_motionEnded(_:with:)))
    }()

    static func postShakeDetected() {
        Task { @MainActor in
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
    @objc(prowl_sendEvent:) 
    dynamic func prowl_sendEvent(_ event: UIEvent) {
        prowl_sendEvent(event)
        guard event.type == .motion, event.subtype == .motionShake else { return }
        ProwlShakeMonitor.postShakeDetected()
    }
}

private extension UIWindow {
    @objc(prowl_motionEnded:withEvent:) 
    dynamic func prowl_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
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
