import 'yarn.dart';

class RavelryYarnCatalogItem {
  const RavelryYarnCatalogItem({
    required this.id,
    required this.name,
    required this.brandName,
    this.permalink,
    this.weightName,
    this.fiberContent,
    this.fiberContents = const [],
    this.yardage,
    this.unitWeightGrams,
    this.needleSize,
    this.gauge,
    this.imageUrl,
  });

  final int? id;
  final String name;
  final String brandName;
  final String? permalink;
  final String? weightName;
  final String? fiberContent;
  final List<YarnFiberContent> fiberContents;
  final int? yardage;
  final int? unitWeightGrams;
  final String? needleSize;
  final String? gauge;
  final String? imageUrl;

  String get catalogKey {
    return id?.toString() ?? '$brandName/$name/$permalink';
  }

  List<String> get chips {
    return [
      ?_clean(weightName),
      ?_clean(
        fiberContent ??
            (fiberContents.isEmpty
                ? null
                : yarnFiberContentSummary(fiberContents)),
      ),
    ];
  }

  factory RavelryYarnCatalogItem.fromJson(Map<String, dynamic> json) {
    final fibers = _fiberContentsFromJson(json);
    final fiberSummary =
        _string(json['fiber_content']) ??
        _string(json['fiber_content_summary']) ??
        _string(json['fiber_contents']) ??
        (fibers.isEmpty ? null : yarnFiberContentSummary(fibers));

    return RavelryYarnCatalogItem(
      id: _int(json['id']),
      name: _string(json['name']) ?? 'Unknown yarn',
      brandName:
          _string(json['yarn_company_name']) ??
          _nestedString(json['yarn_company'], 'name') ??
          _string(json['company_name']) ??
          'Unknown brand',
      permalink: _string(json['permalink']),
      weightName:
          _string(json['yarn_weight_name']) ??
          _nestedString(json['yarn_weight'], 'name') ??
          _string(json['weight_name']),
      fiberContent: fiberSummary,
      fiberContents: fibers,
      yardage:
          _int(json['yardage']) ??
          _int(json['max_yardage']) ??
          _int(json['min_yardage']),
      unitWeightGrams:
          _int(json['grams']) ??
          _int(json['yarn_weight_grams']) ??
          _int(json['skein_weight_grams']),
      needleSize:
      _string(json['needle_size']) ??
          _string(json['needle_sizes']) ??
          _needleSizeSummary(json['needle_sizes']) ??
          _needleSizeSummary(json['needles']) ??
          _needleSizeRange(json),
      gauge: _string(json['gauge']) ??
          _string(json['gauge_description']) ??
          _gaugeSummary(json),
      imageUrl:
          _photoUrl(json['first_photo']) ??
          _photoUrl(_firstListItem(json['photos'])),
    );
  }
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? _string(Object? value) {
  if (value == null) return null;
  if (value is String) return _clean(value);
  if (value is num || value is bool) return value.toString();
  return null;
}

String? _nestedString(Object? value, String key) {
  if (value is! Map) return null;
  return _string(value[key]);
}

int? _int(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

Object? _firstListItem(Object? value) {
  if (value is List && value.isNotEmpty) return value.first;
  return null;
}

String? _photoUrl(Object? value) {
  if (value is! Map) return null;
  return _string(value['medium_url']) ??
      _string(value['small_url']) ??
      _string(value['square_url']) ??
      _string(value['thumbnail_url']);
}

String? _needleSizeSummary(Object? value) {
  if (value is! List || value.isEmpty) return null;

  final labels = [
    for (final needleSize in value)
      if (needleSize is Map)
        ?_string(needleSize['name']) ??
            _string(needleSize['us']) ??
            _string(needleSize['metric']),
  ];
  return labels.isEmpty ? null : labels.join(', ');
}

String? _needleSizeRange(Map<dynamic, dynamic> json) {
  final minNeedle =
      _needleSizeLabel(json['min_needle_size']) ??
          _needleSizeLabel(json['min_needle']);

  final maxNeedle =
      _needleSizeLabel(json['max_needle_size']) ??
          _needleSizeLabel(json['max_needle']);

  if (minNeedle != null && maxNeedle != null) {
    if (minNeedle == maxNeedle) return minNeedle;
    return '$minNeedle - $maxNeedle';
  }

  return minNeedle ?? maxNeedle;
}

String? _needleSizeLabel(Object? value) {
  if (value == null) return null;

  if (value is String || value is num || value is bool) {
    return _string(value);
  }

  if (value is Map) {
    return _string(value['name']) ??
        _string(value['us']) ??
        _string(value['metric']) ??
        _string(value['pretty_name']) ??
        _string(value['description']);
  }

  return null;
}

String? _gaugeSummary(Map<dynamic, dynamic> json) {
  final gauge = _string(json['gauge']);
  final divisor = _string(json['gauge_divisor']);

  if (gauge != null && divisor != null) {
    return '$gauge sts / $divisor';
  }

  final stitchGauge =
      _int(json['gauge_stitches']) ??
          _int(json['stitch_gauge']) ??
          _int(json['stitches_per_4_inches']);

  final rowGauge =
      _int(json['gauge_rows']) ??
          _int(json['row_gauge']);

  if (stitchGauge != null && rowGauge != null) {
    return '$stitchGauge sts / $rowGauge rows';
  }

  if (stitchGauge != null) {
    return '$stitchGauge sts';
  }

  if (rowGauge != null) {
    return '$rowGauge rows';
  }

  return null;
}

List<YarnFiberContent> _fiberContentsFromJson(Map<dynamic, dynamic> json) {
  final rawFibers =
      json['fibers'] ??
          json['fiber_contents'] ??
          json['yarn_fibers'] ??
          json['fiber_types'];

  if (rawFibers is List) {
    return rawFibers
        .whereType<Map>()
        .map((fiber) {
      final fiberName =
          _string(fiber['name']) ??
              _string(fiber['fiber']) ??
              _string(fiber['fiber_name']) ??
              _nestedString(fiber['fiber'], 'name') ??
              _nestedString(fiber['fiber_type'], 'name') ??
              _nestedString(fiber['type'], 'name');

      return YarnFiberContent(
        fiber: fiberName ?? '',
        percentage:
        _int(fiber['percentage']) ??
            _int(fiber['percent']) ??
            _int(fiber['value']) ??
            _int(fiber['amount']) ??
            0,
      );
    })
        .where((fiber) => fiber.fiber.trim().isNotEmpty && fiber.percentage > 0)
        .toList(growable: false);
  }

  final summary =
      _string(json['fiber_content']) ??
          _string(json['fiber_content_summary']) ??
          _string(json['fiber_contents']) ??
          _string(json['fiber']);

  if (summary == null) return const [];

  final fibers = <YarnFiberContent>[];

  for (final part in summary.split(',')) {
    final match = RegExp(r'^\s*(\d+)\s*%\s*(.+?)\s*$').firstMatch(part);
    if (match == null) continue;

    fibers.add(
      YarnFiberContent(
        fiber: match.group(2)!,
        percentage: int.tryParse(match.group(1)!) ?? 0,
      ),
    );
  }

  return fibers;
}