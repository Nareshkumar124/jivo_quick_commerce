/// The rider's vehicle (04 §2.2 registration form, 07 §2.8 `vehicle_type`).
///
/// TODO(api): the wire values are not in the docs yet (no rider contract
/// until the end of P4). Assumed upper-case like the other 07 enums.
enum VehicleType {
  bicycle('BICYCLE'),
  eBike('E_BIKE'),
  motorbike('MOTORBIKE'),
  scooter('SCOOTER');

  const VehicleType(this.wireValue);

  final String wireValue;

  /// Motorised vehicles need a vehicle number, a driving licence and an RC
  /// (04 §2.2, D-14). This is the only place that decides it.
  ///
  /// Open question for Jivo: an e-bike is treated as NOT motorised (low-speed
  /// e-bikes need no registration or licence in India). If Jivo also accepts
  /// high-speed e-bikes, make this `!= bicycle` (one line).
  bool get isMotorised => switch (this) {
    VehicleType.motorbike || VehicleType.scooter => true,
    VehicleType.bicycle || VehicleType.eBike => false,
  };

  static VehicleType? fromWire(String? value) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}
