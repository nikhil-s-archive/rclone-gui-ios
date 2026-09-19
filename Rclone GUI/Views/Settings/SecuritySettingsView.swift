//
//  SecuritySettingsView.swift
//  Rclone GUI — Views/Settings
//
//  Biometric gate + auto-wipe inactivity. Phase E v1 wires the toggles
//  to @AppStorage ; the actual enforcement (re-prompt after timeout)
//  is integrated later in Phase E2.
//

import SwiftUI
import SwiftData

struct SecuritySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("security.requireBiometricsAtLaunch") private var requireBiometrics = true
    @AppStorage("security.inactivityWipeMinutes") private var inactivityWipeMinutes: Int = 30
    @AppStorage("security.wipeCacheOnLock") private var wipeCacheOnLock = true
    @AppStorage(VaultManager.unlockMinutesKey) private var vaultUnlockMinutes: Int = 15
    @State private var biometricsAvailable: Bool = true
    @State private var wipeError: String?
    @State private var wipeSuccess: String?
    @State private var showWipeConfirm = false

    var body: some View {
        Form {
            Section {
                AppHeroCard(
                    title: "Local security",
                    subtitle: "Protects the rclone configuration, the cache and app access.",
                    systemImage: "lock.shield",
                    tint: .green
                ) {
                    HStack(spacing: 10) {
                        AppMetricPill(value: requireBiometrics ? "Active" : "Off", label: "biometrics", systemImage: "faceid", tint: .green)
                        AppMetricPill(value: inactivityLabel, label: "lock", systemImage: "timer", tint: .blue)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Face ID / Touch ID on launch", isOn: $requireBiometrics)
                    .disabled(!biometricsAvailable)
            } footer: {
                if biometricsAvailable {
                    Text("Requires biometric authentication each time the app opens.")
                } else {
                    Text("Biometrics are not set up on this device.")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Picker("Inactivity before lock", selection: $inactivityWipeMinutes) {
                    Text("Never").tag(0)
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 h").tag(60)
                    Text("4 h").tag(240)
                    Text("24 h").tag(1440)
                }
                Toggle("Wipe cache on lock", isOn: $wipeCacheOnLock)
                    .disabled(!requireBiometrics || inactivityWipeMinutes == 0)
            } footer: {
                Text("After this period of inactivity, the app asks for Face ID / Touch ID again. With “Wipe cache on lock”, the local media cache (files decrypted for playback) is purged at that point — no cleartext survives the inactivity.")
            }

            Section {
                Picker("Vault unlock duration", selection: $vaultUnlockMinutes) {
                    Text("On every access").tag(0)
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 h").tag(60)
                }
            } header: {
                Text("Vault")
            } footer: {
                Text("Add a remote to the vault from the Files tab (long-press). It then disappears from the iOS Files app and only opens after Face ID / Touch ID. This duration sets how long it stays unlocked after authentication.")
            }

            Section {
                Button(role: .destructive) {
                    showWipeConfirm = true
                } label: {
                    Label("Erase rclone configuration", systemImage: "trash.slash")
                }
            } header: {
                Text("Configuration")
            } footer: {
                Text("Deletes the locally encrypted rclone.conf and the Keychain master key. You can re-import afterwards.")
            }

            if let wipeError {
                Section {
                    Text(wipeError).foregroundStyle(.red)
                }
            } else if let wipeSuccess {
                Section {
                    Text(wipeSuccess).foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Security")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
        .task {
            biometricsAvailable = await BiometricGate.shared.isAvailable()
        }
        .confirmationDialog(
            "Erase configuration?",
            isPresented: $showWipeConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase", role: .destructive) {
                Task { await wipeConfig() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is irreversible. You can re-import your rclone.conf afterwards.")
        }
    }

    private func wipeConfig() async {
        do {
            try await ConfigStore.shared.wipe()
            // Oublie les remotes encore chargés en mémoire par librclone
            // (sinon ils restent navigables après effacement).
            await RcloneCore.shared.resetToEmptyConfig()
            await FileProviderManager.shared.writeRemotesManifest([])
            FileProviderManager.shared.purgeAllFolderManifests()
            // Purge les favoris/récents locaux et l'état du coffre-fort.
            try? SavedLocationStore.removeAll(in: modelContext)
            VaultManager.shared.clearAll()
            await MainActor.run {
                NotificationCenter.default.post(name: .rcloneConfigurationDidChange, object: nil)
            }
            wipeSuccess = "Configuration effacée."
            wipeError = nil
        } catch {
            wipeError = error.localizedDescription
            wipeSuccess = nil
        }
    }

    private var inactivityLabel: String {
        switch inactivityWipeMinutes {
        case 0: return "Never"
        case 60: return "1 h"
        case 240: return "4 h"
        case 1440: return "24 h"
        default: return "\(inactivityWipeMinutes) min"
        }
    }
}
