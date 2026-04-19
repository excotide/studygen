import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/quiz_model.dart';
import '../../generate/providers/quiz_provider.dart';
import '../../../shared/widgets/botnav_widget.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  String? _filePath;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isPickingFile       = false;
  ExtractionMode _mode      = ExtractionMode.parser;
  String _summaryLength     = 'medium';
  int _numQuestions         = 10;
  bool _isGenerating        = false;
  String _loadingStep       = '';
  double _progress          = 0;
  String? _localError;
  QuizModel? _generatedQuiz;

  Future<FilePickerResult?> _pickPdfFile() async {
    try {
      return await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: kIsWeb,
      );
    } catch (_) {
      // Fallback for web/browser combinations that fail on custom type filters.
      if (!kIsWeb) rethrow;
      return await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await _pickPdfFile();

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final hasPath = !kIsWeb && picked.path != null && picked.path!.isNotEmpty;
      final hasBytes = picked.bytes != null && picked.bytes!.isNotEmpty;

      if (!picked.name.toLowerCase().endsWith('.pdf')) {
        setState(() {
          _localError = 'File harus berformat PDF.';
          _filePath = null;
          _fileName = null;
          _fileBytes = null;
        });
        return;
      }

      if (picked.size > 20 * 1024 * 1024) {
        setState(() {
          _localError = 'Ukuran file maksimal 20MB.';
          _filePath = null;
          _fileName = null;
          _fileBytes = null;
        });
        return;
      }

      if (!hasPath && !hasBytes) {
        if (!mounted) return;
        setState(() => _localError = 'File tidak bisa dibaca. Coba pilih ulang.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File tidak bisa dibaca. Coba pilih ulang.')),
        );
        return;
      }

      setState(() {
        _filePath = kIsWeb ? null : picked.path;
        _fileName = picked.name;
        _fileBytes = hasBytes ? picked.bytes : null;
        _localError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = 'Gagal memilih file: $e';
      setState(() => _localError = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  Future<void> _generate() async {
    if (_filePath == null && _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih file PDF terlebih dahulu')),
      );
      return;
    }

    setState(() { _isGenerating = true; _progress = 0.1; });
    setState(() => _localError = null);

    final provider = context.read<QuizProvider>();
    final ok = await provider.generateQuiz(
      filePath: _filePath,
      fileBytes: _fileBytes,
      fileName: _fileName ?? 'materi.pdf',
      mode: _mode,
      numQuestions: _numQuestions,
      summaryLength: _summaryLength,
      onStep: (step) {
        if (!mounted) return;
        setState(() {
          _loadingStep = step;
          _progress    = (_progress + 0.2).clamp(0.1, 0.92);
        });
      },
      onUploadProgress: (ratio) {
        if (!mounted) return;
        setState(() {
          _loadingStep = 'Mengupload PDF...';
          _progress = (0.1 + (ratio * 0.35)).clamp(0.1, 0.45);
        });
      },
    );

    if (!mounted) return;
    if (ok && provider.currentQuiz != null) {
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generatedQuiz = provider.currentQuiz;
      });
    } else {
      final msg = provider.error ?? 'Gagal membuat rangkuman';
      setState(() {
        _isGenerating = false;
        _localError = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      activeRoute: '/generate',
      child: SafeArea(
        child: _isGenerating
            ? _buildLoading(context)
            : (_generatedQuiz != null
                ? _buildSummaryPreview(context)
                : _buildForm(context)),
      ),
    );
  }

  Widget _buildSummaryPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quiz = _generatedQuiz!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: cs.surface,
          floating: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: Text('Rangkuman Materi',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22, color: cs.onSurface)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      quiz.summary,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${quiz.questions.length} soal sudah siap dibuat dari rangkuman ini.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<QuizProvider>().fetchHistory(forceRefresh: true);
                    if (!context.mounted) return;
                    context.go('/home');
                  },
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: const Text('Kembali ke Beranda'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/summary', extra: quiz),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('Buka Detail Rangkuman'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onSurface,
                    foregroundColor: cs.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _generatedQuiz = null;
                      _filePath = null;
                      _fileName = null;
                      _fileBytes = null;
                    });
                  },
                  child: const Text('Upload PDF Lain'),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: cs.surface,
          floating: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
            title: Text('Buat Rangkuman',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22, color: cs.onSurface)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text('Upload PDF materi dan atur preferensimu.',
                  style: TextStyle(
                      fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),

              // Upload zone
              _buildUploadZone(context),
              if (_localError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _localError!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Mode ekstraksi
              _sectionLabel(context, 'MODE EKSTRAKSI'),
              const SizedBox(height: 10),
              _modeCard(context, ExtractionMode.parser,
                  Icons.text_snippet_outlined,
                  'PDF Digital',
                  'Export dari Word, PPT, modul digital'),
              const SizedBox(height: 8),
              _modeCard(context, ExtractionMode.mistral,
                  Icons.auto_awesome_outlined,
                  'Mistral OCR',
                  'OCR akurat via AI, pakai free tier'),
              const SizedBox(height: 24),

              // Settings
              _sectionLabel(context, 'PENGATURAN OUTPUT'),
              const SizedBox(height: 10),
              _buildDropdown(
                context,
                label: 'Panjang rangkuman',
                value: _summaryLength,
                items: const {
                  'short':  'Singkat (3-4 paragraf)',
                  'medium': 'Sedang (5-7 paragraf)',
                  'long':   'Panjang (8-10 paragraf)',
                },
                onChanged: (v) => setState(() => _summaryLength = v!),
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                context,
                label: 'Jumlah soal',
                value: _numQuestions.toString(),
                items: const {
                  '5':  '5 soal',
                  '10': '10 soal',
                  '15': '15 soal',
                },
                onChanged: (v) =>
                    setState(() => _numQuestions = int.parse(v!)),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Buat Rangkuman'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onSurface,
                    foregroundColor: cs.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadZone(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final hasFile = _filePath != null || _fileBytes != null;

    return GestureDetector(
      onTap: (hasFile || _isPickingFile) ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? cs.outline
                      : cs.outline.withValues(alpha: 0.5),
            width: 1.5,
            style: hasFile ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: hasFile
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.picture_as_pdf_rounded,
                        size: 22, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fileName!,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface),
                            overflow: TextOverflow.ellipsis),
                        Text('Siap diproses',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                        () {
                          _filePath = null;
                          _fileName = null;
                          _fileBytes = null;
                        }),
                    child: Text('Ganti',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant)),
                  ),
                ],
              )
            : _isPickingFile
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Membaca file PDF...',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface)),
                    ],
                  )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.upload_file_rounded,
                        size: 28, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Text('Tap untuk upload PDF',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text('Maksimal 20MB',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
      ),
    );
  }

  Widget _modeCard(BuildContext context, ExtractionMode mode,
      IconData icon, String title, String desc) {
    final cs       = Theme.of(context).colorScheme;
    final selected = _mode == mode;

    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? cs.surfaceContainerHigh
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
                  color: selected ? cs.onSurface : cs.outline.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? cs.onSurface
                    : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 18,
                  color: selected ? cs.surface : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  size: 20, color: cs.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          dropdownColor: cs.surfaceContainerLow,
          style: TextStyle(fontSize: 14, color: cs.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: cs.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: items.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.onSurface),
            ),
            const SizedBox(height: 24),
            Text(_loadingStep,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Mohon tunggu sebentar...',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                      backgroundColor: cs.outline.withValues(alpha: 0.3),
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: .08)),
      );
}