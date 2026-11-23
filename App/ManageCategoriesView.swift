import SwiftUI

struct ManageCategoriesView: View {
  var library: JokeLibrary
  @State private var confirmsReset = false

  var body: some View {
    Form {
      Section {
        NavigationLink {
          CategoryDetailsView(library: library) { name, icon in
            library.saveCategory(name: name, icon: icon)
          }
        } label: {
          Label("New Category", systemImage: "plus")
        }
      }

      Section("Categories") {
        ForEach(library.categories) { category in
          NavigationLink {
            CategoryDetailsView(library: library, originalName: category.name, deleteCategory: {
              library.deleteCategory(named: category.name)
            }) { name, icon in
              library.saveCategory(name: name, icon: icon, replacing: category.name)
            }
          } label: {
            Label {
              Text(category.name)
            } icon: {
              CategoryArtwork(name: category.name)
            }
          }
        }
      }

      Section {
        Button("Reset to Default Categories", systemImage: "arrow.clockwise", role: .destructive) {
          confirmsReset = true
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Manage Categories")
    .alert("Reset to default categories?", isPresented: $confirmsReset) {
      Button("Reset Categories", role: .destructive) { library.resetCategories() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This restores the original category names and icons and removes custom categories from your jokes. Your jokes and favorites stay in the library.")
    }
  }
}
