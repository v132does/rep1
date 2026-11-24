create or replace function it.FUJ_VAL_TRANSACCION_220(
      p_nro_operacion in varchar2,              --Nro de referencia de la operacion
      p_nro_caja      in varchar2,              --Nro de Caja
      p_ruc_despach   in varchar2,              --Campo1
      p_mto_total     in number default null,   --Total a cobrar
      p_mto_efectivo  in number default 0,     --Total efectivo
      p_nro_che_nstro in varchar2 default null, --Nro cheq ntro bco
      p_mto_che_nstro in number default 0,     --Total cheq nstro bco
      -- Agregado para detalle de cheques, si es uno solo,(de despliegue x defecto)
      p_tip_retencion in number default null,   --Tipo de retencion
      p_nro_cheque    in varchar2 default null, --Nro. de cheque
      p_mto_cheque    in number default 0,     --Total de cheq 24 hs
      p_cod_banco     in varchar2 default null) --Codigo del banco
return VARCHAR2 is

  --
  v_msj_salida       varchar2(8000);         -- mensaje final retornado
  v_cod_respuesta    varchar2(03) := '000';  -- sin errores
  v_msj_respuesta    varchar2(4000) := 'OK'; -- sin errores
  v_can_campos       number(3) := 0;         -- cantidad de campos
  v_det_campos       varchar2(8000) := null;

  v_cod_modulo       number(3) := 9;    -- Caja
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy

  v_cod_servicio     number(3) := fug_obt_pardinamico('COD_SER_SOFIA_TID'); -- este es el nro del servicio
  v_for_campo1       ge_cob_ser_parametros.for_campo1%type;    -- Formato
  v_val_campo1       ge_cob_ser_parametros.val_campo1%type;    -- Si valida el formato
  v_tip_servicio     ge_cob_ser_parametros.tip_servicio%type;  -- Tipo de Servicio
  v_nom_importador   varchar2(100);         -- Nombre del Importardor
  v_nom_despachante  varchar2(100);         -- Nombre del Despachante
  v_cod_error        varchar2(200);         -- Error al validar el formato
  v_nro_cuenta       varchar2(20);          -- Nro de cuenta definido en el servicio
  v_cod_moneda       varchar2(3);           -- Mondeda de la cuenta del servicio
  v_cod_oficina      number(3);             -- oficina de la caja
  v_estado           number(1);             -- estado de la caja
  v_fec_caja         date;                  -- fecha de la caja
  v_sal_actual       number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques      number(18,2);          -- saldo actual de la caja en cheques
  v_existe           varchar2(1);
  v_ubi_banco        ge_bancos.ubicacion%type; --P
