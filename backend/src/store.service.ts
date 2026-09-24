import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "crypto";

import { DatabaseService } from "./database.service";
import {
  AssignDriverDto,
  CategoryDto,
  CreateOrderDto,
  DeliveryStatusDto,
  InventoryAdjustmentDto,
  OrderStatusDto,
  PaymentClaimDto,
  PaymentReviewDto,
  PaymentSettingsDto,
  ProductDto,
  StoreSettingsDto,
} from "./dto";
import { MomoService } from "./momo.service";
import { MediaService } from "./media.service";
import { NotificationService } from "./notification.service";
import { AuthUser } from "./security";

@Injectable()
export class StoreService {
  constructor(
    private readonly db: DatabaseService,
    private readonly momo: MomoService,
    private readonly media:MediaService,
    private readonly notifications:NotificationService,
  ) {}

  async dashboard() {
    const result = await this.db.query(`SELECT
      (SELECT coalesce(sum(total_rwf),0)::int FROM orders WHERE status NOT IN ('awaiting_payment','cancelled') AND created_at::date=current_date) AS "todaySalesRwf",
      (SELECT count(*)::int FROM orders WHERE created_at::date=current_date) AS "todayOrders",
      (SELECT count(*)::int FROM orders WHERE status='awaiting_payment') AS "awaitingPayment",
      (SELECT count(*)::int FROM products WHERE active=true) AS "activeProducts",
      (SELECT count(*)::int FROM products WHERE active=true AND stock<=low_stock_threshold) AS "lowStockProducts",
      (SELECT count(*)::int FROM deliveries WHERE status IN ('assigned','picked_up','out_for_delivery')) AS "activeDeliveries",
      (SELECT count(*)::int FROM deliveries WHERE status='delivered' AND delivered_at::date=current_date) AS "deliveredToday",
      (SELECT count(*)::int FROM users WHERE is_active=true) AS "activeUsers"`);
    return result.rows[0];
  }

  async products(includeInactive = false, search = "", categoryId = "") {
    const params: unknown[] = [];
    const where: string[] = [];
    if (!includeInactive) where.push("p.active=true");
    if (search.trim()) {
      params.push(`%${search.trim()}%`);
      where.push(
        `(p.name ILIKE $${params.length} OR p.sku ILIKE $${params.length})`,
      );
    }
    if (categoryId) {
      params.push(categoryId);
      where.push(`p.category_id=$${params.length}`);
    }
    const result = await this.db.query(
      `SELECT p.id,p.name,p.category,p.category_id AS "categoryId",p.description,p.price_rwf AS "priceRwf",p.stock,p.image_url AS "imageUrl",p.image_public_id AS "imagePublicId",p.badge,p.sku,p.low_stock_threshold AS "lowStockThreshold",p.active,p.created_at AS "createdAt",p.updated_at AS "updatedAt" FROM products p ${where.length ? `WHERE ${where.join(" AND ")}` : ""} ORDER BY p.created_at DESC`,
      params,
    );
    return result.rows;
  }

  async categories(includeInactive = false) {
    const result = await this.db.query(
      `SELECT c.id,c.name,c.slug,c.description,c.image_url AS "imageUrl",c.active,c.sort_order AS "sortOrder",count(p.id)::int AS "productCount" FROM categories c LEFT JOIN products p ON p.category_id=c.id ${includeInactive ? "" : "WHERE c.active=true"} GROUP BY c.id ORDER BY c.sort_order,c.name`,
    );
    return result.rows;
  }

  async createCategory(dto: CategoryDto, user: AuthUser) {
    const slug = this.slug(dto.name);
    if (!slug) throw new BadRequestException("Category name is invalid");
    try {
      const r = await this.db.query(
        "INSERT INTO categories(name,slug,description,image_url,active,sort_order) VALUES($1,$2,$3,$4,$5,$6) RETURNING *",
        [
          dto.name.trim(),
          slug,
          dto.description?.trim() ?? "",
          dto.imageUrl ?? null,
          dto.active ?? true,
          dto.sortOrder ?? 0,
        ],
      );
      await this.audit(user, "category.create", "category", r.rows[0].id, {
        name: dto.name,
      });
      await this.notifications.admins('category.created','Category created',`${dto.name.trim()} was added to the Mimi Store catalogue.`);
      return r.rows[0];
    } catch (e) {
      if ((e as { code?: string }).code === "23505")
        throw new BadRequestException("Category already exists");
      throw e;
    }
  }

