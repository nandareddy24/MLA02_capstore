# FixWise — AI-Based Fault Diagnosis & Decision Support Mobile Application

**FixWise** is a full-stack mobile application and Python ML/Decision-Support backend designed as a final-year capstone project for structured device fault reporting, machine-learning fault classification, safety-aware troubleshooting recommendations, and per-user diagnostic history.

---

## 1. Architecture Overview

```
ML-Capstone/
├── lib/                                  # Flutter 3 / Dart 3 (Material 3, Clean Architecture, Riverpod 3, GoRouter)
│   ├── core/
│   │   ├── config/app_config.dart        # Development vs Production config (blocks localhost/HTTP in release)
│   │   ├── constants/                    # App constants & named routes
│   │   ├── errors/                       # Typed Failure hierarchy & Dio/SQLite ErrorMapper
│   │   ├── network/                      # Dio ApiClient (Bearer JWT) & centralized ApiEndpoints
│   │   ├── routing/                      # GoRouter with authentication & onboarding route guards
│   │   ├── theme/                        # Enterprise FixWise Light & Dark themes (Inter font, exact palette)
│   │   ├── utilities/                    # Validators, responsive breakpoints, date formatters
│   │   └── widgets/                      # Reusable Material 3 enterprise UI components
│   ├── data/
│   │   ├── models/                       # Immutable domain models (User, Device, FaultReport, Diagnosis, Plan, Feedback)
│   │   ├── repositories/                 # Auth, Device, Catalog, FaultReport, Diagnosis & Feedback repositories
│   │   └── services/                     # Local SQLite (v5, user-scoped), Preferences, SecureStorage, API services
│   └── features/
│       ├── onboarding/                   # Splash screen & 3-step onboarding
│       ├── authentication/               # Login, Register, 6-digit OTP verification, Forgot/Reset Password
│       ├── dashboard/                    # Personalized Home Dashboard, Quick Access, Recent Diagnoses, Bottom Nav
│       ├── fault_reporting/              # Guided 4-step Device Selection -> Symptoms -> Context -> Review & Submit
│       ├── diagnosis/                    # ML Diagnosis Results (calibrated confidence, alternatives, evidence, severity)
│       ├── recommendations/              # Safety-aware Recommended Actions (dangerous banners, safe checkboxes)
│       ├── history/                      # Searchable, filterable, sortable, paginated per-user Diagnosis History
│       ├── feedback/                     # Post-diagnosis Relevance/Resolution Feedback (duplicate-safe updates)
│       └── profile/                      # Edit Profile, Change Password, Privacy/Terms/About, Logout
├── assets/
│   ├── data/diagnostic_catalog.json      # Supported device categories & categorized symptom catalog
│   └── fonts/                            # Bundled Inter Regular/Medium/SemiBold TTF fonts (Roboto fallback)
├── android/                              # Android manifest security hardening, R8 rules, release signing config
├── backend/                              # Python FastAPI + SQLAlchemy 2.0 + MySQL 8 + scikit-learn
│   ├── app/
│   │   ├── config.py                     # Env settings + production guards (MySQL, JWT secret, CORS, HTTPS)
│   │   ├── database.py                   # SQLAlchemy 2.0 MySQL connection pool & session dependency
│   │   ├── db_models.py                  # Relational ORM schema (7 tables with FKs & unique constraints)
│   │   ├── security.py                   # Salted scrypt hashing, HS256 JWT + jti revocation, RBAC, rate limiting
│   │   ├── schemas.py                    # Pydantic v2 validation & sanitization
│   │   ├── main.py                       # Modular FastAPI factory, CORS, HTTPS & security middleware
│   │   ├── model_registry.py             # Trained scikit-learn artifact loader (honest 503 if untrained)
│   │   ├── preprocessing.py              # Shared train/serve feature preprocessing pipeline
│   │   ├── severity_rules.py             # Server-side safety & severity classification engine
│   │   ├── knowledge_base.py             # Expert-reviewed fault knowledge base with safety guardrails
│   │   ├── decision_support_service.py   # Separate Decision Support Engine
│   │   ├── probabilistic_decision.py     # Optional Bayesian module (refuses invented priors)
│   │   └── routes/                       # auth_routes, device_routes, diagnosis_routes, feedback_routes
│   ├── data/                             # Reviewed knowledge_base.json & severity_rules.json
│   ├── ml/train.py                       # Decision Tree & Random Forest training script (holdout split)
│   ├── schema_mysql.sql                  # MySQL 8.0 DDL
│   └── tests/                            # Pytest suite (14 tests)
├── test/                                 # Flutter unit & widget test suite (27 tests across 8 suites)
└── QA_TESTING_REPORT.md                  # Full QA verification report & feature completion matrix
```

---

## 2. Database Schema (MySQL 8.0)

Full DDL is provided in [`backend/schema_mysql.sql`](backend/schema_mysql.sql) and mirrored in [`backend/app/db_models.py`](backend/app/db_models.py):

