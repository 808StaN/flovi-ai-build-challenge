# Reflection

## What Worked

- Breaking the build into phases kept the scope controlled and made commits meaningful.
- Supabase was a strong fit because Auth, database rows, RPC, and realtime all mapped directly to the assignment workflow.
- Static Flutter Web output is the safest Vercel deployment path for a short demo window.

## What Broke

- Flutter was not installed on PATH, so a temporary local SDK had to be cloned outside the repo before driver checks could run.
- Flutter analysis caught a deprecated Supabase initialization parameter, which was fixed before implementing booking.
- Realtime still needs a real Supabase project smoke test because local builds cannot prove hosted Auth redirect configuration.

## Where AI Got In The Way

- The first Flutter scaffold had to be generated manually because the SDK was unavailable.
- Some generated styling details needed review and correction before relying on the builds.

## What I Would Improve With One More Hour

- Run the full smoke test against deployed Vercel URLs and add screenshots or a short demo script.
- Add a small status update action for completing booked requests.
- Add loading skeletons and more helpful empty states for unstable network conditions.

## What This Says About How Software Development Is Changing

- AI is fastest when the engineer sets tight phases, verifies after each step, and refuses unnecessary scope.
- The work shifts from typing code to steering, inspecting, testing, and correcting generated output.
- Environment readiness still matters: missing SDKs and OAuth configuration can block delivery even when the app code is generated quickly.
