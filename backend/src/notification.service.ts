import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer, { Transporter } from 'nodemailer';

import { DatabaseService } from './database.service';

interface Recipient { email?:string|null; phone?:string|null; }
interface OutboxRow { id:string;channel:'email'|'whatsapp';recipient:string;subject:string;message:string;attempts:number; }

@Injectable()
export class NotificationService implements OnModuleInit,OnModuleDestroy {
  private readonly logger=new Logger(NotificationService.name);
  private readonly emailEnabled:boolean;
  private readonly whatsappEnabled:boolean;
  private readonly transporter?:Transporter;
  private timer?:NodeJS.Timeout;
  private dispatching=false;

  constructor(private readonly db:DatabaseService,private readonly config:ConfigService){
    this.emailEnabled=this.flag('EMAIL_NOTIFICATIONS_ENABLED')&&Boolean(config.get('SMTP_HOST')&&config.get('SMTP_FROM'));
    this.whatsappEnabled=this.flag('WHATSAPP_NOTIFICATIONS_ENABLED')&&Boolean(config.get('WHATSAPP_PHONE_NUMBER_ID')&&config.get('WHATSAPP_ACCESS_TOKEN'));
    if(this.emailEnabled)this.transporter=nodemailer.createTransport({
      host:config.getOrThrow('SMTP_HOST'),
      port:Number(config.get('SMTP_PORT')??587),
      secure:this.flag('SMTP_SECURE'),
      auth:config.get('SMTP_USER')?{user:config.getOrThrow('SMTP_USER'),pass:config.getOrThrow('SMTP_PASS')}:undefined,
    });
  }

  onModuleInit(){this.timer=setInterval(()=>void this.dispatchPending(),15_000);this.timer.unref();void this.dispatchPending();}
  onModuleDestroy(){if(this.timer)clearInterval(this.timer);}

  async user(userId:string,eventType:string,subject:string,message:string){
    try{const r=await this.db.query<Recipient>('SELECT email,phone FROM users WHERE id=$1',[userId]);if(r.rows[0])await this.queue(r.rows[0],eventType,subject,message);}
    catch(error){this.logger.error(`Unable to queue ${eventType} notification`,error instanceof Error?error.stack:undefined);}
  }

  async admins(eventType:string,subject:string,message:string){
    try{const r=await this.db.query<Recipient>("SELECT email,phone FROM users WHERE role IN ('admin','super_admin') AND is_active=true");for(const recipient of r.rows)await this.queue(recipient,eventType,subject,message);}
    catch(error){this.logger.error(`Unable to queue admin ${eventType} notification`,error instanceof Error?error.stack:undefined);}
  }

  async history(){const result=await this.db.query('SELECT id,channel,recipient,event_type AS "eventType",subject,status,attempts,last_error AS "lastError",sent_at AS "sentAt",created_at AS "createdAt" FROM notification_outbox ORDER BY created_at DESC LIMIT 500');return result.rows;}

  private async queue(recipient:Recipient,eventType:string,subject:string,message:string){
    const entries:Array<['email'|'whatsapp',string]>=[];
    if(this.emailEnabled&&recipient.email)entries.push(['email',recipient.email.trim().toLowerCase()]);
    if(this.whatsappEnabled&&recipient.phone)entries.push(['whatsapp',this.normalizePhone(recipient.phone)]);
    for(const [channel,address] of entries)if(address)await this.db.query('INSERT INTO notification_outbox(channel,recipient,event_type,subject,message) VALUES($1,$2,$3,$4,$5)',[channel,address,eventType,subject,message]);
    if(entries.length)void this.dispatchPending();
  }

  private async dispatchPending(){
    if(this.dispatching)return;this.dispatching=true;
    try{
      await this.db.query("UPDATE notification_outbox SET status='pending',next_attempt_at=now(),updated_at=now() WHERE status='processing' AND updated_at<now()-interval '5 minutes'");
      const picked=await this.db.query<OutboxRow>(`WITH selected AS (SELECT id FROM notification_outbox WHERE status='pending' AND next_attempt_at<=now() ORDER BY created_at LIMIT 20 FOR UPDATE SKIP LOCKED) UPDATE notification_outbox n SET status='processing',updated_at=now() FROM selected WHERE n.id=selected.id RETURNING n.id,n.channel,n.recipient,n.subject,n.message,n.attempts`);
      for(const item of picked.rows){
        try{if(item.channel==='email')await this.sendEmail(item);else await this.sendWhatsapp(item);await this.db.query("UPDATE notification_outbox SET status='sent',attempts=attempts+1,sent_at=now(),last_error=null,updated_at=now() WHERE id=$1",[item.id]);}
        catch(error){const attempts=item.attempts+1;const message=(error as Error).message.slice(0,1000);await this.db.query("UPDATE notification_outbox SET status=CASE WHEN $2>=5 THEN 'failed' ELSE 'pending' END,attempts=$2,next_attempt_at=now()+(LEAST(1440,power(2,$2)::int)*interval '1 minute'),last_error=$3,updated_at=now() WHERE id=$1",[item.id,attempts,message]);this.logger.warn(`Notification ${item.id} failed: ${message}`);}
      }
    }catch(error){this.logger.warn(`Notification dispatcher unavailable: ${(error as Error).message}`);}
    finally{this.dispatching=false;}
  }

  private async sendEmail(item:OutboxRow){if(!this.transporter)throw new Error('SMTP is not configured');await this.transporter.sendMail({from:this.config.getOrThrow('SMTP_FROM'),to:item.recipient,subject:item.subject,text:item.message,html:`<div style="font-family:Arial,sans-serif;line-height:1.6"><h2>${this.escape(item.subject)}</h2><p>${this.escape(item.message).replace(/\n/g,'<br>')}</p><p style="color:#666">Mimi Store</p></div>`});}

  private async sendWhatsapp(item:OutboxRow){
    const version=this.config.get<string>('WHATSAPP_GRAPH_VERSION')??'v23.0';const phoneId=this.config.getOrThrow('WHATSAPP_PHONE_NUMBER_ID');const template=this.config.get<string>('WHATSAPP_TEMPLATE_NAME');
    const body=template?{messaging_product:'whatsapp',to:item.recipient,type:'template',template:{name:template,language:{code:this.config.get<string>('WHATSAPP_TEMPLATE_LANGUAGE')??'en'},components:[{type:'body',parameters:[{type:'text',text:item.message.slice(0,1024)}]}]}}:{messaging_product:'whatsapp',recipient_type:'individual',to:item.recipient,type:'text',text:{preview_url:false,body:item.message.slice(0,4096)}};
    const response=await fetch(`https://graph.facebook.com/${version}/${phoneId}/messages`,{method:'POST',headers:{Authorization:`Bearer ${this.config.getOrThrow('WHATSAPP_ACCESS_TOKEN')}`,'Content-Type':'application/json'},body:JSON.stringify(body)});if(!response.ok)throw new Error(`WhatsApp ${response.status}: ${(await response.text()).slice(0,500)}`);
  }

  private flag(key:string){return ['1','true','yes','on'].includes((this.config.get<string>(key)??'false').toLowerCase());}
  private normalizePhone(value:string){const digits=value.replace(/\D/g,'');if(digits.startsWith('0'))return `250${digits.substring(1)}`;if(digits.startsWith('7'))return `250${digits}`;return digits;}
  private escape(value:string){return value.replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]!));}
}
