CREATE OR REPLACE FUNCTION IT.FUJ_VAL_TRANSACCION (
      p_nro_operacion in varchar2,   -- Nro de referencia de la operacion
      p_nro_caja in varchar2,        -- Nro de Caja
      p_cod_transaccion in varchar2) -- Codigo de transaccion
return long is
  -- defino por defecto el modulo y modalidad a utilizar
  v_cod_modulo    number(3) := 9;    -- Caja
  v_cod_modalidad number(3) := 91; -- Caja
  v_cod_usuario   varchar2(10) := upper(user); --usuario
  --
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
  --
  v_msj_salida    long;        -- mensaje final retornado
  v_cod_respuesta varchar2(03) := '000'; -- sin errores
  v_msj_respuesta varchar2(4000) := 'OK'; -- sin errores
  v_can_campos    number(3) := 0;        -- cantidad de campos
  v_det_campos    long := null;
  v_saldos        varchar2(1000) := null;
  v_sis_bloqueado varchar2(1);
  v_mon_fuerte    ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_fuerte;
  v_mto_asegurado cj_cajas.mto_asegurado%type;
  v_restringir    varchar2(1);
  v_sal_caja      cj_controles.sal_actual%type;
  v_msj_cajero    varchar2(4000) := null; -- nota para el cajero
  -- CROFP-3: Nuevos datos para FACPOD
  v_tip_control     varchar2(1);
  v_cod_facultad    varchar2(4);
  v_ser_fir_externo varchar2(1000);
  v_nro_ord_importe varchar2(3);
  v_cod_opcion        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC');
  v_cod_cus_opcion    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_OPC_CUSTOM');
  v_cod_cam_opcion    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAJ_COD_CAM_OPCION');

  -- Cursor de los campos a desplegar por la transaccion
  Cursor campos is Select '['||
                          cod_campo||'~'||
                          tip_campo||'~'||
                          ltrim(to_char(lon_campo,'999'))||'~'||
                          ltrim(to_char(lon_despliegue,'99'))||'~'||
                          ltrim(to_char(nro_linea,'99'))||'~'||
                          ltrim(to_char(nro_columna,'99'))||'~'||
                          nvl(formato,'X')||'~'||
                          alineacion||'~'||
                          nvl(etiqueta,'X')||'~'||
                          ltrim(to_char(nro_lin_etiqueta,'00'))||'~'||
                          ltrim(to_char(nro_col_etiqueta,'00'))||'~' v_parte_01,
                          nvl(val_defecto,'X') v_val_defecto,
                          replace(val_posibles,'&NRO_CAJA',P_NRO_CAJA) v_val_posibles,
                          '~'||tip_dato||'~'||
                          validado||'~'||
                          nvl(ayuda,'X')||'~'||
                          tip_despliegue||'~'||
                          nvl(val_minimo,'X')||'~'||
                          nvl(val_maximo,'X')||']'  v_parte_02
                     from ge_tra_campos
                    where cod_modulo = v_cod_modulo
                      and cod_modalidad = v_cod_modalidad
                      and cod_transaccion = to_number(p_cod_transaccion)
               order by nro_orden;
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=9; end;
  /* Procedimiento para validar la transaccion y el permiso del usuario a la misma,
     para despues armar la respuesta con los campos a desplegar en pantalla */
  v_msj_respuesta := fug_obt_des_transaccion(v_cod_modulo,v_cod_modalidad,p_cod_transaccion);
  if v_msj_respuesta = 'Transaccion inexistente en el Sistema' or
     v_msj_respuesta like 'ERROR%' then
     v_cod_respuesta := '001'; -- Error por codigo de transaccion inexistente
  else
     select sis_bloqueado
       into v_sis_bloqueado
       from ge_par_generales;
     if v_sis_bloqueado = 'S' then
        v_cod_respuesta := '004';  -- Sistema bloqueado
        v_msj_respuesta := 'Sistema bloqueado. No puede ingresar a esta opción!';
     elsif fuj_ver_permiso_usuario(v_cod_usuario,v_cod_modulo,v_cod_modalidad, p_cod_transaccion) = 'N' then
        v_cod_respuesta := '002';  -- Usuario no tiene permiso
        v_msj_respuesta := 'Usuario no tiene permiso a esta transaccion';
     else
        -- Esta todo ok, se arma los campos ---
        v_can_campos := 0;
        for cp in campos loop
          v_det_campos := v_det_campos || cp.v_parte_01;
          if cp.v_val_defecto = 'SQL' then -- ejecutara el sql de valores posibles para su valor por defecto
             v_det_campos := v_det_campos ||replace(fuj_pro_val_posibles(cp.v_val_posibles,'N'),'#','')||'~';
          else
             v_det_campos := v_det_campos || cp.v_val_defecto ||'~';
          end if;
          v_det_campos := v_det_campos || fuj_pro_val_posibles(cp.v_val_posibles);
          v_det_campos := v_det_campos || cp.v_parte_02;
          v_can_campos := v_can_campos + 1;
        end loop;
        if v_can_campos = 0 then
           v_cod_respuesta := '004';
           v_msj_respuesta := 'Transaccion no definida en el Sistema.';
        end if;

     end if;
  end if;
  -- armo finalmente los datos, si hubo o no errores
  if v_cod_respuesta <> '000' then
     -- Hubo algun error, se arma solo el codigo y mensaje de error
     v_msj_salida := p_nro_operacion||'~'||
                     v_cod_respuesta||'~'||
                     v_msj_respuesta;
  else
    --verificar saldos vs monto asegurado
    select mto_asegurado
      into v_mto_asegurado
      from cj_cajas
     where nro_caja = to_number(p_nro_caja);
    --sumar los saldos de la caja
    select sum(pag_gen.FU_CON_MON_A_MONEDA(a.cod_moneda, v_mon_fuerte, a.sal_actual))
      into v_sal_caja
      from cj_controles a
     where nro_caja = to_number(p_nro_caja)
       and fecha = v_fec_actual;
     --si tiene monto asegurado controlar, salvo para reversión y traslado de saldos
     if p_cod_transaccion not in (200, 240) then
       if nvl(v_mto_asegurado,0) > 0 then  
         v_restringir := fug_obt_pardinamico('MSJ_MTO_MAX_RESTRICTIVO',9,91,null,null);   
         if nvl(v_sal_caja,0) > v_mto_asegurado then
           if v_restringir = 'S' then
             --msj de error
             v_cod_respuesta := '005';
             v_msj_respuesta := '!Saldo Total en Caja: '||v_sal_caja||' '||v_mon_fuerte||' supera al Monto Asegurado. Debe transferir al Tesoro.';
             v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 v_msj_respuesta;
