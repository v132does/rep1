create or replace function it.FUJ_VAL_TRANSACCION_226(
      p_nro_operacion in varchar2,              --Nro de referencia de la operacion
      p_nro_caja      in varchar2,              --Nro de Caja
      p_nro_ticket    in varchar2,              --Campo1
      p_mto_total     in number default null)   --Total a cobrar

return VARCHAR2 is
  --
  v_msj_salida       varchar2(8000);         -- mensaje final retornado
  v_cod_respuesta    varchar2(03) := '000';  -- sin errores
  v_msj_respuesta    varchar2(4000) := 'OK'; -- sin errores
  v_can_campos       number(3) := 0;         -- cantidad de campos
  v_det_campos       varchar2(8000) := null;

  v_cod_modulo       number(3) := 9;    -- Caja
  v_fec_actual       date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_cod_oficina      number(3);             -- oficina de la caja
  v_estado           number(1);             -- estado de la caja
  v_fec_caja         date;                  -- fecha de la caja
  v_sal_actual       number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques      number(18,2);          -- saldo actual de la caja en cheques

  v_cod_servicio     number(3) := fug_obt_pardinamico('COD_SER_SOFIA_TLE'); -- este es el nro del servicio
  v_for_campo1       ge_cob_ser_parametros.for_campo1%type;    -- Formato
  v_val_campo1       ge_cob_ser_parametros.val_campo1%type;    -- Si valida el formato
  v_tip_servicio     ge_cob_ser_parametros.tip_servicio%type;  -- Tipo de Servicio
  v_ruc_agente1      varchar2(100);
  v_nom_agente1      varchar2(100);
  v_tip_agente1      varchar2(5);
  v_ruc_agente2      varchar2(100);
  v_nom_agente2      varchar2(100);
  v_tip_agente2      varchar2(5);
  v_tic_mto_total    number;
  v_cod_error        varchar2(200);         -- Error al validar el formato
  v_nro_cuenta       varchar2(20);          -- Nro de cuenta definido en el servicio
  v_cod_moneda       varchar2(3);           -- Mondeda de la cuenta del servicio

begin
  if v_cod_servicio is null then
     v_cod_respuesta := '010';
     v_msj_respuesta := 'No esta definido en GE_PAR_DINAMICOS el parametro COD_SER_SOFIA_TLE';
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
     if p_nro_ticket is null then
        v_cod_respuesta := '061';
        v_msj_respuesta := 'Ingrese el Nro de Boleta';
     else
        pag_Ser.lp_val_referencia(p_nro_ticket,v_for_campo1,v_val_campo1);
        if pag_ser.fu_obt_error(v_cod_error,v_msj_respuesta) then
           v_cod_respuesta :='062';
        else
           if nvl(p_mto_total,0) = 0 then
              v_msj_respuesta := pag_dna.fu_pro_dna_ticket(v_tip_servicio,
                                                           'Q',
                                                           trim(to_char(to_number(p_nro_caja),'000')),
                                                           p_nro_operacion,
                                                           p_nro_ticket,
                                                           v_ruc_agente1,
                                                           v_nom_agente1,
                                                           v_tip_agente1,
                                                           v_ruc_agente2,
                                                           v_nom_agente2,
                                                           v_tip_agente2,
                                                           v_tic_mto_total);
              if v_msj_respuesta not like '00-%' then
                 -- hay error
                 v_cod_respuesta := '063';
                 v_det_campos := v_det_campos || fuj_des_campo('RUC_AGENTE1',null,null);
                 v_det_campos := v_det_campos || fuj_des_campo('NOM_AGENTE1',null,null);
                 v_det_campos := v_det_campos || fuj_des_campo('RUC_AGENTE2',null,null);
                 v_det_campos := v_det_campos || fuj_des_campo('NOM_AGENTE2',null,null);
              else
                 v_det_campos := v_det_campos || fuj_des_campo('RUC_AGENTE1',v_ruc_agente1,null);
                 v_det_campos := v_det_campos || fuj_des_campo('NOM_AGENTE1',v_nom_agente1,null);
                 v_det_campos := v_det_campos || fuj_des_campo('RUC_AGENTE2',v_ruc_agente2,null);
                 v_det_campos := v_det_campos || fuj_des_campo('NOM_AGENTE2',v_nom_agente2,null);
              end if;
          end if;
        end if;
     end if;
  end if;

  -- Valida el monto
  if v_cod_respuesta = '000' then
    if p_mto_total <> v_tic_mto_total then
      v_cod_respuesta := '064';
      v_msj_respuesta := 'Monto Total no coincide con el monto del Ticket: ' || to_char(v_tic_mto_total);
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
  /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta||'~'||
                  ltrim(to_char(v_can_campos,'000'))||'~'||
                  v_det_campos;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION_226;
/

