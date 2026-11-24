CREATE OR REPLACE TRIGGER IT.TA_CR_PER_RECLAMOS
 BEFORE UPDATE --OF COD_USU_RESPONSABLE
 ON CR_PER_RECLAMOS
 FOR EACH ROW
DECLARE
 v_grupo cr_rec_estados.grupo%type;
BEGIN
  IF updating THEN
    IF nvl( :new.cod_usu_responsable, ' ' ) <> nvl( :old.cod_usu_responsable, ' ' ) THEN
      BEGIN
        update cr_agendas
           set cod_usu_encargado = :new.cod_usu_responsable
         where nro_referencia = :old.nro_reclamo
           and cod_actividad = '4';
      EXCEPTION
        when others then
          RAISE_APPLICATION_ERROR( -20000, 'No se pudo actualizar el responsable de la agenda ' || sqlerrm );
      END;
    END IF;
    -- MODIFICA EN EL DETALLE DE LA AGENDA --
    begin
        SELECT r.grupo
          INTO v_grupo
          FROM cr_rec_estados r
         WHERE cod_reclamo  = :new.cod_reclamo
           AND r.cod_rec_estado = :new.cod_rec_estado;
    exception
      when others then
        v_grupo := null;
    end;

    IF nvl( :new.detalle, ' ' ) <> nvl( :old.detalle, ' ' ) and v_grupo = 'P' THEN
      BEGIN
        update cr_agendas
           set det_actividad = :new.detalle
         where nro_referencia = :new.nro_reclamo
           and cod_usu_encargado = :new.cod_usu_responsable
           and cod_actividad = '4';
      EXCEPTION
        when others then
          RAISE_APPLICATION_ERROR( -20000, 'No se pudo actualizar el Detalle de Actividad de la agenda ' || sqlerrm );
      END;
    END IF;
    ------------------------------------------
  END IF;
END;
/

