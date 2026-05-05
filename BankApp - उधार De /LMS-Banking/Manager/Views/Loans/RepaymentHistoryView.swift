//
//  RepaymentHistoryView.swift
//  LMS-Banking
//
//  Created by Nevin Abraham on 21/04/26.
//

import Foundation
import SwiftUI
struct RepaymentHistoryView: View {
    let loan: Loan
    @State private var repayments: [Repayment] = []

    @Environment(\.horizontalSizeClass) var sizeClass
    var isPad: Bool { sizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: Borrower Header
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.appGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(loan.borrowerName.prefix(1))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.appGreen)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(loan.borrowerName)
                            .font(.system(size: 18, weight: .bold))
                        Text("Repayment History")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // MARK: Repayment List
                VStack(spacing: 0) {
                    ForEach(repayments) { repayment in
                        RepaymentRow(repayment: repayment)

                        if repayment.id != repayments.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(isPad ? 28 : 20)
        }
        .background(Color.appBackground)
        .navigationTitle("Repayments")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRepayments()
        }
    }

    func loadRepayments() {
        Task {
            do {
                let data = try await DatabaseService.shared.fetchRepayments(loanId: loan.id)
                await MainActor.run { self.repayments = data }
            } catch {
                print("Error fetching repayments: \(error)")
            }
        }
    }
}

struct RepaymentRow: View {
    let repayment: Repayment
    var statusColor: Color {
        switch repayment.status {
        case "Paid": return Color.appGreen
        case "Overdue": return Color.appRed
        case "Pending": return Color.orange
        default: return .secondary
        }
    }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(repayment.displayDate)
                    .font(.system(size: 15, weight: .medium))

                Text(repayment.status)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(repayment.displayAmount)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(statusColor)
         
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct Repayment: Identifiable, Codable {
    let id: UUID
    let loanId: UUID
    let dueDate: Date
    let amount: Double
    let status: String
    let paidAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case loanId = "loan_id"
        case dueDate = "due_date"
        case amount
        case status
        case paidAt = "paid_at"
    }

    var displayDate: String {
        dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
}
