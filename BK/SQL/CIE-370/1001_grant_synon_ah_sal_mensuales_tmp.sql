--SYNONYM
create or replace public synonym ah_sal_mensuales_tmp for it.ah_sal_mensuales_tmp;
--GRANT
grant select, insert, update, delete on it.ah_sal_mensuales_tmp to it_temporal;
