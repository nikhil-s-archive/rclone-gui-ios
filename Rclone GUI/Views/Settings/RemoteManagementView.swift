//
//  RemoteManagementView.swift
//  Rclone GUI — Views/Settings
//
//  Read-only catalogue of configured remotes with edit / reauthorization
//  actions. The edit action reuses AddRemoteWizard and rclone config/update.
//

import SwiftUI

struct RemoteManagementView: View {
    @State private var remotes: [RemoteSummaryDTO] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var editingRemote: RemoteSummaryDTO?
    @State private var remoteToDelete: RemoteSummaryDTO?
    @State private var actionError: String?
    @State private var publicLinkRemote: RemoteSummaryDTO?

    var body: some View {
        Group {
            if isLoading && remotes.isEmpty {
                ProgressView("Loading remotes…")
            } else if let loadError, remotes.isEmpty {
                ContentUnavailableView(
                    "Remotes unavailable",
                    systemImage: "externaldrive.badge.questionmark",
                    description: Text(loadError)
                )
            } else if remotes.isEmpty {
                ContentUnavailableView(
                    "No remotes",
                    systemImage: "externaldrive",
                    description: Text("Add or import a remote from Settings.")
                )
            } else {
                List {
                    Section {
                        ForEach(remotes) { remote in
                            remoteRow(remote)
                        }
                    } footer: {
                        Text("Existing tokens and passwords stay hidden. Leave a sensitive field empty to keep it, or enter a new value to replace it.")
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Manage remotes")
        .task { await load() }
        .sheet(item: $editingRemote) { remote in
            AddRemoteWizard(editingRemoteName: remote.name) {
                editingRemote = nil
                Task { await load() }
            }
        }
        .sheet(item: $publicLinkRemote) { remote in
            RemotePublicLinkSettingsView(remote: remote.name)
        }
        .confirmationDialog(
            "Delete this remote?",
            isPresented: Binding(
                get: { remoteToDelete != nil },
                set: { if !$0 { remoteToDelete = nil } }
            ),
            presenting: remoteToDelete
        ) { remote in
            Button("Supprimer « \(remote.name) »", role: .destructive) {
                Task { await delete(remote) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { remote in
            Text("This only removes the section from rclone.conf. Your remote files are not deleted.")
        }
        .alert(
            "Action failed",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            ),
            presenting: actionError
        ) { _ in
            Button("OK", role: .cancel) { actionError = nil }
        } message: { message in
            Text(message)
        }
    }

    private func remoteRow(_ remote: RemoteSummaryDTO) -> some View {
        HStack(spacing: 12) {
            Image(systemName: remote.isCrypt ? "lock.shield.fill" : "externaldrive.fill")
                .foregroundStyle(remote.isCrypt ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(remote.name)
                    .font(.body.weight(.semibold))
                Text(remote.type)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                publicLinkRemote = remote
            } label: {
                Label("Configurer les liens publics de \(remote.name)", systemImage: "link")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Configure a custom CDN domain")
            Button {
                editingRemote = remote
            } label: {
                Label(
                    BackendOverrides.oauthConfigs[remote.type] == nil ? "Edit" : "Edit / re-authorize",
                    systemImage: BackendOverrides.oauthConfigs[remote.type] == nil ? "pencil" : "key.fill"
                )
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(
                BackendOverrides.oauthConfigs[remote.type] == nil ? "Modifier \(remote.name)" : "Modifier ou réautoriser \(remote.name)"
            )
            .accessibilityHint("Existing sensitive values stay hidden")
            .contextMenu {
                Button {
                    editingRemote = remote
                } label: {
                    Label("Edit / re-authorize", systemImage: "pencil")
                }
                Button {
                    publicLinkRemote = remote
                } label: {
                    Label("Public links / CDN", systemImage: "link")
                }
                Button(role: .destructive) {
                    remoteToDelete = remote
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                remoteToDelete = remote
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            remotes = try await RemoteService.shared.listRemoteSummaries()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func delete(_ remote: RemoteSummaryDTO) async {
        remoteToDelete = nil
        do {
            try await RcloneConfigEditor.deleteRemote(name: remote.name)
            await load()
        } catch {
            actionError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RemoteManagementView()
    }
}
