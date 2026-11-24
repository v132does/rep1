CREATE OR REPLACE PROCEDURE IT."PRL_PRO_OPE_CAM_SIPAP" (P_HORA IN VARCHAR2,
                                                  P_COD_USUARIO IN VARCHAR2,
                                                  P_NRO_OPERACION IN NUMBER,
                                                  P_TIPO  IN VARCHAR2) IS

v_hora              varchar2(08);
PROCEDURE PR_PRO_OPE_COM_SIPAP;
PROCEDURE PR_PRO_OPE_VTA_SIPAP;

FUNCTION LF_OBT_PER_ENTIDAD
return varchar2
 IS
v_cod_persona ge_par_generales.cod_persona%type;
BEGIN
   select cod_persona
   into v_cod_persona
   from ge_par_generales;
   return v_cod_persona;
exception
   when no_data_found then
     raise_application_error(-20000,
     'Parametro general no registrado');
   when too_many_rows then
     raise_application_error(-20000,
     'Parametro general duplicado');
end;

PROCEDURE PR_PRO_OPE_VTA_SIPAP IS
v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_modulo        NUMBER(04);
v_des_modulo        ba_modulos.descripcion%type;
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
--v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 31; -- fijo venta cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
r_rpoca             lc_bol_automaticos_res%rowtype;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_concepto          ge_movimientos.concepto%type;
v_redondeo          number(5);
v_cod_persona       ba_personas.cod_persona%type;
v_nro_cuenta        ge_cuentas.nro_cuenta%type;
v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;
cursor cur_datos is
     --- operaciones de compra y extracciones atm en el extranjero--
   select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
          decode(a.cod_transaccion, 190, b.nro_cuenta, a.nro_cuenta) nro_cuenta, 
          nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
          '_SIPAP'
     from ge_movimientos b, ge_movimientos a
    where a.cod_tra_padre IN (302, 303, 308)  -- proveedores y transferencias sipap
      and a.estado = 'N'
      and a.cod_transaccion in (503, 190)
      and a.monto <> 0
      and b.cod_mad_padre = 455
      and b.estado = 'N'
      and b.cod_transaccion in (602, 196)
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      and b.nro_documento = P_NRO_OPERACION
      AND B.HORA = P_HORA
      AND B.COD_USUARIO = P_COD_USUARIO;


