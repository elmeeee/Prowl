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
                    
                    Button(role: .none, action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onExportCURL()
                        }
                    }) {
                        Label("Share cURL Commands", systemImage: "terminal")
                    }
                }
                
                Section(header: Text("Environment Info")) {
                    labeledStatRow(title: "App Name", value: appName)
                    labeledStatRow(title: "App Version", value: appVersion)
                    labeledStatRow(title: "Minimum OS", value: minOSVersion)
                    labeledStatRow(title: "OS Version", value: osVersion)
                    labeledStatRow(title: "Screen Size", value: screenResolution)
                }
            }
        .navigationTitle("Settings")
    }

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

    private func labeledStatRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}
