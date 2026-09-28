//
//  BackendOverrides.swift
//  Rclone GUI — Core
//
//  Static lookups that augment the JSON catalog returned by
//  `config/providers`. Kept tight on purpose: every entry that lives
//  here either does not exist in the rclone JSON (categorisation,
//  icons, FR translations, OAuth metadata) or actively contradicts
//  what we want users to see (hidden backends).
//
//  Coverage :
//    Cette table est un SUR-ENSEMBLE statique indexé par nom de backend
//    rclone. Le wizard n'affiche QUE les backends réellement renvoyés par le
//    moteur embarqué via `config/providers` (cf. RemoteCatalogService) — les
//    entrées présentes ici pour des backends absents du rclone compilé sont
//    simplement inutilisées, jamais affichées. Les comptes ci-dessous sont
//    donc une « couverture catalogue », pas « ce qui est livré ».
//    - ~70 backends catégorisés / iconés / décrits en français.
//    - 24 backends avec un guide d'auth manuel (lien + étapes + collage),
//      dont Drime + Filen (nouveaux dans rclone 1.73).
//    - Internxt (1.73) utilise email + mot de passe dans le formulaire
//      dynamique (pas de token à coller) ; les comptes avec 2FA doivent
//      passer par le mode interactif (CLI).
//
//  Auth strategy: NO interactive OAuth in P1.
//    For each backend that needs auth, the wizard:
//    1. Opens the provider's developer console / API key page in Safari.
//    2. Walks the user through 3-5 short numbered steps.
//    3. Asks them to paste the resulting token / API key / JSON blob.
//    The pasted value lands in `parameters[tokenFieldName]` of
//    `config/create`. No browser callback, no Info.plist URL types,
//    no Universal Links infra needed.
//
//  Backends without an explicit override fall back to:
//    - category .specialized
//    - icon "externaldrive"
//    - description from rclone (English, OK for niche backends)
//

import Foundation

/// Guide « où obtenir tes identifiants » affiché EN HAUT du formulaire
/// dynamique (DynamicRemoteFormView) pour les backends qui exigent une clé /
/// token / identifiants mais qui ne passent pas par l'étape OAuth (collage
/// d'un seul secret). Contrairement à `OAuthProviderConfig`, ce guide ne
/// collecte rien lui-même : il pointe l'utilisateur vers la bonne page et
/// nomme les champs à remplir. Convient aussi bien aux backends à un seul
/// secret (pixeldrain, 1Fichier, gofile) qu'à ceux à plusieurs champs
/// (imagekit, internetarchive, netstorage, storj).
struct BackendSetupGuide: Sendable, Hashable {
    /// Page provider à ouvrir pour générer la clé/token. `nil` = pas de page
    /// externe (ex : Sia auto-hébergé, Uloz.to en user/pass).
    let setupURL: URL?
    /// Étapes numérotées, courtes et actionnables (clé FR → String Catalog).
    let steps: [String]
    /// Avertissement optionnel d'une ligne.
    let note: String?
}

enum BackendOverrides {

    // MARK: - Category mapping (67 + 2 hidden)

    nonisolated static let categoryByBackend: [String: BackendCategory] = [
        // Cloud officiels (15)
        "drive": .officialCloud,
        "dropbox": .officialCloud,
        "box": .officialCloud,
        "onedrive": .officialCloud,
        "google photos": .officialCloud,
        "google cloud storage": .officialCloud,
        "azureblob": .officialCloud,
        "azurefiles": .officialCloud,
        "iclouddrive": .officialCloud,
        "protondrive": .officialCloud,
        "mailru": .officialCloud,
        "yandex": .officialCloud,
        "huaweidrive": .officialCloud,
        "jottacloud": .officialCloud,
        "filescom": .officialCloud,

        // S3 compatible (6 + tardigrade hidden)
        "s3": .s3Compatible,
        "b2": .s3Compatible,
        "swift": .s3Compatible,
        "oracleobjectstorage": .s3Compatible,
        "qingstor": .s3Compatible,
        "storj": .s3Compatible,

        // Sync grand public (13)
        "mega": .mainstream,
        "pcloud": .mainstream,
        "sugarsync": .mainstream,
        "hidrive": .mainstream,
        "koofr": .mainstream,
        "seafile": .mainstream,
        "sharefile": .mainstream,
        "quatrix": .mainstream,
        "premiumizeme": .mainstream,
        "putio": .mainstream,
        "zoho": .mainstream,
        "filen": .mainstream,
        "drime": .mainstream,

        // Self-hosted / Standards (6)
        "webdav": .selfHosted,
        "sftp": .selfHosted,
        "ftp": .selfHosted,
        "smb": .selfHosted,
        "http": .selfHosted,
        "hdfs": .selfHosted,

        // Spécialisés (17)
        "cloudinary": .specialized,
        "doi": .specialized,
        "fichier": .specialized,
        "filefabric": .specialized,
        "filelu": .specialized,
        "gofile": .specialized,
        "imagekit": .specialized,
        "internetarchive": .specialized,
        "internxt": .specialized,
        "linkbox": .specialized,
        "netstorage": .specialized,
        "opendrive": .specialized,
        "pikpak": .specialized,
        "pixeldrain": .specialized,
        "shade": .specialized,
        "sia": .specialized,
        "ulozto": .specialized,

        // Wrappers / Composites (9 + memory hidden)
        "alias": .wrapper,
        "crypt": .wrapper,
        "cache": .wrapper,
        "chunker": .wrapper,
        "combine": .wrapper,
        "compress": .wrapper,
        "hasher": .wrapper,
        "union": .wrapper,
        "archive": .wrapper,

        // Local (1)
        "local": .local,
    ]

