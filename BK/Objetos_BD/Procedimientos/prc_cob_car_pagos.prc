create or replace procedure it.prc_cob_car_pagos(
   P_NRO_CUENTA       in GE_CUENTAS.NRO_CUENTA%TYPE
  ,P_COD_TAS_CARGO    in GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_CARGO    in GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_CARGO        in GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRA_IMPUESTO in GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_COD_TAS_IMPUESTO in GE_MOVIMIENTOS.COD_TASA%TYPE
  ,P_VAL_TAS_IMPUESTO in GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_VAL_IMPUESTO     in GE_MOVIMIENTOS.VAL_TASA%TYPE
  ,P_COD_TRANSACCION  in GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
  ,P_FECHA            IN  GE_MOVIMIENTOS.FECHA%TYPE
  ,P_HORA             IN OUT GE_MOVIMIENTOS.HORA%TYPE
  ,P_NRO_sECUENCIA    IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE)
  is
  v_cargos            number(18,2);
  v_nvo_estado        varchar2(1);
  v_sal_disponible    number;
  v_procesa           varchar2(1);
  v_hora              ge_movimientos.hora%type := p_hora;
  v_nro_Secuencia     ge_movimientos.nro_secuencia%type := p_nro_Secuencia;
  v_fcproxi           DATE;
  rv_gcale            GE_CALENDARIOS%ROWTYPE;  
  
---------------------------------------------------
--   PROCESOS AUXILIARES
----------------------------------------------------       
PROCEDURE LP_ACT_SAL_MENSUAL (P_TOTAL IN NUMBER,
                              P_CDMODUL IN NUMBER,
                              P_CDMODAL IN NUMBER,
                              P_CDOFICI IN NUMBER,
                              P_NRCUENT IN VARCHAR2)IS
V_DIAS    NUMBER(2,0);
v_minpa   cc_cta_corrientes.sal_total%type;
v_acsaldi cc_cta_corrientes.sal_total%type;
v_salinic cc_cta_corrientes.sal_total%type;
v_ctdiast NUMBER(7);
v_atransf cc_cta_corrientes.sal_total%type;
v_ctacomb varchar2(1);
BEGIN
  select nvl(cc.sal_total, 0) - nvl(cc.sal_retenido, 0),
         decode(nro_cta_cte,'',0, nvl(cco.sal_minimo, FUG_OBT_SAL_MIN_TRASPASO(nro_cta_cte))), 
         nvl(cc.cta_combinada, 'N')
    into v_salinic, v_atransf, v_ctacomb
    from cc_cta_combinadas cco,
         cc_cta_corrientes cc
   where cco.nro_cta_cte(+) = cc.nro_cuenta
     and cc.cod_modulo    = p_cdmodul
     and cc.cod_modalidad = p_cdmodal
     and cc.cod_oficina   = p_cdofici
     and cc.nro_cuenta    = p_nrcuent;
  If v_ctacomb = 'S' and v_salinic >  v_atransf Then
    v_salinic := v_atransf;
  End If;
  UPDATE cc_sal_mensuales
     SET sal_ini_mes = nvl(v_salinic, 0)
   WHERE cod_modulo    = p_cdmodul
     AND cod_modalidad = p_cdmodal
     AND cod_oficina   = p_cdofici
     AND nro_cuenta    = p_nrcuent
     AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
     AND mes           = to_number(to_char(v_fcproxi,'MM'));
  IF p_fecha + 1 <> v_fcproxi THEN
     V_DIAS := TO_NUMBER(TO_CHAR(v_fcproxi,'DD')) - 1;
     /* Actualiza valores saldo acumulado del mes*/
     UPDATE cc_sal_mensuales
        SET sal_acu_diario = v_dias * nvl(v_salinic, 0)
      WHERE cod_modulo    = p_cdmodul
        AND cod_modalidad = p_cdmodal
        AND cod_oficina   = p_cdofici
        AND nro_cuenta    = p_nrcuent
        AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
        AND mes           = to_number(to_char(v_fcproxi,'MM'));
    -- SALDOS DEUDORES --
    ------------------------------------------------------------
     If nvl(v_salinic, 0) < 0 Then
       UPDATE cc_sal_mensuales
         SET sal_acu_deudor = v_dias * nvl(v_salinic, 0) * -1,
             can_dia_deudor = v_DIAS,
             sal_acu_acreedor = 0,
             can_dia_acreedor = 0
       WHERE cod_modulo    = p_cdmodul
         AND cod_modalidad = p_cdmodal
         AND cod_oficina   = p_cdofici
         AND nro_cuenta    = p_nrcuent
         AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
         AND mes           = to_number(to_char(v_fcproxi,'MM'));
   -- SALDOS ACREEDORES -- menor a cero
    ------------------------------------------------------------
     Else
       UPDATE cc_sal_mensuales
          SET sal_acu_acreedor = v_dias * nvl(v_salinic, 0),
              can_dia_acreedor = v_DIAS,
              sal_acu_deudor = 0,
              can_dia_deudor = 0
        WHERE cod_modulo    = p_cdmodul
          AND cod_modalidad = p_cdmodal
          AND cod_oficina   = p_cdofici
          AND nro_cuenta    = p_nrcuent
          AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
          AND mes           = to_number(to_char(v_fcproxi,'MM'));
     End If;
  END IF;
 -- IF SQL%NOTFOUND THEN
  --  raise_application_error(-20000,'No existe reg de mes proximo en CC_SAL_MENSUALES');
  --END IF;
