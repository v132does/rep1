CREATE OR REPLACE FUNCTION IT.FUG_VER_INHIBICION
 (P_COD_PERSONA IN GE_CTA_CLIENTES.COD_PERSONA%TYPE
 ,P_COD_MODALIDAD IN GE_CTA_CLIENTES.COD_MODALIDAD%TYPE
 )
 RETURN VARCHAR2
 IS
v_salida varchar2(1);
  v_tipo varchar2(50) := 'AFE_TODOS';
begin
  if p_cod_modalidad in (41) then
     v_tipo := 'AFE_CTA_CORRIENTE';
  elsif p_cod_modalidad =334 then
      v_tipo := 'AFE_CTA_AHORRO_BAJO_RIESGO';
  elsif p_cod_modalidad in (31,32,33,34,35,36) then
     v_tipo := 'AFE_CTA_AHORRO';
  elsif ltrim(to_char(p_cod_modalidad)) like '6%' then
     v_tipo := 'AFE_CREDITOS';
  elsif ltrim(to_char(p_cod_modalidad)) like '5%' then
     v_tipo := 'AFE_TARJETAS';
  elsif ltrim(to_char(p_cod_modalidad)) like '7%' then
     v_tipo := 'AFE_CAMBIOS';
  end if;
  select decode(count(*),0,'N','S')
    into v_salida
   from ge_per_inhibidas a
   where cod_persona = p_cod_persona
     and fug_obt_parcausales(a.cod_causa, v_tipo) = 'S'
     and estado = 'I'; -- Controla por el estado no por el vencimiento
  return(v_salida);
exception
  when others then
     If sqlcode = -20000 then
        -- no existe tipo de causa;
        select decode(count(*),0,'N','S')
          into v_salida
          from ge_per_inhibidas a
         where cod_persona = p_cod_persona
           and estado = 'I'; -- Controla por el estado no por el vencimiento
        Return(v_salida);
     Else
       raise_application_error(-20000,'FUG_VER_INHIBICION '||sqlerrm);
     End if;
end;
/
