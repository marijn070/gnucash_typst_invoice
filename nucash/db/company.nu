use ../utils.nu select-rows

export def get-company-info [db] {
    let rows = select-rows $db "SELECT obj_guid, name, string_val FROM slots WHERE string_val IS NOT NULL AND (name LIKE 'options/%' OR name = 'online_id')"
    let bank_guid = $env.GNC_BANK_ACCOUNT_GUID? | default ""
    let banks = $rows | where name == "online_id" | where {|row| $bank_guid == "" or $row.obj_guid == $bank_guid }
    let bank_account = $banks | get string_val | uniq
    if ($bank_account | length) != 1 or ($bank_account | first | str trim) == "" {
        error make {msg: "Could not identify a unique payment account. Set GNC_BANK_ACCOUNT_GUID and check its online_id."}
    }
    {
        name: (required-slot $rows "options/Business/Company Name")
        address: (required-slot $rows "options/Business/Company Address")
        contact_person: (required-slot $rows "options/Business/Company Contact Person")
        company_email: (required-slot $rows "options/Business/Company Email Address")
        phone_number: (required-slot $rows "options/Business/Company Phone Number")
        tax_number: (required-slot $rows "options/Tax/Tax Number")
        bank_account: ($bank_account | first)
        kvk: (required-slot $rows "options/Business/Company ID")
    }
}

def required-slot [rows, name: string] {
    let values = $rows | where name == $name | get string_val | uniq
    if ($values | length) != 1 {
        error make {msg: $"Missing or ambiguous company setting: ($name)"}
    }
    $values | first
}
