CREATE OR REPLACE PROCEDURE IT.PRR_AGE_REPROGRAMAR
 (P_COD_AGENDA IN CR_AGENDAS.COD_AGENDA%TYPE
 ,P_COD_RESPONSABLE IN CR_AGENDAS.COD_USU_ENCARGADO%TYPE
 ,P_FEC_ACTIVIDAD IN DATE
 ,P_COD_ESTADO IN CR_AGENDAS.COD_ESTADO%TYPE
 ,P_DETALLE IN VARCHAR2
 ,P_IND_TIPO IN VARCHAR2
 )
 IS
  vold_estado    CR_AGENDAS.COD_ESTADO%TYPE;
  vold_usuario   CR_AGENDAS.COD_USU_ENCARGADO%TYPE;
  vold_campana   CR_AGENDAS.COD_CAMPANA%TYPE;
  vold_actividad CR_AGENDAS.COD_ACTIVIDAD%TYPE;
  vnew_agenda    CR_AGENDAS.COD_AGENDA%TYPE;
  vmensaje       VARCHAR2(2000);
  verror         EXCEPTION;
  v_gru_agenda   ba_usuarios.gru_agenda%type;
BEGIN
  ---
  -- Busca el estado reprogramacion para dejar a la actividad...
  ---
  BEGIN
    IF nvl( p_ind_tipo, 'P' ) = 'P' THEN
      select e.cod_estado
        into vold_estado
        from cr_agendas a, cr_age_est_actividades e
       where a.cod_agenda = p_cod_agenda
         and a.cod_actividad = e.cod_actividad
         and nvl( e.ind_reprogramacion, 'N' ) = 'S';
    ELSIF nvl( p_ind_tipo, 'P' ) = 'A' THEN
      select e.cod_estado
        into vold_estado
        from cr_agendas a, cr_age_est_actividades e
       where a.cod_agenda = p_cod_agenda
         and a.cod_actividad = e.cod_actividad
         and nvl( e.ind_reasignacion, 'N' ) = 'S';
    END IF;
  EXCEPTION
    when no_data_found then
      vmensaje := 'Error: no esta definido el estado de ';
      IF nvl( p_ind_tipo, 'P' ) = 'P' THEN
        vmensaje := vmensaje || 'Reprogramacion.';
      ELSE
        vmensaje := vmensaje || 'Reasignacion.';
      END IF;
      raise verror;
    when too_many_rows then
      vmensaje := 'Error: existen varios estados de ';
      IF nvl( p_ind_tipo, 'P' ) = 'P' THEN
        vmensaje := vmensaje || 'Reprogramacion.';
      ELSE
        vmensaje := vmensaje || 'Reasignacion.';
      END IF;
      raise verror;
    when others then
      vmensaje := 'ERROR. Al buscar el estado de ';
      IF nvl( p_ind_tipo, 'P' ) = 'P' THEN
        vmensaje := vmensaje || 'Reprogramacion ';
      ELSE
        vmensaje := vmensaje || 'Reasignacion ';
      END IF;
      vmensaje := vmensaje || sqlerrm;
      raise verror;
  END;
  -- Cambia el estado de la actividad a reprogramado
  BEGIN
    select x.gru_agenda
      into v_gru_agenda
      from ba_usuarios x
     where x.cod_usuario = upper(user);
    if fug_ver_pardinamico('PER_REP_ACT_GRU_'||v_gru_agenda,null,null,null,null) = 'S' then
       if fug_obt_pardinamico('PER_REP_ACT_GRU_'||v_gru_agenda,null,null,null,null) = 'N' then
          vmensaje := 'Usuario '||upper(user)||' no puede Reprogramar Actividades.';
          raise verror;
       end if;
    end if;
    update cr_agendas
       set cod_estado = vold_estado
     where cod_agenda = p_cod_agenda;
  EXCEPTION
    when verror then
      raise verror;
    when others then
      vmensaje := 'ERROR. Al actualizar el estado de la agenda ' || vold_estado || '-' || p_cod_agenda || '; ' || sqlerrm;
      raise verror;
  END;
  BEGIN
    select s_cod_agenda.nextval
      into vnew_agenda
      from dual;
  EXCEPTION
    when verror then
      raise verror;
    when others then
      vmensaje := 'ERROR. Al buscar el siguiente codigo de la agenda ' || sqlerrm;
      raise verror;
  END;
  BEGIN
    insert into cr_agendas( cod_agenda,
                            cod_persona,
                            cod_usu_encargado,
                            cod_actividad,
                            cod_estado,
                            cod_mot_actividad,
                            fec_actividad,
                            can_reprogramaciones,
                            det_actividad,
                            fec_vencimiento,
                            revisado,
                            automatico,
                            cod_campana,
                            cod_age_anterior,
                            nro_referencia,
                            cod_canal,
                            nro_orden,
                            cod_respuesta,
                            det_respuesta,
                            dia_atraso,
                            mto_mora,
                            fec_ini_asignacion )
                     select vnew_agenda,
                            a.cod_persona,
                            p_cod_responsable,
                            a.cod_actividad,
                            1 /* p_cod_estado */,
                            a.cod_mot_actividad,
                            p_fec_actividad,
                            nvl( a.can_reprogramaciones, 0 ) + 1,
                            nvl( p_detalle, a.det_actividad ),
                            a.fec_vencimiento,
                            'N',
                            'N',
                            a.cod_campana,
                            p_cod_agenda,
                            a.nro_referencia,
                            a.cod_canal,
                            a.nro_orden,
                            a.cod_respuesta,
                            a.det_respuesta,
                            a.dia_atraso,
                            a.mto_mora,
                            a.fec_ini_asignacion
                       from cr_agendas a
                      where a.cod_agenda = p_cod_agenda;
  EXCEPTION
    when verror then
      raise verror;
    when others then
      vmensaje := 'ERROR. No se pudo insertar la nueva actividad ' ||sqlerrm;
      raise verror;
  END;
  BEGIN
    select cod_usu_encargado, cod_campana, cod_actividad
      into vold_usuario, vold_campana, vold_actividad
      from cr_agendas
     where cod_agenda = p_cod_agenda;
  EXCEPTION
    when verror then
      raise verror;
    when others then
      vold_usuario := 'x';
  END;
  IF vold_campana IS NOT NULL THEN
    IF vold_usuario <> p_cod_responsable THEN
      update cr_cam_personas p
         set p.cod_usu_responsable = p_cod_responsable
       where ( p.cod_persona, p.cod_campana ) = ( select a.cod_persona, a.cod_campana
                                                    from cr_agendas a
                                                   where a.cod_agenda = p_cod_agenda );
    END IF;
    IF vold_actividad = fug_obt_pardinamico( 'COD_ACT_COBRANZA' ) THEN
      BEGIN
        update co_actividades
           set cod_agenda = vnew_agenda,
               fec_ini_asignacion = fec_ini_asignacion,
               cod_usu_responsable = nvl( p_cod_responsable, cod_usu_responsable )
         where cod_agenda = p_cod_agenda
           and cod_campana = vold_campana;
      EXCEPTION
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. No se pudo insertar las cuentas de la actividad para la agenda ' || vnew_agenda || '; ' || sqlerrm;
          raise verror;
      END;
    END IF;
  END IF;
EXCEPTION
  when verror then
    RAISE_APPLICATION_ERROR( -20333, vmensaje || sqlerrm );
  when others then
    vmensaje := 'ERROR. En el proceso de ';
    IF nvl( p_ind_tipo, 'P' ) = 'P' THEN
      vmensaje := vmensaje || 'Reprogramacion ';
    ELSE
      vmensaje := vmensaje || 'Reasignacion ';
    END IF;
    vmensaje := vmensaje || sqlerrm;
    RAISE_APPLICATION_ERROR( -20335, vmensaje );
END;
/

