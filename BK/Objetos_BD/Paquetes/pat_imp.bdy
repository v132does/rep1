CREATE OR REPLACE PACKAGE BODY IT.PAT_IMP IS

--Variable Global
   v_can_user number;
-- Para asignacion de usuario
   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;

   TYPE typ_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora typ_usu_hor;
-- Log nuevo
	PROCEDURE pr_ins_log_inf
	(
      p_cod_error      NUMBER,           
      p_men_error      ta_logs.men_error%TYPE,
      p_comentario     ta_logs.comentario%TYPE
	) 
	IS

	BEGIN
 

	   r_log.fec_hor_fin := SYSDATE;
	   r_log.nro_reg     := g_nro_reg; 
	   r_log.nro_error   := p_cod_error;
	   r_log.men_error   := p_men_error;
	   r_log.comentario  := p_comentario;
	

	   /* Inserto registro en log */
	   prt_ins_log(r_log);

	EXCEPTION

    WHEN OTHERS THEN
    
      r_log.nro_error   := SQLCODE; 
      r_log.men_error   := SQLERRM;
      r_log.comentario  := 'Fallo en pr_ins_log_inf: '|| SQLERRM;

    prt_ins_log(r_log);
	
	END pr_ins_log_inf;

  /* Devuelve el nro de cuenta de una tarjeta*/
FUNCTION FU_OBT_NRO_CUENTA( P_NRO_TARJETA IN TA_TARJETAS.NRO_TARJETA%TYPE) RETURN VARCHAR2 IS
   v_retorno TA_TARJETAS.NRO_CUENTA%TYPE;
BEGIN
   SELECT nro_cuenta
     INTO v_retorno
     FROM ta_tarjetas
    WHERE nro_tarjeta = p_nro_tarjeta;
   RETURN v_retorno;
EXCEPTION
   WHEN no_data_found THEN
      RETURN NULL;
END;

PROCEDURE pr_pro_bancard(p_nro_cuenta IN VARCHAR2 DEFAULT NULL) IS
      c_fec_actual      CONSTANT DATE := pag_cal.fu_obt_fec_actual(5);
      c_fec_min_proceso CONSTANT DATE := to_date('01/01/1901', 'DD/MM/YYYY');
      c_cod_mon_local   CONSTANT VARCHAR2(3) := pag_gen.fu_obt_mon_local;
      c_bancard         CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_BANCARD');
      c_nom_proceso     CONSTANT VARCHAR2(30) := 'pat_imp.PR_PRO_BANCARD';
      v_ge_cliente      VARCHAR2(1);
      v_existe            VARCHAR2(1);
      v_oficina           NUMBER(3);
      v_ofi_matriz        NUMBER(3);
      v_cod_tip_doc       NUMBER;
      v_cod_tip_pas       NUMBER;
      v_cod_tip_dni       NUMBER;
      v_cod_tip_cad       NUMBER;
      v_cod_tip_ruc       NUMBER;
      v_cod_tip_cie       NUMBER;
      v_cod_tip_crc       NUMBER;
      v_per_principal     VARCHAR2(10);
      v_nom_principal     VARCHAR2(200);
      v_estado            VARCHAR2(1);
      v_nro_cta_debito    VARCHAR2(15);
      v_nro_solicitud     NUMBER(8);
      v_fec_solicitud     DATE;
      v_mar_excedido      VARCHAR2(1);
      v_mar_mora          VARCHAR2(1);
      v_existe_tarjeta    VARCHAR2(1);
      v_persona           VARCHAR2(10);
      v_tip_persona       VARCHAR2(1);
      v_nom_completo      VARCHAR2(200);
      v_nom_embozar       VARCHAR2(50);
      v_est_tarjeta       NUMBER(2);
      v_est_anterior      NUMBER(2);
      v_fec_entrega       DATE;
      v_relacion          VARCHAR2(1);
      v_fec_ven_tarjeta   DATE;
      v_recuperada        VARCHAR2(1);
      v_boletinada        VARCHAR2(1);
      v_cod_usuario       VARCHAR2(10);
      v_exi_cta_cli       NUMBER;
      v_per_inhibida      VARCHAR2(5) := 0;
      v_mens              VARCHAR2(200) := NULL;
      v_fec_cierre        DATE;
      v_cod_rub_economico ta_cta_tarjetas.cod_rub_economico%TYPE;
      v_cod_campana       cr_campanas.cod_campana%TYPE;
      --
      v_fec_ult_pago     ta_cta_tarjetas.fec_ult_pago%TYPE;
      v_fec_ult_compra   ta_cta_tarjetas.fec_ult_compra%TYPE;
      v_fec_ult_ope      ta_cta_tarjetas.fec_ult_operacion%TYPE;
      v_fec_vct_ult_cie  ta_cta_tarjetas.fec_vct_ult_cierre%TYPE;
      v_cod_usu_promotor ta_cta_tarjetas.cod_usu_promotor%TYPE;
      v_cod_afinidad     ta_cta_tarjetas.afinidad%TYPE;
      v_sub_afinidad     ta_cta_tarjetas.sub_afinidad%TYPE;
      v_fec_ult_extracto ta_cta_tarjetas.fec_ult_extracto%TYPE;
      v_tip_envio        ta_tarjetas.tip_envio%TYPE;
      v_referencia       ta_tarjetas.referencia%TYPE;
      v_pre_embozada     ta_tarjetas.pre_embozada%TYPE;
      --
      v_error            EXCEPTION;
      v_can_tar_activa   NUMBER := 0;
      v_can_marca        NUMBER := 0; -- Cantidad de tarjetas con algun tipo de marca
      v_nro_cuenta       ta_cta_tarjetas.nro_cuenta%type;
      v_nro_error        NUMBER := 3;
      v_men_error        VARCHAR(500) := 'INFO';
      v_crea_tarjeta     CHAR(1) := NULL;
      v_crea_cuenta      CHAR(1) := NULL;
      v_cod_mod_col      NUMBER;
      v_cod_mad_col      NUMBER;


      --
      --JG 16/02/2011. Se pone NVL al campo mto_mora para contemplar casos con valores NULOS, Mirar AP 1581
      CURSOR cuentas IS
         SELECT DISTINCT c.nro_cuenta,
                         c.denominacion,
                         c.nro_reg,
                         ta.cod_modulo,
                         ta.cod_modalidad,
                         c.cod_moneda,
                         c.lin_credito,
                         lin_cuotas,
                         c.sal_facturar,
                         sal_facturado,
                         sal_financiado,
                         sal_ult_extracto,
                         sal_cuo_pendientes,
                         mto_pag_minimo,
                         sal_pag_minimo,
                         nvl(mto_mora, 0) mto_mora,
                         dia_mora,
                         mto_autorizaciones,
                         mto_pag_mes,
                         estado,
                         fec_ult_pago,
                         fec_ult_compra,
                         fec_ult_operacion,
                         fec_ult_extracto,
/*Ver ch*/               nvl(fec_ult_cierre, pat_imp.fu_obt_fec_cierre(c_bancard, ta.cod_modalidad, c.tip_cierre)) fec_ult_cierre,
                         nvl(fec_vct_ult_cierre,
                             pat_imp.fu_obt_fec_vencim(c_bancard, ta.cod_modalidad, c.tip_cierre)) fec_vct_ult_cierre,
                         tip_cierre,
                         tip_tas_financiacion,
                         tip_com_emision,
                         nvl(tas_financiacion, 0) tas_financiacion,
                         nvl(tas_mora, 0) tas_mora,
                         deb_automatico,
                         tip_cobro,
                         nro_cta_debito,
                         por_pag_minimo,
                         mar_mora,
                         mar_excedido,
                         mar_recuperado,
                         mar_bloqueo,
                         max_atraso,
                         pro_atraso,
                         sit_cuenta,
                         cod_sucursal,
                         fec_apertura,
                         cod_usu_ente,
                         to_number(REPLACE(fug_obt_pardinamico('TASCUO', 5, ta.cod_modalidad, NULL,
                                                               NULL), ',', '.')) tas_cuotas,
                         to_number(REPLACE(fug_obt_pardinamico('TASINAD', 5, ta.cod_modalidad, NULL,
                                                               NULL), ',', '.')) tas_adelanto,
                         c.cod_afinidad afinidad_externa,
                         substr(nro_tarjeta, 1,
                                fug_obt_pardinamico('NRO_BIN_LONGITUD', 5, ta.cod_modalidad, NULL,
                                                     NULL)) nro_bin,
                         /*c.franqueo,
                         c.ind_seg_vida,*/--bancard ueno no existe en bankitti
                         c.car_no_aplicar--c.cod_exc_cargo
           FROM ta_tarjetas_tmp t,
                ta_cta_tarjetas_tmp c,
                (SELECT DISTINCT cod_modulo, cod_modalidad, ref_externa
                   FROM ta_tipos
                  WHERE cod_ent_procesadora = c_bancard) ta
          WHERE c.nro_cuenta IS NOT NULL
            AND (c.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)
            AND c.cod_ent_procesadora = c_bancard
            AND t.nro_cuenta = c.nro_cuenta
            AND t.cod_afinidad = ta.ref_externa
            AND EXISTS (SELECT 1 FROM ba_personas mm where mm.nro_documento = trim(t.nro_documento))
          ORDER BY c.nro_reg;
      CURSOR tarjetas(p_nro_cuenta VARCHAR2) IS
         SELECT nro_cuenta,
                nro_tarjeta,
                cod_afinidad,
                cod_persona,
                cod_estado,
                fec_vencimiento,
                nom_embozar,
                nom_enviar,
                vigente,
                fec_emision,
                dig_verificador,
                relacion,
                cod_situacion,
                nro_documento,
                dur_meses,
                mes_vencimiento,
                mar_boletinada,
                mar_recuperada,
                mar_vencida,
                tip_bloqueo,
                renovar,
                fec_nacimiento,
                cod_est_civil,
                cod_sexo,
                fec_entrega
           FROM ta_tarjetas_tmp
          WHERE nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
            AND cod_ent_procesadora = c_bancard
          ORDER BY nro_cuenta, relacion, nro_tarjeta;
      CURSOR tar_principales --solo implement 3
      IS
         SELECT nro_cuenta, cod_modalidad
           FROM ta_tarjetas_tmp
          WHERE nro_cuenta > 0
            AND nro_tarjeta > 0
            AND nvl(relacion, 0) = 0
            AND cod_ent_procesadora = c_bancard;
      --
      CURSOR solicitudes IS
         SELECT tip_envio, referencia, afinidad, sub_afinidad, pre_embozada
           FROM ta_solicitudes
          WHERE nro_solicitud = v_nro_solicitud;
      --
      i                   DATE;
      x                   NUMBER;
      v_es_juridica       VARCHAR2(1);
      v_nro_doc_principal ba_personas.nro_documento%TYPE;
      v_nom_usuario       ta_tarjetas_tmp.nom_enviar%TYPE;
      v_pri_adicional     ba_personas.nro_documento%TYPE;
      v_nro_doc_adicional ba_personas.nro_documento%TYPE;
      v_aux_encriptado    NUMBER(1);
   BEGIN
      /*Sentencia utilizada para encriptar la fuente en una versión superior */
      BEGIN
         SELECT MIN(1) keep(dense_rank FIRST ORDER BY 1) valor INTO v_aux_encriptado FROM dual;
      END;
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 5;
      END;
      i := SYSDATE;
      --- Inicializacion  de variables ---
      g_secuencia := 0;
      g_hor_movim := to_char(SYSDATE, 'HH24:MI:SS');
      --RI:15/10/2010: Obtener sigte. segundo
      g_hor_movim := pag_gen.fu_obt_sig_segundo(g_hor_movim);
      --truncar log
      --
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_ins_log_inf(v_nro_error , v_men_error ,'*** Iniciando el proceso a las ' || to_char(i, 'HH24:MI:SS') || ' ***');
      g_nro_reg := 0;


                   /************************************* AUD CURSOR CUENTAS  *********************************/
         BEGIN
          FOR a IN (
            SELECT DISTINCT
                 c.nro_cuenta,
                  t.nro_documento,
           CASE
               WHEN NOT EXISTS (SELECT 1 FROM ba_personas mm WHERE mm.nro_documento = TRIM(t.nro_documento)) AND t.nro_documento IS NOT NULL
                  THEN 'PERSON_NOT_FOUND'
               ELSE NULL
               END AS men_error
           FROM ta_tarjetas_tmp t
           JOIN ta_cta_tarjetas_tmp c ON t.nro_cuenta = c.nro_cuenta
           WHERE 1=1
             AND ((NOT EXISTS (SELECT 1 FROM ba_personas mm WHERE mm.nro_documento = TRIM(t.nro_documento)) AND t.nro_documento IS NOT NULL)
             AND c.nro_cuenta IS NOT NULL
             AND (c.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)
             AND c.cod_ent_procesadora = c_bancard
             AND t.nro_cuenta = c.nro_cuenta
             AND EXISTS (SELECT 1 FROM ta_tipos ta
                        WHERE ta.cod_ent_procesadora = 7
                        AND ta.ref_externa = t.cod_afinidad))
         ) LOOP

                v_nro_error := 1 ;
                v_men_error := a.men_error ;


                  pat_imp.pr_ins_log_inf( v_nro_error , v_men_error , 'No se obtuvieron datos en BA_PERSONAS vinculados al Nro de Documento ' || a.nro_documento || '. Cuenta ' || a.nro_cuenta || ' en el cursor CUENTAS - join temporales. Motivo ' || v_men_error );


                  r_log.nro_error := 3;
                  r_log.men_error := 'INFO';
                  r_log.comentario := NULL;
                  v_nro_error := 3;
                  v_men_error := 'INFO' ;


               END LOOP;
         END ;

      --actualizar la oficina de la tarjeta
      BEGIN
         UPDATE ta_cta_tarjetas_tmp a
            SET a.cod_oficina = 61
                /*(SELECT b.cod_oficina
                   FROM ta_sucursales b
                  WHERE b.cod_sucursal = a.cod_sucursal
                    AND b.cod_ent_procesadora = c_bancard)*/
          WHERE a.nro_cuenta > 0
            AND a.cod_ent_procesadora = c_bancard;
      EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20271, c_bancard || ' ' );
      END;
      BEGIN
         UPDATE ta_tarjetas_tmp a
            SET cod_oficina =
                (SELECT cod_oficina FROM ta_cta_tarjetas_tmp b WHERE b.nro_cuenta = a.nro_cuenta)
          WHERE a.nro_cuenta > 0
            AND a.nro_tarjeta > 0
            AND cod_ent_procesadora = c_bancard;
      END;
      ---
      IF fug_obt_tip_implementacion = 3 THEN
         BEGIN
            UPDATE ta_tarjetas_tmp a
               SET (a.nro_cuenta, a.cod_modalidad) =
                   (SELECT to_char(b.cod_modalidad) || a.nro_cuenta, b.cod_modalidad
                      FROM ta_tipos b
                     WHERE b.nro_bin = substr(a.nro_tarjeta, 1, 10))
             WHERE a.nro_cuenta > 0
               AND a.nro_tarjeta > 0
               AND cod_ent_procesadora = c_bancard;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('ITC-00001: Al actualizar el numero de cuenta para la tarjeta. ');
               --        raise v_error;
         END;
      ELSIF fug_obt_tip_implementacion IN (1, 7) THEN
         /* Elimina las cuentas y tarjetas canceladas */
         BEGIN
            DELETE FROM ta_cta_tarjetas_tmp a
             WHERE EXISTS (SELECT 1
                      FROM tm_cta_tarjetas_aux
                     WHERE nro_cuenta = to_char(to_number(a.nro_cuenta)));
            DELETE FROM ta_tarjetas_tmp a
             WHERE EXISTS (SELECT 1
                      FROM tm_tarjetas_aux
                     WHERE nro_cuenta = to_char(to_number(a.nro_cuenta))
                       AND nro_tarjeta = a.nro_tarjeta);
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('ITC-00001: Al eliminar cuentas y tarjetas canceladas');
         END;

      ELSIF fug_obt_tip_implementacion = 2 THEN
         /*
         || Actualiza el numero de cuenta, y la modalidad
         */
         BEGIN
            UPDATE ta_tarjetas_tmp a
               SET a.cod_modalidad =
                   (SELECT b.cod_modalidad
                      FROM ta_tipos b
                     WHERE b.nro_bin = substr(a.nro_tarjeta, 1, 10))
             WHERE nvl(a.nro_cuenta, '0') <> '0'
               AND a.nro_tarjeta > 0
               AND cod_ent_procesadora = c_bancard;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('ITC-00002: Al actualizar el numero de cuenta para la tarjeta. ');
         END;
         /*
         || Actualiza la modalidad para las cuentas de funcionarios.
         */
         BEGIN
            UPDATE ta_tarjetas_tmp a
               SET a.cod_modalidad = 582
             WHERE nvl(a.nro_cuenta, '0') <> '0'
               AND a.nro_tarjeta > 0
               AND cod_ent_procesadora = c_bancard
               AND EXISTS (SELECT 1
                      FROM ge_cta_clientes b
                     WHERE b.nro_cuenta = to_char(to_number(a.nro_cuenta))
                       AND b.cod_persona IS NOT NULL
                       AND b.relacion = 'P'
                       AND fug_es_empleado(b.cod_persona) = 'S');
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('ITC-00002.1: Al actualizar el numero de cuenta para la tarjeta. ');
         END;
         /*
         || Vuelca la informacion de la modalidad de la tarjeta en la modalidad de la cuenta
         */
         BEGIN
            UPDATE ta_cta_tarjetas_tmp a
               SET a.cod_modalidad =
                   (SELECT DISTINCT b.cod_modalidad
                      FROM ta_tarjetas_tmp b
                     WHERE a.nro_cuenta = b.nro_cuenta)
             WHERE nvl(a.nro_cuenta, '0') <> 0
               AND cod_ent_procesadora = c_bancard;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('ITC-00002.2: Al actualizar el numero de cuenta para la tarjeta. ');
         END;
      END IF;
      IF fug_obt_tip_implementacion = 3 THEN
         FOR p IN tar_principales LOOP
            BEGIN
               UPDATE ta_cta_tarjetas_tmp
                  SET nro_cuenta    = p.nro_cuenta,
                      cod_modulo    = 5,
                      cod_modalidad = p.cod_modalidad
                WHERE nro_cuenta = substr(p.nro_cuenta, nvl(length(p.cod_modalidad), 0) + 1)
                  AND cod_ent_procesadora = c_bancard;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  pat_imp.pr_log('ITC-00003: Al actualizar el numero de cuenta para la cuenta. ');
            END;
         END LOOP;
      END IF;
      BEGIN
         SELECT cod_ofi_matriz INTO v_ofi_matriz FROM ge_par_generales;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            pat_imp.pr_log('ITC-00003: Al buscar la oficina matriz. ');
      END;
      -- *****************************************************************************************
       -- Deshabilitar TRIGGERS DE AUDITORIA --
      -- sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      -- sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CUENTAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CUENTAS DISABLE', r_log.comentario);
      -- SDC AP 931 Deshabilitado para que inserte en TA_SAL_CIERRE por que el proceso se corre cuando el modulo esta cerrado
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_SAL_CIERRES DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_SAL_CIERRES DISABLE', r_log.comentario);
      --
      -- *****************************************************************************************

      -- Busca los tipos de documentos (Cedula, Pasaporte, DNI ,CRC y RUC)
      pat_imp.pr_obt_documentos(v_cod_tip_doc, v_cod_tip_ruc, v_cod_tip_pas, v_cod_tip_dni,
                                v_cod_tip_cad, v_cod_tip_cie, v_cod_tip_crc);

      /************************************* SECCION DE CARGA DE TABLAS TEMPORALES *************************************/
      FOR c IN cuentas LOOP
         v_nro_cuenta := c.nro_cuenta;
         g_nro_reg := nvl(g_nro_reg, 0) + 1;

      -- Reinicializa el estado de log para CADA cuenta.
       v_nro_error := 3;
         v_men_error := 'INFO';
         -----
         IF round(g_nro_reg / 1000) = g_nro_reg / 1000 THEN
            x := (SYSDATE - i) * 24 * 60;
            dbms_output.put_line('Registro: ' || lpad(to_char(g_nro_reg, '999G999G999'), 12, ' ') ||
                                 '; Tiempo transcurrido: ' || to_char(floor(x), '999') || ':' ||
                                 lpad(to_char(round((x - floor(x)) * 60, 2)), 2, '0'));
         END IF;
         -----
         -- Inactiva, Baja
         IF nvl(c.sit_cuenta, 0) IN (3, 2) AND
            nvl(c.sal_facturar, 0) + nvl(c.sal_facturado, 0) + nvl(c.sal_financiado, 0) +
            nvl(c.sal_cuo_pendientes, 0) > 0 THEN
            pat_imp.pr_log('ITC-00006: La cuenta ' || to_char(c.nro_cuenta) ||
                           ' con situacion 3, posee un saldo distinto de 0. OPERACION NO PERMITIDA!!!',
                           FALSE);

         ELSE
            /**************************************** SECCION DE PROCESOS DE CUENTAS ***************************************/
            BEGIN -- MLM
                 SELECT 'S'
                 INTO v_existe
                 FROM ta_cta_tarjetas
                 WHERE nro_cuenta = TO_CHAR(TO_NUMBER(c.nro_cuenta))
                 AND cod_modulo = c.cod_modulo
                 AND cod_modalidad = c.cod_modalidad ;

             EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     v_existe := 'N';
                 WHEN OTHERS THEN
                     v_existe := 'N';
             END;

             IF v_existe = 'N' THEN
                 BEGIN
                     SELECT 'S', cod_modulo, cod_modalidad
                     INTO v_existe, v_cod_mod_col, v_cod_mad_col
                     FROM ge_cuentas
                     WHERE nro_cuenta = TO_CHAR(TO_NUMBER(c.nro_cuenta));


                     IF v_existe = 'S'
                     THEN

                        v_nro_error      := 0 ;
                        v_men_error      := 'ACCOUNT_NUMBER_COLLISION';


                        pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'La cuenta '  || c.nro_cuenta ||
                           ' ya existe en la tabla GE_CUENTAS vinculado a otro modulo/modalidad. Módulo: '  || v_cod_mod_col || '/Modalidad: '|| v_cod_mad_col);

                     GOTO siguiente;
           END IF;
                 EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                         v_existe := 'N';
                     WHEN OTHERS THEN
                         v_existe := 'N';
                 END;
             END IF;

               /*
               SELECT 'S'
                 INTO v_existe
                 FROM ta_cta_tarjetas
                WHERE nro_cuenta = to_char(to_number(c.nro_cuenta));
            EXCEPTION
               WHEN no_data_found THEN
                  v_existe := 'N';
               WHEN OTHERS THEN
                  v_existe := 'N';
                  pat_imp.pr_log('ITC-00007: Al comprobar la cuenta ' || c.nro_cuenta);
            END;*/


            /*
            || Busca la oficina relacionada a la sucursal
            *//*
            BEGIN
               SELECT nvl(cod_oficina, 61)
                 INTO v_oficina
                 FROM ta_sucursales
                WHERE cod_ent_procesadora = c_bancard
                  AND cod_sucursal = c.cod_sucursal
                  AND cod_campana IS NULL;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN*/
                  v_oficina := 61;
                  /*pat_imp.pr_ins_sucursal(c_bancard, c.cod_sucursal);
                  r_log.nom_proceso := c_nom_proceso;
               WHEN OTHERS THEN
                  v_oficina := NULL;
                  pat_imp.pr_log('ITC-00008: Al buscar la oficina de la cuenta ' || c.nro_cuenta);
            END;*/
            /*
            || Setea el estado de la cuenta
            */
            IF nvl(c.sit_cuenta, -1) = 1 THEN
               /* || Si tiene algun tipo de bloqueo deja la cuenta Bloqueada  */
               IF nvl(c.mar_bloqueo, 'x') IN ('U', 'A') THEN
                  --mar_bloqueo no tiene nada en la cta, en la tarj mar_boletinada
                  v_estado := 'B';
               ELSE
                  v_estado := 'N';
               END IF;
            ELSIF nvl(c.sit_cuenta, -1) = 3 THEN
               v_estado := 'C';
            ELSIF nvl(c.sit_cuenta, -1) = 2 THEN
               -- Nuevo estado de cuenta de Tarjeta -Inactiva
               v_estado := 'I'; -- Inactiva
            ELSE
               v_estado := NULL;
               pat_imp.pr_log('ITC-00009: La cuenta ' || c.nro_cuenta ||
                              ' posee una situacion no identificada (' ||
                              to_char(nvl(c.sit_cuenta, -1)) || '), no se pudo procesar.');
            END IF;
            /*
            || Verifica las fechas recibidas para dejar NULAS aquellas menores o iguales al 01/01/1901
            */
            IF nvl(c.fec_ult_pago, to_date('01/01/1901', 'DD/MM/YYYY')) <= c_fec_min_proceso THEN
               v_fec_ult_pago := NULL;
            ELSE
               v_fec_ult_pago := c.fec_ult_pago;
            END IF;
            IF nvl(c.fec_ult_compra, to_date('01/01/1901', 'DD/MM/YYYY')) <= c_fec_min_proceso THEN
               v_fec_ult_compra := NULL;
            ELSE
               v_fec_ult_compra := c.fec_ult_compra;
            END IF;
            IF nvl(c.fec_ult_operacion, to_date('01/01/1901', 'DD/MM/YYYY')) <= c_fec_min_proceso THEN
               v_fec_ult_ope := NULL;
            ELSE
               v_fec_ult_ope := c.fec_ult_operacion;
            END IF;
            IF nvl(c.fec_vct_ult_cierre, to_date('01/01/1901', 'DD/MM/YYYY')) <= c_fec_min_proceso THEN
               v_fec_vct_ult_cie := NULL;
            ELSE
               v_fec_vct_ult_cie := c.fec_vct_ult_cierre;
            END IF;
            IF nvl(c.fec_ult_extracto, to_date('01/01/1901', 'DD/MM/YYYY')) <= c_fec_min_proceso THEN
               v_fec_ult_extracto := NULL;
            ELSE
               v_fec_ult_extracto := c.fec_ult_extracto;
            END IF;
            /*      || Busca el usuario del Sistema relacionado con el usuario del Ente      */
            BEGIN
               SELECT cod_usuario
                 INTO v_cod_usuario
                 FROM ge_ent_usuarios
                WHERE cod_ente = c_bancard
                  AND cod_usu_ente = c.cod_usu_ente;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_cod_usuario := NULL;
               WHEN OTHERS THEN
                  v_cod_usuario := NULL;
                  pat_imp.pr_log('ITC-00010: Al buscar el usuario responsable de la cuenta ' ||
                                 c.nro_cuenta);
                  --          raise v_error;
            END;
            /* || __Busca los datos del cliente principal de la cuenta__
            || Aqui busca el cliente principal por la relacion con la tarjeta, en este punto, todavia la relacion
            || esta como viene de la procesadora, o sea 0 para Principal y 1 para Adicional.
            --no se recibe principal juridico,sino 1er adicional fisico   */
            --limpiar variables
            v_nro_doc_principal := NULL;
            v_pri_adicional     := NULL;
            v_per_principal     := NULL;
            v_nom_principal     := NULL;
            v_nro_doc_principal := NULL;
            v_nom_usuario       := NULL;
            v_nro_doc_adicional := NULL;
            v_per_principal     := NULL;

            v_es_juridica := 'N';
            BEGIN
               SELECT DISTINCT NVL(t.nro_documento,ct.ruc), nom_enviar
                 INTO v_nro_doc_principal, v_nom_usuario
                 FROM ta_tarjetas_tmp t,ta_cuentas_tmp ct
                WHERE t.nro_cuenta=ct.nro_cuenta
                  AND t.nro_cuenta = c.nro_cuenta
                  AND nvl(t.relacion, 0) = 0;
            EXCEPTION
               WHEN no_data_found THEN
                  BEGIN
                     SELECT p.nro_documento, NULL
                       INTO v_nro_doc_principal, v_nom_usuario
                       FROM ba_personas p, ge_cta_clientes cl
                      WHERE cl.nro_cuenta = to_char(to_number(c.nro_cuenta))
                        AND relacion = 'P'
                        AND p.cod_persona = cl.cod_persona
                        AND rownum = 1;
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_nro_doc_principal := NULL;
                        v_nom_usuario       := NULL;
                        pat_imp.pr_log('ITC-00011: Al buscar el codigo de persona principal de la cuenta ' ||
                                       c.nro_cuenta);
                  END;
               WHEN OTHERS THEN
                  v_nro_doc_principal := NULL;
                  v_nom_usuario       := NULL;
                  pat_imp.pr_log('ITC-00011: Al buscar el codigo de persona principal de la cuenta ' ||
                                 c.nro_cuenta);
            END;
            --

            IF v_nro_doc_principal IS NULL THEN
                  v_nro_error      := 1;
                  v_men_error      := 'PRINCIPAL_DOC_NUMBER_NOT_FOUND';

               -- si no hay principal,es juridico//YA NO SE DA QUE NO EXISTA,EL ADICIONAL VA COMO PRINCIPAL
               pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'No se obtuvo un nro de documento del principal para la cuenta '  || c.nro_cuenta ||
               ' en el cursor CUENTAS. ');
               GOTO siguiente;
            ELSE
               /* RI : 20/01/2010 : Si ya existe la cuenta traer
               directamente la persona principal utilizando la cuenta */
               IF v_existe = 'S' THEN
                  -- ya existe la cuenta
                  BEGIN
                     SELECT ct.cod_persona, p.nom_completo, decode(tipo, 'F', 'N', 'S')
                       INTO v_per_principal, v_nom_principal, v_es_juridica
                       FROM ba_personas p, ge_cta_clientes ct
                      WHERE ct.nro_cuenta = to_char(to_number(c.nro_cuenta))
                        AND ct.relacion = 'P'
                        AND p.cod_persona = ct.cod_persona;
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_per_principal := NULL;
                        v_nom_principal := NULL;
                  END;
               END IF;
               IF v_per_principal IS NULL THEN
                  BEGIN
                     SELECT p.cod_persona, p.nom_completo
                       INTO v_per_principal, v_nom_principal
                       FROM ba_personas p
                      WHERE p.cod_tip_documento IN
                            (v_cod_tip_doc, v_cod_tip_pas, v_cod_tip_dni, v_cod_tip_cad,
                             v_cod_tip_cie, v_cod_tip_crc) --tipo cedula,dni,pasaporte,Cedula de Admision Permanente,Cedula Identidad Extranjera
                        AND ltrim(REPLACE(TRIM(p.nro_documento), '-', ''), 0) = v_nro_doc_principal
                        AND rownum = 1;
                     v_es_juridica := 'N';
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_per_principal := NULL;
                        v_nom_principal := NULL;
                  END;
               END IF;
               IF v_per_principal IS NULL THEN
                  BEGIN
                     SELECT p.cod_persona, j.raz_social
                       INTO v_per_principal, v_nom_principal
                       FROM ba_per_juridicas j, ba_personas p
                      WHERE p.cod_tip_documento IN (v_cod_tip_ruc) --tipo ruc
                        AND p.nro_documento = trim(substr(v_nro_doc_principal, 1, 10))
                        AND j.cod_persona = p.cod_persona;
                     v_es_juridica := 'S';
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_es_juridica   := 'N';
                        v_per_principal := NULL;
                        v_nom_principal := NULL;
                  END;
               END IF;
            END IF;

            /*   || Busca la solicitud del cliente, por el modulo y la modalidad de la tarjeta,
            || ademas del estado de la solicitud  */
            BEGIN
               SELECT nro_solicitud,
                      fec_solicitud,
                      afinidad,
                      sub_afinidad,
                      nro_cta_debito,
                      cod_usu_promotor,
                      cod_rub_economico,
                      cod_campana
                 INTO v_nro_solicitud,
                      v_fec_solicitud,
                      v_cod_afinidad,
                      v_sub_afinidad,
                      v_nro_cta_debito,
                      v_cod_usu_promotor,
                      v_cod_rub_economico, /*Se recupera la Cta. de Débito y Promotor a partir de la solicitud de la TC */
                      v_cod_campana
                 FROM ta_solicitudes s
                WHERE s.cod_persona = v_per_principal
                  AND s.cod_estado = 'TIA'
                  AND s.cod_modulo = c.cod_modulo
                  AND s.cod_modalidad = c.cod_modalidad
                  AND (s.afinidad, nvl(s.sub_afinidad, 'ZZ')) IN
                      (SELECT t.afinidad, nvl(t.sub_afinidad, 'ZZ')
                         FROM ta_tipos t
                        WHERE t.cod_modulo = c.cod_modulo
                          AND t.cod_modalidad = c.cod_modalidad
                          AND t.nro_bin = c.nro_bin)
                  AND s.fec_solicitud = (SELECT MAX(tsoli2.fec_solicitud)
                                           FROM ta_solicitudes tsoli2
                                          WHERE tsoli2.cod_persona = v_per_principal
                                            AND tsoli2.cod_estado = 'TIA'
                                            AND tsoli2.cod_modulo = c.cod_modulo
                                            AND tsoli2.cod_modalidad = c.cod_modalidad
                                            AND (tsoli2.afinidad, nvl(tsoli2.sub_afinidad, 'ZZ')) IN
                                                (SELECT t.afinidad, nvl(t.sub_afinidad, 'ZZ')
                                                   FROM ta_tipos t
                                                  WHERE t.cod_modulo = c.cod_modulo
                                                    AND t.cod_modalidad = c.cod_modalidad
                                                    AND t.nro_bin = c.nro_bin));
            EXCEPTION
               WHEN OTHERS THEN
                  -- Buscar de la cuenta
                  BEGIN
                     SELECT nro_solicitud,
                            fec_solicitud,
                            afinidad,
                            sub_afinidad,
                            nro_cta_debito,
                            cod_rub_economico,
                            cod_campana
                       INTO v_nro_solicitud,
                            v_fec_solicitud,
                            v_cod_afinidad,
                            v_sub_afinidad,
                            v_nro_cta_debito,
                            v_cod_rub_economico, /*Se recupera la Cta. de Débito a partir de la cuenta de la TC */
                            v_cod_campana
                       FROM ta_cta_tarjetas
                      WHERE nro_cuenta = to_char(to_number(c.nro_cuenta));
                  EXCEPTION
                     WHEN OTHERS THEN
                        --pat_imp.pr_log( 'ITC-00099: Al buscar la solicitud de la cuenta ' || c.nro_cuenta || ', para la persona ' || v_per_principal  );
                        v_nro_solicitud     := NULL;
                        v_fec_solicitud     := NULL;
                        v_cod_afinidad      := NULL;
                        v_sub_afinidad      := NULL;
                        v_cod_rub_economico := nvl(fug_obt_pardinamico('PRE_SOL_COD_RUB_PRIMARIO',c.cod_modulo,c.cod_modalidad,nvl(c.cod_moneda,pag_gen.fu_obt_mon_local)),'970108'); --- Rubro Económico de Consumo
                        v_cod_campana       := null;
                  END;
            END;
            -- Si no encuentra la afinidad buscar en ta_tipos desde la tarjeta
            IF v_cod_afinidad IS NULL THEN
               BEGIN
                  SELECT ta.afinidad, ta.sub_afinidad
                    INTO v_cod_afinidad, v_sub_afinidad
                    FROM ta_tipos ta
                   WHERE ta.cod_modulo = c.cod_modulo
                     AND ta.cod_modalidad = c.cod_modalidad
                     AND ta.nro_bin = c.nro_bin
                     AND rownum = 1;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_cod_afinidad := NULL;
                     v_sub_afinidad := NULL;
               END;
            END IF;
            /* || Si no existe todavia la persona, entonces inserta una nueva persona con los datos recibidos YA NO*/
            IF v_per_principal IS NULL AND v_nom_principal IS NULL THEN

               v_nro_error      := 1;
               v_men_error      := 'PRINCIPAL_PERSON_COD_NOT_FOUND';

               -- si no hay principal,es juridico//YA NO SE DA QUE NO EXISTA,EL ADICIONAL VA COMO PRINCIPAL
               pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'No se encontró un cod_persona del principal para la cuenta '  || c.nro_cuenta ||
               ' y Nro de Documento ' || v_nro_doc_principal ||  ' en las tablas temporales y/o en el Core - Cursor CUENTAS.');

               GOTO siguiente;

            END IF;
            /*
            || Setea la marca de mora y la marca de exceso de la cuenta
            */

            IF nvl(c.mar_mora, ' ') = 'M' THEN
               v_mar_mora := 'S';
            ELSE
               v_mar_mora := 'N';
            END IF;
            IF nvl(c.mar_excedido, ' ') = 'E' THEN
               v_mar_excedido := 'S';
            ELSE
               v_mar_excedido := 'N';
            END IF;

            IF nvl(v_existe, 'N') = 'S' THEN
               /*
               || Si existe la cuenta, actualiza los datos de la misma
               */
               BEGIN
                  UPDATE ta_cta_tarjetas a
                     SET lin_credito          = c.lin_credito,
                         lin_cuotas           = c.lin_cuotas,
                         sal_facturar         = c.sal_facturar,
                         sal_facturado        = c.sal_facturado,
                         sal_financiado       = c.sal_financiado,
                         sal_ult_extracto     = c.sal_ult_extracto,
                         sal_cuo_pendientes   = c.sal_cuo_pendientes,
                         mto_pag_minimo       = c.mto_pag_minimo,
                         sal_pag_minimo       = c.sal_pag_minimo,
                         mto_mora             = c.mto_mora,
                         dia_mora             = c.dia_mora,
                         mto_autorizaciones   = c.mto_autorizaciones,
                         mto_pag_mes          = c.mto_pag_mes,
                         estado               = v_estado,
                         fec_apertura         = c.fec_apertura,
                         fec_ult_pago         = v_fec_ult_pago,
                         fec_ult_compra       = v_fec_ult_compra,
                         fec_ult_operacion    = v_fec_ult_ope,
                         fec_ult_extracto     = v_fec_ult_extracto,
                         fec_ult_cierre       = c.fec_ult_cierre,
                         fec_vct_ult_cierre   = v_fec_vct_ult_cie,
                         fec_modificacion     = c_fec_actual,         -- Actualiza FH Modificación por procesamiento
                         tip_cierre           = c.tip_cierre,
                         cod_tip_cierre       = c.tip_cierre,
                         tip_tas_financiacion = c.tip_tas_financiacion,
                         tip_com_emision      = c.tip_com_emision,
                         tas_financiacion     = c.tas_financiacion,
                         tas_mora             = c.tas_mora,
                         tas_cuotas           = c.tas_cuotas,
                         tas_adelanto         = c.tas_adelanto,
                         por_pag_minimo       = c.por_pag_minimo,
                         mar_mora             = v_mar_mora,
                         mar_excedido         = v_mar_excedido,
                         cod_usu_promotor     = v_cod_usu_promotor,/*,
                         franqueo             = c.franqueo,
                         ind_seg_vida         = c.ind_seg_vida,*/---bancard ueno no existe en bankitti
                         cod_exc_cargo        = c.car_no_aplicar--c.cod_exc_cargo
                   WHERE nro_cuenta    = to_char(to_number(c.nro_cuenta))
                   AND   cod_modalidad = c.cod_modalidad
                   AND   cod_modulo    = c.cod_modulo;

                  v_crea_cuenta := 'N';

               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     v_nro_error      := 1 ;
                     v_men_error      := 'UPDATE_ACCOUNT_ERROR';
                     v_crea_cuenta    := NULL;

                      pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'Ocurrió un error al actualizar los datos de la cuenta '  || c.nro_cuenta ||
                                             ' en la tabla ta_cta_tarjetas');

               END;
               /*Excepciones Cargos del Cierre por Cuenta*/
               DECLARE
               /*se modifica el campo cod_exc_cargo no existe en bankitti por car_no_aplicar*/
                  CURSOR car_exc IS
                       SELECT a.car_no_aplicar, b.val_minimo parametro
                       FROM (SELECT to_number(car_no_aplicar) AS car_no_aplicar
                               FROM (SELECT substr(car_no_aplicar, 1, 3) car_exc1,
                                            substr(car_no_aplicar, 4, 3) car_exc2,
                                            substr(car_no_aplicar, 7, 3) car_exc3,
                                            substr(car_no_aplicar, 10, 3) car_exc4,
                                            substr(car_no_aplicar, 13, 3) car_exc5,
                                            substr(car_no_aplicar, 16, 3) car_exc6,
                                            substr(car_no_aplicar, 19, 3) car_exc7,
                                            substr(car_no_aplicar, 22, 3) car_exc8,
                                            substr(car_no_aplicar, 25, 3) car_exc9,
                                            substr(car_no_aplicar, 28, 3) car_exc10
                                       FROM ta_cta_tarjetas_tmp
                                      WHERE nro_cuenta = c.nro_cuenta)
                                      unpivot(car_no_aplicar FOR parametro
                                      IN(car_exc1 AS 'parametro',
                                         car_exc2 AS 'parametro',
                                         car_exc3 AS 'parametro',
                                         car_exc4 AS 'parametro',
                                         car_exc5 AS 'parametro',
                                         car_exc6 AS 'parametro',
                                         car_exc7 AS 'parametro',
                                         car_exc8 AS 'parametro',
                                         car_exc9 AS 'parametro',
                                         car_exc10 AS'parametro'))) a,
                              ba_cod_referencias b
                        WHERE b.dominio = 'COD_CTO_BANCARD'
                         AND to_number(val_maximo) = a.car_no_aplicar;

               BEGIN

                 UPDATE ba_tab_dat_adicionales a
                    SET a.val_parametro = 'N'
                  WHERE a.tab_relacion = 'TA_CTA_TARJETAS'
                    AND a.referencia = c.nro_cuenta
                    AND a.parametro like'TCR_EXO%';

                  FOR r_car_exc IN car_exc LOOP

                     BEGIN

                        UPDATE ba_tab_dat_adicionales a
                           SET a.val_parametro = 'S'
                         WHERE a.tab_relacion = 'TA_CTA_TARJETAS'
                           AND a.parametro = r_car_exc.parametro
                           AND a.referencia = c.nro_cuenta;
                        IF SQL%NOTFOUND THEN
                           BEGIN
                              INSERT INTO ba_tab_dat_adicionales
                                 (tab_relacion, referencia, parametro, val_parametro)
                              VALUES
                                 ('TA_CTA_TARJETAS', c.nro_cuenta, r_car_exc.parametro, 'S');
                           EXCEPTION
                              WHEN v_error THEN
                                 RAISE v_error;
                              WHEN OTHERS THEN
                                 pat_imp.pr_log('ITC-00014: Al actualizar cargos excluidos de la cuenta ' ||
                                                c.nro_cuenta);
                           END;
                        END IF;
                      END;

                   END LOOP;
                 END;
             ELSE
               /*
               || Si NO existe la cuenta, inserta la cuenta en TA_CTA_TARJETAS
               */
               /* Verificar si la persona esta inhibida */
               v_per_inhibida := fug_ver_firmante(v_per_principal, 5, c.cod_modalidad, NULL,
                                                  v_oficina, v_mens);
               IF v_per_inhibida <> 0 THEN

                  v_men_error      := 'PRINCIPAL_PERSON_COD_INHIBITED';
                  pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'Persona Principal COD_PERSONA ' ||v_per_principal || ' y Nro. de Documento ' ||
                                 v_nro_doc_principal || ' inhibida para este tipo de Cuentas. Cuenta Nro ' || c.nro_cuenta ||
                                             ' - cursor CUENTAS');

                  GOTO siguiente;
               ELSE
                  BEGIN
                     INSERT INTO ta_cta_tarjetas
                        (nro_cuenta, denominacion, cod_modulo, cod_modalidad, cod_oficina,
                         cod_moneda, lin_credito, lin_cuotas, sal_facturar, sal_facturado,
                         sal_financiado, sal_ult_extracto, sal_cuo_pendientes, mto_pag_minimo,
                         sal_pag_minimo, mto_mora, dia_mora, mto_autorizaciones, mto_pag_mes, estado,
                         fec_solicitud, fec_apertura, fec_ult_pago, fec_ult_compra,
                         fec_ult_operacion, fec_ult_extracto, fec_ult_cierre, fec_vct_ult_cierre,
                         tip_cierre, tip_tas_financiacion, tip_com_emision, tas_financiacion,
                         tas_mora, tas_cuotas, tas_adelanto, por_pag_minimo, cod_usu_promotor,
                         mar_mora, mar_excedido, mar_recuperado, mar_bloqueo, nro_solicitud,
                         afinidad, sub_afinidad, cat_automatica, deb_automatico, nro_cta_debito,
                         tip_cobro, cod_rub_economico,/* franqueo, ind_seg_vida,*/ cod_exc_cargo,
                         cod_campana,cod_tip_cierre)
                     VALUES
                        (to_char(to_number(c.nro_cuenta)), nvl(c.denominacion, v_nom_principal),
                         nvl(c.cod_modulo, 5), c.cod_modalidad, v_oficina, c_cod_mon_local,
                         c.lin_credito, c.lin_cuotas, c.sal_facturar, c.sal_facturado,
                         c.sal_financiado, c.sal_ult_extracto, c.sal_cuo_pendientes,
                         c.mto_pag_minimo, c.sal_pag_minimo, c.mto_mora, c.dia_mora,
                         c.mto_autorizaciones, c.mto_pag_mes, v_estado, v_fec_solicitud,
                         c.fec_apertura, v_fec_ult_pago, v_fec_ult_compra, v_fec_ult_ope,
                         v_fec_ult_extracto, c.fec_ult_cierre, v_fec_vct_ult_cie, c.tip_cierre,
                         c.tip_tas_financiacion, c.tip_com_emision, c.tas_financiacion, c.tas_mora,
                         c.tas_cuotas, c.tas_adelanto, c.por_pag_minimo, v_cod_usu_promotor,
                         v_mar_mora, v_mar_excedido, c.mar_recuperado, c.mar_bloqueo,
                         v_nro_solicitud, v_cod_afinidad, v_sub_afinidad, 1,
                         decode(nvl(c.deb_automatico, '0'), '1', 'S', 'N'), v_nro_cta_debito,
                         decode(nvl(c.tip_cobro, '0'), '1', 'M', 'T'), v_cod_rub_economico,
                         /*c.franqueo, c.ind_seg_vida,*/ c.car_no_aplicar/*c.cod_exc_cargo*/, v_cod_campana,c.tip_cierre);

                        v_crea_cuenta := 'S';

                     IF v_es_juridica = 'S' THEN
                       --Verifica que exista como cliente
                        BEGIN
                           SELECT 'S'
                             INTO v_ge_cliente
                             FROM ge_clientes cu
                            WHERE cu.cod_persona = v_per_principal;
                        EXCEPTION
                           WHEN no_data_found THEN
                              BEGIN
                                 INSERT INTO ge_clientes
                                    (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial,
                                     cli_especial, residente, cod_sec_contable, cod_tip_deudor,
                                     cod_seg_cliente)
                                 VALUES
                                    (v_per_principal, NVL(v_oficina,61), 'N',
                                     nvl(fug_obt_pardinamico('GEN_COD_OFICIAL'),
                                          fug_obt_pardinamico('COD_USU_OFI_DEFECTO')), 'N', 'S', 'N', 2,
                                     nvl(fug_obt_pardinamico('GEN_COD_SEG_CLIENTE'), 12));
                              EXCEPTION
                                 WHEN OTHERS THEN
                                    pat_imp.pr_log('No se inserto el cliente ' ||
                                                   v_per_principal || to_char(to_number(c.nro_cuenta)) ||
                                                   ' - ' || SQLERRM);
                                    RAISE v_error;
                              END;
                        END;
                        -- insertar la relacion principal
                        BEGIN
                           INSERT INTO ge_cta_clientes
                              (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
                               cod_modalidad, relacion)
                           VALUES
                              (v_per_principal, to_char(to_number(c.nro_cuenta)), 0, v_oficina, 5,
                               c.cod_modalidad, 'P');
                        EXCEPTION
                           WHEN OTHERS THEN
                              pat_imp.pr_log('ITC-00015: Al insertar ge_cta_clientes ' ||
                                             v_per_principal || ' - ' || c.nro_cuenta);
                        END;
                     END IF;
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        pat_imp.pr_log('ITC-00015: Al insertar los datos de la cuenta ' ||
                                       c.nro_cuenta);
                        --            raise v_error;
                  END;

                  -----------------------------
                  /* RI : 13/05/2010 : Traer la direccion general de la persona
                  y Personalizar la direccion a la cuenta  */
                  DECLARE
                     CURSOR c_dir IS
                        SELECT tip_envio, referencia
                          FROM ge_dir_envios
                         WHERE cod_persona = v_per_principal
                           AND nro_cuenta IS NULL;
                  BEGIN
                     FOR d IN c_dir LOOP
                        INSERT INTO ge_dir_envios
                           (cod_persona, tip_envio, referencia, nro_cuenta)
                        VALUES
                           (v_per_principal, d.tip_envio, d.referencia,
                            to_char(to_number(c.nro_cuenta)));
                     END LOOP;
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        pat_imp.pr_log('ITC-00116: Al insertar la direccion de envio de la Cuenta ' ||
                                       c.nro_cuenta);
                  END;
                  -----------------------------
               END IF;
               /*Excepciones Cargos del Cierre por Cuenta*/
               DECLARE

                  CURSOR car_exc IS
                       SELECT a.car_no_aplicar, b.val_minimo parametro
                       FROM (SELECT to_number(car_no_aplicar) AS car_no_aplicar
                               FROM (SELECT substr(car_no_aplicar, 1, 3) car_exc1,
                                            substr(car_no_aplicar, 4, 3) car_exc2,
                                            substr(car_no_aplicar, 7, 3) car_exc3,
                                            substr(car_no_aplicar, 10, 3) car_exc4,
                                            substr(car_no_aplicar, 13, 3) car_exc5,
                                            substr(car_no_aplicar, 16, 3) car_exc6,
                                            substr(car_no_aplicar, 19, 3) car_exc7,
                                            substr(car_no_aplicar, 22, 3) car_exc8,
                                            substr(car_no_aplicar, 25, 3) car_exc9,
                                            substr(car_no_aplicar, 28, 3) car_exc10
                                       FROM ta_cta_tarjetas_tmp
                                      WHERE nro_cuenta = c.nro_cuenta)
                                      unpivot(car_no_aplicar FOR parametro
                                      IN(car_exc1 AS 'parametro',
                                         car_exc2 AS 'parametro',
                                         car_exc3 AS 'parametro',
                                         car_exc4 AS 'parametro',
                                         car_exc5 AS 'parametro',
                                         car_exc6 AS 'parametro',
                                         car_exc7 AS 'parametro',
                                         car_exc8 AS 'parametro',
                                         car_exc9 AS 'parametro',
                                         car_exc10 AS'parametro'))) a,
                              ba_cod_referencias b
                        WHERE b.dominio = 'COD_CTO_BANCARD'
                         AND to_number(val_maximo) = a.car_no_aplicar;

               BEGIN

                  UPDATE ba_tab_dat_adicionales a
                     SET a.val_parametro = 'N'
                   WHERE a.tab_relacion = 'TA_CTA_TARJETAS'
                     AND a.referencia = c.nro_cuenta
                     AND a.parametro LIKE 'TCR_EXO%';

                  FOR r_car_exc IN car_exc LOOP

                     BEGIN
                        UPDATE ba_tab_dat_adicionales a
                           SET a.val_parametro = 'S'
                         WHERE a.tab_relacion = 'TA_CTA_TARJETAS'
                           AND a.parametro = r_car_exc.parametro
                           AND a.referencia = c.nro_cuenta;
                        IF SQL%NOTFOUND THEN
                           BEGIN
                              INSERT INTO ba_tab_dat_adicionales
                                 (tab_relacion, referencia, parametro, val_parametro)
                              VALUES
                                 ('TA_CTA_TARJETAS', c.nro_cuenta, r_car_exc.parametro, 'S');
                           EXCEPTION
                              WHEN v_error THEN
                                 RAISE v_error;
                              WHEN OTHERS THEN
                                 pat_imp.pr_log('ITC-00014: Al actualizar cargos excluidos de la cuenta ' ||
                                                c.nro_cuenta);
                           END;
                        END IF;
                      END;

                   END LOOP;
                 END;
            END IF;
            pat_imp.pr_act_ult_pro(to_char(to_number(c.nro_cuenta)), c_fec_actual);
         r_log.nom_proceso := c_nom_proceso;

            --Para Fielco se debe sumar dos días habiles porque sabado es habil, recien lunes se procesa
            --v_fec_cierre := nvl(pat_imp.fu_obt_fec_cierre(c_bancard, c.cod_modalidad, c.tip_cierre),trunc(SYSDATE));
            v_fec_cierre := pag_cal.fu_obt_fec_sig_hab(nvl(pat_imp.fu_obt_fec_cierre(c_bancard, c.cod_modalidad, c.tip_cierre),trunc(SYSDATE)),v_ofi_matriz, 2);

            --IF pag_cal.fu_obt_fec_sig_hab(v_fec_cierre, v_ofi_matriz) = c_fec_actual THEN
            IF pag_cal.fu_obt_fec_sig_hab(v_fec_cierre, v_ofi_matriz,-1) = c_fec_actual THEN
               pat_imp.pr_ins_sal_cierre(to_char(to_number(c.nro_cuenta)), v_fec_cierre,c_bancard); --FSPC-509
               r_log.nom_proceso := c_nom_proceso;
            END IF;
            /*************************************** SECCION DE PROCESOS DE TARJETAS ***************************************/
            v_can_tar_activa := 0;
            v_can_marca      := 0;
            -- Reinicializa el estado de log para CADA cuenta.
         v_nro_error := 3;
            v_men_error := 'INFO';

            FOR t IN tarjetas(c.nro_cuenta) LOOP
               /*
               || Verifica que existe la tarjeta
               */
               v_fec_entrega  := NULL;
               v_persona      := NULL;
               v_nom_completo := NULL;
               v_tip_persona  := NULL;
               BEGIN
                  SELECT 'S', cod_estado, fec_entrega
                    INTO v_existe_tarjeta, v_est_anterior, v_fec_entrega
                    FROM ta_tarjetas
                   WHERE nro_cuenta = to_char(to_number(c.nro_cuenta))
                     AND nro_tarjeta = t.nro_tarjeta;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_existe_tarjeta := 'N';
                  WHEN OTHERS THEN
                     v_existe_tarjeta := 'N';
                     pat_imp.pr_log('ITC-00016: Al comprobar la tarjeta de la cuenta ' ||
                                    c.nro_cuenta || ' / ' || substr(t.nro_tarjeta,13,16));
                     --            raise v_error;
               END;

               /* RI : 20/01/2010 : Si ya existe la tarjeta traer la
               persona con el numero de tarjeta */
               IF v_existe_tarjeta = 'S' THEN
                  -- ya existe la tarjeta
                  BEGIN
                     SELECT ta.cod_persona, p.nom_completo, tipo
                       INTO v_persona, v_nom_completo, v_tip_persona
                       FROM ba_personas p, ta_tarjetas ta
                      WHERE ta.nro_cuenta = to_char(to_number(t.nro_cuenta))
                        AND ta.nro_tarjeta = t.nro_tarjeta
                        AND p.cod_persona = ta.cod_persona;
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_persona      := NULL;
                        v_nom_completo := NULL;
                        v_tip_persona  := NULL;
                  END;
               END IF;
               IF v_persona IS NULL THEN
                  BEGIN
                     SELECT cod_persona, nom_completo, tipo
                       INTO v_persona, v_nom_completo, v_tip_persona
                       FROM ba_personas
                      WHERE cod_tip_documento IN
                            (v_cod_tip_doc, v_cod_tip_pas, v_cod_tip_dni, v_cod_tip_cad,
                             v_cod_tip_cie, v_cod_tip_crc)
                        AND ltrim(REPLACE(TRIM(nro_documento), '-', ''), 0) = t.nro_documento
                        AND ROWNUM = 1;
                  EXCEPTION
                     WHEN no_data_found THEN
                        -- es juridica
                        BEGIN
                           SELECT p.cod_persona, j.raz_social, p.tipo
                             INTO v_persona, v_nom_completo, v_tip_persona
                             FROM ba_per_juridicas j, ba_personas p
                            WHERE p.cod_tip_documento IN (v_cod_tip_ruc) --tipo ruc
                              AND p.nro_documento = trim(substr(v_nro_doc_principal, 1, 10))
                              AND j.cod_persona = p.cod_persona
                              AND ROWNUM = 1;
                        EXCEPTION
                           WHEN no_data_found THEN
                              v_persona      := NULL;
                              v_nom_completo := NULL;
                              v_tip_persona  := 'x';
                           WHEN OTHERS THEN
                              v_persona      := NULL;
                              v_nom_completo := NULL;
                              v_tip_persona  := NULL;
                              pat_imp.pr_log('ITC-00017: Al buscar el codigo de persona de la Tarjeta ' ||
                                             c.nro_cuenta || ' / ' || substr(t.nro_tarjeta,13,16));
                        END;
                     WHEN too_many_rows THEN
                        v_persona      := NULL;
                        v_nom_completo := NULL;
                        v_tip_persona  := NULL;
                        pat_imp.pr_log('ITC-00017: Existen mas de una persona con el documento ' ||
                                       t.nro_documento || ' / ' || substr(t.nro_tarjeta,13,16));
                     WHEN OTHERS THEN
                        v_persona      := NULL;
                        v_nom_completo := NULL;
                        v_tip_persona  := NULL;
                        pat_imp.pr_log('ITC-00017: Al buscar el codigo de persona de la Tarjeta ' ||
                                       c.nro_cuenta || ' / ' || substr(t.nro_tarjeta,13,16));
                  END;
               END IF;

               /* || Si la persona aun no esta creada en el sistema, crea una nueva persona con los datos recibidos.  */
               IF nvl(v_tip_persona, 'x') = 'x' THEN
                  IF t.nro_documento IS NOT NULL THEN

                     v_nro_error      := 1 ;
                     v_men_error      := 'PERSON_TYPE_NOT_FOUND';

                      pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'No se encontró a la persona en el sistema para la cuenta '  || c.nro_cuenta ||
                                             ' Nro. de Documento ' || t.nro_documento || ' - Cursor TARJETAS ');

                     GOTO sig_tarjeta;
                  ELSE
                     pat_imp.pr_log('ITC-00018: No se pudo crear la persona para la Tarjeta ' ||
                                    c.nro_cuenta || ' - ' || substr(t.nro_tarjeta,13,16));
                     --RAISE v_error;
                  END IF;
               END IF;

               v_nom_embozar := t.nom_embozar;
               /*
               || Setea el estado de la tarjeta
               */
               IF nvl(t.cod_situacion, 0) = 1 THEN
                  v_can_tar_activa := nvl(v_can_tar_activa, 0) + 1;
                  v_est_tarjeta    := NULL; --- Activa (Se le pasa null para que no reemplace el estado que ya tiene).
                  IF nvl(t.mar_boletinada, 'x') = 'A' THEN
                     v_est_tarjeta := 13; --- Bloqueo Administrativo
                  ELSIF nvl(t.mar_boletinada, 'x') = 'U' THEN
                     v_est_tarjeta := 14; --- Bloqueo del Usuario
                  ELSIF nvl(t.mar_boletinada, 'x') = 'M' THEN
                     v_est_tarjeta := 19; --- Bloqueo por Alerta (Alerta por Riesgos de Bancard)
                  ELSIF nvl(t.mar_boletinada, 'x') = 'P' THEN
                     v_est_tarjeta := 23; --- Bloqueo por Proceso (Tarjetas en MORA)
                  ELSIF nvl(t.mar_boletinada, 'x') = 'C' THEN
                     v_est_tarjeta := 24; --- Bloqueo por Pin Erroneo
                  END IF;
                  IF nvl(t.mar_vencida, 'x') = 'V' THEN
                     v_est_tarjeta := 12; -- Vencida
                  END IF;
                  IF nvl(t.mar_recuperada, 'x') = 'R' THEN
                     v_est_tarjeta := 4; -- Recuperada
                  END IF;
                  -- Esto es para que no pierda el valor que ya tiene en la tabla y se modifica por la entrega.
                  -- Regrabación de Tarjeta(Se realiza directamente en Bancard, estado de la Tarjeta es v_est_tarjeta = 1(en administradora)
                  IF v_est_anterior IN (1, 3, 4, 12, 13, 14, 19, 23, 24) AND v_est_tarjeta IS NULL THEN
                     v_est_tarjeta := 6; -- Activa.
                  END IF;
                  -- Si tarjeta activa tiene algun tipo de marca(4-Recuperada, 12-Vencida, 13-Bloq.Adm, 14 Bloq.Usu, 19 Alerta, 23 Proceso, 24 Pin Incorrecto)
                  IF v_est_tarjeta IN (4, 12, 13, 14, 19, 23, 24) THEN
                     v_can_marca := nvl(v_can_marca, 0) + 1;
                  END IF;
               ELSIF nvl(t.cod_situacion, 0) = 3 AND v_fec_entrega IS NOT NULL THEN
                  v_est_tarjeta := 10; -- Baja
               ELSIF nvl(t.cod_situacion, 0) IN (3, 2) THEN
                  -- Regrabación de TC (cod_situación 2)
                  v_est_tarjeta := v_est_anterior;
               END IF;
               /*  || Setea la relacion de la persona con respecto a la cuenta principal        */
               --solo si el adicional no fue como principal de una persona juridica
               IF v_es_juridica = 'S' AND t.nro_documento = v_nro_doc_adicional THEN
                  v_relacion := 'A';
               ELSE
                  IF nvl(t.relacion, -1) = 0 THEN
                     v_relacion := 'P';
                  ELSIF nvl(t.relacion, -1) = 1 AND v_tip_persona = 'F' THEN
                     v_relacion := 'A';
                  ELSIF nvl(t.relacion, -1) = 1 AND v_tip_persona = 'J' THEN
                     --juridica no puede ser adicional
                     v_relacion := 'P';
                  END IF;
               END IF;
               /*
               || Calcula la fecha de vencimiento de la tarjeta
               */
               IF t.fec_emision IS NOT NULL THEN
                  v_fec_ven_tarjeta := last_day(to_date('01' ||
                                                        nvl(t.mes_vencimiento,
                                                            to_char(c_fec_actual, 'MMRR')), 'DDMMRR'));
               ELSE
                  v_fec_ven_tarjeta := NULL;
               END IF;
               IF nvl(v_existe, 'N') = 'S' AND nvl(v_existe_tarjeta, 'N') = 'S' THEN
                  /*
                  || Si existe la cuenta y la tarjeta, actualiza los datos de la misma
                  */
                  BEGIN
                     UPDATE ta_tarjetas
                        SET cod_estado      = nvl(v_est_tarjeta, cod_estado),
                            fec_vencimiento = v_fec_ven_tarjeta,
                            nom_embozar     = v_nom_embozar,
                            fec_emision     = t.fec_emision,
                            fec_activacion  = t.fec_entrega, -- Actualiza la Fecha de Activacion
                            vigente         = t.vigente, -- Actualiza la Vigencia como viene de Bancard
                            rel_tarjeta     = t.relacion,
                            id_producto     = t.cod_afinidad||'C' -- Identificamos los id_producto de Corpo con cod_afinidad+C (Ej 181C)
                      WHERE nro_cuenta = to_char(to_number(c.nro_cuenta))
                        AND nro_tarjeta = t.nro_tarjeta;

                     v_crea_tarjeta := 'N';

                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        v_crea_tarjeta := NULL;
                        v_nom_embozar := NULL;

                  v_nro_error      := 1 ;
                        v_men_error      := 'UPDATE_CARD_ERROR';

                        pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'Ocurrió un error al actualizar los datos de la tarjeta ' || substr(t.nro_tarjeta,13,16) || ' para la cuenta ' || c.nro_cuenta ||
                                               ' en la tabla ta_arjetas');

                  END;
               ELSE
                  --no existe
                  v_est_tarjeta := 1; -- En Administradora.
                  /*
                  || Si no existe la cuenta, o la tarjeta, entonces inserta los datos de la tarjeta
                  */
                  v_tip_envio  := NULL;
                  v_referencia := NULL;
                  --recupera tipo de envio y direccion
                  v_pre_embozada := NULL;
                  FOR reg IN solicitudes LOOP
                     v_tip_envio    := reg.tip_envio;
                     v_referencia   := reg.referencia;
                     v_pre_embozada := reg.pre_embozada;
                  END LOOP;
                  BEGIN
                     INSERT INTO ta_tarjetas
                        (nro_cuenta, nro_tarjeta, cod_persona, cod_estado, fec_vencimiento,
                         nom_embozar, vigente, fec_emision, fec_solicitud, tip_envio, referencia,
                         pre_embozada, fec_activacion,rel_tarjeta, fec_entrega, id_producto)
                     VALUES
                        (to_char(to_number(c.nro_cuenta)), t.nro_tarjeta, v_persona, v_est_tarjeta,
                         v_fec_ven_tarjeta, substr(v_nom_embozar, 1, 26), t.vigente,
                         -- Tarjeta Vigente o No Vigente, si está inactiva tiene que venir No Vigente
                         t.fec_emision, v_fec_solicitud, v_tip_envio, v_referencia, v_pre_embozada,
                         t.fec_entrega,t.relacion, t.fec_entrega,t.cod_afinidad||'C');

                        v_crea_tarjeta := 'S';

                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN

                     v_nro_error      := 1;
                     v_men_error      := 'INSERT_CARD_ERROR';

                     pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'Ocurrió un error al insertar los datos de la tarjeta ' || substr(t.nro_tarjeta,13,16) || ' para la cuenta ' || c.nro_cuenta ||
                                             ' en la tabla ta_arjetas');

                  END;


                  IF v_persona IS NULL THEN
                     pat_imp.pr_log('ITC-00021: Codigo de persona nula ' || c.nro_cuenta || ' / ' ||
                                    substr(t.nro_tarjeta,13,16));
                  ELSE
                     SELECT COUNT(*)
                       INTO v_exi_cta_cli
                       FROM ge_cta_clientes
                      WHERE nro_cuenta = to_char(to_number(c.nro_cuenta))
                        AND cod_persona = v_persona;
                  END IF;
                  IF v_exi_cta_cli = 0 AND v_persona IS NOT NULL THEN
                     r_log.nom_proceso := c_nom_proceso;
                     --Verifica que exista como cliente
                        BEGIN
                           SELECT 'S'
                             INTO v_ge_cliente
                             FROM ge_clientes cu
                            WHERE cu.cod_persona = v_persona;
                        EXCEPTION
                           WHEN no_data_found THEN
                              BEGIN
                                 INSERT INTO ge_clientes
                                    (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial,
                                     cli_especial, residente, cod_sec_contable, cod_tip_deudor,
                                     cod_seg_cliente)
                                 VALUES
                                    (v_persona, NVL(v_oficina,61), 'N',
                                     nvl(fug_obt_pardinamico('GEN_COD_OFICIAL'),
                                          fug_obt_pardinamico('COD_USU_OFI_DEFECTO')), 'N', 'S', 'N', 2,
                                     nvl(fug_obt_pardinamico('GEN_COD_SEG_CLIENTE'), 12));
                              EXCEPTION
                                 WHEN OTHERS THEN
                                    pat_imp.pr_log('No se inserto el cliente ' ||
                                                   v_persona || to_char(to_number(c.nro_cuenta)) ||
                                                   ' - ' || SQLERRM);
                                    RAISE v_error;
                              END;
                        END;
                     BEGIN
                        /* || Inserta los datos de la cuenta del cliente    */
                        INSERT INTO ge_cta_clientes
                           (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
                            cod_modalidad, relacion)
                        VALUES
                           (v_persona, to_char(to_number(c.nro_cuenta)), 0, v_oficina, 5,
                            c.cod_modalidad, v_relacion);
                     EXCEPTION
                        WHEN v_error THEN
                           RAISE v_error;
                        WHEN OTHERS THEN
                           IF substr(SQLERRM, 1, 9) <> 'ORA-00001' THEN
                              pat_imp.pr_log('ITC-00022: Al insertar los datos del cliente ' ||
                                             v_persona || ', Cuenta ' || c.nro_cuenta || ' / '
                                             || substr(t.nro_tarjeta,13,16)|| ' Error : ' || SQLERRM);
                           END IF;
                     END;

                    END IF;
                      --- Inserta Cta Garantias ---
                      IF v_relacion = 'P' THEN

                        DECLARE
                           CURSOR sol_garantia IS
                              SELECT nro_solicitud, nro_garantia, cod_garantia, mto_aplicado
                                FROM ta_sol_garantias g
                               WHERE g.nro_solicitud = v_nro_solicitud;
                        BEGIN
                           FOR gar IN sol_garantia LOOP
                              BEGIN
                                 INSERT INTO ta_cta_garantias
                                    (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado,
                                     mto_apl_computable)
                                 VALUES
                                    (to_char(to_number(c.nro_cuenta)), gar.nro_garantia, gar.cod_garantia,
                                     gar.mto_aplicado, 0);
                              EXCEPTION
                                 WHEN v_error THEN
                                    RAISE v_error;
                                 WHEN OTHERS THEN
                                    pat_imp.pr_log('ITC-00115: Al insertar la garantia ' ||
                                                gar.nro_garantia || ' de la Cuenta ' || c.nro_cuenta);
                              END;
                            END LOOP;
                          END;
                      END IF;
               END IF;

               -- Seteo variables..
               v_nro_error      := 3;
               v_men_error      := 'INFO';

               IF v_crea_cuenta = 'S' ---AND v_crea_tarjeta = 'S' -- Ambas se crearon
               THEN

                  pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Se creó correctamente la cuenta ' || c.nro_cuenta );

               ELSIF v_crea_cuenta = 'N'
               THEN
                 pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Se actualizo correctamente la cuenta ' || c.nro_cuenta );
               END IF;

               IF v_crea_tarjeta = 'S' ---AND v_crea_tarjeta = 'S' -- Ambas se crearon
               THEN

                  pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Se creó correctamente la tarjeta finalizada en ' || substr(t.nro_tarjeta,13,16)|| ' vinculada a la la cuenta ' || c.nro_cuenta );

               ELSIF v_crea_tarjeta = 'N'
               THEN
                 pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Se actualizo correctamente la tarjeta finalizada en ' || substr(t.nro_tarjeta,13,16)|| ' vinculada a la la cuenta ' || c.nro_cuenta );

               END IF;


               <<sig_tarjeta>>
               NULL;
            END LOOP;

            /*
            || Busca la tarjeta principal de la cuenta, y setea la cuenta de acuerdo al estado de la misma.
            */
            BEGIN
               SELECT decode(nvl(t.mar_recuperada, 'N'), 'R', 'S', 'N'),
                      decode(nvl(t.mar_boletinada, 'x'), 'A', 'A', 'U', 'U', NULL)
                 INTO v_recuperada, v_boletinada
                 FROM ta_tarjetas_tmp t
                WHERE t.nro_cuenta = c.nro_cuenta
                  AND nvl(t.relacion, 0) = 0
                  AND cod_ent_procesadora = c_bancard;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  BEGIN
                     SELECT decode(nvl(t.mar_recuperada, 'N'), 'R', 'S', 'N'),
                            decode(nvl(t.mar_boletinada, 'x'), 'A', 'A', 'U', 'U', NULL)
                       INTO v_recuperada, v_boletinada
                       FROM ta_tarjetas_tmp t
                      WHERE t.nro_cuenta = c.nro_cuenta
                        AND nvl(t.relacion, 0) = 0
                        AND cod_ent_procesadora = c_bancard;
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN no_data_found THEN
                        v_recuperada := NULL;
                        v_boletinada := NULL;
                     WHEN OTHERS THEN
                        pat_imp.pr_log('ITC-00025: Al buscar el estado de los plasticos para la cuenta 1: ' ||
                                       c.nro_cuenta);
                  END;
               WHEN TOO_MANY_ROWS THEN
                BEGIN
                 SELECT decode(nvl(t.mar_recuperada, 'N'), 'R', 'S', 'N'),
                      decode(nvl(t.mar_boletinada, 'x'), 'A', 'A', 'U', 'U', NULL)
                 INTO v_recuperada, v_boletinada
                 FROM ta_tarjetas_tmp t
                WHERE t.nro_cuenta = c.nro_cuenta
                  AND nvl(t.relacion, 0) = 0
                  AND cod_ent_procesadora = c_bancard
                  AND vigente='S';
                EXCEPTION
                 WHEN v_error THEN
                        RAISE v_error;
                     WHEN no_data_found THEN
                        v_recuperada := NULL;
                        v_boletinada := NULL;
                     WHEN OTHERS THEN
                        pat_imp.pr_log('ITC-00028: Al buscar el estado de los plasticos para la cuenta 1: ' ||
                                       c.nro_cuenta);
                 END;
               WHEN OTHERS THEN
                  pat_imp.pr_log('ITC-00026: Al buscar el estado de los plasticos para la cuenta 2: ' ||
                                 c.nro_cuenta);
            END;
            BEGIN
               IF nvl(v_can_marca, 0) > 0 AND nvl(v_can_tar_activa, 0) > 0 THEN
                  -- AP 2289
                  -- verificar si todas las tarjetas activas de la cuenta tienen marca
                  IF nvl(v_can_tar_activa, 0) = nvl(v_can_marca, 0) THEN
                     v_boletinada := 'A'; -- solo bloquear la cuenta si todas las tarjetas activas tienen marca
                  ELSE
                     v_boletinada := NULL;
                  END IF;
               ELSIF nvl(v_can_tar_activa, 0) = 0 THEN
                  -- Ninguna tarjeta activa
                  IF nvl(c.sal_facturar, 0) + nvl(c.sal_facturado, 0) + nvl(c.sal_financiado, 0) +
                     nvl(c.sal_cuo_pendientes, 0) = 0 THEN
                     v_boletinada := NULL; -- Saldo = 0
                  ELSE
                     v_boletinada := 'A'; -- Ninguna tarjeta activa pero saldo > 0 => Cta. Bloqueada
                  END IF;
               END IF;

               UPDATE ta_cta_tarjetas
                  SET mar_recuperado = v_recuperada,
                      mar_bloqueo    = v_boletinada,
                      estado         = decode(nvl(v_boletinada, 'x'), 'A', 'N', 'U', 'N', 'P', 'N',
                                              'C', 'N', 'M', 'N', estado) /*El Estado de la Cuenta debe permanecer en Normal si tiene algún Bloqueo*/
                WHERE nro_cuenta = to_char(to_number(c.nro_cuenta));
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  pat_imp.pr_log('ITC-00027: Al actualizar el estado de la cuenta ' ||
                                 c.nro_cuenta);
                  --          raise v_error;
            END;
         END IF;

         <<siguiente>>
         NULL;
      END LOOP;

      r_log.nro_error := NULL;
      r_log.men_error := NULL;
      r_log.comentario := NULL;
      v_nro_error := 3;
      v_men_error := 'INFO';

      /*  || Actualiza las tarjetas vigentes */
      pat_imp.pr_pro_set_vigente;
      r_log.nom_proceso := c_nom_proceso;
      /*  || Procesa los cobros de Bancard  */
      pat_imp.pr_ins_cobro_ban;
      r_log.nom_proceso := c_nom_proceso;
      /*  Inserta Cuentas para Debitos Automaticos a Cobrar */
      prt_ins_cta_deb_aut_cobrar;
      r_log.nom_proceso := c_nom_proceso;
      /*  || Guarda los cambios realizados  */
      COMMIT;


      -- HABILITAR TRIGGERS DE TARJETAS--
      -- sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      -- sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CUENTAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CUENTAS ENABLE', r_log.comentario);
      -- SDC AP 931
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_SAL_CIERRES ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_SAL_CIERRES ENABLE', r_log.comentario);



      pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||  ' ***');

   EXCEPTION
      WHEN v_error THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
           DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_stack);
           DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_backtrace);
            raise_application_error(-20271, r_log.comentario || ' ' || r_log.men_error);
         END IF;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
           DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_stack);
           DBMS_OUTPUT.put_line (DBMS_UTILITY.format_error_backtrace);
            raise_application_error(-20272, 'Error en el proceso de tarjetas Bancard. Cta:' || v_nro_cuenta || '-' || SQLERRM);
         END IF;
   END pr_pro_bancard;
  /*Importa el archivo de conciliaciones*/
   /*Se ejecuta a partir del  script Execute.sql*/
      PROCEDURE pr_imp_cta_tarjetas(p_nro_cuenta IN VARCHAR2 DEFAULT NULL) IS
      c_bancard     CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_BANCARD');
      c_nom_proceso CONSTANT VARCHAR2(30) := 'pat_imp.PR_IMP_CTA_TARJETAS';

      v_lin_credito_normal    NUMBER;
      v_lin_credito_cuotas    NUMBER;
      v_sal_a_facturar        NUMBER;
      v_sal_fact_no_vencido   NUMBER;
      v_sal_financiado        NUMBER;
      v_sal_cuotas            NUMBER;
      v_sal_ult_resumen       NUMBER;
      v_mto_pag_minimo        NUMBER;
      v_por_pag_minimo        NUMBER;
      v_sal_acu_pag_minimo    NUMBER;
      v_sal_pag_minimo        NUMBER;
      v_mto_mora              NUMBER;
      v_sal_acu_pag_mes       NUMBER;
      v_tip_tas_personalizada ta_sal_fin_tarjetas_tmp.tip_tas_int_personalizada%TYPE;
      v_tip_tas_financiacion  ta_sal_fin_tarjetas_tmp.tip_tas_financiacion%TYPE;
      v_cta_bancaria          ta_sal_fin_tarjetas_tmp.cta_bancaria%TYPE;
      v_tip_pago              ta_sal_fin_tarjetas_tmp.tip_pago%TYPE;
      v_tas_int_corriente     NUMBER;
      v_tas_int_moratorio     NUMBER;
      v_tas_int_compra        NUMBER;
      v_tas_int_cuota_compra  NUMBER;
      v_tas_int_punitorio     NUMBER;
      v_nro_documento         ta_personas_tmp.nro_documento%TYPE;
      v_fec_nacimiento        ta_personas_tmp.fec_nacimiento%TYPE;
      v_cod_sexo              ta_personas_tmp.cod_sexo%TYPE;
      v_cta_tmp_ini          NUMBER;
      v_tar_tmp_ini           NUMBER;
      v_cta_tmp_fin           NUMBER;
      v_tar_tmp_fin           NUMBER;
      v_ind                   NUMBER;
      v_nro_error             NUMBER := 3;
      v_men_error             VARCHAR(500) := 'INFO';
      v_error EXCEPTION;
      i DATE;
      x NUMBER;

      --
      CURSOR cuentas IS
         SELECT nro_cuenta,
                denominacion,
                cod_entidad,
                cod_afinidad,
                cod_marca,
                cod_pro_marca,
                tip_cuenta,
                cod_persona,
                cod_pais,
                cod_departamento,
                cod_ciudad,
                telefono,
                decode(cod_oficina,0,1, cod_oficina)cod_oficina,
                oficial,
                tip_costo,
                vip,
                franqueo,
                ret_extracto,
                tip_cierre,
                sit_cuenta,
                dia_mora,
                fec_ult_vencimiento,
                fec_ult_cierre,
                tip_documento,
                nro_documento,
                ruc,
                cob_costo,
                mot_ret_extracto,
                --ind_seg_vida,--bancard ueno no existe en bankitti
                calificacion_bcp,
                reservado,
                fec_sit_cuenta,
                observacion,
                dir_correo,
                mot_novedad,
                mot_entidad,
                fec_ult_transaccion,
                fec_pri_compra,
                fec_ult_pago,
                fec_ingreso
                --car_no_aplicar
           FROM ta_cuentas_tmp c
           WHERE c.nro_cuenta IS NOT NULL /*c.nro_cuenta = nvl(p_nro_cuenta, c.nro_cuenta)--*/
            AND ((c.sit_cuenta  IN ('I','B') AND c.fec_actualizacion >= SYSDATE -7) OR  c.sit_cuenta = 'A')
      AND exists (select 1 from ta_tipos a
                                where trim(a.afinidad) in ('114','131','132','138','139','140','174','181')
                                  and trim(a.afinidad) = trim(c.cod_afinidad))
            AND c.nro_cuenta <> 108121030
        ORDER BY nro_cuenta;

      CURSOR tarjetas(p_nro_cuenta VARCHAR2) IS
         SELECT nro_tarjeta,
                denominacion,
                cod_entidad,
                cod_afinidad,
                cod_marca,
                cod_pro_marca,
                nro_cuenta,
                cod_persona,
                nro_documento,
                tip_tarjeta,
                nom_plastico,
                fec_desde,
                duracion,
                fec_hasta,
                fec_embozado,
                personalizada,
                renovar,
                tip_plastico,
                tip_documento,
                nom_banda,
                fec_recibo,
                fec_embozado2,
                fec_pin,
                fec_emision,
                tip_ult_embozado,
                t.cob_seguro,
                recuperada,
                vencida,
                tip_bloqueo,
                sit_tarjeta,
                reservado,
                fec_sit_tarjeta
           FROM ta_tar_cuentas_tmp t
          WHERE nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
          ORDER BY nro_cuenta, tip_tarjeta, nro_tarjeta;
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 5;
      END;
      i := SYSDATE;
      --- Inicializacion  de variables ---
      g_secuencia := 0;

      g_hor_movim := to_char(SYSDATE, 'HH24:MI:SS');
      --RI:15/10/2010: Obtener sigte. segundo
      g_hor_movim := pag_gen.fu_obt_sig_segundo(g_hor_movim);
      --truncar log
      --
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
       pat_imp.pr_ins_log_inf(v_nro_error , v_men_error ,'*** Iniciando el proceso a las ' || to_char(i, 'HH24:MI:SS') || ' ***');
       g_nro_reg := 0;

      ---------------
      ---OJO : Se supone que el job ejecuta antes el truncate de las tablas temporales
      ---------------------

     /************************************* SECCION DE AUDITORIA / LOGGEO DE TABLAS TEMPORALES *********************************/
      BEGIN
        FOR a IN (
                SELECT c.nro_cuenta,
                       CASE WHEN c.nro_cuenta IS NULL THEN 'NULL_ACCOUNT_NUMBER' END AS men_error,
                        CASE WHEN c.nro_cuenta IS NULL  THEN 2
                             END AS nro_error
                FROM ta_cuentas_tmp c
                WHERE c.nro_cuenta IS NULL
                AND  exists (select 1 from ta_tipos a
                                where trim(a.afinidad) in ('114','131','132','138','139','140','174')
                                  and trim(a.afinidad) = trim(c.cod_afinidad))
                AND c.nro_cuenta <> 108121030
                ORDER BY nro_cuenta
        ) LOOP

                  v_nro_error := a.nro_error;
                  v_men_error := a.men_error;

            IF v_nro_error IS NOT NULL AND v_men_error IS NOT NULL
            THEN

              pat_imp.pr_ins_log_inf( v_nro_error , v_men_error , 'No se obtuvieron datos para la cuenta ' || a.nro_cuenta ||  ' en el cursor CUENTAS - recorrido temporal ta_cuentas_tmp. Motivo ' || a.men_error );

            END IF;
          END LOOP;
      END ;

      /************************************* SECCION DE CARGA DE TABLAS TEMPORALES *************************************/
      FOR c IN cuentas LOOP
         g_nro_reg := nvl(g_nro_reg, 0) + 1;
         -----
         IF round(g_nro_reg / 1000) = g_nro_reg / 1000 THEN
            x := (SYSDATE - i) * 24 * 60;
            dbms_output.put_line('Registro: ' || lpad(to_char(g_nro_reg, '999G999G999'), 12, ' ') ||
                                 '; Tiempo transcurrido: ' || to_char(floor(x), '999') || ':' ||
                                 lpad(to_char(round((x - floor(x)) * 60, 2)), 2, '0'));
         END IF;
         ----

         --Busca Lineas de Credito
         v_lin_credito_normal := 0;
         v_lin_credito_cuotas := 0;
         --
         DECLARE
            CURSOR c_lineas IS
               SELECT cod_tip_lin_credito, mto_lin_credito
                 FROM ta_cta_lin_tarjetas_tmp
                WHERE nro_cuenta = c.nro_cuenta;
         BEGIN
            FOR x IN c_lineas LOOP
               IF x.cod_tip_lin_credito = 1 THEN
                  --normal
                  v_lin_credito_normal := x.mto_lin_credito;
               ELSIF x.cod_tip_lin_credito = 2 THEN
                  --cuotas
                  v_lin_credito_cuotas := x.mto_lin_credito;
               END IF;
            END LOOP;
         END;

         --Buscar Saldos
         v_sal_a_facturar      := 0;
         v_sal_fact_no_vencido := 0;
         v_sal_financiado      := 0;
         v_sal_cuotas          := 0;
         --
         DECLARE
            CURSOR c_saldos IS
               SELECT cod_tip_saldo, mto_saldo
                 FROM ta_cta_sal_tarjetas_tmp
                WHERE nro_cuenta = c.nro_cuenta;
         BEGIN
            FOR x IN c_saldos LOOP
               IF x.cod_tip_saldo = 1 THEN
                  --Saldo A facturar
                  v_sal_a_facturar := x.mto_saldo;
               ELSIF x.cod_tip_saldo = 2 THEN
                  --Saldo Fact. no vencido
                  v_sal_fact_no_vencido := x.mto_saldo;
               ELSIF x.cod_tip_saldo = 3 THEN
                  --Saldo Financiado
                  v_sal_financiado := x.mto_saldo;
               ELSIF x.cod_tip_saldo = 4 THEN
                  --Saldo en cuotas/planes
                  v_sal_cuotas := x.mto_saldo;
               END IF;
            END LOOP;
         END;
         --
         --Buscar datos financieros
         BEGIN
            SELECT s.sal_ult_resumen,
                   s.pag_minimo,
                   s.por_pag_minimo,
                   s.pag_min_facturado,
                   s.mora,
                   s.sal_acu_pag_mes,
                   s.tip_tas_int_personalizada,
                   s.tip_tas_financiacion,
                   s.cta_bancaria,
                   s.tip_pago,
                   case when nvl(s.pag_min_facturado,0)-nvl(s.sal_acu_pag_mes,0) < 0 then
                     0
                   else
                      nvl(s.pag_min_facturado,0)-nvl(s.sal_acu_pag_mes,0)
                   end
              INTO v_sal_ult_resumen,
                   v_mto_pag_minimo,
                   v_por_pag_minimo,
                   v_sal_acu_pag_minimo,
                   v_mto_mora,
                   v_sal_acu_pag_mes,
                   v_tip_tas_personalizada,
                   v_tip_tas_financiacion,
                   v_cta_bancaria,
                   v_tip_pago,
                   v_sal_pag_minimo
              FROM ta_sal_fin_tarjetas_tmp s
             WHERE s.nro_cuenta = c.nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               v_sal_ult_resumen       := 0;
               v_mto_pag_minimo        := 0;
               v_por_pag_minimo        := 0;
               v_sal_acu_pag_minimo    := 0;
               v_mto_mora              := 0;
               v_sal_acu_pag_mes       := 0;
               v_sal_pag_minimo        := 0;
               v_tip_tas_personalizada := NULL;
               v_tip_tas_financiacion  := NULL;
               v_cta_bancaria          := NULL;
               v_tip_pago              := NULL;
         END;
         --
         --Buscar datos de Tasas
         --Buscar Saldos
         v_tas_int_corriente    := 0;
         v_tas_int_moratorio    := 0;
         v_tas_int_compra       := 0;
         v_tas_int_cuota_compra := 0;
         v_tas_int_punitorio    := 0;
         v_ind                  := 0;
         --
         DECLARE
            CURSOR c_tas_personalizada IS
               SELECT t.tip_tas_interes, t.val_tasa
                 FROM ta_int_per_tarjetas_tmp t
                WHERE t.nro_cuenta = c.nro_cuenta;
         BEGIN
            FOR x IN c_tas_personalizada LOOP
               v_ind := 1;
               IF x.tip_tas_interes = 1 THEN
                  --Interes Corriente
                  v_tas_int_corriente := x.val_tasa;
               ELSIF x.tip_tas_interes = 2 THEN
                  --Moratorio
                  v_tas_int_moratorio := x.val_tasa;
               ELSIF x.tip_tas_interes = 3 THEN
                  --Compra
                  v_tas_int_compra := x.val_tasa;
               ELSIF x.tip_tas_interes = 4 THEN
                  --Cuota Compra
                  v_tas_int_cuota_compra := x.val_tasa;
               ELSIF x.tip_tas_interes = 6 THEN
                  --Punitorio
                  v_tas_int_punitorio := x.val_tasa;
               END IF;
            END LOOP;
         END;
         --- Si No hay Tasa Personalizada por Cuenta buscar por Afinidad
         DECLARE
            CURSOR c_tasas IS
               SELECT i.cod_tip_tas_interes, i.val_tasa
                 FROM ta_tas_int_tarjetas_tmp i
                WHERE i.cod_afinidad = c.cod_afinidad
                  AND i.tip_tas_financiacion = c.tip_costo;
         BEGIN
            FOR x IN c_tasas LOOP
               v_ind := 1;
               IF x.cod_tip_tas_interes = 1 THEN
                  --Interes Corriente
                  v_tas_int_corriente := x.val_tasa;
               ELSIF x.cod_tip_tas_interes = 2 THEN
                  --Moratorio
                  v_tas_int_moratorio := x.val_tasa;
               ELSIF x.cod_tip_tas_interes = 3 THEN
                  --Compra
                  v_tas_int_compra := x.val_tasa;
               ELSIF x.cod_tip_tas_interes = 4 THEN
                  --Cuota Compra
                  v_tas_int_cuota_compra := x.val_tasa;
               ELSIF x.cod_tip_tas_interes = 5 THEN
                  --Punitorio
                  v_tas_int_punitorio := x.val_tasa;
               END IF;
            END LOOP;
         END;
         --Inserta datos en la tabla TA_CTA_TARJETAS
         BEGIN
            INSERT INTO ta_cta_tarjetas_tmp
               (cod_afinidad, nro_cuenta, sit_cuenta, denominacion, cod_sucursal, nro_cta_debito,
                lin_credito, sal_ult_extracto, sal_facturar, sal_facturado, sal_financiado,
                mto_pag_minimo, mto_mora, dia_mora, sal_pag_minimo, mto_pag_mes, deb_automatico,
                tip_cobro, fec_ult_pago, fec_ult_compra, fec_ult_operacion, fec_ult_extracto,
                fec_apertura, mar_mora, mar_excedido, tas_financiacion, tas_mora, por_pag_minimo,
                tip_cierre, lin_cuotas, sal_cuo_pendientes, cod_usu_ente, tip_tas_financiacion,
                tip_com_emision, fec_ult_cierre, fec_vct_ult_cierre, mto_autorizaciones, tas_cuotas,
                nro_reg, cod_ent_procesadora, cod_oficina/*, franqueo, ind_seg_vida, car_no_aplicar*/

                )
            VALUES
               (c.cod_afinidad, TRIM(c.nro_cuenta), decode(c.sit_cuenta, 'B', 3, 'I', 2, 1),
                -- 1- Activa - 2- Inactiva - 3 Baja
                TRIM(c.denominacion), c.cod_oficina, lpad(substr(v_cta_bancaria, -7), 11, '0'),
                TRIM(v_lin_credito_normal), v_sal_ult_resumen,
                --SAL ULT EXTRACTO
                v_sal_a_facturar, v_sal_fact_no_vencido, v_sal_financiado, v_mto_pag_minimo,
                v_mto_mora, c.dia_mora, v_sal_pag_minimo, v_sal_acu_pag_mes,
                decode(nvl(v_cta_bancaria, 0), 0, 0, 1), decode(v_tip_pago, 'M', 1, 2),
                --- 1 Minimo 2, Total
                c.fec_ult_pago, NULL,
                --fec_ult_compra
                c.fec_ult_transaccion, c.fec_ult_vencimiento, c.fec_ingreso,
                decode(nvl(v_mto_mora, 0), 0, NULL, 'M'),
                --M= en mora
                NULL,
                --mar_excedido,
                v_tas_int_corriente,
                --tas_financiacion,
                v_tas_int_moratorio, TRIM(v_por_pag_minimo), c.tip_cierre,
                --Cierre General
                v_lin_credito_cuotas, v_sal_cuotas, NULL,
                --cod_usu_ente,
                decode(v_tip_tas_financiacion, 'N', 1, 0),
                --- 0 Preferente 1 Normal
                1,
                --- 0 Preferente, 1 Normal, 2 Sin Costo
                c.fec_ult_cierre,
                decode(c.fec_ult_vencimiento, to_date('01011901', 'ddmmyyyy'), NULL,
                        c.fec_ult_vencimiento), /*Por defecto trae la fecha 01/01/1901*/ NULL,
                --mto_autorizaciones,
                v_tas_int_cuota_compra,
                --tas_cuotas,
                g_nro_reg, c_bancard, c.cod_oficina/*, c.franqueo, c.ind_seg_vida, c.car_no_aplicar*/);

         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN

                  v_nro_error := 1;
                  v_men_error   := 'INSERT_TEMPORAL_ACCOUNT_ERROR';

               pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'No fue posible insertar registro de la cuenta ' || c.nro_cuenta ||
                              ' en la tabla ta_cta_tarjetas_tmp . Error : ' || SQLERRM);

         END;
         /*************************************** SECCION DE PROCESOS DE TARJETAS ***************************************/
         FOR t IN tarjetas(c.nro_cuenta) LOOP
            --Buscar datos de personas. FARASOP-226. Se cambia aqui la sentencia para haga por tarjeta y no por cuenta. Ya que estos datos no se utilizan en la cuenta.
            BEGIN
               SELECT TRIM(p.nro_documento), p.fec_nacimiento, p.cod_sexo
                 INTO v_nro_documento, v_fec_nacimiento, v_cod_sexo
                 FROM ta_personas_tmp p
                WHERE trim(p.cod_persona) = t.cod_persona;
            EXCEPTION
         WHEN OTHERS THEN
                  v_nro_documento  := NULL;
                  v_fec_nacimiento := NULL;
                  v_cod_sexo       := NULL;
                  v_nro_error      := 2;
                  v_men_error      := 'DOC_NUMBER_NOT_FOUND';

                  pat_imp.pr_ins_log_inf(v_nro_error,v_men_error,'No se obtuvo un nro de documento para el cod_persona '  || t.cod_persona ||
                                 ' de la cuenta ' || c.nro_cuenta || ' Error : ' || SQLERRM);

            END;
            BEGIN
               INSERT INTO ta_tarjetas_tmp
                  (cod_afinidad, nro_tarjeta, dig_verificador, relacion, cod_situacion, nom_embozar,
                   nro_cuenta, nro_documento, dur_meses, fec_emision, fec_entrega, mes_vencimiento,
                   mar_boletinada, mar_recuperada, mar_vencida, tip_bloqueo, renovar, fec_nacimiento,
                   cod_est_civil, cod_sexo, nro_reg, cod_ent_procesadora, cod_oficina, vigente)
               VALUES
                  (t.cod_afinidad, TRIM(t.nro_tarjeta), NULL,
                   --t.dig_verificador,
                   decode(t.tip_tarjeta, 'P', 0, 1),
                   --P=Principal A=Adicional
                   decode(t.sit_tarjeta, 'B', 3, 'I', 2, 1),
                   --1- Activa - 2-Inactiva - 3 Baja
                   TRIM(t.nom_plastico),
                   -- Se utilizará  el nombre del Plastico en vez del nombre de la Banda
                   TRIM(t.nro_cuenta), TRIM(v_nro_documento), t.duracion, t.fec_emision,
                   decode(t.sit_tarjeta, 'A', t.fec_sit_tarjeta, NULL),
                   -- Si es A= Alta debe insertarse como fecha activacion
                   to_char(t.fec_hasta, 'MMYY'), t.tip_bloqueo,
                   -- U Bloqueo Usuario A Administrador
                   decode(t.recuperada, 'S', 'R', NULL),
                   --R Recuperada
                   decode(t.vencida, 'S', 'V', NULL),
                   --V Vencida
                   t.tip_bloqueo, t.renovar, v_fec_nacimiento, NULL,
                   --cod_est_civil,
                   v_cod_sexo, g_nro_reg, c_bancard, c.cod_oficina,
                   decode(t.sit_tarjeta, 'I', 'N', 'B', 'N', 'S')); --Dejar en Estado No Vigentes las Tarjetas con estado Inactiva (I)
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN

                  v_nro_error := 1;
                  v_men_error := 'INSERT_TEMPORAL_CARD_ERROR';

               pat_imp.pr_ins_log_inf(v_nro_error,v_men_error, 'No fue posible insertar registro de la cuenta ' || c.nro_cuenta ||
                              ' en la tabla ta_tarjetas_tmp . Error : ' || SQLERRM);

                  --RAISE_APPLICATION_ERROR( -20000,'Error: '||sqlerrm);
            END;
         END LOOP;
      END LOOP;

        /* Calculo cantidad de registros en temporales iniciales y secundarias */


          SELECT COUNT (*) INTO v_cta_tmp_ini FROM ta_cuentas_tmp;
          SELECT COUNT (*) INTO v_tar_tmp_ini FROM ta_tar_cuentas_tmp;

          SELECT COUNT (*) INTO v_cta_tmp_fin FROM ta_cta_tarjetas_tmp;
          SELECT COUNT (*) INTO v_tar_tmp_fin FROM ta_tarjetas_tmp;

        -- DECLARO VARIABLES DE INFORMACIÓN

                  v_nro_error := 3;
                  v_men_error := 'INFO';


        pat_imp.pr_ins_log_inf(v_nro_error,v_men_error, '*** Se insertaron ' || v_cta_tmp_fin||
                     ' registros en la temporal ta_cta_tarjetas_tmp de '|| v_cta_tmp_ini || ' registros recibidos de ta_cuentas_tmp. Se insertaron '|| v_tar_tmp_fin ||
                     ' tarjetas en la tabla ta_tarjetas_tmp de '|| v_tar_tmp_ini || ' registros recibidos de ta_tar_cuentas_tmp');


      pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||  ' ***');


   EXCEPTION
      WHEN v_error THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20271, r_log.comentario || ' ' || r_log.men_error);
         END IF;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20272,
                                    'Error en el proceso de importacion de Tablas Temporales Bancard ' ||
                                     SQLERRM);
         END IF;
   END pr_imp_cta_tarjetas;

   /* */
   PROCEDURE pr_ins_cobro_ban IS
      c_bancard     CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_BANCARD');
      c_nom_proceso CONSTANT VARCHAR2(30) := 'pat_imp.PR_INS_COBRO_BAN';
      v_hora ta_movimientos_his.hora%TYPE;
      v_error EXCEPTION;
      --
      CURSOR cobros IS
         SELECT t.nro_cuenta,
                t.nro_tarjeta,
                t.fec_proceso,
                t.monto,
                t.estado,
                t.fec_valor,
                t.est_envio,
                t.dia_mora,
                t.nro_reg,
                j.cod_modulo,
                t.cod_modalidad,
                j.cod_moneda,
                j.cod_oficina
           FROM ta_cobros_tmp t, ta_cta_tarjetas j
          WHERE t.nro_cuenta = j.nro_cuenta
            AND cod_ent_procesadora = c_bancard
            AND NOT EXISTS (SELECT 1
                   FROM ta_cobros c
                  WHERE c.nro_cuenta = t.nro_cuenta
                    AND c.nro_tarjeta = t.nro_tarjeta
                    AND c.fec_proceso = t.fec_proceso
                    AND c.monto = t.monto)
          ORDER BY t.nro_reg;
      --
   BEGIN
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_log('*** Iniciando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') || ' ***',
                     FALSE);
      v_hora := '00:00:00';
      BEGIN
         UPDATE ta_cobros_tmp a
            SET (a.nro_cuenta, a.cod_modalidad) =
                (SELECT b.nro_cuenta, b.cod_modalidad
                   FROM ta_tarjetas_tmp b
                  WHERE b.nro_tarjeta = a.nro_tarjeta)
          WHERE nvl(a.nro_cuenta, 0) = 0
            AND a.nro_tarjeta > 0
            AND cod_ent_procesadora = c_bancard;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            pat_imp.pr_log('Al actualizar el numero de cuenta para la tarjeta.' || SQLERRM);
            --
            RAISE v_error;
      END;
      FOR c IN cobros LOOP
         v_hora    := pag_gen.fu_obt_sig_segundo(v_hora);
         g_nro_reg := c.nro_reg;
         BEGIN
            INSERT INTO ta_cobros
               (nro_cuenta, nro_tarjeta, fec_proceso, monto, estado, fec_valor, observacion,
                est_envio, hora, cod_usuario, dia_mora)
            VALUES
               (c.nro_cuenta, c.nro_tarjeta, c.fec_proceso, c.monto, 'P', c.fec_valor,
                'COBRADO POR LA RED', 'E', v_hora, substr(USER, 1, 10), c.dia_mora);
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('Al insertar el pago de la cuenta ' || c.nro_cuenta || '. ' ||
                              SQLERRM);
               --
               RAISE v_error;
         END;
         /*
         || Inserta los movimientos historicos de tarjetas.
         || Este parte del proceso estaba implementado en Atlas, y se migro la logica del procedimiento
         || tal cual como estaba implementado.
         */
         BEGIN
            INSERT INTO ta_movimientos_his
               (fecha, hora, cod_usuario, nro_secuencia, monto, nro_cuenta, cod_moneda, cod_oficina,
                estado, cod_ofi_origen, concepto, reversado, cod_tra_padre, cod_mod_padre,
                cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad)
            VALUES
               (c.fec_proceso, v_hora, substr(USER, 1, 10), 1, c.monto, c.nro_cuenta, c.cod_moneda,
                c.cod_oficina, 'N', c.cod_oficina, 'COBRADO POR LA RED', 'N', 250, 9, 91, 690,
                c.cod_modulo, c.cod_modalidad);
         EXCEPTION
            WHEN OTHERS THEN
               pat_imp.pr_log('Al insertar el movimiento historico para la cuenta ' ||
                              c.nro_cuenta || '. ' || SQLERRM);
               --
               RAISE v_error;
         END;
      END LOOP;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN v_error THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20271, r_log.comentario || ' ' || r_log.men_error);
         END IF;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20272,
                                    'Error en el proceso de cobros de tarjetas Bancard ' || SQLERRM);
         END IF;
   END pr_ins_cobro_ban;
   /* */
   PROCEDURE pr_pro_procard IS
      c_fec_actual      CONSTANT DATE := pag_cal.fu_obt_fec_actual(5);
      c_fec_min_proceso CONSTANT DATE := to_date('01/01/1901', 'DD/MM/YYYY');
      c_cod_mon_local   CONSTANT VARCHAR2(3) := pag_gen.fu_obt_mon_local;
      c_procard         CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_PROCARD');
      c_nom_proceso     CONSTANT VARCHAR2(30) := 'pat_imp.PR_PRO_PROCARD';
      v_oficina       NUMBER(3);
      v_cod_tip_doc   NUMBER(3);
      v_cod_tip_ruc   NUMBER(3);
      v_cod_tip_crc   NUMBER(3);
      v_cod_tip_cie   NUMBER(3);
      v_nro_solicitud NUMBER(8);
      v_est_tarjeta   NUMBER(2);
      v_est_anterior  NUMBER(2);
      v_ofi_matriz    NUMBER(3);
      v_cod_tip_pas   NUMBER;
      v_cod_tip_dni   NUMBER;
      v_cod_tip_cad   NUMBER;

      v_fec_solicitud   DATE;
      v_fec_ven_tarjeta DATE;
      v_fec_cierre      DATE;

      v_existe             VARCHAR2(1);
      v_per_principal      VARCHAR2(10);
      v_nom_principal      VARCHAR2(200);
      v_estado             VARCHAR2(1);
      v_con_costo          VARCHAR2(1);
      v_tip_com_emision    VARCHAR2(1);
      v_cod_afinidad       VARCHAR2(10);
      v_nro_cta_debito_sol VARCHAR2(15);
      v_sub_afinidad       VARCHAR2(2);
      v_mar_excedido       VARCHAR2(1);
      v_nro_cta_debito     VARCHAR2(15);
      v_mar_mora           VARCHAR2(1);
      v_existe_tarjeta     VARCHAR2(1);
      v_persona            VARCHAR2(10);
      v_tip_persona        VARCHAR2(1);
      v_nom_embozar        VARCHAR2(50);
      v_tip_cobro          VARCHAR2(2);
      v_relacion           VARCHAR2(1);
      v_recuperada         VARCHAR2(1);
      v_bloqueada          VARCHAR2(1);
      v_cod_usuario        VARCHAR2(10);
      v_nom_completo       VARCHAR2(200);
      v_nro_cuenta         VARCHAR2(15);
      v_es_innominada      VARCHAR2(1);
      v_es_cliente         VARCHAR2(1);
      --
      v_fec_ult_pago      ta_cta_tarjetas.fec_ult_pago%TYPE;
      v_fec_ult_compra    ta_cta_tarjetas.fec_ult_compra%TYPE;
      v_fec_ult_ope       ta_cta_tarjetas.fec_ult_operacion%TYPE;
      v_fec_vct_ult_cie   ta_cta_tarjetas.fec_vct_ult_cierre%TYPE;
      v_fec_ult_extracto  ta_cta_tarjetas.fec_ult_extracto%TYPE;
      v_cod_rub_economico ta_solicitudes.cod_rub_economico%TYPE;
      v_referencia        ta_tarjetas.referencia%TYPE;
      v_tip_envio         ta_tarjetas.tip_envio%TYPE;
      r_ctapro            ta_cta_tarjetas_pro_tmp%ROWTYPE;
      v_ok                BOOLEAN;
      --
      v_error EXCEPTION;
      --
      CURSOR cuentas IS
         SELECT nro_cuenta,
                nro_tarjeta,
                nro_tar_principal,
                tip_tarjeta,
                nom_embozar,
                cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_moneda,
                direccion,
                /*nvl(otr_documento,*/ nro_documento nro_documento,
               --- nro_documento,
                nro_ruc,
                telefono,
                des_ciudad,
                nacionalidad,
                fec_nacimiento,
                est_civil,
                cod_sexo,
                sucursal cod_sucursal,
                cod_ret_corresp,
                fec_emi_plastico,
                fec_ven_plastico,
                for_pago,
                cod_usu_promotor,
                lin_credito,
                lin_especial,
                sal_facturar,
                sal_facturado,
                sal_financiado,
                mto_mora,
                dia_mora,
                mar_mora,
                mto_pag_minimo,
               -- nvl(fec_ult_cierre, pat_imp.fu_obt_fec_cierre(c_procard, cod_modalidad)) fec_ult_cierre,
               -- nvl(fec_vct_ult_cierre, pat_imp.fu_obt_fec_vencim(c_procard, cod_modalidad)) fec_vct_ult_cierre,
                ---nvl(fec_ult_cierre, pat_imp.fu_obt_fec_cierre(c_procard, null, decode(tip_cierre,0,4, tip_cierre))) fec_ult_cierre,--,bancard ueno no existe en bankitti
                nvl(fec_vct_ult_cierre, pat_imp.fu_obt_fec_vencim(c_procard, null, decode(tip_cierre, 0, 4,tip_cierre))) fec_vct_ult_cierre,
                mar_recuperado,
                mar_vencida,
                mar_excedido,
                mar_bloqueo,
                mar_activa,
                mar_inhabilitada,
                fec_ult_compra,
                fec_ult_operacion,
                decode (to_char(f.fec_ult_pago,'dd/mm/yyyy'),'01/01/2001',(pat_imp.fu_obt_fec_vencim(c_procard, null,decode(tip_cierre,0,4, tip_cierre))+1), f.fec_ult_pago) fec_ult_pago,
               -- fec_ult_pago,
                nvl(mto_pag_mes, 0) mto_pag_mes,
                nvl(abs(mto_ult_pago), 0) mto_ult_pago,
                cod_afinidad cla_tarjeta,
                decode(tip_cierre,0,4, tip_cierre)tip_cierre,
                sal_cuo_pendientes,
                mto_pen_amortizaciones,
                sal_cuo_pen_refin,
                sal_ade_disponible,
                mto_autorizaciones,
                mto_aut_cuotas,
                mto_car_suspendido,
                mto_car_sus_aplicado,
                mto_ult_cierre,
                tas_efectiva,
                tas_nominal,
                tas_financiacion,
                tas_mora,
                tas_cuotas,
                tas_compras,
                por_pag_minimo,
                tip_com_emision,
                fec_ven_extracto,
                con_costo,
                fec_archivo,
                nro_reg,
                cod_usu_ente,
                fec_activacion,
                cod_ent_procesadora,
                nro_cta_debito,
                substr(nro_tarjeta, 1,
                       fug_obt_pardinamico('NRO_BIN_LONGITUD', 5, f.cod_modalidad, NULL, NULL)) nro_bin,
                fec_generacion,
                pag_min_facturado,
                rtrim(ltrim(f.sal_pag_minimo)) sal_pag_minimo,
                --tas_especial,--,bancard ueno no existe en bankitti
                f.lin_cuotas

           FROM ta_cta_tarjetas_pro_tmp f
          WHERE abs(cod_ent_procesadora) = c_procard
            and /*nvl(otr_documento,*/ nro_documento is not null--,bancard ueno no existe en bankitti
            AND nro_cuenta > 0
            AND 0 <>
                (SELECT COUNT(*)
                   FROM ta_tipos a
                  WHERE a.nro_bin =
                        substr(nro_tarjeta, 1,
                               fug_obt_pardinamico('NRO_BIN_LONGITUD', 5, f.cod_modalidad, NULL, NULL)))
          ORDER BY cod_ent_procesadora DESC,
                   nro_tar_principal,
                   decode(nro_tarjeta, nro_tar_principal, 0, 1),
                   tip_tarjeta;

  -- cursor de clientes especiales
     CURSOR tar_cli_especiales IS-- debe estar parametrizado--
        SELECT nro_cuenta,
               cod_modalidad,
               cod_modulo,
               cod_afinidad,
               nro_cta_alternativo,
               nro_documento,
               nro_tarjeta
          FROM ta_cta_clientes_pro_tmp
         WHERE nro_cuenta > 0
           AND nro_tarjeta > 0
           AND cod_ent_procesadora = c_procard;
      --
      i                   DATE;
      x                   NUMBER;
      v_nro_doc_principal ba_personas.nro_documento%TYPE;
      v_pri_adicional     ba_personas.nro_documento%TYPE;
      v_nro_doc_adicional ba_personas.nro_documento%TYPE;
      v_nom_usuario       ta_cta_tarjetas_pro_tmp.nom_embozar%TYPE;
      v_es_juridica       VARCHAR2(01);
      v_nro_cta_original  ge_cta_clientes.nro_cuenta%type;
      v_nro_cta_alternativo  ge_cta_clientes.nro_cuenta%type;

   BEGIN
      i := SYSDATE;
      --- Inicializacion  de variables ---
      g_secuencia       := 0;
      g_hor_movim       := to_char(SYSDATE, 'HH24:MI:SS');
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_log('*** Iniciando el proceso a las ' || to_char(i, 'HH24:MI:SS') || ' ***', FALSE);
      g_nro_reg := 0;
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;

      BEGIN
         UPDATE ta_cta_tarjetas_pro_tmp a
            SET (a.cod_modulo, a.cod_modalidad) =
                (SELECT b.cod_modulo, b.cod_modalidad
                   FROM ta_tipos b
                  WHERE b.nro_bin =
                        substr(a.nro_tarjeta, 1,
                               fug_obt_pardinamico('NRO_BIN_LONGITUD', 5, b.cod_modalidad, NULL, NULL))
                                AND abs(b.cod_ent_procesadora) = c_procard)
          WHERE a.nro_cuenta >= 0
            AND a.nro_tarjeta > 0
            AND abs(a.cod_ent_procesadora) = c_procard;

      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            pat_imp.pr_log('Al actualizar el numero de cuenta para la tarjeta.' || SQLERRM);
      END;

      -- Actualiza nro de cuenta alternativo parametrizado--
      -- se parametriza la cuenta más nueva
         FOR p IN tar_cli_especiales LOOP
            BEGIN
               UPDATE ta_cta_tarjetas_pro_tmp
                  SET nro_cuenta    = p.nro_cta_alternativo--,bancard ueno no existe en bankitti
                     -- nro_cta_original = p.nro_cuenta
                WHERE nro_cuenta = p.nro_cuenta
                  and cod_afinidad = p.cod_afinidad
                  and nro_tarjeta  = p.nro_tarjeta
                  and nro_documento = p.nro_documento
                  AND cod_ent_procesadora = c_procard;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  pat_imp.pr_log('ITC-00003: Al actualizar el numero de cuenta Alternativo. ');
            END;
         END LOOP;

      BEGIN
         SELECT cod_ofi_matriz INTO v_ofi_matriz FROM ge_par_generales;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            pat_imp.pr_log('ITC-00003: Al buscar la oficina matriz. ' || SQLERRM);
      END;
      -- Busca el codigo de documento para Cedula de Identidad y RUC
      pat_imp.pr_obt_documentos(v_cod_tip_doc, v_cod_tip_ruc, v_cod_tip_pas, v_cod_tip_dni,
                                v_cod_tip_cad, v_cod_tip_crc, v_cod_tip_cie);
      --Deshabilitar TRIGGERS DE AUDITORIA --
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CUENTAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CUENTAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_GE_CTA_CLIENTES DISABLE', r_log.comentario);
      /************************************* SECCION DE CARGA DE TABLAS TEMPORALES *************************************/
      FOR c IN cuentas LOOP
         --limpiar variables
         v_es_cliente          := NULL;
         v_nro_doc_principal   := NULL;
         v_pri_adicional       := NULL;
         v_per_principal       := NULL;
         v_persona             := NULL;
         v_nom_principal       := NULL;
         v_nom_usuario         := NULL;
         v_nro_doc_adicional   := NULL;
         r_ctapro.lin_credito  := 0;
         r_ctapro.lin_cuotas   := 0;
         r_ctapro.lin_especial := 0;
         --r_ctapro.sal_facturar := 0;
         r_ctapro.sal_facturado     := 0;
         r_ctapro.sal_financiado    := 0;
         r_ctapro.mto_ult_cierre    := 0;
         r_ctapro.sal_cuo_pen_refin := 0;
         --r_ctapro.mto_pen_amortizaciones := 0;
         r_ctapro.pag_min_facturado    := 0;
         r_ctapro.mto_pag_minimo       := 0;
         r_ctapro.mto_mora             := 0;
         r_ctapro.mto_autorizaciones   := 0;
         r_ctapro.mto_ult_pago         := 0;
         r_ctapro.mto_car_suspendido   := 0;
         r_ctapro.mto_car_sus_aplicado := 0;
         --r_ctapro.tas_especial         := NULL; bancard ueno no existe en bankitti
         r_ctapro.dia_mora             := NULL;
         r_ctapro.fec_generacion       := NULL;
         r_ctapro.fec_emi_plastico     := NULL;
         r_ctapro.fec_ult_pago         := NULL;
         r_ctapro.fec_ult_compra       := NULL;
         r_ctapro.fec_ult_operacion    := NULL;
         r_ctapro.fec_vct_ult_cierre   := NULL;
         r_ctapro.fec_ven_extracto     := NULL;
         --r_ctapro.fec_ult_cierre       := NULL; bancard ueno no existe en bankitti
         r_ctapro.tas_financiacion     := NULL;
         r_ctapro.tas_nominal          := NULL;
         r_ctapro.tas_mora             := NULL;
         r_ctapro.tas_cuotas           := NULL;
         r_ctapro.por_pag_minimo       := NULL;
         v_es_juridica                 := 'N';
         IF instr(',' || fug_obt_pardinamico('TAR_INNOMINADAS') || ',', ',' || c.nom_embozar || ',') > 0 THEN
            v_es_innominada := 'S';
            BEGIN
               SELECT p.nro_documento, c.nom_embozar, p.cod_persona, substr(p.nom_completo,1,65), p.tipo
                 INTO v_nro_doc_principal,
                      v_nom_usuario,
                      v_per_principal,
                      v_nom_principal,
                      v_tip_persona
                 FROM ge_par_generales g, ba_personas p
                WHERE g.cod_persona = p.cod_persona;
               v_persona := v_per_principal;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  pat_imp.pr_log('Al obtener datos generales de la entidad.' || SQLERRM);
            END;
         ELSE
            v_es_innominada := 'N';
         END IF;
         v_existe  := NULL; --se limpia la variable
         g_nro_reg := nvl(g_nro_reg, 0) + 1;
         ---
         IF round(g_nro_reg / 1000) = g_nro_reg / 1000 THEN
            x := (SYSDATE - i) * 24 * 60;
            dbms_output.put_line('Registro: ' || lpad(to_char(g_nro_reg, '999G999G999'), 12, ' ') ||
                                 '; Tiempo transcurrido: ' || to_char(floor(x), '999') || ':' ||
                                 lpad(to_char(round((x - floor(x)) * 60, 2)), 2, '0'));
         END IF;

         ---Si existe la Cta que obtenga el Parámetro Dinamico de Siguiente Nro de Cuenta sino que traiga la del Cursor.
         IF c.nro_cuenta IS NOT NULL THEN
            v_nro_cuenta := c.nro_cuenta;
         END IF;

         --
         /*
         || Si la cuenta ya esta seteada en la variable R_CTAPRO.NRO_CUENTA y es distinta a la cuenta actual
         || significa que ya tiene totalizado -- consolidación de cuenta Principal y Adicional
         */

          IF r_ctapro.nro_cuenta IS NOT NULL AND r_ctapro.nro_cuenta = v_nro_cuenta THEN
              r_ctapro.sal_facturar            := nvl( c.sal_facturar, 0 );
              r_ctapro.mto_pen_amortizaciones  := nvl( c.mto_pen_amortizaciones, 0) + nvl(c.sal_cuo_pendientes,0) ;

            BEGIN
              update ta_cta_tarjetas
                 set sal_facturar       = nvl(sal_facturar,0)       + nvl(r_ctapro.sal_facturar,0),
                     sal_cuo_pendientes = nvl(sal_cuo_pendientes,0) + nvl(r_ctapro.mto_pen_amortizaciones,0)
               where nro_cuenta = r_ctapro.nro_cuenta;
            EXCEPTION
              when v_error then
                raise v_error;
              when others then
                pat_imp.pr_log( 'Al actualizar los saldos de la cuenta ' || c.nro_cuenta||'. '||SQLERRM );
            END;
         END IF;

         r_ctapro.nro_cuenta := v_nro_cuenta;
         r_ctapro.sal_facturar := 0;
         r_ctapro.mto_pen_amortizaciones :=0;
         /*
         || Si el tipo de tarjeta es igual a 0, significa que es la tarjeta principal de la cuenta,
         || entonces se asume que los datos corresponden a la cuenta.
         */
         /**************************************** SECCION DE PROCESOS DE CUENTAS ***************************************/
         --- Las Tarjetas con Mar Activa 3 ya no se leen
         -- y que no tienen saldo -- ajustado MT
         IF nvl(c.mar_activa, -1) = 3 AND
            (c.sal_facturar + c.sal_facturado + c.sal_financiado + c.sal_cuo_pendientes) = 0 THEN --FSPC-269
           /* pat_imp.pr_log('La cuenta ' || to_char(v_nro_cuenta) ||
                           ' se encuenta con Marca Inactiva', FALSE);*/
                           null;
         ELSE
            BEGIN
               SELECT 'S' INTO v_existe FROM ta_cta_tarjetas WHERE nro_cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  v_existe := 'N';
               WHEN OTHERS THEN
                  v_existe := 'N';
                  pat_imp.pr_log('Al comprobar la cuenta ' || v_nro_cuenta || '. ' || SQLERRM);
            END;
            /*
            || Busca la oficina relacionada a la sucursal
            */
            BEGIN
               SELECT nvl(cod_oficina, 1)
                 INTO v_oficina
                 FROM ta_sucursales
                WHERE cod_ent_procesadora = c_procard
                  AND cod_sucursal = c.cod_sucursal
                  AND cod_campana IS NULL;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_oficina         := 1;
                  r_log.nom_proceso := c_nom_proceso;
               WHEN OTHERS THEN
                  v_oficina := NULL;
                  pat_imp.pr_log('Al buscar la oficina de la cuenta ' || v_nro_cuenta || '. ' ||
                                 SQLERRM);
            END;
            /*
            || Setea el estado de la cuenta
            */
            IF nvl(c.mar_activa, -1) = 3 THEN
               v_estado := 'C';
               /*
               || Si tiene algun tipo de bloqueo deja la cuenta Bloqueada
               */

               IF nvl(c.mar_bloqueo, 'x') IN ('U', 'A') THEN
                  v_estado := 'B';
               ELSE
                  v_estado := 'C';
               END IF;
            ELSIF nvl(c.mar_activa, -1) = 1 THEN
               /*
               || Si tiene algun tipo de bloqueo deja la cuenta Bloqueada
               */
               IF nvl(c.mar_bloqueo, 'x') IN ('U', 'A') THEN
                  v_estado := 'B';
               ELSE
                  v_estado := 'N';
               END IF;
            ELSE
               v_estado := NULL;
               pat_imp.pr_log('La cuenta ' || v_nro_cuenta ||
                              ' posee una situacion no identificada (' ||
                              to_char(nvl(c.mar_activa, -1)) || '), no se pudo procesar.');
            END IF;
            IF c.mar_recuperado = 'R' THEN
               v_recuperada := 'S';
               v_estado     := 'C';
            ELSE

               v_recuperada := 'N';
            END IF;
            v_bloqueada := c.mar_bloqueo;

            /*
            || Busca el usuario del Sistema relacionado con el usuario del Ente
            */
            BEGIN
               SELECT cod_usuario
                 INTO v_cod_usuario
                 FROM ge_ent_usuarios
                WHERE cod_ente = c_procard
                  AND cod_usu_ente = c.cod_usu_ente;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_cod_usuario := NULL;
               WHEN OTHERS THEN
                  v_cod_usuario := NULL;
                  pat_imp.pr_log('Al buscar el usuario responsable de la cuenta ' || v_nro_cuenta || '. ' ||
                                 SQLERRM);
            END;

            -- inicio
            /* || __Busca los datos del cliente principal de la cuenta__
            || Aqui busca el cliente principal por la relacion con la tarjeta, en este punto, todavia la relacion
            || esta como viene de la procesadora, o sea 0 para Principal y 1 para Adicional.
            --no se recibe principal juridico,sino 1er adicional fisico   */
            IF nvl(v_es_innominada, 'N') = 'N' THEN
               BEGIN
                  SELECT nvl(t.nro_ruc, /*nvl(trim(t.otr_documento) bancard ueno no existe en bankitti,*/ t.nro_documento), nom_embozar
                    INTO v_nro_doc_principal, v_nom_usuario
                    FROM ta_cta_tarjetas_pro_tmp t, ba_personas p
                   WHERE -- NVL(t.nro_ruc,t.nro_documento) = p.nro_documento
                  --ajuste MT
                   ((p.tipo = 'F' AND nvl(t.nro_ruc,  /*nvl(trim(t.otr_documento), bancard ueno no existe en bankitti*/ t.nro_documento) = p.nro_documento) OR
                   (p.tipo = 'J' AND nvl(t.nro_ruc, t.nro_documento) =
                   regexp_replace(p.nro_documento, '( *[[:punct:]])', '')))

                   AND nvl(t.tip_tarjeta, 0) = 0
                   AND t.nro_tarjeta = c.nro_tar_principal
                   AND t.nro_cuenta = 0;
               EXCEPTION
                  WHEN no_data_found THEN
                     BEGIN
                        SELECT nvl(t.nro_ruc,  /*nvl(trim(t.otr_documento) bancard ueno no existe en bankitti, */t.nro_documento), nom_embozar
                          INTO v_nro_doc_principal, v_nom_usuario
                          FROM ta_cta_tarjetas_pro_tmp t
                         WHERE t.nro_cuenta = v_nro_cuenta
                           AND nvl(t.tip_tarjeta, 0) = 0
                           AND t.nro_tarjeta = c.nro_tar_principal;
                     EXCEPTION
                        WHEN no_data_found THEN
                           BEGIN
                              SELECT p.nro_documento, NULL
                                INTO v_nro_doc_principal, v_nom_usuario
                                FROM ba_personas p, ge_cta_clientes cl
                               WHERE cl.nro_cuenta = v_nro_cuenta
                                 AND relacion = 'P'
                                 AND p.cod_persona = cl.cod_persona
                                 AND rownum = 1;
                           EXCEPTION
                              WHEN OTHERS THEN
                                 v_nro_doc_principal := NULL;
                                 v_nom_usuario       := NULL;
                                 pat_imp.pr_log('ITC-00011: Al buscar el codigo de persona principal de la cuenta ' ||
                                                v_nro_cuenta || ' - Nro. Documento: ' ||
                                                c.nro_documento);
                           END;
                        WHEN OTHERS THEN
                           v_nro_doc_principal := NULL;
                           v_nom_usuario       := NULL;
                           pat_imp.pr_log('ITC-00011: Al buscar el codigo de persona principal de la cuenta ' ||
                                          v_nro_cuenta || 'Nro. Documento: ' || c.nro_documento);
                     END;
               END;

               IF v_nro_doc_principal IS NULL THEN
                  pat_imp.pr_log('ITC-00011: No existe Tarjeta Principal en archivo recibido para la Cta. ' ||
                                 v_nro_cuenta);
                  GOTO siguiente;
               ELSE
                  IF instr(v_nro_doc_principal, '-') > 0 THEN
                     BEGIN
                        SELECT p.cod_persona, substr(p.nom_completo,1,65), nro_documento
                          INTO v_per_principal, v_nom_principal, v_nro_doc_principal
                          FROM ba_personas p
                         WHERE p.nro_documento = to_char(v_nro_doc_principal);
                     EXCEPTION
                        WHEN OTHERS THEN
                           pat_imp.pr_log('ITC-00011: Error al traer Persona ' ||
                                          v_nro_doc_principal);
                           GOTO siguiente;
                     END;
                  ELSE
                     -- es principal fisico o juridico con doc correcto
                     -- busco el principal juridico,si es invalido el doc (negativo)buscar x nro_doc_procesadora,
                     BEGIN
                        SELECT cod_persona
                          INTO v_per_principal
                          FROM ta_env_cuentas_his x
                         WHERE x.nro_cuenta = v_nro_cuenta
                           AND tip_per_titular = 'J'
                           AND fec_envio = (SELECT MAX(fec_envio) --buscar la ultima fec de envio
                                              FROM ta_env_cuentas_his g
                                             WHERE g.nro_cuenta = v_nro_cuenta
                                               AND g.tip_per_titular = 'J');
                        --guardar documento del adicional
                        v_nro_doc_adicional := v_nro_doc_principal;

                        --busco nro de doc del principal juridico
                        BEGIN
                           SELECT substr(p.nom_completo,1,65), nro_documento
                             INTO v_nom_principal, v_nro_doc_principal
                             FROM ba_personas p
                            WHERE p.cod_persona = v_per_principal;
                           v_es_juridica := 'S';
                        EXCEPTION
                           WHEN OTHERS THEN
                              pat_imp.pr_log('ITC-00011: Error al traer Nro de Documento ' ||
                                             v_per_principal);
                              GOTO siguiente;
                        END;
                     EXCEPTION
                        WHEN no_data_found THEN
                           BEGIN
                              SELECT p.cod_persona, substr(j.raz_social,1,65)
                                INTO v_per_principal, v_nom_principal
                                FROM ba_per_juridicas j, ba_personas p
                               WHERE p.cod_tip_documento IN (v_cod_tip_ruc) --tipo ruc
                                 AND (p.nro_documento = v_nro_doc_principal OR
                                     REPLACE(p.nro_documento, '-', '') = v_nro_doc_principal)
                                 AND j.cod_persona = p.cod_persona;
                              v_es_juridica := 'S';
                           EXCEPTION
                              WHEN no_data_found THEN
                                 v_es_juridica := 'N';
                           END;
                     END;
                     --es principal fisico

                     IF v_es_juridica = 'N' THEN
                        BEGIN
                           SELECT p.cod_persona, substr(p.nom_completo,1,65)
                             INTO v_per_principal, v_nom_principal
                             FROM ba_personas p
                            WHERE p.cod_tip_documento IN
                                  (v_cod_tip_doc, v_cod_tip_pas, v_cod_tip_dni, v_cod_tip_cad,
                                   v_cod_tip_crc,8) --tipo cedula
                              AND p.nro_documento = v_nro_doc_principal
                              AND rownum = 1;
                        EXCEPTION
                           WHEN no_data_found THEN
                              IF nvl(fug_obt_pardinamico('TAR_INS_PERSONAS', c.cod_modulo,
                                                         c.cod_modalidad), 'N') = 'S' THEN
                                 v_per_principal := NULL;
                                 v_nom_principal := NULL;
                              ELSE
                                 pat_imp.pr_log('ITC-00010: No se han encontrado datos de la Persona Fisica : ' ||
                                                v_nro_doc_principal || ' - Nro. Cuenta: ' ||
                                                v_nro_cuenta);
                                 GOTO siguiente;
                              END IF;
                           WHEN OTHERS THEN
                              pat_imp.pr_log('ITC-00011: Error al traer Persona Fisica : ' ||
                                             v_nro_doc_principal || ' - Nro. Cuenta: ' ||
                                             v_nro_cuenta);
                              GOTO siguiente;
                        END;

                     END IF;

                  END IF;
               END IF;
            END IF;
            /*
            || Si no existe todavia la persona, entonces inserta una nueva persona con los datos recibidos
            */
            IF v_per_principal IS NULL AND v_nom_principal IS NULL AND
               nvl(fug_obt_pardinamico('TAR_INS_PERSONAS', c.cod_modulo, c.cod_modalidad), 'N') = 'S' THEN
               IF v_nro_doc_principal IS NOT NULL THEN
                  -- Setea el estado civil de acuerdo a los codigos de CABAL
                  pat_imp.pr_ins_persona(c_procard, v_nro_doc_principal, v_cod_tip_doc,
                                         c.nom_embozar, c.fec_nacimiento, c.cod_sexo, c.est_civil,
                                         v_cod_usuario, v_per_principal, v_ok);
                  r_log.nom_proceso := c_nom_proceso;
                  IF v_ok THEN
                     v_nom_principal := c.nom_embozar;
                  ELSE
                     v_nom_principal := NULL;
                     v_per_principal := NULL;
                  END IF;
               ELSE
                  pat_imp.pr_log('No se pudo crear la persona para la cuenta ' || c.nro_cuenta);
                  RAISE v_error;
               END IF;
               v_nro_solicitud := NULL;
               v_fec_solicitud := c_fec_actual;
               /*   || Busca la solicitud del cliente, por el modulo y la modalidad de la tarjeta,
               || ademas del estado de la solicitud  */
            ELSE
               BEGIN
                  SELECT nro_solicitud,
                         fec_solicitud,
                         afinidad,
                         sub_afinidad,
                         tip_cobro,
                         s.nro_cta_debito,
                         cod_rub_economico
                    INTO v_nro_solicitud,
                         v_fec_solicitud,
                         v_cod_afinidad,
                         v_sub_afinidad,
                         v_tip_cobro,
                         v_nro_cta_debito,
                         v_cod_rub_economico
                    FROM ta_solicitudes s
                   WHERE s.cod_persona = v_per_principal
                     AND s.cod_estado = 'TIA'
                     AND s.cod_modulo = c.cod_modulo
                     AND s.cod_modalidad = c.cod_modalidad
                     AND (s.afinidad, nvl(s.sub_afinidad, 'ZZ')) IN
                         (SELECT t.afinidad, nvl(t.sub_afinidad, 'ZZ')
                            FROM ta_tipos t
                           WHERE t.cod_modulo = c.cod_modulo
                             AND t.cod_modalidad = c.cod_modalidad
                             AND t.nro_bin = c.nro_bin)
                     AND rownum = 1;
               EXCEPTION
                  WHEN OTHERS THEN
                     -- Buscar de la cuenta
                     BEGIN
                        SELECT NULL,
                               fec_solicitud,
                               afinidad,
                               sub_afinidad,
                               tip_cobro,
                               cod_rub_economico
                          INTO v_nro_solicitud,
                               v_fec_solicitud,
                               v_cod_afinidad,
                               v_sub_afinidad,
                               v_tip_cobro,
                               v_cod_rub_economico
                          FROM ta_cta_tarjetas
                         WHERE nro_cuenta = v_nro_cuenta;
                     EXCEPTION
                        WHEN OTHERS THEN
                           --pat_imp.pr_log( 'ITC-00099: Al buscar la solicitud de la cuenta ' || c.nro_cuenta || ', para la persona ' || v_per_principal  );
                           v_nro_solicitud     := NULL;
                           v_fec_solicitud     := NULL;
                           v_cod_afinidad      := NULL;
                           v_sub_afinidad      := NULL;
                           v_cod_rub_economico := '970107';
                     END;
               END;
            END IF;
            -- Si no encuentra la afinidad buscar en ta_tipos desde la tarjeta

            IF v_cod_afinidad IS NULL THEN
               BEGIN
                  SELECT ta.afinidad, ta.sub_afinidad
                    INTO v_cod_afinidad, v_sub_afinidad
                    FROM ta_tipos ta
                   WHERE ta.cod_modulo = c.cod_modulo
                     AND ta.cod_modalidad = c.cod_modalidad
                     AND ta.nro_bin = c.nro_bin
                     AND rownum = 1;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_cod_afinidad := NULL;
                     v_sub_afinidad := NULL;
               END;
            END IF;

            -----------
            /*
            || __Busca los datos del cliente principal de la cuenta__
            || Aqui busca el cliente principal por la relacion con la tarjeta, en este punto, todavia la relacion
            || esta como viene de la procesadora, o sea 0 para Principal y 1 para Adicional.
            || Primeramente verifica que el dato del documento recibido no sea RUC, en su defecto sera CI.
            */

            /*
            || Setea la marca de mora y la marca de exceso de la cuenta
            */
            IF nvl(c.mto_mora, 0) > 0 OR nvl(c.dia_mora, 0) > 0 THEN
               v_mar_mora := 'S';
            ELSE
               v_mar_mora := 'N';
            END IF;
            IF nvl(c.mar_excedido, ' ') = 'E' THEN
               v_mar_excedido := 'S';
            ELSE
               v_mar_excedido := 'N';
            END IF;
            IF c.con_costo = '9' THEN
               v_con_costo := 'N';
            ELSE
               v_con_costo := 'S';
            END IF;
            IF c.tip_com_emision = '9' THEN
               v_tip_com_emision := 'N';
            ELSE
               v_tip_com_emision := 'S';
            END IF;
            --
            SELECT SUM(nvl(t.sal_facturar, 0)), SUM(nvl(t.mto_pen_amortizaciones, 0))
              INTO r_ctapro.sal_facturar, r_ctapro.mto_pen_amortizaciones
              FROM ta_cta_tarjetas_pro_tmp t
             WHERE t.cod_ent_procesadora = c.cod_ent_procesadora
               AND t.nro_cuenta = c.nro_cuenta;

            SELECT SUM(nvl(t.lin_credito, 0)),
                   SUM(nvl(t.lin_cuotas, 0)),
                   SUM(nvl(t.lin_especial, 0)),

                   SUM(nvl(t.sal_facturar, 0)), --AJUSTE MT

                   SUM(nvl(t.sal_facturado, 0)),
                   SUM(nvl(t.sal_financiado, 0)),
                   SUM(nvl(t.mto_ult_cierre, 0)),

                   --AJUSTE MT
                   SUM(nvl(t.sal_cuo_pendientes, 0)),
                   SUM(nvl(t.sal_cuo_pen_refin, 0)),
                   SUM(nvl(t.mto_pen_amortizaciones, 0)),

                   SUM(nvl(t.pag_min_facturado, 0)),
                   SUM(nvl(t.mto_pag_minimo, 0)),
                   SUM(nvl(t.mto_mora, 0)),
                   SUM(nvl(t.mto_autorizaciones, 0)),
                   SUM(nvl(t.mto_ult_pago, 0)),
                   SUM(nvl(t.mto_car_suspendido, 0)),
                   SUM(nvl(t.mto_car_sus_aplicado, 0)),
                   --MIN(t.tas_especial) tas_especial, bancard ueno no existe en bankitti
                   MAX(t.dia_mora) dia_mora,
                   MAX(t.fec_generacion) fec_generacion,
                   MAX(t.fec_emi_plastico) fec_emi_plastico,
                  -- MAX(t.fec_ult_pago) fec_ult_pago,
                   MAX(decode (to_char(t.fec_ult_pago,'dd/mm/yyyy'),'01/01/2001',(pat_imp.fu_obt_fec_vencim(c_procard, null,decode(t.tip_cierre,0,4, t.tip_cierre))+1), t.fec_ult_pago)) fec_ult_pago,
                   MAX(t.fec_ult_compra) fec_ult_compra,
                   MAX(t.fec_ult_operacion) fec_ult_operacion,
                   MAX(t.fec_vct_ult_cierre) fec_vct_ult_cierre,
                   MIN(t.fec_ven_extracto) fec_ven_extracto,
                   --MAX(t.fec_ult_cierre) fec_ult_cierre, bancard ueno no existe en bankitti
                   MAX(t.tas_financiacion) tas_financiacion,
                   MAX(t.tas_nominal) tas_nominal,
                   MAX(t.tas_mora) tas_mora,
                   MAX(t.tas_cuotas) tas_cuotas,
                   MIN(t.por_pag_minimo) por_pag_minimo
              INTO r_ctapro.lin_credito,
                   r_ctapro.lin_cuotas,
                   r_ctapro.lin_especial,

                   r_ctapro.sal_facturar,

                   r_ctapro.sal_facturado,
                   r_ctapro.sal_financiado,
                   r_ctapro.mto_ult_cierre,

                   --AJUSTE MT
                   r_ctapro.sal_cuo_pendientes,
                   r_ctapro.sal_cuo_pen_refin,
                   r_ctapro.mto_pen_amortizaciones,

                   r_ctapro.pag_min_facturado,
                   r_ctapro.mto_pag_minimo,
                   r_ctapro.mto_mora,
                   r_ctapro.mto_autorizaciones,
                   r_ctapro.mto_ult_pago,
                   r_ctapro.mto_car_suspendido,
                   r_ctapro.mto_car_sus_aplicado,
                   --r_ctapro.tas_especial, bancard ueno no existe en bankitti
                   r_ctapro.dia_mora,
                   r_ctapro.fec_generacion,
                   r_ctapro.fec_emi_plastico,
                   r_ctapro.fec_ult_pago,
                   r_ctapro.fec_ult_compra,
                   r_ctapro.fec_ult_operacion,
                   r_ctapro.fec_vct_ult_cierre,
                   r_ctapro.fec_ven_extracto,
                   --r_ctapro.fec_ult_cierre, bancard ueno no existe en bankitti
                   r_ctapro.tas_financiacion,
                   r_ctapro.tas_nominal,
                   r_ctapro.tas_mora,
                   r_ctapro.tas_cuotas,
                   r_ctapro.por_pag_minimo
              FROM ta_cta_tarjetas_pro_tmp t
             WHERE t.cod_ent_procesadora = c.cod_ent_procesadora
               AND t.nro_cuenta = c.nro_cuenta
               AND nvl(t.tip_tarjeta, 0) <> 1;
            --and nvl(t.mar_activa,-1) <> 3;  --ajuste MT
            /*
            || Verifica las fechas recibidas para dejar NULAS aquellas menores o iguales al 01/01/1901
            */
            /*  IF nvl( c.fec_ult_pago, to_date( '01/01/1901', 'DD/MM/YYYY' ) ) <= c_fec_min_proceso THEN
              v_fec_ult_pago := NULL;
            END IF;*/
            IF nvl(r_ctapro.fec_ult_compra, to_date('01/01/1901', 'DD/MM/YYYY')) <=
               c_fec_min_proceso THEN
               v_fec_ult_compra := NULL;
            ELSE
               v_fec_ult_compra := r_ctapro.fec_ult_compra;
            END IF;
            IF nvl(r_ctapro.fec_ult_operacion, to_date('01/01/1901', 'DD/MM/YYYY')) <=
               c_fec_min_proceso THEN
               v_fec_ult_ope := NULL;
            ELSE
               v_fec_ult_ope := r_ctapro.fec_ult_operacion;
            END IF;
            IF nvl(r_ctapro.fec_vct_ult_cierre, to_date('01/01/1901', 'DD/MM/YYYY')) <=
               c_fec_min_proceso THEN
               v_fec_vct_ult_cie := NULL;
            ELSE
               v_fec_vct_ult_cie := r_ctapro.fec_vct_ult_cierre;
            END IF;
            IF nvl(r_ctapro.fec_ven_extracto, to_date('01/01/1901', 'DD/MM/YYYY')) <=
               c_fec_min_proceso THEN
               v_fec_ult_extracto := NULL;
            ELSE
               v_fec_ult_extracto := r_ctapro.fec_ven_extracto;
            END IF;

            IF nvl(r_ctapro.fec_ult_pago, to_date('01/01/2001', 'DD/MM/YYYY')) < v_fec_solicitud THEN
               v_fec_ult_pago := NULL;
            ELSE
               v_fec_ult_pago := r_ctapro.fec_ult_pago;
            END IF;

            IF nvl(v_existe, 'N') = 'S' THEN
               IF nvl(c.tip_tarjeta, 0) <> 1 THEN
                  --- si es adicional no tiene que hacer UPDATE
                  /*
                  || Si existe la cuenta, actualiza los datos de la misma, a excepcion de los montos y saldos
                  || que se actualizan al sumar todas las tarjetas de la cuenta.
                  */

                  --dia de mora calcular el maximo,fec_ult_extracto
                  --verificar el estado y la fecha de solicitud,tas_especial,por_pag_minimo
                  --el mínimo debe ser fec_generacion,fecha de solicitud
                  BEGIN
                     UPDATE ta_cta_tarjetas a
                        SET lin_credito      = r_ctapro.lin_credito,
                            lin_cuotas       = r_ctapro.lin_cuotas,
                            lin_especial     = r_ctapro.lin_especial,
                            --tas_especial     = r_ctapro.tas_especial, bancard ueno no existe en bankitti
                            sal_facturar     = r_ctapro.sal_facturar,
                            sal_facturado    = r_ctapro.sal_facturado,
                            sal_financiado   = r_ctapro.sal_financiado,
                            sal_ult_extracto = r_ctapro.mto_ult_cierre,

                            --ajuste MT
                            sal_cuo_pendientes =
                            (r_ctapro.sal_cuo_pen_refin + r_ctapro.mto_pen_amortizaciones),

                            mto_pag_minimo       = r_ctapro.pag_min_facturado,
                            sal_pag_minimo       = r_ctapro.mto_pag_minimo,
                            mto_mora             = r_ctapro.mto_mora,
                            dia_mora             = r_ctapro.dia_mora,
                            mto_autorizaciones   = r_ctapro.mto_autorizaciones,
                            mto_pag_mes          = r_ctapro.mto_ult_pago,
                            estado               = v_estado,
                            fec_solicitud        = v_fec_solicitud,
                            fec_apertura         = r_ctapro.fec_emi_plastico, --r_ctapro.fec_generacion,
                            fec_ult_pago         = v_fec_ult_pago,
                            fec_ult_compra       = v_fec_ult_compra,
                            fec_ult_operacion    = v_fec_ult_ope,
                            fec_ult_extracto     = v_fec_ult_extracto,
                            --fec_ult_cierre       = r_ctapro.fec_ult_cierre, bancard ueno no existe en bankitti
                            fec_vct_ult_cierre   = nvl(r_ctapro.fec_ven_extracto, v_fec_vct_ult_cie),
                            tip_cierre           = c.tip_cierre,
                            mto_car_suspendido   = r_ctapro.mto_car_suspendido,
                            mto_car_sus_aplicado = r_ctapro.mto_car_sus_aplicado,
                            tip_tas_financiacion = r_ctapro.tas_financiacion,
                            tip_com_emision      = c.tip_com_emision,
                            tas_financiacion     = r_ctapro.tas_nominal,
                            tas_mora             = r_ctapro.tas_mora,
                            tas_cuotas           = r_ctapro.tas_cuotas,
                            tas_adelanto         = NULL,
                            por_pag_minimo       = r_ctapro.por_pag_minimo,
                            cod_usu_promotor     = v_cod_usuario,
                            mar_mora             = v_mar_mora,
                            mar_excedido         = v_mar_excedido,
                            mar_recuperado       = v_recuperada,
                            mar_bloqueo          = v_bloqueada,
                            nro_solicitud        = v_nro_solicitud,
                            afinidad             = v_cod_afinidad,
                            sub_afinidad         = v_sub_afinidad,
                            tip_cobro            = decode(nvl(v_tip_cobro, NULL), NULL, 'M',
                                                          v_tip_cobro)

                      WHERE nro_cuenta = to_char(to_number(v_nro_cuenta));
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        pat_imp.pr_log('ITC-00014: Al actualizar los datos de la cuenta ' ||
                                       v_nro_cuenta || ' ' || SQLERRM);
                  END;
               END IF;
            ELSE
               /*
               || Si NO existe la cuenta, inserta la cuenta en TA_CTA_TARJETAS
               */
               BEGIN
                  INSERT INTO ta_cta_tarjetas
                     (nro_cuenta, denominacion, cod_modulo, cod_modalidad, cod_oficina, cod_moneda,
                      lin_credito, lin_cuotas, sal_facturar, sal_facturado, sal_financiado,
                      sal_ult_extracto, sal_cuo_pendientes, mto_pag_minimo, sal_pag_minimo, mto_mora,
                      dia_mora, mto_autorizaciones, mto_pag_mes, estado, fec_solicitud, fec_apertura,
                      fec_ult_pago, fec_ult_compra, fec_ult_operacion, fec_ult_extracto,
                      fec_ult_cierre, fec_vct_ult_cierre, tip_cierre, mto_car_suspendido,
                      mto_car_sus_aplicado, tip_tas_financiacion, tip_com_emision, tas_financiacion,
                      tas_mora, tas_cuotas, tas_adelanto, por_pag_minimo, cod_usu_promotor, mar_mora,
                      mar_excedido, mar_recuperado, mar_bloqueo, nro_solicitud, afinidad,
                      sub_afinidad, cat_automatica, deb_automatico, nro_cta_debito, tip_cobro,
                      cod_rub_economico,
                      --tas_especial, bancard ueno no existe en bankitti
                      lin_especial)
                  VALUES
                     (to_char(to_number(v_nro_cuenta)), nvl(v_nom_principal, 'ERROR VERIFICAR!!!'),
                      nvl(c.cod_modulo, 5), c.cod_modalidad, v_oficina, c_cod_mon_local,
                      r_ctapro.lin_credito, r_ctapro.lin_cuotas, r_ctapro.sal_facturar,
                      r_ctapro.sal_facturado, r_ctapro.sal_financiado, r_ctapro.mto_ult_cierre,
                      (r_ctapro.sal_cuo_pen_refin + r_ctapro.mto_pen_amortizaciones),
                      r_ctapro.pag_min_facturado, r_ctapro.mto_pag_minimo, r_ctapro.mto_mora,
                      r_ctapro.dia_mora, r_ctapro.mto_autorizaciones, r_ctapro.mto_ult_pago,
                      v_estado, v_fec_solicitud, NULL, v_fec_ult_pago, v_fec_ult_compra,
                      v_fec_ult_ope, v_fec_ult_extracto, NULL,
                      nvl(r_ctapro.fec_ven_extracto, v_fec_vct_ult_cie), c.tip_cierre,
                      r_ctapro.mto_car_suspendido, r_ctapro.mto_car_sus_aplicado,
                      r_ctapro.tas_financiacion, c.tip_com_emision, r_ctapro.tas_financiacion,
                      r_ctapro.tas_mora, r_ctapro.tas_cuotas, NULL, r_ctapro.por_pag_minimo,
                      v_cod_usuario, v_mar_mora, v_mar_excedido, c.mar_recuperado, c.mar_bloqueo,
                      v_nro_solicitud, v_cod_afinidad, v_sub_afinidad, 1,
                      decode(nvl(c.nro_cta_debito, 0), 0, 'N', 'S'), v_nro_cta_debito,
                      nvl(v_tip_cobro, 'M'), v_cod_rub_economico,
                      --r_ctapro.tas_especial,bancard ueno no existe en bankitti
                      r_ctapro.lin_especial);
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     pat_imp.pr_log('Al insertar los datos de la cuenta ' || v_nro_cuenta || '. ' ||
                                    SQLERRM);
               END;
            END IF;
            pat_imp.pr_act_ult_pro(v_nro_cuenta, c_fec_actual);
            r_log.nom_proceso := c_nom_proceso;
            v_fec_cierre      := nvl(pat_imp.fu_obt_fec_cierre(c_procard, c.cod_modalidad, c.tip_cierre),
                                     trunc(SYSDATE));
            IF pag_cal.fu_obt_fec_sig_hab(v_fec_cierre, v_ofi_matriz) = c_fec_actual THEN
               pat_imp.pr_ins_sal_cierre(v_nro_cuenta, v_fec_cierre,c_procard); --FSPC-509
               r_log.nom_proceso := c_nom_proceso;
            END IF;
         END IF;
         --- Inserta Cta Garantias ---
         DECLARE
            CURSOR sol_garantia IS
               SELECT nro_solicitud, nro_garantia, cod_garantia, mto_aplicado
                 FROM ta_sol_garantias g
                WHERE g.nro_solicitud = v_nro_solicitud
                  AND NOT EXISTS (SELECT 1
                         FROM ta_cta_garantias a
                        WHERE nvl(a.nro_garantia, 0) = nvl(g.nro_garantia, 0)
                          AND a.nro_cuenta = v_nro_cuenta
                          AND a.cod_garantia = g.cod_garantia);
         BEGIN
            FOR gar IN sol_garantia LOOP
               BEGIN
                  INSERT INTO ta_cta_garantias
                     (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, mto_apl_computable)
                  VALUES
                     (to_char(to_number(v_nro_cuenta)), gar.nro_garantia, gar.cod_garantia,
                      gar.mto_aplicado, 0);
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     pat_imp.pr_log('ITC-00115: Al insertar la garantia ' || gar.nro_garantia ||
                                    ' de la Cuenta ' || v_nro_cuenta);
               END;
            END LOOP;
         END;

         /*************************************** SECCION DE PROCESOS DE TARJETAS ***************************************/
         /*
         || Verifica que existe la tarjeta
         */

         BEGIN
            SELECT 'S', cod_estado
              INTO v_existe_tarjeta, v_est_anterior
              FROM ta_tarjetas
             WHERE nro_cuenta = v_nro_cuenta
               AND nro_tarjeta = c.nro_tarjeta;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN no_data_found THEN
               v_existe_tarjeta := 'N';
            WHEN OTHERS THEN
               v_existe_tarjeta := 'N';
               pat_imp.pr_log('Al comprobar la tarjeta de la cuenta ' || v_nro_cuenta || ' / ' ||
                              c.nro_tarjeta || '. ' || SQLERRM);
         END;
         --

         /* || Busca los datos de la persona relacionada con la tarjeta, mediante el nro. de cedula recibido */
         --solo si ya no es la persona de la tarj. q se busco mas arriba y se hizo la conversion x doc invalido
         IF nvl(v_es_innominada, 'N') = 'N' THEN
            BEGIN
               --si es negativo, es doc invalido
               IF substr(c.nro_documento,1,1) = '-'  AND v_per_principal = abs(c.nro_documento) THEN
                  v_persona      := v_per_principal;
                  v_nom_completo := v_nom_principal;
                  IF v_es_juridica = 'S' THEN
                     v_tip_persona := 'J';
                  ELSE
                     v_tip_persona := 'F';
                  END IF;
               ELSIF substr(c.nro_documento,1,1) = '-' THEN
                  SELECT cod_persona, nom_completo, tipo
                    INTO v_persona, v_nom_completo, v_tip_persona
                    FROM ba_personas
                   WHERE cod_persona = to_char(abs(c.nro_documento));
               ELSE
                  BEGIN
                     SELECT cod_persona, nom_completo, tipo
                       INTO v_persona, v_nom_completo, v_tip_persona
                       FROM ba_personas
                      WHERE cod_tip_documento IN
                            (v_cod_tip_doc, v_cod_tip_pas, v_cod_tip_dni, v_cod_tip_cad,
                             v_cod_tip_crc, v_cod_tip_cie,8) --= 1 cedula
                        AND nro_documento = nvl(c.nro_ruc, c.nro_documento) -- and nro_documento = c.nro_documento;
                        AND rownum = 1;
                  EXCEPTION
                     WHEN no_data_found THEN
                        -- es juridica
                        BEGIN
                           SELECT p.cod_persona, j.raz_social, p.tipo
                             INTO v_persona, v_nom_completo, v_tip_persona
                             FROM ba_per_juridicas j, ba_personas p
                            WHERE p.cod_tip_documento IN (v_cod_tip_ruc) --tipo ruc
                              AND (p.nro_documento = nvl(c.nro_ruc, c.nro_documento) OR
                                  REPLACE(p.nro_documento, '-', '') =
                                  nvl(c.nro_ruc, c.nro_documento))
                              AND j.cod_persona = p.cod_persona;
                        EXCEPTION
                           WHEN no_data_found THEN
                              v_persona      := NULL;
                              v_nom_completo := NULL;
                              v_tip_persona  := 'x';
                           WHEN OTHERS THEN
                              v_persona      := NULL;
                              v_nom_completo := NULL;
                              v_tip_persona  := 'x';
                              pat_imp.pr_log('ITC-00017: Al buscar el codigo de persona de la Tarjeta ' ||
                                             v_nro_cuenta || ' / ' || c.nro_tarjeta || '  Error: ' ||
                                             SQLERRM);
                        END;
                  END;
               END IF;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_persona      := NULL;
                  v_nom_completo := NULL;
                  v_tip_persona  := 'x';
               WHEN OTHERS THEN
                  v_persona      := NULL;
                  v_nom_completo := NULL;
                  v_tip_persona  := NULL;
                  pat_imp.pr_log('ITC-00017: Al buscar el codigo de persona de la Tarjeta ' ||
                                 v_nro_cuenta || ' / ' || c.nro_tarjeta);
            END;
         END IF;
         /*
         || Busca los datos de la persona relacionada con la tarjeta, mediante el nro. de documento recibido
         || Primeramente verifica que el dato del documento recibido no sea RUC, en su defecto sera CI.
         */
         /*
         || Si no existe todavia la persona, entonces inserta una nueva persona con los datos recibidos
         */
         IF nvl(v_tip_persona, 'x') = 'x' THEN
            IF nvl(c.nro_ruc, c.nro_documento) IS NOT NULL THEN
               IF nvl(fug_obt_pardinamico('TAR_INS_PERSONAS', c.cod_modulo, c.cod_modalidad), 'N') = 'S' THEN
                  pat_imp.pr_ins_persona(c_procard, nvl(c.nro_ruc, c.nro_documento), v_cod_tip_doc,
                                         c.nom_embozar, c.fec_nacimiento, c.cod_sexo, c.est_civil,
                                         v_cod_usuario, v_persona, v_ok);
                  r_log.nom_proceso := c_nom_proceso;
                  IF v_ok THEN
                     v_nom_completo := c.nom_embozar;
                     v_tip_persona  := 'F';
                  ELSE
                     v_nom_completo := NULL;
                     v_tip_persona  := 'x';
                     v_persona      := NULL;
                  END IF;
               ELSE
                  pat_imp.pr_log('ITC-00011: Nro. de Documento ' ||
                                 nvl(c.nro_ruc, c.nro_documento) ||
                                 ' inexistente en el Sistema para la Cta. ' || v_nro_cuenta);
                  GOTO siguiente;
               END IF;
            ELSE
               pat_imp.pr_log('ITC-00012: No se pudo crear la persona para la Tarjeta ' ||
                              v_nro_cuenta || ' - ' || c.nro_tarjeta);
               RAISE v_error;
            END IF;
         ELSE
            /*
            || Setea el estado de la tarjeta
            */
            v_nom_embozar := substr(c.nom_embozar, 1, 26);

            IF nvl(c.mar_activa, -1) <> 3 THEN
               IF nvl(fug_obt_pardinamico('TAR_INS_PERSONAS', c.cod_modulo, c.cod_modalidad), 'N') = 'S' THEN
                  --Verifica que exista como cliente
                  BEGIN
                     SELECT 'S'
                       INTO v_es_cliente
                       FROM ge_clientes cu
                      WHERE cu.cod_persona = nvl(v_per_principal, v_persona);
                  EXCEPTION
                     WHEN no_data_found THEN
                        BEGIN
                           INSERT INTO ge_clientes
                              (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial,
                               cli_especial, residente, cod_sec_contable, cod_tip_deudor,
                               cod_seg_cliente)
                           VALUES
                              (nvl(v_per_principal, v_persona), 1, 'N',
                               nvl(fug_obt_pardinamico('GEN_COD_OFICIAL'),
                                    fug_obt_pardinamico('COD_USU_OFI_DEFECTO')), 'N', 'S', 'N', 2,
                               nvl(fug_obt_pardinamico('GEN_COD_SEG_CLIENTE'), 12));
                        EXCEPTION
                           WHEN OTHERS THEN
                              pat_imp.pr_log('No se inserto el cliente ' ||
                                             nvl(v_per_principal, v_persona) || v_nro_cuenta ||
                                             ' - ' || c.nro_tarjeta || SQLERRM);
                              RAISE v_error;
                        END;
                  END;
               END IF;
               v_est_tarjeta := NULL; -- Nulo (Para que no pierda el valor anterior.)
               IF nvl(c.mar_bloqueo, 'x') = 'A' THEN
                  v_est_tarjeta := 13; -- Bloqueo Administrativo
               ELSIF nvl(c.mar_bloqueo, 'x') = 'U' THEN
                  v_est_tarjeta := 14; -- Bloqueo del Usuario
               END IF;
               IF nvl(c.mar_vencida, 'x') = 'V' THEN
                  v_est_tarjeta := 12; -- Vencida
               END IF;
               IF nvl(c.mar_recuperado, 'x') = 'R' THEN
                  v_est_tarjeta := 4; -- Recuperada
               END IF;
               IF v_est_anterior IN (4, 12, 13, 14) AND v_est_tarjeta IS NULL THEN
                  v_est_tarjeta := 6; -- Activa
               END IF;
            ELSIF nvl(c.mar_activa, -1) = 3 THEN
               v_est_tarjeta := 10; -- Baja
            END IF;
            /*
            || Setea la relacion de la persona con respecto a la cuenta principal
            */
            IF nvl(c.tip_tarjeta, -1) = 0 THEN
               v_relacion := 'P';
            ELSIF nvl(c.tip_tarjeta, -1) = 1 THEN
               v_relacion := 'A';
            END IF;
            v_fec_ven_tarjeta := c.fec_ven_plastico;
            IF v_existe IS NULL THEN
               --para los casos de marca 3, ésta variable no se carga, por eso vuelve a calcular, para que no trate de insertar en ta_tarjetas
               BEGIN
                  SELECT 'S' INTO v_existe FROM ta_cta_tarjetas WHERE nro_cuenta = v_nro_cuenta;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_existe := 'N';
                  WHEN OTHERS THEN
                     v_existe := 'N';
                     pat_imp.pr_log('Al comprobar la cuenta ' || v_nro_cuenta || '. ' || SQLERRM);
               END;
            END IF;
            IF nvl(v_existe, 'N') = 'S' AND nvl(v_existe_tarjeta, 'N') = 'S' THEN
               /*
               || Si existe la cuenta y la tarjeta, actualiza los datos de la misma
               */
               BEGIN
                  UPDATE ta_tarjetas
                     SET cod_estado      = nvl(v_est_tarjeta, cod_estado),
                         fec_vencimiento = v_fec_ven_tarjeta,
                         nom_embozar     = v_nom_embozar,
                         fec_emision     = c.fec_emi_plastico,
                         fec_solicitud   = v_fec_solicitud
                   WHERE nro_cuenta = to_char(to_number(v_nro_cuenta))
                     AND nro_tarjeta = c.nro_tarjeta;
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     v_nom_embozar := NULL;
                     pat_imp.pr_log('ITC-00020: Al actualizar los datos de la tarjeta ' ||
                                    v_nro_cuenta || ' / ' || c.nro_tarjeta);
               END;
            ELSE
               IF nvl(c.mar_activa, -1) <> 3 THEN
                  --Daba error de FK porque cuando la tarjeta tiene ésta marca no inserta en ta_cta_tarjetas
                  /*
                  || Si no existe la cuenta, o la tarjeta, entonces inserta los datos de la tarjeta
                  */
                  v_est_tarjeta := 1; -- En Administradora.
                  BEGIN
                     INSERT INTO ta_tarjetas
                        (nro_cuenta, nro_tarjeta, cod_persona, cod_estado, fec_vencimiento,
                         nom_embozar, vigente, fec_emision, fec_solicitud, tip_envio, referencia)
                     VALUES
                        (to_char(to_number(v_nro_cuenta)), c.nro_tarjeta, v_persona, v_est_tarjeta,
                         v_fec_ven_tarjeta, substr(v_nom_embozar, 1, 26), 'S', c.fec_emi_plastico,
                         v_fec_solicitud, v_tip_envio, v_referencia);
                  EXCEPTION
                     WHEN v_error THEN
                        RAISE v_error;
                     WHEN OTHERS THEN
                        pat_imp.pr_log('Al insertar los datos de la tarjeta ' || v_nro_cuenta ||
                                       ' / ' || c.nro_tarjeta || '. ' || SQLERRM);
                  END;
                  IF nvl(v_es_innominada, 'N') = 'S' THEN
                     BEGIN
                        INSERT INTO ba_tab_dat_adicionales
                           (tab_relacion, referencia, parametro, val_parametro)
                        VALUES
                           ('TA_TARJETAS', c.nro_tarjeta, 'NRO_DOCUMENTO', c.nro_documento);
                     EXCEPTION
                        WHEN dup_val_on_index THEN
                           NULL;
                        WHEN v_error THEN
                           RAISE v_error;
                        WHEN OTHERS THEN
                           pat_imp.pr_log('Al insertar el dato adicional de nro. de documento ' ||
                                          v_nro_cuenta || ' / ' || c.nro_tarjeta || '. ' ||
                                          SQLERRM);
                     END;
                  END IF;
                  --
                  IF NOT pat_imp.fu_exi_cta_cli(v_nro_cuenta, v_persona) THEN
                     r_log.nom_proceso := c_nom_proceso;
                     BEGIN
                        /*
                        || Inserta los datos de la cuenta del cliente
                        */
                        INSERT INTO ge_cta_clientes
                           (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
                            cod_modalidad, relacion)
                        VALUES
                           (v_persona, v_nro_cuenta, 0, v_oficina, 5, c.cod_modalidad, v_relacion);
                     EXCEPTION
                        WHEN OTHERS THEN
                           IF substr(SQLERRM, 1, 9) <> 'ORA-00001' THEN
                              pat_imp.pr_log('Al insertar los datos del cliente ' || v_persona ||
                                             ', Cuenta ' || v_nro_cuenta || ' / ' || c.nro_tarjeta || '. ' ||
                                             SQLERRM);
                           END IF;
                     END;
                  END IF;
               END IF;
            END IF;
         END IF;
         <<siguiente>>
         NULL;
      END LOOP;
      ---
      /*  || Actualiza las tarjetas vigentes */
      pat_imp.pr_pro_set_vig_procard;
      /*  || Procesa los cobros de Bancard  */
      pat_imp.pr_ins_cobro_ban;
      r_log.nom_proceso := c_nom_proceso;
      /*  || Guarda los cambios realizados  */
      COMMIT;
      --HABILITAR TRIGGERS DE TARJETAS--
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CUENTAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CUENTAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_GE_CTA_CLIENTES ENABLE', r_log.comentario);
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN v_error THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20271, r_log.comentario || ' ' || r_log.men_error);
         END IF;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20272, 'Error en el proceso de tarjetas Procard ' || SQLERRM);
         END IF;
   END pr_pro_procard;

   -------------------------------*************************FINALIZA PROCARD----------------------------*************************


   /* Procesa los datos de CABAL */
   PROCEDURE pr_pro_cabal IS
      c_fec_actual      CONSTANT DATE := pag_cal.fu_obt_fec_actual(5);
      c_fec_min_proceso CONSTANT DATE := to_date('01/01/1901', 'DD/MM/YYYY');
      c_cod_mon_local   CONSTANT VARCHAR2(3) := pag_gen.fu_obt_mon_local;
      c_cabal           CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_CABAL');
      c_nom_proceso     CONSTANT VARCHAR2(30) := 'pat_imp.PR_PRO_CABAL';
      v_existe          VARCHAR2(1);
      v_oficina         NUMBER(3);
      v_ofi_cta         NUMBER(3);
      v_cod_tip_doc     NUMBER;
      v_cod_tip_ci      NUMBER;
      v_cod_tip_ruc     NUMBER;
      v_cod_tip_pas     NUMBER;
      v_cod_tip_dni     NUMBER;
      v_cod_tip_cad     NUMBER;
      v_cod_tip_cie     NUMBER;
      v_cod_tip_crc     NUMBER;
      v_nro_documento   VARCHAR2(20);
      v_per_principal   VARCHAR2(10);
      v_nom_principal   VARCHAR2(200);
      v_nom_completo    VARCHAR2(200);
      v_estado          VARCHAR2(1);
      v_con_costo       VARCHAR2(1);
      v_tip_com_emision VARCHAR2(1);
      v_est_civil       VARCHAR2(1);
      v_nro_solicitud   NUMBER(8);
      v_fec_solicitud   DATE;
      v_cod_afinidad    VARCHAR2(10);
      v_mar_excedido    VARCHAR2(1);
      v_mar_mora        VARCHAR2(1);
      v_existe_tarjeta  VARCHAR2(1);
      v_persona         VARCHAR2(10);
      v_tip_persona     VARCHAR2(1);
      v_nom_embozar     VARCHAR2(50);
      v_est_tarjeta     NUMBER(2);
      v_est_anterior    NUMBER(2);
      v_relacion        VARCHAR2(1);
      v_fec_ven_tarjeta DATE;
      v_recuperada      VARCHAR2(1);
      v_bloqueada       VARCHAR2(1);
      v_cod_usuario     VARCHAR2(10) := NULL;
      v_ok              BOOLEAN;
      v_deb_automatico  VARCHAR2(1);
      v_nro_cta_debito  VARCHAR2(15);
      --
      v_fec_ult_pago    DATE;
      v_fec_ult_compra  DATE;
      v_fec_ult_ope     DATE;
      v_fec_vct_ult_cie DATE;
      v_fec_emi_plast   DATE;
      v_fec_ven_plast   DATE;
      v_fec_nacimiento  DATE;
      v_ofi_matriz      NUMBER(3);
      v_fec_cierre      DATE;
      v_cod_rub_economico ta_solicitudes.cod_rub_economico%TYPE;
      --
      v_error EXCEPTION;
      --
      CURSOR cuentas IS
         SELECT nro_cuenta,
                nro_tarjeta,
                nro_tar_principal,
                tip_tarjeta,
                nom_embozar,
                cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_moneda,
                direccion,
                nro_documento,
                nro_ruc,
                telefono,
                des_ciudad,
                nacionalidad,
                fec_nacimiento,
                est_civil,
                cod_sexo,
                sucursal cod_sucursal,
                cod_ret_corresp,
                fec_emi_plastico,
                fec_ven_plastico,
                for_pago,
                cod_usu_promotor,
                lin_credito,
                lin_cuotas,
                sal_facturar,
                sal_facturado,
                sal_financiado,
                nvl(mto_mora, 0) mto_mora,
                dia_mora,
                mar_mora,
                mto_pag_minimo,
                nvl(fec_vct_ult_cierre, pat_imp.fu_obt_fec_vencim(c_cabal, cod_modalidad)) fec_vct_ult_cierre,
                mar_recuperado,
                mar_vencida,
                mar_excedido,
                mar_bloqueo,
                mar_activa,
                mar_inhabilitada,
                fec_ult_compra,
                fec_ult_operacion,
                fec_ult_pago,
                nvl(mto_pag_mes, 0) mto_pag_mes,
                cod_afinidad cla_tarjeta,
                tip_cierre,
                sal_cuo_pendientes,
                sal_cuo_pen_refin,
                sal_ade_disponible,
                mto_autorizaciones,
                mto_aut_cuotas,
                mto_car_suspendido,
                tas_efectiva,
                tas_nominal,
                tas_financiacion,
                tas_mora,
                tas_cuotas,
                tas_compras,
                por_pag_minimo,
                tip_com_emision,
                con_costo,
                fec_archivo,
                nro_reg,
                cod_usu_ente,
                estado,
                sal_pag_minimo,
                nro_cta_debito,
                to_number(REPLACE(fug_obt_pardinamico('TASINAD', 5, cod_modalidad, NULL, NULL), ',',
                                  '.')) tas_adelanto
           FROM ta_cta_tarjetas_pro_tmp
          WHERE nro_cuenta IS NOT NULL
            AND cod_ent_procesadora = c_cabal
          ORDER BY nro_cuenta, translate(tip_tarjeta, 'PTA', '012');
      --
      i DATE;
      x NUMBER;
   BEGIN
      i := SYSDATE;
      --- Inicializacion  de variables ---
      g_secuencia := 0;
      g_hor_movim := to_char(SYSDATE, 'HH24:MI:SS');
      --RI:15/10/2010: Obtener sigte. segundo
      g_hor_movim       := pag_gen.fu_obt_sig_segundo(g_hor_movim);
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_log('*** Iniciando el proceso a las ' || to_char(i, 'HH24:MI:SS') || ' ***', FALSE);
      g_nro_reg := 0;
      IF g_tip_implementacion = 3 THEN
         /*
         || Actualiza el numero de cuenta, que en Atlas se compone de la modalidad de la tarjeta
         || mas el codigo de cuenta en la procesadora
         */
         BEGIN
            UPDATE ta_cta_tarjetas_pro_tmp a
               SET (a.nro_cuenta, a.cod_modalidad) =
                   (SELECT to_char(b.cod_modalidad) || a.nro_cuenta, b.cod_modalidad
                      FROM ta_tipos b
                     WHERE b.nro_bin = substr(a.nro_tarjeta, 1, 10))
             WHERE a.nro_cuenta > 0
               AND a.nro_tarjeta > 0
               AND cod_ent_procesadora = c_cabal;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('Al actualizar el numero de cuenta para la tarjeta.');
               --        raise v_error;
         END;
      ELSE
         /*
         || Actualiza la modalidad de las cuentas
         */
         BEGIN
            UPDATE ta_cta_tarjetas_pro_tmp a
               SET a.cod_modalidad =
                   (SELECT b.cod_modalidad
                      FROM ta_tipos b
                     WHERE b.cod_ent_procesadora = c_cabal
                       AND b.nro_bin = substr(a.nro_tarjeta, 1, 10)
                       AND b.afinidad = a.cod_afinidad)
             WHERE a.nro_cuenta > 0
               AND a.nro_tarjeta > 0
               AND cod_ent_procesadora = c_cabal;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('Al actualizar el numero de cuenta para la tarjeta.');
               --        raise v_error;
         END;
      END IF;
      BEGIN
         SELECT cod_ofi_matriz INTO v_ofi_matriz FROM ge_par_generales;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            pat_imp.pr_log('ITC-00003: Al buscar la oficina matriz. ' || SQLERRM);
      END;
      -- Busca el codigo de documento para Cedula de Identidad, Pasaporte, DNI, Certificado de Admision Permanente y RUC
      pat_imp.pr_obt_documentos(v_cod_tip_ci, v_cod_tip_ruc, v_cod_tip_pas, v_cod_tip_dni,
                                v_cod_tip_cad, v_cod_tip_cie, v_cod_tip_crc);
      -- Deshabilitar TRIGGERS DE AUDITORIA --
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_TARJETAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CUENTAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CUENTAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_BA_PERSONAS DISABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_BA_PER_FISICAS DISABLE', r_log.comentario);
      /************************************* SECCION DE CARGA DE TABLAS TEMPORALES *************************************/
      FOR c IN cuentas LOOP
         g_nro_reg := nvl(g_nro_reg, 0) + 1;
         -----
         IF round(g_nro_reg / 1000) = g_nro_reg / 1000 THEN
            x := (SYSDATE - i) * 24 * 60;
            dbms_output.put_line('*** Registro: ' ||
                                 lpad(to_char(g_nro_reg, '999G999G999'), 12, ' ') ||
                                 '; Tiempo transcurrido: ' || to_char(floor(x), '999') || ':' ||
                                 lpad(to_char(round((x - floor(x)) * 60, 2)), 2, '0') || ' ***');
         END IF;
         -----
         /*
         || Verifica las fechas recibidas para dejar NULAS aquellas menores o iguales al 01/01/1901
         */
         IF nvl(c.fec_ult_pago, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_ult_pago := NULL;
         ELSE
            v_fec_ult_pago := c.fec_ult_pago;
         END IF;
         IF nvl(c.fec_ult_compra, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_ult_compra := NULL;
         ELSE
            v_fec_ult_compra := c.fec_ult_compra;
         END IF;
         IF nvl(c.fec_ult_operacion, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_ult_ope := NULL;
         ELSE
            v_fec_ult_ope := c.fec_ult_operacion;
         END IF;
         IF nvl(c.fec_vct_ult_cierre, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_vct_ult_cie := NULL;
         ELSE
            v_fec_vct_ult_cie := c.fec_vct_ult_cierre;
         END IF;
         IF nvl(c.fec_emi_plastico, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_emi_plast := NULL;
         ELSE
            v_fec_emi_plast := c.fec_emi_plastico;
         END IF;
         IF nvl(c.fec_ven_plastico, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_ven_plast := NULL;
         ELSE
            v_fec_ven_plast := c.fec_ven_plastico;
         END IF;
         IF nvl(c.fec_nacimiento, c_fec_min_proceso) <= c_fec_min_proceso THEN
            v_fec_nacimiento := NULL;
         ELSE
            v_fec_nacimiento := c.fec_nacimiento;
         END IF;
         /*
         || Setea el Estado Civil de acuerdo al codigo de CABAL y tambien si es debito automatico
         */
         v_est_civil := translate(substr(c.est_civil, 1, 1), 'CSDVON', 'CSDVOO');
         IF nvl(c.for_pago, 'x') = 'D' THEN
            v_deb_automatico := 'S';
            v_nro_cta_debito := to_number(c.nro_cta_debito);
            IF nvl(v_nro_cta_debito, '0') = 0 THEN
               v_nro_cta_debito := NULL;
            END IF;
         ELSE
            v_deb_automatico := 'N';
            v_nro_cta_debito := NULL;
         END IF;
         IF c.nro_ruc IS NOT NULL AND nvl(c.nro_ruc, ' ') <> nvl(c.nro_documento, ' ') THEN
            v_cod_tip_doc   := v_cod_tip_ruc;
            v_nro_documento := c.nro_ruc;
         ELSE
            /*
            || Convierte el numero de documento recibido en el archivo, ya que CABAL envia el numero de
            || documento rellenado con ceros a la izquierda, aqui se le quita los ceros de mas.
            */
            r_log.comentario := NULL;
            v_nro_documento  := pat_imp.fu_con_documento(c.nro_documento, r_log.comentario);
            IF r_log.comentario IS NOT NULL THEN
               pat_imp.pr_log(r_log.comentario);
            END IF;
            v_cod_tip_doc := v_cod_tip_ci;
         END IF;
         /**************************************** SECCION DE PROCESOS DE CUENTAS ***************************************/
         /*
         || Si el tipo de tarjeta es igual a P, significa que es la tarjeta del Titular de la cuenta,
         || entonces se asume que los datos corresponden a la cuenta.
         */
         IF c.tip_tarjeta = 'P' AND (nvl(c.tas_nominal, 0) <> 0 OR -- Todo esto es para saber si es la cuenta
            nvl(c.tas_financiacion, 0) <> 0 OR -- principal en la que vienen los datos.
            nvl(c.tas_mora, 0) <> 0 OR -- Por de pronto no se puede validar por el estado
            nvl(c.tas_cuotas, 0) <> 0) THEN
            -- ya que en cualquier estado vienen los saldos.
            BEGIN
               SELECT 'S' INTO v_existe FROM ta_cta_tarjetas WHERE nro_cuenta = c.nro_cuenta;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_existe := 'N';
               WHEN OTHERS THEN
                  v_existe := 'N';
                  pat_imp.pr_log('Al comprobar la cuenta ' || c.nro_cuenta);
                  --            raise v_error;
            END;
            /*
            || Busca la oficina relacionada a la sucursal
            */
            BEGIN
               SELECT nvl(cod_oficina, 1)
                 INTO v_oficina
                 FROM ta_sucursales
                WHERE cod_ent_procesadora = c_cabal
                  AND cod_sucursal = c.cod_sucursal
                  AND cod_campana IS NULL;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_oficina := 1;
                  pat_imp.pr_ins_sucursal(c_cabal, c.cod_sucursal);
                  r_log.nom_proceso := c_nom_proceso;
               WHEN OTHERS THEN
                  v_oficina := NULL;
                  pat_imp.pr_log('Al buscar la oficina de la cuenta ' || c.nro_cuenta);
                  --            raise v_error;
            END;
            /*
            || Setea el estado de la cuenta
            */
            v_bloqueada := NULL;
            IF c.estado = 0 THEN
               -- Falta enviar
               v_estado := 'A';
            ELSIF c.estado IN (1, 8, 10, 14, 15, 17, 18) THEN
               -- Normal
               v_estado := 'N';
            ELSIF c.estado IN (4, 5) OR c.estado BETWEEN 50 AND 59 THEN
               -- Bloqueada
               v_estado    := 'B';
               v_bloqueada := 'A';
            ELSIF c.estado BETWEEN 70 AND 89 THEN
               -- Cancelada
               v_estado := 'C';
            ELSE
               pat_imp.pr_log('La cuenta ' || c.nro_cuenta || ' posee un estado desconocido.');
            END IF;
            v_recuperada := 'N';
            /*
                  || Busca el usuario del Sistema relacionado con el usuario del Ente.
                  || Por el momento CABAL no envia el usuario "Promotor" para poder ingresarlo en
                  || el sistema, pero cuando envien esa informacion, hay que descomentar esta seccion.

                  BEGIN
                    select cod_usuario
                      into v_cod_usuario
                      from ge_ent_usuarios
                     where cod_ente = c_cabal
                       and cod_usu_ente = c.cod_usu_ente;
                  EXCEPTION
                    when v_error then
                      raise v_error;
                    when no_data_found then
                      v_cod_usuario := NULL;
                    when others then
                      v_cod_usuario := NULL;
                      pat_imp.pr_log( 'Al buscar el usuario responsable de la cuenta ' || c.nro_cuenta );
            --            raise v_error;
                  END;
                  || Hasta aca verifica el usuario.
                  */
            /*
            || __Busca los datos del cliente principal de la cuenta__
            || Aqui busca el cliente principal por la relacion con la tarjeta, en este punto, todavia la relacion
            || esta como viene de la procesadora, o sea 0 para Principal y 1 para Adicional.
            || Primeramente verifica que el dato del documento recibido no sea RUC, en su defecto sera CI.
            */
            BEGIN
               SELECT cod_persona, nom_completo
                 INTO v_per_principal, v_nom_principal
                 FROM ba_personas
                WHERE cod_tip_documento = v_cod_tip_doc
                  AND nro_documento = v_nro_documento
                  AND rownum = 1;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN no_data_found THEN
                  v_per_principal := NULL;
                  v_nom_principal := NULL;
               WHEN OTHERS THEN
                  v_per_principal := NULL;
                  v_nom_principal := NULL;
                  pat_imp.pr_log('Al buscar el codigo de persona principal de la cuenta ' ||
                                 c.nro_cuenta);
                  --            raise v_error;
            END;
            /*
            || Si no existe todavia la persona, entonces inserta una nueva persona con los datos recibidos
            */
            IF v_per_principal IS NULL AND v_nom_principal IS NULL THEN
               IF v_nro_documento IS NOT NULL THEN
                  -- Setea el estado civil de acuerdo a los codigos de CABAL
                  pat_imp.pr_ins_persona(c_cabal, v_nro_documento, v_cod_tip_doc, c.nom_embozar,
                                         v_fec_nacimiento, c.cod_sexo, v_est_civil, v_cod_usuario,
                                         v_per_principal, v_ok);
                  r_log.nom_proceso := c_nom_proceso;
                  IF v_ok THEN
                     v_nom_principal := c.nom_embozar;
                  ELSE
                     v_nom_principal := NULL;
                     v_per_principal := NULL;
                  END IF;
               ELSE
                  pat_imp.pr_log('No se pudo crear la persona para la cuenta ' || c.nro_cuenta);
                  RAISE v_error;
               END IF;
               v_nro_solicitud := NULL;
               v_fec_solicitud := c_fec_actual;
            ELSE
               /*
               || Busca la solicitud del cliente, por el modulo y la modalidad de la tarjeta,
               || ademas del estado de la solicitud
               */
               BEGIN
                  SELECT nro_solicitud, fec_solicitud, afinidad, cod_rub_economico
                    INTO v_nro_solicitud, v_fec_solicitud, v_cod_afinidad, v_cod_rub_economico
                    FROM ta_solicitudes
                   WHERE cod_modulo = c.cod_modulo
                     AND cod_modalidad = c.cod_modalidad
                     AND cod_persona = v_per_principal
                     AND cod_estado = 'TIA'
                     AND rownum = 1;
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN no_data_found THEN
                     v_nro_solicitud := NULL;
                     v_fec_solicitud := NULL;
                     v_cod_afinidad  := NULL;
                     v_cod_rub_economico := NULL;
                  WHEN OTHERS THEN
                     v_nro_solicitud := NULL;
                     v_fec_solicitud := NULL;
                     v_cod_afinidad  := NULL;
                     v_cod_rub_economico := NULL;
                     pat_imp.pr_log('Al buscar la solicitud de la cuenta ' || c.nro_cuenta ||
                                    ', para la persona ' || v_per_principal);
                     --              raise v_error;
               END;
            END IF;
            /*
            || Setea la marca de mora y la marca de exceso de la cuenta
            */
            IF nvl(c.mto_mora, 0) > 0 OR nvl(c.dia_mora, 0) > 0 THEN
               v_mar_mora := 'S';
            ELSE
               v_mar_mora := 'N';
            END IF;
            IF nvl(c.mar_excedido, ' ') = 'E' THEN
               v_mar_excedido := 'S';
            ELSE
               v_mar_excedido := 'N';
            END IF;
            IF nvl(v_existe, 'N') = 'S' THEN
               /*
               || Si existe la cuenta, actualiza los datos de la misma, a excepcion de los montos y saldos
               || que se actualizan cuento es la tarjeta principal de la cuenta.
               */
               BEGIN
                  UPDATE ta_cta_tarjetas a
                     SET estado             = v_estado,
                         fec_solicitud      = v_fec_solicitud,
                         fec_ult_pago       = v_fec_ult_pago,
                         fec_ult_compra     = v_fec_ult_compra,
                         fec_ult_operacion  = v_fec_ult_ope,
                         fec_vct_ult_cierre = v_fec_vct_ult_cie,
                         fec_apertura       = least(v_fec_emi_plast, nvl(fec_apertura, c_fec_actual)),
                         tip_cierre         = c.tip_cierre,
                         tip_com_emision    = v_tip_com_emision,
                         cod_usu_promotor   = v_cod_usuario,
                         mar_mora           = v_mar_mora,
                         mar_excedido       = v_mar_excedido,
                         mar_bloqueo        = v_bloqueada,
                         --nro_solicitud      = v_nro_solicitud,
                         --afinidad           = v_cod_afinidad,
                         con_costo          = v_con_costo,
                         deb_automatico     = v_deb_automatico,
                         nro_cta_debito     = v_nro_cta_debito,
                         lin_credito        = nvl(c.lin_credito, 0),
                         lin_cuotas         = nvl(c.lin_cuotas, 0),
                         sal_facturar       = nvl(c.sal_facturar, 0),
                         sal_facturado      = nvl(c.sal_facturado, 0),
                         sal_financiado     = nvl(c.sal_financiado, 0),
                         mto_mora           = nvl(c.mto_mora, 0),
                         dia_mora           = nvl(c.dia_mora, 0),
                         mto_pag_minimo     = nvl(c.mto_pag_minimo, 0),
                         sal_pag_minimo     = nvl(c.sal_pag_minimo, 0),
                         mto_pag_mes        = nvl(c.mto_pag_mes, 0),
                         sal_cuo_pendientes = nvl(c.sal_cuo_pendientes, 0),
                         tas_financiacion   = nvl(c.tas_financiacion, 0),
                         tas_mora           = nvl(c.tas_mora, 0),
                         tas_cuotas         = nvl(c.tas_cuotas, 0),
                         tas_adelanto       = nvl(c.tas_adelanto, 0),
                         por_pag_minimo     = nvl(c.por_pag_minimo, 0),
                         --                 sal_cuo_pen_refin  = nvl( c.sal_cuo_pen_refin, 0 ),
                         --                 sal_ade_disponible = nvl( c.sal_ade_disponible, 0 ),
                         mto_autorizaciones = nvl(c.mto_autorizaciones, 0)
                   WHERE nro_cuenta = c.nro_cuenta;
                  IF SQL%NOTFOUND THEN
                     RAISE no_data_found;
                  END IF;
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     pat_imp.pr_log('Al actualizar los datos de la cuenta ' || c.nro_cuenta);
                     --              raise v_error;
               END;
            ELSE
               /*
               || Si NO existe la cuenta, inserta la cuenta en TA_CTA_TARJETAS
               */
               BEGIN
                  INSERT INTO ta_cta_tarjetas
                     (nro_cuenta, denominacion, cod_modulo, cod_modalidad, cod_oficina, cod_moneda,
                      lin_credito, lin_cuotas, sal_facturar, sal_facturado, sal_financiado,
                      sal_cuo_pendientes, mto_pag_minimo, sal_pag_minimo, mto_mora, dia_mora,
                      mto_autorizaciones, mto_pag_mes, estado, fec_solicitud, fec_ult_pago,
                      fec_ult_compra, fec_ult_operacion, fec_vct_ult_cierre, fec_apertura,
                      tip_cierre, tip_com_emision, tas_financiacion, tas_mora, tas_cuotas,
                      tas_adelanto, por_pag_minimo, cod_usu_promotor, mar_mora, mar_excedido,
                      mar_recuperado, mar_bloqueo, nro_solicitud, afinidad, con_costo,
                      cat_automatica, deb_automatico, nro_cta_debito, cod_rub_economico)
                  VALUES
                     (c.nro_cuenta, nvl(v_nom_principal, 'ERROR VERIFICAR!!!'),
                      nvl(c.cod_modulo, 5), c.cod_modalidad, v_oficina, c_cod_mon_local,
                      c.lin_credito, c.lin_cuotas, c.sal_facturar, c.sal_facturado, c.sal_financiado,
                      c.sal_cuo_pendientes, c.mto_pag_minimo, c.sal_pag_minimo, c.mto_mora,
                      c.dia_mora, c.mto_autorizaciones, c.mto_pag_mes, v_estado, v_fec_solicitud,
                      v_fec_ult_pago, v_fec_ult_compra, v_fec_ult_ope, v_fec_vct_ult_cie,
                      v_fec_emi_plast, c.tip_cierre, c.tip_com_emision, c.tas_financiacion,
                      c.tas_mora, c.tas_cuotas, c.tas_adelanto, c.por_pag_minimo, v_cod_usuario,
                      v_mar_mora, v_mar_excedido, v_recuperada, v_bloqueada, v_nro_solicitud,
                      v_cod_afinidad, v_con_costo, 1, v_deb_automatico, v_nro_cta_debito,
                      v_cod_rub_economico);
               EXCEPTION
                  WHEN v_error THEN
                     RAISE v_error;
                  WHEN OTHERS THEN
                     pat_imp.pr_log('Al insertar los datos de la cuenta ' || c.nro_cuenta);
                     --              raise v_error;
               END;
            END IF; -- Fin de verificacion si existe o no
            pat_imp.pr_act_ult_pro(c.nro_cuenta, c_fec_actual);
            r_log.nom_proceso := c_nom_proceso;
            v_fec_cierre      := nvl(pat_imp.fu_obt_fec_cierre(c_cabal, c.cod_modalidad),
                                     trunc(SYSDATE));
            IF pag_cal.fu_obt_fec_sig_hab(v_fec_cierre, v_ofi_matriz) = c_fec_actual THEN
               pat_imp.pr_ins_sal_cierre(c.nro_cuenta, v_fec_cierre,c_cabal);--FSPC-509
               r_log.nom_proceso := c_nom_proceso;
            END IF;
         END IF; -- Fin de tarjeta Principal con datos
         /*************************************** SECCION DE PROCESOS DE TARJETAS ***************************************/
         /*
         || Verifica que existe la tarjeta
         */
         BEGIN
            SELECT 'S', cod_estado
              INTO v_existe_tarjeta, v_est_anterior
              FROM ta_tarjetas
             WHERE nro_cuenta = c.nro_cuenta
               AND nro_tarjeta = c.nro_tarjeta;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN no_data_found THEN
               v_existe_tarjeta := 'N';
            WHEN OTHERS THEN
               v_existe_tarjeta := 'N';
               pat_imp.pr_log('Al comprobar la tarjeta de la cuenta ' || c.nro_cuenta || ' / ' ||
                              c.nro_tarjeta);
               --        raise v_error;
         END;
         /*
         || Busca los datos de la persona relacionada con la tarjeta, mediante el nro. de cedula recibido
         */
         BEGIN
            SELECT cod_persona, nom_completo, tipo
              INTO v_persona, v_nom_completo, v_tip_persona
              FROM ba_personas
             WHERE cod_tip_documento = v_cod_tip_doc
               AND nro_documento = v_nro_documento;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN no_data_found THEN
               v_persona      := NULL;
               v_nom_completo := NULL;
               v_tip_persona  := 'x';
            WHEN OTHERS THEN
               v_persona      := NULL;
               v_nom_completo := NULL;
               v_tip_persona  := NULL;
               pat_imp.pr_log('ITC-00017: Al buscar el codigo de persona de la Tarjeta ' ||
                              c.nro_cuenta || ' / ' || c.nro_tarjeta || '; ' || SQLERRM);
               --            raise v_error;
         END;
         /*
         || Si la persona aun no esta creada en el sistema, crea una nueva persona con los datos recibidos.
         */
         IF nvl(v_tip_persona, 'x') = 'x' THEN
            IF v_nro_documento IS NOT NULL THEN
               pat_imp.pr_ins_persona(c_cabal, v_nro_documento, v_cod_tip_doc, c.nom_embozar,
                                      c.fec_nacimiento, c.cod_sexo, v_est_civil, v_cod_usuario,
                                      v_persona, v_ok);
               r_log.nom_proceso := c_nom_proceso;
               IF v_ok THEN
                  v_nom_completo := c.nom_embozar;
                  v_tip_persona  := 'F';
               ELSE
                  v_nom_completo := NULL;
                  v_tip_persona  := 'x';
                  v_persona      := NULL;
               END IF;
            ELSE
               pat_imp.pr_log('ITC-00018: No se pudo crear la persona para la Tarjeta ' ||
                              c.nro_cuenta || ' - ' || c.nro_tarjeta || '; ' || SQLERRM);
               RAISE v_error;
            END IF;
         END IF;
         /*
         || Selecciona el nombre a embozar en la tarjeta de acuerdo al tipo de persona (Fisica/Juridica)
         */
         BEGIN
            IF nvl(v_tip_persona, 'x') = 'F' THEN
               SELECT substr(pri_nombre || ' ' || pri_apellido, 1, 26)
                 INTO v_nom_embozar
                 FROM ba_per_fisicas
                WHERE cod_persona = v_persona;
            ELSIF nvl(v_tip_persona, 'x') = 'J' THEN
               SELECT substr(raz_social, 1, 26)
                 INTO v_nom_embozar
                 FROM ba_per_juridicas
                WHERE cod_persona = v_persona;
            END IF;
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN no_data_found THEN
               v_nom_embozar := NULL;
               pat_imp.pr_log('La persona ' || v_persona || ' relacionada a la cuenta ' ||
                              c.nro_cuenta || ' / ' || c.nro_tarjeta ||
                              ', no esta definida en la tabla de personas fisicas o juridicas.');
               --        raise v_error;
            WHEN OTHERS THEN
               v_nom_embozar := NULL;
               pat_imp.pr_log('Al buscar el nombre a embozar de la persona ' || v_persona ||
                              ' para la cuenta ' || c.nro_cuenta || ' / ' || c.nro_tarjeta);
               --        raise v_error;
         END;
         /*
         || Setea el estado de la tarjeta
         */
         IF c.estado = 0 THEN
            -- En administradora
            v_est_tarjeta := 1;
         ELSIF c.estado IN (1, 10) THEN
            -- Activa
            v_est_tarjeta := NULL; -- Para que no cambie el estado anterior.
         ELSIF c.estado = 4 THEN
            -- Bloqueo Administrativo
            v_est_tarjeta := 13;
         ELSIF c.estado = 5 THEN
            -- Bloqueo Usuario
            v_est_tarjeta := 14;
         ELSIF c.estado = 8 THEN
            -- Vencida
            v_est_tarjeta := 12;
         ELSIF c.estado = 14 THEN
            -- Robada
            v_est_tarjeta := 7;
         ELSIF c.estado = 15 THEN
            -- Perdida
            v_est_tarjeta := 8;
         ELSIF c.estado BETWEEN 50 AND 59 THEN
            -- Atrasada con Bloqueo
            v_est_tarjeta := 13;
         ELSIF c.estado IN (17, 18) OR c.estado BETWEEN 70 AND 89 THEN
            -- Cancelada
            v_est_tarjeta := 7;
         ELSE
            pat_imp.pr_log('La tarjeta ' || c.nro_cuenta || ' / ' || c.nro_tarjeta ||
                           ' posee un estado desconocido.');
         END IF;
         IF v_est_anterior IN (4, 12, 13, 14) AND v_est_tarjeta IS NULL THEN
            v_est_tarjeta := 6; -- Activa.
         END IF;
         /*
         || Setea la relacion de la persona con respecto a la cuenta principal
         */
         IF nvl(c.tip_tarjeta, ' ') = 'P' THEN
            v_relacion := 'P';
         ELSIF nvl(c.tip_tarjeta, ' ') = 'T' THEN
            v_relacion := 'P';
         ELSIF nvl(c.tip_tarjeta, ' ') = 'A' THEN
            v_relacion := 'A';
         END IF;
         v_fec_ven_tarjeta := v_fec_ven_plast;
         IF nvl(v_existe, 'N') = 'S' AND nvl(v_existe_tarjeta, 'N') = 'S' THEN
            /*
            || Si existe la cuenta y la tarjeta, actualiza los datos de la misma
            */
            BEGIN
               UPDATE ta_tarjetas
                  SET cod_estado      = nvl(v_est_tarjeta, cod_estado),
                      fec_vencimiento = v_fec_ven_tarjeta,
                      nom_embozar     = v_nom_embozar,
                      fec_emision     = v_fec_emi_plast,
                      fec_solicitud   = v_fec_solicitud
                WHERE nro_cuenta = c.nro_cuenta
                  AND nro_tarjeta = c.nro_tarjeta;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_nom_embozar := NULL;
                  pat_imp.pr_log('Al actualizar los datos de la tarjeta ' || c.nro_cuenta || ' / ' ||
                                 c.nro_tarjeta);
                  --          raise v_error;
            END;
         ELSIF nvl(v_existe_tarjeta, 'N') = 'N' THEN
            v_est_tarjeta := 1;
            /*
            || Si no existe la cuenta, o la tarjeta, entonces inserta los datos de la tarjeta
            */
            BEGIN
               INSERT INTO ta_tarjetas
                  (nro_cuenta, nro_tarjeta, cod_persona, cod_estado, fec_vencimiento, nom_embozar,
                   vigente, fec_emision, fec_solicitud)
               VALUES
                  (c.nro_cuenta, c.nro_tarjeta, v_persona, v_est_tarjeta, v_fec_ven_plast,
                   substr(v_nom_embozar, 1, 26), 'N', v_fec_emi_plast, v_fec_solicitud);
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  pat_imp.pr_log('Al insertar los datos de la tarjeta ' || c.nro_cuenta || ' / ' ||
                                 c.nro_tarjeta || ', ' || to_char(v_fec_ven_plast, 'DD/MM/YYY') || ', ' ||
                                 to_char(v_fec_ven_tarjeta, 'DD/MM/YYY'));
                  --          raise v_error;
            END;
         END IF;
         IF NOT pat_imp.fu_exi_cta_cli(c.nro_cuenta, v_persona) THEN
            r_log.nom_proceso := c_nom_proceso;
            /*
            || Busca la oficina de la cuenta para que al insertar la relacion del cliente
            || no de error por el Foreing Key que busca la oficina de la cuenta.
            */
            BEGIN
               SELECT cod_oficina INTO v_ofi_cta FROM ge_cuentas WHERE nro_cuenta = c.nro_cuenta;
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  v_ofi_cta := NULL;
            END;
            BEGIN
               /*
               || Inserta los datos de la cuenta del cliente
               */
               INSERT INTO ge_cta_clientes
                  (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad,
                   relacion)
               VALUES
                  (v_persona, c.nro_cuenta, 0, nvl(v_ofi_cta, v_oficina), 5, c.cod_modalidad,
                   v_relacion);
            EXCEPTION
               WHEN v_error THEN
                  RAISE v_error;
               WHEN OTHERS THEN
                  IF substr(SQLERRM, 1, 9) <> 'ORA-00001' THEN
                     pat_imp.pr_log('Al insertar los datos del cliente ' || v_persona ||
                                    ', Cuenta ' || c.nro_cuenta || ' / ' || c.nro_tarjeta);
                     --            raise v_error;
                  END IF;
            END;
         END IF;
      END LOOP;
      /*
      || Procesa los cobros de CABAL, y le llama al mismo procedimiento de Bancard
      || ya que vienen con el mismo formato.
      */
      pat_imp.pr_ins_cobro_cabal;
      r_log.nom_proceso := c_nom_proceso;
      --HABILITAR TRIGGERS DE TARJETAS--
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AA_GE_CUENTAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_GE_CUENTAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_BA_PERSONAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER TB_BA_PER_FISICAS ENABLE', r_log.comentario);
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN v_error THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20271, r_log.comentario || ' ' || r_log.men_error);
         END IF;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20272, 'Error en el proceso de tarjetas CABAL ' || SQLERRM);
         END IF;
   END pr_pro_cabal;
   /* Procesa los cobros de CABAL */
   PROCEDURE pr_ins_cobro_cabal IS
      c_cabal       CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_CABAL');
      c_nom_proceso CONSTANT VARCHAR2(30) := 'pat_imp.PR_INS_COBRO_CABAL';
      v_hora ta_movimientos_his.hora%TYPE;
      v_error EXCEPTION;
      --
      CURSOR cobros IS
         SELECT t.nro_cuenta,
                t.nro_tarjeta,
                t.fec_proceso,
                t.monto,
                t.estado,
                t.fec_valor,
                t.est_envio,
                t.dia_mora,
                t.nro_reg,
                j.cod_modulo,
                t.cod_modalidad,
                t.observacion,
                j.cod_moneda,
                j.cod_oficina
           FROM ta_cobros_tmp t, ta_cta_tarjetas j
          WHERE t.nro_cuenta = j.nro_cuenta
            AND cod_ent_procesadora = c_cabal
            AND NOT EXISTS (SELECT 1
                   FROM ta_cobros c
                  WHERE c.nro_cuenta = t.nro_cuenta
                    AND c.nro_tarjeta = t.nro_tarjeta
                    AND c.fec_proceso = t.fec_proceso
                    AND c.monto = t.monto)
          ORDER BY t.nro_reg;
      --
   BEGIN
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_log('*** Iniciando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') || ' ***',
                     FALSE);
      v_hora := '00:00:00';
      /*
      || Actualiza la modalidad de las cuentas
      */
      BEGIN
         UPDATE ta_cta_tarjetas_pro_tmp a
            SET a.nro_cuenta =
                (SELECT b.nro_cuenta FROM ta_tarjetas b WHERE b.nro_tarjeta = a.nro_tarjeta)
          WHERE a.nro_tarjeta > 0
            AND cod_ent_procesadora = c_cabal;
      EXCEPTION
         WHEN v_error THEN
            RAISE v_error;
         WHEN OTHERS THEN
            pat_imp.pr_log('Al actualizar el numero de cuenta para la tarjeta.');
            --      raise v_error;
      END;
      FOR c IN cobros LOOP
         v_hora    := pag_gen.fu_obt_sig_segundo(v_hora);
         g_nro_reg := c.nro_reg;
         BEGIN
            INSERT INTO ta_cobros
               (nro_cuenta, nro_tarjeta, fec_proceso, monto, estado, fec_valor, observacion,
                est_envio, hora, cod_usuario, dia_mora)
            VALUES
               (c.nro_cuenta, c.nro_tarjeta, c.fec_proceso, c.monto, 'P', c.fec_valor,
                'COBRADO POR LA RED', 'E', v_hora, substr(USER, 1, 10), c.dia_mora);
         EXCEPTION
            WHEN v_error THEN
               RAISE v_error;
            WHEN OTHERS THEN
               pat_imp.pr_log('Al insertar el pago de la cuenta ' || c.nro_cuenta);
               --        raise v_error;
         END;
         /*
         || Inserta los movimientos historicos de tarjetas.
         || Este parte del proceso estaba implementado en Atlas, y se migro la logica del procedimiento
         || tal cual como estaba implementado.
         */
         BEGIN
            INSERT INTO ta_movimientos_his
               (fecha, hora, cod_usuario, nro_secuencia, monto, nro_cuenta, cod_moneda, cod_oficina,
                estado, cod_ofi_origen, concepto, reversado, cod_tra_padre, cod_mod_padre,
                cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad)
            VALUES
               (c.fec_proceso, v_hora, substr(USER, 1, 10), 1, c.monto, c.nro_cuenta, c.cod_moneda,
                c.cod_oficina, 'N', c.cod_oficina, 'COBRADO POR LA RED / ' || c.observacion, 'N',
                250, 9, 91, 690, c.cod_modulo, c.cod_modalidad);
         EXCEPTION
            WHEN OTHERS THEN
               pat_imp.pr_log('Al insertar el movimiento historico para la cuenta ' ||
                              c.nro_cuenta);
               --        raise v_error;
         END;
      END LOOP;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN v_error THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20271, r_log.comentario || ' ' || r_log.men_error);
         END IF;
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20272,
                                    'Error en el proceso de cobros de tarjetas de Cabal ' ||
                                     SQLERRM);
         END IF;
   END pr_ins_cobro_cabal;
   /* Cambio de Categoria */
   PROCEDURE pr_cam_categoria(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE DEFAULT NULL) IS
      c_fec_actual CONSTANT DATE := pag_cal.fu_obt_fec_actual(5);
      v_new_categoria ta_cta_tarjetas.cat_automatica%TYPE;      

      CURSOR cuentas IS
         SELECT t.nro_cuenta,
                t.cod_modulo,
                t.cod_modalidad,
                t.cod_oficina,
                t.cod_moneda,
                nvl(t.cat_automatica, 1) cat_automatica,
                nvl(t.dia_mora, 0) dia_mora,
                t.sal_facturar,
                t.sal_facturado,
                t.sal_financiado,
                t.sal_cuo_pendientes
           FROM ta_cta_tarjetas t, ge_est_cuentas e
          WHERE nro_cuenta = nvl(p_nro_cuenta, nro_cuenta)
            AND t.cod_modulo = e.cod_modulo
            AND t.cod_modalidad = e.cod_modalidad
            AND t.estado = e.estado
            AND e.activo = 'S';
   BEGIN
      r_log.nom_proceso := 'pat_imp.PR_CAM_CATEGORIA';
      r_log.fec_hor_ini := SYSDATE;
      BEGIN
       SELECT COUNT(*)
         INTO v_can_user
         FROM ba_cod_referencias
         WHERE dominio     = 'USU_MOV_CIERRE'
           AND abreviatura = 'MOVCIERRE';
     EXCEPTION
       WHEN OTHERS THEN
         NULL;
     END;
      g_hor_movim       := fug_ini_hora(sysdate,'HH24:MI:SS');
      g_hor_movim       := pag_gen.FU_OBT_SIG_SEGUNDO(g_hor_movim);
      g_hor_movim       := fug_obt_hor_disponible(c_fec_actual,g_hor_movim,user,'N');
      pat_imp.pr_ins_log_error('*** Iniciando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                               ' ***', FALSE);
      --RI:15/10/2010: Obtener sigte. segundo
      FOR c IN cuentas LOOP
         --g_hor_movim := pag_gen.fu_obt_sig_segundo(g_hor_movim);
         IF c.dia_mora <= 60 THEN
            v_new_categoria := 1;
         ELSIF c.dia_mora > 60 AND c.dia_mora < 91 THEN
            v_new_categoria := 2;
         ELSIF c.dia_mora > 90 AND c.dia_mora < 151 THEN
            v_new_categoria := 3;
         ELSIF (c.dia_mora > 150 AND c.dia_mora < 181) OR fug_obt_tip_implementacion = 3 THEN
            -- Para 3 no se usa cambio por mora a 5
            v_new_categoria := 4;
         ELSIF (c.dia_mora > 180 AND c.dia_mora < 271) THEN
            v_new_categoria := 5;
         ELSE
            v_new_categoria := 6;
         END IF;
         IF v_new_categoria <> c.cat_automatica THEN
            -- Inicializa las globales del paquete para poder ejecutar el resto de los procedimientos
            g_nro_cuenta    := c.nro_cuenta;
            g_cod_modulo    := nvl(c.cod_modulo, 5);
            g_cod_modalidad := c.cod_modalidad;
            g_cod_oficina   := c.cod_oficina;
            g_cod_moneda    := c.cod_moneda;
            g_cotizacion    := pag_gen.fu_obt_cotizacion(g_cod_moneda, c_fec_actual);
            g_dias          := nvl(c.dia_mora, 0);
            g_old_categoria := c.cat_automatica;
            g_sal_tarjeta   := nvl(c.sal_facturar, 0) + nvl(c.sal_facturado, 0) +
                               nvl(c.sal_financiado, 0) + nvl(c.sal_cuo_pendientes, 0);
            pat_imp.pr_pro_cam_est_tar(c.nro_cuenta, c.cat_automatica, v_new_categoria);
         END IF;
      END LOOP;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN OTHERS THEN
         pat_imp.pr_log('Error en el proceso de cambio de categoria para tarjetas ' ||
                        p_nro_cuenta || '. ' || SQLERRM);
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20282,
                                    'Error en el proceso de cambio de categoria para tarjetas ' ||
                                     SQLERRM);
         END IF;
   END pr_cam_categoria;
   /* Proceso de cambio de estado de tarjetas. */
   PROCEDURE pr_pro_cam_est_tar
   (
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_old_categoria IN ta_cta_tarjetas.cat_automatica%TYPE,
      p_new_categoria IN ta_cta_tarjetas.cat_automatica%TYPE
   ) IS
      v_cod_tra_pad   ge_movimientos.cod_tra_padre%TYPE;
      v_cod_tra_hij   ge_movimientos.cod_transaccion%TYPE;
      v_mto_trans     ge_movimientos.monto%TYPE;
      v_mto_prevision ge_movimientos.monto%TYPE;
      v_concepto      ge_movimientos.concepto%TYPE;
      v_est_ant       ge_movimientos.estado%TYPE;
      v_est_act       ge_movimientos.estado%TYPE;
   BEGIN
      r_log.nom_proceso := 'pat_imp.PR_PRO_CAM_EST_TAR';
      r_log.fec_hor_ini := SYSDATE;
      v_cod_tra_pad     := 945;
      v_mto_trans       := 0;
      --actualiza estado de tarjeta
      pat_imp.pr_act_cat_tarjeta(p_nro_cuenta, p_new_categoria);
      IF p_old_categoria = 1 AND p_new_categoria IN (2, 3, 4, 5, 6) THEN
         -- transf. de VIGENTE A VENCIDA O GESTION O MOROSA ---
         v_mto_trans := g_sal_tarjeta;
         IF p_new_categoria = 2 THEN
            v_cod_tra_hij := 920;
            v_concepto    := 'TRANSF.CAP.VIG.A VENC-PF';
         ELSIF p_new_categoria = 3 THEN
            v_cod_tra_hij := 933;
            v_concepto    := 'TRANSF.CAP.VIG.A GEST-PF';
         ELSIF p_new_categoria IN (4, 5, 6) THEN
            v_cod_tra_hij := 936;
            v_concepto    := 'TRANSF.CAP.VIG.A MORO-PF';
         END IF;
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      IF p_old_categoria = 2 AND p_new_categoria = 3 THEN
         -- De VENCIDA a EN GESTION
         v_cod_tra_hij := 926;
         v_mto_trans   := g_sal_tarjeta;
         --x saldo capital
         v_concepto := 'TRANSF.CAPITAL VENC. A EN GEST.';
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      IF p_old_categoria = 2 AND p_new_categoria IN (4, 5, 6) THEN
         -- De VENCIDA a MOROSA
         v_cod_tra_hij := 939;
         v_mto_trans   := g_sal_tarjeta;
         v_concepto    := 'TRANSF.CAPITAL VENC. A MOROSA';
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      IF p_old_categoria = 3 AND p_new_categoria IN (4, 5, 6) THEN
         -- De EN GESTION A MOROSA
         v_cod_tra_hij := 929;
         v_mto_trans   := g_sal_tarjeta;
         v_concepto    := 'TRANSF.CAPITAL EN GEST. A MOROSA';
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      -- esto solo se hace si hay traslado para atras
      IF p_old_categoria IN (2, 3, 4, 5, 6) AND p_new_categoria = 1 THEN
         -- transf. de VENCIDA O GESTION O MOROSA a CARTERA VIGENTE ---
         -- el importe es negativo --- saldo capital
         v_mto_trans := g_sal_tarjeta * -1;
         IF p_old_categoria = 2 THEN
            v_cod_tra_hij := 920;
            v_concepto    := 'TRANSF.CAP.VENC.A VIG.-PF';
         ELSIF p_old_categoria in (3,4) THEN
            v_cod_tra_hij := 933;
            v_concepto    := 'TRANSF.CAP.GEST.A VIG.-PF';
         ELSIF p_old_categoria IN (4, 5, 6) THEN
            v_cod_tra_hij := 936;
            v_concepto    := 'TRANSF.CAP.MORO.A VIG.-PF';
         END IF;
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      IF p_old_categoria IN (4, 5) AND p_new_categoria = 3 THEN
         -- De MOROSA A GESTION
         v_cod_tra_hij := 929;
         v_mto_trans   := g_sal_tarjeta * -1;
         v_concepto    := 'TRANSF.CAPITAL DE MOROSA A GESTION';
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      IF p_old_categoria = 3 AND p_new_categoria = 2 THEN
         -- De GESTION A VENCIDA
         v_cod_tra_hij := 926;
         v_mto_trans   := g_sal_tarjeta * -1;
         v_concepto    := 'TRANSF.CAPITAL DE GESTION A VENCIDA';
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                p_new_categoria);
      END IF;
      -- Agregado para establecer estado anterior y actual
      -- para evitar que se generen asientos de previsión y de cambio de estado
      -- cuando son iguales, como sucede con las categorías 3 y 4, y con 5 y 6.
      IF p_old_categoria = 1 THEN
         v_est_ant := 'C';
      ELSIF p_old_categoria = 2 THEN
         v_est_ant := 'V';
      ELSIF p_old_categoria = 3 THEN
         v_est_ant := 'G';
      ELSIF p_old_categoria IN (4, 5) THEN
         v_est_ant := 'M';
      ELSE
         v_est_ant := 'M';
      END IF;
      IF p_new_categoria = 1 THEN
         v_est_act := 'C';
      ELSIF p_new_categoria = 2 THEN
         v_est_act := 'V';
      ELSIF p_new_categoria = 3 THEN
         v_est_act := 'G';
      ELSIF p_new_categoria IN (4, 5) THEN
         v_est_act := 'M';
      ELSE
         v_est_act := 'M';
      END IF;
      -- GENERA ASIENTO X PREVISION --ojo verif si en el cierre se corre primero la categorizacion y
      -- despues el cambio de estado o sino no va a encontrar datos
      -- x estado anterior y nuevo
      IF v_est_ant <> v_est_act THEN
         v_mto_prevision := pat_imp.fu_obt_prevision(p_nro_cuenta);
         v_cod_tra_hij   := NULL;
         IF nvl(v_mto_prevision, 0) > 0 THEN
            v_mto_trans   := v_mto_prevision;
            v_cod_tra_hij := 944;
            v_concepto    := 'TRANSF. PREVISION EST.ANT';
            pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                   p_old_categoria);
            v_cod_tra_hij := 946;
            v_concepto    := 'TRANSFERENCIA DE PREVISION';
            pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                   p_new_categoria);
         END IF;
         v_cod_tra_hij := NULL;
         IF p_new_categoria = 1 THEN
            v_cod_tra_hij := 432;
         ELSIF p_new_categoria = 2 THEN
            v_cod_tra_hij := 433;
         ELSIF p_new_categoria = 3 THEN
            v_cod_tra_hij := 434;
         ELSIF p_new_categoria IN (4, 5) THEN
            v_cod_tra_hij := 436;
         END IF;
         --- genera cambio de estado de tarjetas ---------
         pat_imp.pr_ins_asiento(v_cod_tra_pad, v_cod_tra_hij, NULL, NULL, p_new_categoria);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         pat_imp.pr_log('Error en el proceso de seteo de transacciones para tarjetas ' ||
                        p_nro_cuenta || '. ' || SQLERRM);
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20292,
                                    'Error en el proceso de seteo de transacciones para tarjetas ' ||
                                     SQLERRM);
         END IF;
   END pr_pro_cam_est_tar;
   /* Actualizar la categoria de una tarjeta. */
   PROCEDURE pr_act_cat_tarjeta
   (
      p_nro_cuenta     IN ta_cta_tarjetas.nro_cuenta%TYPE,
      p_cat_automatica IN ta_cta_tarjetas.cat_automatica%TYPE
   ) IS
      v_existe NUMBER(1);
   BEGIN
      SELECT 1
        INTO v_existe
        FROM ta_cta_tarjetas
       WHERE nro_cuenta = p_nro_cuenta
         FOR UPDATE NOWAIT;

      UPDATE ta_cta_tarjetas
         SET cat_aut_anterior = cat_automatica,
             cat_automatica   = p_cat_automatica
       WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE = -54 THEN
            raise_application_error(-20000,
                                    'Reg. de tarjeta ' || p_nro_cuenta ||
                                     ' bloqueado por otro usuario');
         ELSIF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error('-20005', 'Actu. TA_CTA_TARJETAS cta ' || p_nro_cuenta);
         END IF;
   END pr_act_cat_tarjeta;
   /* Realizar asientos contables por el cambio de estado del prestamo. */
   PROCEDURE pr_ins_asiento
   (
      p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
      p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
      p_monto           IN ge_movimientos.monto%TYPE,
      p_concepto        IN ge_movimientos.concepto%TYPE,
      p_estado          IN ge_movimientos.est_cuenta%TYPE
   ) IS
      r_mvto     ge_movimientos%ROWTYPE;
      v_redondeo NUMBER(5);
      v_fec_actual date := pag_cal.fu_obt_fec_actual(6);
      v_usuario ba_usuarios.cod_usuario%type;      
      
   BEGIN
      r_log.nom_proceso := 'pat_imp.PR_INS_ASIENTO';
      r_log.fec_hor_ini := SYSDATE;    
     
    v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
    IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
       v_usu_secuencia(v_usuario) := 0;
       v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
    END IF;
    IF v_usu_secuencia(v_usuario) >= 995 THEN
        v_usu_secuencia(v_usuario) := 1;
        v_usu_hora(v_usuario)      :=  PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
    ELSE
        -- Se incrementa la secuencia del usuario
        v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
    END IF;
    
      r_mvto.nro_secuencia   := v_usu_secuencia(v_usuario);
      r_mvto.cod_usuario     := v_usuario;
      r_mvto.hora            := v_usu_hora(v_usuario);
      r_mvto.cod_modulo      := g_cod_modulo; --definir hijo
      r_mvto.cod_modalidad   := g_cod_modalidad; --definir hijo
      r_mvto.cod_oficina     := g_cod_oficina;
      r_mvto.nro_cuenta      := g_nro_cuenta;
      r_mvto.cod_moneda      := g_cod_moneda;
      r_mvto.cod_tra_padre   := p_cod_tra_padre;
      r_mvto.cod_transaccion := p_cod_transaccion;
      r_mvto.fecha           := c_fec_actual;
      r_mvto.fec_valor       := c_fec_actual;
      r_mvto.nro_documento   := NULL;
      r_mvto.monto           := p_monto;
      r_mvto.estado          := 'N';
      r_mvto.est_cuenta := (CASE
                              WHEN p_estado = '1' THEN
                               'C'
                              WHEN p_estado = '2' THEN
                               'V'
                              WHEN p_estado = '3' THEN
                               'G'
                              WHEN p_estado IN ('4', '5') THEN
                               'M'
                              ELSE
                               'M'
                           END);
      r_mvto.cod_ofi_origen  := g_cod_oficina;
      r_mvto.concepto        := p_concepto;
      r_mvto.reversado       := 'N';
      r_mvto.emi_aviso       := 'N';
      r_mvto.protegido       := 'N';
      r_mvto.cod_mod_padre   := g_cod_modulo;
      r_mvto.cod_mad_padre   := g_cod_modalidad;
      IF g_cod_moneda = c_mon_local THEN
         r_mvto.mto_equ_local := NULL;
         r_mvto.cotizacion    := NULL;
      ELSE
         v_redondeo           := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', g_cod_modulo,
                                                     g_cod_modalidad, c_mon_local);
         r_mvto.mto_equ_local := round(p_monto * g_cotizacion, v_redondeo);
         r_mvto.cotizacion    := g_cotizacion;
      END IF;
      pag_gen.pr_ins_ge_movimiento(r_mvto); --OJO
   EXCEPTION
      WHEN OTHERS THEN
         pat_imp.pr_log('Al insertar mvto. Cambio Situacion Tarjeta ' || g_nro_cuenta || '. ' ||
                        SQLERRM);
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20302,
                                    SQLERRM || ' Al insertar mvto. Cambio Situacion Tarjeta ' ||
                                     g_nro_cuenta);
         END IF;
   END pr_ins_asiento;
   /* Recupera monto prevision de ge_cla_operaciones. */
   FUNCTION fu_obt_prevision(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE) RETURN NUMBER IS
      v_prevision ge_cla_operaciones.tot_prevision%TYPE;
   BEGIN
      SELECT SUM(nvl(monto, 0))
        INTO v_prevision
        FROM ta_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha = (SELECT MAX(fecha)
                        FROM ta_previsiones
                       WHERE nro_cuenta = p_nro_cuenta
                         AND fecha <= pat_imp.c_fec_actual);
      RETURN nvl(v_prevision, 0);
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            raise_application_error(-20000, 'Recup. Prevision - Cta: ' || p_nro_cuenta);
         END IF;
   END fu_obt_prevision;

   PROCEDURE pr_pro_tarjeta IS
      v_oficina       NUMBER(3);
      v_contador      NUMBER := 0;
      v_fec_actual    DATE;
      v_fec_anterior  DATE;
      v_fec_siguiente DATE;
      v_anio_actual   NUMBER(4);
      v_mes_actual    NUMBER(2);
      v_mes_siguiente NUMBER(2);
      v_dif_dias      NUMBER;
      v_dif_meses     NUMBER;
      v_posicion      NUMBER(2) := 0;
      CURSOR cuentas IS
         SELECT c.cod_modulo,
                c.cod_modalidad,
                c.cod_oficina,
                c.nro_cuenta,
                t.sal_facturar,
                t.sal_financiado,
                t.sal_facturado
           FROM ge_cta_clientes c, ta_cta_tarjetas t
          WHERE c.nro_cuenta = t.nro_cuenta
            AND c.relacion = 'P'
            AND t.estado <> 'C';
   BEGIN
      BEGIN
         SELECT cod_oficina INTO v_oficina FROM ba_usuarios WHERE cod_usuario = USER;
      EXCEPTION
         WHEN OTHERS THEN
            v_oficina := NULL;
      END;
      v_posicion      := 1;
      v_fec_actual    := pag_cal.fu_obt_fec_actual(5);
      v_fec_anterior  := pag_cal.fu_obt_fec_ant_hab(v_fec_actual, v_oficina);
      v_fec_siguiente := pag_cal.fu_obt_fec_sig_hab(v_fec_actual, v_oficina);
      ---------------------------------------------------------------
      --  para probar con otra fecha y no modificar el calendario  --
      --  v_fec_actual    := to_date( '08/11/2005', 'DD/MM/RRRR' );
      --  v_fec_siguiente := to_date( '07/11/2005', 'DD/MM/RRRR' );
      --  v_fec_anterior  := to_date( '09/11/2005', 'DD/MM/RRRR' );
      -----------------------------------------------
      v_posicion      := 2;
      v_mes_actual    := to_char(v_fec_actual, 'MM');
      v_anio_actual   := to_char(v_fec_actual, 'RRRR');
      v_mes_siguiente := to_char(v_fec_siguiente, 'MM');
      ------------------------------------------------------------------
      v_posicion := 3;
      FOR x IN cuentas LOOP
         v_contador := nvl(v_contador, 0) + 1;
         v_posicion := 4;
         IF v_mes_siguiente <> v_mes_actual THEN
            v_dif_dias  := (last_day(v_fec_actual) - v_fec_anterior);
            v_dif_meses := to_number(to_char(v_fec_siguiente, 'DD')) - 1;
         ELSE
            v_dif_dias  := v_fec_siguiente - v_fec_actual;
            v_dif_meses := 0;
         END IF;
         --- MODIFICA SALDOS PROMEDIOS DEL MES DE LA FECHA ANTERIOR ----
         v_posicion := 5;
         BEGIN
            UPDATE ta_sal_mensuales
               SET acu_sal_financiado = nvl(acu_sal_financiado, 0) + x.sal_financiado * v_dif_dias,
                   acu_sal_facturado  = nvl(acu_sal_facturado, 0) + x.sal_facturado * v_dif_dias,
                   acu_sal_facturar   = nvl(acu_sal_facturar, 0) + x.sal_facturar * v_dif_dias,
                   can_dia_acumulado  = nvl(can_dia_acumulado, 0) + v_dif_dias
             WHERE cod_oficina = x.cod_oficina
               AND nro_cuenta = x.nro_cuenta
               AND ano = v_anio_actual
               AND mes = v_mes_actual;
            ------------------------------------------------------------
            -- si no encontro genera un nuevo registro para la cuenta --
            ------------------------------------------------------------
            IF SQL%NOTFOUND THEN
               v_posicion := 6;
               BEGIN
                  INSERT INTO ta_sal_mensuales
                     (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, ano, mes, sal_financiado,
                      sal_facturado, sal_facturar, acu_sal_financiado, acu_sal_facturado,
                      acu_sal_facturar, can_dia_acumulado)
                  VALUES
                     (x.cod_modulo, x.cod_modalidad, x.cod_oficina, x.nro_cuenta, v_anio_actual,
                      v_mes_actual, x.sal_financiado, x.sal_facturado, x.sal_facturar,
                      x.sal_financiado * v_dif_dias, x.sal_facturado * v_dif_dias,
                      x.sal_facturar * v_dif_dias, v_dif_dias);
               EXCEPTION
                  WHEN OTHERS THEN

                     NULL;
               END;
            END IF;
         END;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20251,
                                 'El ultimo numero de tarjeta ejecutado es ' || to_char(v_posicion) || '. ' ||
                                  SQLERRM);
   END pr_pro_tarjeta;
   /* Inserta la persona con los datos recibidos de cada Procesadora */
   PROCEDURE pr_ins_persona
   (
      p_administradora IN ge_entes.cod_ente%TYPE,
      p_nro_documento  IN ba_personas.nro_documento%TYPE,
      p_tip_documento  IN ba_personas.cod_tip_documento%TYPE,
      p_nombre         IN ba_personas.nom_completo%TYPE,
      p_fec_nacimiento IN ba_per_fisicas.fec_nacimiento%TYPE,
      p_cod_sexo       IN ba_per_fisicas.cod_sexo%TYPE,
      p_est_civil      IN ba_per_fisicas.est_civil%TYPE,
      p_cod_promotor   IN ba_personas.cod_usu_promotor%TYPE,
      p_cod_persona    IN OUT ba_per_fisicas.cod_persona%TYPE,
      p_ok             OUT BOOLEAN
   ) IS
      c_bancard CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_BANCARD');
      c_procard CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_PROCARD');
      c_bepsa   CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_BEPSA');
      c_cabal   CONSTANT NUMBER(5) := fug_obt_pardinamico('COD_PRO_CABAL');
      r_persona   ba_personas%ROWTYPE;
      r_per_fis   ba_per_fisicas%ROWTYPE;
      r_per_jur   ba_per_juridicas%ROWTYPE;
      r_log       ta_logs%ROWTYPE;
      v_cod       ba_personas.cod_persona%TYPE;
      v_ok        BOOLEAN;
      v_nombre    VARCHAR2(200);
      v_apellido  VARCHAR2(200);
      v_est_civil VARCHAR2(1);
      v_cod_sexo  VARCHAR2(1);
      v_tipo      VARCHAR2(1);
      /*insertar la persona*/
      PROCEDURE lp_ins_ba_personas
      (
         p_reg IN ba_personas%ROWTYPE,
         p_cod IN OUT ba_personas.cod_persona%TYPE,
         p_ok  OUT BOOLEAN
      ) IS
      BEGIN
         p_ok := FALSE;
         BEGIN
            SELECT s_cod_persona.nextval INTO p_cod FROM dual;
         EXCEPTION
            WHEN OTHERS THEN
               pat_imp.pr_log('LP_INS_BA_PERSONAS: Al buscar el siguiente codigo de persona con nro. de documento ' ||
                              to_char(p_nro_documento) || '. ' || SQLERRM);
               --raise;
         END;
         BEGIN
            INSERT INTO ba_personas
               (cod_persona, nom_completo, tipo, cod_usu_promotor, cod_tip_documento, nro_documento,
                cod_pais, cod_actividad, cod_rub_primario)
            VALUES
               (p_cod, p_reg.nom_completo, p_reg.tipo, p_reg.cod_usu_promotor,
                p_reg.cod_tip_documento, p_reg.nro_documento, p_reg.cod_pais, p_reg.cod_actividad,
                p_reg.cod_rub_primario);
         EXCEPTION
            WHEN OTHERS THEN
               pat_imp.pr_log('LP_INS_BA_PERSONAS: Al insertar la Persona ' || p_cod ||
                              ' con nro. de documento ' || to_char(p_nro_documento) || '. ' ||
                              SQLERRM);
         END;
         p_ok := TRUE;
      EXCEPTION
         WHEN OTHERS THEN
            pat_imp.pr_log('LP_INS_BA_PERSONAS: Error desconocido, para la persona ' || p_cod ||
                           ' con nro. de documento ' || to_char(p_nro_documento) || '. ' ||
                           SQLERRM);
      END lp_ins_ba_personas;
      /* Insertar persona fisica */
      PROCEDURE lp_ins_ba_per_fisicas
      (
         p_cod IN ba_per_fisicas.cod_persona%TYPE,
         p_fis IN ba_per_fisicas%ROWTYPE,
         p_ok  OUT BOOLEAN
      ) IS
      BEGIN
         p_ok := FALSE;
         INSERT INTO ba_per_fisicas
            (cod_persona, pri_nombre, pri_apellido, est_civil, cod_sexo, cod_pai_nacionalidad,
             fec_nacimiento)
         VALUES
            (p_cod, p_fis.pri_nombre, p_fis.pri_apellido, nvl(p_fis.est_civil, 'S'),
             nvl(p_fis.cod_sexo, 'M'), p_fis.cod_pai_nacionalidad, p_fis.fec_nacimiento);
         p_ok := TRUE;
      EXCEPTION
         WHEN OTHERS THEN
            pat_imp.pr_log('LP_INS_BA_PER_FISICAS: Al insertar la persona ' || p_cod ||
                           ' con nro. de documento ' || to_char(p_nro_documento) || '. ' ||
                           SQLERRM);
      END lp_ins_ba_per_fisicas;

      /* Insertar persona juridica */
      PROCEDURE lp_ins_ba_per_juridicas
      (
         p_cod IN ba_per_juridicas.cod_persona%TYPE,
         p_jur IN ba_per_juridicas%ROWTYPE,
         p_ok  OUT BOOLEAN
      ) IS
      BEGIN
         p_ok := FALSE;
         INSERT INTO ba_per_juridicas
            (cod_persona, raz_social, nom_comercial, fec_apertura)
         VALUES
            (p_cod, p_jur.raz_social, p_jur.nom_comercial, p_jur.fec_apertura);
         p_ok := TRUE;
      EXCEPTION
         WHEN OTHERS THEN
            pat_imp.pr_log('LP_INS_BA_PER_JURIDICAS: Al insertar la persona ' || p_cod ||
                           ' con nro. de documento ' || to_char(p_nro_documento) || '. ' ||
                           SQLERRM);
            --raise;
      END lp_ins_ba_per_juridicas;

   BEGIN
      p_ok              := FALSE;
      r_log.nom_proceso := 'pat_imp.PR_INS_PERSONA';
      r_log.fec_hor_ini := SYSDATE;
      --verifica si es cedula o ruc
      IF to_char(p_nro_documento) > 80000000 THEN
         v_tipo := 'J';
      ELSE
         v_tipo := 'F';
      END IF;


      IF nvl(instr(p_nombre, ',', 1, 1), 0) > 0 AND v_tipo = 'F' THEN
         v_nombre   := upper(TRIM(substr(p_nombre, instr(p_nombre || ',', ',', 1, 1) + 1)));
         v_apellido := upper(TRIM(substr(p_nombre, 1, (instr(p_nombre || ',', ',', 1, 1) - 1))));
      ELSIF nvl(instr(TRIM(p_nombre), ' ', 1, 3), 0) > 0 AND v_tipo = 'F' THEN
         v_apellido := upper(TRIM(substr(p_nombre, 1, instr(p_nombre, ' ', 1, 2) - 1)));
         v_nombre   := upper(TRIM(substr(p_nombre, instr(p_nombre, ' ', 1, 2) + 1)));
      ELSIF nvl(instr(TRIM(p_nombre), ' ', 1, 2), 0) > 0 AND v_tipo = 'F' THEN
         v_apellido := upper(TRIM(substr(p_nombre, 1, instr(p_nombre, ' ', 1, 1) - 1)));
         v_nombre   := upper(TRIM(substr(p_nombre, instr(p_nombre, ' ', 1, 1) + 1)));
      ELSE
         v_nombre := upper(TRIM(p_nombre));
         IF v_tipo = 'F' THEN
            v_apellido := 'VERIFICAR';
         END IF;
      END IF;
      IF (v_nombre IS NULL OR v_apellido IS NULL) AND v_tipo = 'F' THEN
         pat_imp.pr_log('La Persona ' || p_cod_persona || ' tuvo error con el nombre ' || p_nombre,
                        FALSE);
      END IF;
      IF v_nombre IS NULL THEN
         v_nombre := 'VERIFICAR';
      END IF;
      IF v_apellido IS NULL THEN
         v_apellido := 'VERIFICAR';
      END IF;
      IF nvl(p_administradora, 0) = nvl(c_bancard, 0) THEN
         /*
         || Setea el estado civil
         */
         IF nvl(p_est_civil, ' ') = '1' THEN
            -- Soltero/a
            v_est_civil := 'S';
         ELSIF nvl(p_est_civil, ' ') = '2' THEN
            -- Casado/a
            v_est_civil := 'C';
         ELSIF nvl(p_est_civil, ' ') = '3' THEN
            -- Divorciado/a
            v_est_civil := 'D';
         ELSIF nvl(p_est_civil, ' ') = '4' THEN
            -- Viudo/a
            v_est_civil := 'V';
         ELSIF nvl(p_est_civil, ' ') = '9' THEN
            -- No definido
            v_est_civil := 'S';
         ELSE
            -- Error
            v_est_civil := 'O';
         END IF;
         /*
         || Setea el Sexo
         */
         IF nvl(p_cod_sexo, ' ') = '0' THEN
            v_cod_sexo := 'M';
         ELSIF nvl(p_cod_sexo, ' ') = '1' THEN
            v_cod_sexo := 'F';
         ELSE
            v_cod_sexo := 'M';
         END IF;
      ELSIF nvl(p_administradora, 0) = nvl(c_procard, 0) THEN
         /*
         || OJO - FALTA SETEAR !!!!!
         */
         v_est_civil := 'O';
         v_cod_sexo  := 'M';
      ELSIF nvl(p_administradora, 0) IN (nvl(c_bepsa, 0), nvl(c_cabal, 0)) THEN
         v_est_civil := p_est_civil;
         v_cod_sexo  := p_cod_sexo;
      END IF;
      -- Datos para la persona
      r_persona.nom_completo      := p_nombre;
      r_persona.nro_documento     := p_nro_documento;
      r_persona.cod_tip_documento := p_tip_documento;
      r_persona.tipo              := v_tipo;
      r_persona.cod_usu_promotor  := p_cod_promotor;
      IF g_tip_implementacion IN (2, 3) THEN
         r_persona.cod_pais := 586;
      ELSE
         r_persona.cod_pais := 1;
      END IF;
      /*  || Inserta las tablas BA_PERSONAS y BA_PER_FISICAS  */
      v_ok  := FALSE;
      v_cod := NULL;
      r_persona.cod_actividad    := fug_obt_pardinamico('GEN_COD_ACTIVIDAD');
      r_persona.cod_rub_primario := fug_obt_pardinamico('GEN_COD_RUB_PRIMARIO');
      lp_ins_ba_personas(r_persona, v_cod, v_ok);
      IF v_ok THEN
         IF v_tipo = 'F' THEN
            -- Datos para la persona Fisica
            r_per_fis.pri_nombre           := substr(v_nombre, 1, 30);
            r_per_fis.pri_apellido         := substr(v_apellido, 1, 30);
            r_per_fis.fec_nacimiento       := p_fec_nacimiento;
            r_per_fis.est_civil            := v_est_civil;
            r_per_fis.cod_sexo             := v_cod_sexo;
            r_per_fis.cod_pai_nacionalidad := r_persona.cod_pais;
            lp_ins_ba_per_fisicas(v_cod, r_per_fis, v_ok);
         ELSE
            -- Datos para la persona Fisica
            r_per_jur.raz_social    := substr(v_nombre, 1, 120);
            r_per_jur.nom_comercial := substr(v_nombre, 1, 65);
            r_per_jur.fec_apertura  := p_fec_nacimiento;
            lp_ins_ba_per_juridicas(v_cod, r_per_jur, v_ok);
         END IF;
         IF NOT v_ok THEN
            pat_imp.pr_log('No se creo la persona fisica/juridica ' || v_cod);
            RAISE no_data_found;
         ELSE
            BEGIN
               INSERT INTO ge_clientes
                  (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial, cli_especial,
                   residente, cod_sec_contable, cod_tip_deudor, cod_seg_cliente)
               VALUES
                  (v_cod, 1, 'N',
                   nvl(fug_obt_pardinamico('GEN_COD_OFICIAL'),
                        fug_obt_pardinamico('COD_USU_OFI_DEFECTO')), 'N', 'S', 'N', 2,
                   nvl(fug_obt_pardinamico('GEN_COD_SEG_CLIENTE'), 12)); --segmento del cliente x defecto('Personales'), el oficial debe modificar despues
            EXCEPTION
               WHEN OTHERS THEN
                  pat_imp.pr_log('No se inserto el cliente ' || v_cod || ', documento ' ||
                                 p_nro_documento);
                  RAISE no_data_found;
            END;
         END IF;
      ELSE
         pat_imp.pr_log('No se creo la persona ' || v_cod || ', documento ' || p_nro_documento);
         RAISE no_data_found;
      END IF;
      p_cod_persona := v_cod;
      p_ok          := v_ok;
   EXCEPTION
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            pat_imp.pr_log('Error fuera del procedimiento.');
            RAISE;
         ELSE
            pat_imp.pr_log('Error proced. para persona con nro. de documento ' ||
                           to_char(p_nro_documento) || '. ' || SQLERRM);
            --raise;
         END IF;
   END pr_ins_persona;
   /* Inserta los datos de nuevas sucursales para una procesadora determinada */
   PROCEDURE pr_ins_sucursal
   (
      p_cod_procesadora IN ta_sucursales.cod_ent_procesadora%TYPE,
      p_cod_sucursal    IN ta_sucursales.cod_sucursal%TYPE
   ) IS
      r_log ta_logs%ROWTYPE;
   BEGIN
      r_log.nom_proceso := 'PRT_IMP.PR_INS_SUCURSAL';
      r_log.fec_hor_ini := SYSDATE;
      --  r_log.nro_reg := 0;
      INSERT INTO ta_sucursales
         (cod_ent_procesadora, cod_sucursal, descripcion, abreviatura, cod_oficina, activo)
      VALUES
         (p_cod_procesadora, p_cod_sucursal, 'Insertado Automaticamente por Proceso', 'IAP', 1, 'S');
   EXCEPTION
      WHEN OTHERS THEN
         r_log.fec_hor_fin := SYSDATE;
         --    r_log.comentario := 'Al insertar la sucursal ' || to_char( p_cod_sucursal ) || ' de la procesadora ' ||
         --                        to_char( p_cod_procesadora );
         pat_imp.pr_log('Al insertar la sucursal ' || to_char(p_cod_sucursal) ||
                        ' de la procesadora ' || to_char(p_cod_procesadora) || '. ' || SQLERRM);
         --    prt_ins_log( r_log );
   END pr_ins_sucursal;

   FUNCTION fu_val_numero(p_dato VARCHAR2) RETURN NUMBER IS
      v_nro NUMBER;
   BEGIN
      BEGIN
         IF fue_val_es_numerico(substr(p_dato, -1)) = 'N' THEN
            v_nro := translate(p_dato, 'JKLMNOPQR}', '1234567890');
            v_nro := v_nro * -1;
         ELSE
            v_nro := p_dato;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_nro := 0;
      END;
      RETURN v_nro;
   END fu_val_numero;
   PROCEDURE pr_ver_errores IS
      v_cantidad NUMBER(10);
   BEGIN
      BEGIN
         SELECT COUNT(*) INTO v_cantidad FROM ta_logs WHERE comentario NOT LIKE '***%***';
      EXCEPTION
         WHEN OTHERS THEN
            v_cantidad := 0;
      END;
      IF nvl(v_cantidad, 0) > 0 THEN
         raise_application_error(-20111,
                                 'Se produjeron ' || to_char(v_cantidad) ||
                                  ' errores durante los procesos ejecutados.' || chr(10) ||
                                  'Verifique la tabla TA_LOGS para obtener mas detalles.');
      END IF;
   END pr_ver_errores;
   /* Inserta el registro de Log en la tabla TA_LOGS */
   PROCEDURE pr_log
   (
      p_mensaje ta_logs.comentario%TYPE,
      p_error   BOOLEAN DEFAULT TRUE
   ) IS
   BEGIN
      r_log.fec_hor_fin := SYSDATE;
      r_log.nro_reg     := g_nro_reg;
      r_log.comentario  := p_mensaje;
      -- Agregado para hacer Test.
      IF p_error THEN
         dbms_output.put_line(r_log.nro_reg);
         dbms_output.put_line(r_log.comentario);
         dbms_output.put_line(SQLERRM);
      ELSE
         dbms_output.put_line(r_log.comentario);
      END IF;
      prt_ins_log(r_log, p_error);
   EXCEPTION
      WHEN OTHERS THEN
         prt_ins_log(r_log, p_error);
   END pr_log;


   /* Verifica que no se hayan producido errores, en la tabla TA_LOGS */
   PROCEDURE pr_ver_log IS
      v_cont NUMBER(10) := 0;
   BEGIN
      BEGIN
         SELECT COUNT(*)
           INTO v_cont
           FROM ta_logs
          WHERE comentario NOT LIKE '***%***'
            and trunc(fec_hor_ini) = trunc(sysdate); --en la fecha
      EXCEPTION
         WHEN OTHERS THEN
            v_cont := 1;
      END;
      IF nvl(v_cont, 0) > 0 THEN
         raise_application_error(-20110,
                                 'Los procesos ejecutados han producido errores. Verifique la tabla de Logs.');
      END IF;
   END pr_ver_log;

/* Inicializa la tabla TA_LOGS */

   PROCEDURE pr_bor_log IS
      v_fec_elim     DATE;
      v_reg_elim     NUMBER := 0 ;
      v_nro_error    NUMBER := 3;
      v_men_error    VARCHAR(2000) := 'INFO';
      i DATE;

     BEGIN

      r_log.nom_proceso := 'pat_imp.PR_BOR_LOG';
      r_log.fec_hor_ini := SYSDATE;
      r_log.nro_reg     := g_nro_reg;
      i := SYSDATE;

       v_fec_elim := trunc(SYSDATE) - 30;  -- Se eliminarán los registros de 30 días para atras

         pat_imp.pr_ins_log_inf(v_nro_error , v_men_error ,'*** Iniciando el proceso a las ' || to_char(i, 'HH24:MI:SS') || ' ***');

      -- Elimino los registros de TA_LOGS con fecha menor a la fecha límite

         DELETE TA_LOGS
         WHERE fec_insercion  < v_fec_elim;

        /* ASIGNO VALOR A LA VARIABLE QUE VA A REGISTRAR LOS REGISTROS ELIMINADOS */

          v_reg_elim := SQL%ROWCOUNT;

       -- COMMIT;

       /* Registro en el log la cantidad de registros eliminados  */

          IF v_reg_elim > 0 THEN

              pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , 'Se han eliminado ' ||  v_reg_elim || ' registros de la tabla TA_LOGS');

          ELSE

              pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , 'No se encontraron registros para eliminar en TA_LOGS para la fecha ' ||  v_fec_elim );

          END IF;

           /* Fin del proceso */

          pat_imp.pr_ins_log_inf(v_nro_error , v_men_error , '*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||  ' ***');



   END pr_bor_log;

   /* Actualiza la fecha de ultimo proceso de la cuenta */
   PROCEDURE pr_act_ult_pro
   (
      p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
      p_fec_actual DATE
   ) IS
      c_parametro CONSTANT VARCHAR2(30) := 'FEC_ULT_PRO_TARJETA';
      v_tmp VARCHAR2(30);
   BEGIN
      r_log.nom_proceso := 'PRT_IMP.PR_ACT_ULT_PRO';
      r_log.fec_hor_ini := SYSDATE;
      r_log.nro_reg     := 0;
      BEGIN
         SELECT 'S' INTO v_tmp FROM ta_cta_tarjetas WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN OTHERS THEN
            v_tmp := 'N';
      END;
      IF nvl(v_tmp, 'N') = 'S' THEN
         BEGIN
            SELECT nvl(val_parametro, to_char(SYSDATE, 'DD/MM/YYYY'))
              INTO v_tmp
              FROM ge_cta_dat_adicionales
             WHERE nro_cuenta = p_nro_cuenta
               AND parametro = c_parametro;
         EXCEPTION
            WHEN no_data_found THEN
               v_tmp := NULL;
            WHEN OTHERS THEN
               pat_imp.pr_log('Error al verificar si existe el valor del parametro para la cuenta ' ||
                              p_nro_cuenta || '. ' || SQLERRM);
         END;
         IF v_tmp IS NOT NULL THEN
            BEGIN
               UPDATE ge_cta_dat_adicionales
                  SET val_parametro = to_char(p_fec_actual, 'DD/MM/YYYY')
                WHERE nro_cuenta = p_nro_cuenta
                  AND parametro = c_parametro;
               IF SQL%NOTFOUND THEN
                  RAISE no_data_found;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  pat_imp.pr_log('Error al actualizar el valor del parametro para la cuenta ' ||
                                 p_nro_cuenta || '. ' || SQLERRM);
            END;
         ELSE
            BEGIN
               INSERT INTO ge_cta_dat_adicionales
                  (nro_cuenta, parametro, val_parametro)
               VALUES
                  (p_nro_cuenta, c_parametro, to_char(p_fec_actual, 'DD/MM/YYYY'));
            EXCEPTION
               WHEN OTHERS THEN
                  pat_imp.pr_log('Error al insertar el valor del parametro para la cuenta ' ||
                                 p_nro_cuenta || '. ' || SQLERRM);
            END;
         END IF;
      END IF;
   END pr_act_ult_pro;
   /* Cancela las cuentas que no vienieron de la procesadora */
   PROCEDURE pr_pro_can_cta IS
      c_fec_actual CONSTANT DATE := pag_cal.fu_obt_fec_actual(5);
      c_parametro  CONSTANT VARCHAR2(30) := 'FEC_ULT_PRO_TARJETA';
      CURSOR cuentas IS
         SELECT t.nro_cuenta,
                nvl(to_date(d.val_parametro, 'DD/MM/YYYY'), c_fec_actual - 2) val_parametro
           FROM ta_cta_tarjetas t, ge_cta_dat_adicionales d
          WHERE t.nro_cuenta = d.nro_cuenta(+)
            AND t.estado <> 'C'
            AND d.parametro(+) = c_parametro
          ORDER BY t.nro_cuenta;
   BEGIN
      FOR c IN cuentas LOOP
         IF c.val_parametro < c_fec_actual THEN
            BEGIN
               UPDATE ta_cta_tarjetas
                  SET dia_mora           = 0,
                      mto_mora           = 0,
                      mto_autorizaciones = 0,
                      mto_gas_mora       = 0,
                      mto_int_compras    = 0,
                      mto_pag_mes        = 0,
                      mto_pag_minimo     = 0,
                      sal_cuo_pendientes = 0,
                      sal_facturado      = 0,
                      sal_facturar       = 0,
                      sal_financiado     = 0,
                      sal_pag_minimo     = 0,
                      sal_ult_extracto   = 0,
                      estado             = 'C'
                WHERE nro_cuenta = c.nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20110,
                                          'No se pudo cancelar la cuenta ' || c.nro_cuenta || '; ' ||
                                           SQLERRM);
            END;
         END IF;
      END LOOP;
      COMMIT;
   END pr_pro_can_cta;
   /* Verifica que exista la relaci{on  de la cuenta con el cliente */
   FUNCTION fu_exi_cta_cli
   (
      p_nro_cuenta  ge_cuentas.nro_cuenta%TYPE,
      p_cod_persona ba_personas.cod_persona%TYPE
   ) RETURN BOOLEAN IS
      v_existe VARCHAR2(1) := 'N';
   BEGIN
      r_log.nom_proceso := 'pat_imp.FU_EXI_CTA_CLI';
      r_log.fec_hor_ini := SYSDATE;
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_cta_clientes
          WHERE cod_persona = p_cod_persona
            AND nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            v_existe := 'N';
         WHEN too_many_rows THEN
            v_existe := 'S';
         WHEN OTHERS THEN
            pat_imp.pr_log('ERROR. Al verificar la relacion del cliente ' || p_cod_persona ||
                           ' con la cuenta ' || p_nro_cuenta || '; ' || SQLERRM);
      END;
      IF nvl(v_existe, 'N') = 'S' THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END fu_exi_cta_cli;
   /* Devuelve el valor para CI y RUC de la tabla de tipos de documentos */
   PROCEDURE pr_obt_documentos
   (
      p_cod_ci  OUT NUMBER,
      p_cod_ruc OUT NUMBER,
      p_cod_pas OUT NUMBER,
      p_cod_dni OUT NUMBER,
      p_cod_cad OUT NUMBER,
      p_cod_cie OUT NUMBER,
      p_cod_crc OUT NUMBER
   ) IS
      v_cod_ci  NUMBER;
      v_cod_ruc NUMBER;
      v_cod_pas NUMBER;
      v_cod_dni NUMBER;
      v_cod_cad NUMBER;
      v_cod_cie NUMBER;
      v_cod_crc NUMBER;
   BEGIN
      -- Busca el codigo de documento para Cedula de Identidad
      BEGIN
         SELECT MIN(cod_tip_documento)
           INTO v_cod_ci
           FROM ba_tip_documentos
          WHERE tip_persona IN ('F', 'A')
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_ci := 1;
      END;
      -- Busca el codigo de documento para Pasaporte
      BEGIN
         SELECT DISTINCT cod_tip_documento
           INTO v_cod_pas
           FROM ba_tip_documentos
          WHERE tip_persona IN ('F', 'A')
            AND descripcion LIKE 'PASAPORTE%'
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_pas := 1;
      END;
      -- Busca el codigo de documento para D.N.I.
      BEGIN
         SELECT DISTINCT cod_tip_documento
           INTO v_cod_dni
           FROM ba_tip_documentos
          WHERE tip_persona IN ('F', 'A')
            AND abreviatura = 'DNI'
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_dni := 1;
      END;
      -- Busca el codigo de documento para Cedula Identidad Extranjera
      BEGIN
         SELECT DISTINCT cod_tip_documento
           INTO v_cod_cie
           FROM ba_tip_documentos
          WHERE tip_persona IN ('F', 'A')
            AND abreviatura IN ('CIE')
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_cie := 1;
      END;
      -- Busca el codigo de documento para Cedula Identidad Extranjera
      BEGIN
         SELECT DISTINCT cod_tip_documento
           INTO v_cod_crc
           FROM ba_tip_documentos
          WHERE tip_persona IN ('F', 'A')
            AND abreviatura IN ('CRC')
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_cie := 1;
      END;
      -- Busca el codigo de Certificado de Admision Permanente
      BEGIN
         SELECT DISTINCT cod_tip_documento
           INTO v_cod_cad
           FROM ba_tip_documentos
          WHERE tip_persona IN ('F', 'A')
            AND abreviatura = 'CRP'
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_cad := 1;
      END;
      -- Busca el codigo de documento para RUC
      BEGIN
         SELECT MIN(cod_tip_documento)
           INTO v_cod_ruc
           FROM ba_tip_documentos
          WHERE tip_persona IN ('J', 'A')
            AND nvl(estado, 'A') <> 'I';
      EXCEPTION
         WHEN OTHERS THEN
            v_cod_ruc := 1;
      END;
      p_cod_ci  := v_cod_ci;
      p_cod_ruc := v_cod_ruc;
      p_cod_pas := v_cod_pas;
      p_cod_dni := v_cod_dni;
      p_cod_cad := v_cod_cad;
      p_cod_cie := v_cod_cie;
      p_cod_crc := v_cod_crc;
   END;
   /* Devuelve el numero de documento recibido SIN los ceros adelante */
   FUNCTION fu_con_documento
   (
      p_nro_documento IN VARCHAR2,
      p_mensaje       OUT VARCHAR2
   ) RETURN VARCHAR2 IS
      v_nro_doc VARCHAR2(50);
      v_mensaje VARCHAR2(2000);
   BEGIN
      BEGIN
         v_nro_doc := to_char(to_number(p_nro_documento));
      EXCEPTION
         WHEN invalid_number OR value_error THEN
            DECLARE
               v_temp VARCHAR2(50) := p_nro_documento;
            BEGIN
               FOR i IN 1 .. length(v_temp) LOOP
                  IF substr(v_temp, i, 1) <> '0' THEN
                     v_nro_doc := substr(v_temp, i);
                     EXIT;
                  END IF;
               END LOOP;
            EXCEPTION
               WHEN OTHERS THEN
                  v_mensaje := 'Error al procesar el documento ' || p_nro_documento || '; ' ||
                               SQLERRM;
            END;
         WHEN OTHERS THEN
            v_mensaje := 'Error al convertir el documento ' || p_nro_documento || '; ' || SQLERRM;
      END;
      IF v_mensaje IS NOT NULL THEN
         p_mensaje := v_mensaje;
      END IF;
      RETURN v_nro_doc;
   END fu_con_documento;
   /* Setea las tarjetas para dejar una sola como VIGENTE */
   PROCEDURE pr_pro_set_vigente IS
      CURSOR c_no_vigentes IS
         SELECT nro_cuenta
           FROM ta_cta_tarjetas a
          WHERE a.estado NOT IN ('C', 'I')
            AND nvl(instr(','||fug_obt_pardinamico('MAD_TAR_BANCARD')||',', ','||cod_modalidad||','),0) > 0
            AND NOT EXISTS (SELECT 1
                              FROM ta_tarjetas b
                             WHERE a.nro_cuenta = b.nro_cuenta
                               AND b.vigente = 'S');
   BEGIN
     r_log.nom_proceso := 'pat_imp.PR_PRO_SET_VIGENTE';
     r_log.fec_hor_ini := SYSDATE;

     pat_imp.pr_ins_log_error('*** Iniciando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                               ' ***', FALSE);
      FOR i IN c_no_vigentes LOOP
         UPDATE ta_tarjetas t
            SET t.vigente = 'S'
          WHERE t.nro_cuenta = i.nro_cuenta
            AND ((t.fec_vencimiento = (SELECT MAX(a.fec_vencimiento)
                                         FROM ta_tarjetas a
                                        WHERE a.nro_cuenta = i.nro_cuenta)
                  --Si es una Regrabación mantiene la fecha de vencimiento
                  --Se agrega para que valide por la fecha de emisión de la misma para que no de error
                  AND t.fec_emision = (SELECT MAX(x.fec_emision)
                                         FROM ta_tarjetas x
                                        WHERE x.nro_cuenta = i.nro_cuenta))
              OR (t.fec_emision = (SELECT b.fec_emision
                                     FROM ta_tarjetas b
                                    WHERE b.fec_vencimiento < (SELECT MAX(c.fec_vencimiento)
                                                                 FROM ta_tarjetas c
                                                                WHERE c.nro_cuenta = i.nro_cuenta)
                                      --Si la emision es la máxima y el vencimiento es menor
                                      AND b.fec_emision = (SELECT MAX(x.fec_emision)
                                                             FROM ta_tarjetas x
                                                            WHERE x.nro_cuenta = i.nro_cuenta)
                                      AND b.nro_cuenta= i.nro_cuenta
                                      AND rownum = 1)));

      END LOOP;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN OTHERS THEN
         pat_imp.pr_log('ITC-00002: Al actualizar la vigencia de las tarjetas.' || SQLERRM);
   END pr_pro_set_vigente;

    PROCEDURE pr_pro_set_vig_procard IS
      CURSOR c_no_vigentes IS
         SELECT nro_cuenta
           FROM ta_cta_tarjetas a
          WHERE a.estado NOT IN ('C', 'I')
            AND nvl(instr(','||fug_obt_pardinamico('MAD_TAR_BANCARD')||',', ','||cod_modalidad||','),0) = 0
            /*AND NOT EXISTS (SELECT 1
                              FROM ta_tarjetas b
                             WHERE a.nro_cuenta = b.nro_cuenta
                               AND b.vigente = 'S')*/;
   BEGIN
     r_log.nom_proceso := 'pat_imp.PR_PRO_SET_VIG_PROCARD';
     r_log.fec_hor_ini := SYSDATE;


     pat_imp.pr_ins_log_error('*** Iniciando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                               ' ***', FALSE);
      /*
  || Primero pone como NO VIGENTE todas las tarjetas, para luego actualizar la vigencia de las
  || tarjetas y dejar siempre UNA SOLA tarjeta vigente.
  */
  BEGIN
     UPDATE ta_tarjetas
         SET vigente = 'N'
       WHERE nro_cuenta IN
             (SELECT nro_cuenta FROM ta_cta_tarjetas a
               WHERE a.estado NOT IN ('I')
              -- a.estado NOT IN ('C', 'I')
               AND nvl(instr(','||fug_obt_pardinamico('MAD_TAR_BANCARD')||',', ','||cod_modalidad||','),0) = 0);

       EXCEPTION
    when others then
      pat_imp.pr_log( 'ITC-00001: Al inicializar la vigencia de las tarjetas.'||SQLERRM );
  END;
      FOR i IN c_no_vigentes LOOP
         UPDATE ta_tarjetas t
            SET t.vigente = 'S'
          WHERE t.nro_cuenta = i.nro_cuenta
            and cod_estado not in ('10')
            and t.fec_emision =
                (SELECT MAX(x.fec_emision)
                   FROM ta_tarjetas x
                  WHERE x.nro_cuenta = i.nro_cuenta)
            and (((select count(*)
                     from ta_tarjetas a
                    where a.nro_cuenta = i.nro_cuenta
                      and a.fec_emision =
                          (SELECT MAX(x.fec_emision)
                             FROM ta_tarjetas x
                            WHERE x.nro_cuenta = i.nro_cuenta )) > 1 and
                t.fec_vencimiento =
                (SELECT MAX(a.fec_vencimiento)
                     FROM ta_tarjetas a
                    WHERE a.nro_cuenta = i.nro_cuenta)) or
                ((select count(*)
                     from ta_tarjetas a
                    where a.nro_cuenta = i.nro_cuenta
                      and a.fec_emision =
                          (SELECT MAX(x.fec_emision)
                             FROM ta_tarjetas x
                            WHERE x.nro_cuenta = i.nro_cuenta)) = 1))

            or ((t.cod_persona in (select cod_persona from ge_cta_clientes o
                                   where o.nro_cuenta = i.nro_cuenta  and o.relacion = 'P'
                                   )
                  and t.nro_tarjeta in (select nro_tarjeta
                                        from ta_cta_tarjetas_pro_tmp
                                        where nro_cuenta=i.nro_cuenta and tip_tarjeta = '0')
                                        and cod_estado not in ('10')
                ) or

                 (t.cod_persona in
                                  (select cod_persona from ge_cta_clientes o
                                  where o.nro_cuenta = i.nro_cuenta  and o.relacion = 'A'
                                  )
                   and t.nro_tarjeta in (select nro_tarjeta
                                             from ta_cta_tarjetas_pro_tmp
                                              where nro_cuenta=i.nro_cuenta and mar_bloqueo is null)
                 )
                );
      END LOOP;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   EXCEPTION
      WHEN OTHERS THEN
         pat_imp.pr_log('ITC-00002: Al actualizar la vigencia de las tarjetas.' || SQLERRM);
   END pr_pro_set_vig_procard;
   /* Devuelve la fecha de cierre de la procesadora en el mes/a?o indicado */
   FUNCTION fu_obt_fec_cierre
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 3
   ) RETURN DATE IS
      v_fecha DATE;
   BEGIN
      SELECT MAX(fec_cierre)
        INTO v_fecha
        FROM ta_cal_cierres
       WHERE cod_ent_procesadora = p_cod_procesadora
         AND cod_modulo = 5
         AND cod_modalidad = p_cod_modalidad
         AND cod_tip_cierre = p_cod_tip_cierre
            --     and fec_cierre <= c_fec_actual;
         AND fec_cierre <= trunc(SYSDATE);
      IF v_fecha IS NULL THEN
         SELECT MAX(fec_cierre)
           INTO v_fecha
           FROM ta_cal_cierres
          WHERE cod_ent_procesadora = p_cod_procesadora
            AND cod_modulo = 5
            -- AND cod_modalidad IS NULL
            AND cod_tip_cierre = p_cod_tip_cierre
               --and fec_cierre <= c_fec_actual;
            AND fec_cierre <= trunc(SYSDATE);
      END IF;
      RETURN v_fecha;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'No existe cierre para Proc: ' || to_char(p_cod_procesadora) ||
                                  ' Modal: ' || to_char(nvl(p_cod_modalidad, -1))||
                                  ' p_cod_tip_cierre '||p_cod_tip_cierre);

      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al buscar cierre ' || SQLERRM || ' Proc: ' ||
                                  to_char(p_cod_procesadora) || ' Modal: ' ||
                                  to_char(nvl(p_cod_modalidad, -1)));
   END fu_obt_fec_cierre;
   /* Inserta la tabla TA_SAL_CIERRE para la cuenta indicada */
   PROCEDURE pr_ins_sal_cierre
   (
      p_nro_cuenta IN VARCHAR2,
      p_fec_cierre IN DATE,
      p_procesadora IN NUMBER DEFAULT NULL --FSPC-509
   ) IS
      c_nom_proceso CONSTANT VARCHAR2(30) := 'pat_imp.PR_INS_SAL_CIERRE';
      v_vto_pag_min ta_ext_cabecera_tmp.vto_pag_minimo%type; --FSPC-509
      v_mto_pag_min ta_ext_cabecera_tmp.imp_min_pag_min%type; --FSPC-509
   BEGIN
      BEGIN
         INSERT INTO ta_sal_cierres
            (nro_cuenta, fec_cierre, sal_financiado, sal_facturado, sal_facturar, lin_credito,
             mto_pag_minimo, fec_vto_pago, lin_cuotas, sal_cuo_pendientes, dia_atraso, lin_especial)
            SELECT t.nro_cuenta,
                   p_fec_cierre,
                   nvl(t.sal_financiado, 0),
                   nvl(t.sal_facturado, 0),
                   nvl(t.sal_facturar, 0),
                   nvl(t.lin_credito, 0),
                   nvl(t.mto_pag_minimo, 0),
                   t.fec_vct_ult_cierre,
                   nvl(t.lin_cuotas, 0),
                   nvl(t.sal_cuo_pendientes, 0),
                   nvl(t.dia_mora, 0),
                   nvl(t.lin_especial, 0)
              FROM ta_cta_tarjetas t
             WHERE t.nro_cuenta = p_nro_cuenta
               AND NOT EXISTS (SELECT 1
                      FROM ta_sal_cierres s
                     WHERE s.nro_cuenta = t.nro_cuenta
                       AND s.fec_cierre = p_fec_cierre);
               --FSPC-509
             if p_procesadora=fug_obt_pardinamico('COD_PRO_BANCARD') then
                begin
                 select ext.vto_pag_minimo,ext.imp_min_pag_min
                 into  v_vto_pag_min,v_mto_pag_min
                 from ta_ext_cabecera_tmp ext
                 where trunc(ext.fec_cierre)=p_fec_cierre
                 and ext.id_cuenta=p_nro_cuenta;

                exception
                  when others then
                    v_vto_pag_min:=null;
                    v_mto_pag_min:=null;
                end;

                 update ta_sal_cierres ci
                 set ci.mto_pag_minimo=nvl(v_mto_pag_min,ci.mto_pag_minimo),
                 ci.fec_vto_pago=nvl(v_vto_pag_min,ci.fec_vto_pago)
                 where ci.nro_cuenta=p_nro_cuenta
                 and trunc(ci.fec_cierre)=p_fec_cierre;

             end if;
      EXCEPTION
         WHEN OTHERS THEN
            pat_imp.pr_log(c_nom_proceso || ': Al insertar los saldos del cierre de la cuenta ' ||
                           p_nro_cuenta || ', ' || SQLERRM);
      END;
   END pr_ins_sal_cierre;
   /* Devuelve la fecha de vencimiento de la procesadora en el mes/a?o indicado */
   FUNCTION fu_obt_fec_vencim
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 1
   ) RETURN DATE IS
      v_fecha DATE;
   BEGIN
      BEGIN
         SELECT fec_vencimiento
           INTO v_fecha
           FROM ta_cal_cierres
          WHERE cod_ent_procesadora = p_cod_procesadora
            AND cod_modulo = 5
            AND cod_modalidad = p_cod_modalidad
            AND cod_tip_cierre = p_cod_tip_cierre
            AND fec_cierre = (SELECT MAX(fec_cierre)
                                FROM ta_cal_cierres
                               WHERE cod_ent_procesadora = p_cod_procesadora
                                 AND cod_modulo = 5
                                 AND cod_modalidad = p_cod_modalidad
                                 AND cod_tip_cierre = p_cod_tip_cierre
                                 AND fec_cierre <= trunc(SYSDATE));
      EXCEPTION
         WHEN no_data_found THEN
            SELECT fec_vencimiento
              INTO v_fecha
              FROM ta_cal_cierres
             WHERE cod_ent_procesadora = p_cod_procesadora
               AND cod_modulo = 5
               AND cod_modalidad IS NULL
               AND cod_tip_cierre = p_cod_tip_cierre
               AND fec_cierre = (SELECT MAX(fec_cierre)
                                   FROM ta_cal_cierres
                                  WHERE cod_ent_procesadora = p_cod_procesadora
                                    AND cod_modulo = 5
                                    AND cod_modalidad IS NULL
                                    AND cod_tip_cierre = p_cod_tip_cierre
                                    AND fec_cierre <= trunc(SYSDATE));
      END;
      RETURN v_fecha;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'No existe cierre para Proc: ' || to_char(p_cod_procesadora) ||
                                  ' Modal: ' || to_char(nvl(p_cod_modalidad, -1))||
                                  ' Cod tip cierre '||p_cod_tip_cierre );
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al buscar cierre ' || SQLERRM || ' Proc: ' ||
                                  to_char(p_cod_procesadora) || ' Modal: ' ||
                                  to_char(nvl(p_cod_modalidad, -1)));
   END fu_obt_fec_vencim;
    -- Reemplaza los caracteres inválidos de una cadena
   FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2,
      p_correo VARCHAR2 DEFAULT 'N'
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                               'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                               'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         v_cadena := translate(v_cadena, 'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                               'aeiouAEIOUAaDO     a  o  y yAa                         ');
         v_cadena := translate(v_cadena, '''', '  ');
         IF nvl(p_correo, 'N') = 'N' THEN
            v_cadena := translate(v_cadena, '@', ' ');
         END IF;
      END IF;
      RETURN(v_cadena);
   END;
   -- Verifica formatos del correo
   FUNCTION fu_val_correo
   (
      p_mail        VARCHAR2,
      p_cod_persona ba_personas.cod_persona%TYPE DEFAULT NULL
   ) RETURN VARCHAR2 IS
      v_mail         VARCHAR2(319) := lower(p_mail);
      v_nom_usuario  VARCHAR2(64);
      v_nom_dominio  VARCHAR2(254);
      v_caracter     VARCHAR2(1);
      v_posicion     NUMBER(3);
      v_car_invalido NUMBER(3);
      v_con_caracter NUMBER(3) := 0;
      --
      v_pos_coma  NUMBER(3);
      v_pos_punto NUMBER(3);
   BEGIN
      --- Identificar el primer correo
      v_pos_punto := instr(v_mail, ';'); -- hasta el punto y coma
      v_pos_coma  := instr(v_mail, ','); -- hasta la coma
      IF v_pos_punto = 0 AND v_pos_coma = 0 THEN
         v_posicion := length(v_mail);
      ELSIF v_pos_coma = 0 THEN
         v_posicion := v_pos_punto - 1;
      ELSIF v_pos_punto = 0 THEN
         v_posicion := v_pos_coma - 1;
      ELSIF v_pos_coma > v_pos_punto THEN
         v_posicion := v_pos_punto - 1;
      ELSIF v_pos_punto > v_pos_coma THEN
         v_posicion := v_pos_coma - 1;
      ELSE
         -- Contiene solo 1 correo
         v_posicion := length(v_mail);
      END IF;
      v_mail := substr(v_mail, 1, v_posicion);
      --
      v_posicion    := instr(v_mail, '@');
      v_nom_usuario := substr(v_mail, 1, instr(v_mail, '@') - 1);
      v_nom_dominio := substr(v_mail, instr(v_mail, '@') + 1);
      ---
      /*
      || Dominios Genéricos
      || ==================
      || .com .net .org
      || .mil .gov .edu .int .coop
      || .info .biz
      || .mobi
      */
      IF instr(v_nom_dominio, '.com', 1) > 0 OR instr(v_nom_dominio, '.net', 1) > 0 OR
         instr(v_nom_dominio, '.org', 1) > 0 OR instr(v_nom_dominio, '.mil', 1) > 0 OR
         instr(v_nom_dominio, '.gov', 1) > 0 OR instr(v_nom_dominio, '.edu', 1) > 0 OR
         instr(v_nom_dominio, '.int', 1) > 0 OR instr(v_nom_dominio, '.biz', 1) > 0 OR
         instr(v_nom_dominio, '.coop', 1) > 0 OR instr(v_nom_dominio, '.info', 1) > 0 OR
         instr(v_nom_dominio, '.mobi', 1) > 0 THEN
         NULL;
      ELSE
         raise_application_error(-20002,
                                 'Dominio no corresponde a uno Genérico. Cliente: ' ||
                                  p_cod_persona || ' Correo: ' || v_mail);
      END IF;
      v_mail := fu_eli_acentos(v_mail, 'S');
      ---
      FOR i IN 1 .. length(v_mail) LOOP
         v_caracter := substr(v_mail, i, 1);
         IF v_caracter = '@' THEN
            v_con_caracter := v_con_caracter + 1;
         END IF;
      END LOOP;
      ---
      IF v_posicion <= 1 OR v_posicion = length(v_mail) OR v_con_caracter > 1 THEN
         raise_application_error(-20001,
                                 'Dirección de Correo debe tener un único @' ||
                                  ' que no este al principio ni al final. ' ||
                                  'Verifique que se ingresó una sola dirección. Cliente: ' ||
                                  p_cod_persona);
      ELSIF substr(v_nom_usuario, 1, 1) = '.' OR
            substr(v_nom_usuario, length(v_nom_usuario), 1) = '.' THEN
         raise_application_error(-20002,
                                 'Usuario No puede empezar ni terminar con un punto. Cliente: ' ||
                                  p_cod_persona);
      ELSIF substr(v_nom_dominio, 1, 1) = '.' OR
            substr(v_nom_dominio, length(v_nom_dominio), 1) = '.' OR instr(v_nom_dominio, '.') = 0 THEN
         raise_application_error(-20003,
                                 'Dominio debe terner al menos' ||
                                  ' un punto que No este al principio ni al final. Cliente: ' ||
                                  p_cod_persona);
      ELSIF v_car_invalido > 0 THEN
         raise_application_error(-20004, 'Carater inválido: ' || substr(v_mail, v_car_invalido, 1));
      ELSIF instr(v_mail, '..') > 0 THEN
         raise_application_error(-20005,
                                 'No puede ingresar punto consecutivamente. Cliente: ' ||
                                  p_cod_persona);
      ELSIF length(v_nom_usuario) > 64 THEN
         raise_application_error(-20006,
                                 'El nombre de usuario no puede ser mayor a 64 caracteres. Cliente: ' ||
                                  p_cod_persona);
      ELSIF length(v_nom_dominio) > 255 THEN
         raise_application_error(-20007,
                                 'El dominio no puede ser mayor a 255 caracteres. Cliente: ' ||
                                  p_cod_persona);
      END IF;
      RETURN v_mail;
   END;

   -- Actualiza en forma dinámica campos definidos en el dominio TAR_ACT_ACENTOS
   PROCEDURE pr_act_acentos
   (
      p_dominio     ba_cod_referencias.dominio%TYPE,
      p_cod_persona ba_personas.cod_persona%TYPE DEFAULT NULL
   ) IS
      v_sentencia VARCHAR2(4000);
      v_error     VARCHAR2(4000);
      CURSOR c_campos IS
         SELECT a.val_maximo, a.abreviatura
           FROM ba_cod_referencias a
          WHERE a.dominio = p_dominio
          ORDER BY to_number(a.val_minimo);
   BEGIN
      FOR i IN c_campos LOOP
         v_sentencia := 'update ' || i.abreviatura || chr(10) || '   set ' || i.val_maximo ||
                        ' = pat_imp.fu_eli_acentos(' || i.val_maximo || ')';
         IF p_cod_persona IS NOT NULL THEN
            v_sentencia := v_sentencia || ' where cod_persona = ' || p_cod_persona;
         END IF;
         sql_util.ejecute_dml(v_sentencia, v_error);
         IF v_error IS NOT NULL THEN
            raise_application_error(-20000,
                                    'Error act.' || i.abreviatura || '.' || i.val_maximo || ':' ||
                                     v_error);
         END IF;
      END LOOP;
   END;
   -- proceso
   PROCEDURE pr_act_solicitudes(p_nro_solicitud ta_solicitudes.nro_solicitud%TYPE DEFAULT NULL) IS
      c_fecha DATE := pag_cal.fu_obt_fec_actual(5);
      CURSOR c_solicitudes IS
         SELECT a.*, a.rowid fila
           FROM ta_solicitudes_tmp a --ta_sol_aprobadas_tmp
          WHERE p_nro_solicitud IS NULL
             OR a.nro_solicitud = p_nro_solicitud;
      v_existe           NUMBER;
      v_ref_persona      ba_cod_referencias.val_minimo%TYPE;
      v_lin_min_tarjeta  ta_tipos.min_linea%TYPE;
      v_lin_max_tarjeta  ta_tipos.max_linea%TYPE;
      c_cod_mon_local    ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_error            ta_solicitudes_tmp.det_error%TYPE;
      rg_ta_sol_apr      ta_solicitudes_tmp%ROWTYPE;
      v_cta_valida       VARCHAR2(1);
      v_tip_plastico     VARCHAR2(1);
      v_dir_correo       ba_personas.dir_correo%TYPE;
      v_tip_persona      ba_personas.tipo%TYPE;
      v_cod_usu_promotor ba_personas.cod_usu_promotor%TYPE;
      v_cod_usu_oficial  ge_clientes.cod_usu_oficial%TYPE;
      v_ofi_oficial      ba_oficinas.cod_oficina%TYPE;
      v_mail_oficial     ba_personas.dir_correo%TYPE;
      v_mail_promotor    ba_personas.dir_correo%TYPE;
      v_cod_per_promotor ba_personas.cod_persona%TYPE;
      v_cod_per_oficial  ba_personas.cod_persona%TYPE;
      v_dir_cliente      VARCHAR2(90); --ba_direcciones.direccion%type;
      v_lin_especial     VARCHAR2(1);
   BEGIN
      FOR i IN c_solicitudes LOOP
         rg_ta_sol_apr      := NULL;
         v_error            := NULL;
         v_cta_valida       := 'N';
         v_tip_plastico     := 'N';
         v_dir_correo       := NULL;
         v_tip_persona      := NULL;
         v_cod_usu_promotor := NULL;
         v_cod_usu_oficial  := NULL;
         v_ofi_oficial      := NULL;
         v_mail_oficial     := NULL;
         v_mail_promotor    := NULL;
         v_cod_per_promotor := NULL;
         v_cod_per_oficial  := NULL;
         v_dir_cliente      := NULL;
         ---
         BEGIN
            SELECT p.cod_persona, p.dir_correo, p.tipo, p.cod_usu_promotor
              INTO rg_ta_sol_apr.cod_persona, v_dir_correo, v_tip_persona, v_cod_usu_promotor
              FROM ba_personas p
             WHERE p.nro_documento = i.nro_documento;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := nvl(v_error, '') || '#' || 'No existe Persona con este documento';
               GOTO siguiente_registro;
            WHEN too_many_rows THEN
               v_error := nvl(v_error, '') || '#' || 'Mas de una Persona con este documento';
               GOTO siguiente_registro;
            WHEN OTHERS THEN
               v_error := nvl(v_error, '') || '#' ||
                          'Error al traer codigo de Persona para el documento : ' ||
                          rg_ta_sol_apr.nro_documento || ' Error : ' || SQLERRM;
               GOTO siguiente_registro;
         END;
         --
         -- Verificar si es persona física
         IF v_tip_persona <> 'F' THEN
            v_error := nvl(v_error, '') || '#' || 'Persona no es Física';
            GOTO siguiente_registro;
         END IF;
         -- Validar el correo de la persona
         IF v_dir_correo IS NOT NULL THEN
            BEGIN
               v_dir_correo := pat_imp.fu_val_correo(v_dir_correo, rg_ta_sol_apr.cod_persona);
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
         END IF;
         --
         IF p_nro_solicitud IS NULL THEN
            /*
            || Se ejecuta luego de la importación del archivo Excel SOLIC_APROB.xls
            || Se verifican y validan los datos importados
            */
            rg_ta_sol_apr.tip_envio := upper(nvl(i.tip_envio, 'D'));
            IF rg_ta_sol_apr.tip_envio NOT IN ('D', 'R') THEN
               rg_ta_sol_apr.tip_envio := 'D';
            END IF;
            rg_ta_sol_apr.retener := upper(nvl(i.retener, 'N'));
            IF rg_ta_sol_apr.retener NOT IN ('N', 'S') OR rg_ta_sol_apr.tip_envio = 'D' THEN
               rg_ta_sol_apr.retener := 'N';
            END IF;
            IF rg_ta_sol_apr.retener = 'S' THEN
               rg_ta_sol_apr.tip_envio := 'R';
            END IF;
            ---
            rg_ta_sol_apr.nom_embozado := upper(i.nom_embozado);
            ---
            --rg_ta_sol_apr.adicionales := upper(nvl(i.adicionales, 'N'));
            --  IF rg_ta_sol_apr.adicionales NOT IN ('N', 'S') THEN
            --    rg_ta_sol_apr.adicionales := 'N';
            --  END IF;
            rg_ta_sol_apr.deb_automatico := upper(nvl(i.deb_automatico, 'N'));
            IF rg_ta_sol_apr.deb_automatico NOT IN ('N', 'S') THEN
               rg_ta_sol_apr.deb_automatico := 'N';
               rg_ta_sol_apr.nro_cta_debito := NULL;
            END IF;
            rg_ta_sol_apr.tip_cobro := upper(nvl(i.tip_cobro, 'M'));
            IF rg_ta_sol_apr.tip_cobro NOT IN ('M', 'T') THEN
               rg_ta_sol_apr.tip_cobro := 'M';
            END IF;
         ELSE
            /*
            || tiene n° de solicitud
            || se trata de un reproceso
            */
            rg_ta_sol_apr.tip_envio    := i.tip_envio;
            rg_ta_sol_apr.retener      := i.retener;
            rg_ta_sol_apr.nom_embozado := i.nom_embozado;
            -- rg_ta_sol_apr.adicionales    := i.adicionales;
            rg_ta_sol_apr.deb_automatico := i.deb_automatico;
            rg_ta_sol_apr.nro_cta_debito := i.nro_cta_debito;
            rg_ta_sol_apr.tip_cobro      := i.tip_cobro;
         END IF;
         --- Recalcular variables por si se editaron desde el form
         rg_ta_sol_apr.afinidad      := i.afinidad;
         rg_ta_sol_apr.sub_afinidad  := NULL;
         rg_ta_sol_apr.cod_modalidad := NULL;
         rg_ta_sol_apr.referencia    := NULL;
         rg_ta_sol_apr.par_modalidad := NULL;
         rg_ta_sol_apr.pre_embozada  := NULL;
         rg_ta_sol_apr.observacion   := NULL;
         rg_ta_sol_apr.per_tasa      := 'N';
         rg_ta_sol_apr.monto         := i.monto;
         --- Asigna la Oficina del Oficial
         --- Si desde el Excel se carga sin valor
         IF i.cod_oficina IS NULL THEN
            BEGIN
               i.cod_oficina := fug_obt_ofi_usuario(rg_ta_sol_apr.cod_persona);
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
         END IF;
         --*
         --*  Traer secuencia para nro. de solicitud
         --*
         IF i.nro_solicitud IS NULL THEN
            BEGIN
               SELECT s_nro_solicitud.nextval INTO rg_ta_sol_apr.nro_solicitud FROM sys.dual;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' ||
                             'Error al traer secuencia de solicitudes : ' || SQLERRM;
            END;
         ELSE
            rg_ta_sol_apr.nro_solicitud := i.nro_solicitud;
         END IF;
         --- Recuperar la modalidad a partir de la afinidad -- ICL. 08/07/2009
         IF rg_ta_sol_apr.afinidad IS NOT NULL THEN
            BEGIN
               SELECT DISTINCT cod_modalidad
                 INTO rg_ta_sol_apr.cod_modalidad
                 FROM ta_tipos t
                WHERE t.afinidad = rg_ta_sol_apr.afinidad
                  AND nvl(t.sub_afinidad, '00') = nvl(rg_ta_sol_apr.sub_afinidad, '00');
            EXCEPTION
               WHEN no_data_found THEN
                  v_error := nvl(v_error, '') || '#' || 'Modalidad no registrada para la afinidad ' ||
                             rg_ta_sol_apr.afinidad || ' sub-afinidad ' ||
                             rg_ta_sol_apr.sub_afinidad;
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || 'Error al buscar Modalidad en ta_tipos : ' ||
                             SQLERRM;
            END;
         END IF;
         IF rg_ta_sol_apr.cod_modalidad IS NULL THEN
            v_error := nvl(v_error, '') || '#' || 'Modalidad no definida para la afinidad' ||
                       rg_ta_sol_apr.afinidad || ' sub-afinidad ' || rg_ta_sol_apr.sub_afinidad;
         END IF;
         ---
         v_ref_persona               := nvl(fue_obt_des_refcodes('COD_PER_EXC_IMP',
                                                                 rg_ta_sol_apr.cod_persona), 'N');
         rg_ta_sol_apr.par_modalidad := nvl(fug_obt_pardinamico('COD_MAD_EXC_IMP', '5',
                                                                rg_ta_sol_apr.cod_modalidad), 'N');
         IF i.monto <> 0 OR (rg_ta_sol_apr.par_modalidad = 'S') THEN
            --- Recuperar embozado
            IF rg_ta_sol_apr.nom_embozado IS NULL THEN
               IF (v_ref_persona = 'S' AND rg_ta_sol_apr.par_modalidad = 'S') THEN
                  -- Control para excluir de la validacion a personas juridicas y la nueva modalidad 501 BANCARDCHECK  -- GC 30/11/2012
                  rg_ta_sol_apr.nom_embozado := '';
               ELSE
                  BEGIN
                     SELECT substr(TRIM(pri_nombre) || ' ' || TRIM(pri_apellido), 1, 20)
                       INTO rg_ta_sol_apr.nom_embozado
                       FROM ba_per_fisicas
                      WHERE cod_persona = rg_ta_sol_apr.cod_persona;
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_error := nvl(v_error, '') || '#' || 'Persona ' ||
                                   rg_ta_sol_apr.cod_persona || ' no registrada como física';
                     WHEN OTHERS THEN
                        v_error := nvl(v_error, '') || '#' || 'Error al buscar persona : ' ||
                                   SQLERRM;
                  END;
               END IF;
            ELSE
               rg_ta_sol_apr.nom_embozado := pat_imp.fu_eli_acentos(i.nom_embozado);
            END IF;
            --* Recuperar direccion de envio  --
            IF nvl(rg_ta_sol_apr.tip_envio, 'D') = 'D' THEN
               BEGIN
                  SELECT cod_direccion
                    INTO rg_ta_sol_apr.referencia
                    FROM ba_direcciones
                   WHERE cod_persona = rg_ta_sol_apr.cod_persona
                     AND cod_direccion = i.referencia;
               EXCEPTION
                  WHEN no_data_found THEN
                     BEGIN
                        SELECT cod_direccion
                          INTO rg_ta_sol_apr.referencia
                          FROM ba_direcciones
                         WHERE cod_persona = rg_ta_sol_apr.cod_persona
                           AND rownum = 1;
                     EXCEPTION
                        WHEN OTHERS THEN
                           rg_ta_sol_apr.referencia := 1;
                     END;
                  WHEN OTHERS THEN
                     rg_ta_sol_apr.referencia := 1;
               END;
            ELSIF rg_ta_sol_apr.tip_envio = 'R' THEN
               rg_ta_sol_apr.referencia := 1; --oficina principal
            END IF;
         END IF;
         --*
         --*
         --* Solicitud es Pre Embozada.
         --*
         IF nvl(pae_cnf.g_programa, 'x') = 'TPSOLPRE' THEN
            rg_ta_sol_apr.pre_embozada := 'S';
         END IF;
         IF rg_ta_sol_apr.pre_embozada = 'S' THEN
            rg_ta_sol_apr.observacion := 'Alta Masiva de Tarjetas PreEmbozadas.';
         ELSE
            rg_ta_sol_apr.observacion := 'Alta Masiva de Tarjetas.';
         END IF;
         /*
         || Mismo control que se realiza en el trigger TB_TA_SOLICITUDES
         || antes de insertar en TA_SOLICITUDES.
         */
         IF nvl(pae_cnf.g_programa, 'x') IN ('GMPROARC', 'GMARCHIV', 'TPSOLPRE') THEN
            IF (v_ref_persona <> 'S' AND
               ((rg_ta_sol_apr.par_modalidad <> 'S') OR
               (rg_ta_sol_apr.par_modalidad = 'S') AND v_tip_persona = 'F')) THEN
               -- Control para excluir de la validacion a personas juridicas
               v_existe := 0;
               SELECT COUNT(*)
                 INTO v_existe
                 FROM ta_solicitudes
                WHERE cod_persona = rg_ta_sol_apr.cod_persona
                  AND cod_modalidad = rg_ta_sol_apr.cod_modalidad
                  AND afinidad = rg_ta_sol_apr.afinidad
                  AND nvl(sub_afinidad, 'ZZ') = nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ')
                  AND cod_estado <> 'RCH';
               IF v_existe <> 0 THEN
                  v_error := nvl(v_error, '') || '#' || 'La persona : ' ||
                             rg_ta_sol_apr.cod_persona ||
                             ' ya posee solicitud activa para la modalidad ' ||
                             rg_ta_sol_apr.cod_modalidad || ', afinidad ' || rg_ta_sol_apr.afinidad ||
                             ' y sub-afinidad ' || rg_ta_sol_apr.sub_afinidad || '.';
               END IF;
               --
               v_existe := 0;
               SELECT COUNT(*)
                 INTO v_existe
                 FROM ta_cta_tarjetas c, ta_tarjetas t
                WHERE t.cod_persona = rg_ta_sol_apr.cod_persona
                  AND t.cod_estado <> 10
                  AND c.nro_cuenta = t.nro_cuenta
                  AND c.cod_modalidad = rg_ta_sol_apr.cod_modalidad
                  AND c.afinidad = rg_ta_sol_apr.afinidad
                  AND nvl(c.sub_afinidad, 'ZZ') = nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ');
               IF v_existe <> 0 THEN
                  v_error := nvl(v_error, '') || '#' || 'La persona : ' ||
                             rg_ta_sol_apr.cod_persona || ' ya posee tarjeta para la modalidad ' ||
                             rg_ta_sol_apr.cod_modalidad || ', afinidad ' || rg_ta_sol_apr.afinidad ||
                             ' y sub-afinidad ' || rg_ta_sol_apr.sub_afinidad || '.';
               END IF;
            END IF;
         END IF;
         --*
         --* Controlar que la persona no se encuentre inhibido para solicitar tarjeta
         --*
         v_existe := 0;
         SELECT COUNT(*)
           INTO v_existe
           FROM ge_par_causales p, ge_causales c, ge_per_inhibidas i
          WHERE i.cod_persona = rg_ta_sol_apr.cod_persona
            AND c.cod_causa = i.cod_causa
            AND p.cod_causa = c.cod_causa
            AND p.parametro = 'AFE_TARJETAS'
            AND i.estado = 'I'
            AND p.val_parametro = 'S';
         IF v_existe <> 0 THEN
            v_error := nvl(v_error, '') || '#' || 'La persona : ' || rg_ta_sol_apr.cod_persona ||
                       ' se encuentra inhibida para este tipo de cuenta.';
         END IF;
         /*
         || Fin controles TB_TA_SOLICITUDES
         */
         -- Verifica si la cuenta de débito es válido
         IF nvl(rg_ta_sol_apr.deb_automatico, 'N') = 'S' THEN
            rg_ta_sol_apr.nro_cta_debito := i.nro_cta_debito;
            IF rg_ta_sol_apr.nro_cta_debito IS NULL THEN
               v_error := nvl(v_error, '') || '#' ||
                          'Debe ingresar un Nro. de Cuenta valido para débito automático.';
            ELSE
               -- Validar la cuenta de débito
               BEGIN
                  v_cta_valida := fug_val_cta_debito(to_char(rg_ta_sol_apr.nro_cta_debito),
                                                     c_cod_mon_local, 16);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := nvl(v_error, '') || '#' || SQLERRM;
               END;
            END IF;
         ELSE
            rg_ta_sol_apr.nro_cta_debito := NULL;
         END IF;
         -- Verifica los límites del tipo de tarjeta
         IF rg_ta_sol_apr.cod_modalidad IS NOT NULL AND c_cod_mon_local IS NOT NULL AND
            rg_ta_sol_apr.afinidad IS NOT NULL THEN
            BEGIN
               SELECT min_linea, max_linea
                 INTO v_lin_min_tarjeta, v_lin_max_tarjeta
                 FROM ta_tipos
                WHERE cod_modulo = 5
                  AND cod_modalidad = rg_ta_sol_apr.cod_modalidad
                  AND afinidad = rg_ta_sol_apr.afinidad
                  AND nvl(sub_afinidad, '00') = nvl(rg_ta_sol_apr.sub_afinidad, '00')
                  AND rownum = 1;
            EXCEPTION
               WHEN OTHERS THEN
                  v_lin_min_tarjeta := 0;
                  v_lin_max_tarjeta := 0;
            END;
         ELSE
            v_error := nvl(v_error, '') || '#' || 'Al Obt. Minimo y Máximo para el Monto de Línea.';
         END IF;
         IF rg_ta_sol_apr.monto IS NOT NULL THEN
            IF nvl(rg_ta_sol_apr.monto, 0) < v_lin_min_tarjeta THEN
               v_error := nvl(v_error, '') || '#' || 'El monto debe ser mayor o igual a ' ||
                          ltrim(to_char(v_lin_min_tarjeta, '999,999,999,999.99'));
            ELSIF nvl(rg_ta_sol_apr.monto, 0) > v_lin_max_tarjeta THEN
               v_error := nvl(v_error, '') || '#' || 'El monto debe ser menor o igual a ' ||
                          ltrim(to_char(v_lin_max_tarjeta, '999,999,999,999.99'));
            END IF;
         END IF;
         /*
         || Eliminar los acentos y caracteres no válidos.
         */
         -- Datos del Promotor
         IF v_cod_usu_promotor IS NOT NULL THEN
            BEGIN
               SELECT cod_persona
                 INTO v_cod_per_promotor
                 FROM ba_usuarios
                WHERE cod_usuario = v_cod_usu_promotor;
            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_per_promotor := NULL;
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
            IF v_cod_per_promotor IS NOT NULL THEN
               BEGIN
                  pat_imp.pr_act_acentos('ACT_SOL_ACENTOS', v_cod_per_promotor);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := nvl(v_error, '') || '#' || SQLERRM;
               END;
            END IF;
            -- Validar el correo del Promotor
            BEGIN
               SELECT dir_correo
                 INTO v_mail_promotor
                 FROM ba_personas
                WHERE cod_persona = v_cod_per_promotor;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL; -- Si no tiene correo no es error
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
            IF v_mail_promotor IS NOT NULL THEN
               BEGIN
                  v_mail_promotor := pat_imp.fu_val_correo(v_mail_promotor, v_cod_per_promotor);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := nvl(v_error, '') || '#' || SQLERRM;
               END;
            END IF;
         END IF;
         -- Datos del Oficial
         BEGIN
            SELECT cod_usu_oficial
              INTO v_cod_usu_oficial
              FROM ge_clientes
             WHERE cod_persona = rg_ta_sol_apr.cod_persona;
         EXCEPTION
            WHEN no_data_found THEN
               v_cod_usu_oficial := NULL;
            WHEN OTHERS THEN
               v_error := nvl(v_error, '') || '#' || SQLERRM;
         END;
         IF v_cod_usu_oficial IS NOT NULL AND
            nvl(v_cod_usu_oficial, 'A') <> nvl(v_cod_usu_promotor, 'A') THEN
            BEGIN
               SELECT cod_persona
                 INTO v_cod_per_oficial
                 FROM ba_usuarios
                WHERE cod_usuario = v_cod_usu_oficial;
            EXCEPTION
               WHEN no_data_found THEN
                  v_cod_per_oficial := NULL;
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
            IF v_cod_per_oficial IS NOT NULL THEN
               BEGIN
                  pat_imp.pr_act_acentos('ACT_SOL_ACENTOS', v_cod_per_oficial);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := nvl(v_error, '') || '#' || SQLERRM;
               END;
            END IF;
            -- Validar el correo del Oficial
            -- no se usa el FUG_OBT_DIR_MAIL_PER porque es valido si no tiene correo
            BEGIN
               SELECT dir_correo
                 INTO v_mail_oficial
                 FROM ba_personas
                WHERE cod_persona = v_cod_per_oficial;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL; -- Si no tiene correo no es error
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
            IF v_mail_oficial IS NOT NULL THEN
               BEGIN
                  v_mail_oficial := pat_imp.fu_val_correo(v_mail_oficial, v_cod_per_oficial);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := nvl(v_error, '') || '#' || SQLERRM;
               END;
            END IF;
            --- Valida Oficina del Oficial y de la Solicitud
            BEGIN
               v_ofi_oficial := fug_obt_ofi_usuario(v_cod_usu_oficial);
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := nvl(v_error, '') || '#' || SQLERRM;
            END;
            IF v_ofi_oficial <> i.cod_oficina THEN
               v_error := nvl(v_error, '') || '#' ||
                          'La Oficina de la cuenta debe llevar la oficina del Oficial: ' ||
                          fue_obt_des_oficina(fug_obt_ofi_usuario(rg_ta_sol_apr.cod_persona)) || ' (' ||
                          fug_obt_ofi_usuario(rg_ta_sol_apr.cod_persona) || ')';
            END IF;
         ELSE
            --- En PRT_GEN_DAT_ALTAS valida que el promotor y el supervisor no sean el mismo.
            v_cod_usu_promotor := fug_obt_pardinamico('TRC_USU_PROMOTOR');
         END IF;
         -- Datos de la Persona
         -- nom_usuario: se obtiene de nom_completo de ba_personas
         -- (se actualiza por trigger de ba_per_fisicas)
         BEGIN
            pat_imp.pr_act_acentos('ACT_SOL_ACENTOS', rg_ta_sol_apr.cod_persona);
         EXCEPTION
            WHEN OTHERS THEN
               v_error := nvl(v_error, '') || '#' || SQLERRM;
         END;
         -- Datos de la solicitud
         BEGIN
            rg_ta_sol_apr.nom_embozado := pat_imp.fu_eli_acentos(rg_ta_sol_apr.nom_embozado);
         EXCEPTION
            WHEN OTHERS THEN
               v_error := nvl(v_error, '') || '#' || SQLERRM;
         END;
         -- Fin control acentos
         /*
         || Se controla que el correo no esté duplicado
         || Si los emails NO son nulas (tienen algún valor),
         || entonces NO deben ser iguales entre si
         || ---------------------
         || Variables a comparar:
         || ---------------------
         || nvl(v_dir_correo,'a')
         || nvl(v_mail_oficial,'c')
         || nvl(v_mail_promotor,'d')
         */
         IF nvl(v_dir_correo, 'a') = nvl(v_mail_oficial, 'c') THEN
            v_error := nvl(v_error, '') || '#' ||
                       'Correo del Titular se encuentra duplicado con el del Oficial';
         END IF;
         IF nvl(v_dir_correo, 'a') = nvl(v_mail_promotor, 'd') THEN
            v_error := nvl(v_error, '') || '#' ||
                       'Correo del Titular se encuentra duplicado con el del Promotor';
         END IF;
         IF nvl(v_mail_oficial, 'c') = nvl(v_mail_promotor, 'd') THEN
            --- v_error := nvl(v_error, '') || '#'
            ---        || 'Correo del Oficial se encuentra duplicado con el del Promotor';
            --- En PRT_GEN_DAT_ALTAS valida que el promotor y el supervisor no sean el mismo.
            v_mail_promotor := NULL;
         END IF;
         -- Fin control correos
         --
         /*
         || Verificar que tenga direccion sea correcta para envio de extracto
         ||
         */
         BEGIN
            SELECT substr(decode(e.tip_envio, 'D',
                                 d.direccion || decode(numero, NULL, '', ' ' || numero),
                                 -- Direccion
                                 'R', o.descripcion, NULL), 1, 50) dir_envio
              INTO v_dir_cliente
              FROM ba_barrios         b,
                   ba_ciudades        c,
                   ba_paises          p,
                   ba_direcciones     d,
                   ge_dir_retenciones o,
                   ge_dir_envios      e
             WHERE p.cod_pais(+) = d.cod_pais
               AND c.cod_pais(+) = d.cod_pais
               AND c.cod_ciudad(+) = d.cod_ciudad
               AND b.cod_pais(+) = d.cod_pais
               AND b.cod_ciudad(+) = d.cod_ciudad
               AND b.cod_barrio(+) = d.cod_barrio
               AND d.cod_persona(+) = e.cod_persona
               AND d.cod_direccion(+) = e.referencia
               AND o.cod_dir_retencion(+) = e.referencia
               AND e.cod_persona = rg_ta_sol_apr.cod_persona
               AND e.nro_cuenta IS NULL;
            IF v_dir_cliente IS NULL THEN
               RAISE no_data_found;
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               v_error := nvl(v_error, '') || '#' || 'Cliente no tiene definida una dirección ' ||
                          'Válida para el envío del Extracto. ' ||
                          'Verifique en la carpeta de la persona';
            WHEN OTHERS THEN
               v_error := nvl(v_error, '') || '#' || 'Cliente tiene definida una dirección ' ||
                          'NO Válida para el envío del Extracto. ' ||
                          'Verifique en la carpeta de la persona';
         END;
         IF i.monto = 0 AND i.par_modalidad = 'S' THEN
            v_error := nvl(v_error, '') || '#' || 'Monto no puede ser 0 para esta modalidad.';
         END IF;

         --- Actualiza los datos importados por los válidos
         UPDATE ta_solicitudes_tmp a
            SET tip_envio    = rg_ta_sol_apr.tip_envio,
                retener      = rg_ta_sol_apr.retener,
                nom_embozado = rg_ta_sol_apr.nom_embozado,
                -- adicionales       = rg_ta_sol_apr.adicionales,
                deb_automatico = rg_ta_sol_apr.deb_automatico,
                tip_cobro      = rg_ta_sol_apr.tip_cobro,
                cod_persona    = rg_ta_sol_apr.cod_persona,
                afinidad       = nvl(rg_ta_sol_apr.afinidad, i.afinidad),
                sub_afinidad   = rg_ta_sol_apr.sub_afinidad,
                cod_modalidad  = rg_ta_sol_apr.cod_modalidad,
                par_modalidad  = rg_ta_sol_apr.par_modalidad,
                referencia     = rg_ta_sol_apr.referencia,
                pre_embozada   = rg_ta_sol_apr.pre_embozada,
                observacion    = rg_ta_sol_apr.observacion,
                nro_cta_debito = rg_ta_sol_apr.nro_cta_debito,
                per_tasa       = rg_ta_sol_apr.per_tasa,
                --  tas_int_corriente = rg_ta_sol_apr.tas_int_corriente,
                --  tas_int_mora      = rg_ta_sol_apr.tas_int_mora,
                --   tas_int_compra    = rg_ta_sol_apr.tas_int_compra,
                nro_solicitud = rg_ta_sol_apr.nro_solicitud
          WHERE a.rowid = i.fila;
         /* Se verifica que la afinidad sea la correcta para la asignacion de
         una línea especial*/
         IF nvl(i.lin_especial, 0) > 0 THEN
            BEGIN
               SELECT nvl(ind_lin_especial, 'N')
                 INTO v_lin_especial
                 FROM ta_tipos
                WHERE cod_modulo = 5
                  AND cod_modalidad = rg_ta_sol_apr.cod_modalidad
                  AND afinidad = rg_ta_sol_apr.afinidad
                  AND nvl(sub_afinidad, 'ZZ') = nvl(rg_ta_sol_apr.sub_afinidad, 'ZZ');
               IF v_lin_especial = 'N' THEN
                  v_error := 'No corresponde una Línea Especial para la Afinidad.';
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  v_error := 'No corresponde una Línea Especial para la Afinidad.';
               WHEN OTHERS THEN
                  v_error := 'Error: Al buscar Ref. Externa para la Afinidad de la Solicitud.' ||
                             SQLERRM;
            END;
         END IF;
         /*
         || Ejecuta el alta de la tarjeta
         */
         IF v_error IS NULL THEN
            BEGIN
               INSERT INTO ta_solicitudes
                  (nro_solicitud, cod_persona, cod_oficina, cod_modulo, cod_modalidad,
                   cod_usu_promotor, fec_solicitud, cod_usu_oficial, fec_aprobacion, cod_causa,
                   deb_automatico, nro_cta_debito, tip_cobro, nom_embozado, lin_sugerida, monto,
                   puntaje, cod_estado, cod_est_sugerido, tas_int_adelanto, tas_financiacion,
                   tas_mora, mto_min_pago, por_pag_minimo, tip_envio, referencia, usu_insercion,
                   fec_insercion, usu_modificacion, fec_modificacion, nro_linea, observacion,
                   cod_moneda, cod_campana, cod_canal, mto_aprobado, niv_aprobacion, nro_acta,
                   nro_cuenta, afinidad, sub_afinidad, lin_especial, cod_tas_procard
                    /*, pre_embozada*/)
               VALUES
                  (rg_ta_sol_apr.nro_solicitud, rg_ta_sol_apr.cod_persona, i.cod_oficina, 5,
                   rg_ta_sol_apr.cod_modalidad, v_cod_usu_promotor, c_fecha, v_cod_usu_oficial,
                   c_fecha, NULL, rg_ta_sol_apr.deb_automatico, rg_ta_sol_apr.nro_cta_debito,
                   rg_ta_sol_apr.tip_cobro, rg_ta_sol_apr.nom_embozado, NULL, i.monto, NULL, 'APR',
                   NULL, NULL, NULL, NULL, NULL, rg_ta_sol_apr.por_pag_minimo,
                   nvl(rg_ta_sol_apr.tip_envio, 'D'), rg_ta_sol_apr.referencia, USER, SYSDATE, USER,
                   SYSDATE, NULL, rg_ta_sol_apr.observacion, 'GS', NULL, NULL, i.monto, NULL, NULL,
                   NULL, rg_ta_sol_apr.afinidad, rg_ta_sol_apr.sub_afinidad, i.lin_especial,
                   i.cod_tas_procard /*, rg_ta_sol_apr.pre_embozada*/);
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'No se pudo crear la solicitud ' || SQLERRM;
            END;
         END IF;
         ---
         <<siguiente_registro>>
         NULL;
         -- Si no hubo error debe actualizar a nulo si es reproceso
         UPDATE ta_solicitudes_tmp a SET det_error = v_error WHERE a.rowid = i.fila;
      END LOOP;
      --- Borrar las solicitudes creadas
      DELETE ta_solicitudes_tmp WHERE det_error IS NULL;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al actualizar solicitudes pre-aprobadas:' || SQLERRM);
   END pr_act_solicitudes;

   --- proceso
   PROCEDURE pr_imp_conciliacion IS
      c_nom_proceso CONSTANT VARCHAR2(100) := 'pat_imp.PR_IMP_CONCILIACION';
      v_directorio  VARCHAR2(1000) := fug_obt_pardinamico('TCR_DIR_IMP_ARC_PROCESADORA'); --'ARCHIVOS_BANCARD';
      v_archivo     utl_file.file_type;
      v_linea       VARCHAR2(32767);
      v_nom_archivo VARCHAR2(1000);
      v_msj         VARCHAR2(4000);
      r_log         ta_logs%ROWTYPE;
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 5;
      END;
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;

      pat_imp.pr_ins_log_error('*** Iniciando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                               ' ***', FALSE);

      v_nom_archivo := 't' || TRIM(to_char(fug_obt_pardinamico('COD_ENT_INFONET'), '000')) || '_' ||
                     to_char(pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(5), 1, 1),
                            'YYYYMMDD') || '.txt';

      pat_imp.pr_ins_log_error('*** Archivo a importar ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                               ' *** '||v_directorio||' - '||v_nom_archivo, FALSE);

      v_archivo         := utl_file.fopen(v_directorio, v_nom_archivo, 'R');

      sql_util.ejecute_dml('TRUNCATE TABLE TA_CONCILIACIONES_TMP ', v_msj);

      IF v_msj IS NOT NULL THEN
         pat_imp.pr_ins_log_error(c_nom_proceso || ': Al intentar borrar la tabla temporal.' || ', ' ||
                                  SQLERRM);
      END IF;
      LOOP
         BEGIN
            utl_file.get_line(v_archivo, v_linea);
            INSERT INTO ta_conciliaciones_tmp (datos) VALUES (v_linea);
         EXCEPTION
            WHEN no_data_found THEN
               EXIT;
            WHEN OTHERS THEN
               pat_imp.pr_ins_log_error(c_nom_proceso ||
                                        ': Al insertar datos de saldos BANCARD en la tabla temporal, ' ||
                                        SQLERRM);
         END;
      END LOOP;
      utl_file.fclose(v_archivo);
      COMMIT;
      pr_ins_conciliacion;
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);
   exception
     when others then
         pat_imp.pr_ins_log_error('Al importar, ' || SQLERRM);
   END pr_imp_conciliacion;

   /* Distribuye en distintas tablas la información recolectada en la tabla temporal*/
   PROCEDURE pr_ins_conciliacion IS
      /*
      Inserta los datos en las tablas TA_DET_CONCILIACIONES, TA_RES_CONCILIACIONES, TA_TOT_CONCILIACIONES.
      Manualmente es ejecutado desde la pantalla Importador de Datos GPPROFIN.-
      */
      --Declaración de variables
      c_nom_proceso CONSTANT VARCHAR2(100) := 'pat_imp.PR_INS_CONCILIACION';
      v_msj             VARCHAR2(4000);
      v_mascara         VARCHAR2(50) := '9999999999999990D00';
      rg_log            ta_logs%ROWTYPE;
      v_error           VARCHAR2(1) := 'N';
      v_cod_ent_infonet ta_det_conciliaciones.cod_ent_debito%TYPE := fug_obt_pardinamico('COD_ENT_INFONET');
      v_conciliados     NUMBER;
      v_no_conciliados  NUMBER;
      v_mov_existe      NUMBER(10);
      --
      rg_ta_det_conciliaciones ta_det_conciliaciones%ROWTYPE;
      rg_ta_res_conciliaciones ta_res_conciliaciones%ROWTYPE;
      rg_ta_tot_conciliaciones ta_tot_conciliaciones%ROWTYPE;
      --
      CURSOR cu_conciliaciones IS
         SELECT datos FROM ta_conciliaciones_tmp;

      CURSOR cu_valores(p_datos IN ta_conciliaciones_tmp.datos%TYPE) IS
         SELECT rownum nro_linea, column_value linea
           FROM TABLE(fug_obt_tab_registro(p_datos, ';'))
          WHERE column_value IS NOT NULL;

      -- Procedimiento para insertar los datos en las tablas correspondientes
      -- Para det en Detalle bucle
   BEGIN
      --
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 5;
      --
      --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
      pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
      --
      rg_log.nom_proceso := c_nom_proceso;
      rg_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_ins_log_error('*** Inicio ins. conciliación ' || to_char(SYSDATE, 'HH24:MI:SS') ||' ***', FALSE);

      sql_util.ejecute_dml('TRUNCATE TABLE TA_DET_CONCILIACIONES ', v_msj);
      IF v_msj IS NOT NULL THEN
         v_error := 'S';
         pat_imp.pr_ins_log_error(c_nom_proceso ||
                                  ': Al intentar borrar la tabla TA_DET_CONCILIACIONES, ' ||
                                  SQLERRM);
      END IF;

      sql_util.ejecute_dml('TRUNCATE TABLE TA_RES_CONCILIACIONES ', v_msj);
      IF v_msj IS NOT NULL THEN
         v_error := 'S';
         pat_imp.pr_ins_log_error(c_nom_proceso ||
                                  ': Al intentar borrar la tabla TA_RES_CONCILIACIONES, ' ||
                                  SQLERRM);
      END IF;

      --Para tot en Totales bucle
      sql_util.ejecute_dml('TRUNCATE TABLE TA_TOT_CONCILIACIONES ', v_msj);
      IF v_msj IS NOT NULL THEN
         v_error := 'S';
         pat_imp.pr_ins_log_error(c_nom_proceso ||
                                  ': Al intentar borrar la tabla TA_TOT_CONCILIACIONES, ' ||
                                  SQLERRM);
      END IF;
      pat_imp.pr_ins_log_error('*** Realizó el truncado de tablas ' || to_char(SYSDATE, 'HH24:MI:SS') ||' ***', FALSE);

      FOR d IN cu_conciliaciones LOOP
         -- Detalle
         IF substr(d.datos, 0, 1) = 'D' THEN
            FOR v IN cu_valores(d.datos) LOOP
               IF v.nro_linea = 2 THEN
                  rg_ta_det_conciliaciones.fec_valor := to_date(v.linea, 'yyyy/mm/dd');
               ELSIF v.nro_linea = 3 THEN
                  rg_ta_det_conciliaciones.cod_gru_servicio := v.linea;
               ELSIF v.nro_linea = 4 THEN
                  rg_ta_det_conciliaciones.cod_transaccion := v.linea;
               ELSIF v.nro_linea = 5 THEN
                  rg_ta_det_conciliaciones.monto := to_char(substr(v.linea, 1, length(v.linea) - 2) || ',' ||
                                                            substr(v.linea, -2), v_mascara);
               ELSIF v.nro_linea = 6 THEN
                  rg_ta_det_conciliaciones.cod_moneda := v.linea;
               ELSIF v.nro_linea = 7 THEN
                  rg_ta_det_conciliaciones.fec_transaccion := to_date(v.linea, 'yyyy/mm/dd');
               ELSIF v.nro_linea = 8 THEN
                  rg_ta_det_conciliaciones.hor_transaccion := to_char(to_date(v.linea, 'hh24:mi:ss'),
                                                                      'hh24:mi:ss');
               ELSIF v.nro_linea = 9 THEN
                  rg_ta_det_conciliaciones.nro_mov_bancard := v.linea;
               ELSIF v.nro_linea = 10 THEN
                  rg_ta_det_conciliaciones.cod_ent_credito := v.linea;
               ELSIF v.nro_linea = 11 THEN
                  rg_ta_det_conciliaciones.cod_ent_debito := v.linea;
               END IF;
            END LOOP;

            rg_ta_det_conciliaciones.usu_insercion    := substr(USER, 1, 10);
            rg_ta_det_conciliaciones.fec_insercion    := SYSDATE;
            rg_ta_det_conciliaciones.usu_modificacion := substr(USER, 1, 10);
            rg_ta_det_conciliaciones.fec_modificacion := SYSDATE;

            BEGIN
               --No informar registros de la Entidad.
               IF NOT (rg_ta_det_conciliaciones.cod_ent_debito = v_cod_ent_infonet AND
                   rg_ta_det_conciliaciones.cod_ent_credito = v_cod_ent_infonet) THEN
                  INSERT INTO ta_det_conciliaciones VALUES rg_ta_det_conciliaciones;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'S';
                  pat_imp.pr_ins_log_error(c_nom_proceso ||
                                           ': Al insertar datos de saldos BANCARD en la tabla Resúmenes, ' ||
                                           SQLERRM);
            END;
            -- Se llama al procedimiento de Conciliación BANCARD
            prt_gen_con_tarjetas(rg_ta_det_conciliaciones.nro_mov_bancard,
                                 rg_ta_det_conciliaciones.fec_valor,
                                 rg_ta_det_conciliaciones.cod_ent_credito,
                                 rg_ta_det_conciliaciones.monto, 'A', 'C');

            rg_ta_det_conciliaciones := NULL;

         ELSIF substr(d.datos, 0, 1) = 'R' THEN
            -- Resumen
            FOR v IN cu_valores(d.datos) LOOP
               IF v.nro_linea = 2 THEN
                  rg_ta_res_conciliaciones.cod_gru_servicio := v.linea;
               ELSIF v.nro_linea = 3 THEN
                  rg_ta_res_conciliaciones.cod_ent_credito := v.linea;
               ELSIF v.nro_linea = 4 THEN
                  rg_ta_res_conciliaciones.cod_ent_debito := v.linea;
               ELSIF v.nro_linea = 5 THEN
                  rg_ta_res_conciliaciones.fec_valor := to_date(v.linea, 'yyyy/mm/dd');
               ELSIF v.nro_linea = 6 THEN
                  rg_ta_res_conciliaciones.mto_cre_mon_local := to_char(substr(v.linea, 1,
                                                                               length(v.linea) - 2) || ',' ||
                                                                        substr(v.linea, -1),
                                                                        v_mascara);
               ELSIF v.nro_linea = 7 THEN
                  rg_ta_res_conciliaciones.mto_deb_mon_local := to_char(substr(v.linea, 1,
                                                                               length(v.linea) - 2) || ',' ||
                                                                        substr(v.linea, -1),
                                                                        v_mascara);
               ELSIF v.nro_linea = 8 THEN
                  rg_ta_res_conciliaciones.mto_cre_mon_extranjera := to_char(substr(v.linea, 1,
                                                                                    length(v.linea) - 2) || ',' ||
                                                                             substr(v.linea, -2),
                                                                             v_mascara);
               ELSIF v.nro_linea = 9 THEN
                  rg_ta_res_conciliaciones.mto_deb_mon_extranjera := to_char(substr(v.linea, 1,
                                                                                    length(v.linea) - 2) || ',' ||
                                                                             substr(v.linea, -2),
                                                                             v_mascara);
               ELSIF v.nro_linea = 10 THEN
                  IF rg_ta_res_conciliaciones.cod_gru_servicio = 4 THEN
                     rg_ta_res_conciliaciones.fec_credito := to_date(substr(d.datos, 87, 95),
                                                                     'yyyy/mm/dd');
                  ELSE
                     rg_ta_res_conciliaciones.fec_credito := rg_ta_res_conciliaciones.fec_valor;
                  END IF;
               END IF;
            END LOOP;

            rg_ta_res_conciliaciones.usu_insercion    := substr(USER, 1, 10);
            rg_ta_res_conciliaciones.fec_insercion    := SYSDATE;
            rg_ta_res_conciliaciones.usu_modificacion := substr(USER, 1, 10);
            rg_ta_res_conciliaciones.fec_modificacion := SYSDATE;

            BEGIN
               --No informar registros de la Entidad.
               IF NOT (rg_ta_res_conciliaciones.cod_ent_debito = v_cod_ent_infonet AND
                   rg_ta_res_conciliaciones.cod_ent_credito = v_cod_ent_infonet) THEN
                  INSERT INTO ta_res_conciliaciones VALUES rg_ta_res_conciliaciones;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'S';
                  pat_imp.pr_ins_log_error(c_nom_proceso ||
                                           ': Al insertar datos de saldos BANCARD en la tabla Detalles, ' ||
                                           SQLERRM);
            END;

            rg_ta_res_conciliaciones := NULL;

         ELSIF substr(d.datos, 0, 1) = 'T' THEN
            -- Totales
            FOR v IN cu_valores(d.datos) LOOP
               IF v.nro_linea = 2 THEN
                  rg_ta_tot_conciliaciones.cod_gru_servicio := v.linea;
               ELSIF v.nro_linea = 3 THEN
                  rg_ta_tot_conciliaciones.cod_entidad := v.linea;
               ELSIF v.nro_linea = 4 THEN
                  rg_ta_tot_conciliaciones.fec_valor := to_date(v.linea, 'yyyy/mm/dd');
               ELSIF v.nro_linea = 5 THEN
                  rg_ta_tot_conciliaciones.mto_tot_mon_local := to_char(substr(v.linea, 1,
                                                                               length(v.linea) - 2) || ',' ||
                                                                        substr(v.linea, -1),
                                                                        v_mascara);
               ELSIF v.nro_linea = 6 THEN
                  rg_ta_tot_conciliaciones.can_tot_mon_local := to_char(v.linea);
               ELSIF v.nro_linea = 7 THEN
                  rg_ta_tot_conciliaciones.mto_tot_mon_extranjera := to_char(substr(v.linea, 1,
                                                                                    length(v.linea) - 2) || ',' ||
                                                                             substr(v.linea, -2),
                                                                             v_mascara);
               ELSIF v.nro_linea = 8 THEN
                  rg_ta_tot_conciliaciones.can_tot_mon_extranjera := to_char(v.linea);
               END IF;
            END LOOP;

            rg_ta_tot_conciliaciones.usu_insercion    := substr(USER, 1, 10);
            rg_ta_tot_conciliaciones.fec_insercion    := SYSDATE;
            rg_ta_tot_conciliaciones.usu_modificacion := substr(USER, 1, 10);
            rg_ta_tot_conciliaciones.fec_modificacion := SYSDATE;

            BEGIN
               INSERT INTO ta_tot_conciliaciones VALUES rg_ta_tot_conciliaciones;
            EXCEPTION
               WHEN OTHERS THEN
                  v_error := 'S';
                  pat_imp.pr_ins_log_error(c_nom_proceso ||
                                           ': Al insertar datos de saldos BANCARD en la tabla Totales, ' ||
                                           SQLERRM);
            END;

            rg_ta_tot_conciliaciones := NULL;

         END IF;
      END LOOP;
      -----
      pat_imp.pr_ins_log_error('*** Generó detalles de conciliación ' || to_char(SYSDATE, 'HH24:MI:SS') ||' ***', FALSE);
      -- Se cuentan los registros procesados
      BEGIN
         SELECT COUNT(nro_conciliacion), (COUNT(nro_mov_bancard) - COUNT(nro_conciliacion))
           INTO v_conciliados, v_no_conciliados
           FROM ta_det_conciliaciones c
          WHERE c.fec_valor =
                pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(5), fug_obt_ofi_matriz, 1);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      -- Se envía correo informando sobre las conciliaciones automáticas
      BEGIN
         IF pas_snp.g_err_dir_correo IS NOT NULL THEN
            it_mail.mail(fug_obt_dir_correo, pas_snp.g_err_dir_correo,
                         'Informe de Conciliaciones BANCARD ',
                         chr(10) || 'Movimientos conciliados: ' || v_conciliados || chr(10) ||
                          'Movimientos no conciliados: ' || v_no_conciliados || chr(10) || chr(10) ||
                          ' Error : ' || SQLERRM || chr(10) || chr(10) || 'Atentamente.');
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
      pat_imp.pr_ins_log_error('*** Va a generar movimientos de conciliación ' || to_char(SYSDATE, 'HH24:MI:SS') ||' ***', FALSE);

      IF v_error <> 'S' THEN
      --Se verifica que no existan movimientos de conciliacion en el dia.
       SELECT COUNT(*)
         INTO V_MOV_EXISTE
           FROM ge_movimientos m
          WHERE m.cod_modulo = 4
            AND m.cod_modalidad IN (43, 46)
            AND m.cod_transaccion IN (4711, 4712);
        IF V_MOV_EXISTE = 0 THEN
         pat_imp.pr_gen_mov_conciliacion;
      END IF;
      END IF;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_log('*** Finalizando el proceso a las ' || to_char(SYSDATE, 'HH24:MI:SS') ||
                     ' ***', FALSE);

   EXCEPTION
      WHEN OTHERS THEN
         /*IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE*/
            pat_imp.pr_ins_log_error(c_nom_proceso ||
                                     ': Al realizar importación de archivo de saldos BANCARD, ' ||
                                     SQLERRM);
         --END IF;
   END pr_ins_conciliacion;

   /* Realiza los mov. correspondientes a los Totales insertados en la tabla TA_TOT_CONCILIACIONES*/
   PROCEDURE pr_gen_mov_conciliacion IS
      v_nro_secuencia ge_movimientos.nro_secuencia%TYPE;
      v_hora          ge_movimientos.hora%TYPE;
      v_monto         ge_movimientos.monto%TYPE;
      c_nom_proceso CONSTANT VARCHAR2(100) := 'pat_imp.PR_GEN_MOV_CONCILIACION';
      v_cod_ent_infonet VARCHAR2(5) := to_char(fug_obt_pardinamico('COD_ENT_INFONET'), '000');
      ex_salir EXCEPTION;
      -- Para el envio
      CURSOR cu_tot_envio IS
         SELECT cod_ent_debito,
                decode(cod_gru_servicio, 4, 1, 0) tip_gru_servicio,
                SUM(nvl(mto_cre_mon_local, 0) - nvl(mto_deb_mon_local, 0)) mto_mon_local,
                0 mto_mon_extranjera,
                pag_gen.fu_obt_mon_local moneda
           FROM ta_res_conciliaciones
          GROUP BY cod_ent_debito, decode(cod_gru_servicio, 4, 1, 0)
         UNION ALL
         SELECT cod_ent_debito,
                decode(cod_gru_servicio, 4, 1, 0) tip_gru_servicio,
                0 mto_mon_local,
                SUM(nvl(mto_cre_mon_extranjera, 0) - nvl(mto_deb_mon_extranjera, 0)) mto_mon_extranjera,
                pag_gen.fu_obt_mon_fuerte moneda
           FROM ta_res_conciliaciones
          GROUP BY cod_ent_debito, decode(cod_gru_servicio, 4, 1, 0);

   BEGIN
      r_log.nom_proceso := c_nom_proceso;
      r_log.fec_hor_ini := SYSDATE;
      pat_imp.pr_ins_log_error('*** Movimientos conciliación ' || to_char(SYSDATE, 'HH24:MI:SS') ||' ***', FALSE);
      --Para el envio
      v_nro_secuencia := 0;
      v_hora          := pas_snp.fu_ini_hora;
      FOR e IN cu_tot_envio LOOP
         IF v_nro_secuencia > 999 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         END IF;
         IF e.moneda = pag_gen.fu_obt_mon_local THEN
            v_monto := e.mto_mon_local;
         ELSE
            v_monto := e.mto_mon_extranjera;
         END IF;
         IF v_monto != 0 AND v_cod_ent_infonet != e.cod_ent_debito THEN
            /*Si el código de servicio != 4*/
            BEGIN
               pas_snp.pr_gen_mov_tar_conciliacion(v_hora, v_nro_secuencia, e.cod_ent_debito,
                                                   v_monto, e.moneda, e.tip_gru_servicio);
               v_nro_secuencia := v_nro_secuencia + 1;
            EXCEPTION
               WHEN OTHERS THEN
                  pas_snp.g_cod_error := -999;
                  pas_snp.g_msj_error := 'Intentando generar movimientos de conciliación: ' ||
                                         SQLERRM;
                  RAISE ex_salir;
            END;
         END IF;
      END LOOP;
      pat_imp.pr_ins_log_error('*** Finalizando el proceso a las ' ||
                               to_char(SYSDATE, 'HH24:MI:SS') || ' ***', FALSE);

   EXCEPTION
      WHEN ex_salir THEN
         pat_imp.pr_ins_log_error(c_nom_proceso || ': Al generar movimientos de conciliaciones, ' ||
                                  pas_snp.fu_obt_msj_error || ' ' || SQLERRM, FALSE);
         raise_application_error(-20001, pas_snp.fu_obt_msj_error);
      WHEN OTHERS THEN
         IF SQLCODE <= -20000 THEN
            RAISE;
         ELSE
            pat_imp.pr_ins_log_error(c_nom_proceso ||
                                     ': Al realizar importación de archivo de saldos BANCARD, ' ||
                                     SQLERRM);
         END IF;

   END pr_gen_mov_conciliacion;
   /* Inserta el registro de Log en la tabla TA_LOGS */
   PROCEDURE pr_ins_log_error
   (
      p_mensaje ta_logs.comentario%TYPE,
      p_error   BOOLEAN DEFAULT TRUE
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      r_log.fec_hor_fin := SYSDATE;
      r_log.nro_reg     := g_nro_reg;
      r_log.comentario  := p_mensaje;
      -- Agregado para hacer Test.
      IF p_error THEN
         dbms_output.put_line(r_log.nro_reg);
         dbms_output.put_line(r_log.comentario);
         dbms_output.put_line(SQLERRM);
      ELSE
         dbms_output.put_line(r_log.comentario);
      END IF;
      prt_ins_log(r_log, p_error);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END pr_ins_log_error;

   /* Obtiene importes de deudas de la cuenta*/
PROCEDURE PR_OBT_DEU_TARJETA( P_NRO_CUENTA       IN  TA_CTA_TARJETAS.NRO_CUENTA%TYPE,
                              P_NRO_TARJETA      IN  TA_TARJETAS.NRO_TARJETA%TYPE,
                              P_SAL_PAG_MINIMO   OUT TA_CTA_TARJETAS.SAL_PAG_MINIMO%TYPE,
                              P_SAL_ULT_EXTRACTO OUT TA_CTA_TARJETAS.SAL_ULT_EXTRACTO%TYPE,
                              P_DEU_TOTAL        OUT TA_CTA_TARJETAS.SAL_FACTURAR%TYPE,
                              P_FEC_ULT_CIERRE   OUT TA_CTA_TARJETAS.FEC_ULT_CIERRE%TYPE,
                              P_NOM_EMBOZAR      OUT TA_TARJETAS.NOM_EMBOZAR%TYPE
                             ) IS
BEGIN
   SELECT a.sal_pag_minimo,
          a.sal_ult_extracto,
          (nvl(a.sal_facturar, 0) + nvl(a.sal_facturado, 0) + nvl(a.sal_financiado, 0) +
          nvl(a.sal_cuo_pendientes, 0)),
          a.fec_ult_cierre,
          t.nom_embozar
     INTO p_sal_pag_minimo,
          p_sal_ult_extracto,
          p_deu_total,
          p_fec_ult_cierre,
          p_nom_embozar
     FROM ta_cta_tarjetas a, ta_tarjetas t
    WHERE a.nro_cuenta  = t.nro_cuenta
      AND t.nro_tarjeta = p_nro_tarjeta
      AND a.nro_cuenta  = p_nro_cuenta;

EXCEPTION
   WHEN no_data_found THEN
      p_sal_pag_minimo   := NULL;
      p_sal_ult_extracto := NULL;
      p_deu_total        := NULL;
      p_fec_ult_cierre   := NULL;
      p_nom_embozar      := NULL;
END;

/* Indica si una cuenta retiene su extracto, S: no imprime, N: imprime */
FUNCTION FU_RET_EXTRACTO(P_NRO_CUENTA IN TA_CTA_TARJETAS.NRO_CUENTA%TYPE) RETURN VARCHAR2 IS
  v_retorno VARCHAR2(1) := 'N';
BEGIN
  BEGIN
     SELECT t.ret_extracto
       INTO v_retorno
       FROM ta_cuentas_tmp t
      WHERE t.nro_cuenta = P_NRO_CUENTA;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        NULL;
  END;
  -- verificar si no esta solicitado
  IF v_retorno = 'N' THEN
     SELECT n.ret_extracto
       INTO v_retorno
       FROM ta_cta_tarjetas_nov n
      WHERE n.nro_cuenta = p_nro_cuenta
        and n.fecha = pag_cal.fu_obt_fec_actual(5);
  END IF;

  RETURN v_retorno;
EXCEPTION
  WHEN OTHERS THEN
     RETURN v_retorno;
END FU_RET_EXTRACTO;
PROCEDURE pr_com_bca_cobranza IS
  /*Servicio de compensacion de bocas de cobranzas t107
  procesa todas las operaciones realizadas entre WEPA y BANCARD */
  c_nom_proceso CONSTANT VARCHAR2(30) := 'pat_imp.pr_com_bca_cobranza';
  r_gmovi              ge_movimientos%rowtype;
  v_cta_ent_credito    cc_cta_bancarias.nro_cuenta%type := null;
  v_cta_ent_debito     cc_cta_bancarias.nro_cuenta%type := null;
  v_cta_ope_bancard    cc_cta_bancarias.nro_cuenta%type := null;
  v_hora               ge_movimientos.hora%type;
  v_cod_modulo         ge_cuentas.cod_modulo%TYPE := 9;
  v_cod_mad_credito    ge_cuentas.cod_modalidad%TYPE;
  v_cod_mod_credito    ge_cuentas.cod_modulo%TYPE;
  v_cod_mod_debito     ge_cuentas.cod_modulo%TYPE;
  v_cod_mad_debito     ge_cuentas.cod_modalidad%TYPE;
  v_nro_secuencia      number := 0;
  v_cantidad           number := 0;
  v_fecha              date := pag_cal.fu_obt_fec_actual(5);
  v_existe             varchar2(1) := null;
  v_lugar              varchar2(1000) := null;
  v_fec_desde         date :=null;
  v_fec_hasta         date :=null;

  cursor c_datos is
    SELECT TO_CHAR(c.nro_mov_bancard) nro_mov_bancard,
           c.cod_transaccion,
           c.monto,
           c.fec_valor,
           c.fec_transaccion,
           c.hor_transaccion,
           c.cod_ent_credito,
           c.cod_ent_debito
      FROM it.ta_det_conciliaciones c;
  --- solo debe procesar movimientos enviados del dia.
begin
  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := v_cod_modulo;
  END;
  v_hora          := to_char(SYSDATE, 'HH24:MI:SS');
  v_hora          := fug_obt_hor_disponible(v_fecha,v_hora,user,'N');
  v_cta_ope_bancard := fug_obt_pardinamico(p_parametro  => 'CTA_OP_BANCARD',p_cod_moneda => 'GS');
  v_nro_secuencia :=0;
  v_cantidad :=0;
  v_existe :='N';

  begin
    SELECT min(c.fec_transaccion) fec_min,
           max(c.fec_valor) fec_max
      into v_fec_desde, v_fec_hasta
      FROM it.ta_det_conciliaciones c;
  exception
    when others then
      raise_application_error('-20000', 'Error al obtener parametro de fecha' ||sqlerrm);
  end;
  for i in c_datos loop
    v_cantidad           := 0;
    v_cta_ent_credito := null;
    v_lugar := null;
    v_lugar := 'Recup .Nro Ope Bancard: '||  i.nro_mov_bancard;
    BEGIN
      SELECT 'S' v_existe,
             cod_oficina,
             cod_moneda,
             fec_valor,
             hora,
             monto,
             cod_ofi_origen,
             cod_modulo,
             cod_modalidad,
             cod_transaccion
        into v_existe,
             r_gmovi.cod_oficina,
             r_gmovi.cod_moneda,
             r_gmovi.fec_valor,
             r_gmovi.hora,
             r_gmovi.monto,
             r_gmovi.cod_ofi_origen,
             r_gmovi.cod_modulo,
             r_gmovi.cod_modalidad,
             r_gmovi.cod_transaccion
        from (

              SELECT a.cod_oficina,
                      A.cod_moneda,
                      a.fec_valor,
                      a.hora,
                      a.monto,
                      a.cod_ofi_origen,
                      a.cod_modulo,
                      a.cod_modalidad,
                      a.REFERENCIA,
                      a.cod_transaccion
                FROM cc_movimientos_his A
               WHERE a.fec_valor >= v_fec_desde and a.fec_valor<= v_fec_hasta + 2
                 and a.referencia = i.nro_mov_bancard
                 and a.cod_tra_padre = '8592'
                 and a.cod_transaccion = '8016'
                 and a.reversado = 'N'
                 and a.nro_documento in
                     (select aa.nro_documento
                        from cc_movimientos_his aa
                       where aa.nro_cuenta = v_cta_ope_bancard
                         and aa.reversado = 'N'
                         and aa.fecha = a.fecha
                         and aa.hora = a.hora
                         and aa.monto = a.monto
                         and aa.cod_tra_padre = '8592')

              UNION ALL
              SELECT a.cod_oficina,
                      A.cod_moneda,
                      a.fec_valor,
                      a.hora,
                      a.monto,
                      a.cod_ofi_origen,
                      a.cod_modulo,
                      a.cod_modalidad,
                      a.referencia,
                      a.cod_transaccion
                FROM cc_movimientos_his A
               WHERE a.fec_valor >= v_fec_desde and a.fec_valor<= v_fec_hasta + 2
                 and a.referencia = i.nro_mov_bancard
                 and a.cod_tra_padre = '8526'
                 and a.cod_transaccion = '8015'
                 and a.reversado = 'N'
                 and a.nro_documento in
                     (select aa.nro_documento
                        from cc_movimientos_his aa
                       where aa.nro_cuenta = v_cta_ope_bancard
                         and aa.monto = a.monto
                         and aa.hora = a.hora
                         and aa.reversado = 'N'
                         and aa.fecha = a.fecha
                         and to_number(substr(aa.nro_documento, 1, 1)) >= 6
                         and aa.cod_tra_padre = '8526')
              UNION ALL
              SELECT a.cod_oficina,
                      A.cod_moneda,
                      a.fec_valor,
                      a.hora,
                      a.monto,
                      a.cod_ofi_origen,
                      a.cod_modulo,
                      a.cod_modalidad,
                      a.REFERENCIA,
                      a.cod_transaccion
                FROM ge_movimientos A
               WHERE a.fec_valor >= v_fec_desde and a.fec_valor<= v_fec_hasta + 2
                 and a.referencia = i.nro_mov_bancard
                 and a.cod_tra_padre = '8592'
                 and a.cod_transaccion = '8016'
                 and a.reversado = 'N'
                 and a.nro_documento in
                     (select aa.nro_documento
                        from ge_movimientos aa
                       where aa.nro_cuenta = v_cta_ope_bancard
                         and aa.reversado = 'N'
                         and aa.fecha = a.fecha
                         and aa.hora = a.hora
                         and aa.monto = a.monto
                         and aa.cod_tra_padre = '8592')
                UNION ALL
                SELECT a.cod_oficina,
                      A.cod_moneda,
                      a.fec_valor,
                      a.hora,
                      a.monto,
                      a.cod_ofi_origen,
                      a.cod_modulo,
                      a.cod_modalidad,
                      a.referencia,
                      a.cod_transaccion
                FROM ge_movimientos A
               WHERE a.fec_valor >= v_fec_desde and a.fec_valor<= v_fec_hasta + 2
                 and a.referencia = i.nro_mov_bancard
                 and a.cod_tra_padre = '8526'
                 and a.cod_transaccion = '8015'
                 and a.reversado = 'N'
                 and a.nro_documento in
                     (select aa.nro_documento
                        from ge_movimientos aa
                       where aa.nro_cuenta = v_cta_ope_bancard
                         and aa.monto = a.monto
                         and aa.hora = a.hora
                         and aa.reversado = 'N'
                         and aa.fecha = a.fecha
                         and to_number(substr(aa.nro_documento, 1, 1)) >= 6
                         and aa.cod_tra_padre = '8526'));

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_existe := 'N';
      WHEN OTHERS THEN
        v_existe := 'N';
    end;
    --generar creditos
    IF v_existe = 'S' THEN
      -- verificar que no ya no exista en ge_movimientos
      v_lugar := 'Ver.Nro Ope Bancard: '||  i.nro_mov_bancard;
      begin
        select count(1)
          into v_cantidad
          from ge_movimientos t
         where t.nro_cuenta = v_cta_ope_bancard
           and t.cod_banco = i.cod_ent_debito
           and t.cod_tra_padre = 380
           and t.cod_mod_padre = 9
           and t.cod_mad_padre = 91
           and t.cod_transaccion = 6444
           and t.cod_modulo = 4
           and t.cod_modalidad in (42,43)
           and t.concepto = i.nro_mov_bancard;
      exception
        when others then
          v_cantidad := 0;
      end;
      if v_cantidad = 0 then
        v_lugar := 'Ins.Nro Ope Bancard: '||  i.nro_mov_bancard;
        BEGIN
      SELECT c.nro_cuenta, c.cod_modalidad, c.cod_modulo
        INTO v_cta_ent_credito, v_cod_mad_credito, v_cod_mod_credito
        FROM cc_cta_bancarias c
       WHERE c.estado = 'N'
         AND c.cod_modulo = 4
         AND c.cod_modalidad = 42
         AND (c.cod_banco = i.cod_ent_credito OR
           cod_ente = i.cod_ent_credito)
         AND c.cod_moneda = r_gmovi.cod_moneda;
        EXCEPTION
            WHEN OTHERS THEN
               v_cod_mad_credito :=0;
               v_cod_mod_credito :=0;
               v_lugar :='Error al obtener datos de cuenta de crédito';
        END;
    BEGIN
          SELECT  c.cod_modulo, c.cod_modalidad
             INTO v_cod_mod_debito, v_cod_mad_debito
          FROM cc_cta_bancarias c
         WHERE c.nro_cuenta = v_cta_ope_bancard;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_mod_debito  :=0;
              v_cod_mad_debito  :=0;
              v_lugar :='Error al obtener datos de cuenta de débito';
          END;
         r_gmovi.tip_mov_rubro := pas_snp.fu_obt_tip_mov_transaccion(r_gmovi.cod_modulo,
                                                                    r_gmovi.cod_modalidad,
                                                                    r_gmovi.cod_transaccion);

        if r_gmovi.tip_mov_rubro = 'D' then
           r_gmovi.tip_mov_rubro := 'C';
        else
          r_gmovi.tip_mov_rubro := 'D';
        end if;
        if v_nro_secuencia > 997 then
          v_hora := FUG_OBT_HOR_DISPONIBLE(v_fecha,v_hora,user,'N');
          v_nro_secuencia := 0;
        end if;
         v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
        --insertar creditos
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_tra_padre   := 380;
        r_gmovi.cod_mod_padre   := 9;
        r_gmovi.cod_mad_padre   := 91;
        r_gmovi.cod_transaccion := 6442;
        r_gmovi.cod_modulo      := v_cod_mod_credito;
        r_gmovi.cod_modalidad   := v_cod_mad_credito;
        r_gmovi.concepto        := i.NRO_MOV_BANCARD;
        r_gmovi.cod_banco       := i.cod_ent_credito;
        r_gmovi.nro_documento   := i.nro_mov_bancard;
        r_gmovi.nro_documento2  := i.nro_mov_bancard;
        r_gmovi.nro_cuenta      := v_cta_ent_credito;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.referencia      := i.nro_mov_bancard;

        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
        --insertar debitos
        v_nro_secuencia :=  nvl(v_nro_secuencia,0) + 1;
        r_gmovi.cod_usuario   := user;
        r_gmovi.hora          := v_hora;
        r_gmovi.nro_secuencia := v_nro_secuencia;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_tra_padre   := 380;
        r_gmovi.cod_mod_padre   := 9;
        r_gmovi.cod_mad_padre   := 91;
        r_gmovi.cod_transaccion := 6444;
        r_gmovi.concepto        := i.NRO_MOV_BANCARD;
        r_gmovi.cod_banco       := i.cod_ent_debito;
        r_gmovi.cod_modulo      := v_cod_mod_debito;
        r_gmovi.cod_modalidad   := v_cod_mad_debito;
        r_gmovi.nro_cuenta      := v_cta_ope_bancard;
        r_gmovi.nro_documento   := i.nro_mov_bancard;
        r_gmovi.nro_documento2  := i.nro_mov_bancard;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.referencia      := i.nro_mov_bancard;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
      end if;
    end if;
  end loop;
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE <= -20000 THEN
      RAISE;
    ELSE
      pat_imp.pr_ins_log_error(c_nom_proceso ||' lugar: '||v_lugar||' '||
                               ': Al generar movimientos de bocas de cobranza de BANCARD-COMP ' ||
                               SQLERRM);
    END IF;
END;


END pat_imp;
/
