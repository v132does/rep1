create or replace procedure it.prb_act_fec_cie_eje is
   v_sql   varchar2(4000);
   v_error varchar2(4000);
   v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(2);
   v_fec_proxima date;
   v_dia_semana varchar2(60);
   /* Transferencia mensual de saldos al historico */
   v_ano_ant number(4);
   v_mes_ant number(2);
   v_valor   varchar2(1);
   -- para saldos mensuales por oficina --
   ---------------------------------------
   CURSOR HIST1 IS
   SELECT 'X'
     FROM CB_SAL_OFICINAS_HIS
    WHERE MES = v_mes_ant
      AND ANO = v_ano_ant;
   -- para saldos mensuales consolidado --
   ---------------------------------------
   CURSOR HIST2 IS
   SELECT 'X'
     FROM CB_SAL_CONSOLIDADOS_HIS
    WHERE MES = v_mes_ant
      AND ANO = v_ano_ant;
begin
   -- copia del proceso 340-CIERRE DE EJERCICIO
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   select lower(TRIM(to_char(v_fec_actual, 'DAY', 'NLS_DATE_LANGUAGE=SPANISH')))
     into v_dia_semana
     from dual;
   if v_dia_semana = 'viernes' or
      v_fec_actual = to_date('28/02/2022','dd/mm/yyyy') then
      v_sql := 'alter trigger TB_GE_CALENDARIOS disable';
      sql_util.ejecute_dml(v_sql,v_error);
      if v_error is not null then
         raise_application_error(-20000,'Al Desabilitar trigger de GE_CALENDARIOS: '||v_error);
      end if;

      v_fec_proxima := v_fec_actual + 1;
      update ge_calendarios c
      set c.fec_proxima=v_fec_proxima/*,
          c.ult_dia_mes_habil=v_fec_proxima,
          c.ult_dia_hab_trimestre=v_fec_proxima*/
      where c.cod_modulo=2;

      v_sql := 'alter trigger TB_GE_CALENDARIOS enable';
      sql_util.ejecute_dml(v_sql,v_error);
      if v_error is not null then
         raise_application_error(-20000,'Al Habilitar trigger de GE_CALENDARIOS: '||v_error);
      end if;
   end if;
   --- copia del prb_tra_sal_historico
   --- proceso para saldos mensuales por oficina ---
   -------------------------------------------------
   v_ano_ant := to_char(v_fec_actual,'yyyy');
   v_mes_ant := to_char(v_fec_actual,'mm');
   OPEN HIST1;
   FETCH HIST1 INTO v_valor;
   IF HIST1%FOUND THEN
      CLOSE HIST1;
      RAISE_APPLICATION_ERROR(-20000,' ERROR. Ya existen Saldos en historico por Oficina ...');
   END IF;
   INSERT INTO CB_SAL_OFICINAS_HIS
   SELECT *
     FROM CB_SAL_OFICINAS
    WHERE MES = v_mes_ant
      AND ANO = v_ano_ant;
   --- proceso para saldos mensuales consolidado ---
   -------------------------------------------------
   OPEN HIST2;
   FETCH HIST2 INTO v_valor;
   IF HIST2%FOUND THEN
      CLOSE HIST2;
      RAISE_APPLICATION_ERROR(-20000,' ERROR. Ya existen Saldos en Historico Consolidado ...');
   END IF;
   INSERT INTO CB_SAL_CONSOLIDADOS_HIS
   SELECT *
     FROM CB_SAL_CONSOLIDADOS
    WHERE MES = v_mes_ant
      AND ANO = v_ano_ant;
      
   /*
   || También el parámetro que registra la fecha del último día del cierre contable hábil
   || del año para la generación del Inventario de Resultado de Depósitos Internos y Trading.
   || Formato:DD/MM/YYYY'
   */

   update ge_par_dinamicos a
      set a.val_parametro = v_fec_actual
    where a.parametro = 'CBN_FEC_ULT_DIA_CIE_ANUAL';

   update ge_par_dinamicos a
      set a.val_parametro = v_fec_actual
    where a.parametro = 'CBN_FEC_ULT_DIA_INV_ANUAL';
end;
/

