# Calendar Rails plan

ADR 0005 is the product decision: the calendar is one text document per user per
year. This note scopes the Rails change that follows from it.

## Target shape

Persist only:

| Model | Table | Notes |
|---|---|---|
| `YearDoc` | `year_docs` | `user_id`, `year`, `body`; unique per user/year |
| `Version` | `versions` | polymorphic over `Note` and `YearDoc`; whole body snapshot |
| derived index | TBD | rebuildable rows for search, reminders, backlinks |

There is no persisted `Day`, `DayEntry`, or `DayLog`. A day is a span in
`YearDoc#body`, found by parsing date lines. Parser return values may be plain
Ruby value objects, but they are not domain models and they do not get ids.

## `YearDoc`

Migration:

- `id` string UUID primary key
- `user_id` string, not null, foreign key
- `year` integer, not null
- `body` text, not null, default `""`
- timestamps
- unique index on `[user_id, year]`

Model:

- `include UuidPrimaryKey`
- `belongs_to :user`
- validate `year` as a four-digit integer in a practical range
- validate uniqueness of `year` scoped to `user_id`
- `for(user:, year:)` or `current_user.year_docs.find_or_create_by!(year:)`
- `ensure_today!(date = Date.current)` can create today's date line if missing,
  but it writes text, not a `Day`
- callbacks or a service rebuild the derived index after save once the index
  exists

Associations:

```rb
class User
  has_many :year_docs, dependent: :destroy
end
```

## Parser boundary

Keep parsing out of Active Record. Suggested namespace:

- `Calendar::Parser.call(body:, year:)`
- `Calendar::Document` — immutable parse result
- `Calendar::DaySpan` — `date`, `heading_line_no`, `from`, `to`, `lines`
- `Calendar::Entry` — `date`, `line_no`, `text`, `kind`, `done`, `time_text`,
  `trace`, `links`

These are values over text. They are useful for rendering, indexing, search hit
resolution, reminder scans and tests. They are not saved.

The first parser can be deliberately small:

- date line: `/^\s*(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/i`
- done line: `/\bdone\s*$/i`
- drop line: `/\b(not ?doing|fail)\b/i`
- leading time is parsed for `kind: event`, but kept as text

## Web/API surface

HTML:

- `YearsController#show` renders the CodeMirror page for `params[:id]`
- `YearsController#update` replaces the body, used by debounced autosave
- left rail `Calendar` link points to the current year

JSON:

- `GET /api/v1/years/:year` returns the year doc
- `PUT /api/v1/years/:year` replaces it
- use a base-version field before native clients write calendar text; otherwise
  two devices turn into last-write-wins immediately

Swagger changes are required when the API lands: request specs under
`spec/requests/api/`, response shapes in `spec/swagger_helper.rb`, then
`bundle exec rake rswag:specs:swaggerize`.

## Versioning

Milestone 14 stays polymorphic. For `YearDoc`, snapshot the whole previous body,
coalesced by editing session the same way as notes. A year is small enough that
diffs are not worth introducing.

If API conflict handling is still simple when native calendar writes arrive, a
stale write can be stored as a `Version` and rejected rather than overwritten.

## Derived index

Do not build this before a caller needs it. The first likely callers are search
and `[[…]]` backlinks.

Expected rows:

- calendar entries: `user_id`, `year_doc_id`, `date`, `line_no`, `kind`, `text`,
  `done`, optional parsed time
- calendar links: `user_id`, `year_doc_id`, `date`, `line_no`, `target_type`,
  `target_id`

The index is disposable: rebuild from all `YearDoc` rows; delete and recreate on
save is fine at this scale.

## Remove now

Files/classes:

- `app/models/day_entry.rb`
- `app/models/day_log.rb`
- `app/models/day.rb`
- `app/models/year.rb`
- `spec/models/day_entry_spec.rb`
- `spec/models/day_log_spec.rb`
- `spec/models/year_spec.rb`
- `test/fixtures/day_entries.yml`
- `test/fixtures/day_logs.yml`

Code edits:

- remove `has_many :day_entries` and `has_many :day_logs` from `User`
- remove `entries` and `logs` helpers from `Scoped`
- remove day-entry/day-log seed data and leak canaries
- update isolation specs to cover `year_docs`
- update ADR 0001/0002 references in a follow-up ADR note only if they become
  confusing; ADR 0005 is the supersession point

Database:

- drop `day_entries`
- drop `day_logs`
- add `year_docs`

Because no deployed calendar UI or API exists yet, there is no user data
migration unless the local seed database matters. The existing text-log import
is a separate importer that writes `YearDoc#body`.

## Implementation order

1. Replace schema and model specs with `YearDoc`.
2. Remove the old calendar models, fixtures, seeds and isolation references.
3. Add parser tests with the prototype's seed text as a fixture.
4. Add `/calendar` or `/years/:year` HTML route and the current-year rail link.
5. Vendor the CodeMirror bundle into `vendor/javascript` with `Annotation`,
   `@codemirror/search` and `@codemirror/autocomplete` included.
6. Port `stream-text.html` into one Stimulus controller and CSS module.
7. Add the JSON year endpoint and rswag specs.
8. Add versioning and the derived index when their milestones arrive.
