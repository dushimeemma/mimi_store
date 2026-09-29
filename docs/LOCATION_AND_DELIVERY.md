# Location and delivery pricing

Customers enter a readable place such as a street, neighbourhood or landmark, or explicitly choose **Use my location**. The API resolves that input to coordinates, stores the resolved display name on the order, and never returns the coordinates in the customer order or quote response. Driver delivery records retain coordinates so assigned staff can open directions.

Each product has its own pickup location. New and edited products accept the place name in the Admin product form. Migration `006_product_origins_and_geocoding.sql` assigns existing products to **Kabuye Health Center, Kigali, Rwanda** at latitude `-1.8795`, longitude `30.0708`.

The API calculates the straight-line distance from each distinct pickup point to the destination once:

```text
origin fee = round((distance km / configured range km) * configured rate RWF)
delivery fee = sum(origin fees)
payable total = product subtotal + delivery fee
```

With the defaults, 3.4 km costs `round((3.4 / 1) * 500) = 1,700 RWF`. Products sharing the same pickup coordinates do not cause a repeated fee. The calculated fee and full total are saved as an order snapshot and the same total is loaded into the Mobile Money USSD code.

Place lookup uses the backend only and is configurable:

```env
GEOCODING_BASE_URL=https://nominatim.openstreetmap.org
GEOCODING_USER_AGENT=MimiStore/1.0 (https://your-production-site.example)
```

The implementation performs explicit searches only, serializes uncached provider requests to at most one per second, stores results in `geocoding_cache`, and displays OpenStreetMap attribution. For larger production traffic, point `GEOCODING_BASE_URL` at a self-hosted Nominatim instance or a compatible managed provider after reviewing its terms.
