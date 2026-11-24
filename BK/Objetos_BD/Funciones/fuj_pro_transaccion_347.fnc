create or replace function it.FUJ_PRO_TRANSACCION_347(
      p_nro_operacion in varchar2,---------------- Nro de referencia de la operacion
      p_nro_caja      in varchar2,---------------- Nro de Caja
      p_cod_ente      in number,  ---------------- Ente
      p_orden         in number,
      p_nro_recibo    in number)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo             number(3) := 9;------- Caja
  v_cod_modalidad          number(3) := 91;------ Caja
  v_cod_transaccion        number(4) := 347;----- transaccion
  v_cod_usuario            varchar2(10) := upper(user);-- Usuario
  v_rubro_contable ge_parametros.parametro%type := fug_obt_parentes(p_cod_ente, 'COD_RUB_PPROV');
  v_cta_debito             varchar2(15) := fug_obt_parentes(p_cod_ente, 'CTA_DEB_PPROV');
  -- Datos de la caja
  v_fec_actual             date := pag_cal.fu_obt_fec_actual(v_cod_modulo);-- Fecha de hoy
  v_hor_actual             varchar2(08) := to_char(sysdate,'HH24:MI:SS');---- Hora actual
  v_cod_oficina            number(3);------------ Codigo de oficina
  v_estado                 number(1);------------ estado de la caja
  v_fec_caja               date;----------------- Fecha de la caja
  v_sal_actual             number(18,2);--------- Saldo actual de la caja en efectivo
  v_sal_cheques            number(18,2);--------- Saldo actual de la caja en cheques
  -- Datos de salida
  v_msj_salida             varchar2(8000);------- Mensaje final retornado
  v_cod_respuesta          varchar2(03) := '000';-- Sin errores
  v_msj_respuesta          varchar2(1000) := 'Operacion Confirmada';-- Sin errores
  -- datos de la operacion convertidos
  v_tipo                   varchar2(01) := 'C';-- Credito para la caja (egreso)
  v_cdmoneda               varchar2(3);---------- Moneda del Rubro
  v_nro_secuencia          number(3) := 0;------- Secuencia del mov.
  v_cod_moneda             varchar2(4);
  v_mto_pago               number(18,2);
  -- Registro de movimientos diarios
  R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
  -- Procedimiento interno para generar movimiento y act. de control de caja
  procedure lp_gen_transaccion  is
  begin
    -- Actualizo el control de caja
    update cj_controles
      set sal_actual = nvl(sal_actual,0) - nvl(v_mto_pago,0),
      tot_creditos = nvl(tot_creditos,0) + nvl(v_mto_pago,0),
      can_creditos = nvl(can_creditos,0) + decode(v_mto_pago,0,0,1),
      estado = 1 -- abierto
    where nro_caja = to_number(p_nro_caja)
      and cod_moneda = v_cod_moneda
      and fecha = v_fec_caja;
    v_nro_secuencia := 0;
    -- genero el movimiento por el egreso en efectivo
    v_nro_secuencia := v_nro_secuencia + 1;
    insert into cj_movimientos
      (fecha, hora, cod_usuario, nro_secuencia,
      cod_tra_padre, cod_mod_padre, cod_mad_padre,
      cod_oficina, cod_moneda, nro_caja,
      nro_documento, nro_cuenta, monto, tip_monto, tipo, cod_rubro,cod_ofi_rubro)
    values
      (v_fec_actual, v_hor_actual, v_cod_usuario, v_nro_secuencia, -- secuencia 1
      v_cod_transaccion, v_cod_modulo, v_cod_modalidad,
      v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
      nvl(p_nro_recibo, p_nro_operacion), null, v_mto_pago,'E' /* efectivo */, v_tipo, v_rubro_contable,v_cod_oficina); /* es credito */
  end lp_gen_transaccion;
  --
