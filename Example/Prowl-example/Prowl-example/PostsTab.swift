//
//  PostsTab.swift
//  ProwlExample
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import Combine

enum PostsLoadState {
    case idle, loading
    case loaded([Post])
    case error(String)
}

@MainActor
final class PostsViewModel: ObservableObject {
    @Published private(set) var state: PostsLoadState = .idle
    @Published private(set) var toastMessage: String? = nil

    func loadPosts() {
        state = .loading
        Task {
            do {
                let posts = try await APIService.shared.fetchPosts()
                state = .loaded(posts)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func createPost() {
        Task {
            do {
                let new = try await APIService.shared.createPost(
                    title: "New from Prowl Demo",
                    body: "This POST was intercepted by Prowl 🚀"
                )
                toast("Created post id: \(new.id)")
            } catch {
                toast("\(error.localizedDescription)")
            }
        }
    }

    func updatePost(id: Int) {
        Task {
            do {
                let updated = try await APIService.shared.updatePost(
                    id: id, title: "Updated by Prowl")
                toast("Updated: \(updated.title)")
            } catch {
                toast("\(error.localizedDescription)")
            }
        }
    }

    func deletePost(id: Int) {
        Task {
            do {
                try await APIService.shared.deletePost(id: id)
                toast("Deleted post \(id)")
            } catch {
                toast("\(error.localizedDescription)")
            }
        }
    }

    private func toast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toastMessage = nil
        }
    }
}

struct PostsTab: View {
    @StateObject private var vm = PostsViewModel()

    var body: some View {
        NavigationView {
            Group {
                switch vm.state {
                case .idle:
                    idleView
                case .loading:
                    ProgressView("Loading posts…").frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let posts):
                    postsList(posts)
                case .error(let msg):
                    errorView(msg)
                }
            }
            .navigationTitle("JSONPlaceholder")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("POST") { vm.createPost() }
                        .foregroundColor(.green)
                    Button("Refresh") { vm.loadPosts() }
                }
            }
            .overlay(alignment: .top) {
                if let toast = vm.toastMessage {
                    Text(toast)
                        .font(.footnote.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: vm.toastMessage)
        }
        .onAppear { if case .idle = vm.state { vm.loadPosts() } }
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Tap Refresh to load posts").foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func postsList(_ posts: [Post]) -> some View {
        List(posts) { post in
            VStack(alignment: .leading, spacing: 4) {
                Text(post.title.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(post.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Button("PUT") { vm.updatePost(id: post.id) }
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    Button("DELETE") { vm.deletePost(id: post.id) }
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(message).multilineTextAlignment(.center).foregroundColor(.secondary)
            Button("Retry") { vm.loadPosts() }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
