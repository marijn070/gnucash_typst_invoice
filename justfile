# Generate PDF for the latest invoice
latest:
    #!/usr/bin/env nu
    use {{ justfile_dir() }}/nucash
    let id = nucash invoice latest | get id
    with-env {GNC_INVOICE_ID: $id} { ^just _compile }

# Interactively pick an invoice and generate a PDF
pick:
    #!/usr/bin/env nu
    use {{ justfile_dir() }}/nucash
    let id = nucash invoice pick | get id
    with-env {GNC_INVOICE_ID: $id} { ^just _compile }

[private]
_compile:
    #!/usr/bin/env nu
    use {{ justfile_dir() }}/nucash
    let invoice_data = nucash invoice get $env.GNC_INVOICE_ID
    if $invoice_data.date_posted == null or $invoice_data.total == null {
        error make {msg: "Cannot render an unposted invoice or one with no posted total."}
    }
    let company_info = nucash company-info

    mkdir invoice/data
    $invoice_data
    | to toml
    | nucash date-only
    | save invoice/data/invoice.toml -f
    $company_info | to toml | save invoice/data/company_info.toml -f

    let company = $company_info.name | str replace --all --regex '[^\p{L}\p{N}_-]' '_'
    let id = $invoice_data.id | str replace --all --regex '[^\p{L}\p{N}_-]' '_'
    let pdf_name = $"Factuur_($company)_($id)_($invoice_data.date_posted | format date "%Y-%m-%d").pdf"

    mkdir out
    ^typst compile invoice/invoice.typ ('out' | path join $pdf_name)
    print $"Factuur is opgeslagen als ($pdf_name)"
