//
//  BackupSettingsView.swift
//  Rclone GUI — Views/Settings
//
//  Toggle pour exclure les données de l'app des sauvegardes iCloud / Finder.
//  Voir BackupExclusionManager pour la liste exacte des cibles.
//

import SwiftUI

struct BackupSettingsView: View {
    @AppStorage(BackupExclusionManager.defaultsKey) private var excludeFromBackup = false
    @State private var transientMessage: String?

    var body: some View {
        Form {
            Section {
                headerCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { excludeFromBackup },
                    set: { newValue in
                        excludeFromBackup = newValue
                        let ok = BackupExclusionManager.apply(excluded: newValue)
                        if !ok {
                            transientMessage = "Some data couldn't be marked. Try again; if it persists, it's harmless for the app."
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Exclude from iCloud backups")
                            .font(.body.weight(.medium))
                        Text(excludeFromBackup
                             ? "The app's data won't be included in the device's iCloud backup."
                             : "The app's data is included in the device's iCloud backup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("iCloud Backup")
            } footer: {
                Text("Quand c'est activé, la configuration rclone (chiffrée), le cache de navigation, les miniatures, le coffre-fort et les fichiers téléchargés sont marqués « exclus de la sauvegarde » (NSURLIsExcludedFromBackupKey). Utile pour la confidentialité ou pour ne pas alourdir votre sauvegarde iCloud.\n\nVos identifiants restent dans le Trousseau (sauvegardé séparément). Après une restauration sur un nouvel appareil, il faudra réimporter votre configuration.")
            }
        }
        .navigationTitle("iCloud Backup")
        #if os(iOS)
        .rgInlineNavTitle()
        #endif
        .alert("Backup", isPresented: Binding(
            get: { transientMessage != nil },
            set: { if !$0 { transientMessage = nil } }
        )) {
            Button("OK", role: .cancel) { transientMessage = nil }
        } message: {
            Text(transientMessage ?? "")
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        HStack(spacing: 14) {
            AppIconTile(systemImage: "icloud.slash", tint: .blue, size: 54, iconSize: .title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(excludeFromBackup ? "Excluded from backup" : "Included in backup")
                    .font(.headline)
                Text("Controls whether the app's data appears in the device's iCloud backup.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary)
        }
    }
}
