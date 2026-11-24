CREATE OR REPLACE PROCEDURE IT.PRG_REV_AUTOMATICA
 IS
   v_fecha          ge_calendarios.fec_actual%type;
   v_hora           ge_movimientos.hora%type;
   v_cod_mod_padre  ba_modulos.cod_modulo%type;
   v_cod_mad_padre  ge_modalidades.cod_modalidad%type;
   v_cod_tra_padre  ge_transacciones.cod_transaccion%type;
   r_gmovi          ge_movimientos%rowtype;
   -- Variable para capturar errores --
   v_msg_error      varchar2(500);
   -- Variables para generar multiusuarios --
   v_usuario_rev    ba_usuarios.cod_usuario%type;
   v_hora_rev       ge_movimientos.hora%type;
   v_can_user       number;

   --- Cursor de movimientos pendientes
   cursor pendientes is
   select distinct fecha, hora, cod_usuario
     from ge_movimientos a
    where fecha = v_fecha
      and estado in ('J','P','X')
      and reversado ='N'
      and not exists (select 0 from ge_aut_pedidos b
                       where b.cod_usuario = a.cod_usuario
                         and b.fecha = a.fecha
                         and b.hora = a.hora
                         and b.respuesta = 'P'
                         and b.estado = 'S')
    order by hora desc;--por si hay movimientos consecutivos

BEGIN
   --- Recuperar datos de fecha calendario
   v_fecha          := pag_cal.FU_OBT_FEC_ACTUAL(1);   
   
   --Obtener cantidad de usuarios de cierre
    BEGIN
      SELECT COUNT(*)
        INTO v_can_user
        FROM ba_cod_referencias
       WHERE dominio = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';
    END;

   for reg in pendientes loop
      begin
          select cod_mod_padre, cod_mad_padre, cod_tra_padre
            into v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre
            from (select cod_mod_padre, cod_mad_padre, cod_tra_padre
                    from ge_movimientos a
                   where fecha = reg.fecha
                     and hora = reg.hora
                     and cod_usuario = reg.cod_usuario
                   group by cod_mod_padre, cod_mad_padre, cod_tra_padre
                   having count(*) = (select max(count(*))
                                        from ge_movimientos b
                                       where fecha = reg.fecha
                                         and hora = reg.hora
                                         and cod_usuario = reg.cod_usuario
                                       group by cod_mod_padre, cod_mad_padre, cod_tra_padre))
           where rownum = 1;
      end;

      v_usuario_rev := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');         
      v_hora_rev    := PAG_CIE.FU_OBT_HORA(v_usuario_rev, 'S_HOR_MOVCIERRE','E');

      begin
      --- Inicializar variables auxiliares
      prg_rev_operacion(reg.fecha,
                        reg.hora,
                        reg.cod_usuario,
                        v_cod_mod_padre,
                        v_cod_mad_padre,
                        v_cod_tra_padre,
                        v_usuario_rev,  -- Nuevo Usuario --
                        v_hora_rev,     -- Nueva Hora --
                        'N', --Es nocturno.
                        'Reversion Automatica');

      if pag_cta.g_cod_error <> 0 then
         r_gmovi.estado    := 'E';
         r_gmovi.cod_error := fug_obt_err_sueldos(pag_cta.g_cod_error, 'A');
      end if;

      exception
          -------------------------------------------------------------------
          -- DETECCION DE ERROR TECNICO --
          -------------------------------------------------------------------
          when others then
             v_msg_error := SUBSTR(SQLERRM, 1, 500);

             it.pag_cie.PR_AT_INS_LOG(
                 p_cod_proceso  => 11,
                 p_nro_orden    => 149,
                 p_cod_programa => 'PRG_REV_AUTOMATICA',
                 p_mensaje      => v_msg_error || ' REV. AUTOMATICA DE OPER.PENDIENTES',
                 p_log_level    => it.pag_cie.c_log_ERROR,
                 p_contexto     => 'OUT',
                 p_fecha        => SYSDATE
             );
      end;
   end loop;
exception
   when others then
     if sqlcode <= -20000 then
        raise;
     else
        raise_application_error(-20000,'Rev.Automat. '||sqlerrm);
     end if;
END;
/
