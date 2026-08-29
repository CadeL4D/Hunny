// Hunny web — a 1:1 port of the SwiftUI app to plain HTML/CSS/JS.
//
// The layout of this file mirrors the Swift sources so the two stay
// diffable: ServerConfig, Theme, Week/ISO, DiagnosticLog, Haptics,
// DirectusClient + APIError (Directus/DirectusClient.swift), the app state
// and every action (State/AppState.swift), then one render function per view
// in Views/*.swift. Identity is the same, too: no login, just the two names
// typed at setup, matched case-sensitively against Directus rows.
//
// Server URL and token come from config.js, which CI fills from repository
// secrets at deploy time (the committed copy is empty).

(function () {
  'use strict';

  // MARK: ServerConfig (Generated/ServerConfig.swift)

  const CONFIG = window.HUNNY_CONFIG || { baseURL: '', token: '' };

  // MARK: Theme (Theme.swift)

  const Theme = {
    accent: '#ffad1d',     // rgb(1.00, 0.68, 0.09)
    accentDeep: '#ff7821', // rgb(1.00, 0.47, 0.13)
  };

  // MARK: Small utilities

  const esc = (value) => String(value == null ? '' : value).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));

  // JSON with sorted keys, matching JSONSerialization's .sortedKeys in the
  // Swift client so request bodies are byte-identical.
  function sortedStringify(value) {
    if (value === undefined) return 'null';
    if (Array.isArray(value)) return '[' + value.map(sortedStringify).join(',') + ']';
    if (value && typeof value === 'object') {
      return '{' + Object.keys(value).sort()
        .map((key) => JSON.stringify(key) + ':' + sortedStringify(value[key])).join(',') + '}';
    }
    return JSON.stringify(value);
  }

  // MARK: Week + ISO (Support/Week.swift)
  // Weeks run Monday → Sunday in the device's local time zone; a week key is
  // the yyyy-MM-dd string of that week's Monday.

  const pad = (n) => String(n).padStart(2, '0');
  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  function dayKey(date) {
    return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate());
  }

  function monday(date = new Date()) {
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
    return d;
  }

  const Week = {
    currentKey: () => dayKey(monday()),
    todayKey: () => dayKey(new Date()),
    rangeLabel() {
      const start = monday();
      const end = new Date(start);
      end.setDate(end.getDate() + 6);
      return MONTHS[start.getMonth()] + ' ' + start.getDate()
        + ' – ' + MONTHS[end.getMonth()] + ' ' + end.getDate();
    },
  };

  // Timestamps sent to Directus: UTC ISO-8601 with milliseconds.
  const ISO = {
    now() {
      const d = new Date();
      return d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1) + '-' + pad(d.getUTCDate())
        + 'T' + pad(d.getUTCHours()) + ':' + pad(d.getUTCMinutes()) + ':' + pad(d.getUTCSeconds())
        + '.' + String(d.getUTCMilliseconds()).padStart(3, '0') + 'Z';
    },
  };

  // Swift's .relative(presentation: .named): "2 hours ago", "yesterday"…
  function relativeTime(raw) {
    const date = new Date(raw);
    if (isNaN(date.getTime())) return '';
    let seconds = Math.floor((Date.now() - date.getTime()) / 1000);
    if (seconds < 0) seconds = 0;
    if (seconds < 5) return 'just now';
    if (seconds < 60) return seconds === 1 ? '1 second ago' : seconds + ' seconds ago';
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return minutes === 1 ? '1 minute ago' : minutes + ' minutes ago';
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return hours === 1 ? '1 hour ago' : hours + ' hours ago';
    const days = Math.floor(hours / 24);
    if (days === 1) return 'yesterday';
    if (days < 7) return days + ' days ago';
    const weeks = Math.floor(days / 7);
    if (weeks === 1) return 'last week';
    if (weeks < 5) return weeks + ' weeks ago';
    const months = Math.floor(days / 30);
    return months === 1 ? 'last month' : months + ' months ago';
  }

  // MARK: DiagnosticLog (Support/Diagnostics.swift)

  const DiagnosticLog = {
    capacity: 200,
    entries: [],
    record(line) {
      const now = new Date();
      this.entries.push(
        pad(now.getHours()) + ':' + pad(now.getMinutes()) + ':' + pad(now.getSeconds())
        + '.' + String(now.getMilliseconds()).padStart(3, '0') + ' ' + line
      );
      if (this.entries.length > this.capacity) {
        this.entries.splice(0, this.entries.length - this.capacity);
      }
    },
    formatted() {
      const now = new Date().toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'medium' });
      return ['Hunny Web · ' + navigator.userAgent, now, '—'].concat(this.entries).join('\n');
    },
  };

  // MARK: Haptics (Support/Haptics.swift) — vibration where the browser has it.

  const Haptics = {
    vibrate(pattern) { if (navigator.vibrate) navigator.vibrate(pattern); },
    tap() { this.vibrate(8); },
    success() { this.vibrate([10, 40, 20]); },
    warning() { this.vibrate([30, 60, 30]); },
  };

  // MARK: Notifications (Support/Notifications.swift)
  // Daily 7:00 question ping and 19:00 tasks check-in, plus an immediate
  // alert when a nudge arrives. Browsers can't wake a closed page, so these
  // fire while the app is actually open (same for an iOS home-screen web
  // app) — the native app's local notifications cover the closed case.
  // requestPermission must run inside the connect tap for iOS Safari.

  const Notify = {
    supported: 'Notification' in window,
    timers: [],
    alertedNudges: new Set(),

    async requestIfNeeded() {
      if (!this.supported || Notification.permission !== 'default') return;
      try { await Notification.requestPermission(); } catch (_) { /* unsupported */ }
    },

    granted() { return this.supported && Notification.permission === 'granted'; },

    // Timers only run while the page is alive, so re-arm on every
    // visibility change; the 19:00 body reads the latest nudge state.
    scheduleDaily() {
      if (!this.granted()) return;
      this.timers.forEach(clearTimeout);
      this.timers = [];
      this.arm(7, 'This week\u2019s question 🍯', 'Answer it, then see what your partner said.');
      const nudger = app.unseenNudges.length
        ? (app.unseenNudges[0].from_player || 'Your partner')
        : null;
      this.arm(19, 'Tasks check-in 🐝', nudger
        ? nudger + ' nudged you about this week\u2019s question — and there may be tasks left today.'
        : 'Any tasks left today? Points don\u2019t earn themselves.');
    },

    arm(hour, title, body) {
      const at = new Date();
      at.setHours(hour, 0, 0, 0);
      if (at <= new Date()) at.setDate(at.getDate() + 1);
      this.timers.push(setTimeout(() => {
        this.show(title, body);
        this.scheduleDaily();
      }, at - new Date()));
    },

    nudgeAlert(from, id) {
      if (!this.granted() || this.alertedNudges.has(id)) return;
      this.alertedNudges.add(id);
      this.show((from || 'Your partner') + ' nudged you 🐝',
        'They\u2019re waiting on your answer to this week\u2019s question.');
    },

    show(title, body) {
      try { new Notification(title, { body }); } catch (_) { /* no SW, some browsers */ }
    },

    cancel() {
      this.timers.forEach(clearTimeout);
      this.timers = [];
      this.alertedNudges.clear();
    },
  };

  // Answer validation (Support/AnswerRules.swift): 10-word minimum with a
  // 20-character floor, so ten one-letter tokens can't pass as words.
  const AnswerRules = {
    minimumWords: 10,
    characterFloor: 20,
    words(text) { return text.split(/\s+/).filter(Boolean).length; },
    isValid(text) {
      const trimmed = String(text || '').trim();
      return trimmed.length > this.characterFloor
        && this.words(trimmed) >= this.minimumWords;
    },
    hint(text) {
      if (this.isValid(text)) return '';
      const remaining = Math.max(0, this.minimumWords - this.words(String(text || '').trim()));
      return '10-word minimum · ' + remaining + ' to go';
    },
  };

  // MARK: APIError + DirectusClient (Directus/DirectusClient.swift)

  class APIError extends Error {
    constructor(status, message) {
      super(message);
      this.status = status;
    }
    // Directus reports unique-constraint violations as a 400/409 whose
    // message mentions the constraint. Hunny leans on these for race-proof
    // writes.
    get isUniqueViolation() {
      if (this.status !== 400 && this.status !== 409) return false;
      const lowered = this.message.toLowerCase();
      return lowered.includes('unique') || lowered.includes('duplicate');
    }
    static from(status, text) {
      try {
        const parsed = JSON.parse(text);
        const message = parsed && parsed.errors
          ? parsed.errors.map((e) => e.message).filter(Boolean)[0] : null;
        if (message) return new APIError(status, message);
      } catch (_) { /* not a Directus error envelope */ }
      return new APIError(status, 'Request failed (HTTP ' + status + ') — ' + text.slice(0, 200));
    }
  }

  function normalizedBaseURL() {
    let candidate = String(CONFIG.baseURL || '').trim();
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      candidate = 'https://' + candidate;
    }
    try {
      const url = new URL(candidate);
      if ((url.protocol !== 'http:' && url.protocol !== 'https:') || !url.host) return null;
      return url.origin + url.pathname.replace(/\/+$/, '');
    } catch (_) {
      return null;
    }
  }

  function hasClient() {
    return normalizedBaseURL() != null && String(CONFIG.token || '') !== '';
  }

  const Filter = {
    eq: (field, value) => sortedStringify({ [field]: { _eq: value } }),
  };

  const client = {
    async request(method, path, { query, body } = {}) {
      let url = normalizedBaseURL() + '/' + path;
      if (query && Object.keys(query).length) {
        url += '?' + Object.keys(query).sort()
          .map((key) => encodeURIComponent(key) + '=' + encodeURIComponent(query[key])).join('&');
      }
      const headers = { Authorization: 'Bearer ' + CONFIG.token, Accept: 'application/json' };
      let bodyText;
      if (body) {
        headers['Content-Type'] = 'application/json';
        bodyText = sortedStringify(body);
      }
      const started = Date.now();
      let response;
      try {
        response = await fetch(url, { method, headers, body: bodyText });
      } catch (networkError) {
        throw new APIError(-1, 'No response from the server');
      }
      const text = await response.text();
      const elapsed = (Date.now() - started) + 'ms';
      const contentType = response.headers.get('content-type') || 'no content-type';
      if (!response.ok) {
        const error = APIError.from(response.status, text);
        DiagnosticLog.record(method + ' ' + path + ' → ' + response.status
          + ' [' + contentType + '] ' + elapsed + ' — ' + error.message);
        throw error;
      }
      let envelope;
      // Directus answers DELETE with 204 No Content — nothing to decode.
      if (text === '') return undefined;
      try {
        envelope = JSON.parse(text);
      } catch (_) {
        const detail = 'invalid JSON at root body: ' + text.slice(0, 300);
        DiagnosticLog.record(method + ' ' + path + ' → ' + response.status
          + ' [' + contentType + '] ' + elapsed + ' — DECODE FAILED · ' + detail);
        throw new APIError(response.status, method + ' ' + path + ': ' + detail);
      }
      DiagnosticLog.record(method + ' ' + path + ' → ' + response.status
        + ' [' + contentType + '] ' + elapsed + ' · ' + text.length + 'B');
      return envelope.data;
    },
    list(path, query) { return this.request('GET', path, { query }); },
    create(path, body) { return this.request('POST', path, { body }); },
    update(path, body) { return this.request('PATCH', path, { body }); },
    del(path) { return this.request('DELETE', path, {}); },
  };

  // MARK: App state (State/AppState.swift)
  // The UI is a pure function of this object; every action mutates it and
  // calls render(), mirroring @Published + SwiftUI invalidation.

  const MY_NAME_KEY = 'hunny.my-name';
  const PARTNER_NAME_KEY = 'hunny.partner-name';

  const storage = {
    get(key) { try { return localStorage.getItem(key); } catch (_) { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch (_) { /* private mode */ } },
    remove(key) { try { localStorage.removeItem(key); } catch (_) { /* private mode */ } },
  };

  const app = {
    myName: storage.get(MY_NAME_KEY) || '',
    partnerName: storage.get(PARTNER_NAME_KEY) || '',

    isReady: false,
    isLoading: false,
    errorMessage: null,
    selectedTab: 0,

    players: [],
    tasks: [],
    allTasks: [],         // retired included — data for the hidden task editor
    completions: [],
    competitionTask: null,
    claim: null,
    question: null,
    answers: [],
    unseenNudges: [],

    // Web-only UI state (SwiftUI keeps this in @State inside the views).
    settingsDraft: null,  // { myName, partnerName } while SetupView is alive
    copiedDiagnostics: false,
    sheetStack: [],       // 'settings' | 'admin' | 'task-form' | 'competition-form'
    admin: { isLoading: false, loadError: null, menuOpen: false },
    form: null,
    draft: '',            // QuestionView's answer editor
    draftSynced: false,
    profileTapCount: 0,
    lastProfileTap: 0,
  };

  // Derived values.

  function isConfigured() {
    return normalizedBaseURL() != null
      && String(CONFIG.token || '') !== ''
      && app.myName !== ''
      && app.partnerName !== ''
      && app.myName !== app.partnerName;
  }

  function partnerHasJoined() {
    return app.players.some((p) => p.name === app.partnerName);
  }

  function myCompletions() { return app.completions.filter((c) => c.player === app.myName); }
  function partnerCompletions() { return app.completions.filter((c) => c.player === app.partnerName); }

  function myPoints() {
    return myCompletions().length + (app.claim && app.claim.player === app.myName ? 1 : 0);
  }

  function partnerPoints() {
    const claimed = app.claim != null && app.claim.player === app.partnerName;
    return partnerCompletions().length + (claimed ? 1 : 0);
  }

  function myAnswer() { return app.answers.find((a) => a.player === app.myName) || null; }
  function theirAnswer() { return app.answers.find((a) => a.player === app.partnerName) || null; }

  function completionsThisWeek(task) {
    return myCompletions().filter((c) => c.task === task.id);
  }

  // Weekly tasks (1×) complete once per week; daily tasks once per day, up to
  // their weekly cap.
  function canComplete(task) {
    const mine = completionsThisWeek(task);
    if (task.max_per_week <= 1) return mine.length === 0;
    const doneToday = mine.some((c) => c.completed_on === Week.todayKey());
    return !doneToday && mine.length < task.max_per_week;
  }

  // MARK: Actions (State/AppState.swift)

  function saveNames(myName, partnerName) {
    app.myName = myName;
    app.partnerName = partnerName;
    storage.set(MY_NAME_KEY, myName);
    storage.set(PARTNER_NAME_KEY, partnerName);
  }

  function signOut() {
    storage.remove(MY_NAME_KEY);
    storage.remove(PARTNER_NAME_KEY);
    app.myName = '';
    app.partnerName = '';
    app.isReady = false;
    app.players = [];
    app.tasks = [];
    app.allTasks = [];
    app.completions = [];
    app.competitionTask = null;
    app.claim = null;
    app.question = null;
    app.answers = [];
    app.unseenNudges = [];
    app.sheetStack = [];
    app.settingsDraft = null;
    app.form = null;
    Notify.cancel();
    stopPolling();
  }

  async function connect() {
    if (!isConfigured()) return;
    if (!hasClient()) {
      app.errorMessage = 'This build has no server configured. Install an official build from the GitHub Releases page.';
      render();
      return;
    }
    app.isLoading = true;
    render();
    try {
      try {
        // Register this name so the other device can see we've joined.
        await client.create('items/players', { name: app.myName });
      } catch (error) {
        if (!(error instanceof APIError) || !error.isUniqueViolation) throw error;
        // Already registered from an earlier run — fine.
      }
      app.isReady = true;
      startPolling();
      await Notify.requestIfNeeded();
      Notify.scheduleDaily();
      await refresh();
    } catch (error) {
      app.errorMessage = "Couldn't connect: " + error.message;
      Haptics.warning();
    } finally {
      app.isLoading = false;
      render();
    }
  }

  // Pulls everything the current week needs. Name-based filtering happens
  // here, client-side, so it's always exactly case-sensitive.
  async function refresh(quiet = false) {
    if (!hasClient()) return;
    const week = Week.currentKey();
    app.isLoading = true;
    if (!quiet) render();
    try {
      const [players, tasks, completions, competitions, questions] = await Promise.all([
        client.list('items/players', { fields: 'id,name', sort: 'id', limit: '10' }),
        client.list('items/own_tasks', {
          filter: Filter.eq('active', true),
          fields: 'id,title,detail,icon,max_per_week',
          sort: 'sort,id',
          limit: '200',
        }),
        client.list('items/task_completions', {
          filter: Filter.eq('week_start', week),
          fields: 'id,player,task,week_start,completed_on',
          limit: '1000',
        }),
        client.list('items/competition_tasks', {
          filter: Filter.eq('week_start', week),
          fields: 'id,title,detail,week_start',
          limit: '1',
        }),
        client.list('items/questions', {
          filter: Filter.eq('week_start', week),
          fields: 'id,text,week_start',
          limit: '1',
        }),
      ]);

      app.players = players;
      app.tasks = tasks;
      app.completions = completions;
      app.competitionTask = competitions[0] || null;
      app.question = questions[0] || null;

      if (app.competitionTask) {
        const claims = await client.list('items/competition_claims', {
          filter: Filter.eq('task', app.competitionTask.id),
          fields: 'id,task,player,claimed_at',
          limit: '1',
        });
        app.claim = claims[0] || null;
      } else {
        app.claim = null;
        await carryForwardCompetition();
      }

      if (app.question) {
        app.answers = await client.list('items/answers', {
          filter: Filter.eq('questions', app.question.id),
          fields: 'id,questions,player,body,updated_on',
          limit: '10',
        });
        if (app.myName !== '') {
          const nudges = await client.list('items/nudges', {
            filter: Filter.eq('questions', app.question.id),
            fields: 'id,questions,from_player,to_player,seen_on',
            sort: '-id',
            limit: '50',
          });
          app.unseenNudges = nudges.filter((n) => n.to_player === app.myName && n.seen_on == null);
          app.unseenNudges.forEach((n) => Notify.nudgeAlert(n.from_player, n.id));
        }
      } else {
        app.answers = [];
        app.unseenNudges = [];
      }
    } catch (error) {
      if (!quiet) app.errorMessage = error.message;
    } finally {
      app.isLoading = false;
      render();
    }
  }

  // Task administration — hidden editor, five taps on your profile avatar.

  async function loadAllTasks() {
    app.allTasks = await client.list('items/own_tasks', {
      fields: 'id,title,detail,icon,max_per_week,sort,active',
      sort: 'sort,id',
      limit: '200',
    });
  }

  async function createTask({ title, detail, icon, maxPerWeek }) {
    const body = {
      title,
      max_per_week: Math.max(1, maxPerWeek),
      sort: Math.max(0, ...app.allTasks.map((t) => t.sort || 0)) + 1,
      // The collection defaults active to false — send it explicitly.
      active: true,
    };
    if (detail !== '') body.detail = detail;
    if (icon !== '') body.icon = icon;
    await client.create('items/own_tasks', body);
    await reloadAfterTaskChange();
  }

  async function updateTask(task, body) {
    await client.update('items/own_tasks/' + task.id, body);
    await reloadAfterTaskChange();
  }

  async function reloadAfterTaskChange() {
    try { await loadAllTasks(); } catch (_) { /* surfaced by the next refresh */ }
    await refresh(true);
  }

  // Create or edit this week's head-to-head. Each week gets its own row
  // (claims hang off the row), but edits persist into future weeks via
  // carryForwardCompetition().
  async function saveCompetition(title, detail) {
    const body = { title, detail: detail === '' ? null : detail };
    if (app.competitionTask) {
      await client.update('items/competition_tasks/' + app.competitionTask.id, body);
    } else {
      body.week_start = Week.currentKey();
      await client.create('items/competition_tasks', body);
    }
    await refresh(true);
  }

  // Keeps the head-to-head going without anyone re-adding it each week: if
  // this week has no row yet, copy the most recent one forward. A unique
  // violation just means the partner's device won the race.
  async function carryForwardCompetition() {
    if (!hasClient()) return;
    try {
      const previous = await client.list('items/competition_tasks', {
        filter: sortedStringify({ week_start: { _lte: Week.currentKey() } }),
        fields: 'id,title,detail,week_start',
        sort: '-week_start',
        limit: '1',
      });
      const latest = previous[0];
      if (!latest || latest.week_start === Week.currentKey()) return;
      const body = { title: latest.title, week_start: Week.currentKey() };
      if (latest.detail != null) body.detail = latest.detail;
      app.competitionTask = await client.create('items/competition_tasks', body);
    } catch (error) {
      if (error instanceof APIError && error.isUniqueViolation) {
        // Partner device copied it first — the next refresh picks up its row.
        return;
      }
      DiagnosticLog.record('carry-forward skipped: ' + error.message);
    }
  }

  // Player actions.

  async function completeTask(task) {
    if (!canComplete(task) || !hasClient()) return;
    const body = {
      player: app.myName,
      task: task.id,
      week_start: Week.currentKey(),
      completed_on: Week.todayKey(),
      dedupe_key: app.myName + ':' + task.id + ':' + Week.todayKey(),
    };
    try {
      const completion = await client.create('items/task_completions', body);
      app.completions.push(completion);
      Haptics.success();
      render();
    } catch (error) {
      handleFailure(error);
    }
  }

  // Undo an accidental completion: removes the most recent one for the task
  // (today's, if several days are in play — the accidental tap is always the
  // fresh one).
  async function uncompleteTask(task) {
    let latest = null;
    for (const completion of completionsThisWeek(task)) {
      if (latest == null
        || completion.completed_on > latest.completed_on
        || (completion.completed_on === latest.completed_on && completion.id > latest.id)) {
        latest = completion;
      }
    }
    if (latest == null || !hasClient()) return;
    try {
      await client.del('items/task_completions/' + latest.id);
      app.completions = app.completions.filter((c) => c.id !== latest.id);
      Haptics.tap();
      render();
    } catch (error) {
      handleFailure(error);
    }
  }

  async function claimCompetition() {
    if (!app.competitionTask || !hasClient() || app.claim != null) return;
    const body = {
      player: app.myName,
      task: app.competitionTask.id,
      dedupe_key: 'task:' + app.competitionTask.id,
    };
    try {
      const created = await client.create('items/competition_claims', body);
      app.claim = created;
      Haptics.success();
      render();
    } catch (error) {
      handleFailure(error);
    }
  }

  async function saveAnswer(text) {
    const trimmed = text.trim();
    if (!AnswerRules.isValid(trimmed) || !app.question || !hasClient()) return;
    try {
      const existing = myAnswer();
      if (existing) {
        const updated = await client.update('items/answers/' + existing.id, { body: trimmed });
        app.answers = app.answers.map((a) => (a.id === updated.id ? updated : a));
      } else {
        const created = await client.create('items/answers', {
          player: app.myName,
          questions: app.question.id,
          body: trimmed,
          dedupe_key: app.question.id + ':' + app.myName,
        });
        app.answers.push(created);
      }
      Haptics.success();
      render();
    } catch (error) {
      handleFailure(error);
    }
  }

  async function sendNudge() {
    if (!app.question || !hasClient() || app.partnerName === '') return;
    try {
      await client.create('items/nudges', {
        questions: app.question.id,
        from_player: app.myName,
        to_player: app.partnerName,
      });
      Haptics.tap();
    } catch (error) {
      handleFailure(error);
    }
  }

  async function acknowledgeNudges() {
    if (!hasClient() || app.unseenNudges.length === 0) return;
    for (const nudge of app.unseenNudges) {
      try {
        await client.update('items/nudges/' + nudge.id, { seen_on: ISO.now() });
      } catch (_) { /* best-effort, like Swift's try? */ }
    }
    app.unseenNudges = [];
    render();
  }

  // Unique-violation errors mean the database already has what we tried to
  // write — just resync rather than showing an error.
  function handleFailure(error) {
    if (error instanceof APIError && error.isUniqueViolation) {
      refresh(true);
    } else {
      app.errorMessage = error.message;
      Haptics.warning();
      render();
    }
  }

  // Polling — scenePhase maps to document visibility.

  let pollTimer = null;

  function startPolling() {
    if (pollTimer != null || !isConfigured()) return;
    pollTimer = setInterval(() => { refresh(true); }, 20000);
  }

  function stopPolling() {
    if (pollTimer != null) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
  }

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      startPolling();
      Notify.scheduleDaily();
      refresh(true);
    } else {
      stopPolling();
    }
  });

  // MARK: Icons
  // SF Symbols don't exist on the web. Curated SF Symbol names render as the
  // closest emoji; UI chrome (tabs, gear, cards' labels) uses stroke SVGs so
  // it can be tinted like SwiftUI tints it. Unknown custom symbol names fall
  // back to a dotted circle, same as an empty icon.

  const SYMBOLS = {
    'circle.dotted': '⊙',
    'figure.run': '🏃', 'dumbbell': '🏋️', 'book': '📖', 'brain.head.profile': '🧠',
    'drop': '💧', 'fork.knife': '🍽️', 'house': '🏠', 'trash': '🗑️', 'paintpalette': '🎨',
    'gamecontroller': '🎮', 'heart': '❤️', 'moon.zzz': '😴',
    'crown.fill': '👑', 'sparkles': '✨', 'trophy.fill': '🏆', 'bolt.slash.fill': '⚡',
    'hand.tap.fill': '👆', 'person.crop.circle': '👤', 'pencil.and.outline': '✏️',
    'bell': '🔔', 'bell.badge.fill': '🔔',
  };

  function symbol(name, fallback = '⊙') {
    const key = String(name == null ? '' : name).trim();
    if (key === '') return fallback;
    return SYMBOLS[key] || fallback;
  }

  const SVGS = {
    // checklist
    checklist: '<path d="M3.5 6.6l2 2 3.6-4.2"/><path d="M11.8 7h9"/><path d="M3.5 15.6l2 2 3.6-4.2"/><path d="M11.8 16h9"/>',
    // flag.checkered
    flag: '<path d="M5.5 21V4"/><path d="M5.5 5c2.6-1.6 5.2-1.6 7.5 0s4.9 1.6 7.5 0v9.5c-2.6 1.6-5.2 1.6-7.5 0s-4.9-1.6-7.5 0z"/>',
    // text.bubble
    bubble: '<path d="M12 3.5c-5 0-8.8 2.9-8.8 6.6 0 2.1 1.2 4 3.2 5.2l-.8 4 4.2-2.2c.7.1 1.4.2 2.2.2 4.9 0 8.8-2.9 8.8-6.6S16.9 3.5 12 3.5z"/>',
    // gearshape
    gear: '<circle cx="12" cy="12" r="3.2"/><path d="M18.9 14.7a1.5 1.5 0 0 0 .3 1.7l.1.1a1.8 1.8 0 1 1-2.6 2.6l-.1-.1a1.5 1.5 0 0 0-1.7-.3 1.5 1.5 0 0 0-.9 1.4v.3a1.8 1.8 0 1 1-3.6 0v-.2a1.5 1.5 0 0 0-1-1.4 1.5 1.5 0 0 0-1.6.4l-.1.1a1.8 1.8 0 1 1-2.6-2.6l.1-.1a1.5 1.5 0 0 0 .3-1.7 1.5 1.5 0 0 0-1.4-.9H3.6a1.8 1.8 0 1 1 0-3.6h.2a1.5 1.5 0 0 0 1.4-1 1.5 1.5 0 0 0-.4-1.6l-.1-.1a1.8 1.8 0 1 1 2.6-2.6l.1.1a1.5 1.5 0 0 0 1.7.3h.1a1.5 1.5 0 0 0 .9-1.4V3.6a1.8 1.8 0 1 1 3.6 0v.2a1.5 1.5 0 0 0 .9 1.4 1.5 1.5 0 0 0 1.7-.3l.1-.1a1.8 1.8 0 1 1 2.6 2.6l-.1.1a1.5 1.5 0 0 0-.3 1.7v.1a1.5 1.5 0 0 0 1.4.9h.3a1.8 1.8 0 1 1 0 3.6h-.2a1.5 1.5 0 0 0-1.4.9z"/>',
  };

  function svgIcon(name) {
    return '<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"'
      + ' stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
      + SVGS[name] + '</svg>';
  }

  // MARK: Views — one function per SwiftUI view.

  function setupHTML(editing) {
    const d = app.settingsDraft || { myName: '', partnerName: '' };
    const me = d.myName.trim();
    const them = d.partnerName.trim();
    const canConnect = me !== '' && them !== '' && me !== them;
    const connectLabel = app.isLoading ? 'Connecting…' : (editing ? 'Save & reconnect' : 'Start playing');
    return `
      <div class="sheet-page">
        <div class="nav-bar inline">
          <div class="nav-title-inline">${editing ? 'Settings' : 'Welcome to Hunny 🍯'}</div>
        </div>
        <div class="scroll form">
          <div class="section">
            <div class="section-title">Players</div>
            <div class="list-card">
              <div class="list-row">
                <input data-bind="setup-my-name" data-focus="setup-my-name" type="text"
                  placeholder="Your name" autocomplete="off" autocorrect="off" spellcheck="false"
                  value="${esc(d.myName)}">
              </div>
              <div class="list-divider"></div>
              <div class="list-row">
                <input data-bind="setup-partner-name" data-focus="setup-partner-name" type="text"
                  placeholder="Their name" autocomplete="off" autocorrect="off" spellcheck="false"
                  value="${esc(d.partnerName)}">
              </div>
            </div>
            <div class="section-foot">Enter the same two names on both devices — spelling and capital letters count. That's how Hunny pairs you.</div>
          </div>
          <div class="section">
            <div class="list-card">
              <div class="list-row button-row connect-row" data-action="setup-connect" ${(!canConnect || app.isLoading) ? 'data-disabled="true"' : ''}>
                ${app.isLoading ? '<span class="spinner small"></span>' : ''}<span>${esc(connectLabel)}</span>
              </div>
            </div>
            ${app.errorMessage ? `<div class="error-text" style="padding-top:8px">${esc(app.errorMessage)}</div>` : ''}
          </div>
          ${editing ? `
          <div class="section">
            <div class="section-title">Diagnostics</div>
            <div class="list-card">
              <div class="list-row button-row left" data-action="copy-diagnostics">${app.copiedDiagnostics ? 'Copied ✓' : 'Copy diagnostics log'}</div>
            </div>
            <div class="section-foot">Copies the last API requests and any errors to the clipboard — paste it into a bug report.</div>
          </div>
          <div class="section">
            <div class="list-card">
              <div class="list-row button-row left destructive" data-action="reset-config">Reset configuration</div>
            </div>
          </div>` : ''}
        </div>
      </div>`;
  }

  function tabBarHTML() {
    const tabs = [
      { icon: svgIcon('checklist'), label: 'Tasks' },
      { icon: svgIcon('flag'), label: 'Compete' },
      { icon: svgIcon('bubble'), label: 'Question' },
    ];
    return '<div class="tab-bar">' + tabs.map((t, i) => `
      <button class="tab-item ${app.selectedTab === i ? 'selected' : ''}" data-action="select-tab" data-tab="${i}">
        ${t.icon}<span class="tab-label">${t.label}</span>
      </button>`).join('') + '</div>';
  }

  function tasksTabHTML() {
    const weekly = app.tasks.filter((t) => t.max_per_week <= 1);
    const daily = app.tasks.filter((t) => t.max_per_week > 1);
    return `
      <div class="tab-page">
        <div class="nav-bar large">
          <div class="nav-title-large">Tasks</div>
          <button class="nav-btn" data-action="open-settings" aria-label="Settings">${svgIcon('gear')}</button>
        </div>
        <div class="scroll tab-scroll" data-pull="tabs">
          <div class="stack">
            ${scoreHeaderHTML()}
            ${app.tasks.length === 0
              ? emptyStateHTML('checklist', 'No tasks yet')
              : (weekly.length ? sectionHTML('Once this week', weekly) : '')
                + (daily.length ? sectionHTML('Once a day this week', daily) : '')}
          </div>
        </div>
      </div>`;
  }

  function sectionHTML(title, tasks) {
    const done = tasks.reduce((sum, t) =>
      sum + Math.min(completionsThisWeek(t).length, Math.max(t.max_per_week, 1)), 0);
    const total = tasks.reduce((sum, t) => sum + Math.max(t.max_per_week, 1), 0);
    return `
      <div class="task-section">
        <div class="section-header">
          <span class="title">${esc(title)}</span>
          <span class="count">${done} / ${total}</span>
        </div>
        ${tasks.map(taskCardHTML).join('')}
      </div>`;
  }

  function taskCardHTML(task) {
    const mine = completionsThisWeek(task);
    const cap = Math.max(task.max_per_week, 1);
    const fullyDone = mine.length >= cap;
    const doneToday = mine.some((c) => c.completed_on === Week.todayKey());
    let subtitle;
    if (task.max_per_week <= 1) {
      subtitle = mine.length === 0 ? 'Worth 1 point this week' : 'Completed · +1 point';
    } else if (doneToday) {
      subtitle = 'Done today · ' + mine.length + ' of ' + task.max_per_week + ' this week';
    } else {
      subtitle = 'Once a day · up to ' + task.max_per_week + ' points';
    }
    const control = canComplete(task)
      ? '<button class="tap-circle" data-action="complete-task" data-id="' + task.id + '" aria-label="Complete task"></button>'
      // Done — tap to undo an accidental completion.
      : '<button class="done-circle" data-action="uncomplete-task" data-id="' + task.id + '" aria-label="Undo completion">✓</button>';
    return `
      <div class="card task-card">
        <div class="icon-circle">${symbol(task.icon)}</div>
        <div class="task-info">
          <div class="task-title ${fullyDone ? 'done' : ''}">${esc(task.title)}</div>
          <div class="task-subtitle">${esc(subtitle)}</div>
          ${task.max_per_week > 1 ? progressDotsHTML(task.max_per_week, mine.length) : ''}
        </div>
        ${control}
      </div>`;
  }

  function progressDotsHTML(count, filled) {
    let dots = '';
    for (let i = 0; i < Math.max(count, 1); i++) {
      dots += '<span class="' + (i < filled ? 'filled' : '') + '"></span>';
    }
    return '<div class="progress-dots">' + dots + '</div>';
  }

  // TasksView/CompeteView/QuestionView all embed ScoreHeader.
  function scoreHeaderHTML() {
    const mine = app.myName === '' ? 'You' : app.myName;
    const theirs = app.partnerName === '' ? 'Them' : app.partnerName;
    const my = myPoints();
    const their = partnerPoints();
    return `
      <div class="card score-header">
        ${playerColumnHTML({ name: mine, points: my, leader: my > their, right: false, joined: true, tappable: true })}
        <div class="week-mid">
          <div class="week-label">THIS WEEK</div>
          <div class="week-range">${esc(Week.rangeLabel())}</div>
          <div class="week-sparkles">${symbol('sparkles')}</div>
        </div>
        ${playerColumnHTML({ name: theirs, points: their, leader: their > my, right: true, joined: partnerHasJoined(), tappable: false })}
      </div>`;
  }

  function playerColumnHTML({ name, points, leader, right, joined, tappable }) {
    const initials = name === '' ? '?' : name.slice(0, 2).toUpperCase();
    return `
      <div class="player-col ${right ? 'right' : 'left'}">
        <div class="avatar-wrap">
          <div class="avatar ${tappable ? 'tappable' : ''}" ${tappable ? 'data-action="avatar-tap"' : ''}>${esc(initials)}</div>
          ${leader ? `<div class="crown">${symbol('crown.fill')}</div>` : ''}
        </div>
        <div class="player-name">${esc(name)}</div>
        <div class="player-points ${leader ? 'leader' : ''}">${points}</div>
        ${joined ? '' : '<div class="player-waiting">waiting to join…</div>'}
      </div>`;
  }

  function competeTabHTML() {
    const competition = app.competitionTask;
    return `
      <div class="tab-page">
        <div class="nav-bar large"><div class="nav-title-large">Compete</div></div>
        <div class="scroll tab-scroll" data-pull="tabs">
          <div class="stack">
            ${scoreHeaderHTML()}
            ${competition ? competitionCardHTML(competition)
              : emptyStateHTML('flag', 'No head-to-head this week',
                "When this week's competition task is added in Directus, the race opens here.")}
          </div>
        </div>
      </div>`;
  }

  function competitionCardHTML(competition) {
    const claimArea = app.claim ? claimResultHTML(app.claim) : `
      <div class="claim-button-wrap">
        <button class="btn-filled" data-action="claim-competition">
          ${symbol('hand.tap.fill')} I've done it — claim the point
        </button>
        <div class="claim-caption">First device to claim wins the point for the week. No take-backs.</div>
      </div>`;
    return `
      <div class="card">
        <div class="card-label accent"><span class="emoji">🏁</span>Head-to-head</div>
        <div class="card-title">${esc(competition.title)}</div>
        ${competition.detail ? `<div class="card-detail">${esc(competition.detail)}</div>` : ''}
        <div class="card-divider"></div>
        ${claimArea}
      </div>`;
  }

  function claimResultHTML(claim) {
    const mine = claim.player === app.myName;
    const opponent = app.partnerName === '' ? 'The other player' : app.partnerName;
    return `
      <div class="claim-result">
        <span class="glyph">${symbol(mine ? 'trophy.fill' : 'bolt.slash.fill')}</span>
        <div>
          <div class="who">${mine ? 'You claimed it first' : esc(opponent) + ' claimed it first'}</div>
          ${claim.claimed_at ? `<div class="when">${esc(relativeTime(claim.claimed_at))}</div>` : ''}
        </div>
      </div>`;
  }

  function questionTabHTML() {
    // .onAppear { draft = myAnswer?.body ?? "" } — runs once per session.
    if (!app.draftSynced) {
      app.draftSynced = true;
      app.draft = (myAnswer() && myAnswer().body) || '';
    }
    const question = app.question;
    return `
      <div class="tab-page">
        <div class="nav-bar large"><div class="nav-title-large">Question</div></div>
        <div class="scroll tab-scroll" data-pull="tabs">
          <div class="stack">
            ${question ? questionCardHTML(question) + myAnswerCardHTML() + theirAnswerCardHTML()
              : emptyStateHTML('bubble', 'No question yet',
                "This week's question appears here once it's added in Directus.")}
          </div>
        </div>
      </div>`;
  }

  function questionCardHTML(question) {
    return `
      <div class="card">
        <div class="card-label accent"><span class="emoji">💬</span>Question of the week</div>
        <div class="card-title">${esc(question.text)}</div>
      </div>`;
  }

  function myAnswerCardHTML() {
    const answer = myAnswer();
    const trimmed = app.draft.trim();
    const unchanged = answer != null && answer.body === trimmed;
    const valid = AnswerRules.isValid(app.draft);
    const hint = AnswerRules.hint(app.draft);
    const caption = hint !== '' ? hint
      : (answer && answer.updated_on ? 'Saved ' + relativeTime(answer.updated_on) : '');
    return `
      <div class="card">
        <div class="card-label"><span class="emoji">${symbol('pencil.and.outline')}</span>Your answer</div>
        <textarea class="answer-editor" data-bind="answer-draft" data-focus="answer-draft"
          placeholder="">${esc(app.draft)}</textarea>
        <div class="answer-footer">
          <span class="saved-caption answer-caption">${esc(caption)}</span>
          <button class="btn-mini" data-action="submit-answer" ${!valid || unchanged ? 'disabled' : ''}>
            ${answer == null ? 'Submit' : 'Update'}
          </button>
        </div>
      </div>`;
  }

  function theirAnswerCardHTML() {
    const partner = app.partnerName === '' ? 'Player two' : app.partnerName;
    const theirs = theirAnswer();
    const body = theirs
      ? `<div class="answer-body">${esc(theirs.body)}</div>
         ${theirs.updated_on ? `<div class="updated-caption">Updated ${esc(relativeTime(theirs.updated_on))}</div>` : ''}`
      : `<div class="no-answer">
           <div class="hint">${esc(partner)} hasn't answered yet</div>
           <button class="btn-bordered" data-action="send-nudge">🔔 Send a nudge</button>
         </div>`;
    return `
      <div class="card">
        <div class="card-label"><span class="emoji">${symbol('person.crop.circle')}</span>${esc(partner)}'s answer</div>
        ${body}
      </div>`;
  }

  function emptyStateHTML(icon, title, message) {
    return `
      <div class="card empty-state">
        <div class="empty-icon">${svgIcon(icon)}</div>
        <div class="empty-title">${esc(title)}</div>
        ${message ? `<div class="empty-message">${esc(message)}</div>` : ''}
      </div>`;
  }

  // Floating banner shown when the other player has nudged you about this
  // week's question. Re-renders (20s polling) don't replay the animation.
  let lastNudgeSignature = '';

  function nudgeBannerHTML() {
    if (app.unseenNudges.length === 0) {
      lastNudgeSignature = '';
      return '';
    }
    const signature = app.unseenNudges.map((n) => n.id).join(',');
    const still = signature === lastNudgeSignature;
    lastNudgeSignature = signature;
    const from = app.unseenNudges[0].from_player || 'Your partner';
    return `
      <div class="nudge-banner ${still ? 'still' : ''}" data-action="banner-tap">
        <span class="nudge-bell">${symbol('bell.badge.fill')}</span>
        <span class="nudge-text">${esc(from)} nudged you to answer this week's question</span>
        <button class="btn-mini" data-action="banner-got-it">Got it</button>
      </div>`;
  }

  // Hidden task editor — TaskAdminView.swift.

  function adminHTML() {
    const active = app.allTasks.filter((t) => t.active == null ? true : t.active);
    const retired = app.allTasks.filter((t) => !(t.active == null ? true : t.active));
    return `
      <div class="sheet-page">
        <div class="nav-bar inline">
          <button class="nav-btn text" data-action="admin-done">Done</button>
          <div class="nav-title-inline">Manage Tasks</div>
          <div class="admin-menu">
            <button class="nav-btn" data-action="admin-add-menu" aria-label="Add"
              style="font-size:22px;font-weight:400;">+</button>
            <div class="menu-popover ${app.admin.menuOpen ? 'open' : ''}">
              <button data-action="admin-add-own"><span class="emoji">${symbol('checklist', '☑️')}</span>Personal task</button>
              <div class="menu-divider"></div>
              <button data-action="admin-add-competition"><span class="emoji">🏁</span>Head-to-head task</button>
            </div>
          </div>
        </div>
        <div class="scroll tab-scroll" data-pull="admin">
          <div class="stack" style="padding:4px 16px 32px">
            ${app.admin.loadError ? `
            <div class="section" style="margin-bottom:14px">
              <div class="list-card">
                <div class="error-text" style="padding:12px 16px">${esc(app.admin.loadError)}</div>
                <div class="list-divider"></div>
                <div class="list-row button-row" data-action="admin-retry">Try Again</div>
              </div>
            </div>` : ''}
            <div class="section">
              <div class="section-title">This Week's Head-to-Head</div>
              <div class="list-card">
                ${app.competitionTask ? competitionRowHTML(app.competitionTask)
                  : '<div class="list-row muted">None this week — add one with +.</div>'}
              </div>
            </div>
            <div class="section">
              <div class="section-title">Active</div>
              <div class="list-card">
                ${active.length === 0 && !app.admin.loadError
                  ? '<div class="list-row muted">No tasks yet — tap + to add one.</div>' : ''}
                ${active.map(adminRowHTML).join('')}
              </div>
            </div>
            ${retired.length ? `
            <div class="section">
              <div class="section-title">Retired</div>
              <div class="list-card">${retired.map(adminRowHTML).join('')}</div>
            </div>` : ''}
          </div>
        </div>
        ${app.admin.isLoading ? '<div class="loading-overlay"><span class="spinner"></span></div>' : ''}
      </div>`;
  }

  function competitionRowHTML(competition) {
    const subtitle = app.claim
      ? 'Claimed by ' + app.claim.player + ' · repeats weekly'
      : 'Unclaimed · repeats weekly';
    return `
      <div class="list-row admin-row" data-action="admin-edit-competition">
        <div class="icon-circle small">🏁</div>
        <div class="admin-info">
          <div class="task-title">${esc(competition.title)}</div>
          <div class="task-subtitle">${esc(subtitle)}</div>
        </div>
      </div>`;
  }

  function adminRowHTML(task) {
    const retired = !(task.active == null ? true : task.active);
    const label = task.max_per_week <= 1
      ? 'Once a week'
      : 'Up to ' + task.max_per_week + '× a week · once a day';
    return `
      <div class="list-row admin-row" data-action="admin-edit-task" data-id="${task.id}">
        <div class="icon-circle small">${symbol(task.icon)}</div>
        <div class="admin-info">
          <div class="task-title ${retired ? 'done' : ''}">${esc(task.title)}</div>
          <div class="task-subtitle">${esc(label)}</div>
        </div>
        <label class="switch">
          <input type="checkbox" data-change="admin-toggle" data-id="${task.id}" ${(task.active == null ? true : task.active) ? 'checked' : ''}>
          <span class="switch-track"></span>
        </label>
      </div>`;
  }

  // TaskFormView — create or edit a personal task.

  function taskFormHTML() {
    const f = app.form;
    const suggested = ['figure.run', 'dumbbell', 'book', 'brain.head.profile', 'drop',
      'fork.knife', 'house', 'trash', 'paintpalette', 'gamecontroller', 'heart', 'moon.zzz'];
    let options = '<option value="1"' + (f.maxPerWeek === 1 ? ' selected' : '') + '>Once a week</option>';
    for (let times = 2; times <= 7; times++) {
      options += '<option value="' + times + '"' + (f.maxPerWeek === times ? ' selected' : '')
        + '>' + times + ' times a week · once a day max</option>';
    }
    return `
      <div class="sheet-page">
        <div class="nav-bar inline">
          <button class="nav-btn text" data-action="form-cancel">Cancel</button>
          <div class="nav-title-inline">${f.task ? 'Edit Task' : 'New Task'}</div>
          <button class="nav-btn text semibold" data-action="form-save"
            ${f.isSaving || f.title.trim() === '' ? 'disabled' : ''}>Save</button>
        </div>
        <div class="scroll tab-scroll">
          <div class="stack" style="padding:4px 16px 32px">
            <div class="section">
              <div class="section-title">Task</div>
              <div class="list-card">
                <div class="list-row">
                  <input data-bind="form-title" data-focus="form-title" type="text" placeholder="Title"
                    autocomplete="off" value="${esc(f.title)}">
                </div>
                <div class="list-divider"></div>
                <div class="list-row">
                  <textarea data-bind="form-detail" data-focus="form-detail" rows="3"
                    placeholder="Detail (optional)">${esc(f.detail)}</textarea>
                </div>
              </div>
            </div>
            <div class="section">
              <div class="list-card">
                <div class="list-row select-row">
                  <select data-change="form-max-week">${options}</select>
                </div>
              </div>
              <div class="section-foot">Daily tasks can be completed once per day, up to their weekly limit. Each completion is worth 1 point.</div>
            </div>
            <div class="section">
              <div class="list-card icon-editor">
                <div class="list-row">
                  <div class="icon-circle">${symbol(f.icon)}</div>
                  <input data-bind="form-icon" data-focus="form-icon" type="text"
                    placeholder="SF Symbol name (optional)" autocomplete="off" autocorrect="off"
                    autocapitalize="none" spellcheck="false" value="${esc(f.icon)}">
                </div>
                <div class="icon-suggestions">
                  ${suggested.map((name) => `
                    <button class="icon-chip ${f.icon === name ? 'selected' : ''}"
                      data-action="pick-icon" data-icon="${name}" aria-label="${name}">${symbol(name)}</button>`).join('')}
                </div>
              </div>
              <div class="section-foot">Pick a suggestion or type any SF Symbol name.</div>
            </div>
            ${f.task ? `
            <div class="section">
              <div class="list-card">
                <div class="list-row toggle-row">
                  <span>Active</span>
                  <label class="switch">
                    <input type="checkbox" data-change="form-active" ${f.isActive ? 'checked' : ''}>
                    <span class="switch-track"></span>
                  </label>
                </div>
              </div>
              <div class="section-foot">Retired tasks keep their history but disappear from the weekly list.</div>
            </div>` : ''}
            ${f.saveError ? `<div class="error-text">${esc(f.saveError)}</div>` : ''}
          </div>
        </div>
      </div>`;
  }

  // CompetitionFormView — create or edit the weekly head-to-head.

  function competitionFormHTML() {
    const f = app.form;
    return `
      <div class="sheet-page">
        <div class="nav-bar inline">
          <button class="nav-btn text" data-action="form-cancel">Cancel</button>
          <div class="nav-title-inline">${f.competition ? 'Edit Head-to-Head' : 'New Head-to-Head'}</div>
          <button class="nav-btn text semibold" data-action="form-save"
            ${f.isSaving || f.title.trim() === '' ? 'disabled' : ''}>Save</button>
        </div>
        <div class="scroll tab-scroll">
          <div class="stack" style="padding:4px 16px 32px">
            <div class="section">
              <div class="list-card">
                <div class="list-row">
                  <input data-bind="form-title" data-focus="form-title" type="text" placeholder="Title"
                    autocomplete="off" value="${esc(f.title)}">
                </div>
                <div class="list-divider"></div>
                <div class="list-row">
                  <textarea data-bind="form-detail" data-focus="form-detail" rows="3"
                    placeholder="Detail (optional)">${esc(f.detail)}</textarea>
                </div>
              </div>
              <div class="section-foot">First to finish it claims the win and a bonus point. It repeats every week until you change it here.</div>
            </div>
            ${f.saveError ? `<div class="error-text">${esc(f.saveError)}</div>` : ''}
          </div>
        </div>
      </div>`;
  }

  // MARK: Render plumbing.

  function tabContentHTML() {
    if (app.selectedTab === 1) return competeTabHTML();
    if (app.selectedTab === 2) return questionTabHTML();
    return tasksTabHTML();
  }

  let lastIsReady = false;

  function render() {
    preserveContext(() => {
      renderApp();
      renderSheets();
      renderOverlays();
    });
    // SetupView(editing) dismisses itself when isReady flips to true — the
    // SwiftUI .onChange(of: app.isReady) behaviour.
    if (app.isReady && !lastIsReady && app.sheetStack[app.sheetStack.length - 1] === 'settings') {
      popSheet();
      renderSheets();
    }
    lastIsReady = app.isReady;
  }

  function renderApp() {
    const root = document.getElementById('app');
    if (isConfigured()) {
      root.innerHTML = `
        <div class="screen">
          ${nudgeBannerHTML()}
          ${tabContentHTML()}
          ${tabBarHTML()}
        </div>`;
    } else {
      if (!app.settingsDraft) {
        app.settingsDraft = { myName: app.myName, partnerName: app.partnerName };
      }
      root.innerHTML = '<div class="screen">' + setupHTML(false) + '</div>';
    }
  }

  function sheetContentHTML(kind) {
    if (kind === 'settings') return setupHTML(true);
    if (kind === 'admin') return adminHTML();
    if (kind === 'task-form') return taskFormHTML();
    if (kind === 'competition-form') return competitionFormHTML();
    return '';
  }

  // Rebuilding identical sheets (20s polling) must not replay the slide-up
  // animation — only newly pushed sheets animate.
  let lastSheetSignature = '';

  function renderSheets() {
    const root = document.getElementById('sheets');
    if (app.sheetStack.length === 0) {
      root.innerHTML = '';
      lastSheetSignature = '';
      return;
    }
    const signature = app.sheetStack.join('|');
    const still = signature === lastSheetSignature;
    lastSheetSignature = signature;
    const top = app.sheetStack.length - 1;
    root.innerHTML = app.sheetStack.map((kind, i) => `
      <div class="sheet-backdrop ${i === top ? 'top' : ''}" data-sheet-index="${i}"></div>
      <div class="sheet ${i === top ? 'top' : ''} ${still ? 'still' : ''}">${sheetContentHTML(kind)}</div>`).join('');
  }

  // The tabs alert: only shown while TabsView is mounted (isConfigured).
  // SetupView shows errorMessage inline instead.
  function renderOverlays() {
    const root = document.getElementById('overlays');
    if (app.errorMessage != null && isConfigured()) {
      root.innerHTML = `
        <div class="alert-backdrop">
          <div class="alert-card">
            <div class="alert-title">Something went wrong</div>
            <div class="alert-message">${esc(app.errorMessage)}</div>
            <div class="alert-divider"></div>
            <button class="alert-button" data-action="alert-ok">OK</button>
          </div>
        </div>`;
    } else {
      root.innerHTML = '';
    }
  }

  // Re-rendering replaces the DOM, so carry focus, selection and scroll
  // positions across — the things SwiftUI gives you for free.
  function preserveContext(fn) {
    const active = document.activeElement;
    const focusKey = active && active.dataset ? active.dataset.focus : null;
    const selectionStart = active && active.selectionStart != null ? active.selectionStart : null;
    const selectionEnd = active && active.selectionEnd != null ? active.selectionEnd : null;
    const scrollers = Array.from(document.querySelectorAll('.tab-scroll'));
    const scrollPositions = scrollers.map((s) => s.scrollTop);

    fn();

    const newScrollers = Array.from(document.querySelectorAll('.tab-scroll'));
    if (newScrollers.length === scrollers.length) {
      newScrollers.forEach((s, i) => { s.scrollTop = scrollPositions[i]; });
    }
    if (focusKey) {
      const restored = document.querySelector('[data-focus="' + focusKey + '"]');
      if (restored) {
        restored.focus();
        if (selectionStart != null) {
          try { restored.setSelectionRange(selectionStart, selectionEnd); } catch (_) { /* not a text field */ }
        }
      }
    }
  }

  function pushSheet(kind) {
    app.sheetStack.push(kind);
    renderSheets();
  }

  function popSheet() {
    app.sheetStack.pop();
    if (app.sheetStack.length === 0) {
      app.form = null;
      app.admin.menuOpen = false;
    }
    renderSheets();
  }

  // MARK: Sheet contents' actions.

  function openSettings() {
    app.settingsDraft = { myName: app.myName, partnerName: app.partnerName };
    app.copiedDiagnostics = false;
    pushSheet('settings');
  }

  function newTaskForm(task) {
    app.form = {
      kind: 'task',
      task: task || null,
      title: task ? task.title : '',
      detail: task ? (task.detail == null ? '' : task.detail) : '',
      icon: task ? (task.icon == null ? '' : task.icon) : '',
      maxPerWeek: Math.max(task ? task.max_per_week : 1, 1),
      isActive: task ? (task.active == null ? true : task.active) : true,
      isSaving: false,
      saveError: null,
    };
    pushSheet('task-form');
  }

  function newCompetitionForm(competition) {
    app.form = {
      kind: 'competition',
      competition: competition || null,
      title: competition ? competition.title : '',
      detail: competition ? (competition.detail == null ? '' : competition.detail) : '',
      isSaving: false,
      saveError: null,
    };
    pushSheet('competition-form');
  }

  async function loadAdmin() {
    app.admin.isLoading = true;
    renderSheets();
    try {
      await loadAllTasks();
      app.admin.loadError = null;
    } catch (error) {
      app.admin.loadError = error.message;
    } finally {
      app.admin.isLoading = false;
      renderSheets();
    }
  }

  // Five taps within 1.5s of each other opens the hidden task editor;
  // anything slower resets the count so it can't trigger by accident.
  function handleProfileTap() {
    const now = Date.now();
    if (now - app.lastProfileTap > 1500) app.profileTapCount = 0;
    app.lastProfileTap = now;
    app.profileTapCount += 1;
    if (app.profileTapCount < 5) return;
    app.profileTapCount = 0;
    Haptics.tap();
    app.admin.menuOpen = false;
    pushSheet('admin');
    loadAdmin();
  }

  async function saveForm() {
    const f = app.form;
    if (!f || f.title.trim() === '') return;
    f.isSaving = true;
    f.saveError = null;
    renderSheets();
    try {
      if (f.kind === 'task') {
        if (f.task) {
          await updateTask(f.task, {
            title: f.title.trim(),
            detail: f.detail === '' ? null : f.detail,
            icon: f.icon === '' ? null : f.icon,
            max_per_week: f.maxPerWeek,
            active: f.isActive,
          });
        } else {
          await createTask({
            title: f.title.trim(),
            detail: f.detail.trim(),
            icon: f.icon.trim(),
            maxPerWeek: f.maxPerWeek,
          });
        }
      } else {
        await saveCompetition(f.title.trim(), f.detail.trim());
      }
      Haptics.success();
      popSheet();
      render();
    } catch (error) {
      f.isSaving = false;
      f.saveError = error.message;
      renderSheets();
    }
  }

  // MARK: Event wiring — one delegated listener per event type.

  document.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target : null;
    if (!target) return;

    // Close an open admin + menu on any click that isn't the menu itself.
    if (app.admin.menuOpen
        && !target.closest('.menu-popover')
        && !target.closest('[data-action="admin-add-menu"]')) {
      app.admin.menuOpen = false;
      renderSheets();
    }

    const trigger = target.closest('[data-action]');
    if (!trigger || trigger.dataset.disabled === 'true') return;
    const action = trigger.dataset.action;

    switch (action) {
      case 'select-tab': {
        app.selectedTab = parseInt(trigger.dataset.tab, 10) || 0;
        render();
        return;
      }
      case 'open-settings': {
        openSettings();
        return;
      }
      case 'setup-connect': {
        const d = app.settingsDraft || { myName: '', partnerName: '' };
        saveNames(d.myName.trim(), d.partnerName.trim());
        Notify.requestIfNeeded(); // inside the tap: iOS Safari needs the gesture
        connect();
        return;
      }
      case 'copy-diagnostics': {
        const text = DiagnosticLog.formatted();
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(() => {
            app.copiedDiagnostics = true;
            renderSheets();
            setTimeout(() => { app.copiedDiagnostics = false; renderSheets(); }, 2000);
          });
        }
        return;
      }
      case 'reset-config': {
        signOut();
        render();
        return;
      }
      case 'complete-task': {
        const task = app.tasks.find((t) => t.id === parseInt(trigger.dataset.id, 10));
        if (task) completeTask(task);
        return;
      }
      case 'uncomplete-task': {
        const task = app.tasks.find((t) => t.id === parseInt(trigger.dataset.id, 10));
        if (task) uncompleteTask(task);
        return;
      }
      case 'claim-competition': {
        claimCompetition();
        return;
      }
      case 'submit-answer': {
        saveAnswer(app.draft);
        return;
      }
      case 'send-nudge': {
        sendNudge();
        return;
      }
      case 'banner-tap': {
        app.selectedTab = 2;
        acknowledgeNudges();
        return;
      }
      case 'banner-got-it': {
        event.stopPropagation();
        acknowledgeNudges();
        return;
      }
      case 'avatar-tap': {
        handleProfileTap();
        return;
      }
      case 'alert-ok': {
        app.errorMessage = null;
        render();
        return;
      }
      case 'admin-done': {
        popSheet();
        return;
      }
      case 'admin-add-menu': {
        app.admin.menuOpen = !app.admin.menuOpen;
        renderSheets();
        return;
      }
      case 'admin-add-own': {
        app.admin.menuOpen = false;
        newTaskForm(null);
        return;
      }
      case 'admin-add-competition': {
        app.admin.menuOpen = false;
        newCompetitionForm(app.competitionTask);
        return;
      }
      case 'admin-edit-competition': {
        if (app.competitionTask) newCompetitionForm(app.competitionTask);
        return;
      }
      case 'admin-edit-task': {
        if (target.closest('.switch')) return; // the toggle owns these clicks
        const task = app.allTasks.find((t) => t.id === parseInt(trigger.dataset.id, 10));
        if (task) newTaskForm(task);
        return;
      }
      case 'admin-retry': {
        loadAdmin();
        return;
      }
      case 'pick-icon': {
        if (app.form) {
          app.form.icon = trigger.dataset.icon;
          renderSheets();
        }
        return;
      }
      case 'form-cancel': {
        if (!app.form || !app.form.isSaving) popSheet();
        return;
      }
      case 'form-save': {
        saveForm();
        return;
      }
      default: return;
    }
  });

  // Backdrop click / Escape dismisses the top sheet, like swiping an iOS
  // sheet down.
  document.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target : null;
    if (!target) return;
    const backdrop = target.closest('.sheet-backdrop.top');
    if (!backdrop) return;
    if (app.form && app.form.isSaving) return;
    popSheet();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && app.sheetStack.length > 0) {
      if (app.form && app.form.isSaving) return;
      popSheet();
    }
  });

  // Text bindings update state without a re-render; only the dependent
  // button states are synced, so typing is never interrupted.
  document.addEventListener('input', (event) => {
    const bind = event.target.dataset ? event.target.dataset.bind : null;
    if (!bind) return;
    const value = event.target.value;
    switch (bind) {
      case 'setup-my-name':
        app.settingsDraft.myName = value;
        syncConnectRow();
        return;
      case 'setup-partner-name':
        app.settingsDraft.partnerName = value;
        syncConnectRow();
        return;
      case 'answer-draft':
        app.draft = value;
        syncAnswerButton();
        return;
      case 'form-title':
        app.form.title = value;
        syncSaveButton();
        return;
      case 'form-detail':
        app.form.detail = value;
        return;
      case 'form-icon':
        app.form.icon = value;
        syncIconPreview();
        return;
      default: return;
    }
  });

  document.addEventListener('change', (event) => {
    const change = event.target.dataset ? event.target.dataset.change : null;
    if (!change) return;
    switch (change) {
      case 'admin-toggle': {
        const task = app.allTasks.find((t) => t.id === parseInt(event.target.dataset.id, 10));
        if (!task) return;
        const active = event.target.checked;
        updateTask(task, { active }).catch((error) => {
          app.admin.loadError = error.message;
          renderSheets();
        });
        return;
      }
      case 'form-max-week': {
        if (app.form) app.form.maxPerWeek = parseInt(event.target.value, 10) || 1;
        return;
      }
      case 'form-active': {
        if (app.form) app.form.isActive = event.target.checked;
        return;
      }
      default: return;
    }
  });

  function syncConnectRow() {
    const row = document.querySelector('[data-action="setup-connect"]');
    if (!row) return;
    const d = app.settingsDraft;
    const me = d.myName.trim();
    const them = d.partnerName.trim();
    const canConnect = me !== '' && them !== '' && me !== them && !app.isLoading;
    if (canConnect) delete row.dataset.disabled;
    else row.dataset.disabled = 'true';
  }

  function syncAnswerButton() {
    const button = document.querySelector('[data-action="submit-answer"]');
    if (!button) return;
    const valid = AnswerRules.isValid(app.draft);
    const answer = myAnswer();
    const unchanged = answer != null && answer.body === app.draft.trim();
    button.disabled = !valid || unchanged;
    // Typing doesn't re-render, so keep the caption/hint in step by hand.
    const caption = document.querySelector('.answer-caption');
    if (caption) {
      const hint = AnswerRules.hint(app.draft);
      caption.textContent = hint !== '' ? hint
        : (answer && answer.updated_on ? 'Saved ' + relativeTime(answer.updated_on) : '');
    }
  }

  function syncSaveButton() {
    const button = document.querySelector('[data-action="form-save"]');
    if (!button || !app.form) return;
    button.disabled = app.form.isSaving || app.form.title.trim() === '';
  }

  function syncIconPreview() {
    const preview = document.querySelector('.icon-editor .icon-circle');
    if (preview) preview.textContent = symbol(app.form.icon);
    document.querySelectorAll('.icon-chip').forEach((chip) => {
      chip.classList.toggle('selected', chip.dataset.icon === app.form.icon);
    });
  }

  // Pull-to-refresh on the tab pages (and the admin list) — touch only,
  // like SwiftUI's .refreshable; desktop gets the 20-second polling.
  let pullScroller = null;
  let pullStartY = null;
  let pullDistance = 0;

  document.addEventListener('touchstart', (event) => {
    const scroller = event.target instanceof Element
      ? event.target.closest('[data-pull]') : null;
    if (!scroller || scroller.scrollTop > 0) {
      pullScroller = null;
      return;
    }
    pullScroller = scroller.dataset.pull;
    pullStartY = event.touches[0].clientY;
    pullDistance = 0;
  }, { passive: true });

  document.addEventListener('touchmove', (event) => {
    if (pullStartY == null) return;
    pullDistance = event.touches[0].clientY - pullStartY;
  }, { passive: true });

  document.addEventListener('touchend', () => {
    if (pullScroller != null && pullDistance > 80) {
      if (pullScroller === 'admin') loadAdmin();
      else refresh();
    }
    pullScroller = null;
    pullStartY = null;
  });

  // MARK: Boot (HunnyApp + TabsView .task)

  DiagnosticLog.record('launch · me=' + (app.myName === '' ? '—' : app.myName)
    + ' partner=' + (app.partnerName === '' ? '—' : app.partnerName)
    + ' server=' + (normalizedBaseURL() == null ? 'none' : normalizedBaseURL()));

  render();
  if (isConfigured()) connect();
})();
