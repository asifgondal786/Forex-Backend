import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/models/task.dart' as task_model;
import '../core/models/user.dart' as app_user;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collections
  static const String tasksCollection = 'tasks';
  static const String usersCollection = 'users';
  static const String updatesCollection = 'live_updates';

  // ==================== AUTH ====================

  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      throw Exception('Anonymous sign-in failed: $e');
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  Future<User?> signUpWithEmail(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        await createUserProfile(userCredential.user!.uid, name, email);
      }
      
      return userCredential.user;
    } catch (e) {
      throw Exception('Sign-up failed: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== USER PROFILE ====================

  Future<void> createUserProfile(String uid, String name, String email) async {
    try {
      final userProfile = app_user.User(
        id: uid,
        name: name,
        email: email,
        currentPlan: 'Free',
        tasksCompleted: 0,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(usersCollection)
          .doc(uid)
          .set(userProfile.toJson());
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  Future<app_user.User?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(uid).get();
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // ==================== TASKS ====================

  Future<String> createTask(Task task) async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final taskData = task.toJson();
      taskData['userId'] = uid;
      taskData['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.collection(tasksCollection).add(taskData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(tasksCollection).doc(taskId).update(updates);
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection(tasksCollection).doc(taskId).delete();
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }

  Future<Task?> getTask(String taskId) async {
    try {
      final doc = await _firestore.collection(tasksCollection).doc(taskId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return Task.fromJson(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get task: $e');
    }
  }

  Stream<List<Task>> getUserTasksStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection(tasksCollection)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Task.fromJson(data);
      }).toList();
    });
  }

  Future<List<Task>> getUserTasks({TaskStatus? status}) async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      Query query = _firestore
          .collection(tasksCollection)
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status.toString().split('.').last);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Task.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get tasks: $e');
    }
  }

  // ==================== LIVE UPDATES ====================

  Future<void> addLiveUpdate(String taskId, String message) async {
    try {
      await _firestore
          .collection(tasksCollection)
          .doc(taskId)
          .collection(updatesCollection)
          .add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add live update: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getLiveUpdatesStream(String taskId) {
    return _firestore
        .collection(tasksCollection)
        .doc(taskId)
        .collection(updatesCollection)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}