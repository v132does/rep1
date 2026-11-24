create or replace PACKAGE BODY  IT.PAG_BOL IS
/*
  Descripcion:
   Paquete que busca encontrar las diferencias de saldos diarios tanto para saldo batch y saldo en linea.
   actualmente se encuentra desarrollado para los movimientos de tipo de saldo 'DISPONIBLE'

   AUTOR   FECHA       DESCRIPCION
   ------  ----------  ---------------------------------------------------
   MJUAREZ 05-Feb-2025 Version inicial

   MJUAREZ 22-May-2025 Se agrega que las cuentas con diferencia de saldos existan en la tabla TM_LOG_CONTROLES
                       en el mismo dia, de esta forma evitamos agarrar diferencias arregladas en el esquema nocturno
                       y replicamos esa tabla de diferencias, se mantiene el calculo inicial y solamente se compara con
                       esa tabla, luege comparamos la diferencia nueva con la anterior para determinar el saldo de variacion

   MJUAREZ 11-Jun-2025 Se evidencian cuentas que tuvieron diferencias de saldo el dia anterior al que lo encontramos ya que
                       respetamos la tabla TM_LOG_CONTROLES, para esto se parcea la auditoria del dia anterior para comparar esas
                       diferencias tambien y lograr segmentarlas, se calcula v_fec_anterior -3 para los dias lunes (comparar con viernes)

   MJUAREZ 27-Jun-2025 Se agrega el prodecimiento prg_lim_segmentacion que se encarga de limpiar los montos segmentados que no coincidan con su diferencia

   MJUAREZ 29-Sep-2025 Cambio como se calcula v_val_diferencia para cambiar el sentido de la segmentacion
                       Agrego manejo de sentido para los casos de genero movimiento no afecto saldo por regla de negocio

   MJUAREZ 27-Nov-2025 Se agrega campo "SENTIDO" en la tabla ge_cta_dif_segmentadas para tener un control de los sentidos que modificamos de forma manual
              
   MJUAREZ 04-Mar-2026 Se agregar funcion fnc_normaliza_signo_dif para manejo de signos sentido contrario y validacion en monto correcto a la hora de limpieza                    

  GMPEREIRA 18-May-2026 Se aplicaron cambios en el proceso para incluir las diferencias en cuentas corrientes (cod modalidad 41)

  MJUAREZ   08-Jun-2026 Se agregan tipos de saldo BLOQUEADO-RETENIDO al proceso de segmentacion y se cambia forma de buscar en ah_movimientos por una vista para mejor performance
  
  MJUAREZ   14-Ago-2026 Se agrega bloqueado, retenido a CC y corte de control para evitar correr mucho tiempo el job en produccion
  
*/

  PROCEDURE pr_pro_dif_saldos (P_FECHA DATE,
                               P_FECHA_ANT DATE) AS


/* Descripcion:
   Procedimiento que se corre diariamente para encontrar cuentas con diferencias, llenara ge_cta_dif_saldos las cuentas con diferencias nuevas, comparando el historico
   de tm_log_controles tanto las nuevas que aparezcan como las que ya tenian diferencia pero presentaron otra diferencia

    Procedimiento que busca:
     1. Cuentas nuevas que aparecen en p_fecha y no existían en la fecha anterior
     2. Cuentas que estaban en ambos días pero cambió el valor de la diferencia
     3. Se inserta indicando si es SALDO ONLINE, BLOQUEADO o RETENIDO
  */

      TYPE t_claves IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(60);
       
      v_dif_anteriores t_claves;
      v_dif_actual       VARCHAR2(100);
      v_dif_anterior     VARCHAR2(100);
      v_clave_compuesta  VARCHAR2(60);
      v_dif_saldo        NUMBER;
      v_dif_saldo_ant    NUMBER;
      v_sal_online       NUMBER;
      v_sal_batch        NUMBER;
      v_corte_activo      VARCHAR2(1000);
      v_corte_max         NUMBER;
      v_conteo            NUMBER;
      v_cod_modalidad     VARCHAR2(100);


      /* Función auxiliar: convierte a NUMBER o devuelve NULL si no es convertible */
    FUNCTION to_number_null(p_text VARCHAR2) RETURN NUMBER IS

        v_num NUMBER;

      BEGIN

        IF p_text IS NULL THEN
          RETURN NULL;  
        END IF;

        BEGIN
          v_num := TO_NUMBER(p_text);
          RETURN v_num;

        EXCEPTION
          WHEN VALUE_ERROR THEN
            RETURN NULL;
          WHEN OTHERS THEN
            RETURN NULL;
        END;

    END to_number_null;

   BEGIN

      -- TN-1133: Leer parámetros de control una sola vez
      BEGIN
        SELECT val_parametro 
        INTO v_corte_activo
        FROM IT.GE_PAR_DINAMICOS
        WHERE parametro = 'DIF_SAL_CORTE_ACTIVO'
        AND cod_modulo IS NULL 
        AND cod_modalidad IS NULL 
        AND cod_oficina IS NULL;
        
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_corte_activo := 'N';  
      END;

      BEGIN
        SELECT VAL_DEFECTO 
        INTO v_corte_max 
        FROM IT.GE_PARAMETROS 
        WHERE PARAMETRO='DIF_SAL_CORTE_MAX';
        
        v_corte_max := TO_NUMBER(NVL(v_corte_max, '1000'));
        
      EXCEPTION 
       WHEN NO_DATA_FOUND THEN v_corte_max := 1000;
      END;

      DELETE FROM IT.GE_DIF_MODALIDAD_CORTE_TMP;
      COMMIT;

      -- TN-1118: Loop por modalidad para control granular de corte
      FOR modalidad_rec IN (
                            SELECT DISTINCT cod_modalidad
                            FROM IT.TM_LOG_CONTROLES
                            WHERE fecha = P_FECHA
							AND COD_MODALIDAD IN ('31','334','41')
                            ORDER BY cod_modalidad
      ) LOOP
      
        v_cod_modalidad := modalidad_rec.cod_modalidad;

        v_dif_anteriores.DELETE;

      -- Cargar diferencias del día anterior en colección (filtradas por modalidad)
      FOR r IN (
        WITH c_dia_anterior AS (
          SELECT DISTINCT log.CLAVE,
                 log.OBSERVACION,
                 CASE
                   WHEN log.OBSERVACION LIKE '%Saldo Total%' THEN 'DISPONIBLE'
                   WHEN log.OBSERVACION LIKE '%Bloqueado%'   THEN 'BLOQUEADO'
                   WHEN log.OBSERVACION LIKE '%Retenido%'    THEN 'RETENIDO'
                   ELSE 'DESCONOCIDO'
                 END AS tip_saldo
          FROM IT.TM_LOG_CONTROLES log
          JOIN( SELECT nro_cuenta, cod_modalidad, cod_moneda, denominacion,
                       sal_total, sal_tot_batch, sal_bloqueado, sal_blo_batch,
                       sal_retenido, sal_ret_batch,
                       'AHORROS A LA VISTA' AS modalidad
                  FROM IT.AH_CTA_VISTAS
                 WHERE COD_MODALIDAD IN ('31','334')
             UNION ALL
                SELECT nro_cuenta, cod_modalidad, cod_moneda, denominacion,
                       sal_total, sal_tot_batch, sal_bloqueado, sal_blo_batch,
                       sal_retenido, sal_ret_batch,
                       'CUENTA CORRIENTE' AS modalidad
                  FROM IT.CC_CTA_CORRIENTES
                 WHERE cod_modalidad = '41' 
               ) cta ON log.CLAVE = cta.NRO_CUENTA
         WHERE log.FECHA = p_fecha_ant
           AND log.TIP_CONTROL = 'DIFERENCIA EN SALDOS BATCH ONLINE'
           AND log.OBSERVACION LIKE '%Saldo%'
           AND cta.COD_MODALIDAD IN ('31','334', '41')
           AND cta.COD_MODALIDAD = v_cod_modalidad
           AND ( cta.SAL_TOT_BATCH <> cta.SAL_TOTAL
                 OR cta.SAL_BLOQUEADO <> cta.SAL_BLO_BATCH
                 OR cta.SAL_RETENIDO <> cta.SAL_RET_BATCH )
        ) SELECT * FROM c_dia_anterior
      ) LOOP
        v_dif_anterior := REGEXP_SUBSTR(r.OBSERVACION, 'Dif\. ?: *-?[0-9]+');
        v_clave_compuesta := r.CLAVE || '_' || r.tip_saldo;
        v_dif_anteriores(v_clave_compuesta) := v_dif_anterior;
      END LOOP;

      ---------------------------------------------------------------------
      -- 2) Procesar diferencias del día actual
      ---------------------------------------------------------------------
      FOR r IN (
            WITH c_dia_actual AS (
      SELECT DISTINCT log.CLAVE,
             log.OBSERVACION,
             cta.nro_cuenta,
             cta.cod_modalidad,
             cta.modalidad,
             cta.cod_moneda,
             cta.denominacion,
             CASE
               WHEN log.OBSERVACION LIKE '%Saldo Total%' THEN 'DISPONIBLE'
               WHEN log.OBSERVACION LIKE '%Bloqueado%'   THEN 'BLOQUEADO'
               WHEN log.OBSERVACION LIKE '%Retenido%'    THEN 'RETENIDO'
               ELSE 'DESCONOCIDO'
             END AS tip_saldo
      FROM IT.TM_LOG_CONTROLES log
      JOIN (
             SELECT nro_cuenta, cod_modalidad, cod_moneda, denominacion,
                    sal_total, sal_tot_batch,
                    sal_bloqueado, sal_blo_batch,
                    sal_retenido, sal_ret_batch,
                    'AHORROS A LA VISTA' AS modalidad
             FROM IT.AH_CTA_VISTAS
             WHERE COD_MODALIDAD IN ('31','334')
             UNION ALL
             SELECT nro_cuenta, cod_modalidad, cod_moneda, denominacion,
                    sal_total, sal_tot_batch,
                    sal_bloqueado, sal_blo_batch,
                    sal_retenido, sal_ret_batch,
                    'CUENTA CORRIENTE' AS modalidad
             FROM IT.CC_CTA_CORRIENTES
             WHERE cod_modalidad = '41'
           ) cta ON log.CLAVE = cta.NRO_CUENTA
               AND log.COD_MODALIDAD = cta.COD_MODALIDAD
      WHERE log.FECHA = p_fecha
        AND log.TIP_CONTROL = 'DIFERENCIA EN SALDOS BATCH ONLINE'
        AND log.OBSERVACION LIKE '%Saldo%'
        AND cta.COD_MODALIDAD = v_cod_modalidad
        AND ( cta.SAL_TOT_BATCH <> cta.SAL_TOTAL
           OR cta.SAL_BLOQUEADO <> cta.SAL_BLO_BATCH
           OR cta.SAL_RETENIDO <> cta.SAL_RET_BATCH )
    )
    SELECT * FROM c_dia_actual
      ) LOOP

        -- Extraer texto de diferencia
        v_dif_actual := REGEXP_SUBSTR(r.OBSERVACION, 'Dif\. ?: *-?[0-9]+');
        v_clave_compuesta := r.CLAVE || '_' || r.tip_saldo;
        v_dif_saldo := to_number_null(REGEXP_SUBSTR(v_dif_actual, '-?[0-9]+'));

        -- Según tipo de saldo, tomar saldos online y batch (todos con to_number_null)
        IF r.tip_saldo = 'DISPONIBLE' THEN
          v_sal_online := to_number_null(REGEXP_SUBSTR(r.OBSERVACION, 'Saldo Total: *(-?[0-9]+)', 1,1,NULL,1));
          v_sal_batch  := to_number_null(REGEXP_SUBSTR(r.OBSERVACION, 'Saldo Total Batch: *(-?[0-9]+)', 1,1,NULL,1));

        ELSIF r.tip_saldo = 'BLOQUEADO' THEN
          v_sal_online := to_number_null(REGEXP_SUBSTR(r.OBSERVACION, 'Saldo Bloqueado: *(-?[0-9]+)', 1,1,NULL,1));
          v_sal_batch  := to_number_null(REGEXP_SUBSTR(r.OBSERVACION, 'Saldo Bloqueado Batch: *(-?[0-9]+)', 1,1,NULL,1));

        ELSIF r.tip_saldo = 'RETENIDO' THEN
          v_sal_online := to_number_null(REGEXP_SUBSTR(r.OBSERVACION, 'Saldo Retenido: *(-?[0-9]+)', 1,1,NULL,1));
          v_sal_batch  := to_number_null(REGEXP_SUBSTR(r.OBSERVACION, 'Saldo Retenido Batch: *(-?[0-9]+)', 1,1,NULL,1));

        ELSE
          v_sal_online := NULL;
          v_sal_batch  := NULL;
        END IF;

        -- Si no existía el día anterior NUEVA diferencia
        IF NOT v_dif_anteriores.EXISTS(v_clave_compuesta) THEN

          INSERT INTO IT.GE_CTA_DIF_SALDOS (
                                            fecha,
                                            nro_cuenta,
                                            cod_modalidad,
                                            modalidad,
                                            cod_moneda,
                                            denominacion,
                                            tip_saldo,
                                            sal_online,
                                            sal_batch,
                                            dif_saldo,
                                            var_dif_saldo,
                                            nueva,
                                            estado,
                                            fec_estado,
                                            usu_insercion,
                                            fec_insercion
                                            )

                                            VALUES 
                                            (
                                            p_fecha,
                                            r.nro_cuenta,
                                            r.cod_modalidad,
                                            r.modalidad,
                                            r.cod_moneda,
                                            r.denominacion,
                                            r.tip_saldo,
                                            v_sal_online,
                                            v_sal_batch,
                                            v_dif_saldo,
                                            v_dif_saldo,
                                            'S',
                                            'INGRESADO',
                                            SYSDATE,
                                            USER,
                                            SYSDATE
                                            );

        ELSE

          --  Si ya existía  ver si cambió la diferencia
          v_dif_anterior := v_dif_anteriores(v_clave_compuesta);

             IF v_dif_actual IS NOT NULL
             AND v_dif_anterior IS NOT NULL
             AND v_dif_actual <> v_dif_anterior THEN

            v_dif_saldo_ant := to_number_null(REGEXP_SUBSTR(v_dif_anterior, '-?[0-9]+'));

            INSERT INTO IT.GE_CTA_DIF_SALDOS  (
                                              fecha,
                                              nro_cuenta,
                                              cod_modalidad,
                                              modalidad,
                                              cod_moneda,
                                              denominacion,
                                              tip_saldo,
                                              sal_online,
                                              sal_batch,
                                              dif_saldo,
                                              var_dif_saldo,
                                              nueva,
                                              estado,
                                              fec_estado,
                                              usu_insercion,
                                              fec_insercion  
                                              )

                                            VALUES 
                                              (
                                              p_fecha,
                                              r.nro_cuenta,
                                              r.cod_modalidad,
                                              r.modalidad,
                                              r.cod_moneda,
                                              r.denominacion,
                                              r.tip_saldo,
                                              v_sal_online,
                                              v_sal_batch,
                                              v_dif_saldo,
                                              CASE WHEN v_dif_saldo IS NULL OR v_dif_saldo_ant IS NULL THEN NULL ELSE v_dif_saldo - v_dif_saldo_ant END,
                                              'N',
                                              'INGRESADO',
                                              SYSDATE,
                                              USER,
                                              SYSDATE
                                              );

             END IF;
           END IF;
        END LOOP;  

        -- TN-1118: Control de corte por modalidad, en caso de pasar la cantidad en par dinamico, se graba en ge_cta_dif_saldos pero no se procesan
        IF v_corte_activo = 'S' THEN
          SELECT COUNT(*) 
          INTO v_conteo
          FROM IT.GE_CTA_DIF_SALDOS
          WHERE fecha = P_FECHA
          AND cod_modalidad = v_cod_modalidad;

          IF v_conteo > v_corte_max THEN
          
            INSERT INTO IT.GE_DIF_MODALIDAD_CORTE_TMP (FECHA, COD_MODALIDAD, CANTIDAD)
            VALUES (P_FECHA, v_cod_modalidad, v_conteo);
            COMMIT;

            IT.PRG_INS_LOG_PROGRAMAS(
              p_cod_programa => 'PAG_BOL',
              p_det_error    => 'Modalidad ' || v_cod_modalidad || ': supera el maximo permitido ('||v_conteo||'/'||v_corte_max||'). Se excluye del resto del proceso (auditoria, segmentacion, limpieza); las demas modalidades continuan.',
              p_cod_persona  => NULL,
              p_nro_cuenta   => NULL
            );
            
          ELSE
            COMMIT;
          END IF;
        ELSE
        
          COMMIT;
        END IF;

      END LOOP;  

        EXCEPTION
          WHEN OTHERS THEN
           ROLLBACK;
            IT.PRG_INS_LOG_PROGRAMAS (
              p_cod_programa => 'PAG_BOL',
              p_det_error    => 'Error en pr_pro_dif_saldos: ' || SQLERRM,
              p_cod_persona  => NULL,
              p_nro_cuenta   => NULL
            );
           RAISE;

 END pr_pro_dif_saldos;

    /* Descripcion: Procedimiento para el parseo de datos en la tabla ah_auditorias y almacenamiento en ge_cta_dif_auditorias */
    PROCEDURE pr_par_tab_ah_auditoria  (
                                         P_FECHA             DATE,
                                         P_FECHA_ANT         DATE,
                                         P_NRO_CUENTA        VARCHAR2 DEFAULT NULL                                    
                                       ) AS
     V_FECHA_ANTERIOR DATE;

    BEGIN

         EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.ge_cta_dif_auditorias';
         EXECUTE IMMEDIATE 'alter session set NLS_NUMERIC_CHARACTERS = ''.,''';

         V_FECHA_ANTERIOR := p_fecha_ant;

        INSERT INTO it.ge_cta_dif_auditorias (origen,
                                              nro_cuenta,
                                              usuario,
                                              fec_calendario,
                                              fec_sistema,
                                              campo,
                                              val_anterior,
                                              val_actual,
                                              cod_modalidad,
                                              modalidad,
                                              tip_saldo
                                              )
           WITH tab_auditoria AS ( 
                 SELECT A.tabla origen,
                        A.clave,
                        A.usuario,
                        A.fec_calendario,
                        A.fec_sistema,
                        A.detalle,
                        CASE 
                        WHEN REGEXP_LIKE(A.detalle, 'SAL_BLOQUEADO|SAL_BLO_BATCH') THEN 'BLOQUEADO'
                        WHEN REGEXP_LIKE(A.detalle, 'SAL_TOTAL|SAL_TOT_BATCH') THEN 'DISPONIBLE'
                        WHEN REGEXP_LIKE(A.detalle, 'SAL_RETENIDO|SAL_RET_BATCH') THEN 'RETENIDO'
                   ELSE 'DESCONOCIDO' 
                   END AS TIP_SALDO
                   FROM IT.AH_AUDITORIAS A
                  WHERE (A.FEC_CALENDARIO = p_fecha OR A.FEC_CALENDARIO = p_fecha_ant)
                    AND a.detalle LIKE '%SAL_%'
                 ),
                 dif_saldos AS (
                 SELECT CDS.COD_MODALIDAD COD_MODALIDAD, 
                        CDS.MODALIDAD MODALIDAD,             
						CDS.TIP_SALDO,
                        nro_cuenta
                   FROM IT.ge_cta_dif_saldos cds
                  WHERE CDS.FECHA = p_fecha
                    AND CDS.modalidad IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
                    AND CDS.tip_saldo IN ('DISPONIBLE', 'BLOQUEADO', 'RETENIDO')
                 )
            SELECT tau.origen,
                   tau.clave nro_cuenta,
                   tau.usuario,
                   tau.fec_calendario,
                   tau.fec_sistema,
                   COALESCE 
                        (REGEXP_SUBSTR(tau.detalle, '(SAL_TOTAL):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_TOT_BATCH):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_BLOQUEADO):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_BLO_BATCH):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_RETENIDO):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_RET_BATCH):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_EXTRACTO):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_CAPITALIZACION):<i:', 1, 1, NULL, 1)
                         )CAMPO,
                   REPLACE(REGEXP_SUBSTR(tau.detalle, COALESCE (REGEXP_SUBSTR(tau.detalle, '(SAL_TOTAL):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_TOT_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLOQUEADO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLO_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RETENIDO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RET_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_EXTRACTO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_CAPITALIZACION):<i:', 1, 1, NULL, 1)
                                                              )||':<i:([^:]+):f><i:([^:]+):f>', 1, 1, NULL, 1)
                                                              , ',', '') AS VAL_ANT,                  
                   REPLACE(REGEXP_SUBSTR(tau.detalle, COALESCE (REGEXP_SUBSTR(tau.detalle, '(SAL_TOTAL):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_TOT_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLOQUEADO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLO_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RETENIDO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RET_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_EXTRACTO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_CAPITALIZACION):<i:', 1, 1, NULL, 1)
                                                              )||':<i:([^:]+):f><i:([^:]+):f>', 1, 1, NULL, 2)
                                                              , ',', '')AS VAL_ACTUAL,
                   dif.COD_MODALIDAD COD_MODALIDAD, 
                   dif.MODALIDAD MODALIDAD,
                   tau.tip_saldo
            FROM tab_auditoria tau,
                 dif_saldos dif
            WHERE tau.CLAVE = dif.nro_cuenta      
            AND tau.tip_saldo = dif.tip_saldo
            AND tau.CLAVE = NVL(P_NRO_CUENTA, tau.CLAVE)
            AND dif.COD_MODALIDAD NOT IN ( SELECT M.COD_MODALIDAD 
                                           FROM IT.GE_DIF_MODALIDAD_CORTE_TMP M 
                                           WHERE M.FECHA = P_FECHA );
           
    COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
        ROLLBACK;
            IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.PR_PAR_TAB_AUDITORIA',
                                       p_det_error    => to_char (systimestamp) || 'Insertando en ge_cta_dif_auditorias: '||SQLERRM,
                                       p_cod_persona  => NULL,
                                       p_nro_cuenta   => NULL);
        RAISE;

    END pr_par_tab_ah_auditoria;

