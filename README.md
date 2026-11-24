# gnucash_invoice

Generates a PDF invoice (factuur) from a [GnuCash](https://www.gnucash.org/) database.

The invoice layout is in Dutch and targets the Dutch/Belgian market (KvK, BTW, IBAN, EPC QR-code). Currency is hardcoded to euros.

## How it works

```
GnuCash SQLite or PostgreSQL DB
       │
       ▼
nucash/mod.nu          ← Nushell module: queries the DB, extracts invoice + company data
       │
       ├─ invoice/data/invoice.toml
       └─ invoice/data/company_info.toml
                │
                ▼
       invoice/invoice.typ   ← Typst template: renders the PDF
                │
                ▼
       out/Factuur_<name>_<date>.pdf
```

### Files

| File | Description |
|---|---|
| `nucash/mod.nu` | Nushell module. Provides `invoice list`, `invoice get`, and `company-info` commands that read from a GnuCash SQLite file or PostgreSQL database. |
| `invoice/invoice.typ` | Typst template. Reads `invoice/data/invoice.toml` and `invoice/data/company_info.toml` and produces the final PDF. Includes an EPC QR-code that customers can scan with their banking app. |
| `justfile` | Glue script. Resolves the invoice ID, writes the TOML files, and calls `typst compile`. Exposes two recipes: `just latest` and `just pick`. |

## Prerequisites

- **[Nushell](https://www.nushell.sh/)** (`nu`) — the scripting language used by the module and justfile
- **[just](https://github.com/casey/just)** — task runner
- **[Typst](https://typst.app/)** — document compiler (`typst compile`)

## GnuCash setup requirements

The following fields must be filled in inside GnuCash before generating an invoice:

- **Edit → Preferences → Business**
  - Company Name
  - Company Address
  - Company Contact Person
  - Company Email Address
  - Company Phone Number
  - **Company ID** — your KvK (Chamber of Commerce) number
- **Edit → Preferences → Tax**
  - **Tax Number** — your BTW (VAT) number
- **Bank account** — the IBAN of your business account must be set as the `online_id` on the corresponding GnuCash bank account. This is used for the payment info block and the EPC QR-code.

## Configuration

Set the `GNC_FILE` environment variable to the path of your GnuCash database:

```sh
export GNC_FILE=/path/to/your/finances.gnucash
```

GnuCash must save local files in SQLite format (not XML). An explicit `--file` always selects SQLite.

### PostgreSQL

Install the `psql` client. Set `GNC_BACKEND=postgres` and the standard libpq settings `PGHOST`, `PGDATABASE`, `PGUSER`, and, if needed, `PGPORT`. Provide authentication through an appropriately protected `PGPASSFILE` or your secret manager; never commit credentials or pass a password on the command line. For remote deployments with PostgreSQL TLS, configure `PGSSLMODE=verify-full` and the trusted CA. Set `PGCONNECT_TIMEOUT` to bound connection attempts.

The exporter uses `psql` non-interactively and executes its static queries inside read-only transactions. It does not acquire or override GnuCash's application lock and does not write to the database. For production usage, prefer a database role limited to reading the necessary tables. Render only from posted invoices and avoid rendering while the invoice is being edited: invoice and company settings are separate reads.

If several different `online_id` values are present, set `GNC_BANK_ACCOUNT_GUID` to the GUID of the intended payment account. The renderer refuses to choose an ambiguous account.

## Usage

### Generate a PDF for the latest invoice

```sh
just latest
```

### Interactively pick an invoice and generate a PDF

```sh
just pick
```

Presents a fuzzy-searchable list of all invoices and compiles the one you select.

The PDF is written to `out/Factuur_<CompanyName>_<InvoiceID>_<date_posted>.pdf`.

### Browse invoices

```nu
use nucash
nucash invoice list          # summary table
nucash invoice list --details   # full details
```

### Use the Nushell module standalone

If you only want access to the GnuCash Nushell commands without the PDF tooling, you can load the module directly in any Nushell session:

```nu
use /path/to/nucash
nucash invoice list
nucash invoice get 2024-001
nucash company-info
```

To make it permanent, add the `use` line to your `$nu.config-path` (usually `~/.config/nushell/config.nu`).

## Assumptions & limitations

- **Euros only.** The currency symbol, EPC QR-code prefix (`EUR`), and Typst template are all hardcoded to €. Other currencies are not supported.
- **Company ID (KvK) and VAT (BTW) number required.** These are read from GnuCash's business preferences and printed on the invoice. If they are not set, the commands will error.
- **No VAT rate is assumed.** The template displays the difference between the posted total and the computed subtotal, without a percentage. The existing subtotal query multiplies quantities by unit prices; it does not model discounts, tax-inclusive prices, or a breakdown by VAT rate. Verify these invoices against GnuCash before using the PDF.
- **Dutch language.** All invoice text (headers, labels, payment instructions) is in Dutch.
- **Latest invoice by default.** `just latest` always picks the most recently opened invoice. Use `just pick` to interactively select a specific one from a fuzzy list.

## Integration tests

With `nu` on `PATH`, run `uv run --with pgserver python tests/test_backends.py`. This creates a private temporary PostgreSQL server and SQLite book containing synthetic data. It checks backend parity, PostgreSQL read-only enforcement, and the SQLite override. Add `--pdf` with `just` and `typst` installed to test full PDF generation (Typst may need to fetch the template's pinned packages).

The fixture does not certify compatibility with any particular migrated production book.

### Prepare a local invoice email draft (optional)

After rendering and reviewing an invoice, supply the intended recipient and
message body explicitly:

```sh
python3 invoice/draft_email.py --pdf out/your-invoice.pdf --out out/draft.eml \
  --to klant@example.com --subject 'Factuur 42' --body-file body.txt
```

The command attaches the PDF to a new local `.eml` with `X-Unsent: 1`. It does
not contact a mail service or send anything. How a mail client opens `.eml`
files varies; review the recipient, body and attachment before any manual send.

### Exact invoice and editable mailbox draft

Use `GNC_INVOICE_ID=101 just render` to render a specific posted invoice,
not whichever invoice happens to be latest. Duplicate IDs are rejected.

After preparing and reviewing the local `.eml`, optionally copy it to the
confirmed IMAP Drafts folder with `python3 invoice/imap_draft.py --host
HOST --folder INBOX.Drafts --draft-key invoice-101 --eml out/draft.eml`.
Provide `INVOICE_IMAP_USER` and `INVOICE_IMAP_PASSWORD` through a protected
runtime. The command uses IMAP with verified TLS, not SMTP. Run only one
draft worker per mailbox. Reuse the same key if the response is lost;
if a mail client has since edited the draft (and perhaps removed its
custom key), inspect the folder manually before retrying. The local `.eml`
remains available if IMAP is not configured.
