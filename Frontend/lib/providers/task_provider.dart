import '../core/models/task_step.dart';
import 'package:flutter/foundation.dart';
import '../core/models/task.dart';
import '../core/models/live_update.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';

class TaskProvider with ChangeNotifier {
  final ApiService _apiService;
  FirebaseService? _firebaseService;
  
  List<Task> _tasks = [];
  List<LiveUpdate> _liveUpdates = [];
  bool _isLoading = false;
  String? _error;
  bool _useFirebase = false;

  // Constructor compatible with your existing main.dart
  TaskProvider({
    required ApiService apiService,
    FirebaseService? firebaseService,
    bool useFirebase = false,
  })  : _apiService = apiService,
        _firebaseService = firebaseService,
        _useFirebase = useFirebase;

  // Getters
  List<Task> get tasks => _tasks;
  List<Task> get activeTasks => _tasks.where((t) => t.status == TaskStatus.running).toList();
  List<Task> get completedTasks => _tasks.where((t) => t.status == TaskStatus.completed).toList();
  List<Task> get pendingTasks => _tasks.where((t) => t.status == TaskStatus.pending).toList();
  List<LiveUpdate> get liveUpdates => _liveUpdates;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get activeTaskCount => activeTasks.length;

  // Enable Firebase mode
  void enableFirebase(FirebaseService firebaseService) {
    _firebaseService = firebaseService;
    _useFirebase = true;
    fetchTasks(); // Reload tasks from Firebase
  }

  // Get task by ID
  Task? getTaskById(String id) {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  // Fetch all tasks (works with both API and Firebase)
  Future<void> fetchTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = _firebaseService;
      if (_useFirebase && service != null) {
        // Use Firebase
        _tasks = await service.getUserTasks();
      } else {
        // Use API
        _tasks = await _apiService.getTasks();
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

  // Fetch single task
  Future<void> fetchTask(String taskId) async {
    try {
      Task task;
      final service = _firebaseService;
      if (_useFirebase && service != null) {
        task = await service.getTask(taskId);
      } else {
        task = await _apiService.getTask(taskId);
      }
      
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = task;
      } else {
        _tasks.add(task);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching task: $e');
      notifyListeners();
    }
  }

  // Create new task (works with both API and Firebase)
  Future<Task?> createTask({
    String? id,
    required String title,
    required String description,
    required TaskPriority priority,
    List<String>? steps,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Task newTask;
      
      final List<TaskStep> taskSteps = steps?.asMap().entries.map((entry) {
            int idx = entry.key;
            String val = entry.value;
            return TaskStep(
              id: '${id ?? DateTime.now().millisecondsSinceEpoch}_$idx',
              name: 'Step ${idx + 1}',
              description: val,
              status: StepStatus.pending,
              order: idx,
            );
          }).toList() ?? [];

      final service = _firebaseService;
      if (_useFirebase && service != null) {
        // Create task object for Firebase
        final taskToCreate = Task(
          id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: description,
          priority: priority,
          status: TaskStatus.pending,
          steps: taskSteps,
          currentStep: 0,
          totalSteps: taskSteps.length,
          createdAt: DateTime.now(),
          startTime: null,
          endTime: null,
        );
        
        final taskId = await service.createTask(taskToCreate);
        newTask = taskToCreate.copyWith(id: taskId);
      } else {
        // Use API
        newTask = await _apiService.createTask(
          title: title,
          description: description,
          priority: priority,
        );
      }
      
      _tasks.insert(0, newTask);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return newTask;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('Error creating task: $e');
      notifyListeners();
      return null;
    }
  }

  // Stop task
  Future<void> stopTask(String taskId) async {
    try {
      final service = _firebaseService;
      if (_useFirebase && service != null) {
        await service.updateTask(taskId, {
          'status': TaskStatus.completed.toString().split('.').last,
          'endTime': DateTime.now().toIso8601String(),
        });
        await fetchTask(taskId);
      } else {
        final updatedTask = await _apiService.stopTask(taskId);
        _updateTask(updatedTask);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error stopping task: $e');
      notifyListeners();
    }
  }

  // Pause task
  Future<void> pauseTask(String taskId) async {
    try {
      final service = _firebaseService;
      if (_useFirebase && service != null) {
        await service.updateTask(taskId, {
          'status': TaskStatus.pending.toString().split('.').last,
        });
        await fetchTask(taskId);
      } else {
        final updatedTask = await _apiService.pauseTask(taskId);
        _updateTask(updatedTask);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error pausing task: $e');
      notifyListeners();
    }
  }

  // Resume task
  Future<void> resumeTask(String taskId) async {
    try {
      final service = _firebaseService;
      if (_useFirebase && service != null) {
        await service.updateTask(taskId, {
          'status': TaskStatus.running.toString().split('.').last,
          'startTime': DateTime.now().toIso8601String(),
        });
        await fetchTask(taskId);
      } else {
        final updatedTask = await _apiService.resumeTask(taskId);
        _updateTask(updatedTask);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error resuming task: $e');
      notifyListeners();
    }
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    try {
      final service = _firebaseService;
      if (_useFirebase && service != null) {
        await service.deleteTask(taskId);
      } else {
        await _apiService.deleteTask(taskId);
      }
      _tasks.removeWhere((task) => task.id == taskId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting task: $e');
      notifyListeners();
    }
  }

  // Update task in list
  void _updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  // Add live update
  void addLiveUpdate(LiveUpdate update) {
    _liveUpdates.insert(0, update);
    
    // Keep only last 50 updates
    if (_liveUpdates.length > 50) {
      _liveUpdates = _liveUpdates.take(50).toList();
    }
    notifyListeners();
  }

  // Clear live updates
  void clearLiveUpdates() {
    _liveUpdates.clear();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh tasks (pull to refresh)
  Future<void> refreshTasks() async {
    await fetchTasks();
  }
}