/* Descripcion: Procedimiento para el parseo de datos en la tabla cc_auditorias y almacenamiento en ge_cta_dif_auditorias */
    PROCEDURE pr_par_tab_cc_auditoria   (
                                         P_FECHA        DATE,
                                         P_FECHA_ANT    DATE,
                                         P_NRO_CUENTA   VARCHAR2 DEFAULT NULL
                                        ) AS
     V_FECHA_ANTERIOR DATE;

    BEGIN
    
         EXECUTE IMMEDIATE 'alter session set NLS_NUMERIC_CHARACTERS = ''.,''';
    
         V_FECHA_ANTERIOR := p_fecha_ant;
    
        INSERT INTO it.ge_cta_dif_auditorias (origen,
                                              nro_cuenta,
                                              usuario,
                                              fec_calendario,
                                              fec_sistema,
                                              campo,
                                              val_anterior,
                                              val_actual,
                                              cod_modalidad,
                                              modalidad,
                                              tip_saldo
                                              )
         WITH tab_auditoria AS ( 
                 SELECT A.tabla origen,
                        A.clave,
                        A.usuario,
                        A.fec_calendario,
                        A.fec_sistema,
                        A.detalle,
                        CASE 
                        WHEN REGEXP_LIKE(A.detalle, 'SAL_BLOQUEADO|SAL_BLO_BATCH') THEN 'BLOQUEADO'
                        WHEN REGEXP_LIKE(A.detalle, 'SAL_TOTAL|SAL_TOT_BATCH') THEN 'DISPONIBLE'
                        WHEN REGEXP_LIKE(A.detalle, 'SAL_RETENIDO|SAL_RET_BATCH') THEN 'RETENIDO'
                   ELSE 'DESCONOCIDO' 
                   END AS TIP_SALDO
                   FROM IT.CC_AUDITORIAS A
                  WHERE (A.FEC_CALENDARIO = p_fecha OR A.FEC_CALENDARIO = p_fecha_ant)
                    AND a.detalle LIKE '%SAL_%'
                 ),
                 dif_saldos AS (
                 SELECT CDS.COD_MODALIDAD COD_MODALIDAD, 
                        CDS.MODALIDAD MODALIDAD,             
						CDS.TIP_SALDO,
                        nro_cuenta
                   FROM IT.ge_cta_dif_saldos cds
                  WHERE CDS.FECHA = p_fecha
                    AND CDS.modalidad = 'CUENTA CORRIENTE'
                    AND CDS.tip_saldo IN ('DISPONIBLE', 'BLOQUEADO','RETENIDO')
                 )
            SELECT tau.origen,
                   tau.clave nro_cuenta,
                   tau.usuario,
                   tau.fec_calendario,
                   tau.fec_sistema,
                   COALESCE 
                        (REGEXP_SUBSTR(tau.detalle, '(SAL_TOTAL):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_TOT_BATCH):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_BLOQUEADO):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_BLO_BATCH):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_RETENIDO):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_RET_BATCH):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_EXTRACTO):<i:', 1, 1, NULL, 1),
                         REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_CAPITALIZACION):<i:', 1, 1, NULL, 1)
                         )CAMPO,
                   REPLACE(REGEXP_SUBSTR(tau.detalle, COALESCE (REGEXP_SUBSTR(tau.detalle, '(SAL_TOTAL):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_TOT_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLOQUEADO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLO_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RETENIDO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RET_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_EXTRACTO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_CAPITALIZACION):<i:', 1, 1, NULL, 1)
                                                              )||':<i:([^:]+):f><i:([^:]+):f>', 1, 1, NULL, 1)
                                                              , ',', '') AS VAL_ANT,                  
                   REPLACE(REGEXP_SUBSTR(tau.detalle, COALESCE (REGEXP_SUBSTR(tau.detalle, '(SAL_TOTAL):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_TOT_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLOQUEADO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_BLO_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RETENIDO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_RET_BATCH):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_EXTRACTO):<i:', 1, 1, NULL, 1),
                                                              REGEXP_SUBSTR(tau.detalle, '(SAL_ULT_CAPITALIZACION):<i:', 1, 1, NULL, 1)
                                                              )||':<i:([^:]+):f><i:([^:]+):f>', 1, 1, NULL, 2)
                                                              , ',', '')AS VAL_ACTUAL,
                   dif.COD_MODALIDAD COD_MODALIDAD, 
                   dif.MODALIDAD MODALIDAD,
                   tau.tip_saldo
            FROM tab_auditoria tau,
                 dif_saldos dif
            WHERE tau.CLAVE = dif.nro_cuenta      
            AND tau.tip_saldo = dif.tip_saldo
            AND tau.CLAVE = NVL(P_NRO_CUENTA, tau.CLAVE)
            AND dif.COD_MODALIDAD NOT IN (SELECT M.COD_MODALIDAD 
                                          FROM IT.GE_DIF_MODALIDAD_CORTE_TMP M 
                                          WHERE M.FECHA = P_FECHA);
           
    COMMIT;
    
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.PR_PAR_TAB_CC_AUDITORIA',
                                       p_det_error    => to_char (systimestamp) || 'Insertando en ge_cta_dif_auditorias: '||SQLERRM,
                                       p_cod_persona  => NULL,
                                       p_nro_cuenta   => NULL);
            RAISE;
    
    END pr_par_tab_cc_auditoria;

