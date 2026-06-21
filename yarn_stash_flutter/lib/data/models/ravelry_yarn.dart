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
          _needleSizeSummary(json['needle_sizes']),
      gauge: _string(json['gauge']),
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

List<YarnFiberContent> _fiberContentsFromJson(Map<String, dynamic> json) {
  final rawFibers = json['fibers'];
  if (rawFibers is List) {
    return rawFibers
        .whereType<Map>()
        .map((fiber) {
          return YarnFiberContent(
            fiber: _string(fiber['name']) ?? '',
            percentage:
                _int(fiber['percentage']) ??
                _int(fiber['percent']) ??
                _int(fiber['value']) ??
                0,
          );
        })
        .where((fiber) => fiber.fiber.trim().isNotEmpty && fiber.percentage > 0)
        .toList(growable: false);
  }

  final summary =
      _string(json['fiber_content']) ?? _string(json['fiber_content_summary']);
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
