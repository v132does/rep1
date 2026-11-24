CREATE OR REPLACE PACKAGE BODY IT.paw_seg IS

   g_mensaje_claac VARCHAR2(150) := fug_obt_parentes(6331, 'COD_MEA_CLA_FACIL');
   g_mensaje_trans VARCHAR2(150) := fug_obt_parentes(6331, 'COD_MET_CLA_FACIL');
   g_mensaje_token VARCHAR2(150) := fug_obt_parentes(6331, 'COD_MEK_CLA_FACIL');

   /** Codigo de respuesta OK generico */
   MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA' ;
   /** Codigo de error generico, Ej. excepciones no manejadas */
   MSG_ERROR CONSTANT VARCHAR2(30) := 'OP_ERROR';
   /** Constantes de tipo de Bitácora */
   BITACORA_ENTRADA       CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_ERROR         CONSTANT VARCHAR2(3) := 'ERR';
   BITACORA_SALIDA        CONSTANT VARCHAR2(3) := 'SAL';
   MAX_TIEMPO_INACTIVIDAD CONSTANT NUMBER(3)   := 0; --minutos; -- 15 minutos
   MAX_TIEMPO_TOKEN       NUMBER(3):= fug_obt_pardinamico('MAX_TIEMPO_TOKEN', NULL, NULL); -- := 5; --minutos; -- 15 minutos
   MSG_PERNOEXIST         CONSTANT VARCHAR2(15) := 'PER_NOEXISTE';
   MSG_NOTARJETA          CONSTANT VARCHAR2(15) := 'TARJ_NOEXISTE';
   MSG_NOPERFISICA        CONSTANT VARCHAR2(15) := 'PER_NOFISICA';
   MSG_PARAM_INCORR       CONSTANT VARCHAR2(15) := 'PARAM_INCORRECT';
   MSG_NOPOSEECLACCESO    CONSTANT VARCHAR2(15) := 'P_PER_NOCLAACCE';
   MSG_NOSOLICITUD        CONSTANT VARCHAR2(15) := 'P_PER_NO_SOLI';
   MSG_CLAESTNOVAL        CONSTANT VARCHAR2(15) := 'P_PER_CLATNOVAL';
   MSG_INACT_ERROR        CONSTANT VARCHAR2(15) := 'CLFA_TIE_INACT';
   MSG_TOKEN_INV          CONSTANT VARCHAR2(15) := 'CLFA_TOK_INVAL';
   MSG_TEL_NOVAL       CONSTANT VARCHAR2(15) := 'CLFA_TEL_NOVAL';
   v_cod_canal            VARCHAR2(3) := '999';

   --Funcion que sera utilizada para validar datos del cliente antes de que
   --el sitio le permita ingresar su clave nueva.
FUNCTION fu_valDatosSolNuevaClave(p_TipoDocumento IN NUMBER, p_nroDocumento IN VARCHAR2, p_fechaNacimiento IN DATE,
                                  p_TipoTarjeta IN VARCHAR2, p_nroTarjeta IN VARCHAR2, p_Origen IN VARCHAR2,
                                  p_dato_adicional IN VARCHAR2, p_nro_ip IN VARCHAR2,
                                  p_tip_clave IN VARCHAR2 DEFAULT NULL) RETURN typ_solicitudNuevaClave IS
  v_token           VARCHAR2(200);
  v_TipoDocumento   NUMBER(3);
  v_nroDocumento    VARCHAR2(20);
  v_fechaNacimiento DATE;
  v_TipoTarjeta     VARCHAR2(1);
  v_nroTarjeta      VARCHAR2(19);
  v_nroTarjetaFull  VARCHAR2(19);
  v_Origen          VARCHAR(200);
  v_numOrigen       NUMBER(1); --activacion de solicitud claves
  v_parDinamico     VARCHAR2(30); --activacion de solicitud  claves
  v_estadoSolClave  VARCHAR2(1); --activacion de solicitud  claves
  v_retorno         typ_solicitudNuevaClave := typ_solicitudNuevaClave;
  v_salt            NUMBER;
  v_codPersol       VARCHAR2(10);
  v_tope            DATE;
  v_fec_nac         DATE;
  v_fec_hora        DATE := SYSDATE;
  v_dato_adicional  VARCHAR2(8);
  v_dato_adi        VARCHAR2(8);
  v_nro_ip          VARCHAR2(15);
  v_tip_clave       VARCHAR2(1);
  MSG_NOFECNAC CONSTANT VARCHAR2(15) := 'PER_NOFECNAC';
  v_cod_oficina ge_clientes.cod_oficina%TYPE;
  v_tip_tar_debito  ah_tar_debitos.tip_tar_debito%TYPE;

  PROCEDURE lp_reg_sol(p_codPersol IN VARCHAR2, p_TipoDocumento IN NUMBER, p_fechaNacimiento IN DATE,
                       p_TipoTarjeta IN VARCHAR2, p_nroTarjeta IN VARCHAR2, p_Origen IN VARCHAR2, p_token IN VARCHAR2,
                       p_nro_ip IN VARCHAR2, p_cod_canal IN VARCHAR2, p_cod_oficina IN VARCHAR2, p_tip_clave IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
  BEGIN
    INSERT INTO bw_sol_claves
      (cod_persona, tipo_documento, nro_documento, fec_nacimiento, tip_tarjeta, nro_tarjeta, cod_origen, token, estado,
       fec_verificacion, nro_ip, cod_canal, cod_oficina, tipo)
    VALUES
      (p_codPersol, p_TipoDocumento, p_nroDocumento, p_fechaNacimiento, p_TipoTarjeta, p_nroTarjeta, p_Origen, p_token,
       'S', SYSDATE, p_nro_ip, p_cod_canal, p_cod_oficina, p_tip_clave);
    COMMIT;
  END;
  FUNCTION lf_obt_origen(p_origen IN VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF (p_origen = 'TIRICA') THEN
      RETURN 1;
    ELSIF (p_origen = 'WEB') THEN
      RETURN 2;
    ELSIF (p_origen = 'android' OR p_origen = 'iphone' OR p_origen = 'huawei') THEN
      RETURN 3;
    END IF;
    RETURN 0;
  END;

  FUNCTION lf_obt_par_activo(p_tipClave IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF (p_tipClave = 'A') THEN
      RETURN 'SOL_CLA_ACC_ESTADO';
    ELSIF (p_tipClave = 'K') THEN
      RETURN 'SOL_CLA_DIN_ESTADO';
    ELSIF (p_tipClave = 'T') THEN
      RETURN 'SOL_CLA_TRA_ESTADO';
    END IF;
    RETURN NULL;
  END;

BEGIN
  --Sanitizacion de variables
  v_TipoDocumento   := p_TipoDocumento; --paw_bem.depurarAlfanumerico(p_TipoDocumento, 1); --Tipo de documento
  v_nroDocumento    := p_nroDocumento; --Nro de documento
  v_fechaNacimiento := p_fechaNacimiento; --Fecha de nacimiento
  v_TipoTarjeta     := substr(upper(p_TipoTarjeta), 1, 1); --Tipo de tarjeta 'D' inicialmente
  --v_nroTarjeta      := paw_bem.depurarAlfanumerico(p_nroTarjeta, 16); -- Nro. de tarjeta
  v_Origen         := paw_bem.depurarAlfanumerico(p_origen, 200); --Origen
  v_token          := paw_bem.depurarAlfanumerico(v_token, 32); -- token
  v_dato_adicional := paw_bem.depurarNumerico(p_dato_adicional, 8); --dato adicional de la tarjeta de débito
  -- v_nroTarjeta      := substr(v_nroTarjeta,length(v_nroTarjeta)-4+1);
  v_nro_ip     := p_nro_ip; -- Nro. Ip
  v_nroTarjeta := p_nroTarjeta; -- Nro. de tarjeta
  v_tip_clave  := nvl(p_tip_clave, 'A');
  --Validar que la persona exista, sea titular y tenga estado 'V' Verificado

  IF (v_Origen IN ('TIRICA', 'WEB', 'iphone', 'android', 'huawei')) THEN
    v_numOrigen      := lf_obt_origen(v_Origen);
    v_parDinamico    := lf_obt_par_activo(v_tip_clave);
    v_estadoSolClave := upper(TRIM(nvl(fug_obt_pardinamico(v_parDinamico, v_numOrigen), 'S')));
    IF (v_estadoSolClave = 'S') THEN
      paw_uti.pr_mensajeUsuario('SOL_DESAC_' || v_tip_clave, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);

        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '519', NULL,
                                    'SOL_DESAC_' || v_tip_clave ||
                                     paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);

      RETURN v_retorno;
    END IF;
  END IF;

  IF v_TipoDocumento >= 0 THEN
    BEGIN
      SELECT DISTINCT p.cod_persona, c.cod_oficina
      INTO v_codPersol, v_cod_oficina
      FROM ba_personas p, ge_clientes c, ge_cta_clientes cta
      WHERE p.cod_persona = c.cod_persona
      AND p.cod_persona = cta.cod_persona
      AND c.cod_persona = cta.cod_persona
           --            and p.est_verificacion = 'V'
      AND cta.relacion IN ('P', 'O', 'Y') --(P)Principal, (O)Indistinta, (Y)Conjunta
      AND p.nro_documento = v_nroDocumento
      AND p.cod_tip_documento = v_TipoDocumento;
      --DYDMR-3011, Jesus Oviedo(xpy0053) se agrega filtro por el tipo de documento
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        paw_uti.pr_mensajeUsuario(MSG_PERNOEXIST, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '519', NULL,
                                    'Persona no existe. ' ||
                                     paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
        RETURN v_retorno;
    END;
  ELSE
    BEGIN
      SELECT DISTINCT p.cod_persona, c.cod_oficina
      INTO v_codPersol, v_cod_oficina
      FROM ba_personas p, ge_clientes c, ge_cta_clientes cta
      WHERE p.cod_persona = c.cod_persona
      AND p.cod_persona = cta.cod_persona
      AND c.cod_persona = cta.cod_persona
           --    and p.est_verificacion = 'V'
      AND relacion IN ('P', 'O', 'Y') --and cta.relacion = 'P'
      AND p.cod_persona = v_nroDocumento;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        paw_uti.pr_mensajeUsuario(MSG_PERNOEXIST, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '519', NULL,
                                    'Persona no existe. ' ||
                                     paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
        RETURN v_retorno;
    END;
  END IF;
  --Si existe persona verifica que tenga tarjeta de débito en estado Activo*/
  BEGIN
    SELECT d.cod_persona, d.nro_tarjeta,d.tip_tar_debito
    INTO v_codPersol, v_nroTarjetaFull,v_tip_tar_debito
    FROM ah_tar_debitos d, ge_cta_clientes c
    WHERE d.nro_tarjeta LIKE v_nroTarjeta
    AND d.nro_cuenta = c.nro_cuenta
    AND c.relacion IN ('P', 'O', 'Y') --(P)Principal, (O)Indistinta, (Y)Conjunta
    and d.tar_activa IN ('S', 'M') -- (M) Migrado
    AND c.cod_persona = d.cod_persona
    AND d.cod_persona = v_codPersol
    AND d.fec_vencimiento > SYSDATE
   -- AND d.fec_cancelacion IS NULL
    AND d.fec_ingreso = (SELECT MAX(a.fec_ingreso)
                        FROM ah_tar_debitos a
                        WHERE a.nro_cuenta = d.nro_cuenta
                        AND a.cod_persona = d.cod_persona
            and a.nro_tarjeta=d.nro_tarjeta);   --DDEVOLUT-1298--Ajuste por rebranding
    --            AND d.adherente='00';

   -- DDSI-2132 - Cuando la tarjeta es infonet se agrega el digito faltante para coincidir con Bancard
   if v_tip_tar_debito in ('I','L')  then
        v_retorno.nroTarjeta := substr(v_nroTarjetaFull,1,6)||'0'||substr(v_nroTarjetaFull,7);
   else
        v_retorno.nroTarjeta := v_nroTarjetaFull;
   end if;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      paw_uti.pr_mensajeUsuario(MSG_NOTARJETA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '520', NULL,
                                  'No posee Tarjeta en estado activo. ' ||
                                   paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                              v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
      RETURN v_retorno;
  END;
  IF (upper(p_Origen) <> 'ATM') THEN
    --Verifica que el dato adicional ingresado sea el correcto
    BEGIN
      SELECT '007' || decode(a.cod_moneda, 'GS', '0', '1') || d.adherente || d.nro_emision
      INTO v_dato_adi
      FROM ah_tar_debitos d, ge_cta_clientes c, ge_cuentas a
      WHERE d.cod_persona = v_codPersol
      AND d.nro_tarjeta LIKE v_nroTarjeta
      AND d.nro_cuenta = c.nro_cuenta
      AND a.nro_cuenta = c.nro_cuenta
      AND a.nro_cuenta = d.nro_cuenta
      AND c.cod_persona = d.cod_persona
      AND c.relacion IN ('P', 'O', 'Y') --(P)Principal, (O)Indistinta, (Y)Conjunta
      and d.tar_activa IN ('S', 'M') -- (M) Migrado
      AND d.fec_vencimiento > SYSDATE
      --AND d.fec_cancelacion IS NULL
      AND d.fec_ingreso = (SELECT MAX(a.fec_ingreso)
                          FROM ah_tar_debitos a
                          WHERE a.nro_cuenta = d.nro_cuenta
                          AND a.cod_persona = d.cod_persona
              and a.nro_tarjeta=d.nro_tarjeta);    --DDEVOLUT-1298--Ajuste por rebranding
      --            AND d.adherente='00';
      IF v_dato_adi IS NOT NULL THEN
        IF v_dato_adi <> v_dato_adicional THEN
          paw_uti.pr_mensajeUsuario(MSG_NOTARJETA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                    v_retorno.error);
          paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '528', NULL,
                                      'No coincide dato adicional. ' ||
                                       paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                  v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
          RETURN v_retorno;
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '527', NULL,
                                    'Others en datos adicionales. ' ||
                                     paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
        RETURN v_retorno;
    END;
  END IF;
  --Verifica que la persona esté cargada en ba_per_fisicas
  BEGIN
    SELECT f.cod_persona, f.fec_nacimiento
    INTO v_codPersol, v_fec_nac
    FROM ba_per_fisicas f
    WHERE f.cod_persona = v_codPersol;
    IF v_fec_nac <> v_fechaNacimiento THEN
      paw_uti.pr_mensajeUsuario(MSG_NOFECNAC, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '521', NULL,
                                  'No corresponde fecha de nacimiento. ' ||
                                   paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                              v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
      RETURN v_retorno;
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      paw_uti.pr_mensajeUsuario(MSG_NOPERFISICA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                v_retorno.error);
      paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, NULL, '522', NULL,
                                  'No está registrado en ba_per_fisicas. ' ||
                                   paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                              v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
      RETURN v_retorno;
  END;
  --Se recupera ultimo acceso de la persona de bw_sol_claves
  BEGIN
    SELECT MAX(sol.fec_verificacion + (MAX_TIEMPO_INACTIVIDAD / 1440))
    INTO v_tope
    FROM bw_sol_claves sol
    WHERE sol.cod_persona = v_codPersol;
    --Verificar que no ingrese solicitud en menos de 15 min. el mismo cliente
    IF v_tope < v_fec_hora THEN
      v_salt  := round(dbms_random.VALUE(1000000, 9999999));
      v_token := v_salt || v_nroDocumento;
      v_token := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_token)));
      --Se inserta en la tabla bw_sol_claves
      lp_reg_sol(v_codPersol, v_TipoDocumento, v_fechaNacimiento, v_TipoTarjeta, v_nroTarjeta, v_Origen, v_token,
                 v_nro_ip, v_cod_canal, v_cod_oficina, v_tip_clave);
      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, v_token, '523', NULL,
                                  'Se insertó correctamente en bw_sol_claves. ' ||
                                   paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                              v_retorno.descripcionRespuesta, NULL), BITACORA_SALIDA);
      v_retorno.token := v_token;
    ELSE
      IF v_tope IS NULL THEN
        v_salt  := round(dbms_random.VALUE(1000000, 9999999));
        v_token := v_salt || p_nroDocumento;
        v_token := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_token)));
        /*Se inserta en la tabla bw_sol_claves*/
        lp_reg_sol(v_codPersol, v_TipoDocumento, v_fechaNacimiento, v_TipoTarjeta, v_nroTarjeta, v_Origen, v_token,
                   v_nro_ip, v_cod_canal, v_cod_oficina, v_tip_clave);
        paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, v_token, '524', NULL,
                                    paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_SALIDA);
        v_retorno.token := v_token;
      END IF;
      IF v_tope = v_fec_hora THEN
        v_salt  := round(dbms_random.VALUE(1000000, 9999999));
        v_token := v_salt || p_nroDocumento;
        v_token := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_token)));
        /*Se inserta en la tabla bw_sol_claves*/
        lp_reg_sol(v_codPersol, v_TipoDocumento, v_fechaNacimiento, v_TipoTarjeta, v_nroTarjeta, v_Origen, v_token,
                   v_nro_ip, v_cod_canal, v_cod_oficina, v_tip_clave);
        paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, v_token, '524', NULL,
                                    paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_SALIDA);
        v_retorno.token := v_token;
      END IF;
      IF v_tope > v_fec_hora THEN
        paw_uti.pr_mensajeUsuario(MSG_INACT_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, v_token, '505', NULL,
                                    paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                                v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
      END IF;
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_salt  := round(dbms_random.VALUE(1000000, 9999999));
      v_token := v_salt || p_nroDocumento;
      v_token := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_token)));
      --Se inserta en la tabla bw_sol_claves
      lp_reg_sol(v_codPersol, v_TipoDocumento, v_fechaNacimiento, v_TipoTarjeta, v_nroTarjeta, v_Origen, v_token,
                 v_nro_ip, v_cod_canal, v_cod_oficina, v_tip_clave);
      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      paw_uti.pr_insertarBitacora(nvl(v_nroDocumento, '999'), v_cod_canal, v_token, '525', NULL,
                                  paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,
                                                              v_retorno.descripcionRespuesta, NULL), BITACORA_SALIDA);
      v_retorno.token := v_token;
  END;
  RETURN v_retorno;
