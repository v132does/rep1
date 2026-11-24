CREATE OR REPLACE PROCEDURE IT.prg_obt_fec_val_transferencia
(  p_cod_msj_swift           IN  ge_snp_transferencias.cod_msj_swift%type,
   p_cod_tip_operacion       IN  ge_snp_transferencias.cod_tip_operacion%type,
   p_cod_sub_tip_operacion   IN  ge_snp_transferencias.cod_sub_tip_operacion%type,
   p_nro_cta_debito          IN  ge_snp_transferencias.nro_cta_solicitante%type,
   p_cod_mon_credito         IN  ge_snp_transferencias.cod_moneda%type,
   p_mto_credito             IN  ge_snp_transferencias.monto%type,
   p_fec_valor         OUT ge_snp_transferencias.fec_valor%type)
IS




   v_fec_sugerida        date;
   v_fec_operacion        date:=trunc(sysdate);
   v_cod_mon_credito      ge_snp_transferencias.cod_moneda%type;
   v_mto_credito          ge_movimientos.monto%type;  -- Monto de la transferencia
   v_cod_msj_swift         ge_snp_transferencias.cod_msj_swift%type;
   v_cod_tip_operacion ge_snp_transferencias.cod_tip_operacion%type;
   v_cod_sub_tip_operacion  ge_snp_transferencias.cod_sub_tip_operacion%type;
   v_nro_cta_debito         ge_snp_transferencias.nro_cta_solicitante%type;
BEGIN
   v_cod_mon_credito :=p_cod_mon_credito;
   v_mto_credito     :=p_mto_credito;
   v_cod_msj_swift:=p_cod_msj_swift;
   v_cod_tip_operacion:=p_cod_tip_operacion;
   v_cod_sub_tip_operacion:=p_cod_sub_tip_operacion;
   v_nro_cta_debito:=p_nro_cta_debito;

 if (to_char(sysdate, 'hh24:mi') >= fug_obt_pardinamico('SNP_HOR_FIN_MT102')
       and pas_snp.fu_obt_est_horario(v_cod_msj_swift, v_cod_tip_operacion, v_cod_sub_tip_operacion) = 'A'
        and instr(','||trim(fug_obt_pardinamico('SNP_COD_MON_ULT_PERIODO'))||',', ','||v_cod_mon_credito||',') = 0)
          or (to_char(sysdate, 'hh24:mi') >= fug_obt_pardinamico('SNP_HOR_FIN_MT102')
           and pas_snp.fu_obt_est_horario(v_cod_msj_swift, v_cod_tip_operacion,  v_cod_sub_tip_operacion) = 'A'
             and instr(','||trim(fug_obt_pardinamico('SNP_COD_MON_ULT_PERIODO'))||',', ','||v_cod_mon_credito||',') > 0
             and v_mto_credito > fug_obt_pardinamico('SNP_MTO_MAX_ULT_PERIODO'))
          -- Control de Monto Total en el último Período de intercambio
          or (to_char(sysdate, 'hh24:mi') >= fug_obt_pardinamico('SNP_HOR_FIN_MT102')
            and pas_snp.fu_obt_est_horario(v_cod_msj_swift, v_cod_tip_operacion,  v_cod_sub_tip_operacion) = 'A'
              and instr(','||trim(fug_obt_pardinamico('SNP_COD_MON_ULT_PERIODO'))||',', ','||v_cod_mon_credito||',') > 0
              and fug_obt_mto_max_cli_periodo(v_nro_cta_debito, v_fec_operacion, v_cod_mon_credito, v_mto_credito) > fug_obt_pardinamico('SNP_MTO_MAX_CLI_ULT_PERIODO', NULL, NULL, v_cod_mon_credito, NULL)) then
              v_fec_sugerida := pag_cal.fu_obt_fec_sig_hab(pag_cal.fu_obt_fec_actual(1), NULL);
              v_fec_operacion := v_fec_sugerida;
    else
      v_fec_sugerida := pas_snp.fu_obt_fec_transferencia(v_cod_msj_swift, v_cod_tip_operacion,v_cod_sub_tip_operacion, v_fec_operacion);
    end if;

    -- Valida la fecha ingresada para la transferencia
        if trunc(sysdate) <> v_fec_sugerida and v_cod_msj_swift!= fug_obt_pardinamico( 'COD_SPI_PCD' ) then
            v_fec_operacion :=  pas_snp.fu_obt_fec_transferencia(v_cod_msj_swift, v_cod_tip_operacion,v_cod_sub_tip_operacion, v_fec_operacion);

        end if;
      --devuelve los valores respectivos.
      p_fec_valor := trunc(v_fec_sugerida);

  EXCEPTION
    WHEN others then
      p_fec_valor := trunc(sysdate);
END;
/
