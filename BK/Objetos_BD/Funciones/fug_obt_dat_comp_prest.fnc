create or replace function it.fug_obt_dat_comp_prest(p_nro_cuenta    in ge_cta_clientes.nro_cuenta%type,
                                                     p_cod_moneda    in ba_monedas.cod_moneda%type,
                                                     p_importe       in ge_movimientos.monto%type,
                                                     p_fecha         in date,
                                                     p_nro_documento in ge_movimientos.nro_documento%type)
  return TYP_DETCOMPPRE is
  MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  v_nro_documento  NUMBER(15);
  v_tipo_operacion VARCHAR2(150);
  v_nro_prestamo   VARCHAR2(30);
  v_cuentadebito   VARCHAR2(15);
  v_monto          NUMBER(18, 2);
  v_cuotas_pagadas NUMBER;
  v_fecha          date;
  v_hora           VARCHAR2(8);
  v_cod_modulo     pr_cta_prestamos.cod_modulo%type;
  v_cod_modalidad  pr_cta_prestamos.cod_modalidad%type;
  v_retorno        TYP_DETCOMPPRE := TYP_DETCOMPPRE();
  v_log_mensaje    varchar2(4000);
  v_can_fir_req    integer := 0;
  v_cotizacion     number(18, 2);
  v_cuota_desde    number(3);
  v_cuota_hasta    number(3);
  
  BEGIN
    BEGIN
      select t.nro_documento,
             upper(t.concepto),
             b.nro_cuenta,
             t.nro_cuenta,
             t.monto,
             0 cuotas_pagadas,
             t.fec_insercion,
             t.hora,
             to_number(b.etiqueta3),
             to_number(b.dato3)
        into v_nro_documento,
             v_tipo_operacion,
             v_nro_prestamo,
             v_cuentadebito,
             v_monto,
             v_cuotas_pagadas,
             v_fecha,
             v_hora,
             v_cuota_desde,
             v_cuota_hasta
        from gv_movimientos t, bw_movimientos b
       where t.nro_cuenta = b.nro_cta_contra
         and t.monto = b.monto
         and t.nro_documento = b.nro_documento
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
        prg_ins_log_programas('FUG_OBT_DAT_COMP_PREST', v_log_mensaje, null, p_nro_cuenta);
    end;

    begin
      Select t.cod_modulo, t.cod_modalidad
        into v_cod_modulo, v_cod_modalidad
        from pr_cta_prestamos t
       where t.nro_cuenta = v_nro_prestamo;
    exception
      when no_data_found then
        v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
        v_retorno.error                := 'S';
      when others then
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
    end;

    begin
      Select t.nro_cuota
        into v_cuotas_pagadas
        from pr_cuotas t
       where t.nro_cuenta = v_nro_prestamo
         and t.fec_ult_pago between trunc(v_fecha) and trunc(v_fecha);
    exception
      when too_many_rows then
        begin
        v_cuotas_pagadas := v_cuota_hasta;

       exception
       when others then
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
        dbms_output.put_line(sqlerrm);
       end;
      when no_data_found then
        v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
        v_retorno.error                := 'S';
      when others then
        v_retorno.descripcionRespuesta := 'Ocurrio un error';
        v_retorno.error                := 'S';
    end;

    If nvl(v_retorno.error, 'N') = 'N' then
      v_retorno.nombrerespuesta      := 0;
      v_retorno.descripcionrespuesta := msg_ok;
      v_retorno.error                := 'N';
      v_retorno.nrooperacion         := v_nro_documento;
      v_retorno.tipooperacion        := v_tipo_operacion;
      v_retorno.nroprestamo          := v_nro_prestamo;
      v_retorno.tipoprestamo         := fug_obt_des_modal(v_cod_modulo, v_cod_modalidad);
      v_retorno.cuentadebito         := v_cuentadebito;
      v_retorno.monto                := v_monto;
      v_retorno.cuotapagada          := v_cuotas_pagadas;
      v_retorno.fecha                := v_fecha;
      v_retorno.hora                 := v_hora;
      v_retorno.cantfirreq           := v_can_fir_req;
      v_retorno.cotizacion           := v_cotizacion;
    else
      v_retorno.error                := 'S';
    end if;

    RETURN v_retorno;
  EXCEPTION
    WHEN others THEN
        v_log_mensaje := substr('Ocurrio un error: ' ||
                                'Importe: ' || p_importe || ' - ' ||
                                'Fecha: ' || p_fecha || ' - ' ||
                                'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                'Nro_documento: ' || p_nro_documento || ' - ' ||
                                'Error: ' || sqlerrm, 1, 4000);
        prg_ins_log_programas('FUG_OBT_DAT_COMP_PREST', v_log_mensaje, null, p_nro_cuenta);
      v_retorno.descripcionRespuesta := 'Ocurrio un error';
      v_retorno.error                := 'S';
      RETURN v_retorno;
end;
/

