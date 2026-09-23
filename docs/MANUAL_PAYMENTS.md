# Manual Mobile Money workflow

Manual payment is intentionally separate from payment-provider integrations.

## Customer flow

1. The API creates an order and calculates the amount from current product prices.
2. The API creates a `manual_momo` payment record with `pending` status.
3. On Android/iOS, the app attempts to open `*182*1*1*RECIPIENT*AMOUNT#` in the external dialer.
4. On web, desktop, simulator, or dialer failure, the app shows the recipient, amount and copyable USSD code.
5. After MTN confirms the transfer, the customer submits **I have paid**, with an optional transaction reference and note.

Submitting the notification does not mark the order as paid.

## Staff review

- Admin and Super Admin see a highlighted **Awaiting review** payment.
- Staff verify the amount in the business Mobile Money account.
- **Approve** changes the payment to `successful` and the order to `payment_confirmed`.
- **Reject** changes the payment to `failed`; the order stays `awaiting_payment` and the customer may resubmit.
- Claims and review decisions are recorded in the audit log.

## Future payment gateways

The `payments.provider` field is the integration boundary. Manual records use `manual_momo`; MTN API records use `mtn_momo`. Store settings retain `manual` and `momo_api` modes, while provider credentials remain backend-only. A future provider should implement server-side initiation, callback/status verification and reconciliation without changing order totals or the manual review history.

Never treat a customer button press, screenshot, or client callback as proof of payment. Automated gateways must be verified server-side before changing an order to `payment_confirmed`.
