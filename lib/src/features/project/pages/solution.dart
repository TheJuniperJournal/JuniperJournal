import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fleather/fleather.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';
import 'package:juniper_journal/src/features/project/project.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:juniper_journal/src/shared/styling/theme.dart';
import '../../../backend/storage/storage_service.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../../main.dart';

/// Custom embed for math equations
// class MathEmbed extends BlockEmbed {
//   MathEmbed(String latex) : super('math:$latex');

//   static MathEmbed fromJson(String data) {
//     return MathEmbed(data);
//   }

//   String get latex => type.substring(5); // Remove 'math:' prefix
// }

class SolutionScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> tags;

  const SolutionScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.tags,
  });

  @override
  State<SolutionScreen> createState() => _SolutionScreenState();
}

class _SolutionScreenState extends State<SolutionScreen> {
  final String _currentSection = 'SOLUTION';

  FleatherController? _controller;
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  final ProjectsRepo _projectsRepo = ProjectsRepo();
  bool _isLoading = true;
  bool _isHeaderCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDocument();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Loads the document from Supabase
  Future<void> _loadDocument() async {
    final solutionJson = await _projectsRepo.getSolution(widget.projectId);

    if (mounted) {
      setState(() {
        if (solutionJson != null && solutionJson.isNotEmpty) {
          try {
            final doc = ParchmentDocument.fromJson(jsonDecode(solutionJson));
            _controller = FleatherController(document: doc);
          } catch (e) {
            debugPrint('Error parsing solution: $e');
            _controller = FleatherController();
          }
        } else {
          _controller = FleatherController();
        }
        _isLoading = false;
      });
    }
  }

  /// Saves the current document to Supabase
  Future<void> _saveDocument() async {
    if (_controller == null) return;

    try {
      // Serialize document to JSON string
      final documentJson = jsonEncode(_controller!.document);

      await _projectsRepo.updateSolution(
        id: widget.projectId,
        solutionJson: documentJson,
      );
    } catch (e) {
      debugPrint('Error saving document: $e');
      if (mounted) {
        showTopSnackBar(context, 'Error saving solution', isError: true);
      }
    }
  }

