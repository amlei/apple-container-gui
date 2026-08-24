import AppKit
import SwiftUI

struct ImagesPageView: View {
    @ObservedObject private var store = Store.shared
    @EnvironmentObject private var model: SQAppModel
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        PageScaffold(title: L("nav.images")) {
            SQSearchField(placeholder: L("search.ph.images"), text: $search)
                .focused($searchFocused)
            SQButton(title: L("act.build"), icon: "hammer") { model.show(.build) }
            SQButton(title: L("act.pull"), icon: "arrow.down", primary: true) { model.show(.pull) }
        } body: {
            VStack(spacing: 12) {
                if !store.servicesRunning { SQOfflineBanner() }
                if filtered.isEmpty {
                    SQCard {
                        SQEmpty(
                            icon: search.isEmpty ? "square.3.layers.3d" : "magnifyingglass",
                            title: search.isEmpty ? L("img.empty") : L("img.nomatch"),
                            hint: search.isEmpty ? L("img.empty.hint") : "",
                            buttonTitle: search.isEmpty ? L("act.pull") : nil
                        ) { model.show(.pull) }
                    }
                } else {
                    SQCard {
                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                Text(L("img.ref")).frame(maxWidth: .infinity, alignment: .leading)
                                Text(L("img.size")).frame(width: 76, alignment: .trailing)
                                Text(L("img.osarch")).frame(width: 88, alignment: .leading)
                                Text(L("img.usedBy")).frame(width: 64, alignment: .center)
                                Text(L("img.created")).frame(width: 92, alignment: .trailing)
                                Color.clear.frame(width: 56)
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SQ.text2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(SQ.fill1)

                            ForEach(filtered.indices, id: \.self) { i in
                                SQImageRow(image: filtered[i])
                                if i != filtered.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: model.searchFocusTick) { _ in searchFocused = true }
    }

    private var filtered: [ImageResourceJSON] {
        guard !search.isEmpty else { return store.images }
        let q = search.lowercased()
        return store.images.filter { $0.ref.lowercased().contains(q) }
    }
}

private struct SQImageRow: View {
    let image: ImageResourceJSON
    @EnvironmentObject private var model: SQAppModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(image.ref)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(image.id)
                    .font(SQ.monoSmall)
                    .foregroundStyle(SQ.text2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.bytes(image.configuration.descriptor?.size))
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
            Text("linux/\(image.arch)")
                .font(SQ.monoSmall)
                .foregroundStyle(SQ.text)
                .frame(width: 88, alignment: .leading)
            SQChip(text: "—")
                .frame(width: 64)
            Text(Fmt.relTime(image.configuration.creationDate))
                .font(.system(size: 12))
                .foregroundStyle(SQ.text2)
                .frame(width: 92, alignment: .trailing)
            HStack(spacing: 3) {
                Button {
                    model.show(.run(image: image.ref))
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SQ.text2)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? SQ.fill2 : Color.clear))
                }
                .buttonStyle(.plain)
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SQ.text2)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? SQ.fill2 : Color.clear))
            }
            .frame(width: 56)
            .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(hovering ? SQ.fill1 : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.openDrawer(.image(ref: image.ref)) }
        .contextMenu {
            Button(L("act.runContainer")) { model.show(.run(image: image.ref)) }
            Button(L("act.push")) {
                Task { try? await Commands.pushImage(image.ref); model.showToast(L("push.doneMsg", ["ref": image.ref])) }
            }
            Button(L("act.tagNew")) { model.show(.tag(image: image.ref)) }
            Divider()
            Button(L("act.saveTar")) {
                let dlg = NSSavePanel()
                dlg.nameFieldStringValue = image.ref.components(separatedBy: "/").last?.replacingOccurrences(of: ":", with: "_").appending(".tar") ?? "image.tar"
                if let w = NSApp.keyWindow {
                    dlg.beginSheetModal(for: w) { resp in
                        guard resp == .OK, let url = dlg.url else { return }
                        Task {
                            try? await Commands.saveImage(image.ref, to: url.path)
                            model.showToast(L("saved.doneMsg", ["path": url.path]))
                        }
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                model.confirm(L("del.img.title", ["ref": image.ref]), message: L("del.img.msg"), confirm: L("confirm.yes"), danger: true) {
                    Task { try? await Commands.deleteImages([image.ref]); Store.shared.refresh() }
                }
            } label: { Text(L("act.delete")) }
        }
    }
}
