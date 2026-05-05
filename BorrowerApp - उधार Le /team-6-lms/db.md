// Database Schema for Loan Management System iOS App

Table users {
  id integer [primary key]
  full_name varchar
  email varchar [unique]
  phone varchar
  password_hash varchar
  role varchar // enum: 'Admin', 'Manager', 'Officer', 'Borrower'
  is_2fa_enabled boolean
  created_at timestamp
}

Table borrower_profiles {
  id integer [primary key]
  user_id integer
  kyc_status varchar // enum: 'Pending', 'Verified', 'Rejected'
  credit_score integer
  address text
  declared_monthly_income decimal // Added for generic budgeting math
  income_details text // Stores qualitative info like employer name
}

Table account_status {
  id integer [primary key]
  borrower_id integer
  // Statuses: timely payer, defaulter>2months, defaulter>6months
  paying_status varchar 
  last_updated timestamp
}

Table loan_products {
  id integer [primary key]
  name varchar
  interest_rate decimal
  processing_fee decimal
  eligibility_criteria text
  min_tenure integer
  max_tenure integer
}

Table loan_applications {
  id integer [primary key]
  borrower_id integer
  product_id integer
  officer_id integer
  manager_id integer
  amount decimal
  tenure integer
  // Statuses: Submitted, Under Review, Recommended, Approved, Rejected, Disbursed
  status varchar 
  is_high_value boolean 
  
  // Snapshots to lock in the risk profile at application time
  credit_score_at_application integer 
  internal_risk_band varchar // e.g., 'Low Risk', 'Medium Risk', 'High Risk'
  
  created_at timestamp
}

// Independent Document Table (borrowers upload once, attach when needed)
Table documents {
  id integer [primary key]
  borrower_id integer 
  doc_type varchar // 'ID', 'Address', 'Income'
  file_url varchar
  uploaded_at timestamp
}

// Junction Table to attach saved documents to specific applications
Table application_documents {
  id integer [primary key]
  application_id integer
  document_id integer
  status varchar // 'Pending', 'Verified', 'Rejected'
  remarks text
  attached_at timestamp
}

Table active_loans {
  id integer [primary key]
  application_id integer
  disbursed_at timestamp
  outstanding_balance decimal
  interest_breakdown text
  is_npa boolean 
  sanction_letter_url varchar
}

Table emi_schedule {
  id integer [primary key]
  loan_id integer
  due_date date
  amount decimal
  status varchar // 'Paid', 'Upcoming', 'Overdue'
  paid_at timestamp
}

// Stores the output of your Core ML predictive model for EMIs
Table emi_predictions {
  id integer [primary key]
  emi_id integer
  prediction_date timestamp
  default_probability decimal // e.g., 0.85 (85% chance of missing EMI)
  risk_factors text 
  is_alert_triggered boolean
}

// Stores the actionable insights/budgeting plans (e.g. 50/30/20 breakdown)
Table financial_insights {
  id integer [primary key]
  borrower_id integer
  prediction_id integer // Optional link back to the prediction that triggered this
  insight_type varchar // 'Actionable_Alert', '50_30_20_Breakdown'
  content text 
  generated_at timestamp
  is_acknowledged boolean 
}

// Push notifications audit trail
Table notifications {
  id integer [primary key]
  user_id integer
  notification_type varchar // 'Predictive_Alert', 'Overdue_Reminder', 'Approval'
  message text
  sent_at timestamp
  is_read boolean
}

Table internal_comments {
  id integer [primary key]
  application_id integer
  author_id integer
  content text
  created_at timestamp
}

Table chat_messages {
  id integer [primary key]
  application_id integer
  sender_id integer
  content text
  timestamp timestamp
}

Table audit_logs {
  id integer [primary key]
  user_id integer 
  action varchar
  timestamp timestamp
  metadata json
}

// ==============================
// RELATIONSHIPS
// ==============================

// Users & Profiles
Ref: users.id < borrower_profiles.user_id
Ref: borrower_profiles.id < account_status.borrower_id

// Applications
Ref: borrower_profiles.id < loan_applications.borrower_id
Ref: users.id < loan_applications.officer_id
Ref: users.id < loan_applications.manager_id
Ref: loan_products.id < loan_applications.product_id

// Document Management
Ref: borrower_profiles.id < documents.borrower_id
Ref: loan_applications.id < application_documents.application_id
Ref: documents.id < application_documents.document_id

// Active Loans & Repayments
Ref: loan_applications.id < active_loans.application_id
Ref: active_loans.id < emi_schedule.loan_id

// AI Predictions & Insights
Ref: emi_schedule.id < emi_predictions.emi_id
Ref: borrower_profiles.id < financial_insights.borrower_id
Ref: emi_predictions.id < financial_insights.prediction_id

// Communications & Audit
Ref: users.id < notifications.user_id
Ref: loan_applications.id < internal_comments.application_id
Ref: loan_applications.id < chat_messages.application_id
Ref: users.id < audit_logs.user_id
