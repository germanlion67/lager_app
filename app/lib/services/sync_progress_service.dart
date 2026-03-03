// lib/services/sync_progress_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Status einer Synchronisationsoperation
enum SyncStatus {
  idle,
  initializing,
  connecting,
  analyzing,
  downloading,
  uploading,
  processing,
  resolving,
  finalizing,
  completed,
  error,
  cancelled
}

/// Details einer Sync-Operation
class SyncOperation {
  final String id;
  final String name;
  final SyncStatus status;
  final double progress;
  final String? currentItem;
  final String? message;
  final DateTime startTime;
  final DateTime? endTime;
  final Object? error;
  final StackTrace? stackTrace;

  SyncOperation({
    required this.id,
    required this.name,
    required this.status,
    this.progress = 0.0,
    this.currentItem,
    this.message,
    DateTime? startTime,
    this.endTime,
    this.error,
    this.stackTrace,
  }) : startTime = startTime ?? DateTime.now();

  SyncOperation copyWith({
    String? id,
    String? name,
    SyncStatus? status,
    double? progress,
    String? currentItem,
    String? message,
    DateTime? startTime,
    DateTime? endTime,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentItem: currentItem ?? this.currentItem,
      message: message ?? this.message,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isCompleted => status == SyncStatus.completed;
  bool get isError => status == SyncStatus.error;
  bool get isActive => !isCompleted && !isError && status != SyncStatus.cancelled;

  String get statusText {
    switch (status) {
      case SyncStatus.idle:
        return 'Bereit';
      case SyncStatus.initializing:
        return 'Initialisiere...';
      case SyncStatus.connecting:
        return 'Verbinde...';
      case SyncStatus.analyzing:
        return 'Analysiere Änderungen...';
      case SyncStatus.downloading:
        return 'Lade herunter...';
      case SyncStatus.uploading:
        return 'Lade hoch...';
      case SyncStatus.processing:
        return 'Verarbeite...';
      case SyncStatus.resolving:
        return 'Löse Konflikte...';
      case SyncStatus.finalizing:
        return 'Finalisiere...';
      case SyncStatus.completed:
        return 'Abgeschlossen';
      case SyncStatus.error:
        return 'Fehler';
      case SyncStatus.cancelled:
        return 'Abgebrochen';
    }
  }
}

/// Detaillierte Sync-Statistiken
class SyncStats {
  final int totalItems;
  final int processedItems;
  final int uploadedItems;
  final int downloadedItems;
  final int conflictItems;
  final int errorItems;
  final int skippedItems;
  final Duration totalDuration;
  final List<String> errors;

  SyncStats({
    this.totalItems = 0,
    this.processedItems = 0,
    this.uploadedItems = 0,
    this.downloadedItems = 0,
    this.conflictItems = 0,
    this.errorItems = 0,
    this.skippedItems = 0,
    this.totalDuration = Duration.zero,
    this.errors = const [],
  });

  SyncStats copyWith({
    int? totalItems,
    int? processedItems,
    int? uploadedItems,
    int? downloadedItems,
    int? conflictItems,
    int? errorItems,
    int? skippedItems,
    Duration? totalDuration,
    List<String>? errors,
  }) {
    return SyncStats(
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      uploadedItems: uploadedItems ?? this.uploadedItems,
      downloadedItems: downloadedItems ?? this.downloadedItems,
      conflictItems: conflictItems ?? this.conflictItems,
      errorItems: errorItems ?? this.errorItems,
      skippedItems: skippedItems ?? this.skippedItems,
      totalDuration: totalDuration ?? this.totalDuration,
      errors: errors ?? this.errors,
    );
  }

  double get progressPercentage {
    if (totalItems == 0) return 0.0;
    return (processedItems / totalItems).clamp(0.0, 1.0);
  }

  bool get hasErrors => errorItems > 0 || errors.isNotEmpty;
  bool get hasConflicts => conflictItems > 0;
  bool get isCompleted => processedItems >= totalItems && totalItems > 0;
}

/// Service für die Verfolgung des Synchronisationsfortschritts
class SyncProgressService extends ChangeNotifier {
  SyncOperation? _currentOperation;
  final List<SyncOperation> _operationHistory = [];
  SyncStats _stats = SyncStats();
  final StreamController<SyncOperation> _operationController = StreamController.broadcast();
  final StreamController<SyncStats> _statsController = StreamController.broadcast();

  SyncOperation? get currentOperation => _currentOperation;
  SyncStats get stats => _stats;
  List<SyncOperation> get operationHistory => List.unmodifiable(_operationHistory);
  Stream<SyncOperation> get operationStream => _operationController.stream;
  Stream<SyncStats> get statsStream => _statsController.stream;

  bool get isSyncing => _currentOperation?.isActive == true;

  /// Startet eine neue Sync-Operation
  String startOperation(String name) {
    final id = 'sync_${DateTime.now().millisecondsSinceEpoch}';
    _currentOperation = SyncOperation(
      id: id,
      name: name,
      status: SyncStatus.initializing,
    );
    
    _stats = SyncStats();
    _operationController.add(_currentOperation!);
    _statsController.add(_stats);
    notifyListeners();
    
    return id;
  }

  /// Aktualisiert den Status der aktuellen Operation
  void updateOperation({
    SyncStatus? status,
    double? progress,
    String? currentItem,
    String? message,
  }) {
    if (_currentOperation == null) return;

    _currentOperation = _currentOperation!.copyWith(
      status: status,
      progress: progress,
      currentItem: currentItem,
      message: message,
    );

    _operationController.add(_currentOperation!);
    notifyListeners();
  }

  /// Setzt die Gesamtanzahl der zu verarbeitenden Items
  void setTotalItems(int totalItems) {
    _stats = _stats.copyWith(totalItems: totalItems);
    _statsController.add(_stats);
    notifyListeners();
  }

  /// Aktualisiert die Statistiken
  void updateStats({
    int? processedItems,
    int? uploadedItems,
    int? downloadedItems,
    int? conflictItems,
    int? errorItems,
    int? skippedItems,
    String? error,
  }) {
    final errors = List<String>.from(_stats.errors);
    if (error != null) {
      errors.add(error);
    }

    _stats = _stats.copyWith(
      processedItems: processedItems ?? _stats.processedItems,
      uploadedItems: uploadedItems ?? _stats.uploadedItems,
      downloadedItems: downloadedItems ?? _stats.downloadedItems,
      conflictItems: conflictItems ?? _stats.conflictItems,
      errorItems: errorItems ?? _stats.errorItems,
      skippedItems: skippedItems ?? _stats.skippedItems,
      errors: errors,
    );

    // Aktualisiere auch den Progress der Operation
    if (_currentOperation != null && _stats.totalItems > 0) {
      final progress = (_stats.processedItems / _stats.totalItems).clamp(0.0, 1.0);
      _currentOperation = _currentOperation!.copyWith(progress: progress);
      _operationController.add(_currentOperation!);
    }

    _statsController.add(_stats);
    notifyListeners();
  }

  /// Inkrementiert einen Statistikwert
  void incrementStat(String type) {
    switch (type) {
      case 'processed':
        updateStats(processedItems: _stats.processedItems + 1);
        break;
      case 'uploaded':
        updateStats(uploadedItems: _stats.uploadedItems + 1);
        break;
      case 'downloaded':
        updateStats(downloadedItems: _stats.downloadedItems + 1);
        break;
      case 'conflict':
        updateStats(conflictItems: _stats.conflictItems + 1);
        break;
      case 'error':
        updateStats(errorItems: _stats.errorItems + 1);
        break;
      case 'skipped':
        updateStats(skippedItems: _stats.skippedItems + 1);
        break;
    }
  }

  /// Dekrementiert einen Statistikwert (für Error Recovery)
  void decrementStat(String type) {
    switch (type) {
      case 'processed':
        if (_stats.processedItems > 0) {
          updateStats(processedItems: _stats.processedItems - 1);
        }
        break;
      case 'uploaded':
        if (_stats.uploadedItems > 0) {
          updateStats(uploadedItems: _stats.uploadedItems - 1);
        }
        break;
      case 'downloaded':
        if (_stats.downloadedItems > 0) {
          updateStats(downloadedItems: _stats.downloadedItems - 1);
        }
        break;
      case 'conflict':
        if (_stats.conflictItems > 0) {
          updateStats(conflictItems: _stats.conflictItems - 1);
        }
        break;
      case 'error':
        if (_stats.errorItems > 0) {
          updateStats(errorItems: _stats.errorItems - 1);
        }
        break;
      case 'skipped':
        if (_stats.skippedItems > 0) {
          updateStats(skippedItems: _stats.skippedItems - 1);
        }
        break;
    }
  }

  /// Beendet die aktuelle Operation erfolgreich
  void completeOperation({String? message}) {
    if (_currentOperation == null) return;

    _currentOperation = _currentOperation!.copyWith(
      status: SyncStatus.completed,
      progress: 1.0,
      message: message ?? 'Synchronisation erfolgreich abgeschlossen',
      endTime: DateTime.now(),
    );

    _stats = _stats.copyWith(
      totalDuration: _currentOperation!.duration,
    );

    _operationHistory.add(_currentOperation!);
    _operationController.add(_currentOperation!);
    _statsController.add(_stats);
    notifyListeners();

    // Reset für nächste Operation
    _currentOperation = null;
  }

  /// Beendet die aktuelle Operation mit einem Fehler
  void failOperation(Object error, {StackTrace? stackTrace, String? message}) {
    if (_currentOperation == null) return;

    _currentOperation = _currentOperation!.copyWith(
      status: SyncStatus.error,
      message: message ?? 'Synchronisation fehlgeschlagen: ${error.toString()}',
      error: error,
      stackTrace: stackTrace,
      endTime: DateTime.now(),
    );

    _stats = _stats.copyWith(
      totalDuration: _currentOperation!.duration,
      errors: [..._stats.errors, error.toString()],
    );

    _operationHistory.add(_currentOperation!);
    _operationController.add(_currentOperation!);
    _statsController.add(_stats);
    notifyListeners();

    // Reset für nächste Operation
    _currentOperation = null;
  }

  /// Bricht die aktuelle Operation ab
  void cancelOperation({String? message}) {
    if (_currentOperation == null) return;

    _currentOperation = _currentOperation!.copyWith(
      status: SyncStatus.cancelled,
      message: message ?? 'Synchronisation abgebrochen',
      endTime: DateTime.now(),
    );

    _operationHistory.add(_currentOperation!);
    _operationController.add(_currentOperation!);
    notifyListeners();

    // Reset für nächste Operation
    _currentOperation = null;
  }

  /// Löscht die Operation History
  void clearHistory() {
    _operationHistory.clear();
    notifyListeners();
  }

  /// Erstellt einen detaillierten Report der letzten Operation
  Map<String, dynamic> getLastOperationReport() {
    if (_operationHistory.isEmpty) return {};

    final lastOp = _operationHistory.last;
    return {
      'operation': {
        'id': lastOp.id,
        'name': lastOp.name,
        'status': lastOp.statusText,
        'duration': _formatDuration(lastOp.duration),
        'progress': '${(lastOp.progress * 100).toStringAsFixed(1)}%',
        'message': lastOp.message,
        'error': lastOp.error?.toString(),
      },
      'statistics': {
        'totalItems': _stats.totalItems,
        'processedItems': _stats.processedItems,
        'uploadedItems': _stats.uploadedItems,
        'downloadedItems': _stats.downloadedItems,
        'conflictItems': _stats.conflictItems,
        'errorItems': _stats.errorItems,
        'skippedItems': _stats.skippedItems,
        'successRate': _stats.totalItems > 0 
          ? '${((_stats.processedItems - _stats.errorItems) / _stats.totalItems * 100).toStringAsFixed(1)}%'
          : '0%',
        'errors': _stats.errors,
      },
      'performance': {
        'totalDuration': _formatDuration(_stats.totalDuration),
        'itemsPerSecond': _stats.totalDuration.inSeconds > 0 
          ? (_stats.processedItems / _stats.totalDuration.inSeconds).toStringAsFixed(2)
          : '0',
      },
    };
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  void dispose() {
    _operationController.close();
    _statsController.close();
    super.dispose();
  }
}