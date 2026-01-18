import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../api_client.dart';
import '../models.dart';
import '../widgets/receipt_card.dart';
import '../strategies/compress_strategy.dart';

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});
  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _picker = ImagePicker();
  static const CompressionContext _compressionContext = CompressionContext(
    fastStrategy: FastCompressStrategy(),
    qualityStrategy: QualityCompressStrategy(),
    originalStrategy: OriginalCompressStrategy(),
    forceOriginal: true,
  );
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  UploadResult? result;
  bool loading = false;
  String? error;
  String? selectedLabel;
  ReceiptJobStatus? currentJob;

  @override
  void dispose() {
    _storeController.dispose();
    _totalController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      loading = true;
      error = null;
      result = null;
      selectedLabel = null;
      currentJob = null;
    });
    _storeController.clear();
    _totalController.clear();
    _dateController.clear();

    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        setState(() => loading = false);
        return;
      }

      final strategy = _compressionContext.choose(source: source);
      final preparedFile = await strategy.run(picked);

      final sizeKb = (await preparedFile.length()) / 1024;
      // ignore: avoid_print
      print(
          "Prepared file: ${preparedFile.path}, size=${sizeKb.toStringAsFixed(1)} KB");

      final file = await http.MultipartFile.fromPath(
        'file',
        preparedFile.path,
        filename: picked.name,
      );

      final api = ref.read(apiProvider);
      final queued = await api.uploadReceipt(file);
      if (!mounted) return;
      setState(() => currentJob = queued);

      ReceiptJobStatus status = queued;
      if (!queued.isFinal) {
        status = await api.waitForJob(
          queued.jobId,
          onUpdate: (s) {
            if (!mounted) return;
            setState(() => currentJob = s);
          },
        );
      }

      if (!mounted) return;
      if (status.status == 'completed' && status.result != null) {
        final r = status.result!;
        _storeController.text = r.store ?? '';
        _totalController.text =
            r.total != null ? r.total!.toStringAsFixed(2) : '';
        _dateController.text = r.date ?? '';
        setState(() {
          result = r;
          selectedLabel = r.category;
          currentJob = status;
        });
      } else if (status.status == 'failed') {
        setState(() {
          error = status.error ?? 'Processing failed';
          currentJob = status;
        });
      } else {
        setState(() {
          error = 'Processing did not finish (status: ${status.status}).';
          currentJob = status;
        });
      }
    } on TimeoutException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message ?? 'Processing timed out';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _saveCorrection() async {
    if (result == null || selectedLabel == null) return;

    final storeInput = _storeController.text.trim();
    final totalInput = _totalController.text.trim();
    final dateInput = _dateController.text.trim();

    double? totalValue;
    if (totalInput.isNotEmpty) {
      final cleaned = totalInput.replaceAll(',', '');
      totalValue = double.tryParse(cleaned);
      if (totalValue == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Total must be a valid number.')),
          );
        }
        return;
      }
    }

    String? dateIso;
    if (dateInput.isNotEmpty) {
      final parsed = DateTime.tryParse(dateInput);
      if (parsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Date must be in ISO format (YYYY-MM-DD).')),
          );
        }
        return;
      }
      dateIso = parsed.toIso8601String().split('T').first;
    }

    try {
      setState(() => loading = true);
      final api = ref.read(apiProvider);

      // Update DB
      await api.updateReceipt(
        id: result!.id,
        category: selectedLabel,
        store: storeInput.isEmpty ? null : storeInput,
        total: totalValue,
        date: dateIso ?? (dateInput.isEmpty ? null : dateInput),
      );

      // Optional: also send feedback to improve ML
      await api.sendFeedback(text: result!.text, trueLabel: selectedLabel!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved and sent feedback.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F0FF), // soft lavender like dashboard
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Upload New Receipt',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Big upload card (inspo style)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.primary.withOpacity(0.25),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary,
                                    scheme.primary.withOpacity(0.7),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.receipt_long,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Upload New Receipt',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take a photo or choose from your gallery.\nWe\'ll read the details for you.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: loading
                                      ? null
                                      : () => _pick(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Camera'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: loading
                                      ? null
                                      : () => _pick(ImageSource.gallery),
                                  icon:
                                      const Icon(Icons.photo_library_outlined),
                                  label: const Text('Gallery'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (loading) const LinearProgressIndicator(),

                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      if (currentJob != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Job ${currentJob!.jobId} - ${currentJob!.status}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (currentJob!.status != 'completed' &&
                                  currentJob!.status != 'failed')
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Processing... you can leave this screen and return later.',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (currentJob!.error != null &&
                                  currentJob!.error!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    currentJob!.error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      if (result != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ReceiptCard(
                                res: result!,
                                selectedCategory: selectedLabel,
                                onCategoryChanged: (v) =>
                                    setState(() => selectedLabel = v),
                                storeController: _storeController,
                                totalController: _totalController,
                                dateController: _dateController,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: loading ? null : _saveCorrection,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text('Save & Confirm'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
