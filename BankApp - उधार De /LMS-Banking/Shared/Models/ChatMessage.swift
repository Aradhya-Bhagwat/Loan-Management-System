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
    case itrReturns = "itr_returns"
    case salarySlip = "salary_slip"
    case tradeLicense = "trade_license"
    case udyamRegistration = "udyam_registration"
    case propertyTaxReceipt = "property_tax_receipt"
    case rentAgreement = "rent_agreement"
    case utilityBill = "utility_bill"
    case businessProof = "business_proof"
    case propertyDeed = "property_deed"
    case buildingPlan = "building_plan"
    case drivingLicense = "driving_license"
    case vehicleQuotation = "vehicle_quotation"
    case admissionLetter = "admission_letter"
    case feeSchedule = "fee_schedule"
    case academicMarksheets = "academic_marksheets"
    case balanceSheet = "balance_sheet"
    case passportPhoto = "passport_photo"
    case other = "other"

    var id: String { rawValue }

    /// Helper to find a matching core type for a given string
    static func from(string: String?) -> DocumentRequestType? {
        guard let s = string?.lowercased() else { return nil }
        // Try exact match on rawValue
        if let exact = DocumentRequestType.allCases.first(where: { $0.rawValue == s }) {
            return exact
        }
        // Try matching against common keywords
        return DocumentRequestType.allCases.first { type in
            type.matchingDocTypes.contains { keyword in
                let normKeyword = keyword.lowercased()
                return s.contains(normKeyword) || normKeyword.contains(s)
            }
        }
    }

    var displayName: String {
        switch self {
        case .panCard: return "PAN Card"
        case .aadhaarCard: return "Aadhaar Card"
        case .incomeProof: return "Income Proof"
        case .addressProof: return "Address Proof"
        case .collateralPaper: return "Collateral Paper"
        case .bankStatement: return "Bank Statement"
        case .gstRegistration: return "GST Registration"
        case .itrReturns: return "ITR Returns"
        case .salarySlip: return "Salary Slip"
        case .tradeLicense: return "Trade License"
        case .udyamRegistration: return "Udyam Registration"
        case .propertyTaxReceipt: return "Property Tax Receipt"
        case .rentAgreement: return "Rent Agreement"
        case .utilityBill: return "Utility Bill"
        case .businessProof: return "Business Proof"
        case .propertyDeed: return "Property Title Deed"
        case .buildingPlan: return "Approved Building Plan"
        case .drivingLicense: return "Driving License"
        case .vehicleQuotation: return "Vehicle Quotation"
        case .admissionLetter: return "Admission Letter"
        case .feeSchedule: return "Fee Schedule"
        case .academicMarksheets: return "Academic Marksheets"
        case .balanceSheet: return "Audited Balance Sheet"
        case .passportPhoto: return "Passport Size Photograph"
        case .other: return "Other Document"
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
        case .itrReturns: return "doc.text.below.ecg.fill"
        case .salarySlip: return "list.bullet.rectangle.fill"
        case .tradeLicense: return "briefcase.fill"
        case .udyamRegistration: return "building.fill"
        case .propertyTaxReceipt: return "building.columns.fill"
        case .rentAgreement: return "doc.plaintext.fill"
        case .utilityBill: return "bolt.fill"
        case .businessProof: return "suitcase.fill"
        case .propertyDeed: return "house.lodge.fill"
        case .buildingPlan: return "map.fill"
        case .drivingLicense: return "car.fill"
        case .vehicleQuotation: return "doc.text.magnifyingglass"
        case .admissionLetter: return "graduationcap.fill"
        case .feeSchedule: return "list.bullet.clipboard.fill"
        case .academicMarksheets: return "doc.on.doc.fill"
        case .balanceSheet: return "chart.bar.doc.horizontal.fill"
        case .passportPhoto: return "person.crop.square.fill"
        case .other: return "doc.fill"
        }
    }

    var matchingDocTypes: [String] {
        switch self {
        case .panCard: return ["PAN Card", "PAN"]
        case .aadhaarCard: return ["Aadhaar Card", "Aadhaar"]
        case .incomeProof: return ["Income Proof", "Income"]
        case .addressProof: return ["Address Proof", "Address"]
        case .collateralPaper: return ["Collateral Paper", "Collateral"]
        case .bankStatement: return ["Bank Statement", "Bank Statement (12 months)", "Business Bank Statement", "Bank Statement (6 Months)"]
        case .gstRegistration: return ["GST Registration", "GST", "GST Certificate"]
        case .itrReturns: return ["ITR", "ITR Returns", "Income Tax Returns", "ITR (2 Years)", "Business ITR (3 Years)"]
        case .salarySlip: return ["Salary Slip", "Salary Slips", "Income Proof", "Salary Slips (3 Months)"]
        case .tradeLicense: return ["Trade License", "Business License"]
        case .udyamRegistration: return ["Udyam", "Udyam Registration", "MSME Registration"]
        case .propertyTaxReceipt: return ["Property Tax", "Property Tax Receipt"]
        case .rentAgreement: return ["Rent Agreement", "Lease Agreement"]
        case .utilityBill: return ["Utility Bill", "Electricity Bill", "Water Bill", "Address Proof (Utility Bill)"]
        case .businessProof: return ["Business Proof", "Business Existence Proof"]
        case .propertyDeed: return ["Property Title Deed", "Title Deed", "Property Papers"]
        case .buildingPlan: return ["Approved Building Plan", "Building Plan"]
        case .drivingLicense: return ["Driving License", "DL"]
        case .vehicleQuotation: return ["Vehicle Quotation", "Quotation", "Proforma Invoice"]
        case .admissionLetter: return ["Admission Letter", "Admission Proof"]
        case .feeSchedule: return ["Fee Schedule", "Fees"]
        case .academicMarksheets: return ["Academic Marksheets", "Marksheets", "Degree Certificate"]
        case .balanceSheet: return ["Audited Balance Sheet", "Balance Sheet"]
        case .passportPhoto: return ["Passport Size Photograph", "Photo", "Passport Photo"]
        case .other: return ["Other", "Document"]
        }
    }
}

struct DBChatMessage: Codable, Identifiable {
    let id: UUID
    let applicationId: UUID
    let senderId: UUID
    let content: String
    let messageType: ChatMessageType
    let documentType: String?
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
}

struct ChatMessage: Identifiable {
    let id: UUID
    let applicationId: UUID
    let senderId: UUID
    let senderName: String
    let content: String
    let messageType: ChatMessageType
    let documentType: String?
    let createdAt: Date
    let isFromOfficer: Bool

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

    init(id: UUID = UUID(), applicationId: UUID, senderId: UUID, senderName: String, content: String, messageType: ChatMessageType, documentType: String? = nil, createdAt: Date = Date(), isFromOfficer: Bool) {
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
