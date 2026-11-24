CREATE OR REPLACE PACKAGE BODY IT.PAW_CAN IS

  /** Constantes de tipo  de Bitácora */
   BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
   BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';

   -- obtener apikey del Micrositio, guardado como parámetro dinámico
   g_api_gateway ge_par_dinamicos.val_parametro%TYPE := TRIM(fug_obt_pardinamico('API_KEY_MICROSITIO'));

   FUNCTION fu_val_api(p_api_key IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
          IF p_api_key = g_api_gateway THEN
            RETURN 'S';
          END IF;

          RETURN 'N';
   END;

  FUNCTION fu_ns_obt_punt_lealtad(p_cod_persona     IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                p_cod_canal         IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                                p_cod_sesion_aux    IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN TYP_OBTPUNTOSLEALTAD IS
      v_cod_persona    BW_AUT_SESIONES.COD_PERSONA%TYPE;
      v_cod_canal      BW_AUT_SESIONES.COD_CANAL%TYPE;
      v_fec_proceso    DATE := NULL;
      v_sal_puntos     NUMBER(15,2) := NULL;
      v_nom_puntos     VARCHAR2(50) := NULL;
      v_puntos         typ_puntoslealtad := typ_puntoslealtad;
      v_cod_operacion  VARCHAR2(3) := '700';
      v_lis_puntos     typ_listapuntoslealtad := typ_listapuntoslealtad();
      v_retorno        TYP_OBTPUNTOSLEALTAD := TYP_OBTPUNTOSLEALTAD();

      CURSOR cuentas(p_cod_persona VARCHAR2) IS
      SELECT t.nro_tarjeta, ct.*
      FROM ta_cta_tarjetas ct, ge_cta_clientes c, ta_tarjetas t
      WHERE ct.nro_cuenta = c.nro_cuenta AND t.nro_cuenta = t.nro_cuenta
      AND t.nro_cuenta = ct.nro_cuenta AND t.cod_persona = c.cod_persona
         AND t.vigente = 'S'
         AND (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS', ct.cod_modulo, ct.cod_modalidad), ct.afinidad) != 0 OR
            instr(fug_obt_pardinamico('AFI_TAR_PUNTOS_EXP', ct.cod_modulo, ct.cod_modalidad), ct.afinidad) != 0 OR
            instr(fug_obt_pardinamico('AFI_SHO_DEL_SOL', ct.cod_modulo, ct.cod_modalidad), ct.afinidad) != 0)
         AND ct.estado = 'N'
         AND c.relacion = 'P'
         AND t.cod_estado = 6
         AND c.cod_persona = p_cod_persona;
  BEGIN

    --por defecto colocamos en retorno en OK
    --llamamos al paw_uti
    paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

    v_cod_persona := p_cod_persona;
    v_cod_canal   := paw_uti.depurarNumerico(p_cod_canal, 3);

    paw_uti.pr_insertarBitacora(v_cod_persona,
                                v_cod_canal,
                                p_cod_sesion_aux,
                                v_cod_operacion,
                                null,
                                'fu_ns_obt_punt_lealtad: [p_cod_persona=' || v_cod_persona || ']',
                                BITACORA_ENTRADA);

    FOR cu IN cuentas(v_cod_persona)
    LOOP
       BEGIN
          SELECT p.fec_proceso, p.sal_puntos, p.nom_puntos
          INTO v_fec_proceso, v_sal_puntos, v_nom_puntos
          FROM ta_pun_lealtad p
          WHERE p.fec_proceso = (SELECT MAX(p2.fec_proceso) FROM ta_pun_lealtad p2 where p2.nro_cuenta = p.nro_cuenta)
             AND  p.nro_cuenta = cu.nro_cuenta;
       EXCEPTION
          WHEN no_data_found THEN
             NULL;
       END;

       v_puntos.nomPrograma := v_nom_puntos;
       v_puntos.canPuntos := v_sal_puntos;
       v_puntos.fecProceso := v_fec_proceso;
       v_puntos.nroTarjeta := cu.nro_Tarjeta;

       v_lis_puntos.Extend;
       v_lis_puntos(v_lis_puntos.count) := v_puntos;
     END LOOP;
     IF v_retorno.error <> 'S' THEN
        v_retorno.lisBolsas := v_lis_puntos;
        v_retorno.cantidad := v_lis_puntos.count;

        paw_uti.pr_insertarBitacora(v_cod_persona,
                                    v_cod_canal,
                                    p_cod_sesion_aux,
                                    v_cod_operacion,
                                    null,
                                    ' fu_ns_obt_punt_lealtad: Tot. tarjetas:' || v_retorno.lisBolsas.count || ' ' ||
                                          paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null ),
                                    BITACORA_SALIDA);

     END IF;
    RETURN v_retorno;
  END fu_ns_obt_punt_lealtad;

 FUNCTION fu_ns_ins_can_puntos(p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                              p_cod_canal            IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_tarjeta          IN BW_CANJES.NRO_TARJETA%TYPE DEFAULT NULL,
                              p_cat_producto         IN BW_CANJES.CAT_PRODUCTO%TYPE,
                              p_nom_producto         IN BW_CANJES.NOM_PRODUCTO%TYPE,
                              p_des_producto         IN BW_CANJES.DES_PRODUCTO%TYPE,
                              p_tel_contacto         IN BW_CANJES.TEL_CONTACTO%TYPE,
                              p_ema_contacto         IN BW_CANJES.EMA_CONTACTO%TYPE,
                              p_ema_des_notificacion IN BW_CANJES.EMA_DES_NOTIFICACION%TYPE,
                              p_cantidad             IN BW_CANJES.CANTIDAD%TYPE DEFAULT NULL,
                              p_puntos               IN BW_CANJES.PUNTOS%TYPE DEFAULT NULL,
                              p_tel_proveedor        IN BW_CANJES.TEL_PROVEEDOR%TYPE DEFAULT NULL,
                              p_showroom             IN BW_CANJES.SHOWROOM%TYPE DEFAULT NULL,
                              p_direccion            IN BW_CANJES.DIRECCION%TYPE DEFAULT NULL,
                              p_rec_autorizada       IN BW_CANJES.REC_AUTORIZADA%TYPE DEFAULT NULL,
                              p_per_autorizada       IN BW_CANJES.PER_AUTORIZADA%TYPE DEFAULT NULL,
                              p_cod_tip_autorizado   IN BW_CANJES.COD_TIP_AUTORIZADO%TYPE DEFAULT NULL,
                              p_nro_doc_autorizado   IN BW_CANJES.NRO_DOC_AUTORIZADO%TYPE DEFAULT NULL,
                              p_hor_inicio           IN BW_CANJES.HOR_INICIO%TYPE DEFAULT NULL,
                              p_hor_fin              IN BW_CANJES.HOR_FIN%TYPE DEFAULT NULL,
                              p_ben_titular          IN BW_CANJES.BEN_TITULAR%TYPE DEFAULT NULL,
                              p_beneficiario         IN BW_CANJES.BENEFICIARIO%TYPE DEFAULT NULL,
                              p_turno                IN BW_CANJES.TURNO%TYPE DEFAULT NULL,
                              p_sol_ida              IN BW_CANJES.SOL_IDA%TYPE DEFAULT NULL,
                              p_fec_salida           IN BW_CANJES.FEC_SALIDA%TYPE DEFAULT NULL,
                              p_fec_retorno          IN BW_CANJES.FEC_RETORNO%TYPE DEFAULT NULL,
                              p_fec_flexible         IN BW_CANJES.FEC_FLEXIBLE%TYPE DEFAULT NULL,
                              p_cla_servicio         IN BW_CANJES.CLA_SERVICIO%TYPE DEFAULT NULL,
                              p_can_ninos            IN BW_CANJES.CAN_NINOS%TYPE DEFAULT NULL,
                              p_can_adultos          IN BW_CANJES.CAN_ADULTOS%TYPE DEFAULT NULL,
                              p_lin_aerea            IN BW_CANJES.LIN_AEREA%TYPE DEFAULT NULL,
                              p_nro_doc_beneficiario IN Bw_Canjes.NRO_DOC_BENEFICIARIO%TYPE DEFAULT NULL,
                              p_fec_entrada          IN BW_CANJES.FEC_ENTRADA%TYPE DEFAULT NULL,
                              p_cod_verificador      IN BW_CANJES.COD_VERIFICADOR%TYPE DEFAULT NULL,
                              p_condiciones          IN VARCHAR2 DEFAULT NULL,
                              p_detalles             IN TYP_LISTADETALLECANJE DEFAULT NULL,
                              p_est_canje            IN BW_CANJES.ESTADO%TYPE,
            p_nom_proveedor        IN BW_CANJES.COMERCIO%TYPE DEFAULT NULL,
                              p_cod_producto         IN BW_CANJES.COD_PRODUCTO%TYPE DEFAULT NULL,
                              p_cod_sesion_aux       IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL,
                              p_usr_operador         IN BW_CANJES.OPE_CANJE%TYPE DEFAULT NULL,
                              p_suc_env_voucher      IN BW_CANJES.SUC_ENV_VOUCHER%TYPE DEFAULT NULL) RETURN TYP_CANJE IS
      v_log_datos               BW_BITACORAS.DATO%TYPE;
      v_cod_persona             BW_AUT_SESIONES.COD_PERSONA%TYPE;
      v_cod_canal               BW_AUT_SESIONES.COD_CANAL%TYPE;
      v_nro_tarjeta             BW_CANJES.NRO_TARJETA%TYPE;
      v_nro_canje               BW_CANJES.NRO_CANJE%TYPE;
      v_cod_estado_tarjeta      TA_TARJETAS.COD_ESTADO%TYPE;
      v_nom_titular             BA_PERSONAS.NOM_COMPLETO%TYPE;
      v_nro_doc_titular         BA_PERSONAS.NRO_DOCUMENTO%TYPE;
      v_nom_producto            BW_CANJES.NOM_PRODUCTO%TYPE;
      v_des_producto            BW_CANJES.DES_PRODUCTO%TYPE;
      v_tel_contacto            BW_CANJES.TEL_CONTACTO%TYPE;
      v_ema_contacto            BW_CANJES.EMA_CONTACTO%TYPE;
      v_ema_des_notificacion    BW_CANJES.EMA_DES_NOTIFICACION%TYPE;
      v_men_estado              VARCHAR(20);
      v_cod_operacion           VARCHAR2(3) := '228';
      v_tel_proveedor           BW_CANJES.TEL_PROVEEDOR%TYPE := NULL;
      v_showroom                BW_CANJES.SHOWROOM%TYPE := NULL;
      v_direccion               BW_CANJES.DIRECCION%TYPE := NULL;
      v_rec_autorizada          BW_CANJES.REC_AUTORIZADA%TYPE := NULL;
      v_per_autorizada          BW_CANJES.PER_AUTORIZADA%TYPE := NULL;
      v_des_documento           BA_TIP_DOCUMENTOS.DESCRIPCION%TYPE := NULL;
      v_nro_doc_autorizado      BW_CANJES.NRO_DOC_AUTORIZADO%TYPE := NULL;
      v_hor_inicio              DATE;
      v_hor_fin                 DATE;
      v_ben_titular             BW_CANJES.BEN_TITULAR%TYPE := NULL;
      v_beneficiario            BW_CANJES.BENEFICIARIO%TYPE := NULL;
      v_nro_doc_beneficiario    BW_CANJES.NRO_DOC_BENEFICIARIO%TYPE := NULL;
      v_turno                   BW_CANJES.TURNO%TYPE := NULL;
      v_sol_ida                 BW_CANJES.SOL_IDA%TYPE := NULL;
      v_fec_flexible            BW_CANJES.FEC_FLEXIBLE%TYPE := NULL;
      v_fec_retorno             BW_CANJES.FEC_RETORNO%TYPE := NULL;
      v_fec_entrada             BW_CANJES.FEC_ENTRADA%TYPE := NULL;
      v_lin_aerea               BW_CANJES.LIN_AEREA%TYPE := NULL;
      v_hor_canje               DATE;
      v_mensaje                 VARCHAR2(8000);
      v_men_not_estado          VARCHAR2(8000);
      v_des_mail                BW_CANJES.DES_PRODUCTO%TYPE;
      v_notificacion_estado     NUMBER;
      v_ema_not_interasistencia VARCHAR2(240);
      v_ema_not_tarjetas        VARCHAR2(240);
      v_ema_not_contacto        VARCHAR2(240);
      v_ema_not_est_canje       VARCHAR2(240);
      v_retorno                 typ_canje := typ_canje();
      v_condiciones             VARCHAR2(4000);
      v_verificado              BW_CANJES.VERIFICADO%TYPE := 'N';
      v_tip_canje               VARCHAR2(2) := NULL;
      v_usr_operador            VARCHAR2(12) := NULL;
      v_suc_envio_voucher       VARCHAR2(50) := NULL;
      v_suc_cliente             VARCHAR2(50) := NULL;

      -- categorías
      TANGIBLES CONSTANT NUMBER := 1;
      SERVICIOS CONSTANT NUMBER := 2;
      VIAJES    CONSTANT NUMBER := 3;  -- Canjes con Puntos Fijos
      CENAS     CONSTANT NUMBER := 4;
      HOSPEDAJES  CONSTANT NUMBER := 5;
      GENERICO  CONSTANT NUMBER := 6;
      TECH      CONSTANT NUMBER := 7;
      VIAJES_GEN  CONSTANT NUMBER := 8;  -- Canje con Puntos definidos por el Usuario.

      -- errores retornados en canjes de puntos
      PAR_ENT_INV        CONSTANT VARCHAR2(15) := 'PAR_ENT_INV';
      EMA_CONF_NOT_FOUND CONSTANT VARCHAR2(15) := 'EMA_CONF_INV';

      -- Parámetro para activar debito de puntos en categoráa viajes
      PAR_ACT_DEB_PUN_MIC_VIAJES CONSTANT ge_parametros.parametro%TYPE := 'ACT_DEB_PUN_MIC_VIAJES';
      V_ACT_DEB_PUN_MIC_VIAJES   ge_par_dinamicos.val_parametro%TYPE;

      PAR_ENV_EMA_CLIENTE CONSTANT ge_parametros.parametro%TYPE := 'ENV_NOT_CLI_CAN_PUNTOS';
      PAR_ENV_EMA_INTERASISTENCIA CONSTANT ge_parametros.parametro%TYPE := 'ENV_NOT_INT_CAN_PUNTOS';
      V_ACT_ENV_CLIENTE   ge_par_dinamicos.val_parametro%TYPE;
      V_ACT_ENV_INTERASISTENCIA   ge_par_dinamicos.val_parametro%TYPE;
      v_origen VARCHAR2(15) := 'BBVAEXPIENCE';

   BEGIN

      v_cod_persona := p_cod_persona;
      v_cod_canal   := paw_uti.depurarNumerico(p_cod_canal, 3);

      -- registra el inicio de la función. Por la cantidad grande de parámetros de entrada solo se
      -- registrará el dato de entrada que viene con un valor invalido para la operación en caso que hubiese
      v_log_datos := 'fu_ns_ins_can_puntos: inicio de funcion';
      paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, v_log_datos, BITACORA_ENTRADA);

      -- valida parámetros generales obligatorios no tengan valores nulos
      IF (p_cat_producto IS NULL OR p_nom_producto IS NULL OR p_des_producto IS NULL OR p_tel_contacto IS NULL OR p_ema_contacto IS NULL OR p_ema_des_notificacion IS NULL OR p_est_canje IS NULL) THEN
         paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro general obligatorio con valor nulo]', BITACORA_ERROR);
         RETURN v_retorno;
      END IF;

      --asumimos que si no tiene sesion es un canje telefonico
      IF p_cod_sesion_aux IS NULL THEN
         v_tip_canje := 'T'; --Telefonico
         v_usr_operador := p_usr_operador;
         v_suc_envio_voucher := p_suc_env_voucher; --solamente si es telefonico puede tener sucursal de envio.
      ELSE
         v_tip_canje := 'A'; --Autogestionado
      END IF;

      -- valida que los números de tarjeta esten relacionados con el cliente
      IF p_detalles IS NOT NULL THEN
        FOR detalle in p_detalles.FIRST .. p_detalles.LAST LOOP
           v_nro_tarjeta := paw_uti.depurarNumerico(p_detalles(detalle).nro_tarjeta, 4);
           BEGIN
              SELECT T.COD_ESTADO
                 INTO v_cod_estado_tarjeta
                 FROM TA_TARJETAS T
                 WHERE T.COD_PERSONA = v_cod_persona
                     AND SUBSTR(T.NRO_TARJETA, -4) = v_nro_tarjeta;
           EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [numero de tarjeta no relacionada con el cliente]', BITACORA_ERROR);
                 RETURN v_retorno;
              WHEN TOO_MANY_ROWS THEN
                 NULL;
           END;
        END LOOP;
      END IF;

      -- obtiene el nombre y cedula del titular de la tarjeta usada en el canje
      BEGIN
         SELECT P.NOM_COMPLETO, P.NRO_DOCUMENTO
           INTO v_nom_titular, v_nro_doc_titular
           FROM BA_PERSONAS P
          WHERE P.COD_PERSONA = v_cod_persona; --DDSI-736 Se elimina validacion de CI nacional para el canje.
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [error al obtener el nombre del titular de la tarjeta]', BITACORA_ERROR);
            RETURN v_retorno;
      END;

      -- obtiene la Sucursal del cliente
      BEGIN

         select t.descripcion as sucursal
         into v_suc_cliente
         from ge_clientes c
         join ba_oficinas t ON c.cod_oficina = t.cod_oficina
         where c.cod_persona = v_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            --por alguna razon no se encontro
            v_suc_cliente := null;
      END;

      -- sanitiza campos de nombre de producto, descripción de producto y teléfono de contacto
      v_nom_producto := SUBSTR(TRIM(p_nom_producto), 1, 255); --caracteres especiales se conservan
      v_des_producto := SUBSTR(REGEXP_REPLACE(TRIM(p_des_producto), '\\r\\n', CHR(10)), 1, 1000); --caracteres especiales se conservan
      v_tel_contacto := paw_uti.depurarNumerico(p_tel_contacto, 10);

      -- valida parámetros de mails
      v_ema_contacto         := TRIM(p_ema_contacto);
      v_ema_des_notificacion := TRIM(p_ema_des_notificacion);
      IF paw_uti.fu_validarMail(v_ema_contacto) = 'N' THEN
         paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_ema_contacto con formato invalido]', BITACORA_ERROR);
         RETURN v_retorno;
      END IF;
      IF paw_uti.fu_validarMail(v_ema_des_notificacion) = 'N' THEN
         paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_des_notificacion con formato invalido]', BITACORA_ERROR);
         RETURN v_retorno;
      END IF;

      -- Variable para Debito de Puntos en el Micrositio
      V_ACT_DEB_PUN_MIC_VIAJES :=  NVL(fug_obt_pardinamico(PAR_ACT_DEB_PUN_MIC_VIAJES),'N');

      -- valida campos por categoría
      CASE
         WHEN p_cat_producto = TANGIBLES THEN
            -- valida parámetros obligatorios de la categoría
            v_tel_proveedor  := paw_uti.depurarNumerico(p_tel_proveedor, 10);
            v_showroom       := paw_uti.depurarAlfanumerico(p_showroom, 1);
            v_direccion      := SUBSTR(TRIM(p_direccion), 1, 80); --conserva caracteres especiales
            v_rec_autorizada := paw_uti.depurarAlfanumerico(p_rec_autorizada, 1);
            IF (p_cantidad IS NULL OR p_puntos IS NULL OR v_tel_proveedor IS NULL OR v_showroom IS NULL OR v_direccion IS NULL OR v_rec_autorizada IS NULL) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro de tangibles obligatorio con valor nulo]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF (v_showroom NOT IN ('S', 'N') OR v_rec_autorizada NOT IN ('S', 'N')) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_showroom o p_rec_autorizada con valor incorrecto]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;

            IF (v_showroom = 'N') THEN
               -- valida horarios
               BEGIN
                  IF (p_hor_inicio IS NULL OR p_hor_fin IS NULL) THEN
                     paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_hor_inicio o p_hor_fin  con valor incorrecto]', BITACORA_ERROR);
                     RETURN v_retorno;
                  END IF;
                  v_hor_inicio := TO_DATE(p_hor_inicio, 'hh24:mi');
                  v_hor_fin    := TO_DATE(p_hor_fin, 'hh24:mi');
                  IF (v_hor_inicio > v_hor_fin) THEN
                     paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_hor_inicio mayor a p_hor_fin]', BITACORA_ERROR);
                     RETURN v_retorno;
                  END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_hor_inicio o p_hor_fin  con formato invalido]', BITACORA_ERROR);
                     RETURN v_retorno;
               END;
            END IF;

            IF (v_rec_autorizada = 'S') THEN
               v_per_autorizada     := SUBSTR(TRIM(p_per_autorizada), 1, 120);
               v_nro_doc_autorizado := SUBSTR(TRIM(p_nro_doc_autorizado), 1, 20);
               IF (v_per_autorizada IS NULL OR p_cod_tip_autorizado IS NULL OR v_nro_doc_autorizado IS NULL) THEN
                  paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_per_autorizada o p_cod_tip_autorizado o p_nro_doc_autorizado  con valor incorrecto]', BITACORA_ERROR);
                  RETURN v_retorno;
               END IF;

               -- valida que el tipo de documento exista
               BEGIN
                  SELECT T.DESCRIPCION
                    INTO v_des_documento
                    FROM BA_TIP_DOCUMENTOS T
                   WHERE T.COD_TIP_DOCUMENTO = p_cod_tip_autorizado;
               EXCEPTION
                  WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
                     paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_cod_tip_autorizado con valor incorrecto]', BITACORA_ERROR);
                     RETURN v_retorno;
               END;
            END IF;
         WHEN p_cat_producto = SERVICIOS THEN
            -- valida parámetros obligatorios de la categoría
            v_tel_proveedor := paw_uti.depurarNumerico(p_tel_proveedor, 10);
            v_ben_titular   := paw_uti.depurarAlfanumerico(p_ben_titular, 1);
            v_turno         := paw_uti.depurarAlfanumerico(p_turno, 1);
            v_direccion     := SUBSTR(TRIM(p_direccion), 1, 80); --conserva caracteres especiales
            IF (p_puntos IS NULL OR p_cantidad IS NULL OR v_tel_proveedor IS NULL OR v_ben_titular IS NULL OR v_turno IS NULL OR v_direccion IS NULL) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro de servicios obligatorio con valor nulo]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF (v_ben_titular NOT IN ('S', 'N') OR v_turno NOT IN ('S', 'N')) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_ben_titular o p_turno con valor incorrecto]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF v_ben_titular = 'S' THEN
               v_beneficiario := v_nom_titular;
            ELSE
               v_beneficiario := SUBSTR(TRIM(p_beneficiario), 1, 120); --conserva caracteres especiales
               IF v_beneficiario IS NULL THEN
                  paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_beneficiario con valor incorrecto]', BITACORA_ERROR);
                  RETURN v_retorno;
               END IF;
            END IF;
    WHEN p_cat_producto IN (VIAJES, VIAJES_GEN) THEN
            IF V_ACT_DEB_PUN_MIC_VIAJES = 'N' THEN
              -- valida parámetros obligatorios de la categoría
              v_sol_ida      := paw_uti.depurarAlfanumerico(p_sol_ida, 1);
              v_fec_flexible := paw_uti.depurarAlfanumerico(p_fec_flexible, 1);
              v_lin_aerea    := SUBSTR(TRIM(p_lin_aerea), 1, 100);
              IF (v_sol_ida IS NULL OR p_fec_salida IS NULL OR v_fec_flexible IS NULL OR p_cla_servicio IS NULL OR p_can_ninos IS NULL OR p_can_adultos IS NULL OR v_lin_aerea IS NULL) THEN
                 paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro de viajes obligatorio con valor nulo]', BITACORA_ERROR);
                 RETURN v_retorno;
              END IF;
              IF (v_sol_ida NOT IN ('S', 'N') OR v_fec_flexible NOT IN ('S', 'N')) THEN
                 paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_sol_ida o p_fec_flexible con valor incorrecto]', BITACORA_ERROR);
                 RETURN v_retorno;
              END IF;
              IF (p_cla_servicio < 1 OR p_cla_servicio > 2) THEN
                 paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                 paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_cla_servicio con valor incorrecto]', BITACORA_ERROR);
                 RETURN v_retorno;
              END IF;
              v_fec_retorno := p_fec_retorno;
              IF (v_sol_ida = 'N') THEN
                 IF (v_fec_retorno IS NULL) THEN
                    paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_fec_retorno con valor incorrecto]', BITACORA_ERROR);
                    RETURN v_retorno;
                 END IF;
                 IF (v_fec_retorno < p_fec_salida) THEN
                    paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                    paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_fec_retorno menor a  p_fec_salida]', BITACORA_ERROR);
                    RETURN v_retorno;
                 END IF;
              ELSE
                 v_fec_retorno := NULL;
              END IF;
           END IF;
        WHEN p_cat_producto IN( TECH,CENAS) THEN
            v_tel_proveedor := paw_uti.depurarNumerico(p_tel_proveedor, 10);
            v_ben_titular   := paw_uti.depurarAlfanumerico(p_ben_titular, 1);
            v_direccion     := SUBSTR(TRIM(p_direccion), 1, 80);
            v_turno         := paw_uti.depurarAlfanumerico(p_turno, 1);
            IF(v_ben_titular IS NULL OR v_direccion IS NULL OR v_tel_proveedor IS NULL OR (p_cat_producto = CENAS AND v_turno IS NULL)) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro obligatorio de tech o cenas con valor nulo]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF (v_ben_titular NOT IN('S','N') OR (p_cat_producto = CENAS AND v_turno NOT IN ('S', 'N'))) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_ben_titular|v_turno con valor incorrecto]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF(v_ben_titular = 'S') THEN
               v_beneficiario := v_nom_titular;
            ELSE
               v_beneficiario := SUBSTR(TRIM(p_beneficiario), 1, 120); --conserva caracteres especiales
               IF (v_beneficiario IS NULL) THEN
                  paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_beneficiario con valor incorrecto]', BITACORA_ERROR);
                  RETURN v_retorno;
               END IF;
            END IF;
        WHEN p_cat_producto = HOSPEDAJES THEN
             v_fec_entrada    := p_fec_entrada;
             v_turno          := paw_uti.depurarAlfanumerico(p_turno, 1);
             v_tel_proveedor  := paw_uti.depurarNumerico(p_tel_proveedor, 10);
             v_ben_titular    := paw_uti.depurarAlfanumerico(p_ben_titular, 1);
             IF (v_fec_entrada IS NULL OR v_turno IS NULL OR v_ben_titular IS NULL OR v_tel_proveedor IS NULL) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro de hospedajes obligatorio con valor nulo]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;

            IF (v_ben_titular NOT IN('S','N') or v_turno NOT IN ('S','N')) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro de hospedajes con valor incorrecto]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF(v_ben_titular = 'S') THEN
               v_beneficiario := v_nom_titular;
               v_nro_doc_beneficiario := v_nro_doc_titular;
            ELSE
               v_beneficiario := SUBSTR(TRIM(p_beneficiario), 1, 120); --conserva caracteres especiales
               v_nro_doc_beneficiario := SUBSTR(TRIM(p_nro_doc_beneficiario), 1, 20);
               IF (v_beneficiario IS NULL OR v_nro_doc_beneficiario IS NULL) THEN
                  paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_beneficiario o p_nro_doc_beneficiario con valor incorrecto]', BITACORA_ERROR);
                  RETURN v_retorno;
               END IF;
            END IF;

        WHEN p_cat_producto = GENERICO THEN
            v_tel_proveedor  := paw_uti.depurarNumerico(p_tel_proveedor, 10);
            v_ben_titular := paw_uti.depurarAlfanumerico(p_ben_titular, 1);
            v_direccion     := SUBSTR(TRIM(p_direccion), 1, 80);
            IF(v_ben_titular IS NULL OR v_direccion IS NULL OR v_tel_proveedor IS NULL) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_ben_titular con valor nulo]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF (v_ben_titular NOT IN('S','N')) THEN
               paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_ben_titular con valor incorrecto]', BITACORA_ERROR);
               RETURN v_retorno;
            END IF;
            IF(v_ben_titular = 'S') THEN
               v_beneficiario := v_nom_titular;
               v_nro_doc_beneficiario := v_nro_doc_titular;
            ELSE
               v_beneficiario := SUBSTR(TRIM(p_beneficiario), 1, 120); --conserva caracteres especiales
               v_nro_doc_beneficiario := SUBSTR(TRIM(p_nro_doc_beneficiario), 1, 20);
               IF (v_beneficiario IS NULL OR v_nro_doc_beneficiario IS NULL) THEN
                  paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_beneficiario o p_nro_doc_beneficiario con valor incorrecto]', BITACORA_ERROR);
                  RETURN v_retorno;
               END IF;
            END IF;
        ELSE
            paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [parametro p_cat_producto con valor incorrecto]', BITACORA_ERROR);
        RETURN v_retorno;
      END CASE ;

      --registra el canje de puntos
      v_hor_canje := SYSDATE;
      SELECT S_NRO_CANJE.NEXTVAL INTO v_nro_canje FROM DUAL;

      BEGIN
         INSERT INTO BW_CANJES
            (nro_canje, nro_tarjeta, cod_persona, cat_producto, nom_producto, des_producto, tel_contacto, ema_contacto, ema_des_notificacion, cantidad, puntos, tel_proveedor, showroom, direccion, rec_autorizada, per_autorizada, cod_tip_autorizado, nro_doc_autorizado, hor_inicio, hor_fin, ben_titular, beneficiario, nro_doc_beneficiario, turno, sol_ida, fec_salida, fec_entrada, fec_retorno, fec_flexible, cla_servicio, can_ninos, can_adultos, lin_aerea, cod_verificador, estado, cod_canal, comercio, verificado, TIP_CANJE, OPE_CANJE, suc_cliente, suc_env_voucher, cod_producto)
         VALUES
            (v_nro_canje, p_nro_tarjeta, v_cod_persona, p_cat_producto, v_nom_producto, v_des_producto, v_tel_contacto, v_ema_contacto, v_ema_des_notificacion, p_cantidad, p_puntos, v_tel_proveedor, v_showroom, v_direccion, v_rec_autorizada, v_per_autorizada, p_cod_tip_autorizado, v_nro_doc_autorizado, p_hor_inicio, p_hor_fin, v_ben_titular, v_beneficiario, v_nro_doc_beneficiario, v_turno, v_sol_ida, p_fec_salida, v_fec_entrada, v_fec_retorno, v_fec_flexible, p_cla_servicio, p_can_ninos, p_can_adultos, v_lin_aerea, p_cod_verificador, p_est_canje, v_cod_canal, p_nom_proveedor, v_verificado, v_tip_canje, v_usr_operador, v_suc_cliente, v_suc_envio_voucher, p_cod_producto);

      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [insercion: bw_canjes, ORA-ERR: ' || SUBSTR(SQLERRM, 1, 200) || '] ', BITACORA_ERROR);
            RETURN v_retorno;
      END;
      IF p_detalles IS NOT NULL THEN
         FOR detalle in p_detalles.FIRST .. p_detalles.LAST LOOP
            BEGIN
               INSERT INTO BW_CANJES_DET
                  (nro_tarjeta, puntos, nro_canje, nro_sub_canje, estado)
               VALUES
                  (p_detalles(detalle).nro_tarjeta, p_detalles(detalle).puntos, v_nro_canje, p_detalles(detalle).nro_canje, p_detalles(detalle).estado);
            EXCEPTION
               WHEN DUP_VAL_ON_INDEX THEN
                  paw_uti.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [insercion: bw_canjes_det, ORA-ERR: ' || SUBSTR(SQLERRM, 1, 200) || '] ', BITACORA_ERROR);
                  RETURN v_retorno;
            END;
         END LOOP;
      END IF;

      v_retorno.nro_canje := v_nro_canje;
      --reemplaza separador de línea por su equivalente en html
      v_des_mail := SUBSTR(REGEXP_REPLACE(TRIM(p_des_producto), '\\r\\n', '<br>'), 1, 500);

      v_mensaje := '
          <h2 style="color:#074CA9; font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; margin-top:0px">CANJE DE PUNTOS</h2>
          <h2 style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; margin-top:0px">' || UTL_URL.ESCAPE(p_nom_proveedor, TRUE, 'UTF-8') || '</h2>
          <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px">' || UTL_URL.ESCAPE(v_nom_producto, TRUE, 'UTF-8') || '</p>';

      v_mensaje := v_mensaje || '
           <table width="500"; style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px;">
           <tbody >
              <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nro. identificador:</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || v_nro_canje || '</td>
              </tr>
              <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Titular de la tarjeta:</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_nom_titular, TRUE, 'UTF-8') || '</td>
              </tr>
              <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>'||UTL_URL.ESCAPE('Cédula del titular  :', TRUE, 'UTF-8') || '</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_nro_doc_titular, TRUE, 'UTF-8') || '</td>
              </tr>
              <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha del Canje:</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || to_char(v_hor_canje, 'dd/mm/yyyy - hh24:mi') || '</td>
              </tr>';

    IF (p_cat_producto NOT IN(VIAJES,VIAJES_GEN) OR ( p_cat_producto IN(VIAJES,VIAJES_GEN) AND V_ACT_DEB_PUN_MIC_VIAJES = 'S')) THEN
      v_mensaje := v_mensaje || '
               <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Puntos canjeados:</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || p_puntos || '</td>
              </tr>';
    END IF;

      IF (p_cat_producto = TANGIBLES) THEN
         IF (v_showroom = 'S') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Entrega:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Retirar del showroom</td>
                     </tr>';
         ELSE
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Entrega:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_direccion, TRUE, 'UTF-8') || '</td>
                     </tr>
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Horario de Entrega:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || TO_CHAR(v_hor_inicio, 'hh24:mi') || ' a ' || TO_CHAR(v_hor_fin, 'hh24:mi') || '</td>
                     </tr>';
         END IF;
         IF (v_rec_autorizada = 'S') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Persona autorizada:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_per_autorizada, TRUE, 'UTF-8') || '</td>
                     </tr>
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Documento:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || v_des_documento || ' - ' || UTL_URL.ESCAPE(v_nro_doc_autorizado, TRUE, 'UTF-8') || '</td>
                     </tr>';
         END IF;
      END IF;
      IF (p_cat_producto = SERVICIOS) THEN
         v_mensaje := v_mensaje || '
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Beneficiario:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_beneficiario, TRUE, 'UTF-8') || '</td>
                   </tr>';
         IF (v_turno = 'S') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Reserva de turno:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Si</td>
                     </tr>';
         ELSE
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Reserva de turno:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">No</td>
                     </tr>';
         END IF;
      END IF;

    IF (p_cat_producto = VIAJES  AND V_ACT_DEB_PUN_MIC_VIAJES = 'N' ) THEN
         IF (v_sol_ida = 'S') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Tipo de pasaje:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Solo ida</td>
                     </tr>';
         ELSE
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Tipo de pasaje:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Ida y vuelta</td>
                     </tr>';
         END IF;
         v_mensaje := v_mensaje || '
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha de salida:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || to_char(p_fec_salida, 'dd/mm/yyyy') || '</td>
                   </tr>';
         IF (v_sol_ida = 'N') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha de retorno:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || to_char(v_fec_retorno, 'dd/mm/yyyy') || '</td>
                     </tr>';
         END IF;
         IF (p_cla_servicio = '1') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Clase de Servicio:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Turista</td>
                     </tr>';
         ELSE
            v_mensaje := v_mensaje || '
                     <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Clase de Servicio:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Ejecutiva</td>
                     </tr>';
         END IF;
         v_mensaje := v_mensaje || '
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>' || UTL_URL.ESCAPE('Línea', TRUE, 'UTF-8') || ' aerea:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_lin_aerea, TRUE, 'UTF-8') || '</td>
                   </tr>
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Pasajeros:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;"> Adultos: ' || to_char(p_can_adultos) || ' - Niños: ' || p_can_ninos || '</td>
                   </tr>';
      END IF;
      IF p_cat_producto IN (TECH,CENAS) THEN
        v_mensaje := v_mensaje || '
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Beneficiario:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_beneficiario, TRUE, 'UTF-8') || '</td>
                   </tr>';

         IF p_cat_producto = CENAS THEN
            IF (v_turno = 'S') THEN
               v_mensaje := v_mensaje || '
                        <tr>
                          <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Reserva de turno:</b></td>
                          <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Si</td>
                        </tr>';
            ELSE
               v_mensaje := v_mensaje || '
                        <tr>
                          <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Reserva de turno:</b></td>
                          <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">No</td>
                        </tr>';
            END IF;
         END IF;
      END IF;
      IF (p_cat_producto = HOSPEDAJES ) THEN
        v_mensaje := v_mensaje || '
                   <tr>
                       <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha de entrada:</b></td>
                       <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || to_char(v_fec_entrada, 'dd/mm/yyyy') || '</td>
                     </tr>';
         IF (v_turno = 'S') THEN
            v_mensaje := v_mensaje || '
                     <tr>
                        <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Reserva de turno:</b></td>
                        <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">Si</td>
                     </tr>';
         ELSE
            v_mensaje := v_mensaje || '
                     <tr>
                        <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Reserva de turno:</b></td>
                        <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">No</td>
                     </tr>';
         END IF;
         v_mensaje := v_mensaje || '
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Beneficiario:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_beneficiario, TRUE, 'UTF-8') || '</td>
                   </tr>
                   <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>' || UTL_URL.ESCAPE('Cédula', TRUE, 'UTF-8') || ' Beneficiario:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_nro_doc_beneficiario, TRUE, 'UTF-8') || '</td>
                   </tr>';
      END IF;
      IF (p_cat_producto = GENERICO) THEN
        v_mensaje := v_mensaje || '
                   <tr>
                     <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Beneficiario:</b></td>
                     <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_beneficiario, TRUE, 'UTF-8') || '</td>
                   </tr>
                   <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>' || UTL_URL.ESCAPE('Cédula', TRUE, 'UTF-8') || ' Beneficiario:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_nro_doc_beneficiario, TRUE, 'UTF-8') || '</td>
                   </tr>';
      END IF;

      v_mensaje := v_mensaje || '
              <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>' || UTL_URL.ESCAPE('Teléfono', TRUE, 'UTF-8') || ' contacto:</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || v_tel_contacto || '</td>
              </tr>
               <tr>
                 <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>E-mail de contacto:</b></td>
                 <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || v_ema_contacto || '</td>
              </tr>';
      IF (p_cat_producto = TANGIBLES OR p_cat_producto = SERVICIOS) THEN
         v_mensaje := v_mensaje || '
                 <tr>
                   <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Cantidad:</b></td>
                   <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || p_cantidad || '</td>
                </tr>';
      END IF;
      IF (p_cat_producto = TANGIBLES AND v_showroom = 'S') OR p_cat_producto IN (SERVICIOS, TECH, CENAS, GENERICO) THEN
         v_mensaje := v_mensaje || '
                  <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>' || UTL_URL.ESCAPE('Dirección', TRUE, 'UTF-8') || ' proveedor:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || UTL_URL.ESCAPE(v_direccion, TRUE, 'UTF-8') || '</td>
                  </tr>
                  <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>' || UTL_URL.ESCAPE('Teléfono', TRUE, 'UTF-8') || ' proveedor:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || v_tel_proveedor || '</td>
                  </tr>';
      END IF;

      IF p_est_canje IN ('X', 'E') THEN
          IF p_est_canje = 'X' THEN
             v_men_estado := 'Confirmado con errores';
          ELSE
             v_men_estado := 'Con errores';
          END IF;

          v_men_not_estado := v_mensaje || '
                  <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px; color:red"><b>' || UTL_URL.ESCAPE('Estado', TRUE, 'UTF-8') || ' canje:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px; color:red">' || UTL_URL.ESCAPE(v_men_estado, TRUE, 'UTF-8') || '</td>
                  </tr>';
      END IF;

      v_mensaje := v_mensaje || '</tbody></table>';

      IF p_condiciones IS NOT NULL AND LENGTH(p_condiciones) > 0 THEN
         v_condiciones := SUBSTR(p_condiciones, 1, 4000);
         v_mensaje := v_mensaje || '
            <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE(v_condiciones, TRUE, 'UTF-8') || '</b></p>';
      ELSE
         IF (p_cat_producto = TANGIBLES) THEN
            v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('El retiro del producto se podrá realizar luego de 48 horas de solicitado el canje y es válido por 30 días. Sujeto a disponibilidad de stock. Para consultas o reclamos sobre la entrega favor comunicarse al 417-6070, disponible las 24 horas del día.', TRUE, 'UTF-8') || '</b></p>';
         END IF;

         IF (p_cat_producto = SERVICIOS) THEN
            v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('El servicio canjeado es válido por 90 días corridos a partir de la fecha de canje. Para consultas o reclamos sobre la entrega favor comunicarse al 417-6070, disponible las 24 horas del día.', TRUE, 'UTF-8') || '</b></p>';
         END IF;

     IF (p_cat_producto = VIAJES AND V_ACT_DEB_PUN_MIC_VIAJES = 'N') THEN
            v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('La presente solicitud se encuentra pendiente de confirmación por parte de la Agencia para verificación de disponibilidad de vuelos en las fechas indicadas.<br>Un agente se pondra en contacto con usted dentro de las próximas 24 horas. Ante consultas favor contacte a la Línea Experience 417-6070, disponible las 24 horas del día.', TRUE, 'UTF-8') || '</b></p>';
         END IF;

         IF p_cat_producto = TECH THEN
           v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('Sujeto a disponibilidad. En caso de no contar con el producto canjeado se podrá solicitar la devolución de los puntos comunicándose a la línea Experience.', TRUE, 'UTF-8') || '</b></p>';
         END IF;

         IF p_cat_producto = CENAS THEN
           v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('Reservas con 48hs. de anticipación a los teléfonos  021 624070/1 / 0976 332244.', TRUE, 'UTF-8') || '</b></p>';
         END IF;
         IF p_cat_producto = HOSPEDAJES THEN
           v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('Reservas con 24hs. de anticipación a los teléfonos 021 621800. Sujeto a disponibilidad de habitaciones.', TRUE, 'UTF-8') || '</b></p>';
         END IF;
         IF p_cat_producto = GENERICO THEN
           v_mensaje := v_mensaje || '
               <p style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px"><b>' || UTL_URL.ESCAPE('Conozca más sobre las Bases y Condiciones del programa <a href="'||fug_obt_pardinamico('URL_BENEFICIOS')||'">aquí</a>', TRUE, 'UTF-8') || '</b></p>';
         END IF;
      END IF;



      v_mensaje := '<div style="padding:20px 20px">' || v_mensaje || '</div>';

      --configura direcciones de correo según el entorno de donde se ejecuta
      IF NVL(fug_ind_produccion,'N') = 'N' THEN
         BEGIN
            SELECT VAL_MINIMO, VAL_MAXIMO
              INTO v_ema_des_notificacion, v_ema_not_contacto
              FROM BA_COD_REFERENCIAS
               WHERE DOMINIO = 'CAN_PUN_EMA_TEST';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_ema_des_notificacion := fug_obt_pardinamico('TST_NOT_MAIL');
               v_ema_not_contacto     := fug_obt_pardinamico('TST_NOT_MAIL');
         END;
         BEGIN
            SELECT VAL_MINIMO, VAL_MAXIMO
              INTO v_ema_not_interasistencia, v_ema_not_tarjetas
              FROM BA_COD_REFERENCIAS
             WHERE DOMINIO = 'CAN_PUN_INT_EMA_TEST';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_ema_not_interasistencia := fug_obt_pardinamico('TST_NOT_MAIL');
               v_ema_not_tarjetas        := fug_obt_pardinamico('TST_NOT_MAIL');
         END;
      ELSE
         v_ema_not_contacto := v_ema_contacto;
         BEGIN
            SELECT VAL_MINIMO, VAL_MAXIMO
              INTO v_ema_not_interasistencia, v_ema_not_tarjetas
              FROM BA_COD_REFERENCIAS
             WHERE DOMINIO = 'CAN_PUN_INT_EMA';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               paw_uti.pr_mensajeUsuario(EMA_CONF_NOT_FOUND, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, NULL, 'fu_ns_ins_can_puntos: [mails de interasistencia no configurada]', BITACORA_ERROR);
               RETURN v_retorno;
         END;
      END IF;


      V_ACT_ENV_CLIENTE :=  NVL(fug_obt_pardinamico(PAR_ENV_EMA_CLIENTE),'N');
      V_ACT_ENV_INTERASISTENCIA :=  NVL(fug_obt_pardinamico(PAR_ENV_EMA_INTERASISTENCIA),'N');

      IF p_est_canje IN ('X', 'C') THEN
         --envia notificaciones via email
         IF p_cat_producto IN (TANGIBLES, SERVICIOS, TECH, CENAS, GENERICO, HOSPEDAJES) THEN
            -- envia notificacion al proveedor del producto o servicio canjeado
            v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_des_notificacion, v_mensaje, v_origen);

            IF v_tip_canje = 'A' and V_ACT_ENV_CLIENTE = 'S' THEN
                --envia notificacion al contacto
                v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_contacto, v_mensaje, v_origen);
            END IF;

            IF V_ACT_ENV_INTERASISTENCIA = 'S' THEN
                --envia notificacion a interasistencia
                v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_interasistencia, v_mensaje, v_origen);
            END IF;

           --envia notificacion a departamento de tarjetas
            v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_tarjetas, v_mensaje, v_origen);
         ELSIF p_cat_producto IN (VIAJES, VIAJES_GEN) THEN

             IF V_ACT_DEB_PUN_MIC_VIAJES = 'S' THEN
                    -- envia notificacion al proveedor del producto o servicio canjeado
                    v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_des_notificacion, v_mensaje, v_origen);
             END IF;

            IF v_tip_canje = 'A' and V_ACT_ENV_CLIENTE = 'S' THEN
                --envia notificacion al contacto
                v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_contacto, v_mensaje, v_origen);
            END IF;

            IF V_ACT_ENV_INTERASISTENCIA = 'S' THEN
                --envia notificacion a interasistencia
                v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_interasistencia, v_mensaje, v_origen);
            END IF;

            --envia notificacion a departamento de tarjetas
            v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_tarjetas, v_mensaje, v_origen);
         ELSE

            IF v_tip_canje = 'A' and V_ACT_ENV_CLIENTE = 'S' THEN
                --envia notificacion al contacto
                v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_contacto, v_mensaje, v_origen);
            END IF;

            IF V_ACT_ENV_INTERASISTENCIA = 'S' THEN
                --envia notificacion a interasistencia
                v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_interasistencia, v_mensaje, v_origen);
            END IF;

           --envia notificacion a departamento de tarjetas
            v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_tarjetas, v_mensaje, v_origen);
         END IF;
      END IF;

      IF p_est_canje IN ('X, E') THEN
         BEGIN
            SELECT VAL_MINIMO
              INTO v_ema_not_est_canje
              FROM BA_COD_REFERENCIAS
               WHERE DOMINIO = 'CAN_PUN_EMA_NOT_ESTADO';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_ema_not_est_canje  :=  v_ema_not_contacto;
         END;
         v_notificacion_estado := paw_not.fu_env_email_prueba(v_ema_not_est_canje, v_men_not_estado, v_origen);
      END IF;

      paw_uti.pr_mensajeUsuario(PAW_UTI. MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, null, v_notificacion_estado || '-'|| paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(v_cod_persona, v_cod_canal, p_cod_sesion_aux, v_cod_operacion, null, 'ORA-ERR:[' || SQLERRM || '] '||paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_SALIDA);
         RETURN v_retorno;
   END fu_ns_ins_can_puntos;

  FUNCTION fu_ns_obt_can_puntos(p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE,
                              p_cod_sesion_aux    IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN TYP_CANJE IS
      v_cod_persona    BW_AUT_SESIONES.COD_PERSONA%TYPE;
      v_cod_canal     BW_AUT_SESIONES.COD_CANAL%TYPE;
      v_cod_operacion VARCHAR2(3) := '230';
      v_retorno       typ_canje := typ_canje();
   BEGIN

      --por defecto colocamos en retorno en OK
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      v_cod_persona := p_cod_persona;
      v_cod_canal   := paw_uti.depurarNumerico(p_cod_canal, 3);

      PAW_UTI.pr_insertarBitacora(v_cod_persona,
                                  v_cod_canal,
                                  p_cod_sesion_aux,
                                  v_cod_operacion,
                                  NULL,
                                  'fu_ns_obt_can_puntos: [p_cod_persona=' || v_cod_persona || '],[p_nro_canje=' || p_nro_canje || ']',
                                  BITACORA_ENTRADA);

      BEGIN
         SELECT NRO_CANJE, CAT_PRODUCTO, NOM_PRODUCTO, DES_PRODUCTO, TEL_CONTACTO, EMA_CONTACTO, FEC_INSERCION, CANTIDAD,
                PUNTOS, TEL_PROVEEDOR, SHOWROOM, DIRECCION, REC_AUTORIZADA, PER_AUTORIZADA, COD_TIP_AUTORIZADO, NRO_DOC_AUTORIZADO,
                HOR_INICIO, HOR_FIN, BEN_TITULAR, BENEFICIARIO, TURNO, SOL_IDA, FEC_SALIDA, FEC_RETORNO, FEC_FLEXIBLE, CLA_SERVICIO,
                CAN_NINOS, CAN_ADULTOS, LIN_AEREA, NRO_DOC_BENEFICIARIO, FEC_ENTRADA, COD_VERIFICADOR, COMERCIO
           INTO v_retorno.nro_canje, v_retorno.cat_producto, v_retorno.nom_producto, v_retorno.des_producto, v_retorno.tel_contacto,
                v_retorno.ema_contacto, v_retorno.fec_insercion, v_retorno.cantidad, v_retorno.puntos, v_retorno.tel_proveedor,
                v_retorno.showroom, v_retorno.direccion, v_retorno.rec_autorizada, v_retorno.per_autorizada, v_retorno.cod_tip_autorizado,
                v_retorno.nro_doc_autorizado, v_retorno.hor_inicio, v_retorno.hor_fin, v_retorno.ben_titular, v_retorno.beneficiario,
                v_retorno.turno, v_retorno.sol_ida, v_retorno.fec_salida, v_retorno.fec_retorno, v_retorno.fec_flexible,
                v_retorno.cla_servicio, v_retorno.can_ninos, v_retorno.can_adultos, v_retorno.lin_aerea, v_retorno.nro_doc_beneficiario,
                v_retorno.fec_entrada, v_retorno.cod_verificador, v_retorno.comercio
           FROM BW_CANJES
          WHERE NRO_CANJE = p_nro_canje
                AND COD_PERSONA = v_cod_persona;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            PAW_UTI.pr_insertarBitacora(v_cod_persona,
                                        v_cod_canal,
                                        p_cod_sesion_aux,
                                        v_cod_operacion,
                                        NULL,
                                        'fu_ns_obt_can_puntos: [p_cod_persona=' || v_cod_persona || '] : datos no encontrados',
                                        BITACORA_ERROR);
            RETURN v_retorno;
      END;

      PAW_UTI.pr_insertarBitacora(v_cod_persona,
                                  v_cod_canal,
                                  p_cod_sesion_aux,
                                  v_cod_operacion,
                                  NULL,
                                  'fu_ns_obt_can_puntos: [p_cod_persona=' || v_cod_persona || '] :' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta),
                                  BITACORA_SALIDA);

      RETURN v_retorno;

   END fu_ns_obt_can_puntos;

   FUNCTION fu_ns_obtenerDetalleCuentas(p_cod_persona         IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                        p_cod_empresa         IN BW_AUT_SESIONES.COD_PER_VINCULADA%TYPE,
                                        p_codCanal            IN VARCHAR2,
                                        p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL,
                                        p_cod_sesion_aux      IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_obtenerDetalleCuentas IS

      MSG_OBT_CTADET_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'OBTCTADET_CTAIX';

      v_ver_todas          VARCHAR2(1);
      v_nro_cta_especifica VARCHAR2(16);
      v_can_detalles       NUMBER(3); -- cantidad de cuentas
      v_monto1             NUMBER(18, 2) := 0; -- monto 1
      v_monto2             NUMBER(18, 2) := 0; -- monto 2
      v_monto3             NUMBER(18, 2) := 0; -- monto 3
      v_monto4             VARCHAR2(18); -- monto 4
      v_monto5             NUMBER(18, 2) := 0; -- monto 5
      v_monto6             NUMBER(18, 2) := 0; -- monto 6
      v_val_tasa           NUMBER(10, 4) := NULL;
      --v_NroCuentaEspecifica VARCHAR2(16);
      v_fec_inicio         DATE;
      v_fec_vencimiento    DATE;
      v_dia_mora           NUMBER;
      v_che_devuelto       VARCHAR2(01);
      v_can_cuotas         NUMBER(5);
      v_cta_formateada     VARCHAR2(17);
      v_fec_prox_vcto      DATE := NULL;
      v_afinidad           TA_CTA_TARJETAS.AFINIDAD%TYPE;
      --jalvarenga 23/Abril/2012
      COD_OPERACION  VARCHAR2(3) := '020';
      v_fec_actual   DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
      v_listaCuentas typ_listaDetalleCuenta := typ_listaDetalleCuenta();
      v_retorno      typ_obtenerDetalleCuentas := typ_obtenerDetalleCuentas;
      v_logmessage   VARCHAR(1000);
      v_tip_cierre   TA_CTA_TARJETAS.COD_TIP_CIERRE%TYPE;
      v_error        VARCHAR2(1);
      v_msj_error    VARCHAR2(2000);
      v_imp_extracto ge_clientes.tip_extracto%TYPE;
      v_ext_cliente  ge_clientes.tip_extracto%TYPE;
      v_existe       VARCHAR2(1);
      v_nro_certificado VARCHAR2(300) := '';
      v_mad_aho         ge_par_dinamicos.val_parametro%type :=fug_obt_pardinamico('MAD_AHO_BAN_WEB');

      -- cursor de cuentas del cliente
      CURSOR cuentas(p_nroCuenta IN VARCHAR2) IS
         SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada, paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta, decode(b.relacion, 'C', 'Codeudor', 'G', 'Codeudor', fug_obt_des_modal(a.cod_modulo, a.cod_modalidad)) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo, b.relacion, a.estado
           FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
                AND ((b.relacion IN ('O', 'P', 'Y') AND b.cod_modulo != 6) OR (b.relacion IN ('O', 'C', 'G', 'P') AND b.cod_modulo = 6))
                AND b.cod_persona = nvl(p_cod_empresa, p_cod_persona)
                AND a.cod_modulo = c.cod_modulo
                AND a.cod_modalidad = c.cod_modalidad
                AND a.estado = c.estado
                AND b.cod_modulo != 7
                AND b.cod_modalidad <> 36
				AND nvl(fug_obt_paradicional(a.nro_cuenta, 'CTA_BILLETERA'),'N') = 'N'
				AND nvl(fug_obt_paradicional(a.nro_cuenta, 'IND_NO_MOS_CTA_APP'),'N') = 'N'
        and not(a.estado = 'A' and a.cod_modulo=3 and (instr(v_mad_aho, '#'||a.cod_modalidad||'#' ) > 0) and nvl(a.cod_sub_modalidad, 999)=9) --No mostrar cuentas que se abrieron para simular cuotas de pre aprobados
        and not (a.estado = 'A' and a.cod_modulo=3 and a.cod_modalidad=33)
                AND (c.activo = 'S' OR (a.cod_modulo = 6 AND p_nroCuenta IS NOT NULL) OR (a.cod_modalidad in (37, 38) AND (p_nroCuenta IS NOT NULL OR sysdate - a.fec_cam_estado < nvl(to_number(fug_obt_pardinamico('MAX_DIA_CTA_INACTIVA', a.cod_modulo, a.cod_modalidad)), 0))) ) -- solo cuentas activas, excepto para prestamos y ahorro a plazo en consultas por cuenta especifica
                --BWP-306 glopez se descomenta por que no quieren que se muestre cuentas con estado X
                AND a.estado <> 'X' -- pendiente de verificacion
                AND (p_nroCuenta IS NULL OR b.nro_cuenta = p_nroCuenta) -- solo ve la cuenta recibida o todas
          ORDER BY decode(b.cod_modalidad, 31, 1,decode(b.cod_modulo, 5, 2, decode(b.cod_modalidad, 33, 4, 34, 4, 36, 4, decode(b.cod_modulo, 4, 3, 7))));

   BEGIN
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_retorno.cantCuentas := 0;

      --Logear parámetros
      v_logMessage := substr('fu_ns_obtenerDetalleCuentas(nroCuentaEspecifica=' || p_nroCuentaEspecifica || ')',0,999);
      PAW_UTI.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, v_logMessage, BITACORA_ENTRADA);

      IF (p_nroCuentaEspecifica IS NULL) THEN
         v_ver_todas := 'S';
      ELSE
         v_ver_todas          := 'N';
         v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nroCuentaEspecifica, 16);
      END IF;
      IF length(v_nro_cta_especifica) = 16 THEN
         -- es un tarjeta de credito, busco y reemplazo el dato
         BEGIN
            SELECT a.nro_cuenta
              INTO v_nro_cta_especifica
              FROM ge_cta_clientes a, ta_tarjetas b
             WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
               AND b.nro_cuenta = a.nro_cuenta
               AND a.cod_persona = nvl(p_cod_empresa, p_cod_persona);
         EXCEPTION
            WHEN no_data_found THEN
               SELECT b.nro_cuenta
                 INTO v_nro_cta_especifica
                 FROM ta_tarjetas b
                WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
                  AND vigente = 'S'
                  AND rownum = 1;
         END;
      END IF;
      -- obtenemos el tipo de extracto por cliente
      v_ext_cliente := paw_uti.fu_imp_extracto(nvl(p_cod_empresa, p_cod_persona));

      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;
         FOR ct IN cuentas(v_nro_cta_especifica)
         LOOP
            DECLARE
               detalleCuenta typ_detalleCuenta := typ_detalleCuenta;
            BEGIN

               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF paw_uti.fu_es_juridica(ct.nro_cuenta, p_cod_empresa, p_cod_persona) = 'N' THEN
                 if p_cod_empresa is not null 
                   and nvl(fug_obt_pardinamico('HAB_TAR_GP_BAN_EMP'), 'N') = 'N'  then
                   --UES-458
                   declare
                    v_cod_ent_procesadora  ta_tipos.cod_ent_procesadora%type;
                   begin
                     --buscamos el ente de la procesadora
                     select d.cod_ent_procesadora
                     into v_cod_ent_procesadora
                      from Ta_Cta_Tarjetas c,
                      ta_tipos d
                      where c.cod_modulo = d.cod_modulo
                      and c.cod_modalidad   = d.cod_modalidad
                      and c.afinidad        = d.afinidad
                      and c.sub_afinidad    = d.sub_afinidad
                      and c.nro_cuenta      = ct.nro_cuenta;
                      --verificamos se el ente es igual a GP
                      if nvl(v_cod_ent_procesadora, '0') = fug_obt_pardinamico('COD_ENT_GLOBAL') then
                        continue;
                      end if;
                      
                      exception
                        when others then
                          null;
                   end;
                 end if;
               
               
              
                  IF ct.cod_modulo = 5 THEN
                     --v_cta_formateada := paw_bce.fu_obt_nro_tarjeta(ct.nro_cuenta, p_cod_persona, p_cod_empresa);
                     Begin
                         SELECT t.nro_tarjeta
                          INTO v_cta_formateada
                          FROM ta_tarjetas t,
                               ta_cta_tarjetas ta
                         WHERE t.nro_cuenta  = ct.nro_cuenta
                           AND t.cod_persona = nvl(p_cod_empresa,p_cod_persona) ---UES-458
                           AND vigente       = 'S' -- vigente
                           AND ta.nro_cuenta = t.nro_cuenta
                           AND ta.estado  NOT IN ('X', 'C', 'T', 'P')
                           AND rownum        = 1
                         ORDER BY t.fec_vencimiento DESC;
                     Exception
                        when no_data_found then
                             BEGIN
                               SELECT t.nro_tarjeta
                                  INTO v_cta_formateada
                                  FROM ta_tarjetas t,
                                       ta_cta_tarjetas ta
                                 WHERE t.nro_cuenta  = ct.nro_cuenta
                                   AND t.cod_persona = nvl(p_cod_empresa,p_cod_persona) ---UES-458
                                   AND vigente       = 'N'
                                   AND EXISTS ( select distinct 'S' 
                                                  from ta_tarjetas c,
                                                       ta_cta_tarjetas 
                                                 where c.nro_cuenta = t.nro_cuenta
                                                   and c.vigente = 'S'
                                               )
                                   AND ta.nro_cuenta = t.nro_cuenta
                                   AND ta.estado  NOT IN ('X', 'C', 'T', 'P')
                                   AND ta.cod_modulo    = 5
                                   AND ta.cod_modalidad in (505,506,507)
                                   AND rownum        = 1
                                 ORDER BY t.fec_vencimiento DESC;
                            EXCEPTION 
                              WHEN no_data_found THEN
                                 v_cta_formateada := null;
                              WHEN OTHERS THEN
                                 v_cta_formateada := null;
                            END;
                        when others then
                            v_cta_formateada := null;
                     End;
                     IF  v_cta_formateada IS NOT NULL THEN
                        detalleCuenta.numeroTarjeta := substr(v_cta_formateada, 1, 20);
                     END IF;
                  ELSE
                     v_cta_formateada := ct.cta_formateada;
                  END IF;
                  -- Si Cuenta tarjeta debe de tener activa un plastico para incluir en el listado
                  IF ( ( ct.cod_modulo = 5 and v_cta_formateada IS NOT NULL ) OR
                       ct.cod_modulo <> 5 )THEN

                    v_can_detalles := v_can_detalles + 1;
                    detalleCuenta.nroCuenta   := substr(ct.cta_formateada, 0, 17);
                    detalleCuenta.tipoCuenta     := TRIM(substr(ct.cod_tip_cuenta, 0, 2));
                    detalleCuenta.descTipoCuenta := substr(ct.des_tip_cuenta, 0, 35);
                    detalleCuenta.denominacion   := substr(ct.nom_cuenta, 0, 50);
                    detalleCuenta.codMoneda      := substr(ct.cod_moneda, 0, 3);
                    detalleCuenta.relacion       := ct.relacion;
                    v_monto1                     := 0; -- monto 1
                    v_monto2                     := 0; -- monto 2
                    v_monto3                     := 0; -- monto 3
                    v_monto4                     := 0; -- monto 4
                    v_monto5                     := 0; -- monto 5
                    v_monto6                     := 0; -- monto 6
                    v_val_tasa                   := NULL;
                    v_fec_inicio                 := NULL;
                    v_fec_vencimiento            := NULL;
                    v_fec_prox_vcto              := NULL;
                    v_dia_mora                   := 0;
                    v_che_devuelto               := 'N';
                    v_can_cuotas                 := 0;
                    v_imp_extracto               := v_ext_cliente;
                    v_nro_certificado            := '';
                    detalleCuenta.alias          := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                  END IF;
                  -- busco los demas datos de las cuentas
                  BEGIN
                     IF ct.cod_modulo = 6 THEN
                        -- prestamos
                        /*BWP-806 - glopez*/
                        SELECT /*monto*/nvl(mto_capital, 0) + nvl(dev_acumulado, 0) - nvl(sal_capital, 0) - nvl(dev_no_cobrado, 0)- nvl(dev_suspenso, 0),
                        nvl(sal_capital, 0)+ nvl(sal_int_adelantado, 0) + nvl(sal_interes, 0),
                           nvl(sal_int_adelantado, 0) + nvl(sal_interes, 0), 0, val_tasa, fec_inicio, fec_vencimiento,
                               /* dia mora 0 a pedido de bbva */ 0 dia_atraso, 'N', can_cuotas
                          INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_can_cuotas
                          FROM pr_cta_prestamos
                         WHERE nro_cuenta = ct.nro_cuenta;
                        --Datos de la siguiente cuota BBVAHB-750
                        BEGIN
                           SELECT nro_cuota, fec_vencimiento
                             INTO v_monto4, v_fec_prox_vcto
                             FROM pr_cuotas p
                            WHERE p.nro_cuenta = ct.nro_cuenta
                              AND p.estado NOT IN ('N')
                              AND p.nro_cuota > 0
                              AND rownum = 1
                            ORDER BY p.nro_cuenta ASC;
                           -- calculamos el saldo interes a la fecha, no el total
                           SELECT nvl(SUM(pc.sal_interes + pc.dev_acumulado), 0)
                             INTO v_monto3
                             FROM pr_cuotas pc
                            WHERE pc.nro_cuenta = ct.nro_cuenta
                              AND pc.estado <> 'N'
                              AND pc.nro_cuota > 0
                              AND pc.fec_vencimiento <= v_fec_actual + 25;

                           -- para descuentos, agregamos el interes a devengar
                           IF nvl(fup_obt_tip_descuento(ct.cod_modalidad),'x') IN ('F','D','C') THEN
                              BEGIN
                                IF ct.cod_modalidad = 608 THEN
                                 -- Si es descuento de cheque, se retorna sal_int_adelantado para obtener la deuda total. DDSI-1867
                                 SELECT nvl(sal_int_adelantado, 0)
                                  INTO v_monto3
                                   FROM pr_cta_prestamos p
                                  WHERE p.nro_cuenta = ct.nro_cuenta;
                                ELSE
                                  SELECT v_monto3 + trunc(p.val_int_devengar, 2)
                                   INTO v_monto3
                                   FROM pr_cta_prestamos p
                                  WHERE p.nro_cuenta = ct.nro_cuenta;
                                END IF;
                              EXCEPTION
                                 WHEN OTHERS THEN
                                    NULL;
                              END;
                           END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                              v_monto4 := -1;
                        END;
                        v_monto4 := v_monto4 || '/' || v_can_cuotas;
                        --Datos de la siguiente cuota BBVAHB-750
                     ELSIF ct.cod_modulo = 5 THEN
                         IF v_cta_formateada IS NOT NULL THEN -- y existe un plastico activo asociado
                             -- tarjetas
                             SELECT nvl(lin_credito, 0) - (nvl(sal_facturar, 0) + nvl(sal_facturado, 0) + nvl(sal_financiado, 0) + nvl(sal_cuo_pendientes, 0)),
                                    (nvl(sal_facturar, 0) + nvl(sal_facturado, 0) + nvl(sal_financiado, 0) + nvl(sal_cuo_pendientes, 0)),
                                    -- OMM 12/11/2010 Analisis Funcional y AP Nro.: 1037.1
                                    --nvl(sal_pag_minimo,0),
                                    decode(nvl(sal_pag_minimo, 0), 0, nvl(mto_mora, 0), nvl(sal_pag_minimo, 0)), nvl(lin_credito, 0), tas_financiacion,
                                    fec_ult_cierre, fec_vct_ult_cierre, dia_mora, 'N', lin_cuotas, cod_tip_cierre, denominacion
                               INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_monto5,
                                    v_tip_cierre, detalleCuenta.denominacion
                               FROM ta_cta_tarjetas
                              WHERE nro_cuenta = ct.nro_cuenta;

                             -- indicamos si la tarjeta imprime extracto
                             SELECT decode(pat_imp.fu_ret_extracto(ct.nro_cuenta), 'S', 'N' -- si retiene extracto, no imprime
                                                                                 , 'S')
                               INTO v_imp_extracto
                               FROM DUAL;

                             -- gourmets no imprimen extractos
                             /*IF paw_not.lf_es_gourmet(ct.cod_modalidad) = 'S' THEN
                                v_imp_extracto := 'N';
                             END IF;*/
                             -- es prepaga mastecard
                             detalleCuenta.extraData := '{"prepaga": "'||paw_uti.fu_es_prepaga(ct.cod_modalidad)  ||'"}';

                             SELECT MIN(fec_cierre)
                               INTO v_fec_prox_vcto
                               FROM ta_cal_cierres v
                              WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                                AND v.cod_modulo = ct.cod_modulo
                                AND v.cod_modalidad = ct.cod_modalidad
                                AND v.cod_tip_cierre = v_tip_cierre
                                AND fec_cierre > v_fec_inicio;

                             -- si ya pago se busca el siguiente cierre, o ya hay nuevo cierre
                             IF v_monto3 = 0 THEN
                                SELECT MIN(fec_cierre), MIN(fec_vencimiento)
                                  INTO v_fec_prox_vcto, v_fec_vencimiento
                                  FROM ta_cal_cierres v
                                 WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                                   AND v.cod_modulo = ct.cod_modulo
                                   AND v.cod_modalidad = ct.cod_modalidad
                                   AND v.cod_tip_cierre = v_tip_cierre
                                   AND fec_cierre > v_fec_inicio;
                             END IF;

                             -- Si no existe para esa modalidad busco el vcto general
                             IF v_fec_prox_vcto IS NULL THEN
                                SELECT MIN(fec_cierre), MIN(fec_vencimiento)
                                  INTO v_fec_prox_vcto, v_fec_vencimiento
                                  FROM ta_cal_cierres v
                                 WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                                   AND v.cod_modulo = ct.cod_modulo
                                   AND v.cod_modalidad IS NULL
                                      --AND v.cod_tip_cierre = v_tip_cierre
                                   AND fec_cierre > v_fec_inicio;
                             END IF;
                             -- Si no existe (puede ser que no se cargo) despliego el ultimo cierre
                             IF v_fec_prox_vcto IS NULL THEN
                                v_fec_prox_vcto := v_fec_inicio;
                             END IF;

                             v_fec_inicio := v_fec_prox_vcto;

                            /* BEGIN
                                --descripcion de la afinidad
                                SELECT DISTINCT p.Descripcion,
                                  substr(FUE_OBT_SIG_REFCODES('AFINIDAD', ct.afinidad), 0, 35)
                                  INTO detalleCuenta.dato1, detalleCuenta.descTipoCuenta
                                  FROM TA_TARJETAS t, TA_CTA_TARJETAS ct, TA_TIPOS p
                                 where p.cod_modulo = ct.cod_modulo
                                   and p.cod_modalidad = ct.cod_modalidad
                                   and p.afinidad = ct.afinidad
                                   and CT.NRO_CUENTA = T.NRO_CUENTA
                                   and T.NRO_TARJETA = detalleCuenta.numeroTarjeta;
                              EXCEPTION
                                when others then
                                  detalleCuenta.dato1 := 'Afinidad no definida';
                                  detalleCuenta.descTipoCuenta := 'Afinidad no definida';
                              END;*/

                             -- si genera puntos la tarjeta dato2 = S, en caso contrario N
                             detalleCuenta.dato2 := 'N';
                             SELECT afinidad
                               INTO v_afinidad
                               FROM ta_cta_tarjetas
                              WHERE nro_cuenta = ct.nro_cuenta;
                              IF (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                                 detalleCuenta.dato2 := 'BPO';
                              ELSIF (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS_EXP', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                                 detalleCuenta.dato1 := CONCAT(detalleCuenta.dato1,' EXPERIENCE');
                                 detalleCuenta.dato2 := 'EXPERIENCE';
                              ELSIF (instr(fug_obt_pardinamico('AFI_SHO_DEL_SOL', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                                 -- VALIDACION SI LA TARJETA GENERA SOLES
                                 detalleCuenta.dato2 := 'SOLES';
                              END IF;
                           END IF;
                     ELSIF instr(v_mad_aho, '#'||ct.cod_modalidad||'#' ) > 0 THEN
                        -- ahorro vista
                        pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                        -- control de error en saldos
                        IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
                           prg_obt_sal_atm_cierre(ct.nro_cuenta,
                                                  pag_cta.g_ctas.sal_disponible,
                                                  pag_cta.g_ctas.sal_actual,
                                                  pag_cta.g_ctas.sal_retenido,
                                                  pag_cta.g_ctas.sal_bloqueado,
                                                  v_error,
                                                  v_msj_error);
                        END IF;
                        --
                        v_monto1          := pag_cta.g_ctas.sal_actual;
                        v_monto2          := pag_cta.g_ctas.sal_disponible;
                        v_monto3          := pag_cta.g_ctas.sal_retenido + pag_cta.g_ctas.mto_cre_a_confirmar;
                        v_monto4          := 0;
                        v_val_tasa        := pag_cta.g_ctas.val_tasa;
                        v_fec_inicio      := pag_cta.g_ctas.fec_apertura;
                        v_fec_vencimiento := pag_cta.g_ctas.fec_vencimiento;
                        v_dia_mora        := 0;
                        v_che_devuelto    := 'N';
                     ELSIF ct.cod_modalidad IN (33, 34, 35, 36, 37) THEN
                        -- cda
                        SELECT capital, nvl(int_pendiente, 0) int_pendiente, nvl(sal_retenido, 0), 0, fug_obt_val_tasa(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda, capital, tas_personalizada, cod_tasa, NULL, v_fec_actual) val_tasa, fec_apertura, fec_vencimiento, 0, 'N', nro_certificado
                          INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, detalleCuenta.dato1
                          FROM ah_cta_certificados,
                   (SELECT nro_cuenta cuenta, SUM(mto_interes) int_pendiente
                                   FROM ah_cupones
                                  WHERE estado IN ('V', 'E')
                                  GROUP BY nro_cuenta) b
                         WHERE nro_cuenta = ct.nro_cuenta
                           AND b.cuenta(+) = nro_cuenta
                       UNION ALL
                       --apfd
                        SELECT capital, nvl(int_pendiente, 0) int_pendiente, nvl(sal_retenido, 0), 0, 0, fec_apertura, fec_vencimiento, 0, 'N', 0 as nro_certificado
                          --INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_nro_certificado
                          FROM ah_cta_plazos,
                               (SELECT nro_cuenta cuenta, SUM(mto_interes) int_pendiente
                                   FROM ah_cupones
                                  WHERE estado IN ('V', 'E')
                                  GROUP BY nro_cuenta) b
                         WHERE nro_cuenta = ct.nro_cuenta
                           AND b.cuenta(+) = nro_cuenta;
                     ELSIF ct.cod_modalidad = 38 THEN
                        -- ahorro programado
                        SELECT a.capital, nvl(a.sal_total, 0), nvl(b.int_pendiente, 0) int_pendiente,
                               nvl(a.sal_retenido, 0) + nvl(a.sal_bloqueado, 0), a.val_tasa, fec_apertura,
                               fec_vencimiento, 0, 'N', substr(fue_obt_sig_refcodes('FEC_DEB_AHO_PROGRAMADO', a.per_debito), 1, 300)
                          INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento,
                               v_dia_mora, v_che_devuelto, detalleCuenta.dato2
                          FROM ah_cta_plazos a, (SELECT nro_cuenta cuenta, SUM(mto_interes) int_pendiente
                                                 FROM ah_pro_cuotas
                                                WHERE estado IN ('V', 'E', 'A')
                                                GROUP BY nro_cuenta) b
                         WHERE a.nro_cuenta = ct.nro_cuenta
                           AND b.cuenta(+) = a.nro_cuenta;
                         detalleCuenta.dato1 := substr(TRIM(fug_obt_paradicional(ct.nro_cuenta, 'HAB_REFUERZO')), 1, 300);
                     ELSIF ct.cod_modalidad = 41 THEN
                        -- cuenta corriente
                        BEGIN
                           SELECT can_dias
                             INTO v_dia_mora
                             FROM cc_sobregiros_res
                            WHERE nro_cuenta = ct.nro_cuenta;
                        EXCEPTION
                           WHEN OTHERS THEN
                              v_dia_mora := 0;
                        END;
                        pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                        -- control de error en saldos
                        IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
                           prg_obt_sal_atm_cierre(ct.nro_cuenta,
                                                  pag_cta.g_ctas.sal_disponible,
                                                  pag_cta.g_ctas.sal_actual,
                                                  pag_cta.g_ctas.sal_retenido,
                                                  pag_cta.g_ctas.sal_bloqueado,
                                                  v_error,
                                                  v_msj_error);
                        END IF;
                        --
                        v_monto1          := pag_cta.g_ctas.sal_actual;
                        v_monto2          := pag_cta.g_ctas.sal_disponible;
                        v_monto3          := pag_cta.g_ctas.sal_retenido + pag_cta.g_ctas.mto_cre_a_confirmar;
                        v_monto4          := paw_uti.lf_for_money(pag_cta.FU_OBT_LIN_SOBREGIRO(ct.nro_cuenta, v_fec_actual));
                        v_val_tasa        := pag_cta.g_ctas.val_tasa;
                        v_fec_inicio      := pag_cta.g_ctas.fec_apertura;
                        v_fec_vencimiento := pag_cta.g_ctas.fec_vencimiento;
                        v_che_devuelto    := 'N';
                     END IF;
                     IF (ct.cod_modulo = 4 AND ct.cod_modalidad = 41) OR (ct.cod_modulo = 3 AND ct.cod_modalidad = 31) THEN
                        BEGIN
                           SELECT nro_celular, estado
                           INTO detalleCuenta.dato1, detalleCuenta.dato2
                           FROM bw_cta_telefonos
                           WHERE nro_cuenta = ct.nro_cuenta
                           AND estado <> 'I';
                        EXCEPTION
                           WHEN OTHERS THEN
                              detalleCuenta.dato1 := NULL;
                              detalleCuenta.dato2 := NULL;
                        END;
                        --verificar que el celular configurado pertenezca a la persona
                        IF detalleCuenta.dato1 IS NOT NULL THEN
                          BEGIN
                            SELECT 'S'
                            INTO v_existe
                            FROM ba_telefonos
                            WHERE cod_persona = p_cod_persona
                            AND AREA||TELEFONO = detalleCuenta.dato1
                            --agregamos el tipo de línea para especificar mas.
                            AND TIP_LINEA = 'C'
                            AND ROWNUM = 1;
                          EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                              detalleCuenta.dato1 := NULL;
                              detalleCuenta.dato2 := 'X'; --estado para configuraciones
                            WHEN OTHERS THEN
                              detalleCuenta.dato1 := NULL;
                              detalleCuenta.dato2 := NULL;
                          END;
                        END IF;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        --p_cod_respuesta := paw_bce.v_cod_cta_inexistente;
                        paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                        paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'cta: '|| ct.nro_cuenta ||', mad:' || ct.cod_modalidad || ', ORA-ERR: ' || SQLERRM || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL) || SQLERRM, BITACORA_ERROR);
                  END;
                  IF v_retorno.error = 'N' AND detalleCuenta.tipoCuenta IS NOT NULL THEN
                     IF ct.cod_modulo = 5 THEN
                        --13/08/2015. Para Tarjetas de Crédito, se consulta si es de la Afinidad Gourmet
                        --Resolución de la incidencia DYDMR-2239
                        v_che_devuelto:=PAW_not.lf_es_gourmet(ct.cod_modalidad);
                     ELSE
                        v_che_devuelto := paw_uti.lf_obt_che_devuelto(ct.nro_cuenta);
                     END IF;

                     -- esta bien el dato se carga el detalle
                     detalleCuenta.monto1                  := substr(paw_uti.lf_for_money(v_monto1), 1, 16);
                     detalleCuenta.monto2                  := substr(paw_uti.lf_for_money(v_monto2), 1, 16);
                     detalleCuenta.monto3                  := substr(paw_uti.lf_for_money(v_monto3), 1, 16);
                     detalleCuenta.monto4                  := substr(v_monto4, 1, 16);
                     detalleCuenta.tasa                    := v_val_tasa;
                     detalleCuenta.fechaInicio             := paw_uti.lf_for_date(v_fec_inicio);
                     detalleCuenta.fechaVencimiento        := paw_uti.lf_for_date(v_fec_vencimiento);
                     detalleCuenta.diasMora                := v_dia_mora;
                     detalleCuenta.chequeDevuelto          := substr(v_che_devuelto, 0, 1);
                     detalleCuenta.fechaProximoVencimiento := paw_uti.lf_for_date(v_fec_prox_vcto);
                     detalleCuenta.imprimeExtracto         := v_imp_extracto;
                     v_listaCuentas.EXTEND;
                     v_listaCuentas(v_listaCuentas.COUNT) := detalleCuenta;
                  END IF;
               END IF;
               IF v_can_detalles >= 999 THEN
                  EXIT; --XXX
               END IF;
            END;
         END LOOP;
         IF v_can_detalles = 0 THEN
            -- no tiene detalles
            -- p_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
            paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas - Cuenta Inexistente -' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null) ||sqlerrm, BITACORA_ERROR);
         END IF;
      END IF;

      -- registro del movimiento
      paw_uti.lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/, NULL /*p_cod_moneda */, NULL /*p_monto*/, NULL /*p_nro_cta_contra*/, NULL /*p_cantidad*/, 'Ver Todas' /*p_etiqueta*/, v_ver_todas, /*p_dato*/ NULL, NULL, NULL, NULL, NULL, p_cod_persona, COD_OPERACION, p_cod_persona || p_codCanal, p_codCanal, p_cod_sesion_aux, p_cod_empresa);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas-' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_SALIDA);
      IF v_retorno.error = 'N' THEN
         -- todo ok, se arma el mensaje de respuesta
         v_retorno.listaCuentas := v_listaCuentas;
         v_retorno.cantCuentas  := v_listaCuentas.Count;
         RETURN v_retorno;
      ELSE
         RETURN v_retorno;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas -' || SQLERRM, BITACORA_ERROR);
         RETURN v_retorno;
   END fu_ns_obtenerDetalleCuentas;

   FUNCTION fu_ver_can_puntos(p_api_key         IN ge_par_dinamicos.val_parametro%TYPE,
                             p_cod_canal       IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                             p_nro_canje       IN BW_CANJES.NRO_CANJE%TYPE,
                             p_cod_verificador IN BW_CANJES.COD_VERIFICADOR%TYPE) RETURN TYP_CANJE IS

    -- variables para bitácora
    v_log_datos        BW_BITACORAS.DATO%TYPE;
    v_log_detalle      VARCHAR(100);
    -- cód. de persona fijo, utiliza del banco
    v_cod_persona      CONSTANT VARCHAR2(10) := '11198';
    v_cod_sesion       BW_AUT_SESIONES.COD_SESION%TYPE := '';
    -- variables para parémetros de entrada depurados
    v_cod_canal        BW_AUT_SESIONES.COD_CANAL%TYPE;
    v_nro_canje        BW_CANJES.NRO_CANJE%TYPE;
    v_cod_verificador  BW_CANJES.COD_VERIFICADOR%TYPE;
    -- código para mensaje 'VERIFICA CANJE DE PUNTOS'
    v_cod_operacion    VARCHAR2(3) := '236';
    -- msj error: apikey inválido
    CAN_API_KEY_INV    CONSTANT VARCHAR2(15) := 'CAN_API_KEY_INV';
    -- msj error: el canje ya fue verificado anteriormente
    CAN_YA_VERIF       CONSTANT VARCHAR2(15) := 'CAN_YA_VERIF';
    -- msj error: el canje no existe
    CAN_NO_EXISTE      CONSTANT VARCHAR2(15) := 'CAN_NO_EXISTE';
    -- msj exito: el canje fue verificado exitosamente
    CAN_OK_VERIF       CONSTANT VARCHAR2(15) := 'CAN_OK_VERIF';
    -- record de uso local solamente. Se utiliza para contener datos luego del UPDATE
    TYPE rec_verificacion IS RECORD(
      nro_canje        BW_CANJES.NRO_CANJE%TYPE,
      cod_verificador  BW_CANJES.COD_VERIFICADOR%TYPE,
      fec_verificacion BW_CANJES.FEC_VERIFICACION%TYPE,
      verificado       BW_CANJES.VERIFICADO%TYPE);
    verificacion_info  rec_verificacion;
    -- excepcion para api key inválido
    EX_INVALID_API_KEY EXCEPTION;
    v_retorno          typ_canje := typ_canje();

  BEGIN
    -- depurar parámetros de entrada
    v_cod_canal        := PAW_UTI.depurarNumerico(p_cod_canal, 3);
    v_nro_canje        := PAW_UTI.depurarNumerico(p_nro_canje, 12);
    v_cod_verificador  := PAW_UTI.depurarAlfanumerico(p_cod_verificador, 10);

    -- prerar cadena para bitácora: datos del canje a marcar
    v_log_detalle := ' p_nro_canje: ' || p_nro_canje || ', p_cod_verificador: ' || p_cod_verificador || '.';

    -- validar acceso a esta función según parámetro p_api_key
    IF fu_val_api(p_api_key) = 'N' THEN
      RAISE EX_INVALID_API_KEY;
    END IF;

    -- preparar cadena para bitácora
    v_log_datos := 'fu_ver_can_puntos: inicio de función. ' || v_log_detalle;

    PAW_UTI.pr_insertarBitacora(v_cod_persona, v_cod_canal, v_cod_sesion, v_cod_operacion, NULL, v_log_datos, PAW_UTI.BITACORA_ENTRADA);

    -- Obtener registro del canje que se desea verificar, para validaciones previas.
    SELECT nro_canje, cod_verificador, verificado, fec_verificacion
    INTO v_retorno.nro_canje, v_retorno.cod_verificador, v_retorno.verificado, v_retorno.fec_verificacion
    FROM BW_CANJES
    WHERE NRO_CANJE = v_nro_canje
    AND COD_VERIFICADOR = v_cod_verificador;

    -- validación: un canje ya verificado no debe volver a verificarse
    IF v_retorno.verificado = 'S' THEN
      -- El canje ya fue verificado.
      PAW_UTI.pr_mensajeUsuario(CAN_YA_VERIF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      v_log_datos := 'fu_ver_can_puntos: Canje ya fue verificado.' || v_log_detalle;

      PAW_UTI.pr_insertarBitacora(v_cod_persona, v_cod_canal, v_cod_sesion, v_cod_operacion, NULL, v_log_datos, PAW_UTI.BITACORA_ERROR);
      RETURN v_retorno;

    END IF;

    /**
    * Ejecutar el update, según la combinación de nro_canje y cod_verificador.
    * Por retrocompatibilidad, debe considerarse que los registros insertados
    * antes de la implementación de esta función tienen NULL en columna 'verificado'.
    * En el RETURNING debe respetarse el ORDEN de las columnas. Deben ser iguales
    * al orden definido en el tipo RECORD rec_verificacion.
    */
    UPDATE BW_CANJES CAN
    SET CAN.VERIFICADO = 'S', CAN.FEC_VERIFICACION = SYSDATE
    WHERE CAN.NRO_CANJE = v_nro_canje
    AND CAN.COD_VERIFICADOR = v_cod_verificador
    AND (CAN.VERIFICADO IS NULL OR CAN.VERIFICADO = 'N')

    RETURNING CAN.NRO_CANJE, CAN.COD_VERIFICADOR, CAN.FEC_VERIFICACION, CAN.VERIFICADO INTO verificacion_info;

    COMMIT;

    v_retorno.NRO_CANJE        := verificacion_info.NRO_CANJE;
    v_retorno.COD_VERIFICADOR  := verificacion_info.COD_VERIFICADOR;
    v_retorno.FEC_VERIFICACION := verificacion_info.FEC_VERIFICACION;
    v_retorno.VERIFICADO       := verificacion_info.VERIFICADO;

    PAW_UTI.pr_mensajeUsuario(CAN_OK_VERIF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

    v_log_datos := 'fu_ver_can_puntos: canje marcado exitosamente. ' || v_log_detalle;
    PAW_UTI.pr_insertarBitacora(v_cod_persona, v_cod_canal, v_cod_sesion, v_cod_operacion, NULL, v_log_datos, PAW_UTI.BITACORA_ENTRADA);

    RETURN v_retorno;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- se solicitó verificar canje inexistente, según la combinación nro. de canje y cod. verificador.
      PAW_UTI.pr_mensajeUsuario(CAN_NO_EXISTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      v_log_datos := 'fu_ver_can_puntos: [select: bw_canjes, ORA-ERR: ' || SUBSTR(SQLERRM, 1, 200) || '] ' || v_log_detalle;
      PAW_UTI.pr_insertarBitacora(v_cod_persona, v_cod_canal, v_cod_sesion, v_cod_operacion, NULL, v_log_datos, PAW_UTI.BITACORA_ERROR);
      RETURN v_retorno;

    WHEN EX_INVALID_API_KEY THEN
      -- cadena inválida para el api key
      PAW_UTI.pr_mensajeUsuario(CAN_API_KEY_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_log_datos := 'fu_ver_can_puntos: API KEY inválido: ' || p_api_key || ', ' || v_log_detalle;

      PAW_UTI.pr_insertarBitacora(v_cod_persona, v_cod_canal, v_cod_sesion, v_cod_operacion, NULL, v_log_datos, PAW_UTI.BITACORA_ERROR);
      RETURN v_retorno;

    WHEN OTHERS THEN
      -- excepciones inesperadas.
      PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      PAW_UTI.pr_insertarBitacora(v_cod_persona, v_cod_canal, v_cod_sesion, v_cod_operacion, NULL, 'ORA-ERR:[' || SQLERRM || '] ' ||
                                   PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), PAW_UTI.BITACORA_ERROR);
      RETURN v_retorno;
  END fu_ver_can_puntos;

  FUNCTION fu_ns_obt_can_entradas( p_cod_persona IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE,
                              p_cod_sesion_aux    IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_canjeentradas IS
      v_cod_persona   BW_AUT_SESIONES.COD_PERSONA%TYPE;
      v_cod_canal     BW_AUT_SESIONES.COD_CANAL%TYPE;
      v_cod_operacion VARCHAR2(3) := '230';
      v_cant          BW_CANJES.CANTIDAD%TYPE;
      v_can_entrada   NUMBER := 0;
      v_can           NUMBER := 0;
      v_cod_producto  BW_CANJES.COD_PRODUCTO%TYPE;
      v_retorno       typ_canjeentradas := typ_canjeentradas();
      v_lista         typ_listaentradas := typ_listaentradas();
      v_detalle       typ_detalleentradas :=  typ_detalleentradas();

   CURSOR c_ent_nueva IS
        SELECT B.COD_ENTRADA
        FROM   BW_CAN_ENTRADAS b
        WHERE B.ESTADO = 'N'
        AND B.COD_TIP_ENTRADA = v_cod_producto
        AND ROWNUM = 1;

   CURSOR c_ent_cajeada is
       SELECT W.COD_ENTRADA
        FROM   BW_CAN_ENTRADAS W
        WHERE W.ESTADO = 'L'
        AND  W.NRO_CANJE = p_nro_canje
        AND W.COD_TIP_ENTRADA = v_cod_producto;

   BEGIN

      --por defecto colocamos en retorno en OK
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      v_cod_persona := p_cod_persona;
      v_cod_canal   := paw_uti.depurarNumerico(p_cod_canal, 3);

      PAW_UTI.pr_insertarBitacora(v_cod_persona,
                                  v_cod_canal,
                                  p_cod_sesion_aux,
                                  v_cod_operacion,
                                  NULL,
                                  'fu_obt_can_entradas: [p_cod_persona=' || v_cod_persona || '],[p_nro_canje=' || p_nro_canje || ']',
                                  BITACORA_ENTRADA);

      BEGIN
       SELECT CANTIDAD, COD_PRODUCTO
         INTO v_cant, v_cod_producto
         FROM BW_CANJES
        WHERE NRO_CANJE = p_nro_canje
          AND COD_PERSONA = v_cod_persona;
      EXCEPTION
       WHEN NO_DATA_FOUND THEN
        PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        PAW_UTI.pr_insertarBitacora(v_cod_persona,
                      v_cod_canal,
                      p_cod_sesion_aux,
                      v_cod_operacion,
                      NULL,
                      'fu_obt_can_entradas: [p_cod_persona=' || v_cod_persona || '] : datos de canje no encontrados',
                      BITACORA_ERROR);
        RETURN v_retorno;
      END;

     --verificamos si se asignaron entradas al canje
       FOR reg IN c_ent_cajeada LOOP
         v_detalle.cod_entrada := reg.cod_entrada;
         v_can := v_can + 1;
         v_lista.extend;
         v_lista(v_lista.count) := v_detalle;
         v_can_entrada  := v_can;
       END LOOP;

   WHILE v_can_entrada < v_cant LOOP
    FOR reg IN c_ent_nueva LOOP
    v_detalle.cod_entrada := reg.cod_entrada;
    Begin
            UPDATE bw_can_entradas
            SET    estado = 'L', nro_canje = p_nro_canje
            WHERE  cod_entrada = reg.cod_entrada
            AND    estado = 'N';
          EXCEPTION
          WHEN OTHERS THEN
            PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            PAW_UTI.pr_insertarBitacora(v_cod_persona,
                          v_cod_canal,
                          p_cod_sesion_aux,
                          v_cod_operacion,
                          NULL,
                          'fu_obt_can_entradas: [p_cod_persona=' || v_cod_persona || '] : Error en actualizar las entradas',
                          BITACORA_ERROR);
              RETURN v_retorno;
          END;
        v_can := v_can + 1;
        v_lista.extend;
        v_lista(v_lista.count) := v_detalle;
        END LOOP;
        v_can_entrada := v_can_entrada + 1;
     END LOOP;

     IF v_can <> v_cant THEN
        PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        PAW_UTI.pr_insertarBitacora(v_cod_persona,
                      v_cod_canal,
                      p_cod_sesion_aux,
                      v_cod_operacion,
                      NULL,
                      'fu_obt_can_entradas: [p_cod_persona=' || v_cod_persona || '] : Cantidad de entradas no disponible en BW_CAN_ENTRADAS ',
                      BITACORA_ERROR);
          RETURN v_retorno;
     END IF;

      v_retorno.listaentradas := v_lista;
      v_retorno.canEntradas   := v_can;
      PAW_UTI.pr_insertarBitacora(v_cod_persona,
                    v_cod_canal,
                    p_cod_sesion_aux,
                    v_cod_operacion,
                    NULL,
                    'fu_obt_can_entradas: [p_cod_persona=' || v_cod_persona || '] :' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta),
                    BITACORA_SALIDA);

    RETURN v_retorno;
     EXCEPTION
      WHEN OTHERS THEN
        PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        PAW_UTI.pr_insertarBitacora(v_cod_persona,
                      v_cod_canal,
                      p_cod_sesion_aux,
                      v_cod_operacion,
                      NULL,
                      'fu_obt_can_entradas: [p_cod_persona=' || v_cod_persona || '] : datos no encontrados',
                      BITACORA_ERROR);
      RETURN v_retorno;
   END fu_ns_obt_can_entradas;

   --
   FUNCTION fu_obtenerSeguros(p_codigoPersona IN VARCHAR2,
                              p_codigoEmpresa IN VARCHAR2,
                              p_codigoCanal   IN VARCHAR2,
                              p_id_session    IN VARCHAR2,
                              p_codigoSeguro  IN VARCHAR2 DEFAULT NULL) RETURN TYP_SEGUROS IS
      v_retorno             typ_seguros := typ_seguros();
      v_seguro              typ_seguropolizas := typ_seguropolizas();
      v_listapolizas        typ_listasegurospolizas := typ_listasegurospolizas();
      v_listacuotas         typ_listaseguroscuotas := typ_listaseguroscuotas();
      v_cancuotasatrasadas  NUMBER(2) := 0;
      v_fec_pro_vencimiento DATE := NULL; --fecha en que vence la sgte factura
      v_cod_operacion       VARCHAR2(3) := '042';--Seguros
      v_contador            VARCHAR2(2) := 0;-- size de listas
      v_cuotas              typ_segurocuotas := typ_segurocuotas();
      v_can_cuotas          NUMBER := 0;
      v_polMadreAccidentes  VARCHAR2(2000) := '';
      v_polMadreVida        VARCHAR2(2000) := '';
      v_msj_bitacora        VARCHAR2(800) := substr('p_codigoPersona' || p_codigoPersona
                                               || ', p_codigoEmpresa' || p_codigoEmpresa
                                              || ', p_codigoCanal:' || p_codigoCanal
                                              || ', p_codigoSeguro:' || nvl(p_codigoSeguro, 'x'), 1, 800);
      CURSOR c_serguros IS
        SELECT s.codigo,s.cod_ente ,s.producto, TRIM(fue_obt_des_refcodes('SEC_SEGURO', s.seccion)) AS seccion,
               s.sub_seccion, s.nro_poliza, e.descripcion AS cia_seguros, s.fec_inicial,
               s.fec_final, s.mto_capital, s.can_cuota, s.cod_moneda, s.tip_movimiento,
               'N' as es_preaprobado, null as beneficiario, -99 as cod_tip_seguro, s.estado as pol_estado
          FROM ge_pol_seguros s
         INNER JOIN ge_entes e ON s.cod_ente = e.cod_ente
         WHERE s.cod_persona = nvl(p_codigoEmpresa, p_codigoPersona)
           AND s.estado = 2 -- 2 estado activo
           ANd s.mto_capital > 0
           AND s.situacion = 1 -- 1 Situacion vigente
           AND (s.codigo = p_codigoSeguro OR p_codigoSeguro IS NULL)
         UNION
        SELECT s2.nro_seguro as codigo,s2.cod_ente as cod_ente ,null as producto, null as seccion, t2.descripcion as sub_seccion,
               decode(s2.cod_tip_seguro, 2,trim(v_polMadreAccidentes),3, trim(v_polMadreVida)) || '/' || to_char(s2.nro_seguro) as nro_poliza,
               e2.descripcion as cia_seguros, s2.fec_inicio as fec_inicial, s2.fec_vencimiento as fec_final,
               s2.mto_capital as mto_capital, 1 as can_cuota, 'GS' as cod_moneda, '1' as tip_movimiento,
               'S' as es_preaprobado, s2.beneficiario, s2.cod_tip_seguro, s2.estado as pol_estado
          FROM ge_cli_seguros s2
         INNER JOIN ge_tip_seguros t2 ON s2.cod_tip_seguro = t2.cod_tipo
         INNER JOIN ge_entes e2 ON e2.cod_ente = t2.cod_ente
           AND s2.estado = 'V'
           AND s2.cod_persona = nvl(p_codigoEmpresa, p_codigoPersona)
           AND (s2.nro_seguro = p_codigoSeguro OR p_codigoSeguro IS NULL);

      CURSOR c_cuotas(p_codigo IN ge_pol_cuotas.codigo%TYPE) IS
        SELECT c.*
          FROM ge_pol_seguros s
         INNER JOIN ge_pol_cuotas c ON c.codigo = s.codigo
         WHERE c.codigo =  p_codigo
           AND s.estado = 2 -- estado activo
           AND s.mto_capital > 0;

      CURSOR c_cuotas_preaprobados(p_codigo IN ge_cuo_seguros.nro_seguro%TYPE) IS
        SELECT sp.nro_seguro as codigo, sp.nro_cuota, sp.fec_vencimiento as fec_vencimiento,
               sp.monto as monto, null as observacion, DECODE(estado,'V','I','C','T','I') as estado,
               usu_insercion, fec_insercion, usu_modificacion, fec_insercion as fec_modificacion
          FROM ge_cuo_seguros sp
         WHERE nro_seguro = p_codigo
           AND sp.estado = 'C';

      /*Retorna 'S' si el tipo de movimiento corresponde a Endoso en la tabla ba_cod_referencias*/
      FUNCTION lf_tiene_endoso(p_cod_tip_movimiento IN VARCHAR2)
        RETURN VARCHAR2 IS
        v_es_endoso NUMBER;
      BEGIN
        select count(*)
          into v_es_endoso
          from ba_cod_referencias
         where dominio = 'TIP_MOV_POLIZA'
           and val_minimo = p_cod_tip_movimiento
           and val_maximo = p_cod_tip_movimiento
           and upper(significado) like '%ENDOSO%';
        IF v_es_endoso >= 1 THEN
          RETURN 'S';
        END IF;
        RETURN 'N';
      EXCEPTION
        WHEN OTHERS THEN
          RETURN 'N';
      END;

   BEGIN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      paw_uti.pr_insertarBitacora(p_codigoPersona, p_codigoCanal, p_id_session, v_cod_operacion, p_codigoEmpresa, v_msj_bitacora ||' '  || paw_bem.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), paw_uti.BITACORA_ENTRADA);

      --Se obtiene el valor de la poliza madre para mostrar en los seguros preaprobados contratados
      v_polMadreAccidentes := fug_obt_pardinamico('SEG_WEB_POL_ACCIDENTES');
      v_polMadreVida := fug_obt_pardinamico('SEG_WEB_POL_VIDA');
      FOR reg IN c_serguros LOOP
        v_seguro.codEnte       := reg.cod_ente;
        v_seguro.codigo        := reg.codigo;
        v_seguro.producto      := reg.producto;
        v_seguro.seccion       := reg.seccion;
        v_seguro.subSeccion    := reg.sub_seccion;
        v_seguro.nroPoliza     := reg.nro_poliza;
        v_seguro.ciaSeguros    := reg.cia_seguros;
        v_seguro.fecInicial    := reg.fec_inicial;
        v_seguro.fecFinal      := reg.fec_final;
        v_seguro.mtoCapital    := reg.mto_capital;
        v_seguro.canCuota      := reg.can_cuota;
        v_seguro.codMoneda     := reg.cod_moneda;
        v_seguro.tipMovimiento := reg.tip_movimiento;
        v_seguro.tieneEndoso   := lf_tiene_endoso(reg.tip_movimiento);
        v_seguro.beneficiario  := reg.beneficiario;
        v_seguro.esPreaprobado := reg.es_preaprobado;
        v_seguro.codTipSeguro  := reg.cod_tip_seguro;
        v_seguro.estado        := reg.pol_estado;

        IF (instr(fug_obt_pardinamico('ASEG_GEN_POLIZA', null, null), reg.cod_ente) = 0) THEN
           v_seguro.generaPolizaWeb := 'N';
        ELSE
           v_seguro.generaPolizaWeb := 'S';
        END IF;

        --Cargamos el detalle solo si llega el codigo del seguro solicitado
        IF p_codigoSeguro is not null THEN
           IF reg.es_preaprobado = 'N' THEN
              FOR cu IN c_cuotas(reg.codigo) LOOP
                 v_cuotas.nroCuota := cu.nro_cuota;
                 v_cuotas.fecVencimiento := cu.fec_vencimiento;
                 v_cuotas.monto := cu.monto;
                 v_cuotas.estado := cu.estado;
                 v_can_cuotas := v_can_cuotas + 1;
                 -- verificar si es cuota atrasada y contar
                 IF trunc(sysdate) >  trunc(v_cuotas.fecVencimiento) AND v_cuotas.estado <> 'T' THEN
                    v_cancuotasatrasadas := v_cancuotasatrasadas + 1 ;
                 END IF;
                 -- verificar el proximo vencimiento
                 IF v_fec_pro_vencimiento IS NULL THEN
                    IF trunc(sysdate) < trunc(v_cuotas.fecVencimiento) AND trunc(v_cuotas.fecVencimiento) < trunc(sysdate + 30) THEN
                       v_fec_pro_vencimiento := v_cuotas.fecVencimiento;
                    else
                       v_fec_pro_vencimiento := null;
                    END IF;
                 END IF;
                 v_listacuotas.extend;
                 v_listacuotas(v_listacuotas.count) := v_cuotas;
              END LOOP;
           ELSE
              -- carga inicial con la fecha actual
              FOR cu IN c_cuotas_preaprobados(reg.codigo) LOOP
                 v_cuotas.nroCuota       := cu.nro_cuota;
                 v_cuotas.fecVencimiento := cu.fec_vencimiento;
                 v_cuotas.monto          := cu.monto;
                 v_cuotas.estado         := cu.estado;
                 v_can_cuotas            := v_can_cuotas + 1;
                 -- verificar el proximo vencimiento
                 IF v_fec_pro_vencimiento IS NULL THEN
                    IF trunc(sysdate) < trunc(v_cuotas.fecVencimiento) AND trunc(v_cuotas.fecVencimiento) < trunc(sysdate + 30) THEN
                       v_fec_pro_vencimiento := v_cuotas.fecVencimiento;
                    ELSE
                       v_fec_pro_vencimiento := NULL;
                    END IF;
                 END IF;
                 v_listacuotas.extend;
                 v_listacuotas(v_listacuotas.count) := v_cuotas;
              END LOOP;
           END IF;
           v_seguro.fecProxVencimiento := v_fec_pro_vencimiento;
           v_seguro.canCuotasAtrasadas := v_cancuotasatrasadas;
           v_seguro.canCuota := v_can_cuotas;
           v_seguro.cantidad := v_listacuotas.count;
           v_seguro.listaCuotas := v_listacuotas;
           --evita null; para el caso mapfre donde no se traen cuotas
           IF v_seguro.listaCuotas.count > 0 THEN
              v_seguro.mtoCuota := v_seguro.listaCuotas(1).monto;
           END IF;
        END IF;
        v_can_cuotas := 0;
        v_listapolizas.extend;
        v_listapolizas(v_listapolizas.count) := v_seguro;
        v_contador := v_contador + 1 ;
      END LOOP;
      v_retorno.listaPolizas := v_listapolizas;
      v_retorno.contPolizas := v_contador;
      v_msj_bitacora := v_msj_bitacora || ', total: ' || v_contador;
      paw_uti.pr_insertarBitacora(p_codigoPersona, p_codigoCanal, p_id_session, v_cod_operacion, p_codigoEmpresa, v_msj_bitacora ||' '|| paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), paw_uti.BITACORA_SALIDA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_codigoPersona, p_codigoCanal, p_id_session, v_cod_operacion, p_codigoEmpresa, v_msj_bitacora ||', ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200) || '] '|| paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), paw_uti.BITACORA_ERROR);
         RETURN v_retorno;
   END;
   -- verifica si la persona ya autorizo en numero de documento
   FUNCTION fu_ver_mov_autorizado(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE,
                                  p_cod_persona   IN bw_autorizaciones.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_sino VARCHAR2(1) := 'N';
   BEGIN
      SELECT 'S'
        INTO v_sino
        FROM bw_autorizaciones a
       WHERE a.cod_persona = p_cod_persona
         AND a.nro_documento = p_nro_documento
         AND a.accion = 'A';
      RETURN v_sino;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_sino;
   END;
   -- verificar si un documento fue autorizado por un usuario
   FUNCTION fu_ver_autorizacion(p_nro_documento IN bw_autorizaciones.nro_documento%TYPE,
                                p_cod_persona   IN bw_autorizaciones.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_retorno VARCHAR2(1) := 'N';
   BEGIN
      SELECT 'S'
        INTO v_retorno
        FROM bw_autorizaciones a
       WHERE a.nro_documento = p_nro_documento
         AND a.cod_persona = p_cod_persona;

      RETURN v_retorno;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN v_retorno;
   END;

   -- volver a dejar pendiente la operacion si falla la autorizacion final del pago de servicio
   PROCEDURE pr_act_pendiente(p_cod_persona     IN ba_personas.cod_persona%TYPE,
                              p_cod_per_empresa IN ba_personas.cod_persona%TYPE,
                              p_cod_operacion   IN bw_tip_mensajes.cod_tip_mensaje%TYPE,
                              p_dato            IN bw_mov_pendientes.dato%TYPE,
                              p_proveedor       IN bw_mov_pendientes.referencia%TYPE DEFAULT NULL) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
     v_nro_doc_confirmado bw_autorizaciones.nro_documento%TYPE;
   BEGIN
      UPDATE bw_mov_pendientes
         SET can_aut_faltantes = 1, estado = 'P', dato2 = NULL
       WHERE cod_per_principal = p_cod_per_empresa
         AND cod_tip_mensaje = p_cod_operacion
         AND dato = p_dato
         AND estado IN ('C', 'E')
         AND can_aut_faltantes = 0
         AND TRUNC(fec_insercion) = TRUNC(SYSDATE)
         RETURNING nro_documento INTO v_nro_doc_confirmado;

      -- elimino la firma registrada
      DELETE FROM bw_autorizaciones
       WHERE nro_documento = v_nro_doc_confirmado
         AND cod_persona = p_cod_persona
         AND TRUNC(fec_insercion) = TRUNC(SYSDATE);

      -- proveedor SET
      IF nvl(p_proveedor, 0) = 2 THEN
         DELETE FROM ge_set_pagos p
          WHERE cod_token = p_dato
            AND TRUNC(fec_insercion) = TRUNC(SYSDATE)
            AND estado = 'N';
      END IF;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         paw_uti.pr_insertarBitacora(p_cod_persona, '999', p_dato, p_cod_operacion, p_cod_per_empresa, 'nro_doc: ' || v_nro_doc_confirmado || ', cod_pro:'|| p_proveedor || ', ERR: [' || substr(sqlerrm, 1, 400) || ']', paw_uti.BITACORA_ERROR);
   END;
   -- verificar un lote de proveedores sipap
  FUNCTION fu_obt_pag_snp_proveedores(p_cod_ente    IN ge_pag_proveedores_tmp.cod_ente%TYPE,
                                       p_fec_pago    IN ge_pag_proveedores_tmp.fec_pago%TYPE,
                                       p_nro_archivo IN ge_pag_proveedores_tmp.nro_archivo%TYPE) RETURN NUMBER IS
      v_retorno NUMBER;
   BEGIN
      SELECT nvl(COUNT(0), 0)
        INTO v_retorno
        FROM ge_pag_proveedores_tmp t
       WHERE t.cod_ente = p_cod_ente
         AND t.fec_pago = p_fec_pago
         AND t.nro_archivo = p_nro_archivo
         AND t.for_pago = 'I';
      RETURN v_retorno;
   END;

    -- Obtener cuentas de tarjeta cancelada
    FUNCTION fu_ns_obtenerCuentascancel(p_cod_persona         IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                        p_cod_empresa         IN BW_AUT_SESIONES.COD_PER_VINCULADA%TYPE,
                                        p_codCanal            IN VARCHAR2,
                                        p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL,
                                        p_cod_sesion_aux      IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_obtenerDetalleCuentas IS

      MSG_OBT_CTADET_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'OBTCTADET_CTAIX';

      v_ver_todas          VARCHAR2(1);
      v_nro_cta_especifica VARCHAR2(16);
      v_can_detalles       NUMBER(3); -- cantidad de cuentas
      v_monto1             NUMBER(18, 2) := 0; -- monto 1
      v_monto2             NUMBER(18, 2) := 0; -- monto 2
      v_monto3             NUMBER(18, 2) := 0; -- monto 3
      v_monto4             VARCHAR2(18); -- monto 4
      v_monto5             NUMBER(18, 2) := 0; -- monto 5
      v_monto6             NUMBER(18, 2) := 0; -- monto 6
      v_val_tasa           NUMBER(10, 4) := NULL;
      --v_NroCuentaEspecifica VARCHAR2(16);
      v_fec_inicio         DATE;
      v_fec_vencimiento    DATE;
      v_dia_mora           NUMBER;
      v_che_devuelto       VARCHAR2(01);
      v_can_cuotas         NUMBER(5);
      v_cta_formateada     VARCHAR2(17);
      v_fec_prox_vcto      DATE := NULL;
      v_afinidad           TA_CTA_TARJETAS.AFINIDAD%TYPE;
      --jalvarenga 23/Abril/2012
      COD_OPERACION  VARCHAR2(3) := '020';
      v_fec_actual   DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
      v_listaCuentas typ_listaDetalleCuenta := typ_listaDetalleCuenta();
      v_retorno      typ_obtenerDetalleCuentas := typ_obtenerDetalleCuentas;
      v_logmessage   VARCHAR(1000);
      v_tip_cierre   TA_CTA_TARJETAS.COD_TIP_CIERRE%TYPE;
      v_error        VARCHAR2(1);
      v_msj_error    VARCHAR2(2000);
      v_imp_extracto ge_clientes.tip_extracto%TYPE;
      v_ext_cliente  ge_clientes.tip_extracto%TYPE;
      v_existe       VARCHAR2(1);
      v_nro_certificado VARCHAR2(300) := '';

      -- cursor de cuentas del cliente
      CURSOR cuentas(p_nroCuenta IN VARCHAR2) IS
          SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada, paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta, decode(b.relacion, 'C', 'Codeudor', 'G', 'Codeudor', fug_obt_des_modal(a.cod_modulo, a.cod_modalidad)) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo, b.relacion, a.estado,a.fec_cam_estado,ta.fec_emision
          FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b,
               ba_personas p, ta_tarjetas ta, ta_cta_tarjetas cta
          WHERE a.nro_cuenta = b.nro_cuenta
                AND b.relacion IN ('O', 'P', 'Y')
                AND b.cod_persona = p_cod_persona
                AND a.cod_modulo = c.cod_modulo
                AND a.cod_modalidad = c.cod_modalidad
                AND a.estado = c.estado
                and b.nro_cuenta =  ta.nro_cuenta
                AND p.cod_persona = b.cod_persona
                AND cta.nro_cuenta = b.nro_cuenta
                AND b.relacion = 'P'
                AND p.tipo = 'F'
                AND ta.vigente = 'N'
                and ta.cod_estado=10
                and cta.estado='C'
                and c.estado='C'
                and b.cod_modulo=5
                and c.cod_modalidad
        in (select cod_modalidad
                from ge_par_dinamicos
                where parametro = 'HAB_TAR_CANCEL')
                AND c.activo = 'N'
                AND a.estado = 'C'
                and a.fec_modificacion between ADD_MONTHS(CURRENT_DATE, -12) and CURRENT_DATE
                AND ('P' is null
                OR ('P'= 'P' and ta.cod_persona = b.cod_persona)
                OR ('P' = 'A' and ta.cod_persona <> b.cod_persona))
                and ta.fec_emision = (SELECT max(ta1.fec_emision)
                                      FROM ge_est_cuentas c1, ge_cuentas a1, ge_cta_clientes b1,
                                           ba_personas p1, ta_tarjetas ta1, ta_cta_tarjetas cta1
                                      WHERE a1.nro_cuenta = b1.nro_cuenta
                                          AND b1.relacion IN ('O', 'P', 'Y')
                                          AND a1.cod_modulo = c1.cod_modulo
                                          AND a1.cod_modalidad = c1.cod_modalidad
                                          AND a1.estado = c1.estado
                                          and b1.nro_cuenta =  ta1.nro_cuenta
                                          AND p1.cod_persona = b1.cod_persona
                                          AND cta1.nro_cuenta = b1.nro_cuenta
                                          AND b1.relacion = 'P'
                                          AND p1.tipo = 'F'
                                          AND ta1.vigente = 'N'
                                          and ta1.cod_estado=10
                                          and cta1.estado='C'
                                          and c1.estado='C'
                                          and b1.cod_modulo=5
                                          and c1.cod_modalidad in
                      (select cod_modalidad
                      from ge_par_dinamicos
                      where parametro = 'HAB_TAR_CANCEL')
                                          AND c1.activo = 'N'
                                          AND a1.estado = 'C'
                                          and b1.cod_persona=b.cod_persona
                                          and ta1.nro_cuenta=ta.nro_cuenta
                                          and a1.fec_modificacion between ADD_MONTHS(CURRENT_DATE, -12) and CURRENT_DATE
                                          AND ('P' is null
                                          OR ('P'= 'P' and ta1.cod_persona = b1.cod_persona)
                                          OR ('P' = 'A' and ta1.cod_persona <> b1.cod_persona))) ;
   BEGIN
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_retorno.cantCuentas := 0;

      --Logear parámetros
      v_logMessage := substr('fu_ns_obtenerDetalleCuentas(nroCuentaEspecifica=' || p_nroCuentaEspecifica || ')',0,999);
      PAW_UTI.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, v_logMessage, BITACORA_ENTRADA);

      IF (p_nroCuentaEspecifica IS NULL) THEN
         v_ver_todas := 'S';
      ELSE
         v_ver_todas          := 'N';
         v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nroCuentaEspecifica, 16);
      END IF;
      IF length(v_nro_cta_especifica) = 16 THEN
         -- es un tarjeta de credito, busco y reemplazo el dato
         BEGIN
            SELECT a.nro_cuenta
              INTO v_nro_cta_especifica
              FROM ge_cta_clientes a, ta_tarjetas b
             WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
               AND b.nro_cuenta = a.nro_cuenta
               AND a.cod_persona = nvl(p_cod_empresa, p_cod_persona);
         EXCEPTION
            WHEN no_data_found THEN
               SELECT b.nro_cuenta
                 INTO v_nro_cta_especifica
                 FROM ta_tarjetas b
                WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
                  AND vigente = 'S'
                  AND rownum = 1;
         END;
      END IF;
      -- obtenemos el tipo de extracto por cliente
      v_ext_cliente := paw_uti.fu_imp_extracto(nvl(p_cod_empresa, p_cod_persona));

      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;
         FOR ct IN cuentas(v_nro_cta_especifica)
         LOOP
            DECLARE
               detalleCuenta typ_detalleCuenta := typ_detalleCuenta;
            BEGIN

               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF paw_uti.fu_es_juridica(ct.nro_cuenta, p_cod_empresa, p_cod_persona) = 'N' THEN
                  v_can_detalles := v_can_detalles + 1;
                  IF ct.cod_modulo = 5 THEN
                     v_cta_formateada := paw_bce.fu_obt_nro_tarjeta(ct.nro_cuenta, p_cod_persona, p_cod_empresa);
                     detalleCuenta.numeroTarjeta := substr(v_cta_formateada, 1, 20);
                  ELSE
                     v_cta_formateada := ct.cta_formateada;
                  END IF;

                  detalleCuenta.nroCuenta      := substr(ct.cta_formateada, 0, 17);
                  detalleCuenta.tipoCuenta     := TRIM(substr(ct.cod_tip_cuenta, 0, 2));
                  detalleCuenta.descTipoCuenta := substr(ct.des_tip_cuenta, 0, 35);
                  detalleCuenta.denominacion   := substr(ct.nom_cuenta, 0, 50);
                  detalleCuenta.codMoneda      := substr(ct.cod_moneda, 0, 3);
                  detalleCuenta.relacion       := ct.relacion;
                  v_monto1                     := 0; -- monto 1
                  v_monto2                     := 0; -- monto 2
                  v_monto3                     := 0; -- monto 3
                  v_monto4                     := 0; -- monto 4
                  v_monto5                     := 0; -- monto 5
                  v_monto6                     := 0; -- monto 6
                  v_val_tasa                   := NULL;
                  v_fec_inicio                 := NULL;
                  v_fec_vencimiento            := NULL;
                  v_fec_prox_vcto              := NULL;
                  v_dia_mora                   := 0;
                  v_che_devuelto               := 'N';
                  v_can_cuotas                 := 0;
                  v_imp_extracto               := v_ext_cliente;
                  v_nro_certificado            := '';
                  detalleCuenta.alias          := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                  -- busco los demas datos de las cuentas
                  BEGIN

                       -- tarjetas
                       SELECT nvl(lin_credito, 0) - (nvl(sal_facturar, 0) + nvl(sal_facturado, 0) + nvl(sal_financiado, 0) /*+ nvl(sal_cuo_pendientes, 0)*/),
                              (nvl(sal_facturar, 0) + nvl(sal_facturado, 0) + nvl(sal_financiado, 0) /*+ nvl(sal_cuo_pendientes, 0)*/),
                              -- OMM 12/11/2010 Analisis Funcional y AP Nro.: 1037.1
                              --nvl(sal_pag_minimo,0),
                              decode(nvl(sal_pag_minimo, 0), 0, nvl(mto_mora, 0), nvl(sal_pag_minimo, 0)), nvl(lin_credito, 0), tas_financiacion,
                              fec_ult_cierre, fec_vct_ult_cierre, dia_mora, 'N', lin_cuotas, cod_tip_cierre, denominacion
                         INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_monto5,
                              v_tip_cierre, detalleCuenta.denominacion
                         FROM ta_cta_tarjetas
                        WHERE nro_cuenta = ct.nro_cuenta;

                       -- indicamos si la tarjeta imprime extracto
                       SELECT decode(pat_imp.fu_ret_extracto(ct.nro_cuenta), 'S', 'N' -- si retiene extracto, no imprime
                                                                           , 'S')
                         INTO v_imp_extracto
                         FROM DUAL;

                       -- gourmets no imprimen extractos
                       IF paw_not.lf_es_gourmet(ct.cod_modalidad) = 'S' THEN
                          v_imp_extracto := 'N';
                       END IF;
                       -- es prepaga mastecard
                       detalleCuenta.extraData := '{"prepaga": "'||paw_uti.fu_es_prepaga(ct.cod_modalidad)  ||'"}';

                       SELECT MIN(fec_cierre)
                         INTO v_fec_prox_vcto
                         FROM ta_cal_cierres v
                        WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                          AND v.cod_modulo = ct.cod_modulo
                          AND v.cod_modalidad = ct.cod_modalidad
                          AND v.cod_tip_cierre = v_tip_cierre
                          AND fec_cierre > v_fec_inicio;

                       -- si ya pago se busca el siguiente cierre, o ya hay nuevo cierre
                       IF v_monto3 = 0 THEN
                          SELECT MIN(fec_cierre), MIN(fec_vencimiento)
                            INTO v_fec_prox_vcto, v_fec_vencimiento
                            FROM ta_cal_cierres v
                           WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                             AND v.cod_modulo = ct.cod_modulo
                             AND v.cod_modalidad = ct.cod_modalidad
                             AND v.cod_tip_cierre = v_tip_cierre
                             AND fec_cierre > v_fec_inicio;
                       END IF;

                       -- Si no existe para esa modalidad busco el vcto general
                       IF v_fec_prox_vcto IS NULL THEN
                          SELECT MIN(fec_cierre), MIN(fec_vencimiento)
                            INTO v_fec_prox_vcto, v_fec_vencimiento
                            FROM ta_cal_cierres v
                           WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                             AND v.cod_modulo = ct.cod_modulo
                             AND v.cod_modalidad IS NULL
                                --AND v.cod_tip_cierre = v_tip_cierre
                             AND fec_cierre > v_fec_inicio;
                       END IF;
                       -- Si no existe (puede ser que no se cargo) despliego el ultimo cierre
                       IF v_fec_prox_vcto IS NULL THEN
                          v_fec_prox_vcto := v_fec_inicio;
                       END IF;

                       v_fec_inicio := v_fec_prox_vcto;

                       BEGIN
                          --descripcion de la afinidad
                          SELECT DISTINCT p.Descripcion,
                            substr(FUE_OBT_SIG_REFCODES('AFINIDAD', ct.afinidad), 0, 35)
                            INTO detalleCuenta.dato1, detalleCuenta.descTipoCuenta
                            FROM TA_TARJETAS t, TA_CTA_TARJETAS ct, TA_TIPOS p
                           where p.cod_modulo = ct.cod_modulo
                             and p.cod_modalidad = ct.cod_modalidad
                             and p.afinidad = ct.afinidad
                             and CT.NRO_CUENTA = T.NRO_CUENTA
                             and T.NRO_TARJETA = detalleCuenta.numeroTarjeta;
                        EXCEPTION
                          when others then
                            detalleCuenta.dato1 := 'Afinidad no definida';
                            detalleCuenta.descTipoCuenta := 'Afinidad no definida';
                        END;

                       -- si genera puntos la tarjeta dato2 = S, en caso contrario N
                       detalleCuenta.dato2 := 'N';
                       SELECT afinidad
                         INTO v_afinidad
                         FROM ta_cta_tarjetas
                        WHERE nro_cuenta = ct.nro_cuenta;
                        IF (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                           detalleCuenta.dato2 := 'BPO';
                        ELSIF (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS_EXP', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                           detalleCuenta.dato1 := CONCAT(detalleCuenta.dato1,' EXPERIENCE');
                           detalleCuenta.dato2 := 'EXPERIENCE';
                        ELSIF (instr(fug_obt_pardinamico('AFI_SHO_DEL_SOL', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                           -- VALIDACION SI LA TARJETA GENERA SOLES
                           detalleCuenta.dato2 := 'SOLES';
                        END IF;

                  EXCEPTION
                     WHEN OTHERS THEN
                        --p_cod_respuesta := paw_bce.v_cod_cta_inexistente;
                        paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                        paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'cta: '|| ct.nro_cuenta ||', mad:' || ct.cod_modalidad || ', ORA-ERR: ' || SQLERRM || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL) || SQLERRM, BITACORA_ERROR);
                  END;
                  IF v_retorno.error = 'N' AND detalleCuenta.tipoCuenta IS NOT NULL THEN
                     IF ct.cod_modulo = 5 THEN
                        --13/08/2015. Para Tarjetas de Crédito, se consulta si es de la Afinidad Gourmet
                        --Resolución de la incidencia DYDMR-2239
                        v_che_devuelto:=PAW_not.lf_es_gourmet(ct.cod_modalidad);
                     ELSE
                        v_che_devuelto := paw_uti.lf_obt_che_devuelto(ct.nro_cuenta);
                     END IF;

                     -- esta bien el dato se carga el detalle
                     detalleCuenta.monto1                  := substr(paw_uti.lf_for_money(v_monto1), 1, 16);
                     detalleCuenta.monto2                  := substr(paw_uti.lf_for_money(v_monto2), 1, 16);
                     detalleCuenta.monto3                  := substr(paw_uti.lf_for_money(v_monto3), 1, 16);
                     detalleCuenta.monto4                  := substr(v_monto4, 1, 16);
                     detalleCuenta.tasa                    := v_val_tasa;
                     detalleCuenta.fechaInicio             := paw_uti.lf_for_date(v_fec_inicio);
                     detalleCuenta.fechaVencimiento        := paw_uti.lf_for_date(v_fec_vencimiento);
                     detalleCuenta.diasMora                := v_dia_mora;
                     detalleCuenta.chequeDevuelto          := substr(v_che_devuelto, 0, 1);
                     detalleCuenta.fechaProximoVencimiento := paw_uti.lf_for_date(v_fec_prox_vcto);
                     detalleCuenta.imprimeExtracto         := v_imp_extracto;
                     v_listaCuentas.EXTEND;
                     v_listaCuentas(v_listaCuentas.COUNT) := detalleCuenta;
                  END IF;
               END IF;
               IF v_can_detalles >= 999 THEN
                  EXIT; --XXX
               END IF;
            END;
         END LOOP;
         IF v_can_detalles = 0 THEN
            -- no tiene detalles
            -- p_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
            paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas - Cuenta Inexistente -' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null) ||sqlerrm, BITACORA_ERROR);
         END IF;
      END IF;

      -- registro del movimiento
      paw_uti.lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/, NULL /*p_cod_moneda */, NULL /*p_monto*/, NULL /*p_nro_cta_contra*/, NULL /*p_cantidad*/, 'Ver Todas' /*p_etiqueta*/, v_ver_todas, /*p_dato*/ NULL, NULL, NULL, NULL, NULL, p_cod_persona, COD_OPERACION, p_cod_persona || p_codCanal, p_codCanal, p_cod_sesion_aux, p_cod_empresa);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas-' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_SALIDA);
      IF v_retorno.error = 'N' THEN
         -- todo ok, se arma el mensaje de respuesta
         v_retorno.listaCuentas := v_listaCuentas;
         v_retorno.cantCuentas  := v_listaCuentas.Count;
         RETURN v_retorno;
      ELSE
         RETURN v_retorno;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas -' || SQLERRM, BITACORA_ERROR);
         RETURN v_retorno;
   END fu_ns_obtenerCuentascancel;

   FUNCTION fu_ns_obtDetCtas_Bancard(p_cod_persona         IN BW_AUT_SESIONES.COD_PERSONA%TYPE,
                                     p_cod_empresa         IN BW_AUT_SESIONES.COD_PER_VINCULADA%TYPE,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL,
                                     p_cod_sesion_aux      IN BW_AUT_SESIONES.COD_SESION%TYPE DEFAULT NULL) RETURN typ_obtdetctas_hb_bancard IS

      MSG_OBT_CTADET_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := 'OBTCTADET_CTAIX';

      v_ver_todas          VARCHAR2(1);
      v_nro_cta_especifica VARCHAR2(16);
      v_can_detalles       NUMBER(3); -- cantidad de cuentas
      v_monto1             NUMBER(18, 2) := 0; -- monto 1
      v_monto2             NUMBER(18, 2) := 0; -- monto 2
      v_monto3             NUMBER(18, 2) := 0; -- monto 3
      v_monto4             VARCHAR2(18); -- monto 4
      v_monto5             NUMBER(18, 2) := 0; -- monto 5
      v_monto6             NUMBER(18, 2) := 0; -- monto 6
      v_val_tasa           NUMBER(10, 4) := NULL;
      --v_NroCuentaEspecifica VARCHAR2(16);
      v_fec_inicio         DATE;
      v_fec_vencimiento    DATE;
      v_dia_mora           NUMBER;
      v_che_devuelto       VARCHAR2(01);
      v_can_cuotas         NUMBER(5);
      v_cta_formateada     VARCHAR2(17);
      v_fec_prox_vcto      DATE := NULL;
      v_afinidad           TA_CTA_TARJETAS.AFINIDAD%TYPE;
      --jalvarenga 23/Abril/2012
      COD_OPERACION  VARCHAR2(3) := '020';
      v_fec_actual   DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
      v_listaCuentas typ_listdetcnta_hb_bancard := typ_listdetcnta_hb_bancard();
      v_retorno      typ_obtdetctas_hb_bancard := typ_obtdetctas_hb_bancard;
      v_logmessage   VARCHAR(1000);
      v_tip_cierre   TA_CTA_TARJETAS.COD_TIP_CIERRE%TYPE;
      v_error        VARCHAR2(1);
      v_msj_error    VARCHAR2(2000);
      v_imp_extracto ge_clientes.tip_extracto%TYPE;
      v_ext_cliente  ge_clientes.tip_extracto%TYPE;
      v_existe       VARCHAR2(1);
      v_nro_certificado VARCHAR2(300) := '';
      v_mad_aho         ge_par_dinamicos.val_parametro%type :=fug_obt_pardinamico('MAD_AHO_BAN_WEB');

      -- cursor de cuentas del cliente
      CURSOR cuentas(p_nroCuenta IN VARCHAR2) IS
         SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad,fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada, paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta, decode(b.relacion, 'C', 'Codeudor', 'G', 'Codeudor', fug_obt_des_modal(a.cod_modulo, a.cod_modalidad)) des_tip_cuenta,
                a.cod_moneda cod_moneda, a.denominacion nom_cuenta, a.cod_modulo, b.relacion, a.estado
           FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
                AND ((b.relacion IN ('O', 'P', 'Y') AND b.cod_modulo != 6) OR (b.relacion IN ('O', 'C', 'G', 'P') AND b.cod_modulo = 6))
                AND b.cod_persona = nvl(p_cod_empresa, p_cod_persona)
                AND a.cod_modulo = c.cod_modulo
                AND a.cod_modalidad = c.cod_modalidad
                AND a.estado = c.estado
                AND b.cod_modulo != 7
                AND b.cod_modalidad <> 36
        and not(a.estado = 'A' and a.cod_modulo=3 and (instr(v_mad_aho, '#'||a.cod_modalidad||'#' ) > 0) and nvl(a.cod_sub_modalidad, 999)=9) --No mostrar cuentas que se abrieron para simular cuotas de pre aprobados
        and not (a.estado = 'A' and a.cod_modulo=3 and a.cod_modalidad=33)
                AND (c.activo = 'S' OR (a.cod_modulo = 6 AND p_nroCuenta IS NOT NULL) OR (a.cod_modalidad in (37, 38) AND (p_nroCuenta IS NOT NULL OR sysdate - a.fec_cam_estado < nvl(to_number(fug_obt_pardinamico('MAX_DIA_CTA_INACTIVA', a.cod_modulo, a.cod_modalidad)), 0))) ) -- solo cuentas activas, excepto para prestamos y ahorro a plazo en consultas por cuenta especifica
                --BWP-306 glopez se descomenta por que no quieren que se muestre cuentas con estado X
                AND a.estado <> 'X' -- pendiente de verificacion
                AND (p_nroCuenta IS NULL OR b.nro_cuenta = p_nroCuenta) -- solo ve la cuenta recibida o todas
          ORDER BY decode(b.cod_modalidad, 31, 1,decode(b.cod_modulo, 5, 2, decode(b.cod_modalidad, 33, 4, 34, 4, 36, 4, decode(b.cod_modulo, 4, 3, 7))));

   BEGIN
      paw_uti.pr_mensajeUsuario(PAW_UTI.MSG_OK,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_retorno.cantCuentas := 0;

      --Logear parámetros
      v_logMessage := substr('fu_ns_obtenerDetalleCuentas(nroCuentaEspecifica=' || p_nroCuentaEspecifica || ')',0,999);
      PAW_UTI.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, v_logMessage, BITACORA_ENTRADA);

      IF (p_nroCuentaEspecifica IS NULL) THEN
         v_ver_todas := 'S';
      ELSE
         v_ver_todas          := 'N';
         v_nro_cta_especifica := PAW_UTI.depurarAlfanumerico(p_nroCuentaEspecifica, 16);
      END IF;
      IF length(v_nro_cta_especifica) = 16 THEN
         -- es un tarjeta de credito, busco y reemplazo el dato
         BEGIN
            SELECT a.nro_cuenta
              INTO v_nro_cta_especifica
              FROM ge_cta_clientes a, ta_tarjetas b
             WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
               AND b.nro_cuenta = a.nro_cuenta
               AND a.cod_persona = nvl(p_cod_empresa, p_cod_persona);
         EXCEPTION
            WHEN no_data_found THEN
               SELECT b.nro_cuenta
                 INTO v_nro_cta_especifica
                 FROM ta_tarjetas b
                WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
                  AND vigente = 'S'
                  AND rownum = 1;
         END;
      END IF;
      -- obtenemos el tipo de extracto por cliente
      v_ext_cliente := paw_uti.fu_imp_extracto(nvl(p_cod_empresa, p_cod_persona));

      -- 2. busco los datos de la cuentas
      IF v_retorno.error = 'N' THEN
         v_can_detalles := 0;
         FOR ct IN cuentas(v_nro_cta_especifica)
         LOOP
            DECLARE
               detalleCuenta typ_detcta_hb_bancard := typ_detcta_hb_bancard;
            BEGIN

               --- Debe controlar para que no muestre cuentas juridicas entre las cuentas del cliente
               IF paw_uti.fu_es_juridica(ct.nro_cuenta, p_cod_empresa, p_cod_persona) = 'N'  THEN
                  v_can_detalles := v_can_detalles + 1;
                  IF ct.cod_modulo = 5 THEN
                     v_cta_formateada := paw_bce.fu_obt_nro_tarjeta(ct.nro_cuenta, p_cod_persona, p_cod_empresa);
                     detalleCuenta.numeroTarjeta := substr(v_cta_formateada, 1, 20);
                  ELSE
                     v_cta_formateada := ct.cta_formateada;
                  END IF;

                  detalleCuenta.nroCuenta   := substr(ct.cta_formateada, 0, 17);
                  detalleCuenta.tipoCuenta     := TRIM(substr(ct.cod_tip_cuenta, 0, 2));
                  detalleCuenta.descTipoCuenta := substr(ct.des_tip_cuenta, 0, 35);
                  detalleCuenta.denominacion   := substr(ct.nom_cuenta, 0, 50);
                  detalleCuenta.codMoneda      := substr(ct.cod_moneda, 0, 3);
                  detalleCuenta.relacion       := ct.relacion;
                  v_monto1                     := 0; -- monto 1
                  v_monto2                     := 0; -- monto 2
                  v_monto3                     := 0; -- monto 3
                  v_monto4                     := 0; -- monto 4
                  v_monto5                     := 0; -- monto 5
                  v_monto6                     := 0; -- monto 6
                  v_val_tasa                   := NULL;
                  v_fec_inicio                 := NULL;
                  v_fec_vencimiento            := NULL;
                  v_fec_prox_vcto              := NULL;
                  v_dia_mora                   := 0;
                  v_che_devuelto               := 'N';
                  v_can_cuotas                 := 0;
                  v_imp_extracto               := v_ext_cliente;
                  v_nro_certificado            := '';
                  detalleCuenta.alias          := fug_obt_paradicional(ct.nro_cuenta, 'CTA_ALIAS');
                  -- busco los demas datos de las cuentas
                  BEGIN
                     IF ct.cod_modulo = 6 THEN
                        -- prestamos
                        SELECT /*monto*/nvl(mto_capital, 0) + nvl(dev_acumulado, 0) - nvl(sal_capital, 0) - nvl(dev_no_cobrado, 0)- nvl(dev_suspenso, 0), nvl(sal_capital, 0), nvl(sal_int_adelantado, 0) + nvl(sal_interes, 0), 0, val_tasa, fec_inicio, fec_vencimiento,
                               /* dia mora 0 a pedido de bbva */ 0 dia_atraso, 'N', can_cuotas
                          INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_can_cuotas
                          FROM pr_cta_prestamos
                         WHERE nro_cuenta = ct.nro_cuenta;
                        --Datos de la siguiente cuota BBVAHB-750
                        BEGIN
                           SELECT nro_cuota, fec_vencimiento
                             INTO v_monto4, v_fec_prox_vcto
                             FROM pr_cuotas p
                            WHERE p.nro_cuenta = ct.nro_cuenta
                              AND p.estado NOT IN ('N')
                              AND p.nro_cuota > 0
                              AND rownum = 1
                            ORDER BY p.nro_cuenta ASC;
                           -- calculamos el saldo interes a la fecha, no el total
                           SELECT nvl(SUM(pc.sal_interes + pc.dev_acumulado), 0)
                             INTO v_monto3
                             FROM pr_cuotas pc
                            WHERE pc.nro_cuenta = ct.nro_cuenta
                              AND pc.estado <> 'N'
                              AND pc.nro_cuota > 0
                              AND pc.fec_vencimiento <= v_fec_actual + 25;

                           -- para descuentos, agregamos el interes a devengar
                           IF nvl(fup_obt_tip_descuento(ct.cod_modalidad),'x') IN ('F','D','C') THEN
                              BEGIN
                                IF ct.cod_modalidad = 608 THEN
                                 -- Si es descuento de cheque, se retorna sal_int_adelantado para obtener la deuda total. DDSI-1867
                                 SELECT nvl(sal_int_adelantado, 0)
                                  INTO v_monto3
                                   FROM pr_cta_prestamos p
                                  WHERE p.nro_cuenta = ct.nro_cuenta;
                                ELSE
                                  SELECT v_monto3 + trunc(p.val_int_devengar, 2)
                                   INTO v_monto3
                                   FROM pr_cta_prestamos p
                                  WHERE p.nro_cuenta = ct.nro_cuenta;
                                END IF;
                              EXCEPTION
                                 WHEN OTHERS THEN
                                    NULL;
                              END;
                           END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                              v_monto4 := -1;
                        END;
                        v_monto4 := v_monto4 || '/' || v_can_cuotas;
                        --Datos de la siguiente cuota BBVAHB-750
                     ELSIF ct.cod_modulo = 5 THEN
                       -- tarjetas
                       SELECT nvl(lin_credito, 0) - (nvl(sal_facturar, 0) + nvl(sal_facturado, 0) + nvl(sal_financiado, 0) /*+ nvl(sal_cuo_pendientes, 0)*/),
                              (nvl(sal_facturar, 0) + nvl(sal_facturado, 0) + nvl(sal_financiado, 0) /*+ nvl(sal_cuo_pendientes, 0)*/),
                              -- OMM 12/11/2010 Analisis Funcional y AP Nro.: 1037.1
                              --nvl(sal_pag_minimo,0),
                              decode(nvl(sal_pag_minimo, 0), 0, nvl(mto_mora, 0), nvl(sal_pag_minimo, 0)), nvl(lin_credito, 0), tas_int_corriente/*tas_financiacion*/,
                              fec_ult_cierre, fec_vct_ult_cierre, dia_mora, 'N', lin_cuotas, cod_tip_cierre, denominacion
                         INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_monto5,
                              v_tip_cierre, detalleCuenta.denominacion
                         FROM ta_cta_tarjetas
                        WHERE nro_cuenta = ct.nro_cuenta;
                     begin
                       select nvl(t.sal_facturar, 0) +
                              nvl(t.sal_financiado, 0) +
                              nvl(t.sal_facturado, x.sal_facturado) +
                              nvl(t.sal_cuo_pendientes, 0)
                         into v_monto5
                         from ta_sal_cierres t, ta_cta_tarjetas x
                        where t.nro_cuenta = x.nro_cuenta
                          and t.nro_cuenta = ct.nro_cuenta
                          and t.fec_cierre = (select max(a.fec_cierre)
                                                from ta_sal_cierres a
                                                where t.nro_cuenta = a.nro_cuenta);
                     exception
                       when others then
                         v_monto5 := 0;
                     end;

                       -- indicamos si la tarjeta imprime extracto
                       SELECT decode(pat_imp.fu_ret_extracto(ct.nro_cuenta), 'S', 'N' -- si retiene extracto, no imprime
                                                                           , 'S')
                         INTO v_imp_extracto
                         FROM DUAL;

                       -- gourmets no imprimen extractos
                       /*IF paw_not.lf_es_gourmet(ct.cod_modalidad) = 'S' THEN
                          v_imp_extracto := 'N';
                       END IF;*/
                       -- es prepaga mastecard
                       detalleCuenta.extraData := '{"prepaga": "'||paw_uti.fu_es_prepaga(ct.cod_modalidad)  ||'"}';

                       SELECT MIN(fec_cierre)
                         INTO v_fec_prox_vcto
                         FROM ta_cal_cierres v
                        WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                          AND v.cod_modulo = ct.cod_modulo
                          AND v.cod_modalidad = ct.cod_modalidad
                          AND v.cod_tip_cierre = v_tip_cierre
                          AND fec_cierre > v_fec_inicio;

                       -- si ya pago se busca el siguiente cierre, o ya hay nuevo cierre
                       IF v_monto3 = 0 THEN
                          SELECT MIN(fec_cierre), MIN(fec_vencimiento)
                            INTO v_fec_prox_vcto, v_fec_vencimiento
                            FROM ta_cal_cierres v
                           WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                             AND v.cod_modulo = ct.cod_modulo
                             AND v.cod_modalidad = ct.cod_modalidad
                             AND v.cod_tip_cierre = v_tip_cierre
                             AND fec_cierre > v_fec_inicio;
                       END IF;

                       -- Si no existe para esa modalidad busco el vcto general
                       IF v_fec_prox_vcto IS NULL THEN
                          SELECT MIN(fec_cierre), MIN(fec_vencimiento)
                            INTO v_fec_prox_vcto, v_fec_vencimiento
                            FROM ta_cal_cierres v
                           WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
                             AND v.cod_modulo = ct.cod_modulo
                             AND v.cod_modalidad IS NULL
                                --AND v.cod_tip_cierre = v_tip_cierre
                             AND fec_cierre > v_fec_inicio;
                       END IF;
                       -- Si no existe (puede ser que no se cargo) despliego el ultimo cierre
                       IF v_fec_prox_vcto IS NULL THEN
                          v_fec_prox_vcto := v_fec_inicio;
                       END IF;

                       v_fec_inicio := v_fec_prox_vcto;

                      /* BEGIN
                          --descripcion de la afinidad
                          SELECT DISTINCT p.Descripcion,
                            substr(FUE_OBT_SIG_REFCODES('AFINIDAD', ct.afinidad), 0, 35)
                            INTO detalleCuenta.dato1, detalleCuenta.descTipoCuenta
                            FROM TA_TARJETAS t, TA_CTA_TARJETAS ct, TA_TIPOS p
                           where p.cod_modulo = ct.cod_modulo
                             and p.cod_modalidad = ct.cod_modalidad
                             and p.afinidad = ct.afinidad
                             and CT.NRO_CUENTA = T.NRO_CUENTA
                             and T.NRO_TARJETA = detalleCuenta.numeroTarjeta;
                        EXCEPTION
                          when others then
                            detalleCuenta.dato1 := 'Afinidad no definida';
                            detalleCuenta.descTipoCuenta := 'Afinidad no definida';
                        END;*/

                       -- si genera puntos la tarjeta dato2 = S, en caso contrario N
                       detalleCuenta.dato2 := 'N';
                       SELECT afinidad
                         INTO v_afinidad
                         FROM ta_cta_tarjetas
                        WHERE nro_cuenta = ct.nro_cuenta;
                        IF (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                           detalleCuenta.dato2 := 'BPO';
                        ELSIF (instr(fug_obt_pardinamico('AFI_TAR_PUNTOS_EXP', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                           detalleCuenta.dato1 := CONCAT(detalleCuenta.dato1,' EXPERIENCE');
                           detalleCuenta.dato2 := 'EXPERIENCE';
                        ELSIF (instr(fug_obt_pardinamico('AFI_SHO_DEL_SOL', ct.cod_modulo, ct.cod_modalidad), v_afinidad) != 0) THEN
                           -- VALIDACION SI LA TARJETA GENERA SOLES
                           detalleCuenta.dato2 := 'SOLES';
                        END IF;

                     ELSIF instr(v_mad_aho, '#'||ct.cod_modalidad||'#' ) > 0 THEN
                        -- ahorro vista
                        pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                        -- control de error en saldos
                        IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
                           prg_obt_sal_atm_cierre(ct.nro_cuenta,
                                                  pag_cta.g_ctas.sal_disponible,
                                                  pag_cta.g_ctas.sal_actual,
                                                  pag_cta.g_ctas.sal_retenido,
                                                  pag_cta.g_ctas.sal_bloqueado,
                                                  v_error,
                                                  v_msj_error);
                        END IF;
                        --
                        v_monto1          := pag_cta.g_ctas.sal_actual;
                        v_monto2          := pag_cta.g_ctas.sal_disponible;
                        v_monto3          := pag_cta.g_ctas.sal_retenido + pag_cta.g_ctas.mto_cre_a_confirmar;
                        v_monto4          := 0;
                        v_val_tasa        := pag_cta.g_ctas.val_tasa;
                        v_fec_inicio      := pag_cta.g_ctas.fec_apertura;
                        v_fec_vencimiento := pag_cta.g_ctas.fec_vencimiento;
                        v_dia_mora        := 0;
                        v_che_devuelto    := 'N';
                     ELSIF  ct.cod_modalidad IN (33, 34, 35, 36, 37) THEN
                        -- cda
                        SELECT capital, nvl(int_pendiente, 0) int_pendiente, nvl(sal_retenido, 0), 0, fug_obt_val_tasa(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda, capital, tas_personalizada, cod_tasa, NULL, v_fec_actual) val_tasa, fec_apertura, fec_vencimiento, 0, 'N', nro_certificado
                          INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, detalleCuenta.dato1
                          FROM ah_cta_certificados,
                   (SELECT nro_cuenta cuenta, SUM(mto_interes) int_pendiente
                                   FROM ah_cupones
                                  WHERE estado IN ('V', 'E')
                                  GROUP BY nro_cuenta) b
                         WHERE nro_cuenta = ct.nro_cuenta
                           AND b.cuenta(+) = nro_cuenta
                       UNION ALL
                       --apfd
                        SELECT capital, nvl(int_pendiente, 0) int_pendiente, nvl(sal_retenido, 0), 0, 0, fec_apertura, fec_vencimiento, 0, 'N', 0 as nro_certificado
                          --INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento, v_dia_mora, v_che_devuelto, v_nro_certificado
                          FROM ah_cta_plazos,
                               (SELECT nro_cuenta cuenta, SUM(mto_interes) int_pendiente
                                   FROM ah_cupones
                                  WHERE estado IN ('V', 'E')
                                  GROUP BY nro_cuenta) b
                         WHERE nro_cuenta = ct.nro_cuenta
                           AND b.cuenta(+) = nro_cuenta;
                     ELSIF ct.cod_modalidad = 38 THEN
                        -- ahorro programado
                        SELECT a.capital, nvl(a.sal_total, 0), nvl(b.int_pendiente, 0) int_pendiente,
                               nvl(a.sal_retenido, 0) + nvl(a.sal_bloqueado, 0), a.val_tasa, fec_apertura,
                               fec_vencimiento, 0, 'N', substr(fue_obt_sig_refcodes('FEC_DEB_AHO_PROGRAMADO', a.per_debito), 1, 300)
                          INTO v_monto1, v_monto2, v_monto3, v_monto4, v_val_tasa, v_fec_inicio, v_fec_vencimiento,
                               v_dia_mora, v_che_devuelto, detalleCuenta.dato2
                          FROM ah_cta_plazos a, (SELECT nro_cuenta cuenta, SUM(mto_interes) int_pendiente
                                                 FROM ah_pro_cuotas
                                                WHERE estado IN ('V', 'E', 'A')
                                                GROUP BY nro_cuenta) b
                         WHERE a.nro_cuenta = ct.nro_cuenta
                           AND b.cuenta(+) = a.nro_cuenta;
                         detalleCuenta.dato1 := substr(TRIM(fug_obt_paradicional(ct.nro_cuenta, 'HAB_REFUERZO')), 1, 300);
                     ELSIF ct.cod_modalidad = 41 THEN
                        -- cuenta corriente
                        BEGIN
                           SELECT can_dias
                             INTO v_dia_mora
                             FROM cc_sobregiros_res
                            WHERE nro_cuenta = ct.nro_cuenta;
                        EXCEPTION
                           WHEN OTHERS THEN
                              v_dia_mora := 0;
                        END;
                        pag_cta.PR_OBT_CUENTA(ct.nro_cuenta);
                        -- control de error en saldos
                        IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
                           prg_obt_sal_atm_cierre(ct.nro_cuenta,
                                                  pag_cta.g_ctas.sal_disponible,
                                                  pag_cta.g_ctas.sal_actual,
                                                  pag_cta.g_ctas.sal_retenido,
                                                  pag_cta.g_ctas.sal_bloqueado,
                                                  v_error,
                                                  v_msj_error);
                        END IF;
                        --
                        v_monto1          := pag_cta.g_ctas.sal_actual;
                        v_monto2          := pag_cta.g_ctas.sal_disponible;
                        v_monto3          := pag_cta.g_ctas.sal_retenido + pag_cta.g_ctas.mto_cre_a_confirmar;
                        v_monto4          := paw_uti.lf_for_money(pag_cta.FU_OBT_LIN_SOBREGIRO(ct.nro_cuenta, v_fec_actual));
                        v_val_tasa        := pag_cta.g_ctas.val_tasa;
                        v_fec_inicio      := pag_cta.g_ctas.fec_apertura;
                        v_fec_vencimiento := pag_cta.g_ctas.fec_vencimiento;
                        v_che_devuelto    := 'N';
                     END IF;
                     IF (ct.cod_modulo = 4 AND ct.cod_modalidad = 41) OR (ct.cod_modulo = 3 AND ct.cod_modalidad = 31) THEN
                        BEGIN
                           SELECT nro_celular, estado
                           INTO detalleCuenta.dato1, detalleCuenta.dato2
                           FROM bw_cta_telefonos
                           WHERE nro_cuenta = ct.nro_cuenta
                           AND estado <> 'I';
                        EXCEPTION
                           WHEN OTHERS THEN
                              detalleCuenta.dato1 := NULL;
                              detalleCuenta.dato2 := NULL;
                        END;
                        --verificar que el celular configurado pertenezca a la persona
                        IF detalleCuenta.dato1 IS NOT NULL THEN
                          BEGIN
                            SELECT 'S'
                            INTO v_existe
                            FROM ba_telefonos
                            WHERE cod_persona = p_cod_persona
                            AND AREA||TELEFONO = detalleCuenta.dato1
                            --agregamos el tipo de línea para especificar mas.
                            AND TIP_LINEA = 'C'
                            AND ROWNUM = 1;
                          EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                              detalleCuenta.dato1 := NULL;
                              detalleCuenta.dato2 := 'X'; --estado para configuraciones
                            WHEN OTHERS THEN
                              detalleCuenta.dato1 := NULL;
                              detalleCuenta.dato2 := NULL;
                          END;
                        END IF;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        --p_cod_respuesta := paw_bce.v_cod_cta_inexistente;
                        paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                        paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'cta: '|| ct.nro_cuenta ||', mad:' || ct.cod_modalidad || ', ORA-ERR: ' || SQLERRM || ' ' || paw_uti.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL) || SQLERRM, BITACORA_ERROR);
                  END;
                  IF v_retorno.error = 'N' AND detalleCuenta.tipoCuenta IS NOT NULL THEN
                     IF ct.cod_modulo = 5 THEN
                        --13/08/2015. Para Tarjetas de Crédito, se consulta si es de la Afinidad Gourmet
                        --Resolución de la incidencia DYDMR-2239
                        v_che_devuelto:=PAW_not.lf_es_gourmet(ct.cod_modalidad);
                     ELSE
                        v_che_devuelto := paw_uti.lf_obt_che_devuelto(ct.nro_cuenta);
                     END IF;

                     -- esta bien el dato se carga el detalle
                     detalleCuenta.monto1                  := substr(paw_uti.lf_for_money(v_monto1), 1, 16);
                     detalleCuenta.monto2                  := substr(paw_uti.lf_for_money(v_monto2), 1, 16);
                     detalleCuenta.monto3                  := substr(paw_uti.lf_for_money(v_monto3), 1, 16);
                     detalleCuenta.monto4                  := substr(v_monto4, 1, 16);
                     detalleCuenta.tasa                    := v_val_tasa;
                     detalleCuenta.fechaInicio             := paw_uti.lf_for_date(v_fec_inicio);
                     detalleCuenta.fechaVencimiento        := paw_uti.lf_for_date(v_fec_vencimiento);
                     detalleCuenta.diasMora                := v_dia_mora;
                     detalleCuenta.chequeDevuelto          := substr(v_che_devuelto, 0, 1);
                     detalleCuenta.fechaProximoVencimiento := paw_uti.lf_for_date(v_fec_prox_vcto);
                     detalleCuenta.monto5                  := substr(v_monto5, 1, 16);
                     detalleCuenta.imprimeExtracto         := v_imp_extracto;
                     v_listaCuentas.EXTEND;
                     v_listaCuentas(v_listaCuentas.COUNT) := detalleCuenta;

                  END IF;
               END IF;
               IF v_can_detalles >= 999 THEN
                  EXIT; --XXX
               END IF;
            END;
         END LOOP;
         IF v_can_detalles = 0 THEN
            -- no tiene detalles
            -- p_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
            paw_uti.pr_mensajeUsuario(MSG_OBT_CTADET_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas - Cuenta Inexistente -' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null) ||sqlerrm, BITACORA_ERROR);
         END IF;
      END IF;

      -- registro del movimiento
      paw_uti.lp_reg_operacion(v_nro_cta_especifica /*p_nro_cuenta*/, NULL /*p_cod_moneda */, NULL /*p_monto*/, NULL /*p_nro_cta_contra*/, NULL /*p_cantidad*/, 'Ver Todas' /*p_etiqueta*/, v_ver_todas, /*p_dato*/ NULL, NULL, NULL, NULL, NULL, p_cod_persona, COD_OPERACION, p_cod_persona || p_codCanal, p_codCanal, p_cod_sesion_aux, p_cod_empresa);
      paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas-' || paw_uti.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta,null), BITACORA_SALIDA);
      IF v_retorno.error = 'N' THEN
         -- todo ok, se arma el mensaje de respuesta
         v_retorno.listaCuentas := v_listaCuentas;
         v_retorno.cantCuentas  := v_listaCuentas.Count;
         RETURN v_retorno;
      ELSE
         RETURN v_retorno;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR,v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_uti.pr_insertarBitacora(p_cod_persona, p_codCanal, p_cod_sesion_aux, COD_OPERACION, p_cod_empresa, 'fu_ns_obtenerDetalleCuentas -' || SQLERRM, BITACORA_ERROR);
         RETURN v_retorno;
   END fu_ns_obtDetCtas_Bancard;

BEGIN
  pre_cam_for_numerico('.,');
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END PAW_CAN;
/