/*
     Descripcion:
     Procedimiento que segmenta las diferencias de saldos con los valores posibles:
     'AFECTO SALDO EN LINEA, NO GENERO MOVIMIENTO'
     'GENERO MOVIMIENTOS, NO AFECTO SALDO EN LINEA'
     'AFECTO SALDO BATCH, NO GENERO MOVIMIENTOS'
     'GENERO MOVIMIENTOS, NO AFECTO SALDO BATCH'
*/
    
      PROCEDURE pr_seg_dif_ah_cuentas   (  P_FECHA       DATE,
                                           P_FECHA_ANT   DATE,
                                           P_NRO_CUENTA  VARCHAR2,
                                           P_TIP_SALDO   VARCHAR2
                                        )  AS

    v_saldo_movimientos NUMBER := 0;
    v_saldo_batch       NUMBER := 0;
    v_val_diferencia    NUMBER;
    v_monto_existe      NUMBER;
    v_rowid_list        T_ROWID_TABLE;
    v_mov_rowid         T_ROWID_LIST;
    v_ya_usado          BOOLEAN;
    v_monto_tmp         NUMBER;
    V_monto_dif         NUMBER;
    v_cod_moneda        IT.GE_CTA_DIF_SALDOS.COD_MONEDA%TYPE;
    v_modalidad         IT.GE_CTA_DIF_SALDOS.MODALIDAD%TYPE;
    v_cod_modalidad     IT.GE_CTA_DIF_SALDOS.COD_MODALIDAD%TYPE;
    v_fecha_anterior    DATE;
    v_monto             IT.AH_MOVIMIENTOS_HIS_TMP.MONTO%TYPE;
    v_cod_tra_padre     IT.AH_MOVIMIENTOS_HIS_TMP.COD_TRA_PADRE%TYPE;
    v_fec_insercion     IT.AH_MOVIMIENTOS_HIS_TMP.FEC_INSERCION%TYPE;
    v_monto_batch       IT.GE_CTA_DIF_AUDITORIAS.VAL_ANTERIOR%TYPE;
    v_usuario           IT.GE_CTA_DIF_AUDITORIAS.USUARIO%TYPE;
    v_usu_cierre        VARCHAR2(100);
    v_tipo_transaccion  VARCHAR2(1);
    v_monto_segmentado  NUMBER; 
    v_saldo_compara     NUMBER; 


    FUNCTION fnc_normaliza_signo_dif (
                                        P_NRO_CUENTA IN NUMBER,
                                        P_FECHA      IN DATE,
                                        P_MONTO      IN NUMBER
                                      ) 
                                      RETURN NUMBER IS
    v_saldo_compara  NUMBER;
    v_monto_result   NUMBER := p_monto;

    BEGIN

          BEGIN

          SELECT var_dif_saldo
          INTO   v_saldo_compara
          FROM   it.ge_cta_dif_saldos
          WHERE  nro_cuenta = p_nro_cuenta
          AND    fecha      = p_fecha
          AND    cod_modalidad IN ('31','334')
          AND    modalidad IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
          AND    tip_saldo = p_tip_saldo;

          EXCEPTION
              WHEN NO_DATA_FOUND THEN
              RETURN p_monto; 
          END;


            IF SIGN(v_saldo_compara) != SIGN(p_monto) THEN
                v_monto_result := p_monto * -1;
            END IF;

     RETURN v_monto_result;

    END fnc_normaliza_signo_dif;

  BEGIN


--CASOS SALDO EN LINEA

    v_rowid_list := T_ROWID_TABLE();
    v_usu_cierre := fug_obt_pardinamico('USU_CIERRE_DIF_SALDOS');
    
    BEGIN
          SELECT cod_moneda, modalidad, cod_modalidad
          INTO   v_cod_moneda, v_modalidad, v_cod_modalidad
          FROM   it.ge_cta_dif_saldos
          WHERE  nro_cuenta = p_nro_cuenta
          AND    fecha      = p_fecha
          AND    cod_modalidad IN ('31','334')
          AND    modalidad IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
          AND    tip_saldo = p_tip_saldo;
    
    EXCEPTION 
       WHEN OTHERS THEN
           NULL; 
    END;

    FOR rec_1 IN (
                  SELECT VAL_ANTERIOR, VAL_ACTUAL, USUARIO, FEC_SISTEMA, modalidad, cod_modalidad
                  FROM IT.ge_cta_dif_auditorias
                  WHERE NRO_CUENTA = p_nro_cuenta
                  AND FEC_CALENDARIO = p_fecha
                  AND MODALIDAD IN ('AHORROS A LA VISTA','CAJA DE AHORRO')
                  AND COD_MODALIDAD IN ('31','334')
                  AND TIP_SALDO = p_tip_saldo
                  AND CAMPO IN ('SAL_TOTAL','SAL_BLOQUEADO','SAL_RETENIDO')
                  )
    LOOP
        v_val_diferencia := rec_1.VAL_ACTUAL - rec_1.VAL_ANTERIOR;
        v_mov_rowid := NULL;
        v_ya_usado := FALSE;

        BEGIN
              SELECT H.ROWID BULK COLLECT
              INTO V_MOV_ROWID
              FROM IT.AH_MOVIMIENTOS_HIS_TMP H
              WHERE H.NRO_CUENTA = p_nro_cuenta
              AND H.FECHA = p_fecha
              AND (H.USU_INSERCION = rec_1.USUARIO OR ',' || v_usu_cierre || ',' LIKE '%,' || rec_1.USUARIO || ',%') --fug_obt_pardinamico
              AND TO_CHAR(H.FEC_INSERCION, 'HH24:MI') = TO_CHAR(rec_1.FEC_SISTEMA, 'HH24:MI') -- Solo horas y minutos
              AND EXISTS (
                             SELECT 1
                             FROM IT.AH_MOVIMIENTOS_HIS_TMP H2
                             WHERE H2.NRO_CUENTA = H.NRO_CUENTA
                             AND H2.FECHA = H.FECHA
                             AND H2.USU_INSERCION = H.USU_INSERCION
                             AND H2.FEC_INSERCION = H.FEC_INSERCION
                             AND H2.COD_TRA_PADRE = H.COD_TRA_PADRE
                             GROUP BY H2.USU_INSERCION, H2.FEC_INSERCION, H2.COD_TRA_PADRE
                             HAVING ABS(SUM(H2.MONTO)) = ABS(v_val_diferencia)
                               OR COUNT(*) > 1)
              AND NOT EXISTS (
                               SELECT 1
                               FROM TABLE(v_rowid_list) RID
                               WHERE RID.ROW_ID = H.ROWID
                               );

            IF v_mov_rowid.COUNT = 0 THEN

                   SELECT ROWID BULK COLLECT
                   INTO V_MOV_ROWID
                   FROM IT.AH_MOVIMIENTOS_HIS_TMP H3
                   WHERE H3.NRO_CUENTA = p_nro_cuenta
                   AND H3.FECHA = p_fecha
                   AND ( ',' || v_usu_cierre || ',' LIKE '%,' || H3.USU_MODIFICACION || ',%')
                   AND TO_CHAR(H3.FEC_INSERCION, 'HH24:MI') = TO_CHAR(rec_1.FEC_SISTEMA, 'HH24:MI')
                   AND NOT EXISTS ( SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = H3.ROWID)
                   AND EXISTS (
                                SELECT 1
                                FROM IT.AH_MOVIMIENTOS_HIS_TMP H3_INNER
                                WHERE H3_INNER.NRO_CUENTA = H3.NRO_CUENTA
                                AND H3_INNER.FECHA = H3.FECHA
                                AND (',' || fug_obt_pardinamico('USU_CIERRE_DIF_SALDOS') || ',' LIKE '%,' || H3_INNER.USU_MODIFICACION || ',%') 
                   AND NOT EXISTS (
                                   SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = H3_INNER.ROWID
                                  )
                   GROUP BY H3_INNER.NRO_CUENTA, H3_INNER.FECHA
                   HAVING ABS(SUM(H3_INNER.MONTO)) = ABS(v_val_diferencia)
                   );
            END IF;

            IF v_mov_rowid.COUNT = 0 THEN
                   SELECT ROWID BULK COLLECT
                   INTO V_MOV_ROWID
                   FROM IT.AH_MOVIMIENTOS_HIS_TMP M1
                   WHERE M1.NRO_CUENTA = p_nro_cuenta
                   AND M1.FECHA = p_fecha
                   AND ',' || v_usu_cierre || ',' LIKE '%,' || M1.USU_MODIFICACION || ',%'
                   AND TO_CHAR(M1.FEC_INSERCION, 'HH24:MI') = TO_CHAR(rec_1.FEC_SISTEMA, 'HH24:MI')
                   AND NOT EXISTS (SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = M1.ROWID)
                   AND EXISTS (
                                  SELECT 1
                                  FROM IT.AH_MOVIMIENTOS_HIS_TMP M1_INNER
                                  WHERE M1_INNER.NRO_CUENTA = M1.NRO_CUENTA
                                  AND M1_INNER.FECHA = M1.FECHA
                                  AND ',' || v_usu_cierre || ',' LIKE '%,' || M1_INNER.USU_MODIFICACION || ',%'
                                  AND NOT EXISTS (
                                                   SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = M1_INNER.ROWID
                                                 )
                    GROUP BY M1_INNER.NRO_CUENTA, M1_INNER.FECHA
                    HAVING ABS(MAX(M1_INNER.MONTO) - MIN(M1_INNER.MONTO)) = ABS(v_val_diferencia));

            END IF;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_mov_rowid := NULL;
        END;

        IF v_mov_rowid.COUNT > 0 THEN

            FOR i IN 1 .. v_mov_rowid.COUNT LOOP

                SELECT MONTO, COD_TRA_PADRE, FEC_INSERCION
                INTO V_MONTO, V_COD_TRA_PADRE, V_FEC_INSERCION
                FROM IT.AH_MOVIMIENTOS_HIS_TMP
                WHERE ROWID = v_mov_rowid(i);

                v_rowid_list.EXTEND;
                v_rowid_list(v_rowid_list.LAST).ROW_ID := v_mov_rowid(i);

            END LOOP;

        ELSE

    v_val_diferencia := fnc_normaliza_signo_dif(
                                                p_nro_cuenta,
                                                p_fecha,
                                                v_val_diferencia);


            INSERT INTO IT.GE_CTA_DIF_SEGMENTADAS (
                NRO_CUENTA,
                FECHA,
                FEC_INSERCION,
                USUARIO,
                MONTO,
                SENTIDO,
                TIPO_DIFERENCIA,
                MONEDA,
                SQUAD,
                MODALIDAD,
                COD_MODALIDAD,
                TIP_SALDO
                )

            VALUES (
                p_nro_cuenta,
                p_fecha,
                rec_1.fec_sistema,
                rec_1.USUARIO,
                v_val_diferencia,
                'A',
                'AFECTO SALDO EN LINEA, NO GENERO MOVIMIENTO',
                v_cod_moneda,
                NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = rec_1.USUARIO AND ROWNUM = 1), 'OTRO'),
                rec_1.modalidad,
                rec_1.cod_modalidad,
                p_tip_saldo);

        END IF;
    END LOOP;

  -- CASO 4: Revisión del día anterior
     BEGIN
     V_FECHA_ANTERIOR := p_fecha_ant;

        SELECT NVL(var_dif_saldo, dif_saldo)
        INTO v_monto_dif
        FROM it.ge_cta_dif_saldos
        WHERE fecha = p_fecha
        AND nro_cuenta = p_nro_cuenta
        AND TIP_SALDO = p_tip_saldo
        AND COD_MODALIDAD IN ('31','334')
        AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
        AND ROWNUM = 1;


            SELECT ROWID BULK COLLECT
            INTO v_mov_rowid
            FROM (
                    SELECT A4.*,
                    ROW_NUMBER() OVER (PARTITION BY A4.NRO_CUENTA, ABS(A4.VAL_ACTUAL - A4.VAL_ANTERIOR)
                    ORDER BY A4.FEC_SISTEMA
                                      ) AS RN
                    FROM IT.ge_cta_dif_auditorias A4
                    WHERE A4.NRO_CUENTA = p_nro_cuenta
                    AND A4.FEC_CALENDARIO =v_fecha_anterior
                    AND ABS(A4.VAL_ACTUAL - A4.VAL_ANTERIOR) = ABS(v_monto_dif)
                    AND COD_MODALIDAD IN ('31','334')
                    AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
                    AND TIP_SALDO = p_tip_saldo
                    AND A4.CAMPO IN ('SAL_TOTAL','SAL_BLOQUEADO','SAL_RETENIDO')
                    AND NOT EXISTS (
                                    SELECT 1 FROM TABLE(v_rowid_list) RID
                                    WHERE RID.ROW_ID = A4.ROWID
                                    )
                    ) A
            WHERE A.RN <= CASE 
                            WHEN (SELECT COUNT(*) FROM IT.AH_MOVIMIENTOS_HIS_TMP m WHERE m.nro_cuenta = p_nro_cuenta AND (m.fecha = v_fecha_anterior or m.fecha = p_fecha) AND ABS(m.monto) = ABS(v_monto_dif)) = 0 THEN 1
                            ELSE (SELECT COUNT(*) FROM IT.AH_MOVIMIENTOS_HIS_TMP m WHERE m.nro_cuenta = p_nro_cuenta AND (m.fecha = v_fecha_anterior or m.fecha = p_fecha) AND ABS(m.monto) = ABS(v_monto_dif))
                          END;

    FOR i IN 1 .. v_mov_rowid.COUNT LOOP

                  v_rowid_list.EXTEND;
                  v_rowid_list(v_rowid_list.LAST).ROW_ID := v_mov_rowid(i);

                END LOOP;

    IF v_mov_rowid.COUNT > 0 THEN

       FOR i IN 1 .. v_mov_rowid.COUNT LOOP

                INSERT INTO IT.GE_CTA_DIF_SEGMENTADAS (
                    NRO_CUENTA,
                    FECHA,
                    FEC_INSERCION,
                    USUARIO,
                    MONTO,
                    SENTIDO,
                    TIPO_DIFERENCIA,
                    MONEDA,
                    SQUAD,
                    MODALIDAD,
                    COD_MODALIDAD,
                    TIP_SALDO)

                    SELECT p_nro_cuenta,
                    v_fecha_anterior,
                    A4.FEC_SISTEMA,
                    A4.USUARIO,
                    ABS(A4.VAL_ACTUAL - A4.VAL_ANTERIOR) *
                    CASE 
                        WHEN v_monto_dif < 0 THEN -1
                        ELSE 1
                    END,
                    'A',
                    'AFECTO SALDO EN LINEA, NO GENERO MOVIMIENTO',
                    v_cod_moneda,
                    NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = A4.USUARIO AND ROWNUM = 1), 'OTRO'),
                    v_modalidad,
                    v_cod_modalidad,
                    p_tip_saldo
                     FROM IT.ge_cta_dif_auditorias A4 WHERE A4.ROWID = v_mov_rowid(i);

       END LOOP;
    END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('CASO 4 - No se encontró diferencia para ' || p_nro_cuenta);
        WHEN OTHERS THEN
        ROLLBACK;
            IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.PR_PAR_TAB_CC_AUDITORIA',
                                       p_det_error    => to_char (systimestamp) || 'Insertando en pr_seg_dif_ah_cuentas: '||SQLERRM,
                                       p_cod_persona  => NULL,
                                       p_nro_cuenta   => NULL);
        RAISE;
    
    END;

    V_VAL_DIFERENCIA := 0;

    FOR REC_2 IN (
                    SELECT MONTO,
                           HORA,
                           USU_INSERCION,
                           fec_insercion,
                           fec_modificacion,
                           cod_tra_padre,
                           cod_transaccion
                    FROM IT.AH_MOVIMIENTOS_HIS_TMP
                    WHERE NRO_CUENTA = p_nro_cuenta
                    AND FECHA = p_fecha
                    AND MONTO IS NOT NULL)
    LOOP

           SELECT ROWID BULK COLLECT  --Busco coincidencia exacta
           INTO v_mov_rowid
           FROM it.ge_cta_dif_auditorias AUD
           WHERE AUD.NRO_CUENTA = P_NRO_CUENTA
           AND AUD.FEC_CALENDARIO = P_FECHA
           AND COD_MODALIDAD IN ('31','334')
           AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
           AND TIP_SALDO = p_tip_saldo
           AND CAMPO IN ('SAL_TOTAL','SAL_BLOQUEADO','SAL_RETENIDO')
           AND ABS(AUD.VAL_ACTUAL - AUD.VAL_ANTERIOR) = ABS(rec_2.monto)
           AND NOT EXISTS (SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = aud.ROWID);

                IF v_mov_rowid.COUNT > 0 THEN
                   v_rowid_list.EXTEND;
                   v_rowid_list(v_rowid_list.LAST).ROW_ID := v_mov_rowid(1);
        ELSE

           BEGIN

           SELECT T.TIPO
           INTO V_TIPO_TRANSACCION
           FROM GE_TRANSACCIONES T
           WHERE T.COD_TRANSACCION = rec_2.cod_transaccion
           AND T.COD_MODULO = '3'
           AND T.COD_MODALIDAD IN ('31','334')
           AND ROWNUM = 1;

                    IF V_TIPO_TRANSACCION = 'D' THEN
                       V_MONTO_SEGMENTADO := -ABS(REC_2.MONTO); 

                    ELSIF
                       V_TIPO_TRANSACCION = 'C' THEN
                       V_MONTO_SEGMENTADO := ABS(REC_2.MONTO); 

                    END IF;

           EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     V_MONTO_SEGMENTADO := REC_2.MONTO;
           END;


        v_monto_segmentado := fnc_normaliza_signo_dif(
                                                      p_nro_cuenta,
                                                      p_fecha,
                                                      v_monto_segmentado);

            INSERT INTO it.ge_cta_dif_segmentadas (
                    nro_cuenta,
                    fecha,
                    fec_insercion,
                    usuario,
                    monto,
                    sentido,
                    tipo_diferencia,
                    MONEDA,
                    squad,
                    MODALIDAD,
                    COD_MODALIDAD,
                    TIP_SALDO
                    )
            VALUES (
                    P_NRO_CUENTA,
                    P_FECHA,
                    rec_2.fec_insercion,
                    rec_2.USU_INSERCION,
                    V_MONTO_SEGMENTADO,
                    'A',
                    'GENERO MOVIMIENTOS, NO AFECTO SALDO EN LINEA',
                    v_cod_moneda,
                    NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = REC_2.USU_INSERCION AND ROWNUM = 1),'OTRO'),
                    v_modalidad,
                    v_cod_modalidad,
                    p_tip_saldo);
        END IF;
    END LOOP;

