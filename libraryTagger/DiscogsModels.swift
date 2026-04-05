//
//  DiscogsModels.swift
//  libraryTagger
//

import Foundation

// MARK: - Search Response

struct DiscogsSearchResponse: Codable {
    let pagination: DiscogsPagination
    let results: [DiscogsSearchResult]
}

struct DiscogsPagination: Codable {
    let page: Int
    let pages: Int
    let perPage: Int
    let items: Int

    enum CodingKeys: String, CodingKey {
        case page, pages, items
        case perPage = "per_page"
    }
}

struct DiscogsSearchResult: Codable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let year: String?
    let coverImage: String?
    let thumb: String?
    let resourceURL: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, year, thumb
        case coverImage = "cover_image"
        case resourceURL = "resource_url"
    }
}

// MARK: - Release Detail

struct DiscogsRelease: Codable {
    let id: Int
    let title: String
    let artistsSort: String?
    let artists: [DiscogsArtist]
    let year: Int?
    let tracklist: [DiscogsTrack]
    let genres: [String]?
    let styles: [String]?

    enum CodingKeys: String, CodingKey {
        case id, title, artists, year, tracklist, genres, styles
        case artistsSort = "artists_sort"
    }
}

struct DiscogsArtist: Codable {
    let name: String
    let id: Int
    let role: String?
}

struct DiscogsTrack: Codable, Identifiable {
    let position: String
    let title: String
    let duration: String
    var artists: [DiscogsArtist]? = nil

    var id: String { position + title }

    /// The track-level artist name, if specified (for split/compilation releases).
    var artistName: String? {
        guard let artists, !artists.isEmpty else { return nil }
        return artists.map { $0.name }.joined(separator: " / ")
    }
}
