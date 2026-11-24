create or replace procedure it.prt_obt_mov_tar_cre_detalle(p_nro_cuenta      in ge_movimientos.nro_cuenta%type,
                                                           p_nro_documento   in ge_movimientos.nro_documento%type,
                                                           p_tipo_movimiento out varchar2,
                                                           p_cod_moneda      out ge_movimientos.cod_moneda%type,
                                                           p_monto           out ge_movimientos.monto%type,
                                                           p_cod_transaccion out ge_movimientos.nro_documento%type,
                                                           p_fec_valor       out ge_movimientos.fec_valor%type,
                                                           p_estado          out varchar2,
                                                           p_descripcion     out ge_movimientos.concepto%type,
                                                           p_fecha_proceso   out ge_movimientos.fec_insercion%type,
                                                           p_afinidad        out ta_tipos.descripcion%type,
                                                           p_alias_tc        out ge_cta_dat_adicionales.val_parametro%type,
                                                           p_tarjeta         out ta_tarjetas.nro_tarjeta%type,
                                                           p_cta_debito      out ge_movimientos.nro_cuenta%type,
                                                           p_comercio        out ge_movimientos.concepto%type,
                                                           p_cod_moneda_usd  out ge_movimientos.cod_moneda%type,
                                                           p_monto_usd       out ge_movimientos.monto%type) is

  v_pro_correcto number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0);
  v_cod_error    number;
  v_mon_local ba_monedas.cod_moneda%type;
  v_mon_fuerte ba_monedas.cod_moneda%type;
  v_log_mensajes varchar2(4000);
