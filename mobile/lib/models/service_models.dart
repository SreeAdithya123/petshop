/// Models for the services / demo / refund / address features added with the
/// account sidebar update. Hand-written fromJson like models.dart.
library;

DateTime? _date(Object? raw) => raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
DateTime _dateOrNow(Object? raw) => _date(raw) ?? DateTime.now();

/// A shop's bookable service (grooming, vet consult, ...). [shopName] comes
/// from the `shops(name)` embed on customer queries.
class ServiceItem {
  final String id;
  final String shopId;
  final String category; // vet|grooming|training|walking|daycare|boarding|trimming|bathing
  final String name;
  final String? description;
  final num price;
  final int? durationMinutes;
  final List<String> photoUrls;
  final String status; // pending | approved | suspended
  final DateTime createdAt;
  final String? shopName;

  const ServiceItem({
    required this.id,
    required this.shopId,
    required this.category,
    required this.name,
    this.description,
    required this.price,
    this.durationMinutes,
    this.photoUrls = const [],
    required this.status,
    required this.createdAt,
    this.shopName,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        category: json['category'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: json['price'] as num,
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
        photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? const [],
        status: json['status'] as String,
        createdAt: _dateOrNow(json['created_at']),
        shopName: (json['shops'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

class ServiceBooking {
  final String id;
  final String serviceId;
  final String shopId;
  final String customerId;
  final String? petId;
  final DateTime bookingDate;
  final String bookingTime; // 'HH:MM:SS'
  final String deliveryMode; // in_person | video | phone
  final String? videoRoomUrl;
  final String status; // pending | confirmed | completed | cancelled
  final num priceAtBooking;
  final String? notes;
  final DateTime createdAt;
  final String? serviceName;
  final String? serviceCategory;
  final String? shopName;

  const ServiceBooking({
    required this.id,
    required this.serviceId,
    required this.shopId,
    required this.customerId,
    this.petId,
    required this.bookingDate,
    required this.bookingTime,
    required this.deliveryMode,
    this.videoRoomUrl,
    required this.status,
    required this.priceAtBooking,
    this.notes,
    required this.createdAt,
    this.serviceName,
    this.serviceCategory,
    this.shopName,
  });

  factory ServiceBooking.fromJson(Map<String, dynamic> json) => ServiceBooking(
        id: json['id'] as String,
        serviceId: json['service_id'] as String,
        shopId: json['shop_id'] as String,
        customerId: json['customer_id'] as String,
        petId: json['pet_id'] as String?,
        bookingDate: _dateOrNow(json['booking_date']),
        bookingTime: json['booking_time'] as String? ?? '',
        deliveryMode: json['delivery_mode'] as String? ?? 'in_person',
        videoRoomUrl: json['video_room_url'] as String?,
        status: json['status'] as String,
        priceAtBooking: json['price_at_booking'] as num? ?? 0,
        notes: json['notes'] as String?,
        createdAt: _dateOrNow(json['created_at']),
        serviceName: json['service_name'] as String?,
        serviceCategory: json['service_category'] as String?,
        shopName: json['shop_name'] as String?,
      );
}

class CustomServiceRequest {
  final String id;
  final String customerId;
  final String title;
  final String description;
  final String? category;
  final String? petName;
  final String? petSpecies;
  final DateTime? preferredDate;
  final num? budget;
  final String status; // open|quoted|accepted|declined|cancelled|closed
  final String? shopId;
  final String? shopName;
  final num? quotedPrice;
  final String? responseMessage;
  final DateTime? respondedAt;
  final DateTime createdAt;

  const CustomServiceRequest({
    required this.id,
    required this.customerId,
    required this.title,
    required this.description,
    this.category,
    this.petName,
    this.petSpecies,
    this.preferredDate,
    this.budget,
    required this.status,
    this.shopId,
    this.shopName,
    this.quotedPrice,
    this.responseMessage,
    this.respondedAt,
    required this.createdAt,
  });

  factory CustomServiceRequest.fromJson(Map<String, dynamic> json) => CustomServiceRequest(
        id: json['id'] as String,
        customerId: json['customer_id'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String?,
        petName: json['pet_name'] as String?,
        petSpecies: json['pet_species'] as String?,
        preferredDate: _date(json['preferred_date']),
        budget: json['budget'] as num?,
        status: json['status'] as String,
        shopId: json['shop_id'] as String?,
        shopName: json['shop_name'] as String?,
        quotedPrice: json['quoted_price'] as num?,
        responseMessage: json['response_message'] as String?,
        respondedAt: _date(json['responded_at']),
        createdAt: _dateOrNow(json['created_at']),
      );
}

class DemoRequest {
  final String id;
  final String customerId;
  final String petId;
  final String shopId;
  final String? petName;
  final String? petBreed;
  final String? petSpecies;
  final String? shopName;
  final DateTime preferredDate;
  final String preferredTime; // free text label, e.g. "11:00 AM"
  final String mode; // video | in_person
  final String? message;
  final String status; // pending|approved|rejected|completed|cancelled
  final String? meetLink;
  final String? sellerNote;
  final DateTime? confirmedDate;
  final String? confirmedTime;
  final DateTime createdAt;

  const DemoRequest({
    required this.id,
    required this.customerId,
    required this.petId,
    required this.shopId,
    this.petName,
    this.petBreed,
    this.petSpecies,
    this.shopName,
    required this.preferredDate,
    required this.preferredTime,
    required this.mode,
    this.message,
    required this.status,
    this.meetLink,
    this.sellerNote,
    this.confirmedDate,
    this.confirmedTime,
    required this.createdAt,
  });

  factory DemoRequest.fromJson(Map<String, dynamic> json) => DemoRequest(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        petId: json['pet_id'] as String,
        shopId: json['shop_id'] as String,
        petName: json['pet_name'] as String?,
        petBreed: json['pet_breed'] as String?,
        petSpecies: json['pet_species'] as String?,
        shopName: json['shop_name'] as String?,
        preferredDate: _dateOrNow(json['preferred_date']),
        preferredTime: json['preferred_time'] as String? ?? '',
        mode: json['mode'] as String? ?? 'video',
        message: json['message'] as String?,
        status: json['status'] as String,
        meetLink: json['meet_link'] as String?,
        sellerNote: json['seller_note'] as String?,
        confirmedDate: _date(json['confirmed_date']),
        confirmedTime: json['confirmed_time'] as String?,
        createdAt: _dateOrNow(json['created_at']),
      );
}

class RefundRequest {
  final String id;
  final String orderId;
  final String customerId;
  final String shopId;
  final String reason;
  final String? notes;
  final num amount;
  final String status; // pending | approved | rejected
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final String? itemLabel;

  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.shopId,
    required this.reason,
    this.notes,
    required this.amount,
    required this.status,
    this.resolvedAt,
    required this.createdAt,
    this.itemLabel,
  });

  factory RefundRequest.fromJson(Map<String, dynamic> json) => RefundRequest(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        customerId: json['customer_id'] as String,
        shopId: json['shop_id'] as String,
        reason: json['reason'] as String? ?? '',
        notes: json['notes'] as String?,
        amount: json['amount'] as num? ?? 0,
        status: json['status'] as String? ?? 'pending',
        resolvedAt: _date(json['resolved_at']),
        createdAt: _dateOrNow(json['created_at']),
        itemLabel: json['item_label'] as String?,
      );
}

class SavedAddress {
  final String id;
  final String customerId;
  final String label;
  final String line1;
  final String? line2;
  final String city;
  final String? state;
  final String zip;
  final bool isDefault;
  final DateTime createdAt;

  const SavedAddress({
    required this.id,
    required this.customerId,
    required this.label,
    required this.line1,
    this.line2,
    required this.city,
    this.state,
    required this.zip,
    required this.isDefault,
    required this.createdAt,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        label: json['label'] as String? ?? 'Home',
        line1: json['line1'] as String? ?? '',
        line2: json['line2'] as String?,
        city: json['city'] as String? ?? '',
        state: json['state'] as String?,
        zip: json['zip'] as String? ?? '',
        isDefault: json['is_default'] as bool? ?? false,
        createdAt: _dateOrNow(json['created_at']),
      );

  /// One-line summary for lists: "12 MG Road, Indiranagar, Bengaluru, KA 560038".
  String get summary => [line1, if (line2 != null && line2!.isNotEmpty) line2!, city, if (state != null && state!.isNotEmpty) state!, zip]
      .join(', ');
}

/// One line returned by the `order_items_detailed(p_order_id)` RPC.
class OrderLine {
  final String orderItemId;
  final String itemType; // pet | product | service | ...
  final String itemId;
  final int quantity;
  final num priceAtPurchase;
  final String label;
  final String shopId;
  final String shopName;

  const OrderLine({
    required this.orderItemId,
    required this.itemType,
    required this.itemId,
    required this.quantity,
    required this.priceAtPurchase,
    required this.label,
    required this.shopId,
    required this.shopName,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        orderItemId: json['order_item_id'] as String,
        itemType: json['item_type'] as String? ?? '',
        itemId: json['item_id'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        priceAtPurchase: json['price_at_purchase'] as num? ?? 0,
        label: json['label'] as String? ?? '',
        shopId: json['shop_id'] as String? ?? '',
        shopName: json['shop_name'] as String? ?? '',
      );
}
