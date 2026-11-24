CREATE OR REPLACE PROCEDURE IT.prs_ins_ope_mesa
(
   p_nro_referencia IN NUMBER DEFAULT 0,
   p_cod_moneda     IN ba_monedas.cod_mon_iso%TYPE,
   p_monto          IN sb_snp_lim_depo.monto%TYPE DEFAULT 0,
   p_tasa           IN sb_snp_lim_depo.tasa%TYPE DEFAULT 0
) IS
   /*Inserción de alta de documento modalidad 116*/
   r_mcta        md_cta_documentos%ROWTYPE;
   v_fec_actual  ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(10);
   v_dia_interes NUMBER;
   v_redondeo    NUMBER;
   v_tasa        ge_tas_rangos.val_tasa%TYPE;
   v_dia_plazo   NUMBER;
   v_tasadiv     NUMBER;
   v_monto       NUMBER;
   v_cod_moneda  ge_snp_transferencias.cod_moneda%TYPE;
   -- Proceso de Inserción de la cuenta.
   rg_gstra ge_snp_transferencias%ROWTYPE;

   PROCEDURE lp_ins_cta_documento IS
      r_gmovi         ge_movimientos%ROWTYPE;
      v_hora          ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS');
      v_nro_secuencia ge_movimientos.nro_secuencia%TYPE := 0;
   BEGIN
      INSERT INTO md_cta_documentos
         (cod_modulo, nro_cuenta, cod_modalidad, cod_oficina, cod_moneda, cod_rub_economico,
          cod_persona, nro_documento, denominacion, fec_inicio, fec_vencimiento, monto, val_tasa,
          cantidad, estado, fec_cam_estado, mto_interes, val_presente, sal_interes, beneficiario,
          tip_calculo, nro_cta_padre, com_doc_relacionados, sal_val_presente, cod_instruccion,
          for_pago, nro_ref_credito, dia_ano, cod_ofi_credito, observacion, mer_secundario, comision,
          mto_impuesto)
      VALUES
         (r_mcta.cod_modulo, r_mcta.nro_cuenta, r_mcta.cod_modalidad, r_mcta.cod_oficina,
          r_mcta.cod_moneda, r_mcta.cod_rub_economico, r_mcta.cod_persona, r_mcta.nro_documento,
          r_mcta.denominacion, r_mcta.fec_inicio, r_mcta.fec_vencimiento, r_mcta.monto,
          r_mcta.val_tasa, r_mcta.cantidad, r_mcta.estado, r_mcta.fec_cam_estado, r_mcta.mto_interes,
          r_mcta.val_presente, r_mcta.sal_interes, r_mcta.beneficiario, r_mcta.tip_calculo,
          r_mcta.nro_cta_padre, r_mcta.com_doc_relacionados, r_mcta.sal_val_presente,
          r_mcta.cod_instruccion, r_mcta.for_pago, r_mcta.nro_ref_credito, r_mcta.dia_ano,
          r_mcta.cod_ofi_credito, NULL, r_mcta.mer_secundario, r_mcta.comision, r_mcta.mto_impuesto);
      -- Movimiento de cambio de estado.
      v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := USER;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fec_actual;
      r_gmovi.cod_modulo      := r_mcta.cod_modulo;
      r_gmovi.cod_modalidad   := r_mcta.cod_modalidad;
      r_gmovi.cod_oficina     := r_mcta.cod_oficina;
      r_gmovi.nro_cuenta      := r_mcta.nro_cuenta;
      r_gmovi.cod_moneda      := r_mcta.cod_moneda;
      r_gmovi.est_cuenta      := 'S';
      r_gmovi.cod_tra_padre   := 401;
      r_gmovi.cod_transaccion := 401;
      r_gmovi.fec_valor       := v_fec_actual;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.concepto        := 'Cambio de Estado';
      r_gmovi.cod_ofi_origen  := r_mcta.cod_oficina;
      r_gmovi.cod_mod_padre   := r_mcta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_mcta.cod_modalidad;
      r_gmovi.nro_documento   := r_mcta.nro_cuenta;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   
      --- Insertar relacion cliente cuentas -----
      --- Cliente Principal
      INSERT INTO ge_cta_clientes
         (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad,
          relacion)
      VALUES
         (r_mcta.cod_persona, r_mcta.nro_cuenta, 0, r_mcta.cod_oficina, r_mcta.cod_modulo,
          r_mcta.cod_modalidad, 'P');
   END;

