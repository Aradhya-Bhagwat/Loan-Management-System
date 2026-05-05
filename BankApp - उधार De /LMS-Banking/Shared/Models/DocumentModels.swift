import Foundation

struct ApplicationDocument: Identifiable, Codable {
    let id: UUID
    let applicationId: UUID
    let name: String
    let fileUrl: String
    var status: String
    var remarks: String?
    let uploadedAt: Date

    /// The real database row ID from `loan_application_documents`.
    /// nil for legacy docs that don't have a row yet.
    var dbDocumentId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case name
        case fileUrl = "file_url"
        case status
        case remarks
        case uploadedAt = "uploaded_at"
        case dbDocumentId = "db_document_id"
    }
}

struct LoanApplicationDocument: Identifiable, Codable {
    let id: UUID
    let applicationId: UUID
    let borrowerId: UUID
    let documentType: String
    let fileUrl: String
    let createdAt: String
    let status: String
    let remarks: String?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case borrowerId = "borrower_id"
        case documentType = "document_type"
        case fileUrl = "file_url"
        case createdAt = "created_at"
        case status
        case remarks
    }
}
