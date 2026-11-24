create or replace function it.fug_sal_promedio(P_COD_PERSONA IN VARCHAR2,
                                            P_COD_MODALIDAD IN NUMBER) return number is
  v_tot_promedio NUMBER;
begin
  -- BUSCO EL SALDO PROMEDIO DE LA PERSONA EN una modalidad
  Select sum(a.sal_promedio * nvl(pag_gen.fu_obt_cotizacion(a.cod_moneda,sysdate),1)) 
    into v_tot_promedio
    from ge_cuentas a, ge_cta_clientes b
   where b.cod_persona = p_cod_persona
     and b.relacion = 'P'
     and b.nro_cuenta = a.nro_cuenta
     and b.cod_modalidad = p_cod_modalidad;
  return(v_tot_promedio);
exception
  when others then
    raise_application_error(-20000,'FUG_SAL_PROMEDIO '||sqlerrm);  
end fug_sal_promedio;
/

