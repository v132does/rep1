create or replace function it.fug_obt_dat_comp_transi(p_nro_cuenta      in ge_cta_clientes.nro_cuenta%type,
                                                      p_cod_moneda      in ba_monedas.cod_moneda%type,
                                                      p_importe         in varchar2,
                                                      p_fecha           in date,
                                                      p_nro_documento   in ge_movimientos.nro_documento%type,
                                                      p_cod_tip_mensaje in bw_movimientos.cod_tip_mensaje%type,
                                                      p_tip_persona     in varchar2,
                                                      p_tip_confirma    in varchar2 default 'X',
                                                      p_fecha_ge        in ge_movimientos.fecha%type default null,
                                                      p_hora_ge            in ge_movimientos.hora%type default null,
                                                      p_cod_usuario_ge  in ge_movimientos.cod_usuario%type default null,
                                                      p_nro_secuencia_ge   in ge_movimientos.nro_secuencia%type default null)

  return TYP_DETCOMTRAI is
  ----https://itti-digital.atlassian.net/browse/NVB-3811
  MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  v_nrooperacion         varchar2(100);
  v_concepto             varchar2(150);
  v_ctadebito            varchar2(20);
  v_denominacionctadeb   varchar2(150);
  v_desmonedadeb         varchar2(30);
  v_importedeb           number(18, 2);
  v_fechacre             date;
  v_nrotransferencia     varchar2(20);
  v_monedatransf         varchar2(30);
  v_nro_doc_beneficiario varchar2(20);
  v_beneficiario         varchar2(150);
  v_ctacredito           varchar2(35);
  v_importecre           number(18, 2);
  v_codswift             varchar2(20);
  v_entidad              varchar2(100);
  v_fechasolicitud       date;
  v_horasolicitud        varchar2(20);
  v_oficina              varchar2(35);
  v_fecha_1              DATE;
  v_retorno              TYP_DETCOMTRAI := TYP_DETCOMTRAI();
  v_log_mensaje          varchar2(4000);
  v_can_fir_req          integer;
  v_cotizacion           number(18, 2);
  v_codmonedadeb         varchar2(3) := null;
  v_codmonedatransf      varchar2(3) := null;
  v_cod_modulo           ge_cuentas.cod_modulo%type;
  v_cod_modalidad        ge_cuentas.cod_modalidad%type;
  v_cantidad             integer;
  v_existe               varchar2(1);

