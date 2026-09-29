require('reflect-metadata');

const assert = require('node:assert/strict');
const test = require('node:test');
const { plainToInstance } = require('class-transformer');
const { validate } = require('class-validator');

const { CategoryDto, PaymentClaimDto, PaymentSettingsDto, ProductDto } = require('../dist/dto');
const { calculateDeliveryQuote } = require('../dist/delivery-pricing');
const { MomoService } = require('../dist/momo.service');

test('product validation accepts a complete catalogue item', async () => {
  const value = plainToInstance(ProductDto, {
    name: 'Imena Draped Dress', category: 'Dresses', priceRwf: 68500,
    stock: 12, lowStockThreshold: 3, active: true,
    originLocationName: 'Kabuye Health Center, Kigali, Rwanda',
  });
  assert.equal((await validate(value)).length, 0);
});

test('product validation rejects negative prices and stock', async () => {
  const value = plainToInstance(ProductDto, {
    name: 'Invalid Product', category: 'Dresses', priceRwf: -1, stock: -2,
    originLocationName: 'Kabuye Health Center, Kigali, Rwanda',
  });
  assert.ok((await validate(value)).length >= 2);
});

test('category validation requires a meaningful name', async () => {
  const value = plainToInstance(CategoryDto, { name: 'A' });
  assert.ok((await validate(value)).length > 0);
});

test('Rwanda MoMo phone numbers are normalized consistently', () => {
  const service = new MomoService({});
  assert.equal(service.normalizePhone('0788 440 177'), '250788440177');
  assert.equal(service.normalizePhone('+250 788 440 177'), '250788440177');
  assert.equal(service.normalizePhone('788440177'), '250788440177');
  assert.throws(() => service.normalizePhone('1234'));
});

test('manual payment notification accepts an optional short reference and note', async () => {
  const value = plainToInstance(PaymentClaimDto, {
    transactionReference: 'MTN-123456', note: 'Paid from my checkout phone',
  });
  assert.equal((await validate(value)).length, 0);
});

test('manual payment notification rejects oversized untrusted input', async () => {
  const value = plainToInstance(PaymentClaimDto, {
    transactionReference: 'x'.repeat(101), note: 'x'.repeat(501),
  });
  assert.ok((await validate(value)).length >= 2);
});

test('delivery pricing applies the configured rate proportionally to distance', () => {
  const settings = {
    deliveryRateRwf: 500,
    deliveryRangeKm: 1,
    freeDeliveryThresholdRwf: 100000,
  };
  const origins = [{ name: 'Kabuye', latitude: -1.8795, longitude: 30.0708 }];
  const quote = calculateDeliveryQuote(20000, -1.8895, 30.0708, settings, origins);
  assert.ok(quote.distanceKm > 1);
  assert.equal(quote.deliveryRwf, quote.breakdown[0].deliveryRwf);
  assert.ok(quote.deliveryRwf > 500 && quote.deliveryRwf < 600);
});

test('delivery pricing charges each distinct product origin once', () => {
  const settings = {
    deliveryRateRwf: 500,
    deliveryRangeKm: 1,
    freeDeliveryThresholdRwf: 0,
  };
  const origins = [
    { name: 'Kabuye A', latitude: -1.8795, longitude: 30.0708 },
    { name: 'Kabuye B', latitude: -1.8795, longitude: 30.0708 },
    { name: 'Kigali Centre', latitude: -1.9441, longitude: 30.0619 },
  ];
  const quote = calculateDeliveryQuote(20000, -1.95, 30.07, settings, origins);
  assert.equal(quote.breakdown.length, 2);
  assert.equal(
    quote.deliveryRwf,
    quote.breakdown.reduce((total, item) => total + item.deliveryRwf, 0),
  );
});

test('delivery pricing honours the configured free-delivery threshold', () => {
  const quote = calculateDeliveryQuote(100000, -1.9625, 30.0619, {
    deliveryRateRwf: 500,
    deliveryRangeKm: 1,
    freeDeliveryThresholdRwf: 100000,
  }, [{ name: 'Kabuye', latitude: -1.8795, longitude: 30.0708 }]);
  assert.equal(quote.freeDelivery, true);
  assert.equal(quote.deliveryRwf, 0);
});

test('delivery settings require a positive range', async () => {
  const value = plainToInstance(PaymentSettingsDto, {
    momoNumber: '+250788440177',
    deliveryRateRwf: 500,
    deliveryRangeKm: 0,
    freeDeliveryThresholdRwf: 100000,
    paymentMode: 'manual',
  });
  assert.ok((await validate(value)).length >= 1);
});