-- CASOS SALDO BATCH

      SELECT NVL(SUM(MONTO), 0)
      INTO V_SALDO_MOVIMIENTOS
      FROM IT.AH_MOVIMIENTOS_HIS_TMP
      WHERE NRO_CUENTA = P_NRO_CUENTA
      AND FECHA = P_FECHA;

      SELECT NVL(SUM(ABS(VAL_ACTUAL - VAL_ANTERIOR)), 0)
      INTO V_SALDO_BATCH
      FROM IT.ge_cta_dif_auditorias
      WHERE NRO_CUENTA   = P_NRO_CUENTA
      AND FEC_CALENDARIO = P_FECHA
      AND COD_MODALIDAD IN ('31','334')
      AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
     AND TIP_SALDO = p_tip_saldo
      AND campo IN ('SAL_TOT_BATCH','SAL_BLO_BATCH','SAL_RET_BATCH');

    IF v_saldo_batch <> v_saldo_movimientos THEN

        FOR rec_batch IN (
                              SELECT val_anterior, val_actual, (VAL_ACTUAL - VAL_ANTERIOR) AS diferencia,
                                     USUARIO, FEC_SISTEMA
                               FROM it.ge_cta_dif_auditorias CDA
                               WHERE CDA.NRO_CUENTA = p_nro_cuenta
                               AND CDA.FEC_CALENDARIO = p_fecha
                               AND CDA.COD_MODALIDAD IN ('31','334')
                               AND CDA.MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
                               AND TIP_SALDO = p_tip_saldo
                               AND CDA.campo IN ('SAL_TOT_BATCH','SAL_BLO_BATCH','SAL_RET_BATCH')
                            )

        LOOP
                v_monto_existe := 0;
                v_val_diferencia := rec_batch.diferencia; 

                SELECT COUNT(*)
                INTO v_monto_existe
                FROM IT.AH_MOVIMIENTOS_HIS_TMP
                WHERE NRO_CUENTA = p_nro_cuenta
                AND FECHA = p_fecha
                AND ABS(MONTO) = ABS (rec_batch.diferencia);


            IF v_monto_existe = 0 THEN

            v_val_diferencia := fnc_normaliza_signo_dif(
                                                        p_nro_cuenta,
                                                        p_fecha,
                                                        v_val_diferencia);

                                   INSERT INTO
                                    IT.GE_CTA_DIF_SEGMENTADAS (
                                    nro_cuenta,
                                    fecha,
                                    fec_insercion,
                                    usuario,
                                    monto,
                                    sentido,
                                    tipo_diferencia,
                                    MONEDA,
                                    squad,
                                    MODALIDAD,
                                    COD_MODALIDAD,
                                    TIP_SALDO
                                    )

                                     VALUES (
                                    p_nro_cuenta,
                                    p_fecha,
                                    rec_batch.fec_sistema,
                                    rec_batch.usuario,
                                    REC_BATCH.DIFERENCIA,
                                    'A',
                                    'AFECTO SALDO BATCH, NO GENERO MOVIMIENTOS',
                                    v_cod_moneda,
                                    NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = rec_batch.USUARIO AND ROWNUM = 1),'OTRO'),
                                    v_modalidad,
                                    v_cod_modalidad,
                                    p_tip_saldo
                                    );

            END IF;
        END LOOP;


      FOR rec_batch_2 IN (
                          SELECT  MONTO,
                                  HORA,
                                  USU_INSERCION,
                                  FEC_INSERCION,
                                  COD_TRANSACCION
                          FROM IT.AH_MOVIMIENTOS_HIS_TMP
                          WHERE NRO_CUENTA = p_nro_cuenta
                          AND FECHA = p_fecha
                          AND MONTO IS NOT NULL
                          )

      LOOP
      v_mov_rowid      := NULL;
      v_ya_usado       := FALSE;
      v_monto_tmp := rec_batch_2.MONTO;

        BEGIN
          SELECT AUD.ROWID
          BULK COLLECT
          INTO V_MOV_ROWID
          FROM IT.ge_cta_dif_auditorias AUD
          WHERE AUD.NRO_CUENTA = P_NRO_CUENTA
          AND aud.FEC_CALENDARIO = p_fecha
          AND AUD.COD_MODALIDAD IN ('31','334')
          AND AUD.MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
          AND AUD.TIP_SALDO = p_tip_saldo
          AND CAMPO IN ('SAL_TOT_BATCH','SAL_BLO_BATCH','SAL_RET_BATCH')
          AND ABS(AUD.VAL_ACTUAL - AUD.VAL_ANTERIOR) = abs( v_monto_tmp)
          AND (
                 AUD.USUARIO = rec_batch_2.USU_INSERCION
                OR ',' || v_usu_cierre || ',' LIKE '%,' || AUD.USUARIO || ',%'
                       OR EXISTS (
                                  SELECT 1
                                  FROM (
                                        SELECT USU_INSERCION
                                        FROM (
                                                SELECT monto,
                                                usu_insercion,
                                                cod_transaccion,
                                                fec_valor
                                                FROM IT.AH_MOVIMIENTOS_HIS_TMP mov
                                                WHERE nro_cuenta = p_nro_cuenta
                                                AND fecha = p_fecha
                                             )
                                        GROUP BY cod_transaccion, fec_valor, USU_INSERCION ) DIFERENCIA
                                         WHERE (DIFERENCIA.USU_INSERCION = rec_batch_2.usu_insercion
                                         OR ',' || v_usu_cierre || ',' LIKE '%,' || DIFERENCIA.USU_INSERCION || ',%')
                                                                        )
                                                    )
                                        AND NOT EXISTS (
                                          SELECT 1 FROM TABLE(V_ROWID_LIST) RID
                                          WHERE RID.ROW_ID = AUD.ROWID
                                                                        );

        EXCEPTION
         WHEN NO_DATA_FOUND THEN
              V_MOV_ROWID := NULL;
        END;

     IF V_MOV_ROWID IS NOT NULL AND V_MOV_ROWID.COUNT > 0 THEN
          -- Si encontró una fila, agrego el ROWID a la lista y pongo bandera TRUE
          FOR i IN 1 .. V_MOV_ROWID.COUNT LOOP
             SELECT (VAL_ACTUAL - VAL_ANTERIOR) AS MONTO, USUARIO
             INTO V_MONTO_BATCH, V_USUARIO
             FROM IT.ge_cta_dif_auditorias
             WHERE ROWID = V_MOV_ROWID(1)
             AND COD_MODALIDAD IN ('31','334')
             AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
             AND TIP_SALDO = p_tip_saldo;

            V_ROWID_LIST.EXTEND;
            V_ROWID_LIST(V_ROWID_LIST.LAST).ROW_ID := V_MOV_ROWID(1);

          END LOOP;

          ELSE
                BEGIN
                SELECT T.TIPO
                INTO V_TIPO_TRANSACCION
                FROM GE_TRANSACCIONES T
                WHERE T.COD_TRANSACCION = rec_batch_2.cod_transaccion
                AND T.COD_MODULO = '3'
                AND T.COD_MODALIDAD IN ('31','334')
                AND ROWNUM = 1;

                  IF V_TIPO_TRANSACCION = 'D' THEN 
                     V_MONTO_SEGMENTADO := -ABS(REC_BATCH_2.MONTO);
                  ELSIF
                     V_TIPO_TRANSACCION = 'C' THEN
                     V_MONTO_SEGMENTADO := ABS(REC_BATCH_2.MONTO);
                  END IF;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
               V_MONTO_SEGMENTADO := REC_BATCH_2.MONTO;
        END;

         v_monto_segmentado := fnc_normaliza_signo_dif(p_nro_cuenta,
                                                       p_fecha,
                                                       v_monto_segmentado);


                INSERT INTO
                IT.GE_CTA_DIF_SEGMENTADAS (NRO_CUENTA,
                                           FECHA,
                                           FEC_INSERCION,
                                           USUARIO,
                                           MONTO,
                                           SENTIDO,
                                           TIPO_DIFERENCIA,
                                           MONEDA,
                                           SQUAD,
                                           MODALIDAD,
                                           COD_MODALIDAD,
                                           TIP_SALDO
                                           )                      

                                          VALUES(
                                          P_NRO_CUENTA,
                                          P_FECHA,
                                          REC_BATCH_2.FEC_INSERCION,
                                          REC_BATCH_2.USU_INSERCION,
                                          V_MONTO_SEGMENTADO,
                                          'A',
                                          'GENERO MOVIMIENTOS, NO AFECTO SALDO BATCH',
                                          v_cod_moneda,
                                          NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = REC_BATCH_2.USU_INSERCION AND ROWNUM = 1), 'OTRO'),
                                          v_modalidad,
                                          v_cod_modalidad,
                                          p_tip_saldo
                                          );

            END IF;
      END LOOP;
   END IF;

    EXCEPTION
        WHEN OTHERS THEN
             IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.SEG_DIF_CUENTAS',
                                       p_det_error    => to_char (systimestamp) || 'Segmentacion : '||SQLERRM,
                                       p_cod_persona  => NULL,
                                       p_nro_cuenta   => NULL);
             RAISE;
    END pr_seg_dif_ah_cuentas;

    PROCEDURE pr_seg_dif_cc_cuentas   (  P_FECHA          DATE,
                                         P_FECHA_ANT      DATE,
                                         P_NRO_CUENTA  VARCHAR2,
                                         P_TIP_SALDO   VARCHAR2 
                                      )  AS

    v_saldo_movimientos NUMBER := 0;
    v_saldo_batch       NUMBER := 0;
    v_val_diferencia    NUMBER;
    v_monto_existe      NUMBER;
    v_rowid_list        T_ROWID_TABLE;
    v_mov_rowid         T_ROWID_LIST;
    v_ya_usado          BOOLEAN;
    v_monto_tmp         NUMBER;
    V_monto_dif         NUMBER;
    v_cod_moneda        IT.GE_CTA_DIF_SALDOS.COD_MONEDA%TYPE;
    v_modalidad         IT.GE_CTA_DIF_SALDOS.MODALIDAD%TYPE;
    v_cod_modalidad     IT.GE_CTA_DIF_SALDOS.COD_MODALIDAD%TYPE;
    v_fecha_anterior    DATE;
    v_monto             IT.CC_MOVIMIENTOS_HIS_TMP.MONTO%TYPE;
    v_cod_tra_padre     IT.CC_MOVIMIENTOS_HIS_TMP.COD_TRA_PADRE%TYPE;
    v_fec_insercion     IT.CC_MOVIMIENTOS_HIS_TMP.FEC_INSERCION%TYPE;
    v_monto_batch       IT.GE_CTA_DIF_AUDITORIAS.VAL_ANTERIOR%TYPE;
    v_usuario           IT.GE_CTA_DIF_AUDITORIAS.USUARIO%TYPE;
    v_usu_cierre        VARCHAR2(100);
    v_tipo_transaccion  VARCHAR2(1);
    v_monto_segmentado  NUMBER; 
    v_saldo_compara     NUMBER; 
    
    FUNCTION fnc_normaliza_signo_dif (
                                        p_nro_cuenta IN NUMBER,
										p_tip_saldo  IN VARCHAR2,
                                        p_fecha      IN DATE,
                                        p_monto      IN NUMBER
                                     ) 
                                      RETURN NUMBER IS
    v_saldo_compara  NUMBER;
    v_monto_result   NUMBER := p_monto;
        
    BEGIN

          BEGIN
        
          SELECT var_dif_saldo
          INTO   v_saldo_compara
          FROM   it.ge_cta_dif_saldos
          WHERE  nro_cuenta = p_nro_cuenta
          AND    fecha      = p_fecha
          AND    cod_modalidad = '41'
          AND    modalidad = 'CUENTA CORRIENTE'
          AND    tip_saldo  = p_tip_saldo;
    
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
              RETURN p_monto; 
          END;
    

            IF SIGN(v_saldo_compara) != SIGN(p_monto) THEN
                v_monto_result := p_monto * -1;
            END IF;
    
     RETURN v_monto_result;
    
    END fnc_normaliza_signo_dif;
    
  BEGIN

