CREATE OR REPLACE FUNCTION IT.FUJ_PRO_TRANSACCION_210 (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja      in varchar2,   -- Nro de Caja
      p_nro_boleta    in varchar2 default null)
return VARCHAR2 is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo      number(3) := 9;          -- Caja
  v_cod_modalidad   number(3) := 91;         -- Caja
  v_cod_tra_padre   number(4) := 210;
  v_cod_transaccion number(4) := 210;        -- Transaccion
  --
  v_cod_oficina    number(3);                   -- oficina de la caja
  v_cod_usuario    varchar2(10) := upper(user); -- usuario
  --
  v_fec_actual     date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  v_hor_actual     varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual
  v_estado         number(1);             -- estado de la caja
  v_fec_caja       date;                  -- fecha de la caja
  v_sal_actual     number(18,2);          -- saldo actual de la caja en efectivo
  v_sal_cheques    number(18,2);          -- saldo actual de la caja en cheques
  --
  v_monto          number(18,2);
  --
  v_msj_salida     varchar2(8000);            -- mensaje final retornado
  v_cod_respuesta  varchar2(03) := '000';     -- sin errores
  v_msj_respuesta  varchar2(100) := 'Operacion confirmada'; -- sin errores
  -- datos de la operacion convertidos
  v_tipo           varchar2(01) := 'D';  -- credito para la caja (egreso)
  v_tip_monto      varchar2(01) := 'E';  -- efectivo
  v_nro_boleta           cj_movimientos.nro_documento%type := to_number(p_nro_boleta);
  v_nro_secuencia  number(3) := 0;  -- secuencia del mov.
  r_gmovi                ge_movimientos%rowtype;
  v_cod_moneda     varchar2(3);
  v_cod_ofi_origen number(3);
  v_nro_caj_origen number(3);
  v_cod_usu_origen ba_usuarios.cod_usuario%type;
  --
  v_cod_tra_afecta number(4) := 1211;
  v_caj_afecta     cj_val_transito.nro_caj_afecta%type;
  v_tip_caja       cj_cajas.tipo%type;
  v_tip_caj_origen cj_cajas.tipo%type;
  --
  v_cod_ofi_prosegur cj_cajas.cod_oficina%type;
  v_fec_caj_prosegur cj_controles.fecha%type;
  v_est_prosegur     cj_cajas.estado%type;
  v_sal_act_prosegur cj_controles.sal_actual%type;
  v_sal_che_prosegur cj_controles.sal_che_otr_bco%type;
  -- Procedimiento interno para generar movimiento de transfrencia
  procedure lp_gen_transaccion  is
  begin
    v_tipo := 'D';
    -- Actualizo el control de caja origen
    update cj_controles
       set sal_actual = nvl(sal_actual,0) + nvl(v_monto,0),
           tot_debitos = nvl(tot_debitos,0) + nvl(v_monto,0),
           can_debitos = nvl(can_debitos,0) + 1,
           estado = 1 -- abierto
     where nro_caja = to_number(p_nro_caja)
       and cod_moneda = v_cod_moneda
       and fecha = v_fec_caja;
      -- genero el movimiento para la caja origen
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, cod_rubro, monto, tip_monto, tipo,
          nro_doc_referencia)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 1,
          v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, to_number(p_nro_caja),
          v_nro_boleta,
          substr('OF:'||to_char(v_cod_ofi_origen)||'-'||TO_CHAR(v_nro_caj_origen)||'-'||v_cod_usu_origen,1,15),
          v_monto,v_tip_monto, -- efectivo
          v_tipo, -- es debito
          v_cod_ofi_origen);
  end lp_gen_transaccion;
  --
  -- Procedimiento interno para generar movimiento afecta caja prosegur
  procedure lp_gen_tra_caj_prosegur  is
  begin
      v_tipo := 'C';
      -- Actualizo el control de caja origen
      update cj_controles
         set sal_actual = nvl(sal_actual,0) - nvl(v_monto,0),
             tot_creditos = nvl(tot_creditos,0) + nvl(v_monto,0),
             can_creditos = nvl(can_creditos,0) + 1,
             estado = 1 -- abierto
       where nro_caja = to_number(v_caj_afecta)
         and cod_moneda = v_cod_moneda
         and fecha = v_fec_caj_prosegur;
      -- genero el movimiento para la caja origen
      insert into cj_movimientos
         (fecha, hora, cod_usuario, nro_secuencia,
          cod_tra_padre, cod_mod_padre, cod_mad_padre,
          cod_oficina, cod_moneda, nro_caja,
          nro_documento, cod_rubro, monto, tip_monto, tipo,
          nro_doc_referencia)
      values
         (v_fec_actual, v_hor_actual, v_cod_usuario, 2,
          v_cod_tra_padre, v_cod_modulo, v_cod_modalidad,
          v_cod_oficina, v_cod_moneda, v_caj_afecta,
          v_nro_boleta,
          substr('OF:'||to_char(v_cod_ofi_origen)||'-'||TO_CHAR(v_nro_caj_origen)||'-'||v_cod_usu_origen,1,15),
          v_monto,v_tip_monto, -- efectivo
          v_tipo, -- es credito
          to_number(v_cod_oficina));
  end lp_gen_tra_caj_prosegur;
