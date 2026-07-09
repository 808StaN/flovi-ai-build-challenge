# Flovi Driver App

Flutter 3 driver booking app for the Flovi AI Build Challenge.

## Local Setup

Install Flutter 3, then run:

```bash
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Web Build

Use static-output deployment first for Vercel:

```bash
flutter build web --release --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Deploy the generated `build/web` directory as a static Vercel site.

## Current Scope

This phase includes Supabase initialization, Google OAuth login/logout, and a mobile-first UI shell. Gig browsing and booking arrive in the next phase.
