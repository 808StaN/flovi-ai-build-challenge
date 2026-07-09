<script setup>
import { computed, onMounted, ref } from 'vue';
import { isSupabaseConfigured, supabase } from './lib/supabase';

const session = ref(null);
const isAuthLoading = ref(true);
const authError = ref('');

const userName = computed(() => {
  const user = session.value?.user;
  return user?.user_metadata?.full_name || user?.email || 'Dispatcher';
});

const userInitials = computed(() =>
  userName.value
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('') || 'F',
);

const signInWithGoogle = async () => {
  authError.value = '';

  if (!isSupabaseConfigured || !supabase) {
    authError.value = 'Add Supabase environment variables before signing in.';
    return;
  }

  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin,
    },
  });

  if (error) {
    authError.value = error.message;
  }
};

const signOut = async () => {
  authError.value = '';

  if (!supabase) {
    return;
  }

  const { error } = await supabase.auth.signOut();

  if (error) {
    authError.value = error.message;
  }
};

onMounted(async () => {
  if (!isSupabaseConfigured || !supabase) {
    isAuthLoading.value = false;
    return;
  }

  const { data, error } = await supabase.auth.getSession();

  if (error) {
    authError.value = error.message;
  }

  session.value = data.session;
  isAuthLoading.value = false;

  supabase.auth.onAuthStateChange((_event, nextSession) => {
    session.value = nextSession;
  });
});
</script>

