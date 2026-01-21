import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../today/today_page.dart';
import '../inbox/inbox_page.dart';
import '../calendar/calendar_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TodayPage(),
    InboxPage(),
    CalendarPage(),
    ProfilePage(),
  ];

  Future<void> _showQuickAddDialog() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l.today),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l.addTaskToToday,
            ),
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final title = controller.text.trim();
      if (title.isEmpty) return;

      final newTask = TasksCompanion(
        id: drift.Value(const Uuid().v4()),
        title: drift.Value(title),
        status: const drift.Value(0),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
        dueDate: drift.Value(DateTime.now()),
      );

      await db.insertTask(newTask);

      setState(() {
        _currentIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 简单阈值判断，> 600 视为桌面/平板宽屏模式
        if (constraints.maxWidth > 600) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final l = AppLocalizations.of(context);

    final titles = [
      l.today,
      l.inbox,
      l.calendar,
      l.profile,
    ];

    return Scaffold(
      body: Row(
        children: [
          // Custom Sidebar
          Container(
            width: 240,
            color: const Color(0xFFF7F7F7), // TickTick-like light grey background
            child: Column(
              children: [
                // Profile Header
                InkWell(
                  onTap: () {
                    setState(() => _currentIndex = 3); // Go to Profile
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.person, size: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'FlowLog User', // TODO: Get actual user name
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                
                // Quick Add Button (TickTick style often has this or just relies on input in list)
                // Keeping it as a list item or separate button? 
                // TickTick Web has a global search at top.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: const [
                        SizedBox(width: 8),
                        Icon(Icons.search, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Search', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _SidebarItem(
                        icon: Icons.wb_sunny_outlined,
                        activeIcon: Icons.wb_sunny,
                        label: l.today,
                        isSelected: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                        count: 2, // Example count
                      ),
                      _SidebarItem(
                        icon: Icons.inbox_outlined,
                        activeIcon: Icons.inbox,
                        label: l.inbox,
                        isSelected: _currentIndex == 1,
                        onTap: () => setState(() => _currentIndex = 1),
                        count: 5, // Example count
                      ),
                      _SidebarItem(
                        icon: Icons.calendar_month_outlined,
                        activeIcon: Icons.calendar_month,
                        label: l.calendar,
                        isSelected: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Lists Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LISTS', 
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.grey[600]
                              )
                            ),
                            const Icon(Icons.add, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                      _SidebarItem(
                        icon: Icons.list,
                        label: 'Work',
                        isSelected: false,
                        onTap: () {},
                        color: Colors.blue,
                      ),
                      _SidebarItem(
                        icon: Icons.list,
                        label: 'Personal',
                        isSelected: false,
                        onTap: () {},
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
                
                // Bottom Actions
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, size: 20)),
                      const Spacer(),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline, size: 20)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(thickness: 1, width: 1),
          
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(titles[_currentIndex]),
                centerTitle: false,
                elevation: 0,
                backgroundColor: Theme.of(context).colorScheme.surface,
                actions: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.sort)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
                  const SizedBox(width: 16),
                ],
              ),
              body: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final l = AppLocalizations.of(context);

    final titles = [
      l.today,
      l.inbox,
      l.calendar,
      l.profile,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.today_outlined),
            activeIcon: const Icon(Icons.today),
            label: titles[0],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox_outlined),
            activeIcon: const Icon(Icons.inbox),
            label: titles[1],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_month_outlined),
            activeIcon: const Icon(Icons.calendar_month),
            label: titles[2],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: titles[3],
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _showQuickAddDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  const _SidebarItem({
    super.key,
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? (isSelected ? theme.colorScheme.primary : Colors.grey[700]);
    final bgColor = isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent;
    final textStyle = TextStyle(
      color: isSelected ? theme.colorScheme.primary : Colors.black87,
      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
      fontSize: 14,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 36, // Compact height like TickTick
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              isSelected && activeIcon != null ? activeIcon : icon, 
              size: 20, 
              color: iconColor
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: textStyle)),
            if (count != null && count! > 0)
              Text(
                count.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}
