# Prompt Log

Use this document to record the key prompts and iterations from the Flovi AI Build Challenge.

## Prompt Entry Template

### Prompt Number


### Goal


### Prompt Summary


### AI Output Summary


### What Changed


### What Broke Or Needed Correction


### Why The Next Iteration Was Needed


## Entries

### Prompt Number

1

### Goal

Create a practical implementation plan from the assignment requirements before generating files.

### Prompt Summary

Asked the AI to inspect the provided assignment requirements, treat them as the source of truth, and produce a realistic phase-by-phase plan for two connected Flovi relocation apps.

### AI Output Summary

The AI proposed a monorepo with Vue dispatcher app, Flutter driver app, Supabase backend, Vercel deployment, phased implementation, commit checkpoints, risks, and a five-minute demo flow.

### What Changed

No files changed during planning.

### What Broke Or Needed Correction

The plan needed small corrections before implementation: static-first Flutter Web deployment, an explicit status constraint, atomic booking RPC behavior, simple RLS, and a demo setup note.

### Why The Next Iteration Was Needed

The next iteration starts Phase 1 and creates the repository foundation with the corrected backend and deployment assumptions.

### Prompt Number

2

### Goal

Scaffold the dispatcher web app only, without implementing request CRUD.

### Prompt Summary

Asked the AI to proceed with Phase 2 by creating the Vue 3, Vite, Tailwind CSS dispatcher app, adding Supabase Google OAuth shell behavior, running relevant checks, and committing the result.

### AI Output Summary

The AI generated the dispatcher app scaffold, Supabase client setup, Flovi-inspired auth/dashboard shell, and environment example while intentionally leaving relocation request CRUD for a later phase.

### What Changed

Created the dispatcher Vue 3 app scaffold with Vite, Tailwind CSS, Supabase client setup, `.env.example`, Google OAuth sign-in/sign-out shell, and a Flovi-inspired dashboard landing state.

### What Broke Or Needed Correction

Review caught several Tailwind opacity utilities using non-default values like `/8` and `/68`. They were corrected to bracketed arbitrary opacity syntax, then `npm run build` passed again.

### Why The Next Iteration Was Needed

The next iteration is needed to add the actual relocation request workflow: create, list, edit, status badges, and Supabase realtime refresh.

### Prompt Number

3

### Goal

Implement the dispatcher relocation workflow.

### Prompt Summary

Asked the AI to add the create request form, list all requests, status badges, edit/update existing requests, Supabase realtime/refetch after changes, checks, and a commit.

### AI Output Summary

The AI implemented authenticated dispatcher CRUD for request creation and detail updates, a polished operations queue, status summary cards, clear status badges, manual refresh, and realtime refetch on `relocation_requests` changes.

### What Changed

`apps/dispatcher-web/src/App.vue` now contains the full dispatcher workflow against Supabase while preserving the Flovi-inspired design system.

### What Broke Or Needed Correction

Review caught a couple of Tailwind opacity utilities that needed bracketed arbitrary syntax. After correction, `npm run build` passed.

### Why The Next Iteration Was Needed

The next iteration can move to the driver Flutter app scaffold and later connect driver booking to the same Supabase data.
