# Notifications, product media and appearance

## Render deployment

Deploy the API, then run this once against the production database:

```bash
node dist/migrate.js
```

Migration `004_media_notifications.sql` adds Cloudinary media metadata to products and creates the persistent notification outbox. Notification delivery failures never roll back a completed order or administrative operation; pending messages are retried with backoff and visible to Super Admins through `GET /api/v1/admin/notifications`.

## Cloudinary

Create a Cloudinary account and add these secrets only to the Render API service:

```env
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
CLOUDINARY_PRODUCT_FOLDER=mimi-store/products
```

An Admin or Super Admin selects a JPG, PNG or WebP file (maximum 8 MB) in the product editor. The Flutter client uploads it to the authenticated backend endpoint; the API uploads it to Cloudinary and stores both the secure URL and public ID. When a product update replaces the image, the database update completes first and the API then deletes the previous asset. Product image credentials are never exposed to Flutter or Vercel.

## Email

Use any production SMTP provider. Add its credentials to Render:

```env
EMAIL_NOTIFICATIONS_ENABLED=true
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-user
SMTP_PASS=your-password
SMTP_FROM=Mimi Store <notifications@your-domain.com>
```

Verify the sender domain with the provider before enabling delivery. Port 465 normally uses `SMTP_SECURE=true`; port 587 normally uses `false` with STARTTLS.

## WhatsApp Cloud API

Create a Meta business app, add WhatsApp, register the sending number and create a production access token. Add these Render secrets:

```env
WHATSAPP_NOTIFICATIONS_ENABLED=true
WHATSAPP_GRAPH_VERSION=v23.0
WHATSAPP_PHONE_NUMBER_ID=your-phone-number-id
WHATSAPP_ACCESS_TOKEN=your-production-token
WHATSAPP_TEMPLATE_NAME=mimi_store_update
WHATSAPP_TEMPLATE_LANGUAGE=en
```

For proactive messages outside the customer-service window, Meta requires an approved template. Create `mimi_store_update` with one body variable for the operation message, or change `WHATSAPP_TEMPLATE_NAME` to your approved template. Leaving the template name empty sends regular text messages, which Meta accepts only inside the permitted conversation window.

Phone values are stored in international form by the app's country selector. Existing Rwanda local numbers are normalized before WhatsApp delivery.

## Notification coverage

The outbox is populated for registration, sign-in, category and product changes, inventory adjustments, business/payment settings, order creation and status changes, payment reporting/review, driver assignment and delivery progress, and user role/status changes. The appropriate customer, driver, administrator, or super administrator receives each operation message when that channel is configured and contact data exists.

## Appearance

The account menu contains System, Light and Dark choices. System is the default, follows the device/browser preference, and the explicit selection is persisted locally per installation.
