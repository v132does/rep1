create or replace function it.fug_obt_dat_comp_sal(p_nro_cuenta      in ge_cta_clientes.nro_cuenta%type,
                                                   p_cod_moneda      in ba_monedas.cod_moneda%type,
                                                   p_importe         in ge_movimientos.monto%type,
                                                   p_fecha           in date,
                                                   p_nro_documento   in ge_movimientos.nro_documento%type,
                                                   p_tip_persona     in varchar2 default 'J',
                                                   p_cod_tip_mensaje in bw_movimientos.cod_tip_mensaje%type default '070',
                                                   p_tip_confirma    in varchar2 default 'X')
  return TYP_DETCOMSAL is
  --https://itti-digital.atlassian.net/browse/NVB-3811
  MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  v_fecha           date;
  v_hora            varchar2(8);
  v_nro_cuenta      varchar2(15);
  v_tipo_cuenta     varchar2(200);
  v_monto           number(18, 2);
  v_nro_documento   number(15);
  v_nro_documento3  number(15);
  v_cod_tip_mensaje varchar2(10);
  v_concepto        varchar2(150);
  v_descripcion     varchar2(150);
  v_tip_movimiento  varchar2(150);
  v_cod_moneda      varchar2(3);
  v_moneda          varchar2(35);
  v_cotizacion      number(18, 2);
  v_can_fir_req     integer;
  v_oficina         varchar2(35);
  v_log_mensaje     varchar2(4000);
  v_tip_pago        varchar2(3);
  v_cantidad        integer;
  v_cod_modulo      ge_cuentas.cod_modulo%type;
  v_cod_modalidad   ge_cuentas.cod_modalidad%type;
  v_retorno         TYP_DETCOMSAL := TYP_DETCOMSAL();

BEGIN
  if p_cod_tip_mensaje = '070' and nvl(p_tip_confirma, 'X') != 'P' then
    BEGIN
      SELECT t.fec_insercion,
             t.hora,
             t.monto,
             t.nro_cuenta,
             It.Fug_Obt_Des_Modal(T.Cod_Modulo, T.Cod_Modalidad) Tipo_Cuenta,
             t.nro_documento,
             t.nro_documento3,
             b.cod_tip_mensaje,
             a.descripcion concepto,
             t.concepto descripcion,
             t.tip_movimiento,
             t.COD_MONEDA,
             fue_obt_des_moneda(t.COD_MONEDA) Moneda,
             t.cotizacion,
             fue_obt_des_oficina(t.cod_ofi_origen),
             decode(trim(t.CONCEPTO), 'Pago de Sueldo', 'S', 'Pago de Aguinaldo', 'A', 'X') tip_pago,
             b.cantidad,
             decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas, 0)
        into v_fecha,
             v_hora,
             v_monto,
             v_nro_cuenta,
             v_tipo_cuenta,
             v_nro_documento,
             v_nro_documento3,
             v_cod_tip_mensaje,
             v_concepto,
             v_descripcion,
             v_tip_movimiento,
             v_cod_moneda,
             v_moneda,
             v_cotizacion,
             v_oficina,
             v_tip_pago,
             v_cantidad,
             v_can_fir_req
        FROM gv_movimientos    t,
             bw_movimientos    b,
             bw_tip_mensajes   a,
             bw_mov_pendientes p
       WHERE t.nro_cuenta = b.nro_cuenta
         AND t.monto = b.monto
         AND t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje
         AND b.cod_tip_mensaje = a.cod_tip_mensaje
         and b.nro_doc_pendiente = p.nro_documento(+)
         and b.cod_tip_mensaje = '070'
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
        prg_ins_log_programas('FUG_OBT_DAT_COMP_SAL', v_log_mensaje, null, p_nro_cuenta);
    end;
  end if;
  if p_cod_tip_mensaje = '070' and nvl(p_tip_confirma, 'X') = 'P' then

    begin
      Select t.cod_modulo, t.cod_modalidad
        into v_cod_modulo, v_cod_modalidad
        from ge_cuentas t
       where t.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
        v_retorno.error                := 'S';
      when others THEN
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
    end;
    begin
      select p.nro_documento,
             p.fec_insercion,
             to_char(p.fec_insercion, 'hh24:mi:ss'),
             p.nro_cuenta,
             it.fug_obt_des_modal(v_cod_modulo, v_cod_modalidad) tipo_cuenta,
             fue_obt_des_moneda(p.cod_moneda),
             p.monto,
             fue_obt_des_operacion(p.cod_tip_mensaje),
             p.cantidad,
             decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas, 0),
             null,
             null,
             p.cod_moneda,
             null,
             null,
             p.tip_pago/*'S'*/,--NVB-3703
             p.dato
        into v_nro_documento,
             v_fecha,
             v_hora,
             v_nro_cuenta,
             v_tipo_cuenta,
             v_moneda,
             v_monto,
             v_concepto,
             v_cantidad,
             v_can_fir_req,
             v_descripcion,
             v_tip_movimiento,
             v_cod_moneda,
             v_cotizacion,
             v_oficina,
             v_tip_pago,
             v_nro_documento3
        from bw_mov_pendientes p
       where p.cod_tip_mensaje = p_cod_tip_mensaje
         and p.cod_moneda = p_cod_moneda
         and trunc(p.fec_insercion) = p_fecha
         and p.nro_cuenta = p_nro_cuenta
         and p.nro_documento = p_nro_documento;

    exception
      when no_data_found then
        v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
        v_retorno.error                := 'S';
      when others THEN
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
        v_log_mensaje                  := substr('Ocurrio un error: ' ||
                                                 'Importe: ' || p_importe || ' - ' || 
                                                 'Fecha: ' || p_fecha || ' - ' ||
                                                 'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                                 'Nro_documento: ' || p_nro_documento || ' - ' ||
                                                 'Error: ' || sqlerrm, 1, 4000);
        prg_ins_log_programas('FUG_OBT_DAT_COMP_SAL', v_log_mensaje, null, p_nro_cuenta);
    end;
  end if;

  If nvl(v_retorno.error, 'N') = 'N' then
    v_retorno.error                := 'N';
    v_retorno.nombrerespuesta      := 0;
    v_retorno.descripcionrespuesta := msg_ok;
    v_retorno.nrocomprobante       := v_nro_documento;
    v_retorno.fecharegistro        := v_fecha;
    v_retorno.hora                 := v_hora;
    v_retorno.fechapago            := v_fecha;
    v_retorno.nroctadebito         := v_nro_cuenta;
    v_retorno.tipoctadebito        := v_tipo_cuenta;
    v_retorno.moneda               := v_moneda;
    v_retorno.importedebito        := v_monto;
    v_retorno.tipooperacion        := v_concepto;
    v_retorno.concepto             := v_descripcion;
    v_retorno.ente                 := v_nro_documento3;
    v_retorno.oficina              := v_oficina;
    v_retorno.canfirreq            := v_can_fir_req;
    v_retorno.cotizacion           := v_cotizacion;
    v_retorno.cantregs             := v_cantidad;
    v_retorno.tipopago             := v_tip_pago;
    v_retorno.codmoneda            := v_cod_moneda;
  else
    v_retorno.error := 'S';
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
    prg_ins_log_programas('FUG_OBT_DAT_COMP_SAL', v_log_mensaje, null, p_nro_cuenta);
    v_retorno.descripcionRespuesta := 'Ocurrio un error';
    v_retorno.error                := 'S';
    RETURN v_retorno;
end;
/

