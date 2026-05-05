import Foundation

enum ChatMessageType: String, Codable {
    case text
    case documentRequest = "document_request"
}

enum DocumentRequestType: String, Codable, CaseIterable, Identifiable {
    case panCard = "pan_card"
    case aadhaarCard = "aadhaar_card"
    case incomeProof = "income_proof"
    case addressProof = "address_proof"
    case collateralPaper = "collateral_paper"
    case bankStatement = "bank_statement"
    case gstRegistration = "gst_registration"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .panCard: return "PAN Card"
        case .aadhaarCard: return "Aadhaar Card"
        case .incomeProof: return "Income Proof"
        case .addressProof: return "Address Proof"
        case .collateralPaper: return "Collateral Paper"
        case .bankStatement: return "Bank Statement"
        case .gstRegistration: return "GST Registration"
        case .other: return "Document"
        }
    }

    var icon: String {
        switch self {
        case .panCard: return "doc.text.fill"
        case .aadhaarCard: return "person.text.rectangle.fill"
        case .incomeProof: return "indianrupeesign.circle.fill"
        case .addressProof: return "house.fill"
        case .collateralPaper: return "doc.fill"
        case .bankStatement: return "building.columns.fill"
        case .gstRegistration: return "building.2.fill"
        case .other: return "doc.fill"
        }
    }

    var dbDocumentType: String {
        switch self {
        case .panCard: return "PAN Card"
        case .aadhaarCard: return "Aadhaar Card"
        case .incomeProof: return "Income"
        case .addressProof: return "Address"
        case .collateralPaper: return "Collateral Paper"
        case .bankStatement: return "Bank Statement (12 months)"
        case .gstRegistration: return "GST Registration"
        case .other: return "Document"
        }
    }

    var dbAliases: [String] {
        switch self {
        case .panCard: return ["PAN", "PAN Card"]
        case .aadhaarCard: return ["Aadhaar", "Aadhaar Card"]
        case .incomeProof: return ["Income", "Income Proof"]
        case .addressProof: return ["Address", "Address Proof"]
        case .collateralPaper: return ["Collateral", "Collateral Paper"]
        case .bankStatement: return ["Bank Statement", "Bank Statement (12 months)"]
        case .gstRegistration: return ["GST", "GST Registration"]
        case .other: return ["Document", "Other"]
        }
    }

    static func fromDBType(_ dbType: String) -> DocumentRequestType? {
        for docType in DocumentRequestType.allCases {
            if docType.dbAliases.contains(where: { dbType.caseInsensitiveCompare($0) == .orderedSame }) {
                return docType
            }
        }
        return nil
    }
}

struct DBChatMessage: Codable, Identifiable {
    let id: UUID
    let applicationId: UUID
    let senderId: UUID
    let content: String
    let messageType: ChatMessageType
    let documentType: DocumentRequestType?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case applicationId = "application_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case documentType = "document_type"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        applicationId = try container.decode(UUID.self, forKey: .applicationId)
        senderId = try container.decode(UUID.self, forKey: .senderId)
        content = try container.decode(String.self, forKey: .content)
        messageType = try container.decode(ChatMessageType.self, forKey: .messageType)
        createdAt = try container.decode(String.self, forKey: .createdAt)

        if let rawDocType = try container.decodeIfPresent(String.self, forKey: .documentType) {
            documentType = DocumentRequestType(rawValue: rawDocType) ?? .other
            if DocumentRequestType(rawValue: rawDocType) == nil {
                print("⚠️ Unknown document_type '\(rawDocType)' — mapped to .other")
            }
        } else {
            documentType = nil
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let applicationId: UUID
    let senderId: UUID
    let senderName: String
    let content: String
    let messageType: ChatMessageType
    let documentType: DocumentRequestType?
    let createdAt: Date
    let isFromOfficer: Bool
    var verificationStatus: String? 

    init(from db: DBChatMessage, currentUserId: UUID, officerId: UUID) {
        self.id = db.id
        self.applicationId = db.applicationId
        self.senderId = db.senderId
        self.senderName = ""
        self.content = db.content
        self.messageType = db.messageType
        self.documentType = db.documentType
        self.isFromOfficer = db.senderId == officerId
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.createdAt = formatter.date(from: db.createdAt) ?? Date()
    }

    init(id: UUID = UUID(), applicationId: UUID, senderId: UUID, senderName: String, content: String, messageType: ChatMessageType, documentType: DocumentRequestType? = nil, createdAt: Date = Date(), isFromOfficer: Bool) {
        self.id = id
        self.applicationId = applicationId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.messageType = messageType
        self.documentType = documentType
        self.createdAt = createdAt
        self.isFromOfficer = isFromOfficer
    }
}