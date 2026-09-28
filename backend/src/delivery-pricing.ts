export interface DeliveryPricingSettings {
  deliveryRateRwf: number;
  deliveryRangeKm: number;
  deliveryOriginLatitude: number;
  deliveryOriginLongitude: number;
  freeDeliveryThresholdRwf: number;
}

export interface DeliveryQuote {
  distanceKm: number;
  chargeableRanges: number;
  deliveryRwf: number;
  deliveryRateRwf: number;
  deliveryRangeKm: number;
  freeDelivery: boolean;
}

const earthRadiusKm = 6371.0088;

const radians = (degrees: number) => (degrees * Math.PI) / 180;

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
): DeliveryQuote {
  const distanceKm = distanceBetweenKm(
    settings.deliveryOriginLatitude,
    settings.deliveryOriginLongitude,
    destinationLatitude,
    destinationLongitude,
  );
  const freeDelivery =
    settings.freeDeliveryThresholdRwf > 0 &&
    subtotalRwf >= settings.freeDeliveryThresholdRwf;
  const chargeableRanges =
    freeDelivery || distanceKm === 0
      ? 0
      : Math.max(1, Math.ceil(distanceKm / settings.deliveryRangeKm));

  return {
    distanceKm: Math.round(distanceKm * 100) / 100,
    chargeableRanges,
    deliveryRwf: freeDelivery
      ? 0
      : chargeableRanges * settings.deliveryRateRwf,
    deliveryRateRwf: settings.deliveryRateRwf,
    deliveryRangeKm: settings.deliveryRangeKm,
    freeDelivery,
  };
}
