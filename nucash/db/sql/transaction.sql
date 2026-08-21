select
  t.guid,
  t.num,
  t.post_date,
  t.enter_date,
  t.description,
  s.guid as split_guid,
  a.guid as account_guid,
  a.name as account_name,
  a.code as account_code,
  s.memo,
  s.action,
  s.reconcile_state,
  s.value_num * 1.0 / s.value_denom as amount
from
  transactions t
  join splits s on s.tx_guid = t.guid
  join accounts a on a.guid = s.account_guid
order by
  t.post_date desc,
  t.guid,
  s.guid;

