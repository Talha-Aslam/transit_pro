import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/language_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class DriverSearchScreen extends StatefulWidget {
  final String pickupAddress;
  final String dropAddress;
  final Function(Map<String, String>) onDriverSelected;

  const DriverSearchScreen({
    super.key,
    required this.pickupAddress,
    required this.dropAddress,
    required this.onDriverSelected,
  });

  @override
  State<DriverSearchScreen> createState() => _DriverSearchScreenState();
}

class _DriverSearchScreenState extends State<DriverSearchScreen> {
  String _sortBy = 'rating'; // rating, distance, price
  bool _loading = true;
  late List<_AvailableDriver> _drivers;

  @override
  void initState() {
    super.initState();
    LanguageProvider.instance.addListener(_onLangChanged);
    _simulateSearching();
  }

  @override
  void dispose() {
    LanguageProvider.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  void _simulateSearching() {
    Future.delayed(const Duration(seconds: 2), () {
      _drivers = [
        _AvailableDriver(
          id: 'driver_1',
          name: 'Muhammad Tariq',
          busNumber: 'Bus #42',
          vehicleType: 'Bus',
          rating: 4.8,
          reviews: 342,
          monthlyFee: 'Rs. 4,500',
          distance: '2.3 km',
          etaPickup: '8 mins',
          seats: 5,
          verified: true,
          image: '🚌',
        ),
        _AvailableDriver(
          id: 'driver_2',
          name: 'Ali Hassan',
          busNumber: 'Van #15',
          vehicleType: 'Van',
          rating: 4.6,
          reviews: 187,
          monthlyFee: 'Rs. 3,800',
          distance: '3.1 km',
          etaPickup: '12 mins',
          seats: 4,
          verified: true,
          image: '🚐',
        ),
        _AvailableDriver(
          id: 'driver_3',
          name: 'Fatima Khan',
          busNumber: 'Bus #28',
          vehicleType: 'Bus',
          rating: 4.9,
          reviews: 520,
          monthlyFee: 'Rs. 5,200',
          distance: '1.8 km',
          etaPickup: '5 mins',
          seats: 6,
          verified: true,
          image: '🚌',
        ),
      ];
      _sortDrivers();
      if (mounted) setState(() => _loading = false);
    });
  }

  void _sortDrivers() {
    switch (_sortBy) {
      case 'distance':
        _drivers.sort(
          (a, b) => int.parse(
            a.distance.split(' ')[0],
          ).compareTo(int.parse(b.distance.split(' ')[0])),
        );
        break;
      case 'price':
        _drivers.sort(
          (a, b) => int.parse(
            a.monthlyFee.replaceAll(RegExp(r'[^\d]'), ''),
          ).compareTo(int.parse(b.monthlyFee.replaceAll(RegExp(r'[^\d]'), ''))),
        );
        break;
      case 'rating':
      default:
        _drivers.sort((a, b) => b.rating.compareTo(a.rating));
    }
  }

  void _selectDriver(_AvailableDriver driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DriverConfirmSheet(
        driver: driver,
        pickup: widget.pickupAddress,
        drop: widget.dropAddress,
        onConfirm: () {
          widget.onDriverSelected({
            'id': driver.id,
            'name': driver.name,
            'busNumber': driver.busNumber,
            'fee': driver.monthlyFee,
          });
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: context.scaffoldBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.parentPurple.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.cardBgElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Drivers',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Select a driver for your child',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Sort options ──────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _SortChip(
                      label: 'Best Rating',
                      active: _sortBy == 'rating',
                      onTap: () {
                        setState(() => _sortBy = 'rating');
                        _sortDrivers();
                      },
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Nearest',
                      active: _sortBy == 'distance',
                      onTap: () {
                        setState(() => _sortBy = 'distance');
                        _sortDrivers();
                      },
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: 'Lowest Price',
                      active: _sortBy == 'price',
                      onTap: () {
                        setState(() => _sortBy = 'price');
                        _sortDrivers();
                      },
                    ),
                  ],
                ),
              ),

              // ── Driver list ────────────────────────────────────────────────
              if (_loading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.parentPurple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  AppTheme.parentPurple,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Finding available drivers...',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_drivers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('😞', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No drivers available',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your location or time',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: _drivers.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DriverCard(
                        driver: _drivers[i],
                        onSelect: () => _selectDriver(_drivers[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final _AvailableDriver driver;
  final VoidCallback onSelect;

  const _DriverCard({required this.driver, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.surfaceBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(driver.image, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            driver.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (driver.verified)
                            const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.success,
                              size: 16,
                            ),
                        ],
                      ),
                      Text(
                        driver.busNumber,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.parentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        driver.rating.toString(),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: '📍',
                    label: 'Distance',
                    value: driver.distance,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: '⏱️',
                    label: 'Pickup',
                    value: driver.etaPickup,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: '💰',
                    label: 'Monthly',
                    value: driver.monthlyFee,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: context.textTertiary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.parentPurple : context.cardBgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.transparent : context.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : context.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DriverConfirmSheet extends StatelessWidget {
  final _AvailableDriver driver;
  final String pickup;
  final String drop;
  final VoidCallback onConfirm;

  const _DriverConfirmSheet({
    required this.driver,
    required this.pickup,
    required this.drop,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.surfaceBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm Driver',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(driver.image, style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              driver.busNumber,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ConfirmRow('Vehicle Type', driver.vehicleType),
                  const SizedBox(height: 10),
                  _ConfirmRow('Monthly Fee', driver.monthlyFee),
                  const SizedBox(height: 10),
                  _ConfirmRow(
                    'Rating',
                    '${driver.rating} (${driver.reviews} reviews)',
                  ),
                  const SizedBox(height: 10),
                  _ConfirmRow('ETA to Pickup', driver.etaPickup),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journey Details',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.parentPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('📍', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pickup,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🏫', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          drop,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onConfirm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.parentPurple, AppTheme.parentAccent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Confirm & Send Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.cardBgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.surfaceBorder),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableDriver {
  final String id;
  final String name;
  final String busNumber;
  final String vehicleType;
  final double rating;
  final int reviews;
  final String monthlyFee;
  final String distance;
  final String etaPickup;
  final int seats;
  final bool verified;
  final String image;

  _AvailableDriver({
    required this.id,
    required this.name,
    required this.busNumber,
    required this.vehicleType,
    required this.rating,
    required this.reviews,
    required this.monthlyFee,
    required this.distance,
    required this.etaPickup,
    required this.seats,
    required this.verified,
    required this.image,
  });
}
