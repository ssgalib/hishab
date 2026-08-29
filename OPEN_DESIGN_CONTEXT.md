# OPEN_DESIGN_CONTEXT.md

Product + functionality context for designing the UI/UX of this expense tracker.
Everything below describes the application **as it is actually implemented today**.
Features that do not exist are explicitly listed in "What Does NOT Exist" so the
designer does not invent them. Planned/unfinished items are clearly marked at the end.

---

# App Overview

A **fully offline, voice-first Android expense tracker** built with Flutter (Material 3).

The core interaction is speech: the user taps a microphone button and speaks an
expense in plain English (e.g., *"bought 3 eggs for 50 taka"*). Android's native
SpeechRecognizer converts the speech to text **on device**, and a fine-tuned
Gemma 3 270M language model running locally via ONNX Runtime parses that text
into structured JSON (`item`, `quantity`, `amount`, `category`). The parsed
expense is saved to a local SQLite database and appears instantly in the UI.

- **Target users**: individuals in Bangladesh (currency is Taka, shown as `৳`;
  example spoken inputs reference rickshaw/CNG/bus fares, eggs, rice, mobile
  recharges) who want zero-friction expense logging without typing.
- **Key constraint**: 100% offline. No accounts, no login, no server, no cloud
  sync. All data lives in a local SQLite database on the device.
- **Platform**: Android only (minSdk 26 / Android 8.0+). Phone form factor,
  portrait, single-handed use assumed.
- **Tone**: fast, personal, single-user tool. The magic moment is "speak an
  expense, watch it appear as a structured record."

---

# Core Features

1. **Voice expense entry (primary feature)**
   - A large mic FAB on the Home tab starts speech recognition.
   - Flow: request microphone permission → listen (tap mic again to stop) →
     recognized text is shown → on-device AI parses it into an expense → saved.
   - 20-second timeout on listening; tap-to-stop supported; the FAB is disabled
     (and colored orange) while the model is processing.
   - If the AI result is incomplete (no amount, or unrecognized item), the app
     opens the edit sheet pre-filled so the user can review/correct before saving.
   - If the AI output is totally unparseable, the raw spoken sentence becomes the
     item name with amount 0, routed to the same review sheet.
   - Specific, human-readable error messages for speech recognition failures
     (nothing heard, unclear speech, recognizer busy, speech service needs
     internet which is unavailable, mic permission missing).

2. **Manual expense entry**
   - A small "+" FAB above the mic opens the same edit sheet in create mode
     (Item, Quantity, Amount, Date, Category).

3. **Home dashboard (Home tab)**
   - Status line (text feedback for voice flow: listening / recognized / saved / errors).
   - Two summary chips: **Today's total** and **current month total** (in ৳).
   - The full expense list grouped by **Day / Month / Year** via a segmented
     toggle. Each group header shows the date title and the group subtotal.
   - Newest-first ordering everywhere.

4. **Expense editing**
   - Tapping any expense tile (Home or History) opens a modal bottom sheet to
     edit: item, quantity, amount, date, category.
   - Date picker is constrained to the past (today is the maximum, year 2000 the minimum).

5. **Delete with undo**
   - Swipe-to-delete on every tile (both tabs), red background with delete icon.
   - A snackbar confirms ("Deleted "item"") with an **Undo** action that restores
     the expense with its original date.
   - Deletion from the list is optimistic (tile leaves instantly).

6. **History (History tab)**
   - All expenses with a **range filter** segmented button: This month / Last month / All time.
   - **Search**: expands into the app bar as a text field; case-insensitive
     substring match on the item name only.
   - **Category pie chart** card at the top of the list: donut chart with
     percentage labels, the grand total in the center ("X ৳ / total"), and a
     color-dot legend ("category · amount ৳"), sorted by spend descending.
   - **CSV export**: writes `expenses-YYYYMMDD.csv` (date, item, quantity,
     amount, category) and opens the Android system share sheet. Shows
     "Nothing to export" snackbar when there is no data.
   - **Clear all data**: overflow menu item with a confirmation dialog
     ("This permanently removes every entry from this device." → Cancel / Delete all).

