
import '/backend/backend.dart';

List<BagsRecord> filteredBags(
  List<BagsRecord> bags,
  String searchQuery,
  String selectedCategory,
) {
  final all = bags;
  final q = searchQuery.toLowerCase();
  final c = selectedCategory;
  return all.where((b) {
    final matchesQuery = q.isEmpty || b.title.toLowerCase().contains(q);
    final matchesCategory = c == "All" || b.category == c;
    return matchesQuery && matchesCategory;
  }).toList();
}
