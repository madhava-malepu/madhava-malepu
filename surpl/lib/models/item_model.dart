class Item {
  final String id;
  final String name;
  final String shop;
  final double price;
  final double originalPrice;
  final String emoji;
  final String timeSlot;
  final int totalBags;
  final int bagsLeft;
  final bool isHot;
  final bool isNew;
  final String category;

  const Item({
    required this.id,
    required this.name,
    required this.shop,
    required this.price,
    required this.originalPrice,
    required this.emoji,
    required this.timeSlot,
    required this.totalBags,
    required this.bagsLeft,
    this.isHot = false,
    this.isNew = false,
    required this.category,
  });

  double get discountPercent =>
      ((originalPrice - price) / originalPrice * 100).roundToDouble();

  double get savedAmount => originalPrice - price;

  bool get isLastOne => bagsLeft == 1;

  double get soldPercent => (totalBags - bagsLeft) / totalBags;
}

final List<Item> dummyItems = [
  const Item(
    id: '1',
    name: 'Surprise Tiffin Bag',
    shop: 'Sri Lakshmi Tiffins',
    price: 79,
    originalPrice: 160,
    emoji: '🍱',
    timeSlot: '6–7 PM',
    totalBags: 5,
    bagsLeft: 2,
    isHot: true,
    category: 'Tiffin',
  ),
  const Item(
    id: '2',
    name: 'Bakery Surprise Bag',
    shop: 'Daily Bread Bakery',
    price: 99,
    originalPrice: 220,
    emoji: '🥐',
    timeSlot: '7–8 PM',
    totalBags: 8,
    bagsLeft: 4,
    isNew: true,
    category: 'Bakery',
  ),
  const Item(
    id: '3',
    name: 'Meals Surprise Bag',
    shop: 'Annapurna Restaurant',
    price: 120,
    originalPrice: 280,
    emoji: '🍛',
    timeSlot: '3–4 PM',
    totalBags: 6,
    bagsLeft: 1,
    isHot: true,
    category: 'Meals',
  ),
  const Item(
    id: '4',
    name: 'Sweet Surprise Bag',
    shop: 'Mithai Corner',
    price: 89,
    originalPrice: 200,
    emoji: '🍮',
    timeSlot: '8–9 PM',
    totalBags: 7,
    bagsLeft: 3,
    category: 'Sweets',
  ),
];
