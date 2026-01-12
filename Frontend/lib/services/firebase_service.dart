import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:flutter/foundation.dart';
import '../core/models/user.dart' as app_user;
import '../core/models/task.dart' as task_model;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final storage.FirebaseStorage _storage = storage.FirebaseStorage.instance;

  // Get current Firebase Auth user
  firebase_auth.User? get currentFirebaseUser => _auth.currentUser;

  // Get current app user
  Future<app_user.User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        return app_user.User.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting current user: $e');
      }
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating user profile: $e');
      }
      throw Exception('Failed to update profile');
    }
  }

  // Create user document
  Future<void> createUserDocument(app_user.User user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toJson());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating user document: $e');
      }
      throw Exception('Failed to create user');
    }
  }

  // Get user by ID
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return app_user.User.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting user: $e');
      }
      return null;
    }
  }

  // Sign in with email and password
  Future<firebase_auth.User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error signing in: $e');
      }
      return null;
    }
  }

  // Sign up with email and password
  Future<firebase_auth.User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error signing up: $e');
      }
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error signing out: $e');
      }
      throw Exception('Failed to sign out');
    }
  }

  // Upload file to Firebase Storage
  Future<String?> uploadFile(String path, List<int> data) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putData(Uint8List.fromList(data));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error uploading file: $e');
      }
      return null;
    }
  }

  // Delete file from Firebase Storage
  Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting file: $e');
      }
      throw Exception('Failed to delete file');
    }
  }

  // --- Task Methods ---

  /// Fetches all tasks for a specific user.
  Future<List<task_model.Task>> getUserTasks() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return []; // Not logged in, return empty list
      }
      final snapshot = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => task_model.Task.fromFirestore(doc.data(), doc.id)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting user tasks: $e');
      }
      throw Exception('Failed to fetch tasks.');
    }
  }

  /// Fetches a single task by its ID.
  Future<task_model.Task> getTask(String taskId) async {
    try {
      final doc = await _firestore.collection('tasks').doc(taskId).get();
      if (doc.exists) {
        return task_model.Task.fromFirestore(doc.data()!, doc.id);
      }
      throw Exception('Task not found');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting task: $e');
      }
      throw Exception('Failed to fetch task.');
    }
  }

  /// Creates a new task in Firestore and returns its ID.
  Future<String> createTask(task_model.Task task) async {
    try {
      final docRef = await _firestore.collection('tasks').add(task.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating task: $e');
      }
      throw Exception('Failed to create task.');
    }
  }

  /// Updates an existing task in Firestore.
  Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating task: $e');
      }
      throw Exception('Failed to update task.');
    }
  }

  /// Deletes a task from Firestore.
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting task: $e');
      }
      throw Exception('Failed to delete task.');
    }
  }

  /// Provides a stream for real-time updates on a single task.
  Stream<task_model.Task> listenToTask(String taskId) {
    return _firestore.collection('tasks').doc(taskId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return task_model.Task.fromFirestore(snapshot.data()!, snapshot.id);
      }
      throw Exception('Task not found for live update.');
    });
  }
}