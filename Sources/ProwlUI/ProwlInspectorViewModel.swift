//
//  ProwlInspectorViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

@MainActor
public final class ProwlInspectorViewModel: ObservableObject {
    @Published public var searchText = ""
    @Published public var statusFilter: ProwlStatusCategory = .all
    @Published public var contentTypeFilter: ProwlContentTypeCategory = .all
    @Published public private(set) var logs: [NetworkLog] = []

    private var streamTask: Task<Void, Never>?
    private let explicitStorage: ProwlStorage?

    public init(storage: ProwlStorage? = nil) {
        self.explicitStorage = storage
        streamTask = Task { [weak self] in
            guard let self else { return }
            let resolvedStorage: ProwlStorage
            if let storage {
                resolvedStorage = storage
            } else {
                resolvedStorage = await ProwlRuntime.shared.currentStorage()
            }
            let stream = await resolvedStorage.stream()

            for await entries in stream {
                await MainActor.run {
                    self.logs = entries.sorted(by: { $0.startedAt > $1.startedAt })
                }
            }
        }
    }

    deinit {
        streamTask?.cancel()
    }

    public var filteredLogs: [NetworkLog] {
        logs.filter { log in
            matchesSearch(log) && statusFilter.matches(log.statusCode) && contentTypeFilter.matches(log)
        }
    }

    private func matchesSearch(_ log: NetworkLog) -> Bool {
        guard !searchText.isEmpty else { return true }
        let haystack = log.url?.absoluteString.lowercased() ?? ""
        return haystack.contains(searchText.lowercased())
    }

    public func clearLogs() {
        Task {
            let targetStorage: ProwlStorage
            if let explicitStorage = explicitStorage {
                targetStorage = explicitStorage
            } else {
                targetStorage = await ProwlRuntime.shared.currentStorage()
            }
            await targetStorage.clear()
        }
    }
}

public enum ProwlContentTypeCategory: String, CaseIterable, Identifiable {
    case all = "All Types"
    case json = "JSON"
    case xml = "XML"
    case html = "HTML"
    case image = "Image"
    case other = "Other"

    public var id: String { rawValue }

    func matches(_ log: NetworkLog) -> Bool {
        guard self != .all else { return true }
        
        let headerType = log.responseHeaders.first(where: { $0.key.lowercased() == "content-type" })?.value
        let type = (log.responseBody?.contentType ?? headerType ?? "").lowercased()
        
        if type.isEmpty {
            return self == .other
        }
        
        switch self {
        case .json: return type.contains("json")
        case .xml: return type.contains("xml")
        case .html: return type.contains("html")
        case .image: return type.contains("image")
        case .other:
            let isKnown = type.contains("json") || type.contains("xml") || type.contains("html") || type.contains("image")
            return !isKnown
        case .all: return true
        }
    }
}