  async updateCategory(id: string, dto: CategoryDto, user: AuthUser) {
    const slug = this.slug(dto.name);
    const r = await this.db.query(
      "UPDATE categories SET name=$2,slug=$3,description=$4,image_url=$5,active=$6,sort_order=$7,updated_at=now() WHERE id=$1 RETURNING *",
      [
        id,
        dto.name.trim(),
        slug,
        dto.description?.trim() ?? "",
        dto.imageUrl ?? null,
        dto.active ?? true,
        dto.sortOrder ?? 0,
      ],
    );
    if (!r.rows[0]) throw new NotFoundException("Category not found");
    await this.db.query(
      "UPDATE products SET category=$2,updated_at=now() WHERE category_id=$1",
      [id, dto.name.trim()],
    );
    await this.audit(user, "category.update", "category", id, {
      name: dto.name,
    });
    await this.notifications.admins('category.updated','Category updated',`${dto.name.trim()} was updated in the Mimi Store catalogue.`);
    return r.rows[0];
  }

  async createProduct(dto: ProductDto, user: AuthUser) {
    const category = await this.resolveCategory(dto.categoryId, dto.category);
    const r = await this.db.query(
      "INSERT INTO products(name,category,category_id,description,price_rwf,stock,image_url,image_public_id,badge,sku,low_stock_threshold,active) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id",
      [
        dto.name.trim(),
        category.name,
        category.id,
        dto.description?.trim() ?? "",
        dto.priceRwf,
        dto.stock,
        dto.imageUrl ?? null,
        dto.imagePublicId ?? null,
        dto.badge?.trim() || null,
        dto.sku?.trim() || null,
        dto.lowStockThreshold ?? 5,
        dto.active ?? true,
      ],
    );
    if (dto.stock > 0)
      await this.db.query(
        "INSERT INTO inventory_movements(product_id,quantity_delta,reason,created_by) VALUES($1,$2,$3,$4)",
        [r.rows[0].id, dto.stock, "Opening stock", user.sub],
      );
    await this.audit(user, "product.create", "product", r.rows[0].id, {
      name: dto.name,
    });
    await this.notifications.admins('product.created','Product created',`${dto.name.trim()} was created with ${dto.stock} item(s) in stock at ${dto.priceRwf.toLocaleString()} RWF.`);
    return (await this.products(true, dto.name)).find(
      (item: any) => item.id === r.rows[0].id,
    );
  }

  async updateProduct(id: string, dto: ProductDto, user: AuthUser) {
    const category = await this.resolveCategory(dto.categoryId, dto.category);
    const old = await this.db.query<{ stock: number;image_public_id:string|null }>(
      "SELECT stock,image_public_id FROM products WHERE id=$1",
      [id],
    );
    if (!old.rows[0]) throw new NotFoundException("Product not found");
    const r = await this.db.query(
      "UPDATE products SET name=$2,category=$3,category_id=$4,description=$5,price_rwf=$6,stock=$7,image_url=$8,image_public_id=$9,badge=$10,sku=$11,low_stock_threshold=$12,active=$13,updated_at=now() WHERE id=$1 RETURNING id",
      [
        id,
        dto.name.trim(),
        category.name,
        category.id,
        dto.description?.trim() ?? "",
        dto.priceRwf,
        dto.stock,
        dto.imageUrl ?? null,
        dto.imagePublicId ?? null,
        dto.badge?.trim() || null,
        dto.sku?.trim() || null,
        dto.lowStockThreshold ?? 5,
        dto.active ?? true,
      ],
    );
    const delta = dto.stock - old.rows[0].stock;
    if (delta)
      await this.db.query(
        "INSERT INTO inventory_movements(product_id,quantity_delta,reason,created_by) VALUES($1,$2,$3,$4)",
        [id, delta, "Product edit adjustment", user.sub],
      );
    await this.audit(user, "product.update", "product", id, { name: dto.name });
    if(old.rows[0].image_public_id&&old.rows[0].image_public_id!==dto.imagePublicId){try{await this.media.deleteProductImage(old.rows[0].image_public_id);}catch(error){await this.audit(user,'product.image.delete_failed','product',id,{publicId:old.rows[0].image_public_id,error:(error as Error).message});}}
    await this.notifications.admins('product.updated','Product updated',`${dto.name.trim()} was updated. Current stock: ${dto.stock}; price: ${dto.priceRwf.toLocaleString()} RWF.`);
    return (await this.products(true, dto.name)).find(
      (item: any) => item.id === r.rows[0].id,
    );
  }

  async adjustInventory(
    id: string,
    dto: InventoryAdjustmentDto,
    user: AuthUser,
  ) {
    if (dto.quantityDelta === 0)
      throw new BadRequestException("Quantity change cannot be zero");
    const changed=await this.db.transaction(async (client) => {
      const changed = await client.query(
        "UPDATE products SET stock=stock+$2,updated_at=now() WHERE id=$1 AND stock+$2>=0 RETURNING id,stock",
        [id, dto.quantityDelta],
      );
      if (!changed.rows[0])
        throw new BadRequestException(
          "Product not found or stock would become negative",
        );
      await client.query(
        "INSERT INTO inventory_movements(product_id,quantity_delta,reason,reference,created_by) VALUES($1,$2,$3,$4,$5)",
        [
          id,
          dto.quantityDelta,
          dto.reason.trim(),
          dto.reference?.trim() || null,
          user.sub,
        ],
      );
      await client.query(
        "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id,details) VALUES($1,'inventory.adjust','product',$2,$3)",
        [user.sub, id, JSON.stringify(dto)],
      );
      return changed.rows[0];
    });
    const product=await this.db.query<{name:string}>('SELECT name FROM products WHERE id=$1',[id]);
    await this.notifications.admins('inventory.adjusted','Inventory adjusted',`${product.rows[0]?.name??'A product'} stock changed by ${dto.quantityDelta}. Reason: ${dto.reason.trim()}.`);
    return changed;
  }

