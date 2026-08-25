import Foundation

/// K8s cluster row parsed from `container k8s ls` table output.
struct K8sCluster {
    var name: String
    var state: String      // running / stopped / exited
    var nodeImage: String
    var nodes: Int
    var isRunning: Bool { state.lowercased().contains("running") }
}

extension K8sCluster: Identifiable {
    var id: String { name }
}

// MARK: - K8s (`container k8s ls`)

struct K8sSpec {
    var name: String
    var nodeImage: String?
    var cpus: Int?
    var memory: String?
    var autoRemove = false

    var argv: [String] {
        var a = ["k8s", "create", "--name", name]
        if let n = nodeImage, !n.isEmpty { a += ["--node-image", n] }
        if let c = cpus { a += ["--cpus", "\(c)"] }
        if let m = memory, !m.isEmpty { a += ["--memory", m] }
        if autoRemove { a.append("--rm") }
        return a
    }
}
