use ./db/company.nu get-company-info
use ./db/invoice.nu get-invoices
use ./db/account.nu get-accounts
use ./db/transaction.nu get-transactions
use ./utils.nu get-date
use ./utils.nu open-db

# Manage accounts
export def account [] {
    help nucash account
}

# List accounts
export def "account list" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --hidden,            # Show hidden accounts
    --details,           # Show account details
] {
    let $db = open-db $file
    let accounts = $db | get-accounts $db

    let accounts = if $hidden {
        $accounts
    } else {
        $accounts
        | where hidden == 0
    }

    if $details {
        $accounts
    } else {
        $accounts | select code name balance
    }
}

# Get account by code
#
# Returns the account with the given code.
export def "account get" [
    --file (-f): path,   # Path to your gnucash sqlite file
    code: string
] {
    let $db = open-db $file
    let matches = $db | get-accounts $db | where code == $code
    if ($matches | is-empty) {
        error make {msg: $"No account found with code ($code)"}
    }
    if ($matches | length) > 1 {
        error make {msg: $"Multiple accounts found with code ($code); use 'account pick' instead"}
    }
    $matches | first
}

# Pick an account interactively
export def "account pick" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --hidden,            # Include hidden accounts
] {
    let $db = open-db $file
    let picked = (account list --file $file --hidden=$hidden) | input list --fuzzy
    if $picked == null {
        error make {msg: "No account selected"}
    }
    $db | get-accounts $db | where name == $picked.name and code == $picked.code | first
}

# Show the transaction register for this account
export def "account transactions" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --details,           # Show full transaction details (all splits)
    code: string         # Account code
] {
    transaction list --file $file --account $code --details=$details
}

# Manage invoices
export def invoice [] {
    help nucash invoice
}

# List invoices
export def "invoice list" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --details,              # show full invoice details
] {
    let $db = open-db $file
    let invoices = $db | get-invoices $db
    if $details {
        $invoices
    } else {
        $invoices
        | select id date_opened customer.name subtotal total
        | rename --column { customer.name: customer_name }
        | update date_opened { format date "%Y-%m-%d" }
    }
}

# Get invoice by ID
#
# Returns the invoice with the given ID.
export def "invoice get" [
    --file (-f): path,   # Path to your gnucash sqlite file
    id: string
] {
    let $db = open-db $file
    let matches = get-invoices $db | where id == $id
    if ($matches | is-empty) {
        error make {msg: $"No invoice found with id ($id)"}
    }
    $matches | first
}

# Get the latest invoice
#
# Returns the most recently posted invoice.
export def "invoice latest" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open-db $file
    let invoices = get-invoices $db | sort-by date_opened --reverse
    if ($invoices | is-empty) {
        error make {msg: "No invoices found"}
    }
    $invoices | first
}

# Pick an invoice interactively
export def "invoice pick" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open-db $file
    let picked = invoice list --file $file | input list --fuzzy
    if $picked == null {
        error make {msg: "No invoice selected"}
    }
    get-invoices $db | where id == $picked.id | first
}

# Manage transactions
export def transaction [] {
    help nucash transaction
}

# List transactions
#
# By default, shows a brief overview of all transactions.
# Use --account to see a register-style view for a single account,
# including the running balance and the other account(s) involved.
export def "transaction list" [
    --file (-f): path,     # Path to your gnucash sqlite file
    --account: string,     # Filter to transactions touching this account code
    --details,             # Show full transaction details (all splits)
] {
    let $db = open-db $file
    let transactions = get-transactions $db

    if $account != null {
        let filtered = $transactions | where {|tx| $tx.splits | any {|s| $s.account_code == $account} }
        if ($filtered | is-empty) {
            error make {msg: $"No transactions found for account code ($account)"}
        }

        $filtered
        | sort-by date_posted
        | reduce -f {balance: 0, rows: []} {|tx, acc|
            let split = $tx.splits | where account_code == $account | first
            let others = $tx.splits | where account_code != $account | get account_name | str join ", "
            let balance = $acc.balance + $split.amount
            {
                balance: $balance
                rows: ($acc.rows | append {
                    id: ($tx.guid | str substring 0..8)
                    date: ($tx.date_posted | format date "%Y-%m-%d")
                    description: $tx.description
                    account: $others
                    amount: $split.amount
                    balance: $balance
                })
            }
        }
        | get rows
        | reverse
    } else if $details {
        $transactions
    } else {
        $transactions
        | each {|tx| {
            id: ($tx.guid | str substring 0..8)
            date: ($tx.date_posted | format date "%Y-%m-%d")
            description: $tx.description
            num: $tx.num
            accounts: ($tx.splits | get account_name | str join ", ")
        }}
    }
}

# Get transaction by id
#
# `id` may be a prefix of the transaction's guid (similar to a short git hash).
export def "transaction get" [
    --file (-f): path,   # Path to your gnucash sqlite file
    id: string
] {
    let $db = open-db $file
    let matches = get-transactions $db | where {|tx| $tx.guid | str starts-with $id}
    if ($matches | is-empty) {
        error make {msg: $"No transaction found with id ($id)"}
    }
    if ($matches | length) > 1 {
        error make {msg: $"Multiple transactions match id ($id); use a longer id"}
    }
    $matches | first
}

# Pick a transaction interactively
export def "transaction pick" [
    --file (-f): path,   # Path to your gnucash sqlite file
    --account: string,   # Filter to transactions touching this account code
] {
    let picked = (transaction list --file $file --account $account) | input list --fuzzy
    if $picked == null {
        error make {msg: "No transaction selected"}
    }
    transaction get --file $file $picked.id
}

# Show company info stored in the GnuCash file
export def "company-info" [
    --file (-f): path,   # Path to your gnucash sqlite file
] {
    let $db = open-db $file
    $db | get-company-info $db
}

export def date-only []: string -> string {
    $in | str replace -a -r 'T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([+-][0-9]{2}:[0-9]{2}|Z)' ''
}
