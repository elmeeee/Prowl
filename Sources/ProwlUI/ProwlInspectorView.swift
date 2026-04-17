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
    @State private var isSettingsPresented = false
    
    @AppStorage("prowl_color_scheme") private var themeRaw: Int = 0

    public init(storage: ProwlStorage? = nil) {
        _viewModel = StateObject(wrappedValue: ProwlInspectorViewModel(storage: storage))
    }

    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationView {
            dashboardList
                .navigationTitle("Prowl")
                .searchable(text: $viewModel.searchText, prompt: "Search URL")
                .toolbar { toolbarContent }
            #if os(macOS) || os(visionOS)
            detailPane
            #endif
        }
        .preferredColorScheme(colorScheme)
        .sheet(item: $iOSExportPayload) { payload in
            ProwlActivityView(activityItems: [payload.content])
        }
        #if os(macOS)
        .sheet(isPresented: $isSettingsPresented) {
            ProwlSettingsView(
                viewModel: viewModel,
                onExportText: { exportLogs(as: .formattedText) },
                onExportCURL: { exportLogs(as: .curlCommands) }
            )
            .frame(minWidth: 560, minHeight: 520)
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch themeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var dashboardList: some View {
        List(selection: $selectedLogID) {
            ForEach(viewModel.filteredLogs) { log in
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
            
            if !viewModel.filteredLogs.isEmpty {
                Text("Prowl • Crafted by Elmee")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
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
    #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Dismiss") {
                dismiss()
            }
        }
    #endif

    #if os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button(role: .destructive) {
                viewModel.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
    #elseif !os(watchOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button(role: .destructive) {
                viewModel.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
            
            NavigationLink(destination: ProwlSettingsView(
                viewModel: viewModel,
                onExportText: { exportLogs(as: .formattedText) },
                onExportCURL: { exportLogs(as: .curlCommands) }
            )) {
                Image(systemName: "gearshape")
            }
        }
    #else
        ToolbarItem(placement: .primaryAction) {
            NavigationLink(destination: ProwlSettingsView(
                viewModel: viewModel,
                onExportText: { exportLogs(as: .formattedText) },
                onExportCURL: { exportLogs(as: .curlCommands) }
            )) {
                Image(systemName: "gearshape")
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
    #if os(iOS)
                    .fill(Color(UIColor.secondarySystemFill))
    #else
                    .fill(Color.secondary.opacity(0.2))
    #endif
                    .frame(width: 88, height: 88)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.secondary)
                    .offset(x: -8, y: -8)
                
                Image(systemName: "network")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                    .offset(x: 10, y: 10)
            }
            .padding(.bottom, 8)
            
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
                
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 40)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