/*           else
             --msj informativo
             v_cod_respuesta := '000';
             v_msj_respuesta := 'Saldo Total en Caja de '||v_sal_caja||' '||v_mon_fuerte||' supera al Monto Asegurado.';
             v_msj_salida := p_nro_operacion||'~'||
                 v_cod_respuesta||'~'||
                 v_msj_respuesta;*/
           end if;
         end if;
       end if;   
     end if;
     if v_cod_respuesta = '000' then
       -- obtengo los saldos en efectivo en las dos monedas principales
       begin
          select a.cod_mon_local||'~'||              -- Moneda local
                 to_char(nvl(b.sal_actual,0))||'~'|| -- Saldo en moneda local
                 a.cod_mon_fuerte||'~'||             -- Moneda extranjera
                 to_char(nvl(c.sal_actual,0))||'~'   -- saldo moneda extranjera
            into v_saldos
            from cj_controles c, cj_controles b, ge_par_generales a
           where b.cod_moneda(+) = a.cod_mon_local
             and b.nro_caja(+) = to_number(p_nro_caja)
             and b.fecha(+) = v_fec_actual
             and c.cod_moneda(+) = a.cod_mon_fuerte
             and c.nro_caja(+) = to_number(p_nro_caja)
             and c.fecha(+) = v_fec_actual;
       exception
          when others then
             v_saldos := null;
       end;
       v_msj_cajero := fuj_obt_not_cajero(p_nro_caja);
       if v_msj_cajero is not null then
          -- se fuerza un codigo de error para que el cajero lea la nota y luego continue
          
          v_cod_respuesta := '009';
          v_msj_respuesta := v_msj_cajero;
       end if;   
	   -- CROFP-3: Busco los datos de Tipo de Control y Codigo de Facultad para FACPOD.
       if v_cod_respuesta = '000' then
          v_tip_control := '';
          v_cod_facultad := '';
          prg_obt_dat_con_firmas(v_cod_modulo,v_cod_modalidad,p_cod_transaccion,
                                 v_tip_control, v_cod_facultad, v_ser_fir_externo, v_nro_ord_importe);
          v_saldos := v_saldos||v_tip_control||'~'||v_cod_facultad||'~'||v_ser_fir_externo||'~'||v_nro_ord_importe||'~';
          v_saldos := v_saldos||'{Opcion:'||v_cod_opcion||'~'||v_cod_cus_opcion||'~'||v_cod_cam_opcion||'}~';
       end if; 
       -- No hubo errores, se devuelven los campos a desplegar
       v_msj_salida := p_nro_operacion||'~'||
                       v_cod_respuesta||'~'||
                       v_msj_respuesta||'~'||
                       v_saldos||  -- agrego los saldos
                       ltrim(to_char(v_can_campos,'000'))||'~'||
                       v_det_campos;
     end if;
     -- CROFP-3: Se cambia el ELSE para que tome los casos dentro del anterior IF.-
	 if v_cod_respuesta <> '000' then
       -- Hubo algun error, se arma solo el codigo y mensaje de error
       v_msj_salida := p_nro_operacion||'~'||
                       v_cod_respuesta||'~'||
                       v_msj_respuesta;
     end if;
  end if;
  return(v_msj_salida);
end FUJ_VAL_TRANSACCION;
/
