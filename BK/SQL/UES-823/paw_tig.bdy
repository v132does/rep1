CREATE OR REPLACE PACKAGE BODY IT.paw_tig IS

  v_tip_mensaje        VARCHAR2(10);
  v_can_aut_requeridas NUMBER(5) := 0;
  g_aut_operacion      BOOLEAN := FALSE;
  MSG_OK           CONSTANT VARCHAR2(30) := 'OP_APROBADA';
  MSG_ERROR        CONSTANT VARCHAR2(30) := 'OP_ERROR';
  BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
  BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
  BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';
  CUENTA_TAMANO    CONSTANT NUMBER(3) := 18;

  /**Estructura interna para verIFicar el estado de la caja*/
  TYPE typ_mensajeCaja IS RECORD(
    error                VARCHAR2(1),
    nombreRespuesta      VARCHAR2(15),
    descripcionRespuesta VARCHAR2(200),
    estadoCaja           VARCHAR2(1),
    tipoCaja             VARCHAR2(1),
    codigoOficinaOrigen  NUMBER(3),
    codigoUsuario        VARCHAR2(10),
    fechaUltimoCierre    DATE,
    fechaCierre          DATE);

  FUNCTION depurarAlfanumerico(p_string IN VARCHAR2, maxLength IN NUMBER)
    RETURN VARCHAR2 IS
  BEGIN
    RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:]])', ''),
                  1,
                  maxLength);
  END;

  FUNCTION lf_val_gen_ope_cierre RETURN VARCHAR2 IS
    v_genera    varchar2(1) := 'S'; -- 'S' Puede Generar Operaci�n. ('N' No Generar ninguna Operaci�n)
    v_nro_orden ge_par_dinamicos.val_parametro%type := Fug_Obt_Pardinamico('NRO_ORD_PROCESOS');
    /*NO se debe generar ningun tipo de movimientos cuando se esta corriENDo alguno de estos procesos */
  BEGIN
    Select distinct ('N')
      into v_genera
      from ge_procesos_det a
     where a.cod_proceso = 11
       and Instr(v_nro_orden, ',' || a.nro_orden || ',') > 0
       and a.hor_inicio is not null
       and a.hor_fin is null;
    return v_genera;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN v_genera;
  END;

  PROCEDURE pr_insertarBitacora(p_codigoPersona       IN VARCHAR2 DEFAULT null,
                                p_codigoCanal         IN VARCHAR2 DEFAULT null,
                                p_codSesion           IN VARCHAR2 DEFAULT null,
                                p_tipoMensaje         IN VARCHAR2 DEFAULT null,
                                p_codigoEmpresa       IN VARCHAR2 DEFAULT null,
                                p_datos               IN VARCHAR2 DEFAULT null,
                                p_tipo                IN VARCHAR2 DEFAULT null,
                                p_numeroTelefono      IN VARCHAR2 DEFAULT null,
                                p_codigoError         IN VARCHAR2 DEFAULT null,
                                p_observacion         IN VARCHAR2 DEFAULT null,
                                p_codigoMotivo        IN VARCHAR2 DEFAULT null,
                                p_numeroCuentaDebito  IN VARCHAR2 DEFAULT null,
                                p_numeroCuentaCredito IN VARCHAR2 DEFAULT null,
                                p_monto               IN NUMBER DEFAULT null,
                                p_codigoMoneda        IN VARCHAR2 DEFAULT null,
                                p_dato2               IN CLOB DEFAULT null) IS
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

    IF p_tipo = BITACORA_ERROR and p_observacion is not null THEN
      insert into bw_log_incidencias
        (nro_telefono,
         cod_error,
         usu_insercion,
         fec_insercion,
         observacion,
         nro_caja,
         cod_tip_mensaje,
         cod_persona,
         nro_cta_debito,
         nro_cta_credito,
         monto,
         cod_moneda,
         cod_motivo)
      values
        (p_numeroTelefono,
         p_codigoError,
         user,
         sysdate,
         p_observacion,
         p_codigoCanal,
         p_tipoMensaje,
         p_codigoPersona,
         p_numeroCuentaDebito,
         p_numeroCuentaCredito,
         p_monto,
         p_codigoMoneda,
         p_codigoMotivo);
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      null;
  END;

  FUNCTION fu_generarBitacora(error                in varchar2,
                              nombreRespuesta      in varchar2,
                              descripcionRespuesta in varchar2,
                              mensajesAdicionales  in varchar2 := null)
    RETURN VARCHAR2 IS
    v_linea    VARCHAR2(1000);
    v_paquete  VARCHAR2(1000);
    v_llamador VARCHAR2(1000);
    v_duenho   VARCHAR2(1000);
  BEGIN
    OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
    RETURN v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV',
                                                                                                        'SESSION_USER') || ' Ip:' || sys_context('USERENV',
                                                                                                                                                 'IP_ADDRESS') || ' isDBA:' || sys_context('USERENV',
                                                                                                                                                                                           'ISDBA') || ' Error:' ||(CASE
                                                                                                                                                                                                                    error WHEN 'S' THEN 'T' WHEN 'N' THEN 'F' END) || ' nombreRespuesta:' || nombreRespuesta || ' descripcionRespuesta:' || descripcionRespuesta;
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
        descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado - [' ||
                              mensaje || ']';
      WHEN OTHERS THEN
        descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado - [' ||
                              mensaje || ']';
    END;
    error := v_error;
  END;

  FUNCTION lf_obt_permisos(p_sesion        IN typ_validarSesion,
                           p_cod_operacion IN VARCHAR2)
    RETURN typ_permisotigo IS
    v_retorno      typ_permisotigo := typ_permisotigo();
    v_consulta     VARCHAR(5);
    v_registra     VARCHAR(5);
    v_autoriza     VARCHAR(5);
    p_cod_persona  ba_personas.cod_persona%TYPE := nvl(p_sesion.codigoEmpresa,
                                                       p_sesion.codigoPersona);
    p_cod_perfil   bw_perfiles.cod_perfil%TYPE := p_sesion.codigoPerfil;
    p_nro_terminal cj_cajas.nro_caja%TYPE := p_sesion.codigoCanal;
    MSG_OP_NO_PERMITIDA CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';
    MSG_OP_INEXISTENTE  CONSTANT VARCHAR2(15) := 'PER_OPE_INVALID';

  BEGIN
    SELECT TRIM(decode(consulta, 'S', 'C', '') ||
                decode(ingresa, 'S', 'I', '') ||
                decode(autoriza, 'S', 'A', ''))
      INTO v_tip_mensaje
      FROM bw_tip_mensajes
     WHERE cod_tip_mensaje = p_cod_operacion;

    BEGIN
      pr_mensajeUsuario(MSG_OK,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);

      -- busco primero especIFico para la empresa
      SELECT decode(consulta, 'S', 'TRUE', 'FALSE'),
             decode(ingresa, 'S', 'TRUE', 'FALSE'),
             decode(autoriza, 'S', 'TRUE', 'FALSE'),
             nvl(can_firmas, 0)
        INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
        FROM bw_rol_permisos
       WHERE cod_perfil = p_cod_perfil
         AND cod_tip_mensaje = p_cod_operacion
         AND cod_persona = p_cod_persona;
    EXCEPTION
      WHEN no_data_found THEN
        -- busco los permisos generales para el perfil
        SELECT decode(consulta, 'S', 'TRUE', 'FALSE'),
               decode(ingresa, 'S', 'TRUE', 'FALSE'),
               decode(autoriza, 'S', 'TRUE', 'FALSE'),
               nvl(can_firmas, 0)
          INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
          FROM bw_rol_permisos
         WHERE cod_perfil = p_cod_perfil
           AND cod_tip_mensaje = p_cod_operacion
           AND cod_persona IS null;
    END;
    IF v_can_aut_requeridas > 0 AND
       paw_bce.fu_caj_homebanking(p_nro_terminal) = 'N' THEN
      -- operacion no permitida en autoservicios por requerir autorizacion
      pr_mensajeUsuario(MSG_OP_NO_PERMITIDA,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);
    END IF;

    v_autoriza := 'TRUE';
    v_consulta := 'TRUE';
    v_registra := 'TRUE';

    v_retorno.autoriza                 := v_autoriza;
    v_retorno.consulta                 := v_consulta;
    v_retorno.registra                 := v_registra;
    v_retorno.autorizacionesRequeridas := v_can_aut_requeridas;
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_OP_INEXISTENTE,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);
      RETURN v_retorno;
  END;

  FUNCTION lf_val_caja(p_sesion IN typ_validarSesion) RETURN typ_mensajeCaja IS
    c_msg_caj_prohibida     constant varchar2(15) := '236';
    c_msg_est_caj_invalida  constant varchar2(15) := '237';
    c_msg_caj_no_encontrada constant varchar2(15) := '235';
    -- VerIFico la situacion del numero de caja
    v_est_caja       cj_cajas.estado%type;
    v_tip_caja       cj_cajas.tipo%type;
    v_cod_ofi_origen cj_cajas.cod_oficina%type;
    v_cod_usuario    cj_cajas.cod_usuario%type;
    v_ult_cierre     cj_cajas.fec_hor_cierre%type;
    v_fec_cie_caja   cj_cajas.fec_cierre%type;
    v_retorno        typ_mensajeCaja;

  BEGIN
    pr_mensajeUsuario(MSG_OK,
                      v_retorno.nombreRespuesta,
                      v_retorno.descripcionRespuesta,
                      v_retorno.error);

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
      pr_mensajeUsuario(c_msg_caj_prohibida,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);
    END IF;
    IF v_est_caja <> 'A' THEN
      pr_mensajeUsuario(c_msg_est_caj_invalida,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);
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
      pr_mensajeUsuario(c_msg_caj_no_encontrada,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);
      RETURN v_retorno;
  END;

  FUNCTION fu_validarSesion(p_sesionUsuario IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_validar       IN VARCHAR DEFAULT 'S')
    RETURN typ_validarSesion IS
    PRAGMA AUTONOMOUS_TRANSACTION;

    MSG_AUTH_ERROR  CONSTANT VARCHAR2(15) := 'L_AUTH_ERROR';
    MSG_CAM_CLA_NUE CONSTANT VARCHAR2(15) := 'L_CAM_CLAVE_NUE';
    MSG_CAM_CLA_EXP CONSTANT VARCHAR2(15) := 'L_CAM_CLAVE_EXP';
    MSG_TK_EXPIRADO CONSTANT VARCHAR2(15) := 'L_SESSION_EXP';

    FECHA_HORA_ACTUAL             CONSTANT DATE := SYSDATE;
    MAX_TIEMPO_INACTIVIDAD_SESION CONSTANT NUMBER(3) := to_number(nvl(fug_obt_pardinamico('NUE_SESION_HB'),
                                                                      30));
    COD_OPERACION                 CONSTANT VARCHAR2(5) := '005';

    v_ultimoAcceso DATE;
    v_sesion       VARCHAR2(32);
    v_retorno      typ_validarSesion := typ_validarSesion();
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

    IF (p_codCanal IS null OR v_sesion IS null OR length(p_codCanal) = 0 OR
       length(v_sesion) = 0) THEN
      pr_mensajeUsuario(MSG_AUTH_ERROR,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);
      pr_insertarBitacora(v_sesion,
                          p_codCanal,
                          null,
                          COD_OPERACION,
                          null,
                          'fu_validarSesion- Error Canal ' ||
                          fu_generarBitacora(v_retorno.error,
                                             v_retorno.nombreRespuesta,
                                             v_retorno.descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
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
        FROM it.BW_AUT_SESIONES TK
       WHERE TK.cod_sesion = v_sesion;
    EXCEPTION
      WHEN no_data_found THEN
        pr_mensajeUsuario(MSG_AUTH_ERROR,
                          v_retorno.nombreRespuesta,
                          v_retorno.descripcionRespuesta,
                          v_retorno.error);
        pr_insertarBitacora('0',
                            p_codCanal,
                            v_sesion,
                            COD_OPERACION,
                            null,
                            'fu_validarSesion - Token inexistente-' ||
                            fu_generarBitacora(v_retorno.error,
                                               v_retorno.nombreRespuesta,
                                               v_retorno.descripcionRespuesta,
                                               null),
                            BITACORA_ERROR);
        RETURN v_retorno;
    END;

    -- AuthToken  NO corresponde al usuario y canal proveido?
    IF (v_retorno.codigoCanal <> p_codCanal) THEN
      DELETE FROM BW_AUT_SESIONES WHERE cod_sesion = p_sesionUsuario;
      COMMIT;

      pr_mensajeUsuario(MSG_AUTH_ERROR,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);

      pr_insertarBitacora('0',
                          p_codCanal,
                          p_sesionUsuario,
                          COD_OPERACION,
                          null,
                          'fu_validarSesion - Token no corresponde a canal-' ||
                          fu_generarBitacora(v_retorno.error,
                                             v_retorno.nombreRespuesta,
                                             v_retorno.descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN v_retorno;
    END IF;

    IF ((FECHA_HORA_ACTUAL - v_ultimoAcceso) * 1440) >
       MAX_TIEMPO_INACTIVIDAD_SESION THEN

      DELETE FROM BW_AUT_SESIONES WHERE cod_sesion = p_sesionUsuario;
      COMMIT;
      pr_mensajeUsuario(MSG_TK_EXPIRADO,
                        v_retorno.nombreRespuesta,
                        v_retorno.descripcionRespuesta,
                        v_retorno.error);

      pr_insertarBitacora('0',
                          p_codCanal,
                          p_sesionUsuario,
                          COD_OPERACION,
                          v_retorno.codigoEmpresa,
                          'fu_validarSesion Token expirado-' ||
                          fu_generarBitacora(v_retorno.error,
                                             v_retorno.nombreRespuesta,
                                             v_retorno.descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN v_retorno;
    END IF;

    --Validamos si la clave de acceso es nueva o ha expirado
    IF p_validar = 'S' THEN
      IF paw_seg.fu_ver_ctr_clave('A') = 'S' THEN
        DECLARE
          v_est_clave bw_ope_claves.est_clave%type;
        BEGIN
          SELECT est_clave
            INTO v_est_clave
            FROM bw_ope_claves
           WHERE cod_persona = v_retorno.codigoPersona
             AND tip_clave = 'A'
             AND ((v_retorno.codigoEmpresa IS null AND
                 cod_per_vinculada IS null) OR
                 (v_retorno.codigoEmpresa IS NOT null AND
                 cod_per_vinculada = v_retorno.codigoEmpresa));
          IF v_est_clave <> 'M' THEN
            IF v_est_clave = 'A' THEN
              pr_mensajeUsuario(MSG_CAM_CLA_EXP,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
              pr_insertarBitacora(v_sesion,
                                  p_codCanal,
                                  p_sesionUsuario,
                                  COD_OPERACION,
                                  v_retorno.codigoEmpresa,
                                  'fu_validarSesion - Clave acceso expirada ' ||
                                  fu_generarBitacora(v_retorno.error,
                                                     v_retorno.nombreRespuesta,
                                                     v_retorno.descripcionRespuesta,
                                                     null),
                                  BITACORA_ERROR);
            ELSIF v_est_clave IN ('N', 'P') THEN
              pr_mensajeUsuario(MSG_CAM_CLA_NUE,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
              pr_insertarBitacora(v_sesion,
                                  p_codCanal,
                                  p_sesionUsuario,
                                  COD_OPERACION,
                                  v_retorno.codigoEmpresa,
                                  'fu_validarSesion - Clave acceso expirada ' ||
                                  fu_generarBitacora(v_retorno.error,
                                                     v_retorno.nombreRespuesta,
                                                     v_retorno.descripcionRespuesta,
                                                     null),
                                  BITACORA_ERROR);
            ELSE
              pr_mensajeUsuario(MSG_AUTH_ERROR,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
              pr_insertarBitacora(v_sesion,
                                  p_codCanal,
                                  null,
                                  COD_OPERACION,
                                  null,
                                  'fu_validarSesion- Estado clave invalida ' ||
                                  fu_generarBitacora(v_retorno.error,
                                                     v_retorno.nombreRespuesta,
                                                     v_retorno.descripcionRespuesta,
                                                     null),
                                  BITACORA_ERROR);
            END IF;
            RETURN v_retorno;
          END IF;
        END;
      END IF;
    END IF;

    UPDATE BW_AUT_SESIONES
       SET fec_ult_actividad = FECHA_HORA_ACTUAL
     WHERE cod_sesion = p_sesionUsuario;
    COMMIT;
    pr_mensajeUsuario(MSG_OK,
                      v_retorno.nombreRespuesta,
                      v_retorno.descripcionRespuesta,
                      v_retorno.error);
    RETURN v_retorno;
  END;

  PROCEDURE lp_reg_operacion(p_nro_cuenta        IN VARCHAR2 DEFAULT null,
                             p_cod_moneda        IN VARCHAR2 DEFAULT null,
                             p_monto             IN NUMBER DEFAULT null,
                             p_nro_cta_contra    IN VARCHAR2 DEFAULT null,
                             p_cantidad          IN NUMBER DEFAULT null,
                             p_etiqueta          IN VARCHAR2 DEFAULT null,
                             p_dato              IN VARCHAR2 DEFAULT null,
                             p_etiqueta2         IN VARCHAR2 DEFAULT null,
                             p_dato2             IN VARCHAR2 DEFAULT null,
                             p_observacion       IN VARCHAR2 DEFAULT null,
                             p_dir_ip            IN VARCHAR2 DEFAULT null,
                             p_cod_respuesta     IN VARCHAR2 DEFAULT null,
                             p_cod_persona       IN VARCHAR2 DEFAULT null,
                             p_cod_operacion     IN VARCHAR2 DEFAULT null,
                             p_nro_operacion     IN VARCHAR2 DEFAULT null,
                             p_nro_terminal      IN VARCHAR2 DEFAULT null,
                             p_clave             IN VARCHAR2 DEFAULT null,
                             p_cod_per_empresa   IN VARCHAR2 DEFAULT null,
                             p_parametros        IN VARCHAR2 DEFAULT null,
                             p_etiqueta3         IN VARCHAR2 DEFAULT null,
                             p_dato3             IN VARCHAR2 DEFAULT null,
                             p_nro_doc_pendiente IN NUMBER default null,
                             p_nro_movimiento    IN NUMBER default null) IS
  BEGIN
    INSERT INTO bw_movimientos
      (nro_documento,
       cod_per_principal,
       cod_per_ingreso,
       clave,
       fec_hora,
       nro_caja,
       cod_tip_mensaje,
       dir_ip,
       cod_respuesta,
       observacion,
       nro_cuenta,
       cod_moneda,
       monto,
       nro_cta_contra,
       cantidad,
       etiqueta,
       dato,
       etiqueta2,
       dato2,
       parametros,
       etiqueta3,
       dato3,
       nro_doc_pendiente,
       nro_movimiento)
    VALUES
      (p_nro_operacion,
       nvl(p_cod_per_empresa, p_cod_persona),
       p_cod_persona,
       substr(p_clave, 1, 20),
       SYSDATE,
       p_nro_terminal,
       p_cod_operacion,
       p_dir_ip,
       p_cod_respuesta,
       p_observacion,
       substr(REPLACE(TRIM(p_nro_cuenta), chr(13), ''), 0, 15),
       p_cod_moneda,
       p_monto,
       substr(REPLACE(TRIM(p_nro_cta_contra), chr(13), ''), 0, 15),
       p_cantidad,
       p_etiqueta,
       p_dato,
       p_etiqueta2,
       p_dato2,
       substr(p_parametros, 1, 1000),
       p_etiqueta3,
       p_dato3,
       p_nro_doc_pendiente,
       p_nro_movimiento);

  EXCEPTION
    WHEN OTHERS THEN
      null;
  END;

  function fu_obt_mov_user(p_tip_user in ba_cod_referencias.abreviatura%type,
                           p_tip_sec  in varchar2) return varchar2 is
    v_nro_sec  number;
    v_can_user number;
    v_nro_user number;
    v_user     ba_usuarios.cod_usuario%type;

  BEGIN
    select count(*)
      into v_can_user
      from ba_cod_referencias
     where dominio = 'USU_MOV_SERVICIO'
       and abreviatura = p_tip_user;

    v_nro_sec  := fue_obt_sig_secuencia(p_tip_sec);
    v_nro_user := mod(v_nro_sec, v_can_user);
    v_user     := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO',
                                              v_nro_user,
                                              p_tip_user);
    return v_user;
  END;

  function fu_obt_hora(p_cod_usuario in varchar2, p_secuencia in varchar2)
    return varchar2 is
    v_hora        ge_movimientos.hora%type;
    v_nro_sec     number;
    v_nro_hor     number;
    v_ind_usuario number;

  BEGIN
    IF upper(substr(p_cod_usuario, -1)) = 'B' THEN
      v_ind_usuario := 0;
    ELSE
      v_ind_usuario := substr(p_cod_usuario, -1);
    END IF;

    IF v_ind_usuario > 0 THEN
      --v_nro_sec := fue_obt_sig_secuencia('s_hor_mov_in' || v_ind_usuario);
      v_nro_sec := fue_obt_sig_secuencia(p_secuencia || v_ind_usuario);
    elsIF v_ind_usuario = 0 THEN
      v_nro_sec := fue_obt_sig_secuencia(p_secuencia);
    END IF;

    v_nro_hor := mod(v_nro_sec, 86400);

    v_hora := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
              TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
              TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

    return v_hora;
  END;

  PROCEDURE pr_tigo_cash_in(p_sesion               IN VARCHAR2,
                            p_codCanal             IN VARCHAR2,
                            p_nroCtaDebito         IN VARCHAR2,
                            p_monto                IN NUMBER,
                            p_nrotelefono          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_nro_mov_pendiente    IN bw_mov_pendientes.nro_documento%type default null,
                            p_error                out VARCHAR2,
                            p_nombreRespuesta      out VARCHAR2,
                            p_descripcionRespuesta out VARCHAR2,
                            p_tipOperacion         out VARCHAR2,
                            p_nroDocumento         out NUMBER) IS

    TRT_SIN_PERMISO CONSTANT VARCHAR2(15) := 'TRT_SIN_PERMISO';
    v_nro_cta_debito   VARCHAR2(16);
    v_monto            NUMBER(18, 2);
    v_modo             VARCHAR2(1);
    v_cod_mon_credito  VARCHAR2(3);
    v_cod_mod_credito  NUMBER(4);
    v_cod_mad_credito  NUMBER(4);
    v_cod_ofi_credito  NUMBER(4);
    v_nro_documento    NUMBER(15);
    v_cod_operacion    VARCHAR2(3) := '301';
    v_nro_secuencia    NUMBER(3);
    v_mensajeCaja      typ_mensajeCaja;
    retValidarSesion   typ_validarSesion;
    v_permiso          typ_permisotigo;
    v_codigo_modulo    NUMBER(3) := 3;
    v_codigo_modalidad NUMBER(3) := 31;
    v_numero_secuencia NUMBER(3) := 0;
    v_cod_tra_padre    NUMBER(4) := 9835;
    v_cod_tra_deb      NUMBER(4);
    v_cod_tra_cre      NUMBER(4);
    v_cod_tra_com      NUMBER(4);
    v_usuario          ge_movimientos.cod_usuario%TYPE;
    v_hora             ge_movimientos.hora%TYPE;
    v_nro_movimiento   bw_movimientos.nro_movimiento%TYPE;
    v_fecha_actual     DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_cta_ope_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_OPE_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_cta_com_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_COM_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_comision         ge_movimientos.monto%type := it.fug_obt_pardinamico('MTO_COM_TIGO',
                                                                           null,
                                                                           null,
                                                                           null);
    v_msj_bitacora     VARCHAR2(1000) := substr('sesion: ' || p_sesion ||
                                                'ctaDebito: ' ||
                                                trim(p_nroCtaDebito) ||
                                                'monto: ' || p_monto ||
                                                'nroTelefono: ' ||
                                                p_nrotelefono || 'modo: ' ||
                                                p_modo ||
                                                'nroMovPendiente: ' ||
                                                p_nro_mov_pendiente || 1,
                                                200);
    ------------------------------------------------------------------------------------
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_oficina         ge_cuentas.cod_oficina%type;
    v_cod_moneda          ge_cuentas.cod_moneda%type;
    v_cod_ofi_credito_com ge_cuentas.cod_oficina%type;
    v_cod_mon_credito_com ge_cuentas.cod_moneda%type;
    v_cod_mod_credito_com ge_cuentas.cod_modulo%type;
    v_cod_mad_credito_com ge_cuentas.cod_modalidad%type;
    ------------------------------------------------------------------------------------
  BEGIN

    --valido la sesi�n del cliente
    retValidarSesion := fu_validarSesion(p_sesion, p_codCanal);
    IF retValidarSesion.error = 'S' THEN
      p_error                := retValidarSesion.error;
      p_nombreRespuesta      := retValidarSesion.nombreRespuesta;
      p_descripcionRespuesta := retValidarSesion.descripcionRespuesta;
      RETURN;
    END IF;
    -- validamos la caja
    v_mensajeCaja := lf_val_caja(retValidarSesion);
    IF v_mensajeCaja.error = 'S' THEN
      p_error                := v_mensajeCaja.error;
      p_nombreRespuesta      := v_mensajeCaja.nombreRespuesta;
      p_descripcionRespuesta := v_mensajeCaja.descripcionRespuesta;
      RETURN;
    END IF;

    v_permiso := lf_obt_permisos(retValidarSesion, v_cod_operacion);
    IF (v_permiso.error = 'S') THEN
      p_nombreRespuesta      := v_permiso.nombreRespuesta;
      p_descripcionRespuesta := v_permiso.descripcionRespuesta;
      p_error                := v_permiso.error;
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;
    -- se verifica que posea permiso para registrar
    IF v_permiso.registra = 'FALSE' AND instr(v_tip_mensaje, 'I') > 0 THEN
      pr_mensajeUsuario(TRT_SIN_PERMISO,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarbitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;

    v_mensajeCaja.codigoUsuario := fug_obt_user_sesion(p_sesion);
    v_modo                      := NVL(SUBSTR(p_modo, 0, 1), 'x');

    IF nvl(p_modo, 'x') = 'A' THEN
      IF g_aut_operacion = FALSE THEN
        p_error                := 'S';
        p_nombreRespuesta      := 'MOD_OPE_INVALIDA';
        p_descripcionRespuesta := 'Modo Operacion Invalida';
        RETURN;
      END IF;
    END IF;

    v_can_aut_requeridas := 1;

    pr_mensajeUsuario(MSG_OK,
                      p_nombreRespuesta,
                      p_descripcionRespuesta,
                      p_error);
    pr_insertarBitacora(retValidarSesion.codigoPersona,
                        p_codCanal,
                        p_sesion,
                        v_cod_operacion,
                        retValidarSesion.codigoEmpresa,
                        v_msj_bitacora || ' ' ||
                        fu_generarBitacora(p_error,
                                           p_nombreRespuesta,
                                           p_descripcionRespuesta,
                                           null),
                        BITACORA_ENTRADA);

    -- 0. inicializo la secuencia
    v_nro_secuencia  := 0;
    v_nro_cta_debito := depurarAlfanumerico(p_nroCtaDebito, CUENTA_TAMANO);
    v_monto          := p_monto;

    IF v_modo = 'C' AND v_can_aut_requeridas = 0 THEN
      v_modo := 'A'; -- CONFIRMACION
    END IF;

    -- 2. busco los datos de la cuentas
    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_nro_cta_debito);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_oficina   := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_moneda    := pag_cta.G_CTAS.cod_moneda;
        v_cod_modulo    := pag_cta.G_CTAS.COD_MODULO;
        v_cod_modalidad := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_deb := fug_obt_pardinamico('COD_TRA_DEB_TIGO',
                                             v_cod_modulo,
                                             v_cod_modalidad);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_ope_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_cre := fug_obt_pardinamico('COD_TRA_CRE_TIGO',
                                             v_cod_mod_credito,
                                             v_cod_mad_credito);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_com_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito_com := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito_com := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito_com := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito_com := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_com := fug_obt_pardinamico('COD_TRA_COM_TIGO',
                                             v_cod_mod_credito_com,
                                             v_cod_mad_credito_com);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta Comision';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      IF v_modo = 'C' THEN
        --- inserto el movimiento pendiente de autorizacion
        SELECT s_nro_documento.NEXTVAL INTO v_nro_documento FROM dual;
        BEGIN
          INSERT INTO bw_mov_pendientes
            (nro_documento,
             cod_per_principal,
             fec_hora,
             cod_tip_mensaje,
             nro_cuenta,
             cod_moneda,
             descripcion,
             monto,
             cotizacion,
             mto_equ_local,
             nro_cta_contra,
             estado,
             can_aut_requeridas,
             can_aut_faltantes,
             cod_per_ingreso,
             mto_contra,
             cot_contra,
             etiqueta,
             dato)
          VALUES
            (v_nro_documento,
             nvl(retValidarSesion.codigoEmpresa,
                 retValidarSesion.codigoPersona),
             SYSDATE,
             v_cod_operacion,
             v_nro_cta_debito,
             v_cod_moneda,
             'Tigo Cash In',
             v_monto,
             null,
             null,
             v_cta_ope_tigo,
             'P',
             v_can_aut_requeridas,
             v_can_aut_requeridas,
             retValidarSesion.codigoPersona,
             v_monto,
             null,
             'Nro. Telefono',
             p_nrotelefono);
        EXCEPTION
          WHEN OTHERS THEN
            p_error                := 'S';
            p_nombreRespuesta      := 'ERROR_INS_MOV_P';
            p_descripcionRespuesta := 'Error al Insertar Movimiento Pendiente ';
            pr_insertarBitacora(retValidarSesion.codigoPersona,
                                p_codCanal,
                                p_sesion,
                                v_cod_operacion,
                                retValidarSesion.codigoEmpresa,
                                'Error:' || ' ' || sqlerrm || ' ' ||
                                fu_generarBitacora(p_error,
                                                   p_nombreRespuesta,
                                                   p_descripcionRespuesta,
                                                   null),
                                BITACORA_SALIDA);
            RETURN;
        END;

        p_tipOperacion := v_cod_operacion;
        p_nroDocumento := v_nro_documento;

        RETURN;
      ELSIF v_modo = 'A' THEN
        --------------------------------------------------------------------------
        savepoint CashIn;
        ----------------------------------------------------------
        v_usuario := fu_obt_mov_user('TCASHIN', 's_hor_mov_in');
        v_hora    := fu_obt_hora(v_usuario, 's_hor_mov_in');
        pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                 p_fec_valor      => trunc(sysdate),
                                 p_cod_tra_padre  => v_cod_tra_padre,
                                 p_estado         => 'N',
                                 p_reversado      => 'N',
                                 p_nro_secuencia  => v_numero_secuencia,
                                 p_est_cuenta     => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre  => v_codigo_modulo,
                                 p_cod_mad_padre  => v_codigo_modalidad);
        ------------------------------------------------------------
        IF nvl(p_error, 'N') = 'N' THEN
          BEGIN
            v_nro_secuencia := v_nro_secuencia;
            PAG_CTA.PR_SET_REFERENCIA(p_nro_mov_pendiente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.PR_SET_NRO_DOCUMENTO3(v_cod_operacion);
            pag_cta.pr_act_operacion(v_nro_cta_debito,
                                     v_hora,
                                     'D',
                                     v_cod_moneda,
                                     p_monto,
                                     v_cod_tra_padre,
                                     v_cod_tra_deb,
                                     p_nro_mov_pendiente,
                                     null,
                                     v_cod_oficina,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Debito CashIn Tigo ' ||
                                     v_nro_cta_debito,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     null);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA.ERROR';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              pr_insertarBitacora(retValidarSesion.codigoPersona,
                                  p_codCanal,
                                  p_sesion,
                                  v_cod_operacion,
                                  retValidarSesion.codigoEmpresa,
                                  'Error:' || ' ' || sqlerrm || ' ' ||
                                  pag_cta.G_MSJ_ERROR || ' ' ||
                                  fu_generarBitacora(p_error,
                                                     p_nombreRespuesta,
                                                     p_descripcionRespuesta,
                                                     null),
                                  BITACORA_SALIDA);
              rollback to CashIn;
              -----------------------------------------------------------------------------------------------
            ELSE
              ----------------------------------------------------------
              pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                       p_fec_valor      => trunc(sysdate),
                                       p_cod_tra_padre  => v_cod_tra_padre,
                                       p_estado         => 'N',
                                       p_reversado      => 'N',
                                       p_nro_secuencia  => v_numero_secuencia,
                                       p_est_cuenta     => null,
                                       p_cod_ofi_origen => 61,
                                       p_cod_mod_padre  => v_codigo_modulo,
                                       p_cod_mad_padre  => v_codigo_modalidad);
              ------------------------------------------------------------
              --generar credito de comision en cta. operativa
              v_nro_secuencia := v_nro_secuencia;
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cta_com_tigo,
                                       v_hora,
                                       'C',
                                       v_cod_mon_credito_com,
                                       v_comision,
                                       v_cod_tra_padre,
                                       v_cod_tra_com,
                                       p_nro_mov_pendiente,
                                       null,
                                       v_cod_ofi_credito_com,
                                       v_codigo_modulo,
                                       v_codigo_modalidad,
                                       null,
                                       null,
                                       'Credito por comisiones CashIn Tigo ' ||
                                       v_cta_com_tigo,
                                       'N',
                                       v_nro_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       null);
              IF pag_cta.G_COD_ERROR != 0 THEN
                p_error                := 'S';
                p_nombreRespuesta      := 'PAG_CTA.ERROR';
                p_descripcionRespuesta := 'Error al Generar Movimiento';
                pr_insertarBitacora(retValidarSesion.codigoPersona,
                                    p_codCanal,
                                    p_sesion,
                                    v_cod_operacion,
                                    retValidarSesion.codigoEmpresa,
                                    'Error:' || ' ' || sqlerrm || ' ' ||
                                    pag_cta.G_MSJ_ERROR || ' ' ||
                                    fu_generarBitacora(p_error,
                                                       p_nombreRespuesta,
                                                       p_descripcionRespuesta,
                                                       null),
                                    BITACORA_SALIDA);
                rollback to CashIn;
                -----------------------------------------------------------------------------------------------
              END IF;
              ----------------------------------------------------------
              pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                       p_fec_valor      => trunc(sysdate),
                                       p_cod_tra_padre  => v_cod_tra_padre,
                                       p_estado         => 'N',
                                       p_reversado      => 'N',
                                       p_nro_secuencia  => v_numero_secuencia,
                                       p_est_cuenta     => null,
                                       p_cod_ofi_origen => 61,
                                       p_cod_mod_padre  => v_codigo_modulo,
                                       p_cod_mad_padre  => v_codigo_modalidad);
              ------------------------------------------------------------
              --generar credito en cta. cliente
              v_nro_secuencia := v_nro_secuencia;
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cta_ope_tigo,
                                       v_hora,
                                       'C',
                                       v_cod_mon_credito,
                                       p_monto,
                                       v_cod_tra_padre,
                                       v_cod_tra_cre,
                                       p_nro_mov_pendiente,
                                       null,
                                       v_cod_ofi_credito,
                                       v_codigo_modulo,
                                       v_codigo_modalidad,
                                       null,
                                       null,
                                       'Credito por CashIn Tigo ' ||
                                       v_cta_ope_tigo,
                                       'N',
                                       v_nro_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       null);
              IF pag_cta.G_COD_ERROR != 0 THEN
                p_error                := 'S';
                p_nombreRespuesta      := 'PAG_CTA.ERROR';
                p_descripcionRespuesta := 'Error al Generar Movimiento';
                pr_insertarBitacora(retValidarSesion.codigoPersona,
                                    p_codCanal,
                                    p_sesion,
                                    v_cod_operacion,
                                    retValidarSesion.codigoEmpresa,
                                    'Error:' || ' ' || sqlerrm || ' ' ||
                                    pag_cta.G_MSJ_ERROR || ' ' ||
                                    fu_generarBitacora(p_error,
                                                       p_nombreRespuesta,
                                                       p_descripcionRespuesta,
                                                       null),
                                    BITACORA_SALIDA);
                rollback to CashIn;
              END IF;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'ERROR PAG_CTA';
              p_descripcionRespuesta := 'Error el proceso ' || sqlerrm;
              rollback to CashIn;
          END;

        END IF;

        IF p_error = 'N' THEN
          select s_nro_bw_movimiento.nextval
            into v_nro_movimiento
            from dual;
          lp_reg_operacion(v_nro_cta_debito,
                           'GS',
                           p_monto,
                           v_cta_ope_tigo,
                           null,
                           'Nro. Telefono',
                           p_nrotelefono,
                           null,
                           null,
                           'Homebanking',
                           null,
                           null,
                           nvl(retValidarSesion.codigoEmpresa,
                               retValidarSesion.codigoPersona),
                           v_cod_operacion,
                           p_nro_mov_pendiente,
                           p_codCanal,
                           p_sesion,
                           nvl(retValidarSesion.codigoEmpresa,
                               retValidarSesion.codigoPersona),
                           null,
                           null,
                           null,
                           p_nro_mov_pendiente,
                           v_nro_movimiento);

          pr_insertarBitacora(nvl(retValidarSesion.codigoEmpresa,
                                  retValidarSesion.codigoPersona),
                              p_codCanal,
                              p_sesion,
                              v_cod_operacion,
                              nvl(retValidarSesion.codigoEmpresa,
                                  retValidarSesion.codigoPersona),
                              v_msj_bitacora || ' ' ||
                              fu_generarbitacora(p_error,
                                                 null,
                                                 p_descripcionRespuesta,
                                                 null),
                              BITACORA_SALIDA);
        END IF;
      END IF;
    END IF;

    IF p_error != 'N' THEN
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_SALIDA);
    END IF;
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ', ORA-ERR:[' ||
                          SUBSTR(SQLERRM, 1, 200) || '] ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
  END;

  PROCEDURE pr_tigo_cash_out(p_sesion               IN VARCHAR2,
                             p_codCanal             IN VARCHAR2,
                             p_nroCtaDebito         IN VARCHAR2,
                             p_monto                IN NUMBER,
                             p_nrotelefono          IN VARCHAR2,
                             p_modo                 IN VARCHAR2,
                             p_nro_mov_pendiente    IN bw_mov_pendientes.nro_documento%type default null,
                             p_error                out VARCHAR2,
                             p_nombreRespuesta      out VARCHAR2,
                             p_descripcionRespuesta out VARCHAR2,
                             p_tipOperacion         out VARCHAR2,
                             p_nroDocumento         out NUMBER) IS

    TRT_SIN_PERMISO CONSTANT VARCHAR2(15) := 'TRT_SIN_PERMISO';
    v_nro_cta_debito   VARCHAR2(16);
    v_monto            NUMBER(18, 2);
    v_modo             VARCHAR2(1);
    v_cod_mon_credito  VARCHAR2(3);
    v_cod_mod_credito  NUMBER(4);
    v_cod_mad_credito  NUMBER(4);
    v_cod_ofi_credito  NUMBER(4);
    v_nro_documento    NUMBER(15);
    v_cod_operacion    VARCHAR2(3) := '302';
    v_nro_secuencia    NUMBER(3);
    v_mensajeCaja      typ_mensajeCaja;
    retValidarSesion   typ_validarSesion;
    v_permiso          typ_permisotigo;
    v_codigo_modulo    NUMBER(3) := 3;
    v_codigo_modalidad NUMBER(3) := 31;
    v_numero_secuencia NUMBER(3) := 0;
    v_cod_tra_padre    NUMBER(4) := 9835;
    v_cod_tra_deb      NUMBER(4);
    v_cod_tra_cre      NUMBER(4);
    v_cod_tra_com      NUMBER(4);
    v_usuario          ge_movimientos.cod_usuario%type;
    v_hora             ge_movimientos.hora%TYPE;
    v_fecha_actual     DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_nro_movimiento   bw_movimientos.nro_movimiento%type;
    v_cta_ope_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_OPE_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_cta_com_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_COM_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_comision         ge_movimientos.monto%type := it.fug_obt_pardinamico('MTO_COM_TIGO',
                                                                           null,
                                                                           null,
                                                                           null);
    v_msj_bitacora     VARCHAR2(1000) := substr('sesion: ' || p_sesion ||
                                                'ctaDebito: ' ||
                                                trim(p_nroCtaDebito) ||
                                                'monto: ' || p_monto ||
                                                'nroTelefono: ' ||
                                                p_nrotelefono || 'modo: ' ||
                                                p_modo ||
                                                'nroMovPendiente: ' ||
                                                p_nro_mov_pendiente || 1,
                                                200);
    ------------------------------------------------------------------------------------
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_moneda          ge_cuentas.cod_moneda%type;
    v_cod_ofi_credito_com ge_cuentas.cod_oficina%type;
    v_cod_mon_credito_com ge_cuentas.cod_moneda%type;
    v_cod_mod_credito_com ge_cuentas.cod_modulo%type;
    v_cod_mad_credito_com ge_cuentas.cod_modalidad%type;
    ------------------------------------------------------------------------------------
  BEGIN
    --valido la sesi�n del cliente
    retValidarSesion := fu_validarSesion(p_sesion, p_codCanal);
    IF retValidarSesion.error = 'S' THEN
      p_error                := retValidarSesion.error;
      p_nombreRespuesta      := retValidarSesion.nombreRespuesta;
      p_descripcionRespuesta := retValidarSesion.descripcionRespuesta;
      RETURN;
    END IF;
    -- validamos la caja
    v_mensajeCaja := lf_val_caja(retValidarSesion);
    IF v_mensajeCaja.error = 'S' THEN
      p_error                := v_mensajeCaja.error;
      p_nombreRespuesta      := v_mensajeCaja.nombreRespuesta;
      p_descripcionRespuesta := v_mensajeCaja.descripcionRespuesta;
      RETURN;
    END IF;

    v_permiso := lf_obt_permisos(retValidarSesion, v_cod_operacion);
    IF (v_permiso.error = 'S') THEN
      p_nombreRespuesta      := v_permiso.nombreRespuesta;
      p_descripcionRespuesta := v_permiso.descripcionRespuesta;
      p_error                := v_permiso.error;
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;
    -- se verifica que posea permiso para registrar
    IF v_permiso.registra = 'FALSE' AND instr(v_tip_mensaje, 'I') > 0 THEN
      pr_mensajeUsuario(TRT_SIN_PERMISO,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarbitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;

    v_mensajeCaja.codigoUsuario := fug_obt_user_sesion(p_sesion);
    v_modo                      := NVL(SUBSTR(p_modo, 0, 1), 'x');

    IF nvl(p_modo, 'x') = 'A' THEN
      IF g_aut_operacion = FALSE THEN
        p_error                := 'S';
        p_nombreRespuesta      := 'MOD_OPE_INVALIDA';
        p_descripcionRespuesta := 'Modo Operacion Invalida';
        RETURN;
      END IF;

    END IF;

    v_can_aut_requeridas := 1; -- evita error de cta conjunta para empresas

    pr_mensajeUsuario(MSG_OK,
                      p_nombreRespuesta,
                      p_descripcionRespuesta,
                      p_error);
    pr_insertarBitacora(retValidarSesion.codigoPersona,
                        p_codCanal,
                        p_sesion,
                        v_cod_operacion,
                        retValidarSesion.codigoEmpresa,
                        v_msj_bitacora || ' ' ||
                        fu_generarBitacora(p_error,
                                           p_nombreRespuesta,
                                           p_descripcionRespuesta,
                                           null),
                        BITACORA_ENTRADA);

    -- 0. inicializo la secuencia
    v_nro_secuencia  := 0;
    v_nro_cta_debito := depurarAlfanumerico(p_nroCtaDebito, CUENTA_TAMANO);
    v_monto          := p_monto;

    IF v_modo = 'C' AND v_can_aut_requeridas = 0 THEN
      v_modo := 'A'; -- CONFIRMACION
    END IF;

    -- 2. busco los datos de la cuentas
    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_nro_cta_debito);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        --v_cod_oficina    := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_moneda    := pag_cta.G_CTAS.cod_moneda;
        v_cod_modulo    := pag_cta.G_CTAS.COD_MODULO;
        v_cod_modalidad := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_cre := fug_obt_pardinamico('COD_TRA_CRE_TIGO',
                                             v_cod_modulo,
                                             v_cod_modalidad);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_ope_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_deb := fug_obt_pardinamico('COD_TRA_DEB_TIGO',
                                             v_cod_mod_credito,
                                             v_cod_mad_credito);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_com_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito_com := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito_com := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito_com := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito_com := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_com := fug_obt_pardinamico('COD_TRA_COM_TIGO',
                                             v_cod_mod_credito_com,
                                             v_cod_mad_credito_com);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta Comision';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      IF v_modo = 'C' THEN
        --- inserto el movimiento pendiente de autorizacion
        SELECT s_nro_documento.NEXTVAL INTO v_nro_documento FROM dual;
        BEGIN
          INSERT INTO bw_mov_pendientes
            (nro_documento,
             cod_per_principal,
             fec_hora,
             cod_tip_mensaje,
             nro_cuenta,
             cod_moneda,
             descripcion,
             monto,
             cotizacion,
             mto_equ_local,
             nro_cta_contra,
             estado,
             can_aut_requeridas,
             can_aut_faltantes,
             cod_per_ingreso,
             mto_contra,
             cot_contra,
             etiqueta,
             dato)
          VALUES
            (v_nro_documento,
             nvl(retValidarSesion.codigoEmpresa,
                 retValidarSesion.codigoPersona),
             SYSDATE,
             v_cod_operacion,
             v_nro_cta_debito,
             v_cod_moneda,
             'Tigo Cash Out',
             v_monto,
             null,
             null,
             v_cta_ope_tigo,
             'P',
             v_can_aut_requeridas,
             v_can_aut_requeridas,
             retValidarSesion.codigoPersona,
             v_monto,
             null,
             'Nro. Telefono',
             p_nrotelefono);
        EXCEPTION
          WHEN OTHERS THEN
            p_error                := 'S';
            p_nombreRespuesta      := 'ERROR_INS_MOV_P';
            p_descripcionRespuesta := 'Error al Insertar Movimiento Pendiente ';
            pr_insertarBitacora(retValidarSesion.codigoPersona,
                                p_codCanal,
                                p_sesion,
                                v_cod_operacion,
                                retValidarSesion.codigoEmpresa,
                                'Error:' || ' ' || sqlerrm || ' ' ||
                                fu_generarBitacora(p_error,
                                                   p_nombreRespuesta,
                                                   p_descripcionRespuesta,
                                                   null),
                                BITACORA_SALIDA);
        END;

        p_tipOperacion := v_cod_operacion;
        p_nroDocumento := v_nro_documento;

        RETURN;
      ELSIF v_modo = 'A' THEN
        --------------------------------------------------------------------------
        savepoint CashOut;
        ----------------------------------------------------------
        v_usuario := fu_obt_mov_user('TCASHOUT', 's_hor_mov_out');
        v_hora    := fu_obt_hora(v_usuario, 's_hor_mov_out');
        pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                 p_fec_valor      => trunc(sysdate),
                                 p_cod_tra_padre  => v_cod_tra_padre,
                                 p_estado         => 'N',
                                 p_reversado      => 'N',
                                 p_nro_secuencia  => v_numero_secuencia,
                                 p_est_cuenta     => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre  => v_codigo_modulo,
                                 p_cod_mad_padre  => v_codigo_modalidad);

        IF nvl(p_error, 'N') = 'N' THEN
          BEGIN
            v_nro_secuencia := v_nro_secuencia;
            PAG_CTA.PR_SET_REFERENCIA(p_nro_mov_pendiente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            PAG_CTA.PR_SET_NRO_DOCUMENTO3(v_cod_operacion);
            pag_cta.pr_act_operacion(p_nroCtaDebito,
                                     v_hora,
                                     'C',
                                     v_cod_moneda,
                                     p_monto,
                                     v_cod_tra_padre,
                                     v_cod_tra_cre,
                                     p_nro_mov_pendiente,
                                     null,
                                     61,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Credito CashOut Tigo ' ||
                                     p_nroCtaDebito,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     null);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA_ERROR';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              pr_insertarBitacora(retValidarSesion.codigoPersona,
                                  p_codCanal,
                                  p_sesion,
                                  v_cod_operacion,
                                  retValidarSesion.codigoEmpresa,
                                  'Error:' || ' ' || sqlerrm || ' ' ||
                                  pag_cta.G_MSJ_ERROR || ' ' ||
                                  fu_generarBitacora(p_error,
                                                     p_nombreRespuesta,
                                                     p_descripcionRespuesta,
                                                     null),
                                  BITACORA_SALIDA);
              rollback to CashOut;
              -----------------------------------------------------------------------------------------------
            ELSE
              ----------------------------------------------------------
              pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                       p_fec_valor      => trunc(sysdate),
                                       p_cod_tra_padre  => v_cod_tra_padre,
                                       p_estado         => 'N',
                                       p_reversado      => 'N',
                                       p_nro_secuencia  => v_numero_secuencia,
                                       p_est_cuenta     => null,
                                       p_cod_ofi_origen => 61,
                                       p_cod_mod_padre  => v_codigo_modulo,
                                       p_cod_mad_padre  => v_codigo_modalidad);
              ------------------------------------------------------------
              v_nro_secuencia := v_nro_secuencia;
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cta_com_tigo,
                                       v_hora,
                                       'D',
                                       v_cod_mon_credito_com,
                                       v_comision,
                                       v_cod_tra_padre,
                                       v_cod_tra_com,
                                       p_nro_mov_pendiente,
                                       null,
                                       v_cod_ofi_credito_com,
                                       v_codigo_modulo,
                                       v_codigo_modalidad,
                                       null,
                                       null,
                                       'Credito por comisiones CashOut Tigo ' ||
                                       v_cta_com_tigo,
                                       'N',
                                       v_nro_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       null);
              IF pag_cta.G_COD_ERROR != 0 THEN
                p_error                := 'S';
                p_nombreRespuesta      := 'PAG_CTA_ERROR';
                p_descripcionRespuesta := 'Error al Generar Movimiento';
                pr_insertarBitacora(retValidarSesion.codigoPersona,
                                    p_codCanal,
                                    p_sesion,
                                    v_cod_operacion,
                                    retValidarSesion.codigoEmpresa,
                                    'Error:' || ' ' || sqlerrm || ' ' ||
                                    pag_cta.G_MSJ_ERROR || ' ' ||
                                    fu_generarBitacora(p_error,
                                                       p_nombreRespuesta,
                                                       p_descripcionRespuesta,
                                                       null),
                                    BITACORA_SALIDA);
                rollback to CashOut;
                -----------------------------------------------------------------------------------------------
              END IF;
              ----------------------------------------------------------
              pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                       p_fec_valor      => trunc(sysdate),
                                       p_cod_tra_padre  => v_cod_tra_padre,
                                       p_estado         => 'N',
                                       p_reversado      => 'N',
                                       p_nro_secuencia  => v_numero_secuencia,
                                       p_est_cuenta     => null,
                                       p_cod_ofi_origen => 61,
                                       p_cod_mod_padre  => v_codigo_modulo,
                                       p_cod_mad_padre  => v_codigo_modalidad);
              ------------------------------------------------------------
              --generar credito en cta. cliente
              v_nro_secuencia := v_nro_secuencia;
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cta_ope_tigo,
                                       v_hora,
                                       'D',
                                       v_cod_mon_credito,
                                       p_monto,
                                       v_cod_tra_padre,
                                       v_cod_tra_deb,
                                       p_nro_mov_pendiente,
                                       null,
                                       v_cod_ofi_credito,
                                       v_codigo_modulo,
                                       v_codigo_modalidad,
                                       null,
                                       null,
                                       'Credito por CashOut Tigo ' ||
                                       v_cta_ope_tigo,
                                       'N',
                                       v_nro_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       null);
              IF pag_cta.G_COD_ERROR != 0 THEN
                p_error                := 'S';
                p_nombreRespuesta      := 'PAG_CTA_ERROR';
                p_descripcionRespuesta := 'Error al Generar Movimiento';
                pr_insertarBitacora(retValidarSesion.codigoPersona,
                                    p_codCanal,
                                    p_sesion,
                                    v_cod_operacion,
                                    retValidarSesion.codigoEmpresa,
                                    'Error:' || ' ' || sqlerrm || ' ' ||
                                    pag_cta.G_MSJ_ERROR || ' ' ||
                                    fu_generarBitacora(p_error,
                                                       p_nombreRespuesta,
                                                       p_descripcionRespuesta,
                                                       null),
                                    BITACORA_SALIDA);
                rollback to CashOut;
                -----------------------------------------------------------------------------------------------
              END IF;
              ---------------------------------------------------------------------------------------------------
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA_ERROR';
              p_descripcionRespuesta := 'Error el proceso CashOut ';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              pr_insertarBitacora(retValidarSesion.codigoPersona,
                                  p_codCanal,
                                  p_sesion,
                                  v_cod_operacion,
                                  retValidarSesion.codigoEmpresa,
                                  'Error:' || ' ' || sqlerrm || ' ' ||
                                  fu_generarBitacora(p_error,
                                                     p_nombreRespuesta,
                                                     p_descripcionRespuesta,
                                                     null),
                                  BITACORA_SALIDA);
              rollback to CashOut;
          END;
        END IF;
        ---------------------------------------------------------------------------------------------------
        IF p_error = 'N' THEN
          -- registro del movimiento
          select s_nro_bw_movimiento.nextval
            into v_nro_movimiento
            from dual;
          lp_reg_operacion(v_nro_cta_debito,
                           'GS',
                           p_monto,
                           v_cta_ope_tigo,
                           null,
                           'Nro. Telefono',
                           p_nrotelefono,
                           null,
                           null,
                           'Homebanking',
                           null,
                           null,
                           nvl(retValidarSesion.codigoEmpresa,
                               retValidarSesion.codigoPersona),
                           v_cod_operacion,
                           p_nro_mov_pendiente,
                           p_codCanal,
                           p_sesion,
                           nvl(retValidarSesion.codigoEmpresa,
                               retValidarSesion.codigoPersona),
                           null,
                           null,
                           null,
                           p_nro_mov_pendiente,
                           v_nro_movimiento);

          pr_insertarBitacora(nvl(retValidarSesion.codigoEmpresa,
                                  retValidarSesion.codigoPersona),
                              p_codCanal,
                              p_sesion,
                              v_cod_operacion,
                              nvl(retValidarSesion.codigoEmpresa,
                                  retValidarSesion.codigoPersona),
                              v_msj_bitacora || ' ' ||
                              fu_generarbitacora(p_error,
                                                 null,
                                                 p_descripcionRespuesta,
                                                 null),
                              BITACORA_SALIDA);

        END IF;
      END IF;
    END IF;

    IF p_error != 'N' THEN
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_SALIDA);
    END IF;
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ', ORA-ERR:[' ||
                          SUBSTR(SQLERRM, 1, 200) || '] ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
  END;

  PROCEDURE pr_tigo_comp_min(p_sesion               IN VARCHAR2,
                             p_codCanal             IN VARCHAR2,
                             p_nroCtaDebito         IN VARCHAR2,
                             p_monto                IN NUMBER,
                             p_nrotelefono          IN VARCHAR2,
                             p_modo                 IN VARCHAR2,
                             p_nro_mov_pendiente    IN bw_mov_pendientes.nro_documento%type default null,
                             p_error                out VARCHAR2,
                             p_nombreRespuesta      out VARCHAR2,
                             p_descripcionRespuesta out VARCHAR2,
                             p_tipOperacion         out VARCHAR2,
                             p_nroDocumento         out NUMBER) IS

    TRT_SIN_PERMISO CONSTANT VARCHAR2(15) := 'TRT_SIN_PERMISO';
    v_nro_cta_debito   VARCHAR2(16);
    v_monto            NUMBER(18, 2);
    v_modo             VARCHAR2(1);
    v_cod_mon_credito  VARCHAR2(3);
    v_cod_mod_credito  NUMBER(4);
    v_cod_mad_credito  NUMBER(4);
    v_cod_ofi_credito  NUMBER(4);
    v_mto_equ_local    NUMBER(18) := null;
    v_nro_documento    NUMBER(15);
    v_cod_operacion    VARCHAR2(3) := '303';
    v_nro_secuencia    NUMBER(3);
    v_mensajeCaja      typ_mensajeCaja;
    retValidarSesion   typ_validarSesion;
    v_permiso          typ_permisotigo;
    v_codigo_modulo    NUMBER(3) := 3;
    v_codigo_modalidad NUMBER(3) := 31;
    v_numero_secuencia NUMBER(3) := 0;
    v_cod_tra_padre    NUMBER(4) := 9835;
    v_cod_tra_deb      NUMBER(4);
    v_cod_tra_cre      NUMBER(4);
    v_cod_tra_com      NUMBER(4);
    v_usuario          ge_movimientos.cod_usuario%type;
    v_hora             ge_movimientos.hora%TYPE;
    v_fecha_actual     DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_nro_movimiento   bw_movimientos.nro_movimiento%type;
    v_cta_ope_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_OPE_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_cta_com_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_COM_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_monto_min        ge_movimientos.monto%type := it.fug_obt_pardinamico('MTO_MIN_TIGO',
                                                                           null,
                                                                           null,
                                                                           null);
    v_comision         ge_movimientos.monto%type := it.fug_obt_pardinamico('MTO_COM_TIGO',
                                                                           null,
                                                                           null,
                                                                           null);
    ------------------------------------------------------------------------------------
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_moneda          ge_cuentas.cod_moneda%type;
    v_cod_ofi_credito_com ge_cuentas.cod_oficina%type;
    v_cod_mon_credito_com ge_cuentas.cod_moneda%type;
    v_cod_mod_credito_com ge_cuentas.cod_modulo%type;
    v_cod_mad_credito_com ge_cuentas.cod_modalidad%type;
    ------------------------------------------------------------------------------------
    v_msj_bitacora VARCHAR2(1000) := substr('sesion: ' || p_sesion ||
                                            'ctaDebito: ' ||
                                            trim(p_nroCtaDebito) ||
                                            'monto: ' || p_monto ||
                                            'nroTelefono: ' ||
                                            p_nrotelefono || 'modo: ' ||
                                            p_modo || 'nroMovPendiente: ' ||
                                            p_nro_mov_pendiente || 1,
                                            200);

  BEGIN
    --valido la sesi�n del cliente
    retValidarSesion := fu_validarSesion(p_sesion, p_codCanal);
    IF retValidarSesion.error = 'S' THEN
      p_error                := retValidarSesion.error;
      p_nombreRespuesta      := retValidarSesion.nombreRespuesta;
      p_descripcionRespuesta := retValidarSesion.descripcionRespuesta;
      RETURN;
    END IF;
    -- validamos la caja
    v_mensajeCaja := lf_val_caja(retValidarSesion);
    IF v_mensajeCaja.error = 'S' THEN
      p_error                := v_mensajeCaja.error;
      p_nombreRespuesta      := v_mensajeCaja.nombreRespuesta;
      p_descripcionRespuesta := v_mensajeCaja.descripcionRespuesta;
      RETURN;
    END IF;

    v_permiso := lf_obt_permisos(retValidarSesion, v_cod_operacion);
    IF (v_permiso.error = 'S') THEN
      p_nombreRespuesta      := v_permiso.nombreRespuesta;
      p_descripcionRespuesta := v_permiso.descripcionRespuesta;
      p_error                := v_permiso.error;
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;
    -- se verifica que posea permiso para registrar
    IF v_permiso.registra = 'FALSE' AND instr(v_tip_mensaje, 'I') > 0 THEN
      pr_mensajeUsuario(TRT_SIN_PERMISO,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarbitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;

    IF p_monto < v_monto_min THEN
      p_error                := 'S';
      p_nombreRespuesta      := 'MTO_MIN_INVAL';
      p_descripcionRespuesta := 'Monto debe ser superior a Un Millon';
      RETURN;
    END IF;

    v_mensajeCaja.codigoUsuario := fug_obt_user_sesion(p_sesion);

    v_modo := NVL(SUBSTR(p_modo, 0, 1), 'x');

    IF nvl(p_modo, 'x') = 'A' THEN
      IF g_aut_operacion = FALSE THEN
        p_error                := 'S';
        p_nombreRespuesta      := 'MOD_OPE_INVALIDA';
        p_descripcionRespuesta := 'Modo Operacion Invalida';
        RETURN;
      END IF;

    END IF;

    v_can_aut_requeridas := 1;

    pr_mensajeUsuario(MSG_OK,
                      p_nombreRespuesta,
                      p_descripcionRespuesta,
                      p_error);
    pr_insertarBitacora(retValidarSesion.codigoPersona,
                        p_codCanal,
                        p_sesion,
                        v_cod_operacion,
                        retValidarSesion.codigoEmpresa,
                        v_msj_bitacora || ' ' ||
                        fu_generarBitacora(p_error,
                                           p_nombreRespuesta,
                                           p_descripcionRespuesta,
                                           null),
                        BITACORA_ENTRADA);

    -- 0. inicializo la secuencia
    v_nro_secuencia  := 0;
    v_nro_cta_debito := depurarAlfanumerico(p_nroCtaDebito, CUENTA_TAMANO);
    v_monto          := p_monto;

    IF v_modo = 'C' AND v_can_aut_requeridas = 0 THEN
      v_modo := 'A'; -- CONFIRMACION
    END IF;

    -- 2. busco los datos de la cuentas
    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_nro_cta_debito);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_moneda    := pag_cta.G_CTAS.cod_moneda;
        v_cod_modulo    := pag_cta.G_CTAS.COD_MODULO;
        v_cod_modalidad := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_deb := fug_obt_pardinamico('COD_TRA_DEB_TIGO',
                                             v_cod_modulo,
                                             v_cod_modalidad);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_ope_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_cre := fug_obt_pardinamico('COD_TRA_CRE_TIGO',
                                             v_cod_mod_credito,
                                             v_cod_mad_credito);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_com_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito_com := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito_com := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito_com := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito_com := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_com := fug_obt_pardinamico('COD_TRA_COM_TIGO',
                                             v_cod_mod_credito_com,
                                             v_cod_mad_credito_com);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta Comision';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      -- no hay problemas hasta aqui
      IF v_modo = 'C' THEN
        v_mto_equ_local := null;
        --- inserto el movimiento pendiente de autorizacion
        SELECT s_nro_documento.NEXTVAL INTO v_nro_documento FROM dual;
        BEGIN
          INSERT INTO bw_mov_pendientes
            (nro_documento,
             cod_per_principal,
             fec_hora,
             cod_tip_mensaje,
             nro_cuenta,
             cod_moneda,
             descripcion,
             monto,
             cotizacion,
             mto_equ_local,
             nro_cta_contra,
             estado,
             can_aut_requeridas,
             can_aut_faltantes,
             cod_per_ingreso,
             mto_contra,
             cot_contra,
             etiqueta,
             dato)
          VALUES
            (v_nro_documento,
             nvl(retValidarSesion.codigoEmpresa,
                 retValidarSesion.codigoPersona),
             SYSDATE,
             v_cod_operacion,
             v_nro_cta_debito,
             v_cod_moneda,
             'Tigo Compra Minutos',
             v_monto,
             null,
             v_mto_equ_local,
             v_cta_ope_tigo,
             'P',
             v_can_aut_requeridas,
             v_can_aut_requeridas,
             retValidarSesion.codigoPersona,
             v_monto,
             null,
             'Nro. Telefono',
             p_nrotelefono);
        EXCEPTION
          WHEN OTHERS THEN
            p_error                := 'S';
            p_nombreRespuesta      := 'ERROR_INS_MOV_P';
            p_descripcionRespuesta := 'Error al Insertar Movimiento Pendiente ';
            pr_insertarBitacora(retValidarSesion.codigoPersona,
                                p_codCanal,
                                p_sesion,
                                v_cod_operacion,
                                retValidarSesion.codigoEmpresa,
                                'Error:' || ' ' || sqlerrm || ' ' ||
                                fu_generarBitacora(p_error,
                                                   p_nombreRespuesta,
                                                   p_descripcionRespuesta,
                                                   null),
                                BITACORA_SALIDA);
        END;

        p_tipOperacion := v_cod_operacion;
        p_nroDocumento := v_nro_documento;

        RETURN;
      ELSIF v_modo = 'A' THEN
        --------------------------------------------------------------------------
        savepoint CompMin;
        ----------------------------------------------------------
        v_usuario := fu_obt_mov_user('TCOMPMI', 's_hor_mov_cm');
        v_hora    := fu_obt_hora(v_usuario, 's_hor_mov_cm');
        pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                 p_fec_valor      => trunc(sysdate),
                                 p_cod_tra_padre  => v_cod_tra_padre,
                                 p_estado         => 'N',
                                 p_reversado      => 'N',
                                 p_nro_secuencia  => v_numero_secuencia,
                                 p_est_cuenta     => null,
                                 p_cod_ofi_origen => 61,
                                 p_cod_mod_padre  => v_codigo_modulo,
                                 p_cod_mad_padre  => v_codigo_modalidad);
        ---------------------------------------------------------------------------------------------------
        IF nvl(p_error, 'N') = 'N' THEN
          BEGIN
            v_hora          := fug_obt_mov_hora;
            v_nro_secuencia := v_nro_secuencia;
            PAG_CTA.PR_SET_REFERENCIA(p_nro_mov_pendiente);
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            PAG_CTA.PR_SET_NRO_DOCUMENTO3(v_cod_operacion);
            pag_cta.pr_act_operacion(p_nroCtaDebito,
                                     v_hora,
                                     'D',
                                     v_cod_moneda,
                                     p_monto,
                                     v_cod_tra_padre,
                                     v_cod_tra_deb,
                                     p_nro_mov_pendiente,
                                     null,
                                     61,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Debito Compra Minutos Tigo ' ||
                                     p_nroCtaDebito,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     v_mto_equ_local);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA_ERROR';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              pr_insertarBitacora(retValidarSesion.codigoPersona,
                                  p_codCanal,
                                  p_sesion,
                                  v_cod_operacion,
                                  retValidarSesion.codigoEmpresa,
                                  'Error:' || ' ' || sqlerrm || ' ' ||
                                  pag_cta.G_MSJ_ERROR || ' ' ||
                                  fu_generarBitacora(p_error,
                                                     p_nombreRespuesta,
                                                     p_descripcionRespuesta,
                                                     null),
                                  BITACORA_SALIDA);
              rollback to CompMin;
              -----------------------------------------------------------------------------------------------
            ELSE
              ----------------------------------------------------------
              pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                       p_fec_valor      => trunc(sysdate),
                                       p_cod_tra_padre  => v_cod_tra_padre,
                                       p_estado         => 'N',
                                       p_reversado      => 'N',
                                       p_nro_secuencia  => v_numero_secuencia,
                                       p_est_cuenta     => null,
                                       p_cod_ofi_origen => 61,
                                       p_cod_mod_padre  => v_codigo_modulo,
                                       p_cod_mad_padre  => v_codigo_modalidad);
              ------------------------------------------------------------
              v_nro_secuencia := v_nro_secuencia;
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cta_com_tigo,
                                       v_hora,
                                       'C',
                                       v_cod_mon_credito_com,
                                       v_comision,
                                       v_cod_tra_padre,
                                       v_cod_tra_com,
                                       p_nro_mov_pendiente,
                                       null,
                                       v_cod_ofi_credito_com,
                                       v_codigo_modulo,
                                       v_codigo_modalidad,
                                       null,
                                       null,
                                       'Credito por comisiones Compra Minutos Tigo ' ||
                                       v_cta_com_tigo,
                                       'N',
                                       v_nro_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       v_mto_equ_local);
              IF pag_cta.G_COD_ERROR != 0 THEN
                p_error                := 'S';
                p_nombreRespuesta      := 'PAG_CTA_ERROR';
                p_descripcionRespuesta := 'Error al Generar Movimiento';
                pr_insertarBitacora(retValidarSesion.codigoPersona,
                                    p_codCanal,
                                    p_sesion,
                                    v_cod_operacion,
                                    retValidarSesion.codigoEmpresa,
                                    'Error:' || ' ' || sqlerrm || ' ' ||
                                    pag_cta.G_MSJ_ERROR || ' ' ||
                                    fu_generarBitacora(p_error,
                                                       p_nombreRespuesta,
                                                       p_descripcionRespuesta,
                                                       null),
                                    BITACORA_SALIDA);
                rollback to CompMin;
                -----------------------------------------------------------------------------------------------
              END IF;
              ----------------------------------------------------------
              pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                       p_fec_valor      => trunc(sysdate),
                                       p_cod_tra_padre  => v_cod_tra_padre,
                                       p_estado         => 'N',
                                       p_reversado      => 'N',
                                       p_nro_secuencia  => v_numero_secuencia,
                                       p_est_cuenta     => null,
                                       p_cod_ofi_origen => 61,
                                       p_cod_mod_padre  => v_codigo_modulo,
                                       p_cod_mad_padre  => v_codigo_modalidad);
              ------------------------------------------------------------
              v_nro_secuencia := v_nro_secuencia;
              pag_cta.PR_NRO_CAJA(p_nro_caja => null);
              pag_cta.pr_act_operacion(v_cta_ope_tigo,
                                       v_hora,
                                       'C',
                                       v_cod_mon_credito,
                                       p_monto,
                                       v_cod_tra_padre,
                                       v_cod_tra_cre,
                                       p_nro_mov_pendiente,
                                       null,
                                       v_cod_ofi_credito,
                                       v_codigo_modulo,
                                       v_codigo_modalidad,
                                       null,
                                       null,
                                       'Credito por Compra Minutos Tigo ' ||
                                       v_cta_ope_tigo,
                                       'N',
                                       v_nro_secuencia,
                                       v_fecha_actual,
                                       null,
                                       null,
                                       v_mto_equ_local);
              IF pag_cta.G_COD_ERROR != 0 THEN
                p_error                := 'S';
                p_nombreRespuesta      := 'PAG_CTA_ERROR';
                p_descripcionRespuesta := 'Error al Generar Movimiento';
                pr_insertarBitacora(retValidarSesion.codigoPersona,
                                    p_codCanal,
                                    p_sesion,
                                    v_cod_operacion,
                                    retValidarSesion.codigoEmpresa,
                                    'Error:' || ' ' || sqlerrm || ' ' ||
                                    pag_cta.G_MSJ_ERROR || ' ' ||
                                    fu_generarBitacora(p_error,
                                                       p_nombreRespuesta,
                                                       p_descripcionRespuesta,
                                                       null),
                                    BITACORA_SALIDA);
                rollback to CompMin;
                -----------------------------------------------------------------------------------------------
              END IF;
              ---------------------------------------------------------------------------------------------------
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA_ERROR';
              p_descripcionRespuesta := 'Error el proceso Compra de Minutos ';
              pr_insertarBitacora(retValidarSesion.codigoPersona,
                                  p_codCanal,
                                  p_sesion,
                                  v_cod_operacion,
                                  retValidarSesion.codigoEmpresa,
                                  'Error:' || ' ' || sqlerrm || ' ' ||
                                  fu_generarBitacora(p_error,
                                                     p_nombreRespuesta,
                                                     p_descripcionRespuesta,
                                                     null),
                                  BITACORA_SALIDA);
              rollback to CompMin;
          END;
        END IF;
        ---------------------------------------------------------------------------------------------------
        IF p_error = 'N' THEN
          select s_nro_bw_movimiento.nextval
            into v_nro_movimiento
            from dual;
          lp_reg_operacion(v_nro_cta_debito,
                           'GS',
                           p_monto,
                           v_cta_ope_tigo,
                           null,
                           'Nro. Telefono',
                           p_nrotelefono,
                           null,
                           null,
                           'Homebanking',
                           null,
                           null,
                           nvl(retValidarSesion.codigoEmpresa,
                               retValidarSesion.codigoPersona),
                           v_cod_operacion,
                           p_nro_mov_pendiente,
                           p_codCanal,
                           p_sesion,
                           nvl(retValidarSesion.codigoEmpresa,
                               retValidarSesion.codigoPersona),
                           null,
                           null,
                           null,
                           p_nro_mov_pendiente,
                           v_nro_movimiento);

          pr_insertarBitacora(nvl(retValidarSesion.codigoEmpresa,
                                  retValidarSesion.codigoPersona),
                              p_codCanal,
                              p_sesion,
                              v_cod_operacion,
                              nvl(retValidarSesion.codigoEmpresa,
                                  retValidarSesion.codigoPersona),
                              v_msj_bitacora || ' ' ||
                              fu_generarbitacora(p_error,
                                                 null,
                                                 p_descripcionRespuesta,
                                                 null),
                              BITACORA_SALIDA);
        END IF;
      END IF;
    END IF;

    IF p_error != 'N' THEN
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_SALIDA);
    END IF;

    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(retValidarSesion.codigoPersona,
                          p_codCanal,
                          p_sesion,
                          v_cod_operacion,
                          retValidarSesion.codigoEmpresa,
                          v_msj_bitacora || ', ORA-ERR:[' ||
                          SUBSTR(SQLERRM, 1, 200) || '] ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
  END;

  PROCEDURE pr_autorizarOperacion(p_sesion               IN VARCHAR2,
                                  p_codigoCanal          IN VARCHAR2,
                                  p_modo                 IN VARCHAR2,
                                  p_numeroDocumento      IN NUMBER,
                                  p_comentario           IN VARCHAR2,
                                  p_error                out VARCHAR2,
                                  p_nombreRespuesta      out VARCHAR2,
                                  p_descripcionRespuesta out VARCHAR2) IS

    PRO_AUT_SIN_PERMISO     CONSTANT VARCHAR2(15) := 'PRO_AUT_SIN_PER';
    PRO_AUT_DOC_INEXISTENTE CONSTANT VARCHAR2(15) := 'PRO_AUT_DOC_INE';
    PRO_AUT_PED_DUPLICADO   CONSTANT VARCHAR2(15) := 'PRO_AUT_DUPLICA';
    ERR_LIM_OPERACION       CONSTANT VARCHAR2(15) := 'G_ERR_LIM_OPERA';
    MSG_MOD_CIERRE          CONSTANT VARCHAR2(15) := 'MOD_SIS_CIERRE';
    MSG_ERROR               CONSTANT VARCHAR2(30) := 'OP_ERROR';
    v_retorno           typ_autorizaOperacion := typ_autorizaOperacion();
    v_usu_sesion        typ_validarsesion;
    v_msj_caja          typ_mensajeCaja;
    v_permiso           TYP_PERMISOTIGO;
    mp                  bw_mov_pendientes%ROWTYPE;
    v_nro_documento     bw_mov_pendientes.nro_documento%TYPE;
    v_cod_per_empresa   ba_personas.cod_persona%TYPE;
    v_modo              VARCHAR2(1) := substr(p_modo, 1, 1); -- modo D,A,R
    v_comentario        VARCHAR(50) := substr(p_comentario, 1, 50);
    v_can_aut_faltantes NUMBER(3) := 0;
    v_cod_operacion     VARCHAR2(3) := '023';
    v_res_limite        VARCHAR2(2);
    v_per_autorizador   VARCHAR2(1) := 'S';
    v_msj_bitacora      VARCHAR2(1000) := substr('sesion: ' || p_sesion ||
                                                 'modo: ' || p_modo ||
                                                 'numeroDocumento: ' ||
                                                 p_numeroDocumento || 1,
                                                 200);

  BEGIN
    -- 1. valido la clave del cliente
    v_usu_sesion := fu_validarSesion(depurarAlfanumerico(p_sesion, 32),
                                     p_codigoCanal);
    IF v_usu_sesion.error = 'S' THEN
      p_error                := v_usu_sesion.error;
      p_nombreRespuesta      := v_usu_sesion.nombreRespuesta;
      p_descripcionRespuesta := v_usu_sesion.descripcionRespuesta;
      RETURN;
    END IF;
    -- 2. verIFica el canal de origen
    v_msj_caja := lf_val_caja(v_usu_sesion);
    IF v_msj_caja.error = 'S' THEN
      p_error                := v_msj_caja.error;
      p_nombreRespuesta      := v_msj_caja.nombreRespuesta;
      p_descripcionRespuesta := v_msj_caja.descripcionRespuesta;
      RETURN;
    END IF;

    pr_mensajeUsuario(MSG_OK,
                      p_nombreRespuesta,
                      p_descripcionRespuesta,
                      p_error);

    v_nro_documento   := p_numeroDocumento;
    v_cod_per_empresa := v_usu_sesion.codigoEmpresa;

    IF p_error = 'N' THEN
      BEGIN
        SELECT *
          INTO mp
          FROM bw_mov_pendientes
         WHERE nro_documento = v_nro_documento
           AND cod_per_principal = v_cod_per_empresa
           AND ((cod_tip_mensaje not in ('070', '075') and
               trunc(sysdate - 10) <= trunc(fec_insercion)) OR
               (cod_tip_mensaje in ('070', '075') and
               trunc(SYSDATE) >= TRUNC(to_date(dato2, 'DD/MM/YYYY'))));

        v_msj_bitacora := v_msj_bitacora || ', cod_tip:' ||
                          mp.cod_tip_mensaje;

        IF v_permiso.autoriza = 'FALSE' THEN
          v_per_autorizador := 'N';
          IF v_permiso.registra = 'FALSE' OR
             mp.cod_per_ingreso <> v_usu_sesion.codigoPersona OR
             p_modo = 'A' OR mp.can_aut_faltantes <> mp.can_aut_requeridas THEN

            pr_mensajeUsuario(PRO_AUT_SIN_PERMISO,
                              p_nombreRespuesta,
                              p_descripcionRespuesta,
                              p_error);
            pr_insertarBitacora(v_usu_sesion.codigoPersona,
                                p_codigoCanal,
                                p_sesion,
                                v_cod_operacion,
                                v_usu_sesion.codigoEmpresa,
                                v_msj_bitacora || ' ' ||
                                fu_generarBitacora(p_error,
                                                   p_nombreRespuesta,
                                                   p_descripcionRespuesta,
                                                   null),
                                BITACORA_ERROR);
            RETURN;
          END IF;
        END IF;
        v_msj_bitacora := v_msj_bitacora || ', es_aut: ' ||
                          v_per_autorizador;
      EXCEPTION
        WHEN OTHERS THEN
          pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE,
                            p_nombreRespuesta,
                            p_descripcionRespuesta,
                            p_error);
          v_msj_bitacora := substr(v_msj_bitacora || ', ORA-ERR:[' ||
                                   SQLERRM || ']',
                                   1,
                                   1000);
          RETURN;
      END;
    END IF;

    IF pae_cnf.FU_OBT_EST_MODULO(3) IN (1, 6) THEN
      pr_mensajeUsuario(MSG_MOD_CIERRE,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(v_usu_sesion.codigoPersona,
                          p_codigoCanal,
                          p_sesion,
                          v_cod_operacion,
                          v_usu_sesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;

    IF NVL(lf_val_gen_ope_cierre, 'S') = 'N' THEN
      pr_mensajeUsuario(MSG_MOD_CIERRE,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(v_usu_sesion.codigoPersona,
                          p_codigoCanal,
                          p_sesion,
                          v_cod_operacion,
                          v_usu_sesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
    END IF;

    IF v_per_autorizador = 'N' THEN
      p_nombreRespuesta := PRO_AUT_SIN_PERMISO;
      pr_mensajeUsuario(PRO_AUT_SIN_PERMISO,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
    END IF;
    pr_insertarBitacora(v_usu_sesion.codigoPersona,
                        p_codigoCanal,
                        p_sesion,
                        v_cod_operacion,
                        v_usu_sesion.codigoEmpresa,
                        v_msj_bitacora || ' ' ||
                        fu_generarBitacora(p_error,
                                           p_nombreRespuesta,
                                           p_descripcionRespuesta,
                                           null),
                        BITACORA_ENTRADA);

    IF p_error = 'N' THEN
      IF v_modo IN ('D', 'A', 'R', 'I') THEN
        -- D-DETALLE, A-AUTORIZAR, R-RECHAZAR OPERACION
        IF paw_bce.fu_val_per_pendiente(v_nro_documento, v_cod_per_empresa) = 'N' AND
           mp.cod_tip_mensaje <> '008' THEN
          pr_mensajeusuario(PRO_AUT_SIN_PERMISO,
                            p_nombreRespuesta,
                            p_descripcionRespuesta,
                            p_error);
        END IF;
        -- controlo el limite de operacion
        IF p_error = 'N' and v_modo in ('D', 'A', 'R') AND
           mp.cod_tip_mensaje <> '008' THEN
          paw_bce.v_cod_respuesta := paw_bce.v_cod_aprobado;
          v_res_limite            := paw_bce.fu_obt_aut_limite(v_cod_per_empresa,
                                                               v_nro_documento,
                                                               v_usu_sesion.codigoPersona);
          v_msj_bitacora          := v_msj_bitacora || ', resLim:' ||
                                     v_res_limite;

          IF paw_bce.v_cod_aprobado <> paw_bce.v_cod_respuesta THEN
            IF paw_bce.v_cod_respuesta = paw_bce.v_cod_cta_sin_mov THEN
              pr_mensajeusuario(PRO_AUT_DOC_INEXISTENTE,
                                p_nombreRespuesta,
                                p_descripcionRespuesta,
                                p_error);
            ELSIF paw_bce.v_cod_respuesta = paw_bce.v_cod_ped_duplicado THEN
              pr_mensajeusuario(PRO_AUT_PED_DUPLICADO,
                                p_nombreRespuesta,
                                p_descripcionRespuesta,
                                p_error);
            ELSE
              pr_mensajeusuario(ERR_LIM_OPERACION,
                                p_nombreRespuesta,
                                p_descripcionRespuesta,
                                p_error);
            END IF;
            v_msj_bitacora := v_msj_bitacora || ', codRes: ' ||
                              paw_bce.v_cod_respuesta || ', ORA-ERR: [' ||
                              substr(sqlerrm, 1, 100) || ']';
          ELSE
            v_retorno.respuestaLimite := v_res_limite;
          END IF;
        END IF;
      END IF;

      IF p_error = 'N' and mp.cod_tip_mensaje = 301 and v_modo IN ('A') THEN
        g_aut_operacion := TRUE;
        DECLARE
          v_error                VARCHAR2(1);
          v_nombreRespuesta      VARCHAR2(15);
          v_descripcionRespuesta VARCHAR2(200);
          v_tipOperacion         VARCHAR2(3);
          v_nroDocumento         VARCHAR2(15);
        BEGIN
          it.paw_tig.pr_tigo_cash_in(p_sesion               => p_sesion,
                                      p_codCanal             => p_codigoCanal,
                                      p_nroCtaDebito         => mp.nro_cuenta,
                                      p_monto                => mp.monto,
                                      p_nrotelefono          => mp.dato,
                                      p_modo                 => 'A',
                                      p_nro_mov_pendiente    => v_nro_documento,
                                      p_error                => v_error,
                                      p_nombreRespuesta      => v_nombreRespuesta,
                                      p_descripcionRespuesta => v_descripcionRespuesta,
                                      p_tipOperacion         => v_tipOperacion,
                                      p_nroDocumento         => v_nroDocumento);

          IF v_error = 'S' THEN
            p_error                := v_error;
            p_nombreRespuesta      := v_nombreRespuesta;
            p_descripcionRespuesta := v_descripcionRespuesta;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            pr_mensajeusuario(MSG_ERROR,
                              p_nombreRespuesta,
                              p_descripcionRespuesta,
                              p_error);
            v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' ||
                              SUBSTR(SQLERRM, 1, 200) || ']';
        END;
      END IF;

      IF p_error = 'N' and mp.cod_tip_mensaje = 302 and v_modo IN ('A') THEN
        g_aut_operacion := TRUE;
        DECLARE
          v_error                VARCHAR2(1);
          v_nombreRespuesta      VARCHAR2(15);
          v_descripcionRespuesta VARCHAR2(200);
          v_tipOperacion         VARCHAR2(3);
          v_nroDocumento         VARCHAR2(15);
        BEGIN
          it.paw_tig.pr_tigo_cash_out(p_sesion               => p_sesion,
                                       p_codCanal             => p_codigoCanal,
                                       p_nroCtaDebito         => mp.nro_cuenta,
                                       p_monto                => mp.monto,
                                       p_nrotelefono          => mp.dato,
                                       p_modo                 => 'A',
                                       p_nro_mov_pendiente    => v_nro_documento,
                                       p_error                => v_error,
                                       p_nombreRespuesta      => v_nombreRespuesta,
                                       p_descripcionRespuesta => v_descripcionRespuesta,
                                       p_tipOperacion         => v_tipOperacion,
                                       p_nroDocumento         => v_nroDocumento);

          IF v_error = 'S' THEN
            p_error                := v_error;
            p_nombreRespuesta      := v_nombreRespuesta;
            p_descripcionRespuesta := v_descripcionRespuesta;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            pr_mensajeusuario(MSG_ERROR,
                              p_nombreRespuesta,
                              p_descripcionRespuesta,
                              p_error);
            v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' ||
                              SUBSTR(SQLERRM, 1, 200) || ']';
        END;
      END IF;

      IF p_error = 'N' and mp.cod_tip_mensaje = 303 and v_modo IN ('A') THEN
        g_aut_operacion := TRUE;
        DECLARE
          v_error                VARCHAR2(1);
          v_nombreRespuesta      VARCHAR2(15);
          v_descripcionRespuesta VARCHAR2(200);
          v_tipOperacion         VARCHAR2(3);
          v_nroDocumento         VARCHAR2(15);
        BEGIN
          it.paw_tig.pr_tigo_comp_min(p_sesion               => p_sesion,
                                       p_codCanal             => p_codigoCanal,
                                       p_nroCtaDebito         => mp.nro_cuenta,
                                       p_monto                => mp.monto,
                                       p_nrotelefono          => mp.dato,
                                       p_modo                 => 'A',
                                       p_nro_mov_pendiente    => v_nro_documento,
                                       p_error                => v_error,
                                       p_nombreRespuesta      => v_nombreRespuesta,
                                       p_descripcionRespuesta => v_descripcionRespuesta,
                                       p_tipOperacion         => v_tipOperacion,
                                       p_nroDocumento         => v_nroDocumento);

          IF v_error = 'S' THEN
            p_error                := v_error;
            p_nombreRespuesta      := v_nombreRespuesta;
            p_descripcionRespuesta := v_descripcionRespuesta;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            pr_mensajeusuario(MSG_ERROR,
                              p_nombreRespuesta,
                              p_descripcionRespuesta,
                              p_error);
            v_msj_bitacora := v_msj_bitacora || ', ORA-ERR:[' ||
                              SUBSTR(SQLERRM, 1, 200) || ']';
        END;
      END IF;

      IF v_modo = 'A' AND p_error = 'N' THEN
        -- actualizo el movimiento pendiente
        UPDATE bw_mov_pendientes
           SET can_aut_faltantes = nvl(can_aut_faltantes, 0) - 1,
               estado            = decode(can_aut_faltantes, 1, 'C', estado)
         WHERE nro_documento = v_nro_documento
           AND cod_per_principal = v_cod_per_empresa
        RETURNING can_aut_faltantes INTO v_can_aut_faltantes;

        IF p_error = 'N' THEN
          BEGIN
            INSERT INTO bw_autorizaciones
              (cod_persona, nro_documento, fec_hora, accion, observacion)
            VALUES
              (v_usu_sesion.codigoPersona,
               v_nro_documento,
               SYSDATE,
               'A',
               v_comentario);
          EXCEPTION
            WHEN dup_val_on_index THEN
              pr_mensajeusuario(PRO_AUT_PED_DUPLICADO,
                                p_nombreRespuesta,
                                p_descripcionRespuesta,
                                p_error);
          END;
        END IF;

        --- VERIFICO QUE TIPO DE OPERACION ES LA QUE SE CONFIRMA
        IF p_error = 'N' AND v_can_aut_faltantes = 0 THEN
          v_can_aut_requeridas := 1;
          g_aut_operacion      := TRUE;
        END IF;

      ELSIF v_modo = 'R' AND p_error = 'N' THEN
        -- si no hubo errores, elimino los temporales
        UPDATE bw_mov_pendientes
           SET estado = decode(v_per_autorizador, 'S', 'A', 'B') -- 'B' ELIMINADA   -- 'A' ANULADA
         WHERE nro_documento = v_nro_documento
           AND cod_per_principal = v_cod_per_empresa;

        IF p_error = 'N' THEN
          BEGIN
            -- inserto el movimiento por la anulacion
            INSERT INTO bw_autorizaciones
              (cod_persona, nro_documento, fec_hora, accion, observacion)
            VALUES
              (v_usu_sesion.codigoPersona,
               v_nro_documento,
               SYSDATE,
               decode(v_per_autorizador, 'S', 'R', 'B'),
               v_comentario);
          EXCEPTION
            WHEN dup_val_on_index THEN
              pr_mensajeusuario(PRO_AUT_PED_DUPLICADO,
                                p_nombreRespuesta,
                                p_descripcionRespuesta,
                                p_error);
          END;
        END IF;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pr_insertarBitacora(v_usu_sesion.codigoPersona,
                          p_codigoCanal,
                          p_sesion,
                          v_cod_operacion,
                          v_usu_sesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_SALIDA);
    ELSE
      pr_insertarBitacora(v_usu_sesion.codigoPersona,
                          p_codigoCanal,
                          p_sesion,
                          v_cod_operacion,
                          v_usu_sesion.codigoEmpresa,
                          v_msj_bitacora || ' ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
    END IF;

    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      pr_insertarBitacora(v_usu_sesion.codigoPersona,
                          p_codigoCanal,
                          p_sesion,
                          v_cod_operacion,
                          v_usu_sesion.codigoEmpresa,
                          v_msj_bitacora || ', ORA-ERR:[' ||
                          SUBSTR(SQLERRM, 1, 200) || '] ' ||
                          fu_generarBitacora(p_error,
                                             p_nombreRespuesta,
                                             p_descripcionRespuesta,
                                             null),
                          BITACORA_ERROR);
      RETURN;
  END;

  PROCEDURE pr_tigo_cash_in_724(p_nroCtaDebito         IN VARCHAR2,
                                p_monto                IN NUMBER,
                                p_tipOperacion         IN VARCHAR2,
                                p_nroPedido            IN VARCHAR2,
                                p_nroComprobante       out VARCHAR2,
                                p_fechaProceso         out date,
                                p_fechaOperacion       out date,
                                p_horaOperacion        out VARCHAR2,
                                p_error                out VARCHAR2,
                                p_nombreRespuesta      out VARCHAR2,
                                p_descripcionRespuesta out VARCHAR2) IS

    v_nro_cta_debito  VARCHAR2(16);
    v_cod_mon_credito VARCHAR2(3);
    v_cod_mod_credito NUMBER(4);
    v_cod_mad_credito NUMBER(4);
    v_cod_ofi_credito NUMBER(4);
    v_nro_documento   NUMBER(15);
    v_cod_operacion   VARCHAR2(3) := '301';
    v_nro_secuencia   NUMBER(3);
    ------------------------------------------------------------------------------------
    v_codigo_modulo    NUMBER(3) := 3;
    v_codigo_modalidad NUMBER(3) := 31;
    v_numero_secuencia NUMBER(3) := 0;
    v_cod_tra_padre    NUMBER(4) := 9835;
    v_cod_tra_deb      NUMBER(4);
    v_cod_tra_cre      NUMBER(4);
    v_cod_tra_com      NUMBER(4);
    v_usuario          ge_movimientos.cod_usuario%type;
    v_hora             ge_movimientos.hora%TYPE;
    v_fecha_actual     DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_cta_ope_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_OPE_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_cta_com_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_COM_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_comision         ge_movimientos.monto%type := it.fug_obt_pardinamico('MTO_COM_TIGO',
                                                                           null,
                                                                           null,
                                                                           null);
    ------------------------------------------------------------------------------------
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_oficina         ge_cuentas.cod_oficina%type;
    v_cod_moneda          ge_cuentas.cod_moneda%type;
    v_cod_ofi_credito_com ge_cuentas.cod_oficina%type;
    v_cod_mon_credito_com ge_cuentas.cod_moneda%type;
    v_cod_mod_credito_com ge_cuentas.cod_modulo%type;
    v_cod_mad_credito_com ge_cuentas.cod_modalidad%type;
    ------------------------------------------------------------------------------------

  BEGIN

    pr_mensajeUsuario(MSG_OK,
                      p_nombreRespuesta,
                      p_descripcionRespuesta,
                      p_error);

    -- 0. inicializo la secuencia
    v_nro_secuencia  := 0;
    v_nro_cta_debito := depurarAlfanumerico(p_nroCtaDebito, CUENTA_TAMANO);

    -- 2. busco los datos de la cuentas
    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_nro_cta_debito);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_oficina   := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_moneda    := pag_cta.G_CTAS.cod_moneda;
        v_cod_modulo    := pag_cta.G_CTAS.COD_MODULO;
        v_cod_modalidad := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_deb := fug_obt_pardinamico('COD_TRA_DEB_TIGO',
                                             v_cod_modulo,
                                             v_cod_modalidad);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_ope_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_cre := fug_obt_pardinamico('COD_TRA_CRE_TIGO',
                                             v_cod_mod_credito,
                                             v_cod_mad_credito);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_com_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito_com := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito_com := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito_com := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito_com := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_com := fug_obt_pardinamico('COD_TRA_COM_TIGO',
                                             v_cod_mod_credito_com,
                                             v_cod_mad_credito_com);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta Comision';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      --------------------------------------------------------------------------
      savepoint CashIn724;
      SELECT s_nro_documento.NEXTVAL INTO v_nro_documento FROM dual;
      ----------------------------------------------------------
      v_usuario := fu_obt_mov_user('TCASHIN', 's_hor_mov_in');
      v_hora    := fu_obt_hora(v_usuario, 's_hor_mov_in');
      pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                               p_fec_valor      => trunc(sysdate),
                               p_cod_tra_padre  => v_cod_tra_padre,
                               p_estado         => 'N',
                               p_reversado      => 'N',
                               p_nro_secuencia  => v_numero_secuencia,
                               p_est_cuenta     => null,
                               p_cod_ofi_origen => 61,
                               p_cod_mod_padre  => v_codigo_modulo,
                               p_cod_mad_padre  => v_codigo_modalidad);
      ------------------------------------------------------------
      IF nvl(p_error, 'N') = 'N' THEN
        BEGIN
          v_nro_secuencia := v_nro_secuencia;
          PAG_CTA.PR_SET_REFERENCIA(v_nro_documento);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          pag_cta.PR_SET_NRO_DOCUMENTO2(p_nroPedido);
          pag_cta.PR_SET_NRO_DOCUMENTO3(v_cod_operacion);
          pag_cta.pr_act_operacion(v_nro_cta_debito,
                                   v_hora,
                                   'D',
                                   v_cod_moneda,
                                   p_monto,
                                   v_cod_tra_padre,
                                   v_cod_tra_deb,
                                   v_nro_documento,
                                   null,
                                   v_cod_oficina,
                                   v_codigo_modulo,
                                   v_codigo_modalidad,
                                   null,
                                   null,
                                   'Debito CashIn Tigo ' ||
                                   v_nro_cta_debito,
                                   'N',
                                   v_nro_secuencia,
                                   v_fecha_actual,
                                   null,
                                   null,
                                   null);
          IF pag_cta.G_COD_ERROR != 0 THEN
            p_error                := 'S';
            p_nombreRespuesta      := 'PAG_CTA_ERROR';
            p_descripcionRespuesta := 'Error al Generar Movimiento';
            PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_IN_724',
                                  'Error: ' || pag_cta.G_COD_ERROR || ' ' ||
                                  pag_cta.G_MSJ_ERROR,
                                  null,
                                  v_nro_cta_debito);
            rollback to CashIn724;
            -----------------------------------------------------------------------------------------------
          ELSE
            ----------------------------------------------------------
            pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                     p_fec_valor      => trunc(sysdate),
                                     p_cod_tra_padre  => v_cod_tra_padre,
                                     p_estado         => 'N',
                                     p_reversado      => 'N',
                                     p_nro_secuencia  => v_numero_secuencia,
                                     p_est_cuenta     => null,
                                     p_cod_ofi_origen => 61,
                                     p_cod_mod_padre  => v_codigo_modulo,
                                     p_cod_mad_padre  => v_codigo_modalidad);
            ------------------------------------------------------------
            v_nro_secuencia := v_nro_secuencia;
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.pr_act_operacion(v_cta_com_tigo,
                                     v_hora,
                                     'C',
                                     v_cod_mon_credito_com,
                                     v_comision,
                                     v_cod_tra_padre,
                                     v_cod_tra_com,
                                     v_nro_documento,
                                     null,
                                     v_cod_ofi_credito_com,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Credito por comisiones CashIn Tigo ' ||
                                     v_cta_com_tigo,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     null);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA_ERROR';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_IN_724',
                                    'Error: ' || pag_cta.G_COD_ERROR || ' ' ||
                                    pag_cta.G_MSJ_ERROR,
                                    null,
                                    v_cta_com_tigo);
              rollback to CashIn724;
              -----------------------------------------------------------------------------------------------
            END IF;
            ----------------------------------------------------------
            pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                     p_fec_valor      => trunc(sysdate),
                                     p_cod_tra_padre  => v_cod_tra_padre,
                                     p_estado         => 'N',
                                     p_reversado      => 'N',
                                     p_nro_secuencia  => v_numero_secuencia,
                                     p_est_cuenta     => null,
                                     p_cod_ofi_origen => 61,
                                     p_cod_mod_padre  => v_codigo_modulo,
                                     p_cod_mad_padre  => v_codigo_modalidad);
            ------------------------------------------------------------
            v_nro_secuencia := v_nro_secuencia;
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.pr_act_operacion(v_cta_ope_tigo,
                                     v_hora,
                                     'C',
                                     v_cod_mon_credito,
                                     p_monto,
                                     v_cod_tra_padre,
                                     v_cod_tra_cre,
                                     v_nro_documento,
                                     null,
                                     v_cod_ofi_credito,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Credito por CashIn Tigo ' ||
                                     v_cta_ope_tigo,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     null);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_nombreRespuesta      := 'PAG_CTA_ERROR';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_IN_724',
                                    'Error: ' || pag_cta.G_COD_ERROR || ' ' ||
                                    pag_cta.G_MSJ_ERROR,
                                    null,
                                    v_cta_ope_tigo);
              rollback to CashIn724;
              -----------------------------------------------------------------------------------------------
            END IF;
            ---------------------------------------------------------------------------------------------------
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            p_error                := 'S';
            p_nombreRespuesta      := 'ERROR_PROCESO';
            p_descripcionRespuesta := 'Error el proceso ' || sqlerrm;
            rollback to CashIn724;
        END;
      END IF;
      ---------------------------------------------------------------------------------------------------
    END IF;

    IF nvl(p_error, 'N') = 'N' THEN
      BEGIN
        Select trunc(t.fec_valor),
               trunc(t.fec_insercion),
               to_char(t.fec_insercion, 'hh24:mi:ss')
          into p_fechaProceso, p_fechaOperacion, p_horaOperacion
          from ge_movimientos t
         where t.cod_usuario = v_usuario
           and t.hora = v_hora
           and t.fecha = v_fecha_actual
           and t.nro_secuencia = 1;
        p_nroComprobante := v_nro_documento;
      EXCEPTION
        WHEN OTHERS THEN
          p_error                := 'S';
          p_nombreRespuesta      := 'ERROR_PROCESO';
          p_descripcionRespuesta := 'Error el proceso ' || sqlerrm;
      END;
    END IF;
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      RETURN;
  END;

  PROCEDURE pr_tigo_cash_out_724(p_nroCtaDebito         IN VARCHAR2,
                                 p_monto                IN NUMBER,
                                 p_tipOperacion         IN VARCHAR2,
                                 p_nroPedido            IN VARCHAR2,
                                 p_nroComprobante       out VARCHAR2,
                                 p_fechaProceso         out date,
                                 p_fechaOperacion       out date,
                                 p_horaOperacion        out VARCHAR2,
                                 p_error                out VARCHAR2,
                                 p_nombreRespuesta      out VARCHAR2,
                                 p_descripcionRespuesta out VARCHAR2) IS

    v_nro_cta_debito   VARCHAR2(16);
    v_cod_mon_credito  VARCHAR2(3);
    v_cod_mod_credito  NUMBER(4);
    v_cod_mad_credito  NUMBER(4);
    v_cod_ofi_credito  NUMBER(4);
    v_nro_documento    NUMBER(15);
    v_cod_operacion    VARCHAR2(3) := '302';
    v_nro_secuencia    NUMBER(3);
    v_codigo_modulo    NUMBER(3) := 3;
    v_codigo_modalidad NUMBER(3) := 31;
    v_numero_secuencia NUMBER(3) := 0;
    v_cod_tra_padre    NUMBER(4) := 9835;
    v_cod_tra_deb      NUMBER(4);
    v_cod_tra_cre      NUMBER(4);
    v_cod_tra_com      NUMBER(4);
    v_usuario          ge_movimientos.cod_usuario%type;
    v_hora             ge_movimientos.hora%TYPE;
    v_fecha_actual     DATE := it.pag_cal.fu_obt_fec_actual(1);
    v_cta_ope_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_OPE_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_cta_com_tigo     ge_movimientos.nro_cuenta%type := it.fug_obt_pardinamico('CTA_COM_TIGO',
                                                                                null,
                                                                                null,
                                                                                null);
    v_comision         ge_movimientos.monto%type := it.fug_obt_pardinamico('MTO_COM_TIGO',
                                                                           null,
                                                                           null,
                                                                           null);
    ------------------------------------------------------------------------------------
    v_cod_modulo          ge_cuentas.cod_modulo%type;
    v_cod_modalidad       ge_cuentas.cod_modalidad%type;
    v_cod_moneda          ge_cuentas.cod_moneda%type;
    v_cod_ofi_credito_com ge_cuentas.cod_oficina%type;
    v_cod_mon_credito_com ge_cuentas.cod_moneda%type;
    v_cod_mod_credito_com ge_cuentas.cod_modulo%type;
    v_cod_mad_credito_com ge_cuentas.cod_modalidad%type;
    ------------------------------------------------------------------------------------

  BEGIN

    pr_mensajeUsuario(MSG_OK,
                      p_nombreRespuesta,
                      p_descripcionRespuesta,
                      p_error);

    -- 0. inicializo la secuencia
    v_nro_secuencia  := 0;
    v_nro_cta_debito := depurarAlfanumerico(p_nroCtaDebito, CUENTA_TAMANO);

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_nro_cta_debito);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_moneda    := pag_cta.G_CTAS.cod_moneda;
        v_cod_modulo    := pag_cta.G_CTAS.COD_MODULO;
        v_cod_modalidad := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_cre := fug_obt_pardinamico('COD_TRA_CRE_TIGO',
                                             v_cod_modulo,
                                             v_cod_modalidad);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_ope_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_deb := fug_obt_pardinamico('COD_TRA_DEB_TIGO',
                                             v_cod_mod_credito,
                                             v_cod_mad_credito);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta ';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      pag_cta.PR_OBT_CUENTA(v_cta_com_tigo);

      IF nvl(pag_cta.G_COD_ERROR, 0) = 0 THEN
        v_cod_ofi_credito_com := pag_cta.G_CTAS.COD_OFICINA;
        v_cod_mon_credito_com := pag_cta.G_CTAS.cod_moneda;
        v_cod_mod_credito_com := pag_cta.G_CTAS.COD_MODULO;
        v_cod_mad_credito_com := pag_cta.G_CTAS.COD_MODALIDAD;
        --------------------
        v_cod_tra_com := fug_obt_pardinamico('COD_TRA_COM_TIGO',
                                             v_cod_mod_credito_com,
                                             v_cod_mad_credito_com);
      ELSE
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_CTA';
        p_descripcionRespuesta := 'Error al consultar cuenta Comision';
        RETURN;
      END IF;
    END IF;

    IF p_error = 'N' THEN
      --------------------------------------------------------------------------
      SELECT s_nro_documento.NEXTVAL INTO v_nro_documento FROM dual;
      savepoint CashOut724;
      ----------------------------------------------------------
      v_usuario := fu_obt_mov_user('TCASHOUT', 's_hor_mov_out');
      v_hora    := fu_obt_hora(v_usuario, 's_hor_mov_out');
      pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                               p_fec_valor      => trunc(sysdate),
                               p_cod_tra_padre  => v_cod_tra_padre,
                               p_estado         => 'N',
                               p_reversado      => 'N',
                               p_nro_secuencia  => v_numero_secuencia,
                               p_est_cuenta     => null,
                               p_cod_ofi_origen => 61,
                               p_cod_mod_padre  => v_codigo_modulo,
                               p_cod_mad_padre  => v_codigo_modalidad);
      ------------------------------------------------------------
      IF nvl(p_error, 'N') = 'N' THEN
        BEGIN
          --generar, debito cuenta operativa
          v_nro_secuencia := v_nro_secuencia;
          PAG_CTA.PR_SET_REFERENCIA(v_nro_documento);
          pag_cta.PR_NRO_CAJA(p_nro_caja => null);
          PAG_CTA.PR_SET_NRO_DOCUMENTO2(p_nroPedido || p_tipOperacion);
          PAG_CTA.PR_SET_NRO_DOCUMENTO3(v_cod_operacion);
          pag_cta.pr_act_operacion(p_nroCtaDebito,
                                   v_hora,
                                   'C',
                                   v_cod_moneda,
                                   p_monto,
                                   v_cod_tra_padre,
                                   v_cod_tra_cre,
                                   v_nro_documento,
                                   null,
                                   61,
                                   v_codigo_modulo,
                                   v_codigo_modalidad,
                                   null,
                                   null,
                                   'Credito CashOut Tigo ' ||
                                   p_nroCtaDebito,
                                   'N',
                                   v_nro_secuencia,
                                   v_fecha_actual,
                                   null,
                                   null,
                                   null);
          IF pag_cta.G_COD_ERROR != 0 THEN
            p_error                := 'S';
            p_descripcionRespuesta := 'Error al Generar Movimiento';
            PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_OUT_724',
                                  'Error: ' || pag_cta.G_COD_ERROR || ' ' ||
                                  pag_cta.G_MSJ_ERROR,
                                  null,
                                  v_cta_ope_tigo);
            rollback to CashOut724;
            -----------------------------------------------------------------------------------------------
          ELSE
            ----------------------------------------------------------
            pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                     p_fec_valor      => trunc(sysdate),
                                     p_cod_tra_padre  => v_cod_tra_padre,
                                     p_estado         => 'N',
                                     p_reversado      => 'N',
                                     p_nro_secuencia  => v_numero_secuencia,
                                     p_est_cuenta     => null,
                                     p_cod_ofi_origen => 61,
                                     p_cod_mod_padre  => v_codigo_modulo,
                                     p_cod_mad_padre  => v_codigo_modalidad);
            ------------------------------------------------------------
            v_nro_secuencia := v_nro_secuencia;
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.pr_act_operacion(v_cta_com_tigo,
                                     v_hora,
                                     'D',
                                     v_cod_mon_credito_com,
                                     v_comision,
                                     v_cod_tra_padre,
                                     v_cod_tra_com,
                                     v_nro_documento,
                                     null,
                                     v_cod_ofi_credito_com,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Credito por comisiones CashOut Tigo ' ||
                                     v_cta_com_tigo,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     null);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_OUT_724',
                                    'Error: ' || pag_cta.G_COD_ERROR || ' ' ||
                                    pag_cta.G_MSJ_ERROR,
                                    null,
                                    v_cta_ope_tigo);
              rollback to CashOut724;
            -----------------------------------------------------------------------------------------------
            END IF;
            ----------------------------------------------------------
            pag_cta.pr_set_variables(p_cod_usuario    => v_usuario,
                                     p_fec_valor      => trunc(sysdate),
                                     p_cod_tra_padre  => v_cod_tra_padre,
                                     p_estado         => 'N',
                                     p_reversado      => 'N',
                                     p_nro_secuencia  => v_numero_secuencia,
                                     p_est_cuenta     => null,
                                     p_cod_ofi_origen => 61,
                                     p_cod_mod_padre  => v_codigo_modulo,
                                     p_cod_mad_padre  => v_codigo_modalidad);
            ------------------------------------------------------------
            v_nro_secuencia := v_nro_secuencia;
            pag_cta.PR_NRO_CAJA(p_nro_caja => null);
            pag_cta.pr_act_operacion(v_cta_ope_tigo,
                                     v_hora,
                                     'D',
                                     v_cod_mon_credito,
                                     p_monto,
                                     v_cod_tra_padre,
                                     v_cod_tra_deb,
                                     v_nro_documento,
                                     null,
                                     v_cod_ofi_credito,
                                     v_codigo_modulo,
                                     v_codigo_modalidad,
                                     null,
                                     null,
                                     'Credito por CashOut Tigo ' ||
                                     v_cta_ope_tigo,
                                     'N',
                                     v_nro_secuencia,
                                     v_fecha_actual,
                                     null,
                                     null,
                                     null);
            IF pag_cta.G_COD_ERROR != 0 THEN
              p_error                := 'S';
              p_descripcionRespuesta := 'Error al Generar Movimiento';
              PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_OUT_724',
                                    'Error: ' || pag_cta.G_COD_ERROR || ' ' ||
                                    pag_cta.G_MSJ_ERROR,
                                    null,
                                    v_cta_ope_tigo);
              rollback to CashOut724;
              -----------------------------------------------------------------------------------------------
            END IF;
            ---------------------------------------------------------------------------------------------------
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            p_error                := 'S';
            p_nombreRespuesta      := 'ERROR_PROCESO';
            p_descripcionRespuesta := 'Error en el proceso CashOut';
            PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_OUT_724',
                                  'Error: ' || sqlerrm,
                                  null,
                                  v_cta_ope_tigo);
            rollback to CashOut724;
        END;

      END IF;
      ---------------------------------------------------------------------------------------------------
    END IF;

    IF nvl(p_error, 'N') = 'N' THEN
      BEGIN
        Select trunc(t.fec_valor),
               trunc(t.fec_insercion),
               to_char(t.fec_insercion, 'hh24:mi:ss')
          into p_fechaProceso, p_fechaOperacion, p_horaOperacion
          from ge_movimientos t
         where t.cod_usuario = v_usuario
           and t.hora = v_hora
           and t.fecha = v_fecha_actual
           and t.nro_secuencia = 1;
        p_nroComprobante := v_nro_documento;
      EXCEPTION
        WHEN OTHERS THEN
          p_error                := 'S';
          p_nombreRespuesta      := 'ERROR_PROCESO';
          p_descripcionRespuesta := 'Error al Obtener Datos de Movimiento';
          PRG_INS_LOG_PROGRAMAS('PAW_TIG.PR_TIGO_CASH_OUT_724',
                                'Obtener Datos de Movimiento, Error: ' ||
                                sqlerrm,
                                null,
                                v_cta_ope_tigo);
      END;
    END IF;
    RETURN;
  EXCEPTION
    WHEN OTHERS THEN
      pr_mensajeUsuario(MSG_ERROR,
                        p_nombreRespuesta,
                        p_descripcionRespuesta,
                        p_error);
      RETURN;
  END;

  procedure pr_gen_rev_operacion(p_tipOperacion         in varchar2,
                                 p_mov_id               in varchar2,
                                 p_error                out VARCHAR2,
                                 p_nombreRespuesta      out VARCHAR2,
                                 p_descripcionRespuesta out VARCHAR2) is

    v_fecha         ge_movimientos.fecha%type;
    v_hora          ge_movimientos.hora%type;
    v_usuario       ge_movimientos.cod_usuario%type;
    v_cod_mod_padre ge_movimientos.cod_mod_padre%type;
    v_cod_mad_padre ge_movimientos.cod_mad_padre%type;
    v_cod_tra_padre ge_movimientos.cod_tra_padre%type;
    v_det_error     ge_log_errores.det_error%type;
    v_nro_documento ge_movimientos.nro_documento%type;
    v_concepto      ge_movimientos.concepto%type;
    v_hora_rev      ge_movimientos.hor_reversion%type;
    v_existe        varchar2(1);

  BEGIN
    BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    END;
    BEGIN
      select 'S',
             t.fecha,
             t.hora,
             t.cod_usuario,
             t.cod_mod_padre,
             t.cod_mad_padre,
             t.cod_tra_padre,
             t.nro_documento,
             t.concepto
        into v_existe,
             v_fecha,
             v_hora,
             v_usuario,
             v_cod_mod_padre,
             v_cod_mad_padre,
             v_cod_tra_padre,
             v_nro_documento,
             v_concepto
        from ge_movimientos t
       where t.reversado = 'N'
         and rownum = 1
         and t.referencia = p_mov_id
         and t.nro_documento3 = p_tipOperacion;
    EXCEPTION
      WHEN no_data_found THEN
        v_existe               := 'N';
        p_error                := 'S';
        p_nombreRespuesta      := 'ERROR_CONS_MOV';
        p_descripcionRespuesta := 'No se encuentra el movimiento a reversar';

    END;
    savepoint reversion;
    IF v_existe = 'S' THEN
      BEGIN
        v_hora_rev := fug_obt_mov_hora;
        it.prg_rev_operacion(p_fecha             => v_fecha,
                             p_hora              => v_hora,
                             p_cod_usuario       => v_usuario,
                             p_cod_mod_padre     => v_cod_mod_padre,
                             p_cod_mad_padre     => V_cod_mad_padre,
                             p_cod_tra_padre     => v_cod_tra_padre,
                             p_cod_usu_reversion => substr(user, 1, 10),
                             p_hor_reversion     => v_hora_rev,
                             p_es_nocturno       => 'N',
                             p_concepto          => 'REVERSION TIGO',
                             p_nro_ncredito      => null);

        p_error                := 'N';
        p_nombreRespuesta      := 'OP_APROBADA';
        p_descripcionRespuesta := 'Se ha generado los movimientos de Reversa';
      EXCEPTION
        WHEN OTHERS THEN
          p_error                := 'S';
          p_nombreRespuesta      := 'ERROR_PROCESO';
          p_descripcionRespuesta := 'Error en el proceso de Reversa ';
          rollback to reversion;
      END;
    END IF;

    IF nvl(p_error, 'N') != 'N' THEN
      v_det_error := 'Referencia : ' || p_mov_id || ' Error: Cod. ' ||
                     p_error || '-' || p_descripcionRespuesta;
      PRG_INS_LOG_PROGRAMAS('pr_gen_rev_operacion',
                            v_det_error,
                            null,
                            null);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      v_det_error            := 'Referencia : ' || p_mov_id ||
                                ' Error: Cod. ' || p_error || '- ' ||
                                sqlerrm;
      p_error                := 'S';
      p_nombreRespuesta      := 'ERROR_PROCESO';
      p_descripcionRespuesta := 'Error en el proceso de Reversa ';
      PRG_INS_LOG_PROGRAMAS('pr_gen_rev_operacion',
                            v_det_error,
                            null,
                            null);
  END pr_gen_rev_operacion;

BEGIN
  pre_cam_for_numerico('.,');
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 9;
END paw_tig;
/