  async inventoryHistory(productId: string) {
    const r = await this.db.query(
      "SELECT m.*,u.full_name AS created_by_name FROM inventory_movements m LEFT JOIN users u ON u.id=m.created_by WHERE m.product_id=$1 ORDER BY m.created_at DESC LIMIT 100",
      [productId],
    );
    return r.rows;
  }

  async settings() {
    const r = await this.db.query(
      "SELECT setting_value FROM app_settings WHERE setting_key='payment'",
    );
    return r.rows[0]?.setting_value ?? {};
  }
  async allSettings() {
    const r = await this.db.query(
      "SELECT setting_key,setting_value FROM app_settings WHERE setting_key IN ('payment','store')",
    );
    return Object.fromEntries(
      r.rows.map((x: any) => [x.setting_key, x.setting_value]),
    );
  }
  async updateSettings(dto: PaymentSettingsDto, user: AuthUser) {
    await this.saveSetting("payment", dto, user);
    await this.notifications.admins('settings.payment.updated','Payment settings updated',`Mimi Store payment and delivery settings were updated.`);
    return dto;
  }
  async updateStoreSettings(dto: StoreSettingsDto, user: AuthUser) {
    await this.saveSetting("store", { ...dto, currency: "RWF" }, user);
    await this.notifications.admins('settings.store.updated','Store settings updated',`Mimi Store business contact settings were updated.`);
    return dto;
  }

  async createOrder(dto: CreateOrderDto, user: AuthUser) {
    const settings = (await this.settings()) as {
      deliveryFeeRwf?: number;
      freeDeliveryThresholdRwf?: number;
    };
    const unique = new Map<string, number>();
    for (const item of dto.items)
      unique.set(
        item.productId,
        (unique.get(item.productId) ?? 0) + item.quantity,
      );
    const ids = [...unique.keys()];
    const products = await this.db.query<{
      id: string;
      name: string;
      price_rwf: number;
      stock: number;
    }>(
      "SELECT id,name,price_rwf,stock FROM products WHERE active=true AND id=ANY($1::uuid[])",
      [ids],
    );
    if (products.rows.length !== ids.length)
      throw new BadRequestException("One or more products are unavailable");
    let subtotal = 0;
    for (const product of products.rows) {
      const quantity = unique.get(product.id)!;
      if (product.stock < quantity)
        throw new BadRequestException(`${product.name} has insufficient stock`);
      subtotal += product.price_rwf * quantity;
    }
    const delivery =
      subtotal >= (settings.freeDeliveryThresholdRwf ?? 100000)
        ? 0
        : (settings.deliveryFeeRwf ?? 2500);
    const orderNumber = `MS-${Date.now().toString().slice(-8)}-${Math.floor(Math.random() * 90 + 10)}`;
    const order = await this.db.transaction(async (client) => {
      const result = await client.query<{
        id: string;
        order_number: string;
        total_rwf: number;
      }>(
        "INSERT INTO orders(order_number,customer_id,subtotal_rwf,delivery_rwf,total_rwf,delivery_address,latitude,longitude,customer_phone) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id,order_number,total_rwf",
        [
          orderNumber,
          user.sub,
          subtotal,
          delivery,
          subtotal + delivery,
          dto.deliveryAddress,
          dto.latitude ?? null,
          dto.longitude ?? null,
          dto.customerPhone,
        ],
      );
      for (const product of products.rows) {
        const quantity = unique.get(product.id)!;
        const changed = await client.query(
          "UPDATE products SET stock=stock-$2,updated_at=now() WHERE id=$1 AND stock>=$2",
          [product.id, quantity],
        );
        if (!changed.rowCount)
          throw new BadRequestException(
            `${product.name} is no longer available`,
          );
        await client.query(
          "INSERT INTO order_items(order_id,product_id,product_name,unit_price_rwf,quantity,line_total_rwf) VALUES($1,$2,$3,$4,$5,$6)",
          [
            result.rows[0].id,
            product.id,
            product.name,
            product.price_rwf,
            quantity,
            product.price_rwf * quantity,
          ],
        );
        await client.query(
          "INSERT INTO inventory_movements(product_id,quantity_delta,reason,reference,created_by) VALUES($1,$2,$3,$4,$5)",
          [product.id, -quantity, "Customer order", orderNumber, user.sub],
        );
      }
      await client.query("INSERT INTO deliveries(order_id) VALUES($1)", [
        result.rows[0].id,
      ]);
      return result.rows[0];
    });
    await this.audit(user, "order.create", "order", order.id, { orderNumber });
    await this.notifications.user(user.sub,'order.created',`Order ${orderNumber} received`,`We received your order ${orderNumber} for ${order.total_rwf.toLocaleString()} RWF. Complete payment to continue processing.`);
    await this.notifications.admins('order.created',`New order ${orderNumber}`,`A new order for ${order.total_rwf.toLocaleString()} RWF is awaiting payment.`);
    return order;
  }

