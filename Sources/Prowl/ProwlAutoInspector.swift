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
        ProwlShakeMonitor.installIfNeeded()
        observer = NotificationCenter.default.addObserver(
            forName: ProwlShakeMonitor.didShakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            presentIfNeeded()
        }
    }

    static func disable() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private static func presentIfNeeded() {
        if let lastPresentationDate, Date().timeIntervalSince(lastPresentationDate) < 0.8 {
            return
        }
        guard let topController = topMostViewController() else { return }
        guard !isInspectorAlreadyPresented(from: topController) else { return }

        let inspectorView = ProwlInspectorView()
        let hostController = UIHostingController(rootView: inspectorView)
        hostController.view.accessibilityIdentifier = inspectorMarker
        hostController.modalPresentationStyle = .automatic
        topController.present(hostController, animated: true)
        lastPresentationDate = Date()
    }

    private static func topMostViewController(
        from controller: UIViewController? = keyWindow()?.rootViewController
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
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first
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
}
#endif
