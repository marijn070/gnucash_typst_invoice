# Invoice management
#
# You must use one of the subcommands below.
export def "invoice" [] {
    print "Use --help for more details."
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

def get-db-file [file?: path] {
    if $file != null {
        $file
    } else if "GNC_FILE" in $env {
        $env.GNC_FILE
    } else {
        error make {msg: "No GnuCach File specified.", help: "Set $env.GNC_FILE or pas --file <path>."}
    }
}

def get-date [] {
    if $in == null {
        null
    } else {
        $in | into datetime #| date to-timezone UTC | format date "%Y-%m-%d" | into datetime
    }
}

def get-invoices [db] {
    let invoices = $db | query db "
            SELECT
                i.guid,
                i.id,
                i.date_opened,
                i.date_posted,
                i.notes,

                c.name AS customer_name,
                c.addr_addr1,
                c.addr_addr2,
                c.addr_addr3,
                c.addr_addr4,
                c.addr_phone,
                c.addr_email,

                e.date,
                e.description,
                e.action,

                e.quantity_num * 1.0 / e.quantity_denom AS quantity,
                e.i_price_num * 1.0 / e.i_price_denom AS unit_price,

                (e.quantity_num * 1.0 / e.quantity_denom)
                * (e.i_price_num * 1.0 / e.i_price_denom) AS amount,

                s.value_num * 1.0 / s.value_denom AS total
            FROM invoices i
            JOIN customers c
                ON c.guid = i.owner_guid
            LEFT JOIN entries e
                ON e.invoice = i.guid
            LEFT JOIN splits s
                ON s.tx_guid = i.post_txn
               AND s.account_guid = i.post_acc
            ORDER BY i.date_opened DESC, e.date;
        "

    $invoices
    | group-by guid
    | transpose guid rows
    | each {|invoice|

    let rows = $invoice.rows
    let first = $rows | first

    {
        id: $first.id
        date_opened: ($first.date_opened | get-date)
        date_posted: ($first.date_posted | get-date)
        notes: $first.notes

        customer: {
            name: $first.customer_name
            address: [
                $first.addr_addr1
                $first.addr_addr2
                $first.addr_addr3
                $first.addr_addr4
            ]
            phone: $first.addr_phone
            email: $first.addr_email
        }

        entries: (
            $rows
            | select date description action quantity unit_price amount
            | update date {get-date}
        )

        subtotal: (if ($rows | is-empty) or ($first.total == null) { null } else { $rows | get amount | math sum })
        total: $first.total
        tax: (if ($rows | is-empty) or ($first.total == null) { null } else { ($first.total - ($rows | get amount | math sum)) | math round --precision 2 })
    }
}
}

def get-company-info [db] {
    let company_name = $db.slots | where name == "options/Business/Company Name" | get string_val | first
    let company_address = $db.slots | where name == "options/Business/Company Address" | get string_val | first
    let contact_person = $db.slots | where name == "options/Business/Company Contact Person" | get string_val | first
    let copmany_email = $db.slots | where name == "options/Business/Company Email Address" | get string_val | first
    let phone_number = $db.slots | where name == "options/Business/Company Phone Number" | get string_val | first
    let kvk = $db.slots | where name == "options/Business/Company ID" | get string_val | first
    let tax_number = $db.slots | where name == "options/Tax/Tax Number" | get string_val | first
    let bank_account = $db.slots | where name == "online_id" | get string_val | first
    {
        name: $company_name
        address: $company_address
        contact_person: $contact_person
        copmany_email: $copmany_email
        phone_number: $phone_number
        tax_number: $tax_number
        bank_account: $bank_account
        kvk: $kvk
    }
}
