CREATE OR REPLACE PACKAGE BODY IT.pag_doc IS

   /*Obtiene el número más próximo con estado 'D' Disponible*/
   FUNCTION fu_obt_min_documento
   (
      p_tipo        ge_inv_documentos.tipo%TYPE,
      p_cod_oficina ge_inv_documentos.cod_oficina%TYPE
   ) RETURN NUMBER IS
      v_nro_documento NUMBER;
      CURSOR cur_documentos IS
         SELECT decode(instr(est_documentos, 'D'), 0, 0,
                       (nro_inicial + instr(est_documentos, 'D') - 1)) vnro
           FROM ge_inv_documentos
          WHERE cod_oficina = p_cod_oficina
            AND tipo = p_tipo
            AND decode(instr(est_documentos, 'D'), 0, 0,
                       (nro_inicial + instr(est_documentos, 'D') - 1)) <> 0
          ORDER BY nro_inicial;
   BEGIN
      FOR j IN cur_documentos LOOP
         IF j.vnro <> 0 THEN
            v_nro_documento := j.vnro;
            EXIT;
         END IF;
      END LOOP;
   
      IF v_nro_documento IS NULL THEN
         raise_application_error(-20000,
                                 'No se han encontrado Grupos de Números para la Oficina ' ||
                                  p_cod_oficina || SQLERRM);
      END IF;
      RETURN v_nro_documento;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'FU_OBT_MIN_DOCUMENTO ' || SQLERRM);
         END IF;
   END;

   /*Obtiene el estado del número de documento*/
   FUNCTION fu_obt_estado
   (
      p_tipo          ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   ge_inv_documentos.cod_oficina%TYPE,
      p_nro_documento ge_inv_documentos.nro_inicial%TYPE
   ) RETURN VARCHAR2 IS
   
      v_estado         VARCHAR2(1);
      v_pos_nro        NUMBER(8);
      v_nro_inicial    ge_inv_documentos.nro_inicial%TYPE;
      v_can_numeros    ge_inv_documentos.cantidad%TYPE;
      v_est_documentos ge_inv_documentos.est_documentos%TYPE;
      v_error          VARCHAR2(4000);
   
      CURSOR cur_documentos IS
         SELECT nro_inicial, cantidad, est_documentos
           FROM ge_inv_documentos
          WHERE cod_oficina = p_cod_oficina
            AND tipo = p_tipo
            AND p_nro_documento >= nro_inicial
            AND p_nro_documento < nro_inicial + cantidad
            AND p_nro_documento BETWEEN nro_inicial AND nro_final
          ORDER BY fec_insercion DESC;
   BEGIN
      OPEN cur_documentos;
      FETCH cur_documentos
         INTO v_nro_inicial, v_can_numeros, v_est_documentos;
      CLOSE cur_documentos;
      IF v_est_documentos IS NULL THEN
         v_error := 'Número ' || to_char(p_nro_documento) || ' Inexistente.';
         raise_application_error(-20000, v_error);
         RETURN(NULL);
      END IF;
      --Posicion del número evaluado
      v_pos_nro := p_nro_documento - v_nro_inicial + 1;
      v_estado  := substr(v_est_documentos, v_pos_nro, 1);
      RETURN v_estado;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
            RETURN(NULL);
         ELSE
            v_error := SQLERRM;
            raise_application_error(-20000, 'FU_OBT_ESTADO ' || v_error);
            RETURN(NULL);
         END IF;
   END;

   /*Obtiene la cantidad de Números de hojas que tienen un estado especifico
   para una oficina, enviado como parámetro*/
   FUNCTION fu_obt_can_documentos
   (
      p_tipo          ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   ge_inv_documentos.cod_oficina%TYPE,
      p_estado        VARCHAR2,
      p_est_hojas     ge_inv_documentos.estado%TYPE,
      p_nro_secuencia ge_inv_documentos.nro_secuencia%TYPE DEFAULT NULL
   ) RETURN NUMBER IS
   
      CURSOR cur_documentos IS
         SELECT est_documentos
           FROM ge_inv_documentos
          WHERE cod_oficina = p_cod_oficina
            AND tipo = p_tipo
            AND estado = p_estado
            AND nro_secuencia = nvl(p_nro_secuencia, nro_secuencia)
            AND instr(est_documentos, p_est_hojas) <> 0
          ORDER BY nro_inicial DESC;
      v_cantidad NUMBER(8) := 0;
      v_estado   VARCHAR2(1);
   BEGIN
      FOR i IN cur_documentos LOOP
         FOR pos IN 1 .. length(i.est_documentos) LOOP
            v_estado := substr(i.est_documentos, pos, 1);
            IF p_est_hojas = v_estado THEN
               v_cantidad := nvl(v_cantidad, 0) + 1;
            END IF;
         END LOOP;
      END LOOP;
      RETURN v_cantidad;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'FU_OBT_CAN_DOCUMENTOS ' || SQLERRM);
         END IF;
   END;

   /*Actualiza el estado del número de documento*/
   PROCEDURE pr_act_estado
   (
      p_tipo          IN ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   IN ge_inv_documentos.cod_oficina%TYPE,
      p_nro_documento IN ge_inv_documentos.nro_inicial%TYPE,
      p_estado        IN VARCHAR2,
      p_nro_ini       IN NUMBER DEFAULT NULL,
      p_cod_causa     IN ge_causales.cod_causa%TYPE DEFAULT NULL,
      p_observacion   IN ge_inv_doc_anulados.observacion%TYPE DEFAULT NULL
   ) IS
   
      v_pos_nro       NUMBER;
      v_estado        VARCHAR2(1);
      v_est_actual    VARCHAR2(1);
      v_nro_inicial   ge_inv_documentos.nro_inicial%TYPE;
      v_nro_secuencia ge_inv_documentos.nro_secuencia%TYPE;
   
   BEGIN
      IF p_nro_ini IS NULL THEN
         -- busco el numero inicial
         BEGIN
            SELECT nro_inicial, nro_secuencia
              INTO v_nro_inicial, v_nro_secuencia
              FROM ge_inv_documentos
             WHERE cod_oficina = p_cod_oficina
               AND tipo = p_tipo
               AND p_nro_documento >= nro_inicial
               AND p_nro_documento < nro_inicial + cantidad
               AND p_nro_documento BETWEEN nro_inicial AND nro_final;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Número de Documento ' || p_nro_documento ||
                                        ' no existe para la oficina ' || p_cod_oficina);
            WHEN too_many_rows THEN
               raise_application_error(-20000,
                                       'Número de Documento ' || p_nro_documento || ' duplicado.');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al leer GE_INV_DOCUMENTOS ' || SQLERRM);
         END;
      END IF;
   
      v_pos_nro := p_nro_documento - nvl(v_nro_inicial, p_nro_ini) + 1;
   
      IF p_estado IS NOT NULL THEN
         -- Verifica el estado actual
         v_est_actual := fu_obt_estado(p_tipo, p_cod_oficina, p_nro_documento);
         pr_ver_estado(p_tipo, p_cod_oficina, p_nro_documento, p_estado);
         --
         UPDATE ge_inv_documentos
            SET est_documentos = substr(est_documentos, 1, v_pos_nro - 1) || p_estado ||
                                 substr(est_documentos, v_pos_nro + 1, length(est_documentos))
          WHERE cod_oficina = p_cod_oficina
            AND tipo = p_tipo
            AND nro_inicial = nvl(v_nro_inicial, p_nro_ini);
         IF SQL%NOTFOUND THEN
            raise_application_error(-20000, 'ERROR. Actualizando GE_INV_DOCUMENTOS ' || SQLCODE);
         END IF;
         -- Si se anula, se debe insertar como anulado
         IF p_estado = 'A' THEN
            IF p_cod_causa IS NULL THEN
               raise_application_error(-20000,
                                       'ERROR. Código de Causa es Obligatorio para anular el documento.');
            END IF;
            INSERT INTO ge_inv_doc_anulados
               (nro_secuencia, nro_documento, cod_causa, est_anterior, observacion)
            VALUES
               (v_nro_secuencia, p_nro_documento, p_cod_causa, v_est_actual, p_observacion);
         END IF;
      
      ELSE
         raise_application_error(-20000, 'ERROR. Estado no se encuentra definido.');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'PR_ACT_ESTADO ' || SQLERRM);
         END IF;
   END;

   /*Verifica si se puede o no pasar a un estado dado*/
   PROCEDURE pr_ver_estado
   (
      p_tipo          IN ge_inv_documentos.tipo%TYPE,
      p_cod_oficina   IN ge_inv_documentos.cod_oficina%TYPE,
      p_nro_documento IN ge_inv_documentos.nro_inicial%TYPE,
      p_estado        IN VARCHAR2
   ) IS
      v_estado      VARCHAR2(1);
      v_pos_doc     NUMBER(8);
      v_nro_inicial ge_inv_documentos.nro_inicial%TYPE;
      v_est_hojas   ge_inv_documentos.est_documentos%TYPE;
   BEGIN
      -- Obtiene el estado anterior
      v_estado := fu_obt_estado(p_tipo, p_cod_oficina, p_nro_documento);
   
      -- Compara con el estado solicitado
      IF v_estado = 'D' AND nvl(p_estado, 'x') NOT IN ('U', 'A') THEN
         raise_application_error(-20000,
                                 'El Documento en estado Disponible solo puede pasar a estado Utilizado o Anulado.');
      ELSIF v_estado = 'U' AND nvl(p_estado, 'x') NOT IN ('I', 'A') THEN
         raise_application_error(-20000,
                                 'El Número de Documento ' || p_nro_documento ||
                                  ' ya se encuentra Utilizado.');
      ELSIF v_estado = 'I' AND nvl(p_estado, 'x') <> 'A' THEN
         raise_application_error(-20000,
                                 'El Número de Documento ' || p_nro_documento ||
                                  ' ya fue Impreso en la oficina ' || p_cod_oficina);
      ELSIF v_estado = 'A' THEN
         raise_application_error(-20000,
                                 'El Documento Nro. ' || p_nro_documento ||
                                  ' ya se encuentra Anulado.');
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'PR_VER_ESTADO ' || SQLERRM);
         END IF;
   END;

   /*Reversa el estado de un número de documento*/
   PROCEDURE pr_rev_estado
   (
      p_cod_oficina   IN ge_inv_documentos.cod_oficina%TYPE,
      p_tipo          IN ge_inv_documentos.tipo%TYPE,
      p_nro_documento IN ge_inv_doc_anulados.nro_documento%TYPE
   ) IS
      v_estado        VARCHAR2(1);
      v_est_anterior  VARCHAR2(1);
      v_est_nuevo     VARCHAR2(1);
      v_pos_doc       NUMBER(8);
      v_nro_inicial   ge_inv_documentos.nro_inicial%TYPE;
      v_est_hojas     ge_inv_documentos.est_documentos%TYPE;
      v_tipo          ge_inv_documentos.tipo%TYPE;
      v_cod_oficina   ge_inv_documentos.cod_oficina%TYPE;
      v_pos_nro       NUMBER;
      v_nro_secuencia ge_inv_documentos.nro_secuencia%TYPE;
   
   BEGIN
      -- Obtiene el estado actual
      BEGIN
         SELECT tipo, cod_oficina, nro_inicial, nro_secuencia
           INTO v_tipo, v_cod_oficina, v_nro_inicial, v_nro_secuencia
           FROM ge_inv_documentos a
          WHERE cod_oficina = p_cod_oficina
            AND tipo = p_tipo
            AND p_nro_documento >= nro_inicial
            AND p_nro_documento < nro_inicial + cantidad
            AND p_nro_documento BETWEEN nro_inicial AND nro_final;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000,
                                    'Número de Documento ' || p_nro_documento ||
                                     ' no existe para la oficina ' || p_cod_oficina);
         WHEN too_many_rows THEN
            raise_application_error(-20000,
                                    'Número de Documento ' || p_nro_documento || ' duplicado.');
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al leer GE_INV_DOCUMENTOS ' || SQLERRM);
      END;
      v_estado := fu_obt_estado(v_tipo, v_cod_oficina, p_nro_documento);
   
      /*
      || Compara con el estado solicitado:
      || Si el estado actual es 'I', directamente pasará a 'U'.
      || Si el estado actual es 'U, directamente pasará a 'D'.
      || Si es 'A', se recupera el valor anterior de tabla GE_INV_DOC_ANULADOS
      */
      IF v_estado = 'I' THEN
         v_est_nuevo := 'U';
      ELSIF v_estado = 'U' THEN
         v_est_nuevo := 'D';
         DELETE FROM bw_cla_acciones WHERE nro_hoj_seguridad = p_nro_documento;
      ELSIF v_estado = 'A' THEN
         BEGIN
            SELECT est_anterior
              INTO v_est_nuevo
              FROM ge_inv_doc_anulados
             WHERE nro_secuencia = v_nro_secuencia
               AND nro_documento = p_nro_documento;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Número de Documento ' || p_nro_documento ||
                                        ' no existe (GE_INV_DOC_ANULADOS).');
            WHEN too_many_rows THEN
               raise_application_error(-20000,
                                       'Número de Documento ' || p_nro_documento ||
                                        ' duplicado (GE_INV_DOC_ANULADOS).');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al leer GE_INV_DOC_ANULADOS ' || SQLERRM);
         END;
         DELETE FROM ge_inv_doc_anulados
          WHERE nro_secuencia = v_nro_secuencia
            AND nro_documento = p_nro_documento;
      
      ELSIF v_estado = 'D' THEN
         raise_application_error(-20000,
                                 'El Documento Nro. ' || p_nro_documento ||
                                  ' ya se encuentra Disponible.');
      ELSE
         raise_application_error(-20000, 'ERROR. Estado no se encuentra definido. ' || v_estado);
      END IF;
   
      IF v_estado <> 'D' THEN
         -- Actualiza al estado anterior
         v_pos_nro := p_nro_documento - v_nro_inicial + 1;
         UPDATE ge_inv_documentos
            SET est_documentos = substr(est_documentos, 1, v_pos_nro - 1) || v_est_nuevo ||
                                 substr(est_documentos, v_pos_nro + 1, length(est_documentos))
          WHERE cod_oficina = v_cod_oficina
            AND tipo = v_tipo
            AND nro_inicial = v_nro_inicial;
         IF SQL%NOTFOUND THEN
            raise_application_error(-20000, 'ERROR. Actualizando GE_INV_DOCUMENTOS ' || SQLCODE);
         END IF;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'PR_REV_ESTADO ' || SQLERRM);
         END IF;
   END;

END pag_doc;
/

