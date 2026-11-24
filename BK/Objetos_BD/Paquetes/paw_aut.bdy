CREATE OR REPLACE PACKAGE BODY IT.paw_aut IS

  BITACORA_ERROR            CONSTANT VARCHAR2(3) := 'ERR';
  BITACORA_ENTRADA          CONSTANT VARCHAR2(3) := 'ENT';
  BITACORA_SALIDA           CONSTANT VARCHAR2(3) := 'SAL';
  MSG_OK                    CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  MSG_ERROR                 CONSTANT VARCHAR2(30) := 'OP_ERROR';
  v_tip_mensaje             VARCHAR2(10);
  v_can_aut_requeridas      NUMBER(5) := 0;
  g_aut_operacion           BOOLEAN := FALSE;

  TYPE typ_obtenerPermisos IS RECORD(
    error                    VARCHAR(1),
    nombreRespuesta          VARCHAR2(15),
    descripcionRespuesta     VARCHAR2(200),
    autoriza                 BOOLEAN,
    registra                 BOOLEAN,
    consulta                 BOOLEAN,
    autorizacionesRequeridas NUMBER,
    canAutRequeridas         NUMBER);
    
  FUNCTION fu_generarUbicacion RETURN VARCHAR2 IS 
      v_linea    VARCHAR2(1000); 
      v_paquete  VARCHAR2(1000); 
      v_llamador VARCHAR2(1000); 
      v_duenho   VARCHAR2(1000); 
   BEGIN 
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador); 
      RETURN v_paquete || '.' || v_linea ; 
   END;  

  FUNCTION depurarAlfanumerico(p_string  IN VARCHAR2,
                               maxLength IN NUMBER,
                               p_espacio IN CHAR DEFAULT 'N') RETURN VARCHAR2 IS
  BEGIN
    IF p_espacio = 'N' THEN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:]])', ''), 1, maxLength);
    ELSE
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:][:space:]])', ''), 1, maxLength);
    END IF;
  END;

  PROCEDURE pr_mensajeUsuario(mensaje            IN VARCHAR2,
                              nombreMensaje      OUT VARCHAR2,
                              descripcionMensaje OUT VARCHAR2,
                              error              OUT VARCHAR2) IS
    v_error VARCHAR2(1);
  BEGIN
    BEGIN
      SELECT a.nombre, a.des_mensaje, a.error
        INTO nombreMensaje, descripcionMensaje, v_error
        FROM bw_men_respuestas a
       WHERE a.nombre = mensaje;
    EXCEPTION
      WHEN no_data_found THEN
        descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado - [' || mensaje || ']';
      WHEN OTHERS THEN
        descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado - [' || mensaje || ']';
    END;
    error := v_error;
  END;

  FUNCTION fu_generarBitacora(error                in varchar2,
                              nombreRespuesta      in varchar2,
                              descripcionRespuesta in varchar2)
    RETURN VARCHAR2 IS
    v_linea    VARCHAR2(1000);
    v_paquete  VARCHAR2(1000);
    v_llamador VARCHAR2(1000);
    v_duenho   VARCHAR2(1000);
  BEGIN
    OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
    RETURN v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV',
           'SESSION_USER') || ' Ip:' || sys_context('USERENV', 'IP_ADDRESS') || ' Error:' || error || ' nombreRespuesta:' || 
           nombreRespuesta || ' descripcionRespuesta:' || descripcionRespuesta;
  END;

  PROCEDURE pr_insertarBitacora(p_codigoPersona IN VARCHAR2 DEFAULT NULL,
                                p_codigoCanal   IN VARCHAR2 DEFAULT NULL,
                                p_codSesion     IN VARCHAR2 DEFAULT NULL,
                                p_tipoMensaje   IN VARCHAR2 DEFAULT NULL,
                                p_codigoEmpresa IN VARCHAR2 DEFAULT NULL,
                                p_datos         IN VARCHAR2 DEFAULT NULL,
                                p_tipo          IN VARCHAR2 DEFAULT NULL,
                                p_dato2         IN CLOB DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO bw_bitacoras
      (COD_PERSONA,
       COD_CANAL,
       COD_SESION,
       COD_TIP_MENSAJE,
       COD_PER_VINCULADA,
       DATO,
       TIPO,
       DATO2)
    VALUES
      (p_codigoPersona,
       p_codigoCanal,
       p_codSesion,
       p_tipoMensaje,
       p_codigoEmpresa,
       SUBSTR(p_datos, 1, 4000),
       p_tipo,
       p_dato2);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  FUNCTION lf_obt_permisos(p_sesion        IN typ_validarSesion,
                           p_cod_operacion IN VARCHAR2)
    RETURN typ_obtenerPermisos IS
    v_retorno      typ_obtenerPermisos;
    v_consulta     VARCHAR(5);
    v_registra     VARCHAR(5);
    v_autoriza     VARCHAR(5);
    p_cod_persona  ba_personas.cod_persona%TYPE := nvl(p_sesion.codigoEmpresa, p_sesion.codigoPersona);
    p_cod_perfil   bw_perfiles.cod_perfil%TYPE := p_sesion.codigoPerfil;
    p_nro_terminal cj_cajas.nro_caja%TYPE := p_sesion.codigoCanal;
    MSG_OP_NO_PERMITIDA CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';
    MSG_OP_INEXISTENTE  CONSTANT VARCHAR2(15) := 'PER_OPE_INVALID';
  BEGIN
    SELECT TRIM(decode(consulta, 'S', 'C', '') || decode(ingresa, 'S', 'I', '') || decode(autoriza, 'S', 'A', ''))
      INTO v_tip_mensaje
      FROM bw_tip_mensajes
     WHERE cod_tip_mensaje = p_cod_operacion;
    BEGIN
      pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    
      -- busco primero especifico para la empresa
      SELECT decode(consulta, 'S', 'TRUE', 'FALSE'), decode(ingresa, 'S', 'TRUE', 'FALSE'),
             decode(autoriza, 'S', 'TRUE', 'FALSE'), nvl(can_firmas, 0)
        INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
        FROM bw_rol_permisos
       WHERE cod_perfil = p_cod_perfil
         AND cod_tip_mensaje = p_cod_operacion
         AND cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        -- busco los permisos generales para el perfil
        SELECT decode(consulta, 'S', 'TRUE', 'FALSE'), decode(ingresa, 'S', 'TRUE', 'FALSE'),
               decode(autoriza, 'S', 'TRUE', 'FALSE'), nvl(can_firmas, 0)
          INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
          FROM bw_rol_permisos
         WHERE cod_perfil = p_cod_perfil
           AND cod_tip_mensaje = p_cod_operacion
           AND cod_persona IS NULL;
    END;
    --operacion no permitida en autoservicios por requerir autorizacion
    IF v_can_aut_requeridas > 0 AND paw_bce.fu_caj_homebanking(p_nro_terminal) = 'N' THEN
      pr_mensajeUsuario(MSG_OP_NO_PERMITIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    END IF;
    v_retorno.autoriza         := (v_autoriza = 'TRUE');
    v_retorno.consulta         := (v_consulta = 'TRUE');
    v_retorno.registra         := (v_registra = 'TRUE');
    v_retorno.canAutRequeridas := v_can_aut_requeridas;
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_OP_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      RETURN v_retorno;
  END;

  FUNCTION fu_validarSesion(p_sesionUsuario IN VARCHAR2,
                            p_codCanal      IN VARCHAR2)
    RETURN typ_validarSesion IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    FECHA_HORA_ACTUAL             CONSTANT DATE := SYSDATE;
    MAX_TIEMPO_INACTIVIDAD_SESION CONSTANT NUMBER(3) := to_number(nvl(fug_obt_pardinamico('NUE_SESION_HB'), 30));
    COD_OPERACION                 CONSTANT VARCHAR2(5) := '005';
    MSG_AUTH_ERROR                CONSTANT VARCHAR2(15) := 'L_AUTH_ERROR';
    MSG_TK_EXPIRADO               CONSTANT VARCHAR2(15) := 'L_SESSION_EXP';
    v_ultimoAcceso                DATE;
    v_sesion                      VARCHAR2(32);
    v_retorno                     typ_validarSesion := typ_validarSesion;
  BEGIN
    IF length(p_sesionUsuario) = 47 THEN
      paw_seg.fu_val_ses_consumer(p_sesionUsuario,
                                  p_codCanal,
                                  v_retorno.error,
                                  v_retorno.nombreRespuesta,
                                  v_retorno.descripcionRespuesta,
                                  v_retorno.codigoPersona,
                                  v_retorno.codigoEmpresa,
                                  v_retorno.codigoPerfil);
      v_retorno.codigoCanal := p_codCanal;
      RETURN v_retorno;
    END IF;
    v_sesion := depurarAlfanumerico(p_sesionUsuario, 32);
  
    IF (p_codCanal IS NULL OR v_sesion IS NULL OR length(p_codCanal) = 0 OR
       length(v_sesion) = 0) THEN
      pr_mensajeUsuario(MSG_AUTH_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      pr_insertarBitacora(v_sesion, p_codCanal, NULL, COD_OPERACION, NULL, 'fu_validarSesion- Error Canal ' ||
                          fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_ERROR);
      RETURN v_retorno;
    END IF;
  
    BEGIN
      SELECT cod_canal,
             cod_persona,
             cod_per_vinculada,
             cod_perfil,
             fec_ult_actividad
        INTO v_retorno.codigoCanal,
             v_retorno.codigoPersona,
             v_retorno.codigoEmpresa,
             v_retorno.codigoPerfil,
             v_ultimoAcceso
        FROM BW_AUT_SESIONES TK
       WHERE TK.cod_sesion = v_sesion;
    EXCEPTION
      WHEN no_data_found THEN
        pr_mensajeUsuario(MSG_AUTH_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        pr_insertarBitacora('0', p_codCanal, v_sesion, COD_OPERACION, NULL, 'fu_validarSesion - Token inexistente-' ||
                            fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_ERROR);
        RETURN v_retorno;
      WHEN others THEN
        pr_insertarBitacora('0', p_codCanal, v_sesion, COD_OPERACION, NULL, ', ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200) || '] ' ||
                            fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_ERROR);
        pr_mensajeUsuario(MSG_AUTH_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        RETURN v_retorno;
    END;
  
    -- AuthToken  NO corresponde al usuario y canal proveido?
    IF (v_retorno.codigoCanal <> p_codCanal) THEN
      DELETE FROM BW_AUT_SESIONES WHERE cod_sesion = p_sesionUsuario;
      COMMIT;
    
      pr_mensajeUsuario(MSG_AUTH_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    
      pr_insertarBitacora('0', p_codCanal, p_sesionUsuario, COD_OPERACION, NULL, 'fu_validarSesion - Token no corresponde a canal-' ||
                          fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_ERROR);
      RETURN v_retorno;
    END IF;
  
    --El AuthToken  ya no es válido?
    IF ((FECHA_HORA_ACTUAL - v_ultimoAcceso) * 1440) > MAX_TIEMPO_INACTIVIDAD_SESION THEN
      DELETE FROM BW_AUT_SESIONES WHERE cod_sesion = p_sesionUsuario;
      COMMIT;
      pr_mensajeUsuario(MSG_TK_EXPIRADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      pr_insertarBitacora('0', p_codCanal, p_sesionUsuario, COD_OPERACION, v_retorno.codigoEmpresa, 'fu_validarSesion Token expirado-' ||
                          fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_ERROR);
      RETURN v_retorno;
    END IF;
  
    --todo fue ok, actualizar el ultimo acceso
    UPDATE BW_AUT_SESIONES
       SET fec_ult_actividad = FECHA_HORA_ACTUAL
     WHERE cod_sesion = p_sesionUsuario;
    COMMIT;
    pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    RETURN v_retorno;
  END;

  -- Verifico la situacion del numero de caja
  FUNCTION lf_val_caja(p_sesion IN typ_validarSesion) RETURN typ_mensajeCaja IS
    c_msg_caj_prohibida     constant varchar2(15) := '236';
    c_msg_est_caj_invalida  constant varchar2(15) := '237';
    c_msg_caj_no_encontrada constant varchar2(15) := '235';
    v_est_caja       cj_cajas.estado%type;
    v_tip_caja       cj_cajas.tipo%type;
    v_cod_ofi_origen cj_cajas.cod_oficina%type;
    v_cod_usuario    cj_cajas.cod_usuario%type;
    v_ult_cierre     cj_cajas.fec_hor_cierre%type;
    v_fec_cie_caja   cj_cajas.fec_cierre%type;
    v_retorno        typ_mensajeCaja := typ_mensajeCaja;
  
  BEGIN
    pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
  
    SELECT estado,
           tipo,
           cod_oficina,
           cod_usuario,
           fec_hor_cierre,
           fec_cierre
      INTO v_est_caja,
           v_tip_caja,
           v_cod_ofi_origen,
           v_cod_usuario,
           v_ult_cierre,
           v_fec_cie_caja
      FROM cj_cajas
     WHERE nro_caja = to_number(p_sesion.codigoCanal);
    IF v_tip_caja NOT IN ('C', 'I', 'S') THEN
      -- tipo de caja no permitido
      pr_mensajeUsuario(c_msg_caj_prohibida, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    END IF;
    IF v_est_caja <> 'A' THEN
      pr_mensajeUsuario(c_msg_est_caj_invalida, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    END IF;
  
    v_retorno.estadoCaja          := v_est_caja;
    v_retorno.tipoCaja            := v_tip_caja;
    v_retorno.codigoOficinaOrigen := v_cod_ofi_origen;
    v_retorno.codigoUsuario       := v_cod_usuario;
    v_retorno.fechaUltimoCierre   := v_ult_cierre;
    v_retorno.fechaCierre         := v_fec_cie_caja;
  
    RETURN v_retorno;
  EXCEPTION
    WHEN no_data_found THEN
      pr_mensajeUsuario(c_msg_caj_no_encontrada, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      RETURN v_retorno;
  END;

  FUNCTION lf_val_gen_ope_cierre RETURN VARCHAR2 IS
    v_genera    varchar2(1) := 'S'; -- 'S' Puede Generar Operación. ('N' No Generar ninguna Operación)
    v_nro_orden ge_par_dinamicos.val_parametro%type := Fug_Obt_Pardinamico('NRO_ORD_PROCESOS');
    /*NO se debe generar ningun tipo de movimientos cuando se esta corriendo alguno de estos procesos */
  BEGIN
    Select distinct ('N')
      into v_genera
      from ge_procesos_det a
     where a.cod_proceso = 11
       AND Instr(v_nro_orden, ',' || a.nro_orden || ',') > 0
       AND a.hor_inicio is not null
       AND a.hor_fin is null;
    return v_genera;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN v_genera;
  END;

  -- devuelve el campo monto formateado
  FUNCTION lf_for_money(p_dato     IN NUMBER,
                        p_longitud IN NUMBER DEFAULT NULL) RETURN VARCHAR2 IS
  BEGIN
    IF p_longitud IS NULL THEN
      RETURN ltrim(to_char(nvl(p_dato, 0), '9999999999999999.99'));
    ELSE
      RETURN lpad(ltrim(to_char(nvl(p_dato, 0), '9999999999999999.99')), p_longitud, ' ');
    END IF;
  END;

  PROCEDURE lp_obt_sue_errores(p_cod_ente            IN ge_entes.cod_ente%TYPE,
                               p_referencia          IN ge_pag_sueldos.nro_secuencia%TYPE,
                               p_listaDetalleSalario IN OUT typ_listaDetalleSalario,
                               p_fecha               IN DATE DEFAULT NULL) IS
    v_can_sue_errores NUMBER;
    v_det_salario     typ_detalleSalario := typ_detalleSalario();
    v_fec_actual      DATE := nvl(p_fecha, pag_cal.fu_obt_fec_actual(9)); -- fecha de hoy;
  
    CURSOR c_sue_error IS
      SELECT x.nro_cuenta,
             substr(z.denominacion, 1, 40) denominacion,
             x.cod_moneda cod_moneda,
             x.monto,
             x.msj_error
        FROM ge_cuentas z, ge_pag_sueldos_err x
       WHERE x.cod_ente = p_cod_ente
         AND x.fec_proceso = v_fec_actual
         AND nvl(x.nro_secuencia, 0) = nvl(p_referencia, 0)
         AND to_char(x.nro_cuenta) = z.nro_cuenta;
  BEGIN
    -- buscamos si hubieron registros con error
    SELECT nvl(COUNT(0), 0)
      INTO v_can_sue_errores
      FROM ge_pag_sueldos_err x
     WHERE x.cod_ente = p_cod_ente
       AND x.fec_proceso = v_fec_actual
       AND nvl(x.nro_secuencia, 0) = nvl(p_referencia, 0);
    -- desplegamos informacion de errores si las hubo
    IF v_can_sue_errores > 0 THEN
      FOR reg IN c_sue_error LOOP
        v_det_salario.numeroCuenta          := reg.nro_cuenta;
        v_det_salario.tipo                  := 'C';
        v_det_salario.descripcionTipoCuenta := NULL;
        v_det_salario.nombreCuenta          := substr(reg.denominacion, 1, 50);
        v_det_salario.codigoMoneda          := reg.cod_moneda;
        v_det_salario.monto                 := reg.monto;
        v_det_salario.error                 := 'S';
        v_det_salario.mensajeRespuesta      := substr(reg.msj_error, 1, 200);
        p_listaDetalleSalario.extend;
        p_listaDetalleSalario(p_listaDetalleSalario.count) := v_det_salario;
      END LOOP;
    END IF;
  END;

  FUNCTION lf_for_date(p_dato IN DATE) RETURN CHAR IS
  BEGIN
    RETURN nvl(to_char(p_dato, 'ddmmyyyy'), ' ');
  END;

  FUNCTION lf_obt_bco_snp_swift(p_cod_swift IN VARCHAR2) RETURN VARCHAR2 IS
    v_retorno gv_snp_participantes.participante%TYPE := NULL;
  BEGIN
    IF p_cod_swift is NULL THEN
      v_retorno := upper(fug_obt_nom_entidad);
    ELSE
      BEGIN
        SELECT a.participante
          INTO v_retorno
          FROM gv_snp_participantes a
         WHERE a.cod_swift = p_cod_swift
           AND rownum = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          SELECT b.subparticipante
            INTO v_retorno
            FROM ge_snp_patrocinador_det b
           WHERE b.cod_swift_sub = p_cod_swift
             AND b.estado = 'S';
      END;
      v_retorno := upper(v_retorno);
    END IF;
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  FUNCTION lf_obt_dat_extra(p_cod_per_principal IN bw_mov_pendientes.cod_per_principal%TYPE,
                            p_nro_documento     IN bw_mov_pendientes.nro_documento%TYPE,
                            p_cod_tip_mensaje   IN bw_mov_pendientes.cod_tip_mensaje%TYPE)
    RETURN VARCHAR2 IS
    v_retorno VARCHAR2(2000) := '{' || chr(10) || '  "valores" : [ ' || chr(10);
    rg_mpen   bw_mov_pendientes%ROWTYPE;
  BEGIN
    SELECT *
      INTO rg_mpen
      FROM bw_mov_pendientes p
     WHERE p.nro_documento = p_nro_documento
       AND p.cod_per_principal = p_cod_per_principal
       AND p.cod_tip_mensaje = p_cod_tip_mensaje;
  
    -- datos extras para transferencias SNP
    IF p_cod_tip_mensaje = '036' THEN
      DECLARE
        v_nom_beneficiario ge_snp_transferencias.nom_beneficiario%TYPE;
      BEGIN
        select transf.nombre
          INTO v_nom_beneficiario
          from (SELECT t.nom_beneficiario as nombre
                  FROM ge_snp_transferencias t
                 WHERE t.nro_referencia = rg_mpen.referencia
                union all
                SELECT p.nom_cli_receptor as nombre
                  FROM ge_spi_transferencias p
                 WHERE p.nro_referencia = rg_mpen.referencia) transf;
      
        v_retorno := v_retorno || '    { "etiqueta" : "Nombre Beneficiario", "valor" : "' || v_nom_beneficiario || '" } ';
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    ELSIF p_cod_tip_mensaje = '039' THEN
      v_retorno := v_retorno || '    { "etiqueta" : "Nro contrato", "valor" : "' || rg_mpen.referencia || '" } ';
    ELSIF p_cod_tip_mensaje = '055' THEN
      v_retorno := v_retorno || '{ "etiqueta" : "Nombre Beneficiario", "valor" : "' || fuw_nom_cre_tra_dev(p_nro_documento, p_cod_per_principal) || '"';
      IF fuw_obt_bts_pendiente(p_nro_documento, 'P') = 'S' THEN
        v_retorno := substr(v_retorno || ', "etiqueta" : "pendingConfirm", "valor" : "' || fug_obt_pardinamico('MSJ_TIMEOUT') || '"', 1, 2000);
      END IF;
      v_retorno := substr(v_retorno || ' }', 1, 2000);
    ELSIF p_cod_tip_mensaje = '150' THEN
      v_retorno := v_retorno || '{ "etiqueta" : "Empresa", "valor" : "' || fue_obt_nom_persona(rg_mpen.cod_per_principal) || '" } ';
    ELSE
      RETURN NULL;
    END IF;
    v_retorno := v_retorno || chr(10) || '  ]' || chr(10) || '}';
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  ------------------------------------------------------------------------------------
  PROCEDURE pr_autorizarOperacion(p_sesion               IN VARCHAR2,
                                  p_codigoCanal          IN VARCHAR2,
                                  p_modo                 IN VARCHAR2,
                                  p_numeroDocumento      IN NUMBER,
                                  p_comentario           IN VARCHAR2,
                                  p_claveTransaccional   IN VARCHAR2,
                                  p_error                OUT VARCHAR2,
                                  p_nombreRespuesta      OUT VARCHAR2,
                                  p_descripcionRespuesta OUT VARCHAR2,
                                  p_numeroDoc            OUT NUMBER) IS
  
    PRO_AUT_SIN_PERMISO         CONSTANT VARCHAR2(15) := 'PRO_AUT_SIN_PER';
    PRO_AUT_DOC_INEXISTENTE     CONSTANT VARCHAR2(15) := 'PRO_AUT_DOC_INE';
    PRO_AUT_ERR_OBT_PENDIENTE   CONSTANT VARCHAR2(15) := 'PRO_AUT_ERR_PEN';
    PRO_AUT_SAL_INSUFICIENTE    CONSTANT VARCHAR2(15) := 'SAL_CTA_INSUFIC';
    PRO_AUT_CTA_DEB_INV         CONSTANT VARCHAR2(15) := 'SAL_CTA_DEB_INV';
    PRO_AUT_PED_DUPLICADO       CONSTANT VARCHAR2(15) := 'PRO_AUT_DUPLICA';
    PRO_AUT_ERR_INS_DAT_SALARIO CONSTANT VARCHAR2(15) := 'PRO_AUT_DAT_SAL';
    PRO_AUT_ERR_PAG_SALARIO     CONSTANT VARCHAR2(15) := 'PRO_AUT_PAG_SAL';
    PRO_AUT_ERR_SAL_LOTES       CONSTANT VARCHAR2(15) := 'PRO_AUT_SAL_LOT';
    PRO_AUT_ERR_DAT_PROVEEDORES CONSTANT VARCHAR2(15) := 'PRO_ERR_VER_PAG';
    PRO_AUT_ERR_PAG_PROVEEDORES CONSTANT VARCHAR2(15) := 'PRO_ERR_PRO_PAG';
    PRO_AUT_ERR_PAG_PROVEE_INTE CONSTANT VARCHAR2(15) := 'ERR_PRO_PAG_INT';
    PRO_AUT_ERR_SNP_CANCELA     CONSTANT VARCHAR2(15) := 'PRO_AUT_SNP_CAN';
    ERR_LIM_OPERACION           CONSTANT VARCHAR2(15) := 'G_ERR_LIM_OPERA';
    PRO_AUT_OBT_DET_ERROR       CONSTANT VARCHAR2(15) := 'PRO_AUT_OBT_DET';
    PRO_ERR_SIPAP               CONSTANT VARCHAR2(15) := 'PRO_ERR_SIPAP';
    PRO_AUT_CTA_MON_CRED_INVA   CONSTANT VARCHAR2(15) := 'MON_DEB_INVALID';
    MSG_MOD_CIERRE              CONSTANT VARCHAR2(15) := 'MOD_SIS_CIERRE';
    MSG_MOD_CERRADO             CONSTANT VARCHAR2(15) := 'MSG_MOD_CERRADO';
    C_COD_OPERACION             CONSTANT VARCHAR2(03) := '026';
    v_modo                      VARCHAR2(1) := p_modo; --modo A,R
    v_nro_documento             bw_mov_pendientes.nro_documento%TYPE;
    v_comentario                VARCHAR(50) := depurarAlfanumerico(p_comentario, 50, 'S'); -- permite espacion
    v_nro_secuencia             NUMBER;
    mp                          bw_mov_pendientes%ROWTYPE;
    v_can_aut_faltantes         NUMBER(3) := 0;
    v_cod_operacion             VARCHAR2(3) := '023';
    v_fec_actual                DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy;
    v_retorno                   typ_autorizaOperacion := typ_autorizaOperacion();
    v_usu_sesion                typ_validarsesion;
    v_msj_caja                  typ_mensajeCaja;
    v_msj_respuesta             typ_mensajeRespuesta := typ_mensajeRespuesta();
    v_permiso                   typ_obtenerPermisos;
    v_cod_per_empresa           ba_personas.cod_persona%TYPE;
    v_cod_tra_padre             ge_transacciones.cod_transaccion%TYPE;
    v_lugar                     VARCHAR2(4000);
    v_cant_error                NUMBER(8);
    v_TCreCab                   NUMBER;
    v_TCreDet                   NUMBER;
    v_TDebDet                   NUMBER;
    v_cCreDet                   NUMBER;
    v_verificacion_ok           VARCHAR2(10);
    v_error                     VARCHAR2(4000);
    v_cod_error                 VARCHAR2(4000);
    v_Reprocesa                 VARCHAR2(1) := 'N';
    v_secuencia                 NUMBER(10) := 1;
    v_err_pago                  VARCHAR2(4000) := '00';
    v_res_limite                VARCHAR2(2);
    v_tip_pro_sueldo            VARCHAR2(1);
    v_pro_con_errores           VARCHAR2(1);
    v_cod_tip_mensaje_per       bw_tip_mensajes.cod_tip_mensaje%type;
    v_monto                     ge_movimientos.monto%TYPE;
    v_des_ente                  ge_entes.descripcion%TYPE;
    v_nro_pre_pactado           NUMBER := null;
    v_cod_mon_credito           VARCHAR2(5);
    v_tkd_admin                 VARCHAR2(1) := 'N';
    v_per_autorizador           VARCHAR2(1) := 'S';
    v_cod_mon_cred              varchar2(3);
    v_msj_bitacora              VARCHAR2(1000) := substr('modo:' || trim(v_modo) || ', nroDoc:' || p_numeroDocumento || ', com:' || v_comentario, 1, 1000);
    v_spi_devolucion            typ_devolucionSpi := typ_devolucionSpi;
    v_mto_devolucion            ge_snp_transferencias.monto%type;
    v_mot_devolucion            ge_snp_transferencias.tip_rechazo%type;
    v_nro_ref_original          ge_snp_transferencias.nro_ref_externa%type;
    v_nro_referencia            ge_snp_transferencias.nro_referencia%type;
    v_detalles                  typ_detalleautorizacion := typ_detalleautorizacion();
    PRO_AUT_ERR_DNA_MOVIMIENTO  CONSTANT VARCHAR2(15) := 'PRO_AUT_DNA_MOV';
    --PDSYP-449
    PRO_ERR_PRO_CRE             CONSTANT VARCHAR2(15) := 'PRO_ERR_PRO_CRE';
    PRO_ERR_SUE_CRE             CONSTANT VARCHAR2(15) := 'PRO_ERR_SUE_CRE';
    MSG_ERROR_CTACRE            CONSTANT VARCHAR2(500) := 'Error en Cta. de crédito:';
    v_pag_sue_mensaje   VARCHAR(4000);
  
    procedure lp_act_fec_valor(r_cab       ge_snp_transferencias%rowtype,
                               p_fec_valor date) is
    
    begin
      UPDATE GE_SNP_TRANSFERENCIAS C
         SET C.FEC_VALOR = p_fec_valor
       WHERE C.NRO_REFERENCIA = r_cab.nro_referencia;
    end;
  
  BEGIN
  
    if v_modo not in ('A', 'R') then
      p_error                := 'S';
      p_nombreRespuesta      := 'E_MODO_ERROR';
      p_descripcionRespuesta := 'El Modo es incorrecto';
      RETURN;
    end if;
  
    if (p_codigoCanal is null or p_codigoCanal not in (999, 998)) then
      p_error                := 'S';
      p_nombreRespuesta      := 'E_CANAL_ERROR';
      p_descripcionRespuesta := 'El Canal no puede ser nulo';
      RETURN;
    end if;    
  
    ------------------------------------------------------------------------------------
    -- 1. valido la clave del cliente
    v_usu_sesion := fu_validarSesion(depurarAlfanumerico(p_sesion, 32), p_codigoCanal);
    
    IF v_usu_sesion.error = 'S' THEN
      p_error                := v_usu_sesion.error;
      p_nombreRespuesta      := v_usu_sesion.nombreRespuesta;
      p_descripcionRespuesta := v_usu_sesion.descripcionRespuesta;
      RETURN;
    END IF;
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, p_nombreRespuesta, p_descripcionRespuesta, p_error);
  
    v_nro_documento   := p_numeroDocumento;
    v_cod_per_empresa := v_usu_sesion.codigoEmpresa;
  
    IF p_error = 'N' THEN
      -- 1. busco los datos de la operacion pendiente
      BEGIN
        SELECT *
          INTO mp
          FROM bw_mov_pendientes
         WHERE nro_documento = v_nro_documento
           AND cod_per_principal = v_cod_per_empresa
           AND ((cod_tip_mensaje not in ('070', '075') and trunc(sysdate - 10) <= trunc(fec_insercion)) -- pago salarios, pago proveedores
               OR (cod_tip_mensaje in ('070', '075') and trunc(SYSDATE) >= TRUNC(to_date(dato2, 'DD/MM/YYYY'))));
        
        v_msj_bitacora := v_msj_bitacora || ', cod_tip:' || mp.cod_tip_mensaje;
        -- verificar si tiene permiso para autorizar esa operacion
        v_cod_tip_mensaje_per := mp.cod_tip_mensaje;
        if v_cod_tip_mensaje_per = '071' then
          v_cod_tip_mensaje_per := '070';
          --acreditacion gourmet usa los mismos permisos que pago de salarios
        end if;
        v_permiso := lf_obt_permisos(v_usu_sesion, v_cod_tip_mensaje_per);
        IF (v_permiso.error = 'S') THEN
          p_nombreRespuesta      := v_permiso.nombreRespuesta;
          p_descripcionRespuesta := v_permiso.descripcionRespuesta;
          p_error                := v_permiso.error;
          pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                              fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
          RETURN;
        END IF;
        -- si no tiene permiso para autorizar, chequeamos que no haya registrado el documento
        -- si el usuario cargo el movimiento, puede eliminar siempre y cuando no se haya firmado
        IF v_permiso.autoriza = FALSE THEN
          v_per_autorizador := 'N';
          IF v_permiso.registra = FALSE OR
             mp.cod_per_ingreso <> v_usu_sesion.codigoPersona OR
             p_modo = 'A' OR mp.can_aut_faltantes <> mp.can_aut_requeridas THEN
            pr_mensajeUsuario(PRO_AUT_SIN_PERMISO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                                fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
            RETURN;
          END IF;
        END IF;
        v_msj_bitacora := v_msj_bitacora || ', es_aut: ' || v_per_autorizador;
      EXCEPTION
        WHEN OTHERS THEN
          pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
          v_msj_bitacora := substr(v_msj_bitacora || ', ORA-ERR:[' || SQLERRM || ']', 1, 1000);
          RETURN;
      END;
    END IF;
    -- 2. verifica el canal de origen
    v_msj_caja := lf_val_caja(v_usu_sesion);
    IF v_msj_caja.error = 'S' THEN
      p_error                := v_msj_caja.error;
      p_nombreRespuesta      := v_msj_caja.nombreRespuesta;
      p_descripcionRespuesta := v_msj_caja.descripcionRespuesta;
      RETURN;
    END IF;
    -- si es adminitrador token digital
    v_tkd_admin    := paw_otp.fu_es_aut_softoken(v_usu_sesion.codigoPersona, v_usu_sesion.codigoEmpresa);
    v_msj_bitacora := v_msj_bitacora || ', st_adm: ' || v_tkd_admin;
  
    -- Verificar estado del modulo
    IF pae_cnf.FU_OBT_EST_MODULO(3) IN (1, 6) THEN
      pr_mensajeUsuario(MSG_MOD_CIERRE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
      RETURN;
    END IF;
  
    IF NVL(lf_val_gen_ope_cierre, 'S') = 'N' THEN
      pr_mensajeUsuario(MSG_MOD_CIERRE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
      RETURN;
    END IF;
  
    pr_mensajeUsuario(MSG_OK, p_nombreRespuesta, p_descripcionRespuesta, p_error);
    IF v_per_autorizador = 'N' THEN
      p_nombreRespuesta := PRO_AUT_SIN_PERMISO; -- puede eliminar, se marca para token digital habilite solo eliminar
    END IF;
    pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                        fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ENTRADA);
  
    -- 2. verifico la accion
    IF p_error = 'N' THEN
      IF v_cod_per_empresa IS NULL THEN
        BEGIN
          SELECT MIN(cod_per_principal)
            INTO v_cod_per_empresa -- esta es una solucion para que los clientes fisicos de cuentas conjuntas puedan autorizarse
            FROM bw_mov_pendientes a
           WHERE estado = 'P'
             AND pag_gen.FU_ES_PER_FISICA(cod_per_principal) = 'S'
             AND cod_per_principal <> v_usu_sesion.codigoPersona
             AND EXISTS
           (SELECT 0
                    FROM ge_cta_clientes b
                   WHERE b.nro_cuenta = a.nro_cuenta
                     AND b.cod_persona = v_usu_sesion.codigoPersona);
        EXCEPTION
          WHEN OTHERS THEN
            v_cod_per_empresa := NULL;
        END;
      END IF;
      IF v_modo IN ('D', 'A', 'R', 'I') THEN
        -- D-DETALLE, A-AUTORIZAR, R-RECHAZAR OPERACION, 'I-IMPRIMIR'
        -- modo visualizar detalles
        -- controlo que el número de documento pertenezca a la empresa
        IF paw_bce.fu_val_per_pendiente(v_nro_documento, v_cod_per_empresa) = 'N' AND mp.cod_tip_mensaje <> '008' THEN
          pr_mensajeusuario(PRO_AUT_SIN_PERMISO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
          RETURN;
        END IF;
        -- controlo el limite de operacion
        IF p_error = 'N' and v_modo in ('D', 'A', 'R') AND
           mp.cod_tip_mensaje <> '008' THEN
          paw_bce.v_cod_respuesta := paw_bce.v_cod_aprobado;
          v_res_limite            := paw_bce.fu_obt_aut_limite(v_cod_per_empresa, v_nro_documento, v_usu_sesion.codigoPersona);
          v_msj_bitacora          := v_msj_bitacora || ', resLim:' || v_res_limite;
        
          IF paw_bce.v_cod_aprobado <> paw_bce.v_cod_respuesta THEN
            IF paw_bce.v_cod_respuesta = paw_bce.v_cod_cta_sin_mov THEN
              pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            ELSIF paw_bce.v_cod_respuesta = paw_bce.v_cod_ped_duplicado THEN
              pr_mensajeusuario(PRO_AUT_PED_DUPLICADO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            ELSE
              pr_mensajeusuario(ERR_LIM_OPERACION, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            END IF;
            v_msj_bitacora := v_msj_bitacora || ', codRes: ' || paw_bce.v_cod_respuesta || ', ORA-ERR: [' || substr(sqlerrm, 1, 100) || ']';
          ELSE
            v_retorno.respuestaLimite := v_res_limite;
          END IF;
        END IF;
        IF mp.cod_tip_mensaje = '008' THEN
          v_res_limite              := '02';
          v_retorno.respuestaLimite := v_res_limite;
        END IF;
      END IF;
    
      -- si no hubo errores se consultan los límites o el detalle
      IF p_error = 'N' THEN
        v_retorno.fechaInsercion := mp.fec_insercion;
        IF v_modo = 'D' THEN
          IF mp.cod_tip_mensaje <> '008' THEN
            v_retorno.detalles := paw_bem.fu_obtenerDetalleAutorizacion(p_sesion, p_codigoCanal, v_nro_documento);
            IF v_retorno.detalles.error = 'S' THEN
              pr_mensajeUsuario(PRO_AUT_OBT_DET_ERROR, p_nombreRespuesta, p_descripcionRespuesta, p_error);
              pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                  v_msj_bitacora || ', det-err: [' || substr(v_retorno.detalles.descripcionError, 1, 200) || ']' ||
                                  fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
              RETURN;
            END IF;
          ELSE
            paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_detalles.descripcionError, v_detalles.descripcionMensaje, v_detalles.error);
            v_detalles.fechaOperacion        := mp.fec_hora;
            v_detalles.codigoMovimiento      := mp.cod_tip_mensaje;
            v_detalles.descripcionMensaje    := mp.descripcion;
            v_detalles.cantidadAutRequeridas := mp.can_aut_requeridas;
            v_detalles.cantidadAutFaltantes  := mp.can_aut_faltantes;
            v_detalles.nombreIngreso         := fue_obt_nom_persona(mp.cod_per_ingreso);
            v_detalles.dato                  := substr('OPERADOR ' || fue_obt_nom_persona(mp.cod_per_ingreso), 1, 50);
            v_detalles.descripcionMovimiento := mp.descripcion;
            v_detalles.numeroComprobante     := mp.nro_documento;
            v_retorno.detalles               := v_detalles;
            v_retorno.numeroDocumento        := mp.nro_documento;
            v_retorno.respuestaLimite        := '02'; -- siempre softoken
            p_numeroDoc                      := mp.nro_documento;
          END IF;
        ELSIF v_modo IN ('R', 'I') THEN
          v_retorno.detalles := paw_bem.fu_obtenerDetalleAutorizacion(p_sesion, p_codigoCanal, v_nro_documento, 'N');
          if mp.cod_tip_mensaje = '036' then
            declare
              r_snp ge_snp_transferencias%rowtype;
            begin
              select *
                into r_snp
                from ge_snp_transferencias c
               where c.nro_referencia = mp.nro_ope_relacionada;
              v_retorno.numeroDocumento := r_snp.nro_referencia;
              p_numeroDoc               := r_snp.nro_referencia;
            end;
          
          end if;
          IF v_retorno.detalles.error = 'S' THEN
            pr_mensajeUsuario(PRO_AUT_OBT_DET_ERROR, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                v_msj_bitacora || ', det-err: [' || substr(v_retorno.detalles.descripcionError, 1, 200) || ']' ||
                                fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
            RETURN;
          END IF;
        END IF;
      END IF;
    
      IF p_error = 'N' AND v_modo IN ('A', 'R') THEN
        -- se debe controlar la clave transaccioanl
        if mp.cod_tip_mensaje in ('030', '039', '036') then
          if (nvl(fug_obt_pardinamico('VAL_CLA_TRANSACCIONAL'), 'N') = 'S') then
            v_msj_respuesta := paw_seg.fu_val_ope_clave(p_claveTransaccional, v_usu_sesion.codigoPersona, v_cod_per_empresa, 'T');
          end if;
        else
          v_msj_respuesta := paw_seg.fu_val_ope_clave(p_claveTransaccional, v_usu_sesion.codigoPersona, v_cod_per_empresa, 'T');
        end if;
        IF v_msj_respuesta.error = 'S' THEN
          p_error                := v_msj_respuesta.error;
          p_nombreRespuesta      := v_msj_respuesta.nombreRespuesta;
          p_descripcionRespuesta := v_msj_respuesta.descripcionRespuesta;
        END IF;
        -- 1. busco los datos de la operacion pendiente
        IF p_error = 'N' THEN
          BEGIN
            SELECT *
              INTO mp
              FROM bw_mov_pendientes
             WHERE nro_documento = v_nro_documento
               AND cod_per_principal = v_cod_per_empresa
               AND estado IN ('P', 'I');
          EXCEPTION
            WHEN no_data_found THEN
              pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            WHEN OTHERS THEN
              pr_mensajeusuario(PRO_AUT_ERR_OBT_PENDIENTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
              v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || ']';
          END;
        END IF;
      END IF;
    
      IF p_error = 'N' and mp.cod_tip_mensaje = 039 and
         v_modo IN ('A', 'D') THEN
        DECLARE
          v_transferencia typ_transferencia_hb;
          v_cod_mon_cred  varchar2(3);
        BEGIN
          SELECT cod_moneda
            INTO v_cod_mon_cred
            FROM ge_cuentas
           WHERE nro_cuenta = mp.nro_cta_contra;
        
          v_transferencia := paw_bem.fu_transferenciasTerceros(p_sesion,
                                                               p_codigoCanal,
                                                               mp.nro_cuenta, -- cuenta debito
                                                               mp.monto, -- monto de la operacion
                                                               mp.nro_cta_contra, -- cuenta credito
                                                               v_cod_mon_cred, -- cod_mon_credito
                                                               'VC', -- ACTUALIZACION DE COTIZACION
                                                               mp.dato, -- documento credito
                                                               mp.dato2, -- concepto
                                                               nvl(mp.referencia, 0), --nro_contrato
                                                               NULL,
                                                               NULL,
                                                               p_numeroDocumento);
          IF v_transferencia.error = 'S' THEN
            p_error                := v_transferencia.error;
            p_nombreRespuesta      := v_transferencia.nombreRespuesta;
            p_descripcionRespuesta := v_transferencia.descripcionRespuesta;
          ELSE
            UPDATE bw_mov_pendientes
               SET cotizacion = v_transferencia.cotizacion,
                   cot_contra = v_transferencia.cotizacionCredito,
                   monto      = v_transferencia.monto,
                   mto_contra = v_transferencia.montoCredito
             WHERE nro_documento = v_nro_documento;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            pr_mensajeusuario(PRO_AUT_CTA_MON_CRED_INVA, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || ']';
        END;
      END IF;

      IF p_error = 'N' and mp.cod_tip_mensaje = 055 and
         v_modo IN ('A', 'D') THEN
        DECLARE
          v_transferencia typ_transferencia_hb;
        BEGIN
          v_transferencia := paw_bem.fu_transferencia_dev(p_sesion,
                                                          p_codigoCanal,
                                                          mp.nro_cuenta, -- cuenta debito
                                                          mp.mto_contra, -- monto credito
                                                          mp.nro_cta_contra, -- cuenta credito
                                                          mp.dato2, -- cod_mon_credito
                                                          'VC', -- ACTUALIZACION DE COTIZACION
                                                          mp.dato, -- documento credito
                                                          mp.descripcion, -- concepto
                                                          nvl(mp.referencia, 0), --nro_contrato
                                                          NULL,
                                                          NULL,
                                                          NULL);
          IF v_transferencia.error = 'S' THEN
            p_error                := v_transferencia.error;
            p_nombreRespuesta      := v_transferencia.nombreRespuesta;
            p_descripcionRespuesta := v_transferencia.descripcionRespuesta;
          ELSE
            UPDATE bw_mov_pendientes
               SET cotizacion = v_transferencia.cotizacion,
                   cot_contra = v_transferencia.cotizacionCredito,
                   monto      = v_transferencia.monto,
                   mto_contra = v_transferencia.montoCredito
             WHERE nro_documento = v_nro_documento;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            pr_mensajeusuario(PRO_AUT_CTA_MON_CRED_INVA, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || ']';
        END;
      END IF;

      -- si no hubo errores y es mensaje para autorizar
      IF v_modo = 'A' AND p_error = 'N' THEN
        -- actualizo el movimiento pendiente
        savepoint mov_pendiente;
        UPDATE bw_mov_pendientes
           SET can_aut_faltantes = nvl(can_aut_faltantes, 0) - 1,
               estado            = decode(can_aut_faltantes, 1, 'C', estado)
         WHERE nro_documento = v_nro_documento
           AND cod_per_principal = v_cod_per_empresa
        RETURNING can_aut_faltantes INTO v_can_aut_faltantes;

        -- verificamos el saldo disponible para pago de salarios
        IF p_error = 'N' THEN
          -- inserto el movimiento de autorización
          BEGIN
            INSERT INTO bw_autorizaciones
              (cod_persona, nro_documento, fec_hora, accion, observacion)
            VALUES
              (v_usu_sesion.codigoPersona, v_nro_documento, SYSDATE, 'A', v_comentario);
          EXCEPTION
            WHEN dup_val_on_index THEN
              pr_mensajeusuario(PRO_AUT_PED_DUPLICADO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
          END;
        END IF;
        -- se controla por autorizante el saldo de la cuenta para pago de sueldos
        IF p_error = 'N' AND mp.cod_tip_mensaje = '070' THEN
          -- obtenemos la transacción padre
          v_cod_tra_padre := paw_bem.fu_obt_tra_sueldo(mp.dato, mp.tip_pago);

          -- obtenemos el tipo de proceso de sueldo para el ente
          v_tip_pro_sueldo  := paw_bem.fu_obt_tip_pro_sueldo(mp.dato);
          v_pro_con_errores := nvl(fug_obt_parentes(mp.dato, 'PRO_CON_ERRORES'), 'N');
        
          IF TRUNC(TO_DATE(mp.dato2, 'DD/MM/YYYY')) >
             TRUNC(mp.fec_insercion) THEN
            v_tip_pro_sueldo := 'B';
          END IF;
        
          -- pagos de aguinalo seran Online y Cancelar con errores independientemente de
          -- la configuracion del ente
          IF mp.tip_pago = 'A' THEN
            v_tip_pro_sueldo  := 'O';
            v_pro_con_errores := 'C';
          END IF;

          v_msj_bitacora := v_msj_bitacora || ', codEn:' || mp.dato || ', tipRe:' || mp.dato2 || ', proSue:' || v_tip_pro_sueldo || ', traPa:' ||
                            v_cod_tra_padre || ', proErr: ' || v_pro_con_errores;
        END IF;
        IF mp.cod_tip_mensaje in ('070', '071') THEN
          IF mp.cod_tip_mensaje = '071' THEN
            --Si el servicio es Gourmet, se trae la cuenta padre
            v_cod_tra_padre := NVL(FUG_OBT_PARDINAMICO('GOU_CTA_PADRE'), 5166);
          END IF;
          -- verificamos si se puede realizar la operación de débito
          IF paw_bce.fu_ver_operacion(mp.nro_cuenta, mp.monto, 503, v_cod_tra_padre, 'D') = 'N' THEN
            IF pag_cta.g_cod_error <> 0 THEN
              --Verificacion de la operacion retorna error. Se verifica si corresponde a insuficiencia de fondos
              IF pag_cta.g_cod_error IN (25, 29, 31, 36) THEN
                IF mp.cod_tip_mensaje = '070' THEN
                  -- En el caso de Pago de salarios se verifica saldo solo si es pago online
                  IF v_tip_pro_sueldo = 'O' OR (v_tip_pro_sueldo = 'B' AND TRUNC(SYSDATE) = TRUNC(TO_DATE(mp.dato2, 'DD/MM/YYYY'))) THEN
                    pr_mensajeusuario(PRO_AUT_SAL_INSUFICIENTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                  END IF;
                ELSE
                  -- La cuenta no tiene saldo suficiente
                  pr_mensajeusuario(PRO_AUT_SAL_INSUFICIENTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                END IF;
              ELSE
                -- Ocurrio un error distinto a insuficiencia de fondos
                pr_mensajeusuario(PRO_AUT_CTA_DEB_INV, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                v_msj_bitacora := v_msj_bitacora || ', CTA-ERR:[' || SUBSTR(pag_cta.G_MSJ_ERROR, 1, 200) || ']';
              END IF;
            END IF;
          END IF;
        END IF;
        --se agrega esto aquí de nuevo para que haga un refresh de la cantidad de autorizaciones
        --registradas, pues en el momento en el que se autoriza por primera vez no refresca y sale 0

        IF p_error = 'N' THEN
          v_retorno.detalles := paw_bem.fu_obtenerDetalleAutorizacion(p_sesion, p_codigoCanal, v_nro_documento);
          IF v_retorno.detalles.error = 'S' THEN
            pr_mensajeUsuario(PRO_AUT_OBT_DET_ERROR, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                v_msj_bitacora || ', det-err: [' || substr(v_retorno.detalles.descripcionError, 1, 200) || ']' ||
                                fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
            RETURN;
          END IF;
        END IF;
        --- VERIFICO QUE TIPO DE OPERACION ES LA QUE SE CONFIRMA
        IF p_error = 'N' AND v_can_aut_faltantes = 0 THEN
          v_can_aut_requeridas := 1; -- esto para permitir debitar a cuentas conjuntas
          g_aut_operacion      := TRUE; -- para controlar el modo 'A' en las funciones que venga de autorizar
          it.paw_bem.pr_set_aut_operacion(TRUE);
		  it.paw_bem.pr_set_can_aut_requeridas(1);

          -- Verificar estado del modulo
          IF pae_cnf.FU_OBT_EST_MODULO(3) IN (1, 6) THEN
            pr_mensajeUsuario(MSG_MOD_CIERRE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
            pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                v_msj_bitacora || ' ' || fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
            RETURN;
          END IF;

          IF mp.cod_tip_mensaje = '030' THEN
            -- transferencias propias
            DECLARE
              v_transferencia typ_transferencia_hb;
            BEGIN
              v_transferencia := paw_bem.fu_transferenciasPropias(p_sesion,
                                                                  p_codigoCanal,
                                                                  mp.nro_cuenta, -- cuenta debito
                                                                  mp.monto, -- monto operacion
                                                                  mp.nro_cta_contra, -- cuentra credito
                                                                  'A', -- autorizar
                                                                  mp.dato2, -- concepto
                                                                  mp.cotizacion, -- cotizacion debito
                                                                  mp.cot_contra, -- cotizacion credito
                                                                  mp.mto_contra, -- monto credito
                                                                  NULL,
                                                                  NULL,
                                                                  p_numeroDocumento);
              IF v_transferencia.error = 'S' THEN
                p_error                := v_transferencia.error;
                p_nombreRespuesta      := v_transferencia.nombreRespuesta;
                p_descripcionRespuesta := v_transferencia.descripcionRespuesta;
              ELSE
                v_retorno.numeroDocumento := v_transferencia.nroDocumento;
                p_numeroDoc               := v_transferencia.nroDocumento;
              END IF;
            END;
          ELSIF mp.cod_tip_mensaje = '031' THEN
            -- pago de prestamos
            DECLARE
              v_prestamo typ_pagoprestamo;
            BEGIN
              v_prestamo                := paw_bem.fu_pagoPrestamo
                                           (p_sesion,
                                            p_codigoCanal,
                                            mp.nro_cta_contra, -- numero prestamo
                                            mp.nro_cuenta, -- cuenta debito
                                            mp.dato, -- cantidad de cuotas
                                            mp.monto, -- monto del prestamo
                                            'A', -- autorizar
                                            NULL,
                                            NULL,
                                            p_numeroDocumento);
              p_error                   := v_prestamo.error;
              p_nombreRespuesta         := v_prestamo.nombreRespuesta;
              p_descripcionRespuesta    := v_prestamo.descripcionRespuesta;
              v_retorno.numeroDocumento := v_prestamo.nroDocumento;
              p_numeroDoc               := v_prestamo.nroDocumento;
            END;
          ELSIF mp.cod_tip_mensaje = '032' THEN
            -- tarjeta credito
            DECLARE
              v_pagotarjeta typ_pagoTarjetaCredito;
            BEGIN
              v_pagotarjeta := paw_bem.fu_pagoTarjetaCredito(p_sesion,
                                                             p_codigoCanal,
                                                             mp.dato, -- numero tarjeta
                                                             mp.nro_cuenta, -- cuenta debito
                                                             'A', -- autorizar
                                                             NULL, -- numero sobre
                                                             0, -- importe efectivo
                                                             0, -- cheque nuestro banco
                                                             0, -- cheque otro banco
                                                             mp.monto, -- importe debito
                                                             mp.monto, -- total pago
                                                             NULL,
                                                             NULL,
                                                             'S' /*p_online*/,
                                                             p_numeroDocumento);
              IF v_pagotarjeta.error = 'S' THEN
                p_error                := v_pagotarjeta.error;
                p_nombreRespuesta      := v_pagotarjeta.nombreRespuesta;
                p_descripcionRespuesta := v_pagotarjeta.descripcionRespuesta;
              ELSE
                v_retorno.numeroDocumento := v_pagotarjeta.numeroOperacion;
                p_numeroDoc               := v_pagotarjeta.numeroOperacion;
              END IF;
            END;
          ELSIF mp.cod_tip_mensaje = '033' THEN
            -- invoco al pago de despachos aduaneros
            DECLARE
              v_msj_original bw_movimientos.observacion%TYPE;
              v_aduana       typ_pagoAduana;
            BEGIN
              SELECT observacion
                INTO v_msj_original
                FROM bw_movimientos
               WHERE nro_documento = mp.nro_documento
                 AND trunc(fec_hora) = trunc(mp.fec_hora)
                 AND cod_tip_mensaje = '033';
            
              v_msj_bitacora := v_msj_bitacora || ', mto:' || mp.monto || ', codOpe: ' || trim(substr(v_msj_original, 1, 3)) || ', cpo1: ' ||
                                trim(substr(v_msj_original, 4, 18)) || ', cpo2: ' || trim(substr(v_msj_original, 22, 18));
            
              v_aduana := paw_bem.fu_pagoAduana(p_sesion,
                                                p_codigoCanal,
                                                mp.nro_cuenta, -- cuenta debito
                                                'A', -- autorizacion
                                                mp.monto, -- monto
                                                trim(substr(v_msj_original, 1, 3)), -- TID, TCA, TLE, TDA
                                                trim(substr(v_msj_original, 4, 18)), -- campo1
                                                trim(substr(v_msj_original, 22, 18)), -- campo2
                                                trim(substr(v_msj_original, 40, 50)), -- nombre importador
                                                trim(substr(v_msj_original, 90, 50)), -- nombre despachante
                                                NULL,
                                                NULL);
              IF v_aduana.error = 'S' THEN
                p_error                := v_aduana.error;
                p_nombreRespuesta      := v_aduana.nombreRespuesta;
                p_descripcionRespuesta := v_aduana.descripcionRespuesta;
              ELSE
                v_retorno.numeroDocumento := v_aduana.nroDocumento;
                p_numeroDoc               := v_aduana.nroDocumento;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                pr_mensajeusuario(PRO_AUT_ERR_DNA_MOVIMIENTO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || ']';
            END;
          
            -- v_nro_operacion    := mp.nro_documento; -- cambio el nro de operacion
          ELSIF mp.cod_tip_mensaje = '036' THEN
            DECLARE
              v_tra_interbancaria typ_transferenciainterbancaria;
              r_snp_tra           ge_snp_transferencias%rowtype;
              c_fec_invalida constant varchar2(03) := '137';
            BEGIN
              v_msj_bitacora := v_msj_bitacora || ', ref:' || mp.referencia;
              v_msj_bitacora := v_msj_bitacora || ', monCre:' || v_cod_mon_credito || ', nroPrePac:' || v_nro_pre_pactado;

              select *
                into r_snp_tra
                from ge_snp_transferencias c
               where c.nro_referencia = mp.nro_ope_relacionada;
            
              v_cod_mon_credito := r_snp_tra.cod_moneda;
              -- Invoco a la Transferencia Interbancaria
              v_tra_interbancaria := paw_bem.fu_transferenciaInterbancaria(p_sesion,
                                                                           p_codigoCanal,
                                                                           'A',
                                                                           r_snp_tra.cod_swi_pte_beneficiario, -- p_codigoSwift
                                                                           r_snp_tra.nro_cta_beneficiario, --p_numeroCuentaCredito
                                                                           r_snp_tra.nro_cta_solicitante, --p_numeroCuentaDebito
                                                                           v_cod_mon_credito, --p_codigoMonedaCredito
                                                                           r_snp_tra.monto, --p_montoCredito
                                                                           r_snp_tra.fec_valor, --p_fechaOperacion
                                                                           NULL, --p_cargos
                                                                           NULL, --p_numeroDocumentoCredito
                                                                           NULL, --p_nombreBeneficiario
                                                                           NULL, --p_direccionBeneficiario
                                                                           null, --p_numeroContrato
                                                                           nvl(mp.dato5, v_comentario), --p_concepto
                                                                           NULL, --p_numeroIp
                                                                           NULL, --p_tipoMensaje
                                                                           NULL, --p_tipoDocumentoBeneficiario
                                                                           r_snp_tra.nro_referencia, --p_numeroReferencia
                                                                           r_snp_tra.monto, --p_montoDebito
                                                                           mp.cotizacion, --p_cotizacionDebito
                                                                           mp.cot_contra, --p_cotizacionCredito
                                                                           NULL,
                                                                           NULL,
                                                                           mp.tip_pago,
                                                                           p_numeroDocumento, 
                                                                           mp.dato7);
              IF v_tra_interbancaria.error = 'S' THEN
                /* En el caso de fecha invalida, hacemos un update a la fecha valor*/
                if v_tra_interbancaria.nombreRespuesta = c_fec_invalida then
                  lp_act_fec_valor(r_snp_tra, to_date(v_tra_interbancaria.fechaOperacion, 'DD/MM/YYYY'));
                  select *
                    into r_snp_tra
                    from ge_snp_transferencias c
                   where c.nro_referencia = mp.nro_ope_relacionada;
                  v_tra_interbancaria := paw_bem.fu_transferenciaInterbancaria(p_sesion,
                                                                               p_codigoCanal,
                                                                               'A',
                                                                               r_snp_tra.cod_swi_pte_beneficiario, -- p_codigoSwift
                                                                               r_snp_tra.nro_cta_beneficiario, --p_numeroCuentaCredito
                                                                               r_snp_tra.nro_cta_solicitante, --p_numeroCuentaDebito
                                                                               v_cod_mon_credito, --p_codigoMonedaCredito
                                                                               r_snp_tra.monto, --p_montoCredito
                                                                               r_snp_tra.fec_valor, --p_fechaOperacion
                                                                               NULL, --p_cargos
                                                                               NULL, --p_numeroDocumentoCredito
                                                                               NULL, --p_nombreBeneficiario
                                                                               NULL, --p_direccionBeneficiario
                                                                               null, --p_numeroContrato
                                                                               nvl(mp.dato5, v_comentario), --p_concept
                                                                               NULL, --p_numeroIp
                                                                               NULL, --p_tipoMensaje
                                                                               NULL, --p_tipoDocumentoBeneficiario
                                                                               r_snp_tra.nro_referencia, --p_numeroReferencia
                                                                               r_snp_tra.monto, --p_montoDebito
                                                                               mp.cotizacion, --p_cotizacionDebito
                                                                               mp.cot_contra, --p_cotizacionCredito
                                                                               NULL,
                                                                               NULL,
                                                                               mp.tip_pago,
                                                                               p_numeroDocumento,
                                                                               mp.dato7);
                end if;
                p_error                := v_tra_interbancaria.error;
                p_nombreRespuesta      := v_tra_interbancaria.nombreRespuesta;
                p_descripcionRespuesta := v_tra_interbancaria.descripcionRespuesta;
              ELSE
                v_retorno.numeroDocumento := substr(v_tra_interbancaria.numeroDocumento, 1, 15);
                p_numeroDoc               := substr(v_tra_interbancaria.numeroDocumento, 1, 15);
              END IF;
            END;
            --SPI fase2 - Autorizacion de devoluciones
          ELSIF mp.cod_tip_mensaje = C_COD_OPERACION THEN
            v_usu_sesion := fu_validarsesion(p_sesion, p_codigoCanal);

            IF v_usu_sesion.error = 'S' THEN
              p_error                := v_usu_sesion.error;
              p_nombreRespuesta      := v_usu_sesion.nombreRespuesta;
              p_descripcionRespuesta := v_usu_sesion.descripcionRespuesta;
              RETURN;
            END IF;

            BEGIN
              select sl.nro_ref_msj_original,
                     sl.nro_referencia,
                     tf.monto,
                     tf.tip_rechazo
                into v_nro_ref_original,
                     v_nro_referencia,
                     v_mto_devolucion,
                     v_mot_devolucion
                from ge_spi_solicitudes sl
                join ge_snp_transferencias tf
                  on sl.nro_referencia = tf.nro_referencia
               where sl.cod_sol_spi = mp.nro_ope_relacionada;
            
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                p_error                := 'S';
                p_nombreRespuesta      := '1';
                p_descripcionRespuesta := 'No se encuentra la solicitud N° ' || mp.nro_ope_relacionada;
                RETURN;
            END;
            v_spi_devolucion := paw_bem.fu_devolucionSpi(p_sesion,
                                                         p_codigoCanal,
                                                         'A',
                                                         v_nro_ref_original,
                                                         v_mot_devolucion,
                                                         v_mto_devolucion,
                                                         mp.nro_ope_relacionada,
                                                         null);
            if v_spi_devolucion.error = 'S' then
              update ge_snp_transferencias fe
                 set fe.estado    = 'C',
                     fe.situacion = 'C',
                     error        = substr(v_spi_devolucion.descripcionRespuesta, 1, 4000)
               where fe.nro_referencia = v_nro_referencia;
            
              update bw_mov_pendientes
                 set estado = decode(v_per_autorizador, 'S', 'A', 'B') -- ELIMINADA
               where nro_documento = v_nro_documento
                 and cod_per_principal = v_cod_per_empresa;
            else
              v_retorno.numeroDocumento := mp.nro_ope_relacionada;
              p_numeroDoc               := mp.nro_ope_relacionada;
            end if;
            p_error                := v_spi_devolucion.error;
            p_nombreRespuesta      := v_spi_devolucion.nombreRespuesta;
            p_descripcionRespuesta := v_spi_devolucion.descripcionRespuesta;
          ELSIF mp.cod_tip_mensaje = '038' THEN
            --Cancelacion de Transferencia Interbancaria
            DECLARE
              v_can_tra_interbancaria typ_cancelarTransferenciaSnp;
            BEGIN
              v_msj_bitacora := v_msj_bitacora || ', ref:' || mp.referencia;
              -- Invoco a la Transferencia Interbancaria
            
              IF v_can_tra_interbancaria.error = 'S' THEN
                p_error                := v_can_tra_interbancaria.error;
                p_nombreRespuesta      := v_can_tra_interbancaria.nombreRespuesta;
                p_descripcionRespuesta := v_can_tra_interbancaria.descripcionRespuesta;
              END IF;
            END;
          ELSIF mp.cod_tip_mensaje = '039' THEN
            -- transferencia terceros
            DECLARE
              v_transferencia typ_transferencia_hb;
            BEGIN
              v_transferencia := paw_bem.fu_transferenciasTerceros(p_sesion,
                                                                   p_codigoCanal,
                                                                   mp.nro_cuenta, -- cuenta debito
                                                                   mp.monto, -- monto de la operacion
                                                                   mp.nro_cta_contra, -- cuenta credito
                                                                   NULL, -- cod_mon_credito
                                                                   'A', -- autorizar
                                                                   mp.dato, -- documento credito
                                                                   mp.dato2, -- concepto
                                                                   nvl(mp.referencia, 0), --nro_contrato
                                                                   NULL,
                                                                   NULL,
                                                                   p_numeroDocumento);
              IF v_transferencia.error = 'S' THEN
                p_error                := v_transferencia.error;
                p_nombreRespuesta      := v_transferencia.nombreRespuesta;
                p_descripcionRespuesta := v_transferencia.descripcionRespuesta;
              ELSE
                v_retorno.numeroDocumento := v_transferencia.nroDocumento;
                p_numeroDoc               := v_transferencia.nroDocumento;
              END IF;
            END;
          ELSIF mp.cod_tip_mensaje = '214' THEN
            -- transferencias con contrato de cambio
            DECLARE
              v_transferencia typ_transferencia_hb;
            BEGIN
              IF v_transferencia.error = 'S' THEN
                p_error                := v_transferencia.error;
                p_nombreRespuesta      := v_transferencia.nombreRespuesta;
                p_descripcionRespuesta := v_transferencia.descripcionRespuesta;
              ELSE
                v_retorno.numeroDocumento := v_transferencia.nroDocumento;
                p_numeroDoc               := v_transferencia.nroDocumento;
              END IF;
            END;
          ELSIF mp.cod_tip_mensaje = '070' THEN
            begin 
              prg_ins_log_pagsalarios(v_usu_sesion.codigoEmpresa,p_sesion,mp.nro_documento,'INFO', 
              substr('INICIO PAGO SAL. COD_PERSONA: ' ||v_usu_sesion.codigoPersona 
              || 'LUGAR: ' || fu_generarUbicacion ,1,4000)); 
            exception 
              when others then 
                null; 
            end;
            -- pago de salarios
            declare
              v_est_proceso ba_modulos.estado%type;
            begin
              --Recuperamos el estado del modulo
              v_est_proceso := pae_cnf.fu_obt_est_modulo(pae_cnf.g_cod_modulo);

              if nvl(v_est_proceso, 2) <> 2 and nvl(PAE_CNF.G_PROGRAMA, 'x') <> 'GPPROFIN' then
                paw_uti.pr_mensajeUsuario(MSG_MOD_CERRADO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                paw_uti.pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                            v_msj_bitacora || ' ' || fu_generarbitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta),
                                            paw_uti.BITACORA_ERROR);
                RETURN;
              end if;
            end;
            IF v_tip_pro_sueldo = 'O' THEN
              declare
                  v_ini date; 
                  v_fin date;
              BEGIN
                v_ini := sysdate; 
                PAG_SUE.PR_INS_GE_PAG_SUELDO(v_verificacion_ok,
                                             mp.dato,
                                             mp.nro_cuenta,
                                             v_cod_tra_padre,
                                             nvl(to_date(mp.dato2, 'DD/MM/YYYY'), v_fec_actual),
                                             v_lugar,
                                             v_cant_error,
                                             v_TCreCab,
                                             v_TCreDet,
                                             v_TDebDet,
                                             v_cCreDet,
                                             mp.referencia,
                                             user,
                                             nvl(to_date(mp.dato2, 'DD/MM/YYYY'), v_fec_actual), 
                                             mp.tip_pago);
                v_fin := sysdate;
                BEGIN 
                 prg_ins_log_pagsalarios(v_usu_sesion.codigoEmpresa,p_sesion,mp.nro_documento,'INFO', 
                 substr('PAG_SUE.PR_INS_GE_PAG_SUELDO ' ||TO_CHAR(v_ini, 'DD/MM/YYYY HH24:MI:SS') ||' - ' ||TO_CHAR(v_fin, 'DD/MM/YYYY HH24:MI:SS') || 
                 ' DURACION: ' ||TO_CHAR(trunc((v_fin - v_ini) * 24 * 60 * 60)) ||' segundos LUGAR: ' || 
                 fu_generarUbicacion, 1, 4000)); 
                exception 
                  when others then 
                   null; 
                end;
                v_pag_sue_mensaje := REGEXP_SUBSTR(v_lugar, '[^|]+', 1, 2);
                  
                if ( INSTR(v_pag_sue_mensaje, MSG_ERROR_CTACRE) > 0)then
                    pr_mensajeusuario(PRO_ERR_SUE_CRE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                    p_descripcionRespuesta := v_pag_sue_mensaje;
                    pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                    ROLLBACK;
                    return;
                end if;
              EXCEPTION
                WHEN OTHERS THEN
                  dbms_output.put_line('Error en PR_INS_GE_PAG_SUELDO ' || sqlerrm);
                  p_error                := 'S';
                  p_nombreRespuesta      := 'PRO_AUT_ING_PAG_SUE';
                  p_descripcionRespuesta := substr('PRO_AUT_ING_PAG_SUE - ' || sqlerrm, 1, 200);
                  pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                  ROLLBACK;
                  return;
              END;

              IF NVL(v_Cant_Error, 0) <> 0 THEN
                SELECT SUM(monto)
                  INTO v_monto
                  FROM ge_pag_sueldos_tmp
                 WHERE cod_ente = mp.dato
                   AND usu_insercion = v_msj_caja.codigoUsuario
                   AND trunc(fec_insercion) = v_fec_actual
                   AND tipo = 'C'
                   AND nro_archivo = mp.referencia;
                   
                -- verificamos si el ente puede procesar pagos con error
                IF NVL(v_monto, 0) <> NVL(v_TDebDet, 0) AND
                   v_pro_con_errores = 'C' THEN
                   
                  pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                  pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                END IF;
              END IF;
              IF p_error = 'N' THEN
                declare
                 v_ini date;
                 v_fin date;
                BEGIN
                  v_secuencia := mp.referencia;
                  v_ini := sysdate; 
                  PAG_Sue.LP_INS_TABLA(mp.dato,
                                       v_lugar,
                                       v_secuencia,
                                       v_error,
                                       mp.referencia,
                                       user,
                                       nvl(to_date(mp.dato2, 'DD/MM/YYYY'), v_fec_actual),
                                       nvl(to_date(mp.dato2, 'DD/MM/YYYY'), v_fec_actual),
                                       'N');
                  v_fin := sysdate;
                  begin 
                     prg_ins_log_pagsalarios(v_usu_sesion.codigoEmpresa,p_sesion,mp.nro_documento,'INFO', 
                                             substr('PAG_Sue.LP_INS_TABLA ' ||TO_CHAR(v_ini, 'DD/MM/YYYY HH24:MI:SS') ||' - ' ||TO_CHAR(v_fin, 'DD/MM/YYYY HH24:MI:SS') || 
                                                    '  DURACION: ' ||TO_CHAR(trunc((v_fin - v_ini) * 24 * 60 * 60)) ||' segundos LUGAR: ' || 
                                                    fu_generarUbicacion, 1, 4000)); 
                 exception 
                     when others then 
                         null; 
                 end;
                EXCEPTION
                  WHEN OTHERS THEN
                   ROLLBACK;
                    p_error                := 'S';
                    p_nombreRespuesta      := 'PRO_AUT_DAT_SAL';
                    p_descripcionRespuesta := substr('PRO_AUT_DAT_SAL - ' || sqlerrm, 1, 200);
                    pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                    return;
                END;
              
                IF nvl(v_error, 'N') IN ('X', 'S') THEN
                  pr_mensajeusuario(PRO_AUT_ERR_INS_DAT_SALARIO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                  v_msj_bitacora := v_msj_bitacora || ', lugar: [' || substr(v_lugar, 1, 200) || ']';
                  pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                ELSE
                  v_nro_secuencia := 0;
                  pag_cta.PR_SET_VARIABLES(v_msj_caja.codigoUsuario,
                                           v_fec_actual,
                                           v_cod_tra_padre,
                                           'N',
                                           'N',
                                           v_nro_secuencia,
                                           NULL,
                                           v_msj_caja.codigoOficinaOrigen,
                                           3,
                                           31);
                  v_secuencia := mp.referencia; 
                  -- se puede hacer el credito
                  declare
                    v_nro_movimiento bw_movimientos.nro_movimiento%type;
                    v_ini date;
                    v_fin date;
                  BEGIN
                    begin
                      select c.nro_movimiento
                        into v_nro_movimiento
                        from bw_movimientos c
                       where c.nro_doc_pendiente = p_numeroDocumento;
                    exception
                      when others then
                        v_nro_movimiento := v_secuencia;
                    end;
                    v_ini := sysdate;
                    PAG_SUE.PR_ACT_CRED_EMPLEADO(v_Reprocesa,
                                                 mp.dato,
                                                 v_secuencia,
                                                 v_msj_caja.codigoOficinaOrigen,
                                                 nvl(to_date(mp.dato2, 'DD/MM/YYYY'), v_fec_actual),
                                                 v_msj_caja.codigoUsuario,
                                                 v_lugar,
                                                 v_error,
                                                 mp.tip_pago,
                                                 null,
                                                 null,
                                                 v_nro_movimiento);
                    v_fin := sysdate;
                    begin 
                         prg_ins_log_pagsalarios(v_usu_sesion.codigoEmpresa,p_sesion,mp.nro_documento,'INFO', 
                                                 substr('PAG_SUE.PR_ACT_CRED_EMPLEADO ' ||TO_CHAR(v_ini, 'DD/MM/YYYY HH24:MI:SS') ||' - ' ||TO_CHAR(v_fin, 'DD/MM/YYYY HH24:MI:SS') || 
                                                        '  DURACION: ' ||TO_CHAR(trunc((v_fin - v_ini) * 24 * 60 * 60)) ||' segundos  LUGAR: ' || 
                                                        fu_generarUbicacion, 1, 4000)); 
                     exception 
                         when others then 
                             null; 
                     end; 
                    IF nvl(v_error, 'N') != 'N' THEN
                      p_error                := 'S';
                      p_nombreRespuesta      := 'ERR_ACRE_SAL';
                      p_descripcionRespuesta := 'Lugar ' || v_lugar;
                      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                          ', pr_pro_pag_snp:[' || SUBSTR(v_error, 1, 400) || ']' || ' ' || 
                                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                    ROLLBACK;
                    return;
                    END IF;
                  EXCEPTION
                    WHEN OTHERS THEN
                      ROLLBACK;
                      p_error                := 'S';
                      p_nombreRespuesta      := 'PRO_AUT_ACR_SAL';
                      p_descripcionRespuesta := substr('Error al acreditar salario ' || SQLERRM, 1, 200);
                      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                      return;
                  END;
                END IF;
              ELSE
                -- hubo error en la verificacion
                pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
              END IF;
            ELSE
              v_nro_secuencia := mp.referencia;
              BEGIN
                INSERT INTO ge_pag_sue_lotes
                  (cod_ente,
                   fec_proceso,
                   nro_secuencia,
                   nro_cta_debito,
                   mto_credito,
                   mto_debito,
                   cod_moneda,
                   cantidad,
                   estado,
                   tip_pago,
                   tip_ingreso,
                   tip_proceso)
                VALUES
                  (mp.dato,
                   TO_DATE(mp.dato2, 'DD/MM/YYYY'),
                   v_nro_secuencia,
                   mp.nro_cuenta,
                   mp.monto,
                   mp.monto,
                   mp.cod_moneda,
                   mp.cantidad,
                   'P',
                   mp.tip_pago,
                   'H',
                   v_tip_pro_sueldo);
              
                -- si la ultima autorizacion se realiza en la fecha de pago llamamos al procedimiento que ejecuta el pago en lotes
                -- con el parametro del ente, para que se realice el pago 'online'
                IF TRUNC(SYSDATE) = TRUNC(TO_DATE(mp.dato2, 'DD/MM/YYYY')) AND TRUNC(SYSDATE) > TRUNC(mp.fec_insercion) THEN
                  pag_sue.pr_pag_sue_lotes('B', mp.dato, mp.referencia);
                END IF;
              EXCEPTION
                WHEN OTHERS THEN
                  pr_mensajeusuario(PRO_AUT_ERR_SAL_LOTES, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                  v_error        := 'S';
                  v_msj_bitacora := v_msj_bitacora || ', ORA-ERR: [' || substr(SQLERRM, 1, 200) || ']';
                  pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                      v_msj_bitacora || ', det-err: [' || substr(v_retorno.detalles.descripcionError, 1, 200) || ']' ||
                                      fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
              END;
            END IF;
            IF nvl(v_error, 'N') IN ('X', 'S') THEN
              IF p_error = 'N' THEN
                pr_mensajeusuario(PRO_AUT_ERR_PAG_SALARIO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
              END IF;
            END IF;
          ELSIF mp.cod_tip_mensaje = '075' THEN
            -- pago a proveedores
            DECLARE
              v_fec_pago1   date := trunc(sysdate);
              v_cam_fecha   BOOLEAN := FALSE;
              v_cantidad    NUMBER;
              v_nro_archivo NUMBER := mp.referencia;
            BEGIN
              v_msj_bitacora := v_msj_bitacora || ', fecPag:' || v_fec_pago1 || ', codEnt:' || mp.dato;
              pag_prv.PR_VER_DAT_TMP_DEV(mp.dato,
                                         v_fec_pago1,
                                         NULL,
                                         v_error,
                                         'S',
                                         mp.nro_documento,
                                         mp.nro_cuenta,
                                         v_nro_archivo,
                                         mp.fec_insercion);
              IF v_error IS NOT NULL THEN
                IF instr(v_error, 'Horario SIPAP Cerrado') > 0 THEN
                  pr_mensajeUsuario(PRO_ERR_SIPAP, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                ELSE
                  pr_mensajeusuario(PRO_AUT_ERR_DAT_PROVEEDORES, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                END IF;
                v_msj_bitacora := v_msj_bitacora || ', PRV-ERR:[' || SUBSTR(v_error, 1, 150) || ']';
              ELSE
                declare
                  v_nro_movimiento bw_movimientos.nro_movimiento%type;
                BEGIN
                  begin
                    select c.nro_movimiento
                      into v_nro_movimiento
                      from bw_movimientos c
                     where c.nro_doc_pendiente = p_numeroDocumento;
                  exception
                    when others then
                      v_nro_movimiento := v_nro_archivo;
                  end;
                  v_des_ente := fue_obt_nom_ente(mp.dato);
                  IF v_fec_pago1 = trunc(SYSDATE) THEN
                    pag_prv.PR_PRO_PAGO_DEV(to_number(mp.dato), mp.nro_documento, v_nro_movimiento, v_err_pago);
                    IF v_err_pago <> '00' THEN
                      if ( INSTR(v_err_pago, MSG_ERROR_CTACRE) > 0)then
                        pr_mensajeusuario(PRO_ERR_PRO_CRE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                        p_descripcionRespuesta := v_err_pago;
                        PRG_INS_LOG_MOVPENDIENTES(mp.nro_documento,
                                                           v_err_pago,
                                                           v_usu_sesion.codigoPersona);
                      else
                        pr_mensajeusuario(PRO_AUT_ERR_PAG_PROVEEDORES, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                      end if; 

                    ELSE
                      --Proyecto pago a proveedores
                      v_cam_fecha := FALSE;
                    END IF;
                  ELSE
                    v_cantidad := pag_prv.fu_obt_can_ope_cambio(mp.dato, v_fec_pago1, mp.cod_moneda, v_nro_archivo);
                    IF v_cantidad > 0 THEN
                      -- hora cerrada no permite operacion de cambio
                      pr_mensajeusuario(PRO_ERR_SIPAP, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                    ELSE
                      it_mail.mail(fug_obt_dir_correo,
                                   fug_obt_pardinamico('SUE_DIR_CORREO'),
                                   'Pago a Proveedores en Fecha Futura',
                                   'Pago a Proveedores ingresado por el HomeBanking ' ||
                                   chr(10) || chr(10) || 'Codigo  : ' ||
                                   mp.dato || chr(10) || 'Empresa : ' ||
                                   v_des_ente || chr(10) || 'Monto   : ' ||
                                   lf_for_money(mp.monto, 16) || chr(10) ||
                                   'Cantidad: ' || to_char(mp.cantidad) ||
                                   chr(10) || 'Fecha de Pago: ' ||
                                   to_char(v_fec_pago1, 'dd/mm/yyyy') ||
                                   chr(10) || chr(10) || 'Atentamente. ');
                    END IF;
                  END IF;
                  IF p_error = 'N' THEN
                    IF v_cam_fecha THEN
                      v_msj_bitacora := v_msj_bitacora || ', cam_hor_snp: ' || to_char(v_fec_pago1, 'dd/mm/yyyy');
                      -- posible cambio de nro_archivo por cambio de fecha de pago
                      IF v_nro_archivo <> mp.referencia THEN
                        UPDATE bw_mov_pendientes
                           SET referencia = v_nro_archivo
                         WHERE nro_documento = v_nro_documento
                           AND cod_per_principal = v_cod_per_empresa;
                      END IF;
                    END IF;
                    v_error     := NULL;
                    v_cod_error := NULL;
                    pag_prv.pr_pro_pag_snp_dev(mp.dato,
                                               user,
                                               v_cod_error,
                                               v_error,
                                               v_fec_pago1,
                                               v_nro_archivo,
                                               p_numeroDocumento);
                    IF v_error IS NOT NULL THEN
                      pr_mensajeusuario(PRO_AUT_ERR_PAG_PROVEE_INTE, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                      v_msj_bitacora := v_msj_bitacora || ', pr_pro_pag_snp:[' || SUBSTR(v_error, 1, 250) || ']';
                      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa,
                                          ', pr_pro_pag_snp:[' || SUBSTR(v_error, 1, 400) || ']' || ' ' || 
                                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
                    ELSE
                      IF v_fec_pago1 = TRUNC(SYSDATE) THEN
                        it_mail.mail(fug_obt_dir_correo,
                                     fug_obt_pardinamico('SUE_DIR_CORREO'),
                                     'Pago a Proveedores en Linea',
                                     'Pago a Proveedores ingresado por el HomeBanking ' ||
                                     chr(10) || chr(10) || 'Codigo  : ' ||
                                     mp.dato || chr(10) || 'Empresa : ' ||
                                     v_des_ente || chr(10) || 'Monto   : ' ||
                                     lf_for_money(mp.monto, 16) || chr(10) ||
                                     'Cantidad: ' || to_char(mp.cantidad) ||
                                     chr(10) || 'Fecha de Pago: ' ||
                                     to_char(v_fec_pago1, 'dd/mm/yyyy') ||
                                     chr(10) || chr(10) || 'Atentamente. ');
                      END IF;
                    END IF;
                  END IF;
                  -- CR actualizamos el cambio de fecha en la tabla de movimientos pendientes
                  IF v_cam_fecha = TRUE AND p_error = 'N' THEN
                    paw_bce.pr_act_fec_pag_pendiente(v_nro_documento, v_cod_per_empresa,
                                                     to_char(v_fec_pago1, 'dd/mm/yyyy') || ' ' || substr(mp.dato2, 12, 10));
                    v_msj_bitacora := v_msj_bitacora || ', fecNue:' || v_fec_pago1;
                  END IF;
                
                  IF p_error = 'N' THEN
                    pag_prv.PR_ELI_PROV_TMP_dev(mp.dato, mp.fec_insercion, v_nro_archivo);
                    pag_prv.PR_ELI_FAC_TMP_dev(mp.dato, mp.fec_insercion, v_nro_archivo);
                  END IF;
                EXCEPTION
                  WHEN OTHERS THEN
                    v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || ']';
                    pr_mensajeusuario(PRO_AUT_ERR_PAG_PROVEEDORES, p_nombreRespuesta, p_descripcionRespuesta, p_error);
                END;
              END IF;
            END;
          END IF;
        END IF;
        -- fin de la confirmacion de operaciones
      ELSIF v_modo = 'R' AND p_error = 'N' THEN
        -- si no hubo errores, elimino los temporales
        IF mp.cod_tip_mensaje = '036' THEN
          BEGIN
            UPDATE ge_snp_transferencias gs
               SET gs.estado = 'C', gs.situacion = 'C'
             WHERE gs.nro_referencia = mp.nro_ope_relacionada;
          EXCEPTION
            WHEN OTHERS THEN
              pr_mensajeusuario(PRO_AUT_ERR_SNP_CANCELA, p_nombreRespuesta, p_descripcionRespuesta, p_error);
          END;
        ELSIF mp.cod_tip_mensaje = C_COD_OPERACION THEN
          --SPI FASE 2
          BEGIN
            select tr.nro_referencia
              into v_nro_referencia
              from ge_spi_solicitudes sl
              join ge_snp_transferencias tr
                on sl.nro_referencia = tr.nro_referencia
             where sl.cod_sol_spi = mp.nro_ope_relacionada;
          
            UPDATE ge_snp_transferencias gs
               SET gs.estado    = 'C',
                   gs.situacion = 'C',
                   gs.error     = substr(v_comentario, 1, 4000)
             WHERE gs.nro_referencia = v_nro_referencia;
          
            update ge_spi_solicitudes sl
               set sl.est_solicitud = 'C',
                   sl.respuesta     = substr(v_comentario, 1, 2000)
             where sl.cod_sol_spi = mp.nro_ope_relacionada;
          
          EXCEPTION
            WHEN OTHERS THEN
              pr_mensajeusuario(PRO_AUT_ERR_SNP_CANCELA, p_nombreRespuesta, p_descripcionRespuesta, p_error);
          END;
        ELSIF mp.cod_tip_mensaje = '075' THEN
          -- borro los movimientos pendientes
          pag_prv.PR_ELI_PROV_TMP_DEV(mp.dato, mp.fec_insercion, mp.referencia);
          pag_prv.PR_ELI_FAC_TMP_DEV(mp.dato, mp.fec_insercion, mp.referencia);
        END IF;
      
        -- actualizo a anulada/eliminada la operacion pendiente
        UPDATE bw_mov_pendientes
           SET estado = decode(v_per_autorizador, 'S', 'A', 'B') 
         WHERE nro_documento = v_nro_documento
           AND cod_per_principal = v_cod_per_empresa;
        -- si no hubo errores
        IF p_error = 'N' THEN
          BEGIN
            -- inserto el movimiento por la anulacion
            INSERT INTO bw_autorizaciones
              (cod_persona, nro_documento, fec_hora, accion, observacion)
            VALUES
              (v_usu_sesion.codigoPersona, v_nro_documento, SYSDATE, decode(v_per_autorizador, 'S', 'R', 'B'), v_comentario);
          EXCEPTION
            WHEN dup_val_on_index THEN
              pr_mensajeusuario(PRO_AUT_PED_DUPLICADO, p_nombreRespuesta, p_descripcionRespuesta, p_error);
          END;
        END IF;
        -- fin de la anulacion
      END IF;
    END IF;
  
    IF p_error = 'N' THEN
      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_SALIDA);
    ELSE
      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
        -- Vuelta atras pendientes y autorizadores
        rollback to mov_pendiente;
    END IF;
  
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR, p_nombreRespuesta, p_descripcionRespuesta, p_error);
      pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora || ', ORA-ERR:[' ||
                          SUBSTR(SQLERRM, 1, 200) || '] ' || fu_generarBitacora(p_error, p_nombreRespuesta, p_descripcionRespuesta), BITACORA_ERROR);
        -- Vuelta atras pendientes y autorizadores
        rollback to mov_pendiente;
      RETURN;
  end;
  ------------------------------------------------------------------------------------
BEGIN
  pre_cam_for_numerico('.,');
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 9;
END paw_aut;
/