  /// Shows a dialog to let the user choose between camera or gallery
  Future<void> _openCamera() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Add Image'),
        message: const Text('Choose a source for your image'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickAndUploadImage(ImageSource.camera);
            },
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickAndUploadImage(ImageSource.gallery);
            },
            child: const Text('Choose from Gallery'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  /// Picks an image from the specified source, uploads it to Supabase, and inserts it into the document
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      // Pick the image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show loading indicator
      if (mounted) {
        showTopSnackBar(context, 'Uploading image...');
      }

      // Upload to Supabase Storage
      final imageUrl = await _storageService.uploadImage(
        image,
        folder: 'solution',
      );

      if (imageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showTopSnackBar(context, 'Failed to upload image', isError: true);
        }
        return;
      }

      // Insert image into Fleather document
      _insertImageIntoDocument(imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showTopSnackBar(context, 'Image added successfully!');
      }
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showTopSnackBar(context, 'Failed to add image', isError: true);
      }
    }
  }

  /// Inserts an image embed into the Fleather document at the current cursor position
  void _insertImageIntoDocument(String imageUrl) {
    if (_controller == null) return;

    final index = _controller!.selection.extentOffset;

    // Create the image embed using BlockEmbed
    final embed = BlockEmbed.image(imageUrl);

    // Insert the embed into the document
    _controller!.replaceText(index, 0, embed);

    // Add a newline after the image for better UX
    _controller!.replaceText(index + 1, 0, '\n');

    // Move cursor after the image
    _controller!.updateSelection(TextSelection.collapsed(offset: index + 2));
  }

  /// Shows a dialog to configure and insert a table
  Future<void> _insertTable() async {
    if (_controller == null) return;

    // Save the current cursor position
    final savedSelection = _controller!.selection;
    final savedIndex =
        savedSelection.isValid && savedSelection.extentOffset >= 0
        ? savedSelection.extentOffset
        : _controller!.document.length - 1;

    final rowsController = TextEditingController(text: '3');
    final colsController = TextEditingController(text: '3');

    final result = await showAppDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Insert Table'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Table dimensions:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: rowsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rows',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Columns',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final rows = int.tryParse(rowsController.text.trim()) ?? 3;
                final cols = int.tryParse(colsController.text.trim()) ?? 3;

                // Validate dimensions
                if (rows > 0 && rows <= 10 && cols > 0 && cols <= 10) {
                  Navigator.of(context).pop({'rows': rows, 'cols': cols});
                }
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted && _controller != null) {
      _insertTableIntoDocument(result['rows']!, result['cols']!, savedIndex);
    }
  }

  /// Updates a table embed in the document with new data
  void _updateTableEmbed(String oldTableUrl, String newTableUrl) {
    if (_controller == null || !mounted) return;

    try {
      // Search through the document to find the old table embed
      final doc = _controller!.document;
      var offset = 0;

      for (final node in doc.root.children) {
        if (node is BlockNode) {
          for (final child in node.children) {
            if (child is EmbedNode) {
              final embed = child.value;
              if (embed.type == 'image') {
                final url = embed.data['source'] as String?;
                if (url == oldTableUrl) {
                  // Found the table, replace it
                  final newEmbed = BlockEmbed.image(newTableUrl);
                  _controller!.replaceText(offset, 1, newEmbed);
                  return;
                }
              }
            }
            offset += child.length;
          }
        } else {
          offset += node.length;
        }
      }
    } catch (e) {
      debugPrint('Error updating table embed: $e');
    }
  }

  /// Inserts a table into the Fleather document at the specified index
  void _insertTableIntoDocument(int rows, int cols, int insertIndex) {
    if (_controller == null || !mounted) return;

    try {
      final docLength = _controller!.document.length;

      // If document is empty or nearly empty, add a space first
      if (docLength <= 1) {
        _controller!.replaceText(0, 0, '\n');
      }

      // Recalculate index after potentially adding content
      final maxIndex = _controller!.document.length - 1;
      final safeIndex = math.max(0, math.min(insertIndex, maxIndex));

      // Create table data structure - initially empty cells
      final tableData = {
        'rows': rows,
        'cols': cols,
        'cells': List.generate(rows, (_) => List.generate(cols, (_) => '')),
      };

      // Encode table data
      final encodedTable = base64Encode(utf8.encode(jsonEncode(tableData)));
      final tableUrl = 'table://$encodedTable';
      final embed = BlockEmbed.image(tableUrl);

      // Insert the embed block into the document
      _controller!.replaceText(safeIndex, 0, embed);

      // Add a newline for spacing
      _controller!.replaceText(safeIndex + 1, 0, '\n');

      // Move cursor after the embed
      _controller!.updateSelection(
        TextSelection.collapsed(offset: safeIndex + 2),
      );

      // Trigger a rebuild after a delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {});
        }
      });

      // Request focus back to the editor
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });

      // Show success message
      if (mounted) {
        showTopSnackBar(context, 'Table inserted!');
      }
    } catch (e, stackTrace) {
      debugPrint('Error inserting table: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        showTopSnackBar(context, 'Failed to insert table', isError: true);
      }
    }
  }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    final embed = node.value;

    // Handle images (which might be math equations in disguise)
    if (embed.type == 'image') {
      final imageUrl = embed.data['source'] as String?;

      // Check if this is a math equation
      if (imageUrl != null && imageUrl.startsWith('math://')) {
        try {
          // Extract and decode the LaTeX
          final encodedLatex = imageUrl.substring(7); // Remove 'math://' prefix
          final latex = utf8.decode(base64Decode(encodedLatex));

          // Render LaTeX using flutter_math_fork
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Math.tex(
              latex,
              textStyle: const TextStyle(
                fontFamily: AppTypography.headingFamily,
                fontSize: AppTypography.sectionTitleSize,
              ),
              mathStyle: MathStyle.display,
              onErrorFallback: (FlutterMathException exception) {
                // Fallback to showing the raw LaTeX if rendering fails
                return Text(
                  latex,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Courier',
                    color: Colors.red,
                  ),
                );
              },
            ),
          );
        } catch (e) {
          return const Icon(Icons.error, color: Colors.red);
        }
      }

      // Check if this is a table
      if (imageUrl != null && imageUrl.startsWith('table://')) {
        try {
          // Extract and decode the table data
          final encodedTable = imageUrl.substring(
            8,
          ); // Remove 'table://' prefix
          final tableJson = utf8.decode(base64Decode(encodedTable));
          final tableData = jsonDecode(tableJson) as Map<String, dynamic>;

          final rows = tableData['rows'] as int;
          final cols = tableData['cols'] as int;
          final cells = (tableData['cells'] as List)
              .map(
                (row) => (row as List).map((cell) => cell.toString()).toList(),
              )
              .toList();

          // Render editable table
          return _EditableTable(
            rows: rows,
            cols: cols,
            initialCells: cells,
            onCellChanged: (rowIndex, colIndex, newValue) {
              // Update the cell data
              cells[rowIndex][colIndex] = newValue;

              // Update the document with new table data
              final updatedTableData = {
                'rows': rows,
                'cols': cols,
                'cells': cells,
              };

              final newEncodedTable = base64Encode(
                utf8.encode(jsonEncode(updatedTableData)),
              );
              final newTableUrl = 'table://$newEncodedTable';

              // Find and replace the old embed with the updated one
              _updateTableEmbed(imageUrl, newTableUrl);
            },
          );
        } catch (e) {
          debugPrint('Error rendering table: $e');
          return const Icon(Icons.error, color: Colors.red);
        }
      }

      // Regular image
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ProtectedImage.network(
          imageUrl ?? '',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Applies text formatting to the selected text or toggles formatting for new text
  void _formatText(ParchmentAttribute attribute) {
    if (_controller == null) return;

    final selection = _controller!.selection;

    // If there's a selection, format the selected text
    if (selection.isValid && !selection.isCollapsed) {
      _controller!.formatText(
        selection.start,
        selection.end - selection.start,
        attribute,
      );
    } else {
      // If no selection, toggle the attribute for future typing
      // Get the current style at cursor position
      final currentStyle = _controller!.getSelectionStyle();

      // Check if the attribute is already active
      final isActive = currentStyle.contains(attribute);

      if (isActive) {
        // If active, unset it (turn off the formatting)
        _controller!.formatSelection(attribute.unset);
      } else {
        // If not active, set it (turn on the formatting)
        _controller!.formatSelection(attribute);
      }
    }

    // Request focus back to the editor
    _focusNode.requestFocus();
  }

  /// Shows a dialog to input a LaTeX math equation
  Future<void> _insertMathEquation() async {
    if (_controller == null) {
      debugPrint('Controller is null, returning');
      return;
    }

    // Save the current cursor position BEFORE opening the dialog
    final savedSelection = _controller!.selection;
    final savedIndex =
        savedSelection.isValid && savedSelection.extentOffset >= 0
        ? savedSelection.extentOffset
        : _controller!.document.length - 1;

    final TextEditingController latexController = TextEditingController();

    final result = await showAppDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Insert Math Equation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter LaTeX equation:',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latexController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Examples:',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r'• E = mc^2'
                  '\n'
                  r'• \frac{a}{b}'
                  '\n'
                  r'• x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}'
                  '\n'
                  r'• \int_0^1 x^2 dx',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final latex = latexController.text.trim();
                if (latex.isNotEmpty) {
                  Navigator.of(context).pop(latex);
                } else {
                  debugPrint('LaTeX is empty, not popping');
                }
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) {
        debugPrint('Widget not mounted after dialog, aborting');
        return;
      }

      if (_controller == null) {
        debugPrint('Controller is null after dialog, aborting');
        return;
      }

      // Insert directly - no callbacks needed
      _insertMathIntoDocument(result, savedIndex);
    } else {
      debugPrint('Result was null or empty, not inserting');
    }
  }

  /// Remove the MathEmbed class definition and use this instead:

  /// Inserts a math equation into the Fleather document at the specified index
  void _insertMathIntoDocument(String latex, int insertIndex) {
    if (_controller == null || !mounted) {
      debugPrint('Controller null or not mounted, returning');
      return;
    }

    try {
      final docLength = _controller!.document.length;

      // If document is empty or nearly empty, add a space first
      if (docLength <= 1) {
        _controller!.replaceText(0, 0, '\n');
      }

      // Recalculate index after potentially adding content
      final maxIndex = _controller!.document.length - 1;
      final safeIndex = math.max(0, math.min(insertIndex, maxIndex));

      // Create an image embed but use a special URL format to indicate it's math
      final encodedLatex = base64Encode(utf8.encode(latex));
      final mathUrl = 'math://$encodedLatex';
      final embed = BlockEmbed.image(mathUrl);

      // Insert the embed block into the document
      _controller!.replaceText(safeIndex, 0, embed);

      // Add a newline for spacing
      _controller!.replaceText(safeIndex + 1, 0, '\n');

      // Move cursor after the embed
      _controller!.updateSelection(
        TextSelection.collapsed(offset: safeIndex + 2),
      );

      // Trigger a rebuild after a delay to ensure dialog is fully closed
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {});
        }
      });

      // Request focus back to the editor after the rebuild
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });

      // Show success message
      if (mounted) {
        showTopSnackBar(context, 'Math equation inserted!');
      }
    } catch (e, stackTrace) {
      debugPrint('!!! ERROR in _insertMathIntoDocument: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        showTopSnackBar(context, 'Failed to insert equation', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.projectName;
    final tags = widget.tags;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content with SafeArea
          SafeArea(
            bottom: false, // Don't apply SafeArea to bottom
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          CupertinoIcons.back,
                          color: AppColors.iconPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          projectName,
                          style: const TextStyle(
                            fontFamily: AppTypography.headingFamily,
                            fontSize: AppTypography.sectionTitleSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      // Save button with options
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.save, color: AppColors.primary),
                        tooltip: 'Save',
                        offset: const Offset(0, 40),
                        onSelected: (value) async {
                          if (value == 'save') {
                            await _saveDocument();
                          } else if (value == 'save_continue') {
                            final navigator = Navigator.of(context);
                            await _saveDocument();
                            if (mounted) {
                              // Navigate to home page
                              navigator.pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const HomeShellScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'save',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.save_outlined,
                                  size: 20,
                                  color: AppColors.darkText,
                                ),
                                SizedBox(width: 12),
                                Text('Save'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'save_continue',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_forward,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 12),
                                Text('Save & Complete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Navigation and performance expectation tags - Collapsible
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  height: _isHeaderCollapsed ? 36 : null,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Navigation dropdown
                          _buildNavigationDropdown(),

                          // Only show tags when not collapsed
                          if (!_isHeaderCollapsed) ...[
                            const SizedBox(height: 12),
                            // Project tags
                            if (tags.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCF7E4),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Text(
                                      tag,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Fleather rich text editor with loading state
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification notification) {
                            if (notification is ScrollUpdateNotification) {
                              // Update scroll position for header collapse
                              final offset = notification.metrics.pixels;
                              final shouldCollapse = offset > 50;

                              if (shouldCollapse != _isHeaderCollapsed) {
                                setState(() {
                                  _isHeaderCollapsed = shouldCollapse;
                                });
                              }
                            }
                            return false;
                          },
                          child: Container(
                            color: AppColors.white,
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                            ),
                            child: FleatherEditor(
                              controller: _controller!,
                              focusNode: _focusNode,
                              padding: const EdgeInsets.only(
                                bottom: 120,
                              ), // Extra space to scroll past toolbar
                              autofocus: false,
                              embedBuilder: _embedBuilder,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Floating toolbar at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: ConceptExplorationToolbar(
              onFormat: _formatText,
              onCamera: _openCamera,
              onInsertMath: _insertMathEquation,
              onInsertTable: _insertTable,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currentSection,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppColors.primary,
          ),
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.primary,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
          dropdownColor: AppColors.accent.withValues(alpha: 0.5),
          items: const [
            DropdownMenuItem(
              value: 'PROJECT NAME',
              child: Text(
                'PROJECT NAME',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'PROBLEM STATEMENT',
              child: Text(
                'PROBLEM STATEMENT',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'TIMELINE',
              child: Text(
                'TIMELINE',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'MATERIALS COST',
              child: Text(
                'MATERIALS COST',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'METRICS',
              child: Text(
                'METRICS',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'SOLUTION',
              child: Text(
                'SOLUTION',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == 'PROJECT NAME') {
              pushAppRoute(
                context,
                MaterialPageRoute(builder: (context) => CreateProjectScreen()),
              );
            } else if (value == 'PROBLEM STATEMENT') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DefineProblemStatementScreen(projectId: widget.projectId),
                ),
              );
            } else if (value == 'TIMELINE') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => InteractiveTimelinePage(
                    projectId: widget.projectId,
                    projectName: widget.projectName,
                    tags: widget.tags,
                  ),
                ),
              );
            } else if (value == 'MATERIALS COST') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => MaterialsCostPage(
                    projectId: widget.projectId,
                    projectName: widget.projectName,
                    tags: widget.tags,
                  ),
                ),
              );
            } else if (value == 'METRICS') {
              pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (context) => MetricsPage(
                    projectId: widget.projectId,
                    projectName: widget.projectName,
                    tags: widget.tags,
                  ),
                ),
              );
            }
            // If SOLUTION is selected, stay on current page
          },
        ),
      ),
    );
  }
}

