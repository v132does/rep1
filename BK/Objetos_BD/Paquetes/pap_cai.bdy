CREATE OR REPLACE PACKAGE BODY IT.PAP_CAI IS
   v_min_exigido             NUMBER(18);
   v_por_cap_min_exigido     pr_parametros.por_cap_min_exigido%TYPE;
   v_por_cap_min_exi_sistema pr_parametros.por_cap_min_exi_sistema%TYPE;
   v_sal_minimo              NUMBER(18);
   -- NGRANCE - Resolución N° 37
   v_riesgo1a pr_parametros.por_riesgo_1a%TYPE;
   v_riesgo1b pr_parametros.por_riesgo_1b%TYPE;
   v_riesgo2  pr_parametros.por_riesgo_2%TYPE;
   v_riesgo3  pr_parametros.por_riesgo_3%TYPE;
   v_riesgo4  pr_parametros.por_riesgo_4%TYPE;
   v_riesgo5  pr_parametros.por_riesgo_5%TYPE;
   v_riesgo6  pr_parametros.por_riesgo_6%TYPE;

   /* Verificar si un cliente es de sólo consumo. */
   FUNCTION fu_cli_solo_consumo(p_cod_clie IN ge_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_cantidad    NUMBER(8);
      v_tip_persona ba_personas.tipo%type := NULL;
   BEGIN
      -- Requerimiento: CNFAIRUNO-3.
      -- Fecha: 22/09/2014.
      -- Los clientes con Personería Jurídica no pueden ser del sector de Consumo.
      SELECT ba.tipo
        INTO v_tip_persona
        FROM ba_personas ba
       WHERE ba.cod_persona = p_cod_clie;

      IF v_tip_persona = 'F' THEN
         BEGIN
            SELECT /*+ index(GE_CLA_OPERACIONES IN_GCOPE_COD_PERSONA) */
                  1
              INTO v_cantidad
              FROM ge_cla_operaciones a
             WHERE a.cod_persona = p_cod_clie
               AND a.cod_sec_credito NOT IN (701,702);

             RETURN 'N';
         EXCEPTION
            WHEN no_data_found THEN
               RETURN 'S';
            WHEN too_many_rows THEN
               RETURN 'N';
         END;
      ELSE
         RETURN 'N';
      END IF;
   EXCEPTION
      WHEN others THEN
         RETURN 'N';
   END;

   /* Verificar si un cliente es de sólo vivienda.*/
   FUNCTION fu_cli_solo_vivienda(p_cod_clie IN ge_clientes.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_cantidad NUMBER(8);
   BEGIN
      SELECT 1
        INTO v_cantidad
        FROM pr_cta_prestamos a, ge_cta_clientes b
       WHERE a.nro_cuenta = b.nro_cuenta
         AND b.cod_persona = p_cod_clie
         AND a.cod_sec_credito <> 702;
      RETURN 'N';
   EXCEPTION
      WHEN too_many_rows THEN
         RETURN 'N';
      WHEN no_data_found THEN
         BEGIN
            SELECT /*+ index(GE_CLA_OPERACIONES IN_GCOPE_COD_PERSONA) */
             1
              INTO v_cantidad
              FROM ge_cla_operaciones a
             WHERE a.cod_persona = p_cod_clie
               AND a.cod_sec_credito <> 702;
            RETURN 'N';
         EXCEPTION
            WHEN too_many_rows THEN
               RETURN 'N';
            WHEN no_data_found THEN
               RETURN 'S';
         END;
   END;

   /* Convertir un monto a guaraníes. */
   FUNCTION fu_con_a_guaranies
   (
      p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
      p_monto      IN pr_cta_prestamos.mto_capital%TYPE
   ) RETURN NUMBER IS
      v_cotizacion ge_cotizaciones.val_conversion%TYPE;
      v_deuda_gs   NUMBER(18);
   BEGIN
      IF p_cod_moneda = v_mon_fuerte THEN
         -- la moneda es Dolares -----------------------------------
         v_deuda_gs := nvl(p_monto, 0) * v_cot_mon_fuerte;
      ELSIF p_cod_moneda <> v_mon_local THEN
         -- moneda diferente a dolares y local ------------------------
         v_cotizacion := pag_gen.fu_obt_cotizacion(p_cod_moneda, v_fec_proceso);
         v_deuda_gs   := nvl(p_monto, 0) * v_cotizacion;
      ELSE
         -- es moneda local - guaraníes -------------------------------
         v_deuda_gs := p_monto;
      END IF;
      RETURN v_deuda_gs;
   END;

   /* Obtener la categoría que le corresponde x mora. */
   FUNCTION fu_obt_categ_x_mora(p_can_dias IN NUMBER) RETURN NUMBER IS
      v_cat_mora ge_cla_operaciones.cat_automatica%TYPE := 1;
   BEGIN
      IF v_tipo_clie IN ('G', 'R', 'M') THEN
         -- comerciales mayores
         --- tipo de cliente comercial ----
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1.1; --- riesgo normal    ---
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1.2; --- riesgo normal    ---
         ELSIF p_can_dias <= 90 THEN
            v_cat_mora := 2; --- riesgo potencial ---
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 3; --- riesgo real      ---
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 4; --- alto riesgo      ---
         ELSIF p_can_dias <= 270 THEN
            v_cat_mora := 5; --- alto riesgo      ---
         ELSE
            v_cat_mora := 6; --- irrecuperable    ---
         END IF;
      ELSIF v_tipo_clie IN ('N', 'C', 'P', 'V') THEN
         --- tipo de cliente personal, y comercial menor
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1.1; --- riesgo normal    ---
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1.2; --- riesgo normal    ---
         ELSIF p_can_dias <= 90 THEN
            v_cat_mora := 2; --- riesgo potencial ---
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 3; --- riesgo real      ---
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 4; --- alto riesgo      ---
         ELSIF p_can_dias <= 270 THEN
            v_cat_mora := 5; --- alto riesgo      ---
         ELSE
            v_cat_mora := 6; --- irrecuperable    ---
         END IF;
      ELSIF v_tipo_clie = 'T' THEN
         -- microcredito
         IF p_can_dias <= 0 THEN
            v_cat_mora := 1; --- riesgo normal    ---
         ELSIF p_can_dias <= 30 THEN
            v_cat_mora := 1.1; --- riesgo normal    ---
         ELSIF p_can_dias <= 60 THEN
            v_cat_mora := 1.2; --- riesgo normal    ---
         ELSIF p_can_dias <= 90 THEN
            v_cat_mora := 2;
         ELSIF p_can_dias <= 120 THEN
            v_cat_mora := 3;
         ELSIF p_can_dias <= 150 THEN
            v_cat_mora := 4;
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 5;
         ELSE
            v_cat_mora := 6;
         END IF;
      END IF;
      RETURN v_cat_mora;
   END;

   -- Requerimiento: CNFAIRUNO-3.
   -- Fecha: 22/09/2014.
   /* Obtiene el código de actividad primaria del cliente. */
   FUNCTION fu_obt_cod_actividad(p_cod_persona IN ge_clientes.cod_persona%TYPE)
      RETURN NUMBER IS
      v_cod_actividad ba_personas.cod_actividad%type;
   BEGIN
      SELECT (CASE WHEN NVL(ba.cod_actividad,701) = 702 THEN 701 ELSE NVL(ba.cod_actividad,701) END)
        INTO v_cod_actividad
        FROM ba_personas ba
       WHERE ba.cod_persona = p_cod_persona;

      RETURN v_cod_actividad;
   EXCEPTION
      WHEN OTHERS THEN
         v_cod_actividad := 701;
         RETURN v_cod_actividad;
   END;

   -- Requerimiento: CNFAIRUNO-3.
   -- Fecha: 22/09/2014.
   /*Retorna el destino de la operación.*/
   FUNCTION fu_obt_tip_destino
   (
      p_cod_persona   IN ge_cla_operaciones.cod_persona%TYPE,
      p_cod_modulo    IN ge_cla_operaciones.cod_modulo%TYPE,
      p_cod_modalidad IN ge_cla_operaciones.cod_modalidad%TYPE,
      p_cod_actividad IN ge_cla_operaciones.cod_sec_credito%TYPE,
      p_tot_deuda     IN ge_cla_operaciones.tot_deu_real%TYPE

   ) RETURN VARCHAR2 IS
   -- Variable para retorno.
   v_tip_destino pr_cta_prestamos.tip_destino%type;
   -- Variables axiliares.
   v_sal_minimo pr_parametros.sal_min_vigente%type;
   v_min_exigido pr_parametros.cap_min_exigido%type;
   v_es_fisica varchar2(01);
   BEGIN
      SELECT nvl(sal_min_vigente,0), nvl(round(cap_min_exigido*(por_cap_min_exigido/100),0),0)
        INTO v_sal_minimo, v_min_exigido
        FROM pr_parametros;
        v_es_fisica := pag_gen.FU_ES_PER_FISICA(p_cod_persona);
        IF v_es_fisica = 'O' THEN
           v_es_fisica := 'S';
        END IF;
        -- Valor por defecto.
        v_tip_destino := 4; -- Consumo
        -- Calcular tipo destino en base al monto solicitado.
        IF p_tot_deuda > v_min_exigido THEN --4% del Min.Exig.
           v_tip_destino := 1; -- Grandes Deudores
           IF p_cod_actividad = '701' THEN
              v_tip_destino := 4;
           END IF;
        ELSIF p_tot_deuda > (v_sal_minimo * 25) AND p_cod_actividad <> '701' THEN
           v_tip_destino := 2; -- Pequeños Deudores
        ELSIF  p_cod_actividad = '701' THEN
           v_tip_destino := 4; -- Consumo
           IF v_es_fisica <> 'S' THEN
              v_tip_destino := 2; -- Pequeños Deudores
           END IF;
        ELSE
           v_tip_destino := 5; -- Microcrédito.
           IF v_es_fisica <> 'S' THEN
              v_tip_destino := 2; -- Pequeños Deudores
           END IF;
        END IF;
        -- Vivienda.
        IF p_cod_modulo = 6 THEN
           IF (nvl(fug_obt_pardinamico('MAD_HIPOTECARIOS',6,p_cod_modalidad), 'N') = 'S'
              OR nvl(fug_obt_pardinamico('PRE_MAD_CONSTRUCCIONES',6,p_cod_modalidad), 'N') = 'S') THEN
                 v_tip_destino := 3;
           END IF;
        END IF;
        RETURN v_tip_destino;
   EXCEPTION
      WHEN OTHERS THEN
         v_tip_destino := 4;
         RETURN v_tip_destino;
   END;

   /* Proceso principal de categorización según la resolución 37. */
   PROCEDURE pr_pro_cat_res37 IS
     v_error VARCHAR2(2000);
   BEGIN
      v_fec_proceso := pag_cal.fu_obt_fec_actual(6);
      -- Resolución N°37
      SELECT por_riesgo_1a,
             por_riesgo_1b,
             por_riesgo_2,
             por_riesgo_3,
             por_riesgo_4,
             por_riesgo_5,
             por_riesgo_6,
             sal_min_vigente,
             cap_min_exigido,
             por_cap_min_exigido,
             por_cap_min_exi_sistema
        INTO v_riesgo1a,
             v_riesgo1b,
             v_riesgo2,
             v_riesgo3,
             v_riesgo4,
             v_riesgo5,
             v_riesgo6,
             v_sal_minimo,
             v_min_exigido,
             v_por_cap_min_exigido,
             v_por_cap_min_exi_sistema
        FROM pr_parametros;
      -- 1. Busco la moneda local y la de pase del sistema -------------
      SELECT cod_mon_local, cod_mon_fuerte 
        INTO v_mon_local, v_mon_fuerte 
        FROM ge_par_generales;

      v_error := NULL;
      sql_util.ejecute_dml('truncate table ge_cla_incobrables', v_error);
      IF v_error IS NOT NULL THEN
         raise_application_error(-20000, 'Trunc Incob.' || v_error);
      END IF;

      -- 2. Busco la cotizacion de la moneda fuerte----------------------
      v_cot_mon_fuerte := pag_gen.fu_obt_cotizacion(v_mon_fuerte);
      -- 3 Proceso cada uno de los tipos de operaciones por cliente
      v_lugar := 'Preparando datos de préstamos..';
      pr_pro_dat_prestamo;
      v_lugar := 'Preparando datos de Cuentas Vencidas..';
      pr_pro_dat_ope_ven;
      COMMIT;
      v_lugar := 'Preparando datos de Clientes..';
      pr_pro_cat_clientes;
      COMMIT;
      v_lugar := 'Preparando datos de Grupos Economicos..';
      pr_pro_cat_gru_econ;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'pap_cai.pr_pro_cat_res37 -' || v_lugar || '-' || SQLERRM);
   END;
   /* Procesar categorización de clientes. */
   PROCEDURE pr_pro_cat_clientes IS
      --- leo las operaciones grabadas en la tabla de OPERACIONES -------
      CURSOR totales IS
         SELECT cod_persona,
               SUM(ww_ttdeuda) ww_ttdeuda,
               SUM(ww_ttdeuco) ww_ttdeuco,
               SUM(ww_capital) ww_capital,
               SUM(ww_mtorigen) ww_mtorigen,
               SUM(ww_ttprevi) ww_ttprevi,
               SUM(ww_garan) ww_garan
          from (select a.cod_persona,
                       (nvl(tot_deu_real, 0)) ww_ttdeuda,
                       (nvl(tot_deu_contingente, 0)) ww_ttdeuco,
                       (nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0)) ww_capital,
                       (nvl(mto_original, 0) + nvl(tot_deu_contingente, 0)) ww_mtorigen,
                       (nvl(tot_prevision, 0)) ww_ttprevi,
                       (nvl(tot_gar_computables, 0)) ww_garan
                  from ge_cla_operaciones a
                 where exists (select 1 from ge_cla_incobrables b where b.cod_persona = a.cod_persona)
                union all
                select a.cod_persona,
                       (nvl(tot_deu_real, 0)) ww_ttdeuda,
                       (nvl(tot_deu_contingente, 0)) ww_ttdeuco,
                       (nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0)) ww_capital,
                       (nvl(mto_original, 0) + nvl(tot_deu_contingente, 0)) ww_mtorigen,
                       (nvl(tot_prevision, 0)) ww_ttprevi,
                       (nvl(tot_gar_computables, 0)) ww_garan
                  from ge_cla_incobrables a
                 where exists (select 1 from ge_cla_operaciones b where b.cod_persona = a.cod_persona) ) tot
        GROUP BY tot.cod_persona
              HAVING SUM(nvl(tot.ww_ttdeuda, 0) + nvl(tot.ww_ttdeuco, 0)) > 0;

      --- Declaro las variables del procedimiento --------------------
      v_cliente            ge_cla_operaciones.cod_persona%type;
      v_gru_eco            ge_clientes.cod_gru_economico%type;
      v_cat_auto           ge_cla_operaciones.cat_automatica%TYPE;
      v_tot_pond           NUMBER(21, 4);
      v_cat_pond           NUMBER(5, 3);
      v_cat_manu           ge_clientes.cat_subjetiva%type;
      v_cat_ant            ge_clientes.cat_riesgo%type;
      v_existe             VARCHAR2(01);
      v_tot_deu_sistema    ge_cla_operaciones.tot_deu_real%TYPE;
      v_tot_deu_real       ge_cla_operaciones.tot_deu_real%TYPE;
      v_cat_sistema        ge_clientes.cat_sistema%type;
      v_cat_peor           NUMBER(3);
      v_cat_final          ge_clientes.cat_automatica%type;
      v_cat_renova         ge_clientes.cat_renovaciones%type;
      v_tip_implementacion ge_par_generales.tip_implementacion%type;
      v_env_mod_tarjeta    ge_par_dinamicos.val_parametro%type; --BBVADES 2132


      -- declaro el cursor de detalles de operaciones por cliente -------
      CURSOR detalles IS
         SELECT nro_cuenta,
                cod_modulo,
                cod_modalidad,
                cat_automatica,
                cat_renovaciones,
                dia_atraso,
                tot_deu_real oc_ttdeuda,
                tot_deu_contingente oc_ttdeuco,
                tipo,
                mto_original,
                nvl(tot_deu_real, 0) - nvl(dev_no_cobrado, 0) sal_capital,
                cod_estado,
                cod_persona
         /*  ROWID FILA*/
           FROM ge_cla_operaciones a
          WHERE a.cod_persona = v_cliente
            and exists (select 1 from ge_cla_incobrables b where b.cod_persona = a.cod_persona)
        union all
        SELECT nro_cuenta,
                cod_modulo,
                cod_modalidad,
                cat_automatica,
                cat_renovaciones,
                dia_atraso,
                tot_deu_real oc_ttdeuda,
                tot_deu_contingente oc_ttdeuco,
                tipo,
                mto_original,
                nvl(tot_deu_real, 0) - nvl(dev_no_cobrado, 0) sal_capital,
                cod_estado,
                cod_persona
           FROM ge_cla_incobrables a
          WHERE a.cod_persona = v_cliente
            AND exists (select 1 from ge_cla_operaciones b where b.cod_persona = a.cod_persona)
          ORDER BY nro_cuenta;

   BEGIN
      v_env_mod_tarjeta := fug_obt_pardinamico('ENV_MOD_TARJETA');
      prg_act_par_dinamico('ENV_MOD_TARJETA', NULL, NULL, NULL, NULL, 'N');
      prg_act_par_dinamico('ENV_MOD_TARJETA', NULL, NULL, NULL, NULL, v_env_mod_tarjeta);
      v_tip_implementacion := fug_obt_tip_implementacion;
      --- proceso de actualizacion ------------------------------------
      FOR tot IN totales LOOP
         v_cliente         := tot.cod_persona;
         v_cat_renova      := 1; /* para categoría  de las operaciones ren,ref y rest */
         v_cat_ant         := 1; /* categoría  anterior, por si no existe */
         v_lugar           := 'Procesando el Cliente Nro. ' || v_cliente;
         v_tipo_clie       := NULL;
         v_cat_manu        := NULL;
         v_existe          := 'N';
         v_tot_deu_sistema := 0;
         v_cat_sistema     := 1;
         v_cat_final       := 1;
         v_cat_pond        := NULL;
         
         --*
      --- 
      UPDATE ge_clientes
         SET tot_deu_real        = 0,
             tot_deu_contingente = 0,
             tot_gar_computables = 0,
             tot_prevision       = 0,
             cat_anterior        = cat_automatica,---CNFICRC-323
             cat_automatica      = 1,
             cat_riesgo          = 1,
             cat_renovaciones    = 1
       WHERE cod_persona = v_cliente
         and (nvl(tot_deu_real, -1) != 0 OR nvl(tot_deu_contingente, -1) != 0 OR
             nvl(tot_gar_computables, -1) != 0 OR nvl(tot_prevision, -1) != 0 OR
             nvl(cat_automatica, -1) != 1 OR nvl(cat_riesgo, -1) != 1);
      -- actualizar a 1 categorías de clientes que son solo codeudores
      UPDATE ge_clientes x
         SET x.cat_riesgo     = 1,
             cat_automatica   = 1,
             cat_renovaciones = 1
       WHERE cod_persona = v_cliente
         and (x.cat_riesgo <> 1 OR x.cat_automatica <> 1 OR x.cat_renovaciones <> 1)
         AND NOT EXISTS
       (SELECT 1
                FROM ge_cta_clientes b, ge_cuentas c, ge_est_cuentas d
               WHERE b.cod_persona = x.cod_persona
                 AND b.relacion = 'P'
                 AND b.nro_cuenta = c.nro_cuenta
                 AND b.cod_modulo IN (5, 6)
                 AND c.cod_modulo = d.cod_modulo
                 AND c.cod_modalidad = d.cod_modalidad
                 AND c.estado = d.estado
                 AND nvl(d.activo, 'N') = 'S')
         AND (EXISTS (SELECT 2
                        FROM ge_cta_clientes b, ge_cuentas c, ge_est_cuentas d
                       WHERE b.cod_persona = x.cod_persona
                         AND b.relacion <> 'P'
                         AND b.nro_cuenta = c.nro_cuenta
                         AND b.cod_modulo IN (5, 6)
                         AND c.cod_modulo = d.cod_modulo
                         AND c.cod_modalidad = d.cod_modalidad
                         AND c.estado = d.estado
                         AND nvl(d.activo, 'N') = 'S') OR EXISTS
              (SELECT 1
                 FROM ba_personas b, ba_vinculos v
                WHERE v.cod_persona = x.cod_persona
                  AND v.tipo = 'E'
                  AND v.cod_per_vinculo = b.cod_persona
                  AND EXISTS (SELECT 1
                         FROM ge_cta_clientes b, ge_cuentas c, ge_est_cuentas d
                        WHERE b.cod_persona = v.cod_per_vinculo
                          AND b.relacion = 'P'
                          AND b.nro_cuenta = c.nro_cuenta
                          AND b.cod_modulo IN (5, 6)
                          AND c.cod_modulo = d.cod_modulo
                          AND c.cod_modalidad = d.cod_modalidad
                          AND c.estado = d.estado
                          AND nvl(d.activo, 'N') = 'S')
               UNION
               SELECT 1
                 FROM ba_personas b, ba_vinculos v
                WHERE v.cod_per_vinculo = x.cod_persona
                  AND v.tipo = 'E'
                  AND v.cod_persona = b.cod_persona
                  AND EXISTS (SELECT 1
                         FROM ge_cta_clientes b, ge_cuentas c, ge_est_cuentas d
                        WHERE b.cod_persona = v.cod_persona
                          AND b.relacion = 'P'
                          AND b.nro_cuenta = c.nro_cuenta
                          AND b.cod_modulo IN (5, 6)
                          AND c.cod_modulo = d.cod_modulo
                          AND c.cod_modalidad = d.cod_modalidad
                          AND c.estado = d.estado
                          AND nvl(d.activo, 'N') = 'S')));
         --*
         
         BEGIN
            -- Requerimiento: CNFAIRUNO-3.
            -- Fecha: 22/09/2014.
            SELECT tipo, cat_anterior, cod_gru_economico, cat_subjetiva, NVL(tot_deu_sistema,0) + NVL(tot_deu_con_sistema,0), cat_sistema
              INTO v_tipo_clie, v_cat_ant, v_gru_eco, v_cat_manu, v_tot_deu_sistema, v_cat_sistema
              FROM ge_clientes
             WHERE cod_persona = v_cliente;
            v_existe := 'S';
         EXCEPTION
            WHEN no_data_found THEN
               v_existe    := 'N';
               v_tipo_clie := 'X';
            WHEN too_many_rows THEN
               v_existe := 'S';
         END;
         --- Consideración del tipo de cliente para tomar el monto de la deuda
         v_lugar := 'Asigna deuda Nro. ' || v_cliente;
         --- se considera el del proceso a ayer.
         IF v_tip_implementacion <> 2 THEN
            IF v_tipo_clie IN ('R', 'G', 'M') THEN
               v_tot_deu_real := tot.ww_capital;
            ELSE
               v_tot_deu_real := tot.ww_mtorigen;
            END IF;
         ELSE
            v_tot_deu_real := tot.ww_capital;
         END IF;
         --Tipo de cliente R = Grandes deudores relacionados a la Entidad,
         --                G = Mayores deudores vinculados a otros grupos económicos
         --                M = Grandes Deudores Comerciales,
         --                N = Pequeñs deudores relacionados a la Entidad,
         --                C = Pequeños deudores comerciales,
         --                P = Deudores Personales, (consumo y vivienda)
         --                T = Micro créditos

         v_lugar := 'Verificat tip cliente: ' || v_cliente;
         IF (nvl(v_tot_deu_real, 0) > (v_min_exigido * v_por_cap_min_exigido / 100)) OR -- Cambió porcentajes según nuevas modificaciones a la Res.8 Nov/2007
            (nvl(v_tot_deu_sistema, 0) > (v_min_exigido * v_por_cap_min_exi_sistema / 100)) OR -- Aplicable a partir del 01/01/2009
            (v_gru_eco IS NOT NULL AND PAP_CAI.fu_ver_gru_mas_clie(v_gru_eco)) THEN
            -- supera el 2% en la entidad, o el 4% en el sistema financiero  ---ANTES
            -- supera el 3% en la entidad, o el 6% en el sistema financiero  ---AHORA!!
            IF fu_ver_cli_rel_enti(v_cliente) THEN
               v_tipo_clie := 'R'; -- Deudores comerciales relacionados.
            ELSE
               IF v_gru_eco IS NOT NULL AND fu_ver_gru_mas_clie(v_gru_eco) THEN
                  --si tiene grupo y hay otros clientes en el mismo then
                  v_tipo_clie := 'G'; -- Deudores vinculados a otros grupos económicos.
               -- Requerimiento: CNFAIRUNO-3.
               -- Fecha: 22/09/2014.
               ELSIF v_gru_eco IS NULL AND fu_cli_solo_consumo(v_cliente) = 'S' THEN
                  IF fu_cli_solo_vivienda(v_cliente) = 'S' THEN
                     v_tipo_clie := 'V'; -- vivienda
                  ELSE
                     v_tipo_clie := 'P'; -- personal
                  END IF;
               ELSE
                  v_tipo_clie := 'M'; -- Grandes deudores comerciales no vinculados.
               END IF;
            END IF;
         ELSIF nvl(v_tot_deu_real, 0) > (v_sal_minimo * 25) AND --- Cambió segun nuevas modif. Res.8 Nov/2007
               fu_cli_solo_consumo(v_cliente) = 'N' THEN
            -- No posee solamente créditos de consumo.
            IF fu_ver_cli_rel_enti(v_cliente) THEN
               v_tipo_clie := 'N'; -- Pequeños deudores comerciales relacionados.
            ELSE
               v_tipo_clie := 'C'; -- pequeños deudores comerciales.
            END IF;
         ELSIF fu_cli_solo_consumo(v_cliente) = 'S' THEN
            -- Requerimiento: CNFAIRUNO-3.
            -- Fecha: 22/09/2014.
            IF fu_cli_solo_vivienda(v_cliente) = 'S' THEN
               v_tipo_clie := 'V'; -- vivienda
            ELSE
               v_tipo_clie := 'P'; -- personal
            END IF;
         ELSE
            v_tipo_clie := 'T'; -- microcréditos
         END IF;

         v_lugar    := 'Ponderar deuda: ' || v_cliente;
         v_tot_pond := 0;
         v_cat_peor := 1;
         FOR det IN detalles LOOP
            v_cat_auto := det.cat_automatica;
            IF det.cod_modulo <> 6 THEN
               --- préstamos no es necesario analizar porque ya se hizo para extornar la deuda
               --- por cada operación de credito, cálculo el ponderado
               IF det.dia_atraso > 0 THEN
                  v_cat_auto := fu_obt_categ_x_mora(det.dia_atraso);
               ELSE
                  v_cat_auto := nvl(det.cat_automatica, 1);
               END IF;
               IF det.cat_renovaciones IS NOT NULL THEN
                  -- es un credito refinanciado, directamente debe tener 3, porque aun
                  -- no pago ni el 10% de su credito original
                  IF v_cat_auto < det.cat_renovaciones THEN
                     --- Si por mora tiene una categoria peor no debe mejorar
                     v_cat_auto := det.cat_renovaciones;
                  END IF;
                  v_cat_renova := round(det.cat_renovaciones);
               END IF;
               --- actualizo la ponderacion por mora ---------------------
               if det.cod_estado = 'I' then
                 UPDATE ge_cla_incobrables
                    SET cat_automatica = v_cat_auto
                  WHERE nro_cuenta = det.nro_cuenta
                    AND cod_persona = det.cod_persona
                    AND cod_estado = det.cod_estado;
               else
                 UPDATE ge_cla_operaciones
                    SET cat_automatica = v_cat_auto
                  WHERE nro_cuenta = det.nro_cuenta
                    AND cod_persona = det.cod_persona
                    AND cod_estado = det.cod_estado;
               end if;

            END IF;
            IF v_tip_implementacion = 2 THEN
               v_tot_pond := v_tot_pond + (nvl(det.oc_ttdeuda, 0) * round(v_cat_auto));
            END IF;
            IF v_tip_implementacion NOT IN (2) THEN
               v_tot_pond := v_tot_pond +
                             ((nvl(det.oc_ttdeuda, 0) + nvl(det.oc_ttdeuco, 0)) * round(v_cat_auto));
            END IF;
            -----------------------------------------------------------
         END LOOP;
         --- cálculo categoría ponderada
         v_lugar := 'Calcular cat pond.: ' || v_cliente;
         IF v_tip_implementacion <> 2 THEN
            v_cat_pond := round(trunc((v_tot_pond /
                                      (nvl(tot.ww_ttdeuda, 0) + nvl(tot.ww_ttdeuco, 0))), 2), 0);
         ELSE
            --- 2
            IF nvl(tot.ww_ttdeuda, 0) <> 0 THEN
               v_cat_pond := round(trunc(v_tot_pond / nvl(tot.ww_ttdeuda, 0), 2), 0);
            ELSE
               IF v_tot_pond > 0 THEN
                  v_cat_pond := round(trunc(v_tot_pond, 2), 0);
               ELSE
                  v_cat_pond := 1;
               END IF;
            END IF;
         END IF;
         v_lugar := 'Calcular cat final: ' || v_cliente;
         IF v_tip_implementacion = -2 THEN
            -- Para este cliente ya no se hace asi, sino como el else
            v_cat_final := nvl(v_cat_manu, round(v_cat_pond));
         ELSE
            v_cat_final := fup_obt_categoria(v_cat_pond, v_cat_manu);
         END IF;
         --- Actualizo los datos del cliente ---------------------
         --- Modifico la fecha de ultima clasificacion a efectos de previsiones
         v_lugar := 'Actualiza cliente ' || v_cliente || ' tipo ' || v_tipo_clie || ' man ' ||
                    v_cat_manu || ' final ' || v_cat_final || ' ren ' || v_cat_renova;
         IF v_cat_ant <> v_cat_final THEN
            UPDATE ge_clientes
               SET /*cat_anterior     = cat_automatica,*/---CNFICRC-323
                   fec_cat_anterior = fec_ult_clasif,
                   fec_ult_clasif   = v_fec_proceso
             WHERE cod_persona = v_cliente;
         END IF;

         --- Actualizo el resto de los datos
         v_lugar := 'Actualiza cliente: ' || v_cliente || ' tipo ' || v_tipo_clie || ' man ' ||
                    v_cat_manu || ' final ' || v_cat_final || ' ren ' || v_cat_renova;
         UPDATE ge_clientes
            SET tot_deu_real        = nvl(tot.ww_ttdeuda, 0),
                tot_deu_contingente = nvl(tot.ww_ttdeuco, 0),
                tot_gar_computables = nvl(tot.ww_garan, 0),
                tot_prevision       = nvl(tot.ww_ttprevi, 0),
                tipo                = v_tipo_clie,
                cat_subjetiva       = v_cat_manu,
                cat_automatica      = v_cat_final, -- desde la nueva Res. 8
                cat_renovaciones    = v_cat_renova,
                cat_riesgo          = round(v_cat_final, 0)
          WHERE cod_persona = v_cliente;

      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'pap_cai.Proc. Clientes ' || v_lugar || ' ' || SQLERRM);
   END;
   /* Procesar categorización de grupos económicos. */
   PROCEDURE pr_pro_cat_gru_econ IS
      CURSOR totales IS
         SELECT cod_gru_economico,
                SUM(nvl(tot_deu_real, 0)) ww_ttdeuda,
                SUM(nvl(tot_deu_contingente, 0)) ww_ttdeuco,
                SUM(nvl(tot_gar_computables, 0)) ww_ttgarco,
                SUM(nvl(capital, 0)) ww_capital,
                SUM(nvl(tot_deu_sistema, 0)) ww_tot_deu_sistema,
                SUM(nvl(tot_prevision, 0)) ww_ttprevi
           FROM ge_clientes a,
                (SELECT cod_persona, SUM(mto_original) capital
                  FROM (
                        SELECT cod_persona, mto_original
                          FROM ge_cla_operaciones a
                         where exists (select 1 from ge_cla_incobrables b where b.cod_persona = a.cod_persona)
                        union all
                        SELECT cod_persona, mto_original
                          FROM ge_cla_incobrables a
                         where exists (select 1 from ge_cla_operaciones b where b.cod_persona = a.cod_persona)
                       )
                 GROUP BY cod_persona) b
          WHERE cod_gru_economico IS NOT NULL
            AND a.cod_persona = b.cod_persona
            AND EXISTS
          (SELECT 0 FROM ge_gru_economicos b WHERE b.cod_gru_economico = a.cod_gru_economico)
          GROUP BY cod_gru_economico
         HAVING SUM(nvl(tot_deu_real, 0) + nvl(tot_deu_contingente, 0)) > 0;
      --- declaro las variables a ser utilizadas en el proc. ------
      v_gru_eco  ge_clientes.cod_gru_economico%type;
      v_factorp  NUMBER(10, 4);
      v_tot_pond NUMBER(5, 3);
      v_cat_pond NUMBER(5, 3);
      --- declaro los detalles de los clientes --------------------
      CURSOR detalles IS
         SELECT tot_deu_real, tot_deu_contingente, cat_automatica, tipo, cod_persona
         /* ROWID FILA*/
           FROM ge_clientes a
          WHERE a.cod_gru_economico = v_gru_eco
            and exists (select 1 from ge_cla_incobrables b where b.cod_persona = a.cod_persona);
   BEGIN
      
      FOR tot IN totales LOOP
         v_lugar    := 'Procesando el Grupo Economico Nro. ' ||
                       to_char(tot.cod_gru_economico, '99999');
         v_gru_eco  := tot.cod_gru_economico;
         v_tot_pond := 0;
         
         UPDATE ge_gru_economicos a
            SET cat_automatica      = 1,
                tot_deu_real        = 0,
                tot_deu_contingente = 0,
                tot_gar_computables = 0,
                tot_prevision       = 0
          WHERE a.cod_gru_economico = v_gru_eco;
         --Tipo de cliente R = Grandes deudores relacionados a la Entidad,
         --                M = Grandes Deudores Comerciales,
         --                N = Pequeños deudores relacionados a la Entidad,
         --                C = Pequeños deudores comerciales,
         --                P = Deudores Personales,
         --                T = Micro creditos
         -- Grandes deudores comerciales
         IF (nvl(tot.ww_capital, 0) > (v_min_exigido * v_por_cap_min_exigido / 100)) OR
            (nvl(tot.ww_tot_deu_sistema, 0) > (v_min_exigido * v_por_cap_min_exi_sistema / 100)) THEN
            -- supera el 2% en la entidad, o el 4% en el sistema financiero
            v_tipo_clie := 'R'; -- grandes deudores comerciales relacionados
         ELSIF nvl(tot.ww_capital, 0) > (v_sal_minimo * 5) AND
               nvl(tot.ww_capital, 0) > (v_sal_minimo * 100) THEN
            v_tipo_clie := 'N'; -- pequeños deudores comerciales relacionados
         ELSIF nvl(tot.ww_capital, 0) > (v_sal_minimo * 5) THEN
            v_tipo_clie := 'P'; -- personal
         ELSE
            v_tipo_clie := 'T'; -- microcreditos
         END IF;
         -- veo los clientes
         FOR det IN detalles LOOP
            --- por cada operación de crédito, cálculo el ponderado ---
            v_factorp  := (nvl(det.tot_deu_real, 0) + nvl(det.tot_deu_contingente, 0)) /
                          (nvl(tot.ww_ttdeuda, 0) + nvl(tot.ww_ttdeuco, 0));
            v_cat_pond := v_factorp * det.cat_automatica;
            v_tot_pond := nvl(v_tot_pond, 0) + v_cat_pond;
            --- verifico si el tipo de cliente esta ok o no ---------------
            v_tipo_clie := det.tipo;
            -- si cambio el tipo se actualizan los tipos
            IF v_tipo_clie <> det.tipo THEN
               UPDATE ge_clientes SET tipo = v_tipo_clie WHERE cod_persona = det.cod_persona;
            END IF;
         END LOOP;
         -----------------------
         UPDATE ge_gru_economicos
            SET cat_automatica      = nvl(v_tot_pond, 1),
                tot_deu_real        = nvl(tot_deu_real, 0) + nvl(tot.ww_ttdeuda, 0),
                tot_deu_contingente = nvl(tot_deu_contingente, 0) + nvl(tot.ww_ttdeuco, 0),
                tot_gar_computables = nvl(tot_gar_computables, 0) + nvl(tot.ww_ttgarco, 0),
                tot_prevision       = nvl(tot_prevision, 0) + nvl(tot.ww_ttprevi, 0)
          WHERE cod_gru_economico = v_gru_eco;
         -- actualizo la categoría  final del cliente
         UPDATE ge_clientes a
            SET a.cat_riesgo        = round(trunc(nvl(v_tot_pond, 1), 2), 0),
                a.cat_gru_economico = round(trunc(nvl(v_tot_pond, 1), 2), 0)
          WHERE cod_gru_economico = v_gru_eco;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'pap_cai.Proc. Grupos Económicos ' || SQLERRM);
   END;
  
  
   /* Proceso de categorización de préstamos. */
   PROCEDURE pr_pro_dat_prestamo IS
      --recupera la deuda de clientes x préstamos
      CURSOR préstamos IS
         SELECT b.cod_persona,
               a.nro_cuenta,
               a.cod_modulo,
               a.cod_modalidad,
               a.cod_moneda,
               NVL(a.sal_capital,0) sal_cap_batch,
               NVL(a.dia_atraso,0) dia_atraso,
               a.estado,
               DECODE(a.estado,'I',NVL(a.sal_interes,0)+NVL(a.sal_int_adelantado,0),
               NVL( a.dev_no_cobrado,0)) dev_no_cobrado,
               a.cod_oficina,
               NVL(a.tip_renovacion,'A') tipo,
               a.mto_capital,
               a.nro_cta_renovada,
               a.cat_renovaciones,
               a.tip_destino,
               c.cod_bco_central cod_sec_credito,
               NVL(f.mto_computable,0)mto_computable,
               NVL(p.monto,0)mto_prevision,
               NVL(p.tot_pri_prevision,0)mto_tot_pri_prevision,
               f.nro_cuenta nro_cta_garantia,
               a.fec_ult_categorizacion
          FROM ge_cta_clientes b,
               pr_cta_prestamos a,
               pr_sec_creditos c,
               pv_cat_gar_operaciones f,
               (SELECT pr.monto,
                       pr.tot_pri_prevision,
                       pr.nro_cuenta
                  FROM pr_previsiones pr
                 WHERE pr.fecha = (SELECT max(pv.fecha)
                                     FROM pr_previsiones pv
                                    WHERE pr.nro_cuenta = pv.nro_cuenta))p
          WHERE b.nro_cuenta = a.nro_cuenta
            AND NVL(a.sal_capital,0)+NVL(a.sal_int_adelantado,0)+NVL(a.sal_interes,0) > 0
            AND a.estado = 'I'
            AND a.cod_sec_credito = c.cod_sec_credito
            AND b.relacion='P'
            AND f.nro_cuenta(+) = a.nro_cuenta
            AND p.nro_cuenta(+) = a.nro_cuenta
            and exists (select 1 from ge_cla_operaciones d where d.cod_persona = b.cod_persona)
        order by a.cod_moneda;

      rv_oper          ge_cla_operaciones%ROWTYPE;
      v_tot_deuda      NUMBER(18, 2);
      v_dev_no_cobrado NUMBER(18, 2);
      v_tot_dev_no_cob NUMBER(18, 2);
      v_mto_original   NUMBER(18, 2);
      v_gar_operacion  NUMBER(18, 2);
      v_cliente        ge_cta_clientes.cod_persona%TYPE;
      v_cat_auto       ge_cla_operaciones.cat_automatica%TYPE;
      v_cat_renov      ge_clientes.cat_riesgo%TYPE;
      v_pue_categoria  VARCHAR2(01);
      v_pue_prevision  VARCHAR2(01);
      v_mon_anterior   pr_cta_prestamos.cod_moneda%TYPE;
      v_redondeo       NUMBER;
      v_cotizacion     ge_cotizaciones.val_conversion%TYPE;
      v_cat_mejorada   varchar2(3); 
      FUNCTION fl_rec_deu_codeudor(p_cliente IN ge_clientes.cod_persona%TYPE) RETURN NUMBER IS
         v_tot_codeudor ge_cla_operaciones.tot_deu_contingente%TYPE;
      BEGIN
         SELECT nvl(SUM(nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0)), 0)
           INTO v_tot_codeudor
           FROM pr_cta_prestamos p, pr_cta_garantias a
          WHERE p.nro_cuenta = a.nro_cuenta
            AND a.cod_garantia = 2 -- codeudoria
            AND a.nro_garantia = p_cliente
            AND p.estado NOT IN ('N', 'I');
         RETURN v_tot_codeudor;
      END;
      --- Consideraciones: Queda definido que se categoriza al préstamo
      --- con la Clasificacion obtenida por el cliente el dia de ayer.
   BEGIN
      dbms_mview.refresh('PV_CAT_GAR_OPERACIONES');
      v_mon_anterior := v_mon_local;
      v_cotizacion   := 1;
      v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_mon_local);
      FOR pr IN préstamos LOOP
         v_lugar   := 'Procesando préstamo Nro. ' || pr.nro_cuenta; --
         v_cliente := pr.cod_persona;
         --- Recuperar categoría  del cliente
         BEGIN
            SELECT tipo INTO v_tipo_clie FROM ge_clientes WHERE cod_persona = v_cliente;
         EXCEPTION
            WHEN no_data_found THEN
               v_tipo_clie := 'X';
         END;
         --- EXTORNO de interes
         --- por cada operación de credito, su categoría  para extornar
         IF pr.dia_atraso > 0 THEN
            v_cat_auto := fu_obt_categ_x_mora(pr.dia_atraso);
         ELSE
            v_cat_auto := 1;
         END IF;
         v_pue_categoria := 'N';
         v_cat_renov     := NULL;
         v_pue_prevision := NULL; --agregado 17/05/2012 segun mail de JS
         v_cat_mejorada  := NULL; --> DYDMR-3169
         IF pr.cat_renovaciones IS NOT NULL THEN
            v_cat_renov := pr.cat_renovaciones;
            -- Verificar si puede mejorar su categoria
            PAP_CAI.pr_obt_for_pag_rrr(pr.nro_cuenta, pr.fec_ult_categorizacion,
                                       v_pue_categoria, v_pue_prevision, v_cat_mejorada);-->DYDMR-3169
            IF v_pue_categoria = 'S' THEN
               IF v_cat_renov >= 2 THEN
                  --DYDMR-7772 - Incidencia SAU - ITGF - Cierre 17/11 Categorizacion de Clientes
                  If (nvl(v_cat_renov,0) - nvl(v_cat_mejorada,0)) <= 0 then
                     v_cat_renov := 1;
                  Elsif (nvl(v_cat_renov,0) - nvl(v_cat_mejorada,0)) > 0 then
                     v_cat_renov := v_cat_renov - v_cat_mejorada;
                  end if;

               ELSE
                  v_cat_renov := 1;
               END IF;
            END IF;
            -- es un credito refinanciado, directamente debe tener 3, porque aun
            -- no pago ni el 10% de su credito original
            IF v_cat_auto < v_cat_renov THEN
               --- Si por mora tiene una categoria peor no debe mejorar
               v_cat_auto := v_cat_renov;
            END IF;
         END IF;

         -- Inicializo el dev no cobrado
         v_dev_no_cobrado := nvl(pr.dev_no_cobrado, 0);
         IF v_cat_auto > 2 THEN
            NULL;
            --- Obs: Aqui se debe generar el movimiento de extorno y transferencia a dev en suspenso
         END IF;
         IF (v_mon_anterior) <> pr.cod_moneda THEN
            IF pr.cod_moneda <> v_mon_local THEN
               v_cotizacion := pag_gen.fu_obt_cotizacion(pr.cod_moneda, v_fec_proceso);
            ELSE
               -- es moneda local - guaraníes -------------------------------
               v_cotizacion := 1;
            END IF;
         END IF;

         v_tot_deuda      := round((nvl(pr.sal_cap_batch, 0) + nvl(v_dev_no_cobrado, 0)) *
                                   v_cotizacion, v_redondeo);
         v_tot_dev_no_cob := round(nvl(v_dev_no_cobrado, 0) * v_cotizacion, v_redondeo);
         ---4. inserto el registro de la operación ----------------------
         IF pr.nro_cta_garantia IS NOT NULL THEN
            v_gar_operacion := round(nvl(pr.mto_computable, 0) * v_cotizacion, v_redondeo);
         ELSE
            v_gar_operacion := 0;
         END IF;
         -- Veo el monto original de la operacion------------------------
         v_mto_original := nvl(pr.mto_capital, 0);
         IF pr.tipo <> 'A' THEN
            -- es una operación renovada, busco el monto original del credito
            BEGIN
               SELECT mto_capital
                 INTO v_mto_original
                 FROM pr_cta_prestamos
                WHERE nro_cuenta = pr.nro_cta_renovada;
            EXCEPTION
               WHEN OTHERS THEN
                  -- sino encuentra o tiene problemas en la busqueda se asigna el actual
                  v_mto_original := nvl(pr.mto_capital, 0);
            END;
         END IF;
         -- inserto el registro de la operación --------------------------
         rv_oper.cod_persona         := pr.cod_persona;
         rv_oper.nro_cuenta          := pr.nro_cuenta;
         rv_oper.cod_modulo          := pr.cod_modulo;
         rv_oper.cod_modalidad       := pr.cod_modalidad;
         rv_oper.cod_estado          := pr.estado;
         rv_oper.tot_deu_real        := v_tot_deuda;
         rv_oper.tot_deu_contingente := 0;
         rv_oper.dev_no_cobrado      := v_tot_dev_no_cob;
         rv_oper.tot_gar_computables := nvl(v_gar_operacion, 0);
         rv_oper.dia_atraso          := pr.dia_atraso;
         rv_oper.cod_moneda          := pr.cod_moneda;
         rv_oper.cod_oficina         := pr.cod_oficina;
         rv_oper.tipo                := pr.tipo;
         rv_oper.cat_renovaciones    := v_cat_renov;
         rv_oper.cat_ren_anterior    := pr.cat_renovaciones;
         rv_oper.lib_prevision       := v_pue_prevision;
         rv_oper.cat_automatica      := v_cat_auto;
         rv_oper.tot_prevision     := PAP_CAI.fu_con_a_guaranies(pr.cod_moneda, pr.mto_prevision);
         rv_oper.tot_pri_prevision := PAP_CAI.fu_con_a_guaranies(pr.cod_moneda,
                                                                 pr.mto_tot_pri_prevision);
         -- se pasa el monto original del credito a guaraníes ------------
         rv_oper.mto_original := fu_con_a_guaranies(pr.cod_moneda, v_mto_original);
         -- Requerimiento: CNFAIRUNO-3.
         -- Fecha: 22/09/2014.
         IF fug_obt_pardinamico('COD_MOD_PRE_FUNCIONARIOS', pr.cod_modulo, pr.cod_modalidad) = 'S' THEN
            rv_oper.cod_sec_credito     := 701;
            rv_oper.tip_destino         := 4;
         ELSE
            rv_oper.cod_sec_credito     := nvl(pr.cod_sec_credito, 701);
            rv_oper.tip_destino         := fu_obt_tip_destino(pr.cod_persona, pr.cod_modulo, pr.cod_modalidad, rv_oper.cod_sec_credito, NVL(v_tot_deuda,0));
         END IF;
         --
         pr_ins_ge_cla_inc(rv_oper);
         v_mon_anterior := pr.cod_moneda;
         --- Actualizar categoria de renovacion para mejorar categoria final
         IF v_cat_renov IS NOT NULL AND v_cat_renov <> pr.cat_renovaciones THEN
            UPDATE pr_cta_prestamos
               SET cat_renovaciones = v_cat_renov
             WHERE nro_cuenta = pr.nro_cuenta;
         END IF;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'pap_cai.Proc. préstamo ' || SQLERRM);
   END;
   
   /* Proceso de categorización de Operaciones Vencidas. */
   PROCEDURE pr_pro_dat_ope_ven IS
      --recupera la deuda de clientes x préstamos
      CURSOR préstamos IS
         SELECT b.cod_persona,a.nro_cuenta,a.cod_modulo, a.cod_modalidad,
                a.cod_moneda,
                NVL(a.sal_total,0) sal_cap_batch,
                NVL(a.dia_atraso,0) dia_atraso, a.estado,
                a.cod_oficina,a.mto_origen mto_capital,
                nvl(f.mto_computable,0)mto_computable,
                nvl(ov.monto,0)mto_prevision,
                nvl(ov.tot_pri_prevision,0)mto_tot_pri_prevision,
                f.nro_cuenta nro_cta_garantia
           FROM ge_cta_clientes b, ov_cta_vencidas a,
                pv_cat_gar_operaciones f,
                (SELECT(pr.monto),
                        pr.tot_pri_prevision,
                        pr.nro_cuenta
                   FROM ov_previsiones pr
                  WHERE pr.fecha = (SELECT MAX(pv.fecha)
                                      FROM ov_previsiones pv
                                     WHERE pr.nro_cuenta = pv.nro_cuenta))ov
          WHERE a.nro_cuenta = b.nro_cuenta
            AND f.nro_cuenta(+) = a.nro_cuenta
            AND ov.nro_cuenta(+)=a.nro_cuenta
            AND NVL(a.sal_total,0) > 0
            AND a.estado = 'I'
            AND b.relacion ='P'
            and exists (select 1 from ge_cla_operaciones c where c.cod_persona = b.cod_persona)
      order by a.cod_moneda;

      rv_oper         ge_cla_operaciones%ROWTYPE;
      v_tot_deuda     NUMBER(18, 2);
      v_mto_original  NUMBER(18, 2);
      v_gar_operacion NUMBER(18, 2);
      v_cliente       ge_cta_clientes.cod_persona%TYPE;
      v_cat_auto      ge_cla_operaciones.cat_automatica%TYPE;
      v_mon_anterior  ov_cta_vencidas.cod_moneda%TYPE;
      v_redondeo      NUMBER;
      v_cotizacion    ge_cotizaciones.val_conversion%TYPE;
      --- Consideraciones: Queda definido que se categoriza a la cuenta
      --- con la Clasificacion obtenida por el cliente el dia de ayer.
   BEGIN
      dbms_mview.refresh('PV_CAT_GAR_OPERACIONES');
      v_mon_anterior := v_mon_local;
      v_cotizacion   := 1;
      v_redondeo     := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_mon_local);
      FOR pr IN préstamos LOOP
         v_lugar   := 'Procesando préstamo Nro. ' || pr.nro_cuenta; --
         v_cliente := pr.cod_persona;
         --- Recuperar categoría del cliente
         BEGIN
            SELECT tipo INTO v_tipo_clie FROM ge_clientes WHERE cod_persona = v_cliente;
         EXCEPTION
            WHEN no_data_found THEN
               v_tipo_clie := 'X';
         END;
         -- se calcula la categoría de acuerdo a la mora-------------
         IF pr.dia_atraso > 0 THEN
            v_cat_auto := fu_obt_categ_x_mora(pr.dia_atraso);
         ELSE
            v_cat_auto := 1;
         END IF;
         ---1. cálculo la deuda en la moneda local ----------------------
         IF (v_mon_anterior) <> pr.cod_moneda THEN
            IF pr.cod_moneda <> v_mon_local THEN
               v_cotizacion := pag_gen.fu_obt_cotizacion(pr.cod_moneda, v_fec_proceso);
            ELSE
               -- es moneda local - guaraníes -------------------------------
               v_cotizacion := 1;
            END IF;
         END IF;
         v_tot_deuda := round(nvl(pr.sal_cap_batch, 0) * v_cotizacion, v_redondeo);
         IF pr.nro_cta_garantia IS NOT NULL THEN
            v_gar_operacion := round(nvl(pr.mto_computable, 0) * v_cotizacion, v_redondeo);
         ELSE
            v_gar_operacion := 0;
         END IF;
         ---4. inserto el registro de la operación ----------------------
         -- Veo el monto original de la operacion------------------------
         v_mto_original := nvl(pr.mto_capital, 0);
         -- inserto el registro de la operación --------------------------
         rv_oper.cod_persona         := pr.cod_persona;
         rv_oper.nro_cuenta          := pr.nro_cuenta;
         rv_oper.cod_modulo          := pr.cod_modulo;
         rv_oper.cod_modalidad       := pr.cod_modalidad;
         rv_oper.cod_estado          := pr.estado;
         rv_oper.tot_deu_real        := v_tot_deuda;
         rv_oper.tot_deu_contingente := 0;
         rv_oper.dev_no_cobrado      := 0;
         rv_oper.tot_gar_computables := nvl(v_gar_operacion, 0);
         rv_oper.dia_atraso          := pr.dia_atraso;
         rv_oper.cod_moneda          := pr.cod_moneda;
         rv_oper.cod_oficina         := pr.cod_oficina;
         rv_oper.tipo                := 'A';
         rv_oper.cat_renovaciones    := NULL;
         rv_oper.cat_automatica      := v_cat_auto;
         rv_oper.tot_prevision       := PAP_CAI.fu_con_a_guaranies(pr.cod_moneda, pr.mto_prevision);
         rv_oper.tot_pri_prevision   := PAP_CAI.fu_con_a_guaranies(pr.cod_moneda,
                                                                   pr.mto_tot_pri_prevision);
         -- se pasa el monto original del credito a guaraníes ------------
         rv_oper.mto_original := fu_con_a_guaranies(pr.cod_moneda, v_mto_original);
         -- Requerimiento: CNFAIRUNO-3.
         -- Fecha: 22/09/2014.
         rv_oper.cod_sec_credito     := NVL(fu_obt_cod_actividad(pr.cod_persona),701);
         rv_oper.tip_destino         := fu_obt_tip_destino(pr.cod_persona, pr.cod_modulo, pr.cod_modalidad, rv_oper.cod_sec_credito, NVL(v_tot_deuda,0));
         --
         pr_ins_ge_cla_inc(rv_oper);
         v_mon_anterior := pr.cod_moneda;
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'pap_cai.Proc. préstamo ' || SQLERRM);
   END;
   --
   PROCEDURE pr_ins_ge_cla_inc(rp_oper IN ge_cla_operaciones%ROWTYPE) IS
      v_can_dias number;
      v_tot_gar_computable ge_cla_incobrables.tot_gar_computables%type;
   BEGIN
      if rp_oper.cat_automatica = 6 then
        BEGIN
          select v_fec_proceso - c.fec_ult_clasif
            into v_can_dias
            from ge_clientes c
           where cod_persona = rp_oper.cod_persona;
        EXCEPTION
          WHEN OTHERS THEN
            v_can_dias := 0;
        END;

        IF nvl(v_can_dias, 0) >= 545 then
           v_tot_gar_computable := 0;
        else
           v_tot_gar_computable := rp_oper.tot_gar_computables;
        end if;
      else
        v_tot_gar_computable := rp_oper.tot_gar_computables;
      end if;


      INSERT INTO ge_cla_incobrables
         (cod_persona, nro_cuenta, cod_modulo, cod_modalidad, cod_estado, tot_deu_real,
          tot_deu_contingente, dev_no_cobrado, cat_automatica, dia_atraso, cod_moneda,
          tot_gar_computables, cod_oficina, tipo, tot_prevision, mto_original, tip_destino,
          cod_sec_credito, cat_renovaciones, cat_ren_anterior, lib_prevision, tot_pri_prevision)
      VALUES
         (rp_oper.cod_persona, rp_oper.nro_cuenta, rp_oper.cod_modulo, rp_oper.cod_modalidad,
          rp_oper.cod_estado, rp_oper.tot_deu_real, rp_oper.tot_deu_contingente,
          rp_oper.dev_no_cobrado, rp_oper.cat_automatica, rp_oper.dia_atraso, rp_oper.cod_moneda,
          v_tot_gar_computable, rp_oper.cod_oficina, rp_oper.tipo, rp_oper.tot_prevision,
          rp_oper.mto_original, rp_oper.tip_destino, rp_oper.cod_sec_credito,
          rp_oper.cat_renovaciones, rp_oper.cat_ren_anterior, rp_oper.lib_prevision,
          rp_oper.tot_pri_prevision);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 SQLERRM || ' al Ins. GE_CLA_INCOBRABLES Clie -' ||
                                  rp_oper.cod_persona || ' Cta. ' || rp_oper.nro_cuenta);
   END;
  
   /* Verifica si el cliente esta relacionado con la entidad. */
   FUNCTION fu_ver_cli_rel_enti(p_cod_persona IN VARCHAR2) RETURN BOOLEAN IS
      v_existe        VARCHAR2(1);
      v_gru_economico ge_clientes.cod_gru_economico%TYPE := fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD');
   BEGIN
      SELECT '*'
        INTO v_existe
        FROM ge_clientes g
       WHERE g.cod_persona = p_cod_persona
         AND nvl(g.cod_gru_economico, -1) = v_gru_economico;
      RETURN TRUE;
   EXCEPTION
      WHEN too_many_rows THEN
         RETURN TRUE;
      WHEN no_data_found THEN
         RETURN FALSE;
      WHEN OTHERS THEN
         RETURN FALSE;
   END;
   /* Solo para RRR, se verifica la forma de pago de la nueva operación */
   PROCEDURE pr_obt_for_pag_rrr
   (
      p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
      p_fec_ult_categorizacion IN pr_cta_prestamos.fec_ult_categorizacion%TYPE,
      p_pue_categoria IN OUT VARCHAR2, --- Puede mejorar categoría S/N
      p_pue_prevision IN OUT VARCHAR2,
      P_CAT_MEJORADA  OUT    VARCHAR2 -->DYDMR-3169
   ) --- Puede liberar previsión S/N
    IS
      v_por_pago NUMBER(15, 2);
      v_mto_capital     PR_CUOTAS.MTO_CAPITAL%TYPE;
      v_mto_cap_cobrado PR_COBROS.MTO_CAPITAL%TYPE;
      v_por_cat_mejora  NUMBER(2)   := FUG_OBT_PARDINAMICO('SIB_POR_CAT_MEJORADA');
      --> DYDMR-3169
    v_mto_interes     PR_CUOTAS.Mto_Interes%type;
      v_mto_int_cobrado PR_COBROS.Mto_Interes%type;
      v_mto_original    PR_CUOTAS.MTO_CAPITAL%TYPE;
      v_mto_cobrado     PR_CUOTAS.Mto_Interes%type;
   BEGIN
      p_cat_mejorada    := null; -->DYDMR-3169
      p_pue_categoria   := 'N';
      p_pue_prevision   := 'N';
      v_mto_capital     := FUP_OBT_MTO_CAPITAL(p_nro_cuenta, NULL, NULL, 'O' , 'M', p_fec_ult_categorizacion);
      v_mto_cap_cobrado := FUP_OBT_MTO_CAPITAL(p_nro_cuenta, NULL, NULL, NULL, 'C', p_fec_ult_categorizacion);
    --> DYDMR-3169
      v_mto_interes     := FUP_OBT_MTO_CAPITAL(p_nro_cuenta, NULL, NULL, 'O' , 'M', p_fec_ult_categorizacion, 'I');
      v_mto_int_cobrado := FUP_OBT_MTO_CAPITAL(p_nro_cuenta, NULL, NULL, NULL, 'C', p_fec_ult_categorizacion, 'I');
      v_mto_original    := v_mto_capital + v_mto_interes;
      v_mto_cobrado     := v_mto_cap_cobrado + v_mto_int_cobrado;
      -- DYDMR-2418 -- CN: 09/2015 - Para evitar divisor cero
      If nvl(v_mto_original,0) > 0 Then
       --> DYDMR-3169
         v_por_pago  := round((v_mto_cobrado * 100) / v_mto_original);
      else
         v_por_pago  := 0;
      end if;
      --
      IF v_por_pago >= v_por_cat_mejora THEN
         p_pue_categoria := 'S';
         p_pue_prevision := 'S';
     --> DYDMR-3169
         p_cat_mejorada  := floor(v_por_pago/v_por_cat_mejora);
         If p_cat_mejorada <= 0 Then
            p_cat_mejorada := 1;
         End If;
         UPDATE pr_cta_prestamos
            SET fec_ult_categorizacion = v_fec_proceso
          WHERE nro_cuenta = p_nro_cuenta;
      END IF;
   END;

   /* Verifica si el grupo económico tiene más de un cliente. */
   FUNCTION fu_ver_gru_mas_clie(p_cod_gru_economico IN ge_gru_economicos.cod_gru_economico%TYPE)
      RETURN BOOLEAN IS
      v_cant NUMBER(20) := 0;
   BEGIN
      SELECT COUNT(1)
        INTO v_cant
        FROM ge_clientes c
       WHERE c.cod_gru_economico = p_cod_gru_economico
         AND EXISTS (SELECT 1
                       FROM ge_cla_operaciones ge
                      WHERE ge.cod_persona = c.cod_persona);
      IF v_cant > 1 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN FALSE;
   END;

END PAP_CAI;
/