- **`users`**: `id`, `name`, `email` (unique), `password_hash` (salted `scrypt`), `role`, `account_status`, `created_at`
- **`otp_codes`**: `id`, `user_id` (FK -> `users`), `email`, `purpose`, `code_hash` (salted `scrypt`), `expires_at`, `consumed_at`, `created_at`
- **`revoked_tokens`**: `jti` (PK), `user_id` (FK -> `users`), `revoked_at`
- **`devices`**: `id`, `user_id` (FK -> `users`), `category`, `manufacturer`, `model`, `device_age`, `operating_environment`, `created_at`
- **`diagnoses`**: `id`, `report_id`, `user_id` (FK -> `users`), `device_id` (FK -> `devices`), device/symptoms/error_code/alternatives/evidence/uncertainty/plan snapshots, `predicted_fault`, `confidence`, `confidence_is_calibrated`, `severity`, `model_version`, `status`, `created_at` (`UNIQUE(user_id, report_id)`)
- **`recommendations`**: `id`, `diagnosis_id` (FK -> `diagnoses`), `fault_category`, `step_number`, `title`, `recommended_action`, `risk_level`, `is_checkable`, `safety_information`, `review_status`
- **`feedback`**: `id`, `user_id` (FK -> `users`), `diagnosis_id` (FK -> `diagnoses`), `report_id`, `relevance_rating`, `resolution_status`, `was_helpful`, `was_issue_resolved`, `still_needs_professional_assistance`, `comments`, `created_at`, `updated_at` (`UNIQUE(user_id, diagnosis_id)`)

---

## 3. API Documentation

Complete endpoint details and examples are documented in [`backend/README.md`](backend/README.md). Summary:

- **System & Catalog**: `GET /api/v1/health`, `GET /api/v1/catalog/devices`
- **Authentication**: `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`, `GET /api/v1/auth/me`, `PATCH /api/v1/auth/me`, `POST /api/v1/auth/password/change`, `POST /api/v1/auth/otp/send`, `POST /api/v1/auth/otp/verify`, `POST /api/v1/auth/password/forgot`, `POST /api/v1/auth/password/reset`
- **Devices**: `GET /api/v1/devices`, `POST /api/v1/devices`, `GET /api/v1/devices/{device_id}`, `DELETE /api/v1/devices/{device_id}`
- **Diagnosis & Decision Support**: `POST /api/v1/diagnosis/analyze`, `POST /api/v1/decision-support/recommend`, `GET /api/v1/diagnosis/{report_id}/recommendations`
- **History & Feedback**: `GET /api/v1/history`, `GET /api/v1/history/{report_id}`, `POST /api/v1/feedback`, `PUT /api/v1/feedback`
- **Admin (RBAC)**: `GET /api/v1/admin/diagnostics/summary` (`admin` / `reviewer` roles only)

---

## 4. Machine Learning Model Integration

FixWise enforces scientific integrity: **no synthetic or random training data is generated, and no predictions or confidence percentages are hardcoded or fabricated.**

1. Prepare a real labeled fault dataset CSV with columns: `device_category`, `manufacturer`, `device_age`, `operating_environment`, `started_when`, `error_code`, `symptoms` (pipe- or semicolon-delimited), and `fault_category`.
2. Train and evaluate `DecisionTreeClassifier` and `RandomForestClassifier` with a strict held-out train/test split before preprocessing:
   ```powershell
   cd backend
   .\.venv\Scripts\python ml\train.py --dataset path\to\real_fault_dataset.csv
   ```
3. The script writes `backend/artifacts/fixwise_model.joblib` and `backend/artifacts/model_metadata.json` (including held-out test metrics and calibration status).
4. Until a real artifact is placed in `backend/artifacts/`, `POST /api/v1/diagnosis/analyze` honestly returns HTTP `503 MODEL_INTEGRATION_PENDING`, and the Flutter app displays a clear status screen with retry/recovery actions.

---

## 5. Setup & Build Instructions

### Backend Setup (Python 3.12 + MySQL 8)
```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
copy .env.example .env
# Edit .env with your MySQL URL, 32+ char FIXWISE_JWT_SECRET, and CORS origins
.\.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Flutter Development Run (Android Emulator)
```powershell
flutter pub get
flutter run --dart-define=FIXWISE_ENV=development --dart-define=FIXWISE_API_BASE_URL=http://10.0.2.2:8000
```

### Android Release APK Signing & Build
Debug-signed APKs are blocked for release builds by `android/app/build.gradle.kts`, and `lib/core/config/app_config.dart` forbids `localhost` or non-HTTPS URLs in release mode.

1. Generate a production upload keystore (keep it private; `*.jks` and `android/key.properties` are gitignored):
   ```powershell
   keytool -genkey -v -keystore android/app/fixwise-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fixwise
   ```
2. Copy [`android/key.properties.example`](android/key.properties.example) to `android/key.properties` and enter your keystore credentials.
3. Accept Android SDK licenses if prompted (`flutter doctor --android-licenses`).
4. Build the R8-minified, release-signed APK targeting your HTTPS backend:
   ```powershell
   flutter clean
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release --dart-define=FIXWISE_ENV=production --dart-define=FIXWISE_API_BASE_URL=https://api.fixwise.example.com
   ```
5. Output APK location: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 6. Running Automated Tests

- **Flutter Tests**: `flutter analyze && flutter test`
- **Backend Tests**: `cd backend && .\.venv\Scripts\pytest -v`
- **Full QA Report**: See [`QA_TESTING_REPORT.md`](QA_TESTING_REPORT.md).
