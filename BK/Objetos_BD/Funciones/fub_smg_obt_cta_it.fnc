CREATE OR REPLACE FUNCTION IT.FUB_SMG_OBT_CTA_IT (p_suc number,p_propuesta number,p_riesgo number) return varchar2 is
  result varchar2(20);
begin
  /*select l.account_number
    into result
  from loans_numero_cuenta l
  where l.nuries = p_riesgo
    and l.sucursalfu = p_suc
    and l.propuesta = p_propuesta;*/
   null;
  return(result);

  exception
    when no_data_found then
      return null;
    when others then
      return null;
end FUB_SMG_OBT_CTA_IT;
/

