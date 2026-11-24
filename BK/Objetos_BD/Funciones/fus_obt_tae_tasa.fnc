CREATE OR REPLACE FUNCTION IT.FUS_OBT_TAE_TASA
 (P_TASA IN NUMBER
 ,P_PERIODO_CAPIT IN NUMBER
 ,P_TIP_INTERES IN VARCHAR2
 )
 return number is
 v_tae   number;

begin
  If p_tip_interes = 'A' then
    v_tae := 100*((1/power((1-(p_tasa * p_periodo_capit/36500)),(365/p_periodo_capit)))-1);
  elsif p_tip_interes = 'V' then
    v_tae := 100*( power( (1+(p_tasa * p_periodo_capit/36500)),(365/p_periodo_capit)  ) -1  );
  else
    v_tae := 0;
  End if;
  return Round(v_tae,2);
exception
  when zero_divide then
     v_tae := '-999';
     return Round(v_tae,2);
  when others then
     v_tae := '-999';
     return Round(v_tae,2);
end fus_obt_tae_tasa;
/

