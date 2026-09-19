//
//  FlowIntents.swift
//  Rclone GUI — AppIntents (Flows / automatisations locales)
//
//  Intents « Flows » (RG-2) : briques d'automatisation 100 % locales,
//  composables dans l'app Raccourcis et par Siri. Aucune dépendance serveur.
//
//    - RunPhotoSyncIntent   : « Sauvegarder mes photos » (lance PhotoSync)
//    - BackupFolderIntent   : « Sauvegarder un dossier » (sync remote → remote)
//    - PauseTransfersIntent  : met en pause tous les transferts
//    - ResumeTransfersIntent : reprend tous les transferts
//
//  Ces intents sont `AppIntent` (découvrables dans Raccourcis), à la
//  différence des LiveActivityIntent de PhotoSyncIntents.swift qui pilotent
//  l'Island.
//

import AppIntents
import Foundation

// MARK: - Sauvegarder mes photos

@available(iOS 17.0, *)
public struct RunPhotoSyncIntent: AppIntent {
    public static let title: LocalizedStringResource = "Back up my photos"
    public static let description = IntentDescription(
        "Runs a photo library backup via PhotoSync. Ideal for automation (e.g. every night, connected to power)."
    )

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await PhotoSyncService.shared.startFullSync()
        let done = summary.completedCount
        let failed = summary.failedCount
        let msg = failed > 0
            ? "Sauvegarde photos lancée — \(done) envoyée(s), \(failed) à revoir."
            : "Sauvegarde photos lancée — \(done) élément(s) traité(s)."
        return .result(dialog: IntentDialog(stringLiteral: msg))
    }
}

// MARK: - Sauvegarder un dossier (remote → remote)

@available(iOS 17.0, *)
public struct BackupFolderIntent: AppIntent {
    public static let title: LocalizedStringResource = "Back up a folder"
    public static let description = IntentDescription(
        "Synchronizes a folder from one remote to another (rclone backup). The destination folder is updated to match the source."
    )

    @Parameter(title: "Source remote")
    public var sourceRemote: String

    @Parameter(title: "Source folder", default: "")
    public var sourcePath: String

    @Parameter(title: "Destination remote")
    public var destinationRemote: String

    @Parameter(title: "Destination folder", default: "")
    public var destinationPath: String

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let src = sourcePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let dst = destinationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let entry = RemoteEntryDTO(
            pathInRemote: src,
            name: src.isEmpty ? sourceRemote : (src as NSString).lastPathComponent,
            isDirectory: true,
            size: 0,
            modTime: Date(),
            mimeType: nil,
            hashMD5: nil,
            hashSHA1: nil
        )
        try await TransferQueue.shared.enqueueRemoteTransfer(
            kind: .sync,
            srcRemote: sourceRemote,
            entry: entry,
            dstRemote: destinationRemote,
            dstPath: dst
        )
        return .result(dialog: "Sauvegarde de \(sourceRemote):\(src) vers \(destinationRemote):\(dst) lancée.")
    }
}

// MARK: - Pause / reprise globale des transferts

@available(iOS 17.0, *)
public struct PauseTransfersIntent: AppIntent {
    public static let title: LocalizedStringResource = "Pause transfers"
    public static let description = IntentDescription(
        "Pauses all ongoing transfers (useful to save cellular data or battery)."
    )

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await TransferQueue.shared.pauseAllTransfers()
        return .result(dialog: "Transfers paused.")
    }
}

@available(iOS 17.0, *)
public struct ResumeTransfersIntent: AppIntent {
    public static let title: LocalizedStringResource = "Resume transfers"
    public static let description = IntentDescription(
        "Resumes all paused transfers."
    )

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mbps = UserDefaults.standard.double(forKey: "transfer.bandwidthLimitMBps")
        let bytesPerSecond = Int64(mbps * 1024 * 1024)
        try await TransferQueue.shared.resumeAllTransfers(bytesPerSecond: bytesPerSecond)
        return .result(dialog: "Transfers resumed.")
    }
}
