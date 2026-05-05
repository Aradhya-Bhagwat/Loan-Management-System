//
//  LoanOfficerSanctionLetter.swift
//  LMS-Banking
//

import SwiftUI

// MARK: - Missing Field Model

struct SanctionMissingField: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Sanction Letter Screen

struct SanctionLetterScreen: View {
    let loan: LoanCase
    let officerName: String

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var renderedImage: UIImage?
    @State private var isRendering = false

    // MARK: - Validation (AC2)

    private var missingFields: [SanctionMissingField] {
        var missing: [SanctionMissingField] = []
        if loan.borrower.fullName == nil || loan.borrower.fullName!.isEmpty {
            missing.append(SanctionMissingField(name: "Borrower name"))
        }
        if loan.borrower.address == nil || loan.borrower.address!.isEmpty {
            missing.append(SanctionMissingField(name: "Borrower address"))
        }
        if loan.borrower.panNumber == nil || loan.borrower.panNumber!.isEmpty {
            missing.append(SanctionMissingField(name: "PAN number"))
        }
        if loan.application.interestRate == nil {
            missing.append(SanctionMissingField(name: "Interest rate"))
        }
        if loan.application.purpose == nil || loan.application.purpose!.isEmpty {
            missing.append(SanctionMissingField(name: "Loan purpose"))
        }
        return missing
    }

    private var canGenerate: Bool { missingFields.isEmpty }

    var body: some View {
        ZStack {
            OfficerTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    if !canGenerate {
                        MissingFieldsBanner(fields: missingFields)
                    }

                    LetterContent(loan: loan, officerName: officerName)

                    if canGenerate {
                        generateButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Sanction Letter")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            isRendering = true
            Task {
                let content = LetterRenderable(loan: loan, officerName: officerName)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 3.0
                renderedImage = renderer.uiImage
                isRendering = false
                showShareSheet = true
            }
        } label: {
            HStack(spacing: 10) {
                if isRendering {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                    Text("Download / Share Letter")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(OfficerTheme.accentBlue)
            )
        }
        .buttonStyle(.plain)
        .disabled(isRendering)
    }
}

// MARK: - Letter Content (shared by preview + renderer)

struct LetterContent: View {
    let loan: LoanCase
    let officerName: String

    private var sanctionDate: String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"
        return f.string(from: Date())
    }

    private var repaymentStartDate: String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"
        let start = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        return f.string(from: start)
    }

    private var emi: String {
        guard let rate = loan.application.interestRate else { return "—" }
        let p = loan.application.loanAmount
        let r = rate / 100 / 12
        let n = Double(loan.application.tenureMonths)
        guard r > 0 else { return CurrencyFormatter.indian(p / n) }
        let computed = p * r * pow(1 + r, n) / (pow(1 + r, n) - 1)
        return CurrencyFormatter.indian(computed)
    }

    private var refNumber: String {
        "SL-\(loan.application.id.uuidString.prefix(8).uppercased())"
    }

