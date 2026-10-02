/// Data models mirroring the Supabase schema (public schema).
/// Kept as plain, hand-written fromJson factories -- no codegen, to keep
/// the mobile build simple and dependency-free.
library;

class Profile {
  final String id;
  final String role; // customer | shop_owner | admin
  final String name;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.role,
    required this.name,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        role: json['role'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Shop {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String licenseNumber;
  final String ownerId;
  final String? description;
  final String? bannerUrl;
  final String status; // pending | approved | suspended
  final String? contractVersion;
  final DateTime? contractAcceptedAt;
  final DateTime createdAt;
  final Profile? owner;

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.licenseNumber,
    required this.ownerId,
    this.description,
    this.bannerUrl,
    required this.status,
    this.contractVersion,
    this.contractAcceptedAt,
    required this.createdAt,
    this.owner,
  });

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        phone: json['phone'] as String,
        licenseNumber: json['license_number'] as String,
        ownerId: json['owner_id'] as String,
        description: json['description'] as String?,
        bannerUrl: json['banner_url'] as String?,
        status: json['status'] as String,
        contractVersion: json['contract_version'] as String?,
        contractAcceptedAt: json['contract_accepted_at'] != null
            ? DateTime.parse(json['contract_accepted_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        owner: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}

class Pet {
  final String id;
  final String shopId;
  final String species;
  final String breed;
  final int ageMonths;
  final num price;
  final String? description;
  final List<String> photoUrls;
  final String status; // available | reserved | sold
  final DateTime createdAt;
  final Shop? shop;

  Pet({
    required this.id,
    required this.shopId,
    required this.species,
    required this.breed,
    required this.ageMonths,
    required this.price,
    this.description,
    required this.photoUrls,
    required this.status,
    required this.createdAt,
    this.shop,
  });

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        species: json['species'] as String,
        breed: json['breed'] as String,
        ageMonths: json['age_months'] as int,
        price: json['price'] as num,
        description: json['description'] as String?,
        photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? const [],
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        shop: json['shops'] != null
            ? Shop.fromJson(json['shops'] as Map<String, dynamic>)
            : null,
      );
}

class Product {
  final String id;
  final String shopId;
  final String category; // medicine | store
  final String name;
  final String? description;
  final num price;
  final int stockQuantity;
  final List<String> photoUrls;
  final String status; // available | unavailable
  final DateTime createdAt;
  final Shop? shop;

  Product({
    required this.id,
    required this.shopId,
    required this.category,
    required this.name,
    this.description,
    required this.price,
    required this.stockQuantity,
    required this.photoUrls,
    required this.status,
    required this.createdAt,
    this.shop,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        category: json['category'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: json['price'] as num,
        stockQuantity: json['stock_quantity'] as int,
        photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? const [],
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        shop: json['shops'] != null
            ? Shop.fromJson(json['shops'] as Map<String, dynamic>)
            : null,
      );
}

class OrderRow {
  final String id;
  final String customerId;
  final String orderType; // pet_reservation | product_purchase | gift
  final String status; // pending | paid | fulfilled | cancelled
  final String paymentType; // deposit | full
  final num totalAmount;
  final DateTime createdAt;
  final Profile? customer;

  OrderRow({
    required this.id,
    required this.customerId,
    required this.orderType,
    required this.status,
    required this.paymentType,
    required this.totalAmount,
    required this.createdAt,
    this.customer,
  });

  factory OrderRow.fromJson(Map<String, dynamic> json) => OrderRow(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        orderType: json['order_type'] as String,
        status: json['status'] as String,
        paymentType: json['payment_type'] as String,
        totalAmount: json['total_amount'] as num,
        createdAt: DateTime.parse(json['created_at'] as String),
        customer: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}

class OrderItem {
  final String id;
  final String orderId;
  final String itemType; // pet | product
  final String itemId;
  final int quantity;
  final num priceAtPurchase;
  final DateTime createdAt;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemType,
    required this.itemId,
    required this.quantity,
    required this.priceAtPurchase,
    required this.createdAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        itemType: json['item_type'] as String,
        itemId: json['item_id'] as String,
        quantity: json['quantity'] as int,
        priceAtPurchase: json['price_at_purchase'] as num,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class Reservation {
  final String id;
  final String petId;
  final String customerId;
  final String status; // pending | confirmed | expired | cancelled
  final num depositAmount;
  final String? cancellationReason;
  final num? finalSaleAmount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String orderId;
  // Populated only when the query joins pets(species, breed), e.g.
  // ReservationsRepository.listForCustomer -- null otherwise.
  final String? petSpecies;
  final String? petBreed;

  Reservation({
    required this.id,
    required this.petId,
    required this.customerId,
    required this.status,
    required this.depositAmount,
    this.cancellationReason,
    this.finalSaleAmount,
    required this.createdAt,
    required this.expiresAt,
    required this.orderId,
    this.petSpecies,
    this.petBreed,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        customerId: json['customer_id'] as String,
        status: json['status'] as String,
        depositAmount: json['deposit_amount'] as num,
        cancellationReason: json['cancellation_reason'] as String?,
        finalSaleAmount: json['final_sale_amount'] as num?,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        orderId: json['order_id'] as String,
        petSpecies: (json['pets'] as Map<String, dynamic>?)?['species'] as String?,
        petBreed: (json['pets'] as Map<String, dynamic>?)?['breed'] as String?,
      );
}

class Gift {
  final String id;
  final String orderId;
  final String senderId;
  final String recipientName;
  final String recipientContact;
  final String? message;
  final String deliveryStatus; // pending | sent | delivered
  final DateTime createdAt;

  Gift({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.recipientName,
    required this.recipientContact,
    this.message,
    required this.deliveryStatus,
    required this.createdAt,
  });

  factory Gift.fromJson(Map<String, dynamic> json) => Gift(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        senderId: json['sender_id'] as String,
        recipientName: json['recipient_name'] as String,
        recipientContact: json['recipient_contact'] as String,
        message: json['message'] as String?,
        deliveryStatus: json['delivery_status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ReferenceVideo {
  final String id;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? category;
  final String? createdBy;
  final DateTime createdAt;

  ReferenceVideo({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    this.category,
    this.createdBy,
    required this.createdAt,
  });

  factory ReferenceVideo.fromJson(Map<String, dynamic> json) => ReferenceVideo(
        id: json['id'] as String,
        title: json['title'] as String,
        videoUrl: json['video_url'] as String,
        thumbnailUrl: json['thumbnail_url'] as String?,
        category: json['category'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SupportTicket {
  final String id;
  final String customerId;
  final String? shopId;
  final String subject;
  final String status; // open | in_progress | resolved | closed
  final DateTime createdAt;
  final Profile? customer;
  final Shop? shop;

  SupportTicket({
    required this.id,
    required this.customerId,
    this.shopId,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.customer,
    this.shop,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        shopId: json['shop_id'] as String?,
        subject: json['subject'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        customer: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
        shop: json['shops'] != null
            ? Shop.fromJson(json['shops'] as Map<String, dynamic>)
            : null,
      );
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final Profile? sender;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.sender,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] as String,
        ticketId: json['ticket_id'] as String,
        senderId: json['sender_id'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        sender: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}

class ShopReview {
  final String id;
  final String shopId;
  final String customerId;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;

  ShopReview({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });

  factory ShopReview.fromJson(Map<String, dynamic> json) => ShopReview(
        id: json['id'] as String,
        shopId: json['shop_id'] as String,
        customerId: json['customer_id'] as String,
        rating: json['rating'] as int,
        reviewText: json['review_text'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class WishlistItem {
  final String customerId;
  final String itemType; // pet | product
  final String itemId;
  final DateTime createdAt;

  WishlistItem({
    required this.customerId,
    required this.itemType,
    required this.itemId,
    required this.createdAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
        customerId: json['customer_id'] as String,
        itemType: json['item_type'] as String,
        itemId: json['item_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
