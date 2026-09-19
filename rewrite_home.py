import re

with open("Rclone GUI/Views/Home/HomeView.swift", "r") as f:
    content = f.read()

# We need to replace the `body` and related view properties to use `List`.

new_body = """    var body: some View {
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
                    Label(LocalizedStringKey("Lecteurs connectés"), systemImage: "externaldrive.connected.to.line.below")
                } footer: {
                    if remotes.count == 1 {
                        Text(LocalizedStringKey("1 lecteur connecté."))
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
                    Label(LocalizedStringKey("Favoris"), systemImage: "pin.fill")
                }
            }

            Section {
                if recentLocations.isEmpty {
                    Text(LocalizedStringKey("Aucun dossier récent"))
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
                Label(LocalizedStringKey("Récents"), systemImage: "clock")
            }
            
            if !activeTransfers.isEmpty {
                Section {
                    ForEach(activeTransfers.prefix(3)) { transfer in
                        TransferRowView(transfer: transfer)
                    }
                } header: {
                    Label(LocalizedStringKey("Activité"), systemImage: "waveform.path.ecg")
                }
            }
        }
        .rgInsetGroupedList()
        .navigationTitle(LocalizedStringKey("Accueil"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(LocalizedStringKey("Rafraîchir l’accueil"))
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
    }"""

body_pattern = r"    var body: some View \{.*?(?=    private var statusHero: some View \{)"
content = re.sub(body_pattern, new_body + "\n\n", content, flags=re.DOTALL)

# Let's add humanType method
human_type_func = """    private func humanType(_ type: String) -> String {
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
        case "crypt": return String(localized: "Crypt chiffré")
        case "alias": return "Alias"
        case "union": return String(localized: "Union de remotes")
        case "combine": return "Combine"
        case "local": return "Local"
        default: return type
        }
    }
"""

content = content.replace("    private func formattedBytes", human_type_func + "\n    private func formattedBytes")

# We need to change quickActions to remove AppSectionHeader since it's now in a section header, or just keep it as is without the header.
quick_actions_new = """    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
            Button {
                showAddRemote = true
            } label: {
                AppActionTile(
                    title: "Nouveau",
                    subtitle: "Ajouter un remote",
                    systemImage: "externaldrive.badge.plus",
                    tint: .blue
                )
            }
            .buttonStyle(.plain)

            Button {
                showImport = true
            } label: {
                AppActionTile(
                    title: "Importer",
                    subtitle: "Charger rclone.conf",
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
                    subtitle: "Pause et débit",
                    systemImage: "speedometer",
                    tint: .indigo
                )
            }
            .buttonStyle(.plain)
        }
    }"""

quick_actions_pattern = r"    private var quickActions: some View \{.*?(?=    /// D4 : Tile PhotoSync sur Home)"
content = re.sub(quick_actions_pattern, quick_actions_new + "\n\n", content, flags=re.DOTALL)

# Delete locationsSection and activitySection
loc_sec_pattern = r"    private func locationsSection\(.*?\).*?    \}"
content = re.sub(loc_sec_pattern, "", content, flags=re.DOTALL)

act_sec_pattern = r"    private var activitySection: some View \{.*?    \}"
content = re.sub(act_sec_pattern, "", content, flags=re.DOTALL)


with open("Rclone GUI/Views/Home/HomeView.swift", "w") as f:
    f.write(content)