7. **Fixed category system**
   - Exactly 8 categories, each with a defined Material icon and brand color:
     | Category | Icon | Color |
     |---|---|---|
     | food | restaurant | orange `#EF6C00` |
     | transport | directions_car | blue `#1565C0` |
     | utilities | bolt | purple `#8E24AA` |
     | rent | home | teal `#00838F` |
     | medicine | medical_services | red `#C62828` |
     | education | school | green `#2E7D32` |
     | entertainment | movie | amber `#F9A825` |
     | mobile | phone_android | brown `#5D4037` |
   - A hidden "other" fallback (attach_money icon, blue-grey) renders if an
     unknown category string ever appears; it is never user-selectable.
   - Categories cannot be created, renamed, or deleted by the user.
   - The AI can also infer a category from keywords when the model returns an
     invalid one (e.g., "egg" → food, "rickshaw" → transport).

---

# User Flows

### Flow 1 — Voice entry (the hero flow)
1. User opens the app → lands on Home, sees totals + grouped list (or empty state).
2. Taps the mic FAB → OS microphone permission requested (first time only).
3. **Listening state**: FAB turns red/error-colored, status reads "Listening...
   (tap the mic to stop)". Tapping the mic again stops early.
4. Speech ends → status shows the recognized sentence, then "Processing...".
5. **Processing state**: FAB turns orange and is disabled (on-device inference
   takes a few seconds; there is no progress %, just this state).
6. Parse succeeds with complete data → expense saved silently → status reads
   "Saved: eggs — 50 taka (food)" → the new entry appears at the top of today's group.
7. Parse succeeds but is incomplete (amount 0 or item "unknown") → the edit
   sheet slides up pre-filled with whatever was parsed → user fixes fields →
   Save, or dismiss to discard ("Entry discarded").
8. Parse fails entirely → same edit sheet, item = the raw spoken sentence,
   amount empty → user completes it or discards.
9. Errors (timeout, permission, STT failure) → clear status message, user can retry.

### Flow 2 — Manual entry
1. Tap the small "+" FAB (Home tab only).
2. Edit sheet opens empty ("Add expense") with date = today, category = food.
3. Fill item (required), quantity (optional), amount (required, digits only),
   optionally change date/category → Save → appears in the list, status confirms.

### Flow 3 — Review & edit an existing expense
1. Tap any tile on Home or History → "Edit expense" sheet opens pre-filled.
2. Modify any field (including backdating via the date picker) → Save → list
   and totals update; regrouping may move the entry under a different date header.

### Flow 4 — Delete / restore
1. Swipe a tile left → it vanishes immediately → snackbar "Deleted "item"" with Undo.
2. Tap Undo within the snackbar window → expense is restored with its original
   date, back in its group. Doing nothing makes deletion permanent.

### Flow 5 — Analyze spending
1. Switch to the History tab (bottom navigation).
2. Optionally pick a range (This month / Last month / All time).
3. Optionally toggle search and type to filter by item name.
4. Read the pie chart (category shares + grand total in center + legend) and
   scan the flat chronological list below.

### Flow 6 — Export / destructive maintenance
1. History tab → share icon → CSV generated and handed to the Android share
   sheet (save to Drive, send to self, etc.).
2. History tab → overflow menu → "Clear all data" → confirmation dialog →
   confirm wipes everything (no undo for clear-all).

---

# Screens and Pages

There are exactly **two screens** (tabs) plus **one global modal bottom sheet**
and a couple of system dialogs. No named routes, no settings screen, no drawer.

### 1. Home tab (`HomeScreen`) — default screen
- **Purpose**: capture expenses (voice/manual) and give an at-a-glance "what did
  I spend today / this month" answer with a recent-activity feed.
