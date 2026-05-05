

struct TransactionInsert: Encodable {
    let borrower_id: String
    let amount: Double
    let type: String
}
