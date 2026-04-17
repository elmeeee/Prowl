//
//  ProwlMockEditorView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

public struct ProwlMockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetURLPattern: String
    @State private var mockStatusCodeStr: String
    @State private var mockBodyJSONString: String
    
    public init(log: NetworkLog) {
        _targetURLPattern = State(initialValue: log.url?.absoluteString ?? "")
        _mockStatusCodeStr = State(initialValue: "200")
        
        var defaultBodyObj = "{ \"message\": \"Mocked via Prowl\" }"
        if let body = log.responseBody,
           let txt = String(data: body.data, encoding: .utf8) {
            defaultBodyObj = txt
        }
        _mockBodyJSONString = State(initialValue: defaultBodyObj)
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Matcher Rules (URL Contains)")) {
                    TextField("Enter URL pattern to mock", text: $targetURLPattern)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Response Status Code")) {
                    TextField("e.g. 200, 404, 500", text: $mockStatusCodeStr)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Response Body (JSON Mock)")) {
                    TextEditor(text: $mockBodyJSONString)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 200)
                }
            }
            .navigationTitle("Mock Endpoint")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save & Enable") {
                    saveMock()
                }
                .font(.headline)
            )
        }
    }
    
    private func saveMock() {
        let code = Int(mockStatusCodeStr) ?? 200
        let data = mockBodyJSONString.data(using: .utf8) ?? Data()
        
        let rule = ProwlMockRule(
            targetURLPattern: targetURLPattern,
            targetMethod: "ANY",
            mockStatusCode: code,
            mockBody: data,
            isEnabled: true
        )
        
        Task {
            await ProwlMocker.shared.addRule(rule)
            await MainActor.run { dismiss() }
        }
    }
}
