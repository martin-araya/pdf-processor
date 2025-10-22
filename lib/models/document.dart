import 'package:intl/intl.dart';  // Para formattedCreatedAt

// Model principal para documentos (de /documents GET)
class Document {
  final String id;
  final String filename;  // Nombre archivo original
  final String? title;  // Título display (de metadata o backend; fallback a filename)
  final int? totalPages;  // Nullable para JSON fails (fallback 0 en UI)
  final DateTime? createdAt;
  final String? status;  // Nuevo: e.g., 'processing', 'processed', 'error'
  final List<PageData> pages;
  final String? targetLanguage;
  final String? continuousText;
  final List<Map<String, dynamic>> allTables;  // Raw para DataTable flex
  final List<ImageData> globalImages;  // List<ImageData> para consistencia

  Document({
    required this.id,
    required this.filename,
    this.title,
    this.totalPages,
    this.createdAt,
    this.status,  // Nuevo
    required this.pages,
    this.targetLanguage,
    this.continuousText,
    this.allTables = const [],
    this.globalImages = const [],  // Default empty
  });

  // From JSON (para response de /documents o single doc)
  factory Document.fromJson(Map<String, dynamic> json) {
    // Fallback title a filename si no presente
    final title = json['title'] as String? ?? json['filename'] as String?;
    return Document(
      id: json['id']?.toString() ?? '',
      filename: json['filename'] as String? ?? 'unknown.pdf',
      title: title,  // Usa title o filename
      totalPages: json['total_pages'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      status: json['status'] as String?,  // Nuevo
      pages: (json['pages'] as List<dynamic>?)?.map((p) => PageData.fromJson(p as Map<String, dynamic>)).toList() ?? [],
      targetLanguage: json['target_language'] as String?,
      continuousText: json['continuousText'] as String?,
      allTables: List<Map<String, dynamic>>.from(json['allTables'] ?? []),
      globalImages: (json['globalImages'] as List<dynamic>?)?.map((imgJson) => ImageData.fromJson(imgJson as Map<String, dynamic>)).toList() ?? [],
    );
  }

  // To JSON (para upload o updates si needed, e.g., POST /documents)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      if (title != null) 'title': title,  // Solo si set
      if (totalPages != null) 'total_pages': totalPages,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (status != null) 'status': status,  // Nuevo
      'pages': pages.map((p) => p.toJson()).toList(),
      if (targetLanguage != null) 'target_language': targetLanguage,
      if (continuousText != null) 'continuousText': continuousText,
      'allTables': allTables,
      'globalImages': globalImages.map((img) => img.toJson()).toList(),
    };
  }

  // Helper para título display (para DashboardScreen, evita null crash)
  String get displayTitle {
    return title ?? filename ?? 'Documento sin título';
  }

  // Helper para fecha formateada (para UI, maneja null)
  String get formattedCreatedAt {
    return createdAt != null
        ? DateFormat('dd/MM/yyyy').format(createdAt!)
        : 'Fecha desconocida';
  }

  @override
  String toString() {
    return 'Document(id: $id, filename: $filename, title: $title, totalPages: $totalPages, status: $status, createdAt: $createdAt, pages: ${pages.length}, allTables: ${allTables.length}, globalImages: ${globalImages.length})';
  }
}

// Datos por página (de processing PDF)
class PageData {
  final int pageNumber;
  final String text;
  final List<String> imageIds;  // Legacy IDs
  final Dimensions dimensions;
  final List<Map<String, dynamic>> tables;
  final List<ImageData> images;  // Full List<ImageData>

  PageData({
    required this.pageNumber,
    required this.text,
    required this.imageIds,
    required this.dimensions,
    this.tables = const [],
    this.images = const [],
  });

  factory PageData.fromJson(Map<String, dynamic> json) {
    return PageData(
      pageNumber: json['page_number'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      imageIds: List<String>.from(json['image_ids'] ?? []),
      dimensions: Dimensions.fromJson(json['dimensions'] ?? {'width': 612.0, 'height': 792.0}),
      tables: List<Map<String, dynamic>>.from(json['tables'] ?? []),
      images: (json['images'] as List<dynamic>?)?.map((imgJson) => ImageData.fromJson(imgJson as Map<String, dynamic>)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page_number': pageNumber,
      'text': text,
      'image_ids': imageIds,
      'dimensions': dimensions.toJson(),
      'tables': tables,
      'images': images.map((img) => img.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'PageData(page: $pageNumber, textLength: ${text.length}, tables: ${tables.length}, images: ${images.length})';
  }
}

// Dimensiones de página (letter size default)
class Dimensions {
  final double width;
  final double height;

  Dimensions({required this.width, required this.height});

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      width: (json['width'] ?? 612.0).toDouble(),
      height: (json['height'] ?? 792.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'width': width, 'height': height};
  }
}

// Datos de imagen (base64 + position)
class ImageData {
  final String id;
  final String data;  // base64 data URI
  final String extension;
  final Map<String, num> position;  // num para flex (x, y, width, height)

  ImageData({
    required this.id,
    required this.data,
    required this.extension,
    required this.position,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    final pos = _parsePosition(json['position'] as Map<String, dynamic>?);
    return ImageData(
      id: json['id'] as String? ?? '',
      data: json['data'] as String? ?? '',
      extension: json['extension'] as String? ?? 'png',
      position: pos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data,
      'extension': extension,
      'position': position.map((k, v) => MapEntry(k, v.toDouble())),  // Convierte num a double
    };
  }

  @override
  String toString() {
    return 'ImageData(id: $id, ext: $extension, pos: $position)';
  }
}

// Helper global para parse position (maneja dynamic/null, defaults)
Map<String, num> _parsePosition(Map<String, dynamic>? posJson) {
  final pos = <String, num>{};
  if (posJson == null || posJson.isEmpty) {
    pos['x'] = 50.0;
    pos['y'] = 50.0;
    pos['width'] = 80.0;
    pos['height'] = 60.0;
    return pos;
  }
  for (var key in posJson.keys) {
    final val = posJson[key];
    if (val != null) {
      pos[key.toString()] = num.tryParse(val.toString()) ?? (val as num? ?? 50.0);
    }
  }
  // Defaults si faltan keys estándar
  pos['x'] ??= 50.0;
  pos['y'] ??= 50.0;
  pos['width'] ??= 80.0;
  pos['height'] ??= 60.0;
  return pos;
}