    // MARK: - Icons (SF Symbols)

    nonisolated static let iconByBackend: [String: String] = [
        // Cloud officiels
        "drive":              "g.circle.fill",
        "dropbox":            "shippingbox.fill",
        "box":                "cube.box.fill",
        "onedrive":           "square.stack.3d.up.fill",
        "google photos":      "photo.on.rectangle.angled",
        "google cloud storage": "cylinder.split.1x2.fill",
        "azureblob":          "cube.transparent",
        "azurefiles":         "folder.fill",
        "iclouddrive":        "icloud.fill",
        "protondrive":        "lock.shield.fill",
        "yandex":             "y.circle.fill",
        "mailru":             "envelope.fill",
        "huaweidrive":        "h.circle.fill",
        "jottacloud":         "j.circle.fill",
        "filescom":           "f.circle.fill",

        // S3 compatible
        "s3":                 "cloud.fill",
        "b2":                 "b.circle.fill",
        "swift":              "swift",
        "oracleobjectstorage": "o.circle.fill",
        "qingstor":           "q.circle.fill",
        "storj":              "shield.lefthalf.filled",

        // Sync grand public
        "mega":               "m.circle.fill",
        "pcloud":             "p.circle.fill",
        "sugarsync":          "arrow.triangle.2.circlepath",
        "hidrive":            "h.square.fill",
        "koofr":              "k.circle.fill",
        "seafile":            "leaf.fill",
        "sharefile":          "square.and.arrow.up.fill",
        "quatrix":            "q.square.fill",
        "premiumizeme":       "star.circle.fill",
        "putio":              "play.circle.fill",
        "zoho":               "z.circle.fill",
        "filen":              "lock.doc.fill",
        "drime":              "d.circle.fill",

        // Self-hosted / Standards
        "sftp":               "terminal.fill",
        "ftp":                "arrow.up.arrow.down.circle",
        "webdav":             "globe",
        "smb":                "network",
        "http":               "link.circle.fill",
        "hdfs":               "server.rack",

        // Spécialisés
        "cloudinary":         "photo.stack.fill",
        "doi":                "graduationcap.fill",
        "fichier":            "doc.fill",
        "filefabric":         "building.2.fill",
        "filelu":             "tray.full.fill",
        "gofile":             "g.square.fill",
        "imagekit":           "photo.tv",
        "internetarchive":    "books.vertical.fill",
        "internxt":           "lock.rectangle.stack.fill",
        "linkbox":            "link.badge.plus",
        "netstorage":         "antenna.radiowaves.left.and.right",
        "opendrive":          "externaldrive.connected.to.line.below",
        "pikpak":             "bolt.circle.fill",
        "pixeldrain":         "drop.fill",
        "shade":              "sunglasses.fill",
        "sia":                "globe.asia.australia.fill",
        "ulozto":             "u.circle.fill",

        // Wrappers / Composites
        "alias":              "link",
        "crypt":              "lock.shield.fill",
        "cache":              "hourglass",
        "chunker":            "rectangle.split.3x1.fill",
        "combine":            "rectangle.stack.fill",
        "compress":           "arrow.down.right.and.arrow.up.left",
        "hasher":             "checkmark.seal.fill",
        "union":              "rectangle.on.rectangle",
        "archive":            "archivebox.fill",

        // Local
        "local":              "internaldrive.fill",
    ]

    // MARK: - French descriptions (67 backends)

