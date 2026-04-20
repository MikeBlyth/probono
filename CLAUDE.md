# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A hybrid AI architecture for immigrant legal aid case management. The goal is to move beyond spreadsheet workflows to a vector-enabled relational database that can:

- **Semantically match** clients to law firms (e.g., matching an indigenous Ecuadorian client to a firm with Andean human rights expertise, not just "Spanish speaker")
- **Predict case success** using historical outcomes and salient characteristics (age, country of origin, assigned judge, etc.)
- **Automate organizational workflows** for client selection, communication, and status monitoring

**Future goal:** Web-based UI so case managers can interact with the matching system through a browser rather than running notebooks.

Current state: full pipeline working end-to-end on 50-row dummy data — load → textualize → embed → search. Paused pending real client/firm schemas.

## Architecture

Three-layer stack:

**Data Layer — PostgreSQL 14 + pgvector (port 5432)**
- `clients` table: hard facts + computed fields + `search_profile` text + `search_vector` tsvector (generated) + `embedding` vector(768) + `language_code CHAR(3)`
- `firms` table: law firm data + `text_summary` + `embedding` vector(768)
- `allowed_languages`: ISO 639-3 living languages (~7,084 rows) with `code`, `canonical_name`, `display_name` (overridable), `scope`
- `language_aliases`: ISO name index + manual colloquial aliases (e.g., "Mandarin" → `cmn`, "Kichwa" → `qug`)
- `firm_languages`: junction table (firm_id × ISO language code)

**Intelligence Layer — Python / Jupyter**
- *Flattening*: `textualizer()` and `firm_textualizer()` in `Import CSV Files.ipynb` convert rows into natural language sentences for embedding. Includes urgency signals: hearing proximity (URGENT/Upcoming), age-cliff warnings (18th/21st birthday), age category labels (minor/young adult/adult).
- *Encoding*: `embed.ipynb` uses `sentence-transformers/all-mpnet-base-v2` (768-dim) to populate `embedding` columns

**Analysis Layer — Hybrid Search**
- `search.ipynb`: cosine similarity ranking (`<=>` operator) of firms against a client embedding
- Language pre-filter (SQL JOIN on `firm_languages`) is implemented but commented out — activate once real schemas are in place

## Notebooks

| Notebook | Purpose |
|---|---|
| `Load Languages Table.ipynb` | Loads ISO 639-3 into `allowed_languages` + `language_aliases` + manual colloquial aliases. Run once before importing client/firm data. |
| `Import CSV Files.ipynb` | Loads `clients.csv` and `practices.csv`, computes derived fields, runs textalizers, pushes to DB. |
| `embed.ipynb` | Encodes `search_profile` and `text_summary` into 768-dim vectors using all-mpnet-base-v2. Re-run after any textualizer change. |
| `search.ipynb` | Runs cosine similarity search — given a client ID, returns ranked firms. |
| `InitialSetup.ipynb` | One-time environment check (package imports). |

**Run order:** `Load Languages Table` → `Import CSV Files` → `embed` → `search`

## Data Schema

### clients
| Field | Notes |
|---|---|
| `Client_ID` | C001–C050 |
| `Name`, `Sex`, `Country_of_Origin` | |
| `DOB` | Date of birth — used to compute `Age` and age-out deadlines |
| `Age` | Integer, computed from DOB at load time |
| `days_to_18`, `days_to_21` | Computed from DOB — negative = already past threshold |
| `Date_of_Entry` | |
| `NTA Date` | Notice to Appear date — must be >= Date_of_Entry |
| `Detention Date` | Must be >= NTA Date |
| `Location` | Detention facility (short name, e.g. "Farmville") |
| `Primary_Language` | Free text — normalized to `language_code` at load time |
| `language_code` | CHAR(3) ISO 639-3 code, FK to `allowed_languages` (NOT VALID constraint) |
| `Medical_Conditions` | Salient for matching and success modeling |
| `Document_Status` | Parole, TPS, Pending Asylum, No Documents, Expired Visa, Visa Overstay, SIV Pending |
| `Next_Hearing_Date`, `Next_Hearing_Type` | Master Calendar, Individual Merits, Status Hearing, Credible Fear Interview |
| `Defense_Category` | Asylum, Removal Defense, Family-Based, Cancellation of Removal, etc. |
| `Notes` | Free text — appended to search_profile for embedding |
| `search_profile` | Output of `textualizer()` — natural language paragraph for embedding |
| `search_vector` | TSVECTOR generated from `search_profile` — for full-text search |
| `embedding` | vector(768) — populated by `embed.ipynb` |

### firms
| Field | Notes |
|---|---|
| `Firm_ID` | Primary key (F101–...) |
| `Firm_Name`, `Size`, `Special_Niche` | |
| `Languages_Spoken` | Raw comma-separated string — normalized via `firm_languages` junction table |
| `Asylum_Success_Count`, `Asylum_Failure_Count`, etc. | Outcome history for success prediction |
| `Current_Org_Caseload`, `Subjective_Rating` | |
| `Notes` | Free text — appended to text_summary for embedding |
| `text_summary` | Output of `firm_textualizer()` — natural language bio for embedding |
| `embedding` | vector(768) — populated by `embed.ipynb` |

## Language Normalization

Colloquial language names (e.g., "Mandarin", "Cantonese", "Kichwa", "Farsi") are not in the ISO name index. They are added manually in `Load Languages Table.ipynb` via `INSERT INTO language_aliases`. When the `firm_languages` build step or the client language normalization step reports unmatched languages, add them to that manual block and re-run `Load Languages Table`.

See memory file `language_table_design.md` for notes on the longer-term design decision around this.

## Next Steps (resuming with real data)

1. **Adapt schemas** — update `clients.csv`, `practices.csv`, textualizers, and DB push logic to match real field names and values.
2. **Activate language pre-filter** in `search.ipynb` — the JOIN on `firm_languages` is implemented but commented out.
3. **Add `display_name` overrides** — for verbose ISO canonical names (e.g., "Chimborazo Highland Quichua" → "Quechua/Kichwa").
4. **Validate `fk_language_code`** — once all client languages resolve cleanly, run `ALTER TABLE clients VALIDATE CONSTRAINT fk_language_code`.
5. **Build web UI** — lightweight browser interface for case managers (FastAPI or Flask + pgvector backend).

## Data Sensitivity

Files contain sensitive personal data (immigration status, medical conditions, hearing dates). Do not expose, log, or transmit to external services. The `.env` file contains the Postgres password — it is gitignored.
