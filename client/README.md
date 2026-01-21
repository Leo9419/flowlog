# FlowLog Client (Flutter)

This directory contains the Flutter client for FlowLog.

## Setup

1.  Ensure you have Flutter SDK installed.
2.  Run `flutter create .` in this directory to initialize the project (if not already initialized).
3.  Run `flutter pub get` to install dependencies.

## Architecture

*   **UI**: Flutter Widgets
*   **State Management**: BLoC / Provider
*   **Local DB**: SQLite (drift/sqflite)
*   **Sync**: Custom Sync Engine via WebSocket