begin
  -- Inicializacion de la aplicacion y el modulo
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=v_cod_modulo; end;
  -- Valido la moneda
  if p_cod_ente is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Codigo del Ente Pagador.'; 
  elsif p_orden is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Orden.';
  end if;  
  begin
     SELECT monto, cod_moneda
       INTO v_mto_pago, v_cod_moneda
     FROM   ge_pag_proveedores
     WHERE  estado IN ('C','R')
     AND    for_pago = 'E'
     AND    nro_orden = p_orden
     and    cod_ente  = p_cod_ente
     AND  ((fug_obt_parentes(p_cod_ente, 'PAG_FAC_ATRASADA') ='S' AND trunc(nvl(fec_pago,sysdate)) <= trunc(sysdate)) OR
           (fug_obt_parentes(p_cod_ente, 'PAG_FAC_ATRASADA') ='N' AND trunc(nvl(fec_pago,sysdate)) = trunc(sysdate)))
     AND FUG_OBT_OFI_USUARIO(COD_USU_OPERADOR) = FUG_OBT_OFI_USUARIO(USER)
     AND FUE_OBT_PER_ENTE(P_COD_ENTE) not in (select cod_persona 
                                        from ge_par_generales);
     
  exception 
     when no_data_found then
        v_cod_respuesta := '002'; -- error
        v_msj_respuesta := 'ERROR: No se encontraron datos para el pago.';
     when others then
        v_cod_respuesta := '003'; -- error
        v_msj_respuesta := 'ERROR: '|| sqlerrm;
  end;
  if v_cod_respuesta = '000' then -- sin errores    
      if v_cod_moneda is null then
        v_cod_respuesta := '002'; -- error
        v_msj_respuesta := 'ERROR: Ingrese la Moneda de la Operacion.';
      elsif v_mto_pago is null or v_mto_pago < 0 then
        v_cod_respuesta := '003'; -- error
        v_msj_respuesta := 'ERROR: Ingrese el importe en Cheques.';
      elsif v_rubro_contable is null then
        v_cod_respuesta := '004'; -- error
        v_msj_respuesta := 'ERROR: No se definió Rubro Contable.';
      else
        -- Valido la moneda ingresada
        prj_val_moneda(v_cod_moneda, v_cod_respuesta,v_msj_respuesta);
      end if;
  end if;
  if v_cod_respuesta = '000' then -- sin errores
    -- Verifico la duplicacion del registro
    prj_val_duplicacion(p_nro_caja,
    v_cod_transaccion,
    v_cod_moneda,
    p_nro_operacion,
    v_cod_respuesta,
    v_msj_respuesta);
    if v_cod_respuesta = '000' then -- sino hubo problemas, veo la caja
      -- Obtengo los datos de la caja ---------------------------------------
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
      elsif v_estado in (0,2) then
        v_cod_respuesta := '004'; -- error
        v_msj_respuesta := 'Realice la Apertura de Caja previamente';
      elsif v_fec_caja <> v_fec_actual then
         v_cod_respuesta := '005'; -- error
         v_msj_respuesta := 'Caja no fue habilitada el dia de hoy';
  /*    elsif v_sal_actual < v_mto_efectivo then
        v_cod_respuesta := '006'; -- error
        v_msj_respuesta := 'Caja no tiene saldo en Efectivo para esta Operacion';*/
  /*    elsif v_sal_cheques < v_mto_cheque then
        v_cod_respuesta := '006'; -- error
        v_msj_respuesta := 'Caja no tiene saldo en Cheques para esta Operacion';*/
      end if;
    end if;
    if v_cod_respuesta = '000' then
      -- verifico los decimales del importe en cheques
      v_msj_respuesta := fuj_val_importe(v_tipo, 'E',v_cod_moneda,v_mto_pago);
    end if;
    if v_cod_respuesta = '000' then
      begin
        -- Acualizo la cuenta con el efectivo
        if v_mto_pago > 0 then
          -- Aumento la secuencia
          v_nro_secuencia         := v_nro_secuencia + 1;
          -- Carga los parametros de movimientos de efectivo
          r_gmovi.cod_modulo      := v_cod_modulo;
          r_gmovi.cod_modalidad   := v_cod_modalidad;
          r_gmovi.cod_oficina     := v_cod_oficina;
          r_gmovi.nro_cuenta      := null;
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hor_actual;
          r_gmovi.fecha           := v_fec_actual;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.fec_valor       := v_fec_actual;
          r_gmovi.cod_tra_padre   := v_cod_transaccion;
          r_gmovi.cod_mod_padre   := v_cod_modulo;
          r_gmovi.cod_mad_padre   := v_cod_modalidad;
          r_gmovi.cod_transaccion := v_cod_transaccion;
          r_gmovi.monto           := v_mto_pago;
          r_gmovi.nro_documento   := nvl(p_nro_recibo,p_nro_operacion);
          r_gmovi.nro_documento2  := to_number(p_orden);--orden de pago
          r_gmovi.nro_documento3  := p_cod_ente;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := v_cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Orden nro. '||p_orden;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := to_number(p_nro_caja);
          r_gmovi.cod_rubro       := null;
          if v_rubro_contable is not null then
            r_gmovi.tip_mov_rubro   := 'D'; --DEBITO
            r_gmovi.cod_rubro       := v_rubro_contable;
          elsif v_cta_debito is not null then
            pag_cta.PR_ACT_OPERACION(v_cta_debito,
                                     v_hor_actual,
                                     'D',
                                     v_cod_moneda,
                                     v_mto_pago,
                                     v_cod_transaccion,
                                     503,nvl(p_nro_recibo, p_nro_operacion),null,
                                     v_cod_oficina,9,91,null,null,'Pago Prov',
                                     'N',v_nro_secuencia,v_fec_actual);
            if pag_cta.G_COD_ERROR <> 0 then
              v_msj_respuesta := pag_cta.G_MSJ_ERROR;
              v_cod_respuesta := '008';                                                  
            end if;                         
          else
              v_msj_respuesta := 'No se tiene definido el Rubro o Cuenta a debitar';
              v_cod_respuesta := '008';               
          end if;  
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
        end if;

        ---
      exception
        when others then
        -- hubo error en la insercion de registros ge_movimientos
        v_msj_respuesta := sqlerrm;
        v_cod_respuesta := '007';
      end;
    end if;
    if v_cod_respuesta = '000' then
      -- no hubo problemas hasta aqui, genero la transaccion en caja
      lp_gen_transaccion();
    end if;
  end if;
  ---
  update ge_pag_proveedores
    set nro_recibo    = nvl(p_nro_recibo, p_nro_operacion),
    estado        = 'N',
    fec_pago      = v_fec_actual,
    usu_insercion = user
  where nro_orden     = p_orden
    and cod_ente      = p_cod_ente;
  if sql%notfound then
    v_msj_respuesta := 'Error al actualizar GE_PAG_PROVEEDORES !!!';
    v_cod_respuesta := '008';
  end if;
  -- mensaje final sino hubo errores
  if v_cod_respuesta = '000' then -- sino hubo problemas, se carga mensaje por defecto
    v_msj_respuesta := 'Operacion confirmada';
  end if;

  /* falta armar el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
  v_cod_respuesta||'~'||
  nvl(v_msj_respuesta,'Operacion confirmada');
  return(v_msj_salida);
end FUJ_PRO_TRANSACCION_347;
/

