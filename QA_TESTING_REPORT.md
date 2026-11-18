# FixWise — Final Quality Assurance & Release Verification Report

**Project**: FixWise — AI-Based Fault Diagnosis and Decision Support Mobile Application  
**Target Platform**: Android (Flutter 3.35.3 / Dart 3.9.2 / Material 3) + Python 3.12 FastAPI / SQLAlchemy 2.0 / MySQL 8 / scikit-learn Backend  
**Release Version**: `1.0.0+1` (`com.fixwise.fixwise`)  
**QA Verification Date**: 2026-11-18  

---

## 1. Automated Verification Summary

| Suite / Command | Scope | Result |
| --- | --- | --- |
| `flutter clean && flutter pub get` | Clean workspace dependency resolution | **PASS** |
| `flutter analyze` | Full Dart static analysis & lints across `lib/` and `test/` | **PASS (0 issues)** |
| `flutter test` | 28 unit & widget tests across 8 test suites | **PASS (28/28)** |
| `backend\.venv\Scripts\pytest -v` | 14 backend API, ML contract, Decision Support, ORM, JWT & security tests | **PASS (14/14)** |
| Android Release APK (`flutter build apk --release`) | R8-minified, release-signed APK (no debug signing fallback) | **PASS** — `build/app/outputs/flutter-apk/app-release.apk` (`52.2 MB`, `54,764,614` bytes), verified via `apksigner` (`CN=FixWise Capstone`, SHA-256 `fd33641b...16c00e`), icon fonts tree-shaken by 97.9%–99.9% |

### Flutter Test Suites Executed (`28/28 Passed`)
1. `test/widget_test.dart` — Design system palette/typography, Splash (`#F5F7F7`), 3-step Onboarding, GoRouter auth guards, 6-digit OTP & expiry, core components, real auth non-fabrication, ML non-fabrication, validators.
2. `test/dashboard_navigation_test.dart` — Personalized greeting, primary CTA, quick access, empty state & latest-3 real records on compact (`360x740`), standard (`412x915`), and tablet (`840x1080`) viewports, plus error retry.
3. `test/fault_reporting_workflow_test.dart` — Guided 4-step workflow validation, state preservation across steps, duplicate submission blocking, and backend failure retry.
4. `test/diagnosis_results_test.dart` — Calibrated-only confidence display, ranked alternative faults, diagnostic evidence, rule-based severity, uncertainty disclaimer, and model-pending recovery UI.
5. `test/recommendations_decision_support_test.dart` — Safe plan with unchecked actionable checkboxes, dangerous-fault safety banner with zero DIY checkboxes, and diagnosis-linked feedback persistence.
6. `test/history_feedback_profile_test.dart` — Paginated history search/severity/sort + Load More, structured feedback Q1/Q2 options + controlled updates, Profile Edit/Legal/Logout flows.
7. `test/app_config_security_test.dart` — Development vs Production URL validation blocking `localhost`, `10.0.2.2`, and cleartext `http://` in release builds.
8. `test/qa_release_verification_test.dart` — Complete Error Recovery Matrix, compact `320x640` auth forms, failed feedback recovery, Dark Mode (`AppTheme.dark`) rendering, and 120-record paginated history performance.

### Backend Pytest Suites Executed (`14/14 Passed`)
1. `backend/tests/test_diagnosis_api.py` — Health check, `401` unauthenticated guard, `503 MODEL_INTEGRATION_PENDING` when untrained, `422` validation, verified scikit-learn fixture inference, server-side critical severity override, duplicate `(user_id, report_id)` protection, SQLAlchemy persistence.
2. `backend/tests/test_decision_support.py` — Safe vs Dangerous severity plans, reviewed KB enforcement (blocks draft & hazardous DIY instructions), Bayesian non-fabrication guard, ownership-checked feedback saving.
3. `backend/tests/test_history_feedback_isolation.py` — Strict JWT per-user isolation (spoofed `X-User-Id` rejected with `401`), cross-user `404` protection, search/severity/sort/pagination, duplicate-free feedback updates.
4. `backend/tests/test_full_backend_security.py` — Salted `scrypt` password hashing, duplicate email `409`, refresh token rotation & logout `jti` revocation, OTP send/verify/expiry (`410`) & password reset, user-scoped device CRUD, self-role escalation `403` guard, RBAC admin enforcement, sliding-window rate limiting (`429`), HTTPS enforcement (`403` + HSTS), production config guards (blocks SQLite, missing JWT secret, wildcard CORS).

---

## 2. UI & Responsive QA Findings & Fixes Applied

