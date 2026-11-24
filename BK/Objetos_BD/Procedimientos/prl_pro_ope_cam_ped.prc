CREATE OR REPLACE PROCEDURE IT.PRL_PRO_OPE_CAM_PED (P_COD_OFICINA IN GE_MOVIMIENTOS.COD_OFICINA%TYPE,
                                                 P_NRO_CUENTA  IN GE_MOVIMIENTOS.NRO_CUENTA%TYPE,
                                                 P_COD_MODULO  IN GE_MOVIMIENTOS.COD_MODULO%TYPE,
                                                 P_COD_MONEDA  IN GE_MOVIMIENTOS.COD_MONEDA%TYPE,
                                                 P_COTIZACION  IN GE_MOVIMIENTOS.COTIZACION%TYPE,
                                                 P_MONTO       IN GE_MOVIMIENTOS.MONTO%TYPE,
                                                 P_HORA        IN GE_MOVIMIENTOS.HORA%TYPE,
                                                 P_TIPO        IN VARCHAR2) IS
                                                 
v_hora              varchar2(08) := P_HORA;

PROCEDURE PR_PRO_OPE_VENTA IS
  v_fec_actual        date := pag_cal.fu_obt_fec_actual(7);
  v_cod_modalidad     NUMBER(04);
  v_des_modulo        ba_modulos.descripcion%type;
  v_tot_mon_local     NUMBER;
  v_cotizacion        ge_cotizaciones.val_conversion%type;
  v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 31; -- fijo venta cuenta contable
  v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
  r_gmovi             ge_movimientos%rowtype;
  v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
  v_nro_operacion     ge_movimientos.nro_documento%type;
  v_concepto          ge_movimientos.concepto%type;
  v_redondeo          number(5);
  v_cod_persona       ba_personas.cod_persona%type;
  
 BEGIN
    -----------------------------------------------------------
    SELECT lower(substr(descripcion,1,9))
      INTO v_des_modulo
      FROM ba_modulos
     WHERE cod_modulo = p_cod_modulo;
    --como tambien entran las reversiones, esto es en caso de q estas superen a las operaciones
    IF p_monto >= 0 THEN
       v_cod_modalidad     := 72;
       v_cod_tip_operacion := 31;
       v_concepto          := 'Venta Div. p/Oper.'||v_des_modulo;
    ELSE
       v_cod_modalidad     := 71;
       v_cod_tip_operacion := 17;
       v_concepto          := 'Compra Div. p/Oper.'||v_des_modulo;
    END IF;
    -----------------------------------------------------------
    BEGIN
     SELECT cod_tip_ope_bcp
       INTO v_cod_tip_ope_bcp
       FROM lc_tip_operaciones
      WHERE lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
    EXCEPTION
     WHEN OTHERS THEN
       IF v_cod_tip_operacion = 31 THEN
          v_cod_tip_ope_bcp := 'B27';
       ELSE
          v_cod_tip_ope_bcp := 'A19';
       END IF;
    END;
    -----------------------------------------------------------
    v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, p_cod_moneda, p_cod_oficina)+1;
    prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, p_cod_moneda, p_cod_oficina, v_nro_operacion);
    IF p_cotizacion is null THEN
       v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda,v_fec_actual);
    ELSE
       v_cotizacion := p_cotizacion;   
    END IF;
    v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
    v_tot_mon_local := round(nvl(v_cotizacion,0) * p_monto,v_redondeo);

    -- Obtiene el código de Persona
    IF p_nro_cuenta is not null THEN
       v_cod_persona := fug_obt_cli_principal (p_nro_cuenta);
       r_gmovi.cod_persona := v_cod_persona;
    ELSE
       v_cod_persona := fug_obt_per_entidad;
    END IF;
        
    --- genera movimiento ---
    r_gmovi.cod_usuario   := user;
    r_gmovi.hora          := v_hora;
    r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
    r_gmovi.cod_modulo    := 7;
    r_gmovi.cod_modalidad := v_cod_modalidad;
    r_gmovi.cod_oficina   := p_cod_oficina;
    r_gmovi.nro_cuenta    := null;
    r_gmovi.cod_moneda    := p_cod_moneda;
    r_gmovi.fec_valor     := v_fec_actual;
    r_gmovi.fecha         := v_fec_actual;
    r_gmovi.cod_tra_padre   := 942;
    r_gmovi.cod_transaccion := 942;
    r_gmovi.nro_documento   := v_nro_operacion;
    r_gmovi.nro_documento2  := null;
    r_gmovi.monto           := abs(p_monto);
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := p_cod_oficina;
    r_gmovi.reversado     := 'N';
    r_gmovi.emi_aviso     := 'N';
    r_gmovi.protegido     := 'N';
    r_gmovi.cod_mod_padre := 7;
    r_gmovi.cod_mad_padre := v_cod_modalidad;
    r_gmovi.concepto      := v_concepto ||' en '||p_cod_moneda;
    r_gmovi.cotizacion    := v_cotizacion;
    r_gmovi.mto_equ_local := abs(v_tot_mon_local);
    r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
    r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
    pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

    --- genera movimiento x persona, para listados ---
    r_gmovi.cod_usuario   := user;
    r_gmovi.hora          := v_hora;
    r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
    r_gmovi.cod_modulo    := 7;
    r_gmovi.cod_modalidad := 70;
    r_gmovi.cod_oficina   := p_cod_oficina;
    r_gmovi.nro_cuenta    := null;
    r_gmovi.cod_moneda    := p_cod_moneda;
    r_gmovi.fec_valor     := v_fec_actual;
    r_gmovi.fecha         := v_fec_actual;
    r_gmovi.cod_tra_padre   := 942;
    r_gmovi.cod_transaccion := 760;
    r_gmovi.nro_documento   := v_nro_operacion;
    r_gmovi.nro_documento2  := v_cod_persona;
    r_gmovi.monto           := 0;
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := p_cod_oficina;
    r_gmovi.reversado     := 'N';
    r_gmovi.emi_aviso     := 'N';
    r_gmovi.protegido     := 'N';
    r_gmovi.cod_mod_padre := 7;
    r_gmovi.cod_mad_padre := v_cod_modalidad;
    r_gmovi.concepto      := v_concepto ||' en '||p_cod_moneda;
    r_gmovi.cotizacion    := null;
    r_gmovi.mto_equ_local := null;
    r_gmovi.cod_tip_ope_cambio := null;
    r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
    pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
    -----------------------------------------------------------
    IF v_cod_modalidad = 72 THEN  /* ES UNA VENTA */
       --actualiza la posicion
       UPDATE lc_posiciones 
          SET mto_vta_nef_act = nvl(mto_vta_nef_act,0) + p_monto,
              mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + v_tot_mon_local
        WHERE cod_tip_ope_bcp  = v_cod_tip_ope_bcp
          AND cod_moneda       = p_cod_moneda
          AND cod_ofi_cambio   = pal_cam.fu_obt_ofi_cambio(p_cod_oficina);
       --inserta posicion si no existe
       IF sql%notfound THEN
         INSERT INTO lc_posiciones
             (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
              mto_vta_nef_act, mto_vta_nef_loc)
         VALUES
             (p_cod_moneda, v_cod_tip_ope_bcp,
              pal_cam.fu_obt_ofi_cambio(p_cod_oficina), p_monto,v_tot_mon_local);
       END IF;
    ELSE --es una compra
       --actualiza la posicion
       UPDATE lc_posiciones 
          SET mto_com_nef_act = nvl(mto_com_nef_act,0) + abs(p_monto),
              mto_com_nef_loc = nvl(mto_com_nef_loc,0) + abs(v_tot_mon_local)
        WHERE cod_tip_ope_bcp = v_cod_tip_ope_bcp
          AND cod_moneda      = p_cod_moneda
          AND cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(p_cod_oficina);
       --inserta posicion si no existe
       IF sql%notfound THEN
          INSERT INTO lc_posiciones
             (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
              mto_com_nef_act, mto_com_nef_loc)
          VALUES
             (p_cod_moneda, v_cod_tip_ope_bcp,
              pal_cam.fu_obt_ofi_cambio(p_cod_oficina), abs(p_monto), abs(v_tot_mon_local));
       END IF;
    END IF;
  
  END;

