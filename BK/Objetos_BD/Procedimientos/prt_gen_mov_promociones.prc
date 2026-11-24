CREATE OR REPLACE PROCEDURE IT.PRT_GEN_MOV_PROMOCIONES IS
-- Fecha: 04/11/2014.
-- Requerimiento: CNFIDPMO-3.
-- Cursor.
CURSOR c_promociones IS 
   SELECT nro_tarjeta, 
          nro_cupon, 
          nro_boleta, 
          nro_cuenta, 
          cod_autorizacion, 
          nom_tarjeta, 
          mto_origen, 
          mto_liquidacion, 
          des_comercio, 
          cod_procesadora, 
          fec_compra, 
          fec_proceso, 
          mto_comision, 
          cod_convenio, 
          mto_descuento
     FROM ta_mov_promociones_tmp 
    ORDER BY cod_convenio;
     
-- Variables.
rg_movs                ge_movimientos%rowtype;
v_cor_convenio         ta_con_promociones.nro_convenio%TYPE;
v_cod_rub_deb_entidad  ge_movimientos.cod_rubro%TYPE;     
v_nro_secuencia        ge_movimientos.nro_secuencia%TYPE := 0;
v_acu_convenio         ge_movimientos.monto%TYPE;
v_cod_mod_padre        ge_movimientos.cod_modulo%TYPE := 4;
v_cod_mad_padre        ge_movimientos.cod_modalidad%TYPE := 41;
v_cod_tra_padre        ge_transacciones.cod_transaccion%TYPE := 237;
v_cod_modulo           ge_movimientos.cod_modulo%TYPE;
v_cod_modalidad        ge_movimientos.cod_modalidad%TYPE;
v_cod_transaccion      ge_movimientos.cod_transaccion%type := 9237;
v_cod_mod_transitoria  ge_movimientos.cod_modulo%type := 5;
v_cod_mad_transitoria  ge_movimientos.cod_modalidad%type := 51;
v_cod_transitoria      ge_movimientos.cod_transaccion%type := 3530;
v_fecha                ge_movimientos.fecha%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(1);
v_hora                 ge_movimientos.hora%type;
v_cod_mon_local        ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
v_cod_ofi_origen       ba_usuarios.cod_oficina%type := FUG_OBT_OFI_USUARIO(USER);

PROCEDURE pr_act_mov_convenio(p_acu_convenio ge_movimientos.monto%TYPE,
                              p_cod_convenio ta_con_promociones.nro_convenio%TYPE) IS
BEGIN
   IF v_nro_secuencia >= 998 then
      v_nro_secuencia := 0;
      v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      rg_movs.hora    := v_hora;
   END IF;
   --
   v_nro_secuencia         := v_nro_secuencia + 1;
   rg_movs.nro_secuencia   := v_nro_secuencia;
   rg_movs.cod_mod_padre   := v_cod_mod_padre;
   rg_movs.cod_mad_padre   := v_cod_mad_padre;
   rg_movs.cod_tra_padre   := v_cod_tra_padre;
   rg_movs.cod_modulo      := v_cod_mod_transitoria;
   rg_movs.cod_modalidad   := v_cod_mad_transitoria;
   rg_movs.cod_transaccion := v_cod_transitoria;
   rg_movs.monto           := NVL(p_acu_convenio,0);
   rg_movs.cod_moneda      := v_cod_mon_local;
   rg_movs.nro_cuenta      := null;
   rg_movs.cod_oficina     := v_cod_ofi_origen;
   rg_movs.nro_documento   := p_cod_convenio;
   rg_movs.nro_documento2  := null;
   rg_movs.nro_documento3  := null;
   rg_movs.cod_tasa        := null;
   rg_movs.val_tasa        := null;
   rg_movs.cotizacion      := null;
   rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
   rg_movs.concepto        := substr('Descuento Mostrador TC. Nro. Convenio '||p_cod_convenio,1,100);
   rg_movs.estado          := 'N';
   rg_movs.est_cuenta      := 'N';
   rg_movs.reversado       := 'N';
   rg_movs.emi_aviso       := 'N';
   rg_movs.nro_caja        := null;
   rg_movs.cod_rubro       := null;
   rg_movs.tip_mov_rubro   := null; 
   rg_movs.referencia      := null;
   --
   PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos 
   --
END;

