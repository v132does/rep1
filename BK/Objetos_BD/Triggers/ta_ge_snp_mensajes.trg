CREATE OR REPLACE TRIGGER IT.TA_GE_SNP_MENSAJES
  after insert on ge_snp_mensajes
  for each row
declare
  v_nro_ref_externa       ge_snp_mensajes.nro_ref_externa%type;
  v_cod_moneda            sb_snp_lim_depo.cod_moneda%type;
  v_mto_bcp_disponible    sb_snp_lim_depo.monto%type;
  v_cta_pte_sol           cc_cta_bancarias.nro_cta_bancaria%type := fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ');
  v_monto                 sb_snp_mensajes.valor%type;
  
begin
  begin
    /*Solo se registran los recibidos por el momento*/
    insert into sb_snp_mensajes
      (cod_mensaje,
       nro_referencia,
       nro_lote,
       orden,
       nro_linea,
       campo,
       valor,
       descripcion,
       ind_requerido,
       nro_detalle,
       err_formato,
       err_validacion)
      (select cod_mensaje,
              :new.nro_referencia,
              null,
              orden,
              nro_linea,
              campo,
              valor,
              descripcion,
              nvl(ind_requerido,'N'),
              nvl(nro_detalle,1),
              err_formato,
              err_validacion
         from sb_snp_mensajes_tmp
        where cod_mensaje like
              '%' || substr(:new.cod_msj_swift, 2, 2) || '%'
          and valor is not null);
  exception
    when others then
    raise_application_error(-20000, SQLERRM);
      null;
  end;

  -- Se valida que la consulta de Saldo se solicitó para la Depo
  if :new.cod_msj_swift = '941' then
    if :new.nro_ref_externa like '%/D%' then
      v_nro_ref_externa := :new.nro_ref_externa;
      v_cod_moneda := substr(pao_pmt.fu_obt_val_campo(replace(:new.msj_swift,
                                                             pas_snp.fu_obt_sal_socket,
                                                             pas_snp.fu_obt_salto),
                                                     '64'),
                            8,
                            3);
      -- Si la consulta de Saldo que se solicitó es para la Depo, generamos el MT541
      if v_nro_ref_externa is not null then
         pas_dep.pr_obt_msj_mt541('MT541',
                                 v_cod_moneda,--pag_gen.FU_OBT_MON_LOCAL,
                                 0,
                                 0,
                                 NULL,
                                 'N');
      end if;
    elsif :new.nro_ref_externa like '%F%' then --consulta de saldo para fondeo
      v_nro_ref_externa := :new.nro_ref_externa;
      if v_nro_ref_externa is not null then
         pas_snp.pr_gen_MT202_automatico(0,v_cta_pte_sol);
      end if;
    end if;
  end if;
  
exception
  when others then
    raise_application_error(-20000, SQLERRM);
    --null;
end TA_GE_SNP_MENSAJES;
/

