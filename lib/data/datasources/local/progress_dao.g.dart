// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_dao.dart';

// ignore_for_file: type=lint
mixin _$ProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $BodyMetricsTable get bodyMetrics => attachedDatabase.bodyMetrics;
  $StrikeStatesTable get strikeStates => attachedDatabase.strikeStates;
  ProgressDaoManager get managers => ProgressDaoManager(this);
}

class ProgressDaoManager {
  final _$ProgressDaoMixin _db;
  ProgressDaoManager(this._db);
  $$BodyMetricsTableTableManager get bodyMetrics =>
      $$BodyMetricsTableTableManager(_db.attachedDatabase, _db.bodyMetrics);
  $$StrikeStatesTableTableManager get strikeStates =>
      $$StrikeStatesTableTableManager(_db.attachedDatabase, _db.strikeStates);
}
