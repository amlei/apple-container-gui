import Testing
import Foundation
@testable import ContainerGUI

struct ModelsTests {
    @Test func decodesRunningContainer() throws {
        let json = #"""
        {"configuration":{"id":"abc123","image":{"reference":"img:1"}},"status":{"state":"running"}}
        """#
        let data = Data(json.utf8)
        let container = try Commands.decoder.decode(ManagedContainer.self, from: data)
        #expect(container.id == "abc123")
        #expect(container.imageRef == "img:1")
        #expect(container.isRunning)
    }

    @Test func statsCpuPercent() {
        let stats = ContainerStatsSnapshot(
            id: "x",
            memoryUsageBytes: nil,
            memoryLimitBytes: nil,
            cpuUsageUsec: 50_000,
            networkRxBytes: nil,
            networkTxBytes: nil,
            blockReadBytes: nil,
            blockWriteBytes: nil,
            numProcesses: nil
        )
        #expect(stats.cpuPercent == 5.0)
    }
}
