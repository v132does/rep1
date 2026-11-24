create or replace package body it.PAT_SOL is
   
   -- 
   FUNCTION fu_val_cta_adicional(p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                                 p_cod_persona   IN ba_personas.cod_persona%TYPE,
                                 p_relacion      IN VARCHAR2 DEFAULT 'P') RETURN NUMBER IS
      v_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
      v_est_cuenta ge_cuentas.estado%TYPE;
   BEGIN
      SELECT c.cod_modalidad, c.estado
        INTO v_cod_modalidad, v_est_cuenta
        FROM ge_cuentas c, ge_cta_clientes cc
       WHERE cc.nro_cuenta = p_nro_cuenta
         AND cc.cod_persona = p_cod_persona
         AND cc.relacion = p_relacion
         AND c.nro_cuenta = cc.nro_cuenta
         AND c.cod_modulo = 5;
      -- control de cuenta bloqueada
      IF v_est_cuenta NOT IN ('B', 'N') THEN
         RETURN 2;
      END IF;
      -- control modalidad valida
      IF fu_es_prepaga(v_cod_modalidad) = 'S' THEN
         RETURN 3;
      END IF;
      
      -- ok
      RETURN 0;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         -- cuenta inexistente
         RETURN 1;
   END;
   
   -- 
   FUNCTION fu_es_prepaga(p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE) RETURN VARCHAR2 IS
   BEGIN
      IF instr(fug_obt_pardinamico('TAR_PRE_PAGAS'), ','||p_cod_modalidad||',') <> 0 THEN
         RETURN 'S';
      END IF;
      RETURN 'N';
   END;

   --
   /**
    * Ej. entrada esperado
    * {
    *    "firstName": "name",
    *    "middleName": "midName",
    *    "lastName": "lastName",
    *    "secLastName": "secLast",
    *    "documentType": 1,
    *    "documentNumber": "135466",
    *    "gender": "F",
    *    "countryCode": 1,
    *    "birthday": "yyyymmdd",
    *    "civilStatus": "S",
    *    "cardName": "JONH F. DOE"
    * }
    */
   FUNCTION fu_obt_sol_adicional(p_cod_persona       IN ba_personas.cod_persona%TYPE, 
                                 p_datosJson         IN VARCHAR2,
                                 p_nro_cuenta        IN ta_tarjetas.nro_cuenta%TYPE,
                                 p_pri_nombre        OUT ba_per_fisicas.pri_nombre%TYPE,
                                 p_seg_nombre        OUT ba_per_fisicas.seg_nombre%TYPE,
                                 p_pri_apellido      OUT ba_per_fisicas.pri_apellido%TYPE,
                                 p_seg_apellido      OUT ba_per_fisicas.seg_apellido%TYPE,
                                 p_tip_documento     OUT ba_tip_documentos.abreviatura%TYPE,
                                 p_nro_doc_persona   OUT ba_personas.nro_documento%TYPE,
                                 p_genero            OUT ba_per_fisicas.cod_sexo%TYPE,
                                 p_cod_pais          OUT ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                                 p_fec_nacimiento    OUT ba_per_fisicas.fec_nacimiento%TYPE,
                                 p_cod_est_civil     OUT ba_per_fisicas.est_civil%TYPE,
                                 p_nom_embozo        OUT ta_tarjetas.nom_embozar%TYPE) RETURN NUMBER IS
      v_json paw_json.JSONStructObj;
      v_cod_per_adicional ba_personas.cod_persona%TYPE;
      v_cod_respuesta NUMBER;
      v_existe VARCHAR2(1);
   BEGIN
      -- parseamos el json "string"
      v_json := paw_json.String2JSON(p_datosJson, '"');
      -- obtenemos los valores
      p_pri_nombre := UPPER(paw_uti.depurarTextos(paw_json.getAttrValue(v_json, 'firstName'), 30));
      p_seg_nombre := UPPER(paw_uti.depurarTextos(paw_json.getAttrValue(v_json, 'middleName'), 30));
      p_pri_apellido := UPPER(paw_uti.depurarTextos(paw_json.getAttrValue(v_json, 'lastName'), 30));
      p_seg_apellido := UPPER(paw_uti.depurarTextos(paw_json.getAttrValue(v_json, 'secLastName'), 30));
      p_tip_documento := paw_uti.depurarAlfanumerico(paw_json.getAttrValue(v_json, 'documentType'), 4);
      p_nro_doc_persona := paw_uti.depurarTextos(paw_json.getAttrValue(v_json, 'documentNumber'), 20);
      p_genero := paw_uti.depurarAlfanumerico(paw_json.getAttrValue(v_json, 'gender'), 1);
      p_cod_pais := paw_uti.depurarNumerico(paw_json.getAttrValue(v_json, 'countryCode'), 3);
      p_cod_est_civil := paw_uti.depurarAlfanumerico(paw_json.getAttrValue(v_json, 'civilStatus'), 1);
      p_nom_embozo := UPPER(paw_uti.depurarTextos(paw_json.getAttrValue(v_json, 'cardName'), 20));
      p_fec_nacimiento := paw_uti.fu_str_fecha(paw_json.getAttrValue(v_json, 'birthday'), 2);
      
      -- limpiamos el object
      IF v_json.count > 0 THEN
         paw_json.closeJSONObj(v_json);
      END IF;
      
      -- validar cuenta para solicitud de adicional
       v_cod_respuesta := pat_sol.fu_val_cta_adicional(p_nro_cuenta, p_cod_persona);
       
       IF v_cod_respuesta = 0 THEN
         -- validar tipo de documento
         IF paw_uti.fu_validarTipoDocumento(p_tip_documento) IS NULL THEN
            RETURN 4;
         END IF;
         -- validar estado civil
         IF paw_uti.fu_obtenerCodigoReferencia('COD_EST_CIVIL', p_cod_est_civil) IS NULL THEN
            RETURN 4;
         END IF;
         -- validar genero
         IF paw_uti.fu_obtenerCodigoReferencia('COD_SEXO', p_genero) IS NULL THEN
            RETURN 4;
         END IF;
         -- validar pais
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ba_paises p
             WHERE p.cod_pais = p_cod_pais;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               RETURN 4;
         END;
         -- validacion duplicado
         BEGIN
            SELECT p.cod_persona
              INTO v_cod_per_adicional
              FROM ba_personas p, ba_tip_documentos d
             WHERE p.cod_tip_documento = d.cod_tip_documento
               AND p.nro_documento = p_nro_doc_persona
               AND d.abreviatura = p_tip_documento;
            IF pat_sol.fu_ver_sol_adi_existente(p_nro_cuenta, v_cod_per_adicional) = 'S' THEN
               RETURN 5;
            END IF;
         EXCEPTION 
            WHEN NO_DATA_FOUND THEN
               NULL;
         END;
       END IF;
      
      RETURN v_cod_respuesta;
   END;
   
   --
   FUNCTION fu_ver_sol_adi_existente(p_nro_cuenta        IN ta_cta_tarjetas.nro_cuenta%TYPE,
                                     p_cod_per_adicional IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_cod_estado ta_sol_adicionales.cod_estado%TYPE;
      v_existe NUMBER;
   BEGIN
      -- verificar si existe una solicitud
      BEGIN
         SELECT a.cod_estado
           INTO v_cod_estado
           FROM (SELECT * 
                   FROM ta_sol_adicionales a  
                  WHERE a.cod_persona = p_cod_per_adicional
                    AND a.nro_cuenta = p_nro_cuenta
                  ORDER BY a.fec_insercion DESC) a 
           WHERE rownum = 1;
           
         RETURN 'S';
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
      END;
      -- verificar si ya posee una tarjeta
      SELECT COUNT(0) 
        INTO v_existe
        FROM ta_cta_tarjetas c, ta_tarjetas t
       WHERE t.cod_persona = p_cod_per_adicional
         AND t.nro_cuenta = p_nro_cuenta
         AND t.cod_estado <> 10
         AND c.nro_cuenta = t.nro_cuenta;
      IF v_existe <> 0 THEN
        RETURN 'S';
      END IF;
      
      RETURN 'N';
   END;
   --
   FUNCTION fu_not_solicitud(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                             p_nro_tarjeta   IN ta_tarjetas.nro_tarjeta%TYPE,
                             p_tip_solicitud IN NUMBER) RETURN NUMBER IS
      v_mensaje   ge_par_dinamicos.val_parametro%TYPE;
      v_des_modal ge_modalidades.descripcion%TYPE;
   BEGIN
      -- modalidad de la tarjeta
      SELECT trim(fug_obt_des_modal(m.cod_modulo, m.cod_modalidad))
        INTO v_des_modal
        FROM ta_tarjetas t, ge_modalidades m, ta_cta_tarjetas ct
       WHERE t.nro_tarjeta = p_nro_tarjeta
         AND t.cod_persona = p_cod_persona
         AND t.nro_cuenta = ct.nro_cuenta
         AND m.cod_modulo = ct.cod_modulo
         AND m.cod_modalidad = ct.cod_modalidad
         AND rownum = 1;
         
      -- mensaje a enviar
      v_mensaje := utl_lms.format_message(fug_obt_pardinamico('NOT_SOL_TARJETAS', p_tip_solicitud), v_des_modal || ' ****' || substr(p_nro_tarjeta, -4));
      RETURN paw_not.fu_env_email_prueba(fug_obt_dir_mail_per(p_cod_persona), utl_url.escape(v_mensaje), 'PAT_SOL');
   EXCEPTION
      WHEN OTHERS THEN
         NULL;  
   END;

begin
   pre_cam_for_numerico('.,');
end PAT_SOL;
/

