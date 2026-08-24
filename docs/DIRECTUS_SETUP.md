# Directus Setup for Hunny

This guide creates everything Hunny needs on your Directus instance
(`https://your-directus.example.com`): the collections, one role for the two players,
the two player users, and the first week's content.

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
> (e.g. "one completion per user per task per day", "one claim per task") to
> be race-proof when both devices write at the same moment. Each collection
> below therefore has a `dedupe_key` string field marked **Unique**. The app
> computes it (e.g. `<user>:<task>:<date>`); the second write hits the unique
> constraint and the app handles it gracefully. Don't edit these by hand.

### `players` — one row per device/user

| Field    | Type                    | Notes                                        |
| -------- | ----------------------- | -------------------------------------------- |
| `id`     | Integer (primary key)   | Auto-increment                               |
| `user`   | M2O → `directus_users`  | Many-to-One, related collection `directus_users`. **Tick Unique.** |
| `name`   | String                  | Display name shown in the app                |

The app creates/updates its own row on first connect — you don't seed this.

### `own_tasks` — the personal task list

| Field          | Type    | Notes                                                       |
| -------------- | ------- | ----------------------------------------------------------- |
| `id`           | Integer (primary key) | Auto-increment                                  |
| `title`        | String  | Required                                                     |
| `detail`       | Text    | Optional longer description                                  |
| `icon`         | String  | Optional SF Symbol name (e.g. `figure.run`, `book`)          |
| `max_per_week` | Integer | `1` = once a week; `4` = up to four times, max once per day  |
| `sort`         | Integer | Display order, default `0`                                   |
| `active`       | Boolean | Default `true` — flip to `false` to retire a task            |

### `task_completions` — one row per completed point

| Field           | Type                  | Notes                                        |
| --------------- | --------------------- | -------------------------------------------- |
| `id`            | Integer (primary key) | Auto-increment                               |
| `user`          | M2O → `directus_users` | Who completed it                            |
| `task`          | M2O → `own_tasks`     | The task                                      |
| `week_start`    | Date                  | Monday of that week, `yyyy-MM-dd`             |
| `completed_on`  | Date                  | The day it was completed                      |
| `dedupe_key`    | String                | **Unique.** `<user>:<task>:<completed_on>`    |

### `competition_tasks` — the weekly head-to-head

| Field        | Type                   | Notes                                    |
| ------------ | ---------------------- | ---------------------------------------- |
| `id`         | Integer (primary key)  | Auto-increment                           |
| `week_start` | Date                   | **Unique.** Monday, `yyyy-MM-dd`         |
| `title`      | String                 | Required                                 |
| `detail`     | Text                   | Optional                                 |
| `active`     | Boolean                | Default `true`                           |

### `competition_claims` — who won the head-to-head

| Field        | Type                   | Notes                                        |
| ------------ | ---------------------- | -------------------------------------------- |
| `id`         | Integer (primary key)  | Auto-increment                               |
| `task`       | M2O → `competition_tasks` | The week's task                          |
| `user`       | M2O → `directus_users` | Winner                                       |
| `claimed_at` | Timestamp              | Default: current date/time                   |
| `dedupe_key` | String                 | **Unique.** `task:<task id>` — first write wins |

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
| `user`       | M2O → `directus_users` | Who answered                                  |
| `body`       | Text                   | The answer                                    |
| `updated_on` | Timestamp              | Timestamp with an **on-update trigger** (the field-creation flow offers an "Updated On" timestamp type; otherwise set default current timestamp) |
| `dedupe_key` | String                 | **Unique.** `<question>:<user>`               |

### `nudges` — "answer the question!" pokes

| Field        | Type                   | Notes                              |
| ------------ | ---------------------- | ---------------------------------- |
| `id`         | Integer (primary key)  | Auto-increment                     |
| `question`   | M2O → `questions`      |                                    |
| `from_user`  | M2O → `directus_users` | Who nudged                         |
| `to_user`    | M2O → `directus_users` | Who was nudged                     |
| `seen_on`    | Timestamp              | Nullable — set when acknowledged   |

---

## 2. Role & permissions

