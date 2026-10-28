/// Implementación con Firebase (Auth + Firestore).
///
/// Usa exactamente las mismas rutas y campos que la versión web
/// (`src/services/*.ts`), de modo que un usuario ve los mismos datos en ambas
/// apps y las reglas de `firestore.rules` siguen aplicando sin cambios.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;

import '../../core/body/progress.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/score.dart';
import '../../core/strength/models.dart';
import '../repositories.dart';

AppUser? _toUser(fa.User? u) =>
    u == null ? null : AppUser(uid: u.uid, displayName: u.displayName, email: u.email, photoUrl: u.photoURL, isAnonymous: u.isAnonymous);

int _millis(Object? v) => v is Timestamp ? v.millisecondsSinceEpoch : (v is num ? v.toInt() : DateTime.now().millisecondsSinceEpoch);

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, {required this.method});

  final fa.FirebaseAuth _auth;

  @override
  final SignInMethod method;

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Stream<AppUser?> watchUser() => _auth.authStateChanges().map(_toUser);

  @override
  Future<void> signIn() async {
    if (method == SignInMethod.anonymous) {
      await _auth.signInAnonymously();
      return;
    }
    // Flujo web de Google dentro de la app (SFSafariViewController en iOS). Requiere
    // el esquema de URL de la app de iOS registrado en Info.plist (ver docs).
    await _auth.signInWithProvider(fa.GoogleAuthProvider());
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class FirestoreFoodRepository implements FoodRepository {
  FirestoreFoodRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('foods');

  static Food _toFood(String id, Map<String, dynamic> d) => Food(
        id: id,
        name: d['name'] as String? ?? '',
        aliases: (d['aliases'] as List? ?? const []).cast<String>(),
        brand: d['brand'] as String?,
        barcode: d['barcode'] as String?,
        per100g: Macros.fromMap(d['per100g']),
        portions: [for (final p in d['portions'] as List? ?? const []) Portion.fromMap((p as Map).cast<String, dynamic>())],
        density: (d['density'] as num?)?.toDouble(),
        source: FoodSource.fromMap(d['source']),
        verified: d['verified'] == true,
        createdBy: d['createdBy'] as String? ?? '',
        fiberMissing: d['per100g'] is! Map || !(d['per100g'] as Map).containsKey('fiber'),
      );

  @override
  Stream<List<Food>> watchFoods() => _col.snapshots().map((s) => [for (final d in s.docs) _toFood(d.id, d.data())]);

  @override
  Future<String> createFood(FoodInput input, String uid, FoodSource source) async {
    final ref = await _col.add({
      ...input.toMap(),
      'source': source.toMap(),
      'verified': false,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> updateFood(String id, FoodInput input) =>
      _col.doc(id).update({...input.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> importSeed({required List<Food> missing, required List<Food> fiberPatches}) async {
    final ops = [...missing.map((f) => (true, f)), ...fiberPatches.map((f) => (false, f))];
    // Firestore admite hasta 500 escrituras por lote.
    for (var i = 0; i < ops.length; i += 400) {
      final batch = _db.batch();
      for (final (add, food) in ops.skip(i).take(400)) {
        final ref = _col.doc(food.id);
        if (add) {
          batch.set(ref, {
            ...FoodInput(
              name: food.name,
              aliases: food.aliases,
              brand: food.brand,
              barcode: food.barcode,
              per100g: food.per100g,
              portions: food.portions,
              density: food.density,
            ).toMap(),
            'source': food.source.toMap(),
            'verified': food.verified,
            'createdBy': food.createdBy,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(ref, {'per100g.fiber': food.per100g.fiber, 'updatedAt': FieldValue.serverTimestamp()});
        }
      }
      await batch.commit();
    }
  }
}

class FirestoreRecipeRepository implements RecipeRepository {
  FirestoreRecipeRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('recipes');

  static Recipe _toRecipe(String id, Map<String, dynamic> d) => Recipe(
        id: id,
        ownerId: d['ownerId'] as String? ?? '',
        name: d['name'] as String? ?? '',
        aliases: (d['aliases'] as List? ?? const []).cast<String>(),
        servings: (d['servings'] as num?)?.toDouble() ?? 1,
        ingredients: [
          for (final i in d['ingredients'] as List? ?? const []) RecipeIngredient.fromMap((i as Map).cast<String, dynamic>()),
        ],
        totalGrams: (d['totalGrams'] as num?)?.toDouble() ?? 0,
        totals: Macros.fromMap(d['totals']),
        perServing: Macros.fromMap(d['perServing']),
      );

  @override
  Stream<List<Recipe>> watchRecipes(String uid) => _col
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((s) => [for (final d in s.docs) _toRecipe(d.id, d.data())]..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Future<String> saveRecipe(Recipe recipe, {String? id}) async {
    if (id != null) {
      await _col.doc(id).set({...recipe.toMap(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      return id;
    }
    final ref = await _col.add({...recipe.toMap(), 'visibility': 'PRIVATE', 'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  @override
  Future<void> deleteRecipe(String id) => _col.doc(id).delete();
}

class FirestoreDiaryRepository implements DiaryRepository {
  FirestoreDiaryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _entries(String uid, String date) =>
      _db.collection('users').doc(uid).collection('days').doc(date).collection('entries');

  @override
  Stream<List<DiaryEntry>> watchDay(String uid, String date) => _entries(uid, date).snapshots().map((s) {
        final rows = [
          for (final d in s.docs)
            (
              DiaryEntry(
                id: d.id,
                kind: d.data()['kind'] == 'recipe' ? EntryKind.recipe : EntryKind.food,
                refId: d.data()['refId'] as String? ?? '',
                name: d.data()['name'] as String? ?? '',
                grams: (d.data()['grams'] as num?)?.toDouble() ?? 0,
                servings: (d.data()['servings'] as num?)?.toDouble(),
                macros: Macros.fromMap(d.data()['macros']),
                meal: MealSlot.values.where((m) => m.name == d.data()['meal']).firstOrNull ?? MealSlot.snack,
                rawInput: d.data()['rawInput'] as String?,
                // Mientras la escritura está pendiente, el servidor aún no fija la hora.
                createdAt: _millis(d.data()['createdAt']),
              ),
              (d.data()['position'] as num?)?.toInt() ?? 0,
            ),
        ];
        rows.sort((a, b) {
          final byTime = a.$1.createdAt.compareTo(b.$1.createdAt);
          return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
        });
        return [for (final r in rows) r.$1];
      });

  @override
  Future<void> addEntries(String uid, String date, List<NewDiaryEntry> entries) async {
    final batch = _db.batch();
    // Las entradas de un mismo lote comparten createdAt; `position` conserva el orden de la lista.
    for (var i = 0; i < entries.length; i++) {
      batch.set(_entries(uid, date).doc(), {...entries[i].toMap(), 'position': i, 'createdAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteEntry(String uid, String date, String id) => _entries(uid, date).doc(id).delete();
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _weights(String uid) => _user(uid).collection('weights');

  @override
  Stream<Goals> watchGoals(String uid) => _user(uid).snapshots().map((s) => goalsFromMap(s.data()?['goals']));

  @override
  Future<void> saveGoals(String uid, Goals goals) =>
      _user(uid).set({'goals': goals.toMap(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  @override
  Stream<BodyGoal?> watchBodyGoal(String uid) => _user(uid).snapshots().map((s) => BodyGoal.fromMap(s.data()?['bodyGoal']));

  @override
  Future<void> saveBodyGoal(String uid, BodyGoal goal) =>
      _user(uid).set({'bodyGoal': goal.toMap(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  @override
  Stream<List<WeightEntry>> watchWeights(String uid) => _weights(uid).snapshots().map(
        (s) => sortByDate([for (final d in s.docs) WeightEntry(date: d.id, kg: (d.data()['kg'] as num?)?.toDouble() ?? 0)]),
      );

  @override
  Future<void> saveWeight(String uid, WeightEntry entry) =>
      _weights(uid).doc(entry.date).set({'kg': entry.kg, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> deleteWeight(String uid, String date) => _weights(uid).doc(date).delete();
}

class FirestoreStrengthRepository implements StrengthRepository {
  FirestoreStrengthRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) => _db.collection('users').doc(uid).collection(name);

  static List<WorkoutExercise> _workoutExercises(Object? data) => [
        for (final e in data is List ? data : const [])
          WorkoutExercise(exerciseId: (e as Map)['exerciseId'] as String? ?? '', name: e['name'] as String? ?? '', sets: setsFrom(e['sets'])),
      ];

  @override
  Stream<List<Routine>> watchRoutines(String uid) => _col(uid, 'routines').snapshots().map((s) => [
        for (final d in s.docs)
          Routine(
            id: d.id,
            name: d.data()['name'] as String? ?? '',
            exercises: [
              for (final e in d.data()['exercises'] as List? ?? const [])
                RoutineExercise(exerciseId: (e as Map)['exerciseId'] as String? ?? '', sets: setsFrom(e['sets'])),
            ],
            updatedAt: d.data()['updatedAt'] is Timestamp ? (d.data()['updatedAt'] as Timestamp).millisecondsSinceEpoch : 0,
          ),
      ]..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Future<String> saveRoutine(String uid, {required String name, required List<RoutineExercise> exercises, String? id}) async {
    final data = {'name': name, 'exercises': exercises.map((e) => e.toMap()).toList(), 'updatedAt': FieldValue.serverTimestamp()};
    if (id != null) {
      await _col(uid, 'routines').doc(id).set(data, SetOptions(merge: true));
      return id;
    }
    return (await _col(uid, 'routines').add({...data, 'createdAt': FieldValue.serverTimestamp()})).id;
  }

  @override
  Future<void> deleteRoutine(String uid, String id) => _col(uid, 'routines').doc(id).delete();

  @override
  Stream<List<Workout>> watchWorkouts(String uid) => _col(uid, 'workouts').snapshots().map((s) => [
        for (final d in s.docs)
          Workout(
            id: d.id,
            routineId: d.data()['routineId'] as String?,
            name: d.data()['name'] as String? ?? 'Entrenamiento',
            date: d.data()['date'] as String? ?? '',
            startedAt: _millis(d.data()['startedAt']),
            finishedAt: _millis(d.data()['finishedAt']),
            exercises: _workoutExercises(d.data()['exercises']),
          ),
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt)));

  @override
  Future<String> saveWorkout(String uid, NewWorkout workout) async =>
      (await _col(uid, 'workouts').add({...workout.toMap(), 'createdAt': FieldValue.serverTimestamp()})).id;

  @override
  Future<void> deleteWorkout(String uid, String id) => _col(uid, 'workouts').doc(id).delete();

  @override
  Stream<List<Exercise>> watchCustomExercises(String uid) => _col(uid, 'exercises').snapshots().map((s) => [
        for (final d in s.docs)
          Exercise(
            id: '$customExercisePrefix${d.id}',
            name: d.data()['name'] as String? ?? '',
            equipment: d.data()['equipment'] as String?,
            primary: (d.data()['primary'] as List? ?? const []).cast<String>(),
            custom: true,
          ),
      ]);

  @override
  Future<Exercise> createCustomExercise(String uid, {required String name, String? equipment, required List<String> primary}) async {
    final ref = await _col(uid, 'exercises').add({
      'name': name,
      'equipment': equipment,
      'primary': primary,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return Exercise(id: '$customExercisePrefix${ref.id}', name: name, equipment: equipment, primary: primary, custom: true);
  }
}