BEGIN
   BEGIN
      SELECT * INTO rg_gstra FROM ge_snp_transferencias WHERE nro_referencia = p_nro_referencia;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Error al obtener la transferencia ' || SQLERRM);
   END;
   -- Convertir Moneda ISO
   v_cod_moneda := p_cod_moneda;
   v_cod_moneda := CASE v_cod_moneda
                      WHEN pas_snp.g_cod_mon_iso_local THEN
                       pas_snp.g_cod_mon_local
                      ELSE
                       v_cod_moneda
                   END;
   -- Alta de documento.
   r_mcta.cod_modulo    := 10;
   r_mcta.cod_modalidad := 116;
   r_mcta.dia_ano       := 365;
   r_mcta.estado        := 'S';
   r_mcta.tip_calculo   := 'V';
   r_mcta.cod_oficina   := fug_obt_ofi_matriz;
   r_mcta.cod_persona   := fug_obt_per_bco_central;
   r_mcta.cod_moneda    := v_cod_moneda;
   --
   r_mcta.nro_cuenta := fug_obt_sig_nro_cuenta(r_mcta.cod_modulo, r_mcta.cod_modalidad,
                                               r_mcta.cod_oficina, r_mcta.cod_moneda,
                                               r_mcta.cod_persona);
   v_redondeo        := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_mcta.cod_modulo,
                                            r_mcta.cod_modalidad, r_mcta.cod_moneda);
   r_mcta.fec_inicio := rg_gstra.fec_valor;

   r_mcta.com_doc_relacionados := 'N';
   r_mcta.mer_secundario       := 'S';

   IF p_monto = 0 THEN
      pas_dep.pr_obt_dat_depo(p_cod_moneda, v_monto, v_tasa);
   ELSE
      v_tasa  := p_tasa;
   END IF;

   r_mcta.val_tasa             := v_tasa;
   r_mcta.cod_rub_economico    := fug_obt_pardinamico('SIB_SNP_COD_RUB_DEPO');
   r_mcta.nro_cta_padre        := NULL;
   r_mcta.com_doc_relacionados := 'N';
   r_mcta.for_pago             := 'R';
   r_mcta.nro_ref_credito      := fug_obt_pardinamico('SIB_SNP_RUB_MESA_DEPO');
   r_mcta.beneficiario         := fug_obt_nom_entidad;
   r_mcta.cantidad             := 0;
   r_mcta.denominacion         := fue_obt_nom_persona(r_mcta.cod_persona);

   v_dia_plazo := pag_cal.fu_obt_fec_sig_hab(v_fec_actual, 1) - v_fec_actual;

   r_mcta.fec_vencimiento  := r_mcta.fec_inicio + nvl(v_dia_plazo, 0);
   r_mcta.monto            := rg_gstra.monto;
   v_tasadiv               := r_mcta.val_tasa / (r_mcta.dia_ano * 100);
   v_dia_interes           := r_mcta.fec_vencimiento - r_mcta.fec_inicio;
   r_mcta.mto_interes      := round((r_mcta.monto * v_tasadiv * v_dia_interes), v_redondeo);
   r_mcta.comision         := 0;
   r_mcta.mto_impuesto     := 0;
   r_mcta.nro_documento    := p_nro_referencia;
   r_mcta.val_presente     := rg_gstra.monto;
   r_mcta.sal_interes      := r_mcta.mto_interes;
   r_mcta.sal_val_presente := r_mcta.val_presente;

   BEGIN
      IF p_monto = 0 THEN
         lp_ins_cta_documento;
      ELSE
         BEGIN
            UPDATE md_cta_documentos m
               SET m.monto            = r_mcta.monto,
                   m.mto_interes      = r_mcta.mto_interes,
                   m.val_tasa         = r_mcta.val_tasa,
                   m.val_presente     = r_mcta.val_presente,
                   m.sal_interes      = r_mcta.sal_interes,
                   m.sal_val_presente = r_mcta.sal_val_presente
             WHERE m.nro_documento = to_char(p_nro_referencia);
         END;
      END IF;
      --             
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al Insertar el Préstamo Recibido ' || r_mcta.nro_cuenta || ', ' ||
                                  SQLERRM);
   END;
END;
/

