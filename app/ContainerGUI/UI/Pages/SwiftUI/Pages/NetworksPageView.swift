import AppKit
import SwiftUI

struct NetworksPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @State private var noteDismissed = false

    var body: some View {
        PageScaffold(title: L("nav.networks")) {
            SQButton(title: L("net.new.title"), icon: "plus", primary: true) { model.show(.newNetwork) }
        } body: {
            VStack(spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                if !noteDismissed {
                    banner(title: "macOS 26", message: L("net.mac26.note")) { noteDismissed = true }
                }
                if store.networks.isEmpty {
                    SQCard {
                        SQEmpty(icon: "globe", title: L("net.empty"), hint: L("net.empty.hint"), buttonTitle: L("net.new.title")) { model.show(.newNetwork) }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 14)], spacing: 14) {
                        ForEach(store.networks) { net in
                            NetworkCardView(network: net, onDelete: {
                                model.confirm(L("del.net.title", ["n": net.name]), message: L("del.net.msg"), confirm: L("confirm.yes"), danger: true) {
                                    Task { try? await Commands.deleteNetworks([net.name]); Store.shared.refresh() }
                                }
                            })
                        }
                    }
                }
            }
        }
    }

    private func banner(title: String, message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SQ.accent)
                .padding(.top, 1)
            Text("**\(title)** · \(message)")
                .font(.system(size: 12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(SQ.text2)
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SQ.accent.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SQ.accent.opacity(0.25), lineWidth: 0.5))
    }
}

private struct NetworkCardView: View {
    let network: NetworkResourceJSON
    let onDelete: () -> Void

    var body: some View {
        SQCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    Text(network.name)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if network.isSystem { SQBadge(text: L("net.default.tag"), accent: true) }
                    if network.configuration.options?["internal"] != nil || network.name.hasPrefix("internal") {
                        SQBadge(text: L("net.internal"), icon: "shield")
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(L("net.subnet4")).foregroundStyle(SQ.text2)
                        Text(network.status?.ipv4Subnet ?? "—").font(SQ.mono).foregroundStyle(SQ.text)
                    }
                    if let s6 = network.status?.ipv6Subnet, !s6.isEmpty {
                        HStack(spacing: 6) {
                            Text(L("net.subnet6")).foregroundStyle(SQ.text2)
                            Text(s6).font(SQ.mono).foregroundStyle(SQ.text)
                        }
                    }
                    Text(L("net.attached") + ": —")
                        .font(.system(size: 12))
                        .foregroundStyle(SQ.text2)
                }
                .font(.system(size: 12))
                if !network.isSystem {
                    Divider()
                    HStack {
                        Spacer()
                        SQButton(title: L("act.delete"), icon: "trash", danger: true, small: true, action: onDelete)
                    }
                }
            }
            .padding(16)
        }
    }
}
