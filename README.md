# Loan Management System (LMS)

A comprehensive, full-stack fintech solution consisting of two native iOS applications designed to streamline the loan lifecycle for both financial institutions and borrowers. Developed as part of an intensive internship program at **Infosys Mysore**, this project demonstrates a modern approach to digital lending, emphasizing security, automated risk assessment, and seamless user experience.

---

## 📱 Applications Overview

### 1. Udhar De (Bank Operations App)
The internal platform for bank staff, including Admins, Managers, and Loan Officers, to manage the loan portfolio and make data-driven decisions.
- **Intelligent Risk Assessment:** Features a custom-built **AHP (Analytic Hierarchy Process) Engine** to evaluate applicants based on multiple weighted criteria (Repayment Capacity, Credit History, Employment Stability, etc.).
- **Managerial Dashboards:** Real-time analytics and metrics tracking for loan performance, overdue accounts, and staff productivity.
- **Compliance & Auditing:** Integrated **Audit Trail** and system-wide logging to ensure transparency in every transaction and decision.
- **Workflow Automation:** Automated generation of Sanction Letters (PDF/HTML) and bulk staff invitation systems.

### 2. Udhar Le (Borrower Customer App)
The customer-facing application providing a frictionless onboarding and loan management experience for borrowers.
- **Automated KYC:** Built-in **OCR (Optical Character Recognition)** using Apple's VisionKit to instantly verify PAN and Aadhaar documents, reducing manual entry errors.
- **Loan Lifecycle Management:** Simple, multi-step loan application process, real-time status tracking, and EMI schedule management.
- **Secure Communication:** Real-time chat interface for direct communication with assigned Loan Officers.
- **Voice Integration:** Integrated **Siri Intents** to allow borrowers to check loan status and EMI details using voice commands.
- **Enterprise-Grade Security:** Implemented **Screenshot Protection**, **Jailbreak Detection**, and secure data handling to protect sensitive financial information.
- **Multi-lingual Support:** Localized in English, Hindi, and Kannada to reach a broader demographic.

---

## 🛠 Technical Stack

- **Frontend:** Swift, SwiftUI (Native iOS)
- **Backend:** Supabase (Authentication, PostgreSQL Database, Storage, Edge Functions)
- **AI/ML & Vision:** VisionKit (OCR for KYC), Custom AHP Mathematical Model
- **Integration:** SiriKit (Siri Intents)
- **Reporting:** PDFKit, HTML/CSS Templates for automated document generation
- **Architecture:** MVVM (Model-View-ViewModel)

---

## 🚀 Development Methodology

This project was developed by a team of 10 interns following **Agile SCRUM** practices. 
- **Project Management:** Leveraged **JIRA** for task tracking, sprint planning, and backlog grooming.
- **Collaboration:** Focused on cross-functional teamwork between frontend and backend workflows to deliver a synchronized two-app ecosystem.
- **Version Control:** Managed through Git with structured branching strategies for feature development and bug fixes.

---

## 👨‍💻 Key Contributions & Learnings

- Designed and implemented a robust **Analytic Hierarchy Process (AHP)** engine to quantify credit risk.
- Developed a high-performance **OCR-based KYC** system using VisionKit, significantly improving user onboarding speed.
- Integrated **Supabase** for real-time data synchronization and secure authentication.
- Focused on building accessible and localized user interfaces for a diverse user base.
