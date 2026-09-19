//
//  PlaybackSettingsView.swift
//  Rclone GUI — Views/Settings
//
//  Réglages de lecture : Picture-in-Picture automatique, audio en arrière-plan,
//  vitesse de lecture par défaut. Stockés en UserDefaults et lus par
//  MediaPlayerView (auto-PiP), MainTabView (audio en fond) et
//  AudioPlaybackCoordinator (vitesse).
//

import SwiftUI

enum PlaybackDefaults {
    static let autoPiPKey = "playback.autoPiP"
    static let backgroundAudioKey = "playback.backgroundAudio"
    static let defaultRateKey = "playback.defaultRate"

    /// Clé absente → activé par défaut (UserDefaults.bool renverrait false).
    static var autoPiP: Bool {
        UserDefaults.standard.object(forKey: autoPiPKey) as? Bool ?? true
    }
    static var backgroundAudio: Bool {
        UserDefaults.standard.object(forKey: backgroundAudioKey) as? Bool ?? true
    }
    /// Clé absente / 0 → 1.0× (vitesse normale).
    static var rate: Double {
        let r = UserDefaults.standard.double(forKey: defaultRateKey)
        return r > 0 ? r : 1.0
    }
}

struct PlaybackSettingsView: View {
    @AppStorage(PlaybackDefaults.autoPiPKey) private var autoPiP = true
    @AppStorage(PlaybackDefaults.backgroundAudioKey) private var backgroundAudio = true
    @AppStorage(PlaybackDefaults.defaultRateKey) private var defaultRate = 1.0

    private let rates: [Double] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $backgroundAudio) {
                    Label("Background audio", systemImage: "speaker.wave.2")
                }
            } footer: {
                Text("Continue audio playback when the app goes into background or the screen is locked. When disabled, playback pauses.")
            }

            Section {
                Toggle(isOn: $autoPiP) {
                    Label("Automatic PiP", systemImage: "pip.enter")
                }
            } footer: {
                Text("Switch video to Picture-in-Picture (floating window) when leaving the app during playback.")
            }

            Section {
                Picker(selection: $defaultRate) {
                    ForEach(rates, id: \.self) { r in
                        Text(rateLabel(r)).tag(r)
                    }
                } label: {
                    Label("Default speed", systemImage: "gauge.with.dots.needle.67percent")
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #endif
            } footer: {
                Text("Speed applied at the start of an audio track (useful for podcasts and audiobooks).")
            }
        }
        .navigationTitle("Playback")
        .rgInlineNavTitle()
    }

    private func rateLabel(_ r: Double) -> String {
        if r == 1.0 { return "Normale (1×)" }
        return String(format: "%g×", r)
    }
}
