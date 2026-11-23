import ImagePlayground
import SwiftUI

struct CategoryDetailsView: View {
  var library: JokeLibrary
  var originalName: String?
  var additionalNames: [String]
  var additionalIcons: [String: Data]
  var saveCategory: (String, Data?) -> Void
  var deleteCategory: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.supportsImagePlayground) private var supportsImagePlayground
  @State private var name = ""
  @State private var choice: IconChoice = .defaultIcon
  @State private var showsImagePlayground = false
  @State private var artworkError = false
  @State private var confirmsDeletion = false

  init(library: JokeLibrary, originalName: String? = nil, additionalNames: [String] = [],
       additionalIcons: [String: Data] = [:], deleteCategory: (() -> Void)? = nil,
       saveCategory: @escaping (String, Data?) -> Void) {
    self.library = library
    self.originalName = originalName
    self.additionalNames = additionalNames
    self.additionalIcons = additionalIcons
    self.deleteCategory = deleteCategory
    self.saveCategory = saveCategory
    _name = State(initialValue: originalName ?? "")
    if let originalName, let icon = library.archive.categoryIcons?[originalName] {
      _choice = State(initialValue: .generated(icon))
    }
  }

  private var defaultAsset: String {
    guard let originalName else { return "CategoryCustom" }
    return CategoryArtwork.assetName(for: library.originalCategoryNames[originalName] ?? originalName)
  }

  private var usedAssets: Set<String> {
    let icons = library.archive.categoryIcons ?? [:]
    let others = library.categories.filter { $0.name != originalName }
    let originalNames = library.originalCategoryNames
    let builtIn = others.filter { icons[$0.name] == nil }.map {
      CategoryArtwork.assetName(for: originalNames[$0.name] ?? $0.name)
    }
    let artwork = Set(others.compactMap { icons[$0.name] }).union(additionalIcons.values)
    return Set(builtIn).union(CategoryIconPreset.assets(matching: artwork))
  }

  private var categoryName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  private var nameIsTaken: Bool {
    categoryName.caseInsensitiveCompare("Favorites") == .orderedSame ||
      (library.reservedCategoryNames(editing: originalName) + additionalNames).contains {
        $0.caseInsensitiveCompare(categoryName) == .orderedSame
      }
  }

  var body: some View {
    Form {
      Section {
        TextField("Category name", text: $name)
      } footer: {
        if nameIsTaken { Text("Choose a different category name.") }
      }

      Section {
        if case .generated(let data) = choice {
          Label {
            Text("Current icon")
          } icon: {
            CategoryArtwork(name: categoryName, size: 40, draftIcon: data)
          }
        }
        Button("Generate with Image Playground", systemImage: "sparkles") {
          showsImagePlayground = true
        }
        .disabled(!supportsImagePlayground || categoryName.isEmpty || nameIsTaken)
      } footer: {
        if !supportsImagePlayground {
          Text("Image Playground is unavailable on this device.")
        } else if categoryName.isEmpty {
          Text("Enter a category name to generate an icon.")
        }
      }

      Section {
        let used = usedAssets
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 8)], spacing: 8) {
          iconButton("Default category icon", assetName: defaultAsset, option: .defaultIcon,
                     isUsed: used.contains(defaultAsset))
          ForEach(CategoryIconPreset.defaults + CategoryIconPreset.all) { preset in
            if preset.assetName != defaultAsset {
              iconButton(preset.name, assetName: preset.assetName, option: .preset(preset),
                         isUsed: used.contains(preset.assetName))
            }
          }
        }
        .padding(.vertical, 4)
      } header: {
        VStack(alignment: .leading, spacing: 8) {
          Label {
            Text("Used by another category")
          } icon: {
            usedMarker
          }
          Text("Choose an icon")
        }
        .textCase(nil)
      }

      if deleteCategory != nil {
        Section {
          Button("Delete Category", systemImage: "trash", role: .destructive) {
            confirmsDeletion = true
          }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle(originalName == nil ? "New Category" : "Edit Category")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(originalName == nil ? "Add" : "Save", action: save)
          .disabled(categoryName.isEmpty || nameIsTaken)
          .keyboardShortcut(.defaultAction)
      }
    }
    .alert("Delete this category?", isPresented: $confirmsDeletion) {
      Button("Delete Category", role: .destructive) {
        deleteCategory?()
        dismiss()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes the category from its jokes. The jokes stay in your library.")
    }
    .imagePlaygroundSheet(isPresented: $showsImagePlayground, concepts: [
      .text(String(localized: "A simple icon representing \(categoryName).")),
      .text(String(localized: "One centered, flat pictogram in a playful cartoon style with a dark rounded outline and a soft pastel square background. Use bold, simple shapes and a limited palette. No text, shadows, gradients, or extra objects."))
    ], onCompletion: useGeneratedIcon)
    .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])
    .alert("Couldn’t Use the Icon", isPresented: $artworkError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Choose another icon or try generating it again.")
    }
  }

  private var usedMarker: some View {
    Image(systemName: "exclamationmark.triangle.fill")
      .symbolRenderingMode(.palette)
      .foregroundStyle(.black, .yellow)
      .accessibilityHidden(true)
  }

  private func iconButton(_ name: LocalizedStringResource, assetName: String, option: IconChoice,
                          isUsed: Bool) -> some View {
    let isSelected = choice == option
    return Button {
      choice = option
    } label: {
      Image(assetName)
        .resizable()
        .renderingMode(.original)
        .scaledToFit()
        .frame(width: 40, height: 40)
        .frame(width: 50, height: 50)
        .background {
          RoundedRectangle(cornerRadius: 13)
            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
          if isUsed { usedMarker.font(.caption) }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(name))
    .accessibilityHint(isUsed ? Text("Used by another category") : Text(""))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func useGeneratedIcon(_ url: URL) {
    do { choice = .generated(try JokeArtwork.prepare(from: url, maximumPixelSize: 128)) }
    catch { artworkError = true }
  }

  private func save() {
    guard !categoryName.isEmpty, !nameIsTaken else { return }
    do {
      let icon: Data?
      switch choice {
      case .defaultIcon: icon = nil
      case .preset(let preset): icon = try preset.iconData()
      case .generated(let data): icon = data
      }
      saveCategory(categoryName, icon)
      dismiss()
    } catch {
      artworkError = true
    }
  }

  private enum IconChoice: Equatable {
    case defaultIcon
    case preset(CategoryIconPreset)
    case generated(Data)
  }
}