    var body: some View {
        WhiteCard {
            VStack(alignment: .leading, spacing: 0) {

                // ── Letterhead ────────────────────────────────────────────
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(OfficerTheme.accentBlue)
                        Text("उधार De Financial Services")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(OfficerTheme.textPrimary)
                    }
                    Text("4th Floor, Prestige Tower, MG Road, Bengaluru – 560001")
                        .font(.system(size: 11))
                        .foregroundStyle(OfficerTheme.textSecondary)
                    Text("Tel: +91-80-4567-8900  |  support@udhaarde.in  |  www.udhaarde.in")
                        .font(.system(size: 11))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)

                Divider().overlay(OfficerTheme.softLine)

                // ── Date & Ref ────────────────────────────────────────────
                HStack {
                    Text("Date: \(sanctionDate)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OfficerTheme.textSecondary)
                    Spacer()
                    Text("Ref No: \(refNumber)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
                .padding(.vertical, 14)

                Divider().overlay(OfficerTheme.softLine)

                // ── To block ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 3) {
                    Text("To,")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OfficerTheme.textPrimary)
                        .padding(.top, 14)
                    Text(loan.borrower.fullName ?? "—")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(loan.borrower.fullName != nil ? OfficerTheme.textPrimary : OfficerTheme.iconRed)
                    Text(loan.borrower.address ?? "—")
                        .font(.system(size: 12))
                        .foregroundStyle(loan.borrower.address != nil ? OfficerTheme.textSecondary : OfficerTheme.iconRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 16)

                // ── Subject ───────────────────────────────────────────────
                HStack(spacing: 4) {
                    Text("Subject:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OfficerTheme.textPrimary)
                    Text("Sanction of Loan")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OfficerTheme.textPrimary)
                }
                .padding(.bottom, 14)

                Divider().overlay(OfficerTheme.softLine)

                // ── Salutation & body ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dear \(loan.borrower.fullName ?? "Applicant"),")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OfficerTheme.textPrimary)
                        .padding(.top, 14)

                    Text("We are pleased to inform you that your loan application has been approved based on the information and documents provided. The details of the sanctioned loan are as follows:")
                        .font(.system(size: 12))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── Loan Details ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    LetterSectionHeader(title: "Loan Details")

                    LetterDetailRow(label: "Loan Type",      value: loan.application.purpose ?? "—")
                    LetterDetailRow(label: "Sanctioned Amount", value: CurrencyFormatter.indian(loan.application.loanAmount), highlight: true)
                    LetterDetailRow(label: "Interest Rate",
                                   value: loan.application.interestRate != nil
                                   ? String(format: "%.2f%% p.a.", loan.application.interestRate!) : "—")
                    LetterDetailRow(label: "Loan Tenure",    value: "\(loan.application.tenureMonths) months")
                    LetterDetailRow(label: "EMI Amount",     value: emi)
                    LetterDetailRow(label: "Processing Fee", value: CurrencyFormatter.indian(loan.application.loanAmount * 0.01))
                    LetterDetailRow(label: "Disbursement Mode", value: "Account Transfer")
                    LetterDetailRow(label: "Repayment Start Date", value: repaymentStartDate, isLast: true)
                }

                // ── Terms & Conditions ────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    LetterSectionHeader(title: "Terms & Conditions")

                    let terms = [
                        "The loan is subject to execution of required agreements and submission of all documents.",
                        "Interest rate is subject to change as per bank policies.",
                        "EMI must be paid on or before the due date to avoid penalties.",
                        "Prepayment/foreclosure charges may apply as per the loan agreement.",
                        "Any default may impact your credit score and legal action may be initiated.",
                    ]
                    ForEach(Array(terms.enumerated()), id: \.offset) { idx, term in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1).")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(OfficerTheme.textSecondary)
                                .frame(width: 18, alignment: .leading)
                            Text(term)
                                .font(.system(size: 12))
                                .foregroundStyle(OfficerTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // ── Validity ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    LetterSectionHeader(title: "Validity")
                    Text("This sanction is valid for 30 days from the date of issue. Kindly confirm your acceptance by signing below.")
                        .font(.system(size: 12))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── Authorised Signatory ──────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    LetterSectionHeader(title: "Authorised Signatory")

                    Spacer().frame(height: 36) // signature space

                    Text("_______________________")
                        .font(.system(size: 12))
                        .foregroundStyle(OfficerTheme.softLine)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(officerName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OfficerTheme.textPrimary)
                        Text("Loan Officer, उधार De Financial Services")
                            .font(.system(size: 11))
                            .foregroundStyle(OfficerTheme.textSecondary)
                    }
                    .padding(.top, 4)
                }

                // ── Borrower Acceptance ───────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Divider().overlay(OfficerTheme.softLine).padding(.top, 8)

                    LetterSectionHeader(title: "Borrower Acceptance")

                    Text("I, \(loan.borrower.fullName ?? "_______________"), accept the above terms and conditions.")
                        .font(.system(size: 12))
                        .foregroundStyle(OfficerTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signature: ______________")
                                .font(.system(size: 12))
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Date: ______________")
                                .font(.system(size: 12))
                                .foregroundStyle(OfficerTheme.textSecondary)
                        }
                    }
                    .padding(.top, 28)
                }
            }
        }
    }
}

// MARK: - Letter Renderable (concrete View type for ImageRenderer)

struct LetterRenderable: View {
    let loan: LoanCase
    let officerName: String
    var body: some View {
        LetterContent(loan: loan, officerName: officerName)
            .frame(width: 390)
            .padding(20)
            .background(OfficerTheme.background)
    }
}

// MARK: - Letter sub-components

private struct LetterSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(OfficerTheme.accentBlue)
            .kerning(0.5)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}

private struct LetterField: View {
    let label: String
    let value: String?
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(label):")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OfficerTheme.textSecondary)
                .frame(width: 56, alignment: .leading)
            Text(value ?? "—")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(value != nil ? OfficerTheme.textPrimary : OfficerTheme.iconRed)
        }
    }
}

private struct LetterDetailRow: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OfficerTheme.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: highlight ? .bold : .semibold))
                    .foregroundStyle(highlight ? OfficerTheme.accentBlue : OfficerTheme.textPrimary)
            }
            .padding(.vertical, 9)
            if !isLast {
                Divider().overlay(OfficerTheme.softLine)
            }
        }
    }
}

// MARK: - Missing Fields Banner (AC2)

private struct MissingFieldsBanner: View {
    let fields: [SanctionMissingField]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(OfficerTheme.iconAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cannot Generate Letter")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OfficerTheme.textPrimary)
                    Text("The following required fields are missing:")
                        .font(.system(size: 13))
                        .foregroundStyle(OfficerTheme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(fields) { field in
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(OfficerTheme.iconRed)
                        Text(field.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OfficerTheme.textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OfficerTheme.iconAmber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OfficerTheme.iconAmber.opacity(0.25), lineWidth: 1)
        )
    }
}