Open **Settings → Access Control** (Directus 11: roles hold *policies*; creating
a role creates its initial policy automatically — you can do everything from the
role's permission grid).

Create a role **`Hunny Players`**:

- **Administrator access**: off
- **App access**: on (lets a player browse the Data Studio read-only-ish if you
  allow; token auth works either way)

Now configure permissions per collection. For each: set the action to
**Use Custom**, open its panel, set **Item permissions** (the rule) and
**Field presets** where noted. `$CURRENT_USER` is typed into the rule/preset
value field as the dynamic variable.

| Collection           | Action | Item permissions (rule)                     | Presets / notes                          |
| -------------------- | ------ | ------------------------------------------- | ---------------------------------------- |
| `players`            | Create | `user` **equals** `$CURRENT_USER`           | Preset `user` = `$CURRENT_USER`          |
|                      | Read   | All items                                   | Fields: all                              |
|                      | Update | `user` **equals** `$CURRENT_USER`           | Field permission: `name` only            |
| `own_tasks`          | Read   | All items                                   |                                          |
| `task_completions`   | Create | `user` **equals** `$CURRENT_USER`           | Preset `user` = `$CURRENT_USER`          |
|                      | Read   | All items (drives the live scoreboard)      |                                          |
| `competition_tasks`  | Read   | All items                                   | Admin writes these                       |
| `competition_claims` | Create | `user` **equals** `$CURRENT_USER`           | Preset `user` = `$CURRENT_USER`          |
|                      | Read   | All items                                   |                                          |
| `questions`          | Read   | All items                                   | Admin writes these                       |
| `answers`            | Create | `user` **equals** `$CURRENT_USER`           | Preset `user` = `$CURRENT_USER`          |
|                      | Read   | All items                                   |                                          |
|                      | Update | `user` **equals** `$CURRENT_USER`           | Field permission: `body` only            |
| `nudges`             | Create | `from_user` **equals** `$CURRENT_USER`      | Preset `from_user` = `$CURRENT_USER`     |
|                      | Read   | `to_user` **equals** `$CURRENT_USER`        |                                          |
|                      | Update | `to_user` **equals** `$CURRENT_USER`        | Field permission: `seen_on` only         |

Leave every **Delete** action unset (no deletes from the app).

Equivalent rule JSON (for the raw rule editor), e.g. `answers` update:

```json
{ "user": { "_eq": "$CURRENT_USER" } }
```

---

## 3. The two player users

Open **User Directory** and create two users (one per device):

1. **New User** → set a **Name** (this can match the display name), an email
   (anything unique, e.g. `hunny-a@example.com` — password login isn't used),
   role **Hunny Players**, **App access** enabled.
2. Repeat for the second device (e.g. `hunny-b@example.com`).
3. On each user's page, use **Generate Static Token** and copy the token
   immediately. Each user gets one static token that never expires; it's stored
   in `directus_users` and is the device's credential — keep it out of the repo.

Device A gets user A's token, device B gets user B's token. Paste each into
Hunny's setup screen along with the Directus URL and a display name. The app
registers each user in `players` automatically.

---

## 4. Seed this week's content

Weeks key off the Monday date (`yyyy-MM-dd`). This week's key is
**`2026-08-17`**; next week is `2026-08-24`. Only admin seeds content —
either via **Content** module in the Data Studio or with curl:

```bash
API=https://your-directus.example.com
ADMIN_TOKEN=your_admin_static_token
WEEK=2026-08-17

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
- Completions, claims, answers and nudges are all written by the app.

---

## 5. Verify

With a **player** token:

```bash
curl -s "$API/users/me?fields=id,first_name" -H "Authorization: Bearer $PLAYER_TOKEN"
curl -s "$API/items/own_tasks" -H "Authorization: Bearer $PLAYER_TOKEN"
```

You should see the user's id and the task list. If item queries come back
empty, re-check the role's Read permissions.

## How the mechanics map to tables (for reference)

- **Own tasks** → a `task_completions` row per point. The once-per-day rule is
  enforced by the `dedupe_key` unique index and by the app hiding the button
  once today's completion exists.
- **Competition** → both devices POST a `competition_claims` row; the unique
  `dedupe_key` means only the first insert survives, so "whoever completed it
  first" is decided by the database, not by clocks or connectivity.
- **Question** → one `answers` row per user per question; each device sees the
  other's row only when it exists. A nudge is a `nudges` row that surfaces as
  a banner on the other device until acknowledged.
