import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../widgets/sidebar.dart';
import '../tasks/task_page.dart';
import '../materials/manager_page.dart';
import '../sales/sales_page.dart';
import '../menu_management/menu_management_page.dart';
import '../inventory/inventory_page.dart';
import '../home/dash.dart';
import '../order/dashboard_page.dart';
import '../config/api_config.dart';

class Expense {
  int? id;
  String date;
  String category;
  String description;
  String vendor;
  double quantity;
  double unitPrice;
  double totalCost;
  String paymentMethod;
  String notes;

  Expense({
    this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.vendor,
    required this.quantity,
    required this.unitPrice,
    required this.totalCost,
    required this.paymentMethod,
    required this.notes,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      date: json['date'],
      category: json['category'],
      description: json['description'],
      vendor: json['vendor'],
      quantity: json['quantity'] is num
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity'].toString()) ?? 0.0,
      unitPrice: json['unit_price'] is num
          ? (json['unit_price'] as num).toDouble()
          : double.tryParse(json['unit_price'].toString()) ?? 0.0,
      totalCost: json['total_cost'] is num
          ? (json['total_cost'] as num).toDouble()
          : double.tryParse(json['total_cost'].toString()) ?? 0.0,
      paymentMethod: json['payment_method'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
}

class ExpensesContent extends StatefulWidget {
  final String userId;
  final String username;
  final String role;
  final bool isSidebarOpen;
  final VoidCallback toggleSidebar;
  final VoidCallback onLogout;

  const ExpensesContent({
    super.key,
    required this.userId,
    required this.username,
    required this.role,
    required this.isSidebarOpen,
    required this.toggleSidebar,
    required this.onLogout,
  });

  @override
  State<ExpensesContent> createState() => _ExpensesContentState();
}

class _ExpensesContentState extends State<ExpensesContent> {
  late bool _isSidebarOpen;
  List<Expense> _allExpenses = [];
  bool isLoading = true;
  List<String> _categories = [];

  // Date filters
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _isSidebarOpen = widget.isSidebarOpen;
    _loadExpenses();
    _loadCategories();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
    widget.toggleSidebar();
  }

  Map<String, List<Expense>> get _expensesByDate {
    final Map<String, List<Expense>> grouped = {};
    for (var expense in _filteredExpenses) {
      final formattedDate = DateFormat(
        'MMM dd, yyyy',
      ).format(DateTime.parse(expense.date));
      if (!grouped.containsKey(formattedDate)) {
        grouped[formattedDate] = [];
      }
      grouped[formattedDate]!.add(expense);
    }
    return grouped;
  }

  void _showAccessDeniedDialog(String page) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Access Denied"),
        content: Text(
          "You don’t have permission to access the $page page. This page is only available to Managers.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() async {
    final _descriptionController = TextEditingController();
    final _unitPriceController = TextEditingController();
    String? _paymentMethod;
    String? _selectedCategory;
    String? _selectedUser; // For Labor category
    DateTime _selectedDate = DateTime.now();
    List<String> _users = [];

    // Load users for Labor dropdown
    Future<void> _loadUsers() async {
      try {
        final baseUrl = await ApiConfig.getBaseUrl();
        final response = await http.get(
          Uri.parse('$baseUrl/user/get_users.php'),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            setState(() {
              _users = List<String>.from(
                data['users'].map((u) => u['username']),
              );
            });
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }

    await _loadUsers();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Add Expense"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: _categories
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedUser = null;
                      _descriptionController.clear();
                    });
                  },
                  decoration: const InputDecoration(labelText: "Category"),
                ),
                const SizedBox(height: 10),

                // Dynamic Description: dropdown for Labor, text field otherwise
                if (_selectedCategory == "Labor") ...[
                  DropdownButtonFormField<String>(
                    value: _selectedUser,
                    items: _users
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUser = value;
                        _descriptionController.text = value != null
                            ? "Labor Fee for $value"
                            : "";
                      });
                    },
                    decoration: const InputDecoration(labelText: "Select User"),
                  ),
                ] else ...[
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: "Description"),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Date: "),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  items: ["Cash", "Gcash", "Card", "Other"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _paymentMethod = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Payment Method",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _unitPriceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Cost"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final category = _selectedCategory ?? "";
                final description = _descriptionController.text.trim();
                final unitPrice =
                    double.tryParse(_unitPriceController.text.trim()) ?? 0.0;
                final paymentMethodSelected = _paymentMethod ?? "Cash";

                if (category.isEmpty ||
                    description.isEmpty ||
                    unitPrice <= 0 ||
                    (_selectedCategory == "Labor" && _selectedUser == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please fill all fields correctly."),
                    ),
                  );
                  return;
                }

                final newExpense = Expense(
                  date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                  category: category,
                  description: description,
                  vendor: "",
                  quantity: 1,
                  unitPrice: unitPrice,
                  totalCost: unitPrice,
                  paymentMethod: paymentMethodSelected,
                  notes: "",
                );

                try {
                  final baseUrl = await ApiConfig.getBaseUrl();
                  final categoryId = _categories.indexOf(category) + 1;

                  final response = await http.post(
                    Uri.parse('$baseUrl/expense/add_expense.php'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      "category_id": categoryId,
                      "date": newExpense.date,
                      "description": newExpense.description,
                      "vendor": newExpense.vendor,
                      "quantity": newExpense.quantity,
                      "unit_price": newExpense.unitPrice,
                      "total_cost": newExpense.totalCost,
                      "payment_method": newExpense.paymentMethod,
                      "notes": newExpense.notes,
                    }),
                  );

                  final data = jsonDecode(response.body);
                  if (data['success'] == true) {
                    setState(() {
                      _allExpenses.insert(0, newExpense);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Expense added successfully'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to add expense: ${data['message']}',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding expense: $e')),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadExpenses() async {
    setState(() => isLoading = true);
    try {
      final baseUrl = await ApiConfig.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/expense/get_expenses.php'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        _allExpenses = data.map((e) => Expense.fromJson(e)).toList();
      } else {
        _allExpenses = [];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load expenses.')),
        );
      }
    } catch (e) {
      _allExpenses = [];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching expenses: $e')));
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadCategories() async {
    try {
      final baseUrl = await ApiConfig.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/expense/get_categories.php'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        setState(() {
          _categories = data.map((e) => e['name'] as String).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load categories.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching categories: $e')));
    }
  }

  double _calculateTotal(List<Expense> expenses) {
    return expenses.fold(0.0, (sum, e) => sum + e.totalCost);
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (startDate ?? DateTime.now())
          : (endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  List<Expense> get _filteredExpenses {
    return _allExpenses.where((e) {
      final expenseDate = DateTime.tryParse(e.date);
      if (expenseDate == null) return false;
      if (startDate != null && expenseDate.isBefore(startDate!)) return false;
      if (endDate != null && expenseDate.isAfter(endDate!)) return false;
      return true;
    }).toList();
  }

  Widget _buildHeaderRow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "Category",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Description",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Vendor",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Date",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Payment Method",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Quantity",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Cost/Unit Price",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Total",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Expense e) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(e.category, style: GoogleFonts.poppins(fontSize: 16)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              e.description,
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(e.vendor, style: GoogleFonts.poppins(fontSize: 16)),
          ),
          Expanded(
            flex: 2,
            child: Text(e.date, style: GoogleFonts.poppins(fontSize: 16)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              e.paymentMethod,
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              e.quantity.toStringAsFixed(2),
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "₱${e.unitPrice.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "₱${e.totalCost.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredExpenses;
    final totalExpenses = _calculateTotal(filtered);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
      body: Row(
        children: [
          Material(
            elevation: 2,
            child: Sidebar(
              isSidebarOpen: _isSidebarOpen,
              toggleSidebar: _toggleSidebar,
              username: widget.username,
              role: widget.role,
              userId: widget.userId,
              onLogout: widget.onLogout,
              activePage: 'expenses',
              onHome: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => dash()),
                  (route) => false,
                );
              },
              onDashboard: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DashboardPage(
                      username: widget.username,
                      role: widget.role,
                      userId: widget.userId,
                      isSidebarOpen: widget.isSidebarOpen,
                      toggleSidebar: widget.toggleSidebar,
                    ),
                  ),
                );
              },
              onTaskPage: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskPage(
                      userId: widget.userId,
                      username: widget.username,
                      role: widget.role,
                      isSidebarOpen: widget.isSidebarOpen,
                      toggleSidebar: widget.toggleSidebar,
                    ),
                  ),
                );
              },
              onMaterials: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManagerPage(
                      username: widget.username,
                      role: widget.role,
                      userId: widget.userId,
                      isSidebarOpen: widget.isSidebarOpen,
                      toggleSidebar: widget.toggleSidebar,
                    ),
                  ),
                );
              },
              onInventory: () {
                if (widget.role.toLowerCase() == "manager") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InventoryManagementPage(
                        userId: widget.userId,
                        username: widget.username,
                        role: widget.role,
                        isSidebarOpen: widget.isSidebarOpen,
                        toggleSidebar: widget.toggleSidebar,
                        onLogout: widget.onLogout,
                      ),
                    ),
                  );
                } else {
                  _showAccessDeniedDialog("Inventory");
                }
              },
              onMenu: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuManagementPage(
                      username: widget.username,
                      role: widget.role,
                      userId: widget.userId,
                      isSidebarOpen: widget.isSidebarOpen,
                      toggleSidebar: widget.toggleSidebar,
                    ),
                  ),
                );
              },
              onSales: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalesContent(
                      userId: widget.userId,
                      username: widget.username,
                      role: widget.role,
                      isSidebarOpen: widget.isSidebarOpen,
                      toggleSidebar: widget.toggleSidebar,
                      onLogout: widget.onLogout,
                    ),
                  ),
                );
              },
              onExpenses: () {},
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isSidebarOpen ? Icons.arrow_back_ios : Icons.menu,
                          color: Colors.orange,
                        ),
                        onPressed: _toggleSidebar,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Expenses",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _pickDate(context, true),
                        icon: const Icon(
                          Icons.calendar_today,
                          color: Colors.orange,
                        ),
                        label: Text(
                          startDate != null
                              ? DateFormat('MMM dd, yyyy').format(startDate!)
                              : 'From',
                          style: GoogleFonts.poppins(color: Colors.orange),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _pickDate(context, false),
                        icon: const Icon(
                          Icons.calendar_today,
                          color: Colors.orange,
                        ),
                        label: Text(
                          endDate != null
                              ? DateFormat('MMM dd, yyyy').format(endDate!)
                              : 'To',
                          style: GoogleFonts.poppins(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Total Expenses: ₱${totalExpenses.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                        ? Center(
                            child: Text(
                              "No expenses found for the selected date range.",
                              style: GoogleFonts.poppins(fontSize: 16),
                            ),
                          )
                        : ListView(
                            children: _expensesByDate.entries.map((entry) {
                              final date = entry.key;
                              final expenses = entry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      date,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ),
                                  // Column headers
                                  _buildHeaderRow(),
                                  // Expenses for that date
                                  ...expenses
                                      .map((e) => _buildExpenseRow(e))
                                      .toList(),
                                ],
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
