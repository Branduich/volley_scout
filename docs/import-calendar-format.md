# Importing a season calendar from a custom spreadsheet

Volley Stratego can import a whole season calendar from a spreadsheet: every
fixture becomes a row you can turn into a match with one tap, already filled in
with date, opponent, home/away and venue. Played fixtures also feed the
**Standings** tab.

The importer was built around the file the Italian federation (FIPAV) exports,
but there is nothing Italian about the format itself: it is an ordinary
spreadsheet with a header row. If your federation exports something else — or
nothing at all — you can build the file yourself in Excel, Google Sheets,
LibreOffice or Numbers, and the app will read it.

This page describes exactly what the file must contain.

---

## 1. The file

- **Format**: `.xlsx` (Excel 2007 and later, Google Sheets, LibreOffice) or
  `.xls` (Excel 97-2003). Both work.
- The app looks at the **content** of the file, not at its name, so a file that
  was renamed by hand still works. A web page saved with an `.xls` extension —
  something a few federation sites do — is rejected with a clear message; open
  it and re-save it as a real spreadsheet.
- **Only the first sheet is read.** Its name does not matter. Anything on a
  second sheet is ignored.
- **The header must be the very first row.** Do not put a title, a logo or a
  blank line above it: the app reads row 1 as the column names.
- Data starts on row 2, one fixture per row.
- Trailing empty rows are ignored (Google Sheets adds hundreds of them — that
  is fine).

## 2. The columns

Copy this header into row 1:

```
Campionato | Gara N | Giornata | Data | Ora | SquadraCasa | SquadraOspite | Risultato | Parziali | StatoDescrizione | Impianto | IndirizzoImpianto
```

The column **names are keywords and must be kept in Italian** — they are how
the app recognises each column. Everything else about them is flexible:

- **Order does not matter.** Columns are matched by name, not by position.
- **Spacing and case do not matter**: `SquadraCasa`, `squadra casa`,
  `SQUADRA_CASA` and `Squadra-Casa` are all understood.
- **Extra columns are ignored**, so you can keep your own notes in the file.

