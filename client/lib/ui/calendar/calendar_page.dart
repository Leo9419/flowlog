import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final List<DateTime> _days = List.generate(
    30,
    (index) => DateTime.now().add(Duration(days: index)),
  );

  int _selectedIndex = 0;

  DateTime get _selectedDay => _days[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final db = Provider.of<AppDatabase>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: 260,
                child: _buildDayList(context, l, db),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _buildTaskList(context, l, db, isWide),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              SizedBox(
                height: 260,
                child: _buildDayList(context, l, db),
              ),
              const Divider(height: 1),
              Expanded(
                child: _buildTaskList(context, l, db, isWide),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDayList(BuildContext context, AppLocalizations l, AppDatabase db) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _days.length,
      itemBuilder: (context, index) {
        final date = _days[index];
        final label = '${date.month}/${date.day}';
        final isSelected = index == _selectedIndex;

        return StreamBuilder<List<Task>>(
          stream: db.watchTasksForDate(date),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;

            return Card(
              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
              child: ListTile(
                title: Text(label),
                subtitle: Text(l.calendarDayTasks(count)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskList(BuildContext context, AppLocalizations l, AppDatabase db, bool isWide) {
    final day = _selectedDay;
    final title = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Task>>(
            stream: db.watchTasksForDate(day),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = snapshot.data!;

              if (tasks.isEmpty) {
                return Center(
                  child: Text(
                    l.todayEmpty,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 80),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskRow(task: task, db: db, isWide: isWide);
                },
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 50),
                itemCount: tasks.length,
              );
            },
          ),
        ),
      ],
    );
  }
}
