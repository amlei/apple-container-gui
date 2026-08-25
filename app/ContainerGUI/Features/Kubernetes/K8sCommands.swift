import Foundation

// MARK: - Kubernetes clusters

extension Commands {
    static func k8sClusters() async -> [K8sCluster] {
        guard let out = try? await CLIRunner.run(["k8s", "ls"]) else { return [] }
        return parseK8sTable(out)
    }

    static func parseK8sTable(_ text: String) -> [K8sCluster] {
        var clusters: [K8sCluster] = []
        var headerCols: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let cols = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            if headerCols.isEmpty {
                headerCols = cols.map { $0.uppercased() }
                continue
            }
            guard cols.count >= 2 else { continue }
            let lower = cols.map { $0.lowercased() }
            // Identify status column value
            let state = lower.first(where: { ["running", "stopped", "exited", "created"].contains($0) }) ?? "unknown"
            // Node image: token containing ":" and "/" or "kindest"
            let image = cols.first(where: { $0.contains("/") && $0.contains(":") }) ?? "—"
            let nameIdx = headerCols.firstIndex(where: { $0.contains("CLUSTER") || $0 == "NAME" }) ?? 0
            guard nameIdx < cols.count else { continue }
            let clusterName = cols[nameIdx]
            guard let existing = clusters.firstIndex(where: { $0.name == clusterName }) else {
                clusters.append(K8sCluster(name: clusterName, state: state, nodeImage: image, nodes: 1))
                continue
            }
            clusters[existing].nodes += 1
            if clusters[existing].state == "unknown" { clusters[existing].state = state }
        }
        return clusters
    }

    static func k8sCreate(_ spec: K8sSpec) async throws { try await CLIRunner.run(spec.argv) }
    static func k8sStart(_ name: String) async throws { try await CLIRunner.run(["k8s", "start", "--name", name]) }
    static func k8sDelete(_ name: String) async throws { try await CLIRunner.run(["k8s", "delete", "--name", name]) }
    static func k8sLoadImage(_ name: String, image: String) async throws {
        try await CLIRunner.run(["k8s", "load-image", "--name", name, image])
    }
    static func k8sWriteConfig(_ name: String) async throws { try await CLIRunner.run(["k8s", "write-config", "--name", name]) }
}
