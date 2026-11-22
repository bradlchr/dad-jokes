import SwiftUI

struct FavoriteDadView: View {
  @Binding var preference: String
  @State private var visibleDad: StagePerformer?
  @State private var audio = StageAudio()
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let velvet = Color(red: 0.09, green: 0.04, blue: 0.15)
  private let gold = Color(red: 1, green: 0.84, blue: 0.47)
  private var dad: StagePerformer { visibleDad ?? .martin }
  private var sample: Joke {
    Joke(setup: String(localized: "I only know twenty-five letters of the alphabet. I don’t know why."))
  }

  init(preference: Binding<String>) {
    _preference = preference
    _visibleDad = State(initialValue: StagePerformer(rawValue: preference.wrappedValue) ?? .martin)
  }

  var body: some View {
    NavigationStack {
      DuoLayout { size in
        ScrollView {
          VStack(spacing: 17) {
            stage(height: min(390, max(175, size.height * 0.56)))
            choices
          }
          .frame(maxWidth: 650)
          .padding(.bottom, 24)
          .frame(maxWidth: .infinity, minHeight: size.height, alignment: .center)
        }
      } primary: { size in
        stage(height: size.height)
      } secondary: { size in
        ScrollView {
          choices
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: size.height)
        }
      }
      .background(velvet.ignoresSafeArea())
      .navigationTitle("Favorite Dad")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .keyboardShortcut(.cancelAction)
        }
      }
    }
    .preferredColorScheme(.dark)
    .tint(gold)
    .onChange(of: visibleDad) { audio.stop() }
    .onChange(of: scenePhase) { if scenePhase != .active { audio.stop() } }
    .onDisappear { audio.stop() }
    #if os(macOS)
    .frame(minWidth: 480, minHeight: 560)
    #endif
  }

  private func stage(height: CGFloat) -> some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(StagePerformer.allCases, id: \.self) { performer in
          StageSet(performer: performer, reaction: 0, speaking: performer == dad && audio.isSpeaking)
            .containerRelativeFrame(.horizontal)
            .accessibilityHidden(performer != dad)
            .id(performer)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollPosition(id: $visibleDad)
    .scrollIndicators(.hidden)
    .frame(height: height)
    .overlay {
      HStack {
        pager("Previous dad", symbol: "chevron.backward", step: -1)
          .keyboardShortcut(.leftArrow, modifiers: [])
        Spacer()
        pager("Next dad", symbol: "chevron.forward", step: 1)
          .keyboardShortcut(.rightArrow, modifiers: [])
      }
      .padding(.horizontal, 14)
    }
  }

  private func pager(_ title: LocalizedStringKey, symbol: String, step: Int) -> some View {
    let index = dad.voiceIndex + step
    return Button {
      withAnimation(reduceMotion ? nil : .snappy) { visibleDad = StagePerformer.allCases[index] }
    } label: {
      Label(title, systemImage: symbol)
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
        .background(.white.opacity(0.12), in: Circle())
    }
    .buttonStyle(.plain)
    .disabled(!StagePerformer.allCases.indices.contains(index))
    .opacity(StagePerformer.allCases.indices.contains(index) ? 1 : 0.38)
  }

  private var choices: some View {
    VStack(spacing: 12) {
      VStack(spacing: 5) {
        Text(dad.rawValue)
          .font(.system(.largeTitle, design: .serif).weight(.bold))
          .accessibilityAddTraits(.isHeader)
        Text("\(dad.voiceIndex + 1) of \(StagePerformer.allCases.count)")
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
          .accessibilityLabel("Dad \(dad.voiceIndex + 1) of \(StagePerformer.allCases.count)")
      }
      Button(audio.isSpeaking ? "Stop Sample" : "Hear Voice Sample",
             systemImage: audio.isSpeaking ? "stop.fill" : "speaker.wave.2", action: playSample)
        .buttonStyle(.bordered)
      Button {
        choose(dad.rawValue)
      } label: {
        Text(preference == dad.rawValue ? "\(dad.rawValue) is Your Favorite" : "Choose \(dad.rawValue)")
          .font(.body.weight(.semibold))
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, minHeight: 48)
          .foregroundStyle(velvet)
          .background(gold, in: Capsule())
      }
      .buttonStyle(.plain)
      Button("Keep It Random", systemImage: "shuffle") { choose(StagePerformer.randomPreference) }
        .buttonStyle(.borderless)
        .padding(.vertical, 5)
    }
    .frame(maxWidth: 330)
    .padding(.horizontal, 22)
  }

  private func playSample() {
    if audio.isSpeaking {
      audio.stop()
    } else {
      audio.speak(sample.setup, using: StageVoice.select(for: sample, performer: dad), pace: 1) {}
    }
  }

  private func choose(_ selection: String) {
    preference = selection
    dismiss()
  }
}
