import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

double parseDouble(dynamic value) {
  if (value == null) return 0.00;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.00;
  return 0.00;
}

/// --- Fetch Menu Addons ---
Future<List<Map<String, dynamic>>> fetchMenuAddons(int menuId) async {
  final apiBase = await ApiConfig.getBaseUrl();
  final url = Uri.parse('$apiBase/menu/get_menu_addons.php?menu_id=$menuId');
  debugPrint('🔹 Fetching addons from: $url');

  final res = await http.get(url);

  if (res.statusCode != 200 || res.body.isEmpty) {
    debugPrint('⚠️ Empty or bad response body for menu_id=$menuId');
    return [];
  }

  try {
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      debugPrint('⚠️ Unexpected response type: ${data.runtimeType}');
      return [];
    }
  } catch (e) {
    debugPrint('❌ JSON decode error for menu_id=$menuId: $e');
    return [];
  }
}

/// --- Show Popup to Customize Item and Add to Cart ---
void showOrderPopup(
  BuildContext context,
  Map<String, dynamic> item,
  void Function(Map<String, dynamic>) onAddToCart,
) async {
  // Strictly parse menu_id as int
  final int menuId =
      int.tryParse(
        item['menu_id']?.toString() ?? item['id']?.toString() ?? '0',
      ) ??
      0;
  if (menuId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid menu ID, cannot load addons.')),
    );
    return;
  }

  // Fetch addons
  List<Map<String, dynamic>> menuAddons = [];
  try {
    menuAddons = await fetchMenuAddons(menuId);
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to load addons: $e')));
    return;
  }

  final double basePrice = parseDouble(item['price']);

  List<int> selectedAddonIds = [];
  Map<String, String> selectedOptions = {"Size": "Medium", "Crust": "Thin"};

  double computeTotal() {
    double total = basePrice;

    // Radio options
    for (var cat in selectedOptions.keys) {
      final selectedName = selectedOptions[cat];
      if (selectedName != null && selectedName.isNotEmpty) {
        final match = menuAddons.firstWhere(
          (a) => a['name'] == selectedName,
          orElse: () => {},
        );
        if (match.isNotEmpty) total += parseDouble(match['price']);
      }
    }

    // Checkbox addons
    for (var id in selectedAddonIds) {
      final match = menuAddons.firstWhere(
        (a) =>
            (a['id'] is int ? a['id'] : int.tryParse(a['id'].toString())) == id,
        orElse: () => {},
      );
      if (match.isNotEmpty) total += parseDouble(match['price']);
    }

    return total;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final totalPrice = computeTotal();

          final grouped = <String, List<Map<String, dynamic>>>{};
          for (var addon in menuAddons) {
            final category = addon['category'] ?? 'Others';
            grouped.putIfAbsent(category, () => []);
            grouped[category]!.add(addon);
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Customize ${item['name'] ?? 'Meal'}",
              style: GoogleFonts.poppins(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Base Price: ₱${basePrice.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...grouped.entries.map((entry) {
                      final category = entry.key;
                      final addons = entry.value;

                      if (["Size", "Crust"].contains(category)) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              category,
                              style: GoogleFonts.poppins(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            ...addons.map((addon) {
                              final addonName = addon['name']?.toString() ?? '';
                              final addonPrice = parseDouble(addon['price']);
                              return RadioListTile<String>(
                                value: addonName,
                                groupValue: selectedOptions[category],
                                onChanged: addon['status'] == 'hidden'
                                    ? null // disable selection
                                    : (value) => setState(
                                        () => selectedOptions[category] =
                                            value ?? '',
                                      ),
                                title: Text(
                                  "${addonName} (+₱${addonPrice.toStringAsFixed(2)})${addon['status'] == 'hidden' ? ' (Unavailable)' : ''}",
                                  style: GoogleFonts.poppins(
                                    color: addon['status'] == 'hidden'
                                        ? Colors.white38
                                        : Colors.white,
                                  ),
                                ),

                                activeColor: Colors.orangeAccent,
                                dense: true,
                              );
                            }).toList(),
                          ],
                        );
                      }

                      // Checkbox categories
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            category,
                            style: GoogleFonts.poppins(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ...addons.map((addon) {
                            final addonId =
                                int.tryParse(addon['id'].toString()) ?? 0;
                            final addonName = addon['name']?.toString() ?? '';
                            final addonPrice = parseDouble(addon['price']);
                            return CheckboxListTile(
                              value: selectedAddonIds.contains(addonId),
                              onChanged: addon['status'] == 'hidden'
                                  ? null // disable selection
                                  : (checked) {
                                      setState(() {
                                        if (checked == true)
                                          selectedAddonIds.add(addonId);
                                        else
                                          selectedAddonIds.remove(addonId);
                                      });
                                    },
                              title: Text(
                                "${addonName} (+₱${addonPrice.toStringAsFixed(2)})${addon['status'] == 'hidden' ? ' (Unavailable)' : ''}",
                                style: GoogleFonts.poppins(
                                  color: addon['status'] == 'hidden'
                                      ? Colors.white38
                                      : Colors.white,
                                ),
                              ),
                              activeColor: Colors.orangeAccent,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                    const Divider(color: Colors.white24, thickness: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total:",
                          style: GoogleFonts.poppins(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "₱${totalPrice.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // Build cart item with strict int menu_id
                  final int menuId =
                      int.tryParse(
                        item['menu_id']?.toString() ??
                            item['id']?.toString() ??
                            '0',
                      ) ??
                      0;

                  if (menuId <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid menu ID, cannot add to cart.'),
                      ),
                    );
                    return;
                  }

                  // Build addons list
                  List<Map<String, dynamic>> addonsToCart = selectedAddonIds
                      .map((addonId) {
                        final match = menuAddons.firstWhere(
                          (a) =>
                              (a['id'] is int
                                  ? a['id']
                                  : int.tryParse(a['id'].toString())) ==
                              addonId,
                          orElse: () => {},
                        );
                        if (match.isNotEmpty) {
                          return {
                            'id': addonId,
                            'name': match['name'],
                            'price': parseDouble(match['price']),
                          };
                        }
                        return null;
                      })
                      .where((e) => e != null)
                      .cast<Map<String, dynamic>>()
                      .toList();

                  // Add radio options (Size, Crust) as "addons" too
                  for (var cat in selectedOptions.keys) {
                    final value = selectedOptions[cat];
                    if (value != null && value.isNotEmpty) {
                      final match = menuAddons.firstWhere(
                        (a) => a['name'] == value,
                        orElse: () => {},
                      );
                      if (match.isNotEmpty) {
                        addonsToCart.add({
                          'id': match['id'] is int
                              ? match['id']
                              : int.tryParse(match['id'].toString()) ?? 0,
                          'name': match['name'],
                          'price': parseDouble(match['price']),
                        });
                      }
                    }
                  }

                  final cartItem = {
                    ...item,
                    'menu_id': menuId,
                    'quantity': 1,
                    'addons': addonsToCart,
                  };

                  onAddToCart(cartItem);
                  Navigator.pop(context);
                },
                child: Text("Add to Cart", style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      );
    },
  );
}
