import Network
import SwiftUI

/// The entry screen: type an issue, send it, and the screen clears for the next one.
struct ComposeView: View {
    private enum Field { case title, description }

    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var title = ""
    @State private var description = ""
    @State private var selectedLabels: Set<String> = []
    @State private var sentCount = 0
    @State private var isClearing = false
    @FocusState private var focus: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Group {
                TextField("Title", text: $title)
                    .font(.title3.bold())
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus = .description }
                TextField("Add a description", text: $description, axis: .vertical)
                    .focused($focus, equals: .description)
            }
            .offset(y: isClearing ? -60 : 0)
            .opacity(isClearing ? 0 : 1)
            Spacer(minLength: 0)
            HStack {
                if let repository = store.currentRepository, repository.canPush {
                    LabelChips(labels: store.labels[repository.fullName] ?? [], selection: $selectedLabels)
                }
                Spacer(minLength: 0)
                Button("Send", systemImage: "arrow.up", action: send)
                    .labelStyle(.iconOnly)
                    .fontWeight(.bold)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .disabled(!canSend)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .simultaneousGesture(repositorySwipe)
        .sensoryFeedback(.success, trigger: sentCount)
        .onAppear { focus = .title }
        .onChange(of: store.currentRepository) { selectedLabels = [] }
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await store.sendOutbox() } }
        }
        .task {
            for await path in NWPathMonitor() where path.status == .satisfied {
                await store.sendOutbox()
            }
        }
    }

    private var header: some View {
        HStack {
            Menu {
                ForEach(store.favourites) { repository in
                    Button(repository.fullName) { store.select(repository) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(store.currentRepository?.fullName ?? "No repository")
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                }
            }
            if let issue = store.lastCreatedIssue {
                Link("#\(issue.number) created", destination: issue.htmlUrl)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !store.outbox.isEmpty {
                Text(store.outbox.count, format: .number)
                    .font(.footnote.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: .capsule)
                    .accessibilityLabel("\(store.outbox.count) in the outbox")
            }
        }
    }

    private var repositorySwipe: some Gesture {
        DragGesture(minimumDistance: 40).onEnded { drag in
            let distance = drag.translation
            guard abs(distance.width) > abs(distance.height) * 2 else { return }
            store.selectNeighbour(distance.width < 0 ? 1 : -1)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        store.currentRepository != nil && !trimmedTitle.isEmpty
    }

    private func send() {
        guard canSend, let repository = store.currentRepository else { return }
        let issue = PendingIssue(repositoryFullName: repository.fullName,
                                 title: trimmedTitle,
                                 body: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                 labels: selectedLabels.sorted())
        sentCount += 1
        focus = .title
        withAnimation(.easeIn(duration: 0.2)) {
            isClearing = true
        } completion: {
            title = ""
            description = ""
            selectedLabels = []
            isClearing = false
        }
        Task { await store.send(issue) }
    }
}