END;

   -- generar claves para un cliente, si existe modificarla, si no, crear.
   FUNCTION fu_gen_Clave(p_cod_persona IN VARCHAR2, p_cod_per_vinculada IN VARCHAR2, p_clave IN OUT VARCHAR2, p_estado IN VARCHAR2, p_tip_clave IN VARCHAR2) RETURN NUMBER IS
      v_msj_bitacora        VARCHAR2(400) := 'codPer:' || p_cod_Persona || ', tipCla:' || p_tip_clave|| ', Clave/Cel:' || p_clave;
      v_salt              NUMBER := round(dbms_random.value(1000000, 9999999));
      v_clave             VARCHAR(200);
      v_retorno           typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_cod_persona       varchar2(10);
      v_cod_per_vinculada varchar2(10);
      v_estado            varchar2(1); -- Estado en el cual crear la clave 'A' o 'M'
      v_tip_clave         varchar2(1); --'A': Acceso 'T' Transaccional
      v_clave_acceso        VARCHAR2(10);
      v_clave_valido      varchar2(10);
      v_clave_transaccional VARCHAR2(10);
      v_tipo                bw_otp_seriales.tipo%TYPE := 'V';
      v_cod_oficina         bw_otp_seriales.cod_oficina%TYPE;
      v_vas_usuario         number(3);
      --Variables validaciones token
      v_verif_exis_token NUMBER(3);
      v_nro_serial       bw_otp_seriales.nro_serial%TYPE;
      v_tok_virtual      NUMBER(3);
      v_tok_vasco        VARCHAR2(10);
      v_val_clave        VARCHAR2(1):= 'S';
      v_celular          ba_telefonos.telefono%TYPE;
      v_cel_md5          VARCHAR2(32);
      v_per_cumple       VARCHAR2(6);
      v_per_cump_md5     VARCHAR2(32);
      --Mensaje de error
      MSG_CLA_DUPLICA CONSTANT VARCHAR2(15) := 'G_CLA_DUPLICADA';

   PROCEDURE lp_pro_perfil(p_cod_persona IN VARCHAR2) IS
      v_perfil ge_clientes.cod_perfil%type;
   BEGIN
         SELECT cod_perfil
           INTO v_perfil
           FROM ge_clientes
          WHERE cod_persona = p_cod_persona;

         IF v_perfil IS NULL OR length(v_perfil) < 2 THEN
            UPDATE ge_clientes
               SET cod_perfil = 'FULL'
             WHERE cod_persona = p_cod_persona;
         END IF;
      END;
   BEGIN
      --Sanitizar variables
      v_cod_persona       := paw_bem.depurarAlfanumerico(p_cod_persona, 10); -- Codigo de persona
      v_cod_per_vinculada := paw_bem.depurarAlfanumerico(p_cod_per_vinculada, 10); -- Codigo de persona vinculada
      v_clave             := paw_bem.depurarAlfanumerico(p_clave, 32); -- Clave
      v_estado            := nvl(p_estado, 'M'); -- Estado en el cual crear la clave 'A' o 'M'
      v_tip_clave         := substr(upper(p_tip_clave), 1, 1); --'A': Acceso 'T' Transaccional


      --Validación de claves Acceso-Trasaccional
      IF v_tip_clave IN ('A', 'T') THEN
      /*13-08-2014 Valida que una clave transaccional no se repita
           S: la clave es válida para usar, N: caso contrario*/
         v_val_clave := paw_bce.fu_val_vul_claves(v_cod_persona, p_clave);
         IF v_val_clave = 'N' THEN
            paw_uti.pr_mensajeUsuario(MSG_CLA_DUPLICA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, NULL, '542', NULL, 'Clave '||v_tip_clave||' repetida.Verificar. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
            RETURN 2;
         END IF;

       /*13-08-2014 Valida que el número de celular no sea igual al de la clave*/
         v_celular := paw_seg.fu_obt_celular(v_cod_persona);
         IF v_celular IS NOT NULL THEN
           v_cel_md5 := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => substr(v_celular, length(v_celular) - 5))));
           IF v_cel_md5 IS NOT NULL and v_cel_md5 = upper(v_clave) THEN
             paw_uti.pr_mensajeUsuario(MSG_CLA_DUPLICA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, NULL, '543', NULL, 'Nro. de celuar igual al de la clave.Verificar. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
             RETURN 2;
           END IF;
         END IF;
       /*13-08-2014 Valida que la fecha de nacimiento no sea igual al de la clave*/
       BEGIN
         SELECT to_char(a.fec_nacimiento, 'ddmmyy')
           INTO v_per_cumple
           FROM ba_per_fisicas a
          WHERE a.cod_persona = v_cod_persona;
       END;
       IF v_per_cumple IS NOT NULL THEN
          v_per_cump_md5 := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_per_cumple)));
          IF upper(v_clave) = v_per_cump_md5 THEN
            paw_uti.pr_mensajeUsuario(MSG_CLA_DUPLICA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, NULL, '544', NULL, 'Fecha de nacimiento igual a la clave.Verificar. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
            RETURN 2;
          END IF;
       END IF;
      END IF;

      -- verificamos el parametro
      IF v_tip_clave NOT IN ('A', 'T', 'K') THEN
         paw_uti.pr_mensajeUsuario(MSG_PARAM_INCORR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(nvl(v_cod_Persona, '999'),
                                     v_cod_canal,
                                     NULL,
                                     '509',
                                     NULL,
                                     'Tipo de Clave no es ni A ni T ' || v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                     BITACORA_ERROR);
         RETURN 1;
      ELSIF v_tip_clave = 'T' THEN
         /*Si tipo Clave es 'T' valido que tenga clave de Acceso*/
         BEGIN
               select f.cod_persona
              INTO v_clave_acceso
                 from bw_ope_claves f
             WHERE f.cod_persona = v_cod_persona
               AND f.cod_per_vinculada IS NULL --AGREGADO 06-08-2014
                  and f.tip_clave = 'A';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               paw_uti.pr_mensajeUsuario(MSG_CLAESTNOVAL, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_Persona, v_cod_canal, NULL, '510', NULL, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
               RETURN 1;
         END;
         v_clave := v_salt || '|' || v_clave;
         v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
         --Si existe clave de Acceso, preguntamos si ya tiene clave Transaccional
         IF v_clave_acceso IS NOT NULL THEN
            BEGIN
               SELECT f.cod_persona
                 INTO v_clave_transaccional
                 FROM bw_ope_claves f
                WHERE f.cod_persona = v_cod_persona
                  AND f.cod_per_vinculada  IS NULL --AGREGADO 06-08-2014
                  AND f.tip_clave = 'T';
               --Se actualiza la tabla de claves
               UPDATE bw_ope_claves z
                  SET z.clave = v_clave, z.cla_verificador = v_salt, z.est_clave = 'M', z.fec_est_clave = SYSDATE, z.fec_cam_clave = SYSDATE, z.fec_ult_acceso = SYSDATE, z.can_intentos = 0
                WHERE z.cod_persona = v_cod_persona
                  AND z.tip_clave LIKE 'T'
                  AND z.cod_per_vinculada IS NULL; --AGREGADO 06-08-2014
               paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(V_cod_Persona, v_cod_canal, NULL, '531', NULL, 'Se inserto correctamente. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_SALIDA);
               RETURN 0;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  INSERT INTO bw_ope_claves
                     (cla_verificador, clave, can_acceso, est_clave, cod_persona, cod_per_vinculada, tip_clave, fec_est_clave, fec_cam_clave, fec_ult_acceso, can_intentos)
                  VALUES
                     (v_salt, v_clave, 0, v_estado, v_cod_Persona, NULL, v_tip_clave, SYSDATE, SYSDATE, SYSDATE, 0);
                  paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_Persona,
                                           v_cod_canal,
                                           NULL,
                                              '529',
                                           NULL,
                                              'Se inserto correctamente. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                              BITACORA_SALIDA);
                  RETURN 0;
               WHEN OTHERS THEN
                  paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, NULL, '532', NULL, 'Others: ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
               RETURN 1;
         END;
         END IF;
      ELSIF v_tip_clave = 'A' THEN
         -- generamos o restablecemos la clave al cliente
         IF v_clave is null then
            --Si la clave es null entonces generamos
            v_clave := v_salt || '|' || lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave))));
            v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
            p_clave := v_clave;
            BEGIN
               INSERT INTO bw_ope_claves
                  (cla_verificador, clave, can_acceso, est_clave, cod_persona, cod_per_vinculada, tip_clave, can_intentos, fec_est_clave, fec_cam_clave)
               VALUES
                  (v_salt, v_clave, 0, v_estado, v_cod_Persona, NULL, v_tip_clave, 0, SYSDATE, SYSDATE);
               paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(nvl(v_cod_Persona, '999'),
                                           'N',
                                           NULL,
                                           '511',
                                           NULL,
                                           ' Se ha guardado correctamente la clave. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                           BITACORA_SALIDA);
               RETURN 0;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                              v_cod_canal,
                                              NULL,
                                              '526',
                                              NULL,
                                              'No se pudo realizar el insert' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                              BITACORA_ERROR);
            RETURN 1;
            END;
         ELSE
            v_clave := v_salt || '|' || v_clave;
            v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
            IF v_tip_clave = 'A' then
               --Existe en bw_ope_clave?
               lp_pro_perfil(v_cod_persona);
               BEGIN
                  SELECT f.cod_persona
                    INTO v_clave_valido
                    FROM bw_ope_claves f
                   WHERE f.cod_persona = v_cod_persona
                     AND f.cod_per_vinculada IS NULL --AGREGADO 06-08-2014
                     AND f.tip_clave = 'A';
               --Se actualiza la tabla de claves
                  UPDATE bw_ope_claves z
                     SET z.clave = v_clave, z.cla_verificador = v_salt, z.est_clave = 'M', z.fec_est_clave = SYSDATE, z.fec_cam_clave = SYSDATE, z.fec_ult_acceso = SYSDATE, z.can_intentos = 0
                   WHERE z.cod_persona = v_cod_persona
                     AND z.tip_clave LIKE 'A'
                     AND z.cod_per_vinculada IS NULL;
                  RETURN 0;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     BEGIN
                        INSERT INTO bw_ope_claves
                           (cla_verificador, clave, can_acceso, est_clave, cod_persona, cod_per_vinculada, tip_clave, fec_est_clave, fec_cam_clave, fec_ult_acceso, can_intentos)
                        VALUES
                           (v_salt, v_clave, 0, v_estado, v_cod_Persona, NULL, v_tip_clave, SYSDATE, SYSDATE, SYSDATE, 0);
                        paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                        paw_uti.pr_insertarBitacora(V_cod_Persona,
                                                    v_cod_canal,
                                                    NULL,
                                                    '504',
                                                    NULL,
                                                    'Se inserto correctamente. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                                    BITACORA_SALIDA);
                        RETURN 0;
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                           paw_uti.pr_insertarBitacora(v_cod_persona,
                                                       v_cod_canal,
                                                       NULL,
                                                       '512',
                                                       NULL,
                                                       'No se pudo completar el insert' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                                       BITACORA_ERROR);
                        RETURN 1;
                     END;
                 END;
            END IF;
         END IF;
      ELSE
         -- v_tipo_clave = 'K'
         v_cod_oficina := to_number(fug_obt_parentes(6331, 'COD_OFI_CLA_FACIL'));
         v_nro_serial  := paw_otp.fu_obt_tok_disponible(v_tipo, v_cod_oficina);
        -- v_nro_serial := '0091234599';

        --verificar que el token ya exista
        --09-09-2014
         BEGIN
            SELECT a.nro_serial
              INTO v_nro_serial
              FROM bw_otp_seriales a
             WHERE a.cod_persona = v_cod_persona
              AND a.tipo = 'V';
         EXCEPTION
            WHEN OTHERS THEN
               null;
         END;

          IF v_nro_serial is NULL then
            paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_Persona,
                                        v_cod_canal,
                                        NULL,
                                        '539',
                                        NULL,
                                        v_msj_bitacora || 'No existe token disponible para oficina '|| v_cod_oficina || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                        BITACORA_ERROR);
            RETURN 1;
          END IF;
         -- Verifica si ya tiene token virtual asignado, 0 si no posee serial asignado
         v_verif_exis_token := paw_otp.fu_ver_asi_toke_virtual(v_cod_persona);
       --  IF v_verif_exis_token = 0 THEN

           IF paw_otp.fu_vas_exi_usuario(v_cod_persona, NULL) = 0 THEN --Si es 0 ya existe el usuario
               v_tok_vasco := paw_otp.fu_vas_asi_token(v_cod_persona, null, v_nro_serial); --en vasco.
                --Capturar si el vasco da error
               IF v_tok_vasco = -1 THEN
                 paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(v_cod_Persona,
                                        v_cod_canal,
                                        NULL,
                                        '540',
                                        NULL,
                                        v_msj_bitacora || 'Error en la asignacion del usuario en vasco. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                        BITACORA_ERROR);
                  RETURN 1;
               END IF;
               v_tok_virtual := paw_otp.fu_asi_tok_virtual(v_cod_persona, p_clave, 'HB', v_nro_serial);
               paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_Persona,
                                        v_cod_canal,
                                        NULL,
                                        '540',
                                        NULL,
                                        v_msj_bitacora || 'Se ha generado clave token para la persona. ' || v_cod_persona || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                        BITACORA_SALIDA);
                p_clave := nvl(v_nro_serial,'');
               RETURN 0;
           ELSE
               v_vas_usuario := paw_otp.fu_vas_nue_usuario(v_cod_persona, NULL, p_clave, 'PAW_SEG');
               IF v_vas_usuario <> -14 THEN
                 v_tok_vasco := paw_otp.fu_vas_asi_token(v_cod_persona, null, v_nro_serial); --en vasco.
                 IF v_tok_vasco <> 0 THEN
                   paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                   paw_uti.pr_insertarBitacora(v_cod_Persona,
                                          v_cod_canal,
                                          NULL,
                                          '541',
                                          NULL,
                                          v_msj_bitacora || 'Error en la asignacion del usuario en vasco. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                          BITACORA_ERROR);
                    RETURN 1;
                 END IF;
                 v_tok_virtual := paw_otp.fu_asi_tok_virtual(v_cod_persona, p_clave, 'HB', v_nro_serial);
               END IF;


            paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_Persona,
                                        v_cod_canal,
                                        NULL,
                                        '536',
                                        NULL,
                                        v_msj_bitacora || 'Se ha generado clave token para la persona. ' || v_cod_persona || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL),
                                        BITACORA_SALIDA);
            p_clave := nvl(v_nro_serial,'');
            RETURN 0;
           END IF;
      END IF;
   END;
   --Guardar la clave ingresada o generada
   FUNCTION fu_guardarClave(p_token IN VARCHAR2,p_clave in VARCHAR2,p_tipo_Clave IN VARCHAR2) RETURN typ_MensajeRespuesta is
      v_retorno           typ_MensajeRespuesta := typ_MensajeRespuesta;
      v_cod_persona       varchar2(10);
      v_cod_per_Vinculada varchar2(10);
      v_estado            varchar2(1);
      v_respuesta         NUMBER;
      v_token             varchar2(200);
      v_clave             varchar2(32);
      v_tipo_clave        varchar2(1);
      v_length            number;
      v_mail              number;
      v_max_token         date;
      v_fec_verif         date;
      v_fec_hora          DATE := SYSDATE;
      v_sms               number;
      v_cod_oficina       bw_otp_seriales.cod_oficina%TYPE;
      v_telefono_predet   ba_telefonos.telefono%TYPE;
      v_env_sms_tel_ingresado number;
      v_dir_email             ba_mails.dir_correo%TYPE;
      MSG_CLA_DUPLICA CONSTANT VARCHAR2(15) := 'G_CLA_DUPLICADA';
      VERIF_BANCARD_OK CONSTANT VARCHAR2(1) := 'V';
   BEGIN

      -- Depuracion de datos
      v_token      := paw_bem.depurarAlfanumerico(p_token, 200); -- Token
      v_clave      := paw_bem.depurarAlfanumerico(p_clave, 32); -- Clave
      --v_tipo_clave := substr(p_tipo_Clave, 1, 1); --Tipo de clave
      v_length     := length(v_clave);


      BEGIN
         -- se verifica que se haya validado con bancard el pin. ESTADO = 'V'
         SELECT fec_verificacion, fec_verificacion + (MAX_TIEMPO_TOKEN / 1440), cod_persona, cod_per_vinculada, tipo
           INTO v_fec_verif, v_max_token, v_cod_persona, v_cod_per_Vinculada, v_tipo_clave
           FROM bw_sol_claves
          WHERE token = v_token
            AND estado = VERIF_BANCARD_OK;
           -- Validez de token no debe superar los 15 min.
         IF v_fec_hora NOT BETWEEN v_fec_verif AND v_max_token THEN
           paw_uti.pr_mensajeUsuario(MSG_TOKEN_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           paw_uti.pr_insertarBitacora(nvl(v_cod_persona,'999'),v_cod_canal,v_token,'508',null,paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta,null),BITACORA_ERROR);
           RETURN v_retorno;
         END IF;

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            paw_uti.pr_mensajeUsuario(MSG_NOSOLICITUD, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),v_cod_canal,v_token,'515',null,paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_ERROR);
            return v_retorno;
      END;


      IF v_token IS NULL OR v_clave IS NULL OR v_tipo_clave IS NULL THEN
         paw_uti.pr_mensajeUsuario(MSG_PARAM_INCORR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(nvl(v_cod_persona,'999'),v_cod_canal,v_token,'514',null,paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_ERROR);
         RETURN v_retorno;
      END IF;

      --Validaciones previas
      IF v_tipo_clave in ('A', 'T') THEN
      IF v_length < 0 or v_length > 32 or v_length <> 32 then
         paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                        v_cod_canal,
                                        v_token,
                                        '513',
                                        null,
                                        'Longitud de clave incorrecta' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                        BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      ELSE
         IF v_length < 0 or v_length > 10  THEN
            paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                        v_cod_canal,
                                        v_token,
                                        '534',
                                        null,
                                        'Longitud del teléfono incorrecto' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                        BITACORA_ERROR);
            RETURN v_retorno;
         END IF;
      END IF;



      -- Validar que el usuario cuente con clave de acceso.
      IF v_tipo_Clave = 'T' then
         BEGIN
            select t.cod_persona/*, t.clave*/, t.est_clave
              into v_cod_persona/*, v_clave*/, v_estado
              from bw_ope_claves t
             where t.cod_persona = v_cod_persona
               and t.cod_per_vinculada IS NULL --AGREGADO 06-08-2014
               and t.tip_clave = 'A';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               paw_uti.pr_mensajeUsuario(MSG_NOPOSEECLACCESO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                           v_cod_canal,
                                           v_token,
                                           '516',
                                           null,
                                           'No posee clave de acceso. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                           BITACORA_ERROR);
               return v_retorno;
         END;
      ELSE
       IF v_tipo_clave = 'K' THEN
         BEGIN
            IF paw_otp.fu_val_telefono(v_cod_persona,p_clave) <> 0 THEN
               paw_uti.pr_mensajeUsuario(MSG_TEL_NOVAL, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                           v_cod_canal,
                                           v_token,
                                           '539',
                                           null,
                                           'El teléfono no es valido para asignacion de token o no se encuentra configurado.' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                           BITACORA_ERROR);
               return v_retorno;
           END IF;
         END;
      END IF;
      END IF;
      --Generar y guardar la clave, se llama a la función "fu_gen_Clave".
      v_respuesta := fu_gen_Clave(v_cod_persona, v_cod_per_Vinculada, v_clave, v_estado, v_tipo_Clave);
      IF v_respuesta = '0' then
         --Exito
         --Se actualiza el estado de la solicitud a C: Confirmado
         IF v_tipo_clave = 'A' THEN
            update bw_sol_claves t set t.estado = 'C', t.fec_confirmacion = sysdate, t.tipo = 'A' where t.token = v_token;
         ELSIF v_tipo_clave = 'T' THEN
            update bw_sol_claves t set t.estado = 'C', t.fec_confirmacion = sysdate, t.tipo = 'T' where t.token = v_token;
         ELSE
            --Recupero la oficina asignado al token y en v_clave recupero el serial para hacer el update.
            v_cod_oficina := to_number(fug_obt_parentes(6331, 'COD_OFI_CLA_FACIL'));
            update bw_sol_claves t set t.estado = 'C', t.fec_confirmacion = sysdate, t.tipo = 'K', t.serial = v_clave, t.cod_oficina = v_cod_oficina where t.token = v_token;
         END IF;
          --Si telefono predeterminado es distinto del ingresado se envía el mensaje de notificacion a ambos números
         IF v_tipo_clave = 'K' AND v_telefono_predet IS NOT NULL AND p_clave <> v_telefono_predet THEN
            v_env_sms_tel_ingresado := paw_not.fu_env_sms_prueba(p_clave, g_mensaje_token, 'CLAVEFACIL');
         END IF;

         /*Envío de mail*/
         BEGIN
             SELECT dir_correo
               INTO v_dir_email
               FROM ba_mails
              WHERE cod_persona = v_cod_persona
                AND ROWNUM = 1;
         EXCEPTION
            WHEN OTHERS THEN
              NULL;
         END;
         IF v_tipo_clave = 'A' THEN
            v_mail := paw_not.fu_env_email_prueba(v_dir_email, g_mensaje_claac , 'CLAVEFACIL');
         ELSIF v_tipo_clave = 'T' THEN
            v_mail := paw_not.fu_env_email_prueba(v_dir_email, g_mensaje_trans , 'CLAVEFACIL');
         ELSE
            v_mail := paw_not.fu_env_email_prueba(v_dir_email, g_mensaje_token , 'CLAVEFACIL');
         END IF;

         v_sms  := paw_seg.fu_env_sms_clavefacil(v_cod_persona, v_tipo_clave);
         --v_mail := fu_env_mai_clavefacil(v_cod_persona, v_tipo_clave);
         IF v_sms = 0 then
             paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             paw_uti.pr_insertarBitacora(nvl(v_cod_persona,'999'),v_cod_canal,v_token,'517',null,paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_SALIDA);
             return v_retorno;
          ELSE
             paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                        v_cod_canal,
                                        v_token,
                                        '531',
                                        null,
                                        'Error en el envío de mensaje Vasco: ' || v_sms || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                        BITACORA_SALIDA);
             return v_retorno;
          END IF;
          IF v_mail = 0 THEN
             paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
             paw_uti.pr_insertarBitacora(nvl(v_cod_persona,'999'),v_cod_canal,v_token,'507',null,paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_SALIDA);
             return v_retorno;
          ELSE
             paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_cod_persona, '999'),
                                        v_cod_canal,
                                        v_token,
                                        '532',
                                        null,
                                        'Error en el envío de mail: ' || v_mail || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                        BITACORA_SALIDA);
             return v_retorno;
          END IF;
      ELSIF v_respuesta = '2' THEN
         paw_uti.pr_mensajeUsuario(MSG_CLA_DUPLICA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(nvl(v_cod_persona,'999'),v_cod_canal,v_token,'545',null,paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_ERROR);
         return v_retorno;
      ELSE
         paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(nvl(v_cod_persona,'999'),v_cod_canal,v_token,'518',null,paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_ERROR);
         return v_retorno;
      END IF;
      return v_retorno;
   END;

   PROCEDURE pr_datosAtm(p_nroCuenta IN VARCHAR2, p_tipoClave IN VARCHAR2, p_claveAcceso IN VARCHAR2, p_nroTelefono IN VARCHAR2, p_TipoDocumento OUT NUMBER, p_nroDocumento OUT VARCHAR2, p_fechaNacimiento OUT DATE, p_TipoTarjeta OUT VARCHAR2,
                         p_nroTarjeta OUT VARCHAR2) IS
      v_codPersona  varchar2(10);
      v_retorno     typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_nroCuenta   varchar2(15);
      v_TipoClave   varchar2(1);
      v_claveAcceso varchar2(32);
      v_nroTelefono varchar2(10);
   BEGIN
      --Sanitizar variables
      v_nroCuenta   := paw_bem.depurarAlfanumerico(p_nroCuenta, 15); --Nro de cuenta
      v_TipoClave   := substr(upper(p_tipoClave), 1, 1); --Tipo de tarjeta 'D' inicialmente
      v_claveAcceso := paw_bem.depurarAlfanumerico(p_claveAcceso, 32); -- Nro. de tarjeta
      v_nroTelefono := p_nroTelefono;
      BEGIN
         select p.cod_persona
           into v_CodPersona
           from ba_personas p, ge_clientes c, ge_cta_clientes cta, ba_per_fisicas f, ah_tar_debitos s
          WHERE p.cod_persona = c.cod_persona
            and p.cod_persona = cta.cod_persona
            and c.cod_persona = cta.cod_persona
            and f.cod_persona = p.cod_persona
            and s.cod_persona = p.cod_persona
          --  and p.est_verificacion = 'V'
            and cta.relacion IN('P','O','Y') --(P)Principal, (O)Indistinta, (Y)Conjunta
            and cta.nro_cuenta = v_nroCuenta;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_codPersona,'999'),v_cod_canal,null,'501',null,'Cuenta no existe' ||paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),BITACORA_ERROR);
      END;
      IF v_nroCuenta is null or v_tipoClave is null or p_claveAcceso is null then
         paw_uti.pr_mensajeUsuario(MSG_PARAM_INCORR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(nvl(v_codPersona, '999'),
                                     v_cod_canal,
                                     null,
                                     '502',
                                     null,
                                     'Se requiere la inserción de parámetros obligatorios. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                     BITACORA_ERROR);
      END IF;
      --Se valida el ingreso del nro de telefono no debe recibir null cuando clave es K: Token*/
      IF v_tipoClave = 'K' then
         IF v_nroTelefono is null then
            paw_uti.pr_mensajeUsuario(MSG_PARAM_INCORR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(nvl(v_codPersona, '999'),
                                        v_cod_canal,
                                        null,
                                        '503',
                                        null,
                                        'Nro. del tel no puede ser nulo cuando tipo clave es K. ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                        BITACORA_ERROR);
         ELSE
            select p.cod_tip_documento, p.nro_documento, f.fec_nacimiento, s.nro_tarjeta, 'D'
              into p_TipoDocumento, p_nroDocumento, p_fechaNacimiento, p_nroTarjeta, p_TipoTarjeta
              from ba_personas p, ge_clientes c, ge_cta_clientes cta, ba_per_fisicas f, ah_tar_debitos s, ba_telefonos t
             WHERE p.cod_persona = c.cod_persona
               and p.cod_persona = cta.cod_persona
               and c.cod_persona = cta.cod_persona
               and f.cod_persona = p.cod_persona
               and s.cod_persona = p.cod_persona
            --   and p.est_verificacion = 'V'
               and cta.relacion IN('P','O','Y') --(P)Principal, (O)Indistinta, (Y)Conjunta
               and t.telefono = v_nroTelefono
               and cta.nro_cuenta = v_nroCuenta;
         END IF;
      ELSE
         select p.cod_tip_documento, p.nro_documento, f.fec_nacimiento, s.nro_tarjeta, 'D'
           into p_TipoDocumento, p_nroDocumento, p_fechaNacimiento, p_nroTarjeta, p_TipoTarjeta
           from ba_personas p, ge_clientes c, ge_cta_clientes cta, ba_per_fisicas f, ah_tar_debitos s
          WHERE p.cod_persona = c.cod_persona
            and p.cod_persona = cta.cod_persona
            and c.cod_persona = cta.cod_persona
            and f.cod_persona = p.cod_persona
            and s.cod_persona = p.cod_persona
          --  and p.est_verificacion = 'V'
            and cta.relacion IN('P','O','Y') --(P)Principal, (O)Indistinta, (Y)Conjunta
            and cta.nro_cuenta = v_nroCuenta;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   function fu_env_sms_clavefacil(p_cod_persona IN VARCHAR2, p_tipClave IN VARCHAR2) RETURN NUMBER IS
     v_telefono varchar2(20);
     v_resultado varchar2(20);
   begin
     v_telefono:=fu_obt_celular (p_cod_persona);
     if(length(v_telefono)>5)Then
         if p_tipClave = 'A' then
        v_resultado:=paw_not.fu_env_sms_prueba(v_telefono,g_mensaje_claac,'CLAVEFACIL');
        return v_resultado;
         elsif p_tipClave = 'T' then
            v_resultado := paw_not.fu_env_sms_prueba(v_telefono, g_mensaje_trans, 'CLAVEFACIL');
            return v_resultado;
         else
            v_resultado := paw_not.fu_env_sms_prueba(v_telefono, g_mensaje_token, 'CLAVEFACIL');
            return v_resultado;
         end if;
     end if;
     return 1;
   end;
   FUNCTION fu_env_mai_clavefacil(p_cod_persona IN VARCHAR2, p_tipClave IN VARCHAR2) RETURN NUMBER IS
      v_dir_email VARCHAR2(300);
   BEGIN
      BEGIN
         SELECT dir_correo
           INTO v_dir_email
           FROM ba_mails
          WHERE cod_persona = p_cod_persona
            AND  ROWNUM = 1;

         IF p_tipClave  = 'A' THEN
           it_mail.mail(fug_obt_dir_correo, v_dir_email, 'Generacion de Clave de acceso', g_mensaje_claac);
         ELSIF p_tipClave = 'T' THEN
           it_mail.mail(fug_obt_dir_correo, v_dir_email, 'Generacion de Clave transaccional', g_mensaje_trans);
         ELSE
           it_mail.mail(fug_obt_dir_correo, v_dir_email, 'Generacion de Clave Dinamica', g_mensaje_token);
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 1;
      end;

   return 0;
   END;
   --Obtiene el Celular de la persona
FUNCTION fu_obt_celular (p_cod_persona IN VARCHAR2)RETURN VARCHAR2 IS
  v_area BA_TELEFONOS.AREA%TYPE;
  v_telefono BA_TELEFONOS.TELEFONO%TYPE;
  v_celular VARCHAR2(50);
BEGIN
  SELECT m.ref_medio
    INTO v_celular
    FROM bw_otp_ref_medios m
   WHERE m.tipo = 'C' --Celular
     AND m.cod_persona = p_cod_persona
     AND ROWNUM = 1;
   RETURN v_celular;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
        BEGIN
          SELECT substr(TRIM(area), 1, 4), substr(TRIM(telefono), 1, 6)
            INTO v_area, v_telefono
            FROM ba_telefonos
           WHERE cod_persona = p_cod_persona
             AND tipo = 'P' --Particular
             AND tip_linea = 'C' --Celular
             AND ROWNUM = 1;
          IF v_area IS NOT NULL THEN
              RETURN v_area||v_telefono;
          ELSIF v_area IS NULL THEN
              RETURN v_telefono;
          ELSE
              RETURN '';
          END IF;
          EXCEPTION
              WHEN OTHERS THEN
                   RETURN '';
          END;
    WHEN OTHERS THEN
      RETURN '';
END;

FUNCTION fu_obt_mail (p_cod_persona IN VARCHAR2)RETURN VARCHAR2 is
  v_dir_email VARCHAR2(300);
  BEGIN
     SELECT dir_correo
       INTO v_dir_email
       FROM ba_mails
      WHERE cod_persona = p_cod_persona
        AND principal = 'S'
        AND rownum = 1;
     RETURN v_dir_email;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
        BEGIN
           SELECT dir_correo
             INTO v_dir_email
             FROM ba_mails
            WHERE cod_persona = p_cod_persona
              AND rownum = 1;
           RETURN v_dir_email;
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
              RETURN ' ';
           WHEN OTHERS THEN
              RETURN ' ';
        END;
     WHEN OTHERS THEN
          RETURN ' ';
   END;
   FUNCTION fu_obt_tar_deb_activa (p_cod_persona IN VARCHAR2)RETURN VARCHAR2 is
  v_tar_deb VARCHAR2(300);
  BEGIN
     SELECT s.nro_tarjeta
       INTO v_tar_deb
       FROM ah_tar_debitos s
      WHERE /*s.tar_activa = 'S'
               AND*/
       s.cod_persona = p_cod_persona
        AND ROWNUM = 1;
     RETURN v_tar_deb;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
          RETURN ' ';
     WHEN OTHERS THEN
          RETURN ' ';
   END;

FUNCTION fu_obt_mot_rechazo (p_token IN VARCHAR2)RETURN VARCHAR2 is
  v_motivo VARCHAR2(4000);
  BEGIN
     SELECT s.dato
       INTO v_motivo
       FROM bw_bitacoras s
      WHERE s.tipo = 'ERR'
        AND s.cod_sesion = p_token
        AND ROWNUM = 1
      ORDER BY s.fec_insercion desc;
     RETURN v_motivo;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
          RETURN ' ';
     WHEN OTHERS THEN
          RETURN ' ';
   END;
   --inicializacion del paquete

   -- Que clave solicitar al usuario
   FUNCTION fu_obt_cla_operacion(p_par_cla_transaccional IN ge_par_entes.parametro%TYPE,
                                 p_par_cla_token         IN ge_par_entes.parametro%TYPE,
                                 p_cod_persona           IN ba_personas.cod_persona%TYPE DEFAULT NULL) RETURN VARCHAR2 IS
   v_cod_ente      ge_entes.cod_ente%TYPE;
   v_retorno       VARCHAR2(2) := NULL;
   v_otp           VARCHAR2(1);
   v_tra           VARCHAR2(1);
   v_obt_swf_token VARCHAR2(1) := 'N';
   v_tip_persona   VARCHAR2(1);
   BEGIN
     v_cod_ente := trim(fug_obt_pardinamico('COD_ENT_CON_CLA'));
     v_tra      := nvl(substr(trim(fug_obt_parentes(v_cod_ente, p_par_cla_transaccional)), 1, 1), 'N');
     v_otp      := nvl(substr(trim(fug_obt_parentes(v_cod_ente, p_par_cla_token)), 1, 1), 'N');

     -- si hay que solicitar CT
     IF v_tra = 'S' THEN
        v_retorno := '1';
     ELSIF v_tra = 'N' THEN
        v_retorno := '0';
     ELSE
        v_retorno := '-1';
     END IF;
     -- verificar asignacion swf token
     IF p_cod_persona IS NOT NULL AND v_otp = 'S' THEN
        -- obtenemos el tipo de persona
        SELECT decode(pag_gen.fu_es_per_fisica(p_cod_persona), 'S', 'F', 'J')
          INTO v_tip_persona
          FROM DUAL;
        -- si tiene asignado swf token, se elije
        IF paw_otp.fu_obtenerAsignacionSofttoken(p_cod_persona, v_tip_persona) IS NOT NULL THEN
           v_obt_swf_token := 'S';
        END IF;
     END IF;
     -- si hay que solicitar SOFT-TOKEN
     IF v_obt_swf_token = 'S' THEN
        v_retorno := '02';
     ELSE
        -- si hay que solicitar OTP
        IF v_otp = 'S' THEN
           v_retorno := v_retorno || '1';
        ELSIF v_otp = 'N' THEN
           v_retorno := v_retorno || '0';
        ELSE
           v_retorno := '-1';
        END IF;
     END IF;

     RETURN v_retorno;
   EXCEPTION
     WHEN OTHERS THEN
        RETURN '-2';
   END;

   -- se inserta la lista de cierres de tarjeta obtenidos del DMS
   FUNCTION fu_ins_dms_tarjetas(p_sesion      IN VARCHAR2,
                                p_codigoCanal IN VARCHAR2,
                                p_listaId     IN TYP_LISTADETALLEDMS) RETURN NUMBER IS
      v_sesion      paw_bem.typ_validarSesion;
      v_cod_persona ge_clientes.cod_persona%TYPE;
   BEGIN
      -- Valido la Sesión del Cliente
      v_sesion := paw_bem.fu_validarSesion(p_sesion, p_codigoCanal);
      IF v_sesion.error = 'S' THEN
         RETURN -1;
      END IF;
      v_cod_persona := NVL(v_sesion.codigoEmpresa, v_sesion.codigoPersona);
      -- insertamos la lista de tarjetas disponibles para el cliente
      FOR i in 1..p_listaId.count LOOP
         BEGIN
            INSERT INTO bw_dms_tarjetas
               (cod_persona, fec_extracto, card_id)
            VALUES
               (v_cod_persona, p_listaId(i).fechaCierre, p_listaId(i).identificador);
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               NULL; -- ya insertado, ignoramos
         END;
      END LOOP;
      RETURN 0;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN -9;
   END;

   -- se inserta la lista de cierres de tarjeta obtenidos del DMS
   FUNCTION fu_val_dms_tarjeta(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_cardId      IN NUMBER) RETURN NUMBER IS
      v_sesion  paw_bem.typ_validarSesion;
      v_retorno NUMBER := -1;
   BEGIN
      -- Valido la Sesión del Cliente
      v_sesion := paw_bem.fu_validarSesion(p_sesion, p_codigoCanal);
      IF v_sesion.error = 'S' THEN
         RETURN v_retorno;
      END IF;

      BEGIN
         SELECT 0
           INTO v_retorno
           FROM bw_dms_tarjetas t
          WHERE t.cod_persona = nvl(v_sesion.codigoEmpresa, v_sesion.codigoPersona)
            AND t.card_id = p_cardId
            AND rownum = 1;
      EXCEPTION
         WHEN OTHERS THEN
            v_retorno := 1;
      END;
      paw_uti.pr_insertarBitacora(v_sesion.codigoPersona,v_sesion.codigoCanal,p_sesion, '213',
                                  null,'Descarga de extracto de tarjeta ',BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN -9;
   END;

   PROCEDURE pr_reg_cla_privada(p_cod_persona IN VARCHAR2,
                              p_id_dispositivo IN VARCHAR2,
                              p_cod_dispositivo IN VARCHAR2,
                              p_cla_privada IN VARCHAR2,
                              p_marca IN VARCHAR2,
                              p_modelo IN VARCHAR2,
                              p_sistema IN VARCHAR2,
                              p_sis_version IN VARCHAR2,
                              p_alias IN VARCHAR2,
                              p_clave IN OUT VARCHAR2,
                              p_retorno IN OUT typ_regclave,
                              p_modo IN VARCHAR2) IS

   v_salt              NUMBER := round(dbms_random.value(1000000, 9999999));
   v_cod_canal CONSTANT VARCHAR2(3) := '994';
   v_clave VARCHAR2(100);
   BEGIN
      SELECT paw_bce.fu_enc_md5(dbms_random.string('P', 7)) salt
      INTO p_clave
      FROM dual;
      v_clave := v_salt || '|' || p_clave;
      v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));

      IF p_modo = 'A' THEN -- A: alta
         BEGIN
           INSERT INTO BW_CLA_CLI_ACCESO (ID_DISPOSITIVO, COD_PERSONA, COD_DISPOSITIVO,
              CLA_PRIVADA, CLA_ACCESO, CLA_VERIFICADOR, MARCA, MODELO, SISTEMA, SIS_VERSION, ALIAS, ESTADO )
           VALUES
             (p_id_dispositivo, p_cod_persona, p_cod_dispositivo, p_cla_privada,
              v_clave, v_salt, p_marca, p_modelo, p_sistema, p_sis_version, p_alias, 'A');
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               -- hacemos un update
               BEGIN
                  UPDATE BW_CLA_CLI_ACCESO
                  SET ID_DISPOSITIVO = p_id_dispositivo,
                     CLA_PRIVADA = p_cla_privada, CLA_ACCESO = v_clave, CLA_VERIFICADOR = v_salt,
                     MARCA = p_marca, MODELO = p_modelo, SISTEMA = p_sistema, SIS_VERSION = p_sis_version,
                     ALIAS = p_alias, ESTADO = 'A'
                  WHERE COD_PERSONA = p_cod_persona AND COD_DISPOSITIVO = p_cod_dispositivo;
               EXCEPTION
                  WHEN OTHERS THEN
                     paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al insertar clave privada' || SQLERRM, BITACORA_ERROR);
                     paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               END;
            WHEN OTHERS THEN
               paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al insertar clave privada' || SQLERRM, BITACORA_ERROR);
               paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END;
      ELSIF p_modo = 'M' THEN -- M: modificacion
         BEGIN
            UPDATE BW_CLA_CLI_ACCESO
                  SET CLA_PRIVADA = p_cla_privada, CLA_ACCESO = v_clave, CLA_VERIFICADOR = v_salt,
                     FEC_INSERCION = SYSDATE
                  WHERE COD_PERSONA = p_cod_persona AND ID_DISPOSITIVO = p_id_dispositivo;
         EXCEPTION
            WHEN OTHERS THEN
               paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al actualizar clave privada' || SQLERRM, BITACORA_ERROR);
               paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END;
      END IF;
   END;

   PROCEDURE pr_reg_cla_softoken(p_nro_serial IN VARCHAR2,
                              p_cod_persona IN VARCHAR2,
                              p_cod_dispositivo IN VARCHAR2,
                              p_cla_encriptacion IN VARCHAR2,
                              p_vec_inicializacion IN VARCHAR2,
                              p_estado IN VARCHAR2,
                              p_retorno IN OUT typ_regsoftokenkey,
                              p_dominio IN VARCHAR2 DEFAULT 'RETAILPY',
                              p_modo IN VARCHAR2 DEFAULT 'A',
                              p_cod_per_vinculada IN VARCHAR2 DEFAULT NULL,
                              p_es_migracion IN VARCHAR2 DEFAULT 'N') IS
    v_id            NUMBER;
    v_cod_canal     CONSTANT VARCHAR2(3) := '994';
    v_cod_operacion CONSTANT VARCHAR2(3) := '008';
    v_reg_seriales  VARCHAR2(1);
    v_reg_empresa   VARCHAR2(1);

    BEGIN
        PAW_UTI.pr_mensajeUsuario(paw_uti.MSG_OK, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
        PAW_UTI.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, p_cod_per_vinculada,
                                    'Registrando Token Digital de cliente: ' || p_cod_persona || ', dominio: ' || p_dominio || ', cod_empresa: ' || p_cod_per_vinculada || ', modo: ' || p_modo,
                                    PAW_UTI.BITACORA_ENTRADA);

        IF p_modo = 'A' THEN
           BEGIN

           IF p_dominio = 'RETAILPY' THEN
                UPDATE BW_SOF_SERIALES
                    SET COD_DISPOSITIVO = p_cod_dispositivo,
                       CLA_ENCRIPTACION = p_cla_encriptacion,
                       VEC_INICIALIZACION = p_vec_inicializacion,
                       DOMINIO = p_dominio
                    WHERE NRO_SERIAL = p_nro_serial
                       AND COD_PERSONA = p_cod_persona
                       AND DOMINIO = p_dominio;
           END IF;

           IF p_dominio = 'CASHPY' THEN
              IF p_es_migracion = 'N' THEN
                 BEGIN
                    SELECT 'S', id
                    INTO v_reg_seriales, v_id
                    FROM BW_SOF_SERIALES
                    WHERE cod_persona = p_cod_persona
                      AND dominio = p_dominio;
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       v_reg_seriales := 'N';
                 END;

                 IF v_reg_seriales = 'N' THEN
                    -- el usuario aun no tiene registrado un serial, insertamos en BW_SOF_SERIALES
                    SELECT S_BW_SOF_SERIALES.NEXTVAL
                    INTO v_id
                    FROM dual;

                    INSERT INTO BW_SOF_SERIALES (id, nro_serial, cod_persona, cod_dispositivo, cla_encriptacion, vec_inicializacion, dominio, sts_status)
                    VALUES (v_id, p_nro_serial, p_cod_persona, p_cod_dispositivo, p_cla_encriptacion, p_vec_inicializacion, p_dominio, 2);
                 END IF;

                 IF v_reg_seriales = 'S' THEN
                    -- el usuario ya tiene registrado un serial, actualizamos con los nuevos datos
                    UPDATE BW_SOF_SERIALES
                    SET cod_dispositivo = p_cod_dispositivo,
                        cla_encriptacion = p_cla_encriptacion,
                        vec_inicializacion = p_vec_inicializacion,
                        sts_status = 2
                    WHERE cod_persona = p_cod_persona
                      AND dominio = p_dominio;
                 END IF;

                 BEGIN
                    SELECT 'S'
                    INTO v_reg_empresa
                    FROM BW_SOF_EMPRESAS
                    WHERE sof_ser_id = v_id
                      AND cod_per_vinculada = p_cod_per_vinculada;
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       v_reg_empresa := 'N';
                 END;

                 IF v_reg_empresa = 'N' THEN
                    -- es la primera vez que el usuario se da de alta con esta empresa, registramos en BW_SOF_EMPRESAS
                    INSERT INTO BW_SOF_EMPRESAS (sof_ser_id, cod_per_vinculada, estado)
                    VALUES (v_id, p_cod_per_vinculada, 'E');
                 END IF;

                 IF v_reg_empresa = 'S' THEN
                    -- el usuario ya se habia dado de alta con esta empresa, actualizamos el estado de esta empresa
                    UPDATE BW_SOF_EMPRESAS
                    SET estado = 'P'
                    WHERE sof_ser_id = v_id
                      AND cod_per_vinculada = p_cod_per_vinculada
                      AND estado <> 'E';
                 END IF;

                 -- actualizamos los estados de las otras empresas registradas del usuario, excepto la empresa actual
                 UPDATE BW_SOF_EMPRESAS
                 SET estado = 'S'
                 WHERE sof_ser_id = v_id
                   AND cod_per_vinculada <> p_cod_per_vinculada;

                 -- notificamos al operador y/o autorizador acerca del nuevo enrollment segun corresponda
                 paw_otp.pr_SoftokenNotifEmpre(p_cod_per_vinculada, p_cod_persona, 'E');

              ELSE
                    UPDATE BW_SOF_SERIALES
                    SET COD_DISPOSITIVO = p_cod_dispositivo,
                       CLA_ENCRIPTACION = p_cla_encriptacion,
                       VEC_INICIALIZACION = p_vec_inicializacion,
                       STS_STATUS = 2,
                       MIGRADO = 2
                    WHERE NRO_SERIAL = p_nro_serial
                       AND COD_PERSONA = p_cod_persona
                       AND DOMINIO = p_dominio;

                     UPDATE BW_SOF_EMPRESAS E
                       SET E.ESTADO = 'A'
                       WHERE E.ESTADO = 'S' AND E.Sof_Ser_Id =
                          (SELECT ID FROM BW_SOF_SERIALES S WHERE S.COD_PERSONA = p_cod_persona
                             AND S.DOMINIO = p_dominio) ;
              END IF;

           END IF;
           EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                 BEGIN
                    UPDATE BW_SOF_SERIALES
                    SET COD_DISPOSITIVO = p_cod_dispositivo,
                       CLA_ENCRIPTACION = p_cla_encriptacion,
                       VEC_INICIALIZACION = p_vec_inicializacion,
                       DOMINIO = p_dominio
                    WHERE NRO_SERIAL = p_nro_serial
                       AND COD_PERSONA = p_cod_persona
                       AND DOMINIO = p_dominio;
                 EXCEPTION
                    WHEN OTHERS THEN
                       paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al insertar clave softoken' || SQLERRM, BITACORA_ERROR);
                       paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                 END;
              WHEN OTHERS THEN
                 paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al insertar clave softoken' || SQLERRM, BITACORA_ERROR);
                 paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
           END;
        ELSIF p_modo = 'I' THEN
           IF p_dominio = 'RETAILPY' THEN
              UPDATE BW_OTP_SERIALES SET estado = p_estado
              WHERE nro_serial = p_nro_serial
                 AND cod_persona = p_cod_persona;
           ELSIF p_dominio = 'CASHPY' THEN
              DECLARE
                 v_id NUMBER;
              BEGIN
                 SELECT id
                 INTO v_id
                 FROM BW_SOF_SERIALES
                 WHERE nro_serial = p_nro_serial
                    AND cod_persona = p_cod_persona
                    AND dominio = p_dominio;

                 UPDATE BW_SOF_SERIALES
                 SET cod_dispositivo = p_cod_dispositivo,
                     cla_encriptacion = NULL,
                     vec_inicializacion = NULL,
                     sts_status = 1
                 WHERE id = v_id;

                 UPDATE BW_SOF_EMPRESAS SET estado = 'S'
                 WHERE sof_ser_id = v_id AND ESTADO = 'A';

                 --Para marcar que fue un intento de migracion en empresas
                 BEGIN
                    IF (p_es_migracion = 'S') THEN
                         UPDATE BW_SOF_SERIALES
                            SET MIGRADO = 1
                        WHERE id = v_id;
                    END IF;
                 EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                 END;

              EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                    -- si no encuestra es porque es su primer enroll, ignoramos el error
                    RETURN;
                 WHEN OTHERS THEN
                    paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al actualizar estado softoken' || SQLERRM, BITACORA_ERROR);
                    paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
              END;
           END IF;
        ELSIF p_modo = 'L' AND p_dominio = 'CASHPY' THEN
           DECLARE
              v_id NUMBER;
           BEGIN
              SELECT id
              INTO v_id
              FROM BW_SOF_SERIALES
              WHERE nro_serial = p_nro_serial
                 AND cod_persona = p_cod_persona
                 AND dominio = p_dominio;
              INSERT INTO BW_SOF_EMPRESAS
              (SOF_SER_ID, COD_PER_VINCULADA, ESTADO)
              VALUES
              (v_id, p_cod_per_vinculada, 'E');
               paw_otp.pr_SoftokenNotifEmpre(p_cod_per_vinculada, p_cod_persona, 'E');
           EXCEPTION
              WHEN DUP_VAL_ON_INDEX THEN
                 BEGIN
                    UPDATE BW_SOF_EMPRESAS SET estado = 'P'
                    WHERE sof_ser_id = v_id AND COD_PER_VINCULADA = p_cod_per_vinculada;
              EXCEPTION
                 WHEN OTHERS THEN
                    paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '007', NULL, 'Error al actualizar estado softoken' || SQLERRM, BITACORA_ERROR);
                    paw_uti.pr_mensajeUsuario(MSG_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
              END;
           END;
        END IF;
     END;

   PROCEDURE pr_val_cla_estatica(p_cod_persona IN VARCHAR2,
                                 p_id_dispositivo IN VARCHAR2,
                                 p_clave IN VARCHAR2,
                                 p_retorno IN OUT typ_iniciarSesion) IS
   MSG_LOGIN_ERR     CONSTANT VARCHAR2(30) := 'L_ERROR';
   v_clave VARCHAR2(100);
   v_cla_recibida VARCHAR2(100);
   v_cla_verificador VARCHAR2(100);
   v_cod_canal CONSTANT VARCHAR2(3) := '994';
   BEGIN
      BEGIN
         SELECT a.cla_acceso, a.cla_verificador
         INTO v_clave, v_cla_verificador
         FROM bw_cla_cli_acceso a
         WHERE a.id_dispositivo = p_id_dispositivo AND a.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            v_clave := null;
      END;
      v_cla_recibida := v_cla_verificador|| '|' ||p_clave;
      v_cla_recibida := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_cla_recibida)));

      IF v_clave <> v_cla_recibida THEN
         paw_uti.pr_mensajeUsuario(MSG_LOGIN_ERR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, v_cod_canal, NULL, '006', NULL, 'Clave invalida ' ||
            paw_uti.fu_generarBitacora(p_retorno.error, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta,null), BITACORA_ERROR);
      END IF;

   END;
   PROCEDURE pr_act_visitas(p_cod_persona       IN VARCHAR2,
                            p_id_dispositivo IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      UPDATE bw_cla_cli_acceso
         SET can_acceso = can_acceso + 1,
             fec_ult_acceso = SYSDATE
       WHERE cod_persona = p_cod_persona
         AND id_dispositivo = p_id_dispositivo;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
          -- reiniciar contador si llega al tope
          UPDATE bw_cla_cli_acceso
             SET can_acceso = 0,
                 fec_ult_acceso = SYSDATE
           WHERE cod_persona = p_cod_persona
             AND id_dispositivo = p_id_dispositivo;
          COMMIT;
   END;

procedure pr_agregarBlacklist is
  CURSOR c_blacklist IS
    SELECT b.cod_persona, b.observaciones
    FROM   bw_aut_blacklist_tmp b;

begin
    FOR cliente IN c_blacklist LOOP
      begin
        insert into bw_aut_blacklist (cod_persona,estado,observaciones)
        values (cliente.cod_persona,'A',cliente.observaciones);
      exception
        when DUP_VAL_ON_INDEX then
          update bw_aut_blacklist set estado='A',observaciones=cliente.observaciones
          where cod_persona=cliente.cod_persona;
        end;
    END LOOP;
    commit;
end;

PROCEDURE pr_quitarBlacklist IS
  CURSOR c_whitelist IS
    SELECT b.cod_persona, b.observaciones
    FROM   bw_aut_whitelist_tmp b;

BEGIN
  FOR cliente IN c_whitelist LOOP
    BEGIN
      UPDATE bw_aut_blacklist
      SET    estado = 'N', observaciones = cliente.observaciones
      WHERE  cod_persona = cliente.cod_persona;
    END;
  END LOOP;
  COMMIT;
END;

FUNCTION fu_obtenerBlacklist(p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
  v_si VARCHAR(1);
BEGIN
  BEGIN
    SELECT 'S'
    INTO   v_si
    FROM   bw_aut_blacklist
    WHERE  cod_persona = p_cod_persona
           AND estado = 'A';
  EXCEPTION
    WHEN OTHERS THEN
      v_si := 'N';
  END;
  RETURN v_si;
END;

FUNCTION fu_val_gen_clave(p_cod_persona IN ba_personas.cod_persona%TYPE,
                          p_cla_md5     IN VARCHAR2) RETURN NUMBER IS
  v_retorno            NUMBER := 0;
  v_fmt_fec_nacimiento VARCHAR2(200);

  -- telefonos del cliente
  CURSOR c_telefonos IS
     SELECT -- paw_bce.fu_enc_md5(t.telefono) tel_md5 --BWP-471 - glopez- Se comenta
            --BWP-471 - glopez- Le agregue primero para que encripte en sha1
            paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(t.telefono)) tel_md5
       FROM ba_telefonos t
      WHERE t.cod_persona = p_cod_persona;

  -- recorre los formatos posibles de fecha de nacimiento del cliente
  CURSOR c_fechas IS
     SELECT --paw_bce.fu_enc_md5(column_value) fec_md5 --BWP-471 - glopez- Se comenta
            --BWP-471 - glopez- Le agregue primero para que encripte en sha1
            paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(column_value)) fec_md5
       FROM TABLE(fug_obt_tab_registro(v_fmt_fec_nacimiento));

  -- cargar fecha de nacimiento en formatos posibles
  PROCEDURE lp_obt_dat_per_fisica IS
  BEGIN
     select to_char(f.fec_nacimiento, 'ddmmyyyy')||','||to_char(f.fec_nacimiento, 'ddmmyy')||','||
            to_char(f.fec_nacimiento, 'yymmdd')||','||to_char(f.fec_nacimiento, 'yyyymmdd')||','||
            to_char(f.fec_nacimiento, 'mmddyyyy')||','||to_char(f.fec_nacimiento, 'mmddyy')||','||
            to_char(f.fec_nacimiento, 'yyyyddmm')||','||to_char(f.fec_nacimiento, 'ddyyyymm')
       into v_fmt_fec_nacimiento
       from ba_per_fisicas f, ba_personas p
      where f.cod_persona = p_cod_persona
        and f.cod_persona = p.cod_persona
        and p.tipo = 'F';
  END lp_obt_dat_per_fisica;
