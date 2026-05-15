import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

const List<Map<String, dynamic>> kWorkTypes = [
  {'label': 'Painting',      'icon': '🎨', 'color': Color(0xFF1BA8D4)},
  {'label': 'Tiling',        'icon': '🟫', 'color': Color(0xFF1BA8D4)},
  {'label': 'Flooring',      'icon': '🏠', 'color': Color(0xFF1BA8D4)},
  {'label': 'False Ceiling',  'icon': '⬜', 'color': Color(0xFF1BA8D4)},
  {'label': 'Full Renovation','icon': '🔨', 'color': Color(0xFF1BA8D4)},
  {'label': 'Electrical',    'icon': '⚡', 'color': Color(0xFF1BA8D4)},
  {'label': 'Plumbing',      'icon': '🔧', 'color': Color(0xFF1BA8D4)},
  {'label': 'Furniture',     'icon': '🪑', 'color': Color(0xFF1BA8D4)},
];

const List<String> kRoomTypes = [
  'Living Room', 'Bedroom', 'Kitchen', 'Bathroom',
  'Office', 'Dining Room', 'Full Home', 'Commercial',
];

const List<String> kQualityLevels = ['Budget', 'Standard', 'Premium', 'Luxury'];

class CostEstimatorScreen extends StatefulWidget {
  const CostEstimatorScreen({super.key});

  @override
  State<CostEstimatorScreen> createState() => _CostEstimatorScreenState();
}

