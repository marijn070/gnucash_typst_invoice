use ../utils.nu get-date

const SQL_DIR = path self | path dirname

export def get-invoices [db] {
    let sql_file = $SQL_DIR | path join "sql/invoice.sql"
    let sql = open $sql_file

    let invoices = $db | query db $sql

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