EXCEPTION
  when no_data_found then
    null;
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||p_nrcuent||' '||sqlerrm);
END;  
----------------------------------------------------
--   PROCESO PRINCIPAL
----------------------------------------------------
BEGIN
  rv_gcale         := pag_cal.fu_obt_reg_cal(1);
  v_fcproxi        := rv_gcale.fec_proxima;  
  pag_cta.PR_OBT_CUENTA(P_NRO_CUENTA);
  v_cargos := nvl(p_val_cargo,0) + nvl(p_val_impuesto,0);

  if nvl(v_cargos,0) > 0 then
        pag_cta.G_COD_ERROR := 0;
        -- verifico si puedo o no cobrar el cargo + iva
        pag_cta.PR_VER_OPERACION(p_nro_cuenta,
                                 p_cod_Transaccion, -- padre
                                 4,
                                 41,
                                 'D', -- TIPO DEBITO
                                 pag_cta.G_CTAS.cod_moneda,
                                 v_cargos,
                                 pag_cta.G_CTAS.cod_oficina,
                                 pag_cta.G_CTAS.COD_MODULO,
                                 pag_cta.G_CTAS.COD_MODALIDAD,
                                 v_nvo_estado,
                                 v_sal_disponible,
                                 v_procesa,
                                 p_cod_transaccion);

        if v_procesa = 'N' then  -- no se puede debitar
           -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
           If  v_sal_disponible = 0 and pag_cta.g_ctas.estado = 'I' then
               null;
           else
             insert into ge_mov_pendientes
                       (nro_cuenta,fecha, cod_modulo, cod_modalidad, cod_transaccion,
                        cod_mod_padre, cod_mad_padre, cod_tra_padre, monto,
                        hora, cod_usuario,  cod_moneda,
                        cod_oficina, cod_error, estado, cod_ofi_origen,
                        concepto, cod_tasa, val_tasa, nro_documento, saldo,
                        motivo)
                values (p_nro_cuenta, p_Fecha, 4, 41, p_cod_transaccion,
                        4, 41, p_cod_transaccion, v_cargos,
                        v_hora, user, pag_cta.G_CTAS.cod_moneda,
                        pag_cta.g_ctas.cod_oficina, pag_cta.g_cod_error, 'I', pag_cta.G_CTAS.cod_oficina,
                        'Cargo por Pago de Cheque',p_COD_TAS_CARGO, p_VAL_TAS_CARGO,
                        p_nro_cuenta /* nro_documento=cuenta*/, v_cargos,
                        pag_cta.G_MSJ_ERROR);
           End if;             
        else
          pag_cta.pr_act_operacion(p_nro_cuenta,
                                 v_hora,
                                 'D', -- debito a la cuenta del cliente
                                 pag_cta.g_ctas.cod_moneda,
                                 p_val_cargo,
                                 p_cod_Transaccion,
                                 p_cod_transaccion, -- trans. hijo
                                 p_nro_cuenta,
                                 null, -- cotizacion
                                 pag_Cta.g_ctas.cod_oficina,
                                 4,
                                 41,
                                 p_COD_TAS_CARGO, -- tasa
                                 p_VAL_TAS_CARGO, -- valor de tasa
                                 'Cargo por Pago de Cheque', --concepto
                                 'N', -- emitir aviso
                                 v_nro_secuencia, -- nro de secuencia
                                 p_fecha);

           if pag_cta.g_cod_error <> 0 then
             raise_application_error(-20000,'No pudo debitar de la cuenta '||p_nro_cuenta|| ' por '||pag_cta.g_msj_error);
           end if;

           if p_val_impuesto > 0 then
            pag_cta.pr_act_operacion(p_nro_cuenta,
                                   v_hora,
                                   'D', -- debito a la cuenta del cliente
                                   pag_Cta.g_ctas.cod_moneda,
                                   p_val_impuesto,
                                   p_COD_TRA_IMPUESTO,
                                   p_COD_TRA_IMPUESTO, -- trans. hijo
                                   pag_Cta.g_ctas.nro_cuenta,
                                   null, -- cotizacion
                                   pag_cta.g_ctas.cod_oficina,
                                   4,
                                   41,
                                   p_COD_TAS_IMPUESTO, -- tasa
                                   p_VAL_TAS_IMPUESTO, -- valor de tasa
                                   'IVA s/Cargo por Pago de Cheque', --concepto
                                   'N', -- emitir aviso
                                   v_nro_secuencia, -- nro de secuencia
                                   p_fecha);

             if pag_cta.g_cod_error <> 0 then
               raise_application_error(-20000,'No pudo debitar de la cuenta '||p_nro_cuenta|| ' por '||pag_cta.g_msj_error);
             end if;
           End if;
           -- Actualizar saldo inicial de fecha proxima
           LP_ACT_SAL_MENSUAL(v_cargos, pag_cta.g_ctas.cod_modulo,
                              pag_Cta.g_ctas.cod_modalidad,pag_cta.g_ctas.cod_oficina,
                              p_nro_cuenta);                                      
      End if;
    End if;
    p_hora := v_hora;
    p_nro_secuencia := v_nro_secuencia;
exception
  when others then
    IF sqlcode <= -20000 THEN
      raise;
    else
      raise_application_error(-20000,'En cobrar cargos por pago de cheques'||' - '||sqlerrm);
    End if;
end prc_cob_car_pagos;
/