BEGIN
  BEGIN
    if p_cod_tip_mensaje = '036' then
      begin 
      select distinct b.nro_documento,
                      fue_obt_des_operacion(b.cod_tip_mensaje),
                      t.nro_cuenta,
                      fug_obt_nom_cuenta(t.nro_cuenta),
                      fue_obt_des_moneda(t.cod_moneda),
                      t.monto,
                      t.fec_insercion,
                      t.nro_documento,
                      fue_obt_des_moneda(s.cod_moneda),
                      s.nro_doc_beneficiario,
                      s.nom_beneficiario beneficiario,
                      s.nro_cta_beneficiario,
                      s.monto,
                      --s.cod_swi_pte_beneficiario,
                      --c.descripcion entidad,
                      nvl(s.cod_swi_suc_beneficiario,s.cod_swi_pte_beneficiario),
                      paw_bem.lf_obt_bco_snp_swift(nvl(s.cod_swi_suc_beneficiario,s.cod_swi_pte_beneficiario)),
                      t.fec_insercion,
                      t.hora,
                      t.fec_insercion,
                      fue_obt_des_oficina(t.cod_ofi_origen),
                      t.cotizacion,
                      decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas, 0),
                      t.cod_moneda,
                      s.cod_moneda
        into v_nrooperacion,
             v_concepto,
             v_ctadebito,
             v_denominacionctadeb,
             v_desmonedadeb,
             v_importedeb,
             v_fechacre,
             v_nrotransferencia,
             v_monedatransf,
             v_nro_doc_beneficiario,
             v_beneficiario,
             v_ctacredito,
             v_importecre,
             v_codswift,
             v_entidad,
             v_fechasolicitud,
             v_horasolicitud,
             v_fecha_1,
             v_oficina,
             v_cotizacion,
             v_can_fir_req,
             v_codmonedadeb,
             v_codmonedatransf
        from gv_movimientos        t,
             bw_movimientos        b,
             ge_snp_transferencias s,
             --ge_bancos             c,
             bw_mov_pendientes p
       where t.nro_cuenta = b.nro_cuenta
         and t.monto = b.monto
         and t.nro_documento = b.nro_documento
         and s.nro_referencia = t.nro_documento
         and (s.cod_moneda = t.cod_moneda or s.cod_moneda != t.cod_moneda)
         and (s.monto = t.monto or s.monto != t.monto)
         and s.nro_cta_solicitante = t.nro_cuenta
            --and s.cod_swi_pte_beneficiario = c.cod_swift(+)
         and b.nro_doc_pendiente = p.nro_documento(+)
         and s.observacion = b.observacion
         and b.cod_tip_mensaje = '036'
         and t.cod_moneda = p_cod_moneda
            --and t.monto = p_importe
         and t.fec_insercion >= p_fecha
         and t.fec_insercion < p_fecha + 1
         and t.nro_cuenta = p_nro_cuenta
         and b.nro_documento = p_nro_documento;
      exception 
        when no_data_found then 
          begin
            Select 'S' into v_existe
              from ge_snp_transferencias t
             where t.situacion != 'L'
               and t.nro_referencia = p_nro_documento;
               
               if v_existe = 'S' then
                  v_retorno.descripcionRespuesta := 'Transferencia en proceso'; 
                  v_retorno.nombrerespuesta := 'ERR-TRA-01';
                  v_retorno.error := 'S';
               end if;
               
           exception 
        when no_data_found then     
          v_retorno.descripcionRespuesta := 'No se econtro ningun registro'; 
          v_retorno.error := 'S'; 
          end;
      end;
      
    end if;
    if p_cod_tip_mensaje = '075' and p_tip_confirma = 'X' then
      BEGIN
        select b.nro_documento,
               fue_obt_des_operacion(b.cod_tip_mensaje),
               t.nro_cuenta,
               fug_obt_nom_cuenta(t.nro_cuenta),
               fue_obt_des_moneda(t.cod_moneda),
               t.monto,
               t.fec_insercion,
               t.nro_documento,
               fue_obt_des_moneda(t.cod_moneda),
               s.nro_doc_beneficiario,
               s.nom_beneficiario beneficiario,
               s.nro_cta_beneficiario,
               t.monto,
               --s.cod_swi_pte_beneficiario,
               --c.descripcion entidad,
               nvl(s.cod_swi_suc_beneficiario,s.cod_swi_pte_beneficiario),
               paw_bem.lf_obt_bco_snp_swift(nvl(s.cod_swi_suc_beneficiario,s.cod_swi_pte_beneficiario)),
               t.fec_insercion,
               t.hora,
               t.fec_insercion,
               fue_obt_des_oficina(t.cod_ofi_origen),
               t.cotizacion
          into v_nrooperacion,
               v_concepto,
               v_ctadebito,
               v_denominacionctadeb,
               v_desmonedadeb,
               v_importedeb,
               v_fechacre,
               v_nrotransferencia,
               v_monedatransf,
               v_nro_doc_beneficiario,
               v_beneficiario,
               v_ctacredito,
               v_importecre,
               v_codswift,
               v_entidad,
               v_fechasolicitud,
               v_horasolicitud,
               v_fecha_1,
               v_oficina,
               v_cotizacion
          from gv_movimientos        t,
               bw_movimientos        b,
               ge_snp_transferencias s--,
               --ge_bancos             c
         where t.nro_cuenta = b.nro_cuenta
           and t.nro_documento3 = b.nro_documento
           and s.nro_operacion = t.nro_documento
           and s.cod_moneda = t.cod_moneda
           and s.monto = t.monto
           and s.nro_cta_solicitante = t.nro_cuenta
          -- and s.cod_swi_pte_beneficiario = c.cod_swift(+)
           and b.cod_tip_mensaje = '075'
           and t.cod_moneda = p_cod_moneda
              --and t.monto = p_importe
           and trunc(t.fec_insercion) = p_fecha
           and t.nro_cuenta = p_nro_cuenta
           and t.nro_documento = p_nro_documento;
      exception
        when no_data_found then
          select b.nro_documento,
                 fue_obt_des_operacion(p_cod_tip_mensaje),
                 t.nro_cuenta,
                 fug_obt_nom_cuenta(t.nro_cuenta),
                 fue_obt_des_moneda(t.cod_moneda),
                 t.monto,
                 t.fec_insercion,
                 t.nro_documento,
                 fue_obt_des_moneda(t.cod_moneda),
                 null,
                 null,
                 null,
                 t.monto,
                 null,
                 null,
                 t.fec_insercion,
                 t.hora,
                 t.fec_insercion,
                 fue_obt_des_oficina(t.cod_ofi_origen),
                 t.cotizacion
            into v_nrooperacion,
                 v_concepto,
                 v_ctadebito,
                 v_denominacionctadeb,
                 v_desmonedadeb,
                 v_importedeb,
                 v_fechacre,
                 v_nrotransferencia,
                 v_monedatransf,
                 v_nro_doc_beneficiario,
                 v_beneficiario,
                 v_ctacredito,
                 v_importecre,
                 v_codswift,
                 v_entidad,
                 v_fechasolicitud,
                 v_horasolicitud,
                 v_fecha_1,
                 v_oficina,
                 v_cotizacion
            from gv_movimientos t, bw_movimientos b
           where t.nro_cuenta = b.nro_cuenta
             and t.nro_documento = b.nro_movimiento || b.cod_tip_mensaje
             and t.cod_moneda = p_cod_moneda
                --and t.monto = p_importe
             and trunc(t.fec_insercion) = p_fecha
             and t.nro_cuenta = p_nro_cuenta
             and t.nro_documento = p_nro_documento
             and t.FECHA  = p_fecha_ge
             and t.HORA = p_hora_ge
             and t.COD_USUARIO = p_cod_usuario_ge
             and t.NRO_SECUENCIA = p_nro_secuencia_ge;
      end;
    end if;
    if p_cod_tip_mensaje = '075' and nvl(p_tip_confirma, 'X') = 'P' then

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
          v_retorno.descripcionRespuesta := 'Ocurrio un error 1: ' ||' '|| sqlerrm ;
          v_retorno.error                := 'S';
      end;
      begin
        select p.nro_documento,
               --to_date(p.fec_insercion, 'dd/mm/yyyy'),
               p.fec_insercion,
               to_char(p.fec_insercion, 'hh24:mi:ss'),
               p.nro_cuenta,
               it.fug_obt_des_modal(v_cod_modulo, v_cod_modalidad) tipo_cuenta,
               fue_obt_des_moneda(p.cod_moneda),
               p.monto,
               fue_obt_des_operacion(p.cod_tip_mensaje),
               p.cantidad,
               --to_date(p.dato2, 'dd/mm/yyyy'),
               p.fec_insercion,
               decode(p_tip_persona, 'F', 0, 'J', p.can_aut_requeridas, 0)
          into v_nrooperacion,
               v_fechacre,
               v_horasolicitud,
               v_ctadebito,
               v_denominacionctadeb,
               v_desmonedadeb,
               v_importedeb,
               v_concepto,
               v_cantidad,
               v_fechasolicitud,
               v_can_fir_req
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
          v_retorno.descripcionRespuesta := 'Ocurrio un error 2: ' ||' '|| sqlerrm ;
          v_retorno.error                := 'S';
          v_log_mensaje                  := substr('Ocurrio un error: ' ||
                                               'Importe: ' || p_importe || ' - ' ||
                                               'Fecha: ' || p_fecha || ' - ' ||
                                               'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                               'Nro_documento: ' || p_nro_documento || ' - ' ||
                                               'Error: ' || sqlerrm, 1, 4000);
           prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANSI', v_log_mensaje, null, p_nro_cuenta);
      end;
    end if;
  exception
    when no_data_found then
      v_retorno.descripcionRespuesta := 'No se econtro ningun registro';
      v_retorno.error                := 'S';
    when others then
      v_retorno.descripcionRespuesta := 'Ocurrio un error 3: ' ||' '|| sqlerrm ;
      v_retorno.error                := 'S';
      v_log_mensaje                  := substr('Ocurrio un error: ' ||
                                               'Importe: ' || p_importe || ' - ' ||
                                               'Fecha: ' || p_fecha || ' - ' ||
                                               'Nro_cuenta: ' || p_nro_cuenta || ' - ' ||
                                               'Nro_documento: ' || p_nro_documento || ' - ' ||
                                               'Error: ' || sqlerrm, 1, 4000);
      prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANSI', v_log_mensaje, null, p_nro_cuenta);

  end;

  If nvl(v_retorno.error, 'N') = 'N' then
    v_retorno.error                := 'N';
    v_retorno.nombrerespuesta      := 0;
    v_retorno.descripcionrespuesta := msg_ok;
    v_retorno.nrooperacion         := v_nrooperacion;
    v_retorno.concepto             := v_concepto;
    v_retorno.ctadebito            := v_ctadebito;
    v_retorno.denominacionctadeb   := v_denominacionctadeb;
    v_retorno.desmonedadeb         := v_desmonedadeb;
    v_retorno.importedeb           := v_importedeb;
    v_retorno.fechacre             := v_fechacre;
    v_retorno.nrotransferencia     := v_nrotransferencia;
    v_retorno.monedatransf         := v_monedatransf;
    v_retorno.nrodocbeneficiario   := v_nro_doc_beneficiario;
    v_retorno.beneficiario         := v_beneficiario;
    v_retorno.ctacredito           := v_ctacredito;
    v_retorno.importecre           := v_importecre;
    v_retorno.codswift             := v_codswift;
    v_retorno.cantidad             := v_cantidad;
    v_retorno.fechasolicitud       := v_fechasolicitud;
    v_retorno.horasolicitud        := v_horasolicitud;
    v_retorno.oficina              := v_oficina;
    v_retorno.cantfirreq           := v_can_fir_req;
    v_retorno.cotizacion           := v_cotizacion;
    v_retorno.codmonedadeb         := v_codmonedadeb;
    v_retorno.codmonedatransf      := v_codmonedatransf;
    v_retorno.entidad              := v_entidad;

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
    prg_ins_log_programas('FUG_OBT_DAT_COMP_TRANSI', v_log_mensaje, null, p_nro_cuenta);
    v_retorno.descripcionRespuesta := 'Ocurrio un error 4: ' ||' '|| sqlerrm ;
    v_retorno.error                := 'S';
    RETURN v_retorno;
end;
/
