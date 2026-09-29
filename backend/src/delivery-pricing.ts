export interface DeliveryPricingSettings {
  deliveryRateRwf: number;
  deliveryRangeKm: number;
  freeDeliveryThresholdRwf: number;
}

export interface DeliveryOrigin {
  name: string;
  latitude: number;
  longitude: number;
}

export interface DeliveryBreakdownItem {
  originName: string;
  distanceKm: number;
  deliveryRwf: number;
}

export interface DeliveryQuote {
  distanceKm: number;
  deliveryRwf: number;
  deliveryRateRwf: number;
  deliveryRangeKm: number;
  freeDelivery: boolean;
  breakdown: DeliveryBreakdownItem[];
}

const earthRadiusKm = 6371.0088;

const radians = (degrees: number) => (degrees * Math.PI) / 180;
const roundedDistance = (value: number) => Math.round(value * 100) / 100;

export function distanceBetweenKm(
  originLatitude: number,
  originLongitude: number,
  destinationLatitude: number,
  destinationLongitude: number,
) {
  const latitudeDelta = radians(destinationLatitude - originLatitude);
  const longitudeDelta = radians(destinationLongitude - originLongitude);
  const originLatitudeRadians = radians(originLatitude);
  const destinationLatitudeRadians = radians(destinationLatitude);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(originLatitudeRadians) *
      Math.cos(destinationLatitudeRadians) *
      Math.sin(longitudeDelta / 2) ** 2;
  return (
    2 * earthRadiusKm * Math.asin(Math.sqrt(Math.min(1, Math.max(0, haversine))))
  );
}

export function calculateDeliveryQuote(
  subtotalRwf: number,
  destinationLatitude: number,
  destinationLongitude: number,
  settings: DeliveryPricingSettings,
  origins: DeliveryOrigin[],
): DeliveryQuote {
  const freeDelivery =
    settings.freeDeliveryThresholdRwf > 0 &&
    subtotalRwf >= settings.freeDeliveryThresholdRwf;
  const uniqueOrigins = new Map<string, DeliveryOrigin>();
  for (const origin of origins) {
    const key = `${origin.latitude.toFixed(5)},${origin.longitude.toFixed(5)}`;
    if (!uniqueOrigins.has(key)) uniqueOrigins.set(key, origin);
  }
  const breakdown = [...uniqueOrigins.values()].map((origin) => {
    const rawDistance = distanceBetweenKm(
      origin.latitude,
      origin.longitude,
      destinationLatitude,
      destinationLongitude,
    );
    const deliveryRwf =
      freeDelivery || rawDistance === 0
        ? 0
        : Math.max(
            1,
            Math.round(
              (rawDistance / settings.deliveryRangeKm) *
                settings.deliveryRateRwf,
            ),
          );
    return {
      originName: origin.name,
      distanceKm: roundedDistance(rawDistance),
      deliveryRwf,
    };
  });

  return {
    distanceKm: roundedDistance(
      breakdown.reduce((total, item) => total + item.distanceKm, 0),
    ),
    deliveryRwf: breakdown.reduce(
      (total, item) => total + item.deliveryRwf,
      0,
    ),
    deliveryRateRwf: settings.deliveryRateRwf,
    deliveryRangeKm: settings.deliveryRangeKm,
    freeDelivery,
    breakdown,
  };
}
