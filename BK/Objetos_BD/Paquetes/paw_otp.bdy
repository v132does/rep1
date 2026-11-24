CREATE OR REPLACE PACKAGE BODY IT.PAW_OTP IS
   PROCEDURE lp_ins_log_mensajeria(p_pedido IN bw_log_bca_electronica.mensaje%TYPE, p_respuesta IN bw_log_bca_electronica.respuesta%TYPE) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      BEGIN 
	     --
         INSERT INTO bw_log_bca_electronica
            (mensaje, respuesta)
         VALUES
            (p_pedido, p_respuesta);
         COMMIT;
      EXCEPTION 
         WHEN OTHERS THEN
            NULL; 
      END;
   END;
 
   PROCEDURE pr_gen_importado IS
      CURSOR cu_seriales IS
         SELECT * FROM bw_otp_seriales_tmp; 
      FUNCTION lf_ver_serial(p_nro_serial bw_otp_seriales.nro_serial%TYPE) RETURN VARCHAR2 IS
         v_existe VARCHAR2(1) := 'N';
      BEGIN
         BEGIN
            SELECT 'S' INTO v_existe FROM bw_otp_seriales WHERE nro_serial = p_nro_serial;
            RETURN v_existe;
         EXCEPTION
            WHEN no_data_found THEN
               RETURN 'N';
            WHEN OTHERS THEN
               RETURN 'S';
         END;
      END;
   
   BEGIN
      BEGIN
         FOR i IN cu_seriales LOOP
            IF lf_ver_serial(i.nro_serial) = 'S' THEN
               raise_application_error(-20000,
                                       'Nro. Serial ' || i.nro_serial || ' ya existe. Verifique.');
               EXIT;
            ELSE
               INSERT INTO bw_otp_seriales
                  (tipo, nro_serial, estado, cod_oficina, nro_lote)
               VALUES
                  (upper(i.tipo), i.nro_serial, 'I', fun_obt_ofi_matriz, i.nro_lote);
            END IF;
         END LOOP;
      END;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'en paw_otp.pr_gen_importado ' || SQLERRM);
         END IF;
   END pr_gen_importado;

   /* Obtiene la cantidad de token por estado y oficina.*/
   FUNCTION fu_obt_can_estado
   (
      p_oficina IN ba_oficinas.cod_oficina%TYPE,
      p_tipo    IN bw_otp_seriales.tipo%TYPE,
      p_estado  IN bw_otp_seriales.estado%TYPE
   ) RETURN NUMBER IS
      v_cantidad NUMBER(3);
   BEGIN
      SELECT COUNT(*)
        INTO v_cantidad
        FROM bw_otp_seriales c
       WHERE c.cod_oficina = nvl(p_oficina, c.cod_oficina)
         AND c.tipo = nvl(p_tipo, c.tipo)
         AND estado = p_estado;
      RETURN nvl(v_cantidad, 0);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END fu_obt_can_estado;

   FUNCTION fu_act_estado
   (
      p_cod_persona       IN ba_personas.cod_persona%TYPE DEFAULT NULL,
      p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL,
      p_tipo              IN bw_otp_seriales.tipo%TYPE,
      p_nro_serial        IN bw_otp_seriales.nro_serial%TYPE,
      p_estado            IN bw_otp_seriales.estado%TYPE
   ) RETURN VARCHAR2 IS
      v_vinculo    VARCHAR2(1) := 'N';
      v_fec_actual DATE := pag_cal.fu_obt_fec_actual(1);
      v_resultado  VARCHAR2(1) := 0;
      v_estado     bw_otp_seriales.estado%TYPE;
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
      --Consulto estado actual
      BEGIN
         SELECT estado INTO v_estado FROM bw_otp_seriales WHERE nro_serial = p_nro_serial;
      END;
      --Validacion de la Persona Vinculada
      --Solo si el estado es Nuevo
      IF p_estado = 'N' THEN
         IF p_cod_per_vinculada IS NOT NULL THEN
            BEGIN
               SELECT 'S'
                 INTO v_vinculo
                 FROM ba_vinculos a
                WHERE a.cod_persona = p_cod_per_vinculada
                  AND a.cod_per_vinculo = p_cod_persona;
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20000, 'Persona no vinculada a la Empresa.');
               WHEN TOO_MANY_ROWS THEN
                  v_vinculo := 'S';
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'al consultar ba_vinculos - ' || SQLERRM);
            END;
         END IF;
      END IF;
      --Actualizo las claves
      UPDATE bw_otp_seriales a
         SET a.est_anterior = a.estado,
             a.estado       = p_estado,
             a.fec_est_otp  = v_fec_actual,
             a.cod_persona = CASE
                                WHEN p_estado IN ('D', 'I') THEN
                                 NULL
                                ELSE
                                 p_cod_persona
                             END,
             --decode(p_estado, 'D', NULL, p_cod_persona),
             a.cod_per_vinculada = CASE
                                      WHEN p_estado IN ('D', 'I') THEN
                                       NULL
                                      ELSE
                                       p_cod_per_vinculada
                                   END, --decode(p_estado, 'D', NULL, p_cod_per_vinculada),
             a.can_intentos      = 0,
             a.fec_asignacion    = decode(p_estado, 'N', v_fec_actual, a.fec_asignacion),
             a.usu_asignacion    = decode(p_estado, 'N', USER, a.usu_asignacion),
             a.fec_entrega       = decode(p_estado, 'E', v_fec_actual, a.fec_entrega),
             a.usu_entrega       = decode(p_estado, 'E', USER, a.usu_entrega),
             a.cod_ofi_entrega   = decode(p_estado, 'E', fug_obt_ofi_usuario(USER), a.cod_ofi_entrega),
             a.fec_impresion     = decode(p_estado, 'P', v_fec_actual, a.fec_impresion),
             a.usu_impresion     = decode(p_estado, 'P', USER, a.usu_impresion),
             a.cod_ofi_impresion = decode(p_estado, 'P', fug_obt_ofi_usuario(USER),
                                          a.cod_ofi_impresion),
             a.fec_activacion    = decode(p_estado, 'A', v_fec_actual, a.fec_activacion),
             a.usu_activacion    = decode(p_estado, 'A', USER, a.usu_activacion),
             a.exportado         = 'N'
       WHERE a.nro_serial = p_nro_serial
         AND a.tipo = p_tipo;
      IF SQL%NOTFOUND THEN
         v_resultado := 1;
      END IF;
      --Elimino los medios anteriores
      IF p_estado IN ('I', 'D') THEN
         DELETE FROM bw_otp_ref_medios WHERE nro_serial = p_nro_serial;
      END IF;
      RETURN v_resultado;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'en paw_otp.fu_act_estado - ' || SQLERRM);
         END IF;
   END fu_act_estado;

   /* Disponibiliza las solicitudes de OTPs que fueron asignados a clientes 
   y que no fueron entregados en un periodo de tiempo.*/
   PROCEDURE pr_eli_otp_ent_pen IS
      v_resultado VARCHAR2(1) DEFAULT 0;
      CURSOR cu_otp_ent_pendientes IS
         SELECT cod_persona, cod_per_vinculada, tipo, nro_serial, estado
           FROM bw_otp_seriales
          WHERE estado IN ('N', 'P') --Estado Nuevo(N) o Impreso(P)
            AND pag_cal.fu_obt_fec_actual(1) - fec_asignacion >
                fug_obt_pardinamico('OTP_DIA_PLZ_ENTREGA');
   BEGIN
      BEGIN
         FOR x IN cu_otp_ent_pendientes LOOP
            IF x.estado = 'P' THEN
               -- Elimina tareas del Workflow segun Nro. de Serial del Token.
               paw_otp.pr_eli_tareas(x.nro_serial);
            END IF;
            v_resultado := paw_otp.fu_act_estado(x.cod_persona, 
                                                 x.cod_per_vinculada, 
                                                 x.tipo,
                                                 x.nro_serial, 
                                                 'D');
            IF v_resultado <> 0 THEN
               raise_application_error(-20000, ' al actualizar el estado de OTP - ' || SQLERRM);
            END IF;
         END LOOP;
      END;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, ' en PAW_OTP.PR_ELI_OTP_ENT_PEN - ' || SQLERRM);
         END IF;
   END pr_eli_otp_ent_pen;

   /* Actualiza el indice de exportacion de las claves OTP en la tabla BW_OTP_SERIALES.*/
   PROCEDURE pr_act_exp
   (
      p_estado  IN bw_otp_seriales.exportado%TYPE,
      p_archivo IN VARCHAR2
   ) IS
   BEGIN
      IF p_estado = 'X' AND p_archivo = 'A' THEN
         UPDATE bw_otp_seriales a
            SET a.exportado = p_estado
          WHERE a.exportado = 'N'
            AND a.estado = 'A';
           commit;
      ELSIF p_estado = 'X' AND p_archivo = 'B' THEN
         UPDATE bw_otp_seriales a
            SET a.exportado = p_estado
          WHERE a.exportado = 'N'
            AND a.estado IN ('I', 'B');
      ELSIF p_estado = 'S' AND p_archivo = 'A' THEN
         UPDATE bw_otp_seriales a
            SET a.exportado = p_estado
          WHERE a.exportado = 'X'
            AND a.estado = 'A';
      ELSIF p_estado = 'S' AND p_archivo = 'B' THEN
         UPDATE bw_otp_seriales a
            SET a.exportado = p_estado
          WHERE a.exportado = 'X'
            AND a.estado IN ('I', 'B');
      END IF;
     /* IF SQL%NOTFOUND THEN
         raise_application_error(-20000,
                                 ' al actualizar el indice de exportacion de las claves OTP - ' ||
                                  SQLERRM);
      END IF;*/
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20001, ' en PAW_OTP.PR_ACT_EXP - ' || SQLERRM);
         END IF;
   END pr_act_exp;

   /* Actualiza la clave a entregado, es invocado desde el workflow.*/
   PROCEDURE pr_act_entregado(p_nro_serial IN bw_otp_seriales.nro_serial%TYPE) IS
      v_resultado VARCHAR2(1);
      rg_seriales bw_otp_seriales%ROWTYPE;
   BEGIN
      SELECT a.cod_persona, a.cod_per_vinculada, a.tipo
        INTO rg_seriales.cod_persona, rg_seriales.cod_per_vinculada, rg_seriales.tipo
        FROM bw_otp_seriales a
       WHERE a.nro_serial = p_nro_serial;
      v_resultado := paw_otp.fu_act_estado(rg_seriales.cod_persona, rg_seriales.cod_per_vinculada,
                                           rg_seriales.tipo, p_nro_serial, 'E');
      IF v_resultado <> 0 THEN
         raise_application_error(-20000, 'No se pudo Entregar.');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, ' en PAW_OTP.PR_ACT_ENTREGADO - ' || SQLERRM);
         END IF;
   END pr_act_entregado;

   /* Actualiza la clave a activo, es invocado desde el workflow.*/
   PROCEDURE pr_act_activado(p_nro_serial IN bw_otp_seriales.nro_serial%TYPE) IS
      v_resultado VARCHAR2(1);
      rg_seriales bw_otp_seriales%ROWTYPE;
   BEGIN
      SELECT a.cod_persona, a.cod_per_vinculada, a.tipo
        INTO rg_seriales.cod_persona, rg_seriales.cod_per_vinculada, rg_seriales.tipo
        FROM bw_otp_seriales a
       WHERE a.nro_serial = p_nro_serial;
      v_resultado := paw_otp.fu_act_estado(rg_seriales.cod_persona, rg_seriales.cod_per_vinculada,
                                           rg_seriales.tipo, p_nro_serial, 'A');
      IF v_resultado <> 0 THEN
         raise_application_error(-20000, 'No se pudo Activar.');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, ' en PAW_OTP.PR_ACT_ACTIVADO - ' || SQLERRM);
         END IF;
   END pr_act_activado;

   /* Elimina las tareas del workflow.*/
   PROCEDURE pr_eli_tareas(p_nro_serial IN bw_otp_seriales.nro_serial%TYPE) IS
      CURSOR c_circuito IS
         SELECT a.cod_circuito FROM wf_circuitos a WHERE a.referencia = p_nro_serial;
   BEGIN
      FOR i IN c_circuito LOOP
         DELETE FROM wf_cir_tareas a WHERE a.cod_circuito = i.cod_circuito;
      END LOOP;
      DELETE wf_circuitos a WHERE a.referencia = p_nro_serial;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, ' en PAW_OTP.PR_ELI_TAREAS - ' || SQLERRM);
   END pr_eli_tareas;

   /*
   Obtiene un serial de un token disponible del tipo p_tipo y de la oficina p_cod_oficina
   */
   FUNCTION fu_obt_tok_disponible(p_tipo VARCHAR2, p_cod_oficina NUMBER) RETURN VARCHAR2 IS
      v_nro_serial bw_otp_seriales.nro_serial%TYPE;
   BEGIN
      BEGIN
       SELECT nro_serial
         INTO v_nro_serial
         FROM (SELECT *
                  FROM bw_otp_seriales s
                 WHERE s.estado = 'D'
                   AND s.cod_persona IS NULL
                   AND s.cod_oficina = p_cod_oficina
                   AND s.tipo = p_tipo
                 ORDER BY dbms_random.value)
        WHERE rownum = 1;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RETURN NULL;
      END;
      RETURN v_nro_serial;
   END;


