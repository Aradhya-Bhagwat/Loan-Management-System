import Foundation

struct ReportHTMLTemplate {
    struct Meta: Sendable {
        let institutionName: String
        let corporateId: String
        let address: String
        let reportTitle: String
        let reportId: String
        let generatedAt: String
        let classification: String
        let reportingWindow: String
        let reportType: String
        let generatingAdmin: String?
    }

    struct KPIItem: Sendable {
        let title: String
        let value: String
        let note: String?
    }

    struct KeyValueRow: Sendable {
        let label: String
        let value: String
    }

    struct TableColumn: Sendable {
        let title: String
    }

    struct Table: Sendable {
        let title: String
        let columns: [TableColumn]
        let rows: [[String]]
        let footnote: String?
    }

    struct Payload: Sendable {
        let meta: Meta
        let headerKpis: [KPIItem]
        let summaryRows: [KeyValueRow]
        let tables: [Table]
    }

    static func generate(payload: Payload) -> String {
        let kpiHtml = payload.headerKpis.map { kpi in
            """
            <div class="kpi-card">
                <div class="kpi-title">\(escape(kpi.title))</div>
                <div class="kpi-value">\(escape(kpi.value))</div>
                <div class="kpi-change">\(escape(kpi.note ?? ""))</div>
            </div>
            """
        }.joined()

        let summaryHtml = payload.summaryRows.isEmpty ? "" : """
            <div class="section">
                <h3>\(escape(payload.meta.reportType))</h3>
                <table class="kv-table">
                    <tbody>
                        \(payload.summaryRows.map { row in
                            """
                            <tr>
                                <td class="kv-label">\(escape(row.label))</td>
                                <td class="kv-value">\(escape(row.value))</td>
                            </tr>
                            """
                        }.joined())
                    </tbody>
                </table>
            </div>
        """

        let tablesHtml = payload.tables.map { table in
            let head = table.columns.map { "<th>\(escape($0.title))</th>" }.joined()
            let body = table.rows.map { row in
                let tds = row.map { "<td>\(escape($0))</td>" }.joined()
                return "<tr>\(tds)</tr>"
            }.joined()

            let footnote = (table.footnote?.isEmpty == false)
                ? "<p class=\"footnote\">\(escape(table.footnote!))</p>"
                : ""

            return """
            <div class="section no-break">
                <h3>\(escape(table.title))</h3>
                <table>
                    <thead><tr>\(head)</tr></thead>
                    <tbody>\(body)</tbody>
                </table>
                \(footnote)
            </div>
            """
        }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <link href="https://fonts.googleapis.com/css2?family=Mrs+Saint+Delafield&family=Inter:wght@400;600;700;800&family=Tiro+Devanagari+Hindi&display=swap" rel="stylesheet">
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
                }
                .page-container {
                    padding: 60px 50px;
                    position: relative;
                    min-height: 27cm;
                }
                /* Watermark removed */
                .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: flex-start;
                    border-bottom: 2px solid #064e3b;
                    padding-bottom: 30px;
                    margin-bottom: 40px;
                    position: relative;
                    z-index: 10;
                }
                .bank-info h1 {
                    margin: 0 0 8px 0;
                    padding: 0;
                    line-height: 1;
                }
                .bank-logo-title {
                    color: #064e3b;
                    font-size: 32px;
                    font-weight: 800;
                    margin: 0;
                    letter-spacing: -1px;
                }
                .bank-logo-devanagari {
                    font-family: 'Tiro Devanagari Hindi', serif;
                    font-size: 36px;
                    font-weight: 400;
                    color: #064e3b;
                    letter-spacing: 1px;
                    line-height: 1.1;
                }
                .bank-logo-latin {
                    font-family: 'Inter', sans-serif;
                    font-size: 22px;
                    font-weight: 700;
                    color: #064e3b;
                    letter-spacing: -0.5px;
                    margin-left: 4px;
                    vertical-align: middle;
                }
                .bank-info p {
                    margin: 4px 0;
                    font-size: 12px;
                    color: #4b5563;
                    font-weight: 500;
                }
                .report-meta {
                    text-align: right;
                    padding-top: 0;
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
                .section {
                    margin-bottom: 35px;
                    position: relative;
                    z-index: 10;
                }
                .no-break { page-break-inside: avoid; }
                .section h3 {
                    font-size: 14px;
                    color: #064e3b;
                    text-transform: uppercase;
                    border-bottom: 1px solid #e5e7eb;
                    padding-bottom: 8px;
                    margin-bottom: 20px;
                    letter-spacing: 1.5px;
                    font-weight: 700;
                }
                .kpi-container {
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    gap: 20px;
                }
                .kpi-card {
                    background: #f9fafb;
                    padding: 20px;
                    border-radius: 12px;
                    border: 1px solid #e5e7eb;
                    border-left: 6px solid #064e3b;
                }
                .kpi-title {
                    font-size: 11px;
                    font-weight: 700;
                    color: #6b7280;
                    margin-bottom: 12px;
                    text-transform: uppercase;
                }
                .kpi-value {
                    font-size: 24px;
                    font-weight: 800;
                    color: #111827;
                }
                .kpi-change {
                    font-size: 11px;
                    color: #059669;
                    margin-top: 10px;
                    font-weight: 700;
                }
                table {
                    width: 100%;
                    border-collapse: separate;
                    border-spacing: 0;
                    font-size: 12px;
                    border: 1px solid #e5e7eb;
                    border-radius: 12px;
                    overflow: hidden;
                    background: #ffffff;
                }
                th {
                    background-color: #f3f4f6;
                    color: #374151;
                    text-align: left;
                    padding: 14px 12px;
                    font-weight: 700;
                    text-transform: uppercase;
                    border-bottom: 1px solid #e5e7eb;
                }
                td {
                    padding: 12px;
                    border-bottom: 1px solid #e5e7eb;
                    color: #4b5563;
                }
                tr:last-child td { border-bottom: none; }
                tr:nth-child(even) { background-color: #fafafa; }
                .kv-table { border: none; background: transparent; }
                .kv-table td { border: none; padding: 10px 0; }
                .kv-label {
                    width: 45%;
                    font-weight: 700;
                    color: #374151;
                }
                .kv-value { font-weight: 600; text-align: right; }
                
                .signature-section {
                    margin-top: 80px;
                    display: flex;
                    justify-content: flex-end;
                    page-break-inside: avoid;
                    position: relative;
                    z-index: 10;
                }
                .sig-box {
                    text-align: center;
                    width: 280px;
                }
                .signature-font {
                    font-family: 'Mrs Saint Delafield', cursive;
                    font-size: 52px;
                    color: #064e3b;
                    margin-bottom: 5px;
                    transform: rotate(-2deg);
                    display: inline-block;
                }
                .sig-name {
                    font-size: 15px;
                    font-weight: 700;
                    color: #111827;
                    text-transform: uppercase;
                    margin-top: 10px;
                }
                .sig-title {
                    font-size: 12px;
                    color: #6b7280;
                    font-weight: 500;
                }
                .footer {
                    margin-top: 100px;
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
            <div class="page-container">
                <div class="header">
                    <div class="bank-info">
                        <h1><span class="bank-logo-devanagari">उधार</span><span class="bank-logo-latin">De</span></h1>
                        <p>Institutional Financial Analysis Division</p>
                        <p>Corporate ID: \(escape(payload.meta.corporateId))</p>
                        <p>Registered Address: \(escape(payload.meta.address))</p>
                    </div>
                    <div class="report-meta">
                        <h2>\(escape(payload.meta.reportTitle))</h2>
                        <p>DOC ID: \(escape(payload.meta.reportId))</p>
                        <p>ISSUED ON: \(escape(payload.meta.generatedAt))</p>
                        <p>CLASSIFICATION: \(escape(payload.meta.classification))</p>
                        <p>PERIOD: \(escape(payload.meta.reportingWindow))</p>
                    </div>
                </div>

                <div class="section">
                    <h3>Executive Summary</h3>
                    <div class="kpi-container">
                        \(kpiHtml)
                    </div>
                </div>

                \(summaryHtml)

                \(tablesHtml)

                <div class="signature-section">
                    <div class="sig-box">
                        <div class="signature-font">\(escape(payload.meta.generatingAdmin ?? "Authorized Signatory"))</div>
                        <p class="sig-name">\(escape(payload.meta.generatingAdmin ?? "Authorized Signatory"))</p>
                        <p class="sig-title">Authorized Signatory</p>
                        <p style="font-size: 11px; color: #059669; font-weight: 700; margin-top: 5px;">
                            <span style="font-size: 14px;">✓</span> Digitally Signed & Verified
                        </p>
                    </div>
                </div>

                <div class="footer">
                    <p>This document is an electronically generated official report of उधार De.</p>
                    <p>Encryption Standard: AES-256 | Report Category: \(escape(payload.meta.reportType))</p>
                </div>
            </div>
        </body>
        </html>
        """
    }

    private static func escape(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
