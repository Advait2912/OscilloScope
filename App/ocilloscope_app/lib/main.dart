import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';

void main() => runApp(OscilloscopeApp());

class OscilloscopeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Oscilloscope',
      theme: ThemeData.dark(),
      home: OscilloscopeScreen(),
    );
  }
}

class OscilloscopeScreen extends StatefulWidget {
  @override
  _OscilloscopeScreenState createState() => _OscilloscopeScreenState();
}

class _OscilloscopeScreenState extends State<OscilloscopeScreen> {
  static const int bufferSize = 16384;
  static const int chunkSize = 2048;
  static const int drawLimit = 2000;
  static const int totalChunks = 8;
  static const double referenceVoltage = 3.3;
  static const double maxDisplayVoltage = 6.0;

  final Color lineColor = Colors.cyanAccent;
  final Color gridColor = Colors.grey;
  final Color borderColor = Colors.grey;
  final Color backgroundColor = Colors.black;
  final Color textColor = Colors.white;

  late List<List<FlSpot>> graphChunks;
  int currentChunkIndex = 0;
  Socket? socket;
  late Timer animationTimer;
  bool isConnected = false;
  bool isReceiving = false;
  double viewMinX = 0;
  double viewMaxX = drawLimit.toDouble();

  @override
  void initState() {
    super.initState();
    graphChunks = List.generate(
      totalChunks,
      (_) => List.generate(chunkSize, (i) => FlSpot(i.toDouble(), 0)),
    );
    connectToESP();
    startGraphLoop();
  }

  void connectToESP() async {
    try {
      socket = await Socket.connect('192.168.4.1', 80);
      print('Connected to ESP32');
      setState(() => isConnected = true);
      receiveData();
    } catch (e) {
      print('Connection failed: $e');
      setState(() => isConnected = false);
      Future.delayed(Duration(seconds: 3), connectToESP);
    }
  }

  void receiveData() async {
    if (socket == null) return;

    final fullBuffer = ByteData(bufferSize * 2);
    int offset = 0;
    isReceiving = true;

    try {
      await for (var data in socket!) {
        for (int byte in data) {
          if (offset < fullBuffer.lengthInBytes) {
            fullBuffer.setUint8(offset++, byte);
          }
          if (offset >= bufferSize * 2) {
            updateGraphFromData(fullBuffer);
            offset = 0;
            break;
          }
        }
      }
    } catch (e) {
      print('Data receive error: $e');
      setState(() => isReceiving = isConnected = false);
      connectToESP();
    }
  }

  List<double> smoothReadings(List<double> values, int windowSize) {
    List<double> smoothed = [];
    for (int i = 0; i < values.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = i - windowSize ~/ 2; j <= i + windowSize ~/ 2; j++) {
        if (j >= 0 && j < values.length) {
          sum += values[j];
          count++;
        }
      }
      smoothed.add(sum / count);
    }
    return smoothed;
  }

  void updateGraphFromData(ByteData data) {
    final newChunks = List.generate(totalChunks, (_) => <FlSpot>[]);
    for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      List<double> rawValues = [];
      for (int i = 0; i < chunkSize; i++) {
        final index = chunkIndex * chunkSize + i;
        final value = data.getUint16(index * 2, Endian.little);
        rawValues.add((value * referenceVoltage) / 4095.0);
      }
      final smoothed = smoothReadings(rawValues, 5);
      for (int i = 0; i < chunkSize; i++) {
        final y = smoothed[i] * (6.0 / maxDisplayVoltage);
        newChunks[chunkIndex].add(FlSpot(i.toDouble(), y));
      }
    }
    setState(() => graphChunks = newChunks);
  }

  void startGraphLoop() {
    animationTimer = Timer.periodic(Duration(milliseconds: 125), (_) {
      setState(() => currentChunkIndex = (currentChunkIndex + 1) % totalChunks);
    });
  }

  LineChartData getChartData(List<FlSpot> spots) {
    final visibleSpots = spots.take(drawLimit).toList();
    return LineChartData(
      backgroundColor: backgroundColor,
      lineTouchData: LineTouchData(enabled: true),
      lineBarsData: [
        LineChartBarData(
          spots: visibleSpots,
          isCurved: false,
          color: lineColor,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        show: true,
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(1),
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 500,
            reservedSize: 22,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: gridColor.withOpacity(0.3), strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            FlLine(color: gridColor.withOpacity(0.3), strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
      ),
      minX: viewMinX,
      maxX: viewMaxX,
      minY: 0,
      maxY: 6,
    );
  }

  @override
  void dispose() {
    socket?.close();
    animationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Oscilloscope', style: TextStyle(color: textColor)),
        backgroundColor: Colors.grey[900],
      ),
      body: GestureDetector(
        onScaleUpdate: (details) {
          final scale = details.scale;
          setState(() {
            final center = (viewMinX + viewMaxX) / 2;
            final range = (viewMaxX - viewMinX) / scale;
            viewMinX = (center - range / 2).clamp(0.0, drawLimit.toDouble());
            viewMaxX = (center + range / 2).clamp(0.0, drawLimit.toDouble());
            if (viewMinX < 0) viewMinX = 0;
            if (viewMaxX > drawLimit) viewMaxX = drawLimit.toDouble();
          });
        },
        onHorizontalDragUpdate: (details) {
          setState(() {
            double delta = details.primaryDelta ?? 0;
            double shift = delta * -3;
            viewMinX = (viewMinX + shift).clamp(
              0.0,
              drawLimit.toDouble() - (viewMaxX - viewMinX),
            );
            viewMaxX = viewMinX + (viewMaxX - viewMinX);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(getChartData(graphChunks[currentChunkIndex])),
        ),
      ),
    );
  }
}
