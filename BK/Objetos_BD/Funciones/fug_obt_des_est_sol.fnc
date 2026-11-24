create or replace function it.fug_obt_des_est_sol(p_cod_estado varchar2) return varchar2 is
  v_descripcion ge_sol_estados.descripcion%type;
begin
  Select descripcion
    into v_descripcion
    from ge_sol_estados
   where cod_estado = p_cod_estado;
  return(v_descripcion);
Exception
  When NO_DATA_FOUND then
       v_descripcion := null;
       Return v_descripcion;
end fug_obt_des_est_sol;
/

