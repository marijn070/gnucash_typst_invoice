select
  i.guid,
  i.id,
  i.date_opened,
  i.date_posted,
  i.notes,
  c.name as customer_name,
  c.addr_addr1,
  c.addr_addr2,
  c.addr_addr3,
  c.addr_addr4,
  c.addr_phone,
  c.addr_email,
  e.date,
  e.description,
  e.action,
  e.quantity_num * 1.0 / e.quantity_denom as quantity,
  e.i_price_num * 1.0 / e.i_price_denom as unit_price,
  (e.quantity_num * 1.0 / e.quantity_denom) * (e.i_price_num * 1.0 / e.i_price_denom) as amount,
  s.value_num * 1.0 / s.value_denom as total
from
  invoices i
  join customers c on c.guid = i.owner_guid
  left join entries e on e.invoice = i.guid
  left join splits s on s.tx_guid = i.post_txn
    and s.account_guid = i.post_acc
  order by
    i.date_opened desc,
    e.date;