- **Information displayed**:
  - App bar title "Expense Tracker".
  - Status line (plain text) reflecting the voice pipeline state.
  - Two rounded chips side by side: "Today — N ৳" and "<Month name> — N ৳".
  - Segmented control: Day | Month | Year (grouping mode).
  - Grouped expense list: sticky-feeling group headers ("27 August 2026" /
    "August 2026" / "2026") each with the group subtotal on the right; under
    each header, expense tiles with:
    - circular category avatar (category color at 15% alpha, colored icon),
    - item name (title),
    - subtitle: "quantity · category" or just category when no quantity,
    - bold amount "N ৳" on the right.
- **User actions**: tap mic (voice entry), tap + (manual entry), tap tile (edit),
  swipe tile left (delete + undo), toggle grouping mode, switch tab.
- **Key UI components**: mic FAB (stacked above a small + FAB, Home tab only —
  they disappear on the History tab), NavigationBar (Home/History),
  SegmentedButton, status text, list with headers, Dismissible tiles.
- **Empty state**: centered text "No expenses yet.\nTap the mic to add one!"

### 2. History tab (`HistoryScreen`)
- **Purpose**: browse, filter, search, analyze, export, and bulk-manage the full ledger.
- **Information displayed**:
  - App bar "History" (or the search field when search is active).
  - Below the app bar: range segmented control "This month | Last month | All time".
  - A card containing the **category pie chart** (donut, % labels, grand total
    centered, color legend with category names and ৳ amounts).
  - Flat (ungrouped) list of filtered expenses, newest first; tiles identical in
    anatomy to Home tiles except the subtitle shows "category · d/m/yyyy" and
    the row is denser (no default tile padding).
- **User actions**: toggle search + type query, pick range, tap tile to edit,
  swipe to delete (with undo), export CSV (share icon), clear all data
  (overflow menu → confirm dialog).
- **Key UI components**: search icon in app bar that morphs into a text field
  (with close icon), SegmentedButton, Card + donut chart, PopupMenuButton,
  share icon, AlertDialog confirmation, Dismissible tiles.
- **Empty states**:
  - No data in range: "No expenses in this range".
  - No search matches: "No matches for "<query>"".

### 3. Edit/Add expense sheet (`EditExpenseSheet`) — modal bottom sheet
- **Purpose**: create or correct an expense; the safety net for imperfect AI parses.
- **Title**: "Add expense" (create) or "Edit expense" (edit).
- **Fields**:
  - Item — text, required ("Enter an item" validation), sentence capitalization.
  - Quantity — optional text, hint "e.g. 2 kg" (free-form: "3 piece", "2 kg").
  - Amount (৳) — numeric keyboard, digits only, required.
  - Date — read-only field that opens the material date picker; past dates only
    (max = today, min = year 2000), shown as d/m/yyyy with a calendar icon.
  - Category — dropdown menu with the 8 categories, each row showing its
    colored icon; defaults to the existing category or "food" when creating.
- **Actions**: single full-width filled "Save" button with a check icon. Dismissing
  the sheet (back/tap-outside) cancels. Keyboard-aware (padding follows insets).
- Opens in three contexts: manual add, editing an existing expense, and
  reviewing an incomplete voice parse.

### 4. System dialogs & snackbars
- **Delete-all confirmation**: AlertDialog — title "Delete all expenses?", body
  "This permanently removes every entry from this device.", Cancel (text
  button) / "Delete all" (filled, destructive).
- **Undo-delete snackbar**: "Deleted "<item>"" + Undo action (shown on both tabs).
- **"Nothing to export" snackbar** on empty CSV export.
- Date picker (material) from the edit sheet.

---

# Data and Financial Concepts

### Expense (the only entity)
Stored in a single SQLite table `expenses`:

