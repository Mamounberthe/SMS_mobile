import 'package:flutter_test/flutter_test.dart';
import 'package:rsms_mobile/models/product.dart';

void main() {
  group('Product Model', () {
    test('fromJson should create Product correctly', () {
      final json = {
        'id': 1,
        'code': 'PRD001',
        'reference': 'REF001',
        'name': 'Test Product',
        'category_name': 'Category A',
        'brand': 'Brand X',
        'purchase_price': 1000,
        'sale_price': 1500,
        'min_stock': 10,
        'unit': 'pcs',
        'is_active': true,
        'total_quantity': 50,
      };

      final product = Product.fromJson(json);

      expect(product.id, 1);
      expect(product.code, 'PRD001');
      expect(product.reference, 'REF001');
      expect(product.name, 'Test Product');
      expect(product.categoryName, 'Category A');
      expect(product.brand, 'Brand X');
      expect(product.purchasePrice, 1000);
      expect(product.salePrice, 1500);
      expect(product.minStock, 10);
      expect(product.unit, 'pcs');
      expect(product.isActive, true);
      expect(product.totalQuantity, 50);
    });

    test('fromJson should handle null values', () {
      final json = {
        'id': 1,
        'code': 'PRD001',
        'reference': null,
        'name': 'Test Product',
        'category_name': null,
        'brand': null,
        'purchase_price': 1000,
        'sale_price': 1500,
        'min_stock': 10,
        'unit': 'pcs',
        'is_active': true,
        'total_quantity': null,
      };

      final product = Product.fromJson(json);

      expect(product.id, 1);
      expect(product.code, 'PRD001');
      expect(product.reference, null);
      expect(product.name, 'Test Product');
      expect(product.categoryName, null);
      expect(product.brand, null);
      expect(product.purchasePrice, 1000);
      expect(product.salePrice, 1500);
      expect(product.minStock, 10);
      expect(product.unit, 'pcs');
      expect(product.isActive, true);
      expect(product.totalQuantity, null);
    });

    test('isLowStock should return true when quantity <= minStock', () {
      final json = {
        'id': 1,
        'code': 'PRD001',
        'name': 'Test Product',
        'purchase_price': 1000,
        'sale_price': 1500,
        'min_stock': 10,
        'unit': 'pcs',
        'is_active': true,
        'total_quantity': 5,
      };

      final product = Product.fromJson(json);
      expect(product.isLowStock, true);
    });

    test('isLowStock should return false when quantity > minStock', () {
      final json = {
        'id': 1,
        'code': 'PRD001',
        'name': 'Test Product',
        'purchase_price': 1000,
        'sale_price': 1500,
        'min_stock': 10,
        'unit': 'pcs',
        'is_active': true,
        'total_quantity': 15,
      };

      final product = Product.fromJson(json);
      expect(product.isLowStock, false);
    });

    test('isLowStock should return false when totalQuantity is null', () {
      final json = {
        'id': 1,
        'code': 'PRD001',
        'name': 'Test Product',
        'purchase_price': 1000,
        'sale_price': 1500,
        'min_stock': 10,
        'unit': 'pcs',
        'is_active': true,
        'total_quantity': null,
      };

      final product = Product.fromJson(json);
      expect(product.isLowStock, false);
    });
  });
}