BEGIN
  -- Seteo de variables.
  v_cor_convenio := NULL;
  v_acu_convenio := 0;
  v_hora         := to_char( sysdate, 'HH24:MI:SS' );
  v_hora         := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  
  --Asignar valores generales para registro de movimientos
  rg_movs.cod_usuario     := user;
  rg_movs.hora            := v_hora;
  rg_movs.fecha           := v_fecha;
  rg_movs.fec_valor       := v_fecha;  
  --
  FOR reg IN c_promociones LOOP
    
    -- Valida el nro. de cuenta.
    BEGIN
       SELECT ta.cod_modulo, ta.cod_modalidad
         INTO v_cod_modulo, v_cod_modalidad
         FROM ta_cta_tarjetas ta
        WHERE ta.nro_cuenta = reg.nro_cuenta;
    EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20000,'La cuenta '||reg.nro_cuenta||' no se encuentra registrada en el Sistema.');
    END;
    
    -- Valida el Código de Convenio.
    BEGIN
       SELECT ta.cod_rub_deb_entidad
         INTO v_cod_rub_deb_entidad
         FROM ta_con_promociones ta
        WHERE ta.nro_convenio = reg.cod_convenio;
    EXCEPTION
       WHEN OTHERS THEN
          raise_application_error(-20000,'El Nro. de Convenio '||reg.cod_convenio||' no se encuentra registrada en el Sistema.');
    END;
    
    -- Valida el Monto del Descuento.
    IF NVL(reg.mto_descuento,0) = 0 THEN
       raise_application_error(-20000,'El Importe del Descuento debe ser distinto a 0(Cero).');
    END IF;
    
    --Se debe agrupar x comercio y tipo de promocion
    IF  v_cor_convenio IS NULL THEN
        --Guardar la variables de corte de control e iniciar acumulados
        v_cor_convenio        := reg.cod_convenio;
        v_acu_convenio        := 0;
    END IF;
    
    -- Corte por Nro. de Convenio.
    IF reg.cod_convenio <> v_cor_convenio THEN        
       -- Genero el movimiento en el rubro transitorio.    
       IF NVL(v_acu_convenio,0) <> 0 THEN
          pr_act_mov_convenio(NVL(v_acu_convenio,0),v_cor_convenio);   
       END IF;
        --
        v_cor_convenio := reg.cod_convenio;
        v_acu_convenio := 0;
    END IF;
    
    -- Genero los movimientos por cuenta de cliente.
    IF v_nro_secuencia >= 998 then
       v_nro_secuencia := 0;
       v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
       rg_movs.hora    := v_hora;
    END IF;    
    v_nro_secuencia         := v_nro_secuencia + 1;
    rg_movs.nro_secuencia   := v_nro_secuencia;
    rg_movs.cod_mod_padre   := v_cod_mod_padre;
    rg_movs.cod_mad_padre   := v_cod_mad_padre;
    rg_movs.cod_tra_padre   := v_cod_tra_padre;
    rg_movs.cod_modulo      := v_cod_modulo;
    rg_movs.cod_modalidad   := v_cod_modalidad;
    rg_movs.cod_transaccion := v_cod_transaccion;
    rg_movs.monto           := NVL(reg.mto_descuento,0);
    rg_movs.cod_moneda      := v_cod_mon_local;
    rg_movs.nro_cuenta      := null;
    rg_movs.cod_oficina     := v_cod_ofi_origen;
    rg_movs.nro_documento   := reg.cod_convenio;
    rg_movs.nro_documento2  := reg.nro_boleta;
    rg_movs.nro_documento3  := reg.nro_cupon;
    rg_movs.cod_tasa        := null;
    rg_movs.val_tasa        := null;
    rg_movs.cotizacion      := null;
    rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
    rg_movs.concepto        := substr('Descuento Mostrador TC, Fecha: '||to_char(reg.fec_compra,'dd/mm/yyyy'),1,100);
    rg_movs.estado          := 'N';
    rg_movs.est_cuenta      := 'N';
    rg_movs.reversado       := 'N';
    rg_movs.emi_aviso       := 'N';
    rg_movs.nro_caja        := null;
    rg_movs.cod_rubro       := v_cod_rub_deb_entidad;
    rg_movs.tip_mov_rubro   := 'D'; -- Débito
    rg_movs.referencia      := reg.nro_cuenta;
    --
    PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs,'N'); -- inserta datos en ge_movimientos 
    --  
    -- Actualizo la variable del acumulado.
    v_acu_convenio := NVL(v_acu_convenio,0) + NVL(reg.mto_descuento,0); 
  END LOOP;
  -- Corte por convenio.
  IF v_cor_convenio IS NOT NULL THEN
     IF NVL(v_acu_convenio,0) <> 0 THEN
        pr_act_mov_convenio(NVL(v_acu_convenio,0),v_cor_convenio);   
     END IF;
     --
  END IF;  
END;
/

