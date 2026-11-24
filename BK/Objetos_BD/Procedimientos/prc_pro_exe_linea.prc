CREATE OR REPLACE PROCEDURE IT.PRC_PRO_EXE_LINEA
 IS
V_FCDEHOY DATE;
V_IMDEBIT GE_MOVIMIENTOS.VAL_TASA%TYPE;
cursor cte is
  select cc.cod_modulo   , cc.cod_modalidad, cc.cod_oficina,
         cc.nro_cuenta   , cc.tra_prohibida, cc.tas_personalizada,
         cc.aut_pendiente, cc.sal_total    , cc.cod_moneda,
         cc.sal_retenido , cc.sal_bloqueado, cc.rowid ww_rowid,
         count(ccs.fecha) cantidad
    from cc_cta_corrientes cc ,
         cc_sobregiros ccs
   where cc.nro_cuenta = ccs.nro_cuenta
     and cc.estado not in ('C','P','A','T','D','X')
     and ccs.fecha between to_date('01'||to_char(v_fcdehoy, 'MMYYYY'),'DDMMYYYY')
     and trunc(v_fcdehoy)
     and not exists (select '1'
                      from cc_lin_sobregiros cls
                     where cls.nro_cuenta = ccs.nro_cuenta
                       and ccs.fecha between cls.fec_inicio and cls.fec_vencimiento
                       and cls.estado = 'A'
                  group by cls.nro_cuenta
                     having ccs.saldo <= sum(cls.monto))
group by ccs.nro_cuenta  ,
         cc.cod_modulo   , cc.cod_modalidad, cc.cod_oficina,
         cc.nro_cuenta   , cc.tra_prohibida, cc.tas_personalizada,
         cc.aut_pendiente, cc.sal_total    , cc.cod_moneda,
         cc.sal_retenido , cc.sal_bloqueado, cc.rowid;
r_cte cte%rowtype;
BEGIN
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;
    -- Se le pasa 'S' para que procese, este mismo procedimiento es
    -- utilizado para consultas
    v_imdebit := PAC_SOB.FU_PRO_EXE_LINEA(r_cte.nro_cuenta, 'S');
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