--CASOS SALDO EN LINEA

    v_rowid_list := T_ROWID_TABLE();
    v_usu_cierre := fug_obt_pardinamico('USU_CIERRE_DIF_SALDOS');
    
        
    BEGIN
          SELECT cod_moneda, modalidad, cod_modalidad
          INTO   v_cod_moneda, v_modalidad, v_cod_modalidad
          FROM   it.ge_cta_dif_saldos
          WHERE  nro_cuenta = p_nro_cuenta
          AND    fecha      = p_fecha
          AND    cod_modalidad IN ('41')
          AND    modalidad IN ('CUENTA CORRIENTE')
          AND    tip_saldo = p_tip_saldo;
    
    EXCEPTION 
       WHEN OTHERS THEN
           NULL; 
    END;

    FOR rec_1 IN (
                  SELECT VAL_ANTERIOR, VAL_ACTUAL, USUARIO, FEC_SISTEMA
                  FROM IT.GE_CTA_DIF_AUDITORIAS
                  WHERE NRO_CUENTA = p_nro_cuenta
                  AND FEC_CALENDARIO = p_fecha
                  AND modalidad = 'CUENTA CORRIENTE'
                  AND cod_modalidad = '41'
                  AND TIP_SALDO = p_tip_saldo
                  AND CAMPO IN ('SAL_TOTAL', 'SAL_BLOQUEADO', 'SAL_RETENIDO'))
    LOOP
        v_val_diferencia := rec_1.VAL_ACTUAL - rec_1.VAL_ANTERIOR;
        v_mov_rowid := NULL;
        v_ya_usado := FALSE;

        BEGIN
              SELECT H.ROWID BULK COLLECT
              INTO V_MOV_ROWID
              FROM IT.CC_MOVIMIENTOS_HIS_TMP H
              WHERE H.NRO_CUENTA = p_nro_cuenta
              AND H.FECHA = p_fecha
              AND (H.USU_INSERCION = rec_1.USUARIO OR ',' || v_usu_cierre || ',' LIKE '%,' || rec_1.USUARIO || ',%') --fug_obt_pardinamico
              AND TO_CHAR(H.FEC_INSERCION, 'HH24:MI') = TO_CHAR(rec_1.FEC_SISTEMA, 'HH24:MI') -- Solo horas y minutos
              AND EXISTS (
                             SELECT 1
                             FROM IT.CC_MOVIMIENTOS_HIS_TMP H2
                             WHERE H2.NRO_CUENTA = H.NRO_CUENTA
                             AND H2.FECHA = H.FECHA
                             AND H2.USU_INSERCION = H.USU_INSERCION
                             AND H2.FEC_INSERCION = H.FEC_INSERCION
                             AND H2.COD_TRA_PADRE = H.COD_TRA_PADRE
                             GROUP BY H2.USU_INSERCION, H2.FEC_INSERCION, H2.COD_TRA_PADRE
                             HAVING ABS(SUM(H2.MONTO)) = ABS(v_val_diferencia)
                               OR COUNT(*) > 1)
              AND NOT EXISTS (
                               SELECT 1
                               FROM TABLE(v_rowid_list) RID
                               WHERE RID.ROW_ID = H.ROWID
                               );

            IF v_mov_rowid.COUNT = 0 THEN

                   SELECT ROWID BULK COLLECT
                   INTO V_MOV_ROWID
                   FROM IT.CC_MOVIMIENTOS_HIS_TMP H3
                   WHERE H3.NRO_CUENTA = p_nro_cuenta
                   AND H3.FECHA = p_fecha
                   AND ( ',' || v_usu_cierre || ',' LIKE '%,' || H3.USU_MODIFICACION || ',%')
                   AND TO_CHAR(H3.FEC_INSERCION, 'HH24:MI') = TO_CHAR(rec_1.FEC_SISTEMA, 'HH24:MI')
                   AND NOT EXISTS ( SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = H3.ROWID)
                   AND EXISTS (
                                SELECT 1
                                FROM IT.CC_MOVIMIENTOS_HIS_TMP H3_INNER
                                WHERE H3_INNER.NRO_CUENTA = H3.NRO_CUENTA
                                AND H3_INNER.FECHA = H3.FECHA
                                AND (',' || fug_obt_pardinamico('USU_CIERRE_DIF_SALDOS') || ',' LIKE '%,' || H3_INNER.USU_MODIFICACION || ',%') 
                   AND NOT EXISTS (
                                   SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = H3_INNER.ROWID
                                  )
                   GROUP BY H3_INNER.NRO_CUENTA, H3_INNER.FECHA
                   HAVING ABS(SUM(H3_INNER.MONTO)) = ABS(v_val_diferencia)
                   );
            END IF;

            IF v_mov_rowid.COUNT = 0 THEN
                   SELECT ROWID BULK COLLECT
                   INTO V_MOV_ROWID
                   FROM IT.CC_MOVIMIENTOS_HIS_TMP M1
                   WHERE M1.NRO_CUENTA = p_nro_cuenta
                   AND M1.FECHA = p_fecha
                   AND ',' || v_usu_cierre || ',' LIKE '%,' || M1.USU_MODIFICACION || ',%'
                   AND TO_CHAR(M1.FEC_INSERCION, 'HH24:MI') = TO_CHAR(rec_1.FEC_SISTEMA, 'HH24:MI')
                   AND NOT EXISTS (SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = M1.ROWID)
                   AND EXISTS (
                                  SELECT 1
                                  FROM IT.CC_MOVIMIENTOS_HIS_TMP M1_INNER
                                  WHERE M1_INNER.NRO_CUENTA = M1.NRO_CUENTA
                                  AND M1_INNER.FECHA = M1.FECHA
                                  AND ',' || v_usu_cierre || ',' LIKE '%,' || M1_INNER.USU_MODIFICACION || ',%'
                                  AND NOT EXISTS (
                                                   SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = M1_INNER.ROWID
                                                  )
                    GROUP BY M1_INNER.NRO_CUENTA, M1_INNER.FECHA
                    HAVING ABS(MAX(M1_INNER.MONTO) - MIN(M1_INNER.MONTO)) = ABS(v_val_diferencia));

            END IF;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_mov_rowid := NULL;
        END;

        IF v_mov_rowid.COUNT > 0 THEN

            FOR i IN 1 .. v_mov_rowid.COUNT LOOP

                SELECT MONTO, COD_TRA_PADRE, FEC_INSERCION
                INTO V_MONTO, V_COD_TRA_PADRE, V_FEC_INSERCION
                FROM IT.CC_MOVIMIENTOS_HIS_TMP
                WHERE ROWID = v_mov_rowid(i);

                v_rowid_list.EXTEND;
                v_rowid_list(v_rowid_list.LAST).ROW_ID := v_mov_rowid(i);

            END LOOP;

        ELSE
        
    v_val_diferencia := fnc_normaliza_signo_dif(
                                                p_nro_cuenta,
												p_tip_saldo,
                                                p_fecha,
                                                v_val_diferencia
												);
        
        
            INSERT INTO IT.GE_CTA_DIF_SEGMENTADAS (
                NRO_CUENTA,
                FECHA,
                FEC_INSERCION,
                USUARIO,
                MONTO,
                SENTIDO,
                TIPO_DIFERENCIA,
                MONEDA,
                SQUAD,
                MODALIDAD,
                COD_MODALIDAD,
                TIP_SALDO
                )

            VALUES (
                p_nro_cuenta,
                p_fecha,
                rec_1.fec_sistema,
                rec_1.USUARIO,
                v_val_diferencia,
                'A',
                'AFECTO SALDO EN LINEA, NO GENERO MOVIMIENTO',
                v_cod_moneda,
                NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = rec_1.USUARIO AND ROWNUM = 1), 'OTRO'),
                v_modalidad,
                v_cod_modalidad,
                p_tip_saldo
                );
        END IF;
    END LOOP;

    -- CASO 4: Revisión del día anterior
      BEGIN
      V_FECHA_ANTERIOR := p_fecha_ant;

        SELECT NVL(var_dif_saldo, dif_saldo)
        INTO v_monto_dif
        FROM it.ge_cta_dif_saldos
        WHERE fecha = p_fecha
        AND nro_cuenta = p_nro_cuenta
        AND TIP_SALDO = p_tip_saldo
        AND cod_modalidad = '41'
        AND modalidad = 'CUENTA CORRIENTE'
        AND ROWNUM = 1;


            SELECT ROWID BULK COLLECT
            INTO v_mov_rowid
            FROM (
                    SELECT A4.*,
                    ROW_NUMBER() OVER (PARTITION BY A4.NRO_CUENTA, ABS(A4.VAL_ACTUAL - A4.VAL_ANTERIOR)
                    ORDER BY A4.FEC_SISTEMA
                                      ) AS RN
                    FROM IT.ge_cta_dif_auditorias A4
                    WHERE A4.NRO_CUENTA = p_nro_cuenta
                    AND A4.FEC_CALENDARIO =v_fecha_anterior
                    AND ABS(A4.VAL_ACTUAL - A4.VAL_ANTERIOR) = ABS(v_monto_dif)
                    AND cod_modalidad = '41'
                    AND modalidad = 'CUENTA CORRIENTE'
                    AND TIP_SALDO = p_tip_saldo
                    AND A4.CAMPO IN ('SAL_TOTAL', 'SAL_BLOQUEADO', 'SAL_RETENIDO') 
                    AND NOT EXISTS (
                                    SELECT 1 FROM TABLE(v_rowid_list) RID
                                    WHERE RID.ROW_ID = A4.ROWID
                                    )
                    ) A
            WHERE A.RN <= (
                           SELECT COUNT(*)
                           FROM IT.CC_MOVIMIENTOS_HIS_TMP m
                           WHERE m.nro_cuenta = p_nro_cuenta
                           AND m.fecha = v_fecha_anterior or m.fecha = p_fecha
                           AND ABS(m.monto) = ABS(v_monto_dif)
                           );

    FOR i IN 1 .. v_mov_rowid.COUNT LOOP

                  v_rowid_list.EXTEND;
                  v_rowid_list(v_rowid_list.LAST).ROW_ID := v_mov_rowid(i);

                END LOOP;

    IF v_mov_rowid.COUNT > 0 THEN

       FOR i IN 1 .. v_mov_rowid.COUNT LOOP

                INSERT INTO IT.GE_CTA_DIF_SEGMENTADAS (
                    NRO_CUENTA,
                    FECHA,
                    FEC_INSERCION,
                    USUARIO,
                    MONTO,
                    SENTIDO,
                    TIPO_DIFERENCIA,
                    MONEDA,
                    SQUAD,
                    MODALIDAD,
                    COD_MODALIDAD,
                    TIP_SALDO)

                    SELECT p_nro_cuenta,
                    v_fecha_anterior,
                    A4.FEC_SISTEMA,
                    A4.USUARIO,
                    ABS(A4.VAL_ACTUAL - A4.VAL_ANTERIOR) *
                    CASE 
                        WHEN v_monto_dif < 0 THEN -1
                        ELSE 1
                    END,
                    'A',
                    'AFECTO SALDO EN LINEA, NO GENERO MOVIMIENTO',
                     v_cod_moneda,
                    NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = A4.USUARIO AND ROWNUM = 1), 'OTRO'),
                    v_modalidad,
                    v_cod_modalidad,
                    p_tip_saldo
                     FROM IT.GE_CTA_DIF_AUDITORIAS A4 WHERE A4.ROWID = v_mov_rowid(i);

       END LOOP;
    END IF;

   EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('CASO 4 - No se encontró diferencia para ' || p_nro_cuenta);
        WHEN OTHERS THEN
        ROLLBACK;
            IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.pr_seg_dif_cc_cuentas',
                                       p_det_error    => to_char (systimestamp) || 'Insertando en pr_seg_dif_cc_cuentas: '||SQLERRM,
                                       p_cod_persona  => NULL,
                                       p_nro_cuenta   => NULL);
        RAISE;
    END;

    V_VAL_DIFERENCIA := 0;

    FOR REC_2 IN (
                    SELECT MONTO,
                           HORA,
                           USU_INSERCION,
                           fec_insercion,
                           fec_modificacion,
                           cod_tra_padre,
                           cod_transaccion
                    FROM IT.CC_MOVIMIENTOS_HIS_TMP
                    WHERE NRO_CUENTA = p_nro_cuenta
                    AND FECHA = p_fecha
                    AND MONTO IS NOT NULL)
    LOOP

           SELECT ROWID BULK COLLECT  --Busco coincidencia exacta
           INTO v_mov_rowid
           FROM it.ge_cta_dif_auditorias AUD
           WHERE AUD.NRO_CUENTA = P_NRO_CUENTA
           AND AUD.FEC_CALENDARIO = P_FECHA
           AND cod_modalidad = '41'
           AND modalidad = 'CUENTA CORRIENTE'
           AND TIP_SALDO = p_tip_saldo
           AND CAMPO IN ('SAL_TOTAL', 'SAL_BLOQUEADO', 'SAL_RETENIDO')
           AND ABS(AUD.VAL_ACTUAL - AUD.VAL_ANTERIOR) = ABS(rec_2.monto)
           AND NOT EXISTS (SELECT 1 FROM TABLE(v_rowid_list) RID WHERE RID.ROW_ID = aud.ROWID);

                IF v_mov_rowid.COUNT > 0 THEN
                   v_rowid_list.EXTEND;
                   v_rowid_list(v_rowid_list.LAST).ROW_ID := v_mov_rowid(1);
        ELSE

           BEGIN
           
           SELECT T.TIPO
           INTO V_TIPO_TRANSACCION
           FROM GE_TRANSACCIONES T
           WHERE T.COD_TRANSACCION = rec_2.cod_transaccion
           AND T.COD_MODULO = '4'
           AND T.cod_modalidad = '41'
           AND ROWNUM = 1;

                    IF V_TIPO_TRANSACCION = 'D' THEN
                       V_MONTO_SEGMENTADO := -ABS(REC_2.MONTO); 
                        
                    ELSIF
                       V_TIPO_TRANSACCION = 'C' THEN
                       V_MONTO_SEGMENTADO := ABS(REC_2.MONTO); 
                        
                    END IF;

           EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     V_MONTO_SEGMENTADO := REC_2.MONTO;
           END;


        v_monto_segmentado := fnc_normaliza_signo_dif(
                                                      p_nro_cuenta,
                                                      p_tip_saldo,
													  p_fecha,
                                                      v_monto_segmentado);

            INSERT INTO it.ge_cta_dif_segmentadas (
                    nro_cuenta,
                    fecha,
                    fec_insercion,
                    usuario,
                    monto,
                    sentido,
                    tipo_diferencia,
                    MONEDA,
                    squad,
                    MODALIDAD,
                    COD_MODALIDAD,
                    TIP_SALDO
                    )
            VALUES (
                    P_NRO_CUENTA,
                    P_FECHA,
                    rec_2.fec_insercion,
                    rec_2.USU_INSERCION,
                    V_MONTO_SEGMENTADO,
                    'A',
                    'GENERO MOVIMIENTOS, NO AFECTO SALDO EN LINEA',
                    v_cod_moneda,
                    NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = REC_2.USU_INSERCION AND ROWNUM = 1),'OTRO'),
                    v_modalidad,
                    v_cod_modalidad,
                    p_tip_saldo
                    );
        END IF;
    END LOOP;

