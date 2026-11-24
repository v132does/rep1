create or replace procedure it.PRE_VER_ACT_PENDIENTES
              (P_COD_USUARIO in BA_USUARIOS.COD_USUARIO%TYPE,
               P_MENSAJE in out VARCHAR2,
               P_COD_PROGRAMA in out BA_PROGRAMAS.COD_PROGRAMA%TYPE) is
  v_cantpend number;
begin
  p_cod_programa := null;
  p_mensaje      := null;
    -- Control Dual - Roles-
  /*Select count(*) into v_cantpend
    from wf_gru_usuarios b, wf_circuitos a
   where a.estado = 'E' -- pendiente
     and fec_inicio <= sysdate
     and b.cod_grupo = a.cod_gru_res_actual
     and b.cod_usuario = p_cod_usuario
     and rownum = 1;*/
   Select count(*)
     into v_cantpend
     from wf_gru_roles b, wf_circuitos a, ba_usu_roles r
    where a.estado = 'E' -- pendiente
      and fec_inicio <= sysdate
      and b.cod_grupo = a.cod_gru_res_actual
      and b.cod_rol = r.cod_rol
      and r.cod_usuario = p_cod_usuario
      and rownum = 1;

     if v_cantpend > 0 then
        p_cod_programa := 'WMSEGUIM';
        p_mensaje      := 'Ud tiene tareas pendientes de WorkFlow. Desea verlas?';
     else
      Select count(*) into v_cantpend
        from GE_AUT_PEDIDOS
       where cod_usu_autorizador = p_cod_usuario
         and respuesta = 'P' -- pendiente
         and estado = 'S'
         and rownum = 1;
      if v_cantpend > 0 then
         p_cod_programa := 'GMAPRAUT';
         p_mensaje      := 'Ud tiene pedidos de autorización pendientes. Desea verlos?';
      ELSE
        Select count(*) into v_cantpend
          from cr_agendas
         where cod_usu_encargado = p_cod_usuario
           and cod_estado = 1 -- pendiente
           and fec_actividad <= sysdate
           and rownum = 1;
        if v_cantpend > 0 then
           p_cod_programa := 'ERAGENDA';
           p_mensaje      := 'Ud tiene tareas pendientes en su Agenda. Desea verlas?';
        end if;

    end if;
  END IF;
end PRE_VER_ACT_PENDIENTES;
/

