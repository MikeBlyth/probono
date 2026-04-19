# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A hybrid AI architecture for immigrant legal aid case management. The goal is to move beyond spreadsheet workflows to a vector-enabled relational database that can:

- **Semantically match** clients to law firms (e.g., matching an indigenous Ecuadorian client to a firm with Andean human rights expertise, not just "Spanish speaker")
- **Predict case success** using historical outcomes and salient characteristics (age, country of origin, assigned judge, etc.)
- **Automate organizational workflows** for client selection, communication, and status monitoring

Current state: database is stood up and populated with 50-row dummy datasets. Core pipeline (load → flatten → push) is working. Language normalization infrastructure is in place but not yet wired into the client/firm tables.

## Architecture

Three-layer stack:

**Data Layer — PostgreSQL 14 + pgvector (port 5432)**
- `clients` table: hard facts + computed fields + `search_profile` text + `search_vector` tsvector (generated) + `embedding` vector(768)
- `firms` table: law firm data + `text_summary` + `embedding` vector(768)
- `allowed_languages`: ISO 639-3 living languages (~7,084 rows) with `code`, `canonical_name`, `display_name` (overridable), `scope`
- `language_aliases`: ISO name index mapping alternate spellings → `allowed_languages.code`
- `firm_languages`: junction table (firm_id × language code) — **not yet rebuilt against ISO codes**

**Intelligence Layer — Python / Jupyter**
- *Flattening*: `textualizer()` in `Import CSV Files.ipynb` converts client rows into natural language sentences for embedding
- *Encoding*: not yet implemented — next step is wiring in a sentence-transformers or Gemini embedding model

**Analysis Layer — Hybrid Search**
- SQL pre-filter on hard constraints (language, document status, etc.)
- Cosine similarity ranking on embeddings — not yet implemented

## Notebooks

| Notebook | Purpose |
|---|---|
| `Load Languages Table.ipynb` | Loads ISO 639-3 into `allowed_languages` + `language_aliases`. Run once before importing client/firm data. |
| `Import CSV Files.ipynb` | Loads `clients.csv` and `practices.csv`, computes derived fields, runs textualizer, pushes to DB. |
| `InitialSetup.ipynb` | Placeholder — not yet used. |

**Run order:** `Load Languages Table` → `Import CSV Files` (top to bottom).

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
| `Primary_Language` | Free text for now — should be normalized to ISO code via `language_aliases` |
| `Medical_Conditions` | Salient for matching and success modeling |
| `Document_Status` | Parole, TPS, Pending Asylum, No Documents, Expired Visa, Visa Overstay, SIV Pending |
| `Next_Hearing_Date`, `Next_Hearing_Type` | Master Calendar, Individual Merits, Status Hearing, Credible Fear Interview |
| `Defense_Category` | Asylum, Removal Defense, Family-Based, Cancellation of Removal, etc. |
| `search_profile` | Output of `textualizer()` — natural language sentence for embedding |
| `search_vector` | TSVECTOR generated from `search_profile` — for full-text search |
| `embedding` | vector(768) — not yet populated |

### firms
| Field | Notes |
|---|---|
| `Firm_ID` | Primary key (F101–...) |
| `Firm_Name`, `Size`, `Special_Niche` | |
| `Languages_Spoken` | Raw comma-separated string — normalized via `firm_languages` junction table |
| `Asylum_Success_Count`, `Asylum_Failure_Count`, etc. | Outcome history for success prediction |
| `Current_Org_Caseload`, `Subjective_Rating` | |
| `text_summary` | Firm-side flattening — not yet implemented |
| `embedding` | vector(768) — not yet populated |

## Next Steps

1. **Fix `firm_languages`** — currently uses raw language name strings. Rebuild to look up ISO codes via `language_aliases`, so `firm_id × code` is the join key.

2. **Normalize `clients.Primary_Language`** — add a `language_code CHAR(3)` column referencing `allowed_languages`, populated via `language_aliases` lookup at load time.

3. **Add `display_name` overrides** — for languages with verbose ISO canonical names (e.g., "Chimborazo Highland Quichua"), add a SQL block in `Load Languages Table.ipynb` to set preferred display names after loading.

4. **Write the firm textualizer** — analogous to the client `textualizer()`, converts firm rows into a natural language bio for embedding.

5. **Wire in embeddings** — use `sentence-transformers` or Gemini embedding API to populate `clients.embedding` and `firms.embedding` from `search_profile` / `text_summary`.

6. **Build hybrid search query** — SQL pre-filter on language code + document status + defense category, then cosine similarity ranking on embeddings.

7. **Clean up notebooks** — delete empty cells (`bafc5e52` in `Import CSV Files.ipynb`, first cell in `Load Languages Table.ipynb`), flesh out or remove `InitialSetup.ipynb`.

## Data Sensitivity

Files contain sensitive personal data (immigration status, medical conditions, hearing dates). Do not expose, log, or transmit to external services. The `.env` file contains the Postgres password — it is gitignored.