/*
Verifica que si la persona no tiene ya asignado un token virtual
si no encuentra retorna 0
*/
FUNCTION fu_ver_asi_toke_virtual(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN NUMBER IS
   v_nro_serial bw_otp_seriales.nro_serial%TYPE;
BEGIN
   BEGIN
      SELECT nro_serial
        INTO v_nro_serial
        FROM bw_otp_seriales
       WHERE cod_persona = p_cod_persona
         AND tipo = 'V';
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;
   --TODO:Agregar logica para verificar en el Vasco si tiene asignado un token
   RETURN 1;

END;

/*
Obtiene el resumem total de token disponibles por sucursal por tipo
*/
PROCEDURE pr_obt_tok_stock(p_cod_oficina IN NUMBER, p_can_virtual OUT NUMBER, p_can_fisico OUT NUMBER) IS
BEGIN
   BEGIN
      SELECT COUNT(*)
        INTO p_can_virtual
        FROM bw_otp_seriales s
       WHERE s.estado = 'D'
         AND s.cod_persona IS NULL
         AND s.cod_oficina = p_cod_oficina
         AND s.tipo = 'V'
         AND rownum = 1;
   
      SELECT COUNT(*)
        INTO p_can_fisico
        FROM bw_otp_seriales s
       WHERE s.estado = 'D'
         AND s.cod_persona IS NULL
         AND s.cod_oficina = p_cod_oficina
         AND s.tipo = 'F'
         AND rownum = 1;
   EXCEPTION
      WHEN OTHERS THEN
         p_can_virtual := -1;
         p_can_fisico  := -1;
      
   
   END;
END;

/*
Valida que el numero de telefono este catastrado en ITGF
*/
  FUNCTION fu_val_telefono(p_cod_persona IN ba_personas.cod_persona%TYPE, p_nro_telefono IN VARCHAR2) RETURN NUMBER IS
     v_nro_telefono VARCHAR2(6);
     v_prefijo      VARCHAR2(4);
     v_tipo         VARCHAR2(1);
  BEGIN
  
     v_nro_telefono := substr(trim(p_nro_telefono), -6);
     v_prefijo      := substr(trim(p_nro_telefono), 0, 4);
  
     BEGIN
        SELECT tipo
          INTO v_tipo
          FROM ba_telefonos t
         WHERE t.cod_persona = p_cod_persona
           --AND t.tip_linea = 'C'
           AND t.area = v_prefijo
           AND t.telefono = v_nro_telefono
           AND ROWNUM = 1;
     EXCEPTION
        WHEN OTHERS THEN
           RETURN - 1;
     END;
     RETURN 0;
  END;

/*
Envia un correo avisando el stock de token de la sucursal 
*/
FUNCTION fu_env_mai_clavefacil(p_nro_serial IN VARCHAR, p_cod_persona IN VARCHAR2, p_cod_oficina IN NUMBER) RETURN NUMBER IS
   v_mensaje     VARCHAR2(1500);
   v_can_virtual NUMBER(5);
   v_can_fisico  NUMBER(5);
   v_email varchar2(200);
BEGIN
   pr_obt_tok_stock(p_cod_oficina, v_can_virtual, v_can_fisico);
   v_email:=fug_obt_parentes(6331, 'EMAIL_STOCK_CLA_FACIL');
   v_mensaje := utl_lms.format_message('Se asigno el token virtual %s al usuario %s. Quedan %s token fisicos y %s token virtuales',
                                       p_nro_serial,
                                       p_cod_persona,
                                       to_char(v_can_fisico),
                                       to_char(v_can_virtual));

 it_mail.mail(fug_obt_dir_correo,
                        v_email,
                        'Clave Facil - Token Asignado',
                        v_mensaje
                        );   
   
   RETURN 0;
END;

/*
Contiene la logica de asignacion de un token virtual a una persona fisica
asume de que ya se hicieron verificaciones de la persona y del token
Retorno 
 0 OK
-1 Nro de telefono no catastrado en sistema
 1 Error asignando token en ITGF

*/
FUNCTION fu_asi_tok_virtual(p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_nro_telefono IN bw_otp_ref_medios.ref_medio%TYPE,
                            p_origen IN bw_sol_claves.cod_origen%TYPE, p_nro_serial IN bw_otp_seriales.nro_serial%type) RETURN NUMBER IS
   v_cod_oficina ba_oficinas.cod_oficina%TYPE;
   v_nro_serial  bw_otp_seriales.nro_serial%TYPE;
   v_respuesta number(3);
   v_telef_regis varchar2(10);
   v_act_telef   number(1);
   v_band number(1):= 1; 
   v_existe number(1):=0;
   
   --v_nro_seri_exist bw_otp_seriales.nro_serial%TYPE;
BEGIN

   v_cod_oficina := to_number(fug_obt_parentes(6331, 'COD_OFI_CLA_FACIL'));
   v_nro_serial  := p_nro_serial;--fu_obt_tok_disponible('V', v_cod_oficina);
    --v_nro_serial := '0091234599'; /*para probar nomas*/
     
   if (fu_val_telefono(p_cod_persona , p_nro_telefono )<>0) then
    return -1;
   end if;
   
   --Validar que el nro ingresado sea igual 
   BEGIN
    SELECT a.ref_medio, a.nro_serial --28/08/2014 Lou
      INTO v_telef_regis , v_nro_serial
      FROM bw_otp_ref_medios a
     WHERE a.cod_persona = p_cod_persona;
   EXCEPTION
     WHEN OTHERS THEN
      v_telef_regis := p_nro_telefono; 
      v_band := 0; 
   END;
       
   IF v_telef_regis IS NOT NULL THEN --28/08/2014 Lou
       v_act_telef := fu_cam_nro_celular(p_cod_persona, p_nro_telefono, v_nro_serial);
   END IF;
   
    --validar que el cliente no exista en la tabla
  BEGIN
    SELECT a.nro_serial 
      INTO v_nro_serial
      FROM bw_otp_seriales a
     WHERE a.cod_persona = p_cod_persona
       AND a.tipo = 'V';
  EXCEPTION
     WHEN OTHERS THEN
      v_existe:=1;
  END;
       
   --Actualizar bw_otp_serials
  BEGIN
    IF v_existe = 1 THEN
      UPDATE bw_otp_seriales
         SET cod_persona = p_cod_persona, estado = 'A'
       WHERE nro_serial = v_nro_serial;
    ELSE
        UPDATE bw_otp_seriales
          SET nro_serial = v_nro_serial, estado = 'A'
        WHERE cod_persona = p_cod_persona;   
    END IF;
         
    IF v_band = 0 then
      --Actualizar bw_otp_ref_medios
      INSERT INTO bw_otp_ref_medios
         (nro_serial, cod_persona, tipo, ref_medio)
      VALUES
         (v_nro_serial, p_cod_persona, 'C', p_nro_telefono);
     END IF;
      --Actualizar bw_sol_calves
      /*INSERT into bw_sol_claves
         (COD_PERSONA, COD_ORIGEN, SERIAL, TIPO, COD_OFICINA)
      VALUES
         (p_cod_persona, p_origen, v_nro_serial, 'V', v_cod_oficina);
      */
      v_respuesta:=fu_env_mai_clavefacil(v_nro_serial, p_cod_persona , v_cod_oficina);
      --p_nro_serial:=v_nro_serial;
      RETURN 0;
   EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line(sqlerrm);
         RETURN 1;
   END;
   --Enviar mail avisando de la asignacion
END;

FUNCTION fu_cam_nro_celular(p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL, p_nro_telefono IN bw_otp_ref_medios.ref_medio%TYPE,
                            p_nro_serial IN bw_otp_ref_medios.nro_serial%TYPE) RETURN VARCHAR2 IS
   v_parametros VARCHAR2(100);
   c_ws_metodo CONSTANT VARCHAR2(50) := 'UpdateUser';
   v_url          VARCHAR2(100) := '';
   v_ws_respuesta paw_json.JSONStructObj;
   v_resPost      TYP_POSTRESPUESTA;
BEGIN
   UPDATE bw_otp_ref_medios
      SET ref_medio = p_nro_telefono
    WHERE nro_serial = p_nro_serial
      AND cod_persona = p_cod_persona;

   v_url := g_otp_webservice || c_ws_metodo;

   --Aca hay que conectarse al vasco para acualizar

   v_parametros := utl_lms.format_message('userId=%s&mobile=%s', p_cod_persona, p_nro_telefono);

   v_resPost := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   IF (v_resPost.error = 'N') THEN
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      RETURN paw_json.getAttrValue(v_ws_respuesta, 'code');
   END IF;
END;

/**
Se conecta al ServiceIntegrator y consulta si existe un usuario creado en el IdentikeyServer
*/
FUNCTION fu_vas_exi_usuario(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL)
   RETURN NUMBER IS
   v_parametros VARCHAR2(100);
   c_ws_metodo CONSTANT VARCHAR2(50) := 'UserExist';
   v_url          VARCHAR2(100) := '';
   v_ws_respuesta paw_json.JSONStructObj;
   v_userId       VARCHAR2(100);
   v_dominio      ge_par_dinamicos.val_parametro%type;
   v_return       VARCHAR2(10);
   v_resPost      TYP_POSTRESPUESTA;
BEGIN
   IF (p_cod_per_vinculada IS NULL) THEN
      v_userId := utl_lms.format_message('%s', p_cod_persona);
      v_dominio := fug_obt_pardinamico('OTP_DOM_FISICA');
   ELSE
      v_userId := utl_lms.format_message('%s_%s', p_cod_persona, p_cod_per_vinculada);
      v_dominio := fug_obt_pardinamico('OTP_DOM_JURIDICA');
   END IF;
   v_url        := g_otp_webservice || c_ws_metodo;
   v_parametros := utl_lms.format_message('userId=%s&domain=%s', v_userId, v_dominio);
   v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   
   lp_ins_log_mensajeria(v_url||v_parametros,v_resPost.respuesta);
   IF (v_resPost.error = 'N') THEN
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
   ELSE
      RETURN - 99;
   END IF;
   RETURN v_return;
END;

FUNCTION fu_vas_nue_usuario(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                            p_nro_telefono IN bw_otp_ref_medios.ref_medio%TYPE, p_origen IN VARCHAR2) RETURN NUMBER IS
   v_parametros VARCHAR2(200);
   c_ws_metodo CONSTANT VARCHAR2(50) := 'CreateUser';
   v_url          VARCHAR2(100) := '';
   v_ws_respuesta paw_json.JSONStructObj;
   v_userId       VARCHAR2(100);
   v_dominio      ge_par_dinamicos.val_parametro%type;
   v_return       VARCHAR2(10);
   v_resPost      TYP_POSTRESPUESTA;
   v_name         VARCHAR2(200);
   v_cod_persona  ba_personas.cod_persona%TYPE;
   v_nro_telefono bw_otp_ref_medios.ref_medio%TYPE;
   v_descripcion  VARCHAR2(100);
   v_email VARCHAR2(100):='prueba@prueba.com';
BEGIN
   v_cod_persona  := paw_bel.depurarAlfanumerico(p_cod_persona,20);
   v_nro_telefono := paw_bel.depurarAlfanumerico(p_nro_telefono, 20);
   v_descripcion  := paw_bel.depurarAlfanumerico(p_origen, 99);
   
   IF (p_cod_per_vinculada IS NULL) THEN
      v_userId := utl_lms.format_message('%s', v_cod_persona);
      v_dominio := fug_obt_pardinamico('OTP_DOM_FISICA');
   ELSE
      v_userId := utl_lms.format_message('%s_%s', v_cod_persona, p_cod_per_vinculada);
      v_dominio := fug_obt_pardinamico('OTP_DOM_JURIDICA');
   END IF;

   SELECT nom_completo
     INTO v_name
     FROM ba_personas
    WHERE cod_persona = v_cod_persona;

   v_url        := g_otp_webservice || c_ws_metodo;
   v_parametros := utl_lms.format_message('userId=%s&domain=%s&name=%s&desc=%s&mail=%s&mobile=%s', v_userId, v_dominio, v_name, v_descripcion, v_email, v_nro_telefono);
   v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   lp_ins_log_mensajeria(v_url||v_parametros,v_resPost.respuesta);
   IF (v_resPost.error = 'N') THEN
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
   ELSE
      RETURN - 99;
   END IF;
   RETURN v_return;
END;



   /*
   Asiga un token a una persona.
   Solo fisica por el momento
   busca un token disponible y le asigna a la persona
   en Vasco
   */
   FUNCTION fu_vas_asi_token(p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL, 
                         p_cod_per_vinculada IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                         p_nro_serial IN bw_otp_seriales.nro_serial%TYPE) RETURN VARCHAR2 IS
   
     c_ws_metodo    CONSTANT VARCHAR2(50) := 'AssingToken';
     v_url          VARCHAR2(100) := '';
     v_ws_respuesta paw_json.JSONStructObj;
     v_parametros VARCHAR2(100);     
     v_resPost      TYP_POSTRESPUESTA;
     v_cod_persona  ba_personas.cod_persona%TYPE;
     v_cod_per_vinculada  ba_personas.cod_persona%TYPE;
     v_nro_serial    bw_otp_seriales.nro_serial%TYPE;
     v_userId       VARCHAR2(100);
     v_dominio      ge_par_dinamicos.val_parametro%type;
     v_return varchar(10);
   BEGIN
     v_cod_persona  := paw_bel.depurarAlfanumerico(p_cod_persona,20);
     v_nro_serial   := paw_bel.depurarAlfanumerico(p_nro_serial, 20);
     v_cod_per_vinculada:= paw_bel.depurarAlfanumerico(p_cod_per_vinculada,20);
      --Vericar si ya tiene asignado un token virtual
 
     IF (v_cod_per_vinculada IS NULL) THEN
        v_userId := utl_lms.format_message('%s', v_cod_persona);
        v_dominio := fug_obt_pardinamico('OTP_DOM_FISICA');
     ELSE
        v_userId := utl_lms.format_message('%s_%s', v_cod_persona, v_cod_per_vinculada);
        v_dominio := fug_obt_pardinamico('OTP_DOM_JURIDICA');
     END IF;
   v_url        := g_otp_webservice || c_ws_metodo;
   v_parametros := utl_lms.format_message('userId=%s&domain=%s&serialNumber=%s', v_userId, v_dominio, v_nro_serial);
   v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
   lp_ins_log_mensajeria(v_url||v_parametros,v_resPost.respuesta);
   IF (v_resPost.error = 'N') THEN
      v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
      v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
   ELSE
      RETURN - 99;
   END IF;  
   
   return v_return;
   END;


   function fu_obtenerToken(p_codPersona  IN ba_personas.cod_persona%TYPE, p_tipo in varchar) return typ_token
     is
     retorno typ_token;
     begin
        begin
          select s.cod_persona,s.nro_serial,s.estado ,s.tipo
          into retorno.persona,retorno.serial,retorno.estado,retorno.tipo
          from bw_otp_seriales s
          where s.cod_persona=p_codPersona and s.tipo=p_tipo;
          return retorno;
        exception
          when others then
            return null;
        end;
       return null;
     end;
    PROCEDURE lp_SoftokenEnviarNotificacion(p_codPersona IN ba_personas.cod_persona%TYPE,
                                            p_tipoAviso  IN VARCHAR2,
                                            p_celular    IN VARCHAR2 DEFAULT NULL) IS
      v_mensaje   VARCHAR2(150);
      v_telefono  VARCHAR2(20);
      v_resultado VARCHAR2(20);
      v_res_noti_mail VARCHAR(5);
      v_dir_email VARCHAR2(300);
    BEGIN
       v_dir_email := fug_obt_dir_mail_per(p_codPersona);
       
       v_telefono := nvl(p_celular, paw_seg.fu_obt_celular(p_codPersona));
     
       IF (p_tipoAviso = 'N') THEN
          v_mensaje := fug_obt_parentes(6331, 'SOFTOKEN_ALTA');
       ELSIF (p_tipoAviso = 'A') THEN
          v_mensaje := fug_obt_parentes(6331, 'SOFTOKEN_ACTIVACION');
       ELSIF (p_tipoAviso = 'R') THEN
          v_mensaje := fug_obt_parentes(6331, 'SOFTOKEN_RECHA');
       ELSIF (p_tipoAviso = 'B') THEN
          v_mensaje := fug_obt_parentes(6331, 'SOFTOKEN_BLOQUEO'); 
       END IF;
     
       IF v_mensaje is not null then
          v_resultado := paw_not.fu_env_sms_prueba(v_telefono, v_mensaje, 'SOFTOKEN');
          v_res_noti_mail := paw_not.fu_env_email_prueba(v_dir_email, v_mensaje, 'PAW_OTP');
       END IF;
   END;

   PROCEDURE pr_SoftokenNotifEmpre(p_cod_empresa IN bw_td_configuraciones.cod_persona%TYPE,
                                   p_cod_persona IN bw_td_configuraciones.cod_per_vinculo%TYPE,
                                   p_tipoAviso   IN VARCHAR2) IS
      v_mensaje        ge_par_dinamicos.val_parametro%TYPE;
      v_telefono       bw_td_configuraciones.telefono%TYPE;
      v_tie_tkd_activo VARCHAR2(1);
      v_resultado      NUMBER;
      
      CURSOR c_ges_tkd_activos IS
         SELECT td.telefono
           FROM bw_sof_empresas e, bw_sof_seriales s, bw_td_configuraciones td
          WHERE e.cod_per_vinculada = p_cod_empresa
            AND s.id = e.sof_ser_id
            AND s.cod_persona <> p_cod_persona
            AND e.estado = 'A'
            AND e.enrolado = 'S'
            AND e.cod_per_vinculada = td.cod_persona
            AND s.cod_persona = td.cod_per_vinculo
            AND fu_es_aut_softoken(s.cod_persona, e.cod_per_vinculada) = 'S';
   BEGIN
      BEGIN
         SELECT td.telefono
           INTO v_telefono
           FROM bw_td_configuraciones td
          WHERE td.cod_persona = p_cod_empresa 
            AND td.cod_per_vinculo = p_cod_persona
            AND ROWNUM = 1; 
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
      v_tie_tkd_activo := fu_tie_aut_token(p_cod_persona, p_cod_empresa);
   
      v_mensaje := '';
      IF (p_tipoAviso = 'E' or p_tipoAviso = 'P') THEN
         -- si no tiene gestor activo, se notifica que un opearador se comunicara con el cliente
         IF(v_tie_tkd_activo = 'N') THEN
            v_mensaje := fug_obt_pardinamico('TOK_DIG_MSJ_ENR_GES');
         ELSE
            -- si tiene gestor activo, se notifica a todos los gestores activos para que se le pueda activar
            v_mensaje := fug_obt_pardinamico('TOK_DIG_MSJ_ENR_OPER_GES');
            v_mensaje := replace(v_mensaje, '%e', fue_obt_nom_comercial(p_cod_empresa));
            FOR g IN c_ges_tkd_activos LOOP
               v_resultado := paw_not.fu_env_sms_prueba(g.telefono, v_mensaje, 'TOKENDIGITALEMPRESA');
            END LOOP;
            -- y se notifica al usuario que un autorizador lo activara
            v_mensaje := fug_obt_pardinamico('TOK_DIG_MSJ_ENR_OPER');
            v_mensaje := replace(v_mensaje, '%e', fue_obt_nom_comercial(p_cod_empresa));
         END IF;
      ELSIF (p_tipoAviso = 'A') THEN
         v_mensaje := fug_obt_pardinamico('TOK_DIG_MSJ_ACT');
      ELSIF (p_tipoAviso = 'R') THEN
         v_mensaje := fug_obt_pardinamico('TOK_DIG_MSJ_BLO');
      ELSIF (p_tipoAviso = 'B') THEN
         v_mensaje := fug_obt_pardinamico('TOK_DIG_MSJ_REC');
      END IF;     
      v_resultado := paw_not.fu_env_sms_prueba(v_telefono, v_mensaje, 'TOKENDIGITALEMPRESA');
   END;
 
 
   PROCEDURE lp_ins_tel_softtoken(p_codPersona IN ba_personas.cod_persona%TYPE,
                                   p_tip_persona IN VARCHAR2,
                                   p_tel_area      IN VARCHAR2,
                                   p_nro_tel    IN VARCHAR2) IS
   v_tip_telefono VARCHAR(1);
   BEGIN
          IF p_tip_persona = 'F' THEN
            v_tip_telefono := 'S';
          ELSE 
            v_tip_telefono := 'T';
          END IF;
            
          INSERT INTO ba_telefonos
          (COD_PERSONA, TIPO, TIP_LINEA, AREA, TELEFONO, OBSERVACION)
          VALUES
          (p_codPersona, v_tip_telefono, 'C' , p_tel_area, p_nro_tel, 'NUMERO INICIAL DE ENROLL TOKEN DIGITAL');
   END;
   
   PROCEDURE lp_ins_pf_ini_sof_seriales(p_codPersona IN ba_personas.cod_persona%TYPE,
                            p_nroSerial IN bw_otp_seriales.nro_serial%TYPE,
                            p_nro_telefono IN VARCHAR2,
                            p_can_activacion IN VARCHAR2) IS
      v_id NUMBER;
   BEGIN
        SELECT S_BW_SOF_SERIALES.NEXTVAL
              INTO v_id
              FROM dual;
              
          INSERT INTO BW_SOF_SERIALES (ID,
             NRO_SERIAL, 
             COD_PERSONA, 
             NRO_TEL_ENROLADO,
             TIP_CAN_SOL_ACTIVACION,
             DOMINIO) 
          VALUES 
             (v_id,
             p_nroSerial,
             p_codPersona,
             p_nro_telefono,
             p_can_activacion,
             'RETAILPY');
   END;
   
   FUNCTION fu_altaSoftoken(p_codPersona IN ba_personas.cod_persona%TYPE, p_tipo IN VARCHAR2,
                            p_nroSerial IN bw_otp_seriales.nro_serial%TYPE,
                            p_nro_telefono IN VARCHAR2, p_can_activacion IN VARCHAR2) RETURN VARCHAR2 IS
     v_lote   VARCHAR2(10);
     v_token  typ_token;
     v_estado VARCHAR2(1) := 'K'; --Siempre se hara el callback
     v_retorno VARCHAR2(30);
     v_id NUMBER;  
     v_area ba_telefonos.area%TYPE := NULL;
     v_tel ba_telefonos.telefono%TYPE := NULL;
     v_count NUMBER;
     v_tie_nro_softtoken NUMBER;
     v_cod_operacion  VARCHAR2(3) := '008';
     v_bitacoratitulo VARCHAR(100) := substr(TRIM('fu_altaSoftoken - p_serial:' || p_nroSerial || ' ,p_nro_telefono' || p_nro_telefono), 0,99);
   BEGIN
   
     IF (p_tipo = 'S') THEN
       v_lote := 'SOFTFIS';
     ELSIF (p_tipo = 'E') THEN
       v_lote := 'SOFTJUR';
     ELSE
       RETURN 'SOFINVTIP';
     END IF;

     --Si tiene celular extranjero marcar para callback
     IF (fu_obtenerTelefonoPais(p_codPersona) IS NOT NULL) THEN
       v_estado := 'K';
       v_retorno:='SOFOKCALLIN';
     END IF;

     --Sino tiene tarjeta de debito activa se marca para callback
     if(fu_obtenerCanTarDebito(p_codPersona)=0)then
         v_estado := 'K';
         v_retorno:='SOFOKCALLPY';
     end if;
     -- MG: migrado a app de GNB
     IF (p_can_activacion = 'MG') THEN
        v_estado := 'A';
     END IF;

    BEGIN
        --Obtenemos el area y telefono del telefono enrolado
         Select area, telefono 
         into v_area, v_tel
         from ba_telefonos
         where tip_linea = 'C' AND cod_persona = p_codPersona AND
         AREA || TELEFONO = p_nro_telefono and rownum = 1;
    EXCEPTION
        WHEN OTHERS THEN
            NULL; --no pudimos hacer match, no registraremos el telefono
    END;
     
     --vemos si ya tiene un token(de otp_seriales) para saber si insertamos o actualizamos
     v_token := fu_obtenerToken(p_codPersona, p_tipo);
   
     --es la primera vez que se enrolla
     IF (v_token.serial IS NULL) THEN
       BEGIN

         INSERT INTO bw_otp_seriales
           (tipo, nro_lote, nro_serial, cod_persona, estado)
         VALUES
           (p_tipo, v_lote, p_nroSerial, p_codPersona, v_estado);
             
       EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
           UPDATE bw_otp_seriales
              SET estado = v_estado, nro_serial = p_nroSerial
            WHERE cod_persona = p_codPersona
              AND tipo = p_tipo;
         WHEN OTHERS THEN
           RETURN 'SOFERRINS';
       END;
       
       BEGIN       
            lp_ins_pf_ini_sof_seriales(p_codPersona, p_nroSerial, p_nro_telefono, p_can_activacion);          
       EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               --ya existe
               NULL;
            WHEN OTHERS THEN
                paw_uti.pr_insertarBitacora(p_codPersona,
                                    '994',
                                    null,
                                    v_cod_operacion,
                                    null,
                                    v_bitacoraTitulo || ' ' || ' llamada a lp_ins_pf_ini_sof_seriales' ||
                                    'ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] : ERROR: ['|| sqlcode ||']',
                                    paw_uti.BITACORA_ERROR);
                RETURN 'SOFERRINS';
       END;
       
       IF v_tel is not null then
          lp_ins_tel_softtoken(p_codPersona, 'F', v_area, v_tel);
       END IF;

     ELSE
     --es un reenroll
     
       UPDATE bw_otp_seriales
          SET estado = v_estado, nro_serial = p_nroSerial
        WHERE cod_persona = p_codPersona
          AND tipo = p_tipo;

       --igual chequeamos si existe registro en sof_seriales       
       SELECT count(*)
         INTO v_count 
         FROM BW_SOF_SERIALES
        WHERE NRO_SERIAL = p_nroSerial
          AND COD_PERSONA = p_codPersona
          AND DOMINIO = 'RETAILPY';

       --igual chequeamos si esta insertado el telefono catastrado     
       SELECT count(*)
         INTO v_tie_nro_softtoken
         FROM ba_telefonos
        WHERE COD_PERSONA =p_codPersona and tipo = 'S';

       IF v_count = 0 THEN      
           BEGIN    
                lp_ins_pf_ini_sof_seriales(p_codPersona, p_nroSerial, p_nro_telefono, p_can_activacion);      
           EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                   --ya existe
                   NULL;
                WHEN OTHERS THEN
                   paw_uti.pr_insertarBitacora(p_codPersona,
                                    '994',
                                    null,
                                    v_cod_operacion,
                                    null,
                                    v_bitacoraTitulo || ' ' || ' llamada a lp_ins_pf_ini_sof_seriales' ||
                                    'ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] : ERROR: ['|| sqlcode ||']',
                                    paw_uti.BITACORA_ERROR);
                    RETURN 'SOFERRINS';
           END; 
       ELSE
          UPDATE BW_SOF_SERIALES
             SET NRO_TEL_ENROLADO = p_nro_telefono,
                 FEC_ULT_SOLICITUD = SYSDATE
           WHERE NRO_SERIAL = p_nroSerial
             AND COD_PERSONA = p_codPersona
             AND DOMINIO = 'RETAILPY';
             
           --Para marcar que fue una migracion  
           BEGIN
                IF (p_can_activacion = 'MG') THEN
                     UPDATE BW_SOF_SERIALES
                        SET MIGRADO = 2
                     WHERE NRO_SERIAL = p_nroSerial
                         AND COD_PERSONA = p_codPersona
                         AND DOMINIO = 'RETAILPY';
                ELSE
                    -- solo en el caso que no es migracion y es un reenroll normal se hace update ddel canal
                    UPDATE BW_SOF_SERIALES
                      SET TIP_CAN_SOL_ACTIVACION = p_can_activacion
                    WHERE NRO_SERIAL = p_nroSerial
                      AND COD_PERSONA = p_codPersona
                      AND DOMINIO = 'RETAILPY';
                END IF;
           EXCEPTION
                WHEN OTHERS THEN
                    NULL;
           END;
       END IF;
       
       IF v_tel is not null then
          IF v_tie_nro_softtoken = 0 THEN
             lp_ins_tel_softtoken(p_codPersona, 'F', v_area, v_tel);
          ELSE
             UPDATE ba_telefonos
                SET AREA = v_area, TELEFONO = v_tel, OBSERVACION = 'NUMERO DE ENROLL TOKEN DIGITAL'
              WHERE COD_PERSONA = p_codPersona AND TIPO = 'S';
          END IF;
       END IF;
     END IF;

     BEGIN
        IF (p_can_activacion <> 'MG') THEN
            lp_SoftokenEnviarNotificacion(p_codPersona, 'N', p_nro_telefono);
        END IF;      
     EXCEPTION
            WHEN OTHERS THEN
                NULL;
     END;

     RETURN paw_uti.MSG_OK;
   EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_insertarBitacora(p_codPersona,
                                    '994',
                                    null,
                                    v_cod_operacion,
                                    null,
                                    v_bitacoraTitulo || ' ' ||
                                    'ORA-ERR: [' || SUBSTR(SQLERRM, 1, 200)|| '] : ERROR: ['|| sqlcode ||']',
                                  paw_uti.BITACORA_ERROR);
        RETURN 'SOFERRINS';
   END;

    

FUNCTION fu_obtenerTelefonoPais(p_codPersona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
  v_nroTelefono VARCHAR2(30);
BEGIN
  BEGIN
    SELECT AREA || TELEFONO
    INTO   v_nroTelefono
    FROM   ba_telefonos
    WHERE  area LIKE '002%'
           AND tip_linea = 'C';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  RETURN v_nroTelefono;
END;

FUNCTION fu_obtenerCanTarDebito(p_codPersona IN ba_personas.cod_persona%TYPE) RETURN NUMBER IS
  v_cantidad NUMBER(4);
BEGIN
  BEGIN
    SELECT COUNT(*)
    INTO   v_cantidad
    FROM   ah_tar_debitos t, ge_cta_clientes c
    WHERE  t.cod_persona = p_codPersona
           AND t.tar_activa = 'S'
           AND c.nro_cuenta = t.nro_cuenta
           AND c.relacion = 'P'
           AND fec_vencimiento > SYSDATE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;

  RETURN v_cantidad;
END;


FUNCTION fu_cambiarEstadoSoftoken(p_serial IN bw_otp_seriales.nro_serial%TYPE,
                                  p_codPersona IN ba_personas.cod_persona%TYPE, p_estado IN VARCHAR2,
                                  p_motivo IN VARCHAR2, p_usuario IN VARCHAR2) RETURN NUMBER IS
								  
	 --- DDEVOLUT-1296-                           
    cursor c_lim_activacion(p_cod_persona varchar2) is
          select l.cod_persona,l.cod_tip_mensaje,l.tip_persona,l.cod_moneda,l.nro_cuenta,min(l.mto_minimo) as minimo,max(l.mto_maximo) as maximo
          from bw_cla_lim_montos l
          where l.cod_persona=p_cod_persona
          and  l.tip_persona='F'
          AND  l.cod_tip_clave in ('K', 'T')
          and l.activo='A'
          group by l.cod_persona,l.cod_tip_mensaje,l.tip_persona,l.cod_moneda,l.nro_cuenta;                                               
 -- FIN - DDEVOLUT-1296- 							  
								  
    v_actualizados NUMBER;
    v_numero VARCHAR2(20);
BEGIN
  BEGIN

    UPDATE bw_otp_seriales s
    SET    s.estado = p_estado, s.observacion = p_motivo, s.usu_adm_modificacion = p_usuario
    WHERE  s.nro_serial = p_serial
           AND s.cod_persona = p_codPersona;
    IF (SQL%ROWCOUNT = 0) THEN
      RETURN 2;
    END IF;

    IF p_codPersona is not null THEN
        UPDATE bw_otp_seriales s
        SET    s.usu_activacion = p_usuario
        WHERE  s.nro_serial = p_serial
               AND s.cod_persona = p_codPersona;
    END IF;

    IF p_estado = 'A' THEN
        UPDATE bw_otp_seriales s
        SET    s.fec_activacion = SYSDATE
        WHERE  s.nro_serial = p_serial
               AND s.cod_persona = p_codPersona;
    END IF;
   
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END;
  
   -- INICIO- DDEVOLUT-1296-  
  BEGIN
      FOR i IN c_lim_activacion(p_codPersona) LOOP
          if i.minimo=1  and i.maximo=1 then
              exit;
          else 
                BEGIN
                     INSERT INTO bw_cla_lim_montos
                       (cod_tip_mensaje,cod_tip_clave, tip_persona, cod_moneda, nro_cuenta,cod_persona,activo,mto_minimo,mto_maximo)
                     VALUES
                       (i.cod_tip_mensaje,'S','F',i.cod_moneda,i.nro_cuenta,i.cod_persona,'A',i.minimo,i.maximo);   
                EXCEPTION
                WHEN OTHERS THEN
                       v_actualizados := PAW_BCE.fu_inh_lim_cliente(p_codPersona);
                END;
                null;
          end if;  
      END LOOP;
    END;
 -- FIN - DDEVOLUT-1296-  
  
  --Si es una actualizacion se inhabilitan sus limites
  if p_estado = 'A' then
    v_actualizados := PAW_BCE.fu_inh_lim_cliente(p_codPersona);
  END if;
  
  BEGIN
   SELECT NRO_TEL_ENROLADO 
   INTO v_numero
   FROM  BW_SOF_SERIALES
   WHERE NRO_SERIAL = p_serial
        AND COD_PERSONA = p_codPersona
        AND DOMINIO = 'RETAILPY';
  EXCEPTION
    WHEN no_data_found THEN
        v_numero := null;
  END;
            
  lp_SoftokenEnviarNotificacion(p_codPersona, p_estado, v_numero);  
  
  RETURN 0;
END;

FUNCTION fu_obtenerAsignacionSofttoken(p_codPersona IN ba_personas.cod_persona%TYPE, 
                                       p_tipoAcceso IN VARCHAR2,
                                       p_cod_empresa IN ba_personas.cod_persona%TYPE DEFAULT NULL)
  RETURN VARCHAR2 IS
  v_existe VARCHAR2(1) := 'N';
BEGIN
  IF (p_tipoAcceso = 'F') THEN
    --buscar softoken
    BEGIN
      SELECT 'S'
        INTO v_existe
        FROM bw_otp_seriales s
       WHERE s.tipo = 'S'
         AND s.cod_persona = p_codPersona
         AND s.estado in ('A', 'B', 'I'); --solo considera que tenes Token solo si esta en estado Activo o Bloqueado(aqui no podra operar) o Inactivo
    EXCEPTION
      WHEN OTHERS THEN
        return NULL;
    END;
    if(v_existe ='S') then
        return 'SF';
    end if;
  ELSE    
    BEGIN
       SELECT 'S'
         INTO v_existe
         FROM BW_SOF_SERIALES S, BW_SOF_EMPRESAS E
        WHERE S.ID = E.SOF_SER_ID 
          AND E.ENROLADO = 'S'
          AND E.COD_PER_VINCULADA = p_cod_empresa
          AND S.COD_PERSONA = p_codPersona;
    EXCEPTION
      WHEN OTHERS THEN
        return NULL;
    END;
    if(v_existe ='S') then
        return 'SE';
    end if;
  END IF;
  return null;
END;

   FUNCTION fu_obt_inf_softtoken(p_nro_serial IN VARCHAR2,
                                 p_cod_persona IN VARCHAR2,
                                 p_cod_per_juridica IN VARCHAR2) 
       RETURN TYP_MAPA IS
     v_retorno           typ_mapa := typ_mapa();
     v_map_softtoken     typ_listaClaveValor := typ_listaClaveValor();
     v_nro_serial        bw_sof_seriales.nro_serial%type;
     v_dominio           bw_sof_seriales.dominio%type;
     v_cod_persona       bw_sof_seriales.cod_persona%type;
     v_cod_per_vinculada bw_sof_empresas.cod_per_vinculada%type;
     v_cod_dispositivo   bw_sof_seriales.cod_dispositivo%type;
     v_estado            bw_sof_empresas.estado%type;
     v_fec_insercion     bw_sof_seriales.fec_insercion%type;
     v_cod_canal         VARCHAR2(3) := '990';
     v_cod_operacion     VARCHAR2(3) := '008';
     
     CLAVE_NRO_SERIAL        CONSTANT VARCHAR2(20) := 'NRO_SERIAL';
     CLAVE_DOMINIO           CONSTANT VARCHAR2(20) := 'DOMINIO';
     CLAVE_COD_PERSONA       CONSTANT VARCHAR2(20) := 'COD_PERSONA';
     CLAVE_COD_PER_VINCULADA CONSTANT VARCHAR2(20) := 'COD_PER_VINCULADA';
     CLAVE_COD_DISPOSITIVO   CONSTANT VARCHAR2(20) := 'COD_DISPOSITIVO';
     CLAVE_ESTADO            CONSTANT VARCHAR2(20) := 'ESTADO';
     CLAVE_FEC_INSERCION     CONSTANT VARCHAR2(20) := 'FEC_INSERCION';
   BEGIN
       PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       PAW_UTI.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, p_cod_per_juridica, 
           'Obteniendo informacion de token: ' || p_nro_serial || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null), 
           PAW_UTI.BITACORA_ENTRADA);
        
       BEGIN
           SELECT ser.nro_serial, ser.dominio, ser.cod_persona, emp.cod_per_vinculada, ser.cod_dispositivo, emp.estado, ser.fec_insercion
           INTO   v_nro_serial,   v_dominio,   v_cod_persona,   v_cod_per_vinculada,   v_cod_dispositivo,   v_estado,   v_fec_insercion
           FROM BW_SOF_SERIALES ser JOIN BW_SOF_EMPRESAS emp ON ser.id = emp.sof_ser_id
           WHERE ser.nro_serial = p_nro_serial
             AND ser.cod_persona = p_cod_persona
             AND emp.cod_per_vinculada = p_cod_per_juridica;
       EXCEPTION
           WHEN no_data_found THEN
               PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               PAW_UTI.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, p_cod_per_juridica, 
                   'Serial de token invalido:' || p_nro_serial || ' ' || PAW_UTI.fu_generarBitacora(v_retorno.error,v_retorno.nombreRespuesta,v_retorno.descripcionRespuesta,null), 
                   PAW_UTI.BITACORA_ERROR);
               return v_retorno;
       END;
       
       IF v_retorno.error = 'N' THEN
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_NRO_SERIAL, v_nro_serial, 'VARCHAR');
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_DOMINIO, v_dominio, 'VARCHAR');
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_COD_PERSONA, v_cod_persona, 'VARCHAR');
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_COD_PER_VINCULADA, v_cod_per_vinculada, 'VARCHAR');
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_COD_DISPOSITIVO, v_cod_dispositivo, 'VARCHAR');
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_ESTADO, v_estado, 'VARCHAR');
           PAW_UTI.pr_add_value(v_map_softtoken, CLAVE_FEC_INSERCION, v_FEC_INSERCION, 'DATE');
           
           v_retorno.datosAdicionales := v_map_softtoken;
           v_retorno.cantidad := v_map_softtoken.count;
           
           return v_retorno;
       END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         PAW_UTI.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, p_cod_per_juridica, 
             'fu_obt_inf_softtoken - ' || SQLERRM, PAW_UTI.BITACORA_ERROR);
         RETURN v_retorno;
   END;

   FUNCTION fu_obt_inf_enroll(p_cod_persona IN VARCHAR2,
                              p_cod_per_juridica IN VARCHAR2) 
       RETURN TYP_MAPA IS
     v_retorno           typ_mapa := typ_mapa();
     v_map_per_enroll    typ_listaClaveValor := typ_listaClaveValor();

     v_enrolable         VARCHAR2(1);
     v_autorizador       VARCHAR2(1);
     v_telefono          bw_td_configuraciones.telefono%type;
     v_enrolado          VARCHAR2(1);
     v_nro_serial        bw_sof_seriales.nro_serial%type;
     v_cod_dispositivo   bw_sof_seriales.cod_dispositivo%type;
     v_sts_status        bw_sof_seriales.sts_status%type;
     v_estado            bw_sof_empresas.estado%type;
     v_sin_gestor        VARCHAR2(1);
     v_sin_verificar     bw_td_configuraciones.sin_verificar%type;

     v_cod_canal         VARCHAR2(3) := '990';
     v_cod_operacion     VARCHAR2(3) := '008';
     
     CLAVE_ENROLABLE       CONSTANT VARCHAR2(20) := 'ENROLABLE';
     CLAVE_AUTORIZADOR     CONSTANT VARCHAR2(20) := 'AUTORIZADOR';
     CLAVE_TELEFONO        CONSTANT VARCHAR2(20) := 'TELEFONO';
     CLAVE_ENROLADO        CONSTANT VARCHAR2(20) := 'ENROLADO';
     CLAVE_NRO_SERIAL      CONSTANT VARCHAR2(20) := 'NRO_SERIAL';
     CLAVE_COD_DISPOSITIVO CONSTANT VARCHAR2(20) := 'COD_DISPOSITIVO';
     CLAVE_STS_STATUS      CONSTANT VARCHAR2(20) := 'STS_STATUS';
     CLAVE_ESTADO          CONSTANT VARCHAR2(20) := 'ESTADO';
     CLAVE_SIN_GESTOR      CONSTANT VARCHAR2(20) := 'SIN_GESTOR';
     CLAVE_SIN_VERIFICAR   CONSTANT VARCHAR2(20) := 'SIN_VERIFICAR';
     CLAVE_TOK_ADM_ACTIVO  CONSTANT VARCHAR2(20) := 'TOK_ADM_ACTIVO';
   BEGIN
      PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      PAW_UTI.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, p_cod_per_juridica, 
           'Obteniendo permisos para enroll a SoftToken para p_cod_persona: ' || p_cod_persona || ', p_cod_per_juridica: ' || p_cod_per_juridica || '. ' || PAW_UTI.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, null), 
           PAW_UTI.BITACORA_ENTRADA);
       
      BEGIN
         SELECT 'S', fu_es_aut_softoken(p_cod_persona, p_cod_per_juridica), conf.telefono, conf.sin_verificar
           INTO v_enrolable, v_autorizador, v_telefono, v_sin_verificar 
           FROM BW_TD_CONFIGURACIONES conf
          WHERE conf.cod_per_vinculo = p_cod_persona
            AND conf.cod_persona = p_cod_per_juridica;
      EXCEPTION
         WHEN no_data_found THEN
            v_enrolable := 'N';
      END;
      BEGIN
         SELECT 'N'
           INTO v_enrolable
           FROM BW_SOF_SERIALES S, BW_SOF_EMPRESAS E 
          WHERE S.ID = E.SOF_SER_ID
            AND S.COD_PERSONA = p_cod_persona
            AND E.Cod_Per_Vinculada = p_cod_per_juridica
            AND E.ESTADO = 'B';
      EXCEPTION 
         WHEN OTHERS THEN
            NULL;
      END;
      IF v_enrolable = 'N' THEN
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_ENROLABLE, v_enrolable, 'VARCHAR');
      ELSE
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_ENROLABLE, v_enrolable, 'VARCHAR');
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_AUTORIZADOR, v_autorizador, 'VARCHAR');
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_TELEFONO, v_telefono, 'VARCHAR');
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_SIN_VERIFICAR, v_sin_verificar, 'VARCHAR');

         BEGIN
               SELECT 'S', ser.nro_serial, ser.cod_dispositivo, emp.estado, ser.sts_status
               INTO v_enrolado, v_nro_serial, v_cod_dispositivo, v_estado, v_sts_status
              FROM BW_SOF_SERIALES ser JOIN BW_SOF_EMPRESAS emp ON ser.id = emp.sof_ser_id
             WHERE ser.cod_persona = p_cod_persona 
               AND emp.cod_per_vinculada = p_cod_per_juridica;
         EXCEPTION
            WHEN no_data_found THEN
               v_enrolado := 'N';
         END;
           
         IF v_enrolado = 'N' THEN
            PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_ENROLADO, v_enrolado, 'VARCHAR');
         ELSE
            PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_ENROLADO, v_enrolado, 'VARCHAR');
            PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_NRO_SERIAL, v_nro_serial, 'VARCHAR');
            PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_ESTADO, v_estado, 'VARCHAR');
            PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_COD_DISPOSITIVO, v_cod_dispositivo, 'VARCHAR');
               PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_STS_STATUS, v_sts_status, 'NUMBER');
         END IF;
         v_sin_gestor := NVL(FUE_PER_DAT_ADICIONAL(p_cod_per_juridica, 'EMP_SIN_GES_TD'), 'N');  
         
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_SIN_GESTOR, v_sin_gestor, 'VARCHAR');
         PAW_UTI.pr_add_value(v_map_per_enroll, CLAVE_TOK_ADM_ACTIVO, fu_tie_aut_token(p_cod_persona, p_cod_per_juridica), 'VARCHAR');
       END IF;

       v_retorno.datosAdicionales := v_map_per_enroll;
       v_retorno.cantidad := v_map_per_enroll.count;

       RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(PAW_UTI.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         PAW_UTI.pr_insertarBitacora(p_cod_persona, v_cod_canal, '', v_cod_operacion, p_cod_per_juridica, 
             'fu_obt_inf_enroll - ' || SQLERRM, PAW_UTI.BITACORA_ERROR);
         RETURN v_retorno;
   END;

FUNCTION fu_cambiarEstadoSoftokenEmpre(p_serial          IN bw_sof_seriales.nro_serial%TYPE, 
                                       p_estado          IN bw_sof_empresas.estado%TYPE,
                                       p_cod_persona     IN bw_sof_seriales.cod_persona%TYPE,
                                       p_cod_per_empresa IN bw_sof_empresas.cod_per_vinculada%TYPE,
                                       p_motivo          IN bw_sof_empresas.observacion%TYPE, 
                                       p_usuario         IN bw_sof_empresas.usu_activacion%TYPE) RETURN NUMBER IS
  v_enrolado          VARCHAR2(1) := 'N';
  v_nro_doc_pendiente bw_mov_pendientes.nro_documento%TYPE;
  v_est_pendiente     bw_mov_pendientes.estado%TYPE := 'A'; 
  v_motivo            VARCHAR2(1000) := null;
BEGIN
   BEGIN
      SELECT p.nro_documento
        INTO v_nro_doc_pendiente
        FROM bw_mov_pendientes p
       WHERE p.cod_per_principal = p_cod_per_empresa
         AND p.cod_per_ingreso = p_cod_persona
         AND p.cod_tip_mensaje = '008'
         AND p.dato = p_serial
         AND p.estado = 'P'
         AND p.fec_insercion > trunc(SYSDATE - 1);
   EXCEPTION
      WHEN OTHERS THEN
         v_nro_doc_pendiente := NULL;
   END;
   BEGIN
      IF p_estado = 'A' THEN
         v_enrolado := 'S';
         v_est_pendiente := 'C';
         UPDATE bw_sof_empresas s
             SET s.estado = p_estado, 
                 s.enrolado = 'S',
                 s.fec_activacion = SYSDATE,
                 s.usu_activacion = p_usuario,
                 s.usu_adm_modificacion = p_usuario,
                 s.observacion = p_motivo
         WHERE s.sof_ser_id = (Select p.id 
                                   from BW_SOF_SERIALES p 
                                  where p.nro_serial = p_serial 
                                    and p.cod_persona = p_cod_persona)
             AND s.cod_per_vinculada = p_cod_per_empresa;        
      ELSE
    
      UPDATE bw_sof_empresas s
         SET s.estado = p_estado, 
               s.usu_adm_modificacion = p_usuario,
               s.enrolado = v_enrolado,                          
               s.observacion = p_motivo
       WHERE s.sof_ser_id = (Select p.id 
                               from BW_SOF_SERIALES p 
                              where p.nro_serial = p_serial 
                                and p.cod_persona = p_cod_persona)
         AND s.cod_per_vinculada = p_cod_per_empresa;  
      END IF;   
      IF (SQL%ROWCOUNT = 0) THEN
         RETURN 2;
      END IF;
      -- si se activo desde el AdminToken, se debe marcar si existe un mov. pendiente asociado
      IF v_nro_doc_pendiente IS NOT NULL THEN
         UPDATE bw_mov_pendientes p
            SET p.estado = v_est_pendiente, p.can_aut_faltantes = 0, 
                p.etiqueta2 = 'OBS.', p.dato2 = substr('MODIFICADO en TDADMIN, est: '||p_estado, 1, 50)
          WHERE p.nro_documento = v_nro_doc_pendiente;
	  else
          UPDATE bw_mov_pendientes p
            SET p.estado = 'A', p.can_aut_faltantes = 0, 
                p.etiqueta2 = 'OBS.', p.dato2 = substr('MODIFICADO en TDADMIN, est: '||p_estado, 1, 50)
          WHERE p.cod_per_principal =p_cod_per_empresa
          AND p.cod_tip_mensaje = '008'
          AND p.dato = p_serial
          AND p.estado = 'P';  	  
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN 1;
    END;  
    pr_SoftokenNotifEmpre(p_cod_per_empresa, p_cod_persona, p_estado); 
    RETURN 0;
END;



FUNCTION fu_obt_soft_fisica(p_fil_serial IN VARCHAR2, 
                            p_fil_estado IN VARCHAR2,  
                            p_fil_desde IN VARCHAR2,                            
                            p_fil_hasta IN VARCHAR2,               
                            p_fil_codPersona IN VARCHAR2, 
                            p_fil_documento IN VARCHAR2, 
                            p_fil_nombre IN VARCHAR2,
                            p_fil_can_act IN VARCHAR2,
                            p_nroPagina        IN NUMBER DEFAULT NULL,
                            p_cantItemsPagina  IN NUMBER DEFAULT NULL) RETURN typ_obtlistasofttokenadm IS

     v_retorno          typ_obtlistasofttokenadm := typ_obtlistasofttokenadm();
     detalle            typ_softtokenadm := typ_softtokenadm();
     lista              typ_listasofttokenadm := typ_listasofttokenadm();
     v_can_detalles     NUMBER := 0;
     v_reg_inicial      NUMBER(10);
     v_reg_final        NUMBER(10);
     v_can_pagina       NUMBER(5); -- movimientos por pagina
     v_nro_pagina       NUMBER(3); -- nro de pagina
     v_cantidad         NUMBER(5); -- nro de registros 
     v_fec_actual       DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy;
     v_fec_desde        DATE; 
     v_fec_hasta        DATE;                           
      --Consulta de los softokens      
      
     CURSOR c_softtokens IS
        SELECT ser.nro_serial nro_serial, ser.estado estado, ser.fec_insercion fec_pri_alta,
               ser.usu_adm_modificacion usu_modificacion, ser.usu_activacion usu_activacion, ser.fec_activacion fec_activacion, ser.fec_modificacion fec_modif_estado, 
               ser.observacion observacion, tok.cod_dispositivo as dispositivo, tok.cod_persona as cod_cliente, tok.fec_ult_solicitud  fec_ult_sol_activacion,
               tok.nro_tel_enrolado nro_tel, tok.tip_can_sol_activacion can_activacion, ua.nombre usu_act_nombre,um.nombre usu_mod_nombre,
               pe.nro_documento as documento, pe.nom_completo as nombre   
        FROM BW_SOF_SERIALES tok
        JOIN BW_OTP_SERIALES ser ON ser.nro_serial = tok.nro_serial
        JOIN BA_PERSONAS pe ON pe.cod_persona = tok.cod_persona
        LEFT JOIN BA_USUARIOS um ON upper(um.cod_usuario) = upper(ser.usu_adm_modificacion)
        LEFT JOIN BA_USUARIOS ua ON upper(ua.cod_usuario) = upper(ser.usu_activacion)
        WHERE (tok.fec_ult_solicitud BETWEEN v_fec_desde AND v_fec_hasta) AND 
              (LOWER(TRIM(tok.nro_serial)) LIKE '%' || LOWER( TRIM(p_fil_serial)) || '%') AND
              (LOWER(TRIM(ser.estado)) LIKE '%' || LOWER( TRIM(p_fil_estado)) || '%') AND
              (LOWER(TRIM(tok.cod_persona)) LIKE '%' || LOWER( TRIM(p_fil_codPersona)) || '%') AND
              --(LOWER(TRIM(tok.tip_can_sol_activacion)) LIKE '%' || LOWER( TRIM(p_fil_can_act)) || '%') AND
              (LOWER(TRIM(pe.nro_documento)) LIKE '%' || LOWER( TRIM(p_fil_documento)) || '%') AND
              (LOWER(TRIM(pe.nom_completo)) LIKE '%' || LOWER( TRIM(p_fil_nombre)) || '%')
        ORDER BY tok.fec_ult_solicitud ASC;
         
     BEGIN
     
       IF p_fil_desde IS NULL THEN
            v_fec_desde := TO_DATE('2019/01/01' || ' 00:00:00', 'YYYY/MM/DD HH24:MI:SS');--incio de los tiempos de token digital       
       ELSE
         v_fec_desde := TO_DATE(p_fil_desde || ' 00:00:00', 'YYYY/MM/DD HH24:MI:SS');       
       END IF;
       
       IF p_fil_hasta IS NULL THEN
         v_fec_hasta := v_fec_actual + 2;
       ELSE
         v_fec_hasta := TO_DATE(p_fil_hasta || ' 23:59:59', 'YYYY/MM/DD HH24:MI:SS');        
       END IF;
     
       SELECT count(*) into v_cantidad
         FROM BW_SOF_SERIALES tok
         JOIN BW_OTP_SERIALES ser ON ser.nro_serial = tok.nro_serial
         JOIN BA_PERSONAS pe ON pe.cod_persona = tok.cod_persona  
         LEFT JOIN BA_USUARIOS u ON u.cod_usuario = ser.usu_activacion
         WHERE (ser.fec_insercion BETWEEN v_fec_desde AND v_fec_hasta) AND 
              (LOWER(TRIM(tok.nro_serial)) LIKE '%' || LOWER( TRIM(p_fil_serial)) || '%') AND
              (LOWER(TRIM(ser.estado)) LIKE '%' || LOWER( TRIM(p_fil_estado)) || '%') AND
              (LOWER(TRIM(tok.cod_persona)) LIKE '%' || LOWER( TRIM(p_fil_codPersona)) || '%') AND
              --(LOWER(TRIM(tok.tip_can_sol_activacion)) LIKE '%' || LOWER( TRIM(p_fil_can_act)) || '%') AND
              (LOWER(TRIM(pe.nro_documento)) LIKE '%' || LOWER( TRIM(p_fil_documento)) || '%') AND
              (LOWER(TRIM(pe.nom_completo)) LIKE '%' || LOWER( TRIM(p_fil_nombre)) || '%');
     
       v_nro_pagina  := p_nroPagina+1; --la pagina
       v_can_pagina  := p_cantItemsPagina; --items en la pagina

       v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
       v_reg_final   := (v_nro_pagina * v_can_pagina); 
     
     
       FOR softoken IN c_softtokens LOOP
          v_can_detalles           := v_can_detalles + 1;
          
          IF (v_reg_inicial IS NULL) OR (v_can_detalles >= v_reg_inicial) THEN
            detalle.nro_serial       := softoken.nro_serial;
            detalle.cod_estado       := softoken.estado;
            detalle.cod_dispositivo  := softoken.dispositivo;
            detalle.fec_alta         := softoken.fec_pri_alta;
            detalle.cod_cliente      := softoken.cod_cliente;
            detalle.nro_documento    := softoken.documento;
            detalle.nom_completo     := softoken.nombre;
            detalle.fec_modificacion := softoken.fec_modif_estado;
            detalle.num_telefono     := softoken.nro_tel; 
            detalle.fec_ult_solicitud := softoken.fec_ult_sol_activacion;
            detalle.fec_modificacion := softoken.fec_modif_estado;
            detalle.fec_activacion   := softoken.fec_activacion;
            detalle.cod_usu_activacion := softoken.usu_activacion;
            detalle.nom_usu_activacion := softoken.usu_act_nombre;
            detalle.cod_usu_modificacion := softoken.usu_modificacion;
            detalle.nom_usu_modificacion := softoken.usu_mod_nombre;
            detalle.can_sol_activacion := softoken.can_activacion;
            if(softoken.estado = 'B') then
              detalle.observacion := softoken.observacion;
            end if;
      
            lista.EXTEND;
            lista(lista.COUNT) := detalle;
            
          END IF;          
          
          IF (v_reg_final IS NOT NULL) AND (v_can_detalles >= v_reg_final) THEN
             EXIT;
          END IF;

      END LOOP;
      
     v_retorno.lista := lista;
     v_retorno.cantidad := v_cantidad;     
     
     RETURN v_retorno;
 END;
 
  
FUNCTION fu_obt_soft_empresa(p_fil_serial IN VARCHAR2, 
                            p_fil_estado IN VARCHAR2,   
                            p_fil_desde IN VARCHAR2,                            
                            p_fil_hasta IN VARCHAR2,               
                            p_fil_codPersona IN VARCHAR2, 
                            p_fil_documento IN VARCHAR2, 
                            p_fil_nombre IN VARCHAR2,         
                            p_fil_codPerVinc IN VARCHAR2, 
                            p_fil_docVinc IN VARCHAR2, 
                            p_fil_nombreVinc IN VARCHAR2,   
                            p_fil_autor IN VARCHAR2,                                                               
                            p_nroPagina IN NUMBER DEFAULT NULL,
                            p_cantItemsPagina     IN NUMBER DEFAULT NULL) RETURN typ_obtlistasofttokenadm IS

     v_retorno          typ_obtlistasofttokenadm := typ_obtlistasofttokenadm();
     detalle            typ_softtokenadm := typ_softtokenadm();
     lista              typ_listasofttokenadm := typ_listasofttokenadm();
     v_can_detalles     NUMBER := 0;
     v_reg_inicial      NUMBER(10);
     v_reg_final        NUMBER(10);
     v_can_pagina       NUMBER(5); -- movimientos por pagina
     v_nro_pagina       NUMBER(5); -- nro de pagina
     v_cantidad         NUMBER(5); -- nro de registros 
     v_fec_actual       DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy;
     v_fec_desde        DATE; 
     v_fec_hasta        DATE;  
      --Consulta de los softokens      
      
     CURSOR c_softtokens IS
        SELECT tok.nro_serial as nro_serial, tok.cod_dispositivo as dispositivo, ser.fec_insercion as fec_alta, 
               tok.cod_persona as cod_cliente, tok.fec_ult_solicitud as fec_ult_solicitud ,ser.usu_activacion as usu_activacion, 
               ser.usu_adm_modificacion as usu_modificacion, ser.observacion as observacion,
               ser.fec_activacion as fec_activacion, ser.fec_modificacion as fec_modif_estado, ua.nombre as usu_act_nombre,
               um.nombre as usu_mod_nombre, ser.estado as estado, pe.nro_documento as documento, pe.nom_completo as nombre,
               ser.cod_per_vinculada as cod_vinculada, em.nro_documento as doc_vinculada, co.telefono as tel_vinculada,
               em.nom_completo as nom_vinculada, fu_es_aut_softoken(tok.cod_persona, ser.cod_per_vinculada) as autorizador
        FROM BW_SOF_SERIALES tok
        JOIN BW_SOF_EMPRESAS ser ON ser.sof_ser_id = tok.id 
        JOIN BA_PERSONAS pe ON pe.cod_persona = tok.cod_persona
        JOIN BA_PERSONAS em ON em.cod_persona = ser.cod_per_vinculada
        JOIN BW_TD_CONFIGURACIONES co ON (co.cod_persona = ser.cod_per_vinculada AND co.cod_per_vinculo = tok.cod_persona)  
        LEFT JOIN BA_USUARIOS ua ON upper(ser.usu_activacion) = upper(ua.cod_usuario)
        LEFT JOIN BA_USUARIOS um ON upper(ser.usu_adm_modificacion) = upper(um.cod_usuario)
        WHERE (ser.fec_insercion BETWEEN v_fec_desde AND v_fec_hasta) AND
              (LOWER(TRIM(tok.nro_serial)) LIKE '%' || LOWER( TRIM(p_fil_serial)) || '%') AND
              (LOWER(TRIM(ser.estado)) LIKE '%' || LOWER( TRIM(p_fil_estado)) || '%') AND
              (LOWER(TRIM(tok.cod_persona)) LIKE '%' || LOWER( TRIM(p_fil_codPersona)) || '%') AND
              (LOWER(TRIM(pe.nro_documento)) LIKE '%' || LOWER( TRIM(p_fil_documento)) || '%') AND
              (LOWER(TRIM(pe.nom_completo)) LIKE '%' || LOWER( TRIM(p_fil_nombre)) || '%') AND
              (LOWER(TRIM(ser.cod_per_vinculada)) LIKE '%' || LOWER( TRIM(p_fil_codPerVinc)) || '%') AND
              (LOWER(TRIM(em.nro_documento)) LIKE '%' || LOWER( TRIM(p_fil_docVinc)) || '%') AND
              (LOWER(TRIM(em.nom_completo)) LIKE '%' || LOWER( TRIM(p_fil_nombreVinc)) || '%') AND
              (LOWER(TRIM(fu_es_aut_softoken(tok.cod_persona, ser.cod_per_vinculada))) LIKE '%' || LOWER( TRIM(p_fil_autor)) || '%');
     BEGIN     
       IF p_fil_desde IS NULL THEN
          v_fec_desde := TO_DATE('2019/01/01' || ' 00:00:00', 'YYYY/MM/DD HH24:MI:SS');--incio de los tiempos de token digital       
       ELSE
          v_fec_desde := TO_DATE(p_fil_desde || ' 00:00:00', 'YYYY/MM/DD HH24:MI:SS');       
       END IF;
       
       IF p_fil_hasta IS NULL THEN
          v_fec_hasta := v_fec_actual + 1;
       ELSE
          v_fec_hasta := TO_DATE(p_fil_hasta || ' 23:59:59', 'YYYY/MM/DD HH24:MI:SS');        
       END IF;
       
       SELECT count(*) into v_cantidad
          FROM BW_SOF_SERIALES tok
          JOIN BW_SOF_EMPRESAS ser ON ser.sof_ser_id = tok.id 
          JOIN BA_PERSONAS pe ON pe.cod_persona = tok.cod_persona
          JOIN BA_PERSONAS em ON em.cod_persona = ser.cod_per_vinculada
          JOIN BW_TD_CONFIGURACIONES co ON (co.cod_persona = ser.cod_per_vinculada AND co.cod_per_vinculo = tok.cod_persona)  
          WHERE (ser.fec_insercion BETWEEN v_fec_desde AND v_fec_hasta) AND
                (LOWER(TRIM(tok.nro_serial)) LIKE '%' || LOWER( TRIM(p_fil_serial)) || '%') AND
                (LOWER(TRIM(ser.estado)) LIKE '%' || LOWER( TRIM(p_fil_estado)) || '%') AND
                (LOWER(TRIM(tok.cod_persona)) LIKE '%' || LOWER( TRIM(p_fil_codPersona)) || '%') AND
                (LOWER(TRIM(pe.nro_documento)) LIKE '%' || LOWER( TRIM(p_fil_documento)) || '%') AND
                (LOWER(TRIM(pe.nom_completo)) LIKE '%' || LOWER( TRIM(p_fil_nombre)) || '%') AND
                (LOWER(TRIM(ser.cod_per_vinculada)) LIKE '%' || LOWER( TRIM(p_fil_codPerVinc)) || '%') AND
                (LOWER(TRIM(em.nro_documento)) LIKE '%' || LOWER( TRIM(p_fil_docVinc)) || '%') AND
                (LOWER(TRIM(em.nom_completo)) LIKE '%' || LOWER( TRIM(p_fil_nombreVinc)) || '%')AND
                (LOWER(TRIM(fu_es_aut_softoken(tok.cod_persona, ser.cod_per_vinculada))) LIKE '%' || LOWER( TRIM(p_fil_autor)) || '%');

       v_nro_pagina  := p_nroPagina + 1; --la pagina
       v_can_pagina  := p_cantItemsPagina; --items en la pagina

       v_reg_inicial := (v_nro_pagina * v_can_pagina) - (v_can_pagina - 1);
       v_reg_final   := (v_nro_pagina * v_can_pagina); 
     
     
       FOR softoken IN c_softtokens LOOP
          v_can_detalles           := v_can_detalles + 1;
          
          IF (v_reg_inicial IS NULL) OR (v_can_detalles >= v_reg_inicial) THEN
            
            detalle.nro_serial         := softoken.nro_serial;
            detalle.cod_estado         := softoken.estado;
            detalle.cod_dispositivo    := softoken.dispositivo;
            detalle.fec_alta           := softoken.fec_alta;
            detalle.cod_cliente        := softoken.cod_cliente;
            detalle.nro_documento      := softoken.documento;
            detalle.nom_completo       := softoken.nombre;
            detalle.num_telefono       := softoken.tel_vinculada;  
            detalle.cod_per_vinculada  := softoken.cod_vinculada;
            detalle.nro_doc_vinculada  := softoken.doc_vinculada;
            detalle.nom_comp_vinculada := softoken.nom_vinculada;
            detalle.autorizador        := softoken.autorizador;
            detalle.fec_ult_solicitud := softoken.fec_ult_solicitud;
            detalle.fec_modificacion := softoken.fec_modif_estado;
            detalle.fec_activacion   := softoken.fec_activacion;
            detalle.cod_usu_activacion := softoken.usu_activacion;
            detalle.nom_usu_activacion := softoken.usu_act_nombre;
            detalle.cod_usu_modificacion := softoken.usu_modificacion;
            detalle.nom_usu_modificacion := softoken.usu_mod_nombre;
            if(softoken.estado = 'B') then
              detalle.observacion := softoken.observacion;
            end if;
            
            lista.EXTEND;
            lista(lista.COUNT) := detalle;
            
          END IF;          
          
          IF (v_reg_final IS NOT NULL) AND (v_can_detalles >= v_reg_final) THEN
             EXIT;
          END IF;

      END LOOP;
      
     v_retorno.lista := lista;
     v_retorno.cantidad := v_cantidad;     
     
     RETURN v_retorno;
END;
--
FUNCTION fu_sof_tok_admin(p_serial       IN bw_sof_seriales.nro_serial%TYPE,
                          p_cod_persona  IN ba_personas.cod_persona%TYPE,
                          p_cod_empresa  IN ba_personas.cod_persona%TYPE,
                          p_modo         IN VARCHAR2,
                          p_accion       IN VARCHAR2) RETURN NUMBER IS
   v_existe          NUMBER;
   v_id_sof_serial   bw_sof_seriales.id%TYPE;
   v_sof_cod_persona bw_sof_seriales.cod_persona%TYPE;
BEGIN
   -- cod_persona+cod_per_vinculada tiene que ser el admin
    IF fu_es_aut_softoken(p_cod_persona, p_cod_empresa) = 'N' THEN
       RETURN -1;
    END IF;
   -- serial tiene que estar vinculado a la empresa
   BEGIN
      SELECT s.cod_persona, s.id
        INTO v_sof_cod_persona, v_id_sof_serial
        FROM bw_sof_seriales s, bw_sof_empresas e
       WHERE s.nro_serial = p_serial
         AND s.id = e.sof_ser_id
         AND s.cod_persona <> p_cod_persona
         AND e.cod_per_vinculada = p_cod_empresa;
      -- existe vinculo de la persona y la empresa
      SELECT 1
       INTO v_existe
       FROM ba_vinculos v
       WHERE v.cod_persona = p_cod_empresa
         AND v.cod_per_vinculo = v_sof_cod_persona
         AND rownum = 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN -2;
   END;
   IF p_modo = 'V' THEN
      RETURN 1;
   ELSIF p_modo = 'C' THEN
      -- accion posible (activar, bloquear y desbloquear)
      IF p_accion = 'A' THEN --
         UPDATE bw_sof_empresas se
            SET se.estado = 'A',
                se.fec_activacion = SYSDATE,
                se.usu_activacion = user,
                se.usu_adm_modificacion = user
          WHERE se.estado IN ('E', 'P')
            AND se.cod_per_vinculada = p_cod_empresa
            AND se.sof_ser_id = v_id_sof_serial;
      ELSIF p_accion = 'B' THEN -- bloquear
         UPDATE bw_sof_empresas se
            SET se.estado = 'B',
                se.observacion = '',
                se.usu_adm_modificacion = user
          WHERE se.estado = 'A'
            AND se.cod_per_vinculada = p_cod_empresa
            AND se.sof_ser_id = v_id_sof_serial;
      ELSIF p_accion = 'D' THEN -- desbloquear
         UPDATE bw_sof_empresas se
            SET se.estado = 'A',
                se.usu_adm_modificacion = user
          WHERE se.estado = 'B'
            AND se.cod_per_vinculada = p_cod_empresa
            AND se.sof_ser_id = v_id_sof_serial;
      END IF;
   END IF;
   -- verificamos si se modifico un solo registro
   RETURN SQL%ROWCOUNT;
EXCEPTION
   WHEN OTHERS THEN
      RETURN -9;
END;

FUNCTION fu_cambiarCanalActivSoftoken(p_serial IN bw_otp_seriales.nro_serial%TYPE,
                                  p_codPersona IN ba_personas.cod_persona%TYPE, 
                                  p_nue_canal IN VARCHAR2) RETURN NUMBER IS
BEGIN
  BEGIN

    UPDATE bw_sof_seriales s
    SET    s.tip_can_sol_activacion = p_nue_canal
    WHERE  s.nro_serial = p_serial AND s.cod_persona = p_codPersona;
    IF (SQL%ROWCOUNT = 0) THEN
      RETURN 2;
    END IF;

   
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END;
  
  RETURN 0;
END;

FUNCTION fu_sof_tok_activo(p_cod_persona IN ba_personas.cod_persona%TYPE,
                           p_cod_empresa IN ba_personas.cod_persona%TYPE DEFAULT NULL) RETURN VARCHAR2 IS
  v_retorno VARCHAR2(1) := 'N';
BEGIN
   IF p_cod_empresa IS NULL THEN
      SELECT 'S'
        INTO v_retorno
        FROM bw_otp_seriales s
       WHERE s.tipo = 'S'
         AND s.cod_persona = p_cod_persona
         AND s.estado = 'A';
   ELSE    
      SELECT 'S'
        INTO v_retorno
        FROM bw_sof_seriales s, bw_sof_empresas e
       WHERE s.id = e.sof_ser_id 
         AND e.enrolado = 'S'
         AND e.estado = 'A'
         AND e.cod_per_vinculada = p_cod_empresa
         AND s.cod_persona = p_cod_persona;
   END IF;
   RETURN v_retorno;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END;
--
FUNCTION fu_tie_aut_token(p_cod_persona IN ba_personas.cod_persona%TYPE,
                          p_cod_empresa IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
  v_existe VARCHAR2(1) := 'N';
BEGIN
   SELECT 'S'
     INTO v_existe
     FROM bw_sof_empresas e, bw_sof_seriales s, bw_td_configuraciones td
    WHERE e.cod_per_vinculada = p_cod_empresa
      AND s.id = e.sof_ser_id
      AND s.cod_persona <> p_cod_persona
      AND e.estado = 'A'
      AND e.enrolado = 'S'
      AND e.cod_per_vinculada = td.cod_persona
      AND s.cod_persona = td.cod_per_vinculo
      AND fu_es_aut_softoken(s.cod_persona, e.cod_per_vinculada) = 'S'
      AND rownum = 1;
   RETURN v_existe;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END;

    /*
      Determina si una persona tiene flag de autorizador de softtoken,
      para una empresa especifica.
     */
   FUNCTION fu_es_aut_softoken(p_cod_persona      IN VARCHAR2,
                               p_cod_empresa      IN VARCHAR2) RETURN VARCHAR2 IS
     v_es_autorizador  VARCHAR(1) := 'N';
     v_sin_gestor      VARCHAR2(1);
   BEGIN
      -- si una empresa tiene marcada que sera sin gestor, nadie puede ser gestor de token digital
      v_sin_gestor := NVL(FUE_PER_DAT_ADICIONAL(p_cod_empresa, 'EMP_SIN_GES_TD'), 'N');
      IF v_sin_gestor = 'S' THEN
         RETURN 'N';
      END IF;
      
      SELECT p.autoriza
        INTO v_es_autorizador
        FROM ba_vinculos v, bw_rol_permisos p 
       WHERE v.cod_persona = p_cod_empresa          -- cod. empresa
         AND v.cod_per_vinculo = p_cod_persona      -- cod. persona operador
         AND v.cod_perfil IS NOT NULL
         AND p.cod_perfil = v.cod_perfil
         AND p.cod_tip_mensaje = '008'
         AND nvl(p.cod_persona, p_cod_empresa) = p_cod_empresa;
      RETURN v_es_autorizador;
   EXCEPTION
      WHEN OTHERS THEN
         -- en caso de cualquier excepcion, retornar valor por defecto N
         RETURN v_es_autorizador; 
   END;
 
begin 
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END;
/

