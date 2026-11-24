create or replace procedure it.prb_tra_sal_historico_cie is
/* Transferencia mensual de saldos al historico */
  v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
  v_ano_ant        number(4);
  v_mes_ant        number(2);
  v_valor          varchar2(1);
  v_sql            varchar2(4000);
  v_error          varchar2(4000);
  -- para saldos mensuales por oficina --
  /*---------------------------------------
  CURSOR HIST1 IS SELECT 'X'
               FROM   CB_SAL_OFICINAS_HIS
               WHERE  MES = v_mes_ant
               AND    ANO = v_ano_ant;
  -- para saldos mensuales consolidado --
  ---------------------------------------
  CURSOR HIST2 IS SELECT 'X'
               FROM   CB_SAL_CONSOLIDADOS_HIS
               WHERE  MES = v_mes_ant
               AND    ANO = v_ano_ant;*/
BEGIN
  -- proceso para saldos mensuales por oficina --
  -----------------------------------------------
  pag_cal.PR_OBT_DAT_CALENDAR(2);
  v_ano_ant := to_char(pag_cal.G_FEC_ANTERIOR,'yyyy');
  v_mes_ant := to_char(pag_cal.G_FEC_ANTERIOR,'mm');
  
   v_sql := 'truncate table it.APE_CB_SAL_OFICINAS_HIS';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar APE_CB_SAL_OFICINAS_HIS: '||v_error);
   end if;
   
  INSERT INTO APE_CB_SAL_OFICINAS_HIS
  SELECT *
    FROM  CIE_CB_SAL_OFICINAS
   WHERE  MES = v_mes_ant
     AND  ANO = v_ano_ant;
  -- proceso para saldos mensuales consolidado --
  -----------------------------------------------
   v_sql := 'truncate table it.cie_cb_sal_consolidados_his';
   sql_util.ejecute_dml(v_sql,v_error);
   if v_error is not null then
      raise_application_error(-20000,'Al truncar ape_cb_sal_consolidados_his: '||v_error);
   end if;
      
  INSERT INTO APE_CB_SAL_CONSOLIDADOS_HIS
  SELECT *
    FROM  CIE_CB_SAL_CONSOLIDADOS
   WHERE  MES = v_mes_ant
     AND  ANO = v_ano_ant;
END;
/

