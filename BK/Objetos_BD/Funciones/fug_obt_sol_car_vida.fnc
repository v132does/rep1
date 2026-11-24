create or replace function it.fug_obt_sol_car_vida(p_nro_solicitud in pr_sol_cargos.nro_solicitud%type)
--Busca si la solicitud de la cuenta de prestamo tiene o no Cargos de Seguro de Vida
return STRING is
  v_return varchar2(9);
  

begin

select case when sc.cod_transaccion = 1521
       then 'SI' -- Si tiene devuelve SI
       end as seg_vida
       into v_return
       from pr_sol_cargos sc
       where sc.nro_solicitud=p_nro_solicitud
       and sc.cod_transaccion = 1521;
  
  return v_return;
Exception
 when NO_DATA_FOUND then return 'NO'; --Si no encuentra datos con Cargos de Seguro de Vida devuelve NO
end fug_obt_sol_car_vida;
/

