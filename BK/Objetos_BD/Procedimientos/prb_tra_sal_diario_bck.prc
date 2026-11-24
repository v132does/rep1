create or replace procedure it.prb_tra_sal_diario_bck is
  v_fec_actual date  := pag_cal.FU_OBT_FEC_ACTUAL(2); --to_date('01/12/2021','dd/mm/yyyy');
  w_cuantos    NUMBER;
BEGIN
  -- Proceso cierre ejercicio GNB Fusion
  -- Inicio ejercicio GNB py
  select count(*)
    into w_cuantos
    FROM CB_SAL_OFICINAS_DIA
   WHERE fecha = v_fec_actual;
  if nvl(w_cuantos,0) > 0 then
     DELETE CB_SAL_OFICINAS_DIA
      WHERE fecha = v_fec_actual;
  end if;
  -- proceso para saldos mensuales por oficina --
  -----------------------------------------------
  INSERT INTO CB_SAL_OFICINAS_DIA(cod_oficina,cod_rubro,fecha,
                                  sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
                                  sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
                                  sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
                                  cre_equ_local, sal_ini_mes_equ_local )
  SELECT cod_oficina,cod_rubro,v_fec_actual,
         sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
         sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
         sal_ini_mes_mon_fuerte, nvl(protegido,'N'), sal_equ_loc_ant, deb_equ_local,
         cre_equ_local, sal_ini_mes_equ_local
    FROM CB_SAL_OFICINAS_bck
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  -- Proceso cierre ejercicio GNB Fusion
  -- Inicio ejercicio GNB py
  select count(*)
    into w_cuantos
    FROM CB_SAL_CONSOLIDADOS_DIA
   WHERE fecha = v_fec_actual;
  if nvl(w_cuantos,0) > 0 then
     DELETE CB_SAL_CONSOLIDADOS_DIA
      WHERE fecha = v_fec_actual;
  end if;
  -- proceso para saldos mensuales consolidado --
  -----------------------------------------------
  INSERT INTO CB_SAL_CONSOLIDADOS_DIA(cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local,
                                      cre_mon_local, sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro ,
                                      cre_mon_rubro, sal_ini_mes_mon_rubro, protegido, sal_equ_loc_ant,
                                      deb_equ_local, cre_equ_local, sal_ini_mes_equ_local )
  SELECT cod_rubro, v_fec_actual, sal_mon_loc_ant, deb_mon_local,
        cre_mon_local, sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro ,
        cre_mon_rubro, sal_ini_mes_mon_rubro, nvl(protegido,'N'), sal_equ_loc_ant,
        deb_equ_local, cre_equ_local, sal_ini_mes_equ_local
   FROM CB_SAL_CONSOLIDADOS_bck
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
     
     
  ----
  --- Para igualar balances cerrados
  ---
  select count(*)
    into w_cuantos
    FROM CB_SAL_OFICINAS
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  if nvl(w_cuantos,0) > 0 then
     DELETE CB_SAL_OFICINAS
      WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
        AND MES = TO_CHAR(v_fec_actual,'MM');
  end if;
  INSERT INTO CB_SAL_OFICINAS(cod_oficina,cod_rubro,ano,mes,
                              sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
                              sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
                              sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
                              cre_equ_local, sal_ini_mes_equ_local )
  SELECT cod_oficina,cod_rubro,ano, mes,
         sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
         sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
         sal_ini_mes_mon_fuerte, nvl(protegido,'N'), sal_equ_loc_ant, deb_equ_local,
         cre_equ_local, sal_ini_mes_equ_local
    FROM CB_SAL_OFICINAS_bck
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  -- Proceso cierre ejercicio GNB Fusion
  -- Inicio ejercicio GNB py
  select count(*)
    into w_cuantos
    FROM CB_SAL_CONSOLIDADOS
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  if nvl(w_cuantos,0) > 0 then
     DELETE CB_SAL_CONSOLIDADOS
      WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
        AND MES = TO_CHAR(v_fec_actual,'MM');
  end if;
  -- proceso para saldos mensuales consolidado --
  -----------------------------------------------
  INSERT INTO CB_SAL_CONSOLIDADOS(cod_rubro, ano, mes, sal_mon_loc_ant, deb_mon_local,
                                  cre_mon_local, sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro ,
                                  cre_mon_rubro, sal_ini_mes_mon_rubro, protegido, sal_equ_loc_ant,
                                  deb_equ_local, cre_equ_local, sal_ini_mes_equ_local )
  SELECT cod_rubro, ano, mes, sal_mon_loc_ant, deb_mon_local,
         cre_mon_local, sal_ini_mes_mon_local, sal_mon_rub_ant, deb_mon_rubro ,
         cre_mon_rubro, sal_ini_mes_mon_rubro, nvl(protegido,'N'), sal_equ_loc_ant,
         deb_equ_local, cre_equ_local, sal_ini_mes_equ_local
   FROM CB_SAL_CONSOLIDADOS_bck
   WHERE ANO = TO_CHAR(v_fec_actual,'YYYY')
     AND MES = TO_CHAR(v_fec_actual,'MM');
  
  
exception
  when others then
    raise_application_error(-20000,' ERROR: Al Trasferir los saldos contables por dia'||sqlerrm);
END;
/

