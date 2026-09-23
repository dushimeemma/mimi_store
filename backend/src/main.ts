import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });
  const config = app.get(ConfigService);
  const production = config.get('NODE_ENV') === 'production';
  const allowedOrigins = (config.get<string>('CORS_ORIGINS') ?? '').split(',').map((value:string)=>value.trim()).filter(Boolean);
  app.use(helmet());
  app.enableCors({
    origin: (origin: string | undefined, callback: (error: Error | null, allow?: boolean) => void) => {
      const localDevelopment = !production && !!origin && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
      callback(null, !origin || allowedOrigins.includes(origin) || localDevelopment);
    },
    methods: ['GET','POST','PUT','PATCH','DELETE'],
    credentials: false,
  });
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableShutdownHooks();
  if (config.get('NODE_ENV') !== 'production') {
    const document = SwaggerModule.createDocument(app, new DocumentBuilder().setTitle('Mimi Store API').setVersion('1.0').addBearerAuth().build());
    SwaggerModule.setup('docs', app, document);
  }
  await app.listen(Number(config.get('PORT',8080)), '0.0.0.0');
}
void bootstrap();
