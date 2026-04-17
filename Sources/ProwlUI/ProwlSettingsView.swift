//
//  ProwlSettingsView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore
#if os(iOS) || os(visionOS)
import UIKit
#endif

public struct ProwlSettingsView: View {
    @ObservedObject var viewModel: ProwlInspectorViewModel
    public var onExportText: () -> Void
    public var onExportCURL: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("prowl_color_scheme") private var themeRaw: Int = 0
    
    public init(
        viewModel: ProwlInspectorViewModel,
        onExportText: @escaping () -> Void,
        onExportCURL: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onExportText = onExportText
        self.onExportCURL = onExportCURL
    }

    public var body: some View {
        Group {
            #if os(macOS)
            macSettingsLayout
            #else
            defaultSettingsLayout
            #endif
        }
        .navigationTitle("Settings")
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        #endif
    }

    private var defaultSettingsLayout: some View {
        Form {
            Section(header: Text("Statistics")) {
                labeledStatRow(title: "Total Requests", value: "\(viewModel.logs.count)")
                labeledStatRow(title: "Success Rate (2xx)", value: successRateString)
                labeledStatRow(title: "Total Errors (4xx/5xx)", value: "\(errorCount)")
            }

            Section(header: Text("Filters")) {
                Picker("Response Status", selection: $viewModel.statusFilter) {
                    ForEach(ProwlStatusCategory.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker("Content Type", selection: $viewModel.contentTypeFilter) {
                    ForEach(ProwlContentTypeCategory.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            }

            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $themeRaw) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Export & Share")) {
                exportJSONButton
                exportCURLButton
            }

            Section(header: Text("Environment Info")) {
                labeledStatRow(title: "App Name", value: appName)
                labeledStatRow(title: "App Version", value: appVersion)
                labeledStatRow(title: "Minimum OS", value: minOSVersion)
                labeledStatRow(title: "OS Version", value: osVersion)
                labeledStatRow(title: "Screen Size", value: screenResolution)
            }
        }
    }

    #if os(macOS)
    private var macSettingsLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                macSection("Statistics") {
                    labeledStatRow(title: "Total Requests", value: "\(viewModel.logs.count)")
                    labeledStatRow(title: "Success Rate (2xx)", value: successRateString)
                    labeledStatRow(title: "Total Errors (4xx/5xx)", value: "\(errorCount)")
                }

                macSection("Filters") {
                    VStack(alignment: .leading, spacing: 10) {
                        labeledControlRow(title: "Response Status") {
                            Picker("Response Status", selection: $viewModel.statusFilter) {
                                ForEach(ProwlStatusCategory.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        labeledControlRow(title: "Content Type") {
                            Picker("Content Type", selection: $viewModel.contentTypeFilter) {
                                ForEach(ProwlContentTypeCategory.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }
                    }
                }

                macSection("Appearance") {
                    labeledControlRow(title: "Theme") {
                        Picker("Theme", selection: $themeRaw) {
                            Text("System").tag(0)
                            Text("Light").tag(1)
                            Text("Dark").tag(2)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 230)
                    }
                }

                macSection("Export & Share") {
                    HStack(spacing: 10) {
                        exportJSONButton
                        exportCURLButton
                    }
                    .buttonStyle(.borderedProminent)
                }

                macSection("Environment Info") {
                    labeledStatRow(title: "App Name", value: appName)
                    labeledStatRow(title: "App Version", value: appVersion)
                    labeledStatRow(title: "Minimum OS", value: minOSVersion)
                    labeledStatRow(title: "OS Version", value: osVersion)
                    labeledStatRow(title: "Screen Size", value: screenResolution)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func macSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    #endif

    private var successRateString: String {
        let total = viewModel.logs.count
        guard total > 0 else { return "0%" }
        let successCount = viewModel.logs.filter { ($0.statusCode ?? 0) >= 200 && ($0.statusCode ?? 0) < 300 }.count
        let percentage = (Double(successCount) / Double(total)) * 100
        return String(format: "%.1f%%", percentage)
    }

    private var errorCount: Int {
        viewModel.logs.filter { ($0.statusCode ?? 0) >= 400 || $0.errorDescription != nil }.count
    }

    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? 
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? ""
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var minOSVersion: String {
        Bundle.main.infoDictionary?["MinimumOSVersion"] as? String ?? "Not Specified"
    }

    private var osVersion: String {
    #if os(iOS) || os(visionOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    #elseif os(macOS)
        return "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    #else
        return "Unknown OS"
    #endif
    }

    private var screenResolution: String {
    #if os(iOS) || os(visionOS)
        let bounds = UIScreen.main.bounds
        return "\(Int(bounds.width)) x \(Int(bounds.height))"
    #else
        return "Undefined"
    #endif
    }

    private var exportJSONButton: some View {
        Button(role: .none, action: {
            dismiss()

            // Adding slight delay allowing modal dismissal animation to complete
            // before prompting UIActivityViewController to avoid hierarchy alerts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onExportText()
            }
        }) {
            Label("Share / Email Logs (JSON)", systemImage: "envelope")
        }
    }

    private var exportCURLButton: some View {
        Button(role: .none, action: {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onExportCURL()
            }
        }) {
            Label("Share cURL Commands", systemImage: "terminal")
        }
    }

    private func labeledStatRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledControlRow<Content: View>(
        title: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer(minLength: 12)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