-- CASOS SALDO BATCH

      SELECT NVL(SUM(MONTO), 0)
      INTO V_SALDO_MOVIMIENTOS
      FROM IT.CC_MOVIMIENTOS_HIS_TMP
      WHERE NRO_CUENTA = P_NRO_CUENTA
      AND FECHA = P_FECHA;

      SELECT NVL(SUM(ABS(VAL_ACTUAL - VAL_ANTERIOR)), 0)
      INTO V_SALDO_BATCH
      FROM IT.GE_CTA_DIF_AUDITORIAS
      WHERE NRO_CUENTA   = P_NRO_CUENTA
	  AND TIP_SALDO = P_TIP_SALDO
      AND FEC_CALENDARIO = P_FECHA
      AND cod_modalidad = '41'
      AND modalidad = 'CUENTA CORRIENTE'
      AND campo IN ('SAL_TOT_BATCH', 'SAL_BLO_BATCH', 'SAL_RET_BATCH');

    IF v_saldo_batch <> v_saldo_movimientos THEN

        FOR rec_batch IN (
                              SELECT val_anterior, val_actual, (VAL_ACTUAL - VAL_ANTERIOR) AS diferencia,
                                     USUARIO, FEC_SISTEMA
                               FROM it.ge_cta_dif_auditorias CDA
                               WHERE CDA.NRO_CUENTA = p_nro_cuenta
							   AND CDA.TIP_SALDO = p_tip_saldo
                               AND CDA.FEC_CALENDARIO = p_fecha
                               AND CDA.cod_modalidad = '41'
                               AND CDA.modalidad = 'CUENTA CORRIENTE'
                              AND CDA.campo IN ('SAL_TOT_BATCH', 'SAL_BLO_BATCH', 'SAL_RET_BATCH')
                              )-- CAMBIO ACÁ

        LOOP
                v_monto_existe := 0;
                v_val_diferencia := rec_batch.diferencia; 

                SELECT COUNT(*)
                INTO v_monto_existe
                FROM IT.CC_MOVIMIENTOS_HIS_TMP
                WHERE NRO_CUENTA = p_nro_cuenta
                AND FECHA = p_fecha
                AND ABS(MONTO) = ABS (rec_batch.diferencia);


            IF v_monto_existe = 0 THEN
            
            v_val_diferencia := fnc_normaliza_signo_dif(
                                                        p_nro_cuenta,
														p_tip_saldo,
                                                        p_fecha,
                                                        v_val_diferencia);

                                   INSERT INTO
                                    it.ge_cta_dif_segmentadas (
                                    nro_cuenta,
                                    fecha,
                                    fec_insercion,
                                    usuario,
                                    monto,
                                    sentido,
                                    tipo_diferencia,
                                    MONEDA,
                                    squad,
                                    MODALIDAD,
                                    COD_MODALIDAD,
                                    TIP_SALDO
                                    )

                                    VALUES (
                                    p_nro_cuenta,
                                    p_fecha,
                                    rec_batch.fec_sistema,
                                    rec_batch.usuario,
                                    REC_BATCH.DIFERENCIA,
                                    'A',
                                    'AFECTO SALDO BATCH, NO GENERO MOVIMIENTOS',
                                    v_cod_moneda,
                                    NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = rec_batch.USUARIO AND ROWNUM = 1),'OTRO'),
                                    v_modalidad,
                                    v_cod_modalidad,
                                    p_tip_saldo
                                    );

            END IF;
        END LOOP;


      FOR rec_batch_2 IN (
                          SELECT  MONTO,
                                  HORA,
                                  USU_INSERCION,
                                  FEC_INSERCION,
                                  COD_TRANSACCION
                          FROM IT.CC_MOVIMIENTOS_HIS_TMP
                          WHERE NRO_CUENTA = p_nro_cuenta
                          AND FECHA = p_fecha
                          AND MONTO IS NOT NULL
                          )

      LOOP
      v_mov_rowid      := NULL;
      v_ya_usado       := FALSE;
      v_monto_tmp := rec_batch_2.MONTO;

        BEGIN
          SELECT AUD.ROWID
          BULK COLLECT
          INTO V_MOV_ROWID
          FROM IT.GE_CTA_DIF_AUDITORIAS AUD
          WHERE AUD.NRO_CUENTA = P_NRO_CUENTA
          AND aud.FEC_CALENDARIO = p_fecha
          AND AUD.cod_modalidad = '41'
          AND AUD.modalidad = 'CUENTA CORRIENTE'
          AND AUD.TIP_SALDO = P_TIP_SALDO
          AND CAMPO IN ('SAL_TOT_BATCH', 'SAL_BLO_BATCH', 'SAL_RET_BATCH') 
          AND ABS(AUD.VAL_ACTUAL - AUD.VAL_ANTERIOR) =abs( v_monto_tmp)
          AND (
                 AUD.USUARIO = rec_batch_2.USU_INSERCION
                OR ',' || v_usu_cierre || ',' LIKE '%,' || AUD.USUARIO || ',%'
                       OR EXISTS (
                                  SELECT 1
                                  FROM (
                                        SELECT USU_INSERCION
                                        FROM (
                                                SELECT monto,
                                                usu_insercion,
                                                cod_transaccion,
                                                fec_valor
                                                FROM IT.CC_MOVIMIENTOS_HIS_TMP mov
                                                WHERE nro_cuenta = p_nro_cuenta
                                                AND fecha = p_fecha
                                             )
                                        GROUP BY cod_transaccion, fec_valor, USU_INSERCION ) DIFERENCIA
                                         WHERE (DIFERENCIA.USU_INSERCION = rec_batch_2.usu_insercion
                                         OR ',' || v_usu_cierre || ',' LIKE '%,' || DIFERENCIA.USU_INSERCION || ',%')
                                                        )
                                                    )
                                        AND NOT EXISTS (
                                          SELECT 1 FROM TABLE(V_ROWID_LIST) RID
                                          WHERE RID.ROW_ID = AUD.ROWID
                                                        );
    
        EXCEPTION
         WHEN NO_DATA_FOUND THEN
              V_MOV_ROWID := NULL;
        END;
        
     IF V_MOV_ROWID IS NOT NULL AND V_MOV_ROWID.COUNT > 0 THEN
          -- Si encontró una fila, agrego el ROWID a la lista y pongo bandera TRUE
          FOR i IN 1 .. V_MOV_ROWID.COUNT LOOP
             SELECT (VAL_ACTUAL - VAL_ANTERIOR) AS MONTO, USUARIO
             INTO V_MONTO_BATCH, V_USUARIO
             FROM IT.GE_CTA_DIF_AUDITORIAS
             WHERE ROWID = V_MOV_ROWID(1)
             AND cod_modalidad = '41'
             AND modalidad = 'CUENTA CORRIENTE'
             AND TIP_SALDO = P_TIP_SALDO;
    
            V_ROWID_LIST.EXTEND;
            V_ROWID_LIST(V_ROWID_LIST.LAST).ROW_ID := V_MOV_ROWID(1);
    
          END LOOP;
    
          ELSE
                BEGIN
                SELECT T.TIPO
                INTO V_TIPO_TRANSACCION
                FROM GE_TRANSACCIONES T
                WHERE T.COD_TRANSACCION = rec_batch_2.cod_transaccion
                AND T.COD_MODULO = '4'
                AND T.cod_modalidad = '41'
                AND ROWNUM = 1;
    
                  IF V_TIPO_TRANSACCION = 'D' THEN 
                     V_MONTO_SEGMENTADO := -ABS(REC_BATCH_2.MONTO);
                  ELSIF
                     V_TIPO_TRANSACCION = 'C' THEN
                     V_MONTO_SEGMENTADO := ABS(REC_BATCH_2.MONTO);
                  END IF;
          
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
               V_MONTO_SEGMENTADO := REC_BATCH_2.MONTO;
        END;
    
         v_monto_segmentado := fnc_normaliza_signo_dif(p_nro_cuenta,
		                                               p_tip_saldo,
                                                       p_fecha,
                                                       v_monto_segmentado);
        
        
    
                INSERT INTO
                IT.GE_CTA_DIF_SEGMENTADAS (NRO_CUENTA,
                                           FECHA,
                                           FEC_INSERCION,
                                           USUARIO,
                                           MONTO,
                                           SENTIDO,
                                           TIPO_DIFERENCIA,
                                           MONEDA,
                                           SQUAD,
                                           MODALIDAD,
                                           COD_MODALIDAD,
                                           TIP_SALDO
                                           )                      
    
                                          VALUES(
                                          P_NRO_CUENTA,
                                          P_FECHA,
                                          REC_BATCH_2.FEC_INSERCION,
                                          REC_BATCH_2.USU_INSERCION,
                                          V_MONTO_SEGMENTADO,
                                          'A',
                                          'GENERO MOVIMIENTOS, NO AFECTO SALDO BATCH',
                                          v_cod_moneda,
                                         NVL((SELECT SQUAD FROM IT.GE_DIF_SQUADS WHERE USUARIO = REC_BATCH_2.USU_INSERCION AND ROWNUM = 1), 'OTRO'),
                                         v_modalidad,
                                         v_cod_modalidad,
                                         p_tip_saldo
                                         );
   
            END IF;
      END LOOP;
   END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
             IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.SEG_DIF_CUENTAS',
                                       p_det_error    => to_char (systimestamp) || 'Segmentacion Cuentas Corrientes: '||SQLERRM,
                                       p_cod_persona  => NULL,
                                       p_nro_cuenta   => NULL);
            RAISE;
    END pr_seg_dif_cc_cuentas;
   
  /*Proceso que busca la  segmentacion de cuentas*/ 
   PROCEDURE pr_bus_segmentacion (p_fecha DATE,
                                  p_fecha_ant DATE) IS
   
      CURSOR c_cta_dif_ah_saldos IS
      SELECT nro_cuenta, tip_saldo
        FROM it.ge_cta_dif_saldos
       WHERE fecha = p_fecha
         AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA')
         AND tip_saldo IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
          AND cod_modalidad NOT IN (
                                    SELECT COD_MODALIDAD 
                                    FROM IT.GE_DIF_MODALIDAD_CORTE_TMP 
                                    WHERE FECHA = p_fecha
                                   );
               
      CURSOR c_cta_dif_cc_saldos IS
      SELECT nro_cuenta,tip_saldo
        FROM it.ge_cta_dif_saldos
       WHERE fecha = p_fecha
         AND MODALIDAD = 'CUENTA CORRIENTE'
         AND tip_saldo IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
          AND cod_modalidad NOT IN (
                                    SELECT COD_MODALIDAD 
                                    FROM IT.GE_DIF_MODALIDAD_CORTE_TMP 
                                    WHERE FECHA = p_fecha
                                   );
   
   BEGIN  

   
      BEGIN
	       INSERT INTO IT.AH_MOVIMIENTOS_HIS_TMP
                SELECT *
                FROM IT.AH_MOVIMIENTOS_HIS
                WHERE (FECHA = p_fecha OR FECHA = p_fecha_ant)
                AND NRO_CUENTA IN (SELECT NRO_CUENTA
                                   FROM it.GE_CTA_DIF_SALDOS
                                   WHERE FECHA = p_fecha
                                   AND cod_modalidad IN('31', '334')
                                   AND tip_saldo IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
                                   AND cod_modalidad NOT IN ( SELECT COD_MODALIDAD 
                                                              FROM IT.GE_DIF_MODALIDAD_CORTE_TMP 
                                                              WHERE FECHA = p_fecha));

      EXCEPTION
	     WHEN OTHERS THEN 
		    IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.pr_bus_segmentacion',
                                        p_det_error    => to_char (systimestamp) || 'Segmentacion Ahorros a la vista: '||SQLERRM,
                                        p_cod_persona  => NULL,
                                        p_nro_cuenta   => NULL);
      END;
      
      BEGIN

	       INSERT INTO IT.CC_MOVIMIENTOS_HIS_TMP
                SELECT *
                FROM IT.CC_MOVIMIENTOS_HIS
                WHERE (FECHA = p_fecha OR FECHA = p_fecha_ant)
                AND NRO_CUENTA IN (SELECT NRO_CUENTA
                                   FROM it.GE_CTA_DIF_SALDOS
                                   WHERE FECHA = p_fecha
                                   AND cod_modalidad = '41'
                                   AND tip_saldo IN ('DISPONIBLE', 'BLOQUEADO','RETENIDO')
                                   AND cod_modalidad NOT IN ( SELECT COD_MODALIDAD 
                                                              FROM IT.GE_DIF_MODALIDAD_CORTE_TMP 
                                                              WHERE FECHA = p_fecha));

      EXCEPTION
	     WHEN OTHERS THEN 
		    IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.Cuenta Corriente',
                                        p_det_error    => to_char (systimestamp) || 'Segmentacion Cuenta corriente: '||SQLERRM,
                                        p_cod_persona  => NULL,
                                        p_nro_cuenta   => NULL);
      END;

      FOR rec IN c_cta_dif_ah_saldos LOOP
          pr_seg_dif_ah_cuentas   (p_fecha      => p_fecha,
                                   p_fecha_ant  => p_fecha_ant,
                                   p_nro_cuenta => rec.nro_cuenta,
                                   p_tip_saldo  => rec.tip_saldo);
      END LOOP;
      
      FOR rec IN c_cta_dif_cc_saldos LOOP
          pr_seg_dif_cc_cuentas   (p_fecha      => p_fecha,
                                   p_fecha_ant  => p_fecha_ant,
                                   p_nro_cuenta => rec.nro_cuenta,
                                   p_tip_saldo  => rec.tip_saldo);
       END LOOP;
         
    
  END;
