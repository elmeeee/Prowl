//
//  PokemonTab.swift
//  ProwlExample
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
final class PokemonViewModel: ObservableObject {
    @Published private(set) var pokemon: [PokemonEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    func load(limit: Int = 20) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                pokemon = try await APIService.shared.fetchPokemonList(limit: limit)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct PokemonTab: View {
    @StateObject private var vm = PokemonViewModel()
    @State private var limit = 20

    private let limits = [10, 20, 50, 100]

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Catching Pokémon…").frame(
                        maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text("⚠️").font(.system(size: 48))
                        Text(error).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { vm.load(limit: limit) }.buttonStyle(.bordered)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                } else {
                    List(vm.pokemon) { entry in
                        HStack(spacing: 12) {
                            // Pokémon number from URL
                            if let number = entry.url.split(separator: "/").last.flatMap({ Int($0) }
                            ) {
                                AsyncImage(
                                    url: URL(
                                        string:
                                            "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(number).png"
                                    )
                                ) { img in
                                    img.resizable().scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 44, height: 44)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name.capitalized)
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("PokéAPI")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("Limit", selection: $limit) {
                        ForEach(limits, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: limit) { _, newValue in
                        vm.load(limit: newValue)
                    }

                    Button("Fetch") { vm.load(limit: limit) }
                }
            }
        }
        .onAppear { vm.load(limit: limit) }
    }
}
