CREATE OR REPLACE TRIGGER IT.TB_CR_AGENDAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CR_AGENDAS
 FOR EACH ROW
DECLARE
  v_nractiv        CR_AGENDAS.COD_AGENDA%TYPE;
  --v_cod_rec_estado CR_REC_ESTADOS.COD_REC_ESTADO%TYPE;
  v_nvo_grupo      VARCHAR2(1) := 'X';
  v_ant_grupo      VARCHAR2(1) := 'X';
BEGIN
  IF nvl( pae_cnf.g_programa, 'x' ) <> 'GPELIPER' THEN -- eliminacion de personas
    IF inserting THEN
      IF :new.cod_agenda IS NULL THEN
        BEGIN
          select s_cod_agenda.nextval
            into v_nractiv
            from dual;
        EXCEPTION
          when others then
            v_nractiv := 0;
        END;
        :new.cod_agenda := v_nractiv;
      END IF;
      /* ya no se maneja por agenda los reclamos por Workfolw - ramg2009
      IF nvl(:new.can_reprogramaciones,0) > 0 AND
         fug_obt_pardinamico('COD_ACT_RECLAMO',null,null,null,null) IS NOT NULL THEN

          --- Recuperar estado del reclamo segun estado de la agenda
          BEGIN
            select e.cod_rec_estado
              into v_cod_rec_estado
              from cr_rec_estados  e, cr_per_reclamos r
             where e.cod_reclamo = r.cod_reclamo
               and r.nro_reclamo = :new.nro_referencia
               and e.cod_actividad = :new.cod_actividad
               and e.cod_estado = :new.cod_estado;
          EXCEPTION
            when no_data_found then
              RAISE_APPLICATION_ERROR( -20000, 'Estado de la Agenda no definido en Reclamos. Estado [' ||
                                               to_char( :new.cod_estado ) || '], Actividad [' ||
                                               to_char( :new.cod_actividad ) || ']' );
          END;

        -- Actualizacion de los datos de Reclamos y Pedidos
          update cr_per_reclamos r
             set r.cod_usu_responsable = :new.cod_usu_encargado,
                 r.cod_rec_estado = v_cod_rec_estado
           where r.nro_reclamo = :new.nro_referencia;
             
      END IF;
      */   
    ELSIF updating THEN
      BEGIN
        select grupo
          into v_ant_grupo
          from cr_age_est_actividades
         where cod_actividad = :old.cod_actividad
           and cod_estado = :old.cod_estado;
      EXCEPTION
        when others then
          v_ant_grupo := 'X';
      END;
      BEGIN
        select grupo
          into v_nvo_grupo
          from cr_age_est_actividades
         where cod_actividad = :new.cod_actividad
           and cod_estado = :new.cod_estado;
        IF v_nvo_grupo = 'R' THEN
          :new.fec_realizacion := to_date( to_char( pag_cal.fu_obt_fec_actual( pae_cnf.g_cod_modulo ), 'DD/MM/RRRR' ) ||
                                  ' ' || to_char( sysdate, 'HH24:MI' ), 'DD/MM/RRRR HH24:MI' );
        END IF;
      EXCEPTION
        when others then
          v_nvo_grupo := 'X';
      END;
      
      IF :new.cod_campana IS NOT NULL THEN
        -- Actualizacion de los datos de la Campana
        IF v_nvo_grupo = 'R' AND
           v_ant_grupo = 'P' THEN
          update cr_cam_personas
             set estado = 3
           where cod_persona = :new.cod_persona
             and cod_campana = :new.cod_campana;
        END IF;
  
        IF v_nvo_grupo = 'C'  AND
           v_ant_grupo <> 'C' THEN
          update cr_cam_personas a
             set a.estado = 9
           where a.cod_persona = :new.cod_persona
             and a.cod_campana = :new.cod_campana
             and not exists ( select t.cod_actividad
                                from cr_age_est_actividades t
                               where t.cod_estado = :new.cod_estado
                                 and t.ind_reprogramacion = 'S'
                            );
        END IF;
  
      END IF;
              
      IF :new.cod_mot_actividad = 3 AND
         :new.cod_actividad = 3 AND
         :new.nro_referencia IS NOT NULL THEN
        -- Actualizacion de los datos de recepcion
        IF :new.cod_estado = 2 AND
           :old.cod_estado = 1 THEN
          update cr_atenciones
             set estado = 'A',
                 fec_hor_atencion = sysdate
           where cod_atencion = :new.nro_referencia;
        END IF;
      ELSIF :new.cod_mot_actividad = 4 AND
            :new.cod_actividad = 4 AND
            :new.nro_referencia IS NOT NULL THEN
        -- Actualizacion de los datos del recepcion
        null;
        /* ya se maneja por workflow
        IF nvl( :new.det_respuesta, ' ' ) <> nvl( :old.det_respuesta, ' ' ) THEN
          update cr_per_reclamos
             set det_solucion = :new.det_respuesta
           where nro_reclamo = :new.nro_referencia;
        END IF;
        IF :new.cod_estado <> :old.cod_estado THEN
          --- Recuperar estado del reclamo segun estado de la agenda
          BEGIN
            select e.cod_rec_estado
              into v_cod_rec_estado
              from cr_rec_estados  e, cr_per_reclamos r
             where e.cod_reclamo = r.cod_reclamo
               and r.nro_reclamo = :new.nro_referencia
               and e.cod_actividad = :new.cod_actividad
               and e.cod_estado = :new.cod_estado;
          EXCEPTION
            when no_data_found then
              RAISE_APPLICATION_ERROR( -20000, 'Estado de la Agenda no definido en Reclamos. Estado [' ||
                                               to_char( :new.cod_estado ) || '], Actividad [' ||
                                               to_char( :new.cod_actividad ) || ']' );
          END;
          update cr_per_reclamos
             set cod_rec_estado = v_cod_rec_estado,
                 fec_solucion = sysdate
           where nro_reclamo = :new.nro_referencia;
        END IF;
        */
      END IF;
    ELSIF deleting THEN
      IF :old.cod_actividad = fug_obt_pardinamico( 'COD_ACT_COBRANZA' ) AND
         :old.cod_campana IS NOT NULL AND
         ( nvl( :old.automatico, 'N' ) = 'S' OR
           nvl( :old.can_reprogramaciones, 0 ) > 0 ) THEN
        BEGIN
          delete co_actividades
           where cod_campana = :old.cod_campana
             and cod_agenda = :old.cod_agenda
             and nro_cuenta IS NOT NULL;
        EXCEPTION
          when no_data_found then
            NULL;
          when others then
            RAISE_APPLICATION_ERROR( -20012, 'Error. Al borrar las actividades de la agenda ' || sqlerrm);
        END;
      END IF;
    END IF;
  END IF;
END;
/