  async orders(user: AuthUser, status = "") {
    const params: unknown[] = [];
    const where: string[] = [];
    if (user.role === "customer") {
      params.push(user.sub);
      where.push(`o.customer_id=$${params.length}`);
    } else if (user.role === "driver") {
      params.push(user.sub);
      where.push(`o.assigned_driver_id=$${params.length}`);
    }
    if (status) {
      params.push(status);
      where.push(`o.status=$${params.length}`);
    }
    const r = await this.db.query(
      `SELECT o.id,o.order_number AS "orderNumber",o.status,o.subtotal_rwf AS "subtotalRwf",o.delivery_rwf AS "deliveryRwf",o.total_rwf AS "totalRwf",o.delivery_address AS "deliveryAddress",o.latitude,o.longitude,o.customer_phone AS "customerPhone",o.created_at AS "createdAt",o.updated_at AS "updatedAt",u.full_name AS "customerName",u.email AS "customerEmail",d.full_name AS "driverName",o.assigned_driver_id AS "driverId",p.id AS "paymentId",p.status AS "paymentStatus",p.provider_reference AS "paymentReference",dv.id AS "deliveryId",dv.status AS "deliveryStatus",coalesce(json_agg(json_build_object('id',oi.id,'productId',oi.product_id,'name',oi.product_name,'unitPriceRwf',oi.unit_price_rwf,'quantity',oi.quantity,'lineTotalRwf',oi.line_total_rwf)) FILTER (WHERE oi.id IS NOT NULL),'[]') AS items FROM orders o JOIN users u ON u.id=o.customer_id LEFT JOIN users d ON d.id=o.assigned_driver_id LEFT JOIN payments p ON p.order_id=o.id LEFT JOIN deliveries dv ON dv.order_id=o.id LEFT JOIN order_items oi ON oi.order_id=o.id ${where.length ? `WHERE ${where.join(" AND ")}` : ""} GROUP BY o.id,u.full_name,u.email,d.full_name,p.id,dv.id ORDER BY o.created_at DESC LIMIT 500`,
      params,
    );
    return r.rows;
  }

  async assignDriver(orderId: string, dto: AssignDriverDto, user: AuthUser) {
    const driver = await this.db.query(
      "SELECT id FROM users WHERE id=$1 AND role='driver' AND is_active=true",
      [dto.driverId],
    );
    if (!driver.rows[0])
      throw new BadRequestException("Active driver not found");
    const r = await this.db.query(
      "UPDATE orders SET assigned_driver_id=$2,status='assigned',updated_at=now() WHERE id=$1 AND status IN ('payment_confirmed','ready_for_pickup','assigned') RETURNING *",
      [orderId, dto.driverId],
    );
    if (!r.rows[0])
      throw new BadRequestException(
        "Only paid or ready orders can be assigned",
      );
    await this.db.query(
      "INSERT INTO deliveries(order_id,driver_id,status,assigned_at) VALUES($1,$2,'assigned',now()) ON CONFLICT(order_id) DO UPDATE SET driver_id=$2,status='assigned',assigned_at=now(),updated_at=now()",
      [orderId, dto.driverId],
    );
    await this.audit(user, "delivery.assign", "order", orderId, {
      driverId: dto.driverId,
    });
    const order=await this.db.query<{order_number:string;customer_id:string;delivery_address:string}>('SELECT order_number,customer_id,delivery_address FROM orders WHERE id=$1',[orderId]);
    if(order.rows[0]){
      await this.notifications.user(dto.driverId,'delivery.assigned',`Delivery ${order.rows[0].order_number} assigned`,`You have been assigned order ${order.rows[0].order_number}. Delivery location: ${order.rows[0].delivery_address}. Open Mimi Store to view details and directions.`);
      await this.notifications.user(order.rows[0].customer_id,'delivery.assigned',`Driver assigned to ${order.rows[0].order_number}`,`A motor driver has been assigned to your order ${order.rows[0].order_number}.`);
    }
    return r.rows[0];
  }

