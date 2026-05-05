import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../../providers.dart';
import '../../../../services/location_service.dart';
import '../../../../services/clock_in_service.dart';
import '../../../../shifts_provider.dart';
import '../../../shifts/domain/shift_model.dart';

class ClockInScreen extends ConsumerStatefulWidget {
  final String shiftId;

  const ClockInScreen({super.key, required this.shiftId});

  @override
  ConsumerState<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends ConsumerState<ClockInScreen> {
  final _mapController = MapController();
  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isClockingIn = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final locationService = ref.read(locationServiceProvider);
    final hasPermission = await locationService.checkPermission();

    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Байршлын эрх олгдоогүй байна. Тохиргооноос идэвхжүүлээ үү.';
      });
      return;
    }

    final position = await locationService.getCurrentPosition();

    if (position == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Байршил авахад алдаа гарлаа. Дахин оролдоно уу.';
      });
      return;
    }

    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    _mapController.move(lat.LatLng(position.latitude, position.longitude), 17);
  }

  Future<void> _clockIn(ShiftModel shift) async {
    if (_currentPosition == null || shift.workLocation == null) return;

    setState(() => _isClockingIn = true);

    final user = ref.read(authProvider).user;
    final locationService = ref.read(locationServiceProvider);

    final distance = locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      shift.workLocation!.latitude,
      shift.workLocation!.longitude,
    );

    final isOnSite = distance <= shift.workLocation!.radiusMeters;

    if (!isOnSite) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Та бүртгүүлэх боломжтой байршлын бусад орлоо: ${locationService.formatDistance(distance)}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      setState(() => _isClockingIn = false);
      return;
    }

    try {
      final clockInService = ref.read(clockInServiceProvider);
      await clockInService.clockIn(
        shiftId: shift.id,
        workerId: user?.id ?? '',
        position: _currentPosition!,
        workLocation: shift.workLocation!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Амжилттай бүртгэгдлээ!'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алда��: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClockingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(shiftsProvider);
    final shift = shifts.where((s) => s.id == widget.shiftId).firstOrNull;

    if (shift == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Цаг бүртгэл')),
        body: const Center(child: Text('Ийм ээлж олдсонгүй')),
      );
    }

    if (shift.workLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Цаг бүртгэл')),
        body: const Center(child: Text('Энэ цагт байршил тохируулаагүй байна')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/dashboard');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Цаг бүртгэл'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/dashboard'),
          ),
        ),
        body: Column(
          children: [
            _buildShiftInfo(shift),
            Expanded(child: _buildMap(shift)),
            _buildStatusBar(shift),
            _buildClockInButton(shift),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftInfo(ShiftModel shift) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.role,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date_utils.DateTimeUtils.formatDate(shift.date)} ${date_utils.DateTimeUtils.formatTimeRange(shift.startTime, shift.endTime)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${shift.workLocation!.radiusMeters}м',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(ShiftModel shift) {
    final workLatLng = lat.LatLng(shift.workLocation!.latitude, shift.workLocation!.longitude);
    final currentLatLng = _currentPosition != null
        ? lat.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : workLatLng;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: currentLatLng, initialZoom: 17),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.shiftmate.app',
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: workLatLng,
                  radius: shift.workLocation!.radiusMeters.toDouble(),
                  useRadiusInMeter: true,
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                  borderColor: AppTheme.accentColor,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: workLatLng,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: AppTheme.accentColor, size: 40),
                ),
                if (_currentPosition != null)
                  Marker(
                    point: currentLatLng,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        if (_errorMessage != null)
          Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            onPressed: _initLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(ShiftModel shift) {
    if (_currentPosition == null || shift.workLocation == null) {
      return const SizedBox.shrink();
    }

    final locationService = ref.read(locationServiceProvider);
    final distance = locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      shift.workLocation!.latitude,
      shift.workLocation!.longitude,
    );

    final isInside = distance <= shift.workLocation!.radiusMeters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isInside ? AppTheme.accentColor : AppTheme.errorColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isInside ? Icons.check_circle : Icons.cancel, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            isInside
                ? 'Байршлийн дотор байна'
                : 'Байршлаас гадна: ${locationService.formatDistance(distance)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildClockInButton(ShiftModel shift) {
    final isInside = _currentPosition != null && shift.workLocation != null
        ? ref.read(locationServiceProvider).calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            shift.workLocation!.latitude,
            shift.workLocation!.longitude,
          ) <= shift.workLocation!.radiusMeters
        : false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: (_currentPosition != null && isInside && !_isClockingIn)
                ? () => _clockIn(shift)
                : null,
            icon: _isClockingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.access_time),
            label: Text(_isClockingIn ? 'Бүртгэж байна...' : 'Цаг бүртгэх'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.textLight,
            ),
          ),
        ),
      ),
    );
  }
}