begin
 -- Inicializacion de la aplicacion y el modulo
 BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=v_cod_modulo; END;
 -- Valido la moneda y el monto de cierre
 if p_nro_boleta is null then
    v_cod_respuesta := '001'; -- error
    v_msj_respuesta := 'ERROR: Ingrese el Nro. de Boleta.';
 end if;
 if v_cod_respuesta = '000' then -- no hubo errores
    begin
      select cod_moneda, monto, a.cod_oficina, nro_caja, a.usu_insercion, a.nro_caj_afecta
        into v_cod_moneda, v_monto, v_cod_ofi_origen, v_nro_caj_origen, v_cod_usu_origen, v_caj_afecta
        from cj_val_transito a,
             ba_usuarios b,
             ba_usuarios c,
             ba_oficinas o
       where b.cod_usuario = a.usu_insercion
         and c.cod_oficina = a.cod_ofi_destino
         and a.nro_documento = to_number(p_nro_boleta)
         and o.cod_oficina = a.cod_ofi_destino
         and a.estado = 'E'
         and c.cod_usuario = user;
    exception
      when no_data_found then
        v_cod_respuesta := '002';
        v_msj_respuesta := 'ERROR: Nro.de Documento no Existe!';
      when others then
        v_cod_respuesta := '003';
        v_msj_respuesta := sqlerrm;
    end;
  end if;

  if v_cod_respuesta = '000' then -- no hubo errores
    v_tip_caja       := nvl(fuj_obt_tip_caja(p_nro_caja),'x');
    v_tip_caj_origen := nvl(fuj_obt_tip_caja(v_nro_caj_origen),'x');
    -- Si la caja es de Tipo P-Prosegur usa la transacción 1210
    if v_tip_caja = 'P' then
      v_cod_transaccion := 1210;
    end if;
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
    end if;
    -- Obtengo los datos de la caja Prosegur -------------------------------------------
    prj_obt_datos_caja(v_caj_afecta,
                       v_cod_moneda,
                       v_cod_ofi_prosegur,
                       v_fec_caj_prosegur,
                       v_est_prosegur,
                       v_sal_act_prosegur,
                       v_sal_che_prosegur,'N');
    if v_est_prosegur = -1 then
          v_cod_respuesta := '006'; -- error, no existe registro de caja
          v_msj_respuesta := 'Caja Nro '||v_caj_afecta||' inexistente!!';
    elsif v_est_prosegur in (0,2) then
          v_cod_respuesta := '004'; -- error
          v_msj_respuesta := 'Se debe realizar la Apertura de Caja Nro'||v_caj_afecta||' previamente';
    elsif v_fec_caj_prosegur <> v_fec_actual then
          v_cod_respuesta := '005'; -- error
          v_msj_respuesta := 'Caja Nro '||v_caj_afecta||'no fue habilitada el dia de hoy';
    end if;
    -- verifico los datos de la caja destino
    If p_nro_boleta is not null then
       if v_cod_respuesta = '000' then
          -- Verifico la duplicacion del registro
          prj_val_duplicacion(p_nro_caja,
                              v_cod_tra_padre,
                              v_cod_moneda,
                              p_nro_boleta,
                              v_cod_respuesta,
                              v_msj_respuesta);
       end if;
    End if;
    if v_cod_respuesta = '000' then
       --if v_msj_respuesta is null then -- valido el efectivo
       --   v_msj_respuesta := fuj_val_importe(v_tipo, 'E',p_cod_moneda,v_monto);
       --end if;
       --if v_msj_respuesta is not null then
       --   v_cod_respuesta := '005';  -- error
       --else
       -- Asigno el nro de caja a los movimientos
       pag_cta.pr_nro_caja(to_number(p_nro_caja));
       -- Acualizo la cuenta con el efectivo depositado
       v_nro_secuencia := 0;
       if v_monto > 0 then
        --generar movimiento
        v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hor_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_ofi_origen;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := v_cod_modulo;--9
        r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
        r_gmovi.nro_caja        := to_number(p_nro_caja);
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.monto           := v_monto;
        r_gmovi.nro_documento   := to_number(v_nro_boleta);
        r_gmovi.nro_documento2  := null; --to_number(p_cod_comercio);
        r_gmovi.nro_documento3  := null; --v_can_cuotas;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := 'Recibir Valores en Transito';
        r_gmovi.referencia      := null; --p_nro_tarjeta;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.nro_cuenta      := null; --v_nro_cuenta;
        r_gmovi.tip_mov_rubro   := NULL;
        --
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);

        --Actualizar Tabla de Valores en Transito--
        update cj_val_transito a
           set a.estado = 'P',  --P-Procesado--
               a.nro_caj_proceso = to_number(p_nro_caja),
               a.fec_proceso = v_fec_actual,
               a.cod_usu_proceso = user
         where a.nro_documento = v_nro_boleta;
       end if;
       --
       /*
       if v_cod_respuesta = '000' then
         -- Movimiento Afecta caja prosegur solo si la caja Origen no es de tipo Prosegur
         if v_monto > 0  and v_tip_caj_origen <> 'P' then
            --generar movimiento
            v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
            --
            r_gmovi.cod_usuario     := v_cod_usuario;
            r_gmovi.hora            := v_hor_actual;
            r_gmovi.fecha           := v_fec_actual;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := v_cod_ofi_origen;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_tra_padre   := v_cod_tra_padre;
            r_gmovi.cod_mod_padre   := v_cod_modulo;--9
            r_gmovi.cod_mad_padre   := v_cod_modalidad;--91
            r_gmovi.nro_caja        := to_number(p_nro_caja);
            r_gmovi.cod_transaccion := v_cod_tra_afecta;
            r_gmovi.monto           := v_monto;
            r_gmovi.nro_documento   := to_number(v_nro_boleta);
            r_gmovi.nro_documento2  := v_caj_afecta; -- Número de caja Prosegur
            r_gmovi.nro_documento3  := v_nro_caj_origen;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Oficina-Caja-Usuario Origen:'||to_char(v_cod_ofi_origen)||'-'||TO_CHAR(v_nro_caj_origen)||'-'||v_cod_usu_origen||
                                       ' Oficina Destino:'||to_char(v_cod_oficina);
            r_gmovi.referencia      := null;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.cod_ofi_origen  := v_cod_oficina;
            r_gmovi.cod_rubro       := null;
            r_gmovi.nro_cuenta      := null;
            r_gmovi.tip_mov_rubro   := null;
            --
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            --
            lp_gen_tra_caj_prosegur;
            --
         end if;
       end if;
       */
       -- Actualizo la cuenta con el cheque depositado plaza local sino hubo errores
       if pag_cta.g_cod_error <> 0 then
         -- actualizacion con problemas
         v_cod_respuesta := ltrim(to_char(pag_cta.g_cod_error,'000'));
         v_msj_respuesta := pag_cta.g_msj_error;
       else -- genero la transaccion en caja
         lp_gen_transaccion();
       end if;
     --end if;
    end if;
 end if;
 /* armo finalmente el mensaje de respuesta */
  v_msj_salida := p_nro_operacion||'~'||
                  v_cod_respuesta||'~'||
                  v_msj_respuesta;
  return(v_msj_salida);
exception
 when others then
     /* armo finalmente el mensaje de respuesta */
     v_msj_salida := p_nro_operacion||'~'||
                     '999'||'~'||
                     sqlerrm;
     return(v_msj_salida);
end FUJ_PRO_TRANSACCION_210;
/

