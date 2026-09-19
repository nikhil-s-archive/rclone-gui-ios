//
//  HomeView.swift
//  Rclone GUI — Views/Home
//
//  Premium command center for the app: health, shortcuts, pinned folders,
//  recents, and current transfer activity.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavedLocation.lastOpenedAt, order: .reverse)
    private var savedLocations: [SavedLocation]
    @Query(sort: \Transfer.startedAt, order: .reverse)
    private var transfers: [Transfer]
    @Query(sort: \TrashEntry.trashedAt, order: .reverse)
    private var trashEntries: [TrashEntry]
    @Query(sort: \PhotoSyncAsset.discoveredAt, order: .reverse)
    private var photoAssets: [PhotoSyncAsset]

    @State private var remotes: [RemoteSummaryDTO] = []
    @State private var hasConfig = false
    @State private var isMockEngine = false
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var cacheBytes: Int64 = 0
    @State private var showImport = false
    @State private var showAddRemote = false
    @State private var vault = VaultManager.shared

    // D4 : snapshot live de PhotoSync pour la mini-card. Polling 4s
    // tant qu'on est sur Home (le hero PhotoSync de l'écran Transferts
    // reste la source d'autorité, ici on offre juste un coup d'œil).
    @State private var photoSyncSummary: PhotoSyncRunSummary?
    @State private var photoSyncIsRunning = false

    private var pinnedLocations: [SavedLocation] {
        savedLocations
            // Masque les remotes au coffre-fort verrouillés (cf. FilesRootView) :
            // ils ne doivent pas être navigables depuis les Favoris tant qu'ils
            // n'ont pas été déverrouillés par Face ID.
            .filter { $0.kind == .pinned && vault.isAccessible($0.remote) }
            .sorted {
                if $0.sortIndex == $1.sortIndex {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortIndex < $1.sortIndex
            }
    }

    private var recentLocations: [SavedLocation] {
        savedLocations
            // Idem : un remote au coffre-fort verrouillé reste hors des Récents
            // tant qu'il n'est pas déverrouillé.
            .filter { $0.kind == .recent && vault.isAccessible($0.remote) }
            .prefix(6)
            .map { $0 }
    }

    private var activeTransfers: [Transfer] {
        transfers.filter {
            $0.status == .running || $0.status == .pending || $0.status == .paused || $0.status == .enqueued
        }
    }

    private var failedTransfers: [Transfer] {
        transfers.filter { $0.status == .failed }
    }

    private var completedTransfers: [Transfer] {
        transfers.filter { $0.status == .completed }
    }

    private var photoSyncPendingCount: Int {
        photoAssets.filter { $0.status == .pending || $0.status == .exporting || $0.status == .enqueued }.count
    }

    private var heroTitle: String {
        if !hasConfig { return String(localized: "Set up Rclone GUI") }
        if isMockEngine { return String(localized: "Demo mode active") }
        if !activeTransfers.isEmpty { return String(localized: "Transfers in progress") }
        return String(localized: "Everything is ready")
    }

    private var heroSubtitle: String {
        if !hasConfig {
            return String(localized: "Import your rclone.conf to browse your remotes, sync your files and expose your folders in Files.")
        }
        if isMockEngine {
            return String(localized: "The configuration is loaded, but the real RcloneKit engine isn’t available in this session.")
        }
        if !activeTransfers.isEmpty {
            return String(localized: "\(activeTransfers.count) opération\(activeTransfers.count > 1 ? "s" : "") active\(activeTransfers.count > 1 ? "s" : "") sur tes remotes.")
        }
        return String(localized: "\(remotes.count) remote\(remotes.count > 1 ? "s" : "") disponible\(remotes.count > 1 ? "s" : "").")
    }

    var body: some View {
        List {
            Section {
                statusHero
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                quickActions
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !remotes.isEmpty {
                Section {
                    ForEach(remotes) { remote in
                        NavigationLink(value: NavigationDestination.folder(remote: remote.name, path: "")) {
                            AppLocationRow(
                                title: remote.name,
                                subtitle: humanType(remote.type),
                                systemImage: remote.type == "crypt" ? "lock.shield" : "externaldrive",
                                tint: remote.type == "crypt" ? .green : .blue
                            )
                        }
                    }
                } header: {
                    Label(LocalizedStringKey("Connected Drives"), systemImage: "externaldrive.connected.to.line.below")
                } footer: {
                    if remotes.count == 1 {
                        Text(LocalizedStringKey("1 connected drive."))
                    } else {
                        Text(LocalizedStringKey("\(remotes.count) lecteurs connectés."))
                    }
                }
            }

            if !pinnedLocations.isEmpty {
                Section {
                    ForEach(pinnedLocations.prefix(6)) { location in
                        NavigationLink(value: location.destination) {
                            AppLocationRow(
                                title: location.displayName,
                                subtitle: location.subtitle,
                                systemImage: location.path.isEmpty ? "externaldrive.fill" : "folder.fill",
                                tint: location.kind == .pinned ? .orange : .blue,
                                trailing: location.kind == .recent ? relativeDate(location.lastOpenedAt) : nil
                            )
                        }
                    }
                } header: {
                    Label(LocalizedStringKey("Favorites"), systemImage: "pin.fill")
                }
            }

            Section {
                if recentLocations.isEmpty {
                    Text(LocalizedStringKey("No recent folders"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentLocations) { location in
                        NavigationLink(value: location.destination) {
                            AppLocationRow(
                                title: location.displayName,
                                subtitle: location.subtitle,
                                systemImage: location.path.isEmpty ? "externaldrive.fill" : "folder.fill",
                                tint: location.kind == .pinned ? .orange : .blue,
                                trailing: relativeDate(location.lastOpenedAt)
                            )
                        }
                    }
                }
            } header: {
                Label(LocalizedStringKey("Recent"), systemImage: "clock")
            }
            
            if !activeTransfers.isEmpty {
                Section {
                    ForEach(activeTransfers.prefix(3)) { transfer in
                        TransferRowView(transfer: transfer)
                    }
                } header: {
                    Label(LocalizedStringKey("Activity"), systemImage: "waveform.path.ecg")
                }
            }
        }
        .rgInsetGroupedList()
        .navigationTitle(LocalizedStringKey("Home"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(LocalizedStringKey("Refresh home"))
            }
        }
        .refreshable {
            await load()
        }
        .task {
            await load()
            await refreshPhotoSyncSnapshot()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await refreshPhotoSyncSnapshot()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rcloneConfigurationDidChange)) { _ in
            Task { await load() }
        }
        .sheet(isPresented: $showImport) {
            ImportConfigView(onImported: {
                showImport = false
                Task { await load() }
            })
        }
        .sheet(isPresented: $showAddRemote) {
            AddRemoteWizard(onSaved: {
                showAddRemote = false
                Task { await load() }
            })
        }
    }

    private var statusHero: some View {
        AppHeroCard(
            // heroTitle/heroSubtitle sont déjà localisés (String(localized:)) ;
            // on les affiche verbatim via LocalizedStringKey(_:).
            title: LocalizedStringKey(heroTitle),
            subtitle: LocalizedStringKey(heroSubtitle),
            systemImage: hasConfig ? "externaldrive.connected.to.line.below" : "doc.badge.gearshape",
            tint: hasConfig ? .blue : .orange
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                AppMetricTile(value: "\(remotes.count)", label: "remotes", systemImage: "externaldrive", tint: .blue)
                AppMetricTile(value: "\(activeTransfers.count)", label: "active", systemImage: "bolt.fill", tint: .indigo)
                AppMetricTile(value: "\(trashEntries.count)", label: "Trash", systemImage: "trash", tint: .red)
                AppMetricTile(value: formattedBytes(cacheBytes), label: "media cache", systemImage: "tray.full", tint: .orange)
            }

            if let loadError {
                AppInlineMessage(
                    title: "Partial read",
                    message: LocalizedStringKey(loadError),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
        }
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
            Button {
                showAddRemote = true
            } label: {
                AppActionTile(
                    title: "New",
                    subtitle: "Add a remote",
                    systemImage: "externaldrive.badge.plus",
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            Button {
                showImport = true
            } label: {
                AppActionTile(
                    title: "Import",
                    subtitle: "Load rclone.conf",
                    systemImage: "square.and.arrow.down",
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                PhotoSyncSettingsView()
            } label: {
                photoSyncTile
            }
            .buttonStyle(.plain)

            NavigationLink {
                PerformanceSettingsView()
            } label: {
                AppActionTile(
                    title: "Performance",
                    subtitle: "Pause and bandwidth",
                    systemImage: "speedometer",
                    tint: .indigo
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// D4 : Tile PhotoSync sur Home. Affiche un ProgressArc + X/Y
    /// quand un sync est en cours, sinon fallback au sous-titre
    /// textuel "Backup configured" / "N en attente".
    @ViewBuilder
    private var photoSyncTile: some View {
        if let summary = photoSyncSummary,
           photoSyncIsRunning,
           summary.effectiveTotal > 0 {
            HStack(spacing: 12) {
                ProgressArc(
                    progress: summary.displayProgress,
                    lineWidth: 3,
                    tint: RG.photoSync.accent
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Text("\(PhotoSyncFormat.percent(summary.displayProgress))%")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(RG.photoSync.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("PhotoSync")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(summary.completedCount) / \(summary.effectiveTotal) photos")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlassSurface(cornerRadius: AppSurface.compactCornerRadius, interactive: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("PhotoSync, \(summary.displayLabel)")
        } else {
            AppActionTile(
                title: "Photos",
                subtitle: photoSyncPendingCount == 0 ? "Backup configured" : "\(photoSyncPendingCount) en attente",
                systemImage: "photo.stack",
                tint: RG.photoSync.accent
            )
        }
    }

    /// D4 : récupère un snapshot PhotoSync depuis le service. Polling
    /// court (4s) tant qu'on est sur Home — on a juste besoin d'un
    /// coup d'œil, pas d'un live à 1s.
    private func refreshPhotoSyncSnapshot() async {
        photoSyncIsRunning = PhotoSyncService.shared.isSyncingPublic
        photoSyncSummary = await PhotoSyncService.shared.currentSummary()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        hasConfig = await ConfigStore.shared.hasStoredConf()
        isMockEngine = await RcloneCore.shared.isMockEngine
        cacheBytes = (try? await MediaCacheService.shared.currentSize()) ?? 0

        guard hasConfig else {
            remotes = []
            loadError = nil
            return
        }

        do {
            remotes = try await RemoteService.shared.listRemoteSummaries()
            try? SavedLocationStore.removeUnavailableRemotes(Set(remotes.map(\.name)), in: modelContext)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func humanType(_ type: String) -> String {
        switch type {
        case "s3": return "S3 / R2 / Bunny / Wasabi"
        case "b2": return "Backblaze B2"
        case "sftp": return "SFTP"
        case "ftp": return "FTP"
        case "webdav": return "WebDAV"
        case "drive": return "Google Drive"
        case "dropbox": return "Dropbox"
        case "onedrive": return "OneDrive"
        case "box": return "Box"
        case "crypt": return String(localized: "Crypt encrypted")
        case "alias": return "Alias"
        case "union": return String(localized: "Union of remotes")
        case "combine": return "Combine"
        case "local": return "Local"
        default: return type
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(
        for: [Remote.self, RemoteEntry.self, Transfer.self, TransferBatch.self, PhotoSyncAsset.self, TrashEntry.self, SavedLocation.self],
        inMemory: true
    )
}
