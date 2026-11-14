import SwiftUI

struct SettingsView: View {
    /// Puts an issue from the outbox back on the entry screen.
    let edit: (PendingIssue) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Repositories") {
                    ForEach(store.favourites) { repository in
                        RepositoryRow(repository: repository)
                    }
                    .onDelete { store.removeFavourites(at: $0) }
                    .onMove { store.moveFavourites(from: $0, to: $1) }
                    NavigationLink("Add a repository") { RepositoryPickerView() }
                }

                if !store.outbox.isEmpty {
                    Section {
                        ForEach(store.outbox) { issue in
                            OutboxRow(issue: issue)
                                .swipeActions {
                                    Button("Delete", role: .destructive) { store.removeFromOutbox(issue) }
                                    Button("Edit") { edit(issue) }
                                    if issue.refusal != nil {
                                        Button("Retry") { Task { await store.retry(issue) } }
                                            .tint(.accentColor)
                                    }
                                }
                        }
                    } header: {
                        Text("Outbox")
                    } footer: {
                        Text("Issues wait here until GitHub accepts them. Swipe an issue to retry, edit or delete it.")
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        store.signOut()
                        dismiss()
                    }
                    Link("Privacy policy", destination: URL(string: "https://github.com/knorthfield/rapporteur/blob/main/PRIVACY.md")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RepositoryRow: View {
    let repository: Repository

    var body: some View {
        HStack {
            Text(repository.fullName)
            if repository.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Private")
            }
        }
    }
}

private struct OutboxRow: View {
    let issue: PendingIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(issue.title)
            Text(issue.repositoryFullName)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let refusal = issue.refusal {
                Text(refusal)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
