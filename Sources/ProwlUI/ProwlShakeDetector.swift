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
    private static var isInstalled = false
    @MainActor
    private static var lastPostedAt: Date?

    public static func installIfNeeded() {
        Task { @MainActor in
            guard !isInstalled else { return }
            isInstalled = true

            let applicationClass: AnyClass = object_getClass(UIApplication.shared) ?? UIApplication.self
            swizzleMethod(
                on: applicationClass,
                original: #selector(UIApplication.sendEvent(_:)),
                swizzledFrom: UIApplication.self,
                swizzled: #selector(UIApplication.prowl_sendEvent(_:))
            )
            swizzleMethod(
                on: UIWindow.self,
                original: #selector(UIWindow.motionEnded(_:with:)),
                swizzledFrom: UIWindow.self,
                swizzled: #selector(UIWindow.prowl_motionEnded(_:with:))
            )
        }
    }

    private static func swizzleMethod(
        on targetClass: AnyClass,
        original originalSelector: Selector,
        swizzledFrom sourceClass: AnyClass,
        swizzled swizzledSelector: Selector
    ) {
        guard
            let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
            let swizzledMethod = class_getInstanceMethod(sourceClass, swizzledSelector)
        else {
            return
        }

        let didAddSwizzledImplementation = class_addMethod(
            targetClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddSwizzledImplementation {
            class_replaceMethod(
                targetClass,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

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