begin
  if v_cod_servicio is null then
     v_cod_respuesta := '010';
     v_msj_respuesta := 'No esta definido en GE_PAR_DINAMICOS el parametro COD_SER_SOFIA_TID';
  else
     begin
        Select nro_cuenta, for_campo1, val_campo1, tip_servicio
          into v_nro_cuenta, v_for_campo1, v_val_campo1, v_tip_servicio
          from ge_cob_ser_parametros
         where cod_servicio = v_cod_servicio;
     exception
        when no_data_found then
           v_cod_respuesta := '002';
           v_msj_respuesta := 'No existe el Servicio, o no esta habilitado para Caja';
        when others then
           v_cod_respuesta := '003';
           v_msj_respuesta := sqlerrm;
     end;
  end if;
  if v_cod_respuesta = '000' then
     if p_ruc_despach is null then
        -- no se ingreso el valor del ruc del despachante
        v_cod_respuesta := '062';
        v_msj_respuesta := 'Ingrese el RUC del Despachante.';
     else
        pag_Ser.lp_val_referencia(p_ruc_despach,v_for_campo1,v_val_campo1);
        if pag_ser.fu_obt_error(v_cod_error,v_msj_respuesta) then
           v_cod_respuesta :='061';
        else
           null;
           if nvl(p_mto_total,0) = 0 then
              v_msj_respuesta := pag_dna.fu_pro_deposito(v_tip_servicio,
                                              'R',
                                               trim(to_char(to_number(p_nro_caja),'000')),
                                               p_nro_operacion,
                                               null,
                                               p_ruc_despach,
                                               p_mto_total,
                                               v_nom_importador,
                                               v_nom_despachante);
              if v_msj_respuesta not like '00-%' then
                 -- hay error
                 v_cod_respuesta := '099';
                 v_det_campos := v_det_campos || fuj_des_campo('DES_DESPACHANTE','ERROR EN SOFIA',null);
              else
                 v_det_campos := v_det_campos || fuj_des_campo('DES_DESPACHANTE',v_nom_despachante,null);
              end if;
           end if;
        end if;
     end if;
  end if;
  if v_cod_respuesta = '000' then
     begin
        -- Verifico cuenta de crédito de la empresa de cobro de servicios ---
        pag_cta.pr_obt_cuenta(v_nro_cuenta);

        v_cod_respuesta := pag_cta.FU_OBT_COD_ERROR;
        v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;

        if v_cod_respuesta = 0 then
           v_cod_respuesta := '000';
           v_msj_respuesta := 'OK';
        else
           v_cod_respuesta := '001';
           v_msj_respuesta := 'Error al verificar Cuenta Crédito';
        end if;

        -- Obtener moneda de la cuenta ---
        v_cod_moneda := pag_Cta.fu_obt_mon_cuenta;
        v_det_campos := v_det_campos || fuj_des_campo('COD_MONEDA',v_cod_moneda,null);
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
        elsif v_estado in (1,3,4) then -- caja
           null;
        end if;
     end;
  end if;
  --validar montos
  if v_cod_respuesta = '000' then
     if p_mto_total <= 0 then
        v_cod_respuesta := '009'; -- error
        v_msj_respuesta := 'ERROR: Ingrese correctamente el Total del Cobro.';
     elsif p_mto_efectivo > p_mto_total then
        v_cod_respuesta := '010'; -- error
        v_msj_respuesta := 'ERROR: Total de Efectivo no puede ser mayor al Total a Cobrar.';
     elsif p_mto_che_nstro > p_mto_total then
        v_cod_respuesta := '011'; -- error
        v_msj_respuesta := 'ERROR: Total de Cheque Nstro. Bco. no puede ser mayor al Total a Cobrar.';
     elsif p_mto_cheque > p_mto_total then
        v_cod_respuesta := '012'; -- error
        v_msj_respuesta := 'ERROR: Total de Cheques no puede ser mayor al Total a Cobrar.';
     elsif nvl(p_mto_efectivo,0) + nvl(p_mto_che_nstro,0) + nvl(p_mto_cheque,0) > p_mto_total then
        v_cod_respuesta := '015'; -- error
        v_msj_respuesta := 'ERROR: Montos detallados superan el Total a Cobrar.';
     end if;
  end if;
  if v_cod_respuesta = '000' then
     if nvl(p_mto_che_nstro,0) <> 0 and p_nro_che_nstro is null then
        v_cod_respuesta := '016'; -- error
        v_msj_respuesta := 'Si tiene desglose de Cheq.Ntro Banco se debe cargar el Nro de Cheque.';
     end if;
     if nvl(p_mto_cheque,0) <> 0 and nvl(p_tip_retencion,0) <= 0 then
        v_cod_respuesta := '016'; -- error
        v_msj_respuesta := 'Si tiene desglose de Cheq.Otros Bancos se debe cargar Tipo de Retencion';
     end if;
    --si no tiene importes en cheque limpiar
     if nvl(p_tip_retencion,0) > 1 then
       v_det_campos := v_det_campos ||
            fuj_des_campo('NRO_CHEQ',p_nro_cheque,null,'O')||
            fuj_des_campo('COD_BANCO',p_cod_banco,null,'O');
     else
       v_det_campos := v_det_campos ||
            fuj_des_campo('NRO_CHEQ',p_nro_cheque,null,'I')||
            fuj_des_campo('COD_BANCO',p_cod_banco,null,'I');
     end if;
     if p_cod_banco is not null then
        --determinar si el banco es local o extranjero
        begin
           select ubicacion, '*', v_det_campos || fuj_des_campo('DES_BANCO',descripcion,null,null)
             into v_ubi_banco, v_existe, v_det_campos
             from ge_bancos
            where cod_banco = p_cod_banco
              and estado = 'A';
           if p_cod_banco = fug_obt_cod_banco then -- no puede ser nuestro bco
              v_cod_respuesta := '099'; -- error
              v_msj_respuesta := 'ERROR: El cod.de Banco no puede ser Ntro Banco';
           end if;
           if v_ubi_banco <> 'L' then
              v_cod_respuesta := '098'; -- error
              v_msj_respuesta := 'ERROR: El Solo puede ser Banco Local';
           end if;
        exception
           when no_data_found then
              v_cod_respuesta := '026'; -- error
              v_msj_respuesta := 'ERROR: Codigo de Banco inexistente.';
           when others then
              v_cod_respuesta := '027'; -- error
              v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
        end;
     else
        v_det_campos := v_det_campos ||fuj_des_campo('DES_BANCO',null,null,null);
     end if;
  end if;
  /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_220;
/

