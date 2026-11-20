---
name: jivo-request
description: "Write a ready-to-send message (email/WhatsApp/Slack) to Jivo IT, management or marketing asking for credentials, accounts, data or decisions the project is waiting on (H-xx items, open decisions D-xx in docs/11, setup PDFs like the Razorpay/Google Maps ones). Use whenever the user asks 'what does Jivo need to give us', 'write a message for Jivo', or a task is blocked on a Jivo input."
---

# Message to Jivo

The user forwards these as is, so they must be complete, plain and safe.

## 1. Gather (from the repo, not memory)
- `docs/task-tracker.md` `## Waiting on you or Jivo` (H-xx rows) and `docs/11-open-decisions.md` (D-xx, recommended defaults).
- The code/settings that consume the input: env var names in `infra/env/backend.env.example` and `backend/config/settings/`, key file paths under `~/.config/jivo-quick-commerce/` (Maps, Firebase), app ids (`in.jivo.quick`, `.dev`, `.staging`) and signing SHA-1 (H-15).
- Earlier messages/PDFs in `docs/` (`Jivo-QC-*-setup-*.pdf`) for tone and what was already asked.

## 2. Write it
```
Subject: <Service> setup for Jivo Quick Commerce: details needed

Hi team,

<1–2 sentences: what it's for and that our side is ready / what it unblocks.>

**<Group, e.g. From the MSG91 account>**
1. **<Item>**: <what exactly, format/example>. <Why, if not obvious.>
...

<Alternatives / "if you already have X, send Y instead".>

Thanks,
[Your name]
```
Rules:
- Ask for secrets (API keys, auth keys, passwords, service-account JSON) to be shared **securely** (password manager / 1:1 secure channel), never by plain email or a group chat.
- Never include our secrets, `.env` values, staff passwords, server IPs or internal hostnames beyond public domains.
- Give exact identifiers they must configure (package/bundle ids, SHA-1, callback/webhook URLs, DLT template text with `{#var#}`) so there's no back-and-forth.
- One message per recipient team; group items; numbered so they can answer "1: done, 2: pending".
- Mark items that are a decision (not a credential) and give our recommended default from doc 11.

## 3. After sending
Offer to record it: `pm-task` → H-xx status `Requested YYYY-MM-DD (<channel>)`. When the inputs arrive, store keys outside the repo (`~/.config/jivo-quick-commerce/...` or server env) and never paste them into chat logs or commits.