BEGIN
   -- verificar si la clave es el nro. doc. del cliente
   /*
        BWP-471 - glopez - Le agregue primero para que encripte en sha1
   */
   IF paw_bce.fu_enc_md5(paw_bce.fu_enc_sha1(fue_obt_nro_doc_persona(p_cod_persona))) = p_cla_md5 THEN
      RETURN -1;
   END IF;
   -- cargar formatos de fechas
   lp_obt_dat_per_fisica;
   -- verificar si la clave es uno de los telefonos registrados
   FOR tel IN c_telefonos LOOP
     IF tel.tel_md5 = p_cla_md5 THEN
        v_retorno := -2;
        EXIT;
     END IF;
   END LOOP;
   -- verificar si la clave es algun formato de fecha de nacimiento
   IF v_retorno = 0 THEN
      FOR na IN c_fechas LOOP
        IF na.fec_md5 = p_cla_md5 THEN
           v_retorno := -3;
           EXIT;
        END IF;
      END LOOP;
   END IF;

   RETURN v_retorno;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN -10;
   WHEN OTHERS THEN
      RETURN -11;
END;

FUNCTION lf_val_cli_tie_tip_clave(p_cod_clave     BW_CLA_VAL_TIP_OPERACION.COD_TIP_CLAVE%TYPE,
                                  p_cod_persona   ba_personas.cod_persona%TYPE,
                                  p_cod_empresa   ba_personas.cod_persona%TYPE) RETURN BOOLEAN IS
    v_tiene BOOLEAN := false;
    v_pin_tx NUMBER;
    v_tipo_token VARCHAR2(1);
    v_token paw_otp.typ_token;
    v_tip_persona VARCHAR2(1);
