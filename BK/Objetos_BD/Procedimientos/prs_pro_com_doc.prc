CREATE OR REPLACE PROCEDURE IT.prs_pro_com_doc(p_nro_referencia IN NUMBER DEFAULT 0) IS
   /*Proceso de compra de documento*/
   v_hora            ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss');
   v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
   r_gmovi           ge_movimientos%ROWTYPE;
   v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
   v_cotizacion      ge_movimientos.cotizacion%TYPE;
   r_docu            md_cta_documentos%ROWTYPE;
   v_mto_desembolsar ge_movimientos.monto%TYPE;
   v_mto_garantia    md_garantias.monto%TYPE;
   v_cod_oficina     ba_oficinas.cod_oficina%TYPE := 10;
   v_cod_rubro       cb_rubros.cod_rubro%TYPE;
   v_fec_actual      ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(10);

BEGIN
   BEGIN
      SELECT nro_cuenta
        INTO v_nro_cuenta 
        FROM md_cta_documentos
       WHERE nro_documento = to_char(p_nro_referencia);
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Error al obtener la cuenta ' || SQLERRM);
   END;
   v_nro_secuencia := 0;
   --Obtener el monto a comprar del documento
   v_mto_desembolsar := 0;
   pam_doc.pr_obt_datos(v_nro_cuenta, r_docu);
   v_mto_desembolsar := r_docu.monto - nvl(r_docu.mto_impuesto, 0);
   pam_doc.pr_com_documentos(v_nro_cuenta, v_mto_desembolsar, v_cod_oficina, v_mto_garantia,
                             v_fec_actual, v_hora, v_nro_secuencia);
   v_cotizacion := NULL;
   IF r_docu.cod_moneda <> pag_gen.fu_obt_mon_local THEN
      v_cotizacion := fug_obt_cotizacion(r_docu.cod_moneda, v_fec_actual);
   END IF;
   v_cod_rubro := fug_obt_pardinamico('SIB_SNP_RUB_MESA_DEPO');
   IF v_cod_rubro IS NOT NULL THEN
   
      r_gmovi.cod_usuario := USER;
      r_gmovi.hora        := v_hora;
      r_gmovi.fecha       := v_fec_actual;
      -- Aumento la secuencia
      v_nro_secuencia       := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia := v_nro_secuencia;
      --
      r_gmovi.cod_modulo      := 10;
      r_gmovi.cod_modalidad   := r_docu.cod_modalidad;
      r_gmovi.cod_oficina     := v_cod_oficina;
      r_gmovi.cod_moneda      := r_docu.cod_moneda;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.cod_tra_padre   := 101;
      r_gmovi.cod_mod_padre   := 10;
      r_gmovi.cod_mad_padre   := r_docu.cod_modalidad;
      r_gmovi.cod_transaccion := 741;
      r_gmovi.monto           := r_docu.monto;
      r_gmovi.nro_documento   := v_nro_cuenta;
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Compra Documento ' || v_nro_cuenta;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_rubro       := v_cod_rubro;
      r_gmovi.nro_cuenta      := NULL;
      r_gmovi.tip_mov_rubro   := 'C';
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(r_gmovi.monto * v_cotizacion);
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al Insertar compra de documento ' || SQLERRM);
END;
/

