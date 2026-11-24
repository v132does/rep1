create or replace function it.fug_obt_dat_comp_ser(p_nro_cuenta    in ge_cta_clientes.nro_cuenta%type,
                                                   p_cod_moneda    in ba_monedas.cod_moneda%type,
                                                   p_importe       in ge_movimientos.monto%type,
                                                   p_fecha         in date,
                                                   p_nro_documento in ge_movimientos.nro_documento%type,
                                                   p_tip_persona   in varchar2)
  return TYP_DETCOMSER is
  MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  v_fecha         date;
  v_hora          varchar2(8);
  v_nro_cuenta    varchar2(15);
  v_monto         number(18, 2);
  v_nro_documento number(15);
  v_concepto      varchar2(150);
  v_cod_moneda    varchar2(3);
  v_moneda        varchar2(35);
  v_log_mensaje   varchar2(4000);
  v_servicio      varchar2(300);
  v_can_fir_req   integer;
  v_denominacion  varchar2(100);
  v_retorno       TYP_DETCOMSER := TYP_DETCOMSER();

BEGIN
  BEGIN
    select t.nro_documento,
           initcap(a.descripcion) concepto,
           t.nro_cuenta,
           fue_obt_des_moneda(t.cod_moneda),
           t.monto,
           t.fec_insercion,
           t.hora,
           t.cod_moneda,
           decode(t.NRO_DOCUMENTO,nvl(b.dato3,-1),t.CONCEPTO,--si es wepa toma concepto
           it.fug_obt_des_servicio(t.nro_documento2)),
           decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas,0),
           fug_obt_nom_cuenta(t.nro_cuenta)
      into v_nro_documento,
           v_concepto,
           v_nro_cuenta,
           v_moneda,
           v_monto,
           v_fecha,
           v_hora,
           v_cod_moneda,
           v_servicio,
           v_can_fir_req,
           v_denominacion
      from gv_movimientos t, bw_movimientos b, bw_tip_mensajes a, bw_mov_pendientes p
     where t.nro_cuenta = b.nro_cuenta
       --and t.monto = b.monto
       --and t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje
       and (
            (t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje) or 
            (t.NRO_DOCUMENTO2 = b.dato and t.NRO_DOCUMENTO  = nvl(b.dato3,-1)) --referencia wepa
            )
       and b.cod_tip_mensaje = a.cod_tip_mensaje
       and b.nro_doc_pendiente = p.nro_documento(+)
       and b.cod_tip_mensaje = '089'
       AND t.cod_moneda = p_cod_moneda
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
      prg_ins_log_programas('FUG_OBT_DAT_COMP_SER', v_log_mensaje, null, p_nro_cuenta);
  end;

  If nvl(v_retorno.error, 'N') = 'N' then
    v_retorno.error                := 'N';
    v_retorno.nombrerespuesta      := 0;
    v_retorno.descripcionrespuesta := msg_ok;
    v_retorno.nrocomprobante       := v_nro_documento;
    v_retorno.tipooperacion        := v_concepto;
    v_retorno.nroctadebito         := v_nro_cuenta;
    v_retorno.moneda               := v_moneda;
    v_retorno.importedebito        := v_monto;
    v_retorno.fechapago            := v_fecha;
    v_retorno.hora                 := v_hora;
    v_retorno.codmoneda            := v_cod_moneda;
    v_retorno.servicio             := v_servicio;
    v_retorno.cantfirreq           := v_can_fir_req;
    v_retorno.denominacioncta      := v_denominacion;
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
    prg_ins_log_programas('FUG_OBT_DAT_COMP_SER', v_log_mensaje, null, p_nro_cuenta);
    v_retorno.descripcionRespuesta := 'Ocurrio un error';
    v_retorno.error                := 'S';
    RETURN v_retorno;
end;
/