BEGIN
    IF p_cod_empresa IS NULL THEN
       v_tip_persona := 'F';
    ELSE
       v_tip_persona := 'J';
    END IF;
    CASE p_cod_clave
        WHEN 'N' THEN -- NO APLICA
            raise_application_error(-20001, 'NO APLICA, NO PUEDE AVANZAR');
        WHEN 'L' THEN -- NONE - Libre
            v_tiene := true;
        WHEN 'T' THEN -- Pin transaccional
           v_pin_tx := fu_verificarClaveTransaccional(p_cod_persona, p_cod_empresa);
            --validar que tenga pin transaccional
            /*IF v_tip_persona = 'F' THEN
                v_pin_tx := fu_verificarClaveTransaccional(p_cod_persona, NULL);
            ELSE
                v_pin_tx := fu_verificarClaveTransaccional(NULL, p_cod_persona);
            END IF;*/

            IF v_pin_tx = 1 then --solo consideramos el caso 1 para mas info paw_bem.fu_verificarClaveTransaccional
                v_tiene := true;
            ELSIF v_pin_tx = 3 then
                raise_application_error(-20002, 'DEBE ACTUALIZAR SU CLAVE TRANSACCIONAL');
            END IF;

        WHEN 'K' THEN -- token
           --validar que tenga otp configurado
            IF v_tip_persona = 'F' THEN
                v_tipo_token := 'V';
            ELSE
                v_tipo_token := 'F';
            END IF;

            v_token := paw_otp.fu_obtenerToken(p_cod_persona, v_tipo_token);

            IF v_token.serial IS NOT NULL THEN
               v_tiene := true;
            END IF;
        WHEN 'S' THEN -- SoftToken
            --validar que tenga ST
           IF paw_otp.fu_obtenerAsignacionSofttoken(p_cod_persona, v_tip_persona, p_cod_empresa) IS NOT NULL THEN
              v_tiene := true;
           END IF;
    END CASE;
    RETURN v_tiene;
END;

FUNCTION lf_val_cli_ope_excepcion(
    p_cod_clave     BW_CLA_VAL_TIP_OPERACION.COD_TIP_CLAVE%TYPE,
    p_cod_clave_sec     BW_CLA_VAL_TIP_OPERACION.COD_TIP_CLAVE%TYPE,
    p_cod_persona   ba_personas.cod_persona%TYPE,
    p_cod_empresa   ba_personas.cod_persona%TYPE,
    p_tip_persona   BW_CLA_VAL_TIP_OPERACION.tip_persona%TYPE
    ) return VARCHAR2 IS

    v_return          VARCHAR2(3) := NULL;
    v_cod_persona     ba_personas.cod_persona%TYPE := NULL;
    v_es_cli_nomina   VARCHAR2(3) := NULL;
BEGIN

    if p_tip_persona = 'F' then
      v_cod_persona := p_cod_persona;
    else
      v_cod_persona := p_cod_empresa;
    end if;

    IF p_cod_clave = '232' THEN -- ACTUALIZACIÓN DE DATOS PERSONALES
            --Se verifica si el cliente es o no de nómina.
            v_es_cli_nomina := fug_es_cli_nomina(v_cod_persona);

            --Si no tiene clave dinámica pero es cliente de nomina, se le deja avanzar sin necesidad de clave
            IF (v_es_cli_nomina = 'S' and (p_cod_clave = 'K' or p_cod_clave_sec = 'K')) then
                v_return := 'L';
            END IF;
    END IF;

    Return v_return;
EXCEPTION
    WHEN OTHERS THEN
        --ocurrio algun error retornamos null
        Return NULL;
END;

