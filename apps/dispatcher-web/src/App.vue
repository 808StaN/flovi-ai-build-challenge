<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue';
import { isSupabaseConfigured, supabase } from './lib/supabase';

const emptyForm = () => ({
  origin: '',
  destination: '',
  move_date: '',
  notes: '',
});

const session = ref(null);
const isAuthLoading = ref(true);
const isRequestsLoading = ref(false);
const isSaving = ref(false);
const authError = ref('');
const requestsError = ref('');
const requests = ref([]);
const editingId = ref(null);
const form = reactive(emptyForm());

let realtimeChannel = null;
let authSubscription = null;

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

const dateTimeValue = (value) => {
  const timestamp = new Date(value).getTime();
  return Number.isNaN(timestamp) ? 0 : timestamp;
};

const sortedRequests = computed(() =>
  [...requests.value].sort((first, second) =>
    dateTimeValue(second.created_at) - dateTimeValue(first.created_at),
  ),
);

const requestStats = computed(() => ({
  available: requests.value.filter((request) => request.status === 'available').length,
  booked: requests.value.filter((request) => request.status === 'booked').length,
  completed: requests.value.filter((request) => request.status === 'completed').length,
}));

const isEditing = computed(() => Boolean(editingId.value));

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

const resetForm = () => {
  Object.assign(form, emptyForm());
  editingId.value = null;
};

const fetchRequests = async () => {
  if (!supabase || !session.value) {
    requests.value = [];
    return;
  }

  isRequestsLoading.value = true;
  requestsError.value = '';

  const { data, error } = await supabase
    .from('relocation_requests')
    .select('id, origin, destination, move_date, notes, status, dispatcher_id, driver_id, booked_at, created_at, updated_at')
    .order('created_at', { ascending: false });

  if (error) {
    requestsError.value = error.message;
  } else {
    requests.value = data || [];
  }

  isRequestsLoading.value = false;
};

const startRealtime = () => {
  if (!supabase || realtimeChannel) {
    return;
  }

  realtimeChannel = supabase
    .channel('dispatcher-relocation-requests')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'relocation_requests' },
      () => {
        fetchRequests();
      },
    )
    .subscribe();
};

const stopRealtime = () => {
  if (!supabase || !realtimeChannel) {
    return;
  }

  supabase.removeChannel(realtimeChannel);
  realtimeChannel = null;
};

const submitRequest = async () => {
  requestsError.value = '';

  if (!supabase || !session.value) {
    requestsError.value = 'Sign in with Google before managing relocation requests.';
    return;
  }

  isSaving.value = true;

  const payload = {
    origin: form.origin.trim(),
    destination: form.destination.trim(),
    move_date: form.move_date,
    notes: form.notes.trim() || null,
  };

  const result = isEditing.value
    ? await supabase
        .from('relocation_requests')
        .update(payload)
        .eq('id', editingId.value)
        .eq('dispatcher_id', session.value.user.id)
    : await supabase.from('relocation_requests').insert({
        ...payload,
        dispatcher_id: session.value.user.id,
      });

  if (result.error) {
    requestsError.value = result.error.message;
  } else {
    resetForm();
    await fetchRequests();
  }

  isSaving.value = false;
};

const startEdit = (request) => {
  editingId.value = request.id;
  form.origin = request.origin;
  form.destination = request.destination;
  form.move_date = request.move_date;
  form.notes = request.notes || '';
};

const canEdit = (request) => request.dispatcher_id === session.value?.user?.id;

const parseDate = (value, dateOnly = false) => {
  if (!value) {
    return null;
  }

  const normalizedValue = String(value);
  const dateValue = dateOnly && /^\d{4}-\d{2}-\d{2}$/.test(normalizedValue)
    ? `${normalizedValue}T12:00:00`
    : normalizedValue;
  const date = new Date(dateValue);

  return Number.isNaN(date.getTime()) ? null : date;
};

