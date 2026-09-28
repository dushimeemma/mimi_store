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
  });
  assert.equal((await validate(value)).length, 0);
});

test('product validation rejects negative prices and stock', async () => {
  const value = plainToInstance(ProductDto, {
    name: 'Invalid Product', category: 'Dresses', priceRwf: -1, stock: -2,
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

test('delivery pricing charges each started configured distance range', () => {
  const settings = {
    deliveryRateRwf: 500,
    deliveryRangeKm: 1,
    deliveryOriginLatitude: -1.9441,
    deliveryOriginLongitude: 30.0619,
    freeDeliveryThresholdRwf: 100000,
  };
  const oneRange = calculateDeliveryQuote(20000, -1.947, 30.0619, settings);
  assert.equal(oneRange.chargeableRanges, 1);
  assert.equal(oneRange.deliveryRwf, 500);
  const multipleRanges = calculateDeliveryQuote(20000, -1.9625, 30.0619, settings);
  assert.ok(multipleRanges.chargeableRanges >= 2);
  assert.equal(multipleRanges.deliveryRwf, multipleRanges.chargeableRanges * 500);
});

test('delivery pricing honours the configured free-delivery threshold', () => {
  const quote = calculateDeliveryQuote(100000, -1.9625, 30.0619, {
    deliveryRateRwf: 500,
    deliveryRangeKm: 1,
    deliveryOriginLatitude: -1.9441,
    deliveryOriginLongitude: 30.0619,
    freeDeliveryThresholdRwf: 100000,
  });
  assert.equal(quote.freeDelivery, true);
  assert.equal(quote.deliveryRwf, 0);
});

test('delivery settings require a positive range and valid coordinates', async () => {
  const value = plainToInstance(PaymentSettingsDto, {
    momoNumber: '+250788440177',
    deliveryRateRwf: 500,
    deliveryRangeKm: 0,
    deliveryOriginLatitude: 100,
    deliveryOriginLongitude: 30.0619,
    freeDeliveryThresholdRwf: 100000,
    paymentMode: 'manual',
  });
  assert.ok((await validate(value)).length >= 2);
});