/* Proceso que limpia redundancia de segmentaciones para quedarse solo con el correcto por falta definicion funcional  */

    PROCEDURE pr_lim_segmentacion (P_FECHA     DATE,
                                   P_FECHA_ANT DATE) IS
                                   
    v_cantidad          NUMBER;
    v_max_fec           DATE;
    v_tipos_encontrados NUMBER;
    v_usuario_match     VARCHAR2(100);
    v_cant_exacto       NUMBER;                             
    
       -- 1.Cursor que verifica correcta segmentacion previa a la limpieza
      CURSOR c_status IS
            WITH DIF_SAL AS (
                SELECT
                    CDS.NRO_CUENTA,
                    CDS.DIF_SALDO,
                    CDS.FECHA,
                    CDS.VAR_DIF_SALDO,
                    CDS.TIP_SALDO,
                    CDS.COD_MODALIDAD
                FROM IT.GE_CTA_DIF_SALDOS CDS
                WHERE CDS.TIP_SALDO IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
                AND CDS.FECHA = p_fecha
                AND CDS.COD_MODALIDAD IN ('31','334','41')
                AND CDS.MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA', 'CUENTA CORRIENTE')
                AND CDS.COD_MODALIDAD NOT IN (
                                              SELECT M.COD_MODALIDAD 
                                              FROM IT.GE_DIF_MODALIDAD_CORTE_TMP M 
                                              WHERE M.FECHA = p_fecha 
                                              AND M.COD_MODALIDAD IS NOT NULL)
                            ),
                DIF_SEG AS (
                       SELECT
                       CDS.NRO_CUENTA,
                       CDS.TIP_SALDO,
                       CDS.COD_MODALIDAD,
                       SUM(CDS.MONTO) AS MONTO_SEG
                       FROM IT.GE_CTA_DIF_SEGMENTADAS CDS
                    WHERE (CDS.FECHA = p_fecha OR CDS.FECHA = p_fecha_ant)
                       AND CDS.COD_MODALIDAD IN ('31','334','41')
                       AND CDS.MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA', 'CUENTA CORRIENTE')
                       AND CDS.TIP_SALDO IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
                       AND CDS.COD_MODALIDAD NOT IN (
                                                      SELECT M.COD_MODALIDAD 
                                                      FROM IT.GE_DIF_MODALIDAD_CORTE_TMP M 
                                                      WHERE M.FECHA = p_fecha 
                                                      AND M.COD_MODALIDAD IS NOT NULL
                                                    )
                       GROUP BY CDS.NRO_CUENTA, CDS.TIP_SALDO, CDS.COD_MODALIDAD
                          )
                SELECT
                DIF_SAL.FECHA,
                DIF_SAL.NRO_CUENTA,
                DIF_SAL.TIP_SALDO,
                DIF_SAL.COD_MODALIDAD,
                DECODE(
                    ABS(NVL(DIF_SAL.VAR_DIF_SALDO, DIF_SAL.DIF_SALDO)) - ABS(NVL(DIF_SEG.MONTO_SEG, 0)),
                    0, 'O',
                    'X'
                ) AS STATUS,
                NVL2(DIF_SEG.NRO_CUENTA, 'SEGMENTADA', 'NO SEGMENTADA') AS SEGMENTACION,
                NVL(DIF_SAL.VAR_DIF_SALDO, DIF_SAL.DIF_SALDO) AS VAR_DIF_SALDO,
                NVL(DIF_SEG.MONTO_SEG, 0) AS DIF_SALDO_SEG,
                ABS(NVL(DIF_SAL.VAR_DIF_SALDO, DIF_SAL.DIF_SALDO)) - ABS(NVL(DIF_SEG.MONTO_SEG, 0)) AS MONTO_NO_SEG
                FROM DIF_SAL
                LEFT JOIN DIF_SEG ON DIF_SAL.NRO_CUENTA = DIF_SEG.NRO_CUENTA AND DIF_SAL.TIP_SALDO = DIF_SEG.TIP_SALDO
                ORDER BY
                DIF_SAL.FECHA,
                DIF_SAL.NRO_CUENTA;
    
    BEGIN
    
        FOR rec IN c_status LOOP
    
            BEGIN --MJ 04/03/2026 valido segmentacion de signo correcto para evitar movimientos erroneos
              SELECT COUNT(*)
              INTO v_cant_exacto
              FROM IT.GE_CTA_DIF_SEGMENTADAS
              WHERE NRO_CUENTA = rec.NRO_CUENTA
              AND tip_saldo = rec.TIP_SALDO
              AND MONTO = rec.VAR_DIF_SALDO
              AND COD_MODALIDAD = rec.COD_MODALIDAD
              AND (FECHA = p_fecha OR FECHA = P_FECHA_ANT);  
            
                   IF v_cant_exacto > 1 THEN
                      DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                      WHERE ROWID IN (
                                     SELECT rid
                                     FROM (
                                           SELECT ROWID rid, ROW_NUMBER() OVER (PARTITION BY NRO_CUENTA, TIP_SALDO, MONTO, TRUNC(FECHA)
                                           ORDER BY ROWID
                                           )
                                        as rn
                      FROM IT.GE_CTA_DIF_SEGMENTADAS
                      WHERE NRO_CUENTA = rec.NRO_CUENTA
                      AND TIP_SALDO = rec.TIP_SALDO
                      AND MONTO = rec.VAR_DIF_SALDO
                      AND COD_MODALIDAD = rec.COD_MODALIDAD
                      AND (FECHA = P_FECHA OR FECHA = P_FECHA_ANT)
                                           )
                      WHERE rn > 1
                                     );
                   END IF;
    
                --CONSIDERAR COINCIDENCIAS POR ABS(MONTO) EN CASO DE NO DAR CON EL SIGNO CORRECTO
              SELECT COUNT(*)
              INTO v_cantidad
              FROM IT.GE_CTA_DIF_SEGMENTADAS
              WHERE NRO_CUENTA = rec.NRO_CUENTA
              AND COD_MODALIDAD = rec.COD_MODALIDAD
              AND TIP_SALDO = rec.TIP_SALDO
              AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
              AND fecha = p_fecha;                      
    
                IF v_cantidad = 1 THEN
                    -- Conservar ese y eliminar el resto
                    DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                    WHERE NRO_CUENTA = rec.NRO_CUENTA
                    AND COD_MODALIDAD = rec.COD_MODALIDAD
                    AND TIP_SALDO = rec.TIP_SALDO
                    AND MONTO != rec.VAR_DIF_SALDO
                    AND fecha = p_fecha;
    
                  ELSIF v_cantidad > 1 THEN
                        -- Verificar si existe al menos un registro con signo exacto correcto en p_fecha
                        -- para priorizar ese sobre los de signo contrario antes de usar MAX(FEC_INSERCION)
                        SELECT COUNT(*)
                        INTO v_cant_exacto
                        FROM IT.GE_CTA_DIF_SEGMENTADAS
                        WHERE NRO_CUENTA = rec.NRO_CUENTA
                        AND COD_MODALIDAD = rec.COD_MODALIDAD
                        AND TIP_SALDO = rec.TIP_SALDO
                        AND MONTO = rec.VAR_DIF_SALDO  -- signo exacto
                        AND fecha = p_fecha;

                        IF v_cant_exacto >= 1 THEN
                            -- Hay registro(s) con signo correcto: eliminar primero todos los de signo incorrecto o monto distinto
                            DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                            WHERE NRO_CUENTA = rec.NRO_CUENTA
                            AND COD_MODALIDAD = rec.COD_MODALIDAD
                            AND TIP_SALDO = rec.TIP_SALDO
                            AND MONTO != rec.VAR_DIF_SALDO
                            AND fecha = p_fecha;

                            -- Si quedaron multiples con signo correcto, conservar solo el mas reciente
                            IF v_cant_exacto > 1 THEN
                                SELECT MAX(FEC_INSERCION)
                                INTO v_max_fec
                                FROM IT.GE_CTA_DIF_SEGMENTADAS
                                WHERE NRO_CUENTA = rec.NRO_CUENTA
                                AND COD_MODALIDAD = rec.COD_MODALIDAD
                                AND TIP_SALDO = rec.TIP_SALDO
                                AND MONTO = rec.VAR_DIF_SALDO
                                AND fecha = p_fecha;

                                DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                                WHERE NRO_CUENTA = rec.NRO_CUENTA
                                AND COD_MODALIDAD = rec.COD_MODALIDAD
                                AND TIP_SALDO = rec.TIP_SALDO
                                AND MONTO = rec.VAR_DIF_SALDO
                                AND FEC_INSERCION < v_max_fec
                                AND fecha = p_fecha;
                            END IF;

                        ELSE
                            -- No hay registro con signo correcto: usar logica ABS con MAX(FEC_INSERCION)
                            SELECT MAX(FEC_INSERCION)
                            INTO v_max_fec
                            FROM IT.GE_CTA_DIF_SEGMENTADAS
                            WHERE NRO_CUENTA = rec.NRO_CUENTA
                            AND COD_MODALIDAD = rec.COD_MODALIDAD
                            AND TIP_SALDO = rec.TIP_SALDO
                            AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
                            AND fecha = p_fecha;

                            -- Eliminar los montos distintos en esa fecha
                            DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                            WHERE NRO_CUENTA = rec.NRO_CUENTA
                            AND FEC_INSERCION = v_max_fec
                            AND ABS(MONTO) != ABS(rec.VAR_DIF_SALDO)
                            AND COD_MODALIDAD = rec.COD_MODALIDAD
                            AND TIP_SALDO = rec.TIP_SALDO
                            AND fecha = p_fecha;

                            -- Eliminar duplicados mas viejos del monto correcto
                            DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                            WHERE NRO_CUENTA = rec.NRO_CUENTA
                            AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
                            AND FEC_INSERCION < v_max_fec
                            AND COD_MODALIDAD = rec.COD_MODALIDAD
                            AND TIP_SALDO = rec.TIP_SALDO
                            AND fecha = p_fecha;

                            -- Eliminar cualquier otro monto incorrecto restante
                            DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                            WHERE NRO_CUENTA = rec.NRO_CUENTA
                            AND ABS(MONTO) != ABS(rec.VAR_DIF_SALDO)
                            AND COD_MODALIDAD = rec.COD_MODALIDAD
                            AND TIP_SALDO  = rec.TIP_SALDO
                            AND fecha = p_fecha;

                            -- Eliminar registros iguales duplicados mediante ROWID
                            DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                            WHERE ROWID IN (
                                            SELECT ROWID
                                            FROM (
                                                  SELECT ROWID, ROW_NUMBER() OVER (PARTITION BY NRO_CUENTA, FECHA, FEC_INSERCION, USUARIO, MONTO, TIPO_DIFERENCIA, MONEDA, SQUAD ORDER BY ROWID) AS RN
                                                  FROM IT.GE_CTA_DIF_SEGMENTADAS
                                                  WHERE NRO_CUENTA = rec.NRO_CUENTA
                                                  AND COD_MODALIDAD = rec.COD_MODALIDAD
                                                  AND TIP_SALDO = rec.TIP_SALDO
                                                  AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
                                                  )
                                            WHERE RN > 1
                                            AND fecha = p_fecha
                                            );

                        END IF;


                END IF;
                     -- Validar si quedaron los dos tipos con mismo monto
                    SELECT COUNT(*)
                    INTO v_tipos_encontrados
                    FROM (
                          SELECT DISTINCT TIPO_DIFERENCIA
                          FROM IT.GE_CTA_DIF_SEGMENTADAS
                          WHERE NRO_CUENTA = rec.NRO_CUENTA
                          AND COD_MODALIDAD = rec.COD_MODALIDAD
                          AND TIP_SALDO = rec.TIP_SALDO
                          AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
                          AND TIPO_DIFERENCIA IN (
                                                  'GENERO MOVIMIENTOS, NO AFECTO SALDO BATCH',
                                                  'GENERO MOVIMIENTOS, NO AFECTO SALDO EN LINEA'
                                                 )
                         );
        
                            -- Si existen ambos tipos, eliminar el de SALDO BATCH
                            IF v_tipos_encontrados = 2 THEN
                                DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                                WHERE NRO_CUENTA = rec.NRO_CUENTA
                                AND COD_MODALIDAD = rec.COD_MODALIDAD
                                AND TIP_SALDO = rec.TIP_SALDO
                                AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
                                AND TIPO_DIFERENCIA = 'GENERO MOVIMIENTOS, NO AFECTO SALDO BATCH'
                                AND fecha = p_fecha;
            
                            END IF;
    
    
            SELECT COUNT(*)
            INTO v_cantidad
            FROM IT.GE_CTA_DIF_SEGMENTADAS
            WHERE NRO_CUENTA = rec.NRO_CUENTA
            AND COD_MODALIDAD = rec.COD_MODALIDAD
            AND TIP_SALDO = rec.TIP_SALDO
            AND ABS(MONTO) = ABS(rec.VAR_DIF_SALDO)
            AND FECHA = p_fecha;
    
                IF v_cantidad = 0 THEN
                    BEGIN
                    SELECT USUARIO
                    INTO v_usuario_match
                    FROM (
                          SELECT USUARIO, ABS(SUM(MONTO)) AS suma
                          FROM IT.GE_CTA_DIF_SEGMENTADAS
                          WHERE NRO_CUENTA = rec.NRO_CUENTA
                          AND COD_MODALIDAD = rec.COD_MODALIDAD
                          AND TIP_SALDO = rec.TIP_SALDO
                          GROUP BY USUARIO
                          HAVING ABS(SUM(MONTO)) = ABS(rec.VAR_DIF_SALDO)
                          )
                    WHERE ROWNUM = 1;
    
                        --SI HAY UN USUARIO CON SUMA QUE COINCIDE, ELIMINAR TODO MENOS ESE USUARIO
                        DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS
                        WHERE NRO_CUENTA = rec.NRO_CUENTA
                        AND COD_MODALIDAD = rec.COD_MODALIDAD
                        AND TIP_SALDO = rec.TIP_SALDO
                        AND USUARIO != v_usuario_match
                        AND fecha = p_fecha;
    
             EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                 NULL; 
    
             END;
         END IF;
    
    
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No se encontró información para la cuenta ' || rec.NRO_CUENTA);
            WHEN OTHERS THEN
            ROLLBACK;
            IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa => 'PAG_BOL.PR_LIM_CUENTAS',
                                   p_det_error    => to_char (systimestamp) || 'Limpieza segmentacion : '||SQLERRM,
                                   p_cod_persona  => NULL,
                                  p_nro_cuenta   => NULL);
            RAISE;
    
        END;
      END LOOP;
    
    
    --2.Se eliminan las cuentas segmentadas con estado X luego de la limpieza para tener solos casos ok prd
    
    
        DELETE FROM IT.GE_CTA_DIF_SEGMENTADAS seg
        WHERE TRUNC(seg.FECHA) = TRUNC(p_fecha)
        AND COD_MODALIDAD IN ('31','334','41')
        AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA', 'CUENTA CORRIENTE')
        AND TIP_SALDO IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
        AND EXISTS (
                    SELECT 1
                    FROM (
                      SELECT s.NRO_CUENTA, s.COD_MODALIDAD, s.TIP_SALDO
                         FROM IT.GE_CTA_DIF_SALDOS s
                         LEFT JOIN (
                          SELECT NRO_CUENTA, COD_MODALIDAD, TIP_SALDO, SUM(MONTO) MONTO_SEG
                                   FROM IT.GE_CTA_DIF_SEGMENTADAS
                                   WHERE FECHA IN (p_fecha, p_fecha_ant)
                                   AND COD_MODALIDAD IN ('31','334','41')
                                   AND MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA', 'CUENTA CORRIENTE') 
                                   AND TIP_SALDO IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
                          GROUP BY NRO_CUENTA, COD_MODALIDAD, TIP_SALDO
                                   ) g
                      ON g.NRO_CUENTA = s.NRO_CUENTA
                      AND g.COD_MODALIDAD = s.COD_MODALIDAD
                      AND g.TIP_SALDO = s.TIP_SALDO
                         WHERE s.TIP_SALDO IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
                         AND s.FECHA = p_fecha
                      AND s.COD_MODALIDAD IN ('31','334','41')
                      AND s.MODALIDAD IN ('CAJA DE AHORRO', 'AHORROS A LA VISTA', 'CUENTA CORRIENTE')
                      AND s.TIP_SALDO IN ('DISPONIBLE','BLOQUEADO','RETENIDO')
                         AND ABS(NVL(s.VAR_DIF_SALDO, s.DIF_SALDO))!= ABS(NVL(g.MONTO_SEG,0))
                         ) x
                    WHERE x.NRO_CUENTA = seg.NRO_CUENTA
                    AND x.COD_MODALIDAD = seg.COD_MODALIDAD
                    AND x.TIP_SALDO = seg.TIP_SALDO
                  );
    
        COMMIT;
    
    END pr_lim_segmentacion;