const formatDate = (value) => {
  const date = parseDate(value, true);

  if (!date) {
    return 'No date';
  }

  return new Intl.DateTimeFormat('en', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
};

const formatDateTime = (value, fallback = 'Unavailable') => {
  const date = parseDate(value);

  if (!date) {
    return fallback;
  }

  return new Intl.DateTimeFormat('en', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};

const statusLabel = (status) => ({
  available: 'Available',
  booked: 'Booked',
  completed: 'Completed',
}[status] || 'Unknown');

const statusBadgeClass = (status) => ({
  available: 'border-flovi-mint/40 bg-flovi-mint/[0.15] text-flovi-mint',
  booked: 'border-flovi-sky/70 bg-flovi-sky/[0.22] text-flovi-sky',
  completed: 'border-flovi-lilac/50 bg-flovi-lilac/25 text-flovi-lilac',
}[status] || 'border-white/20 bg-white/10 text-white/70');

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

  if (data.session) {
    await fetchRequests();
    startRealtime();
  }

  const { data: authListener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
    session.value = nextSession;
    authError.value = '';

    if (nextSession) {
      fetchRequests();
      startRealtime();
    } else {
      requests.value = [];
      resetForm();
      stopRealtime();
    }
  });

  authSubscription = authListener.subscription;
});

onUnmounted(() => {
  stopRealtime();
  authSubscription?.unsubscribe();
});
</script>

