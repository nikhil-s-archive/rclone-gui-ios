//
//  CreateVaultView.swift
//  Rclone GUI — Views/Settings
//
//  Wizard de création d'un Ghost Vault : choix du remote + dossier +
//  passphrase, scellé par Face ID / Touch ID / mot de passe iCloud.
//

import SwiftUI

struct CreateVaultView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .remote
    @State private var remotes: [RemoteSummaryDTO] = []
    @State private var loadingRemotes = true
    @State private var selectedRemote: RemoteSummaryDTO?
    @State private var selectedFolder: String = GhostVault.remoteFolder
    @State private var passphrase: String = ""
    @State private var passphraseConfirm: String = ""
    @State private var biometricsAvailable = true
    @State private var submitting = false
    @State private var submitError: String?
    @State private var success: GhostVaultCreateResult?
    @State private var showFolderPicker = false

    enum Step: Hashable {
        case remote
        case passphrase
        case seal
        case done
    }

    var body: some View {
        Form {
            switch step {
            case .remote:
                remoteSection
            case .passphrase:
                passphraseSection
            case .seal:
                sealSection
            case .done:
                doneSection
            }

            if let error = submitError {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Create a vault")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(submitting)
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            if let remote = selectedRemote {
                NavigationStack {
                    GhostVaultFolderPicker(remote: remote.name, initial: selectedFolder) { folder in
                        selectedFolder = folder
                        showFolderPicker = false
                    }
                }
            }
        }
        .task {
            await loadRemotes()
            biometricsAvailable = await BiometricGate.shared.isAvailable()
        }
    }

    // MARK: Sections

    private var remoteSection: some View {
        Group {
            Section {
                if loadingRemotes {
                    HStack {
                        ProgressView()
                        Text("Loading remotes…").foregroundStyle(.secondary)
                    }
                } else if remotes.isEmpty {
                    Text("No remotes configured. Add a remote first in Settings → Configuration.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remotes) { remote in
                        Button {
                            selectedRemote = remote
                        } label: {
                            HStack {
                                Image(systemName: remote.isCrypt ? "lock.fill" : "externaldrive.fill")
                                    .foregroundStyle(remote.isCrypt ? .indigo : .blue)
                                VStack(alignment: .leading) {
                                    Text(remote.name).foregroundStyle(.primary)
                                    Text(remote.type + (remote.isCrypt ? " · déjà chiffré (on chiffre quand même)" : ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedRemote?.id == remote.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.indigo)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Destination remote")
            } footer: {
                if let remote = selectedRemote {
                    Text("Vault écrit dans \(remote.name):\(selectedFolder.isEmpty ? "/" : selectedFolder)/ghost-vault-AAAA-MM-JJ.rclonebackup")
                } else {
                    Text("ALWAYS encrypted client-side, even if the remote is already an rclone `crypt`.")
                }
            }

            if selectedRemote != nil {
                Section {
                    Button {
                        showFolderPicker = true
                    } label: {
                        HStack {
                            Label("Folder in the remote", systemImage: "folder.fill")
                            Spacer()
                            Text(selectedFolder.isEmpty ? "/" : selectedFolder)
                                .foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Par défaut : \(GhostVault.remoteFolder)/. Tu peux créer un sous-dossier si tu ranges tes backups.")
                }

                Section {
                    Button {
                        step = .passphrase
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    private var passphraseSection: some View {
        Group {
            Section {
                SecureField("Passphrase (min. \(GhostVault.minPassphraseLength) caractères)", text: $passphrase)
                    .textContentType(.newPassword)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("Confirm the passphrase", text: $passphraseConfirm)
                    .textContentType(.newPassword)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            } header: {
                Text("Passphrase")
            } footer: {
                Text("The passphrase encrypts the vault. It never leaves the device and cannot be recovered — choose a long one (phrase + digits) and store it safely in a password manager.")
            }

            Section {
                Toggle("Show criteria", isOn: .constant(false))
                    .disabled(true)
                ForEach(passphraseChecks, id: \.label) { check in
                    HStack(spacing: 8) {
                        Image(systemName: check.ok ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(check.ok ? .green : .secondary)
                        Text(check.label)
                            .font(.caption)
                            .foregroundStyle(check.ok ? .primary : .secondary)
                    }
                }
            } header: {
                Text("Criteria")
            }

            Section {
                Button {
                    Task { await seal() }
                } label: {
                    if submitting {
                        HStack { ProgressView(); Text("Sealing…") }
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Seal and upload")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!passphraseIsValid || submitting)

                Button("Back") { step = .remote }
                    .disabled(submitting)
            }
        }
    }

    private var sealSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("Sealing and uploading…")
            }
        } footer: {
            Text("Face ID / Touch ID is required to confirm this action.")
        }
    }

    private var doneSection: some View {
        Section {
            if let result = success {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Vault created", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text("Location:")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(result.descriptor.remote):\(result.descriptor.remotePath)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Text("Taille : \(ByteCountFormatter.string(fromByteCount: Int64(result.descriptor.sizeBytes), countStyle: .file))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Button("Completed") { dismiss() }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Helpers

    private var passphraseChecks: [(label: String, ok: Bool)] {
        [
            ("Au moins \(GhostVault.minPassphraseLength) caractères", passphrase.count >= GhostVault.minPassphraseLength),
            ("Confirmation identique", passphrase == passphraseConfirm && !passphrase.isEmpty)
        ]
    }

    private var passphraseIsValid: Bool {
        passphrase.count >= GhostVault.minPassphraseLength && passphrase == passphraseConfirm
    }

    private func loadRemotes() async {
        loadingRemotes = true
        defer { loadingRemotes = false }
        do {
            remotes = try await RemoteService.shared.listRemoteSummaries()
        } catch {
            remotes = []
        }
    }

    private func seal() async {
        guard let remote = selectedRemote else { return }
        submitError = nil
        step = .seal
        let biometricResult = await BiometricGate.shared.authenticate(reason: .ghostVaultSeal)
        guard biometricResult == .authenticated else {
            step = .passphrase
            if case .userCancelled = biometricResult {
                // L'utilisateur a annulé — on reste sur l'écran sans erreur
                return
            }
            if case .unavailable(let msg) = biometricResult {
                submitError = msg
            } else {
                submitError = "Authentication cancelled."
            }
            return
        }
        submitting = true
        defer {
            submitting = false
            if step == .seal && submitError == nil {
                step = .passphrase
            }
        }
        do {
            let result = try await GhostVaultService.shared.create(
                request: GhostVaultCreateRequest(
                    remote: remote.name,
                    folder: selectedFolder,
                    passphrase: passphrase
                )
            )
            success = result
            step = .done
        } catch {
            submitError = error.localizedDescription
            step = .passphrase
        }
    }
}

/// Petit navigateur de dossier adapté à Ghost Vault : on choisit un dossier
/// dans le remote, on n'autorise que les dossiers (pas de fichier), et le
/// bouton "Choose" est toujours disponible pour valider le dossier courant.
private struct GhostVaultFolderPicker: View {
    let remote: String
    let initial: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pathStack: [String] = []

    var body: some View {
        NavigationStack(path: $pathStack) {
            GhostVaultFolderLevel(remote: remote, path: "", onPick: onPick)
                .navigationTitle("\(remote):")
                .navigationDestination(for: String.self) { p in
                    GhostVaultFolderLevel(remote: remote, path: p, onPick: onPick)
                        .navigationTitle((p as NSString).lastPathComponent)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

private struct GhostVaultFolderLevel: View {
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
                        .font(.caption).foregroundStyle(.red)
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