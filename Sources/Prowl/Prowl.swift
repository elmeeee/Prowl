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
    public static let version = "0.1.0"

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
        isRunning = true
    }

    /// Unregisters `ProwlProtocol` to fully disable interception.
    public static func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isRunning else { return }
        URLProtocol.unregisterClass(ProwlProtocol.self)
        isRunning = false
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
