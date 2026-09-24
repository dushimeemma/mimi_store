# Production release checklist

## Infrastructure

- Host PostgreSQL with encrypted backups, point-in-time recovery and restricted network access.
- Run the API behind HTTPS with a trusted certificate and reverse proxy or managed load balancer.
- Set `NODE_ENV=production`, strong independent JWT secrets and an exact `CORS_ORIGINS` allowlist.
- Keep `.env`, signing keys and MoMo credentials in a secrets manager.
- Configure centralized logs, uptime checks, error alerts and database monitoring.
- Run migrations before each deployment and retain a tested rollback plan.
- Configure Cloudinary credentials only in the API secret store and test upload, replacement and deletion.
- Configure SMTP and verify the sender domain before enabling email notifications.
- Configure a permanent Meta WhatsApp Cloud API token and an approved transactional message template before enabling WhatsApp notifications.
- Monitor `notification_outbox` failures and retry history through the Super Admin notification endpoint.

## MTN MoMo

- Obtain approved Collections production credentials for Rwanda.
- Register the exact HTTPS callback URL and test provider reachability.
- Confirm the production target environment and RWF currency settings with MTN.
- Reconcile pending payments on a scheduled server job and alert on long-running pending orders.
- Test successful, rejected, cancelled, duplicate and delayed payment cases.
- Never fulfil an order until the API has verified `SUCCESSFUL` with MTN.

## Application security

- Rotate the bootstrap administrator password and restrict Super Admin accounts.
- Add password reset and verified-email delivery through an approved mail provider.
- Add account lockout/abuse monitoring in addition to global rate limiting.
- Review role assignments and driver access before launch.
- Run dependency scanning, static analysis and a penetration test.
- Publish privacy, delivery, refund and returns policies.

## Mobile release

- Apply Android and iOS location-purpose strings.
- Configure production package identifiers and release signing.
- Run `flutter analyze`, automated tests and device testing on supported OS versions.
- Validate deep links, offline/error states, token expiry and refresh behaviour.
- Complete Google Play data-safety and Apple privacy disclosures.

## Operations

- Define order cancellation and stock-release rules for abandoned payments.
- Train Admin and Driver users on assignment and delivery status transitions.
- Confirm customer-support contact details and escalation procedures.
- Perform a small controlled live-payment pilot before public launch.
