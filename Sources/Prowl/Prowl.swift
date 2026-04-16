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
    /// Semantic version of the distributed Prowl package.
    public static let version = "0.5.1"

    private static let stateLock = NSLock()
    private static var isRunning = false

    public static func storage() async -> ProwlStorage {
        await ProwlRuntime.shared.currentStorage()
    }

    /// Registers `ProwlProtocol` once for process-wide interception.
    public static func start() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isRunning else { return }
        URLProtocol.registerClass(ProwlProtocol.self)
    #if os(iOS)
        ProwlAutoInspector.enable()
    #endif
        isRunning = true
    }

    /// Unregisters `ProwlProtocol` to fully disable interception.
    public static func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isRunning else { return }
        URLProtocol.unregisterClass(ProwlProtocol.self)
    #if os(iOS)
        ProwlAutoInspector.disable()
    #endif
        isRunning = false
    }

    /// Shows Prowl inspector manually (iOS only).
    public static func show() {
        guard isRunning else { return }
#if os(iOS)
        ProwlAutoInspector.show()
#endif
    }

    /// Hides Prowl inspector manually (iOS only).
    public static func hide() {
        guard isRunning else { return }
#if os(iOS)
        ProwlAutoInspector.hide()
#endif
    }

    /// Toggles Prowl inspector manually (iOS only).
    public static func toggle() {
        guard isRunning else { return }
#if os(iOS)
        ProwlAutoInspector.toggle()
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
