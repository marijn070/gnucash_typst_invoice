# gnucash_invoice

Generates a PDF invoice (factuur) from a [GnuCash](https://www.gnucash.org/) database.

The invoice layout is in Dutch and targets the Dutch/Belgian market (KvK, BTW, IBAN, EPC QR-code). Currency is hardcoded to euros.

## How it works

```
GnuCash SQLite DB
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
| `nucash/mod.nu` | Nushell module. Provides `invoice list`, `invoice get`, and `company info` commands that read directly from the GnuCash SQLite file. |
| `invoice/invoice.typ` | Typst template. Reads `invoice/data/invoice.toml` and `invoice/data/company_info.toml` and produces the final PDF. Includes an EPC QR-code that customers can scan with their banking app. |
| `justfile` | Glue script. Resolves the invoice ID, writes the TOML files, and calls `typst compile`. Exposes two recipes: `just latest` and `just print`. |

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

> **SQLite format required.** GnuCash must save the file in SQLite format (File → Save As → select *GnuCash sqlite3* as the format). The XML format is not supported.

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
nucash invoice list --full   # full details
```

### Use the Nushell module standalone

If you only want access to the GnuCash Nushell commands without the PDF tooling, you can load the module directly in any Nushell session:

```nu
use /path/to/nucash
nucash invoice list
nucash invoice get --id 2024-001
nucash company info
```

To make it permanent, add the `use` line to your `$nu.config-path` (usually `~/.config/nushell/config.nu`).

## Assumptions & limitations

- **Euros only.** The currency symbol, EPC QR-code prefix (`EUR`), and Typst template are all hardcoded to €. Other currencies are not supported.
- **SQLite format only.** The module opens the GnuCash file with Nushell's `open` command, which uses the SQLite driver. XML-format GnuCash files will not work.
- **`GNC_FILE` environment variable.** This is the expected way to point at your GnuCash file. You can also pass `--file <path>` to any `nucash` subcommand directly.
- **Company ID (KvK) and VAT (BTW) number required.** These are read from GnuCash's business preferences and printed on the invoice. If they are not set, the commands will error.
- **21% VAT assumed.** The template labels the tax line as *BTW 21%*. The actual tax amount is derived from the difference between the invoice total and subtotal as recorded in GnuCash — but the label is not dynamic.
- **Dutch language.** All invoice text (headers, labels, payment instructions) is in Dutch.
- **Latest invoice by default.** `just latest` always picks the most recently opened invoice. Use `just print` to interactively select a specific one from a fuzzy list.
