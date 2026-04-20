//
//  UsersTab.swift
//  ProwlExample
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
final class UsersViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                users = try await APIService.shared.fetchUsers()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct UsersTab: View {
    @StateObject private var vm = UsersViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Fetching users…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "person.fill.xmark").font(.system(size: 48))
                            .foregroundColor(.red)
                        Text(error).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button("Retry") { vm.load() }.buttonStyle(.bordered)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
                } else {
                    List(vm.users) { user in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name).font(.subheadline.weight(.semibold))
                                    Text(user.email).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            HStack(spacing: 16) {
                                Label(user.phone, systemImage: "phone")
                                Label(user.website, systemImage: "globe")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Users (GET)")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") { vm.load() }
                }
            }
        }
        .onAppear { vm.load() }
    }
}