PROCEDURE pr_bus_dif_cuentas is

    V_FECHA     DATE     := FUG_OBT_FEC_HABIL_ANT (TRUNC(SYSDATE));
    V_FECHA_ANT DATE     := FUG_OBT_FEC_HABIL_ANT (V_FECHA);

/*
    Descripcion:
    Procedimiento que busca diferencias en cuentas para posteriormente segmentar, recorrera todas las cuentas con diferencias
    que existan en ge_cta_dif_saldos y luego parceara la tabla de auditoria y llenara la segmentacion en ge_cta_dif_segmentadas
*/

    BEGIN

      ---------------------------------------------------------------------
      -- 1) LLENAR LA TABLA DE DIFERENCIAS
      ---------------------------------------------------------------------

      pr_pro_dif_saldos(p_fecha     => v_fecha,
                        p_fecha_ant => v_fecha_ant );
                 
      ---------------------------------------------------------------------
      -- 2) PARSEAR AUDITORÍA
      ---------------------------------------------------------------------
  
      pr_par_tab_ah_auditoria (p_fecha     => v_fecha,
                               p_fecha_ant => v_fecha_ant);
                  
      pr_par_tab_cc_auditoria (p_fecha     => v_fecha,
                               p_fecha_ant => v_fecha_ant);

    
      ---------------------------------------------------------------------
      -- 3) BUSCAR SEGMENTACION CUENTAS CON DIFERENCIA
      ---------------------------------------------------------------------
      pr_bus_segmentacion(p_fecha     => v_fecha,
                          p_fecha_ant => v_fecha_ant);

      ---------------------------------------------------------------------
      -- 4) LIMPIEZA DE DATOS
      ---------------------------------------------------------------------
    
      pr_lim_segmentacion (p_fecha     => v_fecha,
                           p_fecha_ant => v_fecha_ant);

    EXCEPTION
      WHEN OTHERS THEN
      ROLLBACK;
        IT.PRG_INS_LOG_PROGRAMAS (p_cod_programa => 'PAG_BOL.PR_BUS_DIF_CUENTAS',
                                  p_det_error    => 'Proceso general'||SQLERRM,
                                  p_cod_persona  => NULL,
                                  p_nro_cuenta   => NULL);
      RAISE;
    END pr_bus_dif_cuentas;

END PAG_BOL;