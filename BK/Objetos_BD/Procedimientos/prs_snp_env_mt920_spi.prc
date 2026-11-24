CREATE OR REPLACE PROCEDURE IT.prs_snp_env_mt920_spi
 /*Procedimiento de envio de MT920 para fondeo entre cuentas*/
 /*nrecalde SPI*/
 IS
   v_cod_msj_swift       ge_snp_mensajes.cod_msj_swift%TYPE := '920';
   v_cod_mensaje         sb_snp_tip_mensajes.cod_mensaje%TYPE := 'MT' || v_cod_msj_swift;
   v_cta_pte_sol         cc_cta_bancarias.nro_cta_bancaria%type := fug_obt_pardinamico('TRANSF_CTA_LBTR_LIQ'); --la consulta debe ir para la ctaLiq;
   v_existe_fli          varchar2(1);
   v_existe_dev          varchar2(1);
   v_enviar              varchar2(1):= 'N';
begin
 --primeramente verificamos si existe un fli en la fecha de ejecucion--
  begin
    select 'S'
      into v_existe_fli
      from ge_snp_transferencias s
     where s.fec_valor = trunc(sysdate)--TRFS-990
       and s.cod_msj_swift = 986
       and s.situacion = 'L'
       and s.estado = 'A'
       and s.ref_oid is not null;
  exception
    when no_data_found then
      v_existe_fli := 'N';
    when too_many_rows then--TRFS-990
      v_existe_fli := 'S';
    when others then
      raise_application_error(-20000,
                              'Error al buscar registros de FLI - prs_snp_env_mt920_spi: ' ||
                              SQLERRM);
  end;
  
  --si existe un FLI en la fecha de ejecucion
  --validar recepcion de MT202 de debito del FLI de la cuenta liquidación de esa fecha
  if v_existe_fli = 'S' then
     begin
       select 'S'
         into v_existe_dev
         from ge_snp_transferencias s
        where s.fec_valor = trunc(sysdate)--TRFS-990
          and s.cod_msj_swift = 202
          and s.cod_tip_operacion = 001
          and s.cod_sub_tip_operacion = 006
          and s.situacion = 'L'
          and s.estado = 'A'
          and exists (select 1
                 from ge_snp_mensajes t
                where t.fec_valor = trunc(sysdate)--TRFS-990
                  and t.cod_msj_swift = 900
                  and t.nro_ref_externa = s.nro_ref_externa)
          and rownum = 1;
     exception
       when no_data_found then
         v_existe_dev := 'N';
       when others then
         raise_application_error(-20001,
                                 'Error al buscar MT202 de debito FLI - prs_snp_env_mt920_spi: ' ||
                                 SQLERRM);
     end;
  end if;
  
  -- Si existe Fli y existe MT202 de debito entonces envia la consulta de saldo por la cta de liquidacion
  -- Si no existe el fli por ende no existe el MT202 de debito del fli , entonces debe enviar la consulta de saldo
  -- Si existe el fli pero todavia no existe su respuesta MT202 de debito debera llamar a una funcion hasta encontrar su respuesta
  
  if v_existe_fli = 'S' and v_existe_dev = 'S' then
    v_enviar := 'S';
  elsif v_existe_fli = 'N' then
    v_enviar := 'S';
  elsif v_existe_fli = 'S' and v_existe_dev = 'N' then
    v_enviar := 'S';
    --null; --preguntar
  end if;
   
--se llama al proceso de Consulta de Saldos MT920 desde el pas_snp
  if v_enviar = 'S' then
    pas_dep.pr_obt_msj_MT920(v_cod_mensaje,
                          v_cta_pte_sol,
                          941,
                          NULL,
                          NULL,
                          0,
                          0,
                          pag_gen.FU_OBT_MON_LOCAL,
                          'F');
  end if;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20002, 'Error al Procesar la Consulta de Saldos MT920 para el fondeo: ' || SQLERRM);

END prs_snp_env_mt920_spi;
/