begin
  v_cod_error := v_pro_correcto;
  v_mon_local:=pag_gen.FU_OBT_MON_LOCAL;
  v_mon_fuerte:=pag_gen.FU_OBT_MON_FUERTE;
  begin
    Select it.fug_tip_operacion(t.cod_transaccion,
                                t.cod_modulo,
                                t.cod_modalidad,
                                t.cod_tra_padre,
                                t.cod_mod_padre,
                                t.cod_mad_padre) Tip_movimiento,
           t.transactionCurrency cod_moneda,
           decode(t.transactionCurrency,
                  v_mon_local,
                  t.TransactionsAmount,
                  nvl(t.MTO_EQU_LOCAL,
                      pag_gen.FU_CON_MON_A_MONEDA(t.transactionCurrency,
                                                  v_mon_local,
                                                  t.TransactionsAmount,
                                                  null))) monto_gs,
           t.transactionId,
           t.transactionDate fec_transaccion,
           t.statusDescription estado,
           t.concepto descripcion,
           c.fec_proceso fec_proceso,
           ti.descripcion Afinidad,
           FUG_OBT_PARADICIONAL(t.NRO_CUENTA, 'ALIAS_TARJETA') Alias_TC,
           SUBSTR(j.nro_tarjeta, -4) tarjeta,
           c.nro_cta_debito,
           null Comercio,
           decode(t.transactionCurrency,
                  v_mon_fuerte,
                  t.transactionCurrency,
                  null) cod_moneda_usd,
           decode(t.transactionCurrency,
                  v_mon_local,
                  null,
                  t.TransactionsAmount) Monto_USD
      into p_tipo_movimiento,
           p_cod_moneda,
           p_monto,
           p_cod_transaccion,
           p_fec_valor,
           p_estado,
           p_descripcion,
           p_fecha_proceso,
           p_afinidad,
           p_alias_tc,
           p_tarjeta,
           p_cta_debito,
           p_comercio,
           p_cod_moneda_usd,
           p_monto_usd
      from gv_aho_vis_movimientos_v2 t,
           ta_cobros_gp              c,
           ta_tarjetas               j,
           ta_tipos                  ti
     where t.nro_cuenta = c.nro_cuenta
       and t.hora = c.hora
       and t.Fecha = c.Fec_Proceso
       and t.Cod_Usuario = c.cod_usuario
       and t.nro_cuenta = j.nro_cuenta
       and ti.cod_modalidad = t.cod_modalidad
       and ti.cod_modulo = t.cod_modulo
       and ti.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
       and SUBSTR(j.nro_tarjeta, -4) = c.nro_tarjeta
       and c.nro_cuenta = p_nro_cuenta
       and c.nro_documento = p_nro_documento
       and t.cod_tra_padre = 250
       and j.vigente='S';

  exception
    when no_data_found then
      begin
         Select it.fug_tip_operacion(t.cod_transaccion,
                                t.cod_modulo,
                                t.cod_modalidad,
                                t.cod_tra_padre,
                                t.cod_mod_padre,
                                t.cod_mad_padre) Tip_movimiento,
           t.transactionCurrency cod_moneda,
           decode(t.transactionCurrency,
                  v_mon_local,
                  t.TransactionsAmount,
                  nvl(t.MTO_EQU_LOCAL,
                      pag_gen.FU_CON_MON_A_MONEDA(t.transactionCurrency,
                                                  v_mon_local,
                                                  t.TransactionsAmount,
                                                  null))) monto_gs,
           t.transactionId,
           t.transactionDate fec_transaccion,
           t.statusDescription estado,
           t.concepto descripcion,
           t.fecha fec_proceso,
           ti.descripcion Afinidad,
           FUG_OBT_PARADICIONAL(t.NRO_CUENTA, 'ALIAS_TARJETA') Alias_TC,
           SUBSTR(j.nro_tarjeta, -4) tarjeta,
           case when  concepto like '%CONSUMO CONTADO%' then
             substr(t.concepto,instr(t.concepto,'CONTADO')+length('CONTADO')+1)
                when  concepto like '%CONSUMO%CUOTAS%' then
             substr(t.concepto,instr(t.concepto,'CUOTAS')+length('CUOTAS')+1)
           else
             null
            end  Comercio,
           decode(t.transactionCurrency,
                  v_mon_fuerte,
                  t.transactionCurrency,
                  null) cod_moneda_usd,
           decode(t.transactionCurrency,
                  v_mon_local,
                  null,
                  t.TransactionsAmount) Monto_USD
        into   p_tipo_movimiento,
               p_cod_moneda,
               p_monto,
               p_cod_transaccion,
               p_fec_valor,
               p_estado,
               p_descripcion,
               p_fecha_proceso,
               p_afinidad,
               p_alias_tc,
               p_tarjeta,
               p_comercio,
               p_cod_moneda_usd,
               p_monto_usd
      from gv_aho_vis_movimientos_v2 t,
           ta_tarjetas               j,
           ta_tipos                  ti
     where  t.nro_cuenta = j.nro_cuenta
       and ti.cod_modalidad = t.cod_modalidad
       and ti.cod_modulo = t.cod_modulo
       and ti.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
       and t.nro_cuenta = p_nro_cuenta
       and t.transactionid = p_nro_documento
       and t.cod_tra_padre = 38
       and cod_mod_padre=5
       and j.vigente='S'
       and j.rel_tarjeta=0;
      exception
        when no_data_found then
           p_tipo_movimiento := null;
           p_cod_moneda      := null;
           p_monto           := null;
           p_cod_transaccion := null;
           p_fec_valor       := null;
           p_estado          := null;
           p_descripcion     := null;
           p_fecha_proceso   := null;
           p_afinidad        := null;
           p_alias_tc        := null;
           p_tarjeta         := null;
           p_cta_debito      := null;
           p_comercio        := null;
           p_cod_moneda_usd  := null;
           p_monto_usd       := null;
        when others then
          v_cod_error := 1;
          v_log_mensajes:=substr('Nro.documento: '||p_nro_documento||' Cod. '||v_cod_error||' Mensaje: '||sqlerrm,1,4000);
      end;
    when others then
      v_cod_error := 2;
      v_log_mensajes:=substr('Nro.documento: '||p_nro_documento||' Cod. '||v_cod_error||' Mensaje: '||sqlerrm,1,4000);
  end;

  if v_cod_error <> v_pro_correcto then
    p_tipo_movimiento := null;
    p_cod_moneda      := null;
    p_monto           := null;
    p_cod_transaccion := null;
    p_fec_valor       := null;
    p_estado          := null;
    p_descripcion     := null;
    p_fecha_proceso   := null;
    p_afinidad        := null;
    p_alias_tc        := null;
    p_tarjeta         := null;
    p_cta_debito      := null;
    p_comercio        := null;
    p_cod_moneda_usd  := null;
    p_monto_usd       := null;
    it.prg_ins_log_programas('PRT_OBT_MOV_TAR_CRE_DETALLE',v_log_mensajes,null,p_nro_cuenta);
  end if;

exception
  when others then
    p_tipo_movimiento := null;
    p_cod_moneda      := null;
    p_monto           := null;
    p_cod_transaccion := null;
    p_fec_valor       := null;
    p_estado          := null;
    p_descripcion     := null;
    p_fecha_proceso   := null;
    p_afinidad        := null;
    p_alias_tc        := null;
    p_tarjeta         := null;
    p_cta_debito      := null;
    p_comercio        := null;
    p_cod_moneda_usd  := null;
    p_monto_usd       := null;
    v_cod_error := 99;
   v_log_mensajes:=substr('Nro.documento: '||p_nro_documento||' Cod. '||v_cod_error||' Mensaje: '||DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,1,4000);
   it.prg_ins_log_programas('PRT_OBT_MOV_TAR_CRE_DETALLE',v_log_mensajes,null,p_nro_cuenta);

end prt_obt_mov_tar_cre_detalle;
/

