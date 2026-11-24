create or replace procedure it.PRT_GEN_ASI_ACRE_FIN is
begin
prt_gen_asi_sal_acreedor('C'); --Contabilizacion--
EXCEPTION
   WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'Error en PRT_GEN_ASI_ACRE_FIN-'||sqlerrm);
end PRT_GEN_ASI_ACRE_FIN;
/

