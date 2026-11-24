CREATE OR REPLACE PROCEDURE IT.PRB_FIN_EST_ANUAL
 IS
BEGIN
   UPDATE ba_modulos
      set estado = 4
    where cod_modulo = 2;
   if sql%notfound then
      raise_application_error(-20000,'Act. Modulo Contable a cerrado');
   end if;
   pag_cal.PR_OBT_DAT_CALENDAR(2);
   update ge_calendarios
      set fec_proxima = fec_actual + 1,
          ult_dia_mes_habil = pag_cal.G_ULT_DIA_MES,
          ult_dia_hab_trimestre = pag_cal.G_ULT_DIA_MES
    where cod_modulo in (2);
END;
/