    nonisolated static let frDescriptionByBackend: [String: String] = [
        // Cloud officiels
        "drive":              "Google Drive (personal or Workspace account)",
        "dropbox":            "Dropbox",
        "box":                "Box",
        "onedrive":           "Microsoft OneDrive (personal or Business)",
        "google photos":      "Google Photos",
        "google cloud storage": "Google Cloud Storage (not Drive)",
        "azureblob":          "Microsoft Azure Blob Storage",
        "azurefiles":         "Microsoft Azure Files",
        "iclouddrive":        "iCloud Drive and Photos",
        "protondrive":        "Proton Drive",
        "yandex":             "Yandex Disk",
        "mailru":             "Mail.ru Cloud",
        "huaweidrive":        "Huawei Drive",
        "jottacloud":         "Jottacloud",
        "filescom":           "Files.com",

        // S3 compatible
        "s3":                 "Amazon S3 and compatibles (Cloudflare R2, Wasabi, Backblaze, Minio…)",
        "b2":                 "Backblaze B2",
        "swift":              "OpenStack Swift",
        "oracleobjectstorage": "Oracle Cloud Object Storage",
        "qingstor":           "QingStor (QingCloud)",
        "storj":              "Storj — decentralized storage",

        // Sync grand public
        "mega":               "MEGA",
        "pcloud":             "pCloud",
        "sugarsync":          "SugarSync",
        "hidrive":            "HiDrive (Strato)",
        "koofr":              "Koofr (and compatibles: Digi Storage…)",
        "seafile":            "Seafile",
        "sharefile":          "Citrix ShareFile",
        "quatrix":            "Quatrix (Maytech)",
        "premiumizeme":       "Premiumize.me",
        "putio":              "Put.io",
        "zoho":               "Zoho WorkDrive",
        "filen":              "Filen — end-to-end encrypted",
        "drime":              "Drime",

        // Self-hosted / Standards
        "sftp":               "SSH/SFTP",
        "ftp":                "FTP",
        "webdav":             "WebDAV (Nextcloud, ownCloud, Synology…)",
        "smb":                "SMB / CIFS (Windows / Samba)",
        "http":               "HTTP read-only",
        "hdfs":               "Hadoop HDFS",

        // Spécialisés
        "cloudinary":         "Cloudinary — media with transformations",
        "doi":                "DOI datasets (Dataverse, Figshare…)",
        "fichier":            "1Fichier",
        "filefabric":         "Enterprise File Fabric",
        "filelu":             "FileLu",
        "gofile":             "Gofile",
        "imagekit":           "ImageKit.io",
        "internetarchive":    "Internet Archive",
        "internxt":           "Internxt — end-to-end encrypted",
        "linkbox":            "Linkbox",
        "netstorage":         "Akamai NetStorage",
        "opendrive":          "OpenDrive",
        "pikpak":             "PikPak",
        "pixeldrain":         "Pixeldrain",
        "shade":              "Shade FS",
        "sia":                "Sia — decentralized storage",
        "ulozto":             "Uloz.to",

        // Wrappers / Composites
        "alias":              "Alias of an existing remote (shortcut)",
        "crypt":              "Transparent encryption on top of another remote",
        "cache":              "Local cache of a remote",
        "chunker":            "Splits large files into chunks",
        "combine":            "Combines several remotes into one",
        "compress":           "Compresses another remote on the fly",
        "hasher":             "Improves another remote’s checksums",
        "union":              "Merges the contents of several remotes",
        "archive":            "Reads archives (zip, tar…) from another remote",

        // Local
        "local":              "Local disk (app sandbox)",
    ]

    // MARK: - Auth guides for the 22 backends that need a token / API key
    //
    // No OAuth is performed in-app. Each entry below tells the wizard:
    //   - which provider page to open (setupURL)
    //   - what the user has to do there (setupSteps)
    //   - which rclone field to fill (tokenFieldName)
    //   - how to label the input (tokenLabel) and hint format (tokenHint)
    //
    // The OAuth-specific fields (authURL/tokenURL/clientID/etc.) are kept
    // populated so a future P2 switch back to interactive OAuth is just a
    // strategy flip per backend.

