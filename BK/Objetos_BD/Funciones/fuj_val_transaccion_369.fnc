create or replace function it.FUJ_VAL_TRANSACCION_369(
      p_nro_operacion in varchar2,  -- Nro de referencia de la operacion
      p_nro_caja      in varchar2,  -- Nro de Caja
      p_nro_documento in varchar2, -- Nro. de Documento del Titular del Contrato
      /*p_nombre        in varchar2 default null, */ --nombre de la persona
      p_nro_contrato  in varchar2 default null,  -- Nro.de Contrato

      p_mto_total     in number default null, -- total a cobrar
      p_mto_efectivo  in number default -2, --total efectivo
      p_mto_cheque in number default -2)---, --total cheq nstro bco

return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;        -- Caja
  v_cod_modalidad number(3) := 91;    -- Caja
  v_cod_transaccion number(4) := 369; -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  v_cod_oficina number(3);                   -- oficina de la caja
  v_mto_adeudado      ge_movimientos.monto%Type;

  v_fec_actual        date      := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_estado            number(1);             -- estado de la caja
  v_fec_caja          date;                  -- fecha de la caja
  v_sal_actual        number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques       number(18,2);          -- saldo actual de la caja en cheques
  --
  v_msj_salida    varchar2(8000);        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    varchar2(8000) := null;
  v_cod_persona   ba_personas.cod_persona%type;
  v_nro_contrato  cs_contratos.nro_contrato%type;
  v_cod_moneda    varchar2(3) := pag_gen.FU_OBT_MON_LOCAL;
  v_existe        varchar2(1);
  v_sql           varchar2(1000);
begin
    if p_nro_documento is not null then
       BEGIN
          select fuj_des_campo('NOMBRE',substr(nom_completo,1,100),' '), cod_persona
            into v_det_campos, v_cod_persona
            from ba_personas
           where nro_documento = p_nro_documento;
          If nvl(v_cod_persona,0) = 0 then
            v_cod_respuesta := '001';
            v_msj_respuesta := 'El Nro. de Documento no está registrado';
          End if;            
       END;
    end if;    
    
     if p_nro_contrato is null then
        if v_cod_respuesta = '000' then
           v_sql := replace(fuj_obt_val_posibles(v_cod_transaccion,'NRO_CONTRATO'),'&NRO_DOCUMENTO',p_nro_documento);
           v_det_campos := '[' ||
                            'NRO_CONTRATO~X~'||
                            fuj_pro_val_posibles(v_sql) ||
                            ']';
        end if;
     end if;    


   if p_nro_contrato is not null and p_nro_documento is not null then
    begin
     select 'S', con.cod_moneda
       into v_existe, v_cod_moneda
      from cs_contratos con
     where nro_contrato = p_nro_contrato
       and estado in ('A','M','J');
       --and fec_vencimiento <= v_fec_actual
       /*And Exists (Select 'S'
                    From Cs_Con_Cuotas Cuo
                   Where Con.Nro_Contrato = Cuo.Nro_Contrato
                     And cuo.estado = 'P');*/

    paq_caj.PR_OBT_DEU_CONTRATO(p_nro_contrato, v_mto_adeudado);

    If nvl(v_mto_adeudado,0) = 0 then
      v_cod_respuesta := '002';
      v_msj_respuesta := 'El Contrato no tiene deuda a la fecha';
    End if;

    v_det_campos := v_det_campos ||fuj_des_campo('MTO_ADEUDADO',v_mto_adeudado,null)||
                    fuj_des_campo('COD_MONEDA',v_cod_moneda,null);

    exception
       when no_data_found then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'Nro. de Contrato no existe. ';
       when others then
          v_cod_respuesta := '003';
          v_msj_respuesta := sqlerrm;
    end;

    if v_cod_respuesta = '000' then
       begin
         -- Obtengo los datos de la caja ---
         prj_obt_datos_caja(p_nro_caja,
                            v_cod_moneda,
                            v_cod_oficina,
                            v_fec_caja,
                            v_estado,
                            v_sal_actual,
                            v_sal_cheques);
         if v_estado = -1 then
            v_cod_respuesta := '006'; -- error, no existe registro de caja
            v_msj_respuesta := 'Caja inexistente!!';
         elsif v_estado in (0,2) then  -- error, la caja no esta abierta
            v_cod_respuesta := '003'; -- error
            v_msj_respuesta := 'Caja aun no fue abierta en esta Moneda';
         elsif v_fec_caja <> v_fec_actual then
            v_cod_respuesta := '005'; -- error
            v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
         end if;
       end;
    end if;
    --validar montos
    if v_cod_respuesta = '000' then
      if p_mto_total <= 0 then
         v_cod_respuesta := '009'; -- error
         v_msj_respuesta := 'ERROR: Ingrese correctamente el Total del Cobro.';
      elsif p_mto_total > v_mto_adeudado then
         v_cod_respuesta := '010'; -- error
         v_msj_respuesta := 'ERROR: Total a Cobrar no puede ser mayor al Monto Adeudado.';
      elsif p_mto_efectivo > p_mto_total then
         v_cod_respuesta := '010'; -- error
         v_msj_respuesta := 'ERROR: Total de Efectivo no puede ser mayor al Total a Cobrar.';
      elsif p_mto_cheque > p_mto_total then
         v_cod_respuesta := '011'; -- error
         v_msj_respuesta := 'ERROR: Total de Cheque no puede ser mayor al Total a Cobrar.';
      elsif nvl(p_mto_efectivo,0) + nvl(p_mto_cheque,0) > p_mto_total then
         v_cod_respuesta := '015'; -- error
         v_msj_respuesta := 'ERROR: Montos detallados superan el Total a Cobrar.';
      end if;
    end if;
  end if;

 /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_369;
/

