create or replace procedure it.prb_tra_sal_diario_cie is
  v_fec_actual date  := pag_cal.fu_obt_fec_actual(2);
  v_sql   varchar2(4000);
  v_error varchar2(4000);
  v_dia_semana varchar2(60);
  v_fec_proxima date;
BEGIN
   v_sql := 'truncate table it.ape_cb_sal_oficinas_dia';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar ape_cb_sal_oficinas_dia: '||v_error);
   end if;
   v_sql := 'truncate table it.ape_cb_sal_consolidados_dia';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar ape_cb_sal_consolidados_dia: '||v_error);
   end if;
  -- proceso para saldos mensuales por oficina --
  -----------------------------------------------
  INSERT INTO APE_CB_SAL_OFICINAS_DIA(cod_oficina,cod_rubro,fecha,
                                  sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
                                  sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
                                  sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
                                  cre_equ_local, sal_ini_mes_equ_local )
  SELECT cod_oficina,cod_rubro,v_fec_actual,
         sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
         sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
         sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
         cre_equ_local, sal_ini_mes_equ_local
    FROM APE_CB_SAL_OFICINAS
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  -- proceso para saldos mensuales consolidado --
  -----------------------------------------------
  INSERT INTO APE_CB_SAL_CONSOLIDADOS_DIA(cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local,
                                      cre_mon_local, sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro ,
                                      cre_mon_rubro, sal_ini_mes_mon_rubro, protegido, sal_equ_loc_ant,
                                      deb_equ_local, cre_equ_local, sal_ini_mes_equ_local )
  SELECT cod_rubro, v_fec_actual, sal_mon_loc_ant, deb_mon_local,
        cre_mon_local, sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro ,
        cre_mon_rubro, sal_ini_mes_mon_rubro, protegido, sal_equ_loc_ant,
        deb_equ_local, cre_equ_local, sal_ini_mes_equ_local
   FROM APE_CB_SAL_CONSOLIDADOS
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  --
  -- verificar si no hay que cambiar la fecha
   select lower(TRIM(to_char(v_fec_actual, 'DAY', 'NLS_DATE_LANGUAGE=SPANISH')))
     into v_dia_semana
     from dual;
   if v_dia_semana not in ('sabado','sábado','domingo') then
      v_sql := 'alter trigger TB_GE_CALENDARIOS disable';
      sql_util.ejecute_dml(v_sql,v_error);
      if v_error is not null then
         raise_application_error(-20000,'Al Desabilitar trigger de GE_CALENDARIOS: '||v_error);
      end if;

      v_fec_proxima := v_fec_actual;
      update ge_calendarios c
      set c.fec_proxima=v_fec_proxima
      where c.cod_modulo=2;

      v_sql := 'alter trigger TB_GE_CALENDARIOS enable';
      sql_util.ejecute_dml(v_sql,v_error);
      if v_error is not null then
         raise_application_error(-20000,'Al Habilitar trigger de GE_CALENDARIOS: '||v_error);
      end if;
   end if;
   ---  
exception
  when others then
    raise_application_error(-20000,' ERROR: Al Trasferir los saldos contables por dia'||sqlerrm);
END;
/

