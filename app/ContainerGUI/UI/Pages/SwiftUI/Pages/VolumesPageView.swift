import AppKit
import SwiftUI

struct VolumesPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        PageScaffold(title: L("nav.volumes")) {
            SQSearchField(placeholder: L("search.ph.volumes"), text: $search)
                .focused($searchFocused)
            SQButton(title: L("vol.new.title"), icon: "plus", primary: true) { model.show(.newVolume) }
        } body: {
            VStack(spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                if filtered.isEmpty {
                    SQCard {
                        SQEmpty(
                            icon: search.isEmpty ? "externaldrive" : "magnifyingglass",
                            title: search.isEmpty ? L("vol.empty") : L("ct.nomatch"),
                            hint: search.isEmpty ? L("vol.empty.hint") : "",
                            buttonTitle: search.isEmpty ? L("vol.new.title") : nil
                        ) { model.show(.newVolume) }
                    }
                } else {
                    SQCard {
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                Text(L("vol.name")).frame(width: 260, alignment: .leading)
                                Text(L("vol.size")).frame(width: 76, alignment: .trailing)
                                Text(L("vol.journal")).frame(width: 100, alignment: .leading)
                                Text(L("vol.attached")).frame(maxWidth: .infinity, alignment: .leading)
                                Text(L("vol.created")).frame(width: 92, alignment: .trailing)
                                Color.clear.frame(width: 40)
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SQ.text2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(SQ.fill1)

                            ForEach(filtered.indices, id: \.self) { i in
                                SQVolumeRow(volume: filtered[i])
                                if i != filtered.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: model.searchFocusTick) { _ in searchFocused = true }
    }

    private var filtered: [VolumeResourceJSON] {
        guard !search.isEmpty else { return store.volumes }
        let q = search.lowercased()
        return store.volumes.filter { $0.name.lowercased().contains(q) }
    }
}

private struct SQVolumeRow: View {
    let volume: VolumeResourceJSON
    @EnvironmentObject private var model: SQAppModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 16) {
            Text(volume.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(width: 260, alignment: .leading)
            Text(volume.configuration.sizeInBytes.map { Fmt.bytes($0) } ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .frame(width: 76, alignment: .trailing)
            SQChip(text: volume.journalMode ?? "—")
                .frame(width: 100, alignment: .leading)
            Text("—")
                .font(SQ.monoSmall)
                .foregroundStyle(SQ.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.relTime(volume.configuration.creationDate))
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .frame(width: 92, alignment: .trailing)
            Button {
                model.confirm(L("del.vol.title", ["n": volume.name]), message: L("del.vol.msg"), confirm: L("confirm.yes"), danger: true) {
                    Task { try? await Commands.deleteVolumes([volume.name]); Store.shared.refresh() }
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SQ.red)
                    .frame(width: 28, height: 26)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? SQ.red.opacity(0.1) : Color.clear))
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .opacity(hovering ? 1 : 0.5)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(hovering ? SQ.fill1 : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.openDrawer(.volume(name: volume.name)) }
    }
}
