create or replace PROCEDURE IT.PRS_SNP_GEN_MT985_STAT( p_cod_tip_mensaje  in sb_snp_tip_mensajes.cod_mensaje%type,
                                                       p_nro_cta_bancaria in ge_snp_cta_bancos.nro_cta_bancaria%type,
                                                       p_cod_persona      in ba_personas.cod_persona%type
                                                      )
is
  v_nro_referencia          ge_snp_mensajes.nro_referencia%type := pas_snp.fu_obt_sig_nro_referencia;
  v_cod_swi_pte_solicitante ge_snp_transferencias.cod_swi_pte_solicitante%type := pas_snp.fu_obt_cod_swi_participante(p_cod_persona);
  v_mensaje                 ge_snp_mensajes.msj_swift%type;
begin

  pas_snp.pr_ini_registros;
  -- Cabecera
  pas_snp.g_lugar := 'Insertando en la tabla temporal SB_SNP_MENSAJES_TMP, ';
  pao_pmt.pr_ins_sb_snp_mensajes_tmp( p_cod_tip_mensaje,
                                     'CAB',
                                     '{1:F01'||rpad(pas_snp.g_usu_xadapter,12,'X')||'}'||
                                     '{2:I985'||rpad(pas_snp.fu_obt_bic_sistema,12,'X')||'N}'||
                                     '{3:{113:0020}}{4:'
                                    );
  -- Detalle
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '20', v_nro_referencia);
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '57A', pas_snp.fu_obt_bic_sistema);
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '59', '/'||p_nro_cta_bancaria);
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '59', v_cod_swi_pte_solicitante);
  pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, '75', 'STAT');


  pao_pmt.pr_ins_sb_snp_mensajes_tmp(p_cod_tip_mensaje, 'PIE', '-}');

    pas_snp.g_lugar := 'Creando la mensajería, ';
    pao_pmt.pr_pro_mt_enviado(p_cod_tip_mensaje, v_mensaje);

  BEGIN
    pas_snp.g_lugar := 'Insertando mensaje en GE_SNP_MENSAJES, ';
    insert into ge_snp_mensajes( nro_referencia,
                                 nro_ref_externa,
                                 cod_msj_swift,
                                 fec_valor,
                                 msj_swift,
                                 cod_moneda,
                                 monto,
                                 situacion,
                                 error,
                                 msj_swi_original
                               )
                         values( v_nro_referencia,
                                 null,
                                 985,
                                 pas_snp.g_fec_actual,
                                 v_mensaje,
                                 null,
                                 null,
                                 'V',
                                 null,
                                 v_mensaje
                               );
  exception
    when others then
      -- Hubo problema en la insercion   
      pas_snp.g_cod_error := 49;
      pas_snp.g_msj_error := SQLERRM;
      raise;
  END;

    if nvl(fug_obt_pardinamico('SNP_HAB_AWS'),'N') = 'S' then
      -- TRFS-533-Inserta mensaje para que el OWL/ETL procese

      begin
        insert into ge_men_env_sipap
          (nro_referencia,
           estado,
           msj_swift)
        values
          (v_nro_referencia,
           'PENDING',
           REPLACE(REPLACE(v_mensaje,
                           chr(10),
                           pas_snp.fu_obt_sal_socket),
                   chr(13),
                   '')
           );
      exception
        when others then
          -- Hubo problema en la insercion   
          pas_snp.g_cod_error := 49;
          pas_snp.g_msj_error := SQLERRM;
          raise;
      end;
    else
      pas_snp.g_lugar := 'Enviando mensaje swift al socket, ';
      pas_snp.pr_gen_arc_swi_lote(v_mensaje);
    end if; 

exception
   when others then
      pas_snp.g_cod_error := 89;
      pas_snp.g_msj_error := 'Error al Generar MT: '|| pas_snp.g_lugar ||' '|| sqlerrm;
end PRS_SNP_GEN_MT985_STAT;
/