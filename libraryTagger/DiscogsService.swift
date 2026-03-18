//
//  DiscogsService.swift
//  libraryTagger
//

import Foundation

enum DiscogsError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .rateLimited(let retry):
            return "Rate limited. Retry after \(Int(retry)) seconds."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor DiscogsService {
    static let shared = DiscogsService()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Discogs token=\(DiscogsConfig.token)",
            "User-Agent": DiscogsConfig.userAgent
        ]
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Search

    /// Search Discogs for releases matching a query and optional artist.
    func searchTrack(query: String, artist: String? = nil,
                     page: Int = 1, perPage: Int = 5) async throws -> DiscogsSearchResponse {
        var components = URLComponents(string: "\(DiscogsConfig.baseURL)/database/search")!
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "release"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        if let artist, !artist.isEmpty {
            queryItems.append(URLQueryItem(name: "artist", value: artist))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw DiscogsError.invalidURL }
        return try await performRequest(url: url)
    }

    // MARK: - Release Details

    /// Fetch full release details including tracklist.
    func getRelease(id: Int) async throws -> DiscogsRelease {
        guard let url = URL(string: "\(DiscogsConfig.baseURL)/releases/\(id)") else {
            throw DiscogsError.invalidURL
        }
        return try await performRequest(url: url)
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw DiscogsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscogsError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 429 {
            let retryAfter = Double(
                httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60"
            ) ?? 60.0
            throw DiscogsError.rateLimited(retryAfter: retryAfter)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DiscogsError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DiscogsError.decodingError(error)
        }
    }
}
