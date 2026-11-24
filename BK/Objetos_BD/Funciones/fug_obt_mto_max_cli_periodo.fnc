CREATE OR REPLACE FUNCTION IT.FUG_OBT_MTO_MAX_CLI_PERIODO(P_NRO_CTA_SOLICITANTE      IN ge_snp_transferencias.nro_cta_solicitante%type DEFAULT NULL,
                                                       P_FEC_VALOR                IN ge_snp_transferencias.fec_valor%type,
                                                       P_COD_MONEDA               IN ge_snp_transferencias.cod_moneda%type,
                                                       P_MONTO                    IN ge_snp_transferencias.monto%type)
  RETURN NUMBER IS
  /*
  || Obtiene el Monto Total de la transferencia en una determinada ocurrencia de Período
  */
v_monto  number(18,2);
v_nro_cta_pte_solicitante ge_snp_transferencias.nro_cta_pte_solicitante%type := pas_snp.fu_obt_cta_ban_participante(pas_snp.fu_obt_cod_swi_participante ( fug_obt_per_entidad ), P_COD_MONEDA);
BEGIN
  IF P_NRO_CTA_SOLICITANTE is not NULL THEN
     BEGIN
       -- Recupera el MT102 y MT103
       SELECT nvl(sum(t.monto), 0) +  nvl(P_MONTO, 0) monto
         INTO v_monto
         FROM ge_snp_transferencias t
        WHERE t.nro_cta_solicitante = P_NRO_CTA_SOLICITANTE
          AND t.cod_moneda          = P_COD_MONEDA
          AND trunc(t.fec_insercion) = P_FEC_VALOR
          AND t.nro_cta_pte_solicitante  = v_nro_cta_pte_solicitante
          AND ((to_char(sysdate, 'hh24:mi') > fug_obt_pardinamico('SNP_HOR_FIN_MT102')
           AND t.hora IS NULL OR t.hora > fug_obt_pardinamico('SNP_HOR_FIN_MT102'))
         OR to_char(t.fec_modificacion, 'hh24:mi') > fug_obt_pardinamico('SNP_HOR_FIN_MT102'))
      --AND instr(','||trim(fue_obt_des_refcodes('SNP_MON_PER_OCURRENCIA', fus_obt_per_ocurrencia))||',', ','||pag_gen.fu_obt_mon_fuerte||',') = 0
          AND t.cod_msj_swift       = 103
          AND (t.situacion in ('V','L')
           AND t.estado = 'A');
       IF v_monto is NULL THEN
          v_monto := 0;
       END IF;
     END;
  ELSE
    BEGIN
      -- Recupera el MT202
      SELECT nvl(sum(s.monto), 0) +  nvl(P_MONTO, 0) monto
        INTO v_monto
        FROM ge_snp_transferencias s
       WHERE s.nro_cta_pte_solicitante  = v_nro_cta_pte_solicitante
         AND s.cod_moneda               = P_COD_MONEDA
         AND trunc(s.fec_insercion)     = P_FEC_VALOR
         AND ((to_char(sysdate, 'hh24:mi') > fug_obt_pardinamico('SNP_HOR_FIN_MT102')
           AND s.hora IS NULL OR s.hora > fug_obt_pardinamico('SNP_HOR_FIN_MT102'))
         OR to_char(s.fec_modificacion, 'hh24:mi') > fug_obt_pardinamico('SNP_HOR_FIN_MT102'))
     --AND instr(','||trim(fue_obt_des_refcodes('SNP_MON_PER_OCURRENCIA', fus_obt_per_ocurrencia))||',', ','||pag_gen.fu_obt_mon_fuerte||',') = 0
         AND s.cod_msj_swift            = 202
         AND s.cod_tip_operacion        <> '014'
         AND s.cod_sub_tip_operacion not in ('001', '003')
         AND (s.situacion in ('V','L')
           AND s.estado = 'A');
      IF v_monto is NULL THEN
         v_monto := 0;
      END IF;
    END;
  END IF;

  return v_monto;

EXCEPTION
   when no_data_found then
      v_monto := 0;
      return v_monto;
   when others then
      v_monto := 0;
      return v_monto;
END;
/

