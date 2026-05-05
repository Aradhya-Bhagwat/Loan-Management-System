import Foundation

struct SanctionLetterHTMLTemplate {
    static func generate(
        loanId: String,
        date: String,
        borrowerName: String,
        borrowerAddress: String,
        purpose: String,
        amount: String,
        rate: String,
        tenure: String,
        emi: String,
        processingFee: String,
        repaymentDate: String,
        managerName: String? = nil
    ) -> String {
        let actualManagerName = managerName ?? "Authorized Signatory"
        let refNumber = "SL-\(loanId.prefix(8).uppercased())"
        let institutionName = "उधार De FINANCIAL SERVICES"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <link href="https://fonts.googleapis.com/css2?family=Mrs+Saint+Delafield&family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
            <style>
                @page {
                    size: A4;
                    margin: 0;
                }
                * { -webkit-print-color-adjust: exact; }
                body {
                    font-family: 'Inter', sans-serif;
                    color: #111827;
                    margin: 0;
                    padding: 0;
                    background: #fff;
                    line-height: 1.6;
                }
                .page-container {
                    padding: 60px 50px;
                    position: relative;
                    min-height: 27cm;
                }
                /* Watermark Styling from Admin Report */
                .watermark-overlay {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: -1;
                    pointer-events: none;
                }
                .watermark-text {
                    transform: rotate(-35deg);
                    font-size: 60px;
                    color: rgba(0, 0, 0, 0.03);
                    font-weight: 900;
                    letter-spacing: 10px;
                    text-transform: uppercase;
                    white-space: nowrap;
                    border: 8px solid rgba(0, 0, 0, 0.03);
                    padding: 15px 30px;
                }
                .header {
                    display: flex;
                    justify-content: space-between;
                    border-bottom: 2px solid #064e3b;
                    padding-bottom: 30px;
                    margin-bottom: 40px;
                    position: relative;
                    z-index: 10;
                }
                .bank-logo-title {
                    color: #064e3b;
                    font-size: 32px;
                    font-weight: 800;
                    margin: 0;
                    letter-spacing: -1px;
                }
                .bank-info p {
                    margin: 4px 0;
                    font-size: 12px;
                    color: #4b5563;
                    font-weight: 500;
                }
                .report-meta {
                    text-align: right;
                }
                .report-meta h2 {
                    margin: 0;
                    font-size: 18px;
                    color: #111827;
                    font-weight: 800;
                    text-transform: uppercase;
                }
                .report-meta p {
                    margin: 4px 0;
                    font-size: 11px;
                    color: #6b7280;
                    font-weight: 600;
                }
                .to-block {
                    margin-bottom: 30px;
                    font-size: 13px;
                }
                .to-block p {
                    margin: 2px 0;
                }
                .subject {
                    font-weight: 800;
                    text-decoration: underline;
                    margin-bottom: 25px;
                    font-size: 14px;
                    color: #111827;
                    text-transform: uppercase;
                }
                .content-body {
                    margin-bottom: 25px;
                    font-size: 13px;
                    text-align: justify;
                    color: #374151;
                }
                .section-title {
                    font-size: 14px;
                    color: #064e3b;
                    text-transform: uppercase;
                    border-bottom: 1px solid #e5e7eb;
                    padding-bottom: 8px;
                    margin: 30px 0 15px 0;
                    letter-spacing: 1.5px;
                    font-weight: 700;
                }
                table {
                    width: 100%;
                    border-collapse: separate;
                    border-spacing: 0;
                    font-size: 13px;
                    border: 1px solid #e5e7eb;
                    border-radius: 12px;
                    overflow: hidden;
                    background: rgba(255, 255, 255, 0.7);
                    margin-bottom: 20px;
                }
                th {
                    background-color: #f3f4f6;
                    color: #374151;
                    text-align: left;
                    padding: 14px 15px;
                    font-weight: 700;
                    text-transform: uppercase;
                    width: 40%;
                    border-bottom: 1px solid #e5e7eb;
                }
                td {
                    padding: 14px 15px;
                    border-bottom: 1px solid #e5e7eb;
                    color: #111827;
                    font-weight: 600;
                }
                tr:last-child td, tr:last-child th { border-bottom: none; }
                .highlight-row td {
                    color: #064e3b;
                    font-size: 16px;
                    font-weight: 800;
                }
                .terms-list {
                    padding-left: 20px;
                    font-size: 12px;
                    color: #4b5563;
                }
                .terms-list li {
                    margin-bottom: 10px;
                }
                
                /* Signature Section matching Admin Report */
                .signature-section {
                    margin-top: 60px;
                    display: flex;
                    justify-content: space-between;
                    page-break-inside: avoid;
                    position: relative;
                    z-index: 10;
                }
                .sig-box {
                    text-align: center;
                    width: 260px;
                }
                .signature-font {
                    font-family: 'Mrs Saint Delafield', cursive;
                    font-size: 48px;
                    color: #064e3b;
                    margin-bottom: 0px;
                    transform: rotate(-2deg);
                    display: inline-block;
                }
                .sig-name {
                    font-size: 14px;
                    font-weight: 700;
                    color: #111827;
                    text-transform: uppercase;
                    margin-top: 5px;
                    border-top: 1px solid #e5e7eb;
                    padding-top: 8px;
                }
                .sig-title {
                    font-size: 11px;
                    color: #6b7280;
                    font-weight: 500;
                }
                .footer {
                    margin-top: 60px;
                    font-size: 10px;
                    text-align: center;
                    color: #9ca3af;
                    border-top: 1px solid #f3f4f6;
                    padding-top: 20px;
                    position: relative;
                    z-index: 10;
                }
            </style>
        </head>
        <body>
            <div class="watermark-overlay">
                <div class="watermark-text">\(institutionName) OFFICIAL</div>
            </div>
            <div class="page-container">
                <div class="header">
                    <div class="bank-info">
                        <h1 class="bank-logo-title">उधार De</h1>
                        <p>Institutional Loan Management Division</p>
                        <p>Corporate ID: L65110KA2026PLC04210</p>
                        <p>Registered Address: 4th Floor, Prestige Tower, MG Road, Bengaluru – 560001</p>
                    </div>
                    <div class="report-meta">
                        <h2>LOAN SANCTION ADVICE</h2>
                        <p>REF NO: \(refNumber)</p>
                        <p>DATE: \(date)</p>
                        <p>VALIDITY: 30 DAYS FROM ISSUE</p>
                    </div>
                </div>

                <div class="to-block">
                    <p><b>To,</b></p>
                    <p><b>\(borrowerName.uppercased())</b></p>
                    <p>\(borrowerAddress)</p>
                </div>

                <div class="subject">
                    Subject: Sanction of \(purpose) Facility
                </div>

                <div class="content-body">
                    <p>Dear Sir/Madam,</p>
                    <p>With reference to your application for a loan facility, we are pleased to inform you that उधार De Financial Services has sanctioned a loan facility to you. This sanction is based on the credit appraisal and information provided by you in the application form and subsequent interactions.</p>
                    <p>The facility is sanctioned subject to the following key terms and conditions:</p>
                </div>

                <div class="section-title">Loan Parameters</div>
                <table>
                    <tbody>
                        <tr><th>Facility Type</th><td>\(purpose)</td></tr>
                        <tr class="highlight-row"><th>Sanctioned Amount</th><td>\(amount)</td></tr>
                        <tr><th>Applicable Interest Rate</th><td>\(rate) per annum</td></tr>
                        <tr><th>Repayment Tenure</th><td>\(tenure)</td></tr>
                        <tr><th>Equated Monthly Installment</th><td>\(emi)</td></tr>
                        <tr><th>Upfront Processing Fee</th><td>\(processingFee)</td></tr>
                        <tr><th>First Repayment Date</th><td>\(repaymentDate)</td></tr>
                    </tbody>
                </table>

                <div class="section-title">Standard Terms & Conditions</div>
                <ul class="terms-list">
                    <li><b>Security/Collateral:</b> This sanction is subject to the satisfactory creation of security as per the institution's credit policy (where applicable).</li>
                    <li><b>Rate of Interest:</b> The interest rate mentioned is floating/fixed as per current policy and is subject to change based on RBI guidelines and cost of funds.</li>
                    <li><b>Repayment:</b> The borrower must maintain sufficient funds in the designated account for timely repayment of EMIs. Default will attract penal interest and credit score impact.</li>
                    <li><b>Pre-payment:</b> Any pre-payment or foreclosure will be subject to the charges prevailing at the time of such transaction as per our policy.</li>
                    <li><b>Documentation:</b> Final disbursement is subject to the execution of required loan documents and verification of originals to the satisfaction of the Bank.</li>
                </ul>

                <div class="signature-section">
                    <div class="sig-box">
                        <div class="signature-font">\(actualManagerName)</div>
                        <p class="sig-name">\(actualManagerName)</p>
                        <p class="sig-title">Senior Portfolio Manager<br>Authorised Signatory</p>
                        <p style="font-size: 10px; color: #059669; font-weight: 700; margin-top: 5px;">
                            <span style="font-size: 12px;">✓</span> Digitally Verified
                        </p>
                    </div>
                    <div class="sig-box">
                        <div style="height: 60px;"></div>
                        <p class="sig-name">Borrower Acceptance</p>
                        <p class="sig-title">Signature & Date</p>
                    </div>
                </div>

                <div class="footer">
                    <p>This document is an electronically generated official sanction advice of \(institutionName).</p>
                    <p>उधार De Desk © 2026 | Confidential | Subject to Bangalore Jurisdiction</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
}
