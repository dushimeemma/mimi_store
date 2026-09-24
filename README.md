# Mimi Store — production platform

Full-stack ecommerce implementation for Android, iOS and web.

- `lib/`: responsive Flutter customer and staff application
- `backend/`: NestJS API with PostgreSQL, JWT sessions and MTN MoMo Collections
- `docker-compose.yml`: local/VM deployment for the API and database
- `docs/`: platform setup, production checklist and API notes

## Implemented production features

- Public product catalogue; prices and stock come from PostgreSQL
- Dynamic categories, product search, live stock and out-of-stock controls
- Secure email/password registration and sign-in
- Short-lived access tokens, rotated refresh tokens and secure device storage
- Backend-enforced roles: Customer, Super Admin, Admin and Motor Driver
- Server-calculated order totals and transactional stock reservation
- Manual address or device GPS coordinates at checkout
- Configurable Mobile Money number and delivery fee
- Manual MTN MoMo USSD checkout with a safe desktop/web fallback
- Customer “payment sent” notifications and Admin/Super Admin approval or rejection
- Optional MTN MoMo `requestToPay` and provider-verified payment status for future reactivation
- Product, category, SKU, price, visibility and inventory management
- Inventory movement history and automatic stock restoration after cancellation
- Persistent order details, driver assignment and controlled delivery transitions
- User roles, activation/deactivation and refresh-token revocation
- Payment ledger, pending-payment reconciliation and delivery board
- Live dashboard metrics, business settings and immutable audit history
- Responsive phone, tablet, web and desktop interfaces
- Cloudinary-backed product image upload and replacement cleanup
- Durable email and WhatsApp notifications for customer and staff operations
- International country-code phone inputs for accounts, checkout and settings
- Persisted System, Light and Dark appearance modes
- Rate limiting, DTO validation, Helmet headers and explicit CORS configuration

## 1. Configure and start the API

Create environment files. Never commit either file:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
```

Replace every `replace-...` value. The database password in `.env` is used by Docker. Set two different random JWT secrets of at least 32 characters in `backend/.env`.

For local development, keep `MOMO_ENABLED=false`. Then run:

```bash
docker compose up --build
```

The API health check is available at `http://localhost:8080/api/v1/health`. In development, Swagger documentation is available at `http://localhost:8080/docs`.

The migration service creates the schema once and seeds the Super Admin plus initial products. Change the bootstrap password immediately after the first controlled deployment. Re-running the seed does not overwrite an existing administrator.

Cloudinary, SMTP email and Meta WhatsApp integrations are optional and disabled until their environment variables are configured. After deploying this release, run `node dist/migrate.js` so the product media metadata and durable notification outbox tables are created. See `docs/NOTIFICATIONS_AND_MEDIA.md` for the exact Render configuration.

## 2. Generate Flutter platform shells

Install the current stable Flutter SDK, then run once from this directory:

```bash
flutter create --platforms=android,ios,web --project-name mimi_store .
flutter pub get
```

Apply the required Android/iOS location settings from `docs/PLATFORM_SETUP.md`.

## 3. Run Flutter

After replacing an older source package, clear generated build state first:

```bash
flutter clean
flutter pub get
```

Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

iOS simulator:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

Flutter web uses a fixed development port so it matches CORS configuration:

```bash
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

For a physical phone, use the API's HTTPS URL. Plain HTTP is intentionally not recommended for a production build.

## 4. Release builds

```bash
flutter analyze
flutter test
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.your-domain.rw/api/v1
flutter build ipa --release --dart-define=API_BASE_URL=https://api.your-domain.rw/api/v1
flutter build web --release --dart-define=API_BASE_URL=https://api.your-domain.rw/api/v1
```

## 5. Manual payment workflow

Manual payment is the default. On Android or iOS, checkout attempts to open the configured USSD transfer code. If the device cannot open phone dialing—or the app is running on web/desktop—it displays copyable instructions for completing payment on a phone. The customer then taps **I have paid**, optionally enters the MoMo transaction reference, and an Admin or Super Admin verifies the business account before approving or rejecting the notification.

Mobile operating systems do not provide a reliable cross-platform “SIM installed” check. Mimi Store therefore detects a supported mobile platform, attempts the external dialer, and always falls back to the instruction dialog. The recipient number, amount and approval state remain server-controlled.

See `docs/MANUAL_PAYMENTS.md` for the complete state flow.

## 6. Enable MTN MoMo later

Regenerate any key that has appeared in a screenshot, chat, source file or log. Enter approved production credentials only in the backend secret store, set the public HTTPS callback URL, verify that MTN can reach it, then change `MOMO_ENABLED=true`. In the Super Admin settings page, select `MTN MoMo API` only after credentials are installed. The server initiates payment and independently queries MTN before changing an order to `payment_confirmed`; the Flutter app cannot mark an API payment successful by itself.

See `docs/FEATURES_AND_ROLES.md` for the complete feature and permission matrix.

## Important release boundary

The code is production-oriented and the NestJS application compiles successfully. A real production release still requires your organization-specific secrets, HTTPS domains, MTN approval, signing certificates, privacy policy, store listings and end-to-end tests against the live payment environment. See `docs/PRODUCTION_CHECKLIST.md` before publishing.
