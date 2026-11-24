# CLAUDE.md: UraxOS

Read `plan/UraxOS_PLAN_v7.md` first. It is the master plan and prompt. The UX source of truth is `design/console-mockup-v4-latest.html`
(open it in a browser; it is one self-contained file). Older plans and mockups are in `plan/archive` and `design/archive` for history only.

## Working rules
- The owner chats in Arabic (formal Arabic, short answers, step-by-step explanations because he wants to learn). Code, comments and docs stay in English.
- Do not use cards/widget-style formatting in chat. Put anything he must copy in a code block. When you mention a website or app, give the direct link as plain text.
- Ask before deviating from the mockup, before changing design decisions, and before choosing the base distro (propose options, wait for approval).
- Do NOT write or explain exploit/jailbreak code. For the optional PS4 target, assume GoldHEN is already running.
- The owner is often away from his PC and has no PS4 at hand. Build and verify in the cloud (QEMU/VM, headless screenshots), mock hardware behind interfaces, and keep a short "verify on real hardware" checklist per phase.
- Keep the theme layer (colors, fonts, logo) separate from logic.

## Status
See `docs/progress-log.md` for what is done, what is decided, and what is still open.
