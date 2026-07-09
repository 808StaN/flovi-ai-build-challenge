# Flovi AI Build Challenge Agent Guide

This repository is for the 4-hour Flovi AI Build Challenge. The goal is to ship two connected apps for a relocation workflow: a dispatcher dashboard and a driver booking app.

## Project Context

- Use Vue 3, Vite, Tailwind CSS, Flutter 3, Supabase, and Vercel.
- Use Supabase for Google OAuth, PostgreSQL data storage, and realtime or near-realtime sync.
- Deploy the dispatcher Vue app to Vercel.
- Deploy the Flutter driver app as a Flutter Web build on Vercel.
- Keep the UI modern, polished, logistics-focused, and Flovi-inspired. Avoid tutorial-style screens.
- Prioritize a working end-to-end demo over unnecessary features.

## Working Rules

- Prefer small, testable changes over large rewrites.
- After each implementation step, run relevant checks or builds before moving on.
- Preserve a clean commit history with commits at meaningful milestones.
- Record key prompts, decisions, failures, and corrections in `docs/prompt-log.md`.
- Keep implementation practical for a 4-hour sprint.
- Do not overengineer roles, permissions, or app architecture unless required for the demo.

## Product Rules

- Dispatcher creates and manages relocation requests.
- Driver browses available requests and books one with confirmation.
- Both apps must use the same Supabase project and shared `relocation_requests` table.
- Status values are `available`, `booked`, and `completed`.
- Booking must be atomic and demo-safe.

## UI Direction

- Use a deep navy/purple base.
- Use bright mint green for primary CTAs and accents.
- Use soft blue, yellow, and purple accent cards where useful.
- Prefer rounded cards, pill buttons, bold typography, generous spacing, and clear status badges.
- Dispatcher should feel like a polished operations dashboard.
- Driver should feel like a clean mobile-first gig booking app.
