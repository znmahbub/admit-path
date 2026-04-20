import SwiftUI

struct CommunityPostDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showReplyComposer = false

    let post: PeerPost

    var body: some View {
        let author = appState.author(for: post)
        let replies = appState.replies(for: post.id)

        AppCanvas {
            HeroCard(
                eyebrow: "Community thread",
                title: post.title,
                subtitle: "\(post.country) • \(post.degreeLevel.rawValue) • \(post.kind.rawValue)"
            ) {
                if let author {
                    StatusBadge(title: author.verificationStatus.rawValue, color: author.verificationStatus.tint)
                }
            }

            if let author {
                SurfaceCard {
                    SectionTitle("Author")
                    Text(author.displayName)
                        .font(.headline)
                    Text(author.bio)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                    DetailRow(label: "Current institution", value: "\(author.currentUniversity) • \(author.currentProgram)")
                }
            }

            SurfaceCard {
                SectionTitle("Post")
                Text(post.body)
                    .font(.subheadline)
                HStack(spacing: 8) {
                    ForEach(post.tags, id: \.self) { tag in
                        SummaryPill(title: tag, systemImage: "number", tint: AppTheme.primary)
                    }
                }
            }

            if replies.isNotEmpty {
                SurfaceCard {
                    SectionTitle("Replies")
                    ForEach(replies) { reply in
                        VStack(alignment: .leading, spacing: 6) {
                            if let replyAuthor = appState.author(id: reply.authorID) {
                                HStack {
                                    Text(replyAuthor.displayName)
                                        .font(.headline)
                                    Spacer()
                                    StatusBadge(title: replyAuthor.verificationStatus.rawValue, color: replyAuthor.verificationStatus.tint)
                                }
                            }
                            Text(reply.body)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                        }
                    }
                }
            }
        }
        .navigationTitle("Thread")
        .appInlineNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(appState.bookmarkedPosts.contains(where: { $0.id == post.id }) ? "Bookmarked" : "Bookmark") {
                    appState.toggleBookmarkedPost(post.id)
                }
                .buttonStyle(.bordered)

                Button("Report") {
                    appState.reportPost(post.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.warning)

                Button("Reply") {
                    showReplyComposer = true
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showReplyComposer) {
            ReplyComposerSheet(postID: post.id)
                .environmentObject(appState)
        }
    }
}

private struct ReplyComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let postID: String

    @State private var replyBody = ""

    var bodyView: some View {
        NavigationStack {
            Form {
                Section("Reply") {
                    TextField("Add a specific, practical reply", text: $replyBody, axis: .vertical)
                        .lineLimit(6, reservesSpace: true)
                }
            }
            .navigationTitle("Reply")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        appState.submitReply(to: postID, body: replyBody)
                        dismiss()
                    }
                    .disabled(replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    var body: some View {
        bodyView
    }
}
