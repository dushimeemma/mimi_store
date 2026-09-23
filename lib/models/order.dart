enum OrderStatus { awaitingPayment, confirmed, readyForPickup, assigned, outForDelivery, delivered, cancelled }

class StoreOrder {
  const StoreOrder({
    required this.id,
    required this.customer,
    required this.totalRwf,
    required this.area,
    required this.status,
  });

  final String id;
  final String customer;
  final int totalRwf;
  final String area;
  final OrderStatus status;

  StoreOrder copyWith({OrderStatus? status}) => StoreOrder(
        id: id,
        customer: customer,
        totalRwf: totalRwf,
        area: area,
        status: status ?? this.status,
      );

  factory StoreOrder.fromJson(Map<String,dynamic> json)=>StoreOrder(
    id:json['id'] as String,
    customer:(json['customer_name']??json['customerName']??'Customer').toString(),
    totalRwf:((json['total_rwf']??json['totalRwf']) as num).toInt(),
    area:(json['delivery_address']??json['area']??'').toString(),
    status:switch(json['status']){'payment_confirmed'=>OrderStatus.confirmed,'ready_for_pickup'=>OrderStatus.readyForPickup,'assigned'=>OrderStatus.assigned,'out_for_delivery'=>OrderStatus.outForDelivery,'delivered'=>OrderStatus.delivered,'cancelled'=>OrderStatus.cancelled,_=>OrderStatus.awaitingPayment},
  );
}