| Field | Type | Notes |
|---|---|---|
| id | int, autoincrement | local row id |
| item | text | what was bought (e.g., "eggs") — required |
| quantity | text, nullable | free-form, e.g. "2 kg", "3 piece"; often absent |
| amount | integer | **whole taka only** — no decimals, no pennies; 0 allowed temporarily during review |
| category | text | one of the 8 fixed category strings |
| created_at | ISO8601 text | expense date; editable (backdating supported); sorts newest-first |

There is **no concept of**: currency selection (always ৳ taka), accounts or
wallets, payment methods, income, transfers, refunds, tags, notes, attachments,
recurring charges, or multi-user data. One flat list of expenses is the entire
financial model.

### Derived numbers the UI shows
- **Today total**: sum of amounts where created_at is today's calendar day.
- **Month total**: sum for the current calendar month.
- **Group subtotals**: per day/month/year depending on grouping mode.
- **Category totals + grand total**: computed over whatever is currently
  filtered in History; rendered as the donut chart + legend.
- All arithmetic is integer sums of taka.

### The AI pipeline (context for UI states)
Spoken English → Android SpeechRecognizer (en-US, on-device) → text → Gemma 3
270M ONNX model (on-device, greedy decode, ~60 max new tokens) → JSON
`{item, quantity, amount, category}` → JSON repair step (tolerates truncated/
malformed output) → validation + category keyword fallback → Expense.
Failure modes the UI must absorb: empty speech, STT errors, slow inference
(seconds), malformed JSON, missing amount/item, invalid category.

---

# Navigation

```
MaterialApp (theme: Material 3, blue seed, light theme)
└── Scaffold
    ├── body: IndexedStack          ← both tabs stay alive (state preserved)
    │   ├── [0] Home tab           ← default
    │   └── [1] History tab
    ├── floatingActionButton: mic FAB + small "+" FAB  ← HOME TAB ONLY
    └── bottomNavigationBar: NavigationBar
        ├── Home (home icon)
        └── History (history icon)
```

- Two-level navigation only: tab switching + transient overlays (modal bottom
  sheet, dialogs, snackbars, date picker). No pushed routes, no back-stack
  management, no drawer, no app-bar-level navigation.
- The mic/+ FABs are contextual: visible on Home, hidden on History.

---

# Important UI States

### Empty states
- **Home, no expenses ever**: centered "No expenses yet.\nTap the mic to add
  one!" — doubles as onboarding; the mic is the affordance it points to.
- **History, no data in selected range**: "No expenses in this range".
- **History, no search results**: "No matches for "<query>"".
- Note: with data in some months but none in the selected one, History still
  shows the pie-chart card area only when there are filtered results — an empty
  range hides the chart entirely.

### Loading states
- DB reads happen fast on device; there is currently **no skeleton/spinner** for
  list loading (an area ripe for polish).
- **Voice processing** is the one true long wait (a few seconds): signalled only
  by the status text ("Recognized: "..."\nProcessing...") and the FAB turning
  orange + disabled. No progress bar, no animated indicator.

### Listening state
- FAB turns error/red while the mic is live; label/tooltip "Tap to stop";
  status line "Listening... (tap the mic to stop)". Auto-times-out after 20s
  ("Didn't hear anything. Tap the mic and try again.").

### Error states
- All voice-flow errors surface as the status line text (no dialogs, no toasts):
  - permission denied → "Microphone permission denied"
  - nothing heard / timeout → "Didn't hear anything. Tap the mic and try again."
  - unclear speech → "Couldn't understand that. Try speaking more clearly."
  - recognizer busy → "Recognizer busy — try again in a moment."
  - online-STT-required → "Speech service needs internet, which is unavailable."
  - missing permission (code 9) → "Microphone permission missing."
  - unknown STT error → "Speech recognition failed (error N)."
  - empty result → "No speech detected"
- There are no error states for DB/CRUD failures (not handled in UI today).

