use ../utils.nu get-date

export def get-invoices [db] {
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
