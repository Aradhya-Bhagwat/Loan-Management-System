import SwiftUI
import UniformTypeIdentifiers

private struct BulkInviteTemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

struct BulkInviteView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var controller: AdminDashboardViewModel

    @State private var isExportingTemplate = false
    @State private var isImportingCSV = false

    @State private var parsedRows: [ParsedInviteRow] = []
    @State private var parseErrors: [String] = []
    @State private var importedFileName: String?

    @State private var isInviting = false
    @State private var invitedCount = 0
    @State private var failedCount = 0
    @State private var inviteErrors: [String] = []
    
    private var validRows: [ParsedInviteRow] {
        parsedRows.filter { $0.isValid }
    }
    
    private var hasInvalidRows: Bool {
        parsedRows.contains { !$0.isValid }
    }
    
    private var canSendInvites: Bool {
        !parsedRows.isEmpty && !hasInvalidRows && !isInviting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("1. Template") {
                    Text("Download the CSV template, fill user details in Excel/Sheets, then import it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        isExportingTemplate = true
                    } label: {
                        Label("Download Template", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.appGreen)
                }

                Section("2. Import") {
                    Button {
                        isImportingCSV = true
                    } label: {
                        Label("Choose CSV File", systemImage: "square.and.arrow.down.on.square")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)

                    if let importedFileName {
                        Label(importedFileName, systemImage: "doc.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !parseErrors.isEmpty {
                        ForEach(parseErrors, id: \.self) { err in
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(Color.appRed)
                        }
                    }
                }

                Section("3. Preview") {
                    if parsedRows.isEmpty {
                        Text("Import a filled CSV to preview users.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Valid")
                            Spacer()
                            Text("\(parsedRows.filter { $0.isValid }.count)")
                        }
                        .font(.subheadline)

                        HStack {
                            Text("Invalid")
                            Spacer()
                            Text("\(parsedRows.filter { !$0.isValid }.count)")
                        }
                        .font(.subheadline)

                        ForEach(parsedRows.prefix(10)) { row in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Image(systemName: row.isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                        .foregroundStyle(row.isValid ? Color.appGreen : Color.appRed)
                                    Text(row.name.isEmpty ? "—" : row.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                }
                                Text("\(row.email) • \(row.role.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if !row.errors.isEmpty {
                                    Text(row.errors.joined(separator: " • "))
                                        .font(.caption2)
                                        .foregroundStyle(Color.appRed)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if parsedRows.count > 10 {
                            Text("…and \(parsedRows.count - 10) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("4. Send Invites") {
                    Button {
                        inviteAll(validRows: validRows)
                    } label: {
                        HStack {
                            if isInviting {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            }
                            Text(isInviting ? "Sending Invites..." : "Send \(validRows.count) Invites")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.appGreen)
                    .disabled(!canSendInvites)

                    if hasInvalidRows {
                        Text("Fix all invalid rows before sending invites.")
                            .font(.footnote)
                            .foregroundStyle(Color.appRed)
                    }

                    if isInviting || invitedCount > 0 || failedCount > 0 {
                        Text("Success: \(invitedCount) • Failed: \(failedCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if !inviteErrors.isEmpty {
                        ForEach(inviteErrors.prefix(6), id: \.self) { err in
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(Color.appRed)
                        }
                        if inviteErrors.count > 6 {
                            Text("…and \(inviteErrors.count - 6) more failures")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Bulk Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingTemplate,
            document: BulkInviteTemplateDocument(text: Self.templateCSV),
            contentType: .commaSeparatedText,
            defaultFilename: "udharde_bulk_users_template"
        ) { _ in }
        .fileImporter(
            isPresented: $isImportingCSV,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importedFileName = url.lastPathComponent
                importCSV(from: url)
            case .failure(let error):
                parseErrors = ["Import failed: \(error.localizedDescription)"]
            }
        }
        .onAppear { controller.fetchUsers() }
    }

    private func inviteAll(validRows: [ParsedInviteRow]) {
        isInviting = true
        invitedCount = 0
        failedCount = 0
        inviteErrors = []

        Task {
            for row in validRows {
                do {
                    try await DatabaseService.shared.inviteUser(
                        name: row.name,
                        email: row.email,
                        phone: row.phone,
                        role: row.role,
                        branch: row.branch
                    )
                    await MainActor.run { invitedCount += 1 }
                } catch {
                    await MainActor.run {
                        failedCount += 1
                        inviteErrors.append("\(row.email): \(error.localizedDescription)")
                    }
                }
            }

            await DatabaseService.shared.fetchUsers()
            await DatabaseService.shared.fetchAuditTrail()

            await MainActor.run { isInviting = false }
        }
    }

    private func importCSV(from url: URL) {
        parseErrors = []
        inviteErrors = []
        invitedCount = 0
        failedCount = 0

        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                parseErrors = ["Invalid file encoding. Please export as UTF-8 CSV."]
                return
            }
            let result = Self.parseCSV(text: text)
            parsedRows = result.rows
            parseErrors = result.errors
        } catch {
            parseErrors = ["Could not read file: \(error.localizedDescription)"]
        }
    }

    // MARK: - CSV Parsing

    private struct ParseResult {
        let rows: [ParsedInviteRow]
        let errors: [String]
    }

    private struct ParsedInviteRow: Identifiable {
        let id = UUID()
        let lineNumber: Int
        let name: String
        let email: String
        let phone: String
        let role: UserRole
        let branch: String?
        let errors: [String]

        var isValid: Bool { errors.isEmpty }
    }

    private static func parseCSV(text: String) -> ParseResult {
        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard !rawLines.isEmpty else {
            return .init(rows: [], errors: ["File is empty."])
        }

        let header = parseCSVLine(rawLines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let nameIdx = header.firstIndex(of: "name")
        let emailIdx = header.firstIndex(of: "email")
        let phoneIdx = header.firstIndex(of: "phone")
        let roleIdx = header.firstIndex(of: "role")
        let branchIdx = header.firstIndex(of: "branch")

        if nameIdx == nil || emailIdx == nil || phoneIdx == nil || roleIdx == nil {
            return .init(
                rows: [],
                errors: ["Invalid header. Expected columns: name,email,phone,role,branch"]
            )
        }

        var rows: [ParsedInviteRow] = []
        var errors: [String] = []

        for (i, line) in rawLines.dropFirst().enumerated() {
            let lineNumber = i + 2
            let cols = parseCSVLine(line)
            func col(_ idx: Int?) -> String {
                guard let idx, idx < cols.count else { return "" }
                return cols[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let name = col(nameIdx)
            let email = col(emailIdx).lowercased()
            let phone = col(phoneIdx).filter(\.isNumber)
            let roleString = col(roleIdx)
            let branch = col(branchIdx)

            var rowErrors: [String] = []
            if name.isEmpty { rowErrors.append("Missing name") }
            if !email.contains("@") { rowErrors.append("Invalid email") }

            let role = parseRole(roleString) ?? .borrower
            if parseRole(roleString) == nil { rowErrors.append("Invalid role") }

            if role == .borrower {
                rowErrors.append("Borrowers cannot be added via bulk import.")
            }

            let parsed = ParsedInviteRow(
                lineNumber: lineNumber,
                name: name,
                email: email,
                phone: phone,
                role: role,
                branch: branch.isEmpty ? nil : branch,
                errors: rowErrors
            )
            rows.append(parsed)
        }

        if rows.isEmpty {
            errors.append("No rows found.")
        }

        return .init(rows: rows, errors: errors)
    }

    private static func parseRole(_ input: String) -> UserRole? {
        let v = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if v.isEmpty { return nil }

        if v == "officer" || v == "loan officer" { return .officer }
        if v == "manager" { return .manager }
        if v == "admin" { return .admin }
        if v == "borrower" { return .borrower }

        return UserRole.allCases.first { $0.rawValue.lowercased() == v }
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var isInQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if isInQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                } else {
                    isInQuotes.toggle()
                    i = next
                    continue
                }
            }

            if ch == ",", !isInQuotes {
                result.append(current)
                current = ""
                i = line.index(after: i)
                continue
            }

            current.append(ch)
            i = line.index(after: i)
        }
        result.append(current)
        return result
    }

    private static let templateCSV = """
    name,email,phone,role,branch
    Jane Doe,jane.doe@bank.com,9876543210,Manager,North: Delhi
    John Smith,john.smith@bank.com,9876500000,Loan Officer,South: Bengaluru
    """
}
