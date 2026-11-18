# FixWise Backend — ML Diagnosis, Decision Support & Secure API

Modular FastAPI + SQLAlchemy 2.0 + MySQL 8 + scikit-learn backend serving the FixWise Flutter mobile application.

## 1. Architecture & Modules

```
backend/
├── app/
│   ├── config.py                   # Environment-driven settings & production security guards
│   ├── database.py                 # SQLAlchemy 2.0 engine (MySQL 8 pool + SQLite test support)
│   ├── db_models.py                # Relational ORM models (users, otp_codes, revoked_tokens, devices, diagnoses, recommendations, feedback)
│   ├── security.py                 # Salted scrypt hashing, HS256 JWT + jti revocation, RBAC, sliding-window rate limiter
│   ├── schemas.py                  # Pydantic v2 contracts, strict validation & input sanitization
│   ├── main.py                     # FastAPI factory, CORS, HTTPS enforcement, rate limiting, error handlers
│   ├── model_registry.py           # Trained scikit-learn artifact loader (honest 503 if untrained)
│   ├── preprocessing.py            # Shared train/serve feature preprocessing pipeline
│   ├── severity_rules.py           # Configurable server-side safety & severity classification rules
│   ├── knowledge_base.py           # Reviewed fault knowledge base with safety guardrails
│   ├── decision_support_service.py # Separate Decision Support Engine
│   ├── probabilistic_decision.py   # Optional Bayesian module (refuses invented priors)
│   └── routes/
│       ├── auth_routes.py          # Register, login, refresh, logout, profile, OTP, password reset/change
│       ├── device_routes.py        # User-scoped device CRUD
│       ├── diagnosis_routes.py     # ML analysis, recommendations, history, catalog, admin summary
│       └── feedback_routes.py      # Duplicate-safe diagnosis feedback submission/update
├── data/
│   ├── knowledge_base.json         # Expert-reviewed fault & repair knowledge base
│   └── severity_rules.json         # Configurable safety & severity classification rules
├── ml/
│   └── train.py                    # Decision Tree & Random Forest training script (strict holdout split)
├── tests/                          # Full pytest verification suite
├── schema_mysql.sql                # MySQL 8.0 relational DDL matching ORM tables & constraints
├── .env.example                    # Environment variable template (never commit real secrets)
└── requirements.txt
```

## 2. Database Setup (MySQL 8)

1. Create the MySQL database and apply the schema:
   ```sql
   CREATE DATABASE fixwise CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
   ```bash
   mysql -u fixwise_app -p fixwise < backend/schema_mysql.sql
   ```
2. Copy `backend/.env.example` to `backend/.env` and set your environment variables:
   - `FIXWISE_ENV=production` (or `development` locally)
   - `FIXWISE_DATABASE_URL=mysql+pymysql://<user>:<password>@<host>:3306/fixwise?charset=utf8mb4`
   - `FIXWISE_JWT_SECRET=<at least 32 cryptographically random bytes>`
   - `FIXWISE_CORS_ORIGINS=https://app.fixwise.example.com`
   - `FIXWISE_ENFORCE_HTTPS=true`

> **Production Safety Guards**: When `FIXWISE_ENV=production`, startup intentionally fails if `FIXWISE_JWT_SECRET` is missing/short, if `FIXWISE_DATABASE_URL` points to SQLite instead of MySQL, or if wildcard CORS (`*`) is configured.

## 3. Running Locally (Isolated Virtual Environment)

```powershell
cd backend
.\.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Training a Real ML Model Artifact

FixWise never trains on synthetic/random data and never fabricates predictions. When you have a real labeled dataset CSV, run:

```powershell
cd backend
.\.venv\Scripts\python ml\train.py --dataset path\to\real_fault_dataset.csv
```

Until a verified artifact exists at `backend/artifacts/fixwise_model.joblib`, `POST /api/v1/diagnosis/analyze` honestly returns HTTP `503 MODEL_INTEGRATION_PENDING`.

## 4. API Endpoints

| Group | Method & Path | Auth | Purpose |
| --- | --- | --- | --- |
| System | `GET /api/v1/health` | Public | Service, DB dialect & ML model status |
| Catalog | `GET /api/v1/catalog/devices` | Public | Supported device categories & symptoms |
| Auth | `POST /api/v1/auth/register` | Public | Create user (salted scrypt hash) + issue JWTs |
| Auth | `POST /api/v1/auth/login` | Public | Verify credentials + issue access & refresh JWTs |
| Auth | `POST /api/v1/auth/refresh` | Public | Rotate refresh token & issue new access token |
| Auth | `POST /api/v1/auth/logout` | Bearer | Revoke active access & refresh JWT `jti` |
| Auth | `GET / PATCH /api/v1/auth/me` | Bearer | Fetch / update profile (blocks role escalation) |
| Auth | `POST /api/v1/auth/password/change` | Bearer | Verify current password & set strong password |
| Auth | `POST /api/v1/auth/otp/send`, `/otp/verify` | Public | Server-generated hashed 6-digit OTP + expiry |
| Auth | `POST /api/v1/auth/password/forgot`, `/reset` | Public | Non-enumerating reset OTP + password reset |
| Devices | `GET / POST /api/v1/devices`, `GET / DELETE /api/v1/devices/{id}` | Bearer | User-scoped device management |
| Diagnosis | `POST /api/v1/diagnosis/analyze` | Bearer | ML inference + server-side severity + DB persistence |
| Decision | `POST /api/v1/decision-support/recommend` | Bearer | Reviewed KB recommendations & safety plan |
| Decision | `GET /api/v1/diagnosis/{report_id}/recommendations` | Bearer | Fetch preserved recommendations for user |
| History | `GET /api/v1/history`, `GET /api/v1/history/{report_id}` | Bearer | Paginated search/filter/sort & preserved snapshot |
| Feedback | `POST / PUT /api/v1/feedback` | Bearer | Duplicate-safe feedback linked to owned diagnosis |
| Admin | `GET /api/v1/admin/diagnostics/summary` | Bearer (`admin`/`reviewer`) | Role-protected aggregate metrics |

## 5. Flutter Environment Configuration

Never hardcode `localhost` in release APKs. `lib/core/config/app_config.dart` enforces HTTPS and blocks localhost/emulator hosts in production/release builds:

- **Development (Android Emulator)**:
  ```bash
  flutter run --dart-define=FIXWISE_ENV=development --dart-define=FIXWISE_API_BASE_URL=http://10.0.2.2:8000
  ```
- **Production Release APK**:
  ```bash
  flutter build apk --release --dart-define=FIXWISE_ENV=production --dart-define=FIXWISE_API_BASE_URL=https://api.fixwise.example.com
  ```

## 6. Running Tests

```powershell
cd backend
.\.venv\Scripts\pytest -v
```
