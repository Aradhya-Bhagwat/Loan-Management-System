import SwiftUI
import Supabase

// MARK: - Comment Model

struct LoanComment: Identifiable, Codable {
    let id: UUID
    let loanId: UUID
    let officerId: UUID
    let text: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case loanId = "loan_id"
        case officerId = "officer_id"
        case text
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        loanId: UUID,
        officerId: UUID,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.loanId = loanId
        self.officerId = officerId
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - DatabaseService extension for Officer Notes (loan_comments table)

extension DatabaseService {
    /// Fetch all comments for a loan, ordered oldest → newest.
    func fetchComments(loanId: UUID) async throws -> [LoanComment] {
        return try await SupabaseManager.shared.adminClient
            .from("loan_comments")
            .select()
            .eq("loan_id", value: loanId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Insert a new comment. Returns the saved record.
    func addComment(loanId: UUID, officerId: UUID, text: String) async throws -> LoanComment {
        let payload: [String: AnyJSON] = [
            "loan_id": .string(loanId.uuidString),
            "officer_id": .string(officerId.uuidString),
            "text": .string(text)
        ]
        return try await SupabaseManager.shared.client
            .from("loan_comments")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update the text of an existing comment.
    func updateComment(commentId: UUID, text: String) async throws {
        let updateData: [String: AnyJSON] = [
            "text": .string(text),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        try await SupabaseManager.shared.client
            .from("loan_comments")
            .update(updateData)
            .eq("id", value: commentId)
            .execute()
    }

    /// Delete a comment.
    func deleteComment(commentId: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("loan_comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
    }
}

// MARK: - Comments Card (embed inside LoanDetailScreen)
//
// Usage — add this inside LoanDetailScreen.body's VStack, after NewDocumentsCard:
//
//   LoanCommentsCard(
//       loanId: loan.application.id,
//       officerId: controller.officerId
//   )

struct LoanCommentsCard: View {
    let loanId: UUID
    let officerId: UUID
    @ObservedObject var controller: LoanOfficerDashboardViewModel

    @State private var showComposer = false

    private var comments: [LoanComment]  { controller.commentsByLoan[loanId] ?? [] }
    private var isLoading: Bool           { controller.commentsLoadingFor.contains(loanId) }
    private var errorMessage: String?     { controller.commentsErrorFor[loanId] }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Officer Notes")
                    .font(.title3.bold())
                    .foregroundStyle(OfficerTheme.textSecondary)
                
                Spacer()

                Button {
                    showComposer = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add Note")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(OfficerTheme.accentGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(OfficerTheme.accentGreen.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

            WhiteCard {
                VStack(alignment: .leading, spacing: 16) {

                // ── Body ─────────────────────────────────────────────────
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 12)

                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(OfficerTheme.iconAmber)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(OfficerTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await controller.loadComments(loanId: loanId) } }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(OfficerTheme.accentBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                } else if comments.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 32))
                            .foregroundStyle(OfficerTheme.textSecondary.opacity(0.3))
                        Text("No notes yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(OfficerTheme.textSecondary)
                        Text("Add a note to share your thoughts with the manager.")
                            .font(.system(size: 13))
                            .foregroundStyle(OfficerTheme.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            CommentRow(
                                comment: comment,
                                officerId: officerId,
                                onEdit: { updated in
                                    Task { await controller.editComment(loanId: loanId, commentId: comment.id, newText: updated) }
                                },
                                onDelete: {
                                    Task { await controller.deleteComment(loanId: loanId, commentId: comment.id) }
                                }
                            )

                            if comment.id != comments.last?.id {
                                Divider()
                                    .overlay(OfficerTheme.softLine)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }
    .sheet(isPresented: $showComposer) {
            CommentComposerSheet(
                mode: .new,
                onSave: { text in
                    Task { await controller.addComment(loanId: loanId, text: text) }
                }
            )
        }
        // Always re-fetch from DB so deletions/edits from other devices are visible
        .task {
            await controller.loadComments(loanId: loanId)
        }
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: LoanComment
    let officerId: UUID
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    // AC3: only the authoring officer can edit/delete their own comments
    private var isOwner: Bool { comment.officerId == officerId }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .top) {
                // Avatar
                Circle()
                    .fill(OfficerTheme.accentBlue.opacity(0.13))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(OfficerTheme.accentBlue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("You")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(OfficerTheme.textPrimary)

                        Text("·")
                            .foregroundStyle(OfficerTheme.textSecondary)

                        Text(formatTimestamp(comment.createdAt))
                            .font(.system(size: 12))
                            .foregroundStyle(OfficerTheme.textSecondary)

                        if comment.updatedAt > comment.createdAt.addingTimeInterval(2) {
                            Text("(edited)")
                                .font(.system(size: 11))
                                .foregroundStyle(OfficerTheme.textSecondary.opacity(0.6))
                        }
                    }

                    Text(comment.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OfficerTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                Spacer()

                // Edit/Delete menu — only for the authoring officer (AC3)
                if isOwner {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OfficerTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(OfficerTheme.filterBackground)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showEditSheet) {
            CommentComposerSheet(
                mode: .edit(existing: comment.text),
                onSave: onEdit
            )
        }
        .alert("Delete Note", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This note will be permanently removed.")
        }
    }
}

// MARK: - Comment Composer Sheet

private struct CommentComposerSheet: View {
    enum Mode {
        case new
        case edit(existing: String)

        var title: String {
            switch self {
            case .new:  return "Add Note"
            case .edit: return "Edit Note"
            }
        }

        var cta: String {
            switch self {
            case .new:  return "Save Note"
            case .edit: return "Update Note"
            }
        }

        var initialText: String {
            switch self {
            case .new:               return ""
            case .edit(let text):   return text
            }
        }
    }

    let mode: Mode
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var canSave: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    init(mode: Mode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        _text = State(initialValue: mode.initialText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OfficerTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── Hint ─────────────────────────────────────────
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(OfficerTheme.iconAmber)

                            Text("Notes are visible to the manager when this loan is escalated for sign-off.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(OfficerTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(OfficerTheme.iconAmber.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // ── Text editor ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textSecondary)

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(OfficerTheme.card)
                                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)

                                if text.isEmpty {
                                    Text("Write your assessment, concerns, or observations about this application…")
                                        .font(.system(size: 15))
                                        .foregroundStyle(OfficerTheme.textSecondary.opacity(0.55))
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                }

                                TextEditor(text: $text)
                                    .font(.system(size: 15))
                                    .foregroundStyle(OfficerTheme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .padding(12)
                                    .focused($isFocused)
                            }
                            .frame(minHeight: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        isFocused ? OfficerTheme.accentBlue.opacity(0.5) : OfficerTheme.softLine,
                                        lineWidth: isFocused ? 1.5 : 1
                                    )
                            )

                            HStack {
                                Spacer()
                                Text("\(text.count) characters")
                                    .font(.system(size: 12))
                                    .foregroundStyle(OfficerTheme.textSecondary)
                            }
                        }

                        // ── Quick prompts ────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("QUICK PROMPTS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textSecondary)

                            let prompts = [
                                "All documents verified. Recommending for approval.",
                                "High debt-to-income ratio. Please review before approving.",
                                "Credit score is borderline. Consider conditional approval.",
                                "Employment details need further verification.",
                                "Strong profile. No concerns from my end.",
                            ]

                            ForEach(prompts, id: \.self) { prompt in
                                Button {
                                    text = prompt
                                } label: {
                                    HStack {
                                        Text(prompt)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(OfficerTheme.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(OfficerTheme.accentBlue.opacity(0.6))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(OfficerTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // ── Save button ──────────────────────────────────
                        Button {
                            let trimmed = text.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            onSave(trimmed)
                            dismiss()
                        } label: {
                            Text(mode.cta)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    canSave
                                        ? OfficerTheme.accentGreen
                                        : OfficerTheme.accentGreen.opacity(0.35)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
// MARK: - Timestamp Formatter

private func formatTimestamp(_ date: Date) -> String {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    
    if calendar.isDateInToday(date) {
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    } else {
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
