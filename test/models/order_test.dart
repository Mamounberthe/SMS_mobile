import 'package:flutter_test/flutter_test.dart';
import 'package:rsms_mobile/models/order.dart';

void main() {
  group('Order Model', () {
    test('fromJson should create Order correctly', () {
      final json = {
        'id': 1,
        'reference': 'ORD001',
        'store_id': 1,
        'store_name': 'Store A',
        'status': 'sent',
        'requester_name': 'John Doe',
        'items': [
          {
            'id': 1,
            'product_id': 1,
            'product_name': 'Product A',
            'requested_quantity': 10,
            'validated_quantity': 10,
            'shipped_quantity': 0,
            'received_quantity': 0,
          }
        ],
      };

      final order = Order.fromJson(json);

      expect(order.id, 1);
      expect(order.reference, 'ORD001');
      expect(order.storeId, 1);
      expect(order.storeName, 'Store A');
      expect(order.status, 'sent');
      expect(order.requesterName, 'John Doe');
      expect(order.items.length, 1);
    });

    test('OrderItem fromJson should create item correctly', () {
      final json = {
        'id': 1,
        'product_id': 1,
        'product_name': 'Product A',
        'requested_quantity': 10,
        'validated_quantity': 10,
        'shipped_quantity': 5,
        'received_quantity': 3,
      };

      final item = OrderItem.fromJson(json);

      expect(item.id, 1);
      expect(item.productId, 1);
      expect(item.productName, 'Product A');
      expect(item.quantityRequested, 10);
      expect(item.quantityValidated, 10);
      expect(item.quantityShipped, 5);
      expect(item.quantityReceived, 3);
    });

    test('OrderItem fromJson should handle null values', () {
      final json = {
        'id': 1,
        'product_id': 1,
        'product_name': null,
        'requested_quantity': 10,
        'validated_quantity': 10,
        'shipped_quantity': 5,
        'received_quantity': 3,
      };

      final item = OrderItem.fromJson(json);

      expect(item.id, 1);
      expect(item.productId, 1);
      expect(item.productName, null);
      expect(item.quantityRequested, 10);
      expect(item.quantityValidated, 10);
      expect(item.quantityShipped, 5);
      expect(item.quantityReceived, 3);
    });
  });
}
