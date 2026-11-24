BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
/
grant select on it.ge_con_tra_procesos to IT_TEMPORAL;
/
create or replace public synonym ge_con_tra_procesos for it.ge_con_tra_procesos;
/
commit;
/
