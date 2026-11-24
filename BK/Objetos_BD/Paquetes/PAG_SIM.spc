create or replace PACKAGE                         IT.PAG_SIM IS

  ----------------------------------------------------------------------------
  -- Constantes GLOBALES DEL PACKAGE
  ----------------------------------------------------------------------------
  c_log_INFO     CONSTANT VARCHAR2(10)  := 'INFO';
  c_log_WARN     CONSTANT VARCHAR2(10)  := 'WARN';
  c_log_ERROR    CONSTANT VARCHAR2(10)  := 'ERROR';
  c_log_OK       CONSTANT VARCHAR2(10)  := 'OK';
  c_log_EN_CURSO CONSTANT VARCHAR2(10)  := 'EN_CURSO';
  c_base_actual  CONSTANT VARCHAR2(100)  := sys_context('userenv', 'DB_UNIQUE_NAME');
  c_cod_usuario  CONSTANT VARCHAR2(30)  := SYS_CONTEXT('USERENV','SESSION_USER');
  c_cod_prg_ini  CONSTANT PLS_INTEGER := 10;
  c_cod_prg_cie  CONSTANT PLS_INTEGER := 11;
  
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
  );
  
  ----------------------------------------------------------------------------
  -- PROCEDIMIENTO PRINCIPAL
  ----------------------------------------------------------------------------
  PROCEDURE PR_EJE_SIM(p_reintentar_desde_paso IN VARCHAR2 DEFAULT NULL);

END PAG_SIM;
