//
//  ContentView.swift
//  ProwlExample
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PostsTab()
                .tabItem {
                    Label("Posts", systemImage: "doc.text.fill")
                }

            UsersTab()
                .tabItem {
                    Label("Users", systemImage: "person.2.fill")
                }

            PokemonTab()
                .tabItem {
                    Label("Pokémon", systemImage: "theatermasks.fill")
                }

            DogTab()
                .tabItem {
                    Label("Dog", systemImage: "pawprint.fill")
                }
        }
        .overlay(alignment: .bottom) {
            Text("Shake to open Prowl Inspector")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 80)
        }
    }
}

#Preview {
    ContentView()
}
