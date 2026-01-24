import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';
import 'dart:html' as html;

class ExportReportWidget extends StatefulWidget {
  const ExportReportWidget({super.key});

  @override
  State<ExportReportWidget> createState() => _ExportReportWidgetState();
}

class _ExportReportWidgetState extends State<ExportReportWidget> {
  bool _isExporting = false;
  String? _selectedFormat = 'PDF';
  String? _selectedPeriod = '30days';

  final List<String> _formats = ['PDF', 'CSV', 'Excel', 'JSON'];
  final List<String> _periods = ['7days', '30days', '90days', '1year', 'All'];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📥 Export & Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Download trading reports in multiple formats',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Export Options
          if (!isMobile)
            Row(
              children: [
                Expanded(
                  child: _buildExportOption(
                    'Format',
                    _formats,
                    _selectedFormat,
                    (value) => setState(() => _selectedFormat = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildExportOption(
                    'Period',
                    _periods,
                    _selectedPeriod,
                    (value) => setState(() => _selectedPeriod = value),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildExportOption(
                  'Format',
                  _formats,
                  _selectedFormat,
                  (value) => setState(() => _selectedFormat = value),
                ),
                const SizedBox(height: 16),
                _buildExportOption(
                  'Period',
                  _periods,
                  _selectedPeriod,
                  (value) => setState(() => _selectedPeriod = value),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Export Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    disabledBackgroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    _isExporting ? 'Exporting...' : 'Export ${_selectedFormat}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generatePreview,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.preview),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Exports
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Exports',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _buildExportHistoryItem(
                  'Trading Report - January 2026.pdf',
                  '2.4 MB',
                  '2 hours ago',
                ),
                const SizedBox(height: 8),
                _buildExportHistoryItem(
                  'Performance Analysis - Q4 2025.xlsx',
                  '1.8 MB',
                  '1 day ago',
                ),
                const SizedBox(height: 8),
                _buildExportHistoryItem(
                  'Trade History - 30 Days.csv',
                  '856 KB',
                  '3 days ago',
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideY(begin: 0.2);
  }

  Widget _buildExportOption(
    String label,
    List<String> options,
    String? selectedValue,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1A1F2E),
            items: options.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExportHistoryItem(String name, String size, String date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                size,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text(
              date,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => _downloadFile(name),
              icon: const Icon(Icons.download, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportReport() async {
    setState(() => _isExporting = true);

    try {
      // Simulate export delay
      await Future.delayed(const Duration(seconds: 2));

      // Generate mock report data
      final reportData = _generateReportData();

      // Export based on selected format
      if (_selectedFormat == 'PDF') {
        _exportAsPDF(reportData);
      } else if (_selectedFormat == 'CSV') {
        _exportAsCSV(reportData);
      } else if (_selectedFormat == 'Excel') {
        _exportAsExcel(reportData);
      } else if (_selectedFormat == 'JSON') {
        _exportAsJSON(reportData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Report exported successfully as $_selectedFormat!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export failed. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _generatePreview() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Preview: Trading report for $_selectedPeriod in $_selectedFormat format',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Map<String, dynamic> _generateReportData() {
    return {
      'period': _selectedPeriod,
      'totalTrades': 43,
      'winRate': 68.5,
      'profitFactor': 2.34,
      'totalReturn': 12.45,
      'maxDrawdown': -8.2,
      'sharpeRatio': 1.45,
      'exportDate': DateTime.now().toString(),
    };
  }

  void _exportAsPDF(Map<String, dynamic> data) {
    const content = 'Trading Report\nExport in PDF format\n$data';
    _downloadFile('trading_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        content);
  }

  void _exportAsCSV(Map<String, dynamic> data) {
    String content = 'Metric,Value\n';
    data.forEach((key, value) {
      content += '$key,$value\n';
    });
    _downloadFile('trading_report_${DateTime.now().millisecondsSinceEpoch}.csv',
        content);
  }

  void _exportAsExcel(Map<String, dynamic> data) {
    const content = 'Trading Report\nExport in Excel format';
    _downloadFile('trading_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        content);
  }

  void _exportAsJSON(Map<String, dynamic> data) {
    final content = '''
{
  "report": {
    "period": "${data['period']}",
    "totalTrades": ${data['totalTrades']},
    "winRate": ${data['winRate']},
    "profitFactor": ${data['profitFactor']},
    "totalReturn": ${data['totalReturn']},
    "maxDrawdown": ${data['maxDrawdown']},
    "sharpeRatio": ${data['sharpeRatio']},
    "exportDate": "${data['exportDate']}"
  }
}
''';
    _downloadFile('trading_report_${DateTime.now().millisecondsSinceEpoch}.json',
        content);
  }

  void _downloadFile(String filename, String content) {
    final bytes = Uint8List.fromList(content.codeUnits);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}
