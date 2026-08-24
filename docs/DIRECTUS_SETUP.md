# Directus Setup for Hunny

This guide creates everything Hunny needs on your Directus instance: the
collections, one role, and **a single service token**. That's the whole setup —
nobody logs in anywhere.

**How identity works instead:** on first launch each device types two names —
"your name" and "their name". Both devices enter the same two names (swapped),
and those exact strings are the players' identity. Matching is case-sensitive
and happens inside the app, so your database's collation settings don't matter.
The server address and the service token are baked into official builds from
GitHub secrets and never appear in this repo.

Written against the current Directus docs (Directus 11.x, Access Control with
roles & policies) — key references:

- Users & static tokens: <https://docs.directus.app/user-guide/users/users.html>
- Roles, policies & permissions: <https://docs.directus.app/user-guide/users/roles.html>
- Collections: <https://docs.directus.app/user-guide/data-model/collections.html>
- Fields: <https://docs.directus.app/user-guide/data-model/fields.html>

**Assumptions**

- Your admin user creates the collections and weekly content.
- Both devices are in the same time zone (weeks run Monday → Sunday locally,
  and day boundaries for the "once a day" rule use the device's local date).
- All field names below are snake_case and must match exactly — the app talks
  to the REST API, which uses these names verbatim.

---

## 1. Collections (Data Model)

Open **Settings → Data Model** and create these eight collections. Use the
default auto-increment integer primary key (`id`) for all of them.

> **About unique constraints** — the Data Model UI can mark a *single field*
> unique, but not a combination of fields. Hunny needs composite uniqueness
> (e.g. "one completion per player per task per day", "one claim per task") to
> be race-proof when both devices write at the same moment. Each collection
> below therefore has a `dedupe_key` string field marked **Unique**. The app
> computes it (e.g. `<player>:<task>:<date>`); the second write hits the unique
> constraint and the app handles it gracefully. Don't edit these by hand.

### `players` — a name registry (drives the "waiting to join…" hint)

| Field       | Type                   | Notes                          |
| ----------- | ---------------------- | ------------------------------ |
| `id`        | Integer (primary key)  | Auto-increment                 |
| `name`      | String                 | **Unique.** The exact player name |
| `joined_on` | Timestamp              | Default: current date/time     |

The app creates a row the first time a device connects. You don't seed this.

### `own_tasks` — the personal task list

| Field          | Type    | Notes                                                       |
| -------------- | ------- | ----------------------------------------------------------- |
| `id`           | Integer (primary key) | Auto-increment                                  |
| `title`        | String  | Required                                                     |
| `detail`       | Text    | Optional longer description                                  |
| `icon`         | String  | Optional SF Symbol name (e.g. `figure.run`, `book`)          |
| `max_per_week` | Integer | `1` = once a week; `4` = up to four times, max once per day  |
| `sort`         | Integer | Display order, default `0`                                   |
| `active`       | Boolean | `false` hides the task — the app's editor always sends it on create |

### `task_completions` — one row per completed point

| Field           | Type                  | Notes                                          |
| --------------- | --------------------- | ---------------------------------------------- |
| `id`            | Integer (primary key) | Auto-increment                                 |
| `player`        | String                | Player name, exactly as typed on their device  |
| `task`          | M2O → `own_tasks`     | The task                                        |
| `week_start`    | Date                  | Monday of that week, `yyyy-MM-dd`               |
| `completed_on`  | Date                  | The day it was completed                        |
| `dedupe_key`    | String                | **Unique.** `<player>:<task>:<completed_on>`    |

### `competition_tasks` — the weekly head-to-head

| Field        | Type                   | Notes                                    |
| ------------ | ---------------------- | ---------------------------------------- |
| `id`         | Integer (primary key)  | Auto-increment                           |
| `week_start` | Date                   | **Unique.** Monday, `yyyy-MM-dd`         |
| `title`      | String                 | Required                                 |
| `detail`     | Text                   | Optional                                 |
| `active`     | Boolean                | Default `true`                           |

### `competition_claims` — who won the head-to-head

| Field        | Type                   | Notes                                            |
| ------------ | ---------------------- | ------------------------------------------------ |
| `id`         | Integer (primary key)  | Auto-increment                                   |
| `task`       | M2O → `competition_tasks` | The week's task                              |
| `player`     | String                 | Winner's name                                    |
| `claimed_at` | Timestamp              | Default: current date/time                       |
| `dedupe_key` | String                 | **Unique.** `task:<task id>` — first write wins  |

### `questions` — question of the week

| Field        | Type                  | Notes                            |
| ------------ | --------------------- | -------------------------------- |
| `id`         | Integer (primary key) | Auto-increment                   |
| `week_start` | Date                  | **Unique.** Monday, `yyyy-MM-dd` |
| `text`       | String                | The question                     |
| `active`     | Boolean               | Default `true`                   |

### `answers` — each device's answer

| Field        | Type                   | Notes                                        |
| ------------ | ---------------------- | -------------------------------------------- |
| `id`         | Integer (primary key)  | Auto-increment                               |
| `question`   | M2O → `questions`      |                                              |
| `player`     | String                 | Who answered                                 |
| `body`       | Text                   | The answer                                   |
| `updated_on` | Timestamp              | Timestamp with an **on-update trigger** (the field-creation flow offers an "Updated On" timestamp type; otherwise set default current timestamp) |
| `dedupe_key` | String                 | **Unique.** `<question>:<player>`            |

### `nudges` — "answer the question!" pokes

| Field         | Type                  | Notes                              |
| ------------- | --------------------- | ---------------------------------- |
| `id`          | Integer (primary key) | Auto-increment                     |
| `question`    | M2O → `questions`     |                                    |
| `from_player` | String                | Who nudged                         |
| `to_player`   | String                | Who was nudged                     |
| `seen_on`     | Timestamp             | Nullable — set when acknowledged   |

---

## 2. Role & permissions

Open **Settings → Access Control** (Directus 11: roles hold *policies*;
creating a role creates its initial policy automatically — you can do
everything from the role's permission grid).

Create a role **`Hunny App`**:

- **Administrator access**: off
- **App access**: off — this role exists purely for its token; nobody signs
  into the Data Studio with it.

The app's single token speaks for both devices, and the app enforces which
player each write belongs to — so permissions are simple, no per-item rules
are needed:

| Collection           | Create | Read | Update | Delete |
| -------------------- | ------ | ---- | ------ | ------ |
| `players`            | ✅     | ✅   | —      | —      |
| `own_tasks`          | ✅     | ✅   | ✅ (task editor fields) | —      |
| `task_completions`   | ✅     | ✅   | —      | —      |
| `competition_tasks`  | —      | ✅   | —      | —      |
| `competition_claims` | ✅     | ✅   | —      | —      |
| `questions`          | —      | ✅   | —      | —      |
| `answers`            | ✅     | ✅   | ✅ (own edits) | — |
| `nudges`             | ✅     | ✅   | ✅ (`seen_on` only) | — |

For the three Update actions, use **Use Custom** and limit **Field permissions**
to `body` (answers), `seen_on` (nudges), and `title, detail, icon, max_per_week,
sort, active` (own_tasks — used by the app's hidden task editor, opened by
tapping your profile avatar five times on the score header). Everything else
can be set to full "All items" access for the listed actions. No deletes from
the app — retire a task by flipping `active` off instead.

---

## 3. The service token

One user, one token, shared by the app itself:

1. **User Directory → New User** — name it e.g. `Hunny App`, email anything
   unique (e.g. `hunny-app@example.com`, password login is never used), role
   **Hunny App**, app access disabled.
2. On the user's page, use **Generate Static Token** and copy it immediately —
   it's the app's only credential.
3. Store it as the `DIRECTUS_TOKEN` secret in the Hunny repo
   (**Settings → Secrets and variables → Actions → New repository secret**,
   or `gh secret set DIRECTUS_TOKEN --repo CadeL4D/Hunny`). Official builds
   inject it (base64-encoded) alongside the `DIRECTUS_URL` secret you've
   already set.

Without this secret, official builds compile and run but can't reach the API —
the app will say so when you tap connect.

---

## 4. Seed this week's content

Weeks key off the Monday date (`yyyy-MM-dd`). Only admin seeds content —
either via the **Content** module in the Data Studio or with curl:

```bash
API=https://your-directus.example.com
ADMIN_TOKEN=your_admin_static_token
WEEK=2026-08-24   # the Monday of the current week

# Personal tasks (max_per_week: 1 = weekly, 4 = once a day up to 4×)
curl -sX POST "$API/items/own_tasks" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '[{"title":"Work out","max_per_week":1,"icon":"figure.run","sort":1},
       {"title":"Tidy the kitchen","max_per_week":4,"icon":"trash","sort":2}]'

# This week's head-to-head
curl -sX POST "$API/items/competition_tasks" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d "{\"week_start\":\"$WEEK\",\"title\":\"First to book the restaurant wins\"}"

# This week's question
curl -sX POST "$API/items/questions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d "{\"week_start\":\"$WEEK\",\"text\":\"If we could teleport anywhere this weekend, where?\"}"
```

### Weekly rhythm

- **Each new week**: add one `competition_tasks` row and one `questions` row
  with the new Monday date (the unique `week_start` blocks accidental doubles).
- **Own tasks** carry over every week automatically — toggle `active` to
  retire/add tasks whenever you like.
- Players, completions, claims, answers and nudges are all written by the app.

---

## 5. Verify

With the **service** token:

```bash
curl -s "$API/items/own_tasks" -H "Authorization: Bearer $SERVICE_TOKEN"
```

You should see the seeded task list. If item queries come back empty,
re-check the role's Read permissions.

## How the mechanics map to tables (for reference)

- **Pairing** — each device registers its own name in `players` on first
  connect; the partner's column in the app shows "waiting to join…" until a
  row with the exact same name appears. If scores never show up for one side,
  check that both devices spell both names identically, capitals included.
- **Own tasks** → a `task_completions` row per point. The once-per-day rule is
  enforced by the `dedupe_key` unique index and by the app hiding the button
  once today's completion exists.
- **Competition** → both devices POST a `competition_claims` row; the unique
  `dedupe_key` means only the first insert survives, so "whoever completed it
  first" is decided by the database, not by clocks or connectivity.
- **Question** → one `answers` row per player per question; each device sees
  the other's row only when it exists. A nudge is a `nudges` row that surfaces
  as a banner on the other device until acknowledged.
