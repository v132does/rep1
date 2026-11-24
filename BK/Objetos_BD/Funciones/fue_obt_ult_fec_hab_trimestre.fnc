CREATE OR REPLACE FUNCTION IT.FUE_OBT_ULT_FEC_HAB_TRIMESTRE
  (P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE)

  return date is
  v_fec_ult_dia_hab_trimestre date;

begin
   pag_cal.PR_OBT_DAT_CALENDAR(P_COD_MODULO);
   v_fec_ult_dia_hab_trimestre := pag_cal.G_ULT_DIA_HAB_TRIMESTRE;

   return(v_fec_ult_dia_hab_trimestre);
exception
  when others then
     raise_application_error(-20000,'FUE_OBT_ULT_FEC_HAB_TRIMESTRE '||sqlerrm);
end FUE_OBT_ULT_FEC_HAB_TRIMESTRE;
/

