CREATE OR REPLACE FUNCTION IT.fug_obt_contingencia_cliente (p_cod_persona in ba_personas.cod_persona%type) return number is
  v_monto number(18,2) := 0;
  v_contingencia number(18,2) := 0;
begin
 
  Begin
  
    
    select sum(pag_gen.FU_CON_MON_A_MONEDA(b.cod_moneda,'GS',nvl(fug_obt_contingencia(a.nro_cuenta), 0))) as contingencia
      into v_monto
      from ge_cta_clientes a, ge_cuentas b
     where a.cod_persona = p_cod_persona
       and a.nro_cuenta = b.nro_cuenta
     group by a.cod_persona;
  Exception     
    When OTHERS then
        return 0;        
  End;
  --
    v_contingencia := nvl(v_monto,0);
  
  return(v_contingencia);
end fug_obt_contingencia_cliente;
/

