//
//  ProwlInspectorView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

public struct ProwlInspectorView: View {
    @StateObject private var viewModel: ProwlInspectorViewModel
    @State private var selectedLogID: NetworkLog.ID?
    @State private var iOSExportPayload: ProwlExportPayload?

    public init(storage: ProwlStorage? = nil) {
        _viewModel = StateObject(wrappedValue: ProwlInspectorViewModel(storage: storage))
    }

    public var body: some View {
        NavigationView {
            dashboardList
#if os(macOS) || os(visionOS)
            detailPane
#endif
        }
            .navigationTitle("Prowl")
            .searchable(text: $viewModel.searchText, prompt: "Search URL")
            .toolbar { toolbarContent }
            .sheet(item: $iOSExportPayload) { payload in
                ProwlActivityView(activityItems: [payload.content])
            }
    }

    private var dashboardList: some View {
        List(viewModel.filteredLogs, selection: $selectedLogID) { log in
#if os(macOS) || os(visionOS)
            ProwlDashboardRowView(log: log)
                .tag(log.id)
#else
            NavigationLink {
                ProwlLogDetailView(log: log)
            } label: {
                ProwlDashboardRowView(log: log)
            }
#endif
        }
        .overlay {
            if viewModel.filteredLogs.isEmpty {
                emptyStateView(title: "No Logs", subtitle: "No requests match your filters.")
            }
        }
    }

#if os(macOS) || os(visionOS)
    private var detailPane: some View {
        Group {
            if let selectedLog = selectedLog {
                ProwlLogDetailView(log: selectedLog)
            } else {
                emptyStateView(title: "Select a Request", subtitle: "Choose a network event to inspect.")
            }
        }
    }
#endif

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker("Status", selection: $viewModel.statusFilter) {
                ForEach(ProwlStatusCategory.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)
        }

#if !os(watchOS)
        ToolbarItem(placement: .automatic) {
            Menu("Export") {
                Button("Formatted Text") {
                    exportLogs(as: .formattedText)
                }
                Button("cURL Commands") {
                    exportLogs(as: .curlCommands)
                }
            }
        }
#endif
    }

    private var selectedLog: NetworkLog? {
        guard let selectedLogID else { return nil }
        return viewModel.filteredLogs.first(where: { $0.id == selectedLogID })
    }

    private func exportLogs(as format: ProwlExportFormat) {
        let content = ProwlLogFormatter.export(logs: viewModel.filteredLogs, as: format)
#if os(iOS)
        iOSExportPayload = ProwlExportPayload(content: content)
#elseif os(macOS)
        ProwlMacExporter.save(content: content, suggestedFileName: format.fileName)
#endif
    }

    private func emptyStateView(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
