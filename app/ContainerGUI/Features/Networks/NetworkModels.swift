import Foundation

extension NetworkResourceJSON: Identifiable {}

// MARK: - Networks (`container network list --format json`)

struct NetworkResourceJSON: Codable {
    struct Configuration: Codable {
        let creationDate: Date?
        let labels: [String: String]?
        let mode: String?
        let name: String
        let options: [String: String]?
        let plugin: String?
    }
    struct Status: Codable {
        let ipv4Gateway: String?
        let ipv4Subnet: String?
        let ipv6Subnet: String?
    }
    let configuration: Configuration
    let id: String
    let status: Status?

    var name: String { configuration.name }
    var isSystem: Bool { configuration.labels?["com.apple.container.resource.role"] != nil || name == "default" }
}
