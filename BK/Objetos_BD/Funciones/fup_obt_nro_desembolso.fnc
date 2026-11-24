CREATE OR REPLACE FUNCTION IT.FUP_OBT_NRO_DESEMBOLSO (p_cod_persona in ba_personas.cod_persona%type,
                                                     p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type)
return number is
v_cant number := 0;
v_count number := 0;


  cursor clientes is
 select a.cod_persona, a.nro_cuenta, b.fec_inicio
    from ge_cta_clientes a, pr_cta_prestamos b
   where a.cod_persona = p_cod_persona
     and a.cod_modalidad = '612'
     and a.nro_cuenta = b.nro_cuenta
     order by 3 asc;

begin 
     
      select count(1)
      into v_count
    from ge_cta_clientes a, pr_cta_prestamos b
   where a.cod_persona = p_cod_persona
     and a.cod_modalidad = '612'
     and a.nro_cuenta = b.nro_cuenta
     and a.nro_cuenta = p_nro_cuenta;
     
     if v_count >= 1 then
     
       for x in clientes loop
         
             v_cant := v_cant + 1;
             if x.nro_cuenta = p_nro_cuenta then
              return v_cant;
             end if;
         
         end loop;
         
        else
        
          return v_cant;
         
       end if;
       
     
exception
   when others then
       return null;
end;
/