    nonisolated static let oauthConfigs: [String: OAuthProviderConfig] = [
        // ───────── Google family ─────────
        "drive": OAuthProviderConfig(
            backendName: "drive",
            authURL: URL(string: "https://accounts.google.com/o/oauth2/auth")!,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            defaultClientID: "202264815644.apps.googleusercontent.com",
            defaultClientSecret: "X4Z3ca8xfWDb1Voo-F9a7ZxMv3HCYUCY",
            defaultScopes: ["https://www.googleapis.com/auth/drive"],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://developers.google.com/oauthplayground/?scopes=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fdrive"),
            setupSteps: [
                "Open Google OAuth Playground with the button below.",
                "Step 1: select “Drive API v3 → https://www.googleapis.com/auth/drive” then click “Authorize APIs”.",
                "Sign in to your Google account and accept the permissions.",
                "Step 2: click “Exchange authorization code for tokens”.",
                "Copy the entire JSON block containing access_token + refresh_token, then paste it below."
            ],
            tokenLabel: "JSON token (Google OAuth Playground)",
            tokenFieldName: "token",
            tokenHint: "Format JSON : {\"access_token\":\"...\",\"refresh_token\":\"...\",\"expiry\":\"...\"}"
        ),
        "google photos": OAuthProviderConfig(
            backendName: "google photos",
            authURL: URL(string: "https://accounts.google.com/o/oauth2/auth")!,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            defaultClientID: "202264815644.apps.googleusercontent.com",
            defaultClientSecret: "X4Z3ca8xfWDb1Voo-F9a7ZxMv3HCYUCY",
            defaultScopes: [
                "https://www.googleapis.com/auth/photoslibrary.readonly",
                "https://www.googleapis.com/auth/photoslibrary.appendonly",
            ],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://developers.google.com/oauthplayground/"),
            setupSteps: [
                "Open Google OAuth Playground.",
                "Select the Photos Library API scopes: photoslibrary.readonly + photoslibrary.appendonly.",
                "Click “Authorize APIs” and accept with your Google account.",
                "Click “Exchange authorization code for tokens”.",
                "Copy the JSON block and paste it below."
            ],
            tokenLabel: "JSON token (Google OAuth Playground)",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "google cloud storage": OAuthProviderConfig(
            backendName: "google cloud storage",
            authURL: URL(string: "https://accounts.google.com/o/oauth2/auth")!,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            defaultClientID: "202264815644.apps.googleusercontent.com",
            defaultClientSecret: "X4Z3ca8xfWDb1Voo-F9a7ZxMv3HCYUCY",
            defaultScopes: ["https://www.googleapis.com/auth/devstorage.full_control"],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://console.cloud.google.com/iam-admin/serviceaccounts"),
            setupSteps: [
                "Open Google Cloud Console → IAM → Service Accounts.",
                "Create a service account with the “Storage Admin” role.",
                "“Keys” tab → “Add Key” → “JSON” → download the file.",
                "Open the JSON file, copy all of its contents, and paste it below."
            ],
            tokenLabel: "Service Account JSON",
            tokenFieldName: "service_account_credentials",
            tokenHint: "The full contents of the JSON file downloaded from GCP."
        ),

        // ───────── Microsoft family ─────────
        "onedrive": OAuthProviderConfig(
            backendName: "onedrive",
            authURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
            defaultClientID: "b15665d9-eda6-4092-8539-0eec376afd59",
            defaultClientSecret: nil,
            defaultScopes: ["Files.Read", "Files.ReadWrite", "Files.Read.All", "Files.ReadWrite.All", "offline_access"],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://rclone.org/onedrive/#getting-your-own-client-id-and-key"),
            setupSteps: [
                "Sur un poste avec rclone CLI : `rclone authorize \"onedrive\"`.",
                "A web page opens — sign in to your Microsoft account.",
                "Accept the requested permissions.",
                "The terminal shows a JSON block. Copy it entirely.",
                "Paste the JSON below."
            ],
            tokenLabel: "Token JSON rclone (depuis `rclone authorize \"onedrive\"`)",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "azureblob": OAuthProviderConfig(
            backendName: "azureblob",
            authURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: ["https://storage.azure.com/.default"],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://portal.azure.com/#@/blade/Microsoft_Azure_Storage/StorageAccountsBlade"),
            setupSteps: [
                "Open Azure Portal → Storage accounts.",
                "Select your account → “Access keys” tab → “Show keys”.",
                "Note the account name and “key1”.",
                "In the wizard form, fill in “account” and “key” (no JSON token needed here)."
            ],
            tokenLabel: "Account Key (from Azure Portal)",
            tokenFieldName: "key",
            tokenHint: "Tip: for Azure, you can also fill in “account” + “key” directly in the normal form."
        ),
        "azurefiles": OAuthProviderConfig(
            backendName: "azurefiles",
            authURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: ["https://storage.azure.com/.default"],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://portal.azure.com/"),
            setupSteps: [
                "Azure Portal → Storage accounts → your account.",
                "“Access keys” tab → copy account name + key1.",
                "The wizard also supports SAS and Service Principal — see the rclone docs."
            ],
            tokenLabel: "Account Key",
            tokenFieldName: "key",
            tokenHint: nil
        ),

        // ───────── Apple family ─────────
        "iclouddrive": OAuthProviderConfig(
            backendName: "iclouddrive",
            authURL: URL(string: "https://appleid.apple.com/")!,
            tokenURL: URL(string: "https://appleid.apple.com/")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            // Pas de setupURL : la page appleid.apple.com servait à générer un
            // mot de passe d'app, inutile (et trompeur) depuis le flow 2FA —
            // l'utilisateur saisit son mot de passe habituel, le code 2FA est
            // demandé dans l'app.
            setupURL: nil,
            setupSteps: [
                "Active la 2FA sur ton compte Apple si pas déjà fait (obligatoire).",
                "Utilise ton mot de passe Apple ID HABITUEL (celui de ton compte) — Apple refuse les mots de passe « spécifiques à une app » et les mots de passe uniques.",
                "Sur ton iPhone : Réglages → [ton nom] → iCloud → active « Accéder aux données iCloud sur le web ».",
                "Colle ton mot de passe ci-dessous.",
                "Un code 2FA te sera demandé à l'étape « Récapitulatif » (test ou création).",
                "L'obtention du jeton de session Apple après le code 2FA peut prendre plusieurs minutes — laisse l'écran ouvert.",
                "À l'étape précédente du wizard, remplis aussi « Email Apple ID » et choisis le service (iCloud Drive ou iCloud Photos)."
            ],
            tokenLabel: "Apple ID Password (standard)",
            tokenFieldName: "password",
            tokenHint: "Le mot de passe normal de ton compte Apple — PAS un mot de passe d'app ni un mot de passe unique (rejetés par Apple). L'email Apple ID se remplit dans le formulaire principal."
        ),

        // ───────── Dropbox / Box / pCloud ─────────
        "dropbox": OAuthProviderConfig(
            backendName: "dropbox",
            authURL: URL(string: "https://www.dropbox.com/oauth2/authorize")!,
            tokenURL: URL(string: "https://api.dropboxapi.com/oauth2/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://www.dropbox.com/developers/apps"),
            setupSteps: [
                "Open the Dropbox App Console.",
                "“Create app” → choose “Scoped access” + “Full Dropbox”.",
                "Give it a unique name (e.g. “rclonegui-vitalys”).",
                "“Permissions” tab → check all the files.* and sharing.* scopes. Save.",
                "“Settings” tab → “OAuth 2” section → “Generated access token” → “Generate”.",
                "Copy the token (starts with “sl.”) and paste it below.",
                "💡 The wizard automatically wraps the raw token into JSON for rclone."
            ],
            tokenLabel: "Dropbox generated access token",
            tokenFieldName: "token",
            tokenHint: "Just paste the raw “sl.X…” token — the wizard formats it into JSON automatically."
        ),
        "box": OAuthProviderConfig(
            backendName: "box",
            authURL: URL(string: "https://account.box.com/api/oauth2/authorize")!,
            tokenURL: URL(string: "https://api.box.com/oauth2/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: true,
            setupURL: URL(string: "https://app.box.com/developers/console"),
            setupSteps: [
                "Open the Box Developer Console.",
                "“Create New App” → “Custom App” → “User Authentication (OAuth 2.0)”.",
                "“Configuration” tab → “Developer Token” section → “Generate Developer Token”.",
                "Copy the token (valid for 60 minutes only — regenerate if expired).",
                "Paste it below."
            ],
            tokenLabel: "Box Developer Token",
            // rclone Box accepte un raw access_token via le champ dédié
            // `access_token` (pas le `token` JSON OAuth). Plus simple pour
            // le user que de générer un JSON token complet.
            tokenFieldName: "access_token",
            tokenHint: "⚠️ Token valid for 60 minutes only. For lasting use, create a real app + JWT (see the rclone box docs)."
        ),
        "pcloud": OAuthProviderConfig(
            backendName: "pcloud",
            authURL: URL(string: "https://my.pcloud.com/oauth2/authorize")!,
            tokenURL: URL(string: "https://api.pcloud.com/oauth2_token")!,
            defaultClientID: "DnONSzyJXpm",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://my.pcloud.com/oauth2/authorize?client_id=DnONSzyJXpm&response_type=token&redirect_uri=https://my.pcloud.com"),
            setupSteps: [
                "Open the pCloud authorization URL (link below).",
                "Sign in to your pCloud account.",
                "Accept rclone access.",
                "The return URL contains `access_token=...` in the query string.",
                "Copy that value (without the access_token= prefix) and paste it below."
            ],
            tokenLabel: "pCloud access token",
            tokenFieldName: "access_token",
            tokenHint: "Long alphanumeric string extracted from the return URL."
        ),

        // ───────── Yandex / Mail.ru ─────────
        "yandex": OAuthProviderConfig(
            backendName: "yandex",
            authURL: URL(string: "https://oauth.yandex.com/authorize")!,
            tokenURL: URL(string: "https://oauth.yandex.com/token")!,
            defaultClientID: "ddffbc9bb6394f49a89e74a96a43b6f2",
            defaultClientSecret: nil,
            defaultScopes: ["cloud_api:disk.app_folder", "cloud_api:disk.read", "cloud_api:disk.write", "cloud_api:disk.info"],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://oauth.yandex.com/authorize?response_type=token&client_id=ddffbc9bb6394f49a89e74a96a43b6f2"),
            setupSteps: [
                "Open the Yandex OAuth URL (link below).",
                "Sign in to your Yandex account.",
                "Accept rclone access.",
                "Copy the access_token shown or present in the redirect URL.",
                "Paste it below."
            ],
            tokenLabel: "Yandex access token",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        // mailru NOT in oauthConfigs : les champs `user` (email) et `pass`
        // sont déjà Required dans le schéma rclone et apparaissent dans le
        // formulaire normal. L'utilisateur les remplit là, pas besoin
        // d'écran d'authentification dédié.
        // → Mail.ru : 2FA + app password sur cloud.mail.ru → user/pass dans
        //   le formulaire de l'étape 2.

        // ───────── HiDrive / Huawei / Jottacloud / Premiumize / Putio / Sharefile / Zoho ─────────
        "hidrive": OAuthProviderConfig(
            backendName: "hidrive",
            authURL: URL(string: "https://my.hidrive.com/client/authorize")!,
            tokenURL: URL(string: "https://my.hidrive.com/oauth2/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: ["user,rw"],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://developer.hidrive.com/"),
            setupSteps: [
                "Pour HiDrive, le plus simple est `rclone authorize \"hidrive\"` sur un poste avec navigateur.",
                "Follow the Strato/HiDrive web auth.",
                "The terminal shows a complete JSON token.",
                "Paste that JSON below."
            ],
            tokenLabel: "rclone JSON token",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "huaweidrive": OAuthProviderConfig(
            backendName: "huaweidrive",
            authURL: URL(string: "https://oauth-login.cloud.huawei.com/oauth2/v3/authorize")!,
            tokenURL: URL(string: "https://oauth-login.cloud.huawei.com/oauth2/v3/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: ["openid", "https://www.huawei.com/auth/drive"],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://developer.huawei.com/consumer/en/console"),
            setupSteps: [
                "Le plus simple : `rclone authorize \"huaweidrive\"` sur un poste avec navigateur.",
                "Follow the Huawei ID flow.",
                "Copy the JSON token shown in the terminal.",
                "Paste it below."
            ],
            tokenLabel: "rclone JSON token",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "jottacloud": OAuthProviderConfig(
            backendName: "jottacloud",
            authURL: URL(string: "https://jaccount.jottacloud.com/auth/realms/jottacloud/protocol/openid-connect/auth")!,
            tokenURL: URL(string: "https://jaccount.jottacloud.com/auth/realms/jottacloud/protocol/openid-connect/token")!,
            defaultClientID: "jottacli",
            defaultClientSecret: nil,
            defaultScopes: ["offline_access+openid"],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://www.jottacloud.com/web/secure"),
            setupSteps: [
                "Sign in at jottacloud.com.",
                "Profile → “Personal token” → generate a CLI token.",
                "Copy the displayed token.",
                "Paste it below (rclone will convert it to a JSON token on first use)."
            ],
            tokenLabel: "Jottacloud personal token",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "premiumizeme": OAuthProviderConfig(
            backendName: "premiumizeme",
            authURL: URL(string: "https://www.premiumize.me/authorize")!,
            tokenURL: URL(string: "https://www.premiumize.me/token")!,
            defaultClientID: "658877358",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://www.premiumize.me/account"),
            setupSteps: [
                "Sign in at premiumize.me.",
                "My Account → “Customer settings” tab.",
                "Copy the “API Key”.",
                "Paste it below."
            ],
            tokenLabel: "Premiumize API Key",
            tokenFieldName: "api_key",
            tokenHint: nil
        ),
        "putio": OAuthProviderConfig(
            backendName: "putio",
            authURL: URL(string: "https://api.put.io/v2/oauth2/authenticate")!,
            tokenURL: URL(string: "https://api.put.io/v2/oauth2/access_token")!,
            defaultClientID: "4131",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://app.put.io/settings/account/oauth/apps"),
            setupSteps: [
                "On app.put.io → Settings → OAuth Apps.",
                "“Create new app” → give it a name (e.g. “Rclone GUI”).",
                "The panel shows an OAuth token immediately.",
                "Copy that token and paste it below."
            ],
            tokenLabel: "Put.io OAuth token",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "sharefile": OAuthProviderConfig(
            backendName: "sharefile",
            authURL: URL(string: "https://secure.sharefile.com/oauth/authorize")!,
            tokenURL: URL(string: "https://secure.sharefile.com/oauth/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://api.sharefile.com/rest/getAuthorizationCode"),
            setupSteps: [
                "Le plus simple : `rclone authorize \"sharefile\"` sur un poste avec navigateur.",
                "rclone handles subdomain probing automatically.",
                "Copy the returned JSON token.",
                "Paste it below."
            ],
            tokenLabel: "rclone JSON token",
            tokenFieldName: "token",
            tokenHint: nil
        ),
        "zoho": OAuthProviderConfig(
            backendName: "zoho",
            authURL: URL(string: "https://accounts.zoho.com/oauth/v2/auth")!,
            tokenURL: URL(string: "https://accounts.zoho.com/oauth/v2/token")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: ["WorkDrive.team.READ", "WorkDrive.workspace.READ", "WorkDrive.files.ALL"],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://api-console.zoho.com/"),
            setupSteps: [
                "Open the Zoho API Console.",
                "Create a “Self Client”.",
                "“Generate Code” tab → WorkDrive.* scopes → 10 min duration.",
                "Exchange the code for an access_token via curl (see the rclone docs).",
                "Paste the JSON token below."
            ],
            tokenLabel: "Zoho JSON token",
            tokenFieldName: "token",
            tokenHint: nil
        ),

        // ───────── Token-only providers ─────────
        "filefabric": OAuthProviderConfig(
            backendName: "filefabric",
            authURL: URL(string: "https://www.smartfile.com/")!,
            tokenURL: URL(string: "https://www.smartfile.com/")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://www.smartfile.com/app/login/"),
            setupSteps: [
                "Sign in to your Enterprise File Fabric instance.",
                "Profile → “API Tokens” → “Generate new token”.",
                "Copy the displayed permanent_token.",
                "Paste it below."
            ],
            tokenLabel: "File Fabric permanent token",
            tokenFieldName: "permanent_token",
            tokenHint: nil
        ),
        "linkbox": OAuthProviderConfig(
            backendName: "linkbox",
            authURL: URL(string: "https://linkbox.to/")!,
            tokenURL: URL(string: "https://linkbox.to/")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://www.linkbox.to/admin/account"),
            setupSteps: [
                "Sign in at linkbox.to → Account page.",
                "“API Token” section → copy the displayed token (or ask support).",
                "Paste it below (the “token” field).",
                "On the previous wizard step, also fill in “email” and “password” (the usual Linkbox credentials) in the main form."
            ],
            tokenLabel: "Linkbox API Token",
            tokenFieldName: "token",
            tokenHint: "⚠️ In addition to the token, Linkbox requires email + password (fill them in the main form)."
        ),
        "shade": OAuthProviderConfig(
            backendName: "shade",
            authURL: URL(string: "https://shade.inc/")!,
            tokenURL: URL(string: "https://shade.inc/")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://shade.inc/"),
            setupSteps: [
                "Sign in to Shade and open the account settings.",
                "Generate an API token.",
                "Paste it below."
            ],
            tokenLabel: "Shade API Token",
            tokenFieldName: "token",
            tokenHint: nil
        ),

        // ───────── Nouveaux backends rclone 1.73 ─────────
        // Drime : un seul champ utile, l'API Access Token créé sur le web.
        "drime": OAuthProviderConfig(
            backendName: "drime",
            authURL: URL(string: "https://app.drime.cloud/")!,
            tokenURL: URL(string: "https://app.drime.cloud/")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://app.drime.cloud/"),
            setupSteps: [
                "Sign in to Drime on the web (app.drime.cloud).",
                "Open Account Settings → the “Developer” tab.",
                "Create a token (API Access Token) and name it, e.g. “Rclone GUI”.",
                "Copy the displayed token.",
                "Paste it below."
            ],
            tokenLabel: "Drime API Access Token",
            tokenFieldName: "access_token",
            tokenHint: "Token created in Settings → Developer on app.drime.cloud."
        ),
        // Filen : email + mot de passe se saisissent au formulaire (champs
        // Required du schéma rclone). Il manque la clé API, qui ne s'obtient
        // QUE via le CLI Filen (`filen export-api-key`) → on guide ici.
        "filen": OAuthProviderConfig(
            backendName: "filen",
            authURL: URL(string: "https://app.filen.io/")!,
            tokenURL: URL(string: "https://app.filen.io/")!,
            defaultClientID: "",
            defaultClientSecret: nil,
            defaultScopes: [],
            strategy: .manual,
            usePKCE: false,
            setupURL: URL(string: "https://github.com/FilenCloudDienste/filen-cli"),
            setupSteps: [
                "In the previous step, enter your Filen email and password.",
                "On a computer, install the Filen CLI (link below).",
                "Sign in with `filen`, then run `filen export-api-key`.",
                "Copy the API key shown.",
                "Paste it below."
            ],
            tokenLabel: "Filen API key (`filen export-api-key` command)",
            tokenFieldName: "api_key",
            tokenHint: "⚠️ The API key is only available via the Filen CLI on a computer. Email + password are entered in the Form step."
        ),
    ]

    // MARK: - Field-level overrides (labels + rendu)

    /// Labels par backend/champ quand le nom rclone humanisé est trompeur —
    /// ex. iCloud attend le mot de passe HABITUEL du compte (pas un mot de
    /// passe d'app) et `service` choisit entre Drive et Photos. Chaînes FR
    /// sources, résolues via le String Catalog.
    nonisolated static func fieldLabel(backend: String, field: String) -> String? {
        switch (backend, field) {
        case ("iclouddrive", "apple_id"):
            return String(localized: "Apple ID Email")
        case ("iclouddrive", "password"):
            return String(localized: "Apple ID Password (standard)")
        case ("iclouddrive", "service"):
            return String(localized: "iCloud Service (Drive or Photos)")
        default:
            return nil
        }
    }

    /// Champs à présenter en sélecteur exclusif même quand rclone ne marque
    /// pas l'option `Exclusive` (une valeur libre n'aurait aucun sens).
    private nonisolated static let forcedPickerFields: [String: Set<String>] = [
        "iclouddrive": ["service"],
    ]

    nonisolated static func forcesPicker(backend: String, field: String) -> Bool {
        forcedPickerFields[backend]?.contains(field) ?? false
    }

    // MARK: - Backends to hide on iOS

    nonisolated static let hiddenOnIOS: Set<String> = [
        "tardigrade",   // Deprecated alias of storj
        "memory",       // In-process backend — no value to end-users
    ]

    // MARK: - Setup guides (form path — clé / token sans OAuth)
    //
    // Backends qui ont des champs « clé/token/identifiants » dans le
    // formulaire mais sans tutoriel : on ajoute ici un encart « où obtenir
    // tes identifiants » (lien + étapes). Ne déclenche PAS l'étape OAuth.

    nonisolated static let setupGuides: [String: BackendSetupGuide] = [
        "pixeldrain": BackendSetupGuide(
            setupURL: URL(string: "https://pixeldrain.com/user/api_keys"),
            steps: [
                "Sign in to your Pixeldrain account (a subscription is required for full access).",
                "Open the “API keys” page (link below) and generate a key.",
                "Copy the key and paste it into the form’s “Api Key” field."
            ],
            note: "Read-only access to a shared folder is possible without a key: leave “Api Key” empty and enter the shared folder ID."
        ),
        "fichier": BackendSetupGuide(
            setupURL: URL(string: "https://1fichier.com/console/params.pl"),
            steps: [
                "Sign in at 1fichier.com.",
                "Open “My account” → “Settings” (Console → Params, link below).",
                "Generate / copy your API key.",
                "Paste it into the form’s “Api Key” field."
            ],
            note: "The 1Fichier API generally requires a Premium account."
        ),
        "imagekit": BackendSetupGuide(
            setupURL: URL(string: "https://imagekit.io/dashboard/developer/api-keys"),
            steps: [
                "Sign in to your ImageKit.io dashboard.",
                "Open “Developer” → “API Keys” (link below).",
                "Copy your URL endpoint, Public Key and Private Key.",
                "Fill in “Endpoint”, “Public Key” and “Private Key” in the form."
            ],
            note: nil
        ),
        "internetarchive": BackendSetupGuide(
            setupURL: URL(string: "https://archive.org/account/s3.php"),
            steps: [
                "Sign in at archive.org.",
                "Open the S3 keys page (link below).",
                "Copy your “access key” and “secret key”.",
                "Fill in “Access Key Id” and “Secret Access Key” in the form."
            ],
            note: "Leave both fields empty for anonymous read-only access."
        ),
        "gofile": BackendSetupGuide(
            setupURL: URL(string: "https://gofile.io/myProfile"),
            steps: [
                "Sign in at gofile.io.",
                "Open “My Profile” (link below).",
                "Copy your “Account API token”.",
                "Paste it into the form’s “Access Token” field."
            ],
            note: "Without a token, only public/anonymous access is possible."
        ),
        "sia": BackendSetupGuide(
            setupURL: nil,
            steps: [
                "Sia targets a self-hosted node (siad / renterd) that you run yourself.",
                "Set “Api Url” to your daemon’s address (e.g. http://my-node:9980).",
                "Get the password from the “apipassword” file in your node’s .sia directory.",
                "Set “Api Password” to this value."
            ],
            note: "From iOS, the Sia node must be reachable over the network (not localhost)."
        ),
        "storj": BackendSetupGuide(
            setupURL: URL(string: "https://docs.storj.io/dcs/access"),
            steps: [
                "Open your project’s Storj console (satellite, e.g. us1.storj.io).",
                "Simple: create an “Access Grant” and paste it into “Access Grant” (provider = existing).",
                "Advanced: provider = new, then fill in “Satellite Address”, “Api Key” and “Passphrase”.",
                "The link below explains how to generate these credentials."
            ],
            note: "The passphrase encrypts your data: keep it safe — it cannot be recovered."
        ),
        "netstorage": BackendSetupGuide(
            setupURL: URL(string: "https://control.akamai.com/"),
            steps: [
                "In Akamai Control Center, open NetStorage → your Storage Group.",
                "Get the “host” (domain + path), the “account” (Upload Account) and the G2O secret key.",
                "Fill in “Host”, “Account” and “Secret” in the form."
            ],
            note: "Akamai enterprise backend — requires a NetStorage account."
        ),
        "ulozto": BackendSetupGuide(
            setupURL: nil,
            steps: [
                "Enter your Uloz.to login in “Username” and your password in “Password”.",
                "The “App Token” field is optional — leave it empty."
            ],
            note: "Uloz.to’s app_token is reserved for their in-house app and is unreliable: prefer login + password."
        ),
    ]
}