### Success states
- Status line after save: "Saved: <item> — <amount> taka (<category>)"
  (manual add omits the category). The list itself updates in place.
- Discarding a review sheet: "Entry discarded".

### Destructive-action confirmations
- Single delete: instant + undo snackbar (no confirm dialog).
- Clear all: explicit confirm dialog, no undo.

### First-time user experience
- No onboarding screens, no permission pre-prompt UI, no sample data. First
  launch = empty Home with the empty-state text. The mic permission dialog
  appears the first time the user taps the mic.

---

# Functional Requirements for the UI

The designed UI must support all of the following (all exist in code today):

1. Two persistent bottom tabs (Home, History) with state preserved across switches.
2. A prominent, always-available voice capture entry point on Home with three
   distinct visual states: idle / listening (stop affordance) / processing (disabled).
3. A lightweight status/feedback channel for the voice pipeline (listening,
   recognized sentence, saving, success, and every error above).
4. Microphone permission handling flow (first-request, denied).
5. Manual creation of an expense via a form: item (required), quantity
   (optional), amount (integer taka, required), date (past-only picker),
   category (fixed 8-option picker with icons/colors).
6. Editing every field of an existing expense from any list tile.
7. Review flow: when an AI parse lacks an amount or item, the same form opens
   pre-filled and must make fixing it fast (this is a frequent path, not an edge case).
8. Swipe-to-delete on list rows with an Undo snackbar (restore keeps original date).
9. Grouped list rendering on Home with three modes (Day/Month/Year), group
   headers showing title + subtotal.
10. Today + this-month total chips on Home.
11. History filtering by range (This month / Last month / All time).
12. History search by item name (case-insensitive substring) with clear affordance.
13. A category-distribution donut chart with center grand total, % labels, and
    a legend; recomputed for the active filter.
14. CSV export via the OS share sheet, with an empty-data guard.
15. "Clear all data" behind a confirmation dialog.
16. Currency rendering as "N ৳" everywhere; integer amounts.
17. Category visualization via the fixed icon+color mapping (avatars, dropdown,
    chart, legend) with an "other" fallback style.
18. Empty states for: never-used app, filtered-empty history, no search matches,
    nothing-to-export.
19. Keyboard-aware modal form (sheet must remain usable with keyboard open).

---

# Design Considerations

