import '../core/models/task.dart';
import '../core/models/user.dart';
import '../core/models/header_model.dart';
import '../providers/task_provider.dart';

class MockDataHelper {
  /// Generates a mock user for testing
  static User generateMockUser() {
    return User(
      id: 'mock_user_1',
      email: 'sohaib@forexcompanion.com',
      name: 'Sohaib',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  /// Generates mock header data
  static HeaderData generateMockHeader() {
    return HeaderData(
      user: HeaderUser(
        id: 'mock_user_1',
        name: 'John Doe',
        status: 'Available Online',
        avatarUrl: null,
        riskLevel: 'Moderate',
      ),
      balance: HeaderBalance(
        amount: 5843.21,
        currency: 'USD',
      ),
      notifications: HeaderNotifications(unread: 2),
    );
  }

  /// Generates mock tasks for testing
  static List<Task> generateMockTasks() {
    return [
      Task(
        id: 'task_1',
        userId: 'mock_user_1',
        title: 'Forex Market Summary for Today',
        description: 'Generate a comprehensive market analysis for major currency pairs',
        status: TaskStatus.running,
        priority: TaskPriority.medium,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        currentStep: 3,
        totalSteps: 4,
        steps: [
          TaskStep(
            name: 'Research Data',
            isCompleted: true,
            completedAt: DateTime.now().subtract(const Duration(minutes: 60)),
          ),
          TaskStep(
            name: 'Analyze Trends',
            isCompleted: true,
            completedAt: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          TaskStep(
            name: 'Generate Summary',
            isCompleted: true,
            completedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
          TaskStep(
            name: 'Finalize Report',
            isCompleted: false,
          ),
        ],
        resultFileUrl: 'https://example.com/forex_market_summary_today.pdf',
        resultFileName: 'forex_market_summary_today.pdf',
        resultFileSize: 52000, // 52 KB
      ),
      Task(
        id: 'task_2',
        userId: 'mock_user_1',
        title: 'Automate Daily Forex Report',
        description: 'Create an automated system for daily forex market reports',
        status: TaskStatus.completed,
        priority: TaskPriority.high,
        createdAt: DateTime.parse('2024-04-23T10:00:00'),
        startTime: DateTime.parse('2024-04-23T10:15:00'),
        endTime: DateTime.parse('2024-04-23T14:45:00'),
        currentStep: 5,
        totalSteps: 5,
        steps: [
          TaskStep(
            name: 'Setup automation framework',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-23T11:00:00'),
          ),
          TaskStep(
            name: 'Configure data sources',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-23T12:00:00'),
          ),
          TaskStep(
            name: 'Build report template',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-23T13:00:00'),
          ),
          TaskStep(
            name: 'Test automation',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-23T14:00:00'),
          ),
          TaskStep(
            name: 'Deploy system',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-23T14:45:00'),
          ),
        ],
        resultFileUrl: 'https://example.com/automation_setup.pdf',
        resultFileName: 'automation_setup.pdf',
        resultFileSize: 128000, // 128 KB
      ),
      Task(
        id: 'task_3',
        userId: 'mock_user_1',
        title: 'Generate Forex Trade Ideas',
        description: 'Analyze market conditions and generate potential trading opportunities',
        status: TaskStatus.completed,
        priority: TaskPriority.medium,
        createdAt: DateTime.parse('2024-04-22T09:00:00'),
        startTime: DateTime.parse('2024-04-22T09:30:00'),
        endTime: DateTime.parse('2024-04-22T15:12:00'),
        currentStep: 4,
        totalSteps: 4,
        steps: [
          TaskStep(
            name: 'Collect market data',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-22T10:30:00'),
          ),
          TaskStep(
            name: 'Run technical analysis',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-22T12:00:00'),
          ),
          TaskStep(
            name: 'Identify opportunities',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-22T14:00:00'),
          ),
          TaskStep(
            name: 'Generate trade ideas',
            isCompleted: true,
            completedAt: DateTime.parse('2024-04-22T15:12:00'),
          ),
        ],
        resultFileUrl: 'https://example.com/trade_ideas.pdf',
        resultFileName: 'trade_ideas.pdf',
        resultFileSize: 89000, // 89 KB
      ),
      Task(
        id: 'task_4',
        userId: 'mock_user_1',
        title: 'Weekly Market Analysis',
        description: 'Comprehensive weekly analysis of forex market trends',
        status: TaskStatus.pending,
        priority: TaskPriority.low,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        currentStep: 0,
        totalSteps: 6,
        steps: [
          TaskStep(name: 'Gather weekly data', isCompleted: false),
          TaskStep(name: 'Analyze major pairs', isCompleted: false),
          TaskStep(name: 'Review economic events', isCompleted: false),
          TaskStep(name: 'Generate insights', isCompleted: false),
          TaskStep(name: 'Create visualizations', isCompleted: false),
          TaskStep(name: 'Compile report', isCompleted: false),
        ],
      ),
    ];
  }

  /// Loads mock data into the TaskProvider
  static void loadMockData(TaskProvider taskProvider) {
    final mockTasks = generateMockTasks();
    taskProvider.setTasks(mockTasks);
  }
}
