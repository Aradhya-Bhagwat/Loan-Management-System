import Foundation

struct BorrowerDocumentRecord: Identifiable, Codable {
    let id: UUID
    let borrowerId: UUID?
    let panDocUrl: String?
    let aadhaarDocUrl: String?
    let incomeProofUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case borrowerId = "borrower_id"
        case panDocUrl = "pan_doc_url"
        case aadhaarDocUrl = "aadhaar_doc_url"
        case incomeProofUrl = "income_proof_url"
    }

    var documentSlots: [BorrowerDocumentSlot] {
        [
            BorrowerDocumentSlot(
                displayName: "PAN Card",
                iconName: "creditcard.fill",
                storagePath: panDocUrl
            ),
            BorrowerDocumentSlot(
                displayName: "Aadhaar Card",
                iconName: "person.text.rectangle.fill",
                storagePath: aadhaarDocUrl
            ),
            BorrowerDocumentSlot(
                displayName: "Income Proof",
                iconName: "banknote.fill",
                storagePath: incomeProofUrl
            )
        ]
    }
}

struct BorrowerDocumentSlot: Identifiable {
    let displayName: String
    let iconName: String
    let storagePath: String?

    var id: String { displayName }

    var isUploaded: Bool {
        guard let path = storagePath, !path.isEmpty else { return false }
        return true
    }
}