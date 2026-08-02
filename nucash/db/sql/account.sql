select
  a.guid,
  a.name,
  a.account_type,
  a.code,
  a.description,
  a.hidden,
  p.name as parent,
  coalesce(sum(s.value_num * 1.0 / s.value_denom), 0.0) as balance
from
  accounts a
  left join accounts p on p.guid = a.parent_guid
  left join splits s on s.account_guid = a.guid
group by
  a.guid,
  a.name,
  a.account_type,
  a.code,
  a.description,
  a.hidden,
  p.name
order by
  a.name
