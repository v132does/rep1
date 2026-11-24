create or replace function it.fug_obt_dat_comp(p_nro_cuenta    in ge_cta_clientes.nro_cuenta%type,
                                               p_cod_moneda    in ba_monedas.cod_moneda%type,
                                               p_importe       in ge_movimientos.monto%type,
                                               p_fecha         in date,
                                               p_nro_documento in ge_movimientos.nro_documento%type)
  return TYP_DETCOMP is
  MSG_OK CONSTANT varchar2(30) := 'OP_APROBADA';
  v_nro_documento  number(15);
  v_fecha          date;
  v_hora           varchar2(8);
  v_nro_cuenta     varchar2(15);
  v_tipo_cuenta    varchar2(200);
  v_cod_moneda     varchar2(3);
  v_monto          number(18, 2);
  v_nro_tarjeta    varchar2(20);
  v_cod_afinidad   varchar2(5);
  v_tipo_operacion varchar2(150);
  v_retorno        TYP_DETCOMP := TYP_DETCOMP();
  v_cod_persona    ge_cta_clientes.cod_persona%type;
  v_log_mensaje    varchar2(4000);
  v_can_fir_req    integer := 0;
  v_cotizacion     number(18, 2);

BEGIN
  BEGIN
    BEGIN
      select t.nro_documento,
             t.fec_insercion,
             t.hora,
             t.nro_cuenta,
             it.fug_obt_des_modal(t.cod_modulo, t.cod_modalidad) tipo_cuenta,
             t.cod_moneda,
             t.monto,
             replace(b.observacion, 'Pago tarjeta-Nro.Tarj: ') nro_tarjeta,
             t.concepto tipo_operacion,
             b.cod_per_principal,
             t.cotizacion
        into v_nro_documento,
             v_fecha,
             v_hora,
             v_nro_cuenta,
             v_tipo_cuenta,
             v_cod_moneda,
             v_monto,
             v_nro_tarjeta,
             v_tipo_operacion,
             v_cod_persona,
             v_cotizacion
        from ge_movimientos t, bw_movimientos b
       where t.nro_cuenta = b.nro_cuenta
         and t.monto = b.monto
         and t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje
         and t.cod_moneda = p_cod_moneda
         --and t.monto = p_importe
         and trunc(t.fec_insercion) = p_fecha
         and t.nro_cuenta = p_nro_cuenta
         and t.nro_documento = p_nro_documento;
    exception
      when no_data_found then
        v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
        v_retorno.error                := 'S';
      when others then
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
        v_log_mensaje                  := substr('Ocurrio un error: ' ||
                                                 'Importe: ' || p_importe || ' - ' ||
                                                 'Fecha: ' || p_fecha || ' - ' ||
                                                 'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                                 'Nro_documento: ' || p_nro_documento || ' - ' ||
                                                 'Error: ' || sqlerrm, 1, 4000);
        prg_ins_log_programas('FUG_OBT_DAT_COMP', v_log_mensaje, null, p_nro_cuenta);
    end;

    BEGIN
      Select c.afinidad
        into v_cod_afinidad
        from ta_tarjetas t, ta_cta_tarjetas c
       where t.nro_cuenta = c.nro_cuenta
         and t.nro_tarjeta = v_nro_tarjeta
         and t.cod_persona = v_cod_persona;
    exception
      when no_data_found then
        v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
        v_retorno.error                := 'S';
      when others then
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
    end;
    If nvl(v_retorno.error, 'N') = 'N' then
      v_retorno.nombreRespuesta      := 0;
      v_retorno.descripcionRespuesta := MSG_OK;
      v_retorno.error                := 'N';
      v_retorno.nrodocumento         := v_nro_documento;
      v_retorno.fecha                := v_fecha;
      v_retorno.hora                 := v_hora;
      v_retorno.nrocuenta            := v_nro_cuenta;
      v_retorno.tipocuenta           := v_tipo_cuenta;
      v_retorno.codmoneda            := v_cod_moneda;
      v_retorno.monto                := v_monto;
      v_retorno.nrotarjeta           := v_nro_tarjeta;
      v_retorno.afinidad             := it.fug_obt_des_afinidad(v_cod_afinidad);
      v_retorno.tipooperacion        := v_tipo_operacion;
      v_retorno.cantfirreq           := v_can_fir_req;
      v_retorno.cotizacion           := v_cotizacion;
    else
      v_retorno.error                := 'S';
    End if;

    RETURN v_retorno;
  EXCEPTION
    WHEN others THEN
      v_log_mensaje := substr('Ocurrio un error: ' ||
                                'Importe: ' || p_importe || ' - ' ||
                                'Fecha: ' || p_fecha || ' - ' ||
                                'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                'Nro_documento: ' || p_nro_documento || ' - ' ||
                                'Error: ' || sqlerrm, 1, 4000);
      prg_ins_log_programas('FUG_OBT_DAT_COMP', v_log_mensaje, null, p_nro_cuenta);
      v_retorno.descripcionRespuesta := 'Ocurrio un error';
      v_retorno.error                := 'S';
      RETURN v_retorno;
  end;
end;
/

