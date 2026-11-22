import CloudKit
import CoreData
import Foundation

enum LegacyLibraryMigration {
  private static let appGroup = "group.dadjokes.core.data"
  private static let cloudIdentifier = "iCloud.com.mimikmeapps.dadjokes"

  static func localArchive() throws -> JokeArchive? {
    let manager = FileManager.default
    let group = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    let directories: [URL?] = [group, NSPersistentContainer.defaultDirectoryURL(),
                               manager.urls(for: .documentDirectory, in: .userDomainMask).first]
    return try localArchive(in: directories.compactMap { $0 })
  }

  static func localArchive(in directories: [URL], modelURL: URL? = nil) throws -> JokeArchive? {
    let model = try legacyModel(at: modelURL)
    let manager = FileManager.default
    var seen: Set<URL> = []
    var result: JokeArchive?
    for directory in directories {
      guard let files = manager.enumerator(at: directory, includingPropertiesForKeys: nil,
                                           options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
      for case let file as URL in files where file.pathExtension.lowercased() == "sqlite" {
        guard file.lastPathComponent != "CloudRecovery.sqlite",
              seen.insert(file.standardizedFileURL.resolvingSymlinksInPath()).inserted else { continue }
        let options = [NSReadOnlyPersistentStoreOption: true, NSPersistentHistoryTrackingKey: true]
        let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
          ofType: NSSQLiteStoreType, at: file, options: options
        )
        guard let metadata, model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
          if file.lastPathComponent == "Main.sqlite" {
            throw CocoaError(.fileReadUnknown)
          }
          continue
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                         configurationName: nil, at: file, options: options)
        let archive = try readArchive(from: coordinator)
        try coordinator.remove(store)
        if var previous = result {
          let existingIDs = Set(previous.jokes.map(\.id))
          previous.jokes.append(contentsOf: archive.jokes.filter { !existingIDs.contains($0.id) })
          previous.favorites.formUnion(archive.favorites)
          previous.categoryNames.formUnion(archive.categoryNames)
          result = previous
        } else {
          result = archive
        }
      }
    }
    return result
  }

  @MainActor
  static func cloudArchive() async throws -> JokeArchive? {
    #if targetEnvironment(simulator) || DAD_JOKES_LOCAL_PREVIEW
    return nil
    #else
    guard try await CKContainer(identifier: cloudIdentifier).accountStatus() == .available else { return nil }

    var folder = URL.applicationSupportDirectory.appending(path: "DadJokesCloudRecovery", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try folder.setResourceValues(values)

    // Core Data can read the original private CloudKit records with their shipped model.
    // It mirrors them to a separate store. This app never saves managed objects to it.
    let container = NSPersistentCloudKitContainer(name: "Main", managedObjectModel: try legacyModel())
    let description = NSPersistentStoreDescription(url: folder.appending(path: "CloudRecovery.sqlite"))
    description.shouldMigrateStoreAutomatically = false
    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudIdentifier)
    container.persistentStoreDescriptions = [description]

    let imports = AsyncStream<Bool>(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let token = NotificationCenter.default.addObserver(
        forName: NSPersistentCloudKitContainer.eventChangedNotification, object: container, queue: nil
      ) { notification in
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event, event.endDate != nil,
              event.type == .import || (event.type == .setup && !event.succeeded) else { return }
        continuation.yield(event.succeeded)
      }
      let expiry = Task {
        try await Task.sleep(for: .seconds(45))
        continuation.yield(false)
      }
      continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(token)
        expiry.cancel()
      }
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      container.loadPersistentStores { _, error in
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
      }
    }
    for await succeeded in imports {
      if succeeded {
        return try readArchive(from: container.persistentStoreCoordinator)
      }
      throw CocoaError(.fileReadUnknown)
    }
    return nil
    #endif
  }

  private static func legacyModel(at modelURL: URL? = nil) throws -> NSManagedObjectModel {
    guard let url = modelURL ?? Bundle.main.url(forResource: "DadJokesLegacy", withExtension: "mom"),
          let model = NSManagedObjectModel(contentsOf: url) else {
      throw CocoaError(.fileNoSuchFile)
    }
    for entity in model.entities { entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self) }
    return model
  }

  private static func readArchive(from coordinator: NSPersistentStoreCoordinator) throws -> JokeArchive {
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    return try context.performAndWait {
      let categories = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Category"))
      let request = NSFetchRequest<NSManagedObject>(entityName: "Joke")
      request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
      let items = try context.fetch(request)
      var archive = JokeArchive(jokes: [])
      archive.categoryNames = Set(categories.compactMap { $0.value(forKey: "name") as? String })
        .subtracting(["Favorites"])
      for item in items {
        guard let text = item.value(forKey: "jokeText") as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
        let id = "legacy-\(item.objectID.uriRepresentation().absoluteString)"
        let parts = Joke.split(text)
        let names = (item.value(forKey: "categories") as? Set<NSManagedObject> ?? [])
          .compactMap { $0.value(forKey: "name") as? String }
        let age = (item.value(forKey: "ageLevel") as? NSNumber)?.intValue
        let joke = Joke(id: id, setup: parts.setup, punchline: parts.punchline,
                        categories: names.filter { $0 != "Favorites" }.sorted(), isMature: age != 0,
                        dateAdded: item.value(forKey: "dateAdded") as? Date)
        archive.jokes.append(joke)
        if names.contains("Favorites") { archive.favorites.insert(id) }
      }
      return archive
    }
  }
}
