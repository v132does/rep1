create or replace function it.fug_obt_dat_comp_transt(p_nro_cuenta      in ge_cta_clientes.nro_cuenta%type,
                                                      p_cod_moneda      in ba_monedas.cod_moneda%type,
                                                      p_importe         varchar2,--in ge_movimientos.monto%type,
                                                      p_fecha           in date,
                                                      p_nro_documento   in ge_movimientos.nro_documento%type,
                                                      p_cod_tip_mensaje in bw_movimientos.cod_tip_mensaje%type,
                                                      p_tip_persona     in varchar2 default 'F')
                                                      ----https://itti-digital.atlassian.net/browse/NVB-3811
  return TYP_DETCOMTRAT is
  MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  v_nrooperacion       NUMBER(30);
  v_tipooperacion      VARCHAR2(150);
  v_ctadebito          VARCHAR2(30);
  v_denominacionctadeb VARCHAR2(100);
  v_desmonedadeb       VARCHAR2(100);
  v_ctacredito         VARCHAR2(30);
  v_desmonedacre       VARCHAR2(30);
  v_denominacionctacre VARCHAR2(100);
  v_doctitcred         VARCHAR2(100);
  v_importecre         NUMBER(18, 2);
  v_fecha              DATE;
  v_hora               VARCHAR2(8);
  v_cod_moneda         VARCHAR2(3);
  v_retorno            TYP_DETCOMTRAT := TYP_DETCOMTRAT();
  v_log_mensaje        varchar2(4000);
  v_can_fir_req        integer;
  v_cotizacion         number(18, 2);
  v_cotizacion1        number(18, 2);
  v_codmonedacre       VARCHAR2(3);
  v_concepto           VARCHAR2(150);
  v_importedev         NUMBER(18, 2);
  v_fecha_m            ge_movimientos.fecha%type;
  v_hora_m             ge_movimientos.hora%type;
  v_cod_usuario        ge_movimientos.cod_usuario%type;
