CREATE OR REPLACE PROCEDURE IT.prs_snp_env_mt920
-- Procedimiento de envio de la Consulta de Saldos (MT920)
 IS
   v_cod_msj_swift       ge_snp_mensajes.cod_msj_swift%TYPE := '920';
   v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%TYPE := 'MT' || v_cod_msj_swift;

--cursor que obtiene cuenta bancaria para el envio de deposito--
  cursor cta_int_depo is
    select c.nro_cta_bancaria, c.cod_moneda
     from cc_cta_bancarias c
    where c.cod_modalidad = 455
      and exists (select 1
             from sb_snp_lim_depo s
            where s.val_parametro = c.nro_cuenta
              and s.estado = 'S'
              and s.cod_moneda = c.cod_moneda);
--DA-5991--
--cursor que recupera la cuenta bancaria NO configurada para envia de deposito
 cursor cta_depo is
 select c.nro_cta_bancaria, c.cod_moneda
   from cc_cta_bancarias c
  where c.cod_modalidad = 455
    and exists (select 1
           from sb_snp_lim_depo s
          where s.val_parametro = c.nro_cuenta
            and s.estado = 'N'
            and s.cod_moneda = c.cod_moneda)
    and c.nro_cta_bancaria in
        ((fug_obt_pardinamico('TRANSF_CTA_RES_LBTR')),
         (fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ')));
 
BEGIN
 begin
   FOR c in cta_int_depo LOOP
       -- Se llama al proceso de Consulta de Saldos MT920 para cta.config envio Deposito
       pas_dep.pr_obt_msj_MT920(v_cod_mensaje,
                        c.nro_cta_bancaria,
                        941,
                        NULL,
                        NULL,
                        0,
                        0,
                        c.cod_moneda,--pag_gen.FU_OBT_MON_LOCAL
                        'D');
   END LOOP;
  exception
    when others then
      raise_application_error(-20000, 'Error al Procesar la Consulta de Saldos MT920 Cta.Deposito: ' || SQLERRM);
  end;
  
  begin
    for i in cta_depo loop
      pas_snp.pr_obt_msj_MT920(v_cod_mensaje, i.nro_cta_bancaria, 941, null, null, null, null, null);
    end loop;
  exception
    when others then
      raise_application_error(-20001, 'Error al Procesar la Consulta de Saldos MT920 Cta.NoConfig: ' || SQLERRM);
  end;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20002, 'Error al Procesar la Consulta de Saldos MT920: ' || SQLERRM);
END prs_snp_env_mt920;
/

