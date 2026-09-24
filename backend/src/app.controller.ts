import { Body, Controller, Get, Param, Patch, Post, Put, Query, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { AuthService } from './auth.service';
import { AssignDriverDto, CategoryDto, CreateOrderDto, DeleteMediaDto, DeliveryStatusDto, InventoryAdjustmentDto, LoginDto, OrderStatusDto, PaymentClaimDto, PaymentReviewDto, PaymentSettingsDto, ProductDto, RefreshDto, RegisterDto, StoreSettingsDto, UserRoleDto, UserStatusDto } from './dto';
import { MediaService } from './media.service';
import { NotificationService } from './notification.service';
import { AuthUser, CurrentUser, Public, Roles } from './security';
import { StoreService } from './store.service';

@Controller()
export class AppController {
  constructor(private readonly auth: AuthService, private readonly store: StoreService,private readonly media:MediaService,private readonly notifications:NotificationService) {}

  @Public() @Get('health') health() { return { status: 'ok', service: 'mimi-store-api' }; }
  @Public() @Post('auth/register') register(@Body() dto: RegisterDto) { return this.auth.register(dto); }
  @Public() @Post('auth/login') login(@Body() dto: LoginDto) { return this.auth.login(dto); }
  @Public() @Post('auth/refresh') refresh(@Body() dto: RefreshDto) { return this.auth.refresh(dto); }
  @Post('auth/logout') logout(@Body() dto: RefreshDto) { return this.auth.logout(dto.refreshToken); }
  @Get('auth/me') me(@CurrentUser() user: AuthUser) { return user; }

  @Public() @Get('products') products(@Query('search') search='',@Query('categoryId') categoryId='') { return this.store.products(false,search,categoryId); }
  @Public() @Get('categories') categories() { return this.store.categories(false); }
  @Public() @Get('settings/public') settings() { return this.store.settings(); }

  @Roles('admin','super_admin') @Get('admin/dashboard') dashboard() { return this.store.dashboard(); }
  @Roles('admin','super_admin') @Get('admin/products') adminProducts(@Query('search') search='',@Query('categoryId') categoryId='') { return this.store.products(true,search,categoryId); }
  @Roles('admin','super_admin') @Post('admin/products') createProduct(@Body() dto: ProductDto,@CurrentUser() user:AuthUser) { return this.store.createProduct(dto,user); }
  @Roles('admin','super_admin') @Put('admin/products/:id') updateProduct(@Param('id') id: string,@Body() dto: ProductDto,@CurrentUser() user:AuthUser) { return this.store.updateProduct(id,dto,user); }
  @Roles('admin','super_admin') @Post('admin/media/product-image') @UseInterceptors(FileInterceptor('file',{limits:{fileSize:8*1024*1024}})) uploadProductImage(@UploadedFile() file:Express.Multer.File){return this.media.uploadProductImage(file);}
  @Roles('admin','super_admin') @Post('admin/media/product-image/delete') deleteProductImage(@Body() dto:DeleteMediaDto){return this.media.deleteProductImage(dto.publicId).then(()=>({success:true}));}
  @Roles('admin','super_admin') @Post('admin/products/:id/inventory') adjustInventory(@Param('id') id:string,@Body() dto:InventoryAdjustmentDto,@CurrentUser() user:AuthUser){return this.store.adjustInventory(id,dto,user);}
  @Roles('admin','super_admin') @Get('admin/products/:id/inventory') inventoryHistory(@Param('id') id:string){return this.store.inventoryHistory(id);}

  @Roles('admin','super_admin') @Get('admin/categories') adminCategories(){return this.store.categories(true);}
  @Roles('admin','super_admin') @Post('admin/categories') createCategory(@Body() dto:CategoryDto,@CurrentUser() user:AuthUser){return this.store.createCategory(dto,user);}
  @Roles('admin','super_admin') @Put('admin/categories/:id') updateCategory(@Param('id') id:string,@Body() dto:CategoryDto,@CurrentUser() user:AuthUser){return this.store.updateCategory(id,dto,user);}

  @Post('orders') createOrder(@Body() dto: CreateOrderDto,@CurrentUser() user: AuthUser) { return this.store.createOrder(dto,user); }
  @Get('orders/mine') myOrders(@CurrentUser() user: AuthUser,@Query('status') status='') { return this.store.orders(user,status); }
  @Roles('admin','super_admin') @Get('admin/orders') allOrders(@CurrentUser() user:AuthUser,@Query('status') status='') { return this.store.orders(user,status); }
  @Roles('admin','super_admin') @Put('admin/orders/:id/driver') assign(@Param('id') id:string,@Body() dto:AssignDriverDto,@CurrentUser() user:AuthUser) { return this.store.assignDriver(id,dto,user); }
  @Roles('admin','super_admin','driver') @Patch('orders/:id/status') updateStatus(@Param('id') id:string,@Body() dto:OrderStatusDto,@CurrentUser() user:AuthUser) { return this.store.updateOrderStatus(id,dto,user); }

  @Roles('admin','super_admin','driver') @Get('deliveries') deliveries(@CurrentUser() user:AuthUser){return this.store.deliveries(user);}
  @Roles('admin','super_admin','driver') @Patch('deliveries/:id/status') updateDelivery(@Param('id') id:string,@Body() dto:DeliveryStatusDto,@CurrentUser() user:AuthUser){return this.store.updateDelivery(id,dto,user);}

  @Post('orders/:id/payment') pay(@Param('id') id:string,@CurrentUser() user:AuthUser) { return this.store.initiatePayment(id,user); }
  @Post('orders/:id/payment/notify') notifyPayment(@Param('id') id:string,@Body() dto:PaymentClaimDto,@CurrentUser() user:AuthUser) { return this.store.notifyManualPayment(id,dto,user); }
  @Get('payments/:reference/status') paymentStatus(@Param('reference') reference:string) { return this.store.refreshPayment(reference); }
  @Public() @Post('payments/momo/callback') momoCallback(@Query('reference') reference:string) { return this.store.refreshPayment(reference); }
  @Roles('admin','super_admin') @Get('admin/payments') payments(@Query('status') status=''){return this.store.payments(status);}
  @Roles('admin','super_admin') @Post('admin/payments/reconcile') reconcile(){return this.store.reconcilePayments();}
  @Roles('admin','super_admin') @Post('admin/payments/:id/approve') approveManual(@Param('id') id:string,@Body() dto:PaymentReviewDto,@CurrentUser() user:AuthUser){return this.store.reviewManualPayment(id,true,dto,user);}
  @Roles('admin','super_admin') @Post('admin/payments/:id/reject') rejectManual(@Param('id') id:string,@Body() dto:PaymentReviewDto,@CurrentUser() user:AuthUser){return this.store.reviewManualPayment(id,false,dto,user);}
  @Roles('super_admin') @Post('admin/payments/:id/confirm') confirmManual(@Param('id') id:string,@CurrentUser() user:AuthUser){return this.store.reviewManualPayment(id,true,{},user);}

  @Roles('admin','super_admin') @Get('admin/settings') allSettings(){return this.store.allSettings();}
  @Roles('super_admin') @Put('admin/settings/payment') updateSettings(@Body() dto: PaymentSettingsDto,@CurrentUser() user: AuthUser) { return this.store.updateSettings(dto,user); }
  @Roles('super_admin') @Put('admin/settings/store') updateStoreSettings(@Body() dto:StoreSettingsDto,@CurrentUser() user:AuthUser){return this.store.updateStoreSettings(dto,user);}

  @Roles('super_admin') @Get('admin/users') users(@Query('role') role='') { return this.store.users(role); }
  @Roles('admin','super_admin') @Get('admin/drivers') drivers() { return this.store.users('driver'); }
  @Roles('super_admin') @Patch('admin/users/:id/role') updateRole(@Param('id') id:string,@Body() dto:UserRoleDto,@CurrentUser() user:AuthUser) { return this.store.updateRole(id,dto.role,user); }
  @Roles('super_admin') @Patch('admin/users/:id/status') updateUserStatus(@Param('id') id:string,@Body() dto:UserStatusDto,@CurrentUser() user:AuthUser){return this.store.updateUserStatus(id,dto.isActive,user);}
  @Roles('super_admin') @Get('admin/audit-logs') auditLogs(){return this.store.auditLogs();}
  @Roles('super_admin') @Get('admin/notifications') notificationHistory(){return this.notifications.history();}
}