  async updateOrderStatus(
    orderId: string,
    dto: OrderStatusDto,
    user: AuthUser,
  ) {
    if (dto.status === "cancelled")
      return this.cancelOrder(orderId, "Cancelled by staff", user);
    const allowed =
      user.role === "driver"
        ? ["out_for_delivery", "delivered"]
        : ["ready_for_pickup", "out_for_delivery", "delivered"];
    if (!allowed.includes(dto.status))
      throw new BadRequestException("Status transition is not permitted");
    const condition = user.role === "driver" ? "AND assigned_driver_id=$3" : "";
    const params =
      user.role === "driver"
        ? [orderId, dto.status, user.sub]
        : [orderId, dto.status];
    const r = await this.db.query(
      `UPDATE orders SET status=$2,updated_at=now() WHERE id=$1 ${condition} RETURNING *`,
      params,
    );
    if (!r.rows[0]) throw new NotFoundException("Order not found");
    await this.audit(user, "order.status", "order", orderId, {
      status: dto.status,
    });
    await this.notifyOrderCustomer(orderId,'order.status',`Order status updated`,`Your order is now ${dto.status.replaceAll('_',' ')}.`);
    return r.rows[0];
  }

  async cancelOrder(orderId: string, reason: string, user: AuthUser) {
    const result=await this.db.transaction(async (client) => {
      const r = await client.query(
        "UPDATE orders SET status='cancelled',cancellation_reason=$2,updated_at=now() WHERE id=$1 AND status NOT IN ('delivered','cancelled') RETURNING order_number",
        [orderId, reason],
      );
      if (!r.rows[0])
        throw new BadRequestException("Order cannot be cancelled");
      const items = await client.query<{
        product_id: string;
        quantity: number;
      }>("SELECT product_id,quantity FROM order_items WHERE order_id=$1", [
        orderId,
      ]);
      for (const item of items.rows) {
        await client.query(
          "UPDATE products SET stock=stock+$2,updated_at=now() WHERE id=$1",
          [item.product_id, item.quantity],
        );
        await client.query(
          "INSERT INTO inventory_movements(product_id,quantity_delta,reason,reference,created_by) VALUES($1,$2,$3,$4,$5)",
          [
            item.product_id,
            item.quantity,
            "Order cancellation",
            r.rows[0].order_number,
            user.sub,
          ],
        );
      }
      await client.query(
        "UPDATE deliveries SET status='failed',notes=$2,updated_at=now() WHERE order_id=$1",
        [orderId, reason],
      );
      await client.query(
        "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id,details) VALUES($1,'order.cancel','order',$2,$3)",
        [user.sub, orderId, JSON.stringify({ reason })],
      );
      return { success: true };
    });
    await this.notifyOrderCustomer(orderId,'order.cancelled','Order cancelled',`Your order was cancelled. Reason: ${reason}.`);
    await this.notifications.admins('order.cancelled','Order cancelled',`Order ${orderId} was cancelled. Reason: ${reason}.`);
    return result;
  }

  async deliveries(user: AuthUser) {
    const params = user.role === "driver" ? [user.sub] : [];
    const where = user.role === "driver" ? "WHERE dv.driver_id=$1" : "";
    const r = await this.db.query(
      `SELECT dv.id,dv.order_id AS "orderId",dv.driver_id AS "driverId",dv.status,dv.notes,dv.proof_url AS "proofUrl",dv.assigned_at AS "assignedAt",dv.picked_up_at AS "pickedUpAt",dv.delivered_at AS "deliveredAt",o.order_number AS "orderNumber",o.delivery_address AS "deliveryAddress",o.latitude,o.longitude,o.customer_phone AS "customerPhone",o.total_rwf AS "totalRwf",u.full_name AS "customerName",d.full_name AS "driverName" FROM deliveries dv JOIN orders o ON o.id=dv.order_id JOIN users u ON u.id=o.customer_id LEFT JOIN users d ON d.id=dv.driver_id ${where} ORDER BY CASE WHEN dv.status='delivered' THEN 1 ELSE 0 END,o.created_at DESC`,
      params,
    );
    return r.rows;
  }
  async updateDelivery(id: string, dto: DeliveryStatusDto, user: AuthUser) {
    const condition = user.role === "driver" ? "AND driver_id=$5" : "";
    const statusOrder =
      dto.status === "picked_up"
        ? "out_for_delivery"
        : dto.status === "delivered"
          ? "delivered"
          : dto.status === "out_for_delivery"
            ? "out_for_delivery"
            : null;
    const params =
      user.role === "driver"
        ? [id, dto.status, dto.notes ?? null, dto.proofUrl ?? null, user.sub]
        : [id, dto.status, dto.notes ?? null, dto.proofUrl ?? null];
    const r = await this.db.query(
      `UPDATE deliveries SET status=$2,notes=coalesce($3,notes),proof_url=coalesce($4,proof_url),picked_up_at=CASE WHEN $2='picked_up' THEN now() ELSE picked_up_at END,delivered_at=CASE WHEN $2='delivered' THEN now() ELSE delivered_at END,updated_at=now() WHERE id=$1 ${condition} RETURNING order_id`,
      params,
    );
    if (!r.rows[0]) throw new NotFoundException("Delivery not found");
    if (statusOrder)
      await this.db.query(
        "UPDATE orders SET status=$2,updated_at=now() WHERE id=$1",
        [r.rows[0].order_id, statusOrder],
      );
    await this.audit(user, "delivery.status", "delivery", id, {
      status: dto.status,
    });
    await this.notifyOrderCustomer(r.rows[0].order_id,'delivery.status','Delivery update',`Your delivery is now ${dto.status.replaceAll('_',' ')}${dto.notes?.trim()?`. Note: ${dto.notes.trim()}`:''}.`);
    return { success: true };
  }

