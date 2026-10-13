class ScheduleSubjectOption {
  const ScheduleSubjectOption({
    required this.id,
    required this.value,
    required this.arabicLabel,
    required this.sortOrder,
    this.isBuiltIn = false,
  });

  final String id;
  final String value;
  final String arabicLabel;
  final int sortOrder;
  final bool isBuiltIn;

  factory ScheduleSubjectOption.fromMap(Map<String, dynamic> map) {
    return ScheduleSubjectOption(
      id: (map['id'] ?? '').toString(),
      value: (map['value'] ?? '').toString(),
      arabicLabel: (map['arabicLabel'] ?? '').toString(),
      sortOrder: (map['sortOrder'] is int)
          ? map['sortOrder'] as int
          : int.tryParse('${map['sortOrder']}') ?? 0,
      isBuiltIn: map['isBuiltIn'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'value': value,
      'arabicLabel': arabicLabel,
      'sortOrder': sortOrder,
      'isBuiltIn': isBuiltIn,
    };
  }
}
