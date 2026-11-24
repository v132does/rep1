BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
/
GRANT EXECUTE ON it.typ_ge_par_dinamicos to IT_TEMPORAL;
create or replace public synonym typ_ge_par_dinamicos for it.typ_ge_par_dinamicos;

GRANT EXECUTE ON it.typ_ge_par_dinamicos_tab to IT_TEMPORAL;
create or replace public synonym typ_ge_par_dinamicos_tab for it.typ_ge_par_dinamicos_tab;

commit;
