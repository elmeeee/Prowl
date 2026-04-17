//
//  Prowl.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation
import ProwlCore
@_exported import ProwlUI

@MainActor
public enum Prowl {
    public static let version = "0.5.13"

    private static var isRunning = false

    public static func storage() async -> ProwlStorage {
        await ProwlRuntime.shared.currentStorage()
    }

    /// URLs that should be ignored by Prowl's interceptor.
    public static var ignoredURLs: Set<String> {
        get { ProwlRuntime.ignoredURLs }
        set { ProwlRuntime.ignoredURLs = newValue }
    }
    
    /// Optional custom URLSessionDelegate to handle Certificate Pinning / mTLS
    public static var customSessionDelegate: URLSessionDelegate? {
        get { ProwlRuntime.customSessionDelegate }
        set { ProwlRuntime.customSessionDelegate = newValue }
    }

    public static func ignoreURL(_ urlString: String) {
        ProwlRuntime.ignoredURLs.insert(urlString)
    }

    /// Registers `ProwlProtocol` once for process-wide interception.
    public static func start(ignoredURLs: [String] = []) {
        guard !isRunning else { return }

        ignoredURLs.forEach { ignoreURL($0) }

        URLProtocol.registerClass(ProwlProtocol.self)
        #if os(iOS)
            ProwlAutoInspector.enable()
        #elseif os(macOS)
            ProwlMenuBarInspector.enable()
        #endif
        isRunning = true

        print("Prowl Inspector v\(version) started | Crafted by Elmee")
    }

    /// Unregisters `ProwlProtocol` to fully disable interception.
    public static func stop() {
        guard isRunning else { return }
        URLProtocol.unregisterClass(ProwlProtocol.self)
        #if os(iOS)
            ProwlAutoInspector.disable()
        #elseif os(macOS)
            ProwlMenuBarInspector.disable()
        #endif
        isRunning = false
    }

    /// Shows Prowl inspector manually (iOS only).
    public static func show() {
        if !isRunning {
            start()
        }
        #if os(iOS)
            ProwlAutoInspector.show()
        #elseif os(macOS)
            ProwlMenuBarInspector.show()
        #endif
    }

    /// Hides Prowl inspector manually (iOS only).
    public static func hide() {
        guard isRunning else { return }
        #if os(iOS)
            ProwlAutoInspector.hide()
        #elseif os(macOS)
            ProwlMenuBarInspector.hide()
        #endif
    }

    /// Toggles Prowl inspector manually (iOS only).
    public static func toggle() {
        if !isRunning {
            start()
        }
        #if os(iOS)
            ProwlAutoInspector.toggle()
        #elseif os(macOS)
            ProwlMenuBarInspector.toggle()
        #endif
    }

    /// Allows host apps to override defaults while preserving zero side-effects.
    public static func configure(
        storage: ProwlStorage? = nil,
        masker: SensitiveDataMasker? = nil
    ) {
        Task {
            await ProwlRuntime.shared.configure(storage: storage, masker: masker)
        }
    }
}
