import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Delay showing the splash screen for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showSplash = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ToDo App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: _showSplash ? const SplashScreen() : const ToDoApp(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red[200]!,
              Colors.green[200]!,
              Colors.blue[200]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/images.png', // Replace with your image path
                width: 150.0,
                height: 150.0,
              ),
              const SizedBox(height: 16.0),
              const Text(
                'ToDo App',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class ToDoApp extends StatefulWidget {
  const ToDoApp({super.key});

  @override
  _ToDoAppState createState() => _ToDoAppState();
}

class _ToDoAppState extends State<ToDoApp> {
  List<Task> tasks = [];
  TextEditingController controller = TextEditingController();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  int notificationId = 0;

  @override
  void initState() {
    super.initState();
    initializeNotifications();
    loadTasksFromFile().then((value) {
      setState(() {
        tasks = value;
      });
    });
  }

  Future<void> initializeNotifications() async {
    final InitializationSettings initializationSettings =
    const InitializationSettings(
        android: AndroidInitializationSettings('app_icon'));
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<List<Task>> loadTasksFromFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/tasks.txt');
    if (await file.exists()) {
      final contents = await file.readAsString();
      final List<dynamic> tasksJson = jsonDecode(contents);
      final taskList = tasksJson.map((taskJson) => Task.fromJson(taskJson)).toList();
      return taskList;
    } else {
      return [];
    }
  }

  Future<void> saveTasksToFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/tasks.txt');
    final List<dynamic> tasksJson = tasks.map((task) => task.toJson()).toList();
    final contents = jsonEncode(tasksJson);
    await file.writeAsString(contents);
  }

  Future<bool?> showConfirmationDialog(Task task) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task?'),
          content: Text('Are you sure you want to delete "${task.name}"?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> scheduleNotification(Task task) async {
    if (task.dueDate.isAfter(DateTime.now())) {
      final androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'channel_id',
        'channel_name',
        channelDescription: 'channel_description',
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: false,
      );


      final iOSPlatformChannelSpecifics = const IOSNotificationDetails();
      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.schedule(
        notificationId,
        'Task Reminder',
        'Remember to complete task: ${task.name}',
        task.dueDate,
        platformChannelSpecifics,
      );

      notificationId++;
    }
  }

  Future<void> cancelNotification(int notificationId) async {
    await flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToDo App'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Dismissible(
                  key: Key(task.name),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    color: Colors.red,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    final bool? shouldDelete = await showConfirmationDialog(task);
                    if (shouldDelete!) {
                      setState(() {
                        tasks.removeAt(index);
                      });
                      cancelNotification(index);
                      saveTasksToFile();
                    }
                    return shouldDelete;
                  },
                  child: ListTile(
                    title: Text(
                      task.name,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                        decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      'Due: ${task.dueDate.toIso8601String()}',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: task.dueDate.isBefore(DateTime.now())
                            ? Colors.red
                            : null,
                      ),
                    ),
                    trailing: Checkbox(
                      value: task.completed,
                      onChanged: (value) {
                        setState(() {
                          task.completed = value ?? false;
                        });
                        if (task.completed) {
                          cancelNotification(index);
                        } else {
                          scheduleNotification(task);
                        }
                        saveTasksToFile();
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditTaskPage(
                            task: task,
                            updateTask: (updatedTask) {
                              setState(() {
                                tasks[index] = updatedTask;
                              });
                              saveTasksToFile();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Add a new task',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      final newTask = Task(
                        name: controller.text,
                        dueDate: DateTime.now().add(const Duration(days: 1)),
                        priority: 1,
                        completed: false,
                      );
                      setState(() {
                        tasks.add(newTask);
                      });
                      scheduleNotification(newTask);
                      controller.clear();
                      saveTasksToFile();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Task {
  String name;
  DateTime dueDate;
  int priority;
  bool completed;

  Task({
    required this.name,
    required this.dueDate,
    required this.priority,
    required this.completed,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
        name: json['name'],
        dueDate: DateTime.parse(json['dueDate']),
    priority:
    json['priority'],
      completed: json['completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'completed': completed,
    };
  }
}

class EditTaskPage extends StatefulWidget {
  final Task task;
  final Function(Task) updateTask;

  EditTaskPage({super.key, required this.task, required this.updateTask});

  @override
  _EditTaskPageState createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  TextEditingController controller = TextEditingController();
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    controller.text = widget.task.name;
    selectedDate = widget.task.dueDate;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2021),
      lastDate: DateTime(2025),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Task Name',
              ),
            ),
            const SizedBox(height: 20.0),
            Row(
              children: [
                const Text(
                  'Due Date:',
                  style: TextStyle(fontSize: 16.0),
                ),
                const SizedBox(width: 10.0),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                final updatedTask = Task(
                  name: controller.text,
                  dueDate: selectedDate,
                  priority: widget.task.priority,
                  completed: widget.task.completed,
                );
                widget.updateTask(updatedTask);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}



