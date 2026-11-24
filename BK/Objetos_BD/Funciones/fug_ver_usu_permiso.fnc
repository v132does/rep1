create or replace function it.FUG_VER_USU_PERMISO
            (P_COD_USUARIO      BA_USU_ROLES.COD_USUARIO%TYPE,
             P_COD_MODULO       GE_TRANSACCIONES.COD_MODULO%TYPE,
             P_COD_MODALIDAD    GE_TRANSACCIONES.COD_MODALIDAD%TYPE,
             P_COD_TRANSACCION  GE_TRANSACCIONES.COD_TRANSACCION%TYPE)
  return varchar2 is
  v_tie_permiso varchar2(1);
  -- Verifico si el usuario tiene permiso a la transaccion
begin
  Select 'S' into v_tie_permiso
    from ba_usu_roles a,ge_tra_roles b
   where a.cod_rol = b.cod_rol
     and a.cod_usuario = p_cod_usuario
     and b.cod_transaccion = p_cod_transaccion
     and b.cod_modulo = p_cod_modulo
     and b.cod_modalidad = p_cod_modalidad;
  return(v_tie_permiso);
exception
  when no_data_found then
    return 'N';
  when too_many_rows then
    return 'S';
  when others then
    return 'N';
end FUG_VER_USU_PERMISO;
/

