create or replace function it.fug_obt_des_est_cta
 (p_cod_modulo in number, p_cod_modalidad in number, p_estado in varchar2)
 return varchar2 is
 v_r varchar2(200);
begin
  select descripcion
    into v_r
    from ge_est_cuentas a
   where a.cod_modulo = p_cod_modulo
     and a.cod_modalidad = p_cod_modalidad
     and a.estado = p_estado;
  return v_r;
exception
  when others then 
     return null;
end;
/