FUNCTION fu_obt_cla_val_operacion(p_cod_tip_mensaje       IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                                  p_cod_persona           IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                                  p_cod_empresa           IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                                  p_cod_canal             IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                                  p_cod_sesion_aux        IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN TYP_CLAVE_VALIDACION IS

   v_retorno       TYP_CLAVE_VALIDACION := TYP_CLAVE_VALIDACION();
   v_cod_persona   ba_personas.cod_persona%TYPE := NULL;
   v_tip_persona   VARCHAR2(1) := NULL;
   v_existe        BOOLEAN := FALSE;
   v_tip_clave     BW_CLA_VAL_TIP_OPERACION.COD_TIP_CLAVE%TYPE;
   v_tip_cla_sec   BW_CLA_VAL_TIP_OPERACION.COD_TIP_CLA_SEC%TYPE;
   v_tie_tip_cla   BOOLEAN;
   v_cod_canal     BW_AUT_SESIONES.COD_CANAL%TYPE;
   v_clave_desc    VARCHAR2(12);
   v_tip_cla_aux   BW_CLA_VAL_TIP_OPERACION.COD_TIP_CLA_SEC%TYPE := NULL;

   MSG_CLA_NA    CONSTANT VARCHAR2(15) := 'CLA_OPE_NA';
   MSG_CLA_NO_TIENE   CONSTANT VARCHAR2(15) := 'CLA_OPE_N_TIENE';
   MSG_CLA_OPE_CAMBIAR   CONSTANT VARCHAR2(15) := 'CLA_OPE_CAMBIAR';

   CURSOR c_met( c_tip_mensaje   BW_CLA_VAL_TIP_OPERACION.cod_tip_mensaje%TYPE,
                 c_cod_persona   ba_personas.cod_persona%TYPE,
                 c_tip_persona   BW_CLA_VAL_TIP_OPERACION.tip_persona%TYPE) IS
    SELECT cv.cod_tip_mensaje, cv.cod_tip_clave, cv.cod_tip_cla_sec
    FROM BW_CLA_VAL_TIP_OPERACION cv
    WHERE cod_tip_mensaje = c_tip_mensaje
    AND NVL(cv.TIP_PERSONA, ' ') = NVL(c_tip_persona, ' ')
    AND NVL(cv.cod_persona, ' ') = NVL(c_cod_persona, ' ');

    BEGIN

        paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

        IF p_cod_empresa is NULL and p_cod_persona is NULL then

            paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

            paw_uti.pr_insertarBitacora( NULL,
                                         v_cod_canal,
                                         p_cod_sesion_aux,
                                         null,
                                         null,
                                         'El cod_cliente debe suministrarse, fu_obt_cla_val_operacion ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                         paw_uti.BITACORA_ERROR);
            RETURN v_retorno;
        END IF;

        if p_cod_empresa is NULL then
          v_tip_persona := 'F';
          v_cod_persona := p_cod_persona;
        else
          v_tip_persona := 'J';
          v_cod_persona := p_cod_empresa;
        end if;

        v_cod_canal   := paw_uti.depurarNumerico(p_cod_canal, 3);

        paw_uti.pr_insertarBitacora(v_cod_persona,
                                v_cod_canal,
                                p_cod_sesion_aux,
                                null,
                                null,
                                'fu_obt_cla_val_operacion: [p_cod_persona=' || v_cod_persona || '][p_cod_tip_mensaje=' || p_cod_tip_mensaje || ']',
                                paw_uti.BITACORA_ENTRADA);
        BEGIN
                -- buscamos el perfect match
                 FOR cur_met IN c_met(p_cod_tip_mensaje, v_cod_persona, v_tip_persona) LOOP
                    v_existe := TRUE;
                    v_tip_clave := cur_met.cod_tip_clave;
                    v_tip_cla_sec := cur_met.cod_tip_cla_sec;

                 END LOOP;
                 -- Buscamos por tip persona
                 IF v_existe = FALSE THEN
                     FOR cur_met IN c_met(p_cod_tip_mensaje, NULL, v_tip_persona) LOOP
                        v_existe := TRUE;
                        v_tip_clave := cur_met.cod_tip_clave;
                        v_tip_cla_sec := cur_met.cod_tip_cla_sec;

                     END LOOP;
                 END IF;

                  -- Buscamos el general
                 IF v_existe = FALSE THEN
                    FOR cur_met IN c_met(p_cod_tip_mensaje, NULL, NULL) LOOP
                        v_existe := TRUE;
                        v_tip_clave := cur_met.cod_tip_clave;
                        v_tip_cla_sec := cur_met.cod_tip_cla_sec;
                     END LOOP;
                 END IF;

                 IF v_existe = FALSE THEN
                    --retornar error, no existe configurada la operacion
                     paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona,
                                                 v_cod_canal,
                                                 p_cod_sesion_aux,
                                                 null,
                                                 null,
                                                 'NO EXISTE CONFIGURACION EN BW_CLA_VAL_TIP_OPERACION PARA LA OPERACION ' || p_cod_tip_mensaje ||' , fu_obt_cla_val_operacion ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                 paw_uti.BITACORA_ERROR);
                     RETURN v_retorno;
                 END IF;

        EXCEPTION
          WHEN OTHERS THEN
              paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
              paw_uti.pr_insertarBitacora(v_cod_persona,
                                          v_cod_canal,
                                          p_cod_sesion_aux,
                                          null,
                                          null,
                                          'fu_obt_cla_val_operacion ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                          paw_uti.BITACORA_ERROR);
              RETURN v_retorno;
        END;

        BEGIN
            --chequeamos que el usuario tenga alguno de los metodos
            v_tie_tip_cla := lf_val_cli_tie_tip_clave(v_tip_clave, p_cod_persona, p_cod_empresa); --v_cod_persona, v_tip_persona);

            if v_tie_tip_cla = false then --no tiene el principal,vamos a chequear el secundario
                v_tie_tip_cla := lf_val_cli_tie_tip_clave(v_tip_cla_sec, p_cod_persona, p_cod_empresa); --v_cod_persona, v_tip_persona);
                v_tip_clave := v_tip_cla_sec; --Lo hacemos para poder referenciarlo despues.
            END IF;
        EXCEPTION
            WHEN OTHERS THEN

                IF sqlcode = -20001 then
                    --Entro en NA no puede avanzar
                    paw_uti.pr_mensajeUsuario(MSG_CLA_NA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    paw_uti.pr_insertarBitacora(v_cod_persona,
                                                v_cod_canal,
                                                p_cod_sesion_aux,
                                                null,
                                                null,
                                                'Error no puede avanzar, ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] '|| paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                paw_uti.BITACORA_ERROR);
                ELSIF sqlcode = -20002 then
                    --Debe actualizar su clave transaccional
                    paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_CAMBIAR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    paw_uti.pr_insertarBitacora(v_cod_persona,
                                                v_cod_canal,
                                                p_cod_sesion_aux,
                                                null,
                                                null,
                                                'Error , la clave transaccional debe ser cambiada, ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] '|| paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                paw_uti.BITACORA_ERROR);
                ELSE
                    paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    paw_uti.pr_insertarBitacora(v_cod_persona,
                                                    v_cod_canal,
                                                    p_cod_sesion_aux,
                                                    null,
                                                    null,
                                                    'Error al consultar si tiene clave, ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] '|| paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                    paw_uti.BITACORA_ERROR);
                END IF;
             RETURN v_retorno;
        END;

         if v_tie_tip_cla = false then
             --No tiene el tipo indicado, chequeamos por si exista alguna excepcion de acuerso al tip_mensaje
             v_tip_cla_aux := lf_val_cli_ope_excepcion(v_tip_clave, v_tip_cla_sec, p_cod_persona, p_cod_empresa, v_tip_persona);

             IF v_tip_cla_aux is NULL then
                 -- Error no tiene forma de confirmar
                 paw_uti.pr_mensajeUsuario(MSG_CLA_NO_TIENE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(v_cod_persona,
                                              v_cod_canal,
                                              p_cod_sesion_aux,
                                              null,
                                              null,
                                              'ERROR el cliente no tiene el tipo de clave, fu_obt_cla_val_operacion ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                              paw_uti.BITACORA_ERROR);
                 RETURN v_retorno;
              ELSE
                  v_tie_tip_cla := true;
                  v_tip_clave := v_tip_cla_aux; --Lo hacemos para poder referenciarlo despues.
              END IF;

         END IF;

         if v_tie_tip_cla = true then
             --todo OK
             --LLevar a una tabla maestra?
             CASE v_tip_clave
                WHEN 'L' THEN -- NONE - Libre
                    v_clave_desc := 'NONE';
                WHEN 'T' THEN -- Pin transaccional
                    v_clave_desc := 'PINTX';
                WHEN 'K' THEN -- token
                    v_clave_desc := 'TOKEN';
                WHEN 'S' THEN -- SoftToken
                    v_clave_desc := 'SOFTTOKEN';
             END CASE;
             v_retorno.tipoClaveValidacion := v_clave_desc;
             v_retorno.codigoTipoMensaje := p_cod_tip_mensaje;

        END IF;

        paw_uti.pr_insertarBitacora(v_cod_persona,
                                    v_cod_canal,
                                    p_cod_sesion_aux,
                                    null,
                                    null,
                                    'fu_obt_cla_val_operacion- Tipo Resultante '|| v_clave_desc || ' - ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                    BITACORA_SALIDA);

        RETURN v_retorno;
    EXCEPTION
        WHEN OTHERS THEN
            PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            PAW_UTI.pr_insertarBitacora(v_cod_persona,
                                        v_cod_canal,
                                        p_cod_sesion_aux,
                                        null,
                                        NULL,
                                        'fu_obt_cla_val_operacion: [p_cod_persona=' || v_cod_persona || '] : ERROR: ['|| sqlcode ||']',
                                        BITACORA_ERROR);
            RETURN v_retorno;
   END;

--recibe la clave en minusculas y hasheada en md5 recupera el salt del usuario y verifica que la clave sea igual a la guardada
FUNCTION fu_val_ope_clave(p_clave             IN VARCHAR2,
                          p_cod_persona       IN VARCHAR2,
                          p_cod_per_vinculada IN VARCHAR2,
                          p_tip_clave         IN VARCHAR2,
                          p_act_visitas       IN VARCHAR2 DEFAULT 'N') RETURN typ_mensajeRespuesta IS
   MSG_CLA_OPE_ESTADO   CONSTANT VARCHAR2(15) := 'CLA_OPE_ESTADO';
   MSG_CLA_OPE_INTENTOS CONSTANT VARCHAR2(15) := 'CLA_OPE_INTENTO';
   MSG_CLA_OPE_CAMBIAR  CONSTANT VARCHAR2(15) := 'CLA_OPE_CAMBIAR';
   MSG_CLA_OPE_INVALIDA CONSTANT VARCHAR2(15) := 'CLA_OPE_INVALID';
   v_salt        NUMBER;
   v_clave       VARCHAR(300);
   v_estado      VARCHAR(1);
   v_can_errores bw_ope_claves.can_intentos%TYPE; --NUMBER(2);
   v_max_intentos number;
   v_retorno     typ_mensajeRespuesta := typ_mensajeRespuesta;
   --Verifica que la clave si tiene mas de 3 intentos fallidos pase a estado B
   PROCEDURE lp_blo_clave(p_cod_persona       IN VARCHAR2,
                          p_cod_per_vinculada IN VARCHAR2,
                          p_tip_clave         IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      --v_can_intentos NUMBER;
   BEGIN
      UPDATE bw_ope_claves
        SET est_clave     = 'B',
            fec_est_clave = SYSDATE
      WHERE cod_persona = p_cod_persona
        AND est_clave IN ('A', 'M') -- se bloquea solo si esta para cambiar o modificado
        AND can_intentos >= v_max_intentos
        AND (
             (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
             (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
            )
        AND tip_clave = p_tip_clave;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;
   --registra que cuando ocurrio un error en el uso de la clave
   --para validar que no se ingrese mal la clave muy rapido
   PROCEDURE lp_reg_error(p_cod_persona       IN VARCHAR2,
                          p_cod_per_vinculada IN VARCHAR2,
                          p_tip_clave         IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   BEGIN
      UPDATE bw_ope_claves
         SET fec_ult_error = SYSDATE,
             can_intentos = nvl(can_intentos, 0) + 1
       WHERE cod_persona = p_cod_persona
         AND (
              (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
              (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
             )
         AND tip_clave = p_tip_clave;
      COMMIT;
      lp_blo_clave(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   --actualiza el ultimo acceso realizado, en caso de que la clave sea la correcta
   --reinicia el contados de intentos fallidos a 0
   PROCEDURE lp_act_visitas(p_cod_persona       IN VARCHAR2,
                            p_cod_per_vinculada IN VARCHAR2,
                            p_tip_clave         IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   BEGIN
      UPDATE bw_ope_claves
         SET can_acceso = can_acceso + 1,
             can_intentos = 0,
             fec_ult_acceso = SYSDATE
       WHERE cod_persona = p_cod_persona
         AND (
              (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
              (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
             )
         AND tip_clave = p_tip_clave;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
          -- por si bw_ope_claves.can_acceso llego a su tope, se reinicia
          UPDATE bw_ope_claves
             SET can_acceso = 0,
                 can_intentos = 0,
                 fec_ult_acceso = SYSDATE
           WHERE cod_persona = p_cod_persona
             AND (
                  (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
                  (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                 )
             AND tip_clave = p_tip_clave;
          COMMIT;
   END;
BEGIN

   IF fu_ver_ctr_clave(p_tip_clave) = 'S' THEN
   BEGIN
      -- obtiene el salt y el estado
      select cla_verificador, est_clave, can_intentos
        into v_salt, v_estado, v_can_errores
        from bw_ope_claves
       where cod_persona = p_cod_persona
         and (
              (p_cod_per_vinculada is null and cod_per_vinculada is null) or
              (p_cod_per_vinculada is not null and cod_per_vinculada = p_cod_per_vinculada)
             )
         and tip_clave = p_tip_clave;
   EXCEPTION
      WHEN too_many_rows THEN
         -- RETURN - 1;
         paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

         RETURN v_retorno;
      WHEN no_data_found THEN
         lp_reg_error(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
         -- RETURN - 2;
         paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;

   pr_act_est_ope_clave(p_cod_persona, p_cod_per_vinculada, p_tip_clave);


   v_clave := v_salt || '|' || p_clave;
   v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));

   -- obtenemos la m?ima cantidad de intentos de uso de claves
   BEGIN
      if p_tip_clave = 'T' then -- m?ima cantidad para clave transaccional
         v_max_intentos := to_number(fug_obt_pardinamico('CAN_INT_CLA_TRANSACCIONAL'));
      else -- m?ima cantidad para clave de acceso
         v_max_intentos := to_number(fug_obt_pardinamico('CAN_INT_CLA_ACCESO'));
      end if;
   EXCEPTION
     WHEN OTHERS THEN
       if p_tip_clave = 'T' then
         v_max_intentos := 3;
       else
         v_max_intentos := 5;
       end if;
   END;
   -- se controla el valor de v_max_intentos
   IF v_max_intentos IS NULL THEN
      v_max_intentos := 5;
   END IF;

   IF v_can_errores >= v_max_intentos THEN
      lp_reg_error(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
      -- v_cod_respuesta:=PAW_BCE.v_cla_ope_intentos;
      -- return paw_bce.v_cla_ope_intentos;
      IF v_estado in ('A', 'M', 'B') THEN
         paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSE
         paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_ESTADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;
      RETURN v_retorno;
   END IF;

           BEGIN
                -- validamos la clave
      select cla_verificador, est_clave
        into v_salt, v_estado
        from bw_ope_claves
       where cod_persona = p_cod_persona
         and (
              (p_cod_per_vinculada is null and cod_per_vinculada is null) or
              (p_cod_per_vinculada is not null and cod_per_vinculada = p_cod_per_vinculada)
             )
         and clave = v_clave
         and tip_clave = p_tip_clave;
      --La clave tiene que estar activa
      IF v_estado <> 'M' THEN
         IF v_estado = 'A' THEN
            -- v_cod_respuesta:=PAW_BCE.v_cla_ope_cambiar;
            --return paw_bce.v_cla_ope_cambiar;
            paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_CAMBIAR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
         ELSIF v_estado = 'B' THEN
            paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
         ELSE
            paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_ESTADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
            -- return -9;
         END IF;
      END IF;
   EXCEPTION
      WHEN too_many_rows THEN
         -- RETURN - 3;
         paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      WHEN no_data_found THEN
         lp_reg_error(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
         paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

         BEGIN
            select est_clave
              into v_estado
              from bw_ope_claves
             where cod_persona = p_cod_persona
               and nvl(p_cod_per_vinculada, 'x') = nvl(cod_per_vinculada, 'x')
               and tip_clave = p_tip_clave;

            IF v_estado = 'B' THEN
               paw_uti.pr_mensajeUsuario(MSG_CLA_OPE_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
        -- v_cod_respuesta:=paw_bce.v_cla_ope_invalida;
         RETURN v_retorno;
         --RETURN - 4;

           END;

   IF p_act_visitas = 'S' THEN
      lp_act_visitas(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
           END IF;
   END IF;
   -- v_cod_respuesta:=v_cod_aprobado;
   paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
   RETURN v_retorno;
   -- RETURN 0;
END;

   --Verifica los ultimos accesos de las claves y actualiza el estado de la misma
   PROCEDURE pr_act_est_ope_clave(p_cod_persona       IN VARCHAR2,
                                  p_cod_per_vinculada IN VARCHAR2,
                                  p_tip_clave         IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_ope_cam_cambio NUMBER(5);
      v_ope_cam_uso    NUMBER(5);
   BEGIN
      --Si no exite el parametro dinamico, toma 90 dias
      BEGIN
         IF p_tip_clave = 'T' THEN
           -- frecuencia de cambio para clave transaccional
           v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_CAMBIO', 1));
         ELSE
           -- frecuencia de cambio para clave de acceso
           v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('FRE_CAM_CLA_ACCESO_HB'));
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_ope_cam_cambio := 90;
      END;
      -- controlamos el valor de v_ope_cam_cambio
      IF v_ope_cam_cambio IS NULL THEN
         v_ope_cam_cambio := 90;
      END IF;
      -- Si no existe el paramtro dinamico toma 45
      BEGIN
         IF p_tip_clave = 'T' THEN
            -- frecuencia de cambio para clave transaccional
            v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO', 1));
         ELSE
            -- frecuencia de cambio para clave de acceso
            v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO_ACCESO'));
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_ope_cam_uso := 45;
      END;
      -- controlamos el valor de v_ope_cam_uso
      IF v_ope_cam_uso IS NULL THEN
         v_ope_cam_uso := 45;
      END IF;

      BEGIN
         --exige el cambio a las claves que no se usaron en un tiempo
         -- segun OPE_CAM_USO(transaccional) o OPE_CAM_USO_ACCESO(acceso) días
         UPDATE bw_ope_claves
            SET est_clave     = 'A',
                fec_est_clave = SYSDATE
          WHERE cod_persona   = p_cod_persona
            AND tip_clave     = p_tip_clave
            AND est_clave NOT IN ('X', 'I', 'B') -- no cambiar si el estado es anulada, impresa o bloqueada
            AND (
                  (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
                  (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                )
            AND (fec_ult_acceso IS NULL OR SYSDATE - fec_ult_acceso > v_ope_cam_uso);
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      BEGIN
         --Exigir el cambio de clave a los que cambiaron hace
         -- FRE_CAM_CLA_ACCESO_HB(Acceso) o OPE_CAM_CAMBIO(Transaccional) días
         UPDATE bw_ope_claves
            SET est_clave = 'A', fec_est_clave = SYSDATE
          WHERE cod_persona = p_cod_persona
            AND est_clave = 'M'
            AND (
                  (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
                  (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                )
            AND tip_clave = p_tip_clave
            AND SYSDATE - FEC_CAM_CLAVE > v_ope_cam_cambio;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   END;

   FUNCTION fu_obt_permisos(p_cod_persona        IN varchar2,
                            p_cod_perfil        IN varchar2,
                            p_cod_canal         in varchar2,
                            p_cod_operacion IN VARCHAR2) RETURN typ_permisos IS
      v_retorno  typ_permisos:=typ_permisos;
      v_consulta VARCHAR(5);
      v_registra VARCHAR(5);
      v_autoriza VARCHAR(5);

      p_nro_terminal cj_cajas.nro_caja%TYPE := p_cod_canal;
      MSG_OP_NO_PERMITIDA CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';
      MSG_OP_INEXISTENTE  CONSTANT VARCHAR2(15) := 'PER_OPE_INVALID';
      v_can_aut_requeridas number(3);
      v_cod_tip_mensaje        VARCHAR2(10); -- guarda el tipo IAC
   BEGIN
      SELECT TRIM(decode(consulta, 'S', 'C', '') || decode(ingresa, 'S', 'I', '') || decode(autoriza, 'S', 'A', ''))
        INTO v_cod_tip_mensaje
        FROM bw_tip_mensajes
       WHERE cod_tip_mensaje = p_cod_operacion;
      BEGIN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- busco primero especifico para la empresa
         SELECT consulta, ingresa, autoriza, nvl(can_firmas, 0)
           INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
           FROM bw_rol_permisos
          WHERE cod_perfil = p_cod_perfil
            AND cod_tip_mensaje = p_cod_operacion
            AND cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            -- busco los permisos generales para el perfil
            SELECT consulta, ingresa, autoriza, nvl(can_firmas, 0)
              INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
              FROM bw_rol_permisos
             WHERE cod_perfil = p_cod_perfil
               AND cod_tip_mensaje = p_cod_operacion
               AND cod_persona IS NULL;
      END;
      IF v_can_aut_requeridas > 0 AND paw_bce.fu_caj_homebanking(p_nro_terminal) = 'N' /*p_nro_terminal != '999'*/ THEN
         -- operacion no permitida en autoservicios por requerir autorizacion
         PAW_UTI.pr_mensajeUsuario(MSG_OP_NO_PERMITIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         --pr_insertarBitacora(p_cod_persona, p_nro_terminal, NULL, p_cod_operacion, NULL, 'Operacion no permitida-', BITACORA_ERROR);
      END IF;
      v_retorno.autoriza         := v_autoriza;
      v_retorno.consulta         := v_consulta;
      v_retorno.registra         := v_registra;
      v_retorno.canAutRequeridas := v_can_aut_requeridas;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(MSG_OP_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;

  /*
   *Verificacion de estado de clave transaccional
   *0 no tiene clave ni solicitud
   *1 tiene una clave transaccional y no tiene que hacer nada
   *2 ya tiene una o más claves en bw_ope_claves o solicitudes en bw_sol_claves
   *3 tiene que cambiar su clave
   */
   FUNCTION fu_verificarClaveTransaccional(p_codPersona          IN VARCHAR2,
                                           p_codPersonaVinculada IN VARCHAR2) RETURN NUMBER IS
      v_est_clave   VARCHAR2(1);
      --v_estado      NUMBER(1);
      --v_tip_mensaje VARCHAR2(3) := '224';
   BEGIN
      pr_act_est_ope_clave(p_codPersona, p_codPersonaVinculada, 'T');
      BEGIN
         SELECT EST_CLAVE
           INTO v_est_clave
           FROM bw_ope_claves
          WHERE cod_persona = p_codPersona
            AND tip_clave = 'T'
            AND (
                  (p_codPersonaVinculada IS NULL AND cod_per_vinculada IS NULL) OR
                  (p_codPersonaVinculada IS NOT NULL AND cod_per_vinculada = p_codPersonaVinculada)
                );
      EXCEPTION
         WHEN TOO_MANY_ROWS THEN
            --- ya tiene clave en bw_ope_claves
            --NULL;
            RETURN 2;
         WHEN NO_DATA_FOUND THEN
            --no tiene clave ni solicitud
            RETURN 0;
      END;
      IF (v_est_clave = 'A') THEN
         ---tiene que cambiar su clave
         RETURN 3;
      END IF;
      RETURN 1; --q tiene una clave transaccional y no tiene que hacer nada
   END;

   --hace un substr desde p_ini_ope_clave-1 hasta p_ini_ope_clave+31
   FUNCTION fu_val_cla_transaccional(p_cod_persona       IN VARCHAR2,
                                   p_cod_per_vinculada IN VARCHAR2,
                                   p_cla_transaccional IN VARCHAR2) RETURN typ_mensajeRespuesta IS
   BEGIN
      RETURN FU_VAL_OPE_CLAVE(p_cla_transaccional, p_cod_persona, p_cod_per_vinculada, 'T' , 'S');
   END;

  /** Crea una sesion para el canal y cuenta especificada
  * @param p_password        Contrase? en texto plano
  * @param p_dato            Informaci? de tercero que desea iniciar sesion. El tipo esta especificado en p_tipoDato
  * @param p_tipoDato        C?igo del tipo de cuenta que desea iniciar sesion. "D" documento, "K" codigo Persona, "C" tarjeta de credito
  * @param p_nroDocEmpresa   nro de RUC de empresa a la que esta vinculada la persona.Opcional
  * @param p_tipoDocEmpresa  Tipo de Documento de la empresa. "D" RUC
  * @param p_codCanal        C?igo de Canal para el cual se crear?la sesion
  * @return retorna informacion de la sesion creada  e informaci? referente a la cuenta.
  */
  FUNCTION fu_iniciarsesion(p_password       IN VARCHAR2,
                            p_dato           IN VARCHAR2,
                            p_tipodato       IN VARCHAR2,
                            p_nrodocempresa  IN VARCHAR2,
                            p_tipodocempresa IN VARCHAR2,
                            p_codcanal       IN VARCHAR2)
    RETURN typ_iniciarsesion IS
    PRAGMA AUTONOMOUS_TRANSACTION;

    -- variables
    --v_est_clave       VARCHAR2(1); -- estado de la clave: N-Nueva, A-Activa- B-bloqueada I_Inactiva
    v_tip_clave       VARCHAR2(1); -- Tipo de clave
    v_nro_doc_empresa VARCHAR2(20);
    v_tip_doc_empresa VARCHAR2(1);
    v_pos             NUMBER;
    v_can_intentos    NUMBER(4) := 0; -- cantidad de intentos fallidos
    v_password        VARCHAR2(32); -- clave del cliente (plaintext)
    v_clave           VARCHAR2(32); -- clave del cliente (almacenada en DB)

    v_nro_terminal      VARCHAR2(3);
    v_dato              VARCHAR2(18); -- Dato: nro de documento, cliente o cuenta
    v_tip_dato          VARCHAR2(01); -- Tipo: D-Nro.Doc, C-Cuenta, K-Cod.cliente
    v_cod_operacion     VARCHAR2(3); -- codigo de la operacion recibida
    v_tip_consulta      VARCHAR2(3);
    v_logmessage        VARCHAR2(1000);
    v_codusuariooficial ge_clientes.cod_usu_oficial%TYPE;
    v_tipopersona       ba_personas.tipo%TYPE;
    v_retorno           typ_iniciarsesion := typ_iniciarsesion;
    v_msj_respuesta     typ_mensajerespuesta := typ_mensajerespuesta;
    --Codigos de error
    msg_login_err               CONSTANT VARCHAR2(30) := 'L_ERROR'; --mensaje gen?ico
    msg_login_err_pin_bloqueado CONSTANT VARCHAR2(30) := 'L_PIN_BLOQUEADO';
    msg_login_vinc              CONSTANT VARCHAR2(30) := 'L_VIN_INEXISTE';
    --MSG_LOGIN_ERR_PIN_ANULADO      CONSTANT VARCHAR2(30) := 'L_PIN_ANULADO';
    msg_login_err_sin_autorizacion CONSTANT VARCHAR2(30) := 'L_SIN_AUTH';
    msg_login_err_vinculo_expirado CONSTANT VARCHAR2(30) := 'L_VIN_EXPIRADO';
    msg_login_par_invalido         CONSTANT VARCHAR2(30) := 'G_DATO_INV';
    msg_login_err_cla_inactiva     CONSTANT VARCHAR2(30) := 'CLA_OPE_ESTADO';
    cod_operacion                  CONSTANT VARCHAR2(5) := '005';
  function lf_asignar_perfil_fisica(p_cod_persona ge_clientes.cod_persona%type) return varchar2 is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    update ge_clientes c
    set c.cod_perfil = fug_obt_pardinamico('COD_PERFIL_FISICA_DEF')
    where c.cod_persona = p_cod_persona;
    commit;
    return fug_obt_pardinamico('COD_PERFIL_FISICA_DEF');
  exception
    when others then
      return null;
  end;
  BEGIN
    --Sanitizaci?
    --1. Asigno como valido al inicio
    paw_uti.pr_mensajeusuario(paw_uti.msg_ok, v_retorno.nombrerespuesta,
                              v_retorno.descripcionrespuesta,
                              v_retorno.error);
    --Logear todos los par?etros
    v_logmessage := substr('iniciarSesion(pass=*,p_dato=' || p_dato ||
                           ',p_tipoDato=' || p_tipodato ||
                           ',p_nroDocEmpresa=' || p_nrodocempresa ||
                           ',p_tipoDocEmpresa=' || p_tipodocempresa ||
                           ',p_codCanal=' || p_codcanal || ')', 0, 999);
    paw_uti.pr_insertarbitacora(p_dato, p_codcanal, NULL, cod_operacion,
                                p_nrodocempresa, v_logmessage,
                                paw_uti.bitacora_entrada);

    --2. Sanitizacion de Parametros
    -- Adicionar Sanitizaci?
    v_password        := paw_uti.depuraralfanumerico(p_password, 32); -- clave del cliente
    v_dato            := paw_uti.depurartextos(p_dato, paw_uti.cuenta_tamano); -- existen documentos extranjeros con -
    v_tip_dato        := nvl(paw_uti.depuraralfanumerico(p_tipodato, 1), 'C'); -- Tipo: D-Nro.Doc, C-Cuenta, K-Cod.clientea
    v_nro_doc_empresa := TRIM(p_nrodocempresa); -- empresa si es una empresa la conectada
    v_tip_doc_empresa := paw_uti.depuraralfanumerico(p_tipodocempresa, 1); -- tipo de documento de la empresa
    v_nro_terminal    := paw_uti.depurarnumerico(p_codcanal, 3);

    IF (length(v_password) = 0 OR v_nro_terminal IS NULL OR
       v_password IS NULL OR v_dato IS NULL OR length(v_nro_terminal) <> 3 OR
       length(v_dato) = 0 OR length(v_tip_dato) = 0) THEN
      paw_uti.pr_mensajeusuario(msg_login_err, v_retorno.nombrerespuesta,
                                v_retorno.descripcionrespuesta,
                                v_retorno.error);
      paw_uti. pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                   NULL,
                                   'Error ' ||
                                    paw_uti.fu_generarbitacora(v_retorno.error,
                                                               v_retorno.nombrerespuesta,
                                                               v_retorno.descripcionrespuesta,
                                                               NULL),
                                   paw_uti.bitacora_error);
      RETURN v_retorno;
    END IF;

    v_retorno.cambiarclave := 'N';

    IF v_tip_dato = 'C' AND
       (instr(v_dato, '-') > 0 OR instr(v_dato, ' ') > 0) THEN
      -- se extrae los guiones de la cuenta
      IF v_cod_operacion = '031' OR
         (v_cod_operacion = '010' AND v_tip_consulta = '031') THEN
        -- Si es pago de prestamos solo debe quitarle el guion y el espacio si tiene
        v_dato := TRIM(REPLACE(v_dato, '-', ''));
      ELSE
        v_pos := instr(v_dato, '-', -1);
        IF v_pos > 0 THEN
          v_dato := to_number(substr(v_dato, v_pos + 1));
        END IF;
      END IF;
    ELSIF length(v_dato) = 16 THEN
      -- es un tarjeta de credito, busco y reemplazo el dato
      DECLARE
        v_nro_cta_tar VARCHAR2(16);
      BEGIN
        SELECT b.nro_cuenta
        INTO v_nro_cta_tar
        FROM ta_tarjetas b
        WHERE b.nro_tarjeta = TRIM(v_dato)
        AND rownum = 1;
        -- cambio el nro_de_cuenta por
        v_dato := v_nro_cta_tar;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
      END;
    END IF;
    -- 3. valido los datos del cliente y su clave
    BEGIN

      IF v_tip_dato IN ('D') THEN
        -- nro de documento
        SELECT a.clave, b.nom_completo, a.cod_usu_oficial, b.cod_persona,
               a.can_intentos, nvl(a.tip_clave, 'C'), dir_correo, cod_perfil,
               b.tipo, a.cod_oficina
        INTO v_clave, v_retorno.nombrecompleto, v_codusuariooficial,
             v_retorno.codigocliente, v_can_intentos, v_tip_clave,
             v_retorno.emailcliente, v_retorno.codigoperfil, v_tipopersona,
             v_retorno.codoficina
        FROM ge_clientes a, ba_personas b
        WHERE a.cod_persona = b.cod_persona
        AND b.nro_documento = v_dato;
      ELSIF v_tip_dato IN ('K') THEN
        -- acceso por codigo de cliente ya no es permitido
        paw_uti.pr_mensajeusuario(msg_login_par_invalido,
                                  v_retorno.nombrerespuesta,
                                  v_retorno.descripcionrespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                    NULL,
                                    'Parametro inv?ido-' ||
                                     paw_uti.fu_generarbitacora(v_retorno.error,
                                                                v_retorno.nombrerespuesta,
                                                                v_retorno.descripcionrespuesta,
                                                                NULL),
                                    paw_uti.bitacora_error);
      ELSIF v_tip_dato = 'C' THEN
        -- por cuenta
        SELECT tipo, a.cod_persona, b.nom_completo, b.dir_correo
        INTO v_tipopersona, v_retorno.codigocliente,
             v_retorno.nombrecompleto, v_retorno.emailcliente
        FROM ba_personas b, ge_cta_clientes a
        WHERE a.nro_cuenta = v_dato
        AND a.relacion = 'P'
        AND a.cod_persona = b.cod_persona;
        BEGIN
          IF v_tipopersona = 'J' THEN
            -- empresa
            -- busqueda por clave
            SELECT a.clave, a.cod_usu_oficial, a.can_intentos,
                   nvl(a.tip_clave, 'C'), cod_perfil, a.cod_oficina
            INTO v_clave, v_codusuariooficial, v_can_intentos, v_tip_clave,
                 v_retorno.codigoperfil, v_retorno.codoficina
            FROM ge_clientes a
            WHERE a.cod_persona = v_retorno.codigocliente;
          ELSE
            -- la cuenta es de una persona fisica
            -- OMM 05/11/2010 Modificacion para que no tarde tanto el select
            BEGIN
              SELECT a.clave, b.nom_completo, a.cod_usu_oficial,
                     b.cod_persona, a.can_intentos, nvl(a.tip_clave, 'C'),
                     dir_correo, cod_perfil, a.cod_oficina
              INTO v_clave, v_retorno.nombrecompleto, v_codusuariooficial,
                   v_retorno.codigocliente, v_can_intentos, v_tip_clave,
                   v_retorno.emailcliente, v_retorno.codigoperfil,
                   v_retorno.codoficina
              FROM ge_clientes a, ba_personas b
              WHERE a.cod_persona = b.cod_persona
              AND b.cod_persona IN
                    (SELECT x.cod_persona
                     FROM ge_cta_clientes x
                     WHERE x.nro_cuenta = v_dato
                     AND x.cod_persona = b.cod_persona)
              AND rownum = 1; -- primero que encuentre
            EXCEPTION
              WHEN no_data_found THEN
                SELECT a.clave, b.nom_completo, a.cod_usu_oficial,
                       b.cod_persona, a.can_intentos, nvl(a.tip_clave, 'C'),
                       dir_correo, cod_perfil, a.cod_oficina
                INTO v_clave, v_retorno.nombrecompleto, v_codusuariooficial,
                     v_retorno.codigocliente, v_can_intentos, v_tip_clave,
                     v_retorno.emailcliente, v_retorno.codigoperfil,
                     v_retorno.codoficina
                FROM ge_clientes a, ba_personas b
                WHERE a.cod_persona = b.cod_persona
                AND length(a.clave) < 11
                AND b.cod_persona IN
                      (SELECT x.cod_persona
                       FROM ge_cta_clientes x
                       WHERE x.nro_cuenta = v_dato
                       AND x.cod_persona = b.cod_persona)
                AND rownum = 1; -- primero que encuentre
            END;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            --retValue.cod_respuesta := paw_bce.v_cod_pin_invalido;
            paw_uti.pr_mensajeusuario(msg_login_err,
                                      v_retorno.nombrerespuesta,
                                      v_retorno.descripcionrespuesta,
                                      v_retorno.error);
            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, NULL,
                                        'Pin inv?ido-' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                        paw_uti.bitacora_error);
            -- v_pinInvalido := 'S';
        END;

      ELSE
        --retValue.cod_respuesta := paw_bce.v_cod_cta_inexistente;
        paw_uti.pr_mensajeusuario(msg_login_err, v_retorno.nombrerespuesta,
                                  v_retorno.descripcionrespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                    NULL,
                                    'Cuenta inexistente - ' ||
                                     paw_uti.fu_generarbitacora(v_retorno.error,
                                                                v_retorno.nombrerespuesta,
                                                                v_retorno.descripcionrespuesta,
                                                                NULL),
                                    paw_uti.bitacora_error);
      END IF;
      /*
         BWP-207 - glopez
         En el caso de que el perfil esta vacio
      */
      if nvl(v_retorno.codigoperfil, 'X') != fug_obt_pardinamico('COD_PERFIL_FISICA_DEF') then
        v_retorno.codigoperfil := lf_asignar_perfil_fisica(v_retorno.codigocliente);
      end if;
    EXCEPTION
      WHEN no_data_found THEN
        --retValue.cod_respuesta := paw_bce.v_cod_cta_inexistente;
        paw_uti.pr_mensajeusuario(msg_login_err, v_retorno.nombrerespuesta,
                                  v_retorno.descripcionrespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                    NULL,
                                    'Cuenta inexistente - ' ||
                                     paw_uti.fu_generarbitacora(v_retorno.error,
                                                                v_retorno.nombrerespuesta,
                                                                v_retorno.descripcionrespuesta,
                                                                NULL),
                                    paw_uti.bitacora_error);
      WHEN too_many_rows THEN
        --retValue.cod_respuesta := paw_bce.v_cod_pin_inexistente;
        paw_uti.pr_mensajeusuario(msg_login_err, v_retorno.nombrerespuesta,
                                  v_retorno.descripcionrespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                    NULL,
                                    'PIN inexistente - ' ||
                                     paw_uti.fu_generarbitacora(v_retorno.error,
                                                                v_retorno.nombrerespuesta,
                                                                v_retorno.descripcionrespuesta,
                                                                NULL),
                                    paw_uti.bitacora_error);
    END;

    IF v_retorno.error = 'N' AND v_tipopersona = 'J' AND
       paw_bce.fu_caj_homebanking(v_nro_terminal) = 'S' /*v_nro_terminal = '999'*/
     THEN
      -- una persona juridica ya no tiene clave, no puede acceder
      --retValue.cod_respuesta := paw_bce.v_cod_pin_invalido;
      paw_uti.pr_mensajeusuario(msg_login_err, v_retorno.nombrerespuesta,
                                v_retorno.descripcionrespuesta,
                                v_retorno.error);
      paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                  NULL,
                                  'PIN invalido - ' ||
                                   paw_uti.fu_generarbitacora(v_retorno.error,
                                                              v_retorno.nombrerespuesta,
                                                              v_retorno.descripcionrespuesta,
                                                              NULL),
                                  paw_uti.bitacora_error);
      -- v_pinInvalido := 'S';
    END IF;
    -- 4. Veo la clave si la clave recibida corresponde a la actual
    --IF retValue.cod_respuesta IN (paw_bce.v_cod_aprobado, paw_bce.v_cod_pin_invalido) THEN
    IF v_retorno.error = 'N' /*OR v_pinInvalido = 'S'*/
     THEN
      -- verifico los datos de la empresa
      BEGIN
        IF v_tip_doc_empresa IN ('D') AND v_nro_doc_empresa IS NOT NULL THEN
          -- nro de documento de la empresa
          SELECT b.nom_completo, a.cod_usu_oficial, b.cod_persona,
                 dir_correo, b.tipo, a.cod_oficina
          INTO v_retorno.nombreempresa, v_codusuariooficial,
               v_retorno.codigoempresa, v_retorno.emailcliente,
               v_tipopersona, v_retorno.codoficina
          FROM ge_clientes a, ba_personas b
          WHERE a.cod_persona = b.cod_persona
          AND b.nro_documento = v_nro_doc_empresa;
        ELSIF v_tip_doc_empresa IN ('K') AND v_nro_doc_empresa IS NOT NULL THEN
          -- codigo de cliente - empresa
          SELECT b.nom_completo, a.cod_usu_oficial, b.cod_persona,
                 dir_correo, b.tipo, a.cod_oficina
          INTO v_retorno.nombreempresa, v_codusuariooficial,
               v_retorno.codigoempresa, v_retorno.emailcliente,
               v_tipopersona, v_retorno.codoficina
          FROM ge_clientes a, ba_personas b
          WHERE a.cod_persona = b.cod_persona
          AND b.cod_persona = v_nro_doc_empresa;
        END IF;
        IF v_tipopersona = 'F' AND v_nro_doc_empresa IS NOT NULL THEN
          -- no puede ingresar como empresa a una persona fisica
          --retValue.cod_respuesta := paw_bce.v_cod_pin_invalido;
          paw_uti.pr_mensajeusuario(msg_login_err,
                                    v_retorno.nombrerespuesta,
                                    v_retorno.descripcionrespuesta,
                                    v_retorno.error);
          paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                      cod_operacion, NULL,
                                      'PIN invalido' ||
                                       paw_uti.fu_generarbitacora(v_retorno.error,
                                                                  v_retorno.nombrerespuesta,
                                                                  v_retorno.descripcionrespuesta,
                                                                  NULL),
                                      paw_uti.bitacora_error);
          RETURN v_retorno;
        END IF;
        -- veo si tiene relacion la persona fisica con la empresa
        IF v_retorno.error = 'N' THEN
          DECLARE
            v_fec_ven_vinculo DATE;
          BEGIN
            IF v_retorno.codigoempresa IS NOT NULL THEN
              SELECT fec_vencimiento, cod_perfil
              INTO v_fec_ven_vinculo, v_retorno.codigoperfil
              FROM ba_vinculos
              WHERE cod_persona = v_retorno.codigoempresa
              AND cod_per_vinculo = v_retorno.codigocliente
              AND cod_perfil IS NOT NULL;
            END IF;
            IF v_retorno.codigoperfil IS NULL AND
               v_retorno.codigoempresa IS NOT NULL THEN
              --retValue.cod_respuesta := paw_bce.v_cod_vin_inexistente;
              --LOG "vinculo inexistente"
              paw_uti.pr_mensajeusuario(msg_login_err,
                                        v_retorno.nombrerespuesta,
                                        v_retorno.descripcionrespuesta,
                                        v_retorno.error);
              paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                          cod_operacion, NULL,
                                          'Vinculo Inexistente ' ||
                                           paw_uti.fu_generarbitacora(v_retorno.error,
                                                                      v_retorno.nombrerespuesta,
                                                                      v_retorno.descripcionrespuesta,
                                                                      NULL),
                                          paw_uti.bitacora_error);
              RETURN v_retorno;
            ELSIF v_retorno.codigoperfil IS NULL AND
                  v_retorno.codigoempresa IS NULL THEN
              --LOG "usuario sin autorizacion definida"
              paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,
                                        v_retorno.nombrerespuesta,
                                        v_retorno.descripcionrespuesta,
                                        v_retorno.error);
              paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                          cod_operacion, NULL,
                                          'Usuario sin autorizacion definida ' ||
                                           paw_uti.fu_generarbitacora(v_retorno.error,
                                                                      v_retorno.nombrerespuesta,
                                                                      v_retorno.descripcionrespuesta,
                                                                      NULL),
                                          paw_uti.bitacora_error);
              RETURN v_retorno;
            ELSIF v_fec_ven_vinculo < SYSDATE THEN
              --LOG "vinculo con empresa expirado"
              paw_uti.pr_mensajeusuario(msg_login_err_vinculo_expirado,
                                        v_retorno.nombrerespuesta,
                                        v_retorno.descripcionrespuesta,
                                        v_retorno.error);
              paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                          cod_operacion, NULL,
                                          'Vinculo con empresa expirado ' ||
                                           paw_uti.fu_generarbitacora(v_retorno.error,
                                                                      v_retorno.nombrerespuesta,
                                                                      v_retorno.descripcionrespuesta,
                                                                      NULL),
                                          paw_uti.bitacora_error);
              RETURN v_retorno;
            END IF;
          EXCEPTION
            WHEN no_data_found THEN
              --retValue.cod_respuesta := paw_bce.v_cod_vin_inexistente;
              paw_uti.pr_mensajeusuario(msg_login_vinc,
                                        v_retorno.nombrerespuesta,
                                        v_retorno.descripcionrespuesta,
                                        v_retorno.error);
              paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                          cod_operacion, NULL,
                                          'Vinculo inexistente ' ||
                                           paw_uti.fu_generarbitacora(v_retorno.error,
                                                                      v_retorno.nombrerespuesta,
                                                                      v_retorno.descripcionrespuesta,
                                                                      NULL),
                                          paw_uti.bitacora_error);
              RETURN v_retorno;
            WHEN OTHERS THEN
              --retValue.cod_respuesta := paw_bce.v_cod_vin_inexistente;
              paw_uti.pr_mensajeusuario(msg_login_vinc,
                                        v_retorno.nombrerespuesta,
                                        v_retorno.descripcionrespuesta,
                                        v_retorno.error);
              paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                          cod_operacion, NULL,
                                          'Vinculo Error ' ||
                                           paw_uti.fu_generarbitacora(v_retorno.error,
                                                                      v_retorno.nombrerespuesta,
                                                                      v_retorno.descripcionrespuesta,
                                                                      NULL),
                                          paw_uti.bitacora_error);
              RETURN v_retorno;
          END;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          --retValue.cod_respuesta := paw_bce.v_cod_cta_inexistente;
          paw_uti.pr_mensajeusuario(msg_login_err,
                                    v_retorno.nombrerespuesta,
                                    v_retorno.descripcionrespuesta,
                                    v_retorno.error);
          paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                      cod_operacion, NULL,
                                      'Cuenta inexistente ' ||
                                       paw_uti.fu_generarbitacora(v_retorno.error,
                                                                  v_retorno.nombrerespuesta,
                                                                  v_retorno.descripcionrespuesta,
                                                                  NULL),
                                      paw_uti.bitacora_error);
          RETURN v_retorno;
      END;
      -- fin verificacion datos empresa

      --Verificaion Blacklist
      IF paw_seg.fu_obtenerblacklist(v_retorno.codigocliente) = 'S' THEN
        paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,
                                  v_retorno.nombrerespuesta,
                                  v_retorno.descripcionrespuesta,
                                  v_retorno.error);
        paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL, cod_operacion,
                                    NULL,
                                    'Usuario sin autorizacion definida ' ||
                                     paw_uti.fu_generarbitacora(v_retorno.error,
                                                                v_retorno.nombrerespuesta,
                                                                v_retorno.descripcionrespuesta,
                                                                NULL),
                                    paw_uti.bitacora_error);
        RETURN v_retorno;
      END IF;

      /*
      -1 Se encontro varios
      -2 No se encontro
      paw_bce.v_cla_ope_cambiar Cambia clave
      -9 Bloqueado
      -4 No es la clave
      -3 error interno
      BBVAHB-745: Se cambia la l?ica del control de la clave de acceso
      */
      IF v_retorno.error = 'N' THEN
        -- aca se valida la clave
        v_msj_respuesta := paw_seg.fu_val_ope_clave(v_password,
                                                    v_retorno.codigocliente,
                                                    v_retorno.codigoempresa,
                                                    'A', 'S');
        IF v_msj_respuesta.error = 'S' THEN
          --Si no est?aprobada la verificaci? hay que traducir los errores
          IF v_msj_respuesta.nombrerespuesta = 'CLA_OPE_INTENTO' THEN
            paw_uti.pr_mensajeusuario(msg_login_err_pin_bloqueado,
                                      v_retorno.nombrerespuesta,
                                      v_retorno.descripcionrespuesta,
                                      v_retorno.error);
            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, NULL,
                                        'Clave bloqueada ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                        paw_uti.bitacora_error);
          ELSIF v_msj_respuesta.nombrerespuesta IN
                ('CLA_OPE_INVALID' ) THEN
            paw_uti.pr_mensajeusuario(msg_login_err,
                                      v_retorno.nombrerespuesta,
                                      v_retorno.descripcionrespuesta,
                                      v_retorno.error);
            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, NULL,
                                        'Clave invalida ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                        paw_uti.bitacora_error);
          ELSIF v_msj_respuesta.nombrerespuesta = 'CLA_OPE_ESTADO' then
            paw_uti.pr_mensajeusuario(msg_login_err_cla_inactiva,
                                      v_retorno.nombrerespuesta,
                                      v_retorno.descripcionrespuesta,
                                      v_retorno.error);
            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, NULL,
                                        'Clave Inactiva ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                                                    paw_uti.bitacora_error);
          ELSIF v_msj_respuesta.nombrerespuesta = 'CLA_OPE_CAMBIAR' AND p_codcanal <> '990' THEN
            v_retorno.cambiarclave := 'S';
          ELSIF v_msj_respuesta.nombrerespuesta = 'CLA_OPE_CAMBIAR' AND p_codcanal = '990' THEN
            v_retorno.cambiarclave := 'S';
            v_retorno.error                := 'S';
            v_retorno.nombrerespuesta      := v_msj_respuesta.nombrerespuesta;
            v_retorno.descripcionrespuesta := 'INGRESE A LA WEB PARA EL CAMBIO';
            v_retorno.cambiarclave := 'S';

            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, v_retorno.codigoempresa,
                                        'Cambiar Clave ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    v_retorno.cambiarclave),
                                                                    paw_uti.bitacora_error);
            return v_retorno;
          ELSE
            v_retorno.error                := v_msj_respuesta.error;
            v_retorno.nombrerespuesta      := v_msj_respuesta.nombrerespuesta;
            v_retorno.descripcionrespuesta := v_msj_respuesta.descripcionrespuesta;
          END IF;
        END IF;
      END IF;
      IF v_retorno.error = 'N' THEN
        DECLARE
          v_permiso    typ_permisos := typ_permisos;
        BEGIN
          -- ahora verifico si el usuario tiene acceso a la opcion y en que condicion
          v_permiso := paw_seg.fu_obt_permisos(nvl(v_retorno.codigoempresa,
                                                   v_retorno.codigocliente),
                                               v_retorno.codigoperfil,
                                               p_codcanal, --v_val_sesion.codigocanal,
                                               cod_operacion); --nvl(v_retorno.codigoEmpresa, v_retorno.codigoCliente), v_retorno.codigoPerfil, '005', v_nro_terminal); --XXX operacion 005?

          IF (v_permiso.error = 'S') THEN
            v_retorno.nombrerespuesta      := v_permiso.nombrerespuesta;
            v_retorno.descripcionrespuesta := v_permiso.descripcionrespuesta;
            v_retorno.error                := v_permiso.error;
            paw_uti.pr_insertarbitacora(v_retorno.codigocliente, p_codcanal,
                                        NULL, cod_operacion,
                                        v_retorno.codigoempresa,
                                        'lf_obt_permisos - ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                        paw_uti.bitacora_error);
            RETURN v_retorno;
          END IF;

          --IF v_permiso IS NULL THEN
          IF v_permiso.autoriza = 'N' AND v_permiso.registra = 'N' AND
             v_permiso.consulta = 'N' THEN
            --retValue.cod_respuesta := paw_bce.v_cod_sin_autorizacion;
            paw_uti.pr_mensajeusuario(msg_login_err_sin_autorizacion,
                                      v_retorno.nombrerespuesta,
                                      v_retorno.descripcionrespuesta,
                                      v_retorno.error);
            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, NULL,
                                        'Cuenta sin autorizacion ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                        paw_uti.bitacora_error);
            RETURN v_retorno;
          END IF;
        END;
        BEGIN
          --Obtener datos del oficial
          SELECT substr(nvl(u.nombre, ' '), 1, 50),
                 substr(nvl(u.telefono, '6188000'), 1, 10),
                 nvl(u.dir_correo, fug_obt_dir_correo) dir_correo
          INTO v_retorno.nombreoficial, v_retorno.telefonooficial,
               v_retorno.emailoficial
          FROM ba_usuarios u
          WHERE cod_usuario = v_codusuariooficial;
          --Comentado, es un mensaje que se mostraba al usuario
          --v_retorno.mensaje := paw_uti.lf_obt_mensaje(nvl(v_nro_doc_empresa, v_retorno.codigoCliente));

          v_retorno.esvip := paw_bce.fu_es_vip(nvl(v_retorno.codigoempresa,
                                                   v_retorno.codigocliente));
        EXCEPTION
          WHEN OTHERS THEN
            --retValue.cod_respuesta  := paw_bce.v_cod_otr_error;
            paw_uti.pr_mensajeusuario(msg_login_err,
                                      v_retorno.nombrerespuesta,
                                      v_retorno.descripcionrespuesta,
                                      v_retorno.error);
            paw_uti.pr_insertarbitacora(v_dato, p_codcanal, NULL,
                                        cod_operacion, NULL,
                                        'Error ' ||
                                         paw_uti.fu_generarbitacora(v_retorno.error,
                                                                    v_retorno.nombrerespuesta,
                                                                    v_retorno.descripcionrespuesta,
                                                                    NULL),
                                        paw_uti.bitacora_error);
            RETURN v_retorno;
        END;
        -- obtener descripcion del perfil
        BEGIN
          SELECT p.descripcion
          INTO v_retorno.descripcionperfil
          FROM bw_perfiles p
          WHERE p.cod_perfil = v_retorno.codigoperfil;
        EXCEPTION
          WHEN OTHERS THEN
            v_retorno.descripcionperfil := 'SIN PERFIL ASIGNADO';
        END;
      END IF;

      -- valida que un cliente tenga permitido ver encuestas de opinator
      v_retorno.veEncuesta := 'N';
      IF v_retorno.error = 'N' AND v_tipoPersona = 'F' THEN
         IF NVL(fug_obt_es_per_inhi(v_retorno.codigoCliente),'X') = 'N' AND
            NVL(fug_es_empleado(v_retorno.codigoCliente), 'X') = 'N' THEN
            v_retorno.veEncuesta := 'S';
         END IF;
      END IF;

      -- retorna el nro de documento de la persona logueada
      IF v_retorno.error = 'N' THEN
        v_retorno.nrodocumento := fue_obt_nro_doc_persona(v_retorno.codigocliente);
      END IF;

    END IF;

    --Verificacion de estado de clave transaccional
    v_retorno.estadoclavetran := fu_verificarclavetransaccional(v_retorno.codigocliente,
                                                                v_retorno.codigoempresa);
    -- Registrar acceso -- 04/2018
    BEGIN
      IF nvl(v_retorno.error, 'S') = 'N' THEN
        paw_bas.pr_reg_acc_cli_digitales(nvl(v_retorno.codigoempresa,
                                             v_retorno.codigocliente),
                                         p_codcanal);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_insertarbitacora(v_retorno.codigocliente, p_codcanal,
                                    v_retorno.sesionusuario, cod_operacion,
                                    v_retorno.codigoempresa,
                                    'PAW_BAS.pr_reg_acc_cli_digitales -' ||
                                     SQLERRM, paw_uti.bitacora_error);
    END;
    --
    RETURN v_retorno;
  END;

  FUNCTION fu_ins_otp(p_cod_persona           IN VARCHAR2,
                       p_cod_per_vinculada     IN VARCHAR2,
                       p_cod_canal             IN VARCHAR2,
                       p_otp_value             IN VARCHAR2,
                       p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta IS
    v_id                     NUMBER;
    v_cod_operacion VARCHAR2(3) := '009';
    v_retorno          typ_mensajerespuesta := typ_mensajerespuesta();
    v_msj_bitacora VARCHAR2(800) := substr('p_otp_value:' || '*****', 1, 800);
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
    paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ENTRADA);

    BEGIN
      SELECT S_BW_OTP.Nextval
      INTO v_id
      FROM DUAL;
      INSERT INTO BW_OTP (NRO_OTP, COD_PERSONA, COD_PER_VINCULADA, OTP, ESTADO)
      VALUES
      (v_id, p_cod_persona, p_cod_per_vinculada, p_otp_value, 'P');
    EXCEPTION
       WHEN OTHERS THEN
          paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
          paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
    END;

    RETURN v_retorno;
  END;

  FUNCTION fu_val_otp(p_cod_persona           IN VARCHAR2,
                       p_cod_per_vinculada     IN VARCHAR2,
                       p_cod_canal             IN VARCHAR2,
                       p_otp_value             IN VARCHAR2,
                       p_id_sesion IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta IS
     v_retorno           typ_mensajerespuesta := typ_mensajerespuesta();
     OTP_INVALIDO        VARCHAR2(15) := 'OTP_INVALIDO';
     OTP_ANULADO         VARCHAR2(15) := 'OTP_ANULADO';
     OTP_EXPIRADO        VARCHAR2(15) := 'OTP_EXPIRADO';
     reg                 BW_OTP%ROWTYPE;
     v_can_max_intentos  NUMBER := 3; --LLEVAR A PAR DINAMICO
     v_max_val_minutos   NUMBER := 5;
     v_can_intento       NUMBER;
     v_estado            VARCHAR2(1) := 'P';
     v_fec_error         DATE;
     v_cod_operacion VARCHAR2(3) := '009';
     v_msj_bitacora VARCHAR2(800) := substr('p_otp_value:' || '*****', 1, 800);

     BEGIN
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ' ' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), paw_uti.BITACORA_ENTRADA);

        BEGIN
           SELECT *
           INTO reg
           FROM BW_OTP o
           WHERE o.cod_persona = p_cod_persona
              AND (o.cod_per_vinculada = p_cod_per_vinculada OR o.cod_per_vinculada IS NULL)
              AND o.estado = 'P'
              AND o.nro_otp = (SELECT MAX(NRO_OTP) OO
                               FROM bw_otp oo
                               WHERE OO.COD_PERSONA = p_cod_persona
                                  AND (OO.COD_PER_VINCULADA = p_cod_per_vinculada OR OO.COD_PER_VINCULADA IS NULL)
                                  AND OO.ESTADO = 'P');
            v_can_intento := NVL(reg.can_intentos,0);
            IF ((SYSDATE - reg.fec_insercion) * 1440) > v_max_val_minutos THEN
               paw_uti.pr_mensajeUsuario(OTP_EXPIRADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || 'OTP EXPIRADO ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
               v_estado := 'A';
            END IF;
            IF v_can_intento >= v_can_max_intentos THEN
               paw_uti.pr_mensajeUsuario(OTP_ANULADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || 'OTP ANULADO POR CANT DE INTENTOS ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);
               v_estado := 'A';
            END IF;
            IF v_retorno.error = 'N' THEN
               IF p_otp_value <> reg.otp THEN
                  v_can_intento := v_can_intento + 1;
                  paw_uti.pr_mensajeUsuario(OTP_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || 'OTP INVALIDO ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);

               END IF;
            END IF;
            IF v_retorno.error = 'N' THEN
              v_estado := 'C';
              v_fec_error := reg.fec_ult_error;
            ELSE
              v_fec_error := SYSDATE;
            END IF;
            UPDATE BW_OTP o SET o.estado = v_estado, o.can_intentos = v_can_intento, o.fec_ult_error = v_fec_error
            WHERE o.nro_otp = reg.nro_otp;
        EXCEPTION
           WHEN OTHERS THEN
              paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
              paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_id_sesion, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora || ', ORA-ERR:[' || SUBSTR(SQLERRM, 1, 200) || '] ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ), paw_uti.BITACORA_ERROR);

        END;
        RETURN v_retorno;
     END;
  -- validar pseudo sesion para consumidores del runes
  PROCEDURE fu_val_ses_consumer(p_sesion        IN VARCHAR2,
                                p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                                p_error         OUT VARCHAR2,
                                p_nom_respuesta OUT VARCHAR2,
                                p_des_respuesta OUT VARCHAR2,
                                p_cod_persona   OUT ba_personas.cod_persona%TYPE,
                                p_cod_empresa   OUT ba_personas.cod_persona%TYPE,
                                p_cod_perfil    OUT bw_perfiles.cod_perfil%TYPE) IS
     v_cod_per_principal bw_mov_pendientes.nro_documento%TYPE;
     v_cod_tip_mensaje   bw_mov_pendientes.cod_tip_mensaje%TYPE;
     v_nro_documento     bw_autorizaciones.nro_documento%TYPE;
     v_cod_perfil        bw_perfiles.cod_perfil%TYPE;
     v_separador         VARCHAR2(1) := '|';
     v_hash              VARCHAR2(32);
     v_valor             VARCHAR2(32);
     v_ok                VARCHAR2(1) := 'N';
     -- autorizadores del movimiento
     CURSOR c_autorizadores IS
       SELECT a.cod_persona
         FROM bw_autorizaciones a
        WHERE a.nro_documento = v_nro_documento
          AND a.accion = 'A';
  BEGIN
     -- obtenemos los datos
     SELECT to_number(trim(substr(p_sesion, 1, 15))), substr(p_sesion, 16, 32)
       INTO v_nro_documento, v_hash
       FROM dual;
     -- buscamos el dato pendiente que se encuentre enconaldo
     SELECT p.cod_per_principal, p.cod_tip_mensaje
       INTO v_cod_per_principal, v_cod_tip_mensaje
       FROM bw_mov_pendientes p
      WHERE p.nro_documento = v_nro_documento
        AND p.estado = 'E'
        AND p.can_aut_faltantes = 0;

     FOR au IN c_autorizadores LOOP
       v_valor := paw_bce.fu_enc_md5(v_cod_per_principal||v_separador||au.cod_persona||v_separador||v_cod_tip_mensaje||v_separador||p_cod_canal);
       IF v_valor = v_hash THEN
          v_cod_perfil := fuw_obt_per_empresa(v_cod_per_principal, au.cod_persona);
          IF v_cod_perfil IS NOT NULL THEN
             v_ok := 'S';
             p_cod_empresa := v_cod_per_principal;
             p_cod_persona := au.cod_persona;
             p_cod_perfil  := v_cod_perfil;
             paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, p_nom_respuesta, p_des_respuesta, p_error);
          END IF;
          -- ya no hace falta seguir
          EXIT;
       END IF;
     END LOOP;
     IF v_ok = 'N' THEN
        paw_uti.pr_mensajeUsuario('L_AUTH_ERROR', p_nom_respuesta, p_des_respuesta, p_error);
        paw_uti.pr_insertarBitacora(p_sesion, p_cod_canal, NULL, '005', NULL, 'fu_val_ses_consumer- Error Canal ' || paw_uti.fu_generarBitacora(p_error, p_nom_respuesta, p_des_respuesta,null), paw_uti.BITACORA_ERROR);
     END IF;
  EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario('L_AUTH_ERROR', p_nom_respuesta, p_des_respuesta, p_error);
        paw_uti.pr_insertarBitacora(p_sesion, p_cod_canal, NULL, '005', NULL, 'fu_val_ses_consumer- Error Canal ' || paw_uti.fu_generarBitacora(p_error, p_nom_respuesta, p_des_respuesta,null), paw_uti.BITACORA_ERROR);
  END;

   FUNCTION fu_val_per_operacion(p_cod_persona           IN VARCHAR2,
                                p_cod_per_vinculada     IN VARCHAR2,
                                p_cod_canal             IN VARCHAR2,
                                p_operaciones           IN VARCHAR2) RETURN typ_mapa IS
      v_cod_operacion VARCHAR2(3) := '023';
      v_permiso               typ_permisos := typ_permisos();
      v_retorno               typ_mapa := typ_mapa();
      v_datAdicionales             typ_listaclavevalor := typ_listaclavevalor();
      v_claveValor                  typ_clavevalor := typ_clavevalor();
      v_res_limite            VARCHAR2(3);
      v_lim_general           VARCHAR2(3) := '-1';
      v_perfil                VARCHAR2(50);
      v_mensajeError          VARCHAR2(1000);
      v_prioridad             NUMBER;
      v_max_prioridad         NUMBER := -1;
      MSG_CLA_NO_TIENE   CONSTANT VARCHAR2(15) := 'CLA_OPE_N_TIENE';
      PRO_AUT_SIN_PERMISO         CONSTANT VARCHAR2(15) := 'PRO_AUT_SIN_PER';
      v_msj_bitacora          VARCHAR2(700) := substr('fu_val_per_operacion - codPersona:'||trim(p_cod_persona)
                                                       ||', codPerVinculada:'||trim(p_cod_per_vinculada)
                                                       ||', canal:'||trim(p_cod_canal)
                                                       ||', operaciones:'||trim(p_operaciones), 1, 200);

      CURSOR c_operaciones IS
         SELECT *
         FROM BW_MOV_PENDIENTES P
         WHERE P.NRO_DOCUMENTO IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(p_operaciones, ',' )))
            AND P.COD_PER_PRINCIPAL = p_cod_per_vinculada
            AND p.estado IN ('P', 'I');
   BEGIN
     BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);


      v_perfil := fuw_obt_per_empresa(p_cod_per_vinculada, p_cod_persona);
      v_msj_bitacora := v_msj_bitacora||', perfil:'||v_perfil;

      v_permiso := paw_seg.fu_obt_permisos(p_cod_per_vinculada, v_perfil, p_cod_canal, v_cod_operacion);
      IF (v_permiso.error = 'S') THEN
         paw_uti.pr_mensajeUsuario(v_permiso.nombreRespuesta,
                                   v_retorno.nombreRespuesta,
                                   v_retorno.descripcionRespuesta,
                                   v_retorno.error);
      END IF;
      v_msj_bitacora := substr(v_msj_bitacora||', paw_seg.fu_obt_permisos ('||p_cod_per_vinculada||','||v_perfil||' '||','||p_cod_canal||','||v_cod_operacion||')',1,700);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, null, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora||' '||paw_bem.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL), BITACORA_ENTRADA);

      IF v_retorno.error = 'N' THEN
         FOR mp IN c_operaciones LOOP
            v_permiso := paw_seg.fu_obt_permisos(p_cod_per_vinculada, v_perfil, p_cod_canal, mp.cod_tip_mensaje);
            v_msj_bitacora := substr(' paw_seg.fu_obt_permisos('||p_cod_per_vinculada||','||v_perfil||','||p_cod_canal||','||mp.cod_tip_mensaje||')',1,700);
            -- TODO: si no tiene permiso en un documento retornamos error
            IF (v_permiso.error = 'S') THEN
               paw_uti.pr_mensajeUsuario(v_permiso.nombreRespuesta,
                                   v_retorno.nombreRespuesta,
                                   v_retorno.descripcionRespuesta,
                                   v_retorno.error);
               v_msj_bitacora := substr(v_msj_bitacora || paw_bem.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL),1,700);
               paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, null, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora||' '||paw_bem.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL), BITACORA_ERROR);
               EXIT;
            END IF;

            v_msj_bitacora := substr(v_msj_bitacora || paw_bem.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL),1,700);

            v_res_limite := paw_bce.fu_obt_aut_limite(p_cod_per_vinculada, mp.nro_documento, p_cod_persona);
            SELECT
               CASE v_res_limite
               WHEN '00' THEN 0
               WHEN '10' THEN 1
               WHEN '01' THEN 2
               WHEN '11' THEN 3
               WHEN '02' THEN 4
            END prioridad
            INTO v_prioridad
            FROM DUAL;


            IF v_prioridad > v_max_prioridad THEN
               v_max_prioridad := v_prioridad;
               v_lim_general := v_res_limite;
            END IF;

            v_msj_bitacora := substr(v_msj_bitacora ||'- paw_bce.fu_obt_aut_limite('||p_cod_per_vinculada||','||mp.nro_documento||','||p_cod_persona||'), restLimite='||v_res_limite,1,700);
            paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, null, v_cod_operacion, p_cod_per_vinculada, v_msj_bitacora||' '||paw_bem.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta, NULL), BITACORA_ENTRADA);
         END LOOP;

         --DDSI-1513 Paliativo para impresión de error en bitácora.
         IF to_number(v_lim_general) < 0 THEN

             IF v_lim_general = '-1' THEN
                -- Ingreso en limite excedido
                v_mensajeError := 'ERROR el límite ha sido excedido, fu_val_per_operacion ';
             ELSIF v_lim_general = '-2' THEN
                -- Ingreso en verificacion de soft-token
                v_mensajeError := 'ERROR configuración soft-token inexistente, fu_val_per_operacion ';
             ELSIF v_lim_general = '-3' THEN
                -- Ingresó en límite no definido en bw_cla_lim_montos
                v_mensajeError := 'ERROR límite no definido para la operación, fu_val_per_operacion ';
             ELSIF v_lim_general = '-4' THEN
                -- Ingresó en validacion de clave token en Vasco
                v_mensajeError := 'ERROR de validación de clave token en Vasco, fu_val_per_operacion ';
             END IF;

             paw_uti.pr_mensajeUsuario(PRO_AUT_SIN_PERMISO, v_retorno.nombreRespuesta,
                         v_retorno.descripcionRespuesta, v_retorno.error);
             paw_uti.pr_insertarBitacora(p_cod_persona,
                                                  p_cod_canal,
                                                  null,
                                                  v_cod_operacion,
                                                  p_cod_per_vinculada,
                                                  v_msj_bitacora||' v_lim_general:'||v_lim_general ||' '||v_mensajeError || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                                  paw_uti.BITACORA_ERROR);
         END IF;

         IF v_retorno.error = 'N' THEN
            v_claveValor.clave := 'TIP_CLAVE';
            v_claveValor.valor :=  v_lim_general;
            v_claveValor.tipo := 'varchar';
            v_datAdicionales.extend;
            v_datAdicionales(v_datAdicionales.count) := v_claveValor;
         END IF;

         IF v_max_prioridad = 4 THEN
               DECLARE
                  v_serial VARCHAR2(50);
               BEGIN
                  SELECT S.NRO_SERIAL
                  INTO v_serial
                  FROM BW_SOF_SERIALES S, BW_SOF_EMPRESAS E
                  WHERE S.ID = E.SOF_SER_ID AND S.COD_PERSONA = p_cod_persona
                     AND E.COD_PER_VINCULADA = p_cod_per_vinculada
                     AND E.ESTADO = 'A' AND ROWNUM = 1;
                  v_claveValor.clave := 'SERIAL';
                  v_claveValor.valor :=  v_serial;
                  v_claveValor.tipo := 'varchar';
                  v_datAdicionales.extend;
                  v_datAdicionales(v_datAdicionales.count) := v_claveValor;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                       paw_uti.pr_mensajeUsuario(MSG_CLA_NO_TIENE, v_retorno.nombreRespuesta,
                       v_retorno.descripcionRespuesta, v_retorno.error);

                       paw_uti.pr_insertarBitacora(p_cod_persona,
                                                  p_cod_canal,
                                                  null,
                                                  v_cod_operacion,
                                                  p_cod_per_vinculada,
                                                  'ERROR el cliente no tiene el tipo de clave, fu_val_per_operacion ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null),
                                                  paw_uti.BITACORA_ERROR);
               END;
            END IF;
             v_retorno.cantidad := v_datAdicionales.Count;
             v_retorno.datosAdicionales := v_datAdicionales;

      END IF;
      EXCEPTION
         WHEN OTHERS THEN
            paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta,
                                  v_retorno.descripcionRespuesta,
                                  v_retorno.error);
      END;

      paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, null, v_cod_operacion, p_cod_per_vinculada, 'fu_val_per_operacion -' ||paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_SALIDA);

      RETURN v_retorno;
   END;

   FUNCTION fu_obt_cla_validar(p_clave             IN VARCHAR2,
                               p_cod_persona       IN VARCHAR2,
                               p_cod_per_vinculada IN VARCHAR2,
                               p_cod_canal         IN VARCHAR2,
                               p_operaciones       IN VARCHAR2) RETURN typ_mapa IS
   v_retorno                   typ_mapa := typ_mapa();
   v_tip_cla_map               typ_clavevalor := typ_clavevalor();
   v_val_retorno               typ_mensajerespuesta := typ_mensajerespuesta();
   v_tip_clave                 VARCHAR2(3);

   BEGIN
      -- TODO: AGREGAR BITACORA
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK,
                                v_retorno.nombreRespuesta,
                                v_retorno.descripcionRespuesta,
                                v_retorno.error);
      v_retorno := paw_seg.fu_val_per_operacion(p_cod_persona,p_cod_per_vinculada, p_cod_canal, p_operaciones);
      IF v_retorno.error = 'N' THEN
         v_tip_cla_map := v_retorno.datosAdicionales(1);
         IF v_tip_cla_map IS NOT NULL AND v_tip_cla_map.valor IS NOT NULL THEN
            v_tip_clave := v_tip_cla_map.valor;
            IF v_tip_clave = '10' THEN
               v_val_retorno := paw_seg.FU_VAL_OPE_CLAVE(p_clave, p_cod_persona, p_cod_per_vinculada, 'T', 'S');
            ELSIF v_tip_clave = '01' THEN
               v_val_retorno :=  fu_obt_tok_validar(p_clave, p_cod_persona, p_cod_per_vinculada, 'C');
            END IF;
            IF v_val_retorno.error = 'S' THEN
               paw_uti.pr_mensajeUsuario(v_val_retorno.nombreRespuesta, v_retorno.nombreRespuesta,
                  v_retorno.descripcionRespuesta, v_retorno.error);
            END IF;
         END IF;

      END IF;
      RETURN v_retorno;
   END;

   /**
   * Genera semilla randomica necesaria para encriptar QRs de autorizaciones
   * y la guarda en tabla BW_AUT_SEMILLAS.
   * @param p_nro_documento   Nro. de documento a autorizar
   * @param p_cod_persona     Cod. de persona autorizadora, operador de empresa.
   *
   * @return Retorna semilla generada
   */
   FUNCTION fu_gen_semilla_autorizacion(p_nro_documento IN NUMBER, p_cod_persona IN NUMBER)
     RETURN NUMBER
     IS
         v_randomSeed NUMBER;
         v_count      NUMBER;
     BEGIN
       v_RandomSeed := trunc(dbms_random.value(9, 999999));

       SELECT COUNT(*) INTO v_count
       FROM BW_AUT_SEMILLAS S WHERE S.NRO_DOCUMENTO = p_nro_documento
       AND S.COD_PERSONA = p_cod_persona;

       IF v_count > 0 THEN
         /* ya existe semilla para el nro de documento y cod persona, entonces actualizarla */
         UPDATE BW_AUT_SEMILLAS S
            SET S.nro_semilla = v_randomSeed
          WHERE S.NRO_DOCUMENTO = p_nro_documento
            AND S.COD_PERSONA = p_cod_persona;

       ELSE
         /* no existe semilla, entonces insertar en tabla BW_AUT_SEMILLAS */
         INSERT INTO BW_AUT_SEMILLAS(NRO_DOCUMENTO, COD_PERSONA, NRO_SEMILLA)
         VALUES(p_nro_documento, p_cod_persona, v_randomSeed);
       END IF;

       RETURN v_RandomSeed;

       END fu_gen_semilla_autorizacion;


   FUNCTION fu_obt_tok_validar(p_cla_token         IN VARCHAR2,
                               p_cod_persona       IN VARCHAR2,
                               p_cod_per_vinculada IN VARCHAR2,
                               p_modo              IN VARCHAR2) RETURN typ_mensajeRespuesta IS
      MSG_CLA_TOK_INVALIDO    CONSTANT VARCHAR2(15) := 'G_COD_TOK_INVAL';
      MSG_CLA_OTP_INEXISTENTE CONSTANT VARCHAR2(15) := 'G_COD_TOK_INEXI';
      MSG_ERR_CON_VASCO       CONSTANT VARCHAR2(15) := 'G_COD_ERR_VASCO';
      MSG_OPE_NO_PERMITIDA    CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';
      MSG_ERR_CON_SOCKET      CONSTANT VARCHAR2(15) := 'G_ERR_SOC_VASCO';

      v_retorno            typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_tip_persona        varchar(1):='J';
      v_cod_mensaje        varchar2(3) := paw_bce.v_cod_aprobado;
   BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
   IF(p_cod_per_vinculada IS NULL) THEN
     v_tip_persona:='F';
   END IF;

   IF(Paw_Otp.fu_obtenerAsignacionSofttoken(p_cod_persona,v_tip_persona, p_cod_per_vinculada) IS NULL) THEN
      v_cod_mensaje := paw_bce.fu_obt_tok_validar(p_cla_token,
                                                  p_cod_persona,
                                                  p_cod_per_vinculada,
                                                  0,
                                                  p_modo);

      IF v_cod_mensaje = paw_bce.v_cod_err_con_vasco THEN
         paw_uti.pr_mensajeUsuario(MSG_ERR_CON_VASCO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSIF v_cod_mensaje = paw_bce.v_cod_aprobado THEN
         paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSIF v_cod_mensaje = paw_bce.v_tok_invalido THEN
         paw_uti.pr_mensajeUsuario(MSG_CLA_TOK_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSIF v_cod_mensaje = paw_bce.v_cod_err_con_socket THEN
         paw_uti.pr_mensajeUsuario(MSG_ERR_CON_SOCKET, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSIF v_cod_mensaje = paw_bce.v_cla_otp_inexistente THEN
         paw_uti.pr_mensajeUsuario(MSG_CLA_OTP_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSE
         paw_uti.pr_mensajeUsuario(MSG_OPE_NO_PERMITIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;
    end if;
      RETURN v_retorno;
   END;

   FUNCTION fu_act_est_softoken(p_cod_persona       IN VARCHAR2,
                               p_cod_per_vinculada IN VARCHAR2,
                               p_estado IN VARCHAR2) RETURN typ_mensajerespuesta IS
   v_sof_id NUMBER;
   v_retorno typ_mensajerespuesta := typ_mensajerespuesta();
   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      BEGIN
         SELECT S.ID
           INTO v_sof_id
           FROM BW_SOF_SERIALES S
          WHERE S.COD_PERSONA = p_cod_persona
            AND S.DOMINIO = 'CASHPY'
            AND ROWNUM = 1;
      EXCEPTION
         WHEN OTHERS THEN
            --TODO: ver que error lanzar
            RETURN v_retorno;
      END;
      BEGIN
        IF(p_estado = 'A') THEN
         UPDATE BW_SOF_EMPRESAS E SET ESTADO = p_estado, E.ENROLADO = 'S'
            , E.USU_ACTIVACION = user, E.FEC_ACTIVACION = SYSDATE, E.USU_ADM_MODIFICACION = user
         WHERE E.COD_PER_VINCULADA = p_cod_per_vinculada
         AND E.SOF_SER_ID = v_sof_id;
        ELSE
           UPDATE BW_SOF_EMPRESAS E SET ESTADO = p_estado, E.ENROLADO = 'S', E.USU_ADM_MODIFICACION = user
           WHERE E.COD_PER_VINCULADA = p_cod_per_vinculada
           AND E.SOF_SER_ID = v_sof_id;
        END IF;
      END;
      RETURN v_retorno;
   END;

   FUNCTION fu_ver_inf_pago(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                                P_P6_TAR     IN TA_TARJETAS.NRO_TARJETA%TYPE,
                                                P_U4_TAR     IN TA_TARJETAS.NRO_TARJETA%TYPE,
                                                P_FEC_VENC   in VARCHAR2,
                                                P_CARD_TYPE IN VARCHAR2)
     RETURN VARCHAR2 IS

     RESULT varchar2(10);
   BEGIN
     BEGIN
       /*BSEVOCORE-862 3D SECURE Fase III - MC Debit */
       IF (UPPER(P_CARD_TYPE) = 'DEBIT') THEN
         IF fug_obt_parentes(112, 'NRO_BIN_TDD_MASTERCARD' )= P_P6_TAR OR
            fug_obt_parentes(112, 'NRO_BIN_TDD_MASTERCARD_BLACK' )= P_P6_TAR THEN -- BSEVOCORE-1029-- Se agrega BIN
                                                                                  -- de nuevo tipo TD MC BLACK
           BEGIN
              SELECT d.cod_persona into result FROM ah_tar_debitos d, ge_cta_clientes c
             WHERE d.nro_cuenta = c.nro_cuenta
             AND c.relacion IN ('P', 'O', 'Y')
             AND c.cod_persona = d.cod_persona
             AND sysdate < d.fec_vencimiento
             AND d.fec_cancelacion is null
             AND (to_char(d.fec_vencimiento, 'MM/YYYY') = P_FEC_VENC
             OR to_char(d.fec_vencimiento, 'MM/YY') = P_FEC_VENC)
             AND d.fec_ingreso = (select MAX(a.fec_ingreso)
                                FROM ah_tar_Debitos a
                                WHERE a.nro_cuenta = d.nro_cuenta
                                AND a.cod_persona = d.cod_persona)
             AND d.nro_cuenta = (SELECT nro_cta_cliente
                                FROM ah_tar_cta_ficticias
                                WHERE nro_cuenta = P_NRO_CUENTA
                                AND nro_bin = P_P6_TAR);
           EXCEPTION
              WHEN OTHERS THEN NULL;
           END;
         END IF;
       /*FIN BSEVOCORE-862*/
       ELSE
         select a.cod_persona
         into result
         from ta_tarjetas a
        where a.cod_estado = '6'
          and a.nro_cuenta = P_NRO_CUENTA
          and substr(a.nro_tarjeta, 0, 6) = P_P6_TAR
          and substr(a.nro_tarjeta, 13, 4) = P_U4_TAR
          and to_char(a.fec_vencimiento, 'MM/YYYY') = P_FEC_VENC;
       END IF;
     EXCEPTION
       when no_data_found then
         return - 1;
     END;
     return(result);
   END;



  FUNCTION fu_env_sms_3dsecure(P_COD_TRANSACCION IN TA_LOG_SEC_INITRAN.COD_TRANSACCION%TYPE,
                                P_COD_INITRANSAC  IN TA_LOG_SEC_INITRAN.COD_INITRANSAC%TYPE)
  RETURN VARCHAR2
  IS
    v_telefono     varchar2(20);
    v_nombre_cli   varchar2(120);
    v_token       varchar2(10);
    v_cod_moneda  varchar2(5);
    v_monto        varchar2(100);
    v_comercio    varchar2(80);
    v_tar          varchar(5);
    v_fec_hora     varchar(16);
    v_mensaje      varchar2(250) :=  fug_obt_pardinamico('MSJ_3DSECURE');
    v_resultado   varchar2(10);

  BEGIN
    BEGIN
      SELECT per.nom_completo nombre, initiate.cod_verificacion token, cred.des_credencial contacto,
       initiate.cod_mon_tra cod_moneda, to_char(initiate.mto_transaccion,'999G999G999G999D99','NLS_NUMERIC_CHARACTERS = '',.') monto, initiate.des_comercio comercio,
       substr(stepup.nro_tar, 13, 4) tarjeta, TO_CHAR(initiate.fec_transaccion,'DD/MM HH24:MI') fec_hora
      INTO v_nombre_cli, v_token, v_telefono, v_cod_moneda, v_monto, v_comercio, v_tar, v_fec_hora
      FROM
        ta_log_sec_creds cred,
        ta_log_sec_initrares stepresp,
        ba_personas per,
        ta_log_sec_fintra initiate,
        ta_log_sec_initran stepup
      WHERE cred.cod_respuesta = stepresp.cod_respuesta
        AND    stepup.cod_transaccion   = P_COD_TRANSACCION
        AND    initiate.COD_FINTRANSAC   = P_COD_INITRANSAC
        AND    stepup.cod_autenticacion     = initiate.cod_autenticacion
        AND    stepresp.cod_autenticacion     = stepup.cod_autenticacion
        AND    per.cod_persona           = stepresp.cod_persona
        AND    cred.tip_credencial       = 'OTPSMS';


      v_mensaje := replace(v_mensaje,'v_nombre_cli',v_nombre_cli);
      v_mensaje := replace(v_mensaje,'v_token',v_token);
      v_mensaje := replace(v_mensaje,'v_cod_moneda',v_cod_moneda);
      v_mensaje := replace(v_mensaje,'v_monto',v_monto);
      v_mensaje := replace(v_mensaje,'v_comercio',v_comercio);
      v_mensaje := replace(v_mensaje,'v_tar',v_tar);
      v_mensaje := replace(v_mensaje,'v_fec_hora',v_fec_hora);

      v_resultado := paw_not.fu_env_sms_prueba(v_telefono,v_mensaje,'3DSECURE');

    EXCEPTION
      when no_data_found then
        return -1;
    END;
    return(v_resultado);
  END;

  FUNCTION fu_obt_tel_cli_3dsecure(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
    RETURN VARCHAR2 IS

    v_numero varchar2(10);
  Begin
    Begin
      /*BSEVOCORE-862 Sugerimos que el primer celular sea el vinculado al token digital.*/
      select t.area || t.telefono
        into v_numero
        from BA_TELEFONOS t
       where t.tip_linea = 'C'
         and t.tipo = 'S'
         and substr(t.area, 0, 3) in ('099', '098', '097', '096')
         and length(t.area || t.telefono) = 10
         and t.cod_persona = p_cod_persona
         and trunc(fec_insercion) = (select trunc(max(x.fec_insercion))
                                       from ba_telefonos x
                                      where x.tip_linea = 'C'
                                        and x.tipo = 'S'
                                        and substr(x.area, 0, 3) in ('099', '098', '097', '096')
                                        and length(x.area || x.telefono) = 10
                                        and x.cod_persona = t.cod_persona)
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        Begin
            select t.area || t.telefono
            into v_numero
            from BA_TELEFONOS t
           where t.tip_linea = 'C'
             and t.principal = 'S'
             and substr(t.area, 0, 3) in ('099', '098', '097', '096')
             and length(t.area || t.telefono) = 10
             and t.cod_persona = p_cod_persona
             and rownum = 1;
        Exception
          when no_data_found then
            Begin
              select t.area || t.telefono
                into v_numero
                 from BA_TELEFONOS t
               where substr(t.area, 0, 3) in ('099', '098', '097', '096')
                 and length(t.area || t.telefono) = 10
                 and t.cod_persona = p_cod_persona
                 and rownum = 1;
            Exception
              when no_data_found then
                Begin
                  SELECT m.ref_medio
                  into v_numero
                  FROM bw_otp_ref_medios m
                  WHERE m.tipo = 'C'
                  AND m.cod_persona = p_cod_persona
                  AND ROWNUM = 1;
                EXCEPTION
                  when no_data_found then
                    return - 1;
                END;
            end;
        end;
    end;
    return(v_numero);
  END;

     FUNCTION fu_log_dispositivo( p_cod_persona           IN VARCHAR2,
                             p_cod_per_vinculada     IN VARCHAR2,
                             p_id_dispositivo        IN VARCHAR2,
                             p_cod_canal             IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                             p_os                    IN VARCHAR2,
                             p_os_version            IN VARCHAR2,
                             p_modelo                IN VARCHAR2,
                             p_marca                 IN VARCHAR2,
                             p_emulator              IN VARCHAR2,
                             p_cli_type              IN VARCHAR2,
                             p_ip                    IN VARCHAR2,
                             p_ext_data              IN VARCHAR2,
                             p_latitud               IN NUMBER,
                             p_longitud              IN NUMBER,
                             p_cod_sesion_aux        IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL,
                             p_logueado              IN VARCHAR2) RETURN typ_mapa IS
        v_retorno       typ_mapa := typ_mapa();
        v_exi_device    NUMBER;
        v_exi_persona   NUMBER;
        v_pri_dispositivo NUMBER;
        v_es_confiable  VARCHAR2(1);
        v_os            VARCHAR2(20);
        v_cod_per_dispositivo VARCHAR2(80);
        v_fac_id VARCHAR2(6);
        v_tipo_personeria VARCHAR2(1);
        DIS_NO_CONF    CONSTANT VARCHAR2(15) := 'DIS_NO_CONF';

        PROCEDURE lp_reg_inf_sesion(p_nro_sesion IN VARCHAR2,
                p_cod_per_dispositivo IN VARCHAR2,
                p_ip IN VARCHAR2,
                p_latitud IN NUMBER,
                p_longitud IN NUMBER) IS
            v_id NUMBER;
        BEGIN

            SELECT S_BW_SES_INFORMACION.NEXTVAL
              INTO v_id
              FROM dual;

            INSERT INTO BW_SES_INFORMACION(COD_SES_INFORMACION, NRO_SESION, COD_PER_DISPOSITIVO, IP, LATITUD, LONGITUD) values
            (v_id, p_nro_sesion, p_cod_per_dispositivo, p_ip, p_latitud, p_longitud );

        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;

     BEGIN

        paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK,
                                    v_retorno.nombreRespuesta,
                                    v_retorno.descripcionRespuesta,
                                    v_retorno.error);

        paw_uti.pr_insertarBitacora(p_cod_persona,
                                p_cod_canal,
                                p_cod_sesion_aux,
                                '0',
                                p_cod_per_vinculada,
                                'fu_log_device: [p_cod_persona=' || p_cod_persona || '][p_cod_per_vinculada=' || p_cod_per_vinculada || '][p_id_dispositivo=' || p_id_dispositivo || ']',
                                paw_uti.BITACORA_ENTRADA);
         v_os := p_os;
         if(p_os is null and p_cli_type is not null ) THEN

            IF (p_cli_type = 'ANDROID') THEN
                v_os := 'ANDROID';
            ELSIF (p_cli_type = 'IPHONE') THEN
                v_os := 'IOS';
            ELSIF (p_cli_type = 'HUAWEI') THEN
                v_os := 'HUAWEI';
            End if;

         END IF;

         Select count(*)
         INTO v_exi_device
         FROM BW_DISPOSITIVOS d
         where d.ID_DISPOSITIVO = p_id_dispositivo;

        IF v_exi_device = 0 THEN --Dispositivo nuevo
            Insert into BW_DISPOSITIVOS(ID_DISPOSITIVO,OS,OS_VERSION,MARCA,MODELO,EMULADOR,TIP_CLI_DISPOSITIVO)
            values(p_id_dispositivo, v_os, p_os_version, p_marca, p_modelo,p_emulator, p_cli_type);
        ELSE
            --check if is the same device
            Update BW_DISPOSITIVOS set ult_acceso = SYSDATE, OS_VERSION = p_os_version,
            MARCA = p_marca, MODELO = p_modelo
            WHERE ID_DISPOSITIVO = p_id_dispositivo;
        END IF;

        Select count(*)
        INTO v_exi_persona
        FROM BW_PER_DISPOSITIVOS pd
        where pd.cod_persona = p_cod_persona
        AND pd.cod_dispositivo = p_id_dispositivo
        AND (
             (p_cod_per_vinculada IS NULL AND pd.cod_per_vinculada IS NULL) OR
             (p_cod_per_vinculada IS NOT NULL AND pd.cod_per_vinculada = p_cod_per_vinculada)
            );

        IF v_exi_persona = 0 THEN -- No existe relacion
            --relacionamos la persona con el dispositivo
            v_cod_per_dispositivo := p_cod_persona || '#'|| p_id_dispositivo || '#' || p_cod_per_vinculada;
            v_fac_id := LPAD(TRUNC (DBMS_RANDOM.VALUE(1, POWER(10, 6) - 1)), 6, '0');

            Insert Into BW_PER_DISPOSITIVOS(cod_relacion,cod_persona, cod_per_vinculada, cod_dispositivo, cod_fac_identificador)
            values (v_cod_per_dispositivo, p_cod_persona, p_cod_per_vinculada, p_id_dispositivo, v_fac_id);

            lp_reg_inf_sesion(p_cod_sesion_aux, v_cod_per_dispositivo, p_ip, p_latitud, p_longitud);

            if fug_obt_pardinamico('NUE_DIS_NOTIFICACION') = 'S' THEN
                --verificamos si fue el primer dispositivo de la persona
                Select count(*)
                INTO v_pri_dispositivo
                FROM BW_PER_DISPOSITIVOS pd
                where pd.cod_persona = p_cod_persona
                AND (
                     (p_cod_per_vinculada IS NULL AND pd.cod_per_vinculada IS NULL) OR
                     (p_cod_per_vinculada IS NOT NULL AND pd.cod_per_vinculada = p_cod_per_vinculada)
                    );


               select tipo into v_tipo_personeria from ba_personas bp where bp.cod_persona = p_cod_persona
               and p_cod_canal = '994';

               --se verifica si no es una empresa la que inicia sesion en la app de personas
               --solo asi se notifica, evolutivo DDEVOLUT-1265
               IF v_tipo_personeria != 'J' THEN
                  --solo apartir del segundo dispositivo lo notificamos
                 IF v_pri_dispositivo > 1 THEN
                      --notificar
                      IF p_logueado = 'S' THEN
                         paw_not.pr_not_nue_dispositivo(p_cod_persona, p_cod_per_vinculada,v_os,p_os_version,p_modelo,p_marca,p_ip,p_ext_data, v_fac_id, p_cli_type);
                      ELSE
                         paw_not.pr_not_nue_dispositivo_error(p_cod_persona, p_cod_per_vinculada,v_os,p_os_version,p_modelo,p_marca,p_ip,p_ext_data, v_fac_id, p_cli_type);
                      END IF;
                  END IF;
               END IF;
            END IF;

        ELSE --Ya existe la relacion entre el dispositivo y el cliente

            Select es_confiable, pd.cod_relacion
            INTO  v_es_confiable, v_cod_per_dispositivo
            FROM BW_PER_DISPOSITIVOS pd
            where pd.cod_persona = p_cod_persona
            AND pd.cod_dispositivo = p_id_dispositivo
            AND (
                 (p_cod_per_vinculada IS NULL AND pd.cod_per_vinculada IS NULL) OR
                 (p_cod_per_vinculada IS NOT NULL AND pd.cod_per_vinculada = p_cod_per_vinculada)
                );

            lp_reg_inf_sesion(p_cod_sesion_aux, v_cod_per_dispositivo, p_ip, p_latitud, p_longitud);

            --Controlamos que sea un dispositivo seguro para la persona
            IF v_es_confiable = 'N' THEN
                if fug_obt_pardinamico('BLO_ACC_DIS_NO_CONF') = 'S' THEN
                    --El dispositivo no es confiable para este cliente
                    paw_uti.pr_mensajeUsuario(DIS_NO_CONF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    paw_uti.pr_insertarBitacora(p_cod_persona,
                                                p_cod_canal,
                                                p_cod_sesion_aux,
                                                '0',
                                                p_cod_per_vinculada,
                                                'Error no puede avanzar, El dispositivo: [' || p_id_dispositivo || '] esta marcado como no confiable '|| paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                paw_uti.BITACORA_ERROR);
                    RETURN v_retorno;
                END IF;
            END IF;

            Update BW_PER_DISPOSITIVOS
            Set fec_ult_acceso = SYSDATE, can_accesos = can_accesos +1
            where cod_persona = p_cod_persona
            AND cod_dispositivo = p_id_dispositivo
            AND (
                 (p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR
                 (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada)
                );
        END IF;
        RETURN v_retorno;
     EXCEPTION
         WHEN OTHERS THEN
            paw_uti.pr_insertarBitacora(p_cod_persona,
                                                p_cod_canal,
                                                p_cod_sesion_aux,
                                                '0',
                                                p_cod_per_vinculada,
                                                'Error al insertar el dispositivo, ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] '|| paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                paw_uti.BITACORA_ERROR);
            paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

            RETURN v_retorno;
     END;

    FUNCTION fu_ver_inf_tarjeta(P_TARJETA IN TA_TARJETAS.NRO_TARJETA%TYPE,
                              P_FEC_VENC   in VARCHAR2,
                              P_TIP_TARJETA in VARCHAR2,
                              P_ADHERENTE IN VARCHAR2 DEFAULT NULL)
      RETURN VARCHAR2 IS

      RESULT varchar2(10);
      BEGIN
        BEGIN
          IF(P_TIP_TARJETA = 'DEBIT') THEN
            select d.cod_persona
              into result
            from ah_tar_debitos d, ge_cta_clientes c
            where d.nro_tarjeta = P_TARJETA
             and d.nro_cuenta = c.nro_cuenta
             and c.relacion IN ('P','O','Y')
             and c.cod_persona = d.cod_persona
             and to_number(d.ADHERENTE) = P_ADHERENTE
             and sysdate < d.fec_vencimiento
             and d.fec_cancelacion is null
             and (to_char(d.fec_vencimiento, 'MM/YYYY') = P_FEC_VENC or to_char(d.fec_vencimiento, 'MM/YY') = P_FEC_VENC)
             and d.fec_ingreso = (select MAX(a.fec_ingreso)
                                from ah_tar_Debitos a
                                where a.nro_cuenta = d.nro_cuenta
                                AND a.cod_persona = d.cod_persona);
          ELSE
           select a.cod_persona
              into result
           from ta_tarjetas a, ta_cta_tarjetas b
           where a.cod_estado = '6'
             and a.nro_cuenta = b.nro_cuenta
             and b.COD_MODALIDAD not in (503, 501, 58, 55)
             and a.nro_tarjeta = P_TARJETA
             and (to_char(a.fec_vencimiento, 'MM/YYYY') = P_FEC_VENC or to_char(a.fec_vencimiento, 'MM/YY') = P_FEC_VENC);
          END IF;
        EXCEPTION
          when no_data_found then
            return - 1;
        END;
      return(result);
    END;

  FUNCTION fu_env_vts_token(P_COD_PAN_REF IN BW_TOK_TAR_TOKENIZACION.COD_REF_PAN%TYPE,
                          P_COD_TOKEN  IN BW_TOK_TAR_TOKENIZACION.COD_REF_TOKEN%TYPE)
  RETURN VARCHAR2
  IS
    v_telefono     varchar2(20);
    v_nombre_cli   varchar2(120);
    v_token       varchar2(10);
    v_mensaje      varchar2(250) :=  'Estimado cliente: v_nombre_cli, la clave dinamica es v_token';
    v_resultado   varchar2(10);

  BEGIN
    BEGIN
      select nombre, token, contacto
      INTO v_nombre_cli, v_token, v_telefono
      from (SELECT per.nom_completo nombre, otp.cod_verificacion token, aut.contacto contacto
      FROM
        BW_TOK_TAR_PANREF pan,
        BA_PERSONAS per,
        BW_TOK_TAR_TOKENIZACION tok,
        BW_TOK_TAR_AUTENTICACION aut,
        BW_TOK_TAR_OTP otp
      WHERE
        tok.COD_REF_PAN = P_COD_PAN_REF
        and tok.COD_REF_TOKEN = P_COD_TOKEN
        and pan.COD_REF_PAN = tok.COD_REF_PAN
        and pan.COD_PERSONA = per.COD_PERSONA
        and aut.COD_TOKENIZACION = tok.COD_TOKENIZACION
        and otp.COD_TOKENIZACION = tok.COD_TOKENIZACION
        order by otp.FEC_INSERCION desc
        ) where rownum = 1;

      v_mensaje := replace(v_mensaje,'v_nombre_cli',v_nombre_cli);
      v_mensaje := replace(v_mensaje,'v_token',v_token);

      v_resultado := paw_not.fu_env_sms_prueba(v_telefono,v_mensaje,'VTS');
    EXCEPTION
      when no_data_found then
        return -1;
    END;
    return(v_resultado);
END;

   -- Función para saber que solicitar al autorizador (clave transaccional y/o token o nada).
   FUNCTION fu_validarClave(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                            p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                            p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                            p_monto         IN NUMBER,
                            p_modo          IN VARCHAR2,
                            p_tip_operacion IN VARCHAR2,
                            p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                            p_sesion_aux    IN VARCHAR2 DEFAULT NULL) RETURN typ_clave_validacion is
      v_res_limite    VARCHAR2(2);
      v_cod_ente      ge_entes.cod_ente%TYPE;
      v_tip_mensaje   bw_mov_pendientes.cod_tip_mensaje%TYPE;
      v_nro_cuenta    bw_mov_pendientes.nro_cuenta%TYPE;
      v_cod_moneda    bw_mov_pendientes.cod_moneda%TYPE;
      v_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE := NULL;
      v_tip_ente      ge_entes.tipo%TYPE := NULL;
      v_req_monto     VARCHAR2(1) := 'S';
      v_permiso       typ_permisos;
      v_perfil        bw_perfiles.cod_perfil%TYPE;
      v_existe        VARCHAR2(1);
      v_retorno       typ_clave_validacion := typ_clave_validacion();

     COD_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'G_NROCTAINVALID';
     COD_LIM_EXCEDIDO    CONSTANT VARCHAR2(15) := 'G_COD_LIM_EXCED';
     COD_LIM_INDEFINIDO  CONSTANT VARCHAR2(15) := 'G_COD_LIM_INDEF';
     COD_LIM_CAN_EXCED   CONSTANT VARCHAR2(15) := 'G_LIM_CAN_EXCED';
     COD_LIM_CAN_INDEF   CONSTANT VARCHAR2(15) := 'G_LIM_CAN_INDEF';
     CLA_OTP_INEXISTENTE CONSTANT VARCHAR2(15) := 'G_COD_TOK_INEXI';
     ERR_CON_VASCO       CONSTANT VARCHAR2(15) := 'G_COD_ERR_VASCO';
     ERR_TOK_INVALIDO    CONSTANT VARCHAR2(15) := 'G_ERR_TOK_INVAL';
     COD_TOK_INE_VASCO   CONSTANT VARCHAR2(15) := 'G_TOK_INE_VASCO';
     OPE_NO_PERMITIDA    CONSTANT VARCHAR2(15) := 'P_OP_NO_PERM';
     ERR_CON_SOCKET      CONSTANT VARCHAR2(15) := 'G_ERR_SOC_VASCO';
     ERR_LIM_OPERACION   CONSTANT VARCHAR2(15) := 'G_ERR_LIM_OPERA';
     MSG_CLA_NO_TIENE    CONSTANT VARCHAR2(15) := 'CLA_OPE_N_TIENE';
     COD_PJ_SIN_CLA_OTP  CONSTANT VARCHAR2(15) := 'G_COD_TOK_IN_PJ';
     MSG_SIN_CLA_TRA     CONSTANT VARCHAR2(15) := 'G_SIN_CLA_TRANX';

   BEGIN
      BEGIN
         SELECT c.nro_cuenta, c.cod_moneda
           INTO v_nro_cuenta, v_cod_moneda
           FROM ge_cuentas c, ge_cta_clientes cc
          WHERE c.nro_cuenta = p_nro_cuenta
            AND c.nro_cuenta = cc.nro_cuenta
            AND cc.cod_persona = nvl(p_cod_empresa, p_cod_persona);
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_moneda := 'x';
      END;

      -- obtenemos los datoos necesarios controlar el límite y/o tipo de clave a validar
      prw_obt_lim_relacion(p_tip_operacion, v_tip_mensaje, v_cod_tra_padre, v_req_monto, v_tip_ente);

      -- si no hay cod_mensaje es error
      IF v_tip_mensaje IS NULL THEN
         paw_uti.pr_mensajeUsuario(COD_LIM_INDEFINIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      v_perfil := fuw_obt_perfil(p_cod_persona, p_cod_empresa);
      v_permiso := fu_obt_permisos(nvl(p_cod_empresa, p_cod_persona), v_perfil, p_cod_canal, v_tip_mensaje);
      IF (v_permiso.error = 'S') THEN
         paw_uti.pr_mensajeUsuario(v_permiso.nombreRespuesta, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;

      IF v_req_monto = 'N' THEN
         RETURN fu_obt_cla_val_operacion(v_tip_mensaje, p_cod_persona, p_cod_empresa, p_cod_canal, p_sesion_aux);
      END IF;
      -- si llega hasta aqui, se requiere monto, por ende tambien una cuenta
      IF nvl(p_monto, 0) <= 0 THEN
         paw_uti.pr_mensajeUsuario(COD_LIM_INDEFINIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno; -- monto debe ser mayor a cero.
      END IF;
      -- si llega  hasta aqui, es porque se debe controlar monto e implica cuenta
      IF v_nro_cuenta IS NULL THEN
         paw_uti.pr_mensajeUsuario(COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         return v_retorno;
      END IF;

      -- si hay tipo de ente se busca el codigo
      IF v_tip_ente IS NOT NULL THEN
         SELECT e.cod_ente
           INTO v_cod_ente
           FROM ge_entes e
          WHERE e.cod_persona = p_cod_empresa
            AND e.tipo = v_tip_ente;

         IF v_tip_mensaje = '075' THEN
            v_cod_tra_padre := fug_obt_parentes(v_cod_ente, 'COD_TRA_PAD_PPROV');
         END IF;
      END IF;

      paw_bce.v_cod_respuesta   := paw_bce.v_cod_aprobado;
      paw_bce.v_cod_persona     := p_cod_persona;
      paw_bce.v_cod_per_empresa := p_cod_empresa;
      v_res_limite := paw_bce.fu_obt_limite(v_tip_mensaje,
                                            p_cod_persona,
                                            v_nro_cuenta,
                                            v_cod_moneda,
                                            503, -- operacion debito
                                            v_cod_tra_padre,
                                            p_monto,
                                            p_modo,
                                            v_cod_ente,
                                            null,
                                            null,
                                            1,
                                            p_cod_empresa);

      CASE paw_bce.v_cod_respuesta
         WHEN paw_bce.v_cod_aprobado THEN
            paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cod_cta_inexistente THEN
            paw_uti.pr_mensajeUsuario(COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_can_lim_indefinido THEN
            paw_uti.pr_mensajeUsuario(COD_LIM_CAN_INDEF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_can_lim_excedido THEN
            paw_uti.pr_mensajeUsuario(COD_LIM_CAN_EXCED, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cla_lim_excedido THEN
            paw_uti.pr_mensajeUsuario(COD_LIM_EXCEDIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cla_lim_no_definido THEN
            paw_uti.pr_mensajeUsuario(COD_LIM_INDEFINIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cod_err_con_vasco THEN
            paw_uti.pr_mensajeUsuario(ERR_CON_VASCO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cod_err_con_socket THEN
            paw_uti.pr_mensajeUsuario(ERR_CON_SOCKET, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_tok_invalido THEN
            paw_uti.pr_mensajeUsuario(ERR_TOK_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cod_tok_ine_vasco THEN
            paw_uti.pr_mensajeUsuario(COD_TOK_INE_VASCO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cla_otp_inexistente THEN
            IF p_cod_empresa is null THEN
               paw_uti.pr_mensajeUsuario(CLA_OTP_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            ELSE
               paw_uti.pr_mensajeUsuario(COD_PJ_SIN_CLA_OTP, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            END IF;
         WHEN paw_bce.v_cod_ope_no_permitida THEN
            paw_uti.pr_mensajeUsuario(OPE_NO_PERMITIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         WHEN paw_bce.v_cla_st_inexistente THEN
            paw_uti.pr_mensajeUsuario(MSG_CLA_NO_TIENE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         ELSE
            paw_uti.pr_mensajeUsuario(ERR_LIM_OPERACION, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END CASE;
      IF v_retorno.error = 'N' THEN
         CASE v_res_limite
            WHEN '00' THEN -- NONE - Libre
                v_retorno.tipoClaveValidacion := 'NONE';
            WHEN '10' THEN -- Pin transaccional
                v_retorno.tipoClaveValidacion := 'PINTX';
            WHEN '11' THEN -- token
                v_retorno.tipoClaveValidacion := 'TOKEN';
            WHEN '01' THEN -- token
                v_retorno.tipoClaveValidacion := 'TOKEN';
            WHEN '02' THEN -- SoftToken
                v_retorno.tipoClaveValidacion := 'SOFTTOKEN';
         END CASE;
         v_retorno.codigoTipoMensaje := v_tip_mensaje;
      END IF;
      IF v_retorno.tipoClaveValidacion = 'PINTX' THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM bw_ope_claves c
             WHERE c.cod_persona = p_cod_persona
               AND c.tip_clave = 'T'
               AND nvl(c.cod_per_vinculada, 'x') = nvl(p_cod_empresa, 'x');
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               paw_uti.pr_mensajeUsuario(MSG_SIN_CLA_TRA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         END;
      END IF;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_cod_canal, p_sesion_aux, '0', p_cod_empresa,
                                                'Error al validar clave, ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] '|| paw_uti.fu_generarbitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null),
                                                paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
   END;
   -- controlar clave en base a limite de operaciones
   FUNCTION fu_verificarClave(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                              p_cod_empresa   IN ba_personas.cod_persona%TYPE,
                              p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                              p_monto         IN NUMBER,
                              p_tip_operacion IN VARCHAR2,
                              p_cod_canal     IN cj_cajas.nro_caja%TYPE,
                              p_clave         IN VARCHAR2,
                              p_sesion_aux    IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta IS
      v_tip_clave typ_clave_validacion;
      v_retorno typ_mensajerespuesta := typ_mensajerespuesta();
   BEGIN
      v_tip_clave := fu_validarClave(p_cod_persona, p_cod_empresa, p_nro_cuenta, p_monto, 'C', p_tip_operacion, p_cod_canal, p_sesion_aux);
      paw_uti.pr_mensajeUsuario(v_tip_clave.nombreRespuesta, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      -- si no hay errores, controlamos
      IF v_retorno.error = 'N' THEN
         IF v_tip_clave.tipoClaveValidacion = 'PINTX' ThEN
            -- validar clave transaccional
            RETURN fu_val_ope_clave(p_clave, p_cod_persona, p_cod_empresa, 'T', 'S');
         ELSIF v_tip_clave.tipoClaveValidacion = 'TOKEN' THEN
            -- validar token vasco
            RETURN fu_obt_tok_validar(p_clave, p_cod_persona, p_cod_empresa, 'C');
         END IF;
          -- si es liobre no se valida, si es token-digital, se valida a nivel QR.
      END IF;

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;

    -- Que operaciones tiene configurado el usuario
   FUNCTION fu_obtenerPermisos(p_cod_empresa        IN ba_personas.cod_persona%TYPE,
                               p_cod_persona        IN ba_personas.cod_persona%TYPE,
                               p_cod_canal          IN cj_cajas.nro_caja%TYPE,
                               p_tip_operaciones      IN VARCHAR2 DEFAULT NULL) RETURN typ_permisosUsuarios IS

      v_retorno       typ_permisosUsuarios := typ_permisosUsuarios();
      v_msj_caja      typ_mensajeCaja;
      v_cantidad      NUMBER := 0;
      v_lis_permisos  typ_listaPermisoUsuario := typ_listaPermisoUsuario();
      v_per_usuario   typ_permisoUsuario := typ_permisoUsuario();
      v_mensajes      VARCHAR2(300) := NULL;
      v_cod_operacion VARCHAR2(3) := '200';
      v_cod_perfil    VARCHAR2(30);
      v_cod_persona   ba_personas.cod_persona%TYPE;

     -- permiso del perfil especifico para la empresa
      CURSOR c_per_empresa IS
        SELECT p.cod_tip_mensaje, p.consulta, p.ingresa, p.autoriza, p.can_firmas, r.nombre
        FROM bw_rol_permisos p, bw_cod_lim_relacion r
        WHERE cod_perfil = v_cod_perfil
        AND v_cod_persona = nvl(v_cod_persona, cod_persona)
        AND p.cod_tip_mensaje = r.cod_tip_mensaje
--        AND r.nombre = nvl(p_tip_operaciones,r.nombre);
        AND (r.nombre IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(p_tip_operaciones, ',' ))) OR (p_tip_operaciones IS NULL));

      -- permiso del perfil general
      CURSOR c_per_ferfil IS
        SELECT p.cod_tip_mensaje, p.consulta, p.ingresa, p.autoriza, p.can_firmas, r.nombre
        FROM bw_rol_permisos p, bw_cod_lim_relacion r
        WHERE cod_perfil = v_cod_perfil
        AND p.cod_tip_mensaje = r.cod_tip_mensaje
        AND cod_persona IS NULL
        AND (r.nombre IN (SELECT column_value FROM TABLE (fug_obt_tab_registro(p_tip_operaciones, ',' ))) OR (p_tip_operaciones IS NULL));

   BEGIN
      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      -- se valida la caja
      v_msj_caja := fu_val_caja(p_cod_canal);
      IF v_msj_caja.error = 'S' THEN
         v_retorno.error                := v_msj_caja.error;
         v_retorno.nombreRespuesta      := v_msj_caja.nombreRespuesta;
         v_retorno.descripcionRespuesta := v_msj_caja.descripcionRespuesta;
         RETURN v_retorno;
      END IF;

      --obtenemos el cod persona y el perfil
      v_cod_persona := nvl(p_cod_empresa, p_cod_persona);
      v_cod_perfil  := fuw_obt_perfil(p_cod_persona,p_cod_empresa);

     -- permiso del perfil especifico para la empresa
     FOR per IN c_per_empresa LOOP
        v_cantidad := v_cantidad + 1;
        v_mensajes := v_mensajes || per.cod_tip_mensaje || ',';
        v_per_usuario.codigoMensaje := per.cod_tip_mensaje;
        v_per_usuario.descripcionMensaje := per.nombre;
        v_per_usuario.consulta := per.consulta;
        v_per_usuario.ingresa := per.ingresa;
        v_per_usuario.autoriza := per.autoriza;
        v_per_usuario.canAutRequeridas := nvl(per.can_firmas, 0);
        v_lis_permisos.extend;
        v_lis_permisos(v_lis_permisos.count) := v_per_usuario;
     END LOOP;

      -- permiso del perfil general
     FOR per IN c_per_ferfil LOOP
        IF v_mensajes IS NULL OR instr(v_mensajes, per.cod_tip_mensaje||',') = 0 THEN
           v_cantidad := v_cantidad + 1;
           v_per_usuario.codigoMensaje := per.cod_tip_mensaje;
           v_per_usuario.descripcionMensaje := per.nombre;
           v_per_usuario.consulta := per.consulta;
           v_per_usuario.ingresa := per.ingresa;
           v_per_usuario.autoriza := per.autoriza;
           v_per_usuario.canAutRequeridas := nvl(per.can_firmas, 0);
           v_lis_permisos.extend;

           v_per_usuario.codigoMensaje := per.cod_tip_mensaje;

             /* permisos especiales por persona, que no forman parte de la
              definida con rol_permisos
            */
           -- autorizador de softtoken para empresas: 008
           IF v_per_usuario.codigoMensaje = '008' THEN
               v_per_usuario.autoriza := paw_otp.fu_es_aut_softoken(p_cod_persona, p_cod_empresa);
           END IF;


           v_lis_permisos(v_lis_permisos.count) := v_per_usuario;
        END IF;
     END LOOP;

      v_retorno.cantidad := v_cantidad;
      v_retorno.listaPermisos := v_lis_permisos;
      RETURN v_retorno;

   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;
   --
   FUNCTION fu_obt_aes_tkd(p_cod_persona IN ba_personas.cod_persona%TYPE,
                           p_cod_empresa IN ba_personas.cod_persona%TYPE) RETURN typ_mapa IS
      v_retorno        typ_mapa := typ_mapa();
      v_lis_detalles   typ_listaClaveValor := typ_listaClaveValor();
      v_nro_serial     bw_sof_seriales.nro_serial%TYPE;
      v_cla_encrypt    bw_sof_seriales.cla_encriptacion%TYPE;
      v_vec_inicial    bw_sof_seriales.vec_inicializacion%TYPE;

      MSG_CLA_NO_TIENE CONSTANT VARCHAR2(15) := 'CLA_OPE_N_TIENE';
      KEY_SERIAL       CONSTANT VARCHAR2(15) := 'NRO_SERIAL';
      KEY_ENCRYPT      CONSTANT VARCHAR2(15) := 'CLA_ENCRYPT';
      KEY_IV           CONSTANT VARCHAR2(15) := 'IV';
   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      IF p_cod_empresa IS NULL THEN
         SELECT nro_serial, cla_encriptacion, vec_inicializacion
           INTO v_nro_serial, v_cla_encrypt, v_vec_inicial
           FROM bw_sof_seriales
          WHERE cod_persona = p_cod_persona
            AND dominio = 'RETAILPY';
      ELSE
         SELECT s.nro_serial, s.cla_encriptacion, s.vec_inicializacion
           INTO v_nro_serial, v_cla_encrypt, v_vec_inicial
           FROM bw_sof_seriales s, bw_sof_empresas e
          WHERE s.id = e.sof_ser_id
            AND s.cod_persona = p_cod_persona
            AND s.dominio = 'CASHPY'
            AND e.estado = 'A'
            AND e.cod_per_vinculada = p_cod_empresa;
      END IF;
      paw_uti.pr_add_value(v_lis_detalles, KEY_SERIAL, v_nro_serial, 'VARCHAR');
      paw_uti.pr_add_value(v_lis_detalles, KEY_ENCRYPT, v_cla_encrypt, 'VARCHAR');
      paw_uti.pr_add_value(v_lis_detalles, KEY_IV, v_vec_inicial, 'VARCHAR');

      v_retorno.datosAdicionales := v_lis_detalles;
      v_retorno.cantidad := v_lis_detalles.count;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(MSG_CLA_NO_TIENE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;
   --
   FUNCTION fu_val_caja(p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN typ_mensajeCaja IS
      MSG_CAJ_PROHIBIDA     CONSTANT VARCHAR2(15) := 'CAJ_PROHIBIDA';
      MSG_EST_CAJ_INVALIDA  CONSTANT VARCHAR2(15) := 'EST_CAJ_INVALID';
      MSG_CAJ_NO_ENCONTRADA CONSTANT VARCHAR2(15) := 'CAJ_NO_ENCONTRA';
      -- Verifico la situacion del numero de caja
      v_est_caja       cj_cajas.estado%TYPE;
      v_tip_caja       cj_cajas.tipo%TYPE;
      v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
      v_cod_usuario    cj_cajas.cod_usuario%TYPE;
      v_ult_cierre     cj_cajas.fec_hor_cierre%TYPE;
      v_retorno        typ_mensajeCaja := typ_mensajeCaja;
   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      SELECT estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre
        INTO v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario, v_ult_cierre
        FROM cj_cajas
       WHERE nro_caja = p_cod_canal;
      IF v_tip_caja NOT IN ('C', 'I', 'S') THEN
         -- tipo de caja no permitido
         paw_uti.pr_mensajeUsuario(MSG_CAJ_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;
      IF v_est_caja <> 'A' THEN
         paw_uti.pr_mensajeUsuario(MSG_EST_CAJ_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;

      v_retorno.estadoCaja          := v_est_caja;
      v_retorno.tipoCaja            := v_tip_caja;
      v_retorno.codigoOficinaOrigen := v_cod_ofi_origen;
      v_retorno.codigoUsuario       := v_cod_usuario;
      v_retorno.fechaUltimoCierre   := v_ult_cierre;

      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         paw_uti.pr_mensajeUsuario(MSG_CAJ_NO_ENCONTRADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;

   FUNCTION fu_ver_ctr_clave(p_tip_clave VARCHAR2) RETURN VARCHAR2 IS
      v_val_clave                  VARCHAR2(1) := 'S';
      v_val_cla_acceso             VARCHAR2(1) := fug_obt_pardinamico('VAL_CLA_ACC_SESION');
   BEGIN
     IF p_tip_clave = 'A' THEN -- Clave Acceso
         IF nvl( v_val_cla_acceso , 'S' ) = 'S' THEN  -- si es null Por defecto controla
            v_val_clave := 'S';
         ELSE
            v_val_clave := 'N';
         END IF;
     ELSIF  p_tip_clave = 'T' THEN -- Clave Transaccional
            v_val_clave := 'S';
     END IF;

     RETURN v_val_clave;
   END;
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END PAW_SEG;
/

