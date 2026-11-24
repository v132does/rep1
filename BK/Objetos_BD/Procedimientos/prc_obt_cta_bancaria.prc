CREATE OR REPLACE PROCEDURE IT."PRC_OBT_CTA_BANCARIA"
 (P_COD_BANCO IN CC_CTA_BANCARIAS.COD_BANCO%TYPE
 ,P_COD_MONEDA IN CC_CTA_BANCARIAS.COD_MONEDA%TYPE
 ,P_COD_OFICINA IN CC_CTA_BANCARIAS.COD_OFICINA%TYPE default null
 ,P_CUENTA OUT CC_CTA_BANCARIAS.NRO_CTA_BANCARIA%TYPE
 ,P_MODALIDAD OUT CC_CTA_BANCARIAS.COD_MODALIDAD%TYPE
 )
 IS
 v_cod_mon_local varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;

 begin
  select nro_cuenta,cod_modalidad
    into p_cuenta,p_modalidad
    from cc_cta_bancarias
    --WA:08/08/2014 se agrega para modalidad 49
   where (cod_banco   = p_cod_banco or cod_ente= p_cod_banco)
     and cod_moneda  = p_cod_moneda
     and cod_oficina = nvl(p_cod_oficina,cod_oficina)
     --WA:08/08/2014 se agrega para modalidad 49
     and ((cod_modalidad = 42 and p_cod_moneda=v_cod_mon_local) or
          (cod_modalidad = 49 and p_cod_moneda=v_cod_mon_local) or
          (cod_modalidad = 442 and p_cod_moneda<>v_cod_mon_local))
     and rownum = 1
   order by nro_cuenta;
exception
  when no_data_found then
    if p_cod_oficina is not null then
      prc_obt_cta_bancaria(p_cod_banco,p_cod_moneda, null, p_cuenta, p_modalidad);
    else
      p_cuenta    := null;
      p_modalidad := null;
    end if;
end;
/

