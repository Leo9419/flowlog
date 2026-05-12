# FlowLog

FlowLog is a cross-platform task and planning app. The current repository contains a Flutter client, local SQLite persistence through Drift, AI-assisted task tooling, notification support, and a Java server skeleton for future sync services.

## Repository Layout

```text
client/          Flutter app for macOS, iOS, Android, and other Flutter targets
server/          Maven multi-module server skeleton
docs/            Product and implementation notes
flowlog_design/  Architecture, product logic, and refactor plans
scripts/         Local packaging helpers
```

## Client

The Flutter client is the primary app today. It includes:

- Task views for Inbox, Today, Upcoming, Anytime, Someday, Logbook, Trash, projects, tags, and search.
- Local task storage with Drift and SQLite.
- macOS/iOS/Android platform scaffolding.
- Local notifications and shortcut settings.
- AI chat, local agent integration, privacy filtering, suggestion review, and action logging.
- Database migration and recovery logic for older local database locations.

### Run Locally

```bash
cd client
flutter pub get
flutter run -d macos
```

Use another Flutter device target if needed:

```bash
flutter devices
flutter run -d <device-id>
```

### Test

```bash
cd client
flutter test
```

### Regenerate Drift Code

Run this after changing Drift tables or database declarations:

```bash
cd client
dart run build_runner build --delete-conflicting-outputs
```

### Package macOS App

```bash
scripts/package_macos.sh
```

Install somewhere other than `/Applications`:

```bash
scripts/package_macos.sh --install-dir "$HOME/Applications" --open
```

## Server

The server is a Maven multi-module skeleton:

- `server/common`
- `server/web-server`
- `server/sync-server`

Local service dependencies are defined in `server/docker-compose.yml`:

```bash
cd server
docker compose up -d
mvn test
```

## Local Data

The desktop client stores its primary SQLite database under Application Support:

```text
~/Library/Application Support/com.example.flowlog/FlowLog/flowlog.sqlite
```

The app also checks older database locations and prefers a legacy database that contains tasks when recovering from an empty target database.

## GitHub Push

This repository is configured for:

```text
https://github.com/Leo9419/flowlog.git
```

After GitHub authentication is configured locally:

```bash
git push -u origin main
```
