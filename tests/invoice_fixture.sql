CREATE TABLE accounts (guid text PRIMARY KEY, name text, account_type text, code text, description text, hidden integer, parent_guid text);
CREATE TABLE transactions (guid text PRIMARY KEY, num text, post_date timestamp, enter_date timestamp, description text);
CREATE TABLE splits (guid text PRIMARY KEY, tx_guid text, account_guid text, value_num bigint, value_denom bigint, memo text, action text, reconcile_state text);
CREATE TABLE invoices (guid text PRIMARY KEY, id text, date_opened timestamp, date_posted timestamp, notes text, owner_guid text, post_txn text, post_acc text);
CREATE TABLE customers (guid text PRIMARY KEY, name text, addr_addr1 text, addr_addr2 text, addr_addr3 text, addr_addr4 text, addr_phone text, addr_email text);
CREATE TABLE entries (invoice text, date timestamp, description text, action text, quantity_num bigint, quantity_denom bigint, i_price_num bigint, i_price_denom bigint);
CREATE TABLE slots (obj_guid text, name text, string_val text);
INSERT INTO accounts VALUES ('ar','Receivable','RECEIVABLE','1200','',0,NULL), ('sales','Sales and VAT','INCOME','8000','',0,NULL);
INSERT INTO transactions VALUES ('txn','101','2026-11-12 00:00:00','2026-11-12 00:00:00','Posted invoice');
INSERT INTO splits VALUES ('a','txn','ar',10900,100,'','','n'), ('b','txn','sales',-10900,100,'','','n');
INSERT INTO invoices VALUES ('inv','101','2026-11-12 00:00:00','2026-11-12 00:00:00','','cust','txn','ar');
INSERT INTO customers VALUES ('cust','Fixture Customer','12 Example Street','1234 AB Example','','','','');
INSERT INTO entries VALUES ('inv','2026-11-12 00:00:00','Work "quoted"; test','Hours',3,2,200,3);
INSERT INTO slots VALUES
 ('book','options/Business/Company Name','Fixture Company'),
 ('book','options/Business/Company Address','1 Example Street'),
 ('book','options/Business/Company Contact Person','Fixture Contact'),
 ('book','options/Business/Company Email Address','example@example.com'),
 ('book','options/Business/Company Phone Number','0101234567'),
 ('book','options/Business/Company ID','12345678'),
 ('book','options/Tax/Tax Number','NL000000000B01'),
 ('bank','online_id','NL91ABNA0417164300');
