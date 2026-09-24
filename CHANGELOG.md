# Changelog

## 1.2.0+16

- Added Cloudinary product image upload, secure URL persistence and automatic deletion of replaced images.
- Added durable email and WhatsApp notification outbox delivery with retry handling.
- Added customer and administrator notifications across authentication, catalogue, inventory, order, payment, delivery, user and settings operations.
- Added international phone country selectors to registration, checkout and business settings.
- Added persisted System, Light and Dark appearance modes across customer and staff screens.
- Added production Android network and iOS photo-library declarations.

## 1.1.0+11

- Added configurable MTN MoMo USSD checkout with mobile dialer launch.
- Added web, desktop, simulator and dialer-failure payment instructions.
- Added customer payment notifications with optional transaction references.
- Added Admin and Super Admin approval/rejection with enforced server-side review rules.
- Added payment claim/review audit records and database migration.
- Preserved the provider boundary for re-enabling MTN MoMo API or adding another gateway.

## 1.0.0+10

- Added database-backed product, category and inventory management.
- Added complete order lifecycle, cancellation and automatic stock restoration.
- Added customer, Admin, Super Admin and Motor Driver role workflows.
- Added payment ledger, manual confirmation and MTN MoMo reconciliation.
- Added driver assignment, delivery statuses, directions and fulfilment history.
- Added store/payment settings, live dashboard metrics and administrative audit logs.
- Added dynamic storefront categories, search, stock controls and customer order history.
- Added development-safe dynamic localhost CORS while retaining an exact production allowlist.

## 0.2.1+3

- Fixed the desktop/web storefront hero layout by giving its flex children a bounded height.
- Prevented the cascading `RenderBox` and mouse-tracker assertions seen on Flutter web.

## 0.2.0+2

- Added the Flutter storefront, role-based dashboards, API integration and production NestJS/PostgreSQL backend.
