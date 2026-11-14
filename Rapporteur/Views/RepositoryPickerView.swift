import SwiftUI

/// Adds favourites from the user's repositories, or by a typed "owner/name".
struct RepositoryPickerView: View {
    @Environment(Store.self) private var store
    @State private var repositories: [Repository]?
    @State private var search = ""
    @State private var problem: String?

    var body: some View {
        List {
            if let typedName {
                Button("Add \(typedName)") { Task { await addTyped(typedName) } }
            }
            if let problem {
                Text(problem).foregroundStyle(.red)
            }
            ForEach(matches) { repository in
                Button {
                    store.addFavourite(repository)
                } label: {
                    HStack {
                        RepositoryRow(repository: repository)
                        Spacer()
                        if store.favourites.contains(repository) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Added")
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .overlay {
            if repositories == nil { ProgressView() }
        }
        .searchable(text: $search, prompt: "Search or type owner/name")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Add a repository")
        .task {
            do {
                repositories = try await store.repositories()
            } catch {
                repositories = []
                problem = "GitHub did not send your repositories."
            }
        }
    }

    private var trimmedSearch: String {
        search.trimmingCharacters(in: .whitespaces)
    }

    private var matches: [Repository] {
        let all = repositories ?? []
        return trimmedSearch.isEmpty ? all : all.filter { $0.fullName.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    /// The search text, when it is an "owner/name" that is not in the user's repositories.
    private var typedName: String? {
        let parts = trimmedSearch.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }),
              !matches.contains(where: { $0.fullName.caseInsensitiveCompare(trimmedSearch) == .orderedSame }) else { return nil }
        return trimmedSearch
    }

    private func addTyped(_ fullName: String) async {
        do {
            try await store.addFavourite(fullName: fullName)
            search = ""
            problem = nil
        } catch GitHubError.refused(let message) {
            problem = "\(fullName): \(message)"
        } catch {
            problem = "GitHub did not answer."
        }
    }
}
