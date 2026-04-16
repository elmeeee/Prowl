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
            let originalMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.motionEnded(_:with:))),
            let swizzledMethod = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.prowl_motionEnded(_:with:)))
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

private extension UIWindow {
    @objc dynamic func prowl_motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        prowl_motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
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