BEGIN
  if cur_datos%isopen then
      close cur_datos;
  end if;
  open cur_datos;
  --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_hora := to_char(sysdate,'HH24:MI:SS');
   --wa:para pk
   v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

  loop
      fetch cur_datos
       into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto, v_nro_cuenta, v_cotizacion,
            v_cod_tra_padre,v_referencia;
      exit when cur_datos%notfound;
      -----------------------------------------------------------
      Select lower(substr(descripcion,1,9))
        into v_des_modulo
        from ba_modulos
       Where cod_modulo = v_cod_modulo;
      --como tambien entran las reversiones, esto es en caso de q estas superen a las operaciones
      IF v_monto >= 0 THEN
         v_cod_modalidad     := 72;
         v_cod_tip_operacion := 31;
         v_concepto          := 'Venta Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'VTA'||v_referencia;
      ELSE
         v_cod_modalidad     := 71;
         v_cod_tip_operacion := 17;
         v_concepto          := 'Compra Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'COM_REV'||v_referencia;
      END IF;
      -----------------------------------------------------------
      begin
       select cod_tip_ope_bcp
         into v_cod_tip_ope_bcp
         from lc_tip_operaciones
        where lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
      exception
       when others then
         if v_cod_tip_operacion = 31 then
            v_cod_tip_ope_bcp := 'B27';
         else
            v_cod_tip_ope_bcp := 'A19';
         end if;
      end;
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
      if v_cod_tra_padre in (303, 388, 486) then
         v_cotizacion := nvl(v_cotizacion, paw_bce.fu_obt_cotizacion(v_cod_moneda, 'V'));
      else
         v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda,v_fec_actual);
      end if;
      v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := round(nvl(v_cotizacion,0) * v_monto,v_redondeo);

      -- Obtiene el código de Persona
      if v_nro_cuenta is not null then
         v_cod_persona := fug_obt_cli_principal (v_nro_cuenta);
      else
         v_cod_persona := lf_obt_per_entidad;
      end if;
      --- genera movimiento ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := v_cod_modalidad;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 942;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := null;
      r_gmovi.monto           := abs(v_monto);
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := abs(v_tot_mon_local);
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      r_gmovi.cod_persona   := v_cod_persona;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      r_rpoca.cod_modalidad := v_cod_modalidad;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 942;
      r_rpoca.cod_transaccion := 942;
      r_rpoca.nro_documento   := v_nro_operacion;
      r_rpoca.monto           := abs(v_monto);
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := v_cod_modalidad;
      r_rpoca.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := abs(v_tot_mon_local);
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.cod_bco_central    := v_cod_tip_ope_bcp;
      r_rpoca.referencia         := v_referencia;
      --g_nro_cuenta               := v_nro_cuenta;
      --DYDMR-2477 ITGF - Diferencia Posición de Cambios del 18.09.2015 SC 20865
      --pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := v_cod_persona;
      r_gmovi.monto           := 0;
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
      -- fm 22/04 dydmr-1741
      /*v_hora := to_char(sysdate,'HH24:MI:SS');
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');*/

      if v_cod_modalidad = 72 then  /* ES UNA VENTA */
         --actualiza la posicion
         update lc_posiciones set
                mto_vta_nef_act = nvl(mto_vta_nef_act,0) + v_monto,
                mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + v_tot_mon_local
         where cod_tip_ope_bcp  = v_cod_tip_ope_bcp
           and cod_moneda       = v_cod_moneda
           and cod_ofi_cambio   = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
        --inserta posicion si no existe
        if sql%notfound then
           insert into lc_posiciones
               (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                mto_vta_nef_act, mto_vta_nef_loc)
           values
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), v_monto,v_tot_mon_local);
        end if;
      else --es una compra
        --actualiza la posicion
        update lc_posiciones set
               mto_com_nef_act = nvl(mto_com_nef_act,0) + abs(v_monto),
               mto_com_nef_loc = nvl(mto_com_nef_loc,0) + abs(v_tot_mon_local)
         where cod_tip_ope_bcp = v_cod_tip_ope_bcp
           and cod_moneda      = v_cod_moneda
           and cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
        --inserta posicion si no existe
        if sql%notfound then
           insert into lc_posiciones
               (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                mto_com_nef_act, mto_com_nef_loc)
           values
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), abs(v_monto), abs(v_tot_mon_local));
        end if;
      end if;
  end loop;
  if cur_datos%isopen then
     close cur_datos;
  end if;
    insert into BA_COD_REFERENCIAS
  (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA)
  values
  ('DAT_OPE_RELACION', 'Operaciones Relacionadas',  V_HORA, P_HORA, null);

END;
---RAMON PAVON--
/*Proceso que registra movimientos automaticos de compra por operaciones diarias
por Clientes en moneda extranjera. Es llamado desde PR_PRO_COMPRAS - AP 741 - SDC*/
PROCEDURE PR_PRO_OPE_COM_SIPAP IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_modulo        NUMBER(04);
v_des_modulo        ba_modulos.descripcion%type;
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
--v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
r_rpoca             lc_bol_automaticos_res%rowtype;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_concepto          ge_movimientos.concepto%type;
v_redondeo          number(5);
v_cod_persona       ba_personas.cod_persona%type;
v_nro_cuenta        ge_cuentas.nro_cuenta%type;
v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;

CURSOR CUR_DATOS IS
     --- operaciones de compra y extracciones atm en el extranjero
    select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
           decode(a.cod_transaccion, 196, b.nro_cuenta, a.nro_cuenta) nro_cuenta,
           nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
           '_SIPAP'
    from  ge_movimientos b, ge_movimientos a
    where a.cod_mad_padre = 455
      and a.cod_tra_padre IN (302,303, 308) -- proveedores y transferencias sipap
      and a.estado = 'N'
      and a.cod_transaccion in (602, 196)
      and a.monto <> 0
      and b.cod_mad_padre = 455
      and b.estado = 'N'
      and b.cod_transaccion in (503, 190)
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      and b.nro_documento = P_NRO_OPERACION
      AND B.HORA = P_HORA
      AND B.COD_USUARIO = P_COD_USUARIO;

