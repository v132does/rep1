create or replace procedure it.PRT_GEN_ASI_ACRE_INI is
v_fec_actual date := pag_cal.fu_obt_fec_actual(5);
begin
pag_cal.PR_OBT_DAT_CALENDAR(5);
if v_fec_actual = pag_cal.G_PRI_DIA_MES_HABIL then
   prt_gen_asi_sal_acreedor('R'); --Reversion de la Contabilizacion--
end if;
EXCEPTION
   WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20000,'Error en PRT_GEN_ASI_ACRE_INI-'||sqlerrm);
end PRT_GEN_ASI_ACRE_INI;
/

