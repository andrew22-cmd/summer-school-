import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:summerschool/models/schedule_subject_model.dart';

class ScheduleSubjectService {
  ScheduleSubjectService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _subjectsCollection =>
      _firestore.collection('schedule_subjects');

  static const List<ScheduleSubjectOption> defaultSubjects = [
    ScheduleSubjectOption(
      id: 'bible',
      value: 'Bible',
      arabicLabel: 'الكتاب المقدس',
      sortOrder: 0,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'development',
      value: 'Development',
      arabicLabel: 'التطوير',
      sortOrder: 1,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'talk_about_god',
      value: 'Talk About God',
      arabicLabel: 'التحدث عن الله',
      sortOrder: 2,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'rites',
      value: 'Rites',
      arabicLabel: 'الطقوس',
      sortOrder: 3,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'stay_aware',
      value: 'Stay Aware',
      arabicLabel: 'كن متيقظًا',
      sortOrder: 4,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'discoveries',
      value: 'Discoveries',
      arabicLabel: 'اكتشافات',
      sortOrder: 5,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'doctrine',
      value: 'Doctrine',
      arabicLabel: 'العقيدة',
      sortOrder: 6,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'coptic_and_hymns',
      value: 'Coptic and Hymns',
      arabicLabel: 'القبطي والألحان',
      sortOrder: 7,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'role_model',
      value: 'Role Model',
      arabicLabel: 'قدوة',
      sortOrder: 8,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'first_aid',
      value: 'First Aid',
      arabicLabel: 'الإسعافات الأولية',
      sortOrder: 9,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'your_health',
      value: 'Your Health',
      arabicLabel: 'صحتك',
      sortOrder: 10,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'learn_from_nature',
      value: 'Learn from Nature',
      arabicLabel: 'تعلم من الطبيعة',
      sortOrder: 11,
      isBuiltIn: true,
    ),
    ScheduleSubjectOption(
      id: 'other',
      value: 'Other',
      arabicLabel: 'أخرى',
      sortOrder: 12,
      isBuiltIn: true,
    ),
  ];

  Future<void> ensureDefaults() async {
    final snapshot = await _subjectsCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (var i = 0; i < defaultSubjects.length; i++) {
      final subject = defaultSubjects[i];
      final doc = _subjectsCollection.doc(subject.id);
      batch.set(doc, {...subject.toMap(), 'sortOrder': i});
    }

    await batch.commit();
  }

  Stream<List<ScheduleSubjectOption>> watchSubjects() {
    return _subjectsCollection
        .orderBy('sortOrder', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduleSubjectOption.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<List<ScheduleSubjectOption>> getSubjects() async {
    final snapshot = await _subjectsCollection
        .orderBy('sortOrder', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => ScheduleSubjectOption.fromMap(doc.data()))
        .toList();
  }

  Future<void> addSubject({
    required String englishLabel,
    required String arabicLabel,
  }) async {
    final cleanEnglish = englishLabel.trim();
    final cleanArabic = arabicLabel.trim();

    if (cleanEnglish.isEmpty || cleanArabic.isEmpty) {
      throw Exception('English and Arabic names are required.');
    }

    final existing = await _subjectsCollection.get();
    final duplicate = existing.docs.any(
      (doc) =>
          (doc.data()['value'] ?? '').toString().trim().toLowerCase() ==
              cleanEnglish.toLowerCase() ||
          (doc.data()['arabicLabel'] ?? '').toString().trim().toLowerCase() ==
              cleanArabic.toLowerCase(),
    );

    if (duplicate) {
      throw Exception('This subject already exists.');
    }

    final newId = _slugify(cleanEnglish);
    await _subjectsCollection.doc(newId).set({
      'id': newId,
      'value': cleanEnglish,
      'arabicLabel': cleanArabic,
      'sortOrder': existing.docs.length,
      'isBuiltIn': false,
    });
  }

  Future<void> deleteSubject(String id) async {
    final doc = _subjectsCollection.doc(id);
    await doc.delete();
  }

  String _slugify(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty
        ? 'subject_${DateTime.now().millisecondsSinceEpoch}'
        : normalized;
  }
}
