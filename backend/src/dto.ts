import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsBoolean, IsEmail, IsIn, IsInt, IsLatitude, IsLongitude, IsOptional, IsString, IsUrl, Length, Max, Min, MinLength, ValidateNested } from 'class-validator';

export class RegisterDto {
  @IsEmail() email!: string;
  @MinLength(10) password!: string;
  @IsString() @Length(2, 100) fullName!: string;
  @IsOptional() @IsString() phone?: string;
}
export class LoginDto { @IsEmail() email!: string; @IsString() password!: string; }
export class RefreshDto { @IsString() refreshToken!: string; }

export class ProductDto {
  @IsString() @Length(2, 160) name!: string;
  @IsString() @Length(2, 80) category!: string;
  @IsOptional() @IsString() description?: string;
  @IsInt() @Min(0) @Max(100000000) priceRwf!: number;
  @IsInt() @Min(0) @Max(1000000) stock!: number;
  @IsOptional() @IsUrl({ require_protocol: true }) imageUrl?: string;
  @IsOptional() @IsString() @Length(1, 300) imagePublicId?: string;
  @IsOptional() @IsString() @Length(1, 40) badge?: string;
  @IsOptional() @IsString() categoryId?: string;
  @IsOptional() @IsString() @Length(1, 80) sku?: string;
  @IsOptional() @IsInt() @Min(0) lowStockThreshold?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class DeleteMediaDto { @IsString() @Length(1,300) publicId!:string; }

export class CategoryDto {
  @IsString() @Length(2, 80) name!: string;
  @IsOptional() @IsString() @Length(0, 500) description?: string;
  @IsOptional() @IsUrl({ require_protocol: true }) imageUrl?: string;
  @IsOptional() @IsInt() @Min(0) @Max(10000) sortOrder?: number;
  @IsOptional() @IsBoolean() active?: boolean;
}

export class InventoryAdjustmentDto {
  @IsInt() @Min(-1000000) @Max(1000000) quantityDelta!: number;
  @IsString() @Length(3, 200) reason!: string;
  @IsOptional() @IsString() @Length(1, 100) reference?: string;
}

export class OrderItemDto { @IsString() productId!: string; @IsInt() @Min(1) @Max(20) quantity!: number; }
export class CreateOrderDto {
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(50) @ValidateNested({ each: true }) @Type(() => OrderItemDto) items!: OrderItemDto[];
  @IsString() @Length(3, 300) deliveryAddress!: string;
  @IsOptional() @IsLatitude() latitude?: number;
  @IsOptional() @IsLongitude() longitude?: number;
  @IsString() @Length(8, 20) customerPhone!: string;
}
export class AssignDriverDto { @IsString() driverId!: string; }
export class OrderStatusDto { @IsIn(['ready_for_pickup', 'out_for_delivery', 'delivered', 'cancelled']) status!: string; }
export class DeliveryStatusDto {
  @IsIn(['assigned','picked_up','out_for_delivery','delivered','failed']) status!: string;
  @IsOptional() @IsString() @Length(0, 500) notes?: string;
  @IsOptional() @IsUrl({ require_protocol: true }) proofUrl?: string;
}
export class UserRoleDto { @IsIn(['customer','admin','driver']) role!: string; }
export class UserStatusDto { @IsBoolean() isActive!: boolean; }
export class PaymentSettingsDto {
  @IsString() @Length(10, 20) momoNumber!: string;
  @IsInt() @Min(0) deliveryFeeRwf!: number;
  @IsInt() @Min(0) freeDeliveryThresholdRwf!: number;
  @IsOptional() @IsIn(['manual','momo_api']) paymentMode?: string;
}

export class PaymentClaimDto {
  @IsOptional() @IsString() @Length(0, 100) transactionReference?: string;
  @IsOptional() @IsString() @Length(0, 500) note?: string;
}

export class PaymentReviewDto {
  @IsOptional() @IsString() @Length(0, 500) note?: string;
}

export class StoreSettingsDto {
  @IsString() @Length(2, 100) storeName!: string;
  @IsString() @Length(8, 30) supportPhone!: string;
  @IsEmail() supportEmail!: string;
}
