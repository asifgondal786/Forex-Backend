import 'package:flutter/foundation.dart';
import '../core/models/task.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';

class TaskProvider with ChangeNotifier {
  final ApiService apiService;
  final FirebaseService? firebaseService;
  final bool useFirebase;

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  TaskProvider({
    required this.apiService,
    this.firebaseService,
    this.useFirebase = false,
  });

  // Getters
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<Task> get activeTasks => _tasks.where((task) => 
    task.status == TaskStatus.running || 
    task.status == TaskStatus.pending ||
    task.status == TaskStatus.paused
  ).toList();
  
  List<Task> get completedTasks => _tasks.where((task) => 
    task.status == TaskStatus.completed
  ).toList();

  // Get task by ID
  Task? getTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  // Set tasks (used by mock data helper)
  void setTasks(List<Task> tasks) {
    _tasks = tasks;
    notifyListeners();
  }

  // Fetch all tasks
  Future<void> fetchTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (useFirebase && firebaseService != null) {
        _tasks = await firebaseService!.getTasks();
      } else {
        _tasks = await apiService.getTasks();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new task
  Future<Task?> createTask({
    required String title,
    required String description,
    required TaskPriority priority,
  }) async {
    try {
      Task newTask;
      
      if (useFirebase && firebaseService != null) {
        newTask = await firebaseService!.createTask(
          title: title,
          description: description,
          priority: priority,
        );
      } else {
        newTask = await apiService.createTask(
          title: title,
          description: description,
          priority: priority,
        );
      }

      _tasks.insert(0, newTask);
      notifyListeners();
      return newTask;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creating task: $e');
      notifyListeners();
      return null;
    }
  }

  // Update task status
  Future<void> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    try {
      final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) return;

      final updatedTask = _tasks[taskIndex].copyWith(status: newStatus);
      
      if (useFirebase && firebaseService != null) {
        await firebaseService!.updateTask(taskId, updatedTask);
      }
      
      _tasks[taskIndex] = updatedTask;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating task status: $e');
      notifyListeners();
    }
  }

  // Stop a running task
  Future<void> stopTask(String taskId) async {
    try {
      Task stoppedTask;
      
      if (useFirebase && firebaseService != null) {
        final task = getTaskById(taskId);
        if (task == null) return;
        
        stoppedTask = task.copyWith(
          status: TaskStatus.paused,
          endTime: DateTime.now(),
        );
        await firebaseService!.updateTask(taskId, stoppedTask);
      } else {
        stoppedTask = await apiService.stopTask(taskId);
      }

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = stoppedTask;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error stopping task: $e');
      notifyListeners();
    }
  }

  // Pause a task
  Future<void> pauseTask(String taskId) async {
    try {
      Task pausedTask;
      
      if (useFirebase && firebaseService != null) {
        final task = getTaskById(taskId);
        if (task == null) return;
        
        pausedTask = task.copyWith(status: TaskStatus.paused);
        await firebaseService!.updateTask(taskId, pausedTask);
      } else {
        pausedTask = await apiService.pauseTask(taskId);
      }

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = pausedTask;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error pausing task: $e');
      notifyListeners();
    }
  }

  // Resume a paused task
  Future<void> resumeTask(String taskId) async {
    try {
      Task resumedTask;
      
      if (useFirebase && firebaseService != null) {
        final task = getTaskById(taskId);
        if (task == null) return;
        
        resumedTask = task.copyWith(status: TaskStatus.running);
        await firebaseService!.updateTask(taskId, resumedTask);
      } else {
        resumedTask = await apiService.resumeTask(taskId);
      }

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = resumedTask;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error resuming task: $e');
      notifyListeners();
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      if (useFirebase && firebaseService != null) {
        await firebaseService!.deleteTask(taskId);
      } else {
        await apiService.deleteTask(taskId);
      }

      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting task: $e');
      notifyListeners();
    }
  }

  // Update task with real-time data (from WebSocket or Firebase listener)
  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    } else {
      _tasks.insert(0, updatedTask);
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}