  async initiatePayment(orderId: string, user: AuthUser) {
    const result = await this.db.query<{
      id: string;
      order_number: string;
      total_rwf: number;
      customer_phone: string;
    }>(
      "SELECT id,order_number,total_rwf,customer_phone FROM orders WHERE id=$1 AND customer_id=$2 AND status=$3",
      [orderId, user.sub, "awaiting_payment"],
    );
    const order = result.rows[0];
    if (!order) throw new NotFoundException("Payable order not found");
    const settings = (await this.settings()) as {
      paymentMode?: string;
      momoNumber?: string;
    };
    const existing = await this.db.query<{
      reference: string;
      status: string;
      provider: string;
    }>(
      "SELECT provider_reference AS reference,status,provider FROM payments WHERE order_id=$1",
      [order.id],
    );
    if (existing.rows[0])
      return {
        ...existing.rows[0],
        status:
          existing.rows[0].provider === "manual_momo"
            ? "manual"
            : existing.rows[0].status,
        momoNumber: settings.momoNumber,
      };
    const reference = randomUUID();
    const provider =
      this.momo.enabled && settings.paymentMode === "momo_api"
        ? "mtn_momo"
        : "manual_momo";
    await this.db.query(
      "INSERT INTO payments(order_id,provider,provider_reference,amount_rwf,payer_phone) VALUES($1,$2,$3,$4,$5)",
      [order.id, provider, reference, order.total_rwf, order.customer_phone],
    );
    await this.notifications.user(user.sub,'payment.started',`Payment started for ${order.order_number}`,`Payment of ${order.total_rwf.toLocaleString()} RWF was started for order ${order.order_number}.`);
    if (!this.momo.enabled || settings.paymentMode !== "momo_api") {
      return { reference, status: "manual", momoNumber: settings.momoNumber };
    }
    try {
      return await this.momo.requestToPay(
        reference,
        order.total_rwf,
        order.customer_phone,
        order.order_number,
      );
    } catch (error) {
      await this.db.query(
        "UPDATE payments SET status='failed',provider_payload=$2 WHERE provider_reference=$1",
        [reference, JSON.stringify({ message: (error as Error).message })],
      );
      throw error;
    }
  }

  async payments(status = "") {
    const params = status ? [status] : [];
    const r = await this.db.query(
      `SELECT p.id,p.order_id AS "orderId",p.provider,p.provider_reference AS "reference",p.amount_rwf AS "amountRwf",p.payer_phone AS "payerPhone",p.status,p.customer_notified_at AS "customerNotifiedAt",p.customer_reference AS "customerReference",p.customer_note AS "customerNote",p.reviewed_at AS "reviewedAt",p.review_note AS "reviewNote",p.created_at AS "createdAt",p.updated_at AS "updatedAt",o.order_number AS "orderNumber",u.full_name AS "customerName",reviewer.full_name AS "reviewerName" FROM payments p JOIN orders o ON o.id=p.order_id JOIN users u ON u.id=o.customer_id LEFT JOIN users reviewer ON reviewer.id=p.reviewed_by ${status ? "WHERE p.status=$1" : ""} ORDER BY p.created_at DESC LIMIT 500`,
      params,
    );
    return r.rows;
  }

  async notifyManualPayment(
    orderId: string,
    dto: PaymentClaimDto,
    user: AuthUser,
  ) {
    const result=await this.db.transaction(async (client) => {
      const reference = dto.transactionReference?.trim() || null;
      const r = await client.query(
        "UPDATE payments p SET status='pending',customer_notified_at=now(),customer_reference=$3,customer_note=$4,reviewed_by=null,reviewed_at=null,review_note=null,updated_at=now() FROM orders o WHERE p.order_id=o.id AND o.id=$1 AND o.customer_id=$2 AND o.status='awaiting_payment' AND p.provider='manual_momo' AND p.status IN ('pending','failed') RETURNING p.id",
        [orderId, user.sub, reference, dto.note?.trim() || null],
      );
      if (!r.rows[0])
        throw new BadRequestException(
          "Manual payment for this order cannot be notified",
        );
      await client.query(
        "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id,details) VALUES($1,'payment.claim','payment',$2,$3)",
        [
          user.sub,
          r.rows[0].id,
          JSON.stringify({ transactionReference: reference }),
        ],
      );
      return { success: true, status: "pending_review" };
    });
    await this.notifications.user(user.sub,'payment.reported','Payment notification received','We received your payment notification. An administrator will verify the business Mobile Money account.');
    await this.notifications.admins('payment.reported','Customer reported a payment',`A customer reported payment for order ${orderId}${dto.transactionReference?.trim()?` with reference ${dto.transactionReference.trim()}`:''}. Review it in the Payments dashboard.`);
    return result;
  }

