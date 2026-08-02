const SQL_DIR = path self | path dirname

export def get-accounts [db] {
    let sql_file = $SQL_DIR | path join "sql/account.sql"
    let sql = open $sql_file

    let accounts = $db | query db $sql

    $accounts
}
