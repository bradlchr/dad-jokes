import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct StageVoiceHelp: View {
  var language: String
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Download a stage voice")
            .font(.system(.title, design: .serif).weight(.bold))
            .accessibilityAddTraits(.isHeader)
          #if os(iOS)
          Text("In Settings, go to Accessibility → Read & Speak → Voices. If Settings opens to Dad Jokes, go back to the main Settings screen first.")
          #else
          Text("In System Settings, go to Accessibility → Read & Speak, then click the info button next to System voice.")
          #endif
          Text("Choose \(language) and download an Enhanced or Premium male voice. Dad Jokes will pick it up when you return.")
            .foregroundStyle(.secondary)
          Button("Open Settings", systemImage: "gearshape", action: openSettings)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 480, alignment: .leading)
        .padding(24)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("Stage Voice")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 460, minHeight: 310)
    #endif
  }

  private func openSettings() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    #else
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
      NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
    #endif
  }
}
