export def get-company-info [db] {
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
