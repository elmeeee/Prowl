//
//  APIService.swift
//  ProwlExample
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

struct Post: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let phone: String
    let website: String
}

struct PokemonListResponse: Codable {
    let count: Int
    let results: [PokemonEntry]
}

struct PokemonEntry: Codable, Identifiable {
    var id: String { name }
    let name: String
    let url: String
}

struct DogImageResponse: Codable {
    let message: String
    let status: String
}

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let e): return "Network: \(e.localizedDescription)"
        case .invalidResponse(let code): return "Server error: \(code)"
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        }
    }
}

@MainActor
final class APIService {
    static let shared = APIService()
    private let session = URLSession.shared

    func fetchPosts() async throws -> [Post] {
        try await get("https://jsonplaceholder.typicode.com/posts")
    }

    func fetchUsers() async throws -> [User] {
        try await get("https://jsonplaceholder.typicode.com/users")
    }

    func createPost(title: String, body: String) async throws -> Post {
        let payload = ["title": title, "body": body, "userId": "1"]
        return try await post("https://jsonplaceholder.typicode.com/posts", body: payload)
    }

    func updatePost(id: Int, title: String) async throws -> Post {
        let payload = ["id": String(id), "title": title, "body": "updated", "userId": "1"]
        return try await put("https://jsonplaceholder.typicode.com/posts/\(id)", body: payload)
    }

    func deletePost(id: Int) async throws {
        try await delete("https://jsonplaceholder.typicode.com/posts/\(id)")
    }

    func fetchPokemonList(limit: Int = 20) async throws -> [PokemonEntry] {
        let response: PokemonListResponse = try await get(
            "https://pokeapi.co/api/v2/pokemon?limit=\(limit)"
        )
        return response.results
    }

    func fetchRandomDogImage() async throws -> DogImageResponse {
        try await get("https://dog.ceo/api/breeds/image/random")
    }

    func fetchDogImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    private func get<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await execute(request)
    }

    private func post<T: Decodable>(_ urlString: String, body: [String: String]) async throws -> T {
        try await mutate(urlString, method: "POST", body: body)
    }

    private func put<T: Decodable>(_ urlString: String, body: [String: String]) async throws -> T {
        try await mutate(urlString, method: "PUT", body: body)
    }

    private func delete(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    private func mutate<T: Decodable>(_ urlString: String, method: String, body: [String: String])
        async throws -> T
    {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