class _CostEstimatorScreenState extends State<CostEstimatorScreen>
    with TickerProviderStateMixin {

  // Form state
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedRoomType = 'Living Room';
  int _selectedWorkIndex = 0;
  String _selectedQuality = 'Standard';
  String _selectedUnit = 'Feet';
  String _selectedCurrency = 'INR (Rs)';

  String _generatedResult = '';
  bool _isGenerating = false;
  bool _showResult = false;
  String _selectedLanguage = 'English';

  WebSocketChannel? _channel;
  final ScrollController _scrollController = ScrollController();

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  final List<String> _units = ['Feet', 'Meters'];
  final List<String> _currencies = ['INR (Rs)', 'USD (\$)', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selectedLanguage = prefs.getString('selected_language') ?? 'English');
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _slideController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _estimate() {
    final length = _lengthController.text.trim();
    final width = _widthController.text.trim();
    if (length.isEmpty || width.isEmpty) {
      _showSnack('Please enter room length and width!');
      return;
    }

    setState(() { _isGenerating = true; _generatedResult = ''; _showResult = false; });
    _slideController.reset();

    final height = _heightController.text.trim().isNotEmpty ? _heightController.text.trim() : '9';
    final location = _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : 'India';
    final notes = _notesController.text.trim();
    final work = kWorkTypes[_selectedWorkIndex];

    // Calculate area
    final l = double.tryParse(length) ?? 0;
    final w = double.tryParse(width) ?? 0;
    final h = double.tryParse(height) ?? 9;
    final floorArea = l * w;
    final wallArea = 2 * (l + w) * h;
    final totalArea = floorArea + wallArea;

    final prompt =
        'You are an expert interior cost estimator in $location. '
        'Provide a detailed cost breakdown for the following renovation work.\n\n'
        'ROOM DETAILS:\n'
        '- Room Type: $_selectedRoomType\n'
        '- Work Type: ${work['label']}\n'
        '- Dimensions: $length × $width × $height $_selectedUnit\n'
        '- Floor Area: ${floorArea.toStringAsFixed(1)} sq $_selectedUnit\n'
        '- Wall Area: ${wallArea.toStringAsFixed(1)} sq $_selectedUnit\n'
        '- Total Area: ${totalArea.toStringAsFixed(1)} sq $_selectedUnit\n'
        '- Quality Level: $_selectedQuality\n'
        '- Location: $location\n'
        '- Currency: $_selectedCurrency\n'
        '${notes.isNotEmpty ? '- Additional Notes: $notes\n' : ''}'
        '\nProvide complete cost estimate:\n\n'
        '💰 COST SUMMARY\n'
        '- Total Estimated Cost: (range min-max)\n'
        '- Cost per sq ft: \n'
        '- Labor Cost: \n'
        '- Material Cost: \n\n'
        '📋 DETAILED BREAKDOWN\n'
        'List each item with:\n'
        '- Item name\n'
        '- Quantity needed\n'
        '- Unit price\n'
        '- Total cost\n\n'
        '🏷️ MATERIAL LIST\n'
        'Specific materials needed with quantities and estimated prices\n\n'
        '👷 LABOR ESTIMATE\n'
        '- Number of workers needed\n'
        '- Estimated days to complete\n'
        '- Daily labor rate\n'
        '- Total labor cost\n\n'
        '💡 COST SAVING TIPS\n'
        '3-5 practical tips to reduce cost\n\n'
        '⚠️ IMPORTANT NOTES\n'
        '- Factors that may increase cost\n'
        '- Recommended contractors/vendors\n\n'
        'Use $_selectedCurrency currency. Be specific with current market rates in $location.\n'
        'Language: $_selectedLanguage';

    try {
      _channel?.sink.close(status.goingAway);
      _channel = WebSocketChannel.connect(Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));
      _channel!.stream.listen((data) {
        final decoded = jsonDecode(data);
        setState(() {
          if (decoded['type'] == 'stream') _generatedResult = decoded['message'] ?? '';
          if (decoded['type'] == 'done') {
            _isGenerating = false;
            _showResult = true;
            _slideController.forward();
            // ✅ Auto scroll to result
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
      }, onError: (_) { setState(() => _isGenerating = false); _showSnack('Connection error.'); });

      _channel!.sink.add(jsonEncode({
        'message': prompt,
        'language': _selectedLanguage,
        'model': 'Llama 3.3 70B', // ✅ Better model for detailed cost breakdown
      }));
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnack('Error: $e');
    }
  }

  void _resetAll() {
    setState(() {
      _generatedResult = ''; _showResult = false;
      _lengthController.clear(); _widthController.clear();
      _heightController.clear(); _locationController.clear();
      _notesController.clear();
    });
    _slideController.reset();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    const accent = Color(0xFF1BA8D4);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: bg, statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 4),
                const Text('💰', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Cost Estimator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                if (_showResult)
                  TextButton.icon(onPressed: _resetAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(foregroundColor: accent),
                  ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Work type ──
                  Text('Work Type', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kWorkTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final w = kWorkTypes[i];
                        final isSelected = i == _selectedWorkIndex;
                        final color = w['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedWorkIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 76,
                            decoration: BoxDecoration(
                              color: isSelected ? color : card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1),
                              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(w['icon'] as String, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(w['label'] as String, textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : color)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Room type ──
                  Text('Room Type', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kRoomTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final isSelected = kRoomTypes[i] == _selectedRoomType;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRoomType = kRoomTypes[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? accent : card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? accent : accent.withOpacity(0.3)),
                            ),
                            child: Center(child: Text(kRoomTypes[i],
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : accent))),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Dimensions ──
                  Text('Room Dimensions', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),

                  // Unit selector
                  Row(children: _units.map((unit) {
                    final isSelected = unit == _selectedUnit;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedUnit = unit),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: unit != _units.last ? 8 : 0, bottom: 10),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? accent : accent.withOpacity(0.3)),
                        ),
                        child: Center(child: Text(unit,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : accent))),
                      ),
                    ));
                  }).toList()),

                  Row(children: [
                    Expanded(child: _dimField(_lengthController, 'Length', '12', textColor, subColor, card, accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _dimField(_widthController, 'Width', '10', textColor, subColor, card, accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _dimField(_heightController, 'Height', '9', textColor, subColor, card, accent)),
                  ]),

                  const SizedBox(height: 18),

                  // ── Quality level ──
                  Text('Quality Level', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: kQualityLevels.map((q) {
                    final isSelected = q == _selectedQuality;
                    final colors = {'Budget': Color(0xFF1BA8D4), 'Standard': const Color(0xFF1BA8D4), 'Premium': const Color(0xFF1BA8D4), 'Luxury': const Color(0xFF1BA8D4)};
                    final qColor = colors[q]!;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedQuality = q),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: q != kQualityLevels.last ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? qColor : card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? qColor : qColor.withOpacity(0.4)),
                        ),
                        child: Center(child: Text(q,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : qColor))),
                      ),
                    ));
                  }).toList()),

                  const SizedBox(height: 18),

                  // ── Currency + Location row ──
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Currency', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.2))),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            isExpanded: true,
                            dropdownColor: card,
                            style: TextStyle(color: textColor, fontSize: 13),
                            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _selectedCurrency = v!),
                          ),
                        ),
                      ),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Location', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.2))),
                        child: TextField(
                          controller: _locationController,
                          style: TextStyle(color: textColor, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. Chennai',
                            hintStyle: TextStyle(color: subColor, fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.location_on_rounded, color: accent, size: 18),
                          ),
                        ),
                      ),
                    ])),
                  ]),

                  const SizedBox(height: 14),

                  // ── Additional notes ──
                  Text('Additional Notes (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.2))),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 2,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Need waterproof paint, premium tiles only...',
                        hintStyle: TextStyle(color: subColor, fontSize: 12),
                        contentPadding: const EdgeInsets.all(12),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.note_rounded, color: accent, size: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Estimate button ──
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _estimate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4, shadowColor: accent.withOpacity(0.4),
                      ),
                      child: _isGenerating
                          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Calculating...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ])
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('💰', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text('Calculate Cost Estimate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Streaming ──
                  if (_isGenerating && _generatedResult.isNotEmpty)
                    _buildResultCard(card, textColor, accent, isStreaming: true),

                  // ── Final result ──
                  if (_showResult && !_isGenerating)
                    SlideTransition(position: _slideAnim,
                        child: _buildResultCard(card, textColor, accent, isStreaming: false)),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dimField(TextEditingController ctrl, String label, String hint,
      Color textColor, Color subColor, Color card, Color accent) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.2))),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: subColor, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: InputBorder.none,
            suffixText: _selectedUnit == 'Feet' ? 'ft' : 'm',
            suffixStyle: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ]);
  }

  Widget _buildResultCard(Color card, Color textColor, Color accent, {required bool isStreaming}) {
    final work = kWorkTypes[_selectedWorkIndex];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Text(work['icon'] as String, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isStreaming ? 'Calculating...' : 'Cost Estimate Ready! 💰',
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent, fontSize: 14)),
              Text('${work['label']} • $_selectedRoomType • $_selectedQuality',
                  style: TextStyle(fontSize: 11, color: accent.withOpacity(0.7))),
            ])),
            if (!isStreaming) ...[
              IconButton(icon: Icon(Icons.copy_rounded, color: accent, size: 20),
                  onPressed: () { Clipboard.setData(ClipboardData(text: _generatedResult)); _showSnack('Copied! ✅'); },
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
              IconButton(icon: Icon(Icons.share_rounded, color: accent, size: 20),
                  onPressed: () => Share.share('💰 Cost Estimate\n\n$_generatedResult\n\n— Omega AI'),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_generatedResult,
              style: TextStyle(color: textColor, fontSize: 13.5, height: 1.65)),
        ),
        if (!isStreaming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Clipboard.setData(ClipboardData(text: _generatedResult)); _showSnack('Copied! ✅'); },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: accent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Share.share('💰 Cost Estimate\n\n$_generatedResult\n\n— Omega AI'),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
            ]),
          ),
      ]),
    );
  }
}