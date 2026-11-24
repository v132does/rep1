create or replace procedure it.prb_ini_cie_ejercicio is
   v_sql   varchar2(4000);
   v_error varchar2(4000);
   v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(2);
   v_fec_proxima date;
   v_dia_semana varchar2(60);
begin
   -- copia del proceso 350-INICIO DE EJERCICIO
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   select lower(TRIM(to_char(v_fec_actual, 'DAY', 'NLS_DATE_LANGUAGE=SPANISH')))
     into v_dia_semana
     from dual;
   /*if v_dia_semana in ('sabado','sábado','domingo') then
      v_sql := 'alter trigger TB_GE_CALENDARIOS disable';
      sql_util.ejecute_dml(v_sql,v_error);
      if v_error is not null then
         raise_application_error(-20000,'Al Desabilitar trigger de GE_CALENDARIOS: '||v_error);
      end if;

      v_fec_proxima := v_fec_actual + 1;
      update ge_calendarios c
      set c.fec_proxima=v_fec_proxima\*,
          c.ult_dia_mes_habil=v_fec_proxima,
          c.ult_dia_hab_trimestre=v_fec_proxima*\
      where c.cod_modulo=2;

      v_sql := 'alter trigger TB_GE_CALENDARIOS enable';
      sql_util.ejecute_dml(v_sql,v_error);
      if v_error is not null then
         raise_application_error(-20000,'Al Habilitar trigger de GE_CALENDARIOS: '||v_error);
      end if;
   end if;*/

   /*
   || Ejecutar los procesos e insertar en otras tablas
   */

   v_sql := 'truncate table it.ape_cb_sal_consolidados';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar ape_cb_sal_consolidados: '||v_error);
   end if;
   v_sql := 'truncate table it.ape_cb_sal_oficinas';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar ape_cb_sal_oficinas: '||v_error);
   end if;
   v_sql := 'truncate table it.ape_cb_rub_oficinas';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar ape_cb_rub_oficinas: '||v_error);
   end if;

end;
/

