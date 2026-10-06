import Foundation
import AICabCore

/// Drafts a three-level definition for a user-entered term ("Your own words").
protocol DefinitionDrafting: Sendable {
    func draft(term: String) async throws -> DraftedDefinition
}

struct DraftedDefinition: Codable, Sendable {
    var pos: String
    var beginner: String
    var builder: String
    var research: String
    var example: String?
    var analogy: String?
}

/// Calls the tiny serverless proxy in `server/define-worker` (keeps the API key off the device).
struct RemoteDefinitionDrafter: DefinitionDrafting {
    let endpoint: URL
    var session: URLSession = .shared

    enum DraftError: LocalizedError {
        case badResponse

        var errorDescription: String? { "Couldn't draft a definition right now. You can write your own." }
    }

    func draft(term: String) async throws -> DraftedDefinition {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(["term": term])
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw DraftError.badResponse }
        return try JSONDecoder().decode(DraftedDefinition.self, from: data)
    }
}
