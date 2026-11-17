import 'package:flutter/material.dart';

class StoreCategory {
  final String id;
  final String name;
  final String segment;
  final int order;
  final String? imagePath;
  final bool active;
  final int productCount;
  final IconData? icon;

  const StoreCategory({
    required this.id,
    required this.name,
    this.segment = 'RETAIL',
    this.order = 0,
    this.imagePath,
    this.active = true,
    this.productCount = 0,
    this.icon,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      segment: json['segment']?.toString() ?? 'RETAIL',
      order: (json['order'] is num) ? (json['order'] as num).toInt() : 0,
      imagePath: json['imagePath']?.toString(),
      active: json['active'] is bool ? json['active'] as bool : true,
      productCount: (json['productCount'] is num)
          ? (json['productCount'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'segment': segment,
      'order': order,
      'imagePath': imagePath,
      'active': active,
      'productCount': productCount,
    };
  }

  StoreCategory copyWith({
    String? id,
    String? name,
    String? segment,
    int? order,
    String? imagePath,
    bool? active,
    int? productCount,
    IconData? icon,
  }) {
    return StoreCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      segment: segment ?? this.segment,
      order: order ?? this.order,
      imagePath: imagePath ?? this.imagePath,
      active: active ?? this.active,
      productCount: productCount ?? this.productCount,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