| Area | Verification Result | Defects Found & Resolved During QA |
| --- | --- | --- |
| Brand Palette & Typography | Exact FixWise tokens (`#123B46`, `#176B68`, `#F5F7F7`, `#FFFFFF`, `#172B32`, `#66767B`, `#E3E9E9`, `#AAB5B8`, Safe `#27845B`, Warning `#C58A27`, Dangerous `#C74747`, Info `#3978AD`) + bundled Inter TTF fonts with Roboto fallback | Verified via automated design-system assertions |
| Small-Screen Portrait (`320x640`, `360x740`) | Zero `RenderFlex` overflows across Login, Register, Forgot Password, Dashboard, Fault Reporting, Results, Recommendations, History, Feedback, and Profile | **Fixed**: Wrapped `StatusBadge` text in `Flexible` with `TextOverflow.ellipsis` (`lib/core/widgets/status_badge.dart`) and replaced single-line `StatusBadge` error display in `FeedbackScreen` with a wrapping error banner (`lib/features/feedback/presentation/screens/feedback_screen.dart`) |
| Dark Mode (`AppTheme.dark`) | Verified Dashboard, History, and Profile in `ThemeMode.dark` with proper surface contrast and zero overflow | Verified in `test/qa_release_verification_test.dart` |
| Keyboard & Scrolling | `adjustResize` enabled in `AndroidManifest.xml`; scrollable forms across auth, fault reporting, and feedback | Verified via widget tests |
| Invalid Error Code Validation | Added `Validators.optionalErrorCode` rejecting control/HTML/injection characters and >64-char inputs inline in Step 3 | **Fixed**: Added validator to `lib/core/utilities/validators.dart` and wired into `step_additional_info.dart` |

---

## 3. Error Handling & Recovery Verification

| Failure Scenario | Observed Behavior & Recovery Action | Status |
| --- | --- | --- |
| Internet disconnected | `ErrorMapper` maps `DioExceptionType.connectionError` -> `NetworkFailure (CONNECTION_ERROR)` with clear message & Retry CTA | **Verified** |
| Backend unavailable | Returns `ServiceUnavailableException` / `ModelNotIntegratedFailure` without fabricating results; Retry action available | **Verified** |
| Invalid credentials | Backend returns `401 INVALID_CREDENTIALS`; Flutter displays inline auth error banner | **Verified** |
| Expired authentication | Backend returns `401`; `ApiClient` triggers `onSessionExpired` callback, clears tokens, redirects to Login | **Verified** |
| Invalid / Expired OTP | Backend returns `400 INVALID_OTP` / `410 OTP_EXPIRED`; Flutter shows clear error and Resend Code action | **Verified** |
| Empty form submission | Inline form validation errors block submission on Login, Register, Forgot Password, and Fault Reporting | **Verified** |
| Invalid error code | Inline validation rejects disallowed characters / oversized error codes before submission | **Verified** |
| Missing ML model | Backend honestly returns `503 MODEL_INTEGRATION_PENDING`; Flutter shows status screen with Retry & Back options | **Verified** |
| Diagnosis timeout | `ErrorMapper` maps `DioExceptionType.receiveTimeout` -> `NetworkFailure (TIMEOUT)` with Retry | **Verified** |
| Empty history | Displays exact empty state (`"No diagnosis records available."`) + `"Start Diagnosis"` CTA | **Verified** |
| Failed feedback submission | Displays wrapping error banner, preserves user's selected ratings and comment text, allows immediate retry | **Verified** |

---

## 4. Performance Review

