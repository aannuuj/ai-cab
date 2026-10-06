import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Published next to each content pack so the app can check for updates cheaply.
public struct ContentManifest: Codable, Sendable {
    public var version: Int
    /// Absolute URL, or a path relative to the manifest.
    public var url: String
    public var minimumAppBuild: Int?

    public init(version: Int, url: String, minimumAppBuild: Int? = nil) {
        self.version = version
        self.url = url
        self.minimumAppBuild = minimumAppBuild
    }
}

public protocol RemoteContentFetching: Sendable {
    /// Returns a newer pack, or nil when the installed version is current.
    func fetchPack(newerThan version: Int) async throws -> ContentPack?
}

/// Weekly content drops served as static JSON (GitHub Pages / any CDN). No SDK, no backend.
public struct RemoteContentClient: RemoteContentFetching {
    public let manifestURL: URL
    public let appBuild: Int
    private let session: URLSession

    public init(manifestURL: URL, appBuild: Int, session: URLSession = .shared) {
        self.manifestURL = manifestURL
        self.appBuild = appBuild
        self.session = session
    }

    public func fetchPack(newerThan version: Int) async throws -> ContentPack? {
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (manifestData, _) = try await session.data(for: request)
        let manifest = try JSONDecoder().decode(ContentManifest.self, from: manifestData)
        guard manifest.version > version else { return nil }
        if let minimum = manifest.minimumAppBuild, minimum > appBuild { return nil }
        guard let packURL = URL(string: manifest.url, relativeTo: manifestURL) else { return nil }
        let (packData, _) = try await session.data(from: packURL.absoluteURL)
        let pack = try JSONDecoder().decode(ContentPack.self, from: packData)
        return pack.version > version ? pack : nil
    }
}

/// Keeps the last downloaded pack on disk so updates survive relaunches offline.
public struct ContentCache: Sendable {
    private let file: JSONFile<ContentPack>

    public init(directory: URL = SharedContainer.url) {
        file = JSONFile(url: directory.appendingPathComponent("content-cache.json"))
    }

    public func load() -> ContentPack? { file.read() }
    public func save(_ pack: ContentPack) throws { try file.write(pack) }
}

public enum ContentLoader {
    public enum LoadError: Error {
        case missingBundledContent
    }

    public static func decode(_ data: Data) throws -> ContentPack {
        try JSONDecoder().decode(ContentPack.self, from: data)
    }

    public static func bundled(in bundle: Bundle = .main, resource: String = "content") throws -> ContentPack {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw LoadError.missingBundledContent
        }
        return try decode(Data(contentsOf: url))
    }

    /// Picks whichever pack is newer. The bundled pack wins ties so app updates always apply.
    public static func newest(bundled: ContentPack, cached: ContentPack?) -> ContentPack {
        guard let cached, cached.version > bundled.version else { return bundled }
        return cached
    }
}
