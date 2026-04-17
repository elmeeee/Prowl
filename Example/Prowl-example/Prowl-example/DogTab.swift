//
//  DogTab.swift
//  ProwlExample
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class DogViewModel: ObservableObject {
    @Published private(set) var imageURL: URL? = nil
    @Published private(set) var imageData: Data? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var fetchCount = 0

    func fetchNewDog() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                // Step 1: GET JSON metadata — Prowl logs this as JSON response
                let response = try await APIService.shared.fetchRandomDogImage()
                imageURL = URL(string: response.message)

                // Step 2: GET actual image binary — Prowl logs this as image/jpeg response
                // Open Prowl inspector and tap this log → Body tab shows the actual image!
                if let url = imageURL {
                    imageData = try await APIService.shared.fetchDogImageData(
                        from: url.absoluteString)
                }
                fetchCount += 1
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct DogTab: View {
    @StateObject private var vm = DogViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Dog image display
                Group {
                    if vm.isLoading {
                        ProgressView("Fetching woof…")
                            .frame(width: 280, height: 280)
                    } else if let data = vm.imageData {
                        imagePreview(from: data)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .overlay {
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                    }
                }
                .animation(.spring(response: 0.4), value: vm.imageData)

                // Error
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // URL label
                if let url = vm.imageURL {
                    Text(url.lastPathComponent)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Counter
                if vm.fetchCount > 0 {
                    Text("\(vm.fetchCount) requests captured by Prowl 🐾")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                Button {
                    vm.fetchNewDog()
                } label: {
                    Label("Fetch New Dog", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)

                Text("🔍 Shake phone → open Prowl → tap the image/jpeg log → Body tab")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Dog CEO API")
        }
        .onAppear { vm.fetchNewDog() }
    }

    @ViewBuilder
    private func imagePreview(from data: Data) -> some View {
    #if canImport(UIKit)
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 300)
                .cornerRadius(20)
                .shadow(radius: 12)
                .transition(.scale.combined(with: .opacity))
        }
    #elseif canImport(AppKit)
        if let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 300)
                .cornerRadius(20)
                .shadow(radius: 12)
                .transition(.scale.combined(with: .opacity))
        }
    #else
        EmptyView()
    #endif
    }
}
