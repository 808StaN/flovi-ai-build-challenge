import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const isSupabaseConfigured = supabaseUrl != '' && supabaseAnonKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isSupabaseConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
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
        scaffoldBackgroundColor: const Color(0xFF100B2F),
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
  String? _authError;

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
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      if (!mounted) {
        return;
      }

      setState(() {
        _session = data.session;
        _authError = null;
      });
    });
  }

  @override
  void dispose() {
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
        redirectTo: Uri.base.origin,
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

  @override
  Widget build(BuildContext context) {
    final user = _session?.user;
    final displayName = user?.userMetadata?['full_name']?.toString() ?? user?.email ?? 'Driver';

    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: SingleChildScrollView(
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
                    _SignedInShell(displayName: displayName),
                ],
              ),
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
          'A clean Flovi-inspired driver shell for Google OAuth. Available gigs and one-tap booking arrive in the next phase.',
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

class _SignedInShell extends StatelessWidget {
  const _SignedInShell({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(label: 'Signed in as $displayName'),
        const SizedBox(height: 20),
        const Text(
          'Your gig board is almost ready.',
          style: TextStyle(
            fontSize: 42,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Next phase connects this driver view to available relocation requests, atomic booking, and your booked gigs.',
          style: TextStyle(
            color: Color(0xB3FFFFFF),
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 26),
        const _StatusPanel(),
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
                  'Upcoming gig preview',
                  style: TextStyle(
                    color: FloviColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LightBadge(label: 'Shell'),
            ],
          ),
          SizedBox(height: 16),
          _RouteCard(
            color: FloviColors.sky,
            title: 'Austin, TX',
            subtitle: 'Origin',
          ),
          SizedBox(height: 10),
          _RouteCard(
            color: FloviColors.lemon,
            title: 'Denver, CO',
            subtitle: 'Destination',
          ),
          SizedBox(height: 16),
          Text(
            'Booking actions are intentionally not implemented in this scaffold phase.',
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver workspace',
            style: TextStyle(
              color: FloviColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  color: FloviColors.sky,
                  label: 'Available',
                  value: '--',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  color: FloviColors.lilac,
                  label: 'Booked',
                  value: '--',
                ),
              ),
            ],
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
          Column(
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
                style: const TextStyle(
                  color: FloviColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: FloviColors.mint,
          foregroundColor: FloviColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
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
    return Container(
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
          child: _GlowOrb(
            size: 320,
            color: Color(0x556246EA),
          ),
        ),
        Positioned(
          top: 90,
          right: -150,
          child: _GlowOrb(
            size: 360,
            color: Color(0x4434F5A6),
          ),
        ),
        Positioned(
          bottom: -180,
          left: 40,
          child: _GlowOrb(
            size: 340,
            color: Color(0x229BD8FF),
          ),
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