PROCEDURE PR_PRO_OPE_COMPRA IS

  v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); 
  v_cod_modalidad     NUMBER(04);
  v_des_modulo        ba_modulos.descripcion%type;
  v_tot_mon_local     NUMBER;
  v_cotizacion        ge_cotizaciones.val_conversion%type;
  v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
  v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
  r_gmovi             ge_movimientos%rowtype;
  v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
  v_nro_operacion     ge_movimientos.nro_documento%type;
  v_concepto          ge_movimientos.concepto%type;
  v_redondeo          number(5);
  v_cod_persona       ba_personas.cod_persona%type;
  
  BEGIN
    -----------------------------------------------------------
    SELECT lower(substr(descripcion,1,9))
      INTO v_des_modulo
      FROM ba_modulos
     WHERE cod_modulo = p_cod_modulo;
    
    IF p_monto >= 0 THEN
       v_cod_modalidad     := 71;
       v_cod_tip_operacion := 17;
       v_concepto          := 'Compra Div. p/Oper.'||v_des_modulo;
    ELSE
       v_cod_modalidad     := 72;
       v_cod_tip_operacion := 31;
       v_concepto          := 'Venta Div. p/Oper.'||v_des_modulo;
    END IF;
    -----------------------------------------------------------
    BEGIN
       SELECT cod_tip_ope_bcp
         INTO v_cod_tip_ope_bcp
         FROM lc_tip_operaciones
        WHERE lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
    EXCEPTION
       WHEN others THEN 
          IF v_cod_tip_operacion = 31 THEN
             v_cod_tip_ope_bcp := 'B27';
          ELSE
             v_cod_tip_ope_bcp := 'A19';
          END IF;
    END;
    -----------------------------------------------------------
    v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, p_cod_moneda, p_cod_oficina)+1;
    prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, p_cod_moneda, p_cod_oficina, v_nro_operacion);
    IF p_cotizacion is null THEN
       v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda,v_fec_actual);
    ELSE
       v_cotizacion := p_cotizacion;
    END IF;
    v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
    v_tot_mon_local := round(nvl(v_cotizacion,0) * p_monto,v_redondeo);

    -- Obtiene el código de Persona
    IF p_nro_cuenta is not null THEN
       v_cod_persona := fug_obt_cli_principal (p_nro_cuenta);
       r_gmovi.cod_persona := v_cod_persona;
    ELSE
       v_cod_persona := fug_obt_per_entidad;
    END IF;

    --- genera movimiento ---
    r_gmovi.cod_usuario   := user;
    r_gmovi.hora          := v_hora;
    r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
    r_gmovi.cod_modulo    := 7;
    r_gmovi.cod_modalidad := v_cod_modalidad;
    r_gmovi.cod_oficina   := p_cod_oficina;
    r_gmovi.nro_cuenta    := null;
    r_gmovi.cod_moneda    := p_cod_moneda;
    r_gmovi.fec_valor     := v_fec_actual;
    r_gmovi.fecha         := v_fec_actual;
    r_gmovi.cod_tra_padre   := 942;
    r_gmovi.cod_transaccion := 942;
    r_gmovi.nro_documento   := v_nro_operacion;
    r_gmovi.nro_documento2  := null;
    r_gmovi.monto           := abs(p_monto);
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := p_cod_oficina;
    r_gmovi.reversado     := 'N';
    r_gmovi.emi_aviso     := 'N';
    r_gmovi.protegido     := 'N';
    r_gmovi.cod_mod_padre := 7;
    r_gmovi.cod_mad_padre := v_cod_modalidad;
    r_gmovi.concepto      := v_concepto ||' en '||p_cod_moneda;
    r_gmovi.cotizacion    := v_cotizacion;
    r_gmovi.mto_equ_local := abs(v_tot_mon_local);
    r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
    r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
    pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

    --- genera movimiento x persona, para listados ---
    r_gmovi.cod_usuario   := user;
    r_gmovi.hora          := v_hora;
    r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
    r_gmovi.cod_modulo    := 7;
    r_gmovi.cod_modalidad := 70;
    r_gmovi.cod_oficina   := p_cod_oficina;
    r_gmovi.nro_cuenta    := null;
    r_gmovi.cod_moneda    := p_cod_moneda;
    r_gmovi.fec_valor     := v_fec_actual;
    r_gmovi.fecha         := v_fec_actual;
    r_gmovi.cod_tra_padre   := 942;
    r_gmovi.cod_transaccion := 760;
    r_gmovi.nro_documento   := v_nro_operacion;
    r_gmovi.nro_documento2  := v_cod_persona;
    r_gmovi.monto           := 0;
    r_gmovi.estado          := 'N';
    r_gmovi.cod_ofi_origen  := p_cod_oficina;
    r_gmovi.reversado     := 'N';
    r_gmovi.emi_aviso     := 'N';
    r_gmovi.protegido     := 'N';
    r_gmovi.cod_mod_padre := 7;
    r_gmovi.cod_mad_padre := v_cod_modalidad;
    r_gmovi.concepto      := v_concepto ||' en '||p_cod_moneda;
    r_gmovi.cotizacion    := null;
    r_gmovi.mto_equ_local := null;
    r_gmovi.cod_tip_ope_cambio := null;
    r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
    pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        
    -----------------------------------------------------------
    IF v_cod_modalidad = 71 THEN  /* ES UNA COMPRA */
       --actualiza la posicion
       UPDATE lc_posiciones 
          SET mto_com_nef_act = nvl(mto_com_nef_act,0) + p_monto,
              mto_com_nef_loc = nvl(mto_com_nef_loc,0) + v_tot_mon_local
        WHERE cod_tip_ope_bcp = v_cod_tip_ope_bcp
          AND cod_moneda      = p_cod_moneda
          AND cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(p_cod_oficina);
       --inserta posicion si no existe
       IF SQL%NOTFOUND THEN
            INSERT INTO lc_posiciones
                (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                 mto_com_nef_act, mto_com_nef_loc)
            VALUES
                (p_cod_moneda, v_cod_tip_ope_bcp,
              pal_cam.fu_obt_ofi_cambio(p_cod_oficina), p_monto,v_tot_mon_local);
       END IF;
    ELSE --es una venta
       --actualiza la posicion
       UPDATE lc_posiciones 
          SET mto_vta_nef_act = nvl(mto_vta_nef_act,0) + abs(p_monto),
              mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + abs(v_tot_mon_local)
        WHERE cod_tip_ope_bcp = v_cod_tip_ope_bcp
          AND cod_moneda      = p_cod_moneda
          AND cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(p_cod_oficina);
       --inserta posicion si no existe
       IF SQL%NOTFOUND THEN
          INSERT INTO lc_posiciones
             (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
              mto_com_nef_act, mto_com_nef_loc)
          VALUES
             (p_cod_moneda, v_cod_tip_ope_bcp,
              pal_cam.fu_obt_ofi_cambio(p_cod_oficina), abs(p_monto), abs(v_tot_mon_local));
       END IF;
    END IF;
  END;

BEGIN
  IF P_TIPO = 'C' THEN --Compras--
     PR_PRO_OPE_COMPRA;
  ELSIF P_TIPO = 'V' THEN --Ventas--
     PR_PRO_OPE_VENTA;
  ELSE
     raise_application_error(-20005,'Error en PRL_PRO_OPE_CAM_PED. Debe ser Tipo C-Compra o V-Venta.');
  END IF;
END;
/

