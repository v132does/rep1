create or replace function it.FUJ_VAL_TRANSACCION_218(
      p_nro_operacion in varchar2,  -- Nro de referencia de la operacion
      p_nro_caja      in varchar2,  -- Nro de Caja
      p_cod_telegrama  in number,  -- Codigo de servicio
      p_mto_efectivo  in number default -2, --total efectivo
      p_nro_che_nstro in varchar2 default null,  --nro cheq ntro bco
      p_mto_che_nstro in number default -2, --total cheq nstro bco
      -- Agregado para detalle de cheques, si es uno solo,(de despliegue x defecto)
      p_tip_retencion in number default null, --retencion
      p_nro_cheque    in varchar2 DEFAULT NULL,  -- numero de cheque
      p_mto_cheque    in number default -2,  -- total de cheq 24 hs     
      p_cod_banco     in varchar2 DEFAULT NULL)  -- codigo del banco
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo number(3) := 9;        -- Caja
  v_cod_modalidad number(3) := 91;    -- Caja
  v_cod_transaccion number(4) := 218; -- cod de transaccion
  v_cod_usuario varchar2(10) := upper(user); --usuario
  v_cod_oficina number(3);                   -- oficina de la caja

  v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
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
  -- Contenedor de la lista de valores a devolver
  v_val_posibles  varchar2(3000) := null;
  v_sal_multa     number(18,2)   := 0;

  v_cod_moneda    varchar2(3);

  v_nro_cta_mjt          varchar2(15) := '1020448'; -- cuenta del ministerio de just. trabajo 
  v_existe               varchar2(1);
  v_error number;
