// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<String> workoutId = GeneratedColumn<String>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planSessionIdMeta = const VerificationMeta(
    'planSessionId',
  );
  @override
  late final GeneratedColumn<String> planSessionId = GeneratedColumn<String>(
    'plan_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exercisesJsonMeta = const VerificationMeta(
    'exercisesJson',
  );
  @override
  late final GeneratedColumn<String> exercisesJson = GeneratedColumn<String>(
    'exercises_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _restJsonMeta = const VerificationMeta(
    'restJson',
  );
  @override
  late final GeneratedColumn<String> restJson = GeneratedColumn<String>(
    'rest_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _pausedJsonMeta = const VerificationMeta(
    'pausedJson',
  );
  @override
  late final GeneratedColumn<String> pausedJson = GeneratedColumn<String>(
    'paused_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalRepsMeta = const VerificationMeta(
    'totalReps',
  );
  @override
  late final GeneratedColumn<int> totalReps = GeneratedColumn<int>(
    'total_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgCadenceRpmMeta = const VerificationMeta(
    'avgCadenceRpm',
  );
  @override
  late final GeneratedColumn<double> avgCadenceRpm = GeneratedColumn<double>(
    'avg_cadence_rpm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _formAccuracyPctMeta = const VerificationMeta(
    'formAccuracyPct',
  );
  @override
  late final GeneratedColumn<double> formAccuracyPct = GeneratedColumn<double>(
    'form_accuracy_pct',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    planSessionId,
    startedAt,
    endedAt,
    status,
    exercisesJson,
    restJson,
    pausedJson,
    durationSec,
    totalReps,
    avgCadenceRpm,
    formAccuracyPct,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('plan_session_id')) {
      context.handle(
        _planSessionIdMeta,
        planSessionId.isAcceptableOrUnknown(
          data['plan_session_id']!,
          _planSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('exercises_json')) {
      context.handle(
        _exercisesJsonMeta,
        exercisesJson.isAcceptableOrUnknown(
          data['exercises_json']!,
          _exercisesJsonMeta,
        ),
      );
    }
    if (data.containsKey('rest_json')) {
      context.handle(
        _restJsonMeta,
        restJson.isAcceptableOrUnknown(data['rest_json']!, _restJsonMeta),
      );
    }
    if (data.containsKey('paused_json')) {
      context.handle(
        _pausedJsonMeta,
        pausedJson.isAcceptableOrUnknown(data['paused_json']!, _pausedJsonMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('total_reps')) {
      context.handle(
        _totalRepsMeta,
        totalReps.isAcceptableOrUnknown(data['total_reps']!, _totalRepsMeta),
      );
    }
    if (data.containsKey('avg_cadence_rpm')) {
      context.handle(
        _avgCadenceRpmMeta,
        avgCadenceRpm.isAcceptableOrUnknown(
          data['avg_cadence_rpm']!,
          _avgCadenceRpmMeta,
        ),
      );
    }
    if (data.containsKey('form_accuracy_pct')) {
      context.handle(
        _formAccuracyPctMeta,
        formAccuracyPct.isAcceptableOrUnknown(
          data['form_accuracy_pct']!,
          _formAccuracyPctMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_id'],
      )!,
      planSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_session_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      exercisesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercises_json'],
      )!,
      restJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rest_json'],
      )!,
      pausedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paused_json'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      totalReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_reps'],
      )!,
      avgCadenceRpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_cadence_rpm'],
      )!,
      formAccuracyPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}form_accuracy_pct'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSessionRow extends DataClass
    implements Insertable<WorkoutSessionRow> {
  final String id;
  final String workoutId;
  final String? planSessionId;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// SessionStatus.name — active | paused | completed | abandoned.
  final String status;
  final String exercisesJson;
  final String restJson;
  final String? pausedJson;
  final int durationSec;
  final int totalReps;
  final double avgCadenceRpm;
  final double formAccuracyPct;
  final DateTime? syncedAt;
  const WorkoutSessionRow({
    required this.id,
    required this.workoutId,
    this.planSessionId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    required this.exercisesJson,
    required this.restJson,
    this.pausedJson,
    required this.durationSec,
    required this.totalReps,
    required this.avgCadenceRpm,
    required this.formAccuracyPct,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workout_id'] = Variable<String>(workoutId);
    if (!nullToAbsent || planSessionId != null) {
      map['plan_session_id'] = Variable<String>(planSessionId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['status'] = Variable<String>(status);
    map['exercises_json'] = Variable<String>(exercisesJson);
    map['rest_json'] = Variable<String>(restJson);
    if (!nullToAbsent || pausedJson != null) {
      map['paused_json'] = Variable<String>(pausedJson);
    }
    map['duration_sec'] = Variable<int>(durationSec);
    map['total_reps'] = Variable<int>(totalReps);
    map['avg_cadence_rpm'] = Variable<double>(avgCadenceRpm);
    map['form_accuracy_pct'] = Variable<double>(formAccuracyPct);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      planSessionId: planSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(planSessionId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      status: Value(status),
      exercisesJson: Value(exercisesJson),
      restJson: Value(restJson),
      pausedJson: pausedJson == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedJson),
      durationSec: Value(durationSec),
      totalReps: Value(totalReps),
      avgCadenceRpm: Value(avgCadenceRpm),
      formAccuracyPct: Value(formAccuracyPct),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory WorkoutSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSessionRow(
      id: serializer.fromJson<String>(json['id']),
      workoutId: serializer.fromJson<String>(json['workoutId']),
      planSessionId: serializer.fromJson<String?>(json['planSessionId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      status: serializer.fromJson<String>(json['status']),
      exercisesJson: serializer.fromJson<String>(json['exercisesJson']),
      restJson: serializer.fromJson<String>(json['restJson']),
      pausedJson: serializer.fromJson<String?>(json['pausedJson']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      totalReps: serializer.fromJson<int>(json['totalReps']),
      avgCadenceRpm: serializer.fromJson<double>(json['avgCadenceRpm']),
      formAccuracyPct: serializer.fromJson<double>(json['formAccuracyPct']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workoutId': serializer.toJson<String>(workoutId),
      'planSessionId': serializer.toJson<String?>(planSessionId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'status': serializer.toJson<String>(status),
      'exercisesJson': serializer.toJson<String>(exercisesJson),
      'restJson': serializer.toJson<String>(restJson),
      'pausedJson': serializer.toJson<String?>(pausedJson),
      'durationSec': serializer.toJson<int>(durationSec),
      'totalReps': serializer.toJson<int>(totalReps),
      'avgCadenceRpm': serializer.toJson<double>(avgCadenceRpm),
      'formAccuracyPct': serializer.toJson<double>(formAccuracyPct),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  WorkoutSessionRow copyWith({
    String? id,
    String? workoutId,
    Value<String?> planSessionId = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    String? status,
    String? exercisesJson,
    String? restJson,
    Value<String?> pausedJson = const Value.absent(),
    int? durationSec,
    int? totalReps,
    double? avgCadenceRpm,
    double? formAccuracyPct,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => WorkoutSessionRow(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    planSessionId: planSessionId.present
        ? planSessionId.value
        : this.planSessionId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    status: status ?? this.status,
    exercisesJson: exercisesJson ?? this.exercisesJson,
    restJson: restJson ?? this.restJson,
    pausedJson: pausedJson.present ? pausedJson.value : this.pausedJson,
    durationSec: durationSec ?? this.durationSec,
    totalReps: totalReps ?? this.totalReps,
    avgCadenceRpm: avgCadenceRpm ?? this.avgCadenceRpm,
    formAccuracyPct: formAccuracyPct ?? this.formAccuracyPct,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  WorkoutSessionRow copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSessionRow(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      planSessionId: data.planSessionId.present
          ? data.planSessionId.value
          : this.planSessionId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      status: data.status.present ? data.status.value : this.status,
      exercisesJson: data.exercisesJson.present
          ? data.exercisesJson.value
          : this.exercisesJson,
      restJson: data.restJson.present ? data.restJson.value : this.restJson,
      pausedJson: data.pausedJson.present
          ? data.pausedJson.value
          : this.pausedJson,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      totalReps: data.totalReps.present ? data.totalReps.value : this.totalReps,
      avgCadenceRpm: data.avgCadenceRpm.present
          ? data.avgCadenceRpm.value
          : this.avgCadenceRpm,
      formAccuracyPct: data.formAccuracyPct.present
          ? data.formAccuracyPct.value
          : this.formAccuracyPct,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionRow(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('planSessionId: $planSessionId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('exercisesJson: $exercisesJson, ')
          ..write('restJson: $restJson, ')
          ..write('pausedJson: $pausedJson, ')
          ..write('durationSec: $durationSec, ')
          ..write('totalReps: $totalReps, ')
          ..write('avgCadenceRpm: $avgCadenceRpm, ')
          ..write('formAccuracyPct: $formAccuracyPct, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    planSessionId,
    startedAt,
    endedAt,
    status,
    exercisesJson,
    restJson,
    pausedJson,
    durationSec,
    totalReps,
    avgCadenceRpm,
    formAccuracyPct,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSessionRow &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.planSessionId == this.planSessionId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.status == this.status &&
          other.exercisesJson == this.exercisesJson &&
          other.restJson == this.restJson &&
          other.pausedJson == this.pausedJson &&
          other.durationSec == this.durationSec &&
          other.totalReps == this.totalReps &&
          other.avgCadenceRpm == this.avgCadenceRpm &&
          other.formAccuracyPct == this.formAccuracyPct &&
          other.syncedAt == this.syncedAt);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSessionRow> {
  final Value<String> id;
  final Value<String> workoutId;
  final Value<String?> planSessionId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> status;
  final Value<String> exercisesJson;
  final Value<String> restJson;
  final Value<String?> pausedJson;
  final Value<int> durationSec;
  final Value<int> totalReps;
  final Value<double> avgCadenceRpm;
  final Value<double> formAccuracyPct;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.planSessionId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.exercisesJson = const Value.absent(),
    this.restJson = const Value.absent(),
    this.pausedJson = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.totalReps = const Value.absent(),
    this.avgCadenceRpm = const Value.absent(),
    this.formAccuracyPct = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    required String id,
    required String workoutId,
    this.planSessionId = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required String status,
    this.exercisesJson = const Value.absent(),
    this.restJson = const Value.absent(),
    this.pausedJson = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.totalReps = const Value.absent(),
    this.avgCadenceRpm = const Value.absent(),
    this.formAccuracyPct = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workoutId = Value(workoutId),
       startedAt = Value(startedAt),
       status = Value(status);
  static Insertable<WorkoutSessionRow> custom({
    Expression<String>? id,
    Expression<String>? workoutId,
    Expression<String>? planSessionId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? status,
    Expression<String>? exercisesJson,
    Expression<String>? restJson,
    Expression<String>? pausedJson,
    Expression<int>? durationSec,
    Expression<int>? totalReps,
    Expression<double>? avgCadenceRpm,
    Expression<double>? formAccuracyPct,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (planSessionId != null) 'plan_session_id': planSessionId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (status != null) 'status': status,
      if (exercisesJson != null) 'exercises_json': exercisesJson,
      if (restJson != null) 'rest_json': restJson,
      if (pausedJson != null) 'paused_json': pausedJson,
      if (durationSec != null) 'duration_sec': durationSec,
      if (totalReps != null) 'total_reps': totalReps,
      if (avgCadenceRpm != null) 'avg_cadence_rpm': avgCadenceRpm,
      if (formAccuracyPct != null) 'form_accuracy_pct': formAccuracyPct,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? workoutId,
    Value<String?>? planSessionId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String>? status,
    Value<String>? exercisesJson,
    Value<String>? restJson,
    Value<String?>? pausedJson,
    Value<int>? durationSec,
    Value<int>? totalReps,
    Value<double>? avgCadenceRpm,
    Value<double>? formAccuracyPct,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      planSessionId: planSessionId ?? this.planSessionId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      exercisesJson: exercisesJson ?? this.exercisesJson,
      restJson: restJson ?? this.restJson,
      pausedJson: pausedJson ?? this.pausedJson,
      durationSec: durationSec ?? this.durationSec,
      totalReps: totalReps ?? this.totalReps,
      avgCadenceRpm: avgCadenceRpm ?? this.avgCadenceRpm,
      formAccuracyPct: formAccuracyPct ?? this.formAccuracyPct,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<String>(workoutId.value);
    }
    if (planSessionId.present) {
      map['plan_session_id'] = Variable<String>(planSessionId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (exercisesJson.present) {
      map['exercises_json'] = Variable<String>(exercisesJson.value);
    }
    if (restJson.present) {
      map['rest_json'] = Variable<String>(restJson.value);
    }
    if (pausedJson.present) {
      map['paused_json'] = Variable<String>(pausedJson.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (totalReps.present) {
      map['total_reps'] = Variable<int>(totalReps.value);
    }
    if (avgCadenceRpm.present) {
      map['avg_cadence_rpm'] = Variable<double>(avgCadenceRpm.value);
    }
    if (formAccuracyPct.present) {
      map['form_accuracy_pct'] = Variable<double>(formAccuracyPct.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('planSessionId: $planSessionId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('status: $status, ')
          ..write('exercisesJson: $exercisesJson, ')
          ..write('restJson: $restJson, ')
          ..write('pausedJson: $pausedJson, ')
          ..write('durationSec: $durationSec, ')
          ..write('totalReps: $totalReps, ')
          ..write('avgCadenceRpm: $avgCadenceRpm, ')
          ..write('formAccuracyPct: $formAccuracyPct, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingPlansTable extends TrainingPlans
    with TableInfo<$TrainingPlansTable, TrainingPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<DateTime> weekStart = GeneratedColumn<DateTime>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daysJsonMeta = const VerificationMeta(
    'daysJson',
  );
  @override
  late final GeneratedColumn<String> daysJson = GeneratedColumn<String>(
    'days_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    weekStart,
    source,
    daysJson,
    lastUpdated,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('days_json')) {
      context.handle(
        _daysJsonMeta,
        daysJson.isAcceptableOrUnknown(data['days_json']!, _daysJsonMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingPlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}week_start'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      daysJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}days_json'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $TrainingPlansTable createAlias(String alias) {
    return $TrainingPlansTable(attachedDatabase, alias);
  }
}

class TrainingPlanRow extends DataClass implements Insertable<TrainingPlanRow> {
  final String id;
  final DateTime weekStart;

  /// PlanSource.name — ai | manual.
  final String source;

  /// Serialized PlanDay list (see plan mapping in `plan_dao.dart`).
  final String daysJson;
  final DateTime lastUpdated;
  final DateTime? syncedAt;
  const TrainingPlanRow({
    required this.id,
    required this.weekStart,
    required this.source,
    required this.daysJson,
    required this.lastUpdated,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['week_start'] = Variable<DateTime>(weekStart);
    map['source'] = Variable<String>(source);
    map['days_json'] = Variable<String>(daysJson);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  TrainingPlansCompanion toCompanion(bool nullToAbsent) {
    return TrainingPlansCompanion(
      id: Value(id),
      weekStart: Value(weekStart),
      source: Value(source),
      daysJson: Value(daysJson),
      lastUpdated: Value(lastUpdated),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory TrainingPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingPlanRow(
      id: serializer.fromJson<String>(json['id']),
      weekStart: serializer.fromJson<DateTime>(json['weekStart']),
      source: serializer.fromJson<String>(json['source']),
      daysJson: serializer.fromJson<String>(json['daysJson']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'weekStart': serializer.toJson<DateTime>(weekStart),
      'source': serializer.toJson<String>(source),
      'daysJson': serializer.toJson<String>(daysJson),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  TrainingPlanRow copyWith({
    String? id,
    DateTime? weekStart,
    String? source,
    String? daysJson,
    DateTime? lastUpdated,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => TrainingPlanRow(
    id: id ?? this.id,
    weekStart: weekStart ?? this.weekStart,
    source: source ?? this.source,
    daysJson: daysJson ?? this.daysJson,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  TrainingPlanRow copyWithCompanion(TrainingPlansCompanion data) {
    return TrainingPlanRow(
      id: data.id.present ? data.id.value : this.id,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      source: data.source.present ? data.source.value : this.source,
      daysJson: data.daysJson.present ? data.daysJson.value : this.daysJson,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingPlanRow(')
          ..write('id: $id, ')
          ..write('weekStart: $weekStart, ')
          ..write('source: $source, ')
          ..write('daysJson: $daysJson, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, weekStart, source, daysJson, lastUpdated, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingPlanRow &&
          other.id == this.id &&
          other.weekStart == this.weekStart &&
          other.source == this.source &&
          other.daysJson == this.daysJson &&
          other.lastUpdated == this.lastUpdated &&
          other.syncedAt == this.syncedAt);
}

class TrainingPlansCompanion extends UpdateCompanion<TrainingPlanRow> {
  final Value<String> id;
  final Value<DateTime> weekStart;
  final Value<String> source;
  final Value<String> daysJson;
  final Value<DateTime> lastUpdated;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const TrainingPlansCompanion({
    this.id = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.source = const Value.absent(),
    this.daysJson = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingPlansCompanion.insert({
    required String id,
    required DateTime weekStart,
    required String source,
    this.daysJson = const Value.absent(),
    required DateTime lastUpdated,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       weekStart = Value(weekStart),
       source = Value(source),
       lastUpdated = Value(lastUpdated);
  static Insertable<TrainingPlanRow> custom({
    Expression<String>? id,
    Expression<DateTime>? weekStart,
    Expression<String>? source,
    Expression<String>? daysJson,
    Expression<DateTime>? lastUpdated,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekStart != null) 'week_start': weekStart,
      if (source != null) 'source': source,
      if (daysJson != null) 'days_json': daysJson,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingPlansCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? weekStart,
    Value<String>? source,
    Value<String>? daysJson,
    Value<DateTime>? lastUpdated,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return TrainingPlansCompanion(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      source: source ?? this.source,
      daysJson: daysJson ?? this.daysJson,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<DateTime>(weekStart.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (daysJson.present) {
      map['days_json'] = Variable<String>(daysJson.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingPlansCompanion(')
          ..write('id: $id, ')
          ..write('weekStart: $weekStart, ')
          ..write('source: $source, ')
          ..write('daysJson: $daysJson, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealEntriesTable extends MealEntries
    with TableInfo<$MealEntriesTable, MealEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMillisMeta = const VerificationMeta(
    'timeMillis',
  );
  @override
  late final GeneratedColumn<int> timeMillis = GeneratedColumn<int>(
    'time_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dateKey,
    name,
    calories,
    mealType,
    timeMillis,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('time_millis')) {
      context.handle(
        _timeMillisMeta,
        timeMillis.isAcceptableOrUnknown(data['time_millis']!, _timeMillisMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      )!,
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      timeMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_millis'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $MealEntriesTable createAlias(String alias) {
    return $MealEntriesTable(attachedDatabase, alias);
  }
}

class MealEntryRow extends DataClass implements Insertable<MealEntryRow> {
  final String id;
  final String dateKey;
  final String name;
  final int calories;
  final String mealType;

  /// Meal clock time as epoch millis (device-local: auto tag + log order).
  /// NULL on rows logged before schema v2.
  final int? timeMillis;
  final DateTime? syncedAt;
  const MealEntryRow({
    required this.id,
    required this.dateKey,
    required this.name,
    required this.calories,
    required this.mealType,
    this.timeMillis,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['name'] = Variable<String>(name);
    map['calories'] = Variable<int>(calories);
    map['meal_type'] = Variable<String>(mealType);
    if (!nullToAbsent || timeMillis != null) {
      map['time_millis'] = Variable<int>(timeMillis);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  MealEntriesCompanion toCompanion(bool nullToAbsent) {
    return MealEntriesCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      name: Value(name),
      calories: Value(calories),
      mealType: Value(mealType),
      timeMillis: timeMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(timeMillis),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory MealEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealEntryRow(
      id: serializer.fromJson<String>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      name: serializer.fromJson<String>(json['name']),
      calories: serializer.fromJson<int>(json['calories']),
      mealType: serializer.fromJson<String>(json['mealType']),
      timeMillis: serializer.fromJson<int?>(json['timeMillis']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dateKey': serializer.toJson<String>(dateKey),
      'name': serializer.toJson<String>(name),
      'calories': serializer.toJson<int>(calories),
      'mealType': serializer.toJson<String>(mealType),
      'timeMillis': serializer.toJson<int?>(timeMillis),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  MealEntryRow copyWith({
    String? id,
    String? dateKey,
    String? name,
    int? calories,
    String? mealType,
    Value<int?> timeMillis = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => MealEntryRow(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    name: name ?? this.name,
    calories: calories ?? this.calories,
    mealType: mealType ?? this.mealType,
    timeMillis: timeMillis.present ? timeMillis.value : this.timeMillis,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  MealEntryRow copyWithCompanion(MealEntriesCompanion data) {
    return MealEntryRow(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      name: data.name.present ? data.name.value : this.name,
      calories: data.calories.present ? data.calories.value : this.calories,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      timeMillis: data.timeMillis.present
          ? data.timeMillis.value
          : this.timeMillis,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealEntryRow(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('mealType: $mealType, ')
          ..write('timeMillis: $timeMillis, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dateKey, name, calories, mealType, timeMillis, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealEntryRow &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.name == this.name &&
          other.calories == this.calories &&
          other.mealType == this.mealType &&
          other.timeMillis == this.timeMillis &&
          other.syncedAt == this.syncedAt);
}

class MealEntriesCompanion extends UpdateCompanion<MealEntryRow> {
  final Value<String> id;
  final Value<String> dateKey;
  final Value<String> name;
  final Value<int> calories;
  final Value<String> mealType;
  final Value<int?> timeMillis;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const MealEntriesCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.name = const Value.absent(),
    this.calories = const Value.absent(),
    this.mealType = const Value.absent(),
    this.timeMillis = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealEntriesCompanion.insert({
    required String id,
    required String dateKey,
    required String name,
    required int calories,
    required String mealType,
    this.timeMillis = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dateKey = Value(dateKey),
       name = Value(name),
       calories = Value(calories),
       mealType = Value(mealType);
  static Insertable<MealEntryRow> custom({
    Expression<String>? id,
    Expression<String>? dateKey,
    Expression<String>? name,
    Expression<int>? calories,
    Expression<String>? mealType,
    Expression<int>? timeMillis,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (name != null) 'name': name,
      if (calories != null) 'calories': calories,
      if (mealType != null) 'meal_type': mealType,
      if (timeMillis != null) 'time_millis': timeMillis,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? dateKey,
    Value<String>? name,
    Value<int>? calories,
    Value<String>? mealType,
    Value<int?>? timeMillis,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return MealEntriesCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      mealType: mealType ?? this.mealType,
      timeMillis: timeMillis ?? this.timeMillis,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (timeMillis.present) {
      map['time_millis'] = Variable<int>(timeMillis.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealEntriesCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('mealType: $mealType, ')
          ..write('timeMillis: $timeMillis, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealTargetsTable extends MealTargets
    with TableInfo<$MealTargetsTable, MealTargetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyCaloriesMeta = const VerificationMeta(
    'dailyCalories',
  );
  @override
  late final GeneratedColumn<int> dailyCalories = GeneratedColumn<int>(
    'daily_calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dailyCalories, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_targets';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealTargetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('daily_calories')) {
      context.handle(
        _dailyCaloriesMeta,
        dailyCalories.isAcceptableOrUnknown(
          data['daily_calories']!,
          _dailyCaloriesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyCaloriesMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealTargetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealTargetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dailyCalories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_calories'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $MealTargetsTable createAlias(String alias) {
    return $MealTargetsTable(attachedDatabase, alias);
  }
}

class MealTargetRow extends DataClass implements Insertable<MealTargetRow> {
  final int id;
  final int dailyCalories;
  final DateTime? syncedAt;
  const MealTargetRow({
    required this.id,
    required this.dailyCalories,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['daily_calories'] = Variable<int>(dailyCalories);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  MealTargetsCompanion toCompanion(bool nullToAbsent) {
    return MealTargetsCompanion(
      id: Value(id),
      dailyCalories: Value(dailyCalories),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory MealTargetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealTargetRow(
      id: serializer.fromJson<int>(json['id']),
      dailyCalories: serializer.fromJson<int>(json['dailyCalories']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dailyCalories': serializer.toJson<int>(dailyCalories),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  MealTargetRow copyWith({
    int? id,
    int? dailyCalories,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => MealTargetRow(
    id: id ?? this.id,
    dailyCalories: dailyCalories ?? this.dailyCalories,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  MealTargetRow copyWithCompanion(MealTargetsCompanion data) {
    return MealTargetRow(
      id: data.id.present ? data.id.value : this.id,
      dailyCalories: data.dailyCalories.present
          ? data.dailyCalories.value
          : this.dailyCalories,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealTargetRow(')
          ..write('id: $id, ')
          ..write('dailyCalories: $dailyCalories, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dailyCalories, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealTargetRow &&
          other.id == this.id &&
          other.dailyCalories == this.dailyCalories &&
          other.syncedAt == this.syncedAt);
}

class MealTargetsCompanion extends UpdateCompanion<MealTargetRow> {
  final Value<int> id;
  final Value<int> dailyCalories;
  final Value<DateTime?> syncedAt;
  const MealTargetsCompanion({
    this.id = const Value.absent(),
    this.dailyCalories = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  MealTargetsCompanion.insert({
    this.id = const Value.absent(),
    required int dailyCalories,
    this.syncedAt = const Value.absent(),
  }) : dailyCalories = Value(dailyCalories);
  static Insertable<MealTargetRow> custom({
    Expression<int>? id,
    Expression<int>? dailyCalories,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dailyCalories != null) 'daily_calories': dailyCalories,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  MealTargetsCompanion copyWith({
    Value<int>? id,
    Value<int>? dailyCalories,
    Value<DateTime?>? syncedAt,
  }) {
    return MealTargetsCompanion(
      id: id ?? this.id,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dailyCalories.present) {
      map['daily_calories'] = Variable<int>(dailyCalories.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealTargetsCompanion(')
          ..write('id: $id, ')
          ..write('dailyCalories: $dailyCalories, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $BodyMetricsTable extends BodyMetrics
    with TableInfo<$BodyMetricsTable, BodyMetricRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dateKey,
    weightKg,
    heightCm,
    notes,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'body_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyMetricRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dateKey};
  @override
  BodyMetricRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyMetricRow(
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $BodyMetricsTable createAlias(String alias) {
    return $BodyMetricsTable(attachedDatabase, alias);
  }
}

class BodyMetricRow extends DataClass implements Insertable<BodyMetricRow> {
  final String dateKey;
  final double weightKg;
  final double? heightCm;
  final String? notes;
  final DateTime? syncedAt;
  const BodyMetricRow({
    required this.dateKey,
    required this.weightKg,
    this.heightCm,
    this.notes,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_key'] = Variable<String>(dateKey);
    map['weight_kg'] = Variable<double>(weightKg);
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  BodyMetricsCompanion toCompanion(bool nullToAbsent) {
    return BodyMetricsCompanion(
      dateKey: Value(dateKey),
      weightKg: Value(weightKg),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory BodyMetricRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyMetricRow(
      dateKey: serializer.fromJson<String>(json['dateKey']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      notes: serializer.fromJson<String?>(json['notes']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dateKey': serializer.toJson<String>(dateKey),
      'weightKg': serializer.toJson<double>(weightKg),
      'heightCm': serializer.toJson<double?>(heightCm),
      'notes': serializer.toJson<String?>(notes),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  BodyMetricRow copyWith({
    String? dateKey,
    double? weightKg,
    Value<double?> heightCm = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => BodyMetricRow(
    dateKey: dateKey ?? this.dateKey,
    weightKg: weightKg ?? this.weightKg,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    notes: notes.present ? notes.value : this.notes,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  BodyMetricRow copyWithCompanion(BodyMetricsCompanion data) {
    return BodyMetricRow(
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      notes: data.notes.present ? data.notes.value : this.notes,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyMetricRow(')
          ..write('dateKey: $dateKey, ')
          ..write('weightKg: $weightKg, ')
          ..write('heightCm: $heightCm, ')
          ..write('notes: $notes, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dateKey, weightKg, heightCm, notes, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyMetricRow &&
          other.dateKey == this.dateKey &&
          other.weightKg == this.weightKg &&
          other.heightCm == this.heightCm &&
          other.notes == this.notes &&
          other.syncedAt == this.syncedAt);
}

class BodyMetricsCompanion extends UpdateCompanion<BodyMetricRow> {
  final Value<String> dateKey;
  final Value<double> weightKg;
  final Value<double?> heightCm;
  final Value<String?> notes;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const BodyMetricsCompanion({
    this.dateKey = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.notes = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodyMetricsCompanion.insert({
    required String dateKey,
    required double weightKg,
    this.heightCm = const Value.absent(),
    this.notes = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dateKey = Value(dateKey),
       weightKg = Value(weightKg);
  static Insertable<BodyMetricRow> custom({
    Expression<String>? dateKey,
    Expression<double>? weightKg,
    Expression<double>? heightCm,
    Expression<String>? notes,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateKey != null) 'date_key': dateKey,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
      if (notes != null) 'notes': notes,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodyMetricsCompanion copyWith({
    Value<String>? dateKey,
    Value<double>? weightKg,
    Value<double?>? heightCm,
    Value<String?>? notes,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return BodyMetricsCompanion(
      dateKey: dateKey ?? this.dateKey,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      notes: notes ?? this.notes,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyMetricsCompanion(')
          ..write('dateKey: $dateKey, ')
          ..write('weightKg: $weightKg, ')
          ..write('heightCm: $heightCm, ')
          ..write('notes: $notes, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StrikeStatesTable extends StrikeStates
    with TableInfo<$StrikeStatesTable, StrikeStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StrikeStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentStrikeMeta = const VerificationMeta(
    'currentStrike',
  );
  @override
  late final GeneratedColumn<int> currentStrike = GeneratedColumn<int>(
    'current_strike',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestStrikeMeta = const VerificationMeta(
    'longestStrike',
  );
  @override
  late final GeneratedColumn<int> longestStrike = GeneratedColumn<int>(
    'longest_strike',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastActiveDateKeyMeta = const VerificationMeta(
    'lastActiveDateKey',
  );
  @override
  late final GeneratedColumn<String> lastActiveDateKey =
      GeneratedColumn<String>(
        'last_active_date_key',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _unlockedTiersJsonMeta = const VerificationMeta(
    'unlockedTiersJson',
  );
  @override
  late final GeneratedColumn<String> unlockedTiersJson =
      GeneratedColumn<String>(
        'unlocked_tiers_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentStrike,
    longestStrike,
    lastActiveDateKey,
    unlockedTiersJson,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'strike_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<StrikeStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_strike')) {
      context.handle(
        _currentStrikeMeta,
        currentStrike.isAcceptableOrUnknown(
          data['current_strike']!,
          _currentStrikeMeta,
        ),
      );
    }
    if (data.containsKey('longest_strike')) {
      context.handle(
        _longestStrikeMeta,
        longestStrike.isAcceptableOrUnknown(
          data['longest_strike']!,
          _longestStrikeMeta,
        ),
      );
    }
    if (data.containsKey('last_active_date_key')) {
      context.handle(
        _lastActiveDateKeyMeta,
        lastActiveDateKey.isAcceptableOrUnknown(
          data['last_active_date_key']!,
          _lastActiveDateKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastActiveDateKeyMeta);
    }
    if (data.containsKey('unlocked_tiers_json')) {
      context.handle(
        _unlockedTiersJsonMeta,
        unlockedTiersJson.isAcceptableOrUnknown(
          data['unlocked_tiers_json']!,
          _unlockedTiersJsonMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StrikeStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StrikeStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentStrike: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_strike'],
      )!,
      longestStrike: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest_strike'],
      )!,
      lastActiveDateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_active_date_key'],
      )!,
      unlockedTiersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unlocked_tiers_json'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $StrikeStatesTable createAlias(String alias) {
    return $StrikeStatesTable(attachedDatabase, alias);
  }
}

class StrikeStateRow extends DataClass implements Insertable<StrikeStateRow> {
  final int id;
  final int currentStrike;
  final int longestStrike;
  final String lastActiveDateKey;
  final String unlockedTiersJson;
  final DateTime? syncedAt;
  const StrikeStateRow({
    required this.id,
    required this.currentStrike,
    required this.longestStrike,
    required this.lastActiveDateKey,
    required this.unlockedTiersJson,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_strike'] = Variable<int>(currentStrike);
    map['longest_strike'] = Variable<int>(longestStrike);
    map['last_active_date_key'] = Variable<String>(lastActiveDateKey);
    map['unlocked_tiers_json'] = Variable<String>(unlockedTiersJson);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  StrikeStatesCompanion toCompanion(bool nullToAbsent) {
    return StrikeStatesCompanion(
      id: Value(id),
      currentStrike: Value(currentStrike),
      longestStrike: Value(longestStrike),
      lastActiveDateKey: Value(lastActiveDateKey),
      unlockedTiersJson: Value(unlockedTiersJson),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory StrikeStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StrikeStateRow(
      id: serializer.fromJson<int>(json['id']),
      currentStrike: serializer.fromJson<int>(json['currentStrike']),
      longestStrike: serializer.fromJson<int>(json['longestStrike']),
      lastActiveDateKey: serializer.fromJson<String>(json['lastActiveDateKey']),
      unlockedTiersJson: serializer.fromJson<String>(json['unlockedTiersJson']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentStrike': serializer.toJson<int>(currentStrike),
      'longestStrike': serializer.toJson<int>(longestStrike),
      'lastActiveDateKey': serializer.toJson<String>(lastActiveDateKey),
      'unlockedTiersJson': serializer.toJson<String>(unlockedTiersJson),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  StrikeStateRow copyWith({
    int? id,
    int? currentStrike,
    int? longestStrike,
    String? lastActiveDateKey,
    String? unlockedTiersJson,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => StrikeStateRow(
    id: id ?? this.id,
    currentStrike: currentStrike ?? this.currentStrike,
    longestStrike: longestStrike ?? this.longestStrike,
    lastActiveDateKey: lastActiveDateKey ?? this.lastActiveDateKey,
    unlockedTiersJson: unlockedTiersJson ?? this.unlockedTiersJson,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  StrikeStateRow copyWithCompanion(StrikeStatesCompanion data) {
    return StrikeStateRow(
      id: data.id.present ? data.id.value : this.id,
      currentStrike: data.currentStrike.present
          ? data.currentStrike.value
          : this.currentStrike,
      longestStrike: data.longestStrike.present
          ? data.longestStrike.value
          : this.longestStrike,
      lastActiveDateKey: data.lastActiveDateKey.present
          ? data.lastActiveDateKey.value
          : this.lastActiveDateKey,
      unlockedTiersJson: data.unlockedTiersJson.present
          ? data.unlockedTiersJson.value
          : this.unlockedTiersJson,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StrikeStateRow(')
          ..write('id: $id, ')
          ..write('currentStrike: $currentStrike, ')
          ..write('longestStrike: $longestStrike, ')
          ..write('lastActiveDateKey: $lastActiveDateKey, ')
          ..write('unlockedTiersJson: $unlockedTiersJson, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currentStrike,
    longestStrike,
    lastActiveDateKey,
    unlockedTiersJson,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StrikeStateRow &&
          other.id == this.id &&
          other.currentStrike == this.currentStrike &&
          other.longestStrike == this.longestStrike &&
          other.lastActiveDateKey == this.lastActiveDateKey &&
          other.unlockedTiersJson == this.unlockedTiersJson &&
          other.syncedAt == this.syncedAt);
}

class StrikeStatesCompanion extends UpdateCompanion<StrikeStateRow> {
  final Value<int> id;
  final Value<int> currentStrike;
  final Value<int> longestStrike;
  final Value<String> lastActiveDateKey;
  final Value<String> unlockedTiersJson;
  final Value<DateTime?> syncedAt;
  const StrikeStatesCompanion({
    this.id = const Value.absent(),
    this.currentStrike = const Value.absent(),
    this.longestStrike = const Value.absent(),
    this.lastActiveDateKey = const Value.absent(),
    this.unlockedTiersJson = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  StrikeStatesCompanion.insert({
    this.id = const Value.absent(),
    this.currentStrike = const Value.absent(),
    this.longestStrike = const Value.absent(),
    required String lastActiveDateKey,
    this.unlockedTiersJson = const Value.absent(),
    this.syncedAt = const Value.absent(),
  }) : lastActiveDateKey = Value(lastActiveDateKey);
  static Insertable<StrikeStateRow> custom({
    Expression<int>? id,
    Expression<int>? currentStrike,
    Expression<int>? longestStrike,
    Expression<String>? lastActiveDateKey,
    Expression<String>? unlockedTiersJson,
    Expression<DateTime>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentStrike != null) 'current_strike': currentStrike,
      if (longestStrike != null) 'longest_strike': longestStrike,
      if (lastActiveDateKey != null) 'last_active_date_key': lastActiveDateKey,
      if (unlockedTiersJson != null) 'unlocked_tiers_json': unlockedTiersJson,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  StrikeStatesCompanion copyWith({
    Value<int>? id,
    Value<int>? currentStrike,
    Value<int>? longestStrike,
    Value<String>? lastActiveDateKey,
    Value<String>? unlockedTiersJson,
    Value<DateTime?>? syncedAt,
  }) {
    return StrikeStatesCompanion(
      id: id ?? this.id,
      currentStrike: currentStrike ?? this.currentStrike,
      longestStrike: longestStrike ?? this.longestStrike,
      lastActiveDateKey: lastActiveDateKey ?? this.lastActiveDateKey,
      unlockedTiersJson: unlockedTiersJson ?? this.unlockedTiersJson,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentStrike.present) {
      map['current_strike'] = Variable<int>(currentStrike.value);
    }
    if (longestStrike.present) {
      map['longest_strike'] = Variable<int>(longestStrike.value);
    }
    if (lastActiveDateKey.present) {
      map['last_active_date_key'] = Variable<String>(lastActiveDateKey.value);
    }
    if (unlockedTiersJson.present) {
      map['unlocked_tiers_json'] = Variable<String>(unlockedTiersJson.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StrikeStatesCompanion(')
          ..write('id: $id, ')
          ..write('currentStrike: $currentStrike, ')
          ..write('longestStrike: $longestStrike, ')
          ..write('lastActiveDateKey: $lastActiveDateKey, ')
          ..write('unlockedTiersJson: $unlockedTiersJson, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextRefMeta = const VerificationMeta(
    'contextRef',
  );
  @override
  late final GeneratedColumn<String> contextRef = GeneratedColumn<String>(
    'context_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    content,
    createdAt,
    contextRef,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('context_ref')) {
      context.handle(
        _contextRefMeta,
        contextRef.isAcceptableOrUnknown(data['context_ref']!, _contextRefMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      contextRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_ref'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessageRow extends DataClass implements Insertable<ChatMessageRow> {
  final String id;
  final String role;

  /// Message body (named `content` — `text` collides with Table.text()).
  final String content;
  final DateTime createdAt;
  final String? contextRef;
  final DateTime? syncedAt;
  const ChatMessageRow({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.contextRef,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || contextRef != null) {
      map['context_ref'] = Variable<String>(contextRef);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      role: Value(role),
      content: Value(content),
      createdAt: Value(createdAt),
      contextRef: contextRef == null && nullToAbsent
          ? const Value.absent()
          : Value(contextRef),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory ChatMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessageRow(
      id: serializer.fromJson<String>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      contextRef: serializer.fromJson<String?>(json['contextRef']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'contextRef': serializer.toJson<String?>(contextRef),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  ChatMessageRow copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? createdAt,
    Value<String?> contextRef = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => ChatMessageRow(
    id: id ?? this.id,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    contextRef: contextRef.present ? contextRef.value : this.contextRef,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  ChatMessageRow copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessageRow(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      contextRef: data.contextRef.present
          ? data.contextRef.value
          : this.contextRef,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessageRow(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('contextRef: $contextRef, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, role, content, createdAt, contextRef, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageRow &&
          other.id == this.id &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.contextRef == this.contextRef &&
          other.syncedAt == this.syncedAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessageRow> {
  final Value<String> id;
  final Value<String> role;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<String?> contextRef;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.contextRef = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String role,
    required String content,
    required DateTime createdAt,
    this.contextRef = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatMessageRow> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<String>? contextRef,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (contextRef != null) 'context_ref': contextRef,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? role,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<String?>? contextRef,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      contextRef: contextRef ?? this.contextRef,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (contextRef.present) {
      map['context_ref'] = Variable<String>(contextRef.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('contextRef: $contextRef, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseProgressTable extends ExerciseProgress
    with TableInfo<$ExerciseProgressTable, ExerciseProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoSeenMeta = const VerificationMeta(
    'videoSeen',
  );
  @override
  late final GeneratedColumn<bool> videoSeen = GeneratedColumn<bool>(
    'video_seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("video_seen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [exerciseId, videoSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('video_seen')) {
      context.handle(
        _videoSeenMeta,
        videoSeen.isAcceptableOrUnknown(data['video_seen']!, _videoSeenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseId};
  @override
  ExerciseProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseProgressRow(
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      videoSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}video_seen'],
      )!,
    );
  }

  @override
  $ExerciseProgressTable createAlias(String alias) {
    return $ExerciseProgressTable(attachedDatabase, alias);
  }
}

class ExerciseProgressRow extends DataClass
    implements Insertable<ExerciseProgressRow> {
  final String exerciseId;
  final bool videoSeen;
  const ExerciseProgressRow({
    required this.exerciseId,
    required this.videoSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_id'] = Variable<String>(exerciseId);
    map['video_seen'] = Variable<bool>(videoSeen);
    return map;
  }

  ExerciseProgressCompanion toCompanion(bool nullToAbsent) {
    return ExerciseProgressCompanion(
      exerciseId: Value(exerciseId),
      videoSeen: Value(videoSeen),
    );
  }

  factory ExerciseProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseProgressRow(
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      videoSeen: serializer.fromJson<bool>(json['videoSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseId': serializer.toJson<String>(exerciseId),
      'videoSeen': serializer.toJson<bool>(videoSeen),
    };
  }

  ExerciseProgressRow copyWith({String? exerciseId, bool? videoSeen}) =>
      ExerciseProgressRow(
        exerciseId: exerciseId ?? this.exerciseId,
        videoSeen: videoSeen ?? this.videoSeen,
      );
  ExerciseProgressRow copyWithCompanion(ExerciseProgressCompanion data) {
    return ExerciseProgressRow(
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      videoSeen: data.videoSeen.present ? data.videoSeen.value : this.videoSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseProgressRow(')
          ..write('exerciseId: $exerciseId, ')
          ..write('videoSeen: $videoSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(exerciseId, videoSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseProgressRow &&
          other.exerciseId == this.exerciseId &&
          other.videoSeen == this.videoSeen);
}

class ExerciseProgressCompanion extends UpdateCompanion<ExerciseProgressRow> {
  final Value<String> exerciseId;
  final Value<bool> videoSeen;
  final Value<int> rowid;
  const ExerciseProgressCompanion({
    this.exerciseId = const Value.absent(),
    this.videoSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseProgressCompanion.insert({
    required String exerciseId,
    this.videoSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : exerciseId = Value(exerciseId);
  static Insertable<ExerciseProgressRow> custom({
    Expression<String>? exerciseId,
    Expression<bool>? videoSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (videoSeen != null) 'video_seen': videoSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseProgressCompanion copyWith({
    Value<String>? exerciseId,
    Value<bool>? videoSeen,
    Value<int>? rowid,
  }) {
    return ExerciseProgressCompanion(
      exerciseId: exerciseId ?? this.exerciseId,
      videoSeen: videoSeen ?? this.videoSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (videoSeen.present) {
      map['video_seen'] = Variable<bool>(videoSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseProgressCompanion(')
          ..write('exerciseId: $exerciseId, ')
          ..write('videoSeen: $videoSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(
    this,
  );
  late final $TrainingPlansTable trainingPlans = $TrainingPlansTable(this);
  late final $MealEntriesTable mealEntries = $MealEntriesTable(this);
  late final $MealTargetsTable mealTargets = $MealTargetsTable(this);
  late final $BodyMetricsTable bodyMetrics = $BodyMetricsTable(this);
  late final $StrikeStatesTable strikeStates = $StrikeStatesTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $ExerciseProgressTable exerciseProgress = $ExerciseProgressTable(
    this,
  );
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final PlanDao planDao = PlanDao(this as AppDatabase);
  late final NutritionDao nutritionDao = NutritionDao(this as AppDatabase);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final ChatDao chatDao = ChatDao(this as AppDatabase);
  late final ExerciseDao exerciseDao = ExerciseDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workoutSessions,
    trainingPlans,
    mealEntries,
    mealTargets,
    bodyMetrics,
    strikeStates,
    chatMessages,
    exerciseProgress,
  ];
}

typedef $$WorkoutSessionsTableCreateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      required String id,
      required String workoutId,
      Value<String?> planSessionId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required String status,
      Value<String> exercisesJson,
      Value<String> restJson,
      Value<String?> pausedJson,
      Value<int> durationSec,
      Value<int> totalReps,
      Value<double> avgCadenceRpm,
      Value<double> formAccuracyPct,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$WorkoutSessionsTableUpdateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<String> id,
      Value<String> workoutId,
      Value<String?> planSessionId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String> status,
      Value<String> exercisesJson,
      Value<String> restJson,
      Value<String?> pausedJson,
      Value<int> durationSec,
      Value<int> totalReps,
      Value<double> avgCadenceRpm,
      Value<double> formAccuracyPct,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$WorkoutSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planSessionId => $composableBuilder(
    column: $table.planSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exercisesJson => $composableBuilder(
    column: $table.exercisesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restJson => $composableBuilder(
    column: $table.restJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pausedJson => $composableBuilder(
    column: $table.pausedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalReps => $composableBuilder(
    column: $table.totalReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgCadenceRpm => $composableBuilder(
    column: $table.avgCadenceRpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get formAccuracyPct => $composableBuilder(
    column: $table.formAccuracyPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planSessionId => $composableBuilder(
    column: $table.planSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exercisesJson => $composableBuilder(
    column: $table.exercisesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restJson => $composableBuilder(
    column: $table.restJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pausedJson => $composableBuilder(
    column: $table.pausedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalReps => $composableBuilder(
    column: $table.totalReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgCadenceRpm => $composableBuilder(
    column: $table.avgCadenceRpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get formAccuracyPct => $composableBuilder(
    column: $table.formAccuracyPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workoutId =>
      $composableBuilder(column: $table.workoutId, builder: (column) => column);

  GeneratedColumn<String> get planSessionId => $composableBuilder(
    column: $table.planSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get exercisesJson => $composableBuilder(
    column: $table.exercisesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get restJson =>
      $composableBuilder(column: $table.restJson, builder: (column) => column);

  GeneratedColumn<String> get pausedJson => $composableBuilder(
    column: $table.pausedJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalReps =>
      $composableBuilder(column: $table.totalReps, builder: (column) => column);

  GeneratedColumn<double> get avgCadenceRpm => $composableBuilder(
    column: $table.avgCadenceRpm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get formAccuracyPct => $composableBuilder(
    column: $table.formAccuracyPct,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTable,
          WorkoutSessionRow,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (
            WorkoutSessionRow,
            BaseReferences<
              _$AppDatabase,
              $WorkoutSessionsTable,
              WorkoutSessionRow
            >,
          ),
          WorkoutSessionRow,
          PrefetchHooks Function()
        > {
  $$WorkoutSessionsTableTableManager(
    _$AppDatabase db,
    $WorkoutSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workoutId = const Value.absent(),
                Value<String?> planSessionId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> exercisesJson = const Value.absent(),
                Value<String> restJson = const Value.absent(),
                Value<String?> pausedJson = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> totalReps = const Value.absent(),
                Value<double> avgCadenceRpm = const Value.absent(),
                Value<double> formAccuracyPct = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                id: id,
                workoutId: workoutId,
                planSessionId: planSessionId,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                exercisesJson: exercisesJson,
                restJson: restJson,
                pausedJson: pausedJson,
                durationSec: durationSec,
                totalReps: totalReps,
                avgCadenceRpm: avgCadenceRpm,
                formAccuracyPct: formAccuracyPct,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workoutId,
                Value<String?> planSessionId = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required String status,
                Value<String> exercisesJson = const Value.absent(),
                Value<String> restJson = const Value.absent(),
                Value<String?> pausedJson = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> totalReps = const Value.absent(),
                Value<double> avgCadenceRpm = const Value.absent(),
                Value<double> formAccuracyPct = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                id: id,
                workoutId: workoutId,
                planSessionId: planSessionId,
                startedAt: startedAt,
                endedAt: endedAt,
                status: status,
                exercisesJson: exercisesJson,
                restJson: restJson,
                pausedJson: pausedJson,
                durationSec: durationSec,
                totalReps: totalReps,
                avgCadenceRpm: avgCadenceRpm,
                formAccuracyPct: formAccuracyPct,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutSessionsTable, WorkoutSessionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkoutSessionsTable,
                    WorkoutSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTable,
      WorkoutSessionRow,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (
        WorkoutSessionRow,
        BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSessionRow>,
      ),
      WorkoutSessionRow,
      PrefetchHooks Function()
    >;
typedef $$TrainingPlansTableCreateCompanionBuilder =
    TrainingPlansCompanion Function({
      required String id,
      required DateTime weekStart,
      required String source,
      Value<String> daysJson,
      required DateTime lastUpdated,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$TrainingPlansTableUpdateCompanionBuilder =
    TrainingPlansCompanion Function({
      Value<String> id,
      Value<DateTime> weekStart,
      Value<String> source,
      Value<String> daysJson,
      Value<DateTime> lastUpdated,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$TrainingPlansTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingPlansTable> {
  $$TrainingPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get daysJson => $composableBuilder(
    column: $table.daysJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrainingPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingPlansTable> {
  $$TrainingPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get daysJson => $composableBuilder(
    column: $table.daysJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrainingPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingPlansTable> {
  $$TrainingPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get daysJson =>
      $composableBuilder(column: $table.daysJson, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$TrainingPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingPlansTable,
          TrainingPlanRow,
          $$TrainingPlansTableFilterComposer,
          $$TrainingPlansTableOrderingComposer,
          $$TrainingPlansTableAnnotationComposer,
          $$TrainingPlansTableCreateCompanionBuilder,
          $$TrainingPlansTableUpdateCompanionBuilder,
          (
            TrainingPlanRow,
            BaseReferences<_$AppDatabase, $TrainingPlansTable, TrainingPlanRow>,
          ),
          TrainingPlanRow,
          PrefetchHooks Function()
        > {
  $$TrainingPlansTableTableManager(_$AppDatabase db, $TrainingPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> weekStart = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> daysJson = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingPlansCompanion(
                id: id,
                weekStart: weekStart,
                source: source,
                daysJson: daysJson,
                lastUpdated: lastUpdated,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime weekStart,
                required String source,
                Value<String> daysJson = const Value.absent(),
                required DateTime lastUpdated,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingPlansCompanion.insert(
                id: id,
                weekStart: weekStart,
                source: source,
                daysJson: daysJson,
                lastUpdated: lastUpdated,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrainingPlansTable, TrainingPlanRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TrainingPlansTable,
                    TrainingPlanRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrainingPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingPlansTable,
      TrainingPlanRow,
      $$TrainingPlansTableFilterComposer,
      $$TrainingPlansTableOrderingComposer,
      $$TrainingPlansTableAnnotationComposer,
      $$TrainingPlansTableCreateCompanionBuilder,
      $$TrainingPlansTableUpdateCompanionBuilder,
      (
        TrainingPlanRow,
        BaseReferences<_$AppDatabase, $TrainingPlansTable, TrainingPlanRow>,
      ),
      TrainingPlanRow,
      PrefetchHooks Function()
    >;
typedef $$MealEntriesTableCreateCompanionBuilder =
    MealEntriesCompanion Function({
      required String id,
      required String dateKey,
      required String name,
      required int calories,
      required String mealType,
      Value<int?> timeMillis,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$MealEntriesTableUpdateCompanionBuilder =
    MealEntriesCompanion Function({
      Value<String> id,
      Value<String> dateKey,
      Value<String> name,
      Value<int> calories,
      Value<String> mealType,
      Value<int?> timeMillis,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$MealEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeMillis => $composableBuilder(
    column: $table.timeMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MealEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeMillis => $composableBuilder(
    column: $table.timeMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<int> get timeMillis => $composableBuilder(
    column: $table.timeMillis,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$MealEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealEntriesTable,
          MealEntryRow,
          $$MealEntriesTableFilterComposer,
          $$MealEntriesTableOrderingComposer,
          $$MealEntriesTableAnnotationComposer,
          $$MealEntriesTableCreateCompanionBuilder,
          $$MealEntriesTableUpdateCompanionBuilder,
          (
            MealEntryRow,
            BaseReferences<_$AppDatabase, $MealEntriesTable, MealEntryRow>,
          ),
          MealEntryRow,
          PrefetchHooks Function()
        > {
  $$MealEntriesTableTableManager(_$AppDatabase db, $MealEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> calories = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<int?> timeMillis = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealEntriesCompanion(
                id: id,
                dateKey: dateKey,
                name: name,
                calories: calories,
                mealType: mealType,
                timeMillis: timeMillis,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dateKey,
                required String name,
                required int calories,
                required String mealType,
                Value<int?> timeMillis = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealEntriesCompanion.insert(
                id: id,
                dateKey: dateKey,
                name: name,
                calories: calories,
                mealType: mealType,
                timeMillis: timeMillis,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealEntriesTable, MealEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MealEntriesTable,
                    MealEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MealEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealEntriesTable,
      MealEntryRow,
      $$MealEntriesTableFilterComposer,
      $$MealEntriesTableOrderingComposer,
      $$MealEntriesTableAnnotationComposer,
      $$MealEntriesTableCreateCompanionBuilder,
      $$MealEntriesTableUpdateCompanionBuilder,
      (
        MealEntryRow,
        BaseReferences<_$AppDatabase, $MealEntriesTable, MealEntryRow>,
      ),
      MealEntryRow,
      PrefetchHooks Function()
    >;
typedef $$MealTargetsTableCreateCompanionBuilder =
    MealTargetsCompanion Function({
      Value<int> id,
      required int dailyCalories,
      Value<DateTime?> syncedAt,
    });
typedef $$MealTargetsTableUpdateCompanionBuilder =
    MealTargetsCompanion Function({
      Value<int> id,
      Value<int> dailyCalories,
      Value<DateTime?> syncedAt,
    });

class $$MealTargetsTableFilterComposer
    extends Composer<_$AppDatabase, $MealTargetsTable> {
  $$MealTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyCalories => $composableBuilder(
    column: $table.dailyCalories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MealTargetsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealTargetsTable> {
  $$MealTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyCalories => $composableBuilder(
    column: $table.dailyCalories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealTargetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealTargetsTable> {
  $$MealTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dailyCalories => $composableBuilder(
    column: $table.dailyCalories,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$MealTargetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealTargetsTable,
          MealTargetRow,
          $$MealTargetsTableFilterComposer,
          $$MealTargetsTableOrderingComposer,
          $$MealTargetsTableAnnotationComposer,
          $$MealTargetsTableCreateCompanionBuilder,
          $$MealTargetsTableUpdateCompanionBuilder,
          (
            MealTargetRow,
            BaseReferences<_$AppDatabase, $MealTargetsTable, MealTargetRow>,
          ),
          MealTargetRow,
          PrefetchHooks Function()
        > {
  $$MealTargetsTableTableManager(_$AppDatabase db, $MealTargetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealTargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealTargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dailyCalories = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => MealTargetsCompanion(
                id: id,
                dailyCalories: dailyCalories,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dailyCalories,
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => MealTargetsCompanion.insert(
                id: id,
                dailyCalories: dailyCalories,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealTargetsTable, MealTargetRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MealTargetsTable,
                    MealTargetRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MealTargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealTargetsTable,
      MealTargetRow,
      $$MealTargetsTableFilterComposer,
      $$MealTargetsTableOrderingComposer,
      $$MealTargetsTableAnnotationComposer,
      $$MealTargetsTableCreateCompanionBuilder,
      $$MealTargetsTableUpdateCompanionBuilder,
      (
        MealTargetRow,
        BaseReferences<_$AppDatabase, $MealTargetsTable, MealTargetRow>,
      ),
      MealTargetRow,
      PrefetchHooks Function()
    >;
typedef $$BodyMetricsTableCreateCompanionBuilder =
    BodyMetricsCompanion Function({
      required String dateKey,
      required double weightKg,
      Value<double?> heightCm,
      Value<String?> notes,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$BodyMetricsTableUpdateCompanionBuilder =
    BodyMetricsCompanion Function({
      Value<String> dateKey,
      Value<double> weightKg,
      Value<double?> heightCm,
      Value<String?> notes,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$BodyMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $BodyMetricsTable> {
  $$BodyMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyMetricsTable> {
  $$BodyMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyMetricsTable> {
  $$BodyMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$BodyMetricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyMetricsTable,
          BodyMetricRow,
          $$BodyMetricsTableFilterComposer,
          $$BodyMetricsTableOrderingComposer,
          $$BodyMetricsTableAnnotationComposer,
          $$BodyMetricsTableCreateCompanionBuilder,
          $$BodyMetricsTableUpdateCompanionBuilder,
          (
            BodyMetricRow,
            BaseReferences<_$AppDatabase, $BodyMetricsTable, BodyMetricRow>,
          ),
          BodyMetricRow,
          PrefetchHooks Function()
        > {
  $$BodyMetricsTableTableManager(_$AppDatabase db, $BodyMetricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dateKey = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyMetricsCompanion(
                dateKey: dateKey,
                weightKg: weightKg,
                heightCm: heightCm,
                notes: notes,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dateKey,
                required double weightKg,
                Value<double?> heightCm = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyMetricsCompanion.insert(
                dateKey: dateKey,
                weightKg: weightKg,
                heightCm: heightCm,
                notes: notes,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BodyMetricsTable, BodyMetricRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BodyMetricsTable,
                    BodyMetricRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyMetricsTable,
      BodyMetricRow,
      $$BodyMetricsTableFilterComposer,
      $$BodyMetricsTableOrderingComposer,
      $$BodyMetricsTableAnnotationComposer,
      $$BodyMetricsTableCreateCompanionBuilder,
      $$BodyMetricsTableUpdateCompanionBuilder,
      (
        BodyMetricRow,
        BaseReferences<_$AppDatabase, $BodyMetricsTable, BodyMetricRow>,
      ),
      BodyMetricRow,
      PrefetchHooks Function()
    >;
typedef $$StrikeStatesTableCreateCompanionBuilder =
    StrikeStatesCompanion Function({
      Value<int> id,
      Value<int> currentStrike,
      Value<int> longestStrike,
      required String lastActiveDateKey,
      Value<String> unlockedTiersJson,
      Value<DateTime?> syncedAt,
    });
typedef $$StrikeStatesTableUpdateCompanionBuilder =
    StrikeStatesCompanion Function({
      Value<int> id,
      Value<int> currentStrike,
      Value<int> longestStrike,
      Value<String> lastActiveDateKey,
      Value<String> unlockedTiersJson,
      Value<DateTime?> syncedAt,
    });

class $$StrikeStatesTableFilterComposer
    extends Composer<_$AppDatabase, $StrikeStatesTable> {
  $$StrikeStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStrike => $composableBuilder(
    column: $table.currentStrike,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestStrike => $composableBuilder(
    column: $table.longestStrike,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastActiveDateKey => $composableBuilder(
    column: $table.lastActiveDateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unlockedTiersJson => $composableBuilder(
    column: $table.unlockedTiersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StrikeStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $StrikeStatesTable> {
  $$StrikeStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStrike => $composableBuilder(
    column: $table.currentStrike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestStrike => $composableBuilder(
    column: $table.longestStrike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastActiveDateKey => $composableBuilder(
    column: $table.lastActiveDateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unlockedTiersJson => $composableBuilder(
    column: $table.unlockedTiersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StrikeStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StrikeStatesTable> {
  $$StrikeStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentStrike => $composableBuilder(
    column: $table.currentStrike,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longestStrike => $composableBuilder(
    column: $table.longestStrike,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastActiveDateKey => $composableBuilder(
    column: $table.lastActiveDateKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unlockedTiersJson => $composableBuilder(
    column: $table.unlockedTiersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$StrikeStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StrikeStatesTable,
          StrikeStateRow,
          $$StrikeStatesTableFilterComposer,
          $$StrikeStatesTableOrderingComposer,
          $$StrikeStatesTableAnnotationComposer,
          $$StrikeStatesTableCreateCompanionBuilder,
          $$StrikeStatesTableUpdateCompanionBuilder,
          (
            StrikeStateRow,
            BaseReferences<_$AppDatabase, $StrikeStatesTable, StrikeStateRow>,
          ),
          StrikeStateRow,
          PrefetchHooks Function()
        > {
  $$StrikeStatesTableTableManager(_$AppDatabase db, $StrikeStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StrikeStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StrikeStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StrikeStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentStrike = const Value.absent(),
                Value<int> longestStrike = const Value.absent(),
                Value<String> lastActiveDateKey = const Value.absent(),
                Value<String> unlockedTiersJson = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => StrikeStatesCompanion(
                id: id,
                currentStrike: currentStrike,
                longestStrike: longestStrike,
                lastActiveDateKey: lastActiveDateKey,
                unlockedTiersJson: unlockedTiersJson,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentStrike = const Value.absent(),
                Value<int> longestStrike = const Value.absent(),
                required String lastActiveDateKey,
                Value<String> unlockedTiersJson = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
              }) => StrikeStatesCompanion.insert(
                id: id,
                currentStrike: currentStrike,
                longestStrike: longestStrike,
                lastActiveDateKey: lastActiveDateKey,
                unlockedTiersJson: unlockedTiersJson,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StrikeStatesTable, StrikeStateRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StrikeStatesTable,
                    StrikeStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StrikeStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StrikeStatesTable,
      StrikeStateRow,
      $$StrikeStatesTableFilterComposer,
      $$StrikeStatesTableOrderingComposer,
      $$StrikeStatesTableAnnotationComposer,
      $$StrikeStatesTableCreateCompanionBuilder,
      $$StrikeStatesTableUpdateCompanionBuilder,
      (
        StrikeStateRow,
        BaseReferences<_$AppDatabase, $StrikeStatesTable, StrikeStateRow>,
      ),
      StrikeStateRow,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required String role,
      required String content,
      required DateTime createdAt,
      Value<String?> contextRef,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<String> role,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<String?> contextRef,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextRef => $composableBuilder(
    column: $table.contextRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextRef => $composableBuilder(
    column: $table.contextRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get contextRef => $composableBuilder(
    column: $table.contextRef,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessageRow,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessageRow,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessageRow>,
          ),
          ChatMessageRow,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> contextRef = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                role: role,
                content: content,
                createdAt: createdAt,
                contextRef: contextRef,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String role,
                required String content,
                required DateTime createdAt,
                Value<String?> contextRef = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                role: role,
                content: content,
                createdAt: createdAt,
                contextRef: contextRef,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessageRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatMessagesTable,
                    ChatMessageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessageRow,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessageRow,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessageRow>,
      ),
      ChatMessageRow,
      PrefetchHooks Function()
    >;
typedef $$ExerciseProgressTableCreateCompanionBuilder =
    ExerciseProgressCompanion Function({
      required String exerciseId,
      Value<bool> videoSeen,
      Value<int> rowid,
    });
typedef $$ExerciseProgressTableUpdateCompanionBuilder =
    ExerciseProgressCompanion Function({
      Value<String> exerciseId,
      Value<bool> videoSeen,
      Value<int> rowid,
    });

class $$ExerciseProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseProgressTable> {
  $$ExerciseProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get videoSeen => $composableBuilder(
    column: $table.videoSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseProgressTable> {
  $$ExerciseProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get videoSeen => $composableBuilder(
    column: $table.videoSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseProgressTable> {
  $$ExerciseProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get videoSeen =>
      $composableBuilder(column: $table.videoSeen, builder: (column) => column);
}

class $$ExerciseProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseProgressTable,
          ExerciseProgressRow,
          $$ExerciseProgressTableFilterComposer,
          $$ExerciseProgressTableOrderingComposer,
          $$ExerciseProgressTableAnnotationComposer,
          $$ExerciseProgressTableCreateCompanionBuilder,
          $$ExerciseProgressTableUpdateCompanionBuilder,
          (
            ExerciseProgressRow,
            BaseReferences<
              _$AppDatabase,
              $ExerciseProgressTable,
              ExerciseProgressRow
            >,
          ),
          ExerciseProgressRow,
          PrefetchHooks Function()
        > {
  $$ExerciseProgressTableTableManager(
    _$AppDatabase db,
    $ExerciseProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> exerciseId = const Value.absent(),
                Value<bool> videoSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseProgressCompanion(
                exerciseId: exerciseId,
                videoSeen: videoSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String exerciseId,
                Value<bool> videoSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseProgressCompanion.insert(
                exerciseId: exerciseId,
                videoSeen: videoSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExerciseProgressTable, ExerciseProgressRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ExerciseProgressTable,
                    ExerciseProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseProgressTable,
      ExerciseProgressRow,
      $$ExerciseProgressTableFilterComposer,
      $$ExerciseProgressTableOrderingComposer,
      $$ExerciseProgressTableAnnotationComposer,
      $$ExerciseProgressTableCreateCompanionBuilder,
      $$ExerciseProgressTableUpdateCompanionBuilder,
      (
        ExerciseProgressRow,
        BaseReferences<
          _$AppDatabase,
          $ExerciseProgressTable,
          ExerciseProgressRow
        >,
      ),
      ExerciseProgressRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$TrainingPlansTableTableManager get trainingPlans =>
      $$TrainingPlansTableTableManager(_db, _db.trainingPlans);
  $$MealEntriesTableTableManager get mealEntries =>
      $$MealEntriesTableTableManager(_db, _db.mealEntries);
  $$MealTargetsTableTableManager get mealTargets =>
      $$MealTargetsTableTableManager(_db, _db.mealTargets);
  $$BodyMetricsTableTableManager get bodyMetrics =>
      $$BodyMetricsTableTableManager(_db, _db.bodyMetrics);
  $$StrikeStatesTableTableManager get strikeStates =>
      $$StrikeStatesTableTableManager(_db, _db.strikeStates);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$ExerciseProgressTableTableManager get exerciseProgress =>
      $$ExerciseProgressTableTableManager(_db, _db.exerciseProgress);
}
