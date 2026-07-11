use ./db/company.nu get-company-info
use ./db/invoice.nu get-invoices
use ./utils.nu get-date
use ./utils.nu get-db-file


export def invoice [] {
    invoice list
}

# List invoices
export def "invoice list" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --full,              # show full invoice details
] {
    let $db = open (get-db-file $file)
    let invoices = $db | get-invoices $db
    if $full {
        $invoices
    } else {
        $invoices | select id date_opened customer.name subtotal total
    }
}

# Get invoice by ID
#
# Returns the invoice with the given ID, or the last invoice if no ID is specified.
export def "invoice get" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --id: string
] {
    let $db = open (get-db-file $file)
    let invoices = $db | get-invoices $db

    if $id != null {
        $invoices | where id == $id | first
    } else {
        $invoices | first
    }
}

export def "company info" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open (get-db-file $file)
    $db | get-company-info $db
}

export def date-only []: string -> string {
    $in | str replace -a -r 'T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([+-][0-9]{2}:[0-9]{2}|Z)' ''
}
