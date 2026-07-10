import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const driverOAuthRedirectUrl = 'https://flovi-driver-app.vercel.app/';
const isSupabaseConfigured = supabaseUrl != '' && supabaseAnonKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flovi Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: FloviColors.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FloviColors.mint,
          brightness: Brightness.dark,
        ),
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
              fontFamily: 'Inter',
            ),
      ),
      home: const DriverHomePage(),
    );
  }
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  Session? _session;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _requestsChannel;

  var _selectedTab = DriverTab.available;
  var _isLoading = false;
  var _bookingRequestId = '';
  String? _authError;
  String? _workflowError;
  List<RelocationRequest> _availableGigs = [];
  List<RelocationRequest> _bookedGigs = [];

  SupabaseClient? get _client {
    if (!isSupabaseConfigured) {
      return null;
    }

    return Supabase.instance.client;
  }

  @override
  void initState() {
    super.initState();

    final client = _client;
    if (client == null) {
      return;
    }

    _session = client.auth.currentSession;
    if (_session != null) {
      unawaited(_loadGigs());
      _startRealtime();
    }

    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      if (!mounted) {
        return;
      }

      setState(() {
        _session = data.session;
        _authError = null;
        _workflowError = null;
      });

      if (data.session == null) {
        _stopRealtime();
        setState(() {
          _availableGigs = [];
          _bookedGigs = [];
          _selectedTab = DriverTab.available;
        });
      } else {
        unawaited(_loadGigs());
        _startRealtime();
      }
    });
  }

  @override
  void dispose() {
    _stopRealtime();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final client = _client;

    if (client == null) {
      setState(() {
        _authError = 'Add SUPABASE_URL and SUPABASE_ANON_KEY dart defines before signing in.';
      });
      return;
    }

    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: driverOAuthRedirectUrl,
      );
    } on AuthException catch (error) {
      setState(() {
        _authError = error.message;
      });
    } catch (error) {
      setState(() {
        _authError = 'Google sign-in failed: $error';
      });
    }
  }

  Future<void> _signOut() async {
    final client = _client;
    if (client == null) {
      return;
    }

    await client.auth.signOut();
  }

  Future<void> _loadGigs() async {
    final client = _client;
    final userId = _session?.user.id;

    if (client == null || userId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _workflowError = null;
    });

    try {
      final availableRows = await client
          .from('relocation_requests')
          .select(_requestColumns)
          .eq('status', 'available')
          .order('move_date');

      final bookedRows = await client
          .from('relocation_requests')
          .select(_requestColumns)
          .eq('driver_id', userId)
          .order('booked_at', ascending: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _availableGigs = _parseRequests(availableRows);
        _bookedGigs = _parseRequests(bookedRows);
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _workflowError = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _workflowError = 'Could not load gigs: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startRealtime() {
    final client = _client;
    if (client == null || _requestsChannel != null) {
      return;
    }

    _requestsChannel = client
        .channel('driver-relocation-requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'relocation_requests',
          callback: (_) {
            unawaited(_loadGigs());
          },
        )
        .subscribe();
  }

  void _stopRealtime() {
    final client = _client;
    final channel = _requestsChannel;

    if (client == null || channel == null) {
      return;
    }

    unawaited(client.removeChannel(channel));
    _requestsChannel = null;
  }

  Future<void> _confirmBooking(RelocationRequest request) async {
    final shouldBook = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingSheet(request: request),
    );

    if (shouldBook == true) {
      await _bookGig(request);
    }
  }

  Future<void> _bookGig(RelocationRequest request) async {
    final client = _client;

    if (client == null || _session == null) {
      return;
    }

    setState(() {
      _bookingRequestId = request.id;
      _workflowError = null;
    });

    try {
      final response = await client.rpc(
        'book_relocation_request',
        params: {'request_id': request.id},
      );
      final result = _parseRpcResult(response);
      final success = result['success'] == true;
      final message = result['message']?.toString() ?? 'Booking failed.';

      if (!success) {
        setState(() {
          _workflowError = message;
        });
      } else {
        setState(() {
          _selectedTab = DriverTab.booked;
        });
        await _loadGigs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: FloviColors.violet,
            ),
          );
        }
      }
    } on PostgrestException catch (error) {
      setState(() {
        _workflowError = error.message;
      });
    } catch (error) {
      setState(() {
        _workflowError = 'Could not book this gig: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _bookingRequestId = '';
        });
      }
    }
  }

  List<RelocationRequest> _parseRequests(dynamic response) {
    final rows = response as List<dynamic>;
    return rows
        .map((row) => RelocationRequest.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Map<String, dynamic> _parseRpcResult(dynamic response) {
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return {
      'success': false,
      'message': 'Booking did not return a result.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = _session?.user;
    final displayName = user?.userMetadata?['full_name']?.toString() ?? user?.email ?? 'Driver';
    final visibleGigs = _selectedTab == DriverTab.available ? _availableGigs : _bookedGigs;

    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: RefreshIndicator(
              color: FloviColors.mint,
              backgroundColor: FloviColors.ink,
              onRefresh: _loadGigs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      isSignedIn: _session != null,
                      displayName: displayName,
                      onSignOut: _signOut,
                    ),
                    const SizedBox(height: 30),
                    if (_session == null)
                      _SignedOutShell(
                        authError: _authError,
                        onSignIn: _signInWithGoogle,
                      )
                    else
                      _DriverWorkspace(
                        displayName: displayName,
                        selectedTab: _selectedTab,
                        isLoading: _isLoading,
                        bookingRequestId: _bookingRequestId,
                        workflowError: _workflowError,
                        availableCount: _availableGigs.length,
                        bookedCount: _bookedGigs.length,
                        visibleGigs: visibleGigs,
                        onSelectTab: (tab) => setState(() => _selectedTab = tab),
                        onRefresh: _loadGigs,
                        onBook: _confirmBooking,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RelocationRequest {
  const RelocationRequest({
    required this.id,
    required this.origin,
    required this.destination,
    required this.moveDate,
    required this.status,
    required this.dispatcherId,
    required this.createdAt,
    this.notes,
    this.driverId,
    this.bookedAt,
    this.updatedAt,
  });

  factory RelocationRequest.fromJson(Map<String, dynamic> json) {
    return RelocationRequest(
      id: json['id'].toString(),
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      moveDate: DateTime.parse('${json['move_date']}T12:00:00'),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'available',
      dispatcherId: json['dispatcher_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString(),
      bookedAt: _dateTimeOrNull(json['booked_at']),
      createdAt: _dateTimeOrNull(json['created_at']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updated_at']),
    );
  }

  final String id;
  final String origin;
  final String destination;
  final DateTime moveDate;
  final String? notes;
  final String status;
  final String dispatcherId;
  final String? driverId;
  final DateTime? bookedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

class _DriverWorkspace extends StatelessWidget {
  const _DriverWorkspace({
    required this.displayName,
    required this.selectedTab,
    required this.isLoading,
    required this.bookingRequestId,
    required this.availableCount,
    required this.bookedCount,
    required this.visibleGigs,
    required this.onSelectTab,
    required this.onRefresh,
    required this.onBook,
    this.workflowError,
  });

  final String displayName;
  final DriverTab selectedTab;
  final bool isLoading;
  final String bookingRequestId;
  final int availableCount;
  final int bookedCount;
  final List<RelocationRequest> visibleGigs;
  final ValueChanged<DriverTab> onSelectTab;
  final Future<void> Function() onRefresh;
  final ValueChanged<RelocationRequest> onBook;
  final String? workflowError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(label: 'Signed in as $displayName'),
        const SizedBox(height: 18),
        const Text(
          'Grab the next relocation gig.',
          style: TextStyle(
            fontSize: 43,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Browse unbooked moves, confirm the one you want, and keep your booked work in one mobile-first board.',
          style: TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        _SummaryPanel(
          availableCount: availableCount,
          bookedCount: bookedCount,
          isLoading: isLoading,
          onRefresh: onRefresh,
        ),
        if (workflowError != null) ...[
          const SizedBox(height: 14),
          _NoticeCard(
            color: const Color(0xFFFF8A8A),
            text: workflowError!,
          ),
        ],
        const SizedBox(height: 18),
        _DriverTabs(
          selectedTab: selectedTab,
          availableCount: availableCount,
          bookedCount: bookedCount,
          onSelectTab: onSelectTab,
        ),
        const SizedBox(height: 16),
        _GigList(
          selectedTab: selectedTab,
          gigs: visibleGigs,
          bookingRequestId: bookingRequestId,
          onBook: onBook,
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.availableCount,
    required this.bookedCount,
    required this.isLoading,
    required this.onRefresh,
  });

  final int availableCount;
  final int bookedCount;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3308061C),
            blurRadius: 52,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gig pulse',
                  style: TextStyle(
                    color: FloviColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onRefresh,
                style: TextButton.styleFrom(
                  foregroundColor: FloviColors.ink,
                  backgroundColor: FloviColors.mint,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  isLoading ? 'Syncing...' : 'Refresh',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  color: FloviColors.sky,
                  label: 'Available',
                  value: availableCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  color: FloviColors.lilac,
                  label: 'Booked',
                  value: bookedCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverTabs extends StatelessWidget {
  const _DriverTabs({
    required this.selectedTab,
    required this.availableCount,
    required this.bookedCount,
    required this.onSelectTab,
  });

  final DriverTab selectedTab;
  final int availableCount;
  final int bookedCount;
  final ValueChanged<DriverTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Available',
              count: availableCount,
              selected: selectedTab == DriverTab.available,
              onPressed: () => onSelectTab(DriverTab.available),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Booked',
              count: bookedCount,
              selected: selectedTab == DriverTab.booked,
              onPressed: () => onSelectTab(DriverTab.booked),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected ? FloviColors.ink : Colors.white,
        backgroundColor: selected ? FloviColors.mint : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        '$label ($count)',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _GigList extends StatelessWidget {
  const _GigList({
    required this.selectedTab,
    required this.gigs,
    required this.bookingRequestId,
    required this.onBook,
  });

  final DriverTab selectedTab;
  final List<RelocationRequest> gigs;
  final String bookingRequestId;
  final ValueChanged<RelocationRequest> onBook;

  @override
  Widget build(BuildContext context) {
    if (gigs.isEmpty) {
      return _EmptyState(selectedTab: selectedTab);
    }

    return Column(
      children: gigs
          .map(
            (gig) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GigCard(
                gig: gig,
                selectedTab: selectedTab,
                isBooking: bookingRequestId == gig.id,
                onBook: () => onBook(gig),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _GigCard extends StatelessWidget {
  const _GigCard({
    required this.gig,
    required this.selectedTab,
    required this.isBooking,
    required this.onBook,
  });

  final RelocationRequest gig;
  final DriverTab selectedTab;
  final bool isBooking;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final isAvailable = selectedTab == DriverTab.available;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _LightBadge(label: statusLabel(gig.status))),
              Text(
                formatShortDate(gig.moveDate),
                style: const TextStyle(
                  color: Color(0x99100B2F),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RouteCard(
            color: FloviColors.sky,
            title: gig.origin,
            subtitle: 'Pickup',
          ),
          const SizedBox(height: 10),
          _RouteCard(
            color: FloviColors.lemon,
            title: gig.destination,
            subtitle: 'Dropoff',
          ),
          const SizedBox(height: 14),
          Text(
            gig.notes?.isNotEmpty == true ? gig.notes! : 'No extra notes from dispatch.',
            style: const TextStyle(
              color: Color(0xA6100B2F),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (gig.bookedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Booked ${formatDateTime(gig.bookedAt!)}',
              style: const TextStyle(
                color: FloviColors.violet,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (isAvailable) ...[
            const SizedBox(height: 16),
            _PrimaryButton(
              label: isBooking ? 'Booking...' : 'Book this gig',
              onPressed: isBooking ? null : onBook,
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingSheet extends StatelessWidget {
  const _BookingSheet({required this.request});

  final RelocationRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: FloviColors.ink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(80),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _Pill(label: 'Confirm booking'),
            const SizedBox(height: 16),
            const Text(
              'Lock in this relocation gig?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1.0,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${request.origin} to ${request.destination} on ${formatShortDate(request.moveDate)}',
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            _PrimaryButton(
              label: 'Yes, book it',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(color: Colors.white.withAlpha(32)),
                  ),
                ),
                child: const Text(
                  'Not now',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.selectedTab});

  final DriverTab selectedTab;

  @override
  Widget build(BuildContext context) {
    final isAvailable = selectedTab == DriverTab.available;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        children: [
          Text(
            isAvailable ? 'No open gigs right now.' : 'No booked gigs yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAvailable
                ? 'When dispatch creates a request, it will appear here automatically.'
                : 'Book an available relocation to build your driver queue.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isSignedIn,
    required this.displayName,
    required this.onSignOut,
  });

  final bool isSignedIn;
  final String displayName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FloviColors.mint,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x5534F5A6),
                blurRadius: 36,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'F',
              style: TextStyle(
                color: FloviColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FLOVI DRIVER',
                style: TextStyle(
                  color: FloviColors.mint,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSignedIn ? displayName : 'Relocation gigs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (isSignedIn)
          TextButton(
            onPressed: onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: Color(0x26FFFFFF)),
              ),
            ),
            child: const Text(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _SignedOutShell extends StatelessWidget {
  const _SignedOutShell({
    required this.authError,
    required this.onSignIn,
  });

  final String? authError;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Pill(label: 'Mobile-first driver booking'),
        const SizedBox(height: 20),
        const Text(
          'Claim relocation gigs without calling dispatch.',
          style: TextStyle(
            fontSize: 46,
            height: 0.96,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.8,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Sign in with Google to browse available relocation work and keep your booked gigs synced with dispatch.',
          style: TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: 'Continue with Google',
          onPressed: onSignIn,
        ),
        if (!isSupabaseConfigured) ...[
          const SizedBox(height: 14),
          const _NoticeCard(
            color: FloviColors.lemon,
            text: 'Supabase dart defines are missing. Pass SUPABASE_URL and SUPABASE_ANON_KEY when running or building Flutter Web.',
          ),
        ],
        if (authError != null) ...[
          const SizedBox(height: 14),
          _NoticeCard(
            color: const Color(0xFFFF8A8A),
            text: authError!,
          ),
        ],
        const SizedBox(height: 28),
        const _PreviewCard(),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3308061C),
            blurRadius: 52,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live gig preview',
                  style: TextStyle(
                    color: FloviColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LightBadge(label: 'Available'),
            ],
          ),
          SizedBox(height: 16),
          _RouteCard(
            color: FloviColors.sky,
            title: 'Austin, TX',
            subtitle: 'Pickup',
          ),
          SizedBox(height: 10),
          _RouteCard(
            color: FloviColors.lemon,
            title: 'Denver, CO',
            subtitle: 'Dropoff',
          ),
          SizedBox(height: 16),
          Text(
            'Real dispatcher requests appear after sign-in.',
            style: TextStyle(
              color: Color(0x99100B2F),
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(115),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0x99100B2F),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: FloviColors.ink,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(140),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: FloviColors.ink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0x99100B2F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FloviColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: FloviColors.mint,
          disabledBackgroundColor: FloviColors.mint.withAlpha(120),
          foregroundColor: FloviColors.ink,
          disabledForegroundColor: FloviColors.ink.withAlpha(150),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: FloviColors.mint.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FloviColors.mint.withAlpha(89)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: FloviColors.mint,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LightBadge extends StatelessWidget {
  const _LightBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FloviColors.mint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: FloviColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(33),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha(89)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: -130,
          left: -120,
          child: _GlowOrb(size: 320, color: Color(0x556246EA)),
        ),
        Positioned(
          top: 90,
          right: -150,
          child: _GlowOrb(size: 360, color: Color(0x4434F5A6)),
        ),
        Positioned(
          bottom: -180,
          left: 40,
          child: _GlowOrb(size: 340, color: Color(0x229BD8FF)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

enum DriverTab { available, booked }

class FloviColors {
  static const ink = Color(0xFF100B2F);
  static const night = Color(0xFF17113F);
  static const violet = Color(0xFF6246EA);
  static const mint = Color(0xFF34F5A6);
  static const sky = Color(0xFF9BD8FF);
  static const lemon = Color(0xFFFFE985);
  static const lilac = Color(0xFFC7B8FF);

  const FloviColors._();
}

const _requestColumns =
    'id, origin, destination, move_date, notes, status, dispatcher_id, driver_id, booked_at, created_at, updated_at';

DateTime? _dateTimeOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value.toString());
}

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${formatShortDate(value)} at $hour:$minute';
}

String statusLabel(String status) {
  return switch (status) {
    'available' => 'Available',
    'booked' => 'Booked',
    'completed' => 'Completed',
    _ => 'Unknown',
  };
}