begin
  if p_cod_telegrama is not null then
    begin
      Select fuj_des_campo('NOM_CLIENTE',b.nom_completo,null)||
             fuj_des_campo('COD_MONEDA',a.cod_moneda,null),
             cod_moneda
        into v_det_campos, v_cod_moneda
        from ba_personas b, ge_telegramas a
       where a.cod_telegrama = p_cod_telegrama
         and a.cod_persona = b.cod_persona;
               
      select sum(nvl(b.sal_multa,0)) 
        into v_sal_multa
        from cc_che_devueltos b, ge_telegramas_det a
       where a.nro_cuenta = b.nro_cuenta
         and a.nro_cheque = b.nro_cheque
         and a.fecha = b.fecha
         and a.hora = b.hora
         and a.cod_telegrama = p_cod_telegrama;
      if v_sal_multa <= 0 then
         v_cod_respuesta := '002';
          v_msj_respuesta := 'Telegrama no registra Multa Pendiente';
      end if;    
    exception
       when no_data_found then
          v_cod_respuesta := '002';
          v_msj_respuesta := 'Telegrama no identificado';
          v_det_campos := fuj_des_campo('NOM_CLIENTE',null,null)||
                          fuj_des_campo('COD_MONEDA',null,null);
       when others then
          v_cod_respuesta := '003';
          v_msj_respuesta := sqlerrm;
          v_det_campos := fuj_des_campo('NOM_CLIENTE',null,null)||
                          fuj_des_campo('COD_MONEDA',null,null);
    end;
    if v_cod_respuesta = '000' then
       if v_cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
          -- cambio la cuenta si es usd
          v_nro_cta_mjt := '7030562';
       end if;
       begin
         -- Verifico cuenta de crédito de la empresa de cobro de servicios ---
            pag_cta.pr_obt_cuenta(v_nro_cta_mjt);
   
            v_cod_respuesta := pag_cta.FU_OBT_COD_ERROR;
            v_msj_respuesta := pag_cta.FU_OBT_MSJ_ERROR;
   
            if v_cod_respuesta = 0 then
               v_cod_respuesta := '000';
               v_msj_respuesta := 'OK';
            else
               v_cod_respuesta := '001';
            end if;
   
         -- Obtener moneda de la cuenta ---
            if v_cod_moneda <> pag_cta.FU_OBT_MON_CUENTA then
               v_cod_respuesta := '001';
               v_msj_respuesta := 'Moneda de la cuenta no corresponde al del Telegrama';
            end if;  
            if v_cod_respuesta = '000' then
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
             end if;   
       end;
    end if;
    --validar montos
    if v_cod_respuesta = '000' then
      if v_sal_multa <= 0 then 
         v_cod_respuesta := '009'; -- error
         v_msj_respuesta := 'ERROR: No existe Multa pendiente...';
      elsif p_mto_efectivo > v_sal_multa then
         v_cod_respuesta := '010'; -- error
         v_msj_respuesta := 'ERROR: Total de Efectivo no puede ser mayor al Total a Cobrar.';
      elsif p_mto_che_nstro > v_sal_multa then
         v_cod_respuesta := '011'; -- error
         v_msj_respuesta := 'ERROR: Total de Cheque Nstro. Bco. no puede ser mayor al Total a Cobrar.';
      elsif p_mto_cheque > v_sal_multa then
         v_cod_respuesta := '012'; -- error
         v_msj_respuesta := 'ERROR: Total de Cheques no puede ser mayor al Total a Cobrar.';
      elsif nvl(p_mto_efectivo,0) + nvl(p_mto_che_nstro,0) + nvl(p_mto_cheque,0) > v_sal_multa then
         v_cod_respuesta := '015'; -- error
         v_msj_respuesta := 'ERROR: Montos detallados superan el Total a Cobrar.';
      end if;
    end if;
    v_det_campos := v_det_campos ||
                    fuj_des_campo('TOT_A_COBRAR',ltrim(to_char(v_sal_multa)),null);
    --si no cargo nada mostrar null,sino mantener lo q cargó
    if nvl(p_tip_retencion,0) <= 0 then
      v_det_campos := v_det_campos ||
                      fuj_des_campo('TIP_RETEN',null,null,'I');
    else
      v_det_campos := v_det_campos ||
                      fuj_des_campo('TIP_RETEN',p_tip_retencion,null,'I');
    end if;
    if nvl(p_mto_cheque,0) <= 0 then
      v_det_campos := v_det_campos ||
                      fuj_des_campo('IMP_CHEQUE',null,null,'I');
    else
      v_det_campos := v_det_campos ||
                      fuj_des_campo('IMP_CHEQUE',p_mto_cheque,null,'I');
    end if;
    if nvl(p_mto_che_nstro,0) <= 0 then
      v_det_campos := v_det_campos ||
                      fuj_des_campo('IMP_CHE_NTRO',null,null,'I');
    else
      v_det_campos := v_det_campos ||
                      fuj_des_campo('IMP_CHE_NTRO',p_mto_che_nstro,null,'I');
    end if;
    --si no tiene importes en cheque limpiar
    if nvl(p_mto_cheque,0) <= 0 then
      v_det_campos := v_det_campos ||
           fuj_des_campo('COD_BANCO',null,null,'D');--||fuj_des_campo('NRO_CHEQ',null,null,'D');
    else 
      --si ya no cargó banco
      if p_cod_banco is null then
       v_det_campos := v_det_campos ||
             fuj_des_campo('COD_BANCO',null,null,'I');--||fuj_des_campo('NRO_CHEQ',null,null,'I');
      else
       v_det_campos := v_det_campos ||
           fuj_des_campo('COD_BANCO',p_cod_banco,null,'I');--||fuj_des_campo('NRO_CHEQ',p_nro_cheque,null,'I');
      end if;
    end if;
    --banco
    if v_cod_respuesta = '000' then
       if p_cod_banco is not null then--and p_nro_cheque is not null then
          --determinar si el banco es local o extranjero
          begin
            select '*', v_det_campos || fuj_des_campo('DES_BANCO',descripcion,null,null)
              into v_existe, v_det_campos
             from ge_bancos
             where cod_banco = p_cod_banco
               and estado = 'A'
               and ubicacion = 'L';
             if p_cod_banco = fug_obt_cod_banco then -- nuestro bco
               v_cod_respuesta := '028'; -- error
               v_msj_respuesta := 'ERROR: El Banco no puede ser Nuestro Banco';
             end if; 
          exception
             when no_data_found then
               v_cod_respuesta := '026'; -- error
               v_msj_respuesta := 'ERROR: Codigo de Banco inexistente.';
             when others then
               v_cod_respuesta := '027'; -- error
               v_msj_respuesta := 'ERROR: Codigo de Banco invalido.';
          end;
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
end FUJ_VAL_TRANSACCION_218;
/

