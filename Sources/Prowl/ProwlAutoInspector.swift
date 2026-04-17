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

private class ProwlInspectorHostingController: UIHostingController<ProwlInspectorView> {
    override init(rootView: ProwlInspectorView) {
        super.init(rootView: rootView)
        self.modalPresentationStyle = .pageSheet
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
enum ProwlAutoInspector {
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
        guard let window = keyWindow() else { return }
        guard let root = window.rootViewController else { return }
        guard presentedInspectorController() == nil else { return }
        guard let topController = topMostViewController(from: root) else { return }

        guard !topController.isBeingPresented,
              !topController.isBeingDismissed,
              topController.presentedViewController == nil else {
            return
        }

        let inspectorView = ProwlInspectorView()
        let hostController = ProwlInspectorHostingController(rootView: inspectorView)
        topController.present(hostController, animated: true)
    }

    private static func topMostViewController(
        from controller: UIViewController?
    ) -> UIViewController? {
        guard let controller else { return nil }

        // We MUST verify presentedViewController first, because if a UINavigationController
        // has a modal presented over it, navigation.visibleViewController will miss the modal
        // and mistakenly return the underlying UI.
        if let presented = controller.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return topMostViewController(from: navigation.visibleViewController ?? navigation.topViewController)
        }
        if let tab = controller as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController)
        }
        return controller
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        
        let foregroundWindows = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            // System windows (like text effects) might not have a root view controller
            .filter { $0.rootViewController != nil }
            
        if let activeKeyWindow = foregroundWindows.first(where: \.isKeyWindow) {
            return activeKeyWindow
        }
        if let anyForeground = foregroundWindows.first {
            return anyForeground
        }

        let allWindows = scenes.flatMap(\.windows).filter { $0.rootViewController != nil }
        if let anyKeyWindow = allWindows.first(where: \.isKeyWindow) {
            return anyKeyWindow
        }
        return allWindows.first
    }

    private static func presentedInspectorController() -> UIViewController? {
        guard let root = keyWindow()?.rootViewController else { return nil }
        var cursor: UIViewController? = root
        while let current = cursor {
            if current is ProwlInspectorHostingController {
                return current
            }
            cursor = current.presentedViewController
        }
        return nil
    }
}
#endif
