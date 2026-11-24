CREATE OR REPLACE PROCEDURE IT.PRG_PRO_INHIBICIONES (P_FILA            VARCHAR2,
                                                  P_IND_CRE_PERSONA VARCHAR2 DEFAULT 'N',
                                                  P_IND_VAL_NOMBRE  VARCHAR2 DEFAULT 'N')
IS
  v_cod_tip_documento ba_tip_documentos.cod_tip_documento%TYPE := NULL;
  v_cod_persona       ba_personas.cod_persona%TYPE;
  v_tipo              ba_personas.tipo%TYPE;
  v_nom_completo      ba_personas.nom_completo%TYPE;
  v_msj_error         VARCHAR2(200);
  v_cantidad          NUMBER(5);
  reg                 tm_osc_inhi_pendientes%ROWTYPE;
  v_ano               NUMBER(2);
  v_fec_vencimiento   DATE;
  v_detalle           VARCHAR2(300);
BEGIN
  SELECT * INTO reg FROM tm_osc_inhi_pendientes WHERE ROWID = p_fila;

  prg_cre_savepoint('inhi');

  -- Busco el tipo de documento
  BEGIN
    SELECT cod_tip_documento
      INTO v_cod_tip_documento
      FROM ba_tip_documentos a
     WHERE abreviatura = reg.tipo_document
       AND estado = 'A'
       AND ROWNUM = 1;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_tip_documento := 999; -- otros
    WHEN OTHERS THEN
      v_msj_error := 'Error al obtener cod_tip_documento';
      RAISE;
  END;

  -- Verifica la longitud del documento
  DECLARE
    v_lon        NUMBER(10);
    v_lon_minima ba_tip_documentos.lon_minima%TYPE;
    v_lon_maxima ba_tip_documentos.lon_maxima%TYPE;
  BEGIN
    v_lon := length(reg.nro_documento);
    SELECT lon_minima, lon_maxima
      INTO v_lon_minima, v_lon_maxima
      FROM ba_tip_documentos
     WHERE cod_tip_documento = v_cod_tip_documento;
    IF NOT (v_lon BETWEEN v_lon_minima AND v_lon_maxima) THEN
      v_msj_error := 'La longitud del documento está fuera de rango';
      raise_application_error(-20000, v_msj_error);
    END IF;
  END;

  -- Verifica el formato del documento
  BEGIN
    IF NOT fue_val_tip_doc(v_cod_tip_documento, reg.nro_documento, v_msj_error) THEN
      v_msj_error := v_msj_error || ' (Nro. Documento)';
      raise_application_error(-20000, v_msj_error);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_msj_error := SQLERRM || ' (Nro. Documento)';
      raise_application_error(-20000, v_msj_error);
  END;

  -- Verifica si ya existe la persona en GF
  BEGIN
    SELECT cod_persona
      INTO v_cod_persona
      FROM ba_personas
     WHERE cod_tip_documento = v_cod_tip_documento
       AND nro_documento = reg.nro_documento;
  EXCEPTION
    WHEN no_data_found THEN
      v_cod_persona := NULL;
      v_tipo        := NULL;
    WHEN OTHERS THEN
      v_msj_error := 'Error al obtener codigo de persona: ' || SQLERRM;
      RAISE;
  END;
  
    Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
	
  IF v_cod_persona IS NOT NULL THEN  -- Existe la persona
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
  ELSE -- No existe la persona
    IF p_ind_cre_persona = 'S' THEN
      -- Obtiene el siguiente codigo de persona valido en GF
      SELECT s_cod_persona.NEXTVAL INTO v_cod_persona FROM dual;

      IF v_cod_tip_documento = 6 THEN
        v_tipo := 'J';
      ELSE
        v_tipo := 'F';
      END IF;

      SELECT substr(reg.nombre1 ||
                   decode(reg.nombre2,   null, null, ' ' || reg.nombre2)   ||
                   decode(reg.nombre3,   null, null, ' ' || reg.nombre3)   ||
                   decode(reg.apellido1, null, null, ' ' || reg.apellido1) ||
                   decode(reg.apellido2, null, null, ' ' || reg.apellido2) ||
                   decode(reg.apellido_casa, null, null, ' ' || reg.apellido_casa), 1, 120)
       INTO v_nom_completo
       FROM dual;

      -- Insercion de BA_PERSONAS
      INSERT INTO ba_personas
       (cod_persona, nom_completo, tipo, cod_tip_documento,
        nro_documento, cod_pais,
        est_verificacion, obs_verificacion,
        fec_verificacion, fec_vto_documento)
      VALUES
       (v_cod_persona, v_nom_completo, v_tipo, v_cod_tip_documento,
        reg.nro_documento, 1, --Pais 1= Paraguay
        'V', 'DATOS DE INFOCHECK', SYSDATE, SYSDATE); --Se agrega fec_vto_documento porque controla en el trigger tb_ba_personas

      -- Inserción de BA_PER_FICICAS / BA_PER_JURIDICAS
      IF v_tipo = 'J' THEN -- Es persona Juridica
        INSERT INTO ba_per_juridicas
         (cod_persona, raz_social, nom_comercial)
        VALUES
         (v_cod_persona, reg.nombre1, substr(reg.nombre1, 1, 65));
      ELSE -- Es persona Fisica
        INSERT INTO ba_per_fisicas
         (cod_persona, pri_nombre, seg_nombre, pri_apellido, seg_apellido,
          est_civil, cod_sexo)
        VALUES
         (v_cod_persona,
           trim(substr(reg.nombre1, 1, 30)),
          trim(substr(reg.nombre2 || ' ' || reg.nombre3, 1, 30)),
          trim(substr(nvl(reg.apellido1, 'SIN APELLIDO'), 1, 30)),
          trim(substr(reg.apellido2 || ' ' || reg.apellido_casa, 1, 30)),
           decode(reg.apellido_casa, NULL, 'S', 'C'), 'M');
      END IF;
    ELSE -- No se crea la persona
      IF p_ind_val_nombre = 'S' THEN
        IF v_tipo = 'F' THEN  -- Persona Fisica
          -- Verifica el nombre exacto
          SELECT COUNT(*)
            INTO v_cantidad
            FROM ba_per_fisicas
           WHERE pri_nombre = reg.nombre1
             AND seg_nombre = reg.nombre2
             AND pri_apellido = reg.apellido1
             AND seg_apellido = reg.apellido2;
          IF v_cantidad > 0 THEN
            v_msj_error := 'Existe persona con el nombre completo exactamente igual con nro. documento distinto';
            raise_application_error(-20000, v_msj_error);
          END IF;
          -- Verifica nombres parecidos
          SELECT COUNT(*)
            INTO v_cantidad
            FROM ba_per_fisicas
           WHERE pri_nombre = reg.nombre1
             AND pri_apellido = reg.apellido1;
          IF v_cantidad > 0 THEN
            v_msj_error := 'Existe persona con el nombre parecido con nro. documento distinto';
            raise_application_error(-20000, v_msj_error);
          END IF;
        ELSE -- Persona Juridica
          DECLARE
            v_val_busqueda VARCHAR2(300);
            v_pos          NUMBER(10);
          BEGIN
            v_val_busqueda := ltrim(rtrim(reg.nombre1));
            v_pos          := instr(v_val_busqueda, ' ', -1);
            IF v_pos > 0 THEN
              v_val_busqueda := translate(substr(v_val_busqueda,1,v_pos), ' .', '%%');
            END IF;
            SELECT COUNT(*)
              INTO v_cantidad
              FROM ba_per_juridicas
             WHERE raz_social LIKE '%' || v_val_busqueda || '%';
            IF v_cantidad > 0 THEN
              v_msj_error := 'Existe persona con el nombre parecido con nro. documento distinto';
              raise_application_error(-20000, v_msj_error);
            END IF;
          END;
        END IF;
      END IF;
      v_msj_error := 'No se encontro la persona con este nro. de documento';
      raise_application_error(-20000, v_msj_error);
    END IF;
  END IF;

  -- Variable auxiliar para saber cuantos años debo sumar a la fecha de circular
  IF to_number(reg.inhab_por) = 10 THEN
    v_ano:= 10;
  ELSE
    v_ano:= 1;
  END IF;

  v_fec_vencimiento := to_date(substr(reg.fecha_circula, 1, 4) ||
                               to_char(to_number(substr(reg.fecha_circula,5,4)) + v_ano),'ddmmyyyy');
  v_detalle := ' Inhabilitado por ' || v_ano || ' años.' || chr(10) ||
               ' Circular: Año: ' || reg.ano_circular ||
               ' Nro: ' || reg.nro_circular || ' Sec.: ' || reg.nro_secuencia ||
               ' Moneda: ' || reg.moneda;

  -- Actualizo las inhibiciones, si existe
  UPDATE ge_per_inhibidas a
     SET cod_causa        = decode(to_number(reg.inhab_por), 10, 22, 21),
         fec_inicio       = to_date(reg.fecha_circula, 'ddmmyyyy'),
         fec_vencimiento  = v_fec_vencimiento,
         origen           = 'BANCO CENTRAL DEL PARAGUAY',
         cod_banco        = to_number(substr(reg.codigo_banco, 3)),
         nro_cta_inhibida = NULL,
         mto_multa        = to_number(reg.multa),
         referencia       = NULL,
         detalle          = detalle || chr(10) || v_detalle,
         usu_modificacion = USER,
         fec_modificacion = SYSDATE
   WHERE cod_persona = v_cod_persona
     AND nro_orden = to_number(reg.nro_secuencia);

  IF SQL%NOTFOUND THEN
    -- No esta en inhibidos
    INSERT INTO ge_per_inhibidas
      (cod_persona, nro_orden, cod_causa, fec_inicio, fec_vencimiento,
       origen, cod_banco, nro_cta_inhibida, mto_multa, referencia, detalle,
       usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, estado)
    VALUES
      (v_cod_persona, to_number(reg.nro_secuencia),
       decode(to_number(reg.inhab_por), 10, 22, 21),
       to_date(reg.fecha_circula, 'ddmmyyyy'), v_fec_vencimiento,
       'BANCO CENTRAL DEL PARAGUAY', substr(reg.codigo_banco, 3), NULL,
       to_number(reg.multa), NULL, v_detalle,
       USER, SYSDATE, USER, SYSDATE, 'I');
  END IF;

  -- Si no hubo error borra el registro de inhibiciones pendientes
  DELETE FROM tm_osc_inhi_pendientes WHERE ROWID = p_fila;

EXCEPTION
  WHEN OTHERS THEN
  	IF v_msj_error IS NULL THEN
      raise_application_error(-20000, SQLERRM);
  	END IF;

  	prg_rol_savepoint('inhi'); --- Desahace lo que ya hizo

    -- Actualiza el mensaje de error
    UPDATE tm_osc_inhi_pendientes
       SET msj_error = v_msj_error,
           cod_tip_documento = v_cod_tip_documento
     WHERE nro_secuencia = reg.nro_secuencia
       AND nro_circular = reg.nro_circular
       AND ano_circular = reg.ano_circular;
END;
/

