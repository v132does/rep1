CREATE OR REPLACE PROCEDURE IT.prs_pro_vta_doc(p_nro_referencia IN NUMBER DEFAULT 0) IS
   /*Proceso de venta de documento*/
   v_hora               ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE;
   r_gmovi              ge_movimientos%ROWTYPE;
   v_tip_mov_rubro      ge_movimientos.tip_mov_rubro%TYPE := NULL;
   v_cod_oficina        ba_oficinas.cod_oficina%TYPE := 10;
   v_mto_pagado         ge_movimientos.monto%TYPE;
   v_mto_debito         ge_movimientos.monto%TYPE;
   v_mto_interes        ge_movimientos.monto%TYPE;
   v_mto_int_descontado ge_movimientos.monto%TYPE;
   v_mto_cargo          ge_movimientos.monto%TYPE; 
   v_mto_impuesto       ge_movimientos.monto%TYPE;
   v_nro_cuenta         ge_cuentas.nro_cuenta%TYPE;
   v_fec_actual         ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(10);
   v_cod_rubro          cb_rubros.cod_rubro%TYPE;
   v_val_tasa           ge_tas_fechas.val_tasa%TYPE;
BEGIN
   BEGIN
      SELECT nro_cuenta, monto, mto_interes, mto_impuesto, v_cod_oficina
        INTO v_nro_cuenta, v_mto_pagado, v_mto_interes, v_mto_impuesto, v_cod_oficina
        FROM md_cta_documentos
       WHERE nro_documento = to_char(p_nro_referencia);
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Error al obtener la cuenta ' || SQLERRM);
   END;
   v_nro_secuencia := 0;
   pam_doc.pr_vta_documento(v_nro_cuenta, (nvl(v_mto_pagado, 0) + nvl(v_mto_interes, 0) + nvl(v_mto_impuesto, 0)), v_cod_oficina,
                            --- oficina origen
                            'Venta de Documento ' || v_nro_cuenta, v_fec_actual, v_hora,
                            v_nro_secuencia, 102, 10, 116, 0, v_mto_interes, v_mto_int_descontado,
                            v_mto_impuesto, v_mto_cargo, v_val_tasa, NULL);
   BEGIN
      SELECT tipo
        INTO v_tip_mov_rubro
        FROM ge_transacciones
       WHERE cod_transaccion = 842
         AND cod_modulo = 10
         AND cod_modalidad = 116
         AND tipo IN ('D', 'C')
         AND nvl(afecta, 'N') = 'N' --no debe afectar a algún saldo
         AND rutina3 IS NULL; --Esta validación se hace mientras se utilice la Modalidad 31
   EXCEPTION
      WHEN OTHERS THEN
         v_tip_mov_rubro := 'D';
   END;
   v_cod_rubro :=  fug_obt_pardinamico('SIB_SNP_RUB_MESA_DEPO');
   v_mto_debito := v_mto_pagado + v_mto_interes;
   IF v_cod_rubro IS NOT NULL THEN
      r_gmovi.cod_usuario := USER;
      r_gmovi.hora        := v_hora;
      r_gmovi.fecha       := v_fec_actual;
      -- Aumento la secuencia
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.cod_modulo      := 10;
      r_gmovi.cod_modalidad   := 116;
      r_gmovi.cod_oficina     := v_cod_oficina;
      r_gmovi.cod_moneda      := pag_gen.fu_obt_mon_local;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := 102;
      r_gmovi.cod_mod_padre   := 10;
      r_gmovi.cod_mad_padre   := 116;
      r_gmovi.cod_transaccion := 842;
      r_gmovi.monto           := v_mto_debito;
      r_gmovi.nro_documento   := NULL;
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Venta de Documento ' || v_nro_cuenta;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       := v_cod_rubro;
      r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   END IF;
EXCEPTION

   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al Insertar compra de documento ' || SQLERRM);
END;
/

