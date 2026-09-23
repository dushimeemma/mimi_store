require('reflect-metadata');

const assert = require('node:assert/strict');
const test = require('node:test');
const { plainToInstance } = require('class-transformer');
const { validate } = require('class-validator');

const { CategoryDto, PaymentClaimDto, ProductDto } = require('../dist/dto');
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
