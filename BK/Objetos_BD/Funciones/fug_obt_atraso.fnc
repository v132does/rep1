create or replace function it.FUG_OBT_ATRASO
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_TIP_ATRASO  IN VARCHAR2,                  --- A-Atraso, M-Maximo Atraso, P-Promedio atraso
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL,     --- Modalidad de cuenta  
   P_COD_MONEDA    IN VARCHAR2 DEFAULT NULL)   --- moneda de la cuenta
  return number is
  v_dia_atraso     number;  -- dia de atraso en cuenta
  v_dia_max_atraso number;  -- dia max atraso en la cuenta
  v_pro_atraso     number;  -- promedio de atraso
begin
  -- Busco los datos de atrasos en las cuentas que tiene el cliente
  SELECT nvl(max(dia_atraso),0) dia_atraso,
         nvl(max(max_atraso),0) dia_max_atraso,
         nvl(trunc(sum(pro_atraso)/decode(count(*),0,1),2),0) pro_atraso 
    INTO v_dia_atraso, v_dia_max_atraso, v_pro_atraso
    from GE_CUENTAS a, GE_CTA_CLIENTES B
   WHERE a.nro_cuenta = b.nro_cuenta
     and b.relacion = 'P'
     and b.cod_persona = p_cod_persona
     and b.cod_modalidad = nvl(p_cod_modalidad,b.cod_modalidad)
     and a.cod_moneda = nvl(p_cod_moneda,a.cod_moneda)
     and a.cod_modulo in (4,5,6,8)  -- solo cuentas pasivas
     and exists (Select 0
                   from ge_est_cuentas c
                  where c.cod_modulo = b.cod_modulo
                    and c.cod_modalidad = b.cod_modalidad
                    and c.estado = a.estado
                    and c.activo = 'S');
  if p_tip_atraso = 'A' then
     return (v_dia_atraso);
  elsif p_tip_atraso = 'M' then
     return (v_dia_max_atraso);
  elsif p_tip_atraso = 'P' then
    return (v_pro_atraso);
  else
    return 0;  
  end if;         
exception
  when others then
     raise_application_error(-20000,'FUG_OBT_CAN_CUENTAS '||sqlerrm);  
end FUG_OBT_ATRASO;
/