  async reviewManualPayment(
    id: string,
    approved: boolean,
    dto: PaymentReviewDto,
    user: AuthUser,
  ) {
    const result=await this.db.transaction(async (client) => {
      const next = approved ? "successful" : "failed";
      const note = dto.note?.trim() || null;
      const r = await client.query(
        "UPDATE payments SET status=$2::payment_status,reviewed_by=$3::uuid,reviewed_at=now(),review_note=$4::text,updated_at=now(),provider_payload=coalesce(provider_payload,'{}'::jsonb)||jsonb_build_object('reviewedBy',$3::text,'mode','manual','approved',$5::boolean) WHERE id=$1::uuid AND status='pending' AND provider='manual_momo' AND customer_notified_at IS NOT NULL RETURNING order_id",
        [id, next, user.sub, note, approved],
      );
      if (!r.rows[0])
        throw new BadRequestException(
          "A customer payment notification is required before review",
        );
      if (approved) {
        const order = await client.query(
          "UPDATE orders SET status='payment_confirmed',updated_at=now() WHERE id=$1 AND status='awaiting_payment' RETURNING id",
          [r.rows[0].order_id],
        );
        if (!order.rows[0])
          throw new BadRequestException("Order is no longer awaiting payment");
      }
      await client.query(
        "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id,details) VALUES($1,$2,'payment',$3,$4)",
        [
          user.sub,
          approved ? "payment.approve" : "payment.reject",
          id,
          JSON.stringify({ mode: "manual", note }),
        ],
      );
      return { success: true, status: next };
    });
    const payment=await this.db.query<{order_id:string}>('SELECT order_id FROM payments WHERE id=$1',[id]);
    if(payment.rows[0])await this.notifyOrderCustomer(payment.rows[0].order_id,approved?'payment.approved':'payment.rejected',approved?'Payment approved':'Payment rejected',approved?'Your payment was approved. We will now prepare your order.':`Your payment notification was rejected${dto.note?.trim()?`. Reason: ${dto.note.trim()}`:''}.`);
    await this.notifications.admins(approved?'payment.approved':'payment.rejected',approved?'Payment approved':'Payment rejected',`Payment ${id} was ${approved?'approved':'rejected'}.`);
    return result;
  }
  async refreshPayment(reference: string) {
    const status = await this.momo.status(reference);
    const mapped =
      status.status === "SUCCESSFUL"
        ? "successful"
        : status.status === "FAILED"
          ? "failed"
          : "pending";
    const previous=await this.db.query<{order_id:string;status:string}>('SELECT order_id,status FROM payments WHERE provider_reference=$1',[reference]);
    await this.db.transaction(async (client) => {
      const payment = await client.query<{ order_id: string }>(
        "UPDATE payments SET status=$2,provider_payload=$3,updated_at=now() WHERE provider_reference=$1 RETURNING order_id",
        [reference, mapped, JSON.stringify(status)],
      );
      if (mapped === "successful" && payment.rows[0])
        await client.query(
          "UPDATE orders SET status='payment_confirmed',updated_at=now() WHERE id=$1 AND status='awaiting_payment'",
          [payment.rows[0].order_id],
        );
    });
    if(previous.rows[0]&&previous.rows[0].status!==mapped&&mapped!=='pending')await this.notifyOrderCustomer(previous.rows[0].order_id,mapped==='successful'?'payment.approved':'payment.failed',mapped==='successful'?'Payment confirmed':'Payment failed',mapped==='successful'?'Your Mobile Money payment was confirmed. We will prepare your order.':'The payment provider reported that your payment failed. Please try again.');
    return { reference, status: mapped };
  }
  async reconcilePayments() {
    const settings = (await this.settings()) as { paymentMode?: string };
    if (!this.momo.enabled || settings.paymentMode !== "momo_api") return [];
    const pending = await this.db.query<{ provider_reference: string }>(
      "SELECT provider_reference FROM payments WHERE status='pending' AND provider='mtn_momo' ORDER BY created_at LIMIT 100",
    );
    const results = [];
    for (const row of pending.rows) {
      try {
        results.push(await this.refreshPayment(row.provider_reference));
      } catch (e) {
        results.push({
          reference: row.provider_reference,
          status: "error",
          message: (e as Error).message,
        });
      }
    }
    return results;
  }

