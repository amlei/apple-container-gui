import Foundation

// MARK: - Volumes (`container volume list --format json`)

struct VolumeResourceJSON: Codable {
    struct Configuration: Codable {
        let name: String
        let driver: String?
        let format: String?
        let source: String?
        let creationDate: Date?
        let labels: [String: String]?
        let options: [String: String]?
        let sizeInBytes: UInt64?
    }
    let configuration: Configuration
    let id: String

    var name: String { configuration.name }
    var journalMode: String? { configuration.options?["journal"] }
}
