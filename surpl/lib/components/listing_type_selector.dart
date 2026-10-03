import 'package:flutter/material.dart';

/// Ordinary vendor approval permits both discounted listing types.
/// Only Skip the Queue uses the separate administrator approval flag.
class ListingTypeSelector extends StatelessWidget {
  const ListingTypeSelector({
    super.key,
    required this.value,
    required this.skipQueueApproved,
    required this.onChanged,
  });

  final String value;
  final bool skipQueueApproved;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final types = [
      ('surplus', '🎁 Surprise Bag'),
      ('happyHour', '⚡ Happy Hour'),
      if (skipQueueApproved) ('freshFood', '⏩ Skip the Queue'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        for (final type in types)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == type.$1,
              child: GestureDetector(
                key: ValueKey('listing-type-${type.$1}'),
                onTap: () => onChanged(type.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: value == type.$1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(type.$2, textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: value == type.$1
                        ? const Color(0xFF1A4731) : Colors.grey.shade600)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