  async users(role = "") {
    const params = role ? [role] : [];
    const r = await this.db.query(
      `SELECT id,email,full_name AS "fullName",phone,role,is_active AS "isActive",created_at AS "createdAt" FROM users ${role ? "WHERE role=$1" : ""} ORDER BY created_at DESC`,
      params,
    );
    return r.rows;
  }
  async updateRole(id: string, role: string, user: AuthUser) {
    const target = await this.db.query("SELECT role FROM users WHERE id=$1", [
      id,
    ]);
    if (!target.rows[0]) throw new NotFoundException("User not found");
    if (target.rows[0].role === "super_admin")
      throw new ForbiddenException("Super Admin role cannot be changed here");
    const r = await this.db.query(
      'UPDATE users SET role=$2,updated_at=now() WHERE id=$1 RETURNING id,email,full_name AS "fullName",role',
      [id, role],
    );
    await this.audit(user, "user.role", "user", id, { role });
    await this.notifications.user(id,'account.role.updated','Your Mimi Store role changed',`Your account role is now ${role.replaceAll('_',' ')}.`);
    await this.notifications.admins('account.role.updated','User role updated',`${r.rows[0].fullName} now has the ${role.replaceAll('_',' ')} role.`);
    return r.rows[0];
  }
  async updateUserStatus(id: string, isActive: boolean, user: AuthUser) {
    if (id === user.sub)
      throw new BadRequestException("You cannot disable your own account");
    const target = await this.db.query("SELECT role FROM users WHERE id=$1", [
      id,
    ]);
    if (!target.rows[0]) throw new NotFoundException("User not found");
    if (target.rows[0].role === "super_admin")
      throw new ForbiddenException("Super Admin cannot be disabled here");
    await this.db.query(
      "UPDATE users SET is_active=$2,updated_at=now() WHERE id=$1",
      [id, isActive],
    );
    if (!isActive)
      await this.db.query(
        "UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL",
        [id],
      );
    await this.audit(user, "user.status", "user", id, { isActive });
    await this.notifications.user(id,'account.status.updated','Your Mimi Store account status changed',`Your account is now ${isActive?'active':'disabled'}.`);
    await this.notifications.admins('account.status.updated','User status updated',`User ${id} was ${isActive?'activated':'disabled'}.`);
    return { success: true };
  }
  async auditLogs() {
    const r = await this.db.query(
      'SELECT a.id,a.action,a.entity_type AS "entityType",a.entity_id AS "entityId",a.details,a.created_at AS "createdAt",u.full_name AS "actorName",u.email AS "actorEmail" FROM audit_logs a LEFT JOIN users u ON u.id=a.actor_id ORDER BY a.created_at DESC LIMIT 500',
    );
    return r.rows;
  }

  private async resolveCategory(categoryId: string | undefined, name: string) {
    if (categoryId) {
      const r = await this.db.query<{ id: string; name: string }>(
        "SELECT id,name FROM categories WHERE id=$1 AND active=true",
        [categoryId],
      );
      if (r.rows[0]) return r.rows[0];
    }
    const r = await this.db.query<{ id: string; name: string }>(
      "SELECT id,name FROM categories WHERE lower(name)=lower($1) AND active=true",
      [name.trim()],
    );
    if (!r.rows[0]) throw new BadRequestException("Select an active category");
    return r.rows[0];
  }
  private async notifyOrderCustomer(orderId:string,eventType:string,subject:string,message:string){const order=await this.db.query<{customer_id:string;order_number:string}>('SELECT customer_id,order_number FROM orders WHERE id=$1',[orderId]);if(order.rows[0])await this.notifications.user(order.rows[0].customer_id,eventType,`${subject}: ${order.rows[0].order_number}`,`${message}\n\nOrder: ${order.rows[0].order_number}`);}
  private slug(value: string) {
    return value
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "");
  }
  private async saveSetting(key: string, value: unknown, user: AuthUser) {
    await this.db.query(
      "INSERT INTO app_settings(setting_key,setting_value,updated_by,updated_at) VALUES($1,$2,$3,now()) ON CONFLICT(setting_key) DO UPDATE SET setting_value=excluded.setting_value,updated_by=excluded.updated_by,updated_at=now()",
      [key, JSON.stringify(value), user.sub],
    );
    await this.audit(user, "settings.update", "settings", key, {});
  }
  private async audit(
    user: AuthUser,
    action: string,
    entityType: string,
    entityId: string,
    details: unknown,
  ) {
    await this.db.query(
      "INSERT INTO audit_logs(actor_id,action,entity_type,entity_id,details) VALUES($1,$2,$3,$4,$5)",
      [user.sub, action, entityType, entityId, JSON.stringify(details)],
    );
  }
}
