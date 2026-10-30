import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/expense.dart';
import 'database/_helper.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

import 'pages/expense_chart_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const App());
}

final currencyFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

class RupiahInputFormatter extends TextInputFormatter {
  String _format(String digits) {
    if (digits.isEmpty) return '';

    return NumberFormat('#,##0', 'id_ID').format(
      int.parse(digits),
    );
  }

  int _getCursorOffset(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;

    var count = 0;

    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        count++;
      }

      if (count == digitCount) {
        return i + 1;
      }
    }

    return formatted.length;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // Remove leading zeroes
    digits = digits.replaceFirst(
      RegExp(r'^0+(?=\d)'),
      '',
    );

    // Max 12 digits
    if (digits.length > 12) {
      return oldValue;
    }

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _format(digits);

    final digitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(
            0,
            newValue.text.length,
          ),
        )
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final cursorOffset = _getCursorOffset(
      formatted,
      digitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: cursorOffset,
      ),
    );
  }
}

// Categories for spending list
const List<String> expenseCategories = [
  'Makanan',
  'Transportasi',
  'Pendidikan',
  'Hiburan',
  'Kesehatan',
  'Lainnya',
];

class App extends StatelessWidget {
  const App({super.key});

  // Root widget
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Singaparna',
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor:
            const Color(0xFFF5F7F2),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F2),
          foregroundColor: Color(0xFF1B1F1B),
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: const Color(0xFFFFFFFF),
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFDCE3D8),
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF2E7D32),
              width: 2,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const HomePage(title: 'Budget Expense'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> _expenses = [];

  Future<void> _loadExpenses() async {
  final expenses =
      await DatabaseHelper.instance.getExpenses();

    if (!mounted) return;

    setState(() {
      _expenses
        ..clear()
        ..addAll(expenses);
    });
  }

  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedCategory = 'Semua Kategori';
  List<String> get _filterCategories {
    return [
      'Semua Kategori',
      ...expenseCategories,
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  // Start date picker
  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
      });
    }
  }

  // End date picker
  Future<void> _pickEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  // Date format
  String _formatDate(DateTime date) {
    return '${date.day}/'
        '${date.month}/'
        '${date.year}';
  }

  // Filter by categories and date
  List<Expense> get _filteredExpenses {
    return _expenses.where((expense) {
      // Filter by category
      final matchesCategory =
          _selectedCategory == 'Semua Kategori' ||
          expense.category == _selectedCategory;

      // Filter by start date
      final matchesStartDate =
          _startDate == null ||
          !DateUtils.dateOnly(expense.date).isBefore(
            DateUtils.dateOnly(_startDate!),
          );

      // Filter by end date
      final matchesEndDate =
          _endDate == null ||
          !DateUtils.dateOnly(expense.date).isAfter(
            DateUtils.dateOnly(_endDate!),
          );

      return matchesCategory &&
          matchesStartDate &&
          matchesEndDate;
    }).toList();
  }

  // Filtered total expense
  int get _filteredTotalExpense {
    return _filteredExpenses.fold(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  // Getter total expense
  int get _totalExpense {
    return _expenses.fold(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  // Icon data based on category
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Makanan':
        return Icons.restaurant;

      case 'Transportasi':
        return Icons.directions_bus;

      case 'Pendidikan':
        return Icons.school;

      case 'Hiburan':
        return Icons.movie;

      case 'Kesehatan':
        return Icons.local_hospital;

      default:
        return Icons.receipt;
    }
  }

  // Delete popup
  void _confirmDeleteExpense(
    Expense expense,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Pengeluaran?'),
          content: Text(
            'Apakah kamu yakin ingin menghapus '
            '"${expense.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (expense.id != null) {
                    await DatabaseHelper.instance.deleteExpense(
                      expense.id!,
                    );
                  }

                  if (!mounted) return;

                  Navigator.pop(dialogContext);

                  await _loadExpenses();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengeluaran berhasil dihapus.'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus pengeluaran: $e'),
                    ),
                  );
                }
              },
              child: const Text(
                'Hapus',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Grafik Pengeluaran',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseChartPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1000,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total amount
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Color(0xFF2E7D32),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Total Pengeluaran',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currencyFormatter.format(_totalExpense),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1F1B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pengeluaran sesuai filter: '
                          '${currencyFormatter.format(_filteredTotalExpense)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Total numbers of expenses
                Text(
                  'Jumlah transaksi: ${_filteredExpenses.length}',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 16),

                // Categorical filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Filter Kategori',
                    prefixIcon: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF2E7D32),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFD9E2D5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFD9E2D5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E7D32),
                        width: 2,
                      ),
                    ),
                  ),
                  items: [
                    for (final category in _filterCategories)
                      DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Date filter
                LayoutBuilder(
                  builder: (context, constraints) {
                    final startButton = OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _startDate == null
                            ? 'Tanggal Mulai'
                            : _formatDate(_startDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF356B3A),
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(
                          color: Color(0xFF7B8879),
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );

                    final endButton = OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _endDate == null
                            ? 'Tanggal Akhir'
                            : _formatDate(_endDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF356B3A),
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(
                          color: Color(0xFF7B8879),
                        ),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );

                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: startButton,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: endButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: startButton),
                        const SizedBox(width: 12),
                        Expanded(child: endButton),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Expense list
                Expanded(
                  child: _filteredExpenses.isEmpty
                    ? SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 220,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _expenses.isEmpty
                                        ? Icons.account_balance_wallet_outlined
                                        : Icons.search_off_rounded,
                                    size: 44,
                                    color: const Color(0xFF9EAD9C),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _expenses.isEmpty
                                        ? 'Belum ada pengeluaran'
                                        : 'Pengeluaran tidak ditemukan',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF29332A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _expenses.isEmpty
                                        ? 'Mulai catat pengeluaranmu agar keuangan lebih teratur.'
                                        : 'Coba ubah filter kategori atau rentang tanggal.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ),
                      )
                    : ListView.builder(
                      itemCount: _filteredExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = _filteredExpenses[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Category icon
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: const Color(0xFFB9F0B5),
                                  child: Icon(
                                    _getCategoryIcon(expense.category),
                                    color: const Color(0xFF245C2A),
                                    size: 25,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Expense information
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${expense.category} • '
                                        '${expense.date.day}/'
                                        '${expense.date.month}/'
                                        '${expense.date.year}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF626B62),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Amount and action buttons
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currencyFormatter.format(expense.amount),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF354438),
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Edit button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Colors.blue,
                                          ),
                                          tooltip: 'Edit pengeluaran',
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () async {
                                            final updatedExpense =
                                                await Navigator.push<Expense>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AddExpensePage(
                                                  expense: expense,
                                                ),
                                              ),
                                            );

                                            if (updatedExpense != null) {
                                              try {
                                                await DatabaseHelper.instance.updateExpense(
                                                  updatedExpense,
                                                );

                                                await _loadExpenses();

                                                if (!mounted) return;

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Pengeluaran berhasil diperbarui.',
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Gagal memperbarui pengeluaran: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),

                                        // Delete button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Hapus pengeluaran',
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            _confirmDeleteExpense(expense);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Add expense button
                ElevatedButton(
                  onPressed: () async {
                    final expense = await Navigator.push<Expense>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddExpensePage(),
                      ),
                    );

                    if (expense != null) {
                      try {
                        await DatabaseHelper.instance.insertExpense(expense);
                        await _loadExpenses();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengeluaran berhasil disimpan.'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal menyimpan pengeluaran: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Tambah Pengeluaran'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddExpensePage extends StatefulWidget {
  final Expense? expense;

  const AddExpensePage({
    super.key,
    this.expense,
  });
  
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  // Temp values
  String _category = 'Makanan';

  // Date picker
  DateTime _selectedDate = DateTime.now();
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Init
  @override
  void initState() {
    super.initState();

    if (widget.expense != null) {
      _nameController.text = widget.expense!.name;

      _amountController.text = NumberFormat(
        '#,##0',
        'id_ID',
      ).format(widget.expense!.amount);

      _category = widget.expense!.category;

      _selectedDate = widget.expense!.date;
    }
  }

  // Build func
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expense == null
              ? 'Tambah Pengeluaran'
              : 'Edit Pengeluaran',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name controller
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pengeluaran',
                    hintText: 'Contoh: Makan siang',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama pengeluaran wajib diisi';
                    }

                    return null;
                  },
                ),

                // Amount controller
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                    inputFormatters: [
                      RupiahInputFormatter(),
                    ],
                  decoration: const InputDecoration(
                    labelText: 'Nominal',
                    hintText: 'Contoh: 25.000',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = int.tryParse(
                      (value ?? '').replaceAll('.', '').trim(),
                    );

                    if (amount == null || amount <= 0) {
                      return 'Nominal harus lebih besar dari 0';
                    }

                    if (amount > 999999999999) {
                      return 'Nominal maksimal Rp999.999.999.999';
                    }

                    return null;
                  },
                ),
                
                // Category
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final cat in expenseCategories)
                      DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      ),
                  ],
                  onChanged: (nilai) {
                    if (nilai != null) {
                      setState(() {
                        _category = nilai;
                      });
                    }
                  },
                ),

                // Calendar picker
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    'Tanggal: ${_selectedDate.day}/'
                    '${_selectedDate.month}/'
                    '${_selectedDate.year}',
                  ),
                ),

                // Save button
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final name = _nameController.text.trim();
                      final amount = int.parse(
                        _amountController.text.replaceAll('.', '').trim(),
                      );

                      debugPrint('Nama: $name');
                      debugPrint('Nominal: $amount');
                      debugPrint('Kategori: $_category');
                      debugPrint('Tanggal: $_selectedDate');

                      final expense = Expense(
                        id: widget.expense?.id,
                        name: _nameController.text.trim(),
                        amount: int.parse(
                          _amountController.text.replaceAll('.', '').trim(),
                        ),
                        category: _category,
                        date: _selectedDate,
                      );

                      Navigator.pop(context, expense);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.expense == null
                                ? 'Pengeluaran berhasil ditambahkan.'
                                : 'Pengeluaran berhasil diperbarui.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(
                    widget.expense == null
                        ? 'Simpan Pengeluaran'
                        : 'Simpan Perubahan',
                  ),
                ),
              ],
            ),
          )
        )
      )
    );
  }
}