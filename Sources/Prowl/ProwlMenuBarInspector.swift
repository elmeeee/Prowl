//
//  ProwlMenuBarInspector.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
import SwiftUI

@MainActor
enum ProwlMenuBarInspector {
    private static var statusItem: NSStatusItem?
    private static var menuActionHandler: MenuActionHandler?
    private static var inspectorWindowController: NSWindowController?

    static func enable() {
        guard statusItem == nil else { return }
        installStatusItem()
    }

    static func disable() {
        hide()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        menuActionHandler = nil
    }

    static func show() {
        let windowController = ensureWindowController()
        guard let window = windowController.window else { return }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func hide() {
        inspectorWindowController?.close()
    }

    static func toggle() {
        if let window = inspectorWindowController?.window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    private static func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Prowl"
            button.image = NSImage(
                systemSymbolName: "ladybug.fill",
                accessibilityDescription: "Prowl Inspector"
            )
            button.imagePosition = .imageLeading
            button.toolTip = "Open Prowl Inspector"
        }

        let menu = NSMenu()
        let actionHandler = MenuActionHandler()

        let openItem = NSMenuItem(
            title: "Open Prowl Inspector",
            action: #selector(MenuActionHandler.openInspector),
            keyEquivalent: ""
        )
        openItem.target = actionHandler
        menu.addItem(openItem)

        let hideItem = NSMenuItem(
            title: "Hide Prowl Inspector",
            action: #selector(MenuActionHandler.hideInspector),
            keyEquivalent: ""
        )
        hideItem.target = actionHandler
        menu.addItem(hideItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: "Toggle Inspector",
            action: #selector(MenuActionHandler.toggleInspector),
            keyEquivalent: "p"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = actionHandler
        menu.addItem(toggleItem)

        statusItem.menu = menu
        self.statusItem = statusItem
        menuActionHandler = actionHandler
    }

    private static func ensureWindowController() -> NSWindowController {
        if let inspectorWindowController {
            return inspectorWindowController
        }

        let host = NSHostingController(rootView: ProwlInspectorView())
        let window = NSWindow(contentViewController: host)
        window.title = "Prowl Inspector"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 980, height: 680))
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        inspectorWindowController = controller
        return controller
    }

    @MainActor
    private final class MenuActionHandler: NSObject {
        @objc func openInspector() {
            ProwlMenuBarInspector.show()
        }

        @objc func hideInspector() {
            ProwlMenuBarInspector.hide()
        }

        @objc func toggleInspector() {
            ProwlMenuBarInspector.toggle()
        }
    }
}
#endif
