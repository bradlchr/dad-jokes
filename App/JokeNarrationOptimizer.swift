import Foundation
import Observation

@MainActor
@Observable
final class JokeNarrationOptimizer {
  private(set) var isAvailable = JokeSpeech.isAvailable
  private(set) var progress: Progress?
  private(set) var summary: LocalizedStringResource?

  @ObservationIgnored private var automatic =
    UserDefaults.standard.stringArray(forKey: JokeNarrationOptimizer.pendingKey) ?? []
  @ObservationIgnored private var bulk: [String] = []
  @ObservationIgnored private var bulkID: UUID?
  @ObservationIgnored private var worker: Task<Void, Never>?

  private static let pendingKey = "pending-joke-narration"
  private static let resumeKey = "resume-library-narration"

  func refresh(for library: JokeLibrary) {
    isAvailable = JokeSpeech.isAvailable
    if isAvailable, bulkID == nil, UserDefaults.standard.bool(forKey: Self.resumeKey) {
      optimizeLibrary(library)
    }
    startWorker(for: library)
  }

  func schedule(_ joke: Joke, in library: JokeLibrary) {
    if !automatic.contains(joke.id) {
      automatic.append(joke.id)
      UserDefaults.standard.set(automatic, forKey: Self.pendingKey)
    }
    isAvailable = JokeSpeech.isAvailable
    startWorker(for: library)
  }

  func optimizeLibrary(_ library: JokeLibrary) {
    guard isAvailable, bulkID == nil else { return }
    if case .checking = library.migration {
      UserDefaults.standard.set(true, forKey: Self.resumeKey)
      summary = "Optimization will start after the library recovery check."
      return
    }
    bulk = library.jokes.filter { $0.narration == nil }.map(\.id)
    guard !bulk.isEmpty else {
      UserDefaults.standard.removeObject(forKey: Self.resumeKey)
      summary = "Your library is already optimized."
      return
    }
    summary = nil
    progress = Progress(total: bulk.count)
    bulkID = UUID()
    UserDefaults.standard.set(true, forKey: Self.resumeKey)
    startWorker(for: library)
  }

  func cancelLibraryOptimization() {
    finishBulk()
    summary = "Optimization stopped. Prepared jokes are saved."
  }

  private func startWorker(for library: JokeLibrary) {
    guard worker == nil, isAvailable, !automatic.isEmpty || !bulk.isEmpty else { return }
    worker = Task(priority: .utility) { [weak self, weak library] in
      guard let self, let library else { return }
      await processQueue(in: library)
    }
  }

  private func processQueue(in library: JokeLibrary) async {
    defer { worker = nil }
    while JokeSpeech.isAvailable, let id = automatic.first ?? bulk.first {
      let session = bulkID
      let wasAutomatic = automatic.contains(id)
      let original = library.jokes.first { $0.id == id }
      let prepared: JokeNarration?
      if let original, original.narration == nil {
        prepared = try? await JokeSpeech.prepare(original)
      } else {
        prepared = original?.narration
      }

      guard JokeSpeech.isAvailable else { break }
      let activeBulk = session != nil && session == bulkID && bulk.contains(id)
      if (wasAutomatic || activeBulk), let original, let prepared {
        library.applyNarration(prepared, to: original)
      }

      // Edits can arrive while the model is working. Leave the new text in the queue.
      if let original, let current = library.jokes.first(where: { $0.id == id }),
         original.setup != current.setup || original.punchline != current.punchline { continue }

      if wasAutomatic {
        automatic.removeAll { $0 == id }
        UserDefaults.standard.set(automatic, forKey: Self.pendingKey)
      }
      if activeBulk, var snapshot = progress {
        bulk.removeAll { $0 == id }
        snapshot.completed += 1
        if prepared != nil { snapshot.optimized += 1 }
        progress = snapshot
        if bulk.isEmpty {
          finishBulk()
          summary = snapshot.optimized == snapshot.completed
            ? "Library optimization complete."
            : "Prepared \(snapshot.optimized) of \(snapshot.completed) jokes. The remaining jokes can still be played."
        }
      }
    }
    isAvailable = JokeSpeech.isAvailable
    if !isAvailable, bulkID != nil {
      bulk = []
      progress = nil
      bulkID = nil
      summary = "Optimization will resume when Apple Intelligence is available."
    }
  }

  private func finishBulk() {
    bulk = []
    bulkID = nil
    progress = nil
    UserDefaults.standard.removeObject(forKey: Self.resumeKey)
  }

  struct Progress {
    var total: Int
    var completed = 0
    var optimized = 0
  }
}
