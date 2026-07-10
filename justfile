# Generate PDF for the latest invoice
latest:
    #!/usr/bin/env nu
    use {{ justfile_dir() }}/nucash
    let id = nucash invoice get | get id
    just _compile $id

# Interactively pick an invoice and generate a PDF
pick:
    #!/usr/bin/env nu
    use {{ justfile_dir() }}/nucash
    let id = nucash invoice list | input list --fuzzy | get id
    just _compile $id

[private]
_compile id:
    #!/usr/bin/env nu
    use {{ justfile_dir() }}/nucash
    let invoice_data = nucash invoice get --id "{{ id }}"
    let company_info = nucash company info

    mkdir invoice/data
    $invoice_data | to toml | nucash date-only | save invoice/data/invoice.toml -f
    $company_info | to toml | save invoice/data/company_info.toml -f

    let pdf_name = $"Factuur_($company_info.name | str replace ' ' '_')_($invoice_data.id)_($invoice_data.date_posted | format date "%Y-%m-%d").pdf"

    mkdir out
    typst compile invoice/invoice.typ ('out' | path join $pdf_name)
    print $"Factuur is opgeslagen als ($pdf_name)"
