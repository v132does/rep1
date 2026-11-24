CREATE OR REPLACE PROCEDURE IT.PRB_FIN_EST_MODULO
 IS
BEGIN
   UPDATE ba_modulos
      set estado = 4
    where cod_modulo in (2); --agregado 13-AF, -- 3-11-2010 VC se hace por separado 13 se hace con otros módulos en esta implementación
   if sql%notfound then
      raise_application_error(-20000,'Act. Modulo Contable a cerrado');
   end if;
   pag_cal.PR_OBT_DAT_CALENDAR(2);
   /* Para el Cierre Anual: Se considera que siempre el 31/12 va a ser
      el último día contable */
   if upper(pag_cal.G_NOM_MES) in ('DICIEMBRE','DECEMBER') then
      if pag_cal.G_FEC_ACTUAL = pag_cal.G_ULT_DIA_MES_HABIL
      and pag_cal.G_FEC_PROXIMA <> pag_cal.G_ULT_DIA_MES then
         if pag_cal.G_FEC_ACTUAL < pag_cal.G_ULT_DIA_MES then
            update ge_calendarios
               set fec_proxima = pag_cal.G_ULT_DIA_MES,
                   ult_dia_mes_habil = pag_cal.G_ULT_DIA_MES,
                   ult_dia_hab_trimestre = pag_cal.G_ULT_DIA_MES
             where cod_modulo in (2);
         end if;
      end if;
   end if;
   -- Inicializo procesos de inicio de dia contable
   prb_ini_pro_contab(310);
END;
/

