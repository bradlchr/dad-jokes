import SwiftUI

struct PreferencesView: View {
  var library: JokeLibrary
  @Binding var theme: JokeTheme
  @AppStorage("include-mature-jokes") private var includesMature = false
  @AppStorage(StagePerformer.preferenceKey) private var favoritePerformer = StagePerformer.randomPreference
  @AppStorage("reveal-punchlines") private var hidesPunchlines = true
  @Environment(\.dynamicTypeSize) private var typeSize

  @State private var exporting = false
  @State private var importing = false
  @State private var alert: BackupMessage?
  @State private var requestedRecovery = false
  @State private var choosingDad = false

  var body: some View {
    DuoLayout { size in
      if size.width >= 700 && !typeSize.isAccessibilitySize {
        ScrollView {
          HStack(alignment: .top, spacing: 22) {
            stageSettings
              .frame(maxWidth: 420)
            librarySettings
              .frame(maxWidth: 540)
          }
          .padding(24)
          .frame(maxWidth: .infinity)
        }
      } else {
        compactSettings
      }
    } primary: { _ in
      ScrollView { stageSettings.padding(16) }
    } secondary: { _ in
      ScrollView { librarySettings.padding(16) }
    }
    .background(Color("Stage").ignoresSafeArea())
    .navigationTitle("Settings")
    .sheet(isPresented: $choosingDad) {
      FavoriteDadView(preference: $favoritePerformer)
    }
    .fileExporter(isPresented: $exporting, document: JokeArchiveDocument(archive: library.archive),
                  contentType: .json, defaultFilename: "Dad Jokes Library") {
      if case .failure = $0 {
        alert = BackupMessage(title: "Couldn’t export library",
                              detail: "Choose another location and try again.")
      }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let archive = try JokeArchive.decode(Data(contentsOf: url))
        let count = library.merge(archive)
        alert = BackupMessage(title: "Library imported",
                              detail: String(localized: "\(count) new jokes added."))
      } catch {
        alert = BackupMessage(title: "Couldn’t import library",
                              detail: "Choose a Dad Jokes library backup in JSON format.")
      }
    }
    .alert(alert?.title ?? "", isPresented: Binding(
      get: { alert != nil }, set: { if !$0 { alert = nil } }
    ), presenting: alert) { _ in
      Button("OK", role: .cancel) {}
    } message: { message in
      Text(message.detail)
    }
  }

  private var compactSettings: some View {
    Form {
      Section("Reading") { readingControls }
      Section("Dad Jokes Live") { favoriteDadRow }
      Section("Apple Intelligence") { narrationControls }
      Section("Appearance") { themePicker }
      Section("Library Backup") { backupControls }
      Section("About") { sourceLink }
    }
    .formStyle(.grouped)
  }

  private var stageSettings: some View {
    VStack(spacing: 18) {
      VStack(spacing: 0) {
        Text("Dad Jokes Live")
          .font(.system(.title2, design: .serif).weight(.bold))
          .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.47))
          .accessibilityAddTraits(.isHeader)
          .padding(.top, 17)
          .padding(.bottom, 7)
        StageSet(performer: StagePerformer(rawValue: favoritePerformer) ?? .martin,
                 reaction: 0, speaking: false)
          .frame(height: 226)
          .accessibilityHidden(true)
        favoriteDadRow
          .padding(16)
          .background(Color("StageSurface"))
      }
      .background(Color(red: 0.09, green: 0.04, blue: 0.15))
      .clipShape(.rect(cornerRadius: 20))
      preferenceCard("Appearance") { themePicker }
    }
    .frame(maxWidth: .infinity)
  }

  private var librarySettings: some View {
    VStack(spacing: 18) {
      preferenceCard("Reading") { readingControls }
      preferenceCard("Apple Intelligence") { narrationControls }
      preferenceCard("Library Backup") { backupControls }
      preferenceCard("About") { sourceLink }
    }
    .frame(maxWidth: .infinity)
  }

  private func preferenceCard<Content: View>(
    _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      Text(title)
        .font(.system(.title3, design: .serif).weight(.bold))
        .accessibilityAddTraits(.isHeader)
      content()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(18)
    .background(Color("StageSurface"), in: .rect(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .strokeBorder(.primary.opacity(0.08))
        .allowsHitTesting(false)
    }
  }

  private var favoriteDadRow: some View {
    Button {
      choosingDad = true
    } label: {
      LabeledContent {
        Text(StagePerformer(rawValue: favoritePerformer)?.rawValue ?? String(localized: "Random"))
          .foregroundStyle(.secondary)
      } label: {
        Label("Favorite Dad", systemImage: "theatermasks")
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(.tint)
  }

  @ViewBuilder
  private var readingControls: some View {
    Toggle("Tap to reveal punchlines", isOn: $hidesPunchlines)
    Toggle("Include mature jokes", isOn: $includesMature)
  }

  @ViewBuilder
  private var narrationControls: some View {
    let optimizer = library.narrationOptimizer
    if let progress = optimizer.progress {
      ProgressView(value: Double(progress.completed), total: Double(progress.total)) {
        Text("Optimizing joke delivery")
      } currentValueLabel: {
        Text("\(progress.completed) of \(progress.total) jokes checked")
      }
      Button("Stop Optimization", role: .cancel) { optimizer.cancelLibraryOptimization() }
    } else {
      Button("Optimize Joke Library", systemImage: "sparkles") { optimizer.optimizeLibrary(library) }
        .disabled(!optimizer.isAvailable)
    }
    Text(optimizer.summary ?? JokeSpeech.availabilityMessage)
      .font(.footnote)
      .foregroundStyle(.secondary)
  }

  private var themePicker: some View {
    Picker("Theme", selection: $theme) {
      ForEach(JokeTheme.allCases) { theme in
        Label {
          Text(theme.name)
        } icon: {
          Circle().fill(theme.accent).frame(width: 12, height: 12)
        }
        .tag(theme)
      }
    }
    .pickerStyle(.menu)
  }

  @ViewBuilder
  private var backupControls: some View {
    Button("Export library", systemImage: "square.and.arrow.up") { exporting = true }
    Button("Import library", systemImage: "square.and.arrow.down") { importing = true }
    if library.canRetryRecovery {
      Button("Recover Original Library", systemImage: "arrow.clockwise") {
        requestedRecovery = true
        Task { await library.recoverOriginalLibrary() }
      }
    }
    if requestedRecovery {
      Text(library.migrationMessage)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var sourceLink: some View {
    Link("Online jokes by icanhazdadjoke", destination: URL(string: "https://icanhazdadjoke.com")!)
  }
}

private struct BackupMessage {
  var title: LocalizedStringKey
  var detail: String
}
