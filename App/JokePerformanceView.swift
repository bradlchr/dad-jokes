import Accessibility
import AVFoundation
import SwiftUI

struct JokePerformanceView: View {
  var performance: JokePerformance
  var library: JokeLibrary
  var anotherJoke: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("stage-audio-enabled") private var soundEnabled = true
  @State private var revealed = false
  @State private var setupFinished = false
  @State private var reaction = 0
  @State private var didAutoplay = false
  @State private var audio = StageAudio()
  @State private var beatTask: Task<Void, Never>?
  @State private var voice: StageVoice?
  @State private var showsVoiceHelp = false
  @State private var savedFromStage = false

  private let golden = Color(red: 1, green: 0.84, blue: 0.47)
  private let velvet = Color(red: 0.09, green: 0.04, blue: 0.15)
  private let cream = Color(red: 1, green: 0.95, blue: 0.83)
  private var joke: Joke { library.currentVersion(of: performance.joke) }

  var body: some View {
    NavigationStack {
      DuoLayout { size in
        let artHeight = max(155, min(size.height * 0.43, 410))
        ScrollView {
          VStack(spacing: 0) {
            speechBubble
              .padding(.horizontal, 22)
              .zIndex(1)
            set.frame(height: artHeight)
            controls
              .padding(.horizontal, 20)
              .padding(.top, 17)
              .padding(.bottom, 22)
          }
          .frame(maxWidth: 710)
          .frame(maxWidth: .infinity, minHeight: size.height, alignment: .center)
        }
      } primary: { _ in
        set
      } secondary: { size in
        ScrollView {
          VStack(spacing: 24) {
            speechBubble
            controls
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .frame(maxWidth: .infinity, minHeight: size.height)
        }
      }
      .background(velvet.ignoresSafeArea())
      .navigationTitle("Dad Jokes Live")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close stage", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .keyboardShortcut(.cancelAction)
        }
        ToolbarItem(placement: .primaryAction) {
          Button(soundEnabled ? "Mute stage" : "Unmute stage",
                 systemImage: soundEnabled ? "speaker.wave.2" : "speaker.slash") { soundEnabled.toggle() }
            .labelStyle(.iconOnly)
            .accessibilityValue(soundEnabled ? "Sound on" : "Sound off")
        }
      }
    }
    .preferredColorScheme(.dark)
    .tint(golden)
    .onDisappear { stopPerformance() }
    .task {
      refreshVoice()
      guard performance.autoplay, soundEnabled, !didAutoplay else { return }
      didAutoplay = true
      perform()
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active { refreshVoice() } else { stopPerformance() }
    }
    .onChange(of: [joke.setup, joke.punchline]) {
      stopPerformance()
      setupFinished = false
      revealed = false
      reaction = 0
      refreshVoice()
    }
    .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
      refreshVoice()
    }
    .onChange(of: soundEnabled) { if !soundEnabled { stopPerformance() } }
    .sheet(isPresented: $showsVoiceHelp) {
      if let voice { StageVoiceHelp(language: voice.languageName) }
    }
  }

  private var set: some View {
    StageSet(performer: performance.performer, reaction: reaction, speaking: audio.isSpeaking)
  }

  private var speechBubble: some View {
    VStack(spacing: 8) {
      Text(revealed ? "PUNCHLINE" : joke.hasPunchline ? "THE SETUP" : "ONE-LINER")
        .font(.caption2.weight(.heavy))
        .tracking(2)
        .foregroundStyle(Color(red: 0.39, green: 0.21, blue: 0.34))
        .accessibilityHidden(true)
      Text(revealed ? joke.punchline : joke.setup)
        .font(.system(.title2, design: .serif).weight(.bold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
        .contentTransition(.opacity)
    }
    .foregroundStyle(velvet)
    .frame(maxWidth: 470)
    .padding(.horizontal, 20)
    .padding(.vertical, 17)
    .background(cream, in: .rect(cornerRadius: 21))
    .background(alignment: .bottom) {
      BubbleTail().fill(cream)
        .frame(width: 23, height: 15)
        .offset(y: 11)
        .accessibilityHidden(true)
    }
  }

  private var controls: some View {
    VStack(spacing: 8) {
      if reaction > 0 {
        Label("The crowd laughs!", systemImage: "hands.clap.fill")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(golden)
          .transition(.opacity)
      }
      Button(action: perform) {
        Label(setupFinished ? "Hear the Punchline" : "Play",
              systemImage: setupFinished ? "mic.fill" : "play.fill")
          .contentTransition(.opacity)
          .font(.body.weight(.bold))
          .multilineTextAlignment(.center)
          .padding(.vertical, 13)
          .padding(.horizontal, 22)
          .frame(maxWidth: 370, minHeight: 48)
          .foregroundStyle(velvet)
          .background(golden, in: Capsule())
      }
      .buttonStyle(.plain)
      .disabled(audio.isSpeaking || beatTask != nil)
      .opacity(audio.isSpeaking || beatTask != nil ? 0.65 : 1)
      if reaction > 0, let anotherJoke {
        Button("Another joke", systemImage: "shuffle", action: anotherJoke)
          .buttonStyle(.bordered)
          .tint(cream)
      }
      saveAction
      if soundEnabled, let voice, !voice.isHighQuality {
        Button("Download a better voice", systemImage: "arrow.down.circle") {
          stopPerformance()
          showsVoiceHelp = true
        }
        .font(.footnote.weight(.semibold))
        .buttonStyle(.borderless)
        .tint(cream)
        .padding(.vertical, 8)
      }
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var saveAction: some View {
    if savedFromStage {
      Label("Added to Library", systemImage: "checkmark")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(golden)
    } else if !library.hasCopy(of: joke) {
      Button("Add to Library", systemImage: "plus") {
        if library.addIfNew(joke) {
          savedFromStage = true
          AccessibilityNotification.Announcement("Added to Library").post()
        }
      }
      .font(.subheadline.weight(.semibold))
      .buttonStyle(.borderless)
      .tint(cream)
      .padding(.vertical, 6)
    }
  }

  private func refreshVoice() {
    voice = StageVoice.select(for: joke, performer: performance.performer)
  }

  private func perform() {
    let isPunchline = joke.hasPunchline && setupFinished
    let performer = performance.performer
    withAnimation(reduceMotion ? nil : .smooth) { reaction = 0 }

    if isPunchline, !revealed, soundEnabled, voice?.canNarrate == true {
      afterBeat(performer.punchlineBeat) { deliver(isPunchline: true) }
    } else {
      deliver(isPunchline: isPunchline)
    }
  }

  private func deliver(isPunchline: Bool) {
    let isSetup = joke.hasPunchline && !isPunchline
    let line = isPunchline ? joke.punchline : joke.setup
    withAnimation(reduceMotion ? nil : .smooth) { revealed = isPunchline }

    let finished = {
      if isSetup {
        withAnimation(reduceMotion ? nil : .snappy) { setupFinished = true }
      } else if soundEnabled {
        afterBeat(.milliseconds(240), action: respond)
      } else {
        respond()
      }
    }
    if soundEnabled, let narration = voice, narration.canNarrate {
      let pace = isSetup ? 1 : performance.performer.punchlinePace
      let prepared = isPunchline ? joke.narration?.punchline : joke.narration?.setup
      audio.speak(JokeSpeech.spokenLine(line, prepared: prepared),
                  using: narration, pace: pace, completion: finished)
    } else {
      AccessibilityNotification.Announcement(line).post()
      finished()
    }
  }

  private func afterBeat(_ duration: Duration, action: @escaping @MainActor () -> Void) {
    beatTask?.cancel()
    beatTask = Task { @MainActor in
      do { try await Task.sleep(for: duration) } catch { return }
      guard !Task.isCancelled else { return }
      beatTask = nil
      action()
    }
  }

  private func stopPerformance() {
    beatTask?.cancel()
    beatTask = nil
    audio.stop()
  }

  private func respond() {
    if soundEnabled { audio.playAudience() }
    withAnimation(reduceMotion ? nil : .snappy) { reaction += 1 }
  }
}

private struct BubbleTail: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
      path.closeSubpath()
    }
  }
}