| Column | Required | Content |
|---|---|---|
| `Campionato` | **yes** | League/division/group name, e.g. `U18 WOMEN – GROUP B`. Write the **same value on every row**: it becomes the name of the league in the app. |
| `Data` | **yes** | Match date. See [Dates and times](#3-dates-and-times) — read that section, it is the one thing that goes wrong most often. |
| `SquadraCasa` | **yes** | Home team. |
| `SquadraOspite` | **yes** | Away team. |
| `Gara N` | no, but recommended | Match number, a whole number, unique in the file. See [Re-importing](#5-re-importing-the-same-league). |
| `Giornata` | no | Round / matchday number, a whole number. |
| `Ora` | no | Start time. Empty means midnight. |
| `Risultato` | no | Final result **in sets**, e.g. `3-1`. Leave empty for a fixture that has not been played yet. |
| `Parziali` | no | Set scores, e.g. `25-17 20-25 25-14 25-6`. |
| `Impianto` | no | Venue name, e.g. `Sports Hall Galilei`. |
| `IndirizzoImpianto` | no | Venue street address, e.g. `Via Porrettana 97`. |
| `StatoDescrizione` | no | Free text status from your federation. Stored, but not used by any calculation. |

If one of the four required columns is missing, the import stops with a message
listing what it could not find, and shows the column names it did read — useful
to spot a typo.

A row that has no home team, no away team or no readable date is skipped and
counted in the import summary ("N rows ignored"), so nothing disappears
silently.

## 3. Dates and times

**The safest option: format the `Data` column as a real date** in your
spreadsheet (Format → Number → Date), and the `Ora` column as a real time. The
app reads the underlying value, so the day/month order can never be
misunderstood — regardless of your locale or your federation's conventions.

If you prefer plain text, then:

- **Date must be `dd/MM/yyyy`** — day first: `12/10/2027` means **12 October**
  2027. Single digits are fine (`5/2/2027`).
  > ⚠️ US-style `MM/DD/YYYY` and ISO `YYYY-MM-DD` written as text are **not**
  > recognised. `10/12/2027` typed as text is read as 10 December. If your dates
  > are in either of those formats, convert the column to a real date instead —
  > that removes the ambiguity completely.
- **Time must be 24-hour `HH:mm`**: `21:00`, not `9:00 PM`. A trailing `PM` is
  ignored rather than applied, so `9:00 PM` would be stored as 09:00.

## 4. Results and standings

- A fixture counts as **played** as soon as `Risultato` contains something like
  `3-1`. Anything else — empty, `-`, `TBD` — counts as **not yet played**, which
  is what makes the **Create match** button appear for it in the Calendar tab.
- `Parziali` is only used for the points-ratio tiebreaker. You can leave it
  empty: match points and set counts stay correct, only that one tiebreaker
  becomes unusable.
- Team names are matched **exactly** (after trimming spaces at the ends). Spell
  each team identically on every row — `Volley Tower` and `VOLLEY TOWER` would
  appear as two separate teams in the standings.

> **Standings use the FIPAV/FIVB points system**, which is currently fixed:
> **3 points** for a 3-0 or 3-1 win, **2 points** for a 3-2 win and **1 point**
> for the team losing 2-3, 0 for any other defeat. Ranking order: points, then
> matches won, then set ratio, then points ratio, then name. If your federation
> uses a different system, the Calendar tab still works perfectly — only the
> Standings numbers will not match your official table.

If every fixture in the file involves the same team — which is what you get when
a federation site exports "my club's matches only" — the app detects it and
shows a **partial standings** warning, because the matches between the other
teams are missing. Export or build the whole group to get a complete table.

The **season label** (`2027/28`) is deduced from the earliest date in the file:
July and later belong to the season starting that year.

## 5. Re-importing the same league

Import the same file again whenever results are published: existing fixtures are
updated in place instead of being duplicated, and a fixture you already turned
into a match keeps that link.

How a fixture is recognised as "the same one":

- if `Gara N` is present, by that number — **this is why the column is
  recommended**: the fixture is still recognised after a postponement changes
  its date;
- otherwise, by date + home team + away team, so a rescheduled fixture is
  treated as a new one, and the old row stays in the calendar.

Fixtures are never deleted by an import. If the file changed a lot, delete the
league from the ⋮ menu and import again — matches you already created stay in
**Matches**.

When a league with the same name already exists, the app asks whether to update
it or to create a new one, which is how two seasons of the same group can live
side by side.

## 6. Minimal example

Only the four required columns, dates as text:

| Campionato | Data | SquadraCasa | SquadraOspite |
|---|---|---|---|
| U18 WOMEN GROUP B | 12/10/2027 | PINK D | NETTUNO |
| U18 WOMEN GROUP B | 17/10/2027 | NETTUNO | PS SPORT |

A complete row, as the app likes it best:

| Campionato | Gara N | Giornata | Data | Ora | SquadraCasa | SquadraOspite | Risultato | Parziali | Impianto | IndirizzoImpianto |
|---|---|---|---|---|---|---|---|---|---|---|
| U18 WOMEN GROUP B | 386 | 1 | 12/10/2027 | 11:00 | PINK D | NETTUNO | 3-0 | 26-24 25-15 25-12 | Sports Hall Galilei | Via Porrettana 97 |

## 7. After the import

The app asks **which team is yours**, choosing from the names found in the file.
That answer decides home/away for every fixture and which side is shown as the
opponent, so the **Create match** buttons stay disabled until you give it.

Each created match gets: name (`Gara N 386 G. 1 PINK D - NETTUNO`), date and
time, home/away, opponent, and venue as `Impianto, IndirizzoImpianto` — which
the match form can open in your phone's maps app.

> Importing a calendar is a **premium** feature. Viewing the standings is not.
