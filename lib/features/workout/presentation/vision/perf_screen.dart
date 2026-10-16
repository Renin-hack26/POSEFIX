import 'package:flutter/material.dart';
import 'package:graphify/graphify.dart';

import 'perf_telemetry.dart';

/// Performance charts (round-9): UI build/raster ms, ML Kit inference ms and
/// pipeline FPS over the current/last session, rendered with Apache ECharts
/// (graphify WebView). Opened by long-pressing the pipeline status strip.
class PerfScreen extends StatefulWidget {
  const PerfScreen({super.key});

  @override
  State<PerfScreen> createState() => _PerfScreenState();
}

class _PerfScreenState extends State<PerfScreen> {
  final GraphifyController _controller = GraphifyController();
  bool _attached = false;

  @override
  void initState() {
    super.initState();
    PerfTelemetry.instance.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    PerfTelemetry.instance.revision.removeListener(_refresh);
    if (_attached) _controller.dispose();
    super.dispose();
  }

  /// The WebView finished loading — safe to push chart options from here on.
  void _onCreated() {
    _attached = true;
    _refresh();
  }

  void _refresh() {
    if (!_attached) return;
    final samples = PerfTelemetry.instance.samples;
    if (samples.isEmpty) return;
    _controller.update(_option(samples));
  }

  Map<String, dynamic> _option(List<PerfSample> all) {
    // Last ~3 minutes of samples.
    final samples =
        all.length > 180 ? all.sublist(all.length - 180) : all;
    return {
      'backgroundColor': 'transparent',
      'animation': false,
      'tooltip': {'trigger': 'axis'},
      'legend': {
        'top': 0,
        'textStyle': {'color': '#9AA7B4', 'fontSize': 11},
      },
      'grid': {'left': 44, 'right': 44, 'top': 32, 'bottom': 24},
      'xAxis': {
        'type': 'category',
        'data': [for (final s in samples) '${s.tSec.toStringAsFixed(0)}s'],
        'axisLabel': {'color': '#9AA7B4', 'fontSize': 10},
      },
      'yAxis': [
        {
          'type': 'value',
          'name': 'ms',
          'nameTextStyle': {'color': '#9AA7B4', 'fontSize': 10},
          'axisLabel': {'color': '#9AA7B4', 'fontSize': 10},
          'splitLine': {
            'lineStyle': {'color': '#26313D'},
          },
        },
        {
          'type': 'value',
          'name': 'fps',
          'nameTextStyle': {'color': '#9AA7B4', 'fontSize': 10},
          'axisLabel': {'color': '#9AA7B4', 'fontSize': 10},
          'splitLine': {'show': false},
        },
      ],
      'series': [
        _line('UI build', [for (final s in samples) s.uiBuildMs], '#4FC3F7', 0),
        _line('Raster', [for (final s in samples) s.uiRasterMs], '#9575CD', 0),
        _line('ML Kit', [for (final s in samples) s.inferMs], '#FFB74D', 0),
        _line('FPS', [for (final s in samples) s.fps], '#81C784', 1),
      ],
    };
  }

  Map<String, dynamic> _line(
    String name,
    List<double> data,
    String color,
    int axis,
  ) =>
      {
        'name': name,
        'type': 'line',
        'showSymbol': false,
        'smooth': true,
        'yAxisIndex': axis,
        'itemStyle': {'color': color},
        'lineStyle': {'width': 2},
        'data': [for (final v in data) _r(v)],
      };

  /// ECharts chokes on NaN/Infinity — clamp every series point.
  static double _r(double v) =>
      v.isFinite ? double.parse(v.toStringAsFixed(2)) : 0;

  @override
  Widget build(BuildContext context) {
    final samples = PerfTelemetry.instance.samples;
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: samples.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No samples yet. Start a vision session — health samples '
                  'land here once per second while it runs.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _statsLine(samples),
                ),
                Expanded(
                  child: GraphifyView(
                    controller: _controller,
                    initialOptions: _option(samples),
                    onCreated: _onCreated,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'UI build · Raster · ML Kit (ms) / Pipeline FPS — charted live',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statsLine(List<PerfSample> samples) {
    double avg(double Function(PerfSample) get) {
      var sum = 0.0;
      for (final s in samples) {
        sum += get(s);
      }
      return samples.isEmpty ? 0 : sum / samples.length;
    }

    double p95(double Function(PerfSample) get) {
      if (samples.isEmpty) return 0;
      final xs = [for (final s in samples) get(s)]..sort();
      return xs[((xs.length - 1) * 0.95).round()];
    }

    final last = samples.last;
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodySmall ??
          const TextStyle(fontSize: 12),
      child: Row(
        children: [
          Expanded(
            child: Text('ML Kit avg ${avg((s) => s.inferMs).toStringAsFixed(0)}'
                ' · p95 ${p95((s) => s.inferMs).toStringAsFixed(0)} ms'),
          ),
          Expanded(
            child: Text('UI ${avg((s) => s.uiBuildMs).toStringAsFixed(1)}'
                ' · raster ${avg((s) => s.uiRasterMs).toStringAsFixed(1)} ms'),
          ),
          Expanded(
            child: Text(
                '${avg((s) => s.fps).toStringAsFixed(1)} fps'
                ' · ${last.throttled} capped'
                ' · ${last.poses} pose${last.poses == 1 ? '' : 's'}'),
          ),
        ],
      ),
    );
  }
}
