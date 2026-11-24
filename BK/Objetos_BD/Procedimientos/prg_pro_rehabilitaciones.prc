CREATE OR REPLACE PROCEDURE IT.PRG_PRO_REHABILITACIONES (P_FILA VARCHAR2)
IS
  v_cod_tip_documento ba_tip_documentos.cod_tip_documento%TYPE := NULL;
  v_cod_persona       ba_personas.cod_persona%TYPE;
  v_tipo              ba_personas.tipo%TYPE;
  v_detalle           ge_per_inhibidas.detalle%TYPE;
  v_msj_error         VARCHAR2(200);
  reg                 tm_osc_reha_pendientes%ROWTYPE;
BEGIN
  SELECT * INTO reg FROM tm_osc_reha_pendientes WHERE ROWID = p_fila;

  prg_cre_savepoint('reha');

  -- Busco el tipo de documento
  BEGIN
    SELECT cod_tip_documento
      INTO v_cod_tip_documento
      FROM ba_tip_documentos a
     WHERE abreviatura = reg.tipo_document
       AND estado = 'A'
       AND rownum = 1;
  EXCEPTION
    WHEN OTHERS THEN
    	v_msj_error := 'Error al obtener cod_tip_documento';
      RAISE;
  END;

  --Obtiene el codigo de persona
  BEGIN
    SELECT cod_persona, tipo
      INTO v_cod_persona, v_tipo
      FROM ba_personas
     WHERE cod_tip_documento = v_cod_tip_documento
       AND nro_documento = reg.nro_documento;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_msj_error := 'No se encontró la persona con este nro. de documento';
      RAISE;
    WHEN OTHERS THEN
      v_msj_error := 'Error al obtener el codigo de persona';
      RAISE;
  END;

  IF v_tipo = 'F' THEN
    -- Verifica si coincide el primer nombre y apellido
    DECLARE
      v_existe VARCHAR2(1);
    BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ba_per_fisicas f
       WHERE f.cod_persona = v_cod_persona
         AND f.pri_nombre = reg.nombre1
         AND f.pri_apellido = reg.apellido1;
    EXCEPTION
      WHEN no_data_found THEN
        v_msj_error := 'No hay coincidencia en el primer nombre y/o primer apellido';
        RAISE;
    END;
  END IF;

  --Arma el detalle que debe ser guardado
  v_detalle := ' Rehabilitado en fecha: ' || reg.fecha_circula ||
               ' Circular: Año: ' || reg.ano_circular ||
               ' Nro: ' || reg.nro_circular || ' Sec.: ' || reg.nro_secuencia;

  prg_cre_savepoint('reha');

  -- Actualiza las inhibiciones
  DECLARE
    v_posicion  NUMBER(5);
    v_can_inhi  NUMBER(5);

    CURSOR c_inhi IS
    SELECT cod_persona, detalle, nro_orden, ROWID fila
      FROM ge_per_inhibidas
     WHERE cod_causa in (21,22) -- solo inhibiciones de Infocheck
       AND cod_persona = v_cod_persona;
  BEGIN
    FOR inh IN c_inhi LOOP
      v_can_inhi := v_can_inhi + 1;
      v_posicion := instr(inh.detalle, v_detalle);
      IF v_posicion = 0 THEN -- si el detalle no existe
        -- Actualiza las inhibiciones
        UPDATE ge_per_inhibidas
           SET estado = 'D',
               detalle = detalle || chr(10) || v_detalle
         WHERE ROWID = inh.fila;
      END IF;
    END LOOP;
    IF v_can_inhi = 0 THEN
      v_msj_error := 'No se encontró la inhibicion de la persona';
      raise_application_error(-20000, v_msj_error);
    END IF;
  END;

  -- Si no hubo error borra el registro de rehabilitaciones pendientes
  DELETE FROM tm_osc_reha_pendientes WHERE ROWID = p_fila;

EXCEPTION
  WHEN OTHERS THEN
    IF v_msj_error IS NULL THEN
      raise_application_error(-20000, SQLERRM);
    END IF;

    prg_rol_savepoint('reha'); --- Desahace lo que ya hizo

    -- Actualiza el mensaje de error
    UPDATE tm_osc_reha_pendientes
       SET msj_error = v_msj_error,
           cod_tip_documento = v_cod_tip_documento
     WHERE nro_secuencia = reg.nro_secuencia
       AND nro_circular = reg.nro_circular
       AND ano_circular = reg.ano_circular;
END;
/

