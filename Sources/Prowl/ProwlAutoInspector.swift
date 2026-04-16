//
//  ProwlAutoInspector.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation

#if os(iOS)
import SwiftUI
import UIKit

@MainActor
enum ProwlAutoInspector {
    private static let inspectorMarker = "com.prowl.auto-inspector"
    private static var observer: NSObjectProtocol?
    private static var lastPresentationDate: Date?

    static func enable() {
        guard observer == nil else { return }
        UIApplication.shared.applicationSupportsShakeToEdit = true
        ProwlShakeMonitor.installIfNeeded()
        observer = NotificationCenter.default.addObserver(
            forName: ProwlShakeMonitor.didShakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                toggle()
            }
        }
    }

    static func disable() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    static func show() {
        presentIfNeeded()
    }

    static func hide() {
        guard let inspector = presentedInspectorController() else { return }
        inspector.dismiss(animated: true)
    }

    static func toggle() {
        if presentedInspectorController() != nil {
            hide()
        } else {
            show()
        }
    }

    private static func presentIfNeeded() {
        if let lastPresentationDate, Date().timeIntervalSince(lastPresentationDate) < 0.8 {
            return
        }

        guard let window = keyWindow() else { return }
        guard let root = window.rootViewController else { return }
        guard !isInspectorAlreadyPresented(from: root) else { return }
        guard let topController = topMostViewController(from: root) else { return }

        guard !topController.isBeingPresented,
              !topController.isBeingDismissed,
              topController.presentedViewController == nil else {
            return
        }

        let inspectorView = ProwlInspectorView()
        let hostController = UIHostingController(rootView: inspectorView)
        hostController.view.accessibilityIdentifier = inspectorMarker
        hostController.modalPresentationStyle = .pageSheet
        topController.present(hostController, animated: true)
        lastPresentationDate = Date()
    }

    private static func topMostViewController(
        from controller: UIViewController?
    ) -> UIViewController? {
        if let navigation = controller as? UINavigationController {
            return topMostViewController(from: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController)
        }
        if let presented = controller?.presentedViewController {
            return topMostViewController(from: presented)
        }
        return controller
    }

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

    private static func isInspectorAlreadyPresented(from controller: UIViewController?) -> Bool {
        var cursor = controller
        while let current = cursor {
            if current.view.accessibilityIdentifier == inspectorMarker {
                return true
            }
            cursor = current.presentedViewController
        }
        return false
    }

    private static func presentedInspectorController() -> UIViewController? {
        guard let root = keyWindow()?.rootViewController else { return nil }
        var cursor: UIViewController? = root
        while let current = cursor {
            if current.view.accessibilityIdentifier == inspectorMarker {
                return current
            }
            cursor = current.presentedViewController
        }
        return nil
    }
}
#endif
