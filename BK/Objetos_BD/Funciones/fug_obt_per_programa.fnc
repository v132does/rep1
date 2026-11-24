create or replace function it.fug_obt_per_programa(
      p_cod_usuario ba_usuarios.cod_usuario%type,
      p_cod_programa ba_programas.cod_programa%type,
      p_per_necesario varchar2
   ) return varchar2 is

      cursor c1 is
        select   inserta,
                elimina,
                actualiza,
                consulta,
                imprime
          from ba_usu_roles r, ba_rol_programas a
         where r.cod_usuario = p_cod_usuario
           and a.cod_rol = r.cod_rol
           and a.cod_programa = p_cod_programa;

      v_permiso varchar2(5) := '';
begin
      for c1rec in c1 loop
        if c1rec.inserta = 'S' and
           (instr(v_permiso,'I') = 0  or v_permiso is null) then
            v_permiso := v_permiso||'I';
        end if;

        if c1rec.elimina = 'S' and
           (instr(v_permiso,'D') = 0  or v_permiso is null) then
            v_permiso := v_permiso||'D';
        end if;

        if c1rec.consulta = 'S' and
           (instr(v_permiso,'Q') = 0  or v_permiso is null) then
            v_permiso := v_permiso||'Q';
        end if;

        if c1rec.actualiza = 'S' and
           (instr(v_permiso,'U') = 0  or v_permiso is null) then
            v_permiso := v_permiso||'U';
        end if;

        if c1rec.imprime = 'S' and
           (instr(v_permiso,'P') = 0  or  v_permiso is null) then
            v_permiso := v_permiso||'P';
        end if;
     end loop;
     --Evaluacion del permiso--
     If nvl(instr(v_permiso, UPPER(p_per_necesario)), 0) = 0 Then
  	    -- No posee el permiso Solicitado --
        return 'N';
  	 else
        return 'S';
     End If;
end fug_obt_per_programa;
/

