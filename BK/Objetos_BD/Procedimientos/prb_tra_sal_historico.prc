create or replace procedure it.prb_tra_sal_historico is
/* Transferencia mensual de saldos al historico */
  v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
  v_ano_ant        number(4);
  v_mes_ant        number(2);
  v_valor          varchar2(1);
  -- para saldos mensuales por oficina --
  ---------------------------------------
  CURSOR HIST1 IS SELECT 'X'
               FROM   CB_SAL_OFICINAS_HIS
               WHERE  MES = v_mes_ant
               AND    ANO = v_ano_ant;
  -- para saldos mensuales consolidado --
  ---------------------------------------
  CURSOR HIST2 IS SELECT 'X'
               FROM   CB_SAL_CONSOLIDADOS_HIS
               WHERE  MES = v_mes_ant
               AND    ANO = v_ano_ant;
BEGIN
  -- proceso para saldos mensuales por oficina --
  -----------------------------------------------
  pag_cal.PR_OBT_DAT_CALENDAR(2);
  v_ano_ant := to_char(pag_cal.G_FEC_ANTERIOR,'yyyy');
  v_mes_ant := to_char(pag_cal.G_FEC_ANTERIOR,'mm');
  OPEN HIST1;
  FETCH HIST1 INTO v_valor;
  IF HIST1%FOUND THEN
     CLOSE HIST1;
     --RAISE_APPLICATION_ERROR(-20000,' ERROR. Ya existen Saldos en historico por Oficina ...');
     return;
  END IF;
  INSERT INTO CB_SAL_OFICINAS_HIS
  SELECT *
    FROM   CB_SAL_OFICINAS
   WHERE  MES = v_mes_ant
     AND  ANO = v_ano_ant;
  -- proceso para saldos mensuales consolidado --
  -----------------------------------------------
  OPEN HIST2;
  FETCH HIST2 INTO v_valor;
  IF HIST2%FOUND THEN
     CLOSE HIST2;
     --RAISE_APPLICATION_ERROR(-20000,' ERROR. Ya existen Saldos en Historico Consolidado ...');
     return;
  END IF;
  INSERT INTO CB_SAL_CONSOLIDADOS_HIS
  SELECT *
    FROM   CB_SAL_CONSOLIDADOS
   WHERE  MES = v_mes_ant
     AND  ANO = v_ano_ant;
END;
/

