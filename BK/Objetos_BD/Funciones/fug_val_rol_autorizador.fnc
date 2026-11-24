create or replace function it.FUG_VAL_ROL_AUTORIZADOR(
   p_cod_rol in ba_programas.cod_programa%type
  ,p_cod_usuario in ba_usuarios.cod_usuario%type)
   return varchar2 is
   v_resultado varchar2(1):='N';
begin
   select 'S'
     into v_resultado
     from ba_usu_roles a
    where upper(a.cod_usuario) = upper(p_cod_usuario)
      and instr(',' || p_cod_rol || ',', ',' || a.cod_rol || ',') > 0;
    return v_resultado;
exception
   when no_data_found then
      return 'N';
   when too_many_rows then
        return 'N';
   when others then
        return 'N';

end;
/

