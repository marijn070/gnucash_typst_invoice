use ../utils.nu get-date

const SQL_DIR = path self | path dirname

export def get-transactions [db] {
    let sql_file = $SQL_DIR | path join "sql/transaction.sql"
    let sql = open $sql_file

    let rows = $db | query db $sql

    $rows
    | group-by guid
    | transpose guid rows
    | each {|tx|

    let rows = $tx.rows
    let first = $rows | first

    {
        guid: $first.guid
        num: $first.num
        date_posted: ($first.post_date | get-date)
        date_entered: ($first.enter_date | get-date)
        description: $first.description

        splits: (
            $rows
            | select account_guid account_name account_code memo action reconcile_state amount
        )
    }
}
| sort-by date_posted --reverse
}
