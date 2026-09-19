//
//  CryptSetupView.swift
//  Rclone GUI — Views/Settings/AddRemote
//
//  Guided crypt setup. Instead of the generic dynamic form (where the user
//  would have to hand-type `remote = gdrive:folder`), this walks them through:
//    1. Picking the underlying (plaintext) remote that crypt will wrap.
//    2. Browsing that remote to choose the destination folder.
//    3. Setting the encryption password (+ optional salt) and name-encryption.
//
//  Selections are committed into WizardState.fieldValues (via
//  commitCryptFieldValues) on advance, so the recap + config/create steps
//  treat crypt like any other backend. rclone obscures the password at write
//  time (config/create opt.obscure = true, set in RecapAndTestView).
//

import SwiftUI

struct CryptSetupView: View {

    @Bindable var state: WizardState
    let onNext: () -> Void

    @State private var remotes: [RemoteSummaryDTO] = []
    @State private var loadingRemotes = true
    @State private var loadError: String?
    @State private var confirmPassword = ""
    @State private var showFolderPicker = false

    /// Non-crypt remotes only — wrapping a crypt in another crypt is almost
    /// never what the user wants here.
    private var selectableRemotes: [RemoteSummaryDTO] {
        remotes.filter { !$0.isCrypt }
    }

    private var passwordsMatch: Bool {
        confirmPassword == state.cryptPassword
    }

    var body: some View {
        Form {
            underlyingSection
            folderSection
            passwordSection
            encryptionSection
        }
        .task { await loadRemotes() }
        .sheet(isPresented: $showFolderPicker) {
            CryptFolderPicker(
                remote: state.cryptUnderlyingRemote,
                initialPath: state.cryptFolderPath
            ) { picked in
                state.cryptFolderPath = picked
                showFolderPicker = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") { onNext() }
                    .disabled(!state.canProceedFromCrypt || !passwordsMatch)
            }
        }
    }

    // MARK: - Underlying remote

    @ViewBuilder
    private var underlyingSection: some View {
        Section {
            if loadingRemotes {
                HStack {
                    ProgressView()
                    Text("Loading remotes…").foregroundStyle(.secondary)
                }
            } else if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if selectableRemotes.isEmpty {
                Label("No storage available. Add a remote first (Drive, S3, SFTP…), then come back to create the vault.",
                      systemImage: "externaldrive.badge.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Storage", selection: $state.cryptUnderlyingRemote) {
                    Text("Choose…").tag("")
                    ForEach(selectableRemotes) { remote in
                        Text("\(remote.name) (\(remote.type))").tag(remote.name)
                    }
                }
                .onChange(of: state.cryptUnderlyingRemote) { _, _ in
                    // Le dossier choisi appartenait au remote précédent — on le
                    // réinitialise quand on change de stockage.
                    state.cryptFolderPath = ""
                }
            }
        } header: {
            Text("Underlying storage")
        } footer: {
            Text("The vault encrypts files on top of this remote. Data stays with the provider, but end-to-end encrypted.")
        }
    }

    // MARK: - Folder

    @ViewBuilder
    private var folderSection: some View {
        Section {
            Button {
                showFolderPicker = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Destination folder")
                                .foregroundStyle(.primary)
                            Text(folderDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } icon: {
                        Image(systemName: "folder")
                    }
                    Spacer()
                    Text("Browse")
                        .font(.callout)
                        .foregroundStyle(RG.accent)
                }
            }
            .buttonStyle(.plain)
            .disabled(state.cryptUnderlyingRemote.isEmpty)
        } header: {
            Text("Folder")
        } footer: {
            Text("Where the vault lives in the remote. Leave at the root to encrypt the whole remote.")
        }
    }

    private var folderDisplay: String {
        guard !state.cryptUnderlyingRemote.isEmpty else {
            return String(localized: "Select a storage first")
        }
        return state.cryptRemoteValue
    }

    // MARK: - Password

    @ViewBuilder
    private var passwordSection: some View {
        Section {
            SecureField("Password", text: $state.cryptPassword)
            SecureField("Confirm password", text: $confirmPassword)
            if !confirmPassword.isEmpty && !passwordsMatch {
                Label("Passwords do not match.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            SecureField("Salt / password2 (optional)", text: $state.cryptPassword2)
        } header: {
            Text("Password")
        } footer: {
            Text("Without this password the files are unrecoverable — it is stored only on your device. The salt (password2) strengthens encryption; keep it too.")
        }
    }

    // MARK: - Encryption options

    @ViewBuilder
    private var encryptionSection: some View {
        Section {
            Picker("File names", selection: $state.cryptFilenameEncryption) {
                Text("Encrypted (standard)").tag("standard")
                Text("Obfuscated").tag("obfuscate")
                Text("Plain (off)").tag("off")
            }
            Toggle("Encrypt folder names", isOn: $state.cryptDirNameEncryption)
        } header: {
            Text("Name encryption")
        } footer: {
            Text("“Standard” encrypts file and folder names. “Plain” keeps names readable (handy to find files on the provider side).")
        }
    }

    // MARK: - Loading

    private func loadRemotes() async {
        loadingRemotes = true
        defer { loadingRemotes = false }
        do {
            remotes = try await RemoteService.shared.listRemoteSummaries()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Folder picker

/// Lightweight directory browser used to pick the crypt destination folder
/// inside the underlying remote. Navigates with a path stack; each level lists
/// only sub-folders and offers a "use this folder" action.
private struct CryptFolderPicker: View {
    let remote: String
    let initialPath: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            CryptFolderLevel(remote: remote, path: "", onPick: pick)
                .navigationTitle("\(remote):")
                .navigationDestination(for: String.self) { p in
                    CryptFolderLevel(remote: remote, path: p, onPick: pick)
                        .navigationTitle(displayName(p))
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private func pick(_ folder: String) {
        onPick(folder)
        dismiss()
    }

    private func displayName(_ p: String) -> String {
        (p as NSString).lastPathComponent
    }
}

private struct CryptFolderLevel: View {
    let remote: String
    let path: String
    let onPick: (String) -> Void

    @State private var entries: [RemoteEntryDTO] = []
    @State private var loading = true
    @State private var error: String?

    private var directories: [RemoteEntryDTO] {
        entries.filter(\.isDirectory)
    }

    var body: some View {
        List {
            Section {
                Button {
                    onPick(path)
                } label: {
                    Label(
                        path.isEmpty ? "Choose the root" : "Choisir « \(path) »",
                        systemImage: "checkmark.circle.fill"
                    )
                }
            }

            Section("Subfolders") {
                if loading {
                    HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
                } else if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if directories.isEmpty {
                    Text("No subfolders here.").foregroundStyle(.secondary)
                } else {
                    ForEach(directories) { dir in
                        NavigationLink(value: dir.pathInRemote) {
                            Label(dir.name, systemImage: "folder")
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await RemoteService.shared.list(remote: remote, path: path)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