<template>
  <main class="min-h-screen bg-white text-flovi-night">
    <header class="bg-flovi-violet text-white">
      <div class="mx-auto flex max-w-7xl justify-end px-5 py-2 text-xs font-black sm:px-8 lg:px-10">
        <span class="rounded-full bg-flovi-night px-4 py-1 text-flovi-mint">For dispatch teams</span>
      </div>

      <nav class="bg-flovi-night">
        <div class="mx-auto flex max-w-7xl items-center justify-between px-5 py-4 sm:px-8 lg:px-10">
          <div class="flex items-center gap-3">
            <div class="text-2xl font-black tracking-tight">Flovi</div>
            <span class="hidden rounded-full bg-white/10 px-3 py-1 text-xs font-bold text-white/70 sm:inline-flex">Dispatcher</span>
          </div>

          <div class="hidden items-center gap-6 text-sm font-extrabold text-white/80 md:flex">
            <span>Requests</span>
            <span>Drivers</span>
            <span>Realtime ops</span>
          </div>

          <div v-if="session" class="flex items-center gap-3">
            <p class="hidden max-w-44 truncate text-right text-sm font-bold sm:block">{{ userName }}</p>
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-flovi-mint text-sm font-black text-flovi-night">
              {{ userInitials }}
            </div>
            <button class="rounded-full border border-white/20 px-4 py-2 text-sm font-black text-white transition hover:border-flovi-mint hover:text-flovi-mint" type="button" @click="signOut">
              Sign out
            </button>
          </div>
        </div>
      </nav>
    </header>

    <template v-if="!session">
      <section class="relative overflow-hidden bg-flovi-night text-white">
        <div class="absolute inset-0 bg-[radial-gradient(circle_at_80%_20%,rgba(52,245,166,0.25),transparent_30%),linear-gradient(120deg,rgba(16,11,47,0.98),rgba(23,17,63,0.78))]" />
        <div class="relative mx-auto grid max-w-7xl items-center gap-10 px-5 py-16 sm:px-8 lg:grid-cols-[1fr_0.9fr] lg:px-10 lg:py-24">
          <div>
            <p class="mb-5 inline-flex rounded-full bg-flovi-mint px-4 py-2 text-sm font-black text-flovi-night">Relocation dispatch, simplified</p>
            <h1 class="max-w-4xl text-5xl font-black leading-[0.95] tracking-tight sm:text-6xl lg:text-7xl">
              Intelligent car relocation operations for teams.
            </h1>
            <p class="mt-6 max-w-2xl text-base font-semibold leading-8 text-white/[0.78] sm:text-lg">
              Create requests, monitor booking status, and keep drivers synced from one polished Flovi-style command center.
            </p>
            <div class="mt-8 flex flex-col gap-3 sm:flex-row">
              <button
                class="rounded-full bg-flovi-mint px-6 py-4 text-base font-black text-flovi-night shadow-glow transition hover:-translate-y-0.5 hover:bg-[#7cffc6] disabled:cursor-not-allowed disabled:opacity-60"
                type="button"
                :disabled="isAuthLoading"
                @click="signInWithGoogle"
              >
                Continue with Google
              </button>
            </div>

            <p v-if="authError" class="mt-4 max-w-xl rounded-2xl border border-red-200/40 bg-red-400/[0.15] px-4 py-3 text-sm font-bold text-red-50">
              {{ authError }}
            </p>

            <p v-if="!isSupabaseConfigured" class="mt-4 max-w-xl rounded-2xl border border-flovi-lemon/40 bg-flovi-lemon/[0.15] px-4 py-3 text-sm font-bold text-flovi-lemon">
              Supabase env vars are not configured yet. Copy `.env.example` to `.env.local` and add project credentials.
            </p>
          </div>

          <aside class="relative rounded-[2rem] bg-white p-5 text-flovi-night shadow-card sm:p-6">
            <div class="absolute -right-3 top-8 rotate-12 rounded-xl bg-flovi-mint px-4 py-3 text-center text-xs font-black uppercase leading-none shadow-card">
              Let's<br />go
            </div>
            <div class="absolute -left-2 bottom-8 -rotate-6 rounded-xl bg-flovi-lemon px-4 py-3 text-center text-xs font-black uppercase leading-none shadow-card">
              Hit the<br />road
            </div>

            <p class="text-sm font-black uppercase tracking-[0.22em] text-flovi-violet">Live workflow</p>
            <h2 class="mt-3 text-3xl font-black">Create. Sync. Book.</h2>
            <div class="mt-6 grid gap-3">
              <div class="rounded-3xl bg-flovi-sky/50 p-4 font-bold">1. Dispatcher creates a relocation request.</div>
              <div class="rounded-3xl bg-flovi-mint/[0.35] p-4 font-bold">2. Driver sees it as available.</div>
              <div class="rounded-3xl bg-flovi-lilac/60 p-4 font-bold">3. Booking updates the board instantly.</div>
            </div>
          </aside>
        </div>
      </section>

      <section class="bg-white px-5 py-14 sm:px-8 lg:px-10">
        <div class="mx-auto grid max-w-7xl gap-8 lg:grid-cols-[0.8fr_1.2fr] lg:items-center">
          <h2 class="text-3xl font-black leading-tight sm:text-4xl">Move requests faster, cleaner, and with fewer status checks.</h2>
          <p class="text-base font-semibold leading-8 text-flovi-night/70">
            The demo uses Supabase auth, shared request data, and realtime refresh so dispatch and drivers stay aligned through the same relocation pipeline.
          </p>
        </div>
      </section>

      <section class="bg-flovi-night px-5 py-12 text-white sm:px-8 lg:px-10">
        <div class="mx-auto grid max-w-5xl gap-6 text-center md:grid-cols-3">
          <div>
            <p class="text-5xl font-black">3</p>
            <p class="mt-2 text-sm font-bold text-white/70">Core request states</p>
          </div>
          <div>
            <p class="text-5xl font-black">1</p>
            <p class="mt-2 text-sm font-bold text-white/70">Shared Supabase table</p>
          </div>
          <div>
            <p class="text-5xl font-black">0</p>
            <p class="mt-2 text-sm font-bold text-white/70">Manual booking calls</p>
          </div>
        </div>
      </section>

      <section class="bg-flovi-violet px-5 py-14 text-white sm:px-8 lg:px-10">
        <div class="mx-auto max-w-7xl">
          <h2 class="text-center text-3xl font-black">Dispatcher tools</h2>
          <div class="mx-auto mt-5 flex max-w-2xl rounded-full bg-flovi-night p-1 text-xs font-black">
            <span class="flex-1 rounded-full bg-flovi-sky px-4 py-3 text-center text-flovi-night">Create jobs</span>
            <span class="flex-1 px-4 py-3 text-center text-white/80">Track bookings</span>
            <span class="flex-1 px-4 py-3 text-center text-white/80">Sync drivers</span>
          </div>
          <div class="mt-8 grid gap-5 md:grid-cols-3">
            <article class="rounded-3xl bg-flovi-sky p-6 text-flovi-night">
              <h3 class="text-xl font-black">Fast request intake</h3>
              <p class="mt-3 text-sm font-bold leading-6 text-flovi-night/70">Capture origin, destination, dates, and move notes in one clean flow.</p>
            </article>
            <article class="rounded-3xl bg-flovi-mint p-6 text-flovi-night">
              <h3 class="text-xl font-black">Driver-ready jobs</h3>
              <p class="mt-3 text-sm font-bold leading-6 text-flovi-night/70">Available requests become bookable from the connected driver web app.</p>
            </article>
            <article class="rounded-3xl bg-flovi-lemon p-6 text-flovi-night">
              <h3 class="text-xl font-black">Clear status flow</h3>
              <p class="mt-3 text-sm font-bold leading-6 text-flovi-night/70">Available, booked, and completed states stay visible across the board.</p>
            </article>
          </div>
        </div>
      </section>
    </template>

    <section v-else class="bg-[#F7F6FF] px-5 py-10 sm:px-8 lg:px-10">
      <div class="mx-auto max-w-7xl">
        <header class="rounded-[2rem] bg-flovi-night p-6 text-white shadow-card sm:p-8 lg:p-10">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <div class="mb-4 inline-flex rounded-full bg-flovi-mint px-4 py-2 text-sm font-black text-flovi-night">
                Live dispatcher board
              </div>
              <h1 class="max-w-4xl text-4xl font-black leading-none tracking-tight sm:text-5xl lg:text-6xl">
                Relocation requests moving through one shared pipeline.
              </h1>
              <p class="mt-4 max-w-2xl text-base font-semibold leading-7 text-white/70">
                Create and edit relocation jobs here. Driver bookings appear automatically through Supabase realtime updates.
              </p>
            </div>
            <button class="rounded-full border border-flovi-mint px-5 py-3 text-sm font-black text-flovi-mint transition hover:bg-flovi-mint hover:text-flovi-night disabled:cursor-not-allowed disabled:opacity-60" type="button" :disabled="isRequestsLoading" @click="fetchRequests">
              {{ isRequestsLoading ? 'Refreshing...' : 'Refresh board' }}
            </button>
          </div>
        </header>

        <section class="mt-6 grid gap-4 md:grid-cols-3">
          <div class="rounded-[1.7rem] bg-flovi-mint p-5 text-flovi-night shadow-card">
            <p class="text-sm font-black">Available</p>
            <p class="mt-3 text-5xl font-black">{{ requestStats.available }}</p>
          </div>
          <div class="rounded-[1.7rem] bg-flovi-sky p-5 text-flovi-night shadow-card">
            <p class="text-sm font-black">Booked</p>
            <p class="mt-3 text-5xl font-black">{{ requestStats.booked }}</p>
          </div>
          <div class="rounded-[1.7rem] bg-flovi-lilac p-5 text-flovi-night shadow-card">
            <p class="text-sm font-black">Completed</p>
            <p class="mt-3 text-5xl font-black">{{ requestStats.completed }}</p>
          </div>
        </section>

        <div class="mt-6 grid gap-6 xl:grid-cols-[0.9fr_1.35fr]">
          <section class="rounded-[2rem] bg-white p-4 shadow-card sm:p-5">
            <form class="rounded-[1.5rem] border border-flovi-night/10 bg-white p-5 text-flovi-night sm:p-6" @submit.prevent="submitRequest">
              <p class="text-sm font-black uppercase tracking-[0.24em] text-flovi-violet">
                {{ isEditing ? 'Edit request' : 'New relocation' }}
              </p>
              <h2 class="mt-2 text-3xl font-black">
                {{ isEditing ? 'Update job details' : 'Create a request' }}
              </h2>

              <div class="mt-6 grid gap-4">
                <label class="block">
                  <span class="text-sm font-black text-flovi-night/70">Origin</span>
                  <input v-model="form.origin" class="mt-2 w-full rounded-2xl border border-flovi-night/10 bg-[#F7F6FF] px-4 py-3 font-semibold outline-none transition focus:border-flovi-violet focus:ring-4 focus:ring-flovi-violet/10" required placeholder="Austin, TX" type="text" />
                </label>

                <label class="block">
                  <span class="text-sm font-black text-flovi-night/70">Destination</span>
                  <input v-model="form.destination" class="mt-2 w-full rounded-2xl border border-flovi-night/10 bg-[#F7F6FF] px-4 py-3 font-semibold outline-none transition focus:border-flovi-violet focus:ring-4 focus:ring-flovi-violet/10" required placeholder="Denver, CO" type="text" />
                </label>

                <label class="block">
                  <span class="text-sm font-black text-flovi-night/70">Move date</span>
                  <input v-model="form.move_date" class="mt-2 w-full rounded-2xl border border-flovi-night/10 bg-[#F7F6FF] px-4 py-3 font-semibold outline-none transition focus:border-flovi-violet focus:ring-4 focus:ring-flovi-violet/10" required type="date" />
                </label>

                <label class="block">
                  <span class="text-sm font-black text-flovi-night/70">Notes</span>
                  <textarea v-model="form.notes" class="mt-2 min-h-28 w-full resize-none rounded-2xl border border-flovi-night/10 bg-[#F7F6FF] px-4 py-3 font-semibold outline-none transition focus:border-flovi-violet focus:ring-4 focus:ring-flovi-violet/10" placeholder="Elevator access, preferred pickup window, special handling..." />
                </label>
              </div>

              <p v-if="requestsError" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-700">
                {{ requestsError }}
              </p>

              <div class="mt-6 flex flex-col gap-3 sm:flex-row">
                <button class="rounded-full bg-flovi-mint px-6 py-4 text-base font-black text-flovi-night shadow-glow transition hover:-translate-y-0.5 hover:bg-[#7cffc6] disabled:cursor-not-allowed disabled:opacity-60" type="submit" :disabled="isSaving">
                  {{ isSaving ? 'Saving...' : isEditing ? 'Save changes' : 'Create request' }}
                </button>
                <button v-if="isEditing" class="rounded-full border border-flovi-night/[0.15] px-6 py-4 text-base font-black text-flovi-night transition hover:bg-flovi-night/5" type="button" @click="resetForm">
                  Cancel edit
                </button>
              </div>
            </form>
          </section>

          <section class="rounded-[2rem] bg-white p-4 shadow-card sm:p-5">
            <div class="rounded-[1.5rem] border border-flovi-night/10 bg-white p-5 text-flovi-night sm:p-6">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <p class="text-sm font-black uppercase tracking-[0.24em] text-flovi-violet">All requests</p>
                  <h2 class="mt-2 text-3xl font-black">Operations queue</h2>
                </div>
                <span class="rounded-full bg-flovi-night px-4 py-2 text-sm font-black text-white">
                  {{ sortedRequests.length }} total
                </span>
              </div>

              <div v-if="isRequestsLoading && !sortedRequests.length" class="mt-6 rounded-3xl bg-[#F7F6FF] p-6 text-center font-bold text-flovi-night/60">
                Loading relocation requests...
              </div>

              <div v-else-if="!sortedRequests.length" class="mt-6 rounded-3xl border border-dashed border-flovi-violet/30 bg-flovi-violet/5 p-6 text-center">
                <p class="text-lg font-black">No relocation requests yet.</p>
                <p class="mt-2 text-sm font-semibold text-flovi-night/60">Create the first request to make it available for drivers.</p>
              </div>

              <div v-else class="mt-6 space-y-4">
                <article v-for="request in sortedRequests" :key="request.id" class="rounded-3xl border border-flovi-night/10 bg-[#F7F6FF] p-4 transition hover:-translate-y-0.5 hover:bg-white sm:p-5">
                  <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                      <div class="flex flex-wrap items-center gap-2">
                        <span class="rounded-full border px-3 py-1 text-xs font-black uppercase tracking-[0.16em]" :class="statusBadgeClass(request.status)">
                          {{ statusLabel(request.status) }}
                        </span>
                        <span v-if="canEdit(request)" class="rounded-full bg-flovi-mint px-3 py-1 text-xs font-black text-flovi-night">
                          Your request
                        </span>
                      </div>
                      <h3 class="mt-4 text-2xl font-black leading-tight">
                        {{ request.origin }} <span class="text-flovi-violet">-></span> {{ request.destination }}
                      </h3>
                      <p class="mt-2 text-sm font-bold text-flovi-night/60">
                        Move date: {{ formatDate(request.move_date) }}
                      </p>
                    </div>

                    <button v-if="canEdit(request)" class="rounded-full bg-flovi-night px-4 py-2 text-sm font-black text-white transition hover:bg-flovi-violet" type="button" @click="startEdit(request)">
                      Edit
                    </button>
                    <span v-else class="rounded-full bg-flovi-night/5 px-4 py-2 text-sm font-black text-flovi-night/50">
                      Read only
                    </span>
                  </div>

                  <p class="mt-4 rounded-2xl bg-white px-4 py-3 text-sm font-semibold leading-6 text-flovi-night/70">
                    {{ request.notes || 'No dispatcher notes added.' }}
                  </p>

                  <dl class="mt-4 grid gap-3 text-sm sm:grid-cols-3">
                    <div class="rounded-2xl bg-white px-4 py-3">
                      <dt class="font-black text-flovi-night/[0.45]">Created</dt>
                      <dd class="mt-1 font-bold">{{ formatDateTime(request.created_at) }}</dd>
                    </div>
                    <div class="rounded-2xl bg-white px-4 py-3">
                      <dt class="font-black text-flovi-night/[0.45]">Booked</dt>
                      <dd class="mt-1 font-bold">{{ formatDateTime(request.booked_at, 'Not booked yet') }}</dd>
                    </div>
                    <div class="rounded-2xl bg-white px-4 py-3">
                      <dt class="font-black text-flovi-night/[0.45]">Driver</dt>
                      <dd class="mt-1 truncate font-bold">{{ request.driver_id || 'Unassigned' }}</dd>
                    </div>
                  </dl>
                </article>
              </div>
            </div>
          </section>
        </div>
      </div>
    </section>
  </main>
</template>
