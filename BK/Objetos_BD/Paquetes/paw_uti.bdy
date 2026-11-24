CREATE OR REPLACE PACKAGE BODY IT.PAW_UTI IS

   FUNCTION rellenarDerecha(p_dato     IN VARCHAR2,
                            p_longitud IN NUMBER,
                            p_char     IN CHAR) RETURN VARCHAR2 IS
   BEGIN
      RETURN substr(rpad(nvl(p_dato,p_char),p_longitud,p_char),1,p_longitud);
   END;

   FUNCTION depurarMail(p_string  IN VARCHAR2,
                        maxLength IN NUMBER) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$])', ''), 1, maxLength);
   END;

   -- validar direccion de correo
   FUNCTION fu_validarMail(p_mail IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      IF REGEXP_LIKE(p_mail, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$') THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   /* Permite obtener la Información de Paises, Ciudades y Barrios */
   FUNCTION fu_obtenerDatosGeograficos(p_tipoPedido IN VARCHAR2,
                                       p_codPedido  IN NUMBER DEFAULT NULL,
                                       p_codPais    IN NUMBER DEFAULT NULL) RETURN typ_datosGeograficos IS
      --v_codCanal              VARCHAR2(3) := '999';
      v_retorno               typ_datosGeograficos := typ_datosGeograficos;
      v_cod_aux               VARCHAR2(3);
      v_descripcion           VARCHAR2(35);
      v_listaDatosGeograficos typ_listaDatosGeograficos := typ_listaDatosGeograficos();
      --v_cod_mensaje           VARCHAR2(3) := '222';
      v_retMenRespuesta       typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_detalle               typ_datoGeografico := typ_datoGeografico;
      v_can_detalles          NUMBER(3) := 0;

      --Errores
      MSG_OBTDEPARTAMENTO CONSTANT VARCHAR2(15) := 'OBTDATGEOG_DEP';
      MSG_OBTCIUDAD       CONSTANT VARCHAR2(15) := 'OBTDATGEOG_CIU';
      MSG_OBTBARRIO       CONSTANT VARCHAR2(15) := 'OBTDATGEOG_BAR';
      MSG_SINDATOS        CONSTANT VARCHAR2(15) := 'G_SIN_DATOS';

      FUNCTION lf_obt_departamentos RETURN typ_datosGeograficos IS
         v_ret typ_datosGeograficos := typ_datosGeograficos;
         CURSOR mon_cur IS
            SELECT DISTINCT (m.descripcion) descripcion, m.cod_departamento cod_departamento
              FROM ba_departamentos m
             ORDER BY TRIM(m.descripcion);
      BEGIN
         FOR t IN mon_cur
         LOOP
            BEGIN
               v_can_detalles        := v_can_detalles + 1;
               v_cod_aux             := substr(t.cod_departamento,0, 3);
               v_descripcion         := substr(t.descripcion,0, 35);
               v_detalle.codigo      := v_cod_aux;
               v_detalle.descripcion := v_descripcion;
               v_listaDatosGeograficos.EXTEND;
               v_listaDatosGeograficos(v_listaDatosGeograficos.COUNT) := v_detalle;
            EXCEPTION
               WHEN OTHERS THEN
                  paw_bel.pr_mensajeUsuario(MSG_OBTDEPARTAMENTO, v_ret.nombreRespuesta, v_ret.descripcionRespuesta, v_ret.error);
                  v_retMenRespuesta.error                := v_ret.error;
                  v_retMenRespuesta.nombreRespuesta      := v_ret.nombreRespuesta;
                  v_retMenRespuesta.descripcionRespuesta := v_ret.descripcionRespuesta;
                  --pr_insertarBitacora('0', v_codCanal, NULL, v_tip_mensaje, NULL, SQLERRM || 'Obtener datos geograficos - Tipo pedido: ' || p_tipoPedido || ' Código: ' || p_codPedido ||fu_generarBitacora(v_retMenRespuesta.error,v_retMenRespuesta.nombreRespuesta, v_retMenRespuesta.descripcionRespuesta,null ), BITACORA_ERROR);
                  RETURN v_ret;
            END;
         END LOOP;
         v_ret.cantDatos             := v_can_detalles;
         v_ret.listaDatosGeograficos := v_listaDatosGeograficos;
         RETURN v_ret;
      END lf_obt_departamentos;

      --obtiene todas las ciudades de un departamento
      FUNCTION lf_obt_ciudades(p_codigoPais IN NUMBER) RETURN typ_datosGeograficos IS
         v_ret typ_datosGeograficos := typ_datosGeograficos;
         CURSOR mon_cur IS
            SELECT COD_CIUDAD, DESCRIPCION
              FROM ba_ciudades
             WHERE cod_pais = p_codigoPais
             ORDER BY TRIM(descripcion);
      BEGIN
         FOR t IN mon_cur
         LOOP
            BEGIN
               v_can_detalles        := v_can_detalles + 1;
               v_cod_aux             := substr(t.cod_ciudad,0, 3);
               v_descripcion         := substr(t.descripcion,0, 35);
               v_detalle.codigo      := v_cod_aux;
               v_detalle.descripcion := v_descripcion;
               v_listaDatosGeograficos.EXTEND;
               v_listaDatosGeograficos(v_listaDatosGeograficos.COUNT) := v_detalle;
            EXCEPTION
               WHEN OTHERS THEN
                  paw_bel.pr_mensajeUsuario(MSG_OBTCIUDAD, v_ret.nombreRespuesta, v_ret.descripcionRespuesta, v_ret.error);
                  v_retMenRespuesta.error                := v_ret.error;
                  v_retMenRespuesta.nombreRespuesta      := v_ret.nombreRespuesta;
                  v_retMenRespuesta.descripcionRespuesta := v_ret.descripcionRespuesta;
                  --pr_insertarBitacora('0', v_codCanal, NULL, v_tip_mensaje, NULL, SQLERRM || 'Obtener datos geograficos - Tipo pedido: ' || p_tipoPedido || ' Código: ' || p_codPedido ||fu_generarBitacora(v_retMenRespuesta.error,v_retMenRespuesta.nombreRespuesta, v_retMenRespuesta.descripcionRespuesta,null ), BITACORA_ERROR);
                  RETURN v_ret;
            END;
         END LOOP;
         v_ret.cantDatos             := v_can_detalles;
         v_ret.listaDatosGeograficos := v_listaDatosGeograficos;
         RETURN v_ret;
      END lf_obt_ciudades;
      --obtiene todos los barrios de una ciudad
      FUNCTION lf_obt_barrios(p_ciudad IN NUMBER, p_pais IN NUMBER) RETURN typ_datosGeograficos IS
         v_ret typ_datosGeograficos := typ_datosGeograficos;
         CURSOR mon_cur IS
            SELECT COD_BARRIO, DESCRIPCION
              FROM BA_BARRIOS
             WHERE COD_CIUDAD = p_ciudad
              AND  COD_PAIS = NVL(p_pais, 1) -- Por defecto Paraguay
             ORDER BY TRIM(DESCRIPCION);
      BEGIN
         FOR t IN mon_cur
         LOOP
            BEGIN
               v_can_detalles := v_can_detalles + 1;

               v_cod_aux             := substr(t.cod_barrio,0, 3);
               v_descripcion         := substr(t.descripcion,0, 35);
               v_detalle.codigo      := v_cod_aux;
               v_detalle.descripcion := v_descripcion;
               v_listaDatosGeograficos.EXTEND;
               v_listaDatosGeograficos(v_listaDatosGeograficos.COUNT) := v_detalle;
            EXCEPTION
               WHEN OTHERS THEN
                  paw_bel.pr_mensajeUsuario(MSG_OBTBARRIO, v_ret.nombreRespuesta, v_ret.descripcionRespuesta, v_ret.error);
                  v_retMenRespuesta.error                := v_ret.error;
                  v_retMenRespuesta.nombreRespuesta      := v_ret.nombreRespuesta;
                  v_retMenRespuesta.descripcionRespuesta := v_ret.descripcionRespuesta;
                  --pr_insertarBitacora('0', v_codCanal, NULL, v_tip_mensaje, NULL, SQLERRM || 'Obtener datos geograficos - Tipo pedido: ' || p_tipoPedido || ' Código: ' || p_codPedido ||fu_generarBitacora(v_retMenRespuesta.error,v_retMenRespuesta.nombreRespuesta, v_retMenRespuesta.descripcionRespuesta,null ), BITACORA_ERROR);
                  RETURN v_ret;
            END;
         END LOOP;
         v_ret.cantDatos             := v_can_detalles;
         v_ret.listaDatosGeograficos := v_listaDatosGeograficos;
         RETURN v_ret;
      END lf_obt_barrios;
      --
      FUNCTION lf_obt_paises RETURN typ_datosGeograficos IS
         v_ret typ_datosGeograficos := typ_datosGeograficos;
         CURSOR c_paises IS
            SELECT p.cod_pais, p.descripcion
              FROM ba_paises p
             ORDER BY DESCRIPCION;
      BEGIN
         FOR t IN c_paises
         LOOP
            BEGIN
               v_can_detalles := v_can_detalles + 1;

               v_cod_aux             := substr(t.cod_pais,0, 3);
               v_descripcion         := substr(t.descripcion,0, 35);
               v_detalle.codigo      := v_cod_aux;
               v_detalle.descripcion := v_descripcion;
               v_listaDatosGeograficos.EXTEND;
               v_listaDatosGeograficos(v_listaDatosGeograficos.COUNT) := v_detalle;
            EXCEPTION
               WHEN OTHERS THEN
                  paw_bel.pr_mensajeUsuario(MSG_OBTBARRIO, v_ret.nombreRespuesta, v_ret.descripcionRespuesta, v_ret.error);
                  v_retMenRespuesta.error                := v_ret.error;
                  v_retMenRespuesta.nombreRespuesta      := v_ret.nombreRespuesta;
                  v_retMenRespuesta.descripcionRespuesta := v_ret.descripcionRespuesta;
                  --pr_insertarBitacora('0', v_codCanal, NULL, v_tip_mensaje, NULL, SQLERRM || 'Obtener datos geograficos - Tipo pedido: ' || p_tipoPedido || ' Código: ' || p_codPedido ||fu_generarBitacora(v_retMenRespuesta.error,v_retMenRespuesta.nombreRespuesta, v_retMenRespuesta.descripcionRespuesta,null ), BITACORA_ERROR);
                  RETURN v_ret;
            END;
         END LOOP;
         v_ret.cantDatos             := v_can_detalles;
         v_ret.listaDatosGeograficos := v_listaDatosGeograficos;
         RETURN v_ret;
      END lf_obt_paises;
   BEGIN
      CASE p_tipoPedido
         WHEN 'D' THEN
            v_retorno := lf_obt_departamentos;
         WHEN 'C' THEN
            v_retorno := lf_obt_ciudades(p_codPedido);
         WHEN 'B' THEN
            v_retorno := lf_obt_barrios(p_codPedido, p_codPais);
         WHEN 'P' THEN
            v_retorno := lf_obt_paises;
      END CASE;

      IF v_retorno.cantDatos = 0 OR v_retorno.cantDatos IS NULL THEN
         paw_bel.pr_mensajeUsuario(MSG_SINDATOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSE
         paw_bel.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;

      v_retMenRespuesta.error                := v_retorno.error;
      v_retMenRespuesta.nombreRespuesta      := v_retorno.nombreRespuesta;
      v_retMenRespuesta.descripcionRespuesta := v_retorno.descripcionRespuesta;
      --pr_insertarBitacora('0', v_codCanal, NULL, v_tip_mensaje, NULL, 'Obtener datos geograficos - Tipo pedido: ' || p_tipoPedido || ' Código: ' || p_codPedido || fu_generarBitacora(v_retMenRespuesta.error,v_retMenRespuesta.nombreRespuesta, v_retMenRespuesta.descripcionRespuesta,null ), BITACORA_ENTRADA);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         v_retMenRespuesta.error                := v_retorno.error;
         v_retMenRespuesta.nombreRespuesta      := v_retorno.nombreRespuesta;
         v_retMenRespuesta.descripcionRespuesta := v_retorno.descripcionRespuesta;
         --pr_insertarBitacora('0', v_codCanal, NULL, v_tip_mensaje, NULL, SQLERRM || 'Obtener datos geograficos - Tipo pedido: ' || p_tipoPedido || ' Código: ' || p_codPedido || fu_generarBitacora(v_retMenRespuesta.error,v_retMenRespuesta.nombreRespuesta, v_retMenRespuesta.descripcionRespuesta,null ), BITACORA_ERROR);
         RETURN v_retorno;
   END fu_obtenerDatosGeograficos;

   -- tipos de documentos para personas fisicas
   FUNCTION fu_tipDocumentos(p_tipoPersona IN VARCHAR2 DEFAULT NULL) RETURN typ_listaconsultadocumentos IS
      v_retorno   typ_listaconsultadocumentos := typ_listaconsultadocumentos();
      v_documento typ_detalleConsultaDocumentos := typ_detalleConsultaDocumentos();
      CURSOR c_documentos IS
         SELECT *
           FROM ba_tip_documentos d
          WHERE d.estado = 'A'
            AND (d.tip_persona = nvl(p_tipoPersona, d.tip_persona) OR d.tip_persona = 'A');
   BEGIN
      FOR doc IN c_documentos LOOP
         v_documento.codigoTipoDocumento      := substr(doc.cod_tip_documento, 1, 3);
         v_documento.abreviaturaTipoDocumento := substr(doc.abreviatura, 1, 200);

         v_retorno.extend;
         v_retorno(v_retorno.count) := v_documento;
      END LOOP;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END fu_tipDocumentos;

   -- tipos de documentos para personas fisicas
   FUNCTION fu_profesiones RETURN typ_listaconsultadocumentos IS
      v_retorno   typ_listaconsultadocumentos := typ_listaconsultadocumentos();
      v_documento typ_detalleConsultaDocumentos := typ_detalleConsultaDocumentos();
      CURSOR c_profesiones IS
         SELECT *
           FROM ba_profesiones p
       ORDER BY descripcion;
   BEGIN
      FOR pro IN c_profesiones LOOP
         v_documento.codigoTipoDocumento      := substr(pro.cod_profesion, 1, 3);
         v_documento.abreviaturaTipoDocumento := substr(pro.descripcion, 1, 200);

         v_retorno.extend;
         v_retorno(v_retorno.count) := v_documento;
      END LOOP;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END fu_profesiones;

   -- obtener un campo de una cadena
   FUNCTION fu_obt_campo(p_cadena    IN VARCHAR2,
                         p_orden     IN NUMBER,
                         p_separador IN VARCHAR2) RETURN VARCHAR2 IS
      v_posicion NUMBER;
      v_fin      NUMBER;
      v_inicio   NUMBER;
   BEGIN
      v_posicion := instr(p_cadena, p_separador);
      v_fin      := length(p_cadena);

      IF p_orden = 1 THEN
         v_inicio := 1;
         IF v_posicion > 0 THEN
            v_fin := v_posicion;
         END IF;
      ELSE
         v_inicio := v_posicion + 1;
         IF v_posicion < 1 THEN
            v_fin := 0;
         END IF;
      END IF;

      RETURN TRIM(SUBSTR(p_cadena, v_inicio, v_fin));
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- obtener significado ba_cod_referencias
   FUNCTION fu_obtenerCodigoReferencia(p_dominio IN VARCHAR2,
                                       p_valor IN VARCHAR2) RETURN VARCHAR2 IS
      v_referencia ba_cod_referencias.abreviatura%type;
   BEGIN
      select abreviatura
        into v_referencia
        from ba_cod_referencias
       where dominio    = p_dominio
         and val_minimo = p_valor;
      return v_referencia;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- validar abreviatura de tipo de documento
   FUNCTION fu_validarTipoDocumento(p_tipo IN VARCHAR2) RETURN VARCHAR2 IS
      v_cod_tip_documento ba_tip_documentos.cod_tip_documento%type;
   BEGIN
      select cod_tip_documento
        into v_cod_tip_documento
       from ba_tip_documentos
      where abreviatura = p_tipo;
      return v_cod_tip_documento;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   -- convertir fecha a string
   FUNCTION fu_fec_char(p_fecha IN DATE, p_formato IN NUMBER) RETURN VARCHAR2 IS
      v_formato VARCHAR2(20);
   BEGIN
      CASE p_formato
         WHEN 0 THEN v_formato := 'ddmmyyyy';
         WHEN 1 THEN v_formato := 'yyyymmdd';
         WHEN 2 THEN v_formato := 'dd/mm/yyyy';
         WHEN 3 THEN v_formato := 'yyyy/mm/dd';
         ELSE v_formato := 'dd-mm-yyyy';
      END CASE;

      return to_char(p_fecha, v_formato);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
  -- convertir string a fecha
   FUNCTION fu_str_fecha(p_fecha IN VARCHAR2, p_formato IN NUMBER) RETURN DATE IS
      v_formato VARCHAR2(20);
   BEGIN
      CASE p_formato
         WHEN 0 THEN v_formato := 'ddmmyyyy';
         WHEN 1 THEN v_formato := 'yyyymmdd';
         WHEN 2 THEN v_formato := 'dd/mm/yyyy';
         WHEN 3 THEN v_formato := 'yyyy/mm/dd';
         ELSE v_formato := 'dd-mm-yyyy';
      END CASE;

      return to_date(p_fecha, v_formato);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
     /**
    * Funcion para depurar un varchar2 a number
    * @param p_numero Numero a convertir
    * @param p_longitud Longitud maxima a convertir
    * @param p_formato 0: 1200000.23 1: 1200000,23
   */
   -- depurar varchar2 a number
   FUNCTION fu_for_number(p_numero   IN VARCHAR2,
                          p_longitud IN NUMBER,
                          p_formato  IN NUMBER DEFAULT 0) RETURN NUMBER IS
      v_retorno ge_movimientos.monto%TYPE := NULL;
      v_cadena  VARCHAR2(20);
   BEGIN
      IF p_longitud > 20 THEN
         RETURN NULL;
      END IF;
      v_cadena := SUBSTR(REGEXP_REPLACE(TRIM(p_numero), '([^[0-9.,]])', ''), 1, p_longitud);
      IF nvl(p_formato, 0) = 0 THEN
         v_retorno := replace(replace(v_cadena, '.', ''), ',', '.');
      ELSIF p_formato = 1 THEN
         v_retorno := replace(v_cadena, '.', '');
      END IF;

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- Funcion para validar que un numero tenga prefijo celular
   FUNCTION fu_val_celular(p_numero IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      IF REGEXP_LIKE(p_numero, '^09[6-9][1-9][0-9]{6,}') THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

      -- Funcion para validar que un numero tenga prefijo celular
   FUNCTION fu_val_telefono(p_numero IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      IF REGEXP_LIKE(p_numero, '[0-9]{5,}') AND fu_val_celular(p_numero) = 'N' THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   -- cargar un item en List<etiquetaValor>
   PROCEDURE pr_add_value(p_lista IN OUT typ_listaetiquetavalor,
                          p_tag   IN VARCHAR2,
                          p_value IN VARCHAR2) IS
       v_etiqueta typ_etiquetaValor := typ_etiquetaValor();
   BEGIN
      IF p_value IS NOT NULL AND p_tag IS NOT NULL THEN
         v_etiqueta.etiqueta := substr(p_tag, 1, 120);
         v_etiqueta.valor    := substr(p_value, 1, 2000);
         p_lista.extend;
         p_lista(p_lista.count) := v_etiqueta;
      END IF;
   END;

   --
   PROCEDURE pr_add_value(p_lista IN OUT typ_listaclavevalor,
                          p_tag   IN VARCHAR2,
                          p_value IN VARCHAR2,
                          p_tipo  IN VARCHAR2) IS
       v_etiqueta typ_clavevalor := typ_clavevalor();
   BEGIN
      IF p_value IS NOT NULL AND p_tag IS NOT NULL THEN
         v_etiqueta.clave := depurarTextos(p_tag, 50);
         v_etiqueta.valor    := depurarTextos(p_value, 300);
         v_etiqueta.tipo    := depurarTextos(p_tipo, 100);
         p_lista.extend;
         p_lista(p_lista.count) := v_etiqueta;
      END IF;
   END;

   -- indica si un cliente imprime su extracto de cuenta cc/ah
   FUNCTION fu_imp_extracto(p_cod_persona IN ge_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_retorno VARCHAR2(1) := 'N';
   BEGIN
      -- obtenemos el tipo de extracto por cliente
      SELECT decode(c.tip_extracto, 'C', 'S' -- C-Impreso
                                  , 'Z', 'N' -- Z-x Mail
                                  , 'X', 'S' -- X-Envío x mail e impreso
                                  , 'N') -- No impreso
        INTO v_retorno
        FROM ge_clientes c
       WHERE c.cod_persona = p_cod_persona;

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'N';
   END;

   -- Funcion para obtener el mensaje parametrizado del extracto
   FUNCTION fu_msg_extracto(p_fecha_cierre IN DATE) RETURN VARCHAR2 IS
      v_retorno VARCHAR2(1000);
   BEGIN
      SELECT mensaje
      INTO v_retorno
      FROM ge_msj_extractos
      WHERE trunc(fec_extracto) = p_fecha_cierre
      AND ROWNUM = 1;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN ' ';
   END;

    --S si la modalidad pertenece a las tarjetas prepagas
   FUNCTION fu_es_prepaga(p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE) RETURN VARCHAR2 IS
      v_cod_respuesta VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_cod_respuesta
           FROM ba_cod_referencias
          WHERE dominio = 'TAR_MAD_PREPAGA'
            AND val_minimo = p_cod_modalidad;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 'N';
      END;
      RETURN v_cod_respuesta;
   END;

 FUNCTION fu_val_cuenta(p_codpersona IN ge_clientes.cod_persona%TYPE,
                        p_nrocuenta IN ge_cuentas.nro_cuenta%TYPE,
                        p_codmodulo IN ge_cuentas.cod_modulo%TYPE,
                        p_modalidad IN ge_cuentas.cod_modalidad%TYPE,
                        p_relacion IN ge_cta_clientes.relacion%TYPE) RETURN typ_mensajerespuesta IS
   v_relacion  ge_cta_clientes.relacion%TYPE := NULL;
   v_codmodulo ge_cuentas.cod_modulo%TYPE;
   v_modalidad ge_cuentas.cod_modalidad%TYPE;
   v_respuesta typ_mensajerespuesta := typ_mensajerespuesta();
   OBTCTADET_CTAIX VARCHAR2(15):='OBTCTADET_CTAIX';
 BEGIN

   paw_bel.pr_mensajeusuario(msg_ok, v_respuesta.nombrerespuesta, v_respuesta.descripcionrespuesta, v_respuesta.error);

   BEGIN
     SELECT ge_cuentas.cod_modulo, ge_cuentas.cod_modalidad, ge_cta_clientes.relacion
     INTO v_codmodulo, v_modalidad, v_relacion
     FROM ge_cuentas, ge_cta_clientes
     WHERE ge_cuentas.nro_cuenta = ge_cta_clientes.nro_cuenta
     AND ge_cta_clientes.cod_persona = p_codpersona
     AND ge_cuentas.nro_cuenta = p_nrocuenta;
   EXCEPTION
     WHEN OTHERS THEN
       paw_bel.pr_mensajeusuario(OBTCTADET_CTAIX, v_respuesta.nombrerespuesta, v_respuesta.descripcionrespuesta, v_respuesta.error);
       RETURN v_respuesta;
   END;

   IF (NOT p_codmodulo IS NULL AND p_codmodulo <> v_codmodulo) THEN
     paw_bel.pr_mensajeusuario(OBTCTADET_CTAIX, v_respuesta.nombrerespuesta, v_respuesta.descripcionrespuesta, v_respuesta.error);
     v_respuesta.error:= 'M';
     RETURN v_respuesta;
   END IF;
   IF (NOT p_modalidad IS NULL AND p_modalidad <> v_modalidad) THEN
     paw_bel.pr_mensajeusuario(OBTCTADET_CTAIX, v_respuesta.nombrerespuesta, v_respuesta.descripcionrespuesta, v_respuesta.error);
      v_respuesta.error:= 'O';
     RETURN v_respuesta; --'O';
   END IF;
   IF (NOT p_relacion IS NULL AND p_relacion <> v_relacion) THEN
     paw_bel.pr_mensajeusuario(OBTCTADET_CTAIX, v_respuesta.nombrerespuesta, v_respuesta.descripcionrespuesta, v_respuesta.error);
     v_respuesta.error:= 'Y';
     RETURN v_respuesta;
   END IF;
   RETURN v_respuesta;
 END;
   FUNCTION depurarAlfanumerico(p_string IN VARCHAR2, maxLength IN NUMBER, p_espacio IN CHAR DEFAULT 'N') RETURN VARCHAR2 IS
   BEGIN
      IF p_espacio = 'N' THEN
         RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:]])', ''), 1, maxLength);
      ELSE
         RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:][:space:]])', ''), 1, maxLength);
      END IF;
   END;
   FUNCTION depurarTextos(p_string IN VARCHAR2, maxLength IN NUMBER, p_documento IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2 IS
   BEGIN
      IF p_documento = 'N' THEN
         --texto
         RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^0-9A-Za-z ,./_-])', ''), 1, maxLength);
      ELSE
         --documento
         RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^0-9A-Za-z-])', ''), 1, maxLength);
      END IF;
   END;
   FUNCTION depurarNumerico(p_string IN VARCHAR2, maxLength IN NUMBER) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:digit:]])', ''), 1, maxLength);
   END;
   /** Obtiene un mensaje de la base de datos por el nombre del mensaje
   * @param p_mensaje Nombre del mensaje
   * @return p_nombreMensaje Nombre del mensaje
   * @return p_descripcionMensaje Descripción del mensaje
   * @return p_error Indicador de si es o no un mensaje de error
   */
   PROCEDURE pr_mensajeUsuario(mensaje IN VARCHAR2, nombreMensaje OUT VARCHAR2, descripcionMensaje OUT VARCHAR2, error OUT VARCHAR2) IS
      v_error VARCHAR2(1) := 'S';
   BEGIN
      BEGIN
         SELECT a.nombre, a.des_mensaje, a.error
           INTO nombreMensaje, descripcionMensaje, v_error
           FROM bw_men_respuesta a
          WHERE a.nombre = mensaje;
      EXCEPTION
         WHEN no_data_found THEN
            descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado';
         WHEN OTHERS THEN
            descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado';
      END;
      error := v_error;
   END;
   -- Convertir a moneda
   PROCEDURE pr_con_mon_a_moneda(p_cod_mon_original IN ba_monedas.cod_moneda%TYPE, p_cod_mon_destino IN ba_monedas.cod_moneda%TYPE,
                                 p_mto_mon_original IN NUMBER, p_mto_mon_destino OUT NUMBER, p_cot_mon_original IN OUT NUMBER,
                                 p_cot_mon_destino IN OUT NUMBER, p_interbancaria IN VARCHAR2 DEFAULT NULL) IS
      v_lugar         VARCHAR2(100);
      v_cod_mon_local ba_monedas.cod_moneda%TYPE := nvl(pag_gen.fu_obt_mon_local, 'GS');
      -- obtener cotizacion para operaciones via banca electronica
      FUNCTION lf_obt_cotizacion(p_cod_moneda IN ba_monedas.cod_moneda%TYPE, p_tipo IN VARCHAR2
                                 -- C-COMPRA o V-VENTA
                                 ) RETURN NUMBER IS
         v_fec_actual DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
         v_cotizacion ge_cotizaciones.val_conversion%TYPE;
      BEGIN
         SELECT decode(p_tipo, 'C', val_com_electronica, 'V', val_ven_electronica, NULL)
           INTO v_cotizacion
           FROM ge_cotizaciones a
          WHERE fecha = (SELECT MAX(fecha)
                           FROM ge_cotizaciones
                          WHERE cod_moneda = a.cod_moneda
                            AND fecha <= v_fec_actual)
            AND cod_moneda = p_cod_moneda;
         RETURN v_cotizacion;
      EXCEPTION
         WHEN no_data_found THEN
            RETURN NULL;
         WHEN OTHERS THEN
            RETURN NULL;
      END;
      -- fin fu_obt_cotizacion
   BEGIN
      v_lugar := 'obtener moneda base';
      IF p_cod_mon_original = p_cod_mon_destino THEN
         p_mto_mon_destino := p_mto_mon_original;
         IF p_cod_mon_original <> v_cod_mon_local THEN
            p_cot_mon_destino  := nvl(p_cot_mon_original, pag_gen.fu_obt_cotizacion(p_cod_mon_original));
            p_cot_mon_original := p_cot_mon_destino;
         ELSE
            p_cot_mon_destino  := 1;
            p_cot_mon_original := 1;
         END IF;
      ELSE
         IF nvl(p_interbancaria, 'N') = 'N' THEN
            IF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino = v_cod_mon_local THEN
               --convertir moneda original a base o destino
               p_cot_mon_original := nvl(p_cot_mon_original, lf_obt_cotizacion(p_cod_mon_original, 'C' /*COMPRA*/));
               p_cot_mon_destino  := 1;
               p_mto_mon_destino  := round(p_mto_mon_original * p_cot_mon_original, 0);
            ELSIF p_cod_mon_original = v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               -- pasar moneda original a moneda base
               p_cot_mon_original := 1;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, lf_obt_cotizacion(p_cod_mon_destino, 'V' /*VENTA */));
               p_mto_mon_destino  := round(p_mto_mon_original / p_cot_mon_destino, 2);
            ELSIF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               p_cot_mon_original := nvl(p_cot_mon_original, lf_obt_cotizacion(p_cod_mon_original, 'C' /*COMPRA*/));
               p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, lf_obt_cotizacion(p_cod_mon_destino, 'V' /*VENTA */));
               p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino, 2);
            END IF;
         ELSE
            --SNP
            IF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino = v_cod_mon_local THEN
               --convertir moneda original a base o destino
               p_cot_mon_original := nvl(p_cot_mon_original, paw_bce.fu_obt_cotizacion(p_cod_mon_original, 'V' /*VENTA*/));
               p_cot_mon_destino  := 1;
               p_mto_mon_destino  := round(p_mto_mon_original * p_cot_mon_original, 0);
            ELSIF p_cod_mon_original = v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               -- pasar moneda original a moneda base
               p_cot_mon_original := 1;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, paw_bce.fu_obt_cotizacion(p_cod_mon_destino, 'C' /*COMPRA*/));
               p_mto_mon_destino  := round(p_mto_mon_original / p_cot_mon_destino, 2);
            ELSIF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               p_cot_mon_original := nvl(p_cot_mon_original, paw_bce.fu_obt_cotizacion(p_cod_mon_original, 'V' /*VENTA*/));
               p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, paw_bce.fu_obt_cotizacion(p_cod_mon_destino, 'C' /*COMPRA*/));
               p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino, 2);
            END IF;
            --SNP
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_lugar || ' - ' || SQLERRM);
   END;

   /*Devuelve la cuenta en formato IT - Cuenta Bepsa*/
   FUNCTION fu_ver_cuenta(p_cta IN VARCHAR2) RETURN VARCHAR2 IS
       v_cta VARCHAR2(15);
   BEGIN
      v_cta := p_cta;
      IF substr(p_cta, 3, 6) IN ('210100', '215000') THEN
         v_cta := (substr(p_cta, 1, 2) || '01' || substr(p_cta, 9, 6));
      ELSIF substr(p_cta, 3, 6) IN ('210500', '215500') THEN
         v_cta := (substr(p_cta, 1, 2) || '02' || substr(p_cta, 9, 6));
      END IF;
      RETURN v_cta;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN p_cta;
   END;

   /*Devuelve la cuenta en formato IT - Cuenta Bancard*/
   FUNCTION fu_for_cuenta(p_cta IN VARCHAR2) RETURN VARCHAR2 IS
      v_tip_cuenta VARCHAR2(2);
      v_cta        VARCHAR2(10);
   BEGIN
      v_cta        := substr(lpad(TRIM(p_cta), 10, '0'), -10);
      v_tip_cuenta := substr(v_cta, 4, 1);
      IF v_tip_cuenta IN ('1', '3') THEN
         v_tip_cuenta := '01';
         v_cta        := substr(v_cta, 2, 2) || v_tip_cuenta || substr(v_cta, -6);
      ELSIF v_tip_cuenta IN ('2', '4') THEN
         v_tip_cuenta := '02';
         v_cta        := substr(v_cta, 2, 2) || v_tip_cuenta || substr(v_cta, -6);
      END IF;
      RETURN v_cta;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN p_cta;
   END;
   /* Verifica si existe Banco */
   FUNCTION fu_exi_banco(p_cod_banco NUMBER) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_par_entes p, ge_entes e
          WHERE p.parametro = 'COD_ENT_FINANCIERA'
            AND p.cod_ente = e.cod_ente
            AND p.val_parametro = p_cod_banco
            AND e.tipo = 'FI';
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
      IF nvl(v_existe, 'N') = 'N' THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ge_bancos
             WHERE cod_banco = p_cod_banco
               AND estado = 'A'
               AND ubicacion = 'L';
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               RETURN v_existe;
         END;
      END IF;
      RETURN v_existe;
   END fu_exi_banco;
   /* Verifica si existe Financiera */
   FUNCTION fu_exi_financiera(p_cod_ente NUMBER) RETURN VARCHAR2 IS
      v_existe VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_par_entes p, ge_entes e
          WHERE p.parametro = 'COD_ENT_FINANCIERA'
            AND p.cod_ente = e.cod_ente
            AND p.val_parametro = p_cod_ente
            AND e.tipo = 'FI';
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
      RETURN v_existe;
   END fu_exi_financiera;

   PROCEDURE pr_insertarBitacora(p_codigoPersona IN VARCHAR2 DEFAULT NULL,
                                 p_codigoCanal   IN VARCHAR2 DEFAULT NULL,
                                 p_codSesion     IN VARCHAR2 DEFAULT NULL,
                                 p_tipoMensaje   IN VARCHAR2 DEFAULT NULL,
                                 p_codigoEmpresa IN VARCHAR2 DEFAULT NULL,
                                 p_datos         IN VARCHAR2 DEFAULT NULL,
                                 p_tipo          IN VARCHAR2 DEFAULT NULL) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO bw_bitacoras
         (COD_PERSONA, COD_CANAL, COD_SESION, COD_TIP_MENSAJE, COD_PER_VINCULADA, DATO, TIPO)
      VALUES
          (SUBSTR(p_codigoPersona, 1, 10), SUBSTR(NVL(p_codigoCanal, '0'), 1, 3), SUBSTR(p_codSesion, 1 ,32), SUBSTR(NVL(p_tipoMensaje,'0'), 1, 3), SUBSTR(p_codigoEmpresa, 1, 10),
         SUBSTR(p_datos, 1, 4000), p_tipo);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   FUNCTION fu_obt_codPersona(p_nro_documento IN VARCHAR2) RETURN VARCHAR2 IS
     v_retorno VARCHAR2(15):='';
   BEGIN
     BEGIN
       SELECT c.cod_persona
       INTO v_retorno
       FROM ge_clientes c, ba_personas p
       WHERE p.cod_persona = c.cod_persona
       AND p.nro_documento = p_nro_documento;
     EXCEPTION
       WHEN OTHERS THEN
         v_retorno := 'N';
     END;
     RETURN v_retorno;
   END;

   FUNCTION fu_apertura_cuenta_pre(p_sesion IN VARCHAR2,p_cod_persona IN ge_clientes.cod_persona%TYPE, p_codigoCanal IN VARCHAR2) RETURN TYP_CUENTAGENERADA IS
         v_nro_cuenta ge_cuentas.nro_cuenta%TYPE;
         v_cod_campanha ge_pro_pre_aprobados.cod_campana%TYPE;
         v_cod_ofi_cliente ge_clientes.cod_oficina%TYPE;
         v_fecha_creacion_cuenta ge_cuentas.fec_apertura%TYPE;
         v_cta_estado      ge_cuentas.estado%TYPE;
         v_cta_modalidad   ge_cuentas.cod_modalidad%TYPE;
         v_cta_modulo      ge_cuentas.cod_modulo%TYPE;
         ty_cta_generada   TYP_CUENTAGENERADA;
   begin
     ty_cta_generada := TYP_CUENTAGENERADA();
     ty_cta_generada.error := 'N';
			    -- SI NO POSEE CUENTA
              --SE OBTIENE CODIGO DE OFICINA DEL CLIENTE
              BEGIN
                  Select a.cod_oficina
                  into v_cod_ofi_cliente
                  from ge_clientes a where a.cod_persona = p_cod_persona;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     v_cod_ofi_cliente := 31;
               END;
               --SE OBTIENE CODIGO DE CAMPA¿A
               BEGIN
                  Select cod_campana
                  into v_cod_campanha
                  from ge_pro_pre_aprobados a
                  where a.estado ='V'
                  AND cod_persona = p_cod_persona
                  and cod_modulo = '6'
                  and a.ind_hab_hb ='S'
                  and cod_modalidad ='68'
                  and ROWNUM <= 1;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     v_cod_campanha := null;
               END;
               --SE CREA UNA CUENTA NUEVA
               BEGIN
                 dbms_output.put_line('Nro de Cuenta: ' || v_nro_cuenta);
                 pra_gen_cta_vista(p_cod_persona,
                                   v_cod_ofi_cliente,
                                   pag_gen.fu_obt_mon_local,
                                   p_codigoCanal,
                                   v_cod_campanha,
                                   v_nro_cuenta);
                                   --commit;
               EXCEPTION
                 WHEN OTHERS THEN
                 paw_bel.pr_insertarBitacora(p_cod_persona, p_codigoCanal, p_sesion, '100', p_cod_persona, 'Error al generar cuenta para desembolso de prestamos', BITACORA_ERROR);
                 ty_cta_generada.error := 'S';
                 --pr_insertarBitacora(v_usu_sesion.codigoPersona, p_codigoCanal, p_sesion, v_cod_operacion, v_usu_sesion.codigoEmpresa, v_msj_bitacora|| ' ' ||fu_generarbitacora('S','', '',null), BITACORA_ERROR);
               END;
               PRAGMA AUTONOMOUS_TRANSACTION;
               BEGIN
                  select a.fec_insercion, a.estado, a.cod_modulo, a.cod_modalidad
                  into v_fecha_creacion_cuenta, v_cta_estado, v_cta_modulo, v_cta_modalidad
                  from ah_cta_vistas a
                  where a.nro_cuenta = v_nro_cuenta;
               END;
               ty_cta_generada.NRO_CUENTA := v_nro_cuenta;
               ty_cta_generada.FECHA_APERTURA := v_fecha_creacion_cuenta;
               ty_cta_generada.COD_MODALIDAD := v_cta_modalidad;
               ty_cta_generada.COD_MODULO := v_cta_modulo;
               ty_cta_generada.ESTADO := v_cta_estado;
               return ty_cta_generada;
     end;

  FUNCTION fu_generarBitacora(error in varchar2, nombreRespuesta in varchar2 ,descripcionRespuesta in varchar2, mensajesAdicionales in varchar2 := NULL) RETURN VARCHAR2 IS
      v_linea    VARCHAR2(1000);
      v_paquete  VARCHAR2(1000);
      v_llamador VARCHAR2(1000);
      v_duenho   VARCHAR2(1000);
   BEGIN
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
      RETURN v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV', 'SESSION_USER') || ' Ip:' || sys_context('USERENV', 'IP_ADDRESS') || ' isDBA:' || sys_context('USERENV', 'ISDBA') || ' Error:' ||(CASE error WHEN 'S' THEN 'T' WHEN 'N' THEN 'F' END) || ' nombreRespuesta:' || nombreRespuesta || ' descripcionRespuesta:' || descripcionRespuesta||' a:'||mensajesAdicionales;
   END fu_generarBitacora;

   /** Determina si la persona es una persona Juridica
   */
   FUNCTION fu_es_juridica(p_numeroCuenta    IN VARCHAR2,
                           p_cod_per_empresa IN VARCHAR2,
                           p_cod_persona     IN VARCHAR2) RETURN VARCHAR2 IS
      v_cod_principal ba_personas.cod_persona%TYPE;
   BEGIN
      --- Obtengo el principal.
      SELECT cod_persona
        INTO v_cod_principal
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_numeroCuenta
         AND relacion = 'P';
      --
      IF pag_gen.FU_ES_PER_FISICA(v_cod_principal) = 'N' AND nvl(p_cod_per_empresa, p_cod_persona) != v_cod_principal THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   FUNCTION lf_for_date(p_dato IN DATE) RETURN CHAR IS
   BEGIN
      RETURN nvl(to_char(p_dato, 'ddmmyyyy'), ' ');
   END;

   -- devuelve el campo monto formateado
   FUNCTION lf_for_money(p_dato IN NUMBER,
                         p_longitud IN NUMBER DEFAULT NULL) RETURN VARCHAR2 IS
   BEGIN
      IF p_longitud IS NULL THEN
         RETURN ltrim(to_char(nvl(p_dato, 0), '9999999999999999.99'));
      ELSE
         RETURN lpad(ltrim(to_char(nvl(p_dato, 0), '9999999999999999.99')), p_longitud, ' ');
      END IF;
   END;

   /* Función que devuelve si una cuenta tiene o no cheque devuelto
   */
   FUNCTION lf_obt_che_devuelto(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_cantidad NUMBER;
   BEGIN
      SELECT COUNT(*)
        INTO v_cantidad
        FROM ge_movimientos
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_mod_padre = 4
         AND cod_mad_padre = 41
         AND cod_tra_padre = 321
         AND cod_transaccion IN (522, 503, 182)
         AND reversado = 'N'
         AND estado = 'N'
         AND rownum = 1;
      IF v_cantidad > 0 THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   /**Inserta registro en bw_movimientos
   * @param p_nro_cuenta Nro de cuenta
   * @param p_cod_moneda Código de moneda
   * @param p_monto monto
   * @param p_nro_cta_contra Nro de cuenta
   * @param p_cantidad Cantidad
   * @param p_etiqueta Etiqueta
   * @param p_dato Dato
   * @param p_etiqueta2 Etiqueta2
   * @param p_dato2 Dato2
   * @param p_observacion Observación
   * @param p_dir_ip Dirección ip
   * @param p_cod_respuesta Codigo de respuesta
   * @param p_cod_persona Codigo de persona
   * @param p_cod_operacion Codigo de operación
   * @param p_nro_operacion Nro de operación
   * @param p_nro_terminal Nro de terminal
   * @param p_clave Clave
   * @param p_cod_per_empresa Código de empresa
   */
   PROCEDURE lp_reg_operacion(p_nro_cuenta      IN VARCHAR2 DEFAULT NULL,
                              p_cod_moneda      IN VARCHAR2 DEFAULT NULL,
                              p_monto           IN NUMBER DEFAULT NULL,
                              p_nro_cta_contra  IN VARCHAR2 DEFAULT NULL,
                              p_cantidad        IN NUMBER DEFAULT NULL,
                              p_etiqueta        IN VARCHAR2 DEFAULT NULL,
                              p_dato            IN VARCHAR2 DEFAULT NULL,
                              p_etiqueta2       IN VARCHAR2 DEFAULT NULL,
                              p_dato2           IN VARCHAR2 DEFAULT NULL,
                              p_observacion     IN VARCHAR2 DEFAULT NULL,
                              p_dir_ip          IN VARCHAR2 DEFAULT NULL,
                              p_cod_respuesta   IN VARCHAR2 DEFAULT NULL,
                              p_cod_persona     IN VARCHAR2 DEFAULT NULL,
                              p_cod_operacion   IN VARCHAR2 DEFAULT NULL,
                              p_nro_operacion   IN VARCHAR2 DEFAULT NULL,
                              p_nro_terminal    IN VARCHAR2 DEFAULT NULL,
                              p_clave           IN VARCHAR2 DEFAULT NULL,
                              p_cod_per_empresa IN VARCHAR2 DEFAULT NULL,
                              p_parametros      IN VARCHAR2 DEFAULT NULL,
                              p_etiqueta3       IN VARCHAR2 DEFAULT NULL,
                              p_dato3           IN VARCHAR2 DEFAULT NULL) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   BEGIN
      INSERT INTO bw_movimientos
         (nro_documento, cod_per_principal, cod_per_ingreso, clave, fec_hora, nro_caja, cod_tip_mensaje, dir_ip, cod_respuesta, observacion, nro_cuenta, cod_moneda, monto, nro_cta_contra, cantidad, etiqueta, dato, etiqueta2, dato2, parametros, etiqueta3, dato3)
      VALUES
         (p_nro_operacion, nvl(p_cod_per_empresa, p_cod_persona), p_cod_persona, substr(p_clave, 1, 20), SYSDATE, p_nro_terminal, p_cod_operacion, p_dir_ip, p_cod_respuesta, p_observacion, substr(REPLACE(TRIM(p_nro_cuenta), chr(13), ''),0,15), p_cod_moneda, p_monto, substr(REPLACE(TRIM(p_nro_cta_contra), chr(13), ''),0,15), p_cantidad, p_etiqueta, p_dato, p_etiqueta2, p_dato2, substr(p_parametros, 1, 1000),p_etiqueta3, p_dato3);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   FUNCTION lp_ver_horario(p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_ult_cierre     IN DATE,
                           p_cod_ofi_origen IN VARCHAR2,
                           p_fec_actual     OUT DATE) RETURN typ_MensajeRespuesta IS

      MSG_SIS_CIERRE CONSTANT VARCHAR2(15) := 'HOR_SIS_CIERRE';
      v_est_modulo ba_modulos.estado%TYPE;
      v_retorno    typ_MensajeRespuesta := typ_MensajeRespuesta;
   BEGIN
      --v_cod_respuesta := paw_bce.v_cod_aprobado;
      pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

      IF v_est_modulo IN (1,6) THEN -- DDSI-29 -- 07/2017 --
         -- En cierre.
         --v_cod_respuesta := paw_bce.v_cod_sis_cierre;
         pr_mensajeUsuario(MSG_SIS_CIERRE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora(NULL, NULL, NULL, '999', NULL, ' lp_ver_horario()-Sistema en cierre-', BITACORA_ERROR);
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto

         -- Verifica la hora --
         IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
            p_horario    := 'T'; -- Tarde
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
            p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         END IF;

      ELSE
         p_horario := 'N'; -- Noche
         IF v_est_modulo <> 1 THEN
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
         END IF;
         p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      pag_cta.g_horario := p_horario;
      RETURN v_retorno;
   END lp_ver_horario;

   FUNCTION fu_ver_horario(p_horario        OUT VARCHAR2,
                           p_es_mov_noc     OUT VARCHAR2,
                           p_es_cta_noc     OUT VARCHAR2,
                           p_ult_cierre     IN DATE,
                           p_cod_ofi_origen IN VARCHAR2,
                           p_fec_actual     OUT DATE) RETURN typ_MensajeRespuesta IS
   BEGIN
      RETURN lp_ver_horario(p_horario, p_es_mov_noc, p_es_cta_noc,
                           p_ult_cierre, p_cod_ofi_origen, p_fec_actual);
   END;

   PROCEDURE lp_can_reg_historicos(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                   p_fecha      IN ge_movimientos.fecha%TYPE,
                                   p_horario    OUT VARCHAR2) IS
      v_lugar         VARCHAR2(100);
      v_can_registros NUMBER(5) := 99;
   BEGIN
      v_lugar := 'obtener cantidad de registros historicos';
      BEGIN
         SELECT 1
           INTO v_can_registros
           FROM cc_movimientos_his h
          WHERE h.fecha = p_fecha
            AND h.nro_cuenta = p_nro_cuenta
            AND rownum = 1
         UNION
         SELECT 1
           FROM ah_movimientos_his h
          WHERE h.fecha = p_fecha
            AND h.nro_cuenta = p_nro_cuenta
            AND rownum = 1;
      EXCEPTION
         WHEN no_data_found THEN
            v_can_registros := 0;
      END;
      IF v_can_registros = 0 THEN
         p_horario := 'D';
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_lugar || ' - ' || SQLERRM);
   END;

   -- insertar comprobante comprimido
   FUNCTION fu_ins_archivo(p_cod_persona   IN bw_archivos.cod_persona%TYPE,
                           p_cod_operacion IN bw_archivos.cod_tip_operacion%TYPE,
                           p_nro_documento IN bw_archivos.nro_documento%TYPE,
                           p_comprobante   IN bw_archivos.contenido%TYPE,
                           p_nombre        IN bw_archivos.nombre%TYPE) RETURN NUMBER IS
      v_con_compreso bw_archivos.contenido%TYPE;
      v_nombre       bw_archivos.nombre%TYPE := depurarTextos(p_nombre, 100);
      v_size         bw_archivos.longitud%TYPE := 0;
      v_con_size     bw_archivos.longitud%TYPE;
      v_extension    bw_archivos.extension%TYPE := NULL;
      v_ind          NUMBER;
   BEGIN
      -- convertimos a BLOB:
      v_size := nvl(dbms_lob.getlength(p_comprobante), 0);
      IF v_size > 0 THEN
         -- set-up para convertir a BLOB
         dbms_lob.createtemporary(v_con_compreso, FALSE);

         -- comprimimos
         v_con_compreso := utl_compress.lz_compress(p_comprobante);

         v_con_size := dbms_lob.getlength( v_con_compreso );
         BEGIN
            v_ind := instr(v_nombre, '.', -1);
            v_extension := substr(substr(v_nombre, v_ind), 1, 10);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;

         BEGIN
            --insertamos el archivo
            INSERT INTO bw_archivos
               (cod_persona, nombre, nro_documento, cod_tip_operacion, contenido, longitud, extension)
            VALUES
               (p_cod_persona, v_nombre, p_nro_documento, p_cod_operacion, v_con_compreso, v_con_size, v_extension);
            v_size := v_con_size;
         EXCEPTION
            WHEN OTHERS THEN
               v_size := -1;
         END;

         dbms_lob.freetemporary(v_con_compreso);
      END IF;
      RETURN v_size;
   END;
   FUNCTION fu_obt_abr_refcodes(P_DOMINIO   IN VARCHAR2,
                             P_VALOR_MIN IN VARCHAR2,
                             P_VALOR_MAX IN VARCHAR2) RETURN VARCHAR2 IS
   v_referencia ba_cod_referencias.abreviatura%TYPE := null;
   BEGIN
     SELECT abreviatura
       INTO v_referencia
       FROM ba_cod_referencias
      WHERE dominio = P_DOMINIO
        AND val_minimo = P_VALOR_MIN
        AND val_maximo = P_VALOR_MAX;
     RETURN v_referencia;
   EXCEPTION
     WHEN no_data_found THEN
       RETURN('Referencia  no registrada en el Sistema');
   END;
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END paw_uti;
/

