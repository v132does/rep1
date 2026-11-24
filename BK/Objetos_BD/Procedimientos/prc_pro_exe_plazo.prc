CREATE OR REPLACE PROCEDURE IT.PRC_PRO_EXE_PLAZO
 IS
V_FCDEHOY DATE;
V_IMDEBIT GE_MOVIMIENTOS.VAL_TASA%TYPE;
CURSOR cte IS
  select cc.cod_modulo   , cc.cod_modalidad, cc.cod_oficina,
         cc.nro_cuenta   , cc.tra_prohibida, cc.tas_personalizada,
         cc.aut_pendiente, cc.sal_total    , cc.cod_moneda,
         cc.sal_retenido , cc.sal_bloqueado, cc.rowid v_rowid
        from cc_cta_corrientes cc
       where cc.estado not in ('C','P','A','T','D','X')
         and cc.cod_modalidad = 41
         and exists
            (select '1'
              from cc_sobregiros ccs
             where ccs.nro_cuenta = cc.nro_cuenta
               and ccs.fecha  between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
               and v_fcdehoy);
r_cte cte%rowtype;
--
BEGIN
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;
    -- Se le pasa 'S' para que procese, este mismo procedimiento es
    -- utilizado para consultas
    v_imdebit := PAC_SOB.FU_PRO_EXE_PLAZO(r_cte.nro_cuenta, 'S');
  END LOOP;
  IF cte%ISOPEN THEN
     CLOSE cte;
  END IF;
EXCEPTION
  when no_data_found then
      raise_application_error(-20000,'No existen datos');
  WHEN OTHERS THEN
      raise_application_error(-20000,SQLERRM);
end;
/

