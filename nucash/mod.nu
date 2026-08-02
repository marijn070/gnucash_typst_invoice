use ./db/company.nu get-company-info
use ./db/invoice.nu get-invoices
use ./db/account.nu get-accounts
use ./utils.nu get-date
use ./utils.nu get-db-file

export def account [] {
    help nucash account
}

export def "account list" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --hidden,            # Show hidden accounts
] {
    let $db = open (get-db-file $file)
    let accounts = $db | get-accounts $db

    let accounts = if $hidden {
        $accounts
    } else {
        $accounts
        | where hidden == 0
    }

    $accounts | select code name balance
}

export def invoice [] {
    help nucash invoice
}

# List invoices
export def "invoice list" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --details,              # show full invoice details
] {
    let $db = open (get-db-file $file)
    let invoices = $db | get-invoices $db
    if $details {
        $invoices
    } else {
        $invoices | select id date_opened customer.name subtotal total | rename --column { customer.name: customer_name }
    }
}

# Get invoice by ID
#
# Returns the invoice with the given ID.
export def "invoice get" [
    --file (-f): path,   # Path to your gnucash sqlite file
    id: string
] {
    let $db = open (get-db-file $file)
    get-invoices $db | where id == $id | first
}

# Get the latest invoice
#
# Returns the most recently posted invoice.
export def "invoice latest" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open (get-db-file $file)
    let invoices = get-invoices $db | sort-by date_opened --reverse
    $invoices | first
}

# Pick an invoice interactively
export def "invoice pick" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open (get-db-file $file)
    let id = invoice list | input list --fuzzy | get id
    get-invoices $db | where id == $id
}

export def "company-info" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open (get-db-file $file)
    $db | get-company-info $db
}

export def date-only []: string -> string {
    $in | str replace -a -r 'T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([+-][0-9]{2}:[0-9]{2}|Z)' ''
}
