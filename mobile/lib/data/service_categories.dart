import 'package:flutter/material.dart';

/// Service categories, matching the `service_category` Postgres enum.
class ServiceCategory {
  final String key;
  final String label;
  final IconData icon;
  const ServiceCategory(this.key, this.label, this.icon);
}

const serviceCategories = <ServiceCategory>[
  ServiceCategory('vet', 'Vet', Icons.medical_services_outlined),
  ServiceCategory('grooming', 'Grooming', Icons.content_cut),
  ServiceCategory('trimming', 'Trimming', Icons.cut),
  ServiceCategory('bathing', 'Bathing', Icons.bathtub_outlined),
  ServiceCategory('training', 'Training', Icons.school_outlined),
  ServiceCategory('walking', 'Walking', Icons.directions_walk),
  ServiceCategory('daycare', 'Daycare', Icons.home_outlined),
  ServiceCategory('boarding', 'Boarding', Icons.hotel_outlined),
];

ServiceCategory serviceCategoryFor(String? key) {
  for (final category in serviceCategories) {
    if (category.key == key) return category;
  }
  return const ServiceCategory('other', 'Other', Icons.pets);
}

String serviceCategoryLabel(String? key) => serviceCategoryFor(key).label;
