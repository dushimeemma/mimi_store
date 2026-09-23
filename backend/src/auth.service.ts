import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { createHash, randomUUID } from 'crypto';

import { DatabaseService } from './database.service';
import { LoginDto, RefreshDto, RegisterDto } from './dto';
import { AuthUser, Role } from './security';

interface UserRow { id: string; email: string; full_name: string; phone: string | null; role: Role; password_hash: string; is_active: boolean; }

@Injectable()
export class AuthService {
  constructor(private readonly db: DatabaseService, private readonly jwt: JwtService, private readonly config: ConfigService) {}

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const exists = await this.db.query('SELECT 1 FROM users WHERE lower(email)=$1', [email]);
    if (exists.rowCount) throw new ConflictException('Email is already registered');
    const passwordHash = await bcrypt.hash(dto.password, 12);
    const result = await this.db.query<UserRow>('INSERT INTO users(email,password_hash,full_name,phone) VALUES($1,$2,$3,$4) RETURNING *', [email, passwordHash, dto.fullName.trim(), dto.phone?.trim() || null]);
    return this.issue(result.rows[0]);
  }

  async login(dto: LoginDto) {
    const result = await this.db.query<UserRow>('SELECT * FROM users WHERE lower(email)=$1', [dto.email.trim().toLowerCase()]);
    const user = result.rows[0];
    if (!user || !user.is_active || !(await bcrypt.compare(dto.password, user.password_hash))) throw new UnauthorizedException('Invalid email or password');
    return this.issue(user);
  }

  async refresh(dto: RefreshDto) {
    let payload: AuthUser & { jti: string };
    try { payload = await this.jwt.verifyAsync(dto.refreshToken, { secret: this.config.getOrThrow('JWT_REFRESH_SECRET') }); }
    catch { throw new UnauthorizedException('Refresh token is invalid or expired'); }
    const tokenHash = createHash('sha256').update(dto.refreshToken).digest('hex');
    const result = await this.db.query<UserRow>('SELECT u.* FROM refresh_tokens r JOIN users u ON u.id=r.user_id WHERE r.token_hash=$1 AND r.revoked_at IS NULL AND r.expires_at>now() AND u.is_active=true', [tokenHash]);
    if (!result.rows[0]) throw new UnauthorizedException('Refresh token is revoked');
    await this.db.query('UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1', [tokenHash]);
    return this.issue(result.rows[0]);
  }

  async logout(refreshToken: string) {
    const hash = createHash('sha256').update(refreshToken).digest('hex');
    await this.db.query('UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1', [hash]);
    return { success: true };
  }

  private async issue(user: UserRow) {
    const payload: AuthUser = { sub: user.id, email: user.email, role: user.role };
    const accessToken = await this.jwt.signAsync(payload, { secret: this.config.getOrThrow('JWT_ACCESS_SECRET'), expiresIn: (this.config.get<string>('JWT_ACCESS_TTL') ?? '15m') as any });
    const jti = randomUUID();
    const refreshToken = await this.jwt.signAsync({ ...payload, jti }, { secret: this.config.getOrThrow('JWT_REFRESH_SECRET'), expiresIn: (this.config.get<string>('JWT_REFRESH_TTL') ?? '30d') as any });
    const hash = createHash('sha256').update(refreshToken).digest('hex');
    await this.db.query("INSERT INTO refresh_tokens(user_id,token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')", [user.id, hash]);
    return { accessToken, refreshToken, user: { id: user.id, email: user.email, fullName: user.full_name, phone: user.phone, role: user.role } };
  }
}
