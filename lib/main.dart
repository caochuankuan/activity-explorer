// ignore_for_file: library_private_types_in_public_api, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode themeMode = ThemeMode.system; // 默认使用系统主题

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Explorer',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode, // 根据当前模式动态切换主题
      home: AppActivityExplorer(
        onThemeModeChanged: (newThemeMode) {
          setState(() {
            themeMode = newThemeMode;
          });
        },
        currentThemeMode: themeMode,
      ),
    );
  }
}

class AppActivityExplorer extends StatefulWidget {
  final Function(ThemeMode) onThemeModeChanged;
  final ThemeMode currentThemeMode;

  const AppActivityExplorer({
    super.key,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
  });

  @override
  _AppActivityExplorerState createState() => _AppActivityExplorerState();
}

class _AppActivityExplorerState extends State<AppActivityExplorer> {
  static const platform = MethodChannel('app_activity_explorer/channel');
  List<Map<String, dynamic>> apps = [];
  Map<String, List<Map<String, dynamic>>> allActivities = {};
  Map<String, List<Map<String, dynamic>>> visibleActivities = {};
  bool isLoading = false;
  bool showSystemApps = true;
  bool showUnexportedActivities = true;
  int currentPage = 0;
  final int pageSize = 50;
  Set<String> expandedTiles = {};

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    expandedTiles = {};
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });

    try {
      final result =
          await platform.invokeMethod<List<dynamic>>('getInstalledAppsPaged', {
        'startIndex': currentPage * pageSize,
        'limit': pageSize,
        'showSystemApps': showSystemApps,
      });
      if (result != null) {
        setState(() {
          apps.addAll(result.map((e) => Map<String, dynamic>.from(e)).toList());
          currentPage++;
        });
      }
    } on PlatformException catch (e) {
      print("获取应用失败: ${e.message}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadActivities(String packageName) async {
    if (allActivities.containsKey(packageName)) return;

    try {
      final result =
          await platform.invokeMethod<List<dynamic>>('getAllActivities', {
        'packageName': packageName,
      });
      if (result != null) {
        final activityList =
            result.map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {
          allActivities[packageName] = activityList;
          _filterActivities(packageName);
        });
      }
    } on PlatformException catch (e) {
      print("加载活动失败: ${e.message}");
    }
  }

  void _filterActivities(String packageName) {
    final activities = allActivities[packageName] ?? [];
    setState(() {
      visibleActivities[packageName] = activities.where((activity) {
        return showUnexportedActivities || activity['exported'] == "true";
      }).toList();
    });
  }

  Future<void> _launchActivity(String packageName, String activityName) async {
    try {
      await platform.invokeMethod('launchActivity', {
        'packageName': packageName,
        'activityName': activityName,
      });
    } on PlatformException catch (e) {
      print("启动活动失败: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () {
          // 关于页面
          showAboutDialog(
            context: context,
            applicationIcon: Image.asset("assets/app_icon.png", width: 80, height: 80),
            applicationName: 'Activity 探索',
            applicationVersion: '1.0.0',
            children: [
              GestureDetector(
                child: Text('联系方式：酷安@于逸风'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'http://www.coolapk.com/u/852927'));
                  // 提示信息
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制到剪贴板')));
                },
              ),
              const Text(''),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'https://github.com/chuankuan0213/activity-explorer'));
                  // 提示信息
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制到剪贴板')));
                },
                child: Text('项目开源地址(Gitlab): https://gitlab.com/chuankuan0213/activity-explorer'),
              ),
            ]
          );
        }, icon: const Icon(Icons.info_outlined)),
        title: const Text('Activity 探索'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              widget.currentThemeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              final newMode = widget.currentThemeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              widget.onThemeModeChanged(newMode);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggleSystemApps') {
                setState(() {
                  showSystemApps = !showSystemApps;
                  apps.clear();
                  currentPage = 0;
                });
                _loadInstalledApps();
              } else if (value == 'toggleUnexportedActivities') {
                setState(() {
                  showUnexportedActivities = !showUnexportedActivities;
                  visibleActivities.clear();
                });
                allActivities.keys.forEach(_filterActivities);
              }
            },
            icon: const Icon(Icons.filter_alt_outlined),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Theme.of(context).colorScheme.surface,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggleSystemApps',
                child: Row(
                  children: [
                    Icon(
                      showSystemApps ? Icons.toggle_on : Icons.toggle_off,
                      color: showSystemApps
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      showSystemApps ? '隐藏系统应用' : '显示系统应用',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggleUnexportedActivities',
                child: Row(
                  children: [
                    Icon(
                      showUnexportedActivities
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: showUnexportedActivities
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      showUnexportedActivities ? '隐藏未导出的活动' : '显示未导出的活动',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollEndNotification &&
              scrollNotification.metrics.extentAfter == 0) {
            _loadInstalledApps();
          }
          return false;
        },
        child: ListView.builder(
          itemCount: apps.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= apps.length) {
              return const Center(child: CircularProgressIndicator());
            }

            final app = apps[index];
            final packageName = app['packageName'];
            final isExpanded = expandedTiles.contains(packageName);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: isExpanded
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surface,
              child: ExpansionTile(
                leading: Icon(Icons.apps, color: Colors.blue),
                title: Text(app['appName']),
                subtitle: Text(packageName),
                onExpansionChanged: (expanded) {
                  if (expanded) {
                    _loadActivities(packageName);
                  }
                  setState(() {
                    if (expanded) {
                      expandedTiles.add(packageName);
                      _loadActivities(packageName);
                    } else {
                      expandedTiles.remove(packageName);
                    }
                  });
                },
                children: visibleActivities[packageName]?.map((activity) {
                      return ListTile(
                        splashColor: const Color.fromARGB(255, 203, 237, 217),
                        title: Text(
                          activity['label'],
                          style: TextStyle(
                            color: activity['exported'] == "true"
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),
                        subtitle: Text(
                          activity['name'],
                          style: TextStyle(
                            color: activity['exported'] == "true"
                                ? Colors.blue[700]
                                : Colors.red[700],
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          _launchActivity(packageName, activity['name']);
                        },
                      );
                    }).toList() ??
                    [const Center(child: CircularProgressIndicator())],
              ),
            );
          },
        ),
      ),
    );
  }
}
