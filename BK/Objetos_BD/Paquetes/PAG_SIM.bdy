create or replace PACKAGE BODY                                                    IT.PAG_SIM IS

  ----------------------------------------------------------------------------
  -- VARIABLES GLOBALES DEL PACKAGE
  ----------------------------------------------------------------------------
  vg_id_param          NUMBER;
  vg_id_ejecucion      NUMBER := S_EJEC_SIMULACION.NEXTVAL;
  vg_id_log            NUMBER;
  vg_fecha_programada  DATE;
  vg_fecha_negocio     DATE;
  vg_fecha_inicio      DATE;
  vg_base_esperada     VARCHAR2(100);
  vg_flag_activo       VARCHAR2(1);
  vg_paso              VARCHAR2(100);
  vg_error             VARCHAR2(4000);
  
  ----------------------------------------------------------------------------
  -- DECLARACION DE PROCEDIMIENTOS INTERNOS
  ----------------------------------------------------------------------------
  PROCEDURE PR_INI_MODULOS;
  PROCEDURE PR_ABRIR_MODULOS;
  PROCEDURE PR_CERRAR_MODULOS;
  PROCEDURE PR_REG_USUARIO;
  PROCEDURE PR_LIMPIAR_TMP;
  PROCEDURE PR_INS_FERIADOS(p_fecha_negocio DATE);
  PROCEDURE PR_INS_COTIZACIONES(p_fecha_negocio DATE);
  PROCEDURE PR_UPD_CALENDARIO;
  PROCEDURE PR_DESHABILITAR_PROC;
  PROCEDURE PR_DESHABILITAR_TRIGGERS;
  PROCEDURE PR_SET_PARAMS;
  PROCEDURE PR_CARGA_PARAMETROS;
  PROCEDURE PR_RECUPERA_PARAMETROS;
  PROCEDURE PR_VALIDA_ENTORNO;
  PROCEDURE PR_CONTROL_PROC(p_cod_proceso NUMBER, p_paso VARCHAR2);
  PROCEDURE PR_INS_LOG(p_paso in varchar2, p_estado in varchar2, p_mensaje_error in varchar2 default null);
  PROCEDURE PR_UPD_LOG(p_estado in varchar2, p_mensaje_error in varchar2 default null);
  
  ----------------------------------------------------------------------------
  -- FUNCION PARA VALIDAR AMBIENTE
  ----------------------------------------------------------------------------
  FUNCTION FN_BASE_ACTUAL_ES_PROD RETURN BOOLEAN IS
    v_lista_bases VARCHAR2(4000);
    v_base        VARCHAR2(100);
  BEGIN
    v_lista_bases := fug_obt_pardinamico('VAL_BDNAME_CONTROL_SIM');
    FOR i IN 1 .. REGEXP_COUNT(v_lista_bases, '[^,]+') LOOP
      v_base := TRIM(REGEXP_SUBSTR(v_lista_bases, '[^,]+', 1, i));
      IF UPPER(c_base_actual) = UPPER(v_base) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
    RETURN FALSE;
  END FN_BASE_ACTUAL_ES_PROD;

  ----------------------------------------------------------------------------
  -- PROCEDIMIENTO PRINCIPAL
  ----------------------------------------------------------------------------
  PROCEDURE PR_EJE_SIM(p_reintentar_desde_paso IN VARCHAR2 DEFAULT NULL) IS
  
  CURSOR c_pasos_simulacion IS
    SELECT ORDEN, CODIGO_INTERNO
      FROM IT.GE_CLA_PASOS_SIMULACION
     WHERE EJECUTAR = 'S'
     ORDER BY ORDEN;

  BEGIN
    ----------------------------------------------------------------------------
    -- Guard silencioso de entorno previo a cualquier log
    -- (NOR-655 / SRER-5770): si la base esta en la lista de produccion
    -- controlada, se retorna sin generar registros en GE_CLA_LOG_SIMULACION.
    ----------------------------------------------------------------------------
    IF FN_BASE_ACTUAL_ES_PROD THEN
      RETURN;
    END IF;

    ----------------------------------------------------------------------------
    -- LECTURA_PARAMETROS_EJECUCION
    ----------------------------------------------------------------------------
    IF p_reintentar_desde_paso IN ('3', '4') THEN
      PR_RECUPERA_PARAMETROS;
    ELSE
      PR_CARGA_PARAMETROS;
    END IF;
    
    IF vg_id_param IS NULL THEN
        RETURN; 
    END IF;
    
    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''. ,''';
   
    ----------------------------------------------------------------------------
    -- INICIAR EJECUCION
    ----------------------------------------------------------------------------
    UPDATE IT.GE_CLA_FEC_SIMULACION
       SET FECHA_INICIO = SYSDATE
     WHERE ID_PARAM = vg_id_param;
    ----------------------------------------------------------------------------
    -- EJECUCION DE PASOS CONFIGURADOS
    ----------------------------------------------------------------------------
    FOR r_paso IN c_pasos_simulacion LOOP
      vg_paso := TO_CHAR(r_paso.ORDEN) || '. ' || r_paso.CODIGO_INTERNO;

      BEGIN
        CASE r_paso.CODIGO_INTERNO
          WHEN 'VALIDACION_ENTORNO_EJECUCION'  THEN
              IF p_reintentar_desde_paso IS NULL THEN
                PR_INS_LOG(vg_paso, c_log_EN_CURSO);
                PR_VALIDA_ENTORNO;
              END IF;
            

          WHEN 'GENERACION_CONTEXTO_EJECUCION'  THEN
            IF p_reintentar_desde_paso IS NULL THEN
                PR_INS_LOG(vg_paso, c_log_EN_CURSO);
                PR_INI_MODULOS;
                PR_ABRIR_MODULOS;
                PR_REG_USUARIO;
                PR_LIMPIAR_TMP;
                PR_INS_FERIADOS(vg_fecha_negocio);
                PR_INS_COTIZACIONES(vg_fecha_negocio);
                PR_UPD_CALENDARIO;
				PR_DESHABILITAR_TRIGGERS;
                PR_DESHABILITAR_PROC;
				PR_SET_PARAMS;
                PR_CERRAR_MODULOS;
            END IF;

          WHEN 'EJECUCION_PROCESO_INICIO'  THEN
            IF p_reintentar_desde_paso IS NULL OR p_reintentar_desde_paso = 3 THEN
                PR_INS_LOG(vg_paso, c_log_EN_CURSO);
                PRG_EJE_PROCESOS(P_FECHA => PAG_CAL.FU_OBT_FEC_ACTUAL(1), P_TIP_PROCESO => 'I', P_COD_PROCESO => c_cod_prg_ini);
                PR_CONTROL_PROC(c_cod_prg_ini, vg_paso);
            END IF;

          WHEN 'EJECUCION_PROCESO_CIERRE'  THEN
            IF p_reintentar_desde_paso IS NULL OR p_reintentar_desde_paso IN (3,4) THEN
                PR_INS_LOG(vg_paso, c_log_EN_CURSO);
                PRG_EJE_PROCESOS(P_FECHA => PAG_CAL.FU_OBT_FEC_ACTUAL(1), P_TIP_PROCESO => 'F', P_COD_PROCESO => c_cod_prg_cie);
                PR_CONTROL_PROC(c_cod_prg_cie, vg_paso);
            END IF;

          WHEN 'GENERACION_REPORTE' THEN
            PR_INS_LOG(vg_paso, c_log_EN_CURSO);
            EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.GE_CLA_TMP_SIMULACION';
            INSERT INTO IT.GE_CLA_TMP_SIMULACION SELECT * FROM IT.GV_CLA_SIMULACION;

          ELSE
            PR_UPD_LOG(c_log_WARN, 'Paso no reconocido: ' || r_paso.CODIGO_INTERNO);
        END CASE;

        PR_UPD_LOG(c_log_OK);

      EXCEPTION
        WHEN OTHERS THEN
          vg_error := SQLERRM;
          PR_UPD_LOG(c_log_ERROR, vg_error);
          RETURN;
      END;
    END LOOP;
    ----------------------------------------------------------------------------
    -- FINALIZAR EJECUCION
    ----------------------------------------------------------------------------
    UPDATE IT.GE_CLA_FEC_SIMULACION
       SET FECHA_FIN = SYSDATE
     WHERE ID_PARAM = vg_id_param;

  END PR_EJE_SIM;

----------------------------------------------------------------------------
  -- PR_INI_MODULOS: Inicializa la aplicacion y establece el codigo de modulo.
  ----------------------------------------------------------------------------
  PROCEDURE PR_INI_MODULOS IS
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END PR_INI_MODULOS;

  ----------------------------------------------------------------------------
  -- PR_ABRIR_MODULOS: Cambia el estado del modulo a abierto.
  ----------------------------------------------------------------------------
  PROCEDURE PR_ABRIR_MODULOS IS
  BEGIN
    UPDATE BA_MODULOS SET ESTADO = 2;
    COMMIT;
  END PR_ABRIR_MODULOS;

  ----------------------------------------------------------------------------
  -- PR_CERRAR_MODULOS: Cambia el estado del modulo a cerrado.
  ----------------------------------------------------------------------------
  PROCEDURE PR_CERRAR_MODULOS IS
  BEGIN
    UPDATE BA_MODULOS SET ESTADO = 4;
    COMMIT;
  END PR_CERRAR_MODULOS;

  ----------------------------------------------------------------------------
  -- PR_REG_USUARIO: Registra el usuario actual y asigna roles.
  ----------------------------------------------------------------------------
  PROCEDURE PR_REG_USUARIO IS
  BEGIN
    BEGIN
      INSERT INTO BA_USUARIOS (cod_usuario, nombre, cod_oficina, cod_area, fec_ingreso, estado)
      SELECT c_cod_usuario, c_cod_usuario, 61, 54, SYSDATE, 'A'
        FROM DUAL
       WHERE NOT EXISTS (SELECT 1 FROM BA_USUARIOS WHERE cod_usuario = c_cod_usuario);
      COMMIT;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;

    DELETE FROM BA_USU_ROLES WHERE cod_usuario = c_cod_usuario;
    COMMIT;

    FOR r IN (SELECT cod_rol FROM BA_ROLES) LOOP
      INSERT INTO BA_USU_ROLES (cod_rol, cod_usuario) VALUES (r.cod_rol, c_cod_usuario);
    END LOOP;
    COMMIT;
  END PR_REG_USUARIO;

  ----------------------------------------------------------------------------
  -- PR_INS_FERIADOS: Inserta feriados habiles hasta la fecha de negocio.
  ----------------------------------------------------------------------------
  PROCEDURE PR_INS_FERIADOS(p_fecha_negocio DATE) IS
    v_fec_actual  DATE;
    v_fec_limite  DATE;
  BEGIN
    SELECT FEC_ACTUAL INTO v_fec_actual FROM GE_CALENDARIOS WHERE COD_MODULO = 1;
    v_fec_limite := p_fecha_negocio - 1;

    FOR r IN (
      SELECT dia
        FROM (
          SELECT v_fec_actual + LEVEL - 1 AS dia
            FROM DUAL
          CONNECT BY v_fec_actual + LEVEL - 1 <= v_fec_limite
        )
        WHERE TO_CHAR(dia, 'DY', 'NLS_DATE_LANGUAGE = ''ENGLISH''') NOT IN ('SAT','SUN')
        AND NOT EXISTS (SELECT 1 FROM BA_FERIADOS f WHERE f.FECHA = dia)
    ) LOOP
      INSERT INTO BA_FERIADOS (
        FECHA, COD_OFICINA, MOTIVO,
        USU_INSERCION, FEC_INSERCION,
        USU_MODIFICACION, FEC_MODIFICACION
      ) VALUES (
        r.dia, NULL, 'AUTO PARA SIMULACION',
        c_cod_usuario, SYSDATE,
        c_cod_usuario, SYSDATE
      );
    END LOOP;
    COMMIT;
  END PR_INS_FERIADOS;

  ----------------------------------------------------------------------------
  -- PR_INS_COTIZACIONES: Duplica cotizaciones hasta la fecha de negocio.
  ----------------------------------------------------------------------------
  PROCEDURE PR_INS_COTIZACIONES(p_fecha_negocio DATE) IS
  BEGIN
    INSERT INTO GE_COTIZACIONES (
      COD_MONEDA, FECHA, VAL_CONVERSION,
      VAL_COMPRA, VAL_VENTA, VAL_VEN_CHEQUE,
      VAL_COM_CHEQUE, VAL_COM_ELECTRONICA, VAL_VEN_ELECTRONICA,
      USU_INSERCION, FEC_INSERCION,
      USU_MODIFICACION, FEC_MODIFICACION,
      VAL_COM_INTERBANCARIA, VAL_VEN_INTERBANCARIA,
      VAL_COM_AUTORIZADOR, VAL_VEN_AUTORIZADOR
    )
    SELECT s.COD_MONEDA,
           p_fecha_negocio,
           s.VAL_CONVERSION, s.VAL_COMPRA, s.VAL_VENTA,
           s.VAL_VEN_CHEQUE, s.VAL_COM_CHEQUE,
           s.VAL_COM_ELECTRONICA, s.VAL_VEN_ELECTRONICA,
           c_cod_usuario, SYSDATE,
           c_cod_usuario, SYSDATE,
           s.VAL_COM_INTERBANCARIA, s.VAL_VEN_INTERBANCARIA,
           s.VAL_COM_AUTORIZADOR, s.VAL_VEN_AUTORIZADOR
      FROM GE_COTIZACIONES s
     WHERE s.FECHA = (
           SELECT MAX(fecha)
             FROM GE_COTIZACIONES
            WHERE TO_CHAR(fecha,'MM/YYYY') = TO_CHAR(pag_cal.FU_OBT_FEC_ACTUAL('1'),'MM/YYYY'))
       AND NOT EXISTS (
           SELECT 1 FROM GE_COTIZACIONES t
            WHERE t.FECHA = p_fecha_negocio AND t.COD_MONEDA = s.COD_MONEDA
       );
    COMMIT;
  END PR_INS_COTIZACIONES;

  ----------------------------------------------------------------------------
  -- PR_UPD_CALENDARIO: Fuerza actualizacion de calendario (reciclado).
  ----------------------------------------------------------------------------
  PROCEDURE PR_UPD_CALENDARIO IS
  BEGIN
    UPDATE GE_CALENDARIOS SET FEC_ACTUAL = FEC_ACTUAL;
    COMMIT;
  END PR_UPD_CALENDARIO;

  ----------------------------------------------------------------------------
  -- PR_DESHABILITAR_PROC: Desactiva procesos de inicio y cierre de dia.
  ----------------------------------------------------------------------------
  PROCEDURE PR_DESHABILITAR_PROC IS
  BEGIN
    -- Desactivar NRO_ORDEN configurados para proceso 10 (inicio)
    UPDATE GE_PROCESOS_DET
       SET ACTIVO = 'N'
     WHERE COD_PROCESO = c_cod_prg_ini
       AND NRO_ORDEN IN (
             SELECT TO_NUMBER(REGEXP_SUBSTR(fug_obt_pardinamico('VAL_PRG_DES_SIM_INI'), '[^,]+', 1, LEVEL))
               FROM DUAL
            CONNECT BY REGEXP_SUBSTR(fug_obt_pardinamico('VAL_PRG_DES_SIM_INI'), '[^,]+', 1, LEVEL) IS NOT NULL
           );
  
    -- Desactivar NRO_ORDEN configurados para proceso 11 (cierre)
    UPDATE GE_PROCESOS_DET
       SET ACTIVO = 'N'
     WHERE COD_PROCESO = c_cod_prg_cie
       AND NRO_ORDEN IN (
             SELECT TO_NUMBER(REGEXP_SUBSTR(fug_obt_pardinamico('VAL_PRG_DES_SIM_CIE'), '[^,]+', 1, LEVEL))
               FROM DUAL
            CONNECT BY REGEXP_SUBSTR(fug_obt_pardinamico('VAL_PRG_DES_SIM_CIE'), '[^,]+', 1, LEVEL) IS NOT NULL
           );
  
    -- Limpiar horarios en DET y CABECERA, eliminar DEPENDENCIAS
    FOR cod_proc IN 10 .. 11 LOOP
      UPDATE GE_PROCESOS_DET
         SET HOR_INICIO = NULL, HOR_FIN = NULL
       WHERE COD_PROCESO = cod_proc AND ACTIVO = 'S';
  
      UPDATE GE_PROCESOS
         SET HOR_INICIO = NULL, HOR_FIN = NULL
       WHERE COD_PROCESO = cod_proc;
  
      DELETE FROM GE_PROCESOS_DEP
       WHERE COD_PROCESO = cod_proc;
    END LOOP;
  
    COMMIT;
  END PR_DESHABILITAR_PROC;

  ----------------------------------------------------------------------------
  -- PR_LIMPIAR_TMP: Trunca la tabla ge_cla_operaciones_tmp
  ----------------------------------------------------------------------------
  PROCEDURE PR_LIMPIAR_TMP IS
  BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.GE_CLA_OPERACIONES_TMP';
  END PR_LIMPIAR_TMP;

  -----------------------------------------------------------------------------
  -- PR_VALIDA_ENTORNO: Realiza validaciones del entorno de ejecucion.
  -----------------------------------------------------------------------------
  PROCEDURE PR_VALIDA_ENTORNO IS
    v_count      NUMBER;
  BEGIN
    IF FN_BASE_ACTUAL_ES_PROD THEN
      vg_error := 'Ejecucion prohibida en base productiva: ' || c_base_actual;
      PR_UPD_LOG(c_log_ERROR, vg_error);
      RAISE_APPLICATION_ERROR(-20001, vg_error);
    END IF;
  
    SELECT COUNT(*)
      INTO v_count
      FROM IT.GE_CLA_LOG_SIMULACION
     WHERE ESTADO       = c_log_EN_CURSO
       AND ID_EJECUCION != vg_id_ejecucion;
  
    IF v_count > 0 THEN
      RAISE_APPLICATION_ERROR(-20004, 'Ejecucion en curso detectada');
    END IF;
  
    IF c_base_actual != vg_base_esperada THEN
      RAISE_APPLICATION_ERROR(-20001, 'Base activa incorrecta');
    END IF;
  
    IF vg_flag_activo is not null and vg_flag_activo != 'S' THEN
      RAISE_APPLICATION_ERROR(-20002, 'Flag de ejecucion inactivo');
    END IF;
  
  END PR_VALIDA_ENTORNO;

  -----------------------------------------------------------------------------
  -- PR_CONTROL_PROC: Evalua si un proceso finalizo y detecta errores.
  -----------------------------------------------------------------------------
    PROCEDURE PR_CONTROL_PROC (
        p_cod_proceso IN NUMBER,
        p_paso        IN VARCHAR2
    ) IS
        v_finalizado            NUMBER := 0;
        v_programa              VARCHAR2(100);
        v_errores_obligatorios  VARCHAR2(4000) := NULL;
        v_tuvo_warn             BOOLEAN := FALSE;
    BEGIN
        -- Verifica si el proceso finalizo
        SELECT COUNT(*)
          INTO v_finalizado
          FROM GE_PROCESOS
         WHERE COD_PROCESO = p_cod_proceso
           AND HOR_FIN IS NOT NULL;
    
        -- Revisa errores por programa asociados al proceso
        FOR r IN (
            SELECT COD_PROGRAMA, ERROR, OBLIGATORIO
              FROM GE_PROCESOS_DET
             WHERE COD_PROCESO = p_cod_proceso
               AND ACTIVO = 'S'
               AND FRECUENCIA IN ('D','M')
               AND HOR_INICIO IS NOT NULL
               AND ERROR IS NOT NULL
        ) LOOP
            v_programa := r.COD_PROGRAMA;
            vg_error := v_programa || ': ' || r.ERROR;
    
            IF r.OBLIGATORIO = 'S' THEN
                v_errores_obligatorios := v_errores_obligatorios || vg_error || ' | ';
                PR_UPD_LOG(c_log_ERROR, vg_error);  -- Se registra cada error obligatorio
            ELSE
                v_tuvo_warn := TRUE;
                PR_UPD_LOG(c_log_WARN, vg_error);   -- Se registra cada advertencia
            END IF;
        END LOOP;
    
        IF v_finalizado = 0 THEN
            PR_INS_LOG(p_paso, c_log_ERROR, 'El proceso aun no ha finalizado');
            RAISE_APPLICATION_ERROR(-20011, 'Proceso ' || p_cod_proceso || ' no ha finalizado aun');
        END IF;

    
        -- Si hubo errores obligatorios acumulados
        IF NVL(LENGTH(v_errores_obligatorios), 0) > 0 THEN
            PR_UPD_LOG(c_log_ERROR, 'Finalizo con errores obligatorios: ' || v_errores_obligatorios);
            RAISE_APPLICATION_ERROR(-20010, 'Proceso ' || p_cod_proceso || ' finalizo con errores obligatorios: ' || v_errores_obligatorios);
        END IF;
    
        -- Si finalizo con advertencias no obligatorias
        IF v_tuvo_warn THEN
            PR_UPD_LOG(c_log_WARN, 'Proceso ' || p_cod_proceso || ' finalizo con advertencias no obligatorias');
        ELSE
            PR_UPD_LOG(c_log_OK, 'Proceso ' || p_cod_proceso || ' finalizo correctamente sin errores');
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            PR_UPD_LOG(c_log_ERROR, 'Excepcion en PR_CONTROL_PROC (' || p_cod_proceso || '): ' || SQLERRM);
            RAISE;
    END PR_CONTROL_PROC;

  ----------------------------------------------------------------------------
  -- PR_CARGA_PARAMETROS: Carga los parametros de ejecucion.
  ----------------------------------------------------------------------------
  PROCEDURE PR_CARGA_PARAMETROS IS
  BEGIN
    SELECT ID_PARAM,
           FECHA_PROGRAMADA,
           FECHA_NEGOCIO,
           FLAG_ACTIVO,
           BASE_OBJETIVO
      INTO vg_id_param,
           vg_fecha_programada,
           vg_fecha_negocio,
           vg_flag_activo,
           vg_base_esperada
      FROM (
            SELECT ID_PARAM,
                   FECHA_PROGRAMADA,
                   FECHA_NEGOCIO,
                   FLAG_ACTIVO,
                   BASE_OBJETIVO
              FROM IT.GE_CLA_FEC_SIMULACION
             WHERE FECHA_INICIO    IS NULL
               AND FECHA_FIN       IS NULL
               AND SYSDATE         >= FECHA_PROGRAMADA
               AND FECHA_PROGRAMADA >= TRUNC(SYSDATE)
             ORDER BY FECHA_PROGRAMADA, ID_PARAM
           )
     WHERE ROWNUM = 1;

    PR_INS_LOG('0. LECTURA_PARAMETROS_EJECUCION', c_log_OK);
    PR_UPD_LOG(c_log_OK);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN;
    WHEN OTHERS THEN
      vg_error := SQLERRM;
      PR_INS_LOG('0. LECTURA_PARAMETROS_EJECUCION', c_log_ERROR, vg_error);
      RETURN;
  END PR_CARGA_PARAMETROS;
    
  ----------------------------------------------------------------------------
  -- PR_RECUPERA_PARAMETROS: Recupera los parametros de la ultima ejecucion.
  ----------------------------------------------------------------------------
  PROCEDURE PR_RECUPERA_PARAMETROS IS
  BEGIN
    PR_INI_MODULOS;
    SELECT ID_PARAM,
           FECHA_PROGRAMADA,
           FECHA_NEGOCIO,
           BASE_OBJETIVO,
           FLAG_ACTIVO
      INTO vg_id_param,
           vg_fecha_programada,
           vg_fecha_negocio,
           vg_base_esperada,
           vg_flag_activo
      FROM (
            SELECT ID_PARAM,
                   FECHA_PROGRAMADA,
                   FECHA_NEGOCIO,
                   BASE_OBJETIVO,
                   FLAG_ACTIVO
              FROM IT.GE_CLA_FEC_SIMULACION
             WHERE FECHA_INICIO IS NOT NULL
               AND FECHA_FIN IS NULL
               AND FLAG_ACTIVO = 'S'
             ORDER BY FECHA_PROGRAMADA DESC, ID_PARAM DESC
           )
     WHERE ROWNUM = 1;

    SELECT MAX(ID_EJECUCION)
      INTO vg_id_ejecucion
      FROM IT.GE_CLA_LOG_SIMULACION
     WHERE ID_PARAM = vg_id_param;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      vg_error := 'No se encontro contexto anterior para reintento';
      PR_INS_LOG('REINTENTO', c_log_ERROR, vg_error);
      RETURN;
    WHEN OTHERS THEN
      vg_error := SQLERRM;
      PR_INS_LOG('REINTENTO', c_log_ERROR, vg_error);
      RETURN;
  END PR_RECUPERA_PARAMETROS;
    
  ----------------------------------------------------------------------------
  -- PR_INS_PARAM: Inserta un nuevo parametro de simulacion.
  ----------------------------------------------------------------------------
   PROCEDURE PR_INS_PARAM (
    p_fecha_programada IN DATE,
    p_fecha_negocio    IN DATE,
    p_base_objetivo    IN VARCHAR2,
    p_flag_activo      IN VARCHAR2,
    p_observaciones    IN VARCHAR2,
    o_id_param         OUT NUMBER
  ) IS
    v_lista_bases VARCHAR2(4000);
    v_base        VARCHAR2(100);
  BEGIN
    -- 0) Controlar que no se permita insertar en base productiva
    v_lista_bases := fug_obt_pardinamico('VAL_BDNAME_CONTROL_SIM');
    FOR i IN 1 .. REGEXP_COUNT(v_lista_bases, '[^,]+') LOOP
      v_base := TRIM(REGEXP_SUBSTR(v_lista_bases, '[^,]+', 1, i));
      IF UPPER(p_base_objetivo) = UPPER(v_base) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insercion prohibida en base productiva: ' || c_base_actual);
        EXIT;
      END IF;
    END LOOP;
  
    -- 1) Validar fechas
    IF p_fecha_programada IS NULL THEN
      RAISE_APPLICATION_ERROR(-20010, 'La fecha programada no puede ser nula');
    ELSIF p_fecha_negocio IS NULL THEN
      RAISE_APPLICATION_ERROR(-20011, 'La fecha de negocio no puede ser nula');
    END IF;
  
    -- 2) Normalizar y validar flag activo
    IF UPPER(NVL(p_flag_activo, 'N')) NOT IN ('S','N') THEN
      RAISE_APPLICATION_ERROR(-20013, 'El flag activo debe ser S o N');
    END IF;
  
    -- 3) Validar base objetivo
    IF TRIM(p_base_objetivo) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20014, 'La base objetivo no puede ser nula o vacia');
    END IF;
  
    -- 4) Generar ID_PARAM
    SELECT IT.S_FEC_SIMULACION.NEXTVAL
      INTO o_id_param
      FROM DUAL;
  
    -- 5) Insertar registro
    INSERT INTO IT.GE_CLA_FEC_SIMULACION (
      ID_PARAM,
      FECHA_PROGRAMADA,
      FECHA_NEGOCIO,
      BASE_OBJETIVO,
      FLAG_ACTIVO,
      OBSERVACIONES,
      FECHA_CREACION,
      USUARIO_CREACION
    ) VALUES (
      o_id_param,
      p_fecha_programada,
      p_fecha_negocio,
      p_base_objetivo,
      p_flag_activo,
      p_observaciones, 
      SYSDATE,
      USER
    );
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20099, 'Error al insertar parametro: ' || SQLERRM);
  END PR_INS_PARAM;
  
  ----------------------------------------------------------------------------
  -- PR_SET_PARAMS: Controla y actualiza/inserta el parametro CAN_BUS_POR_HORA
  ----------------------------------------------------------------------------
  PROCEDURE PR_SET_PARAMS IS
    v_existe_parametro   NUMBER := 0;
    v_existe_dinamico    NUMBER := 0;
  BEGIN
    ----------------------------------------------------------------------------
    -- Paso 1: Verificar existencia en GE_PARAMETROS
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
      INTO v_existe_parametro
      FROM GE_PARAMETROS
     WHERE PARAMETRO = 'CAN_BUS_POR_HORA';

    IF v_existe_parametro = 0 THEN
      INSERT INTO GE_PARAMETROS (
        PARAMETRO, DESCRIPCION, TAB_RELACION,
        USU_INSERCION, FEC_INSERCION,
        OBSERVACION
      ) VALUES (
        'CAN_BUS_POR_HORA',
        'CICLOS DE BUSQUEDA HORA DISPONIBLE',
        'GE_PAR_DINAMICOS',
        USER, SYSDATE,
        'cantidad de ciclos en que se busca hora disponible en FUG_OBT_HOR_DISPONIBLE'
      );
    END IF;

    ----------------------------------------------------------------------------
    -- Paso 2: Insertar o actualizar en GE_PAR_DINAMICOS
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
      INTO v_existe_dinamico
      FROM GE_PAR_DINAMICOS
     WHERE PARAMETRO = 'CAN_BUS_POR_HORA';

    IF v_existe_dinamico = 0 THEN
      INSERT INTO GE_PAR_DINAMICOS (
        PARAMETRO, VAL_PARAMETRO,
        USU_INSERCION, FEC_INSERCION,
        USU_MODIFICACION, FEC_MODIFICACION
      ) VALUES (
        'CAN_BUS_POR_HORA', '170000',
        USER, SYSDATE,
        USER, SYSDATE
      );
    ELSE
      UPDATE GE_PAR_DINAMICOS
         SET VAL_PARAMETRO     = '170000',
             USU_MODIFICACION = USER,
             FEC_MODIFICACION = SYSDATE
       WHERE PARAMETRO = 'CAN_BUS_POR_HORA';
    END IF;

    COMMIT;
  END PR_SET_PARAMS;
  ----------------------------------------------------------------------------
  -- PR_DESHABILITAR_TRIGGERS: Desactiva los triggers configurados en parametro dinamico.
  ----------------------------------------------------------------------------
  PROCEDURE PR_DESHABILITAR_TRIGGERS IS
    v_trigger_name   VARCHAR2(100);
    v_exists         NUMBER;
  BEGIN
    FOR reg IN (
      SELECT REGEXP_SUBSTR(fug_obt_pardinamico('TRIGGERS_SIM_DESHABILITAR'), '[^,]+', 1, LEVEL) AS trigger_name
        FROM DUAL
      CONNECT BY REGEXP_SUBSTR(fug_obt_pardinamico('TRIGGERS_SIM_DESHABILITAR'), '[^,]+', 1, LEVEL) IS NOT NULL
    ) LOOP
      SELECT COUNT(*) INTO v_exists
        FROM ALL_TRIGGERS
       WHERE TRIGGER_NAME = UPPER(TRIM(reg.trigger_name))
         AND OWNER = 'IT';
  
      IF v_exists > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TRIGGER IT.' || TRIM(reg.trigger_name) || ' DISABLE';
      END IF;
    END LOOP;
  END;
  -----------------------------------------------------------------------------
  -- PR_INS_LOG: insercion de logs
  -----------------------------------------------------------------------------
  PROCEDURE PR_INS_LOG(
    p_paso          in varchar2,
    p_estado        in varchar2,
    p_mensaje_error in varchar2 default null
  ) is
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    vg_id_log := IT.S_LOG_SIMULACION.NEXTVAL;
    INSERT INTO IT.GE_CLA_LOG_SIMULACION (
      id_log, id_ejecucion, id_param, paso, fecha_inicio, estado,
      usuario_ejecucion, origen_ejecucion, mensaje_error
    ) VALUES (
      vg_id_log, vg_id_ejecucion, vg_id_param, p_paso, sysdate, p_estado,
      user, 'AUTOMATICA', p_mensaje_error
    );
    COMMIT;
  END PR_INS_LOG;

  -----------------------------------------------------------------------------
  -- PR_UPD_LOG: actualizacion de logs
  -----------------------------------------------------------------------------
  PROCEDURE PR_UPD_LOG(
    p_estado        in varchar2,
    p_mensaje_error in varchar2 default null
  ) is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    UPDATE IT.GE_CLA_LOG_SIMULACION
       SET ESTADO        = p_estado,
           FECHA_FIN     = SYSDATE,
           MENSAJE_ERROR = p_mensaje_error
     WHERE ID_LOG = vg_id_log;
    commit;
  END PR_UPD_LOG;

END PAG_SIM;