- **Asset Optimization**: Bundled assets total ~964 KB (3 Inter TTF weights + 11 KB JSON diagnostic catalog; vector Lucide icons & custom FixWise mark, zero heavy raster PNG/JPG bloat).
- **Large History Lists**: Upgraded `HistoryScreen` (`lib/features/history/presentation/screens/history_screen.dart`) from eager list spreading to `CustomScrollView` + lazy `SliverList.builder` backed by 20-record SQLite/API pagination (`Load More Records`). Verified with 120 records in `qa_release_verification_test.dart`.
- **Android Release Optimization**: Enabled R8 code minification (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`) with dedicated `android/app/proguard-rules.pro`.

---

## 5. Security Review

- **Secrets & Credentials**: Static scan confirmed zero hardcoded API keys, JWT secrets, DB passwords, or plaintext passwords in `lib/` and `backend/app/`. `.gitignore` excludes `android/key.properties`, `*.jks`, `*.keystore`, `backend/.env`, and `backend/data/*.db`.
- **Password & OTP Hashing**: Salted `scrypt` (`N=16384, r=8, p=1`) + constant-time `hmac.compare_digest` in `backend/app/security.py`.
- **Client Token Storage**: Tokens stored exclusively in `FlutterSecureStorage` (Android EncryptedSharedPreferences/Keystore); `android:allowBackup="false"` set in `AndroidManifest.xml`.
- **Transport Security**: `android:usesCleartextTraffic="false"` enforced in main `AndroidManifest.xml` (cleartext enabled ONLY in `android/app/src/debug/AndroidManifest.xml`), `AppConfig.validateApiBaseUrl` blocks `localhost` and `http://` in release builds, and backend `FIXWISE_ENFORCE_HTTPS=true` enforces HTTPS + HSTS.
- **Authorization & Isolation**: Removed spoofable `X-User-Id` header from `ApiClient`; all protected backend routes derive user identity strictly from verified HS256 JWT `sub` claims with `jti` revocation, ownership scoping (`404` on cross-user access), RBAC (`403`), and sliding-window rate limiting (`429`).
- **Input Validation & SQL Safety**: Strict Pydantic v2 validation/sanitization + 100% SQLAlchemy 2.0 parameterized queries (zero raw SQL string interpolation).
- **Production Logging**: Backend error handlers log tracebacks server-side only and never return stack traces or internal paths in API responses; Flutter uses `kDebugMode`-gated `debugPrint` only.

---

## 6. Feature Completion Checklist (Honest Status)

| # | Feature | Status | Evidence / Notes |
| --- | --- | --- | --- |
| 1 | Splash screen (`#F5F7F7`, logo, subtitle) | **Fully Working** | Tested in `widget_test.dart` |
| 2 | 3-step Onboarding (Skip, Next, indicators, Get Started) | **Fully Working** | Tested in `widget_test.dart` |
| 3 | User Registration (strong password, scrypt, duplicate `409`) | **Fully Working** | Tested in Flutter & `test_full_backend_security.py` |
| 4 | Login & Session Persistence (JWT access/refresh, Remember Me) | **Fully Working** | Tested in Flutter & `test_full_backend_security.py` |
| 5 | Email OTP Verification (server-generated hashed 6-digit OTP, expiry) | **Partially Implemented** | Backend API, hashing, expiry (`410`), verification & Flutter 6-digit UI are **fully tested**; production SMTP/email provider credentials must be wired to `otp_dispatcher` in deployment |
| 6 | Forgot & Reset Password | **Partially Implemented** | End-to-end backend + Flutter UI flow tested; relies on production `otp_dispatcher` SMTP configuration to deliver reset emails |
| 7 | Home Dashboard & Bottom Navigation | **Fully Working** | Tested across compact, standard, tablet, and dark mode |
| 8 | Device Selection (catalog-driven) | **Fully Working** | Tested in `fault_reporting_workflow_test.dart` + `/api/v1/catalog/devices` |
| 9 | Symptom Selection (search, categories, multi-select) | **Fully Working** | Tested in `fault_reporting_workflow_test.dart` |
| 10 | Additional Information (validated error code, onset, context) | **Fully Working** | Tested in `fault_reporting_workflow_test.dart` + `qa_release_verification_test.dart` |
| 11 | Review & Duplicate-Protected Submission | **Fully Working** | Tested in Flutter & `test_diagnosis_api.py` |
| 12 | ML Fault Diagnosis Pipeline (`DecisionTree` / `RandomForest`) | **Pending Real Dataset Artifact** | Full training script (`backend/ml/train.py`), preprocessing parity, inference API, and Flutter UI are **fully implemented & verified on isolated test fixtures**; intentionally returns `503 MODEL_INTEGRATION_PENDING` until trained on a real labeled fault dataset CSV (no fake/synthetic model trained) |
| 13 | Alternative Fault Display & Calibrated Confidence | **Fully Working** | Tested in `diagnosis_results_test.dart` & `test_diagnosis_api.py` |
| 14 | Server-Side Severity Classification (`Safe` / `Medium` / `High` / `Critical`) | **Fully Working** | Tested in `test_diagnosis_api.py` & `test_decision_support.py` |
| 15 | Decision Support Recommendation Retrieval & Reviewed KB | **Fully Working** | Tested in `test_decision_support.py` & `recommendations_decision_support_test.dart` |
| 16 | Safety Warnings & Dangerous-Fault Guardrails | **Fully Working** | Tested in `test_decision_support.py` & `recommendations_decision_support_test.dart` |
| 17 | Diagnosis History (search, severity/date filter, sort, pagination) | **Fully Working** | Tested in `history_feedback_profile_test.dart`, `qa_release_verification_test.dart`, and `test_history_feedback_isolation.py` |
| 18 | Diagnosis Details (preserved snapshot, never recalculated) | **Fully Working** | Tested in `diagnosis_results_test.dart` & `test_history_feedback_isolation.py` |
| 19 | Feedback Submission & Controlled Duplicate-Free Updates | **Fully Working** | Tested in `history_feedback_profile_test.dart`, `qa_release_verification_test.dart`, and `test_history_feedback_isolation.py` |
| 20 | User Profile (Edit Profile, Change Password, Legal, About) | **Fully Working** | Tested in `history_feedback_profile_test.dart` & `test_full_backend_security.py` |
| 21 | Logout & Token Revocation (`RevokedTokenORM`) | **Fully Working** | Tested in `test_full_backend_security.py` & Flutter auth controller |
| 22 | MySQL 8 Relational Schema & SQLAlchemy 2.0 ORM | **Fully Working** | DDL (`backend/schema_mysql.sql`) & ORM (`backend/app/db_models.py`) verified via SQLAlchemy 2.0 test suite; requires live MySQL 8 server credentials in `.env` for production deployment |
| 23 | Optional Bayesian Decision Module | **Pending Real Empirical Priors** | Isolated module (`backend/app/probabilistic_decision.py`) implemented and verified to refuse fabricated priors/costs |