BEGIN
  begin
    select cod_tip_ope_bcp
      into v_cod_tip_ope_bcp
      from lc_tip_operaciones
     where lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
  exception
    when others then v_cod_tip_ope_bcp := 'A19';
  end;
  ----------------------------------------------------------------
  if cur_datos%isopen then
      close cur_datos;
  end if;
  open cur_datos;
  --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
  --wa:para pk
  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
  loop
      fetch cur_datos
      into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto,v_nro_cuenta, v_cotizacion,
           v_cod_tra_padre,v_referencia;
      exit when cur_datos%notfound;

      Select lower(substr(descripcion,1,9))
        into v_des_modulo
        from ba_modulos
       where cod_modulo = v_cod_modulo;
      /*
      || DYDMR-860 - SC 6884 DIFERENCIA POSICIÓN DE CAMBIOS 26-06-13 - SP 2025
      || como tambien entran las reversiones, esto es en caso de q estas superen a las operaciones
      || No se ajustará el código en esta incidencia
      || Solo la referencia para el detalle de la boleta
      */
      IF v_monto >= 0 THEN
         v_cod_modalidad     := 71;
         v_cod_tip_operacion := 17;
         v_concepto          := 'Compra Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'COM'||v_referencia;
      ELSE
         v_cod_modalidad     := 72;
         v_cod_tip_operacion := 31;
         v_concepto          := 'Venta Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'VTA_REV'||v_referencia;
      END IF;
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
      if v_cod_tra_padre in (303, 388,486, 308) then
         v_cotizacion := nvl(v_cotizacion, paw_bce.fu_obt_cotizacion(v_cod_moneda, 'C'));
      else
         v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda,v_fec_actual);
      end if;
      v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := round(nvl(v_cotizacion,0) * v_monto,v_redondeo);

      -- Obtiene el código de Persona
      if v_nro_cuenta is not null then
         v_cod_persona := fug_obt_cli_principal (v_nro_cuenta);
      else
         v_cod_persona := lf_obt_per_entidad;
      end if;

      --- genera movimiento ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := v_cod_modalidad;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 942;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := null;
      r_gmovi.monto           := abs(v_monto);
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := abs(v_tot_mon_local);
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      r_gmovi.cod_persona   := v_cod_persona;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      r_rpoca.cod_modalidad := v_cod_modalidad;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 942;
      r_rpoca.cod_transaccion := 942;
      r_rpoca.nro_documento   := v_nro_operacion;
      r_rpoca.monto           := abs(v_monto);
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := v_cod_modalidad;
      r_rpoca.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := abs(v_tot_mon_local);
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.cod_bco_central    := v_cod_tip_ope_bcp;
      r_rpoca.referencia    := v_referencia;
      --g_nro_cuenta          := v_nro_cuenta;
      --DYDMR-2477 ITGF - Diferencia Posición de Cambios del 18.09.2015 SC 20865
      --pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := v_cod_persona;
      r_gmovi.monto           := 0;
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
     -- v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N'); /*fm dydmr-1741*/
      if v_cod_modalidad = 71 then  /* ES UNA COMPRA */
         --actualiza la posicion
         update lc_posiciones set
                mto_com_nef_act = nvl(mto_com_nef_act,0) + v_monto,
                mto_com_nef_loc = nvl(mto_com_nef_loc,0) + v_tot_mon_local
          where cod_tip_ope_bcp = v_cod_tip_ope_bcp
            and cod_moneda      = v_cod_moneda
            and cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
         --inserta posicion si no existe
         if sql%notfound then
              insert into lc_posiciones
                  (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                   mto_com_nef_act, mto_com_nef_loc)
              values
                  (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), v_monto,v_tot_mon_local);
         end if;
      else --es una venta
        --actualiza la posicion
        update lc_posiciones set
               mto_vta_nef_act = nvl(mto_vta_nef_act,0) + abs(v_monto),
               mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + abs(v_tot_mon_local)
         where cod_tip_ope_bcp = v_cod_tip_ope_bcp
           and cod_moneda      = v_cod_moneda
           and cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
        --inserta posicion si no existe
        if sql%notfound then
           insert into lc_posiciones
               (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                mto_com_nef_act, mto_com_nef_loc)
           values
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), abs(v_monto), abs(v_tot_mon_local));
        end if;
      end if;
  end loop;
  if cur_datos%isopen then
     close cur_datos;
  end if;
  insert into BA_COD_REFERENCIAS
  (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA)
  values
  ('DAT_OPE_RELACION', 'Operaciones Relacionadas',  V_HORA, P_HORA, null);



END;

BEGIN
  IF P_TIPO = 'C' then --Compras--
     PR_PRO_OPE_COM_SIPAP;
  elsif P_TIPO = 'V' then --Ventas--
     PR_PRO_OPE_VTA_SIPAP;
  else
     raise_application_error(-20005,'Error. El Tipo debe ser C-Compra, o V-Venta. Verifique.');
  end if;

  --Insertado una Referencia en caso de reversion--
 /* insert into BA_COD_REFERENCIAS
  (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA)
  values
  ('DAT_OPE_RELACION', 'Operaciones Relacionadas', P_HORA, V_HORA, null);*/ 
END;
/

