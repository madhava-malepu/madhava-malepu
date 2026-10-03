// Shared impact calculation - used on both the customer order confirmation
// screen and the vendor dashboard, so both sides always show numbers that
// agree with each other rather than two separately-maintained formulas.
//
// IMPORTANT, HONEST NOTE ON THE NUMBERS BELOW:
// Surpl does not track the actual weight of each bag, and food-waste CO2e
// varies enormously by food type (a kg of wasted beef has roughly 40x the
// footprint of a kg of wasted vegetables - WRAP/FoodSight data). There is
// no single precise, universally-agreed conversion factor for this.
//
// The figures used here are reasonable, widely-cited industry
// approximations, not precise measurements:
//   - Average bag weight: ~0.6kg (a common assumption for a single-meal
//     surprise bag in this category of app)
//   - CO2e per kg of food waste avoided: ~2.5kg (a commonly cited rough
//     average - see New Food Magazine / ClimatePartner UK reporting)
//
// This is why every number this service produces is surfaced to the user
// with "approximately" / "an estimated" language, never presented as an
// exact measurement. If Surpl later tracks real bag weights, replace
// _avgBagWeightKg with the real value per order instead of this constant.

class OrderImpact {
  final double foodSavedKg;
  final double co2SavedKg;
  final double moneySaved;

  const OrderImpact({
    required this.foodSavedKg,
    required this.co2SavedKg,
    required this.moneySaved,
  });
}

class ImpactService {
  static const double _avgBagWeightKg = 0.6;
  static const double _co2PerKgFoodWaste = 2.5;

  /// Computes the estimated impact of a single order, given how many bags
  /// were in it and the money saved (original price minus what was paid).
  static OrderImpact forOrder({
    required int bagCount,
    required double originalPrice,
    required double amountPaid,
  }) {
    final foodSavedKg = bagCount * _avgBagWeightKg;
    final co2SavedKg = foodSavedKg * _co2PerKgFoodWaste;
    final moneySaved = (originalPrice - amountPaid).clamp(0, double.infinity);
    return OrderImpact(
      foodSavedKg: foodSavedKg,
      co2SavedKg: co2SavedKg,
      moneySaved: moneySaved.toDouble(),
    );
  }

  /// Computes cumulative impact across many orders (e.g., a vendor's
  /// all-time total, or a customer's lifetime total).
  static OrderImpact cumulative(List<OrderImpact> orders) {
    double food = 0, co2 = 0, money = 0;
    for (final o in orders) {
      food += o.foodSavedKg;
      co2 += o.co2SavedKg;
      money += o.moneySaved;
    }
    return OrderImpact(foodSavedKg: food, co2SavedKg: co2, moneySaved: money);
  }
}
