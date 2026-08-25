import AppKit
import SwiftUI

struct MachinesPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel

    var body: some View {
        PageScaffold(title: L("nav.machines")) {
            SQButton(title: L("mach.new.title"), icon: "plus", primary: true) { model.show(.newMachine) }
        } body: {
            VStack(alignment: .leading, spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                Text(L("mach.sub"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(SQ.text2)
                    .padding(.horizontal, 2)
                if store.machines.isEmpty {
                    SQCard {
                        SQEmpty(icon: "display", title: L("mach.empty"), hint: L("mach.empty.hint"), buttonTitle: L("mach.new.title")) { model.show(.newMachine) }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14)], spacing: 14) {
                        ForEach(store.machines, id: \.id) { m in
                            MachineCardView(machine: m)
                        }
                    }
                }
            }
        }
    }
}

private struct MachineCardView: View {
    let machine: MachineResourceJSON
    @EnvironmentObject private var model: SQAppModel

    var body: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Text(machine.name)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if machine.default == true { SQBadge(text: L("mach.default"), icon: "star", orange: true) }
                    SQPill(text: machine.isRunning ? L("mach.running") : L("mach.stopped"), ok: machine.isRunning)
                }
                VStack(alignment: .leading, spacing: 5) {
                    kvLine(L("mach.image"), machine.imageReference)
                    kvLine(L("mach.resources"), "\(machine.cpus ?? 0) CPU · \(Fmt.bytes(machine.memory ?? 0))")
                    kvLine(L("mach.home"), machine.homeMountText)
                    kvLine(L("mach.created"), Fmt.relTime(machine.createdDate))
                }
                .font(.system(size: 12))

                Divider()
                HStack(spacing: 8) {
                    if machine.default != true {
                        SQButton(title: L("act.setDefault"), icon: "star", small: true) {
                            Task { try? await Commands.machineSetDefault(machine.name); Store.shared.refresh() }
                        }
                    }
                    Spacer()
                    if machine.isRunning {
                        SQButton(title: L("act.shell"), icon: "terminal", small: true) {
                            model.openDrawer(.machineShell(name: machine.name))
                        }
                        SQButton(title: L("act.stop"), icon: "stop.fill", small: true) {
                            Task { try? await Commands.machineStop(machine.name); Store.shared.refresh() }
                        }
                    } else {
                        SQButton(title: L("act.start"), icon: "play.fill", small: true) {
                            Task { try? await Commands.machineSet(name: machine.name, settings: ["start"]); Store.shared.refresh() }
                        }
                    }
                    Menu {
                        Button { model.show(.machineConfig(name: machine.name)) } label: {
                            Label(L("act.config"), systemImage: "slider.horizontal.3")
                        }
                        Button { model.openDrawer(.machineLogs(name: machine.name)) } label: {
                            Label(L("act.viewLogs"), systemImage: "doc.text")
                        }
                        Divider()
                        Button(role: .destructive) {
                            model.confirm(L("del.mach.title", ["n": machine.name]), message: L("del.mach.msg"), confirm: L("confirm.yes"), danger: true) {
                                Task { try? await Commands.machineDelete(machine.name); Store.shared.refresh() }
                            }
                        } label: { Label(L("act.delete"), systemImage: "trash").foregroundStyle(SQ.red) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SQ.text2)
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SQ.fill1))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            .padding(16)
        }
    }

    private func kvLine(_ key: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(key).foregroundStyle(SQ.text2)
            Text(value).font(SQ.mono).foregroundStyle(SQ.text)
        }
    }
}
