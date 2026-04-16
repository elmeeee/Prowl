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

public enum ProwlShakeMonitor {
    public static let didShakeNotification = Notification.Name("com.prowl.didShake")
    private static let bridgeMarker = "com.prowl.shake-bridge"

    private static let debounceInterval: TimeInterval = 0.25
    @MainActor
    private static var lastPostedAt: Date?
    @MainActor
    private static var isInstalled = false
    @MainActor
    private static var keyWindowObserver: NSObjectProtocol?

    @MainActor
    public static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        attachBridgeIfNeeded()
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                attachBridgeIfNeeded()
            }
        }
    }

    @MainActor
    private static func attachBridgeIfNeeded() {
        guard let root = keyWindow()?.rootViewController else { return }
        if root.children.contains(where: { $0 is ProwlShakeBridgeViewController }) {
            return
        }

        let bridge = ProwlShakeBridgeViewController()
        bridge.view.accessibilityIdentifier = bridgeMarker
        root.addChild(bridge)
        root.view.addSubview(bridge.view)
        bridge.view.frame = .zero
        bridge.didMove(toParent: root)
        bridge.refreshFirstResponder()
    }

    @MainActor
    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foregroundWindows = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
        if let activeKeyWindow = foregroundWindows.first(where: \.isKeyWindow) {
            return activeKeyWindow
        }

        let allWindows = scenes.flatMap(\.windows)
        if let anyKeyWindow = allWindows.first(where: \.isKeyWindow) {
            return anyKeyWindow
        }
        return allWindows.first
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

@MainActor
private final class ProwlShakeBridgeViewController: UIViewController {
    override var canBecomeFirstResponder: Bool { true }

    override func loadView() {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        ProwlShakeMonitor.postShakeDetected()
    }

    func refreshFirstResponder() {
        guard view.window != nil else { return }
        _ = becomeFirstResponder()
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
