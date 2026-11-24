BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
/
GRANT EXECUTE ON it.typ_cta_garantia to IT_TEMPORAL;
create or replace public synonym typ_cta_garantia for it.typ_cta_garantia;

GRANT EXECUTE ON it.typ_cta_garantia_tab to IT_TEMPORAL;
create or replace public synonym typ_cta_garantia_tab for it.typ_cta_garantia_tab;

commit;
