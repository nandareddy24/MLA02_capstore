-- FixWise MySQL 8.0 Reference Schema
-- Matches SQLAlchemy 2.0 ORM models in backend/app/db_models.py

CREATE DATABASE IF NOT EXISTS fixwise
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fixwise;

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(64) NOT NULL DEFAULT 'technician',
  account_status VARCHAR(32) NOT NULL DEFAULT 'active',
  created_at DATETIME(6) NOT NULL,
  INDEX idx_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS otp_codes (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NULL,
  email VARCHAR(255) NOT NULL,
  purpose VARCHAR(32) NOT NULL,
  code_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  consumed_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_otp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_otp_email_purpose (email, purpose)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS revoked_tokens (
  jti VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  revoked_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_revoked_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS devices (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  category VARCHAR(64) NOT NULL,
  manufacturer VARCHAR(80) NOT NULL DEFAULT '',
  model VARCHAR(100) NOT NULL DEFAULT '',
  device_age VARCHAR(64) NULL,
  operating_environment VARCHAR(64) NULL,
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_devices_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS diagnoses (
  id VARCHAR(64) PRIMARY KEY,
  report_id VARCHAR(120) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  device_id VARCHAR(64) NULL,
  device_category VARCHAR(64) NOT NULL,
  device_name VARCHAR(160) NOT NULL,
  device_details_json LONGTEXT NOT NULL,
  reported_symptoms_json LONGTEXT NOT NULL,
  error_code VARCHAR(64) NULL,
  predicted_fault VARCHAR(160) NOT NULL,
  alternative_faults_json LONGTEXT NOT NULL,
  confidence DOUBLE NULL,
  confidence_is_calibrated TINYINT(1) NOT NULL DEFAULT 0,
  severity VARCHAR(32) NOT NULL,
  severity_rationale TEXT NOT NULL,
  evidence_json LONGTEXT NOT NULL,
  uncertainty_json LONGTEXT NOT NULL,
  decision_support_plan_json LONGTEXT NULL,
  model_version VARCHAR(64) NOT NULL,
  algorithm VARCHAR(80) NOT NULL DEFAULT 'unknown',
  processing_time_ms DOUBLE NOT NULL DEFAULT 0,
  status VARCHAR(32) NOT NULL DEFAULT 'diagnosed',
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT uq_diagnoses_user_report UNIQUE (user_id, report_id),
  CONSTRAINT fk_diagnoses_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_diagnoses_device FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE SET NULL,
  INDEX idx_diagnoses_user_created (user_id, created_at),
  INDEX idx_diagnoses_user_severity (user_id, severity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recommendations (
  id VARCHAR(64) PRIMARY KEY,
  diagnosis_id VARCHAR(64) NOT NULL,
  fault_category VARCHAR(160) NOT NULL,
  step_number INT NOT NULL,
  title VARCHAR(200) NOT NULL,
  recommended_action TEXT NOT NULL,
  risk_level VARCHAR(32) NOT NULL DEFAULT 'caution',
  is_checkable TINYINT(1) NOT NULL DEFAULT 0,
  safety_information TEXT NULL,
  review_status VARCHAR(32) NOT NULL DEFAULT 'reviewed',
  CONSTRAINT fk_recommendations_diagnosis FOREIGN KEY (diagnosis_id) REFERENCES diagnoses(id) ON DELETE CASCADE,
  INDEX idx_recommendations_diagnosis (diagnosis_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS feedback (
  id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  diagnosis_id VARCHAR(64) NOT NULL,
  report_id VARCHAR(120) NOT NULL,
  relevance_rating VARCHAR(32) NOT NULL,
  resolution_status VARCHAR(32) NOT NULL,
  was_helpful TINYINT(1) NOT NULL DEFAULT 1,
  was_issue_resolved TINYINT(1) NOT NULL DEFAULT 0,
  still_needs_professional_assistance TINYINT(1) NOT NULL DEFAULT 0,
  comments TEXT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uq_feedback_user_diagnosis UNIQUE (user_id, diagnosis_id),
  CONSTRAINT fk_feedback_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_feedback_diagnosis FOREIGN KEY (diagnosis_id) REFERENCES diagnoses(id) ON DELETE CASCADE,
  INDEX idx_feedback_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
