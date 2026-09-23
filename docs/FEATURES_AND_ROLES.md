# Mimi Store feature and role matrix

| Capability | Customer | Motor Driver | Admin | Super Admin |
| --- | --- | --- | --- | --- |
| Browse/search catalogue and categories | Yes | Yes | Yes | Yes |
| Cart, checkout, address and GPS pin | Yes | — | — | — |
| View own orders | Yes | — | — | — |
| View assigned deliveries | — | Yes | Yes | Yes |
| Update assigned delivery progress | — | Yes | Yes | Yes |
| Manage products, prices and visibility | — | — | Yes | Yes |
| Manage categories and inventory | — | — | Yes | Yes |
| View and fulfil all orders | — | — | Yes | Yes |
| Assign/reassign drivers | — | — | Yes | Yes |
| Report a completed manual payment | Yes | — | — | — |
| View payments and reconcile MTN status | — | — | Yes | Yes |
| Approve/reject reported manual payments | — | — | Yes | Yes |
| Manage users, roles and account access | — | — | — | Yes |
| Change payment/business settings | — | — | — | Yes |
| View security audit history | — | — | — | Yes |

## Operational safeguards

- Totals are recalculated by the API from current database prices.
- Stock is reserved transactionally when an order is created.
- Cancelling an eligible order restores stock and records inventory movements.
- Drivers can update only deliveries assigned to their authenticated account.
- Super Admin cannot disable their own account or demote another Super Admin through the standard endpoint.
- Manual payments require a customer notification followed by explicit Admin or Super Admin review.
- API payments become successful only after server-side verification with MTN.
- Every sensitive product, inventory, order, payment, delivery, user and settings change writes an audit entry.

## Release boundary

The package contains the complete commerce application code. Deployment remains environment-specific: production domains, HTTPS, PostgreSQL hosting/backups, MTN approval and credentials, Android/iOS signing, store accounts, policies, observability and live acceptance testing must be supplied by the business before public launch.
