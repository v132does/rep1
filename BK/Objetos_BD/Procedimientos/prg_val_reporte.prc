CREATE OR REPLACE PROCEDURE IT.PRG_VAL_REPORTE(P_REPORTE IN VARCHAR2,
                                            P_FILTRO  IN VARCHAR2,
                                            P_MENSAJE OUT VARCHAR2) IS
  v_sentencia           varchar2(4000);
  v_error               varchar2(1000);
BEGIN
  if p_reporte = 'ALCERCDA' then
    v_sentencia := ' Declare V_ESTADO VARCHAR2(1); ' ||
                   'v_cod_modulo             ah_cta_certificados.cod_modulo%type;' ||
                   'v_cod_modalidad          ah_cta_certificados.cod_modalidad%type;' ||
                   'v_cod_moneda             ah_cta_certificados.cod_moneda%type;' ||
                   'v_fec_vencimiento        ah_cta_certificados.fec_vencimiento%type;' ||
                   'v_fec_apertura           ah_cta_certificados.fec_apertura%type;' ||
                   'v_capital                ah_cta_certificados.capital%type;' ||
                   'v_tip_capitalizacion     ah_cta_certificados.tip_capitalizacion%type;' ||
                   'v_cod_oficina            ah_cta_certificados.cod_oficina%type;' ||
                   'v_nro_cuenta             ah_cta_certificados.nro_cuenta%type;' ||
                   'v_tas_personalizada      ah_cta_certificados.tas_personalizada%type;' ||
                   'v_cod_tasa               ah_cta_certificados.cod_tasa%type;' ||
                   'v_aut_pendiente          ah_cta_certificados.aut_pendiente%type;' ||
                   'v_tas_minima             cr_piz_plazos.tas_minima%type;' ||
                   'v_tas_maxima             cr_piz_plazos.tas_maxima%type;' ||
                   'v_tas_interes            cr_piz_plazos.tas_interes%type;' ||
                   'v_val_tasa      ge_tas_fechas.val_tasa%type;' ||
                   'v_fec_vigencia  ge_tas_fechas.fec_vigencia%type;' ||
                   'v_tip_valor     ge_tasas.tip_valor%type;' ||
                   'v_tipo          ge_tasas.tipo%type;' ||
                   'v_aut_tasa      varchar2(1);' ||
                   'v_cod_autorizacion   ge_autorizaciones.cod_autorizacion%type;' ||
                   'v_cod_usu_autorizador ge_autorizaciones.cod_usu_autorizador%type;' ||
                   'v_mensaje             varchar2(4000);' || ' Begin ' ||
                   'select cod_modulo,cod_modalidad,cod_moneda,fec_vencimiento,' ||
                   'fec_apertura, capital, tip_capitalizacion,' ||
                   'cod_oficina,nro_cuenta,tas_personalizada,cod_tasa, aut_pendiente ' ||
                   'into v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_fec_vencimiento,' ||
                   'v_fec_apertura, v_capital, v_tip_capitalizacion,' ||
                   'v_cod_oficina,v_nro_cuenta, v_tas_personalizada, v_cod_tasa, v_aut_pendiente ' ||
                   ' from ah_cta_certificados ' || 'where ' || P_FILTRO || ';';
    v_sentencia := v_sentencia ||

                   'pag_cta.pr_obt_tas_pizarra(v_cod_modulo, v_cod_modalidad, v_cod_moneda,' ||
                   'trunc(v_fec_vencimiento - v_fec_apertura), v_capital, v_tas_minima,' ||
                   'v_tas_maxima, v_tas_interes, v_tip_capitalizacion );';

    v_sentencia := v_sentencia ||
                   'pag_gen.pr_obt_val_tasa(v_cod_modulo, v_cod_modalidad, v_cod_oficina,' ||
                   'v_nro_cuenta, v_cod_moneda, v_capital, v_tas_personalizada, v_cod_tasa, null,' ||
                   'v_fec_apertura, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);' ||
                   'v_aut_tasa := fug_obt_pardinamico(''AUT_TASA'', v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina);';
    v_sentencia := v_sentencia ||
                   'if v_aut_tasa = ''N'' and (v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima) then ' ||
                   'raise_application_error(-20015,' || '''' ||
                   'Tasa fuera de rango de pizarra ' || '''' || ' ); ' ||
                   'elsif v_aut_tasa = ''S'' and ((v_val_tasa < v_tas_minima or v_val_tasa > v_tas_maxima)) then ' ||
                   'if v_aut_pendiente = ''S'' then ' ||
                   'if v_cod_tasa = v_cod_tasa then ' ||
                  --- Verificar si posee autorizacion por cambio de tasa
                   'if v_aut_pendiente != ''N'' then ' ||
                   'pag_aut.PR_OBT_AUT_PENDIENTE(v_nro_cuenta, 100, v_cod_modulo, v_cod_modalidad, v_cod_tasa, v_cod_autorizacion, v_cod_usu_autorizador);' ||
                   'if v_cod_autorizacion is null then ' ||
                   'raise_application_error(-20015,' || '''' ||
                   'Tasa fuera de rango de pizarra ''||v_nro_cuenta);' ||
                   'end if;' || 'end if;' || 'end if;' || 'end if;' ||
                   'end if;' || ' End; ';
    sql_util.ejecute_dml(v_sentencia, v_error);
    if v_error is not null then
      raise_application_error(-20015,'Tasa fuera de rango de pizarra. Verifique.');
      p_mensaje := v_error;
    end if;
  elsif p_reporte in ('CLCHMEFE','CLCHMLFE','CLCHMEV1') then
    v_sentencia := 'declare
      v_can_select number := 0;
      v_can_wf number:= 0;
    begin
      begin
         select count(*)
           into v_can_select
           from cc_che_ger_emitidos,
                cc_chequeras,
                cc_cta_bancarias
          where cc_che_ger_emitidos.nro_cuenta = cc_chequeras.nro_cuenta
            and cc_che_ger_emitidos.nro_cheque between cc_chequeras.nro_che_inicial and cc_chequeras.nro_che_final
            and nvl(cc_che_ger_emitidos.impreso,''N'') = ''N''
            and cc_cta_bancarias.nro_cuenta = cc_chequeras.nro_cuenta
            and cc_chequeras.tipo in (2,4)
            and '|| P_FILTRO;
    if p_reporte in ('CLCHMEFE','CLCHMEV1') then
      v_sentencia := v_sentencia ||' and cc_cta_bancarias.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL';
    else
      v_sentencia := v_sentencia ||' and cc_cta_bancarias.cod_moneda = pag_gen.FU_OBT_MON_LOCAL';
    end if;
      v_sentencia := v_sentencia ||' and not exists (select 1 from ge_movimientos m, ge_pag_proveedores p
                                   where m.cod_mod_padre = 28
                                       and m.cod_mad_padre = 281
                                       and m.cod_tra_padre = 346
                                       and m.nro_documento2 = p.referencia
                                       and m.estado = ''P''
                                       and m.nro_cuenta = cc_che_ger_emitidos.nro_cuenta
                                       and m.nro_documento =  cc_che_ger_emitidos.nro_cheque);
      exception
        when others then
          v_can_select := 0;
      end;

      begin
        SELECT COUNT(*)
          into v_can_wf
          FROM cc_che_ger_emitidos
         WHERE exists (select 1
                         from ge_movimientos m, ge_pag_proveedores p
                        where m.cod_mod_padre = 28
                          and m.cod_mad_padre = 281
                          and m.cod_tra_padre = 346
                          and m.nro_documento2 = p.referencia
                          and m.estado = ''P''
                          and m.nro_cuenta = cc_che_ger_emitidos.nro_cuenta
                          and m.nro_documento =  cc_che_ger_emitidos.nro_cheque)
           and '|| P_FILTRO|| '; '||
       'exception
         when others then
            v_can_wf := 0;
       end;

       if v_can_select = 0 and  v_can_wf > 0 then
          raise_application_error(-20016,''Cheque pendiente de aprobación. Verifique.'');
       elsif v_can_select = 0 and  v_can_wf = 0 then
          raise_application_error(-20017,''No se encuentra cheque pendiente de impresion. Verifique.'');
       end if;
    end;';
    sql_util.ejecute_dml(v_sentencia, v_error);
    if v_error is not null then
      p_mensaje := v_error;
    end if;
  end if;
END;
/
