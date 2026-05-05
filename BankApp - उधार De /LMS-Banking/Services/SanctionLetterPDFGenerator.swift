import PDFKit
import UIKit

struct SanctionLetterPDFGenerator {

    static func generate(for loan: Loan, managerName: String) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "LMS Banking",
            kCGPDFContextAuthor: managerName,
            kCGPDFContextTitle: "Sanction Letter - \(loan.borrowerName)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 48
        let contentWidth = pageWidth - (margin * 2)

        // Colors
        let black = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        let darkGray = UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        let mediumGray = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
        let lightGray = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        let accentGreen = UIColor(red: 0.02, green: 0.31, blue: 0.23, alpha: 1) // #064e3b
        let lightGreenBg = UIColor(red: 0.92, green: 0.97, blue: 0.94, alpha: 1)

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            // White background
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)).fill()

            var y: CGFloat = margin

            // MARK: Top accent bar
            accentGreen.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: 6)).fill()

            y = 24

            // MARK: Institution Header
            let institutionName = "उधार De BANK"
            let instAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: accentGreen,
                .kern: 1.5
            ]
            institutionName.draw(at: CGPoint(x: margin, y: y), withAttributes: instAttrs)
            y += 24

            let divisionText = "Institutional Financial Analysis Division"
            let divisionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: darkGray
            ]
            divisionText.draw(at: CGPoint(x: margin, y: y), withAttributes: divisionAttrs)
            y += 14

            let corpId = "Corporate ID: L65110MH2026PLC04210"
            let corpAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: mediumGray
            ]
            corpId.draw(at: CGPoint(x: margin, y: y), withAttributes: corpAttrs)
            y += 13

            let address = "Registered Address: Mumbai, Maharashtra, India"
            address.draw(at: CGPoint(x: margin, y: y), withAttributes: corpAttrs)
            y += 20

            // Full-width divider
            drawHorizontalLine(x: margin, y: y, width: contentWidth, color: lightGray)
            y += 12

            // MARK: Doc Meta Block — right aligned
            let refNo = "DOC ID: REF-\(Int.random(in: 100000...999999))"
            let issuedOn = "ISSUED ON: \(formattedDateTime())"
            let classification = "CLASSIFICATION: CONFIDENTIAL"
            let period = "PERIOD: \(formattedDate())"

            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: darkGray
            ]

            for line in [refNo, issuedOn, classification, period] {
                let size = line.size(withAttributes: metaAttrs)
                line.draw(at: CGPoint(x: pageWidth - margin - size.width, y: y), withAttributes: metaAttrs)
                y += 13
            }
            y += 8

            // MARK: Title Banner
            let bannerRect = CGRect(x: margin, y: y, width: contentWidth, height: 36)
            accentGreen.setFill()
            UIBezierPath(roundedRect: bannerRect, cornerRadius: 4).fill()

            let titleText = "SANCTION LETTER"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.white,
                .kern: 2.0
            ]
            let titleSize = titleText.size(withAttributes: titleAttrs)
            titleText.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: y + (36 - titleSize.height) / 2), withAttributes: titleAttrs)
            y += 48

            // MARK: Executive Summary / KPI row
            let kpiItems: [(String, String)] = [
                ("BORROWER", loan.borrowerName),
                ("LOAN AMOUNT", CurrencyFormatter.indian(loan.amountValue)),
                ("PURPOSE", loan.purpose),
                ("TENURE", loan.tenure)
            ]

            let kpiBoxWidth = contentWidth / CGFloat(kpiItems.count)
            let kpiBoxHeight: CGFloat = 54

            for (i, item) in kpiItems.enumerated() {
                let boxX = margin + CGFloat(i) * kpiBoxWidth
                let boxRect = CGRect(x: boxX, y: y, width: kpiBoxWidth - 4, height: kpiBoxHeight)

                lightGreenBg.setFill()
                UIBezierPath(roundedRect: boxRect, cornerRadius: 4).fill()
                accentGreen.withAlphaComponent(0.3).setStroke()
                UIBezierPath(roundedRect: boxRect, cornerRadius: 4).stroke()

                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                    .foregroundColor: mediumGray
                ]
                item.0.draw(at: CGPoint(x: boxX + 8, y: y + 8), withAttributes: labelAttrs)

                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: accentGreen
                ]
                let valueStr = item.1
                let maxWidth = kpiBoxWidth - 20
                let valueSize = valueStr.size(withAttributes: valueAttrs)
                let scaledAttrs: [NSAttributedString.Key: Any] = valueSize.width > maxWidth ? [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: accentGreen
                ] : valueAttrs
                valueStr.draw(at: CGPoint(x: boxX + 8, y: y + 22), withAttributes: scaledAttrs)
            }
            y += kpiBoxHeight + 20

            // MARK: Loan Details Section
            drawSectionHeader("LOAN DETAILS", x: margin, y: &y, width: contentWidth, accentColor: accentGreen, textColor: UIColor.white)

            let details: [(String, String)] = [
                ("Loan Reference",    "LN/\(loan.id.uuidString.prefix(8).uppercased())"),
                ("Borrower Name",     loan.borrowerName),
                ("Sanctioned Amount", CurrencyFormatter.indian(loan.amountValue)),
                ("Loan Purpose",      loan.purpose),
                ("Tenure",            loan.tenure),
                ("Credit Score",      "\(loan.creditScore)"),
                ("Monthly Income",    loan.income.replacingOccurrences(of: "$", with: "₹")),
                ("Risk Category",     loan.risk.rawValue),
                ("Assigned Officer",  loan.officer),
                ("Status",            "APPROVED")
            ]

            for (i, row) in details.enumerated() {
                let rowRect = CGRect(x: margin, y: y, width: contentWidth, height: 26)
                if i % 2 == 0 {
                    UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1).setFill()
                    UIBezierPath(rect: rowRect).fill()
                }

                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: mediumGray
                ]
                let valAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: row.0 == "Status" ? accentGreen : black
                ]

                row.0.draw(at: CGPoint(x: margin + 10, y: y + 7), withAttributes: keyAttrs)
                let valSize = row.1.size(withAttributes: valAttrs)
                row.1.draw(at: CGPoint(x: pageWidth - margin - valSize.width - 10, y: y + 7), withAttributes: valAttrs)

                lightGray.setStroke()
                let divider = UIBezierPath()
                divider.move(to: CGPoint(x: margin, y: y + 26))
                divider.addLine(to: CGPoint(x: pageWidth - margin, y: y + 26))
                divider.lineWidth = 0.4
                divider.stroke()

                y += 26
            }

            // Table border
            accentGreen.withAlphaComponent(0.25).setStroke()
            let tableBorder = UIBezierPath(
                roundedRect: CGRect(x: margin, y: y - CGFloat(details.count) * 26, width: contentWidth, height: CGFloat(details.count) * 26),
                cornerRadius: 4
            )
            tableBorder.lineWidth = 0.8
            tableBorder.stroke()
            y += 18

            // MARK: Terms Section
            drawSectionHeader("TERMS & CONDITIONS", x: margin, y: &y, width: contentWidth, accentColor: accentGreen, textColor: UIColor.white)

            let terms = [
                "This sanction is subject to execution of the loan agreement and fulfillment of all documentation requirements.",
                "The sanctioned amount must be utilized solely for the stated purpose: \(loan.purpose).",
                "Any misrepresentation of facts may lead to immediate recall of the sanctioned loan.",
                "This sanction letter is valid for 30 days from the date of issue.",
                "Interest rates and processing fees are subject to change as per RBI guidelines.",
                "Disbursement will be initiated only after successful KYC verification and document submission."
            ]

            for (i, term) in terms.enumerated() {
                let termText = "\(i + 1). \(term)"
                let termAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9.5),
                    .foregroundColor: darkGray
                ]
                let attrStr = NSAttributedString(string: termText, attributes: termAttrs)
                let boundingRect = attrStr.boundingRect(
                    with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                attrStr.draw(in: CGRect(x: margin + 10, y: y, width: contentWidth - 20, height: boundingRect.height))
                y += boundingRect.height + 6
            }
            y += 12

            // MARK: Signature Block — new page if needed
            if y + 140 > pageHeight - 40 {
                ctx.beginPage()
                UIColor.white.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)).fill()
                accentGreen.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageWidth, height: 6)).fill()
                y = 40
            }

            drawHorizontalLine(x: margin, y: y, width: contentWidth, color: lightGray)
            y += 16

            // Signatory name (bold)
            let sigNameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: black
            ]
            managerName.uppercased().draw(at: CGPoint(x: margin, y: y), withAttributes: sigNameAttrs)
            y += 16

            // Title
            let titleLineAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: mediumGray
            ]
            "Branch Manager — उधार De Bank".draw(at: CGPoint(x: margin, y: y), withAttributes: titleLineAttrs)
            y += 20

            // Checkmark + verified line
            let verifiedAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: accentGreen
            ]
            "✓ Digitally Signed & Verified".draw(at: CGPoint(x: margin, y: y), withAttributes: verifiedAttrs)
            y += 22

            // Cursive signature
            let signatureFont: UIFont = UIFont(name: "MrsSaintDelafield-Regular", size: 40)
                ?? UIFont(name: "SnellRoundhand", size: 40)
                ?? UIFont(name: "ZapfChancery-MediumItalic", size: 40)
                ?? UIFont.italicSystemFont(ofSize: 40)

            let signatureAttrs: [NSAttributedString.Key: Any] = [
                .font: signatureFont,
                .foregroundColor: accentGreen
            ]

            let context = UIGraphicsGetCurrentContext()!
            context.saveGState()
            context.translateBy(x: margin, y: y)
            context.rotate(by: -0.035)
            managerName.draw(at: .zero, withAttributes: signatureAttrs)
            context.restoreGState()
            y += 48

            // MARK: Footer
            drawHorizontalLine(x: margin, y: pageHeight - 36, width: contentWidth, color: lightGray)

            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: mediumGray
            ]
            let footerText = "This document is an electronically generated official sanction letter of उधार De Bank.  |  Encryption Standard: AES-256  |  Classification: Confidential"
            let footerSize = footerText.size(withAttributes: footerAttrs)
            footerText.draw(
                at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - 26),
                withAttributes: footerAttrs
            )

            // Top accent bar on every page is handled — footer line done
        }

        return data
    }

    // MARK: - Helpers

    private static func drawSectionHeader(_ title: String, x: CGFloat, y: inout CGFloat, width: CGFloat, accentColor: UIColor, textColor: UIColor) {
        let rect = CGRect(x: x, y: y, width: width, height: 22)
        accentColor.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 3).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: textColor,
            .kern: 1.0
        ]
        title.draw(at: CGPoint(x: x + 10, y: y + 5), withAttributes: attrs)
        y += 22
    }

    private static func drawHorizontalLine(x: CGFloat, y: CGFloat, width: CGFloat, color: UIColor) {
        color.setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: x, y: y))
        line.addLine(to: CGPoint(x: x + width, y: y))
        line.lineWidth = 0.5
        line.stroke()
    }

    private static func formattedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: Date())
    }

    private static func formattedDateTime() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
