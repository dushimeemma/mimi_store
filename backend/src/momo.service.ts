import { BadGatewayException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface MomoStatus { status?: string; financialTransactionId?: string; reason?: string; }

@Injectable()
export class MomoService {
  constructor(private readonly config: ConfigService) {}

  get enabled() { return this.config.get('MOMO_ENABLED', 'false') === 'true'; }

  async requestToPay(reference: string, amountRwf: number, phone: string, orderNumber: string) {
    if (!this.enabled) throw new ServiceUnavailableException('Mobile Money is not configured');
    const token = await this.token();
    const response = await fetch(`${this.baseUrl}/collection/v1_0/requesttopay`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Ocp-Apim-Subscription-Key': this.config.getOrThrow('MOMO_SUBSCRIPTION_KEY'),
        'X-Reference-Id': reference,
        'X-Target-Environment': this.config.get('MOMO_TARGET_ENVIRONMENT', 'mtnrwanda'),
        'X-Callback-Url': `${this.config.getOrThrow('MOMO_CALLBACK_URL')}?reference=${encodeURIComponent(reference)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountRwf.toString(),
        currency: this.config.get('MOMO_CURRENCY', 'RWF'),
        externalId: orderNumber,
        payer: { partyIdType: 'MSISDN', partyId: this.normalizePhone(phone) },
        payerMessage: `Payment for ${orderNumber}`,
        payeeNote: 'Mimi Store order',
      }),
    });
    if (response.status !== 202) throw new BadGatewayException(`MoMo request rejected (${response.status})`);
    return { reference, status: 'pending' };
  }

  async status(reference: string): Promise<MomoStatus> {
    if (!this.enabled) throw new ServiceUnavailableException('Mobile Money is not configured');
    const token = await this.token();
    const response = await fetch(`${this.baseUrl}/collection/v1_0/requesttopay/${reference}`, { headers: { Authorization: `Bearer ${token}`, 'Ocp-Apim-Subscription-Key': this.config.getOrThrow('MOMO_SUBSCRIPTION_KEY'), 'X-Target-Environment': this.config.get('MOMO_TARGET_ENVIRONMENT', 'mtnrwanda') } });
    if (!response.ok) throw new BadGatewayException(`MoMo status unavailable (${response.status})`);
    return response.json() as Promise<MomoStatus>;
  }

  private get baseUrl() { return this.config.get('MOMO_BASE_URL', 'https://proxy.momoapi.mtn.com').replace(/\/$/, ''); }
  private normalizePhone(phone: string) {
    const digits=phone.replace(/\D/g,'');
    if(/^2507\d{8}$/.test(digits))return digits;
    if(/^07\d{8}$/.test(digits))return `25${digits}`;
    if(/^7\d{8}$/.test(digits))return `250${digits}`;
    throw new BadGatewayException('A valid Rwanda Mobile Money number is required');
  }
  private async token() {
    const credentials = Buffer.from(`${this.config.getOrThrow('MOMO_API_USER')}:${this.config.getOrThrow('MOMO_API_KEY')}`).toString('base64');
    const response = await fetch(`${this.baseUrl}/collection/token/`, { method: 'POST', headers: { Authorization: `Basic ${credentials}`, 'Ocp-Apim-Subscription-Key': this.config.getOrThrow('MOMO_SUBSCRIPTION_KEY') } });
    if (!response.ok) throw new BadGatewayException('Unable to authenticate with Mobile Money');
    const data = await response.json() as { access_token?: string };
    if (!data.access_token) throw new BadGatewayException('Mobile Money token was missing');
    return data.access_token;
  }
}
