# FlowLog M2 Standard Design

## Purpose

M2 standard turns the M1 adaptive shell into a usable Things-style task
experience. It restores the product surface that became incomplete when
`AdaptiveShell` replaced the old `HomePage`, and it standardizes the core list
views without pulling M3 interactions into scope.

## Scope

M2 includes:

- Dynamic sidebar navigation for Areas, Projects, and Tags.
- Project rows with color/icon, open task count, and progress.
- Quick Find wired to `Cmd+K`, with search across fixed views, tasks,
  projects, and tags.
- Context-aware Quick Add for Inbox, Today, Project, and Tag views.
- Today rebuilt on `watchTodayWithEvening()` with Overdue, Today, and This
  Evening sections.
- Calendar kept on the existing date grouping model, but using the shared M2
  list style.
- Future/Someday, Logbook, Project, and Tag pages converted to the shared M2
  list shell and empty-state patterns.
- A unified task row style for completion, detail opening, date/deadline chips,
  repeat marker, tags, and the existing priority context menu.
- Desktop row taps continue selecting the right-side DetailPane; mobile and
  tablet taps continue opening the modal detail sheet.

M2 does not include:

- Drag and drop sorting.
- Multi-select or batch operations.
- Markdown notes.
- Checklist editing UI.
- AI workflow redesign.
- Natural language date parsing beyond the existing AI parsing services.
- Server sync, device pairing, or conflict handling.

## Approach

Use shared list infrastructure rather than editing every page independently.
The core pages provide data streams, titles, grouping rules, and Quick Add
context. Shared widgets own layout, row styling, section headers, and empty
states.

This keeps M2 incremental and prepares M3 to add drag, multi-select, and
Checklist UI in one place.

## Components

Create these shared widgets under `client/lib/ui/m2/`:

- `task_list_scaffold.dart`: common page shell with title, optional subtitle,
  optional Quick Add bar, scroll padding, loading, error, and empty states.
- `task_quick_add_bar.dart`: one-line task creator. It accepts a
  `QuickAddContext` and writes the correct task fields for the active view.
- `task_section.dart`: section header and task list block for grouped views.
- `m2_task_row.dart`: shared task row for all M2 pages.
- `task_empty_state.dart`: consistent icon + message empty state.

Update these existing shell/page files:

- `client/lib/ui/shell/sidebar.dart`: render Areas -> Projects, standalone
  Projects, and Tags below fixed views.
- `client/lib/ui/shell/quick_find.dart`: search fixed views, tasks, projects,
  and tags; invoke the correct SelectionStore or detail action.
- `client/lib/ui/shell/adaptive_shell.dart`: wrap shell content in Shortcuts
  and Actions so `Cmd+K` opens Quick Find.
- `client/lib/ui/shell/shell_content.dart`: route Area, Project, and Tag
  selection to M2 pages consistently.
- `client/lib/ui/today/today_page.dart`: use M2 scaffold and
  `watchTodayWithEvening()`.
- `client/lib/ui/inbox/inbox_page.dart`: use M2 scaffold and Quick Add context.
- `client/lib/ui/upcoming/upcoming_page.dart`: keep current grouping behavior,
  but use M2 task rows and section styling.
- `client/lib/ui/someday/someday_page.dart`: keep the current user preference
  that this view means future dated tasks, and use the M2 shell.
- `client/lib/ui/logbook/logbook_page.dart`: group completed tasks by month in
  the M2 shell.
- `client/lib/ui/projects/project_page.dart`: use M2 scaffold, project progress,
  and context-aware Quick Add.
- `client/lib/ui/tags/tag_page.dart`: use M2 scaffold and tag-aware Quick Add.

## Data Flow

Sidebar:

1. Fixed views still use `SelectionStore.selectView`.
2. Areas come from `AppDatabase.watchAreas()`.
3. Projects come from `watchProjectsByArea(areaId)` for each area plus one
   standalone project group for `areaId == null`.
4. Tags come from `watchTags()`.
5. Project and tag taps call SelectionStore project/tag selection methods that
   already drive `ShellContent`.

Quick Find:

1. Empty query shows fixed views and recent navigation entries.
2. Non-empty query merges:
   - fixed view labels from the shell,
   - active tasks from `watchTasksByKeyword(query)`,
   - projects from `watchProjects()`,
   - tags from `watchTags()`.
3. Selecting a task opens DetailPane on desktop and modal detail on smaller
   layouts.
4. Selecting a project or tag updates `SelectionStore`; selecting Settings or
   Trash pushes the existing route.

Quick Add:

`QuickAddContext` determines the write:

- Inbox: insert active task with no project and no when.
- Today: insert active task with `whenType=today` and today's date.
- Project: insert active task with the active `projectId`.
- Tag: insert active task, then assign the active tag with `setTagsForTask`.
- Calendar/Future: insert into Inbox for M2; date-specific creation is reserved
  for M3 or AI parsing.
- Logbook: no Quick Add bar.

## Visual Behavior

M2 uses a quiet work-focused layout:

- No nested page cards.
- Lists sit in the page surface with restrained dividers.
- Headers are compact and scannable.
- Task rows keep stable dimensions and do not resize on hover.
- Project progress is compact: count text plus a small circular progress
  indicator or equivalent lightweight visual.
- Empty states are minimal and do not include instructional marketing copy.

## Error Handling

- Stream errors render an inline error state in the affected list area.
- Quick Add rejects empty input without writing.
- If tag assignment fails after task creation, the task remains in Inbox and the
  page shows a transient error.
- If a selected project or tag no longer exists, the page shows the existing
  not-found empty state.

## Testing

Add or update Flutter tests before implementation:

- `client/test/ui/shell_navigation_test.dart`
  - Sidebar displays areas, projects, standalone projects, and tags.
  - Tapping project/tag changes SelectionStore state.
- `client/test/ui/quick_find_test.dart`
  - `Cmd+K` opens Quick Find.
  - Query matches fixed views, tasks, projects, and tags.
  - Selecting project/tag/task performs the correct action.
- `client/test/ui/quick_add_test.dart`
  - Inbox Quick Add writes an unplanned task.
  - Today Quick Add writes `whenType=today`.
  - Project Quick Add writes `projectId`.
  - Tag Quick Add assigns the selected tag.
- `client/test/database/queries_test.dart`
  - Today sections split overdue, today, and evening tasks.
  - Project progress returns done and total.
  - Area/project ordering matches `sortOrder` then name.

Completion requires:

- Targeted tests passing.
- Full `flutter test` passing.
- `flutter analyze --no-pub` reporting no errors.

## Rollout

M2 should land in small commits:

1. Shared M2 list widgets.
2. Sidebar dynamic navigation.
3. Quick Find and `Cmd+K`.
4. Quick Add contexts.
5. Core page conversions.
6. Test and progress document updates.

`flowlog_design/refactor/PROGRESS.md` should be updated when M2 is complete.
