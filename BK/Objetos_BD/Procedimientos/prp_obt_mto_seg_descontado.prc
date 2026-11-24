CREATE OR REPLACE PROCEDURE IT.prp_obt_mto_seg_descontado
(
   p_nro_cuenta IN VARCHAR2,
   p_mto_seguro OUT NUMBER,
   p_impuesto   OUT NUMBER
) IS
   v_mto_seg_descontar pr_cta_prestamos.monto%TYPE;
   v_impuesto          pr_cta_prestamos.monto%TYPE;
   r_pcpre             pr_cta_prestamos%ROWTYPE;
   v_val_tas_seguro    ge_tas_rangos.val_tasa%TYPE;
   v_cod_tas_seguro    ge_tasas.cod_tasa%TYPE;
   v_plazo             NUMBER(6);
   v_fecha             ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(6);
   v_val_tas_impuesto  ge_movimientos.val_tasa%TYPE;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%TYPE;
   v_tip_valor         ge_tasas.tip_valor%TYPE;
   v_tipo              ge_tasas.tipo%TYPE;
   v_cod_tasa          ge_tasas.cod_tasa%TYPE;
   CURSOR gastos(p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE) IS
      SELECT cod_transaccion
        FROM pr_sol_cargos
       WHERE cod_ent_seguro IS NOT NULL
         AND nro_solicitud = p_nro_solicitud;
   -- calcula el monto de seguro (pagado en el desembolso) a descontar por cancelación total de préstamos.
BEGIN
   pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);

   FOR g IN gastos(r_pcpre.nro_solicitud) LOOP
      --  ((saldo * 0.80* PlazoRestante)/30)/1000
      BEGIN
         SELECT cod_tasa
           INTO v_cod_tas_seguro
           FROM ge_transacciones
          WHERE cod_transaccion = g.cod_transaccion
            AND cod_modulo = r_pcpre.cod_modulo
            AND cod_modalidad = r_pcpre.cod_modalidad;
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_tas_seguro := NULL;
      END;
      v_plazo             := r_pcpre.fec_vencimiento - v_fecha;
      v_val_tas_seguro    := fug_obt_valtas_rango(v_cod_tas_seguro, r_pcpre.cod_modulo,
                                                  r_pcpre.cod_modalidad, r_pcpre.cod_moneda,
                                                  r_pcpre.cod_oficina, NULL, r_pcpre.fec_inicio);
      v_mto_seg_descontar := round(((r_pcpre.sal_cap_batch * v_val_tas_seguro * v_plazo) / 30) / 1000,
                                   0);

      pag_gen.pr_obt_val_tasa(r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_oficina,
                              p_nro_cuenta, r_pcpre.cod_moneda, v_mto_seg_descontar, 'N', v_cod_tasa,
                              1709, v_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);
      v_impuesto := round(nvl(v_mto_seg_descontar, 0) * (v_val_tas_impuesto / 100), 0);
   END LOOP;
   p_mto_seguro := p_mto_seguro + v_mto_seg_descontar;
   p_impuesto   := p_impuesto + v_impuesto;

EXCEPTION
   WHEN OTHERS THEN
      p_mto_seguro := 0;
      p_impuesto   := 0;

END prp_obt_mto_seg_descontado;
/