<template>
  <main class="min-h-screen overflow-hidden bg-flovi-ink text-white">
    <div class="pointer-events-none fixed inset-0">
      <div class="absolute -left-28 top-[-9rem] h-96 w-96 rounded-full bg-flovi-violet/[0.35] blur-3xl" />
      <div class="absolute right-[-8rem] top-20 h-[30rem] w-[30rem] rounded-full bg-flovi-mint/20 blur-3xl" />
      <div class="absolute bottom-[-16rem] left-1/3 h-[28rem] w-[28rem] rounded-full bg-flovi-sky/10 blur-3xl" />
    </div>

    <section class="relative mx-auto flex min-h-screen w-full max-w-7xl flex-col px-5 py-6 sm:px-8 lg:px-10">
      <nav class="flex items-center justify-between rounded-full border border-white/10 bg-white/[0.08] px-4 py-3 shadow-card backdrop-blur-xl sm:px-5">
        <div class="flex items-center gap-3">
          <div class="flex h-11 w-11 items-center justify-center rounded-2xl bg-flovi-mint text-lg font-black text-flovi-ink shadow-glow">
            F
          </div>
          <div>
            <p class="text-sm font-bold tracking-[0.28em] text-flovi-mint">FLOVI</p>
            <p class="text-xs text-white/[0.55]">Dispatcher Control</p>
          </div>
        </div>

        <div v-if="session" class="flex items-center gap-3">
          <div class="hidden text-right sm:block">
            <p class="text-sm font-semibold">{{ userName }}</p>
            <p class="text-xs text-white/[0.55]">Google session active</p>
          </div>
          <div class="flex h-10 w-10 items-center justify-center rounded-full bg-white text-sm font-black text-flovi-night">
            {{ userInitials }}
          </div>
          <button class="rounded-full border border-white/[0.15] px-4 py-2 text-sm font-bold text-white/80 transition hover:border-white/30 hover:bg-white/10" type="button" @click="signOut">
            Sign out
          </button>
        </div>
      </nav>

      <div class="grid flex-1 items-center gap-10 py-12 lg:grid-cols-[1fr_0.82fr] lg:py-16">
        <div class="max-w-3xl">
          <div class="mb-6 inline-flex rounded-full border border-flovi-mint/30 bg-flovi-mint/10 px-4 py-2 text-sm font-bold text-flovi-mint">
            Relocation ops, ready for dispatch
          </div>

          <h1 class="text-5xl font-black leading-[0.95] tracking-tight text-white sm:text-6xl lg:text-7xl">
            Move requests, booked gigs, one shared command center.
          </h1>

          <p class="mt-6 max-w-2xl text-lg leading-8 text-white/[0.68]">
            A Flovi-inspired dashboard shell for dispatchers to authenticate and prepare relocation operations. Request creation, editing, and live lists arrive in the next phase.
          </p>

          <div class="mt-8 flex flex-col gap-3 sm:flex-row">
            <button
              v-if="!session"
              class="rounded-full bg-flovi-mint px-6 py-4 text-base font-black text-flovi-ink shadow-glow transition hover:-translate-y-0.5 hover:bg-[#7cffc6] disabled:cursor-not-allowed disabled:opacity-60"
              type="button"
              :disabled="isAuthLoading"
              @click="signInWithGoogle"
            >
              Continue with Google
            </button>
            <a class="rounded-full border border-white/[0.15] px-6 py-4 text-center text-base font-bold text-white transition hover:border-white/30 hover:bg-white/10" href="https://supabase.com/docs/guides/auth/social-login/auth-google" target="_blank" rel="noreferrer">
              OAuth setup notes
            </a>
          </div>

          <p v-if="authError" class="mt-4 rounded-2xl border border-red-300/30 bg-red-400/10 px-4 py-3 text-sm font-semibold text-red-100">
            {{ authError }}
          </p>

          <p v-if="!isSupabaseConfigured" class="mt-4 rounded-2xl border border-flovi-lemon/30 bg-flovi-lemon/10 px-4 py-3 text-sm font-semibold text-flovi-lemon">
            Supabase env vars are not configured yet. Copy `.env.example` to `.env.local` and add project credentials.
          </p>
        </div>

        <aside class="rounded-[2rem] border border-white/10 bg-white/[0.09] p-4 shadow-card backdrop-blur-2xl sm:p-5">
          <div class="rounded-[1.5rem] bg-white p-5 text-flovi-night sm:p-6">
            <div class="flex items-center justify-between gap-4">
              <div>
                <p class="text-sm font-black uppercase tracking-[0.24em] text-flovi-violet">Today</p>
                <h2 class="mt-2 text-3xl font-black">Ops Pulse</h2>
              </div>
              <span class="rounded-full bg-flovi-mint px-4 py-2 text-sm font-black text-flovi-ink">
                Shell
              </span>
            </div>

            <div class="mt-6 grid gap-3 sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3">
              <div class="rounded-3xl bg-flovi-sky/[0.45] p-4">
                <p class="text-sm font-bold text-flovi-night/60">Available</p>
                <p class="mt-3 text-4xl font-black">--</p>
              </div>
              <div class="rounded-3xl bg-flovi-lemon/70 p-4">
                <p class="text-sm font-bold text-flovi-night/60">Booked</p>
                <p class="mt-3 text-4xl font-black">--</p>
              </div>
              <div class="rounded-3xl bg-flovi-lilac/70 p-4">
                <p class="text-sm font-bold text-flovi-night/60">Completed</p>
                <p class="mt-3 text-4xl font-black">--</p>
              </div>
            </div>

            <div class="mt-5 rounded-3xl border border-dashed border-flovi-violet/30 bg-flovi-violet/5 p-5">
              <p class="text-sm font-black uppercase tracking-[0.22em] text-flovi-violet">Next phase</p>
              <h3 class="mt-3 text-2xl font-black">Relocation request workflow</h3>
              <p class="mt-2 text-sm leading-6 text-flovi-night/[0.62]">
                This scaffold intentionally stops before CRUD. The next milestone adds create, list, edit, and realtime status updates against Supabase.
              </p>
            </div>

            <div class="mt-5 flex items-center justify-between rounded-3xl bg-flovi-night px-5 py-4 text-white">
              <div>
                <p class="text-sm font-bold text-white/50">Auth status</p>
                <p class="font-black">{{ session ? 'Signed in' : isAuthLoading ? 'Checking session' : 'Ready for Google OAuth' }}</p>
              </div>
              <div class="h-3 w-3 rounded-full" :class="session ? 'bg-flovi-mint' : 'bg-flovi-lemon'" />
            </div>
          </div>
        </aside>
      </div>
    </section>
  </main>
</template>
