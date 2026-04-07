class NegotiationOffer {
  final String id;
  final String tripId;
  final String driverId;
  final double offeredPrice;
  final double? counterPrice;
  final String status;
  final DateTime createdAt;
  final String? driverName;
  final double? driverRating;

  NegotiationOffer({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.offeredPrice,
    this.counterPrice,
    required this.status,
    required this.createdAt,
    this.driverName,
    this.driverRating,
  });

  factory NegotiationOffer.fromJson(Map<String, dynamic> json) {
    return NegotiationOffer(
      id: json['id'] ?? '',
      tripId: json['tripId'] ?? '',
      driverId: json['driverId'] ?? '',
      offeredPrice: (json['offeredPrice'] as num).toDouble(),
      counterPrice: json['counterPrice'] != null ? (json['counterPrice'] as num).toDouble() : null,
      status: json['status'] ?? 'pending',
      createdAt: DateTime.now(), // Simplified
      driverName: json['driverName'],
      driverRating: json['driverRating'] != null ? (json['driverRating'] as num).toDouble() : null,
    );
  }
}
