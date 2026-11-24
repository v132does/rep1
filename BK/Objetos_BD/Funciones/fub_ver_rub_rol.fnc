create or replace function it.FUB_VER_RUB_ROL
            (P_COD_RUBRO     CB_RUBROS.COD_RUBRO%TYPE,
             P_COD_USUARIO   BA_USU_ROLES.COD_USUARIO%TYPE,
             P_COD_PROGRAMA  BA_PROGRAMAS.COD_PROGRAMA%TYPE,
             P_FECHA DATE DEFAULT NULL)
  return varchar2 is
--verifica si el usuario puede utilizar el rubro según el rol asignado
--y/o el programa desde el que es llamado
  v_tie_permiso varchar2(1);
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
begin

  Select 'S' into v_tie_permiso
    from cb_rubros c, ba_usu_roles b, cb_rub_roles a
   where b.cod_rol = a.cod_rol
     and b.cod_usuario = p_cod_usuario
     and a.cod_rubro = p_cod_rubro
     and nvl(a.cod_programa,nvl(p_cod_programa,'XX')) = nvl(p_cod_programa,'XX')
     and a.cod_rubro = c.cod_rubro
     and (c.fec_inicio is null or c.fec_inicio <= nvl(p_fecha, v_fec_actual)) 
     and (c.fec_fin is null or c.fec_fin >= nvl(p_fecha, v_fec_actual));
  return(v_tie_permiso);
exception
  when no_data_found then
    return 'N';
  when too_many_rows then
    return 'S';
  when others then
    return 'N';
end FUB_VER_RUB_ROL;
/