/// Editable table widget that allows users to tap and edit cells
class _EditableTable extends StatefulWidget {
  final int rows;
  final int cols;
  final List<List<String>> initialCells;
  final Function(int rowIndex, int colIndex, String newValue) onCellChanged;

  const _EditableTable({
    required this.rows,
    required this.cols,
    required this.initialCells,
    required this.onCellChanged,
  });

  @override
  State<_EditableTable> createState() => _EditableTableState();
}

class _EditableTableState extends State<_EditableTable> {
  late List<List<FleatherController>> _controllers;
  late List<List<FocusNode>> _focusNodes;

  @override
  void initState() {
    super.initState();
    // Create Fleather controllers for each cell
    _controllers = List.generate(
      widget.rows,
      (row) => List.generate(widget.cols, (col) {
        // Try to parse existing cell data as Fleather JSON, or create empty doc
        try {
          final cellData = widget.initialCells[row][col];
          if (cellData.isNotEmpty) {
            final doc = ParchmentDocument.fromJson(jsonDecode(cellData));
            return FleatherController(document: doc);
          }
        } catch (e) {
          // If not valid JSON, treat as plain text
          final cellData = widget.initialCells[row][col];
          if (cellData.isNotEmpty) {
            final doc = ParchmentDocument()..insert(0, cellData);
            return FleatherController(document: doc);
          }
        }
        return FleatherController();
      }),
    );

    _focusNodes = List.generate(
      widget.rows,
      (row) => List.generate(widget.cols, (col) => FocusNode()),
    );

    // Listen to document changes
    for (var row = 0; row < widget.rows; row++) {
      for (var col = 0; col < widget.cols; col++) {
        final r = row;
        final c = col;
        _controllers[r][c].document.changes.listen((_) {
          // Save the document as JSON when it changes
          final json = jsonEncode(_controllers[r][c].document);
          widget.onCellChanged(r, c, json);
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose all controllers and focus nodes
    for (var row in _controllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    for (var row in _focusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Table(
        border: TableBorder.all(color: Colors.grey[400]!, width: 1.0),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: List.generate(widget.rows, (rowIndex) {
          return TableRow(
            children: List.generate(widget.cols, (colIndex) {
              return Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.all(4.0),
                child: FleatherEditor(
                  controller: _controllers[rowIndex][colIndex],
                  focusNode: _focusNodes[rowIndex][colIndex],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