BEGIN
  begin
    begin
      select b.nro_documento,
             m.descripcion,
             t.nro_cuenta,
             fug_obt_nom_cuenta(b.nro_cuenta),
             fue_obt_des_moneda(t.cod_moneda),
             b.nro_cta_contra,
             fue_obt_des_moneda(fug_obt_mon_cta(nvl(b.nro_cta_contra, 'GS'))),
             fug_obt_nom_cuenta(b.nro_cta_contra),
             (select a.cod_persona
                from ge_cta_clientes a
               where b.nro_cta_contra = a.nro_cuenta
                 and a.relacion = 'P'),
             t.monto,
             t.fec_insercion,
             t.hora,
             t.cod_moneda,
             t.cotizacion,
             decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas, 0),
             fug_obt_mon_cta(nvl(b.nro_cta_contra, 'GS')),
             trim(SUBSTR(t.concepto, (INSTR(t.concepto, '-') + 1))),
             decode(b.etiqueta2, 'Cotizacion', b.dato2, 1),
             t.monto
        into v_nrooperacion,
             v_tipooperacion,
             v_ctadebito,
             v_denominacionctadeb,
             v_desmonedadeb,
             v_ctacredito,
             v_desmonedacre,
             v_denominacionctacre,
             v_doctitcred,
             v_importecre,
             v_fecha,
             v_hora,
             v_cod_moneda,
             v_cotizacion,
             v_can_fir_req,
             v_codmonedacre,
             v_concepto,
             v_cotizacion1,
             v_importedev
        from gv_movimientos t, bw_movimientos b, bw_mov_pendientes p, bw_tip_mensajes m
       where t.nro_cuenta = b.nro_cuenta
         and t.monto = b.monto
         and t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje
         and b.nro_doc_pendiente = p.nro_documento(+)
         and b.cod_tip_mensaje = m.cod_tip_mensaje
         and b.cod_tip_mensaje = p_cod_tip_mensaje
         and t.cod_moneda = p_cod_moneda
         --and t.monto = p_importe
         and trunc(t.fec_insercion) = p_fecha
         and t.nro_cuenta = p_nro_cuenta
         and b.nro_documento = p_nro_documento;
    exception
      when no_data_found then
        begin
        select b.nro_documento,
               m.descripcion,
               t.nro_cuenta,
               fug_obt_nom_cuenta(b.nro_cuenta),
               fue_obt_des_moneda(t.cod_moneda),
               b.nro_cta_contra,
               fue_obt_des_moneda(fug_obt_mon_cta(nvl(b.nro_cta_contra, 'GS'))),
               fug_obt_nom_cuenta(b.nro_cta_contra),
               (select a.cod_persona
                  from ge_cta_clientes a
                 where b.nro_cta_contra = a.nro_cuenta
                   and a.relacion = 'P'),
               t.monto,
               t.fec_insercion,
               t.hora,
               t.cod_moneda,
               t.cotizacion,
               decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas, 0),
               fug_obt_mon_cta(nvl(b.nro_cta_contra, 'GS')),
               trim(SUBSTR(t.concepto, (INSTR(t.concepto, '-') + 1))),
               decode(b.etiqueta2, 'Cotizacion', b.dato2, 1),
               t.monto
          into v_nrooperacion,
               v_tipooperacion,
               v_ctadebito,
               v_denominacionctadeb,
               v_desmonedadeb,
               v_ctacredito,
               v_desmonedacre,
               v_denominacionctacre,
               v_doctitcred,
               v_importecre,
               v_fecha,
               v_hora,
               v_cod_moneda,
               v_cotizacion,
               v_can_fir_req,
               v_codmonedacre,
               v_concepto,
               v_cotizacion1,
               v_importedev
          from gv_movimientos t, bw_movimientos b, bw_mov_pendientes p, bw_tip_mensajes m
         where t.nro_cuenta = b.nro_cuenta
           and t.monto = b.monto
           and t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje
           and b.nro_doc_pendiente = p.nro_documento(+)
           and b.cod_tip_mensaje = m.cod_tip_mensaje
           and b.cod_tip_mensaje = p_cod_tip_mensaje
           and t.cod_moneda = p_cod_moneda
           --and t.monto = p_importe
           and trunc(t.fec_insercion) = p_fecha
           and t.nro_cuenta = p_nro_cuenta
           and t.nro_documento = p_nro_documento;
        exception
          when no_data_found then
             select t.nro_documento,
                   (Select initcap(a.descripcion) from bw_tip_mensajes a
                     where a.cod_tip_mensaje = p_cod_tip_mensaje),
                   t.nro_cuenta,
                   fug_obt_nom_cuenta(t.nro_cuenta),
                   fue_obt_des_moneda(t.cod_moneda),
                   t.monto,
                   t.fec_insercion,
                   t.hora,
                   t.cod_moneda,
                   t.cotizacion,
                   0,
                   t.des_tra_padre,
                   t.cotizacion,
                   t.monto,
                   t.fecha,
                   t.hora,
                   t.cod_usuario
              into v_nrooperacion,
                   v_tipooperacion,
                   v_ctadebito,
                   v_denominacionctadeb,
                   v_desmonedadeb,
                   v_importecre,
                   v_fecha,
                   v_hora,
                   v_cod_moneda,
                   v_cotizacion,
                   v_can_fir_req,
                   v_concepto,
                   v_cotizacion1,
                   v_importedev,
                   v_fecha_m,
                   v_hora_m,
                   v_cod_usuario
              from gv_movimientos t
             where t.cod_moneda = p_cod_moneda
               and trunc(t.fec_insercion) = p_fecha
               and t.nro_cuenta = p_nro_cuenta
               and t.nro_documento = p_nro_documento
               and t.monto = p_importe
               and t.reversado = 'N';
               
         begin
           select t.nro_cuenta,
                  fue_obt_des_moneda(t.cod_moneda),
                  fug_obt_nom_cuenta(t.nro_cuenta),
                  (select a.cod_persona
                     from ge_cta_clientes a
                    where a.nro_cuenta = t.nro_cuenta
                      and a.relacion = 'P'),
                  fug_obt_mon_cta(t.nro_cuenta)
             into v_ctacredito,
                  v_desmonedacre,
                  v_denominacionctacre,
                  v_doctitcred,
                  v_codmonedacre
             from gv_movimientos t
            where t.FECHA = v_fecha_m
              and t.HORA = v_hora_m
              and t.COD_USUARIO = v_cod_usuario
              and t.NRO_CUENTA != p_nro_cuenta
              and t.reversado = 'N';
         exception
           when no_data_found then
             v_ctacredito         := null;
             v_desmonedacre       := null;
             v_denominacionctacre := null;
             v_doctitcred         := null;
             v_codmonedacre       := null;
           when others then
            v_retorno.descripcionRespuesta := 'Ocurrio un error';
            v_retorno.error                := 'S';
            v_log_mensaje                  := substr('Ocurrio un error: ' ||
                                                     'Importe: ' || p_importe || ' - ' ||
                                                     'Fecha: ' || p_fecha || ' - ' ||
                                                     'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                                     'Nro_documento: ' || p_nro_documento || ' - ' ||
                                                     'Error: ' || sqlerrm, 1, 4000);
            prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANST', v_log_mensaje, null, p_nro_cuenta);
         end;
          when others then
            v_retorno.descripcionRespuesta := 'Ocurrio un error';
            v_retorno.error                := 'S';
            v_log_mensaje                  := substr('Ocurrio un error: ' ||
                                                     'Importe: ' || p_importe || ' - ' ||
                                                     'Fecha: ' || p_fecha || ' - ' ||
                                                     'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                                     'Nro_documento: ' || p_nro_documento || ' - ' || 
                                                     'Error: ' || sqlerrm, 1, 4000);
            prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANST', v_log_mensaje, null, p_nro_cuenta);
        end;
    end;
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
      prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANST', v_log_mensaje, null, p_nro_cuenta);
  end;

  If nvl(v_retorno.error, 'N') = 'N' then
    v_retorno.error                := 'N';
    v_retorno.nombrerespuesta      := 0;
    v_retorno.descripcionrespuesta := msg_ok;
    v_retorno.nrooperacion         := v_nrooperacion;
    v_retorno.tipooperacion        := v_tipooperacion;
    v_retorno.ctadebito            := v_ctadebito;
    v_retorno.denominacionctadeb   := v_denominacionctadeb;
    v_retorno.desmonedadeb         := v_desmonedadeb;
    v_retorno.ctacredito           := v_ctacredito;
    v_retorno.desmonedacre         := v_desmonedacre;
    v_retorno.denominacionctacre   := v_denominacionctacre;
    v_retorno.doctitcred           := v_doctitcred;
    v_retorno.fecha                := v_fecha;
    v_retorno.hora                 := v_hora;
    v_retorno.codmoneda            := v_cod_moneda;
    v_retorno.cantfirreq           := v_can_fir_req;
    v_retorno.codmonedacre         := v_codmonedacre;
    v_retorno.concepto             := v_concepto;
    v_retorno.importecre           := v_importecre;
    v_retorno.importedev           := v_importedev;
  
    if v_codmonedacre = 'GS' and v_cod_moneda = 'USD' then
      v_retorno.importecre := v_importecre *
                              nvl(v_cotizacion, v_cotizacion1);
    end if;
  
    if v_codmonedacre = 'USD' and v_cod_moneda = 'GS' then
      v_retorno.importecre := v_importecre /
                              nvl(v_cotizacion, v_cotizacion1);
    end if;
  
    if p_cod_tip_mensaje = '030' and v_cod_moneda != v_codmonedacre then
      v_retorno.cotizacion := nvl(v_cotizacion, v_cotizacion1);
    else
      v_retorno.cotizacion := v_cotizacion;
    end if;
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
    prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANST', v_log_mensaje, null, p_nro_cuenta);
    v_retorno.descripcionRespuesta := 'Ocurrio un error';
    v_retorno.error                := 'S';
    RETURN v_retorno;
end;
/