1. **The mic button is the product.** Its idle/listening/processing states must
   be unmistakable at a glance (color, icon, motion). Users must never wonder
   whether the app is hearing them, thinking, or stuck. Processing takes real
   seconds of on-device inference — this needs a better signal than the current
   text line (the designer's biggest single opportunity).
2. **The status line carries the whole voice conversation today.** Plain text
   top-of-screen. A designer should turn this into a proper transcript/feedback
   component (heard sentence, parse result preview, error + retry) without
   turning the flow into a wizard.
3. **Review-before-save is a first-class flow**, not an error path. AI parsing
   is imperfect by design; the UI should make "fix the missing amount and save"
   feel like one smooth gesture.
4. **Destructive asymmetry**: single deletes are undo-able and instant; clear-all
   is dialog-guarded and permanent. Preserve this asymmetry visually (snackbar
   vs dialog).
5. **Integer taka everywhere**: no decimals, no currency switching. Formatting
   should respect that (e.g., "1,250 ৳" is fine; "1,250.00" is wrong for this app).
6. **Category color system is load-bearing**: the same 8 icon+color pairs
   identify rows, dropdown entries, chart slices, and legend dots. A redesign
   must keep this consistent and accessible (color-blind-safe differentiation,
   readable icon-on-tint backgrounds).
7. **One-hand, voice-while-doing-things usage**: entries happen mid-task; the
   capture UI should be reachable and legible without precision taps. The FABs
   currently sit bottom-right above the nav bar.
8. **Group headers double as mini-reports** (subtotal per day/month/year) —
   scannability of these headers matters more than decoration.
9. **Offline privacy is a selling point** — the UI may communicate "all data
   stays on this device" (currently only implied by the clear-all dialog copy).
10. **English-only speech (en-US) with Bangladeshi context**: sample/empty-state
    copy should feel natural for the audience (taka, rickshaw/CNG examples are
    already the app's idiom).
11. **History list density**: rows are tighter there than on Home (zero content
    padding); a redesign may unify tile anatomy but should keep History scannable
    for long ledgers.
12. **The chart is the only data-viz in the app.** No trends-over-time chart,
    no budget bars, no comparisons — the pie answers "where does my money go"
    for a filtered period only.

---

# What Does NOT Exist (do not design these)

- No income tracking, balances, or net-position views.
- No budgets, limits, goals, or savings targets.
- No accounts, wallets, cards, or payment-method tagging.
- No authentication, PIN/biometric lock, profiles, or multi-user support.
- No cloud sync, backup/restore (beyond manual CSV share), or web/desktop UI.
- No settings screen or preferences (theme is fixed Material-3 blue seed, light
  theme only; no dark-mode toggle; no locale/currency options).
- No recurring transactions, subscriptions, reminders, or notifications of any kind.
- No category management (fixed list; no add/reorder/recolor in UI).
- No trends over time, bar/line charts, budgets-vs-actuals, or reports beyond
  the single category donut on History.
- No notes, tags, attachments, receipts, or photos on expenses.
- No onboarding tour, sample data, or app-icon-level customization.
- No tablet/landscape-optimized layouts (phone-portrait Android only).

---

# Planned / Unfinished (visible in repo, not in the shipped UI)

- **`summary_screen.dart` from the original spec was never built**; its purpose
  (totals by category) was absorbed into the History tab's pie chart. Do not
  design a third tab unless explicitly desired.
- **Quantization was abandoned**: the shipped ONNX model is FP16 (~537 MB);
  INT8/INT4 exports broke output quality. Implication: heavy on-device
  inference and a large app — loading/processing UX deserves real design care.
- **JSON repair + category keyword fallback** are defensive mitigations for
  known model failure modes (truncated JSON, bogus categories) — the review
  sheet is the visible counterpart; treat "AI was slightly wrong" as normal.
- **No skeleton loaders or inference progress indication exist yet**; the
  spec's "known challenges" section explicitly calls for a loading indicator
  during 2–5s processing. This is acknowledged-but-unbuilt UX debt.
- The spec once listed an `INTERNET` permission for an optional online STT
  fallback; it was removed — the app is strictly offline and its error copy
  says so ("Speech service needs internet, which is unavailable").
- No dark theme is defined in code (`theme` only, no `darkTheme`), though the
  Android launch theme has a night variant.

---

# Suggested Design Priorities

1. **Voice capture experience** — mic button states (idle/listening/processing),
   real-time feedback (heard text, processing indicator), and error/retry
   microcopy. This is the hero interaction and the current weakest UI surface.
2. **Review/edit sheet** — the form users hit both for manual entry and for
   correcting AI parses; optimize for speed (big amount field, quick category
   picking, immediate save) and clarity of the two modes (add vs review).
3. **Home dashboard** — Today/Month totals, grouping toggle, and scannable
   grouped list with subtotals; the default "did I overspend today?" glance.
4. **History + category donut** — filtering, search, chart legend, and long-list
   performance/scannability.
5. **Empty & first-run states** — the app's de-facto onboarding is the Home
   empty state + mic permission moment; make them teach the voice flow.
6. **Destructive-action patterns** — consistent swipe-delete + undo, and a
   trustworthy clear-all confirmation.
7. **Category identity system** — a refined, accessible icon+color language used
   consistently across rows, forms, chart, and legend.
8. **Polish layer** — skeletons for loads, success micro-animations (save → row
   appears), haptics on capture, and a subtle "offline/private" trust signal.
