DECLARE
  TYPE array_tabla_HIS IS TABLE OF GE_SNP_TRANSFERENCIAS_HIS%ROWTYPE INDEX BY BINARY_INTEGER;
  CURSOR c IS
    SELECT 
      nro_referencia,
      nro_lote,
      nro_sec_lote,
      cod_modulo,
      cod_modalidad,
      cod_oficina,
      cod_msj_swift,
      cod_tip_operacion,
      cod_sub_tip_operacion,
      msj_swift,
      fec_valor,
      fec_ingreso,
      fec_recepcion,
      fecha,
      hora,
      cod_usuario,
      cod_moneda,
      monto,
      cod_per_solicitante,
      nom_solicitante,
      dir_solicitante,
      cod_tip_doc_solicitante,
      nro_doc_solicitante,
      nro_cta_solicitante,
      cod_swi_pte_solicitante,
      cod_swi_suc_solicitante,
      nro_cta_pte_solicitante,
      cod_per_beneficiario,
      nom_beneficiario,
      dir_beneficiario,
      cod_tip_doc_beneficiario,
      nro_doc_beneficiario,
      nro_cta_beneficiario,
      nro_cta_pte_beneficiario,
      cod_swi_pte_beneficiario,
      cod_swi_suc_beneficiario,
      plazo,
      concepto,
      observacion,
      nro_ref_externa,
      tip_cargo,
      ind_valor,
      situacion,
      estado,
      tip_rechazo,
      mto_cargo,
      prioridad,
      nro_operacion,
      tip_mensaje,
      error,
      cod_usu_transaccion,
      usu_insercion,
      fec_insercion,
      usu_modificacion,
      fec_modificacion,
      imp_inf_hacienda,
      origen,
      plataforma,
      indemnizado,
      ref_oid,
      cod_per_intermediario,
      nom_intermediario,
      cod_swi_pte_intermediario,
      dir_intermediario,
      nro_cta_pte_intermediario,
      cod_bco_corresponsal,
      nom_corresponsal,
      cod_swi_pte_corresponsal,
      nro_cta_pte_corresponsal,
      nro_cta_suc_pte_solicitante,
      nro_cta_suc_pte_beneficiario,
      cod_servicio,
      ben_dir_correo,
      cod_tra_padre,
      nro_cta_ben_recibido
FROM IT.GE_SNP_TRANSFERENCIAS_HIS_TMP;
  v_registros array_tabla_HIS;
BEGIN
    OPEN c;
    LOOP
      FETCH c BULK COLLECT INTO v_registros LIMIT 80000;
      BEGIN
        FORALL i IN 1 .. v_registros.COUNT
          INSERT INTO GE_SNP_TRANSFERENCIAS_HIS VALUES v_registros(i);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000, 'Insert a ge_snp_transferencias_his - ' || SQLERRM);
      END;
	    COMMIT;
      EXIT WHEN c%NOTFOUND;
    END LOOP;
END;
