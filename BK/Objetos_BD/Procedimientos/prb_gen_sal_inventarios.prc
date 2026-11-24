CREATE OR REPLACE PROCEDURE IT.PRB_GEN_SAL_INVENTARIOS IS

--https://itti-digital.atlassian.net/browse/FSOP-21602
 --- Tipos de saldos a cuadrarse
 --- C = Capital
 --- F = Capital AFD
 --- I = Interes
 --- A = A devengar
 --- P = Pignoracion
 --- T = Sobregiro Transitorio
 --- B = Bancos del Pais
 --- D = Devengado
 --- S = Devengado en Suspenso
 --- Z = Saldo Iva vencido en suspenso
 --- G = Gastos
 --- V = Prevision
 --- S = Saldo en (COMEX) --> Repetido
 --- B = Act. Fijo: Depreciacion Acumulada
 --- L = Valuacion --> Valuacion
 --- E = Garantias Computables
 --- J = Garantias No Computables
 --- N = Intereses no documentados
 --- R = Retenido
 --- O = Saldo Contingente
 --- K = Cuentas de resultados
 --- Q = BloQueos por Embargos
 --- O = Cargos Diferidos COVID-19
 --- M = Dep.Dat. Ctas. Pend. de Cancel.

 v_msj VARCHAR2(250);
 v_hor_ini varchar2(8);
 v_hor_fin varchar2(8);
       -- Definición tipos para tabla de rubros en memoria
      TYPE typ_rec_rubros IS RECORD(
        cod_transaccion  ge_transacciones.cod_transaccion%TYPE,
        cod_modulo       ge_transacciones.cod_modulo%TYPE,
        cod_modalidad    ge_transacciones.cod_modalidad%TYPE,
        cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE,
        tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE,
        cod_moneda       ge_tip_asientos.cod_moneda%TYPE,
        ind_plazo        ge_tip_asientos.ind_plazo%TYPE,
        cod_sec_contable ge_tip_asientos.cod_sec_contable%TYPE,
        ind_deudor       ge_tip_asientos.ind_deudor%TYPE,
        ind_producto     ge_tip_asientos.ind_producto%TYPE,
        tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE,
        cod_rubro        ge_tip_asientos.cod_rubro%TYPE,
        cod_sit_contable ge_tip_asientos.cod_sit_contable%TYPE,
        tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE,
        tip_interes      ge_tip_asientos.tip_interes%TYPE,
        cat_automatica   ge_tip_asientos.cat_automatica%TYPE,
        est_cuenta       ge_tip_asientos.est_cuenta%TYPE,
        ind_residente    ge_tip_asientos.ind_residente%TYPE);

      TYPE typ_reg_rubros IS TABLE OF typ_rec_rubros INDEX BY PLS_INTEGER;
      v_reg_rubros      typ_reg_rubros;
      
FUNCTION lf_col_cod_rubro (
   p_cod_modulo      IN ge_transacciones.cod_modulo%TYPE,
   p_cod_modalidad   IN typ_num_lista,
   p_cod_transaccion IN typ_num_lista
) RETURN typ_reg_rubros IS

   v_resultado typ_reg_rubros;

BEGIN
   SELECT 
     b.cod_transaccion,
     b.cod_modulo,
     b.cod_modalidad,
     a.cod_tip_asiento,
     a.tip_movimiento,
     a.cod_moneda,
     a.ind_plazo,
     a.cod_sec_contable,
     NVL(a.ind_deudor, 'X'),
     NVL(a.ind_producto, 'X'),
     NVL(a.tip_cuenta, 'X'),
     a.cod_rubro,
     a.cod_sit_contable,
     NVL(a.tip_renovacion, 'A'),
     a.tip_interes,
     a.cat_automatica,
     a.est_cuenta,
     a.ind_residente
   BULK COLLECT INTO v_resultado
   FROM ge_tip_asientos a
        JOIN ge_transacciones b ON a.cod_tip_asiento = b.cod_tip_asiento
   WHERE b.cod_transaccion IN (SELECT COLUMN_VALUE FROM TABLE(p_cod_transaccion)) 
     AND b.cod_modulo = p_cod_modulo
     AND b.cod_modalidad IN (SELECT COLUMN_VALUE FROM TABLE(p_cod_modalidad))
     AND a.tip_movimiento = 'C';

   RETURN v_resultado;
END;
    
   PROCEDURE lp_sit_del_sobregiro
   (
      cdmodul IN NUMBER,
      cdmodal IN NUMBER,
      cdofici IN NUMBER,
      nrcuent IN VARCHAR2,
      cdtrans IN OUT NUMBER,
      sitsald IN OUT VARCHAR2,
      trautil IN OUT NUMBER
   ) IS
      cantdia NUMBER;
   BEGIN
      cdtrans := 902; /* Situacion vigente */
      trautil := 942; /* Situacion vigente */
      sitsald := 'S';
      SELECT sit_deuda,
             decode(sit_deuda, 'S', 902, 'V', 909, 'G', 900, 'M', 912, 'I', 912, 902),
             decode(sit_deuda, 'S', 942, 'V', 949, 'G', 940, 'M', 952, 'I', 952, 942)
        INTO sitsald, cdtrans, trautil
        FROM cc_sobregiros_res
       WHERE nro_cuenta = nrcuent;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN too_many_rows THEN
         raise_application_error(-20000, 'ERROR. Existen varios registros en CC_SOBREGIROS_RES.');
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR.  en CC_SOBREGIROS_RES.');
   END;
   --------------------------------------------------------------------------------------------------------------------

   -- obtiene el codigo de rubro que corresponde a una cuenta
   PROCEDURE lp_obt_cod_rubro
   (
      p_cod_modulo       IN NUMBER,
      p_cod_modalidad    IN NUMBER,
      p_cod_transaccion  IN NUMBER,
      p_cod_moneda       IN VARCHAR2,
      p_cod_sec_contable IN VARCHAR2,
      p_cod_tip_deudor   IN NUMBER,
      p_residente        IN VARCHAR2,
      p_cod_plazo        IN VARCHAR2,
      p_tip_movimiento   IN VARCHAR2,
      p_cod_rubro        IN OUT VARCHAR2,
      p_est_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_tip_renovacion   IN VARCHAR2 DEFAULT NULL,
      p_cat_automatica   IN NUMBER DEFAULT NULL,
      p_tip_interes      IN VARCHAR2 DEFAULT NULL,
      p_tip_cuenta       IN VARCHAR2 DEFAULT NULL,
      p_cod_sit_contable IN NUMBER DEFAULT NULL,
      p_cod_sec_credito  IN NUMBER DEFAULT NULL
   ) IS
      v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_ind_deudor       ge_tip_asientos.ind_deudor%TYPE;
      v_ind_plazo        ge_tip_asientos.ind_plazo%TYPE;
      v_ind_producto     ge_tip_asientos.ind_producto%TYPE;
   BEGIN
      /* busco la transaccion que le corresponde */
      SELECT tr.cod_tip_asiento, cod_tip_asiento2, cod_pro_contable
        INTO v_cod_tip_asiento, v_cod_tip_asiento2, v_cod_pro_contable
        FROM ge_modalidades mo, ge_transacciones tr
       WHERE tr.cod_modulo = p_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_transaccion = p_cod_transaccion
         AND mo.cod_modulo = p_cod_modulo
         AND mo.cod_modalidad = p_cod_modalidad;

      /* busco la cuenta contable que le corresponde */
      SELECT ind_plazo, ind_deudor, cod_rubro, ind_producto
        INTO v_ind_plazo, v_ind_deudor, p_cod_rubro, v_ind_producto
        FROM ge_tip_asientos
       WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
         AND cod_moneda = p_cod_moneda
         AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
         AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
         AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
         --AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
         and ((nvl(p_tip_cuenta, 'x') = 'B' and tip_cuenta = p_tip_cuenta) or
              (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = p_tip_cuenta)))
         AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
         AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
         AND (ind_residente = 'X' OR ind_residente = p_residente)
         AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
         AND tip_movimiento = p_tip_movimiento
         AND nro_linea =
             (SELECT MIN(nro_linea)
                FROM ge_tip_asientos
               WHERE cod_tip_asiento = v_cod_tip_asiento
                 AND cod_moneda = p_cod_moneda
                 AND (cod_sec_contable IS NULL OR cod_sec_contable = p_cod_sec_contable)
                 AND (tip_renovacion IS NULL OR tip_renovacion = nvl(p_tip_renovacion, 'A'))
                 AND (tip_interes IS NULL OR tip_interes = p_tip_interes)
                 AND (tip_cuenta IS NULL OR tip_cuenta = p_tip_cuenta)
                 AND (cat_automatica IS NULL OR cat_automatica = p_cat_automatica)
                 AND (est_cuenta IS NULL OR est_cuenta = p_est_cuenta)
                 AND (ind_residente = 'X' OR ind_residente = p_residente)
                 AND (cod_sit_contable = p_cod_sit_contable OR cod_sit_contable IS NULL)
                 AND tip_movimiento = p_tip_movimiento);
      IF v_ind_plazo = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 2) || p_cod_plazo || substr(p_cod_rubro, 4, 12);
      END IF;
      IF v_ind_deudor = 'S' OR substr(p_cod_rubro, 9, 2) = 'TD' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 8) || (ltrim(to_char(p_cod_tip_deudor, '00'))) ||
                        substr(p_cod_rubro, 11, 5);
      END IF;
      ---Reemplaza el codigo del producto -----------------------
      IF v_ind_producto = 'S' THEN
         p_cod_rubro := substr(p_cod_rubro, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
      IF substr(p_cod_rubro, 11, 3) = 'SEC' THEN
         -- es solo para prestamos, para contabilizar por sector
         p_cod_rubro := substr(p_cod_rubro, 1, 10) ||
                        ltrim(to_char(fup_obt_sec_rubro(p_cod_sec_credito), '000')) ||
                        substr(p_cod_rubro, 14, 2);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_rubro := NULL;
   END;
   --- fin del obtener codigo de rubro------------------------------------

   --------------------------------------------------------------------------------------------------------------------
   /*Modificado por Ana Azorero Abr-10*/
   --obtiene el codigo de transaccion, segun el codigo de retencion
   PROCEDURE lp_obt_cod_transaccion
   (
      p_cod_modulo      IN NUMBER,
      p_cod_modalidad   IN NUMBER,
      p_cod_retencion   IN VARCHAR2,
      p_cod_transaccion IN OUT VARCHAR2
   ) IS

   BEGIN
      SELECT tr.cod_transaccion
        INTO p_cod_transaccion
        FROM ge_transacciones tr
       WHERE tr.cod_modulo = p_cod_modulo
         AND tr.cod_modalidad = p_cod_modalidad
         AND tr.cod_retencion = p_cod_retencion;
   EXCEPTION
      WHEN OTHERS THEN
         p_cod_transaccion := NULL;
   END;
   --------------------------------------------------------------------------------------------------------------------

   PROCEDURE lp_acu_ctacte_normal IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIENTOS
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_cod_plazo        NUMBER(2);
      v_sal_tot_batch    NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_cau_embargo  ge_par_causales.val_parametro%TYPE;
      v_fila             VARCHAR2(30);
      /* Modificado por Ana Azorero Abr-10 */
      v_sal_ret_batch   NUMBER(22, 2);
      v_sal_blo_batch   NUMBER(22, 2);
      v_sal_disponible  NUMBER(22, 2);
      v_sal_contable    NUMBER(22, 2);
      v_cod_retencion   NUMBER(3);
      v_monto_retencion NUMBER(22, 2);
      v_cod_transaccion NUMBER(05);
      v_mon_pignorado   NUMBER(22, 2);
      v_cod_persona     VARCHAR2(10);
      v_sal_embargo     NUMBER(22, 2);

      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                'N',
                1,
                --SUM(NVL(SAL_TOT_BATCH,0)-NVL(SAL_RET_BATCH,0)-NVL(SAL_BLO_BATCH,0)),
                nvl(sal_tot_batch, 0),
                nvl(sal_ret_batch, 0),
                nvl(sal_blo_batch, 0), /* Modificado por Ana Azorero Abr-10 */
                nvl(emb.monto,0), /* Modificado CNF-2013-Resoluci?n SB SG 00076 2013- Cuentas con embargo */
                a.nro_cuenta,
                c.cod_persona
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_corrientes a,
                (select e.nro_cuenta, sum(nvl(e.monto,0)) monto
                        from ge_bloqueos e
                        where e.cod_causa = v_cod_cau_embargo
                        group by e.nro_cuenta) emb
          WHERE b.cod_persona = c.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR a.sal_blo_batch <> 0)
            and b.nro_cuenta = emb.nro_cuenta(+);
         --EST_BATCH <> 'C'
         --AND NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0) - NVL(SAL_BLO_BATCH,0) >= 0
         --GROUP BY a.COD_MODULO, a.COD_MODALIDAD, a.COD_OFICINA, COD_SEC_CONTABLE,
         --         COD_TIP_DEUDOR, RESIDENTE, COD_MONEDA, 'N', 1, a.NRO_CUENTA


      /* Modificado por Ana Azorero Abr-10 */
      CURSOR reten IS
         SELECT r.cod_retencion, SUM(r.sal_retenido)
           FROM ah_retenciones r
          WHERE r.liberado = 'N'
            AND r.cod_modalidad = 41
            AND r.nro_cuenta = v_nro_cuenta
          GROUP BY r.cod_retencion;

   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      v_cod_cau_embargo := fug_obt_pardinamico('COD_CAU_BLO_EMBAR');
      /* Modificado por Ana Azorero Abr-10 */
      IF reten%ISOPEN THEN
         CLOSE reten;
      END IF;

      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_sal_ret_batch,
                 v_sal_blo_batch, /* Modificado por Ana Azorero Abr-10 */
                 v_sal_embargo,
                 v_nro_cuenta,
                 v_cod_persona;
         EXIT WHEN movimien%NOTFOUND;

         /* Modificado por Ana Azorero Abr-10 */
         --------------------------------------------------------------
         v_sal_disponible := v_sal_tot_batch - v_sal_ret_batch - v_sal_blo_batch;

         CASE
            WHEN v_sal_disponible > 0 AND v_sal_blo_batch = 0 THEN
               v_sal_contable := v_sal_disponible;
            WHEN v_sal_disponible > 0 AND v_sal_blo_batch > 0 THEN
               v_sal_contable := v_sal_disponible + v_sal_blo_batch - v_sal_embargo;
            WHEN v_sal_disponible < 0 AND v_sal_blo_batch > 0 THEN
               v_sal_contable := v_sal_blo_batch - v_sal_embargo;
            WHEN v_sal_disponible = 0 AND v_sal_blo_batch > 0 THEN
               v_sal_contable := v_sal_blo_batch - v_sal_embargo;
            WHEN v_sal_disponible < 0 AND v_sal_blo_batch = 0 THEN
               v_sal_contable := 0;
            WHEN v_sal_disponible = 0 AND v_sal_blo_batch = 0 THEN
               v_sal_contable := 0; --confirmar!!!
            ELSE
               v_sal_contable := 0; --OBS: hubo un error con una cuenta que ten?a sal_blo_batch negativo
         --RAISE_APPLICATION_ERROR(-20000,'CTA: '||v_nro_cuenta||'. ERROR EN ACU_CTACTE_NORMAL:' || sqlerrm);
         END CASE;
         --------------------------------------------------------------
         --Obtengo el monto de pignoracion
         v_mon_pignorado := 0;
         SELECT nvl(SUM(v.monto), 0) monto
            INTO v_mon_pignorado
            FROM (SELECT gb.monto
                    FROM pr_gar_cash      c,
                         pr_garantias     ga,
                         ge_bloqueos      gb
                   WHERE ga.nro_garantia = c.nro_garantia
                     AND ga.estado IN ('C', 'V', 'N', 'T')
                     AND c.nro_cta_referencia = gb.nro_cuenta
                     AND gb.cod_causa = '230'
                     and exists (select 1
                                   from pr_cta_garantias g,
                                        pr_cta_prestamos pr
                                  where g.nro_cuenta = pr.nro_cuenta
                                    and c.nro_garantia = g.nro_garantia
                                    and pr.estado != 'N')
                     AND c.nro_cta_referencia = v_nro_cuenta) v;

         IF v_mon_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mon_pignorado
              FROM (SELECT gb.monto
                      FROM ge_bloqueos gb
                     WHERE gb.nro_cuenta = v_nro_cuenta
                       AND gb.cod_causa = '230'
                       AND EXISTS
              (SELECT 1
                 FROM pr_gar_cash c,
                  pr_garantias ga
                WHERE ga.nro_garantia = c.nro_garantia
                AND ga.estado IN ('C', 'V', 'N', 'T')
                AND c.nro_cta_referencia = gb.nro_cuenta)) v;
         END IF;

         IF v_mon_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mon_pignorado
              FROM (SELECT gb.Monto
                      FROM ge_bloqueos gb
                     WHERE gb.cod_causa = '230'
                       AND NOT EXISTS
                     (SELECT 1 FROM pr_gar_cash m WHERE m.nro_cta_referencia = gb.nro_cuenta)
                       AND gb.nro_cuenta = v_nro_cuenta) v;
         END IF;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'C';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         -- ACTUALIZA SALDO DE CAPITAL --
         --------------------------------

         /* Modificado por Ana Azorero Abr-10 */

         v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 602, v_cod_moneda,
                                                v_cod_persona, to_char(v_cod_plazo), 'C');

         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + /*v_sal_tot_batch*/
                               v_sal_contable /*Modificado por Ana Azorero Abr-10*/
             WHERE ROWID = v_fila;

            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + /*v_sal_tot_batch*/
                                v_sal_contable /*Modificado por Ana Azorero Abr-10*/
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, /*v_sal_tot_batch*/ v_sal_contable, 0); /*Modificado por Ana Azorero Abr-10*/
            END IF;

         EXCEPTION
            WHEN no_data_found THEN

               --- busco la cuenta que le corresponde al saldo ----
               /*
               LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,602,
                                v_cod_moneda,v_cod_sec_contable,v_cod_tip_deudor,
                                v_residente,TO_CHAR(v_cod_plazo),
                                'C',v_cod_rubro);*/

               ------------------------------
               -- INSERTA SALDO DE CAPITAL --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes,
                   /*v_sal_tot_batch*/ v_sal_contable, /*Modificado por Ana Azorero Abr-10*/
                   v_cod_rubro, v_nro_referencia);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, /*v_sal_tot_batch*/ v_sal_contable, 0); /*Modificado por Ana Azorero Abr-10*/
         END;

         /* Modificado por Ana Azorero Abr-10 */
         -------------------------------------------------------
         -- ACTUALIZA SALDO RETENIDO PARA TIPO DE SALDO = R --
         -------------------------------------------------------

         /*OPEN RETEN;
         LOOP FETCH RETEN INTO v_cod_retencion,v_monto_retencion;
         EXIT WHEN RETEN%NOTFOUND;

         v_tip_saldo := 'R';

         --se obtiene el c?digo de transacci?n, seg?n el c?digo de retenci?n
         LP_OBT_COD_TRANSACCION(v_cod_modulo,v_cod_modalidad,v_cod_retencion,v_cod_transaccion);

         --se obtiene el rubro que correspondiente al c?digo de transacci?n
         v_cod_rubro := FUB_OBT_RUB_TRANSACCION(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,v_cod_moneda,
                                                v_cod_persona,TO_CHAR(v_cod_plazo),'C');
         \*
         LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,v_cod_moneda,v_cod_sec_contable,v_cod_tip_deudor,
                          v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*\


         BEGIN

         SELECT NRO_REFERENCIA,ROWID
           INTO v_nro_referencia,v_fila
           FROM CB_SAL_INVENTARIOS
          WHERE COD_MODULO = v_cod_modulo
            AND COD_MODALIDAD = v_cod_modalidad
            AND COD_OFICINA = v_cod_oficina
            AND COD_SEC_CONTABLE = v_cod_sec_contable
            AND COD_TIP_DEUDOR = v_cod_tip_deudor
            AND RESIDENTE = v_residente
            AND COD_MONEDA = v_cod_moneda
            AND situacion = v_sit_saldo
            AND TIP_SALDO = v_tip_saldo
            AND COD_PLAZO = v_cod_plazo
            AND TIP_OPERACION = v_tip_credito
            AND TIP_INTERES = v_tip_interes
            AND COD_RUBRO = v_cod_rubro;

         UPDATE CB_SAL_INVENTARIOS
            SET SAL_TOTAL = NVL(SAL_TOTAL,0) + NVL(v_monto_retencion,0)
            WHERE ROWID = v_fila;

         ----------Genero Detalle------------------------
         UPDATE CB_SAL_INVENTARIOS_DET
            SET SAL_ACTUAL = NVL(SAL_ACTUAL,0) + NVL(v_monto_retencion,0)
            WHERE NRO_REFERENCIA = v_nro_referencia
            AND NRO_CUENTA = v_nro_cuenta;

         IF SQL%NOTFOUND THEN
            INSERT INTO CB_SAL_INVENTARIOS_DET
                (NRO_REFERENCIA,NRO_CUENTA,SAL_ACTUAL,SAL_ANTERIOR)
            VALUES
                (v_nro_referencia, v_nro_cuenta,v_monto_retencion , 0);
         END IF;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
            ----------------------------------------
            -- INSERTA SALDO RETENIDO --------------
            ----------------------------------------
            SELECT S_NRO_REFERENCIA.NEXTVAL INTO v_nro_referencia FROM DUAL;

            INSERT INTO CB_SAL_INVENTARIOS(COD_MODULO, COD_MODALIDAD, COD_OFICINA,
                                       COD_SEC_CONTABLE, COD_TIP_DEUDOR, RESIDENTE,
                                       COD_MONEDA, situacion, TIP_SALDO,
                                       COD_PLAZO, TIP_OPERACION, TIP_INTERES,
                                       SAL_TOTAL, COD_RUBRO, NRO_REFERENCIA)
            VALUES (v_cod_modulo, v_cod_modalidad, v_cod_oficina,
                    v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                    v_cod_moneda, v_sit_saldo, v_tip_saldo,
                    v_cod_plazo, v_tip_credito, v_tip_interes,
                    v_monto_retencion, v_cod_rubro, v_nro_referencia);

            INSERT INTO CB_SAL_INVENTARIOS_DET
                (NRO_REFERENCIA,NRO_CUENTA,SAL_ACTUAL,SAL_ANTERIOR)
            VALUES
                (v_nro_referencia, v_nro_cuenta,v_monto_retencion, 0);
         END;
         -------------------------------------------------------

         END LOOP;
         CLOSE RETEN;*/

         -------------------------------------------------------
         -- ACTUALIZA SALDO PIGNORADO --
         -------------------------------------------------------
         IF v_mon_pignorado > 0 THEN
            v_tip_saldo       := 'P';
            v_cod_transaccion := 2604;
            v_cod_rubro       := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad,
                                                         v_cod_transaccion, v_cod_moneda,
                                                         v_cod_persona, to_char(v_cod_plazo), 'C');

            BEGIN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               --
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                   v_nro_referencia);
               --
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
            -----------------------------------------------------
            v_tip_saldo     := 'T';
            v_mon_pignorado := v_mon_pignorado * -1;
            v_cod_rubro     := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad,
                                                       v_cod_transaccion, v_cod_moneda, v_cod_persona,
                                                       to_char(v_cod_plazo), 'D');

            BEGIN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               --
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                   v_nro_referencia);
               --
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN ACU_CTACTE_NORMAL:' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------

   PROCEDURE lp_acu_ctacte_sobregiro IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIENTOS
      ------------------------------------------------------------------------
      v_cod_modulo          cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad       cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
      v_cod_tra_utilizacion NUMBER(03);
      v_cod_oficina         cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_cuenta          ge_cuentas.nro_cuenta%TYPE;
      v_cod_sec_contable    cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor      cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente           cb_sal_inventarios.residente%TYPE;
      v_cod_moneda          cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo           VARCHAR2(01);
      v_tip_credito         VARCHAR2(01);
      v_categoria           cb_sal_inventarios.cat_automatica%TYPE;
      v_cod_plazo           NUMBER(2);
      v_sal_tot_batch       NUMBER(22, 2);
      v_sal_interes         NUMBER(22, 2);
      v_sob_sin_acuerdo     NUMBER(22, 2);
      v_sob_con_acuerdo     NUMBER(22, 2);
      v_val_sob_acuerdo     NUMBER(22, 2);
      v_tip_saldo           cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes         cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro           cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia      cb_sal_inventarios.nro_referencia%TYPE;
      v_fila                VARCHAR2(30);
      v_fec_actual          DATE := pag_cal.fu_obt_fec_actual(4);
      /*Modificado por Ana Azorero Abr-10*/
      v_sal_contable      NUMBER(22, 2);
      v_cod_persona       VARCHAR2(10);
      v_can_dia_sobregiro NUMBER(7);
      v_fec_ini_sobregiro DATE;
      v_sit_deuda         VARCHAR2(1);
      v_mto_lin_sobregiro NUMBER(22, 2);
      v_cod_rubro_tra     VARCHAR2(15);
      v_cod_rubro_aut     VARCHAR2(15);
      v_mon_pignorado     NUMBER(22, 2);
      v_con_pignoracion   NUMBER(7);

      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                NULL,
                1,
                nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(sal_blo_batch, 0),
                b.cod_persona /*Modificado por Ana Azorero Abr-10*/
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_corrientes a
          WHERE b.cod_persona = c.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND relacion = 'P'
            AND (nvl(sal_tot_batch, 0) <> 0 OR nvl(sal_ret_batch, 0) <> 0 OR
                nvl(sal_blo_batch, 0) <> 0)
               --AND EST_BATCH <> 'C'
            AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(sal_blo_batch, 0) < 0;

   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;

      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_cod_persona;
         EXIT WHEN movimien%NOTFOUND;

         BEGIN
            SELECT r.sit_deuda
              INTO v_sit_deuda
              FROM cc_sobregiros_res r
             WHERE r.nro_cuenta = v_nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_sit_deuda := 'S';
            WHEN OTHERS THEN
               --v_sit_deuda := null;
               raise_application_error(-20000,
                                       'ERROR al obtener SIT_DEUDA en ACU_CTACTE_SOBREGIRO. Nro_cuenta: ' ||
                                        v_nro_cuenta || '. :' || SQLERRM);
         END;

         CASE
            WHEN v_sit_deuda = 'V' THEN
               --Vencido
               v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 949,
                                                      v_cod_moneda, v_cod_persona, '1', 'D');
               IF (v_cod_rubro IS NULL) THEN
                  v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 909,
                                                         v_cod_moneda, v_cod_persona, '1', 'D');
               END IF;

            WHEN v_sit_deuda = 'G' THEN
               --Gestion
               v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 940,
                                                      v_cod_moneda, v_cod_persona, '1', 'D');
               IF (v_cod_rubro IS NULL) THEN
                  v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 900,
                                                         v_cod_moneda, v_cod_persona, '1', 'D');
               END IF;

            WHEN v_sit_deuda IN ('M', 'I') THEN
               --Moroso
               v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 912,
                                                      v_cod_moneda, v_cod_persona, '1', 'D');
               IF (v_cod_rubro IS NULL) THEN
                  v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 952,
                                                         v_cod_moneda, v_cod_persona, '1', 'D');
               END IF;

            WHEN v_sit_deuda = 'S' THEN
               --Transitorio o Autorizado
               v_mto_lin_sobregiro := fuc_obt_mto_lin_sob(v_nro_cuenta, 'T');

               v_sob_con_acuerdo := 0;
               v_sob_sin_acuerdo := 0;

               IF (nvl(v_mto_lin_sobregiro, 0) >= abs(v_sal_tot_batch)) THEN
                  v_sob_con_acuerdo := abs(v_sal_tot_batch);
                  v_sob_sin_acuerdo := 0;
               ELSIF (nvl(v_mto_lin_sobregiro, 0) > 0 AND
                     nvl(v_mto_lin_sobregiro, 0) < abs(v_sal_tot_batch)) THEN
                  v_sob_con_acuerdo := v_mto_lin_sobregiro;
                  v_sob_sin_acuerdo := abs(v_sal_tot_batch) - v_mto_lin_sobregiro;
               ELSE
                  v_sob_con_acuerdo := 0;
                  v_sob_sin_acuerdo := abs(v_sal_tot_batch);
               END IF;

               --Transitorio
               v_cod_rubro_tra := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 902,
                                                          v_cod_moneda, v_cod_persona, '1', 'D');

               --Autorizado
               v_cod_rubro_aut := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, 942,
                                                          v_cod_moneda, v_cod_persona, '1', 'D');

         END CASE;

         --Obtengo el monto de pignoracion
         v_mon_pignorado := 0;
         SELECT nvl(SUM(v.monto), 0) monto
           INTO v_mon_pignorado
           FROM (SELECT gb.monto
                    FROM pr_gar_cash      c,
                         pr_garantias     ga,
                         ge_bloqueos      gb
                   WHERE ga.nro_garantia = c.nro_garantia
                     AND ga.estado IN ('C', 'V', 'N', 'T')
                     AND c.nro_cta_referencia = gb.nro_cuenta
                     AND gb.cod_causa = '230'
                     and exists (select 1
                                   from pr_cta_garantias g,
                                        pr_cta_prestamos pr
                                  where g.nro_cuenta = pr.nro_cuenta
                                    and c.nro_garantia = g.nro_garantia
                                    and pr.estado != 'N')
                     AND c.nro_cta_referencia = v_nro_cuenta) v;

         IF v_mon_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mon_pignorado
              FROM (SELECT gb.monto
                      FROM ge_bloqueos gb
                     WHERE gb.nro_cuenta = v_nro_cuenta
                       AND gb.cod_causa = '230'
                       AND EXISTS
                        (SELECT 1
                           FROM pr_gar_cash c,
                                pr_garantias ga
                          WHERE ga.nro_garantia = c.nro_garantia
                            AND ga.estado IN ('C', 'V', 'N', 'T')
                            AND c.nro_cta_referencia = gb.nro_cuenta)) v;
         END IF;
         --
         IF v_mon_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mon_pignorado
              FROM (SELECT gb.Monto
                      FROM ge_bloqueos gb
                     WHERE gb.cod_causa = '230'
                       AND NOT EXISTS
                     (SELECT 1 FROM pr_gar_cash m WHERE m.nro_cta_referencia = gb.nro_cuenta)
                       AND gb.nro_cuenta = v_nro_cuenta) v;
         END IF;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (Capital, Interes o Devengado)
         --------------------------------------------------------------
         v_tip_saldo := 'C';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';

         IF (v_sit_deuda IN ('V', 'G', 'M', 'I')) THEN
            --SOBREGIRO VENCIDO, EN GESTION, MOROSO O INCOBRABLE

            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_fila
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_sit_deuda
                  AND tip_saldo = v_tip_saldo
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_credito
                  AND tip_interes = v_tip_interes
                  AND cod_rubro = v_cod_rubro;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + abs(v_sal_tot_batch)
                WHERE ROWID = v_fila;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + abs(v_sal_tot_batch)
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, abs(v_sal_tot_batch), 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  ------------------------------
                  -- INSERTA SALDO DE CAPITAL --
                  ------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_deuda, v_tip_saldo,
                      v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_tot_batch), v_cod_rubro,
                      v_nro_referencia);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, abs(v_sal_tot_batch), 0);
            END;

         ELSE
            --SOBREGIRO AUTORIZADO
            IF (v_sob_con_acuerdo > 0) THEN

               v_sit_deuda := 'A';

               BEGIN
                  SELECT nro_referencia, ROWID
                    INTO v_nro_referencia, v_fila
                    FROM cb_sal_inventarios
                   WHERE cod_modulo = v_cod_modulo
                     AND cod_modalidad = v_cod_modalidad
                     AND cod_oficina = v_cod_oficina
                     AND cod_sec_contable = v_cod_sec_contable
                     AND cod_tip_deudor = v_cod_tip_deudor
                     AND residente = v_residente
                     AND cod_moneda = v_cod_moneda
                     AND situacion = v_sit_deuda
                     AND tip_saldo = v_tip_saldo
                     AND cod_plazo = v_cod_plazo
                     AND tip_operacion = v_tip_credito
                     AND tip_interes = v_tip_interes
                     AND cod_rubro = v_cod_rubro_aut;

                  UPDATE cb_sal_inventarios
                     SET sal_total = nvl(sal_total, 0) + v_sob_con_acuerdo
                   WHERE ROWID = v_fila;

                  --- genero detalle ---------------------------------
                  UPDATE cb_sal_inventarios_det
                     SET sal_actual = nvl(sal_actual, 0) + v_sob_con_acuerdo
                   WHERE nro_referencia = v_nro_referencia
                     AND nro_cuenta = v_nro_cuenta;

                  IF SQL%NOTFOUND THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_nro_cuenta, v_sob_con_acuerdo, 0);
                  END IF;

               EXCEPTION
                  WHEN no_data_found THEN
                     ------------------------------
                     -- INSERTA SALDO DE CAPITAL --
                     ------------------------------
                     SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia)
                     VALUES
                        (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                         v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_deuda, v_tip_saldo,
                         v_cod_plazo, v_tip_credito, v_tip_interes, v_sob_con_acuerdo,
                         v_cod_rubro_aut, v_nro_referencia);

                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_nro_cuenta, v_sob_con_acuerdo, 0);
               END;

            END IF;

            --SOBREGIRO TRANSITORIO
            IF (v_sob_sin_acuerdo > 0) THEN

               v_sit_deuda := 'T';

               BEGIN
                  SELECT nro_referencia, ROWID
                    INTO v_nro_referencia, v_fila
                    FROM cb_sal_inventarios
                   WHERE cod_modulo = v_cod_modulo
                     AND cod_modalidad = v_cod_modalidad
                     AND cod_oficina = v_cod_oficina
                     AND cod_sec_contable = v_cod_sec_contable
                     AND cod_tip_deudor = v_cod_tip_deudor
                     AND residente = v_residente
                     AND cod_moneda = v_cod_moneda
                     AND situacion = v_sit_deuda
                     AND tip_saldo = v_tip_saldo
                     AND cod_plazo = v_cod_plazo
                     AND tip_operacion = v_tip_credito
                     AND tip_interes = v_tip_interes
                     AND cod_rubro = v_cod_rubro_tra;

                  UPDATE cb_sal_inventarios
                     SET sal_total = nvl(sal_total, 0) + v_sob_sin_acuerdo
                   WHERE ROWID = v_fila;

                  --- genero detalle ---------------------------------
                  UPDATE cb_sal_inventarios_det
                     SET sal_actual = nvl(sal_actual, 0) + v_sob_sin_acuerdo
                   WHERE nro_referencia = v_nro_referencia
                     AND nro_cuenta = v_nro_cuenta;

                  IF SQL%NOTFOUND THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_nro_cuenta, v_sob_sin_acuerdo, 0);
                  END IF;

               EXCEPTION
                  WHEN no_data_found THEN
                     ------------------------------
                     -- INSERTA SALDO DE CAPITAL --
                     ------------------------------
                     SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia)
                     VALUES
                        (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                         v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_deuda, v_tip_saldo,
                         v_cod_plazo, v_tip_credito, v_tip_interes, v_sob_sin_acuerdo,
                         v_cod_rubro_tra, v_nro_referencia);

                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_nro_cuenta, v_sob_sin_acuerdo, 0);
               END;
            END IF;
         END IF;

         -------------------------------------------------------
         -- ACTUALIZA SALDO PIGNORADO --
         -------------------------------------------------------
         v_con_pignoracion := 0;
         SELECT COUNT(*)
           INTO v_con_pignoracion
           FROM cb_sal_inventarios a, cb_sal_inventarios_det b
          WHERE a.nro_referencia = b.nro_referencia
            AND a.tip_saldo = 'P'
            AND b.nro_cuenta = v_nro_cuenta;

         IF v_con_pignoracion = 0 THEN
            IF v_mon_pignorado > 0 THEN
               v_tip_saldo       := 'P';
               v_cod_transaccion := 2604;
               v_cod_rubro       := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad,
                                                            v_cod_transaccion, v_cod_moneda,
                                                            v_cod_persona, to_char(v_cod_plazo), 'C');

               BEGIN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  --
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                      v_cod_plazo, v_tip_credito, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                      v_nro_referencia);
                  --
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
               -----------------------------------------------------
               v_tip_saldo     := 'T';
               v_mon_pignorado := v_mon_pignorado * -1;
               v_cod_rubro     := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad,
                                                          v_cod_transaccion, v_cod_moneda,
                                                          v_cod_persona, to_char(v_cod_plazo), 'D');

               BEGIN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  --
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                      v_cod_plazo, v_tip_credito, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                      v_nro_referencia);
                  --
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            END IF;
         END IF;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en ACU_CTACTE_SOBREGIRO:' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------

   PROCEDURE lp_acu_ctaban_normal IS
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_fila             VARCHAR2(30);
      v_cod_persona      ba_personas.cod_persona%TYPE;
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_plazo        NUMBER(2);
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_sal_tot_batch    NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_tot_interes      NUMBER(16, 2);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_sal_ret_batch    NUMBER(22, 2);
      v_sal_blo_batch    NUMBER(22, 2);
      v_sal_disponible   NUMBER(22, 2);
      v_sal_contable     NUMBER(22, 2);
      v_cod_retencion    NUMBER(3);
      v_monto_retencion  NUMBER(22, 2);
      v_cod_transaccion  NUMBER(05);
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                'N',
                1,
                nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(sal_blo_batch, 0),
                a.nro_cuenta,
                c.cod_persona,
                nvl(a.cod_rubro, 0)
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a
          WHERE c.cod_persona = b.cod_persona
            AND a.nro_cuenta = b.nro_cuenta
            AND relacion = 'P'
            --WA:08/08/2014 Se incluye modalidad 49 para Financieras Pais
            AND a.cod_modalidad IN (42, 45, 48, 442, 455,49)--WA: 19/02/2014 Se incluye Cta SIPAP
            AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) < 0;
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_nro_cuenta,
                 v_cod_persona,
                 v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'B';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         --- busco la cuenta que le corresponde al saldo ----
         /* v_cod_transaccion := 602;
         LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
                          v_cod_moneda,V_cod_sec_contable,v_cod_tip_deudor,
                          v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*/

         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_tot_batch)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + abs(v_sal_tot_batch)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_tot_batch), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               ---
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_tot_batch), v_cod_rubro,
                   v_nro_referencia);
               ---
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_tot_batch), 0);
         END;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en ACU_CTABAN_NORMAL ' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------

   PROCEDURE lp_acu_ctaban_sobregiro IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIENTOS
      ------------------------------------------------------------------------
      v_cod_tip_deudor      NUMBER(02);
      v_cod_plazo           NUMBER(02);
      v_cod_modulo          cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad       cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion     ge_transacciones.cod_transaccion%TYPE;
      v_cod_tra_utilizacion NUMBER(03);
      v_cod_oficina         cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_referencia      cb_sal_inventarios.nro_referencia%TYPE;
      v_sal_tot_batch       NUMBER(22, 2);
      v_sal_interes         NUMBER(22, 2);
      v_cod_sec_contable    cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente           cb_sal_inventarios.residente%TYPE;
      v_sit_saldo           VARCHAR2(01);
      v_tip_credito         VARCHAR2(01);
      v_categoria           cb_sal_inventarios.cat_automatica%TYPE;
      v_tip_saldo           cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes         cb_sal_inventarios.tip_interes%TYPE;
      v_cod_moneda          cb_sal_inventarios.cod_moneda%TYPE;
      v_cod_persona         ba_personas.cod_persona%TYPE;
      v_nro_cuenta          ge_cuentas.nro_cuenta%TYPE;
      v_cod_rubro           cb_sal_inventarios.cod_rubro%TYPE;
      v_fila                VARCHAR2(30);
      rg_cale               ge_calendarios%ROWTYPE := pag_cal.fu_obt_reg_cal(1);
      v_fec_proceso  CONSTANT DATE := rg_cale.fec_anterior;
      v_fec_anterior CONSTANT DATE := pag_cal.fu_obt_fec_ant_hab(rg_cale.fec_actual,
                                                                 fun_obt_ofi_matriz, 2);
      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                a.cod_moneda,
                NULL,
                1,
                --NVL(SAL_TOT_BATCH,0)-NVL(SAL_RET_BATCH,0)-NVL(SAL_BLO_BATCH,0),
                nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(d.monto, 0),
                b.cod_persona --, nvl(a.cod_rubro,0)
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a, xv_dep_overnight d
          WHERE c.cod_persona = b.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND a.nro_cuenta = d.nro_cuenta(+)
            AND relacion = 'P'
            --WA:08/08/2014 Se incluye modalidad 49 para Financieras Pais
            AND a.cod_modalidad IN (42, 45, 48, 442,49)
            AND d.fecha(+) = v_fec_proceso
            AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(d.monto, 0) > 0;
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_cod_persona; --,v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;
         --- Busco la transaccion y el estado del sobregiro -----------
         lp_sit_del_sobregiro(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nro_cuenta,
                              v_cod_transaccion, v_sit_saldo, v_cod_tra_utilizacion);
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'B';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         --- busco la cuenta que le corresponde al saldo ----
         /* LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
         v_cod_moneda,V_cod_sec_contable,v_cod_tip_deudor,
         v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*/

         -- Rubro de Sobregiros de Cuentas Bancarias
         v_cod_rubro := fug_obt_paradicional(v_nro_cuenta, 'COD_RUB_SOB_CTA_BAN');
         IF v_cod_rubro IS NULL THEN
            BEGIN
               SELECT a.cod_rubro
                 INTO v_cod_rubro
                 FROM cc_cta_bancarias a
                WHERE a.nro_cuenta = v_nro_cuenta
                  AND a.cod_modulo = v_cod_modulo
                  AND a.cod_modalidad = v_cod_modalidad;
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20000,
                                          'ERROR. No se encontro Rubro Cta.Bancaria:' ||
                                           v_nro_cuenta);
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'ERROR:Obt.Rubro Cta.Bancaria:' || SQLERRM);
            END;
         END IF;
         ---
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_tot_batch
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_tot_batch
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               ---
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, v_sal_tot_batch, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
         END;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en ACU_CTABAN_SOBREGIRO ' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------
   PROCEDURE lp_acu_ahorro_a_la_vista IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIEN
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_situacion        cb_sal_inventarios.situacion%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_cod_cau_embargo  ge_par_causales.val_parametro%TYPE;
      v_cod_plazo        NUMBER(02);
      v_sal_tot_batch    NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_tip_saldo        VARCHAR2(01);
      v_tip_interes      VARCHAR2(01);
      v_cod_rubro        VARCHAR2(15);
      v_nro_cuenta       VARCHAR2(15);
      v_cod_transaccion  NUMBER(05);
      v_dev_no_cobrado   NUMBER(16, 2);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_mon_pignorado    NUMBER(22, 2);
      v_rowid            VARCHAR2(30);
      v_fecha            DATE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%type;
      /* Modificado por Ana Azorero Abr-10 */
      v_sal_ret_batch   NUMBER(22, 2);
      v_cod_retencion   NUMBER(3);
      v_monto_retencion NUMBER(22, 2);
      v_cod_persona     VARCHAR2(10);
      v_tip_movimiento  VARCHAR2(1);

      --Deveg. Grupal--
      v_tie_dev_grupal  varchar2(1);
      v_pri_dev_grupal  varchar2(1);
      V_HAB_DEV_GRUPAL GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;

      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
       SELECT * from av_cta_inventarios;

       TYPE cb_sal_inventarios_tmp_type IS TABLE OF cb_sal_inventarios_tmp%ROWTYPE INDEX BY PLS_INTEGER;
       reg_cb_sal_inventarios_tmp cb_sal_inventarios_tmp_type;
       TYPE cursor2_type IS TABLE OF movimien%ROWTYPE;
                             reg2 cursor2_type;

       -- Definición del type segun la tabla temporal.
       TYPE t_resultados_tabla IS TABLE OF cb_sal_inventarios_tmp%ROWTYPE INDEX BY PLS_INTEGER;

       v_resultados t_resultados_tabla;
       v_indice PLS_INTEGER := 0;
       c PLS_INTEGER:= 1;
       j PLS_INTEGER;
       v_gru_encontrado BOOLEAN; -- Para verificar si se encontró el grupo
       v_limit CONSTANT PLS_INTEGER := 500000;
       v_cod_pro_contable number;
       v_cod_modalidades        typ_num_lista:= typ_num_lista(31,334);
       v_cod_transacciones      typ_num_lista:= typ_num_lista(602,682,901);
  BEGIN
        V_HAB_DEV_GRUPAL := NVL(fug_obt_pardinamico('DEV_GRU_HAB_DEV_GRUPAL'),
                                'N');
        DBMS_MVIEW.REFRESH(list           => 'AV_CTA_INVENTARIOS',
                           method         => 'C', -- indico que el refrescamiento es completo 
                           atomic_refresh => FALSE -- falso porque asi hace un truncado basicamente 
                           );
        sql_util.ejecute_dml('TRUNCATE TABLE CB_SAL_INVENTARIOS_TMP', v_msj);
  
      IF v_msj IS NOT NULL THEN
         raise_application_error(-20000, v_msj);
      END IF;
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
  
  v_cod_cau_embargo := fug_obt_pardinamico('COD_CAU_BLO_EMBAR');
  --Cargo mi coleccion.
  v_reg_rubros := lf_col_cod_rubro(3, v_cod_modalidades, v_cod_transacciones);

  -- Vaciar colecciones
  reg_cb_sal_inventarios_tmp.DELETE;
  v_resultados.DELETE;
  ------------------------- LEER MOVIMIEN ------------------------------
  OPEN movimien;
  LOOP
    FETCH movimien BULK COLLECT
      INTO reg2 LIMIT v_limit;
    FOR i IN 1 .. reg2.count LOOP
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
      --------------------------------------------------------------
      v_tip_saldo := 'C';
      --------------------------------------------------------------
    
      IF reg2(i).situacion = 'S' THEN
        /* Es cuenta combinada */
        v_cod_transaccion := 682;
      ELSE
        /* no es cuenta combinada */
        v_cod_transaccion := 602;
      END IF;
      ----------------------------------------------------------------
      -- OBTENGO EL RUBRO CONTABLE------------------------------------
      if reg2(i).cod_modalidad = 31 then
        v_cod_pro_contable := 2;
      elsif reg2(i).cod_modalidad = 334 then
        v_cod_pro_contable := 7;
      else
        v_cod_pro_contable := null;
      end if;
      --Agregado Proyecto Dev. Grupal Cta Tran. Bancard - DYDMR-9825--
      --relacionado a CORECTRB-19--
      v_tie_dev_grupal := 'N';
      v_pri_dev_grupal := 'N';
      v_dev_no_cobrado := 0;
    
      if V_HAB_DEV_GRUPAL = 'S' then
        select decode(nvl(count(*), 0), 0, 'N', 'S') dev_grupal,
               decode(nvl(count(*), 0),
                      0,
                      'N',
                      decode(sum(decode(x.tipo, 'P', 1, 0)), 0, 'N', 'S')) es_principal
          into v_tie_dev_grupal, v_pri_dev_grupal
          from ah_dev_gru_cuentas x
         where x.nro_cuenta = reg2(i).nro_cuenta;
      end if;
    
      if ((v_tie_dev_grupal = 'N') or
         (v_tie_dev_grupal = 'S' and v_pri_dev_grupal = 'S')) then
        SELECT nvl(SUM(mto_dev_acumulado), 0)
          INTO v_dev_no_cobrado
          FROM ah_devengados
         WHERE nro_cuenta = reg2(i).nro_cuenta
           AND fec_inicio >= reg2(i).fec_ult_capitalizacion;
      end if;
    
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
      --------------------------------------------------------------
      v_tip_interes := 'X';
      --------------------------------------------------------------
      -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
      --------------------------------------------------------------
      v_tip_operacion := 'X';
      --------------------------------------------------------------
      -- ACTUALIZA SALDO DE CAPITAL --
      --------------------------------
    
      /* Modificado por Ana Azorero Abr-10 */
    
      begin
        v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(reg2(i).cod_modulo) ||trim(reg2(i).cod_modalidad) ||trim(reg2(i).cod_sub_modalidad));
      exception
        when others then
          v_tip_cuenta := 'X';
      end;
      v_tip_movimiento := 'C';
      v_cod_rubro := NULL;
      FOR idx IN 1 .. v_reg_rubros.COUNT LOOP  
        IF v_reg_rubros(idx)
         .cod_transaccion = v_cod_transaccion AND v_reg_rubros(idx).cod_moneda = reg2(i).cod_moneda AND v_reg_rubros(idx).cod_modalidad = reg2(i).cod_modalidad AND
            (v_reg_rubros(idx).cod_sec_contable IS NULL OR v_reg_rubros(idx).cod_sec_contable = reg2(i).cod_sec_contable) AND
            (v_reg_rubros(idx).tip_renovacion IS NULL OR v_reg_rubros(idx)
             .tip_renovacion = 'A') AND
            (v_reg_rubros(idx).tip_interes IS NULL OR v_reg_rubros(idx).tip_interes = 'X') AND
            ((NVL(v_tip_cuenta, 'X') = 'B' AND v_reg_rubros(idx)
             .tip_cuenta = v_tip_cuenta) OR
             (NVL(v_tip_cuenta, 'X') <> 'B' AND (v_reg_rubros(idx).tip_cuenta IS NULL OR v_reg_rubros(idx).tip_cuenta =
              v_tip_cuenta))) AND
            (v_reg_rubros(idx).cat_automatica IS NULL) AND
            (v_reg_rubros(idx).est_cuenta IS NULL) AND
            (v_reg_rubros(idx).ind_residente = 'X' OR v_reg_rubros(idx).ind_residente = reg2(i).residente) AND v_reg_rubros(idx).cod_sit_contable IS NULL AND v_reg_rubros(idx)
           .tip_movimiento = v_tip_movimiento THEN
          v_cod_rubro := v_reg_rubros(idx).cod_rubro;
          IF v_reg_rubros(idx).ind_plazo = 'S' then
            v_cod_rubro := substr(v_cod_rubro, 1, 2) || reg2(i).cod_plazo ||
                           substr(v_cod_rubro, 4, 12);
          END IF;
          IF v_reg_rubros(idx)
           .ind_deudor = 'S' OR substr(v_cod_rubro, 9, 2) = 'TD' then
            v_cod_rubro := substr(v_cod_rubro, 1, 8) ||
                           (ltrim(to_char(reg2(i).cod_tip_deudor, '00'))) ||
                           substr(v_cod_rubro, 11, 5);
          END IF;
          ---Reemplaza el codigo del producto -----------------------
          IF v_reg_rubros(idx).IND_PRODUCTO = 'S' THEN
            v_cod_rubro := SUBSTR(v_cod_rubro, 1, 10) ||
                           LTRIM(TO_CHAR(v_cod_pro_contable, '000')) ||
                           SUBSTR(v_cod_rubro, 14, 2);
          END IF;
          EXIT;
        END IF;
      END LOOP;
    
      IF v_cod_rubro IS NULL THEN
        -- Si no encuentro busco utilizando la funcion..
         v_cod_rubro      := fub_obt_rub_transaccion(reg2(i).cod_modulo, reg2(i).cod_modalidad,
                                                     v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_persona,
                                                     to_char(reg2(i).cod_plazo), v_tip_movimiento, null, null, null, null,  v_tip_cuenta);
      END IF;
    
      -- Llenado del tipo en memoria para el primer insert
      reg_cb_sal_inventarios_tmp(c).cod_modulo := reg2(i).cod_modulo;
      reg_cb_sal_inventarios_tmp(c).cod_modalidad := reg2(i).cod_modalidad;
      reg_cb_sal_inventarios_tmp(c).cod_oficina := reg2(i).cod_oficina;
      reg_cb_sal_inventarios_tmp(c).cod_sec_contable := reg2(i).cod_sec_contable;
      reg_cb_sal_inventarios_tmp(c).cod_tip_deudor := reg2(i).cod_tip_deudor;
      reg_cb_sal_inventarios_tmp(c).residente := reg2(i).residente;
      reg_cb_sal_inventarios_tmp(c).cod_moneda := reg2(i).cod_moneda;
      reg_cb_sal_inventarios_tmp(c).situacion := reg2(i).situacion;
      reg_cb_sal_inventarios_tmp(c).tip_saldo := v_tip_saldo;
      reg_cb_sal_inventarios_tmp(c).cod_plazo := reg2(i).cod_plazo;
      reg_cb_sal_inventarios_tmp(c).tip_operacion := v_tip_operacion;
      reg_cb_sal_inventarios_tmp(c).tip_interes := v_tip_interes;
      reg_cb_sal_inventarios_tmp(c).sal_total := reg2(i).sal_tot_batch; -- Para el primer insert
      reg_cb_sal_inventarios_tmp(c).cod_rubro := v_cod_rubro;
      reg_cb_sal_inventarios_tmp(c).nro_referencia := v_nro_referencia;
      reg_cb_sal_inventarios_tmp(c).nro_cuenta := reg2(i).nro_cuenta;
      c := c + 1;
      -------------------------------------------------------
      -- ACTUALIZA SALDO DE INTERES PARA TIPO DE SALDO = D --
      -------------------------------------------------------
      v_tip_saldo := 'D';
    
      v_cod_transaccion := 901;
    
      v_cod_rubro := NULL;
      FOR idx IN 1 .. v_reg_rubros.COUNT LOOP
        IF v_reg_rubros(idx)
         .cod_transaccion = v_cod_transaccion AND v_reg_rubros(idx).cod_moneda = reg2(i).cod_moneda AND v_reg_rubros(idx).cod_modalidad = reg2(i).cod_modalidad AND
            (v_reg_rubros(idx).cod_sec_contable IS NULL OR v_reg_rubros(idx).cod_sec_contable = reg2(i).cod_sec_contable) AND
            (v_reg_rubros(idx).tip_renovacion IS NULL OR v_reg_rubros(idx)
             .tip_renovacion = 'A') AND
            (v_reg_rubros(idx).tip_interes IS NULL OR v_reg_rubros(idx).tip_interes = 'X') AND
            ((NVL(v_tip_cuenta, 'X') = 'B' AND v_reg_rubros(idx)
             .tip_cuenta = v_tip_cuenta) OR
             (NVL(v_tip_cuenta, 'X') <> 'B' AND (v_reg_rubros(idx).tip_cuenta IS NULL OR v_reg_rubros(idx).tip_cuenta =
              v_tip_cuenta))) AND
            (v_reg_rubros(idx).cat_automatica IS NULL) AND
            (v_reg_rubros(idx).est_cuenta IS NULL) AND
            (v_reg_rubros(idx).ind_residente = 'X' OR v_reg_rubros(idx).ind_residente = reg2(i).residente) AND v_reg_rubros(idx).cod_sit_contable IS NULL AND v_reg_rubros(idx)
           .tip_movimiento = v_tip_movimiento THEN
          v_cod_rubro := v_reg_rubros(idx).cod_rubro;
        
          IF v_reg_rubros(idx).ind_plazo = 'S' then
            v_cod_rubro := substr(v_cod_rubro, 1, 2) || reg2(i).cod_plazo ||
                           substr(v_cod_rubro, 4, 12);
          END IF;
          IF v_reg_rubros(idx)
           .ind_deudor = 'S' OR substr(v_cod_rubro, 9, 2) = 'TD' then
            v_cod_rubro := substr(v_cod_rubro, 1, 8) ||
                           (ltrim(to_char(reg2(i).cod_tip_deudor, '00'))) ||
                           substr(v_cod_rubro, 11, 5);
          END IF;
          ---Reemplaza el codigo del producto -----------------------
          IF v_reg_rubros(idx).IND_PRODUCTO = 'S' THEN
            v_cod_rubro := SUBSTR(v_cod_rubro, 1, 10) ||
                           LTRIM(TO_CHAR(v_cod_pro_contable, '000')) ||
                           SUBSTR(v_cod_rubro, 14, 2);
          END IF;
        
          EXIT;
        END IF;
      END LOOP;
    
      IF v_cod_rubro IS NULL THEN
        -- Si no encuentro busco utilizando la funcion ...
         v_cod_rubro := fub_obt_rub_transaccion(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion,
                                                reg2(i).cod_moneda, reg2(i).cod_persona, to_char(reg2(i).cod_plazo),
                                                v_tip_movimiento, null, null, null, null,  v_tip_cuenta);
      END IF;
    
      -- Llenado del tipo en memoria
      reg_cb_sal_inventarios_tmp(c).cod_modulo := reg2(i).cod_modulo;
      reg_cb_sal_inventarios_tmp(c).cod_modalidad := reg2(i).cod_modalidad;
      reg_cb_sal_inventarios_tmp(c).cod_oficina := reg2(i).cod_oficina;
      reg_cb_sal_inventarios_tmp(c).cod_sec_contable := reg2(i).cod_sec_contable;
      reg_cb_sal_inventarios_tmp(c).cod_tip_deudor := reg2(i).cod_tip_deudor;
      reg_cb_sal_inventarios_tmp(c).residente := reg2(i).residente;
      reg_cb_sal_inventarios_tmp(c).cod_moneda := reg2(i).cod_moneda;
      reg_cb_sal_inventarios_tmp(c).situacion := reg2(i).situacion;
      reg_cb_sal_inventarios_tmp(c).tip_saldo := v_tip_saldo;
      reg_cb_sal_inventarios_tmp(c).cod_plazo := reg2(i).cod_plazo;
      reg_cb_sal_inventarios_tmp(c).tip_operacion := v_tip_operacion;
      reg_cb_sal_inventarios_tmp(c).tip_interes := v_tip_interes;
      reg_cb_sal_inventarios_tmp(c).sal_total := v_dev_no_cobrado; -- Para el segundo insert
      reg_cb_sal_inventarios_tmp(c).cod_rubro := v_cod_rubro;
      reg_cb_sal_inventarios_tmp(c).nro_referencia := v_nro_referencia;
      reg_cb_sal_inventarios_tmp(c).nro_cuenta := reg2(i).nro_cuenta;
      c := c + 1;
    
    END LOOP;
    EXIT WHEN movimien%NOTFOUND;
  END LOOP;
  commit;
  CLOSE movimien;

    -- Recorriendo la colección y agrupando los datos
    FOR i IN 1 .. reg_cb_sal_inventarios_tmp.COUNT LOOP
        -- Verificamos si ya existe el grupo en v_resultados
        v_gru_encontrado:= FALSE;
            FOR j IN 1 .. v_indice LOOP
                IF v_resultados(j).cod_modulo = reg_cb_sal_inventarios_tmp(i).cod_modulo AND
                   v_resultados(j).cod_modalidad = reg_cb_sal_inventarios_tmp(i).cod_modalidad AND
                   v_resultados(j).cod_oficina = reg_cb_sal_inventarios_tmp(i).cod_oficina AND
                   v_resultados(j).cod_sec_contable = reg_cb_sal_inventarios_tmp(i).cod_sec_contable AND
                   v_resultados(j).cod_tip_deudor = reg_cb_sal_inventarios_tmp(i).cod_tip_deudor AND
                   v_resultados(j).residente = reg_cb_sal_inventarios_tmp(i).residente AND
                   v_resultados(j).cod_moneda = reg_cb_sal_inventarios_tmp(i).cod_moneda AND
                   v_resultados(j).situacion = reg_cb_sal_inventarios_tmp(i).situacion AND
                   v_resultados(j).tip_saldo = reg_cb_sal_inventarios_tmp(i).tip_saldo AND
                   v_resultados(j).cod_plazo = reg_cb_sal_inventarios_tmp(i).cod_plazo AND
                   v_resultados(j).tip_operacion = reg_cb_sal_inventarios_tmp(i).tip_operacion AND
                   nvl(v_resultados(j).tip_interes,'X') = nvl(reg_cb_sal_inventarios_tmp(i).tip_interes,'X') AND
                   nvl(v_resultados(j).cod_rubro,'X') = nvl(reg_cb_sal_inventarios_tmp(i).cod_rubro,'X') AND
                   nvl(v_resultados(j).tip_renovacion,'X') = nvl(reg_cb_sal_inventarios_tmp(i).tip_renovacion,'X') AND
                   nvl(v_resultados(j).cat_automatica,'X') = nvl(reg_cb_sal_inventarios_tmp(i).cat_automatica,'X') AND
                   nvl(v_resultados(j).cod_sit_contable,'X') = nvl(reg_cb_sal_inventarios_tmp(i).cod_sit_contable,'X') THEN

                    -- Si existe, acumulamos el sal_total
                    v_resultados(j).sal_total := v_resultados(j).sal_total + reg_cb_sal_inventarios_tmp(i).sal_total;
                    v_gru_encontrado := TRUE; -- Marcamos que se encontró el grupo

                    -- Actualizamos el nro_referencia en reg_cb_sal_inventarios_tmp con las mismas condiciones
                    reg_cb_sal_inventarios_tmp(i).nro_referencia := v_resultados(j).nro_referencia;
                    EXIT; -- Salimos del bucle ya que encontramos el grupo
                END IF;
            END LOOP;

            -- Si no se encontró el grupo, lo agregamos
            IF NOT v_gru_encontrado THEN
                v_indice := v_indice + 1;
                v_resultados(v_indice).cod_modulo := reg_cb_sal_inventarios_tmp(i).cod_modulo;
                v_resultados(v_indice).cod_modalidad := reg_cb_sal_inventarios_tmp(i).cod_modalidad;
                v_resultados(v_indice).cod_oficina := reg_cb_sal_inventarios_tmp(i).cod_oficina;
                v_resultados(v_indice).cod_sec_contable := reg_cb_sal_inventarios_tmp(i).cod_sec_contable;
                v_resultados(v_indice).cod_tip_deudor := reg_cb_sal_inventarios_tmp(i).cod_tip_deudor;
                v_resultados(v_indice).residente := reg_cb_sal_inventarios_tmp(i).residente;
                v_resultados(v_indice).cod_moneda := reg_cb_sal_inventarios_tmp(i).cod_moneda;
                v_resultados(v_indice).situacion := reg_cb_sal_inventarios_tmp(i).situacion;
                v_resultados(v_indice).tip_saldo := reg_cb_sal_inventarios_tmp(i).tip_saldo;
                v_resultados(v_indice).cod_plazo := reg_cb_sal_inventarios_tmp(i).cod_plazo;
                v_resultados(v_indice).tip_operacion := reg_cb_sal_inventarios_tmp(i).tip_operacion;
                v_resultados(v_indice).tip_interes := reg_cb_sal_inventarios_tmp(i).tip_interes;
                v_resultados(v_indice).cod_rubro := reg_cb_sal_inventarios_tmp(i).cod_rubro;
                v_resultados(v_indice).tip_renovacion := reg_cb_sal_inventarios_tmp(i).tip_renovacion;
                v_resultados(v_indice).cat_automatica := reg_cb_sal_inventarios_tmp(i).cat_automatica;
                v_resultados(v_indice).cod_sit_contable := reg_cb_sal_inventarios_tmp(i).cod_sit_contable;
                v_resultados(v_indice).sal_total := reg_cb_sal_inventarios_tmp(i).sal_total; -- Inicializamos sal_total

                -- Generamos un nuevo número de referencia
                v_nro_referencia := s_nro_referencia.nextval;
                v_resultados(v_indice).nro_referencia := v_nro_referencia; -- Asignamos el número de referencia

                -- Actualizamos el nro_referencia en reg_cb_sal_inventarios_tmp
                reg_cb_sal_inventarios_tmp(i).nro_referencia := v_nro_referencia;
            END IF;
    END LOOP;

    -- Insertar los resultados agrupados en la tabla final
    FOR k IN 1 .. v_indice LOOP
        INSERT INTO cb_sal_inventarios (
          cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
          residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
          tip_interes, sal_total, cod_rubro, nro_referencia
      ) VALUES (
          v_resultados(k).cod_modulo, v_resultados(k).cod_modalidad, v_resultados(k).cod_oficina,
          v_resultados(k).cod_sec_contable, v_resultados(k).cod_tip_deudor, v_resultados(k).residente,
          v_resultados(k).cod_moneda, v_resultados(k).situacion, v_resultados(k).tip_saldo,
          v_resultados(k).cod_plazo, v_resultados(k).tip_operacion, v_resultados(k).tip_interes,
          v_resultados(k).sal_total, v_resultados(k).cod_rubro, v_resultados(k).nro_referencia
      );

    END LOOP;

    COMMIT;

    -- Insertar en cb_sal_inventarios_det con los datos en reg_cb_sal_inventarios_tmp
    FORALL i IN 1 .. reg_cb_sal_inventarios_tmp.COUNT
        INSERT INTO cb_sal_inventarios_det (
            nro_referencia, nro_cuenta, sal_actual, sal_anterior
        ) VALUES (
            reg_cb_sal_inventarios_tmp(i).nro_referencia,
            reg_cb_sal_inventarios_tmp(i).nro_cuenta,
            NVL(reg_cb_sal_inventarios_tmp(i).sal_total, 0),
            0
        );

    COMMIT;

  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000, 'ERROR LP_ACU_AHORRO_A_LA_VISTA:' || SQLERRM);
  END;
   -- fin de ahorros a la vista
   --------------------------------------------------------------------------------------------------------------------
    PROCEDURE lp_acu_ahorro_a_plazo IS
        v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
        v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
        v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
        v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
        v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
        v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
        v_residente        cb_sal_inventarios.residente%TYPE;
        v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
        v_situacion        cb_sal_inventarios.situacion%TYPE;
        v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
        v_cod_plazo        NUMBER(02);
        v_fec_apertura     DATE;
        v_sal_tot_batch    NUMBER(22, 2);
        v_interes          NUMBER(22, 2);
        v_sal_total        NUMBER(22, 2);
        v_dev_no_cobrado   NUMBER(22, 2);
        v_int_devengado    NUMBER(22, 2);
        v_tot_pago         NUMBER(22, 2);
        v_tip_saldo        VARCHAR2(01);
        v_tip_interes      VARCHAR2(01);
        v_cod_rubro        VARCHAR2(15);
        v_est_cta_batch    VARCHAR2(01);
        v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
        v_mon_pignorado    NUMBER(22, 2);
        v_cod_transaccion  NUMBER(05);
        v_men_error        VARCHAR2(512);

        v_limit CONSTANT PLS_INTEGER := 80000;

        CURSOR movimien IS
            SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                   c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda,
                   cod_plazo, nvl(a.fec_ult_capitalizacion, a.fec_apertura) fec_apertura,
                   a.est_batch,
                   nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) sal_tot_batch
            FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, ah_cta_plazos a
            WHERE b.nro_cuenta = a.nro_cuenta
              AND b.relacion = 'P'
              AND c.cod_persona = b.cod_persona
              AND a.est_batch NOT IN ('C', 'T')
              AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR a.sal_blo_batch <> 0)
              AND can_dias = (SELECT MIN(can_dias)
                                FROM ge_plz_contables
                               WHERE can_dias >= a.fec_vencimiento - a.fec_apertura);
                               
        TYPE t_movimientos_coll IS TABLE OF movimien%ROWTYPE;
        l_movimientos t_movimientos_coll;
        
        --Colección para la tabla temporal
        r_tmp cb_sal_inventarios_tmp%ROWTYPE;
        TYPE t_tmp_insert_coll IS TABLE OF cb_sal_inventarios_tmp%ROWTYPE;
        l_tmp_insert t_tmp_insert_coll := t_tmp_insert_coll();

        --Colecciones de memoria
        TYPE tab_cache_number IS TABLE OF NUMBER INDEX BY VARCHAR2(20);
        l_pignorado tab_cache_number;
        l_pagado    tab_cache_number;
        l_devengado tab_cache_number;
        l_cache_vacia tab_cache_number;

        --Cursor de consolidación
        CURSOR c_inventario IS
            select sum(sal_total) sal_total,
                   t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                   t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                   t.tip_interes, t.cod_rubro
            from cb_sal_inventarios_tmp t
            group by
                   t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                   t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                   t.tip_interes, t.cod_rubro;
                   
        TYPE cursor3_type IS TABLE OF c_inventario%ROWTYPE;
        reg3 cursor3_type;
    BEGIN
        sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_inventarios_tmp', v_msj);
        IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
        END IF;
        --PRE-CARGAR DATOS EN MEMORIA
        l_pignorado := l_cache_vacia;
        l_pagado    := l_cache_vacia;
        l_devengado := l_cache_vacia;

        FOR r IN (
            SELECT nro_cuenta, SUM(monto) AS total
            FROM (
                SELECT c.nro_cta_referencia AS nro_cuenta, gb.monto
                FROM pr_gar_cash c, pr_garantias ga, ge_bloqueos gb
                WHERE ga.nro_garantia = c.nro_garantia
                  AND ga.estado IN ('C', 'V', 'N', 'T')
                  AND c.nro_cta_referencia = gb.nro_cuenta
                  AND gb.cod_causa = '230'
                  AND exists (select 1 from pr_cta_garantias g, pr_cta_prestamos pr
                              where g.nro_cuenta = pr.nro_cuenta
                                and c.nro_garantia = g.nro_garantia
                                and pr.estado != 'N')
                UNION ALL
                SELECT gb.nro_cuenta, gb.monto
                FROM ge_bloqueos gb
                WHERE gb.cod_causa = '230'
                  AND EXISTS (SELECT 1 FROM pr_gar_cash c, pr_garantias ga
                              WHERE ga.nro_garantia = c.nro_garantia
                                AND ga.estado IN ('C', 'V', 'N', 'T')
                                AND c.nro_cta_referencia = gb.nro_cuenta)
                UNION ALL
                SELECT gb.nro_cuenta, gb.Monto
                FROM ge_bloqueos gb
                WHERE gb.cod_causa = '230'
                  AND NOT EXISTS (SELECT 1 FROM pr_gar_cash m WHERE m.nro_cta_referencia = gb.nro_cuenta)
            )
            WHERE nro_cuenta IN (SELECT nro_cuenta FROM ah_cta_plazos WHERE est_batch NOT IN ('C', 'T'))
            GROUP BY nro_cuenta
        ) LOOP
            l_pignorado(r.nro_cuenta) := r.total;
        END LOOP;

        -- Pagos de Cupones
        FOR r IN (
            SELECT nro_cuenta, SUM(nvl(mto_interes, 0)) AS total
            FROM ah_cupones
            WHERE estado = 'P'
              AND EXISTS (SELECT 1 FROM ah_cta_plazos a WHERE a.nro_cuenta = ah_cupones.nro_cuenta AND a.est_batch NOT IN ('C', 'T'))
            GROUP BY nro_cuenta
        ) LOOP
            l_pagado(r.nro_cuenta) := r.total;
        END LOOP;

        -- Intereses Devengados
        FOR r IN (
            SELECT d.nro_cuenta, SUM(nvl(d.mto_dev_acumulado, 0)) AS total
            FROM ah_devengados d
            JOIN ah_cta_plazos a ON d.nro_cuenta = a.nro_cuenta
            WHERE d.fec_inicio >= nvl(a.fec_ult_capitalizacion, a.fec_apertura)
              AND a.est_batch NOT IN ('C', 'T')
            GROUP BY d.nro_cuenta
        ) LOOP
            l_devengado(r.nro_cuenta) := r.total;
        END LOOP;

        IF movimien%ISOPEN THEN CLOSE movimien; END IF;
        OPEN movimien;
        LOOP
            FETCH movimien BULK COLLECT INTO l_movimientos LIMIT v_limit;
            EXIT WHEN l_movimientos.COUNT = 0;
            
            l_tmp_insert.DELETE;

           FOR i IN 1 .. l_movimientos.COUNT LOOP
                v_cod_modulo       := l_movimientos(i).cod_modulo;
                v_cod_modalidad    := l_movimientos(i).cod_modalidad;
                v_cod_oficina      := l_movimientos(i).cod_oficina;
                v_nro_cuenta       := l_movimientos(i).nro_cuenta;
                v_cod_sec_contable := l_movimientos(i).cod_sec_contable;
                v_cod_tip_deudor   := l_movimientos(i).cod_tip_deudor;
                v_residente        := l_movimientos(i).residente;
                v_cod_moneda       := l_movimientos(i).cod_moneda;
                v_cod_plazo        := l_movimientos(i).cod_plazo;
                v_fec_apertura     := l_movimientos(i).fec_apertura;
                v_est_cta_batch    := l_movimientos(i).est_batch;
                v_sal_tot_batch    := l_movimientos(i).sal_tot_batch;
                v_situacion        := 'N';
                v_cod_transaccion  := 602;
                v_tip_interes      := 'X';
                v_tip_operacion    := 'X';
                
                BEGIN
                    v_mon_pignorado := l_pignorado(v_nro_cuenta);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN v_mon_pignorado := 0;
                END;
                
                BEGIN
                    v_tot_pago := l_pagado(v_nro_cuenta);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN v_tot_pago := 0;
                END;

                BEGIN
                    v_int_devengado := l_devengado(v_nro_cuenta);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN v_int_devengado := 0;
                END;
                -- Calcular saldos
                v_sal_total      := nvl(v_sal_tot_batch, 0);
                v_dev_no_cobrado := nvl(v_int_devengado, 0);
                v_interes        := nvl(v_int_devengado, 0);

                --Acumular Saldo Capital
                v_tip_saldo := 'C';
                BEGIN
                    lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda, v_cod_sec_contable, 
                                     v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN 
                      v_cod_rubro := NULL;
                END;
                
                l_tmp_insert.EXTEND;
                r_tmp := NULL;
                r_tmp.cod_modulo := v_cod_modulo; 
                r_tmp.cod_modalidad := v_cod_modalidad; 
                r_tmp.cod_oficina := v_cod_oficina;
                r_tmp.cod_sec_contable := v_cod_sec_contable; 
                r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                r_tmp.residente := v_residente;
                r_tmp.cod_moneda := v_cod_moneda; 
                r_tmp.situacion := v_situacion; 
                r_tmp.tip_saldo := v_tip_saldo;
                r_tmp.cod_plazo := v_cod_plazo; 
                r_tmp.tip_operacion := v_tip_operacion; 
                r_tmp.tip_interes := v_tip_interes;
                r_tmp.sal_total := v_sal_total; 
                r_tmp.cod_rubro := v_cod_rubro; 
                r_tmp.nro_cuenta := v_nro_cuenta;
                l_tmp_insert(l_tmp_insert.LAST) := r_tmp;

                -- Acumular Interés Plazo Fijo Digital
                IF v_cod_modalidad = 37 THEN
                    v_tip_saldo := 'I';
                    BEGIN
                        lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 400, v_cod_moneda, v_cod_sec_contable, 
                                         v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN 
                          v_cod_rubro := NULL;
                    END;
                    
                    l_tmp_insert.EXTEND;
                    r_tmp := NULL;
                    r_tmp.cod_modulo := v_cod_modulo; 
                    r_tmp.cod_modalidad := v_cod_modalidad; 
                    r_tmp.cod_oficina := v_cod_oficina;
                    r_tmp.cod_sec_contable := v_cod_sec_contable; 
                    r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                    r_tmp.residente := v_residente;
                    r_tmp.cod_moneda := v_cod_moneda; 
                    r_tmp.situacion := v_situacion; 
                    r_tmp.tip_saldo := v_tip_saldo;
                    r_tmp.cod_plazo := v_cod_plazo; 
                    r_tmp.tip_operacion := v_tip_operacion; 
                    r_tmp.tip_interes := v_tip_interes;
                    r_tmp.sal_total := v_interes; 
                    r_tmp.cod_rubro := v_cod_rubro; 
                    r_tmp.nro_cuenta := v_nro_cuenta;
                    l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
                END IF;

                -- Acumular Interés Ahorro Programado
                IF v_cod_modalidad = 38 THEN
                    v_tip_saldo := 'D';
                    v_cod_transaccion := 901;
                    BEGIN
                        lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda, v_cod_sec_contable,
                                         v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN 
                          v_cod_rubro := NULL;
                    END;
                    
                    l_tmp_insert.EXTEND;
                    r_tmp := NULL;
                    r_tmp.cod_modulo := v_cod_modulo; 
                    r_tmp.cod_modalidad := v_cod_modalidad; 
                    r_tmp.cod_oficina := v_cod_oficina;
                    r_tmp.cod_sec_contable := v_cod_sec_contable; 
                    r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                    r_tmp.residente := v_residente;
                    r_tmp.cod_moneda := v_cod_moneda; 
                    r_tmp.situacion := v_situacion; 
                    r_tmp.tip_saldo := v_tip_saldo;
                    r_tmp.cod_plazo := v_cod_plazo; 
                    r_tmp.tip_operacion := v_tip_operacion; 
                    r_tmp.tip_interes := v_tip_interes;
                    r_tmp.sal_total := v_dev_no_cobrado; 
                    r_tmp.cod_rubro := v_cod_rubro; 
                    r_tmp.nro_cuenta := v_nro_cuenta;
                    l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
                END IF;

                --Acumular Pignoración
                IF v_mon_pignorado > 0 THEN
                    -- Pignoración (Tipo 'P')
                    v_tip_saldo := 'P'; 
                    v_situacion := 'N'; 
                    v_cod_transaccion := 603;
                    BEGIN
                        lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda, v_cod_sec_contable,
                                                       v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN 
                          v_cod_rubro := NULL;
                    END;

                    l_tmp_insert.EXTEND;
                    r_tmp := NULL;
                    r_tmp.cod_modulo := v_cod_modulo; 
                    r_tmp.cod_modalidad := v_cod_modalidad; 
                    r_tmp.cod_oficina := v_cod_oficina;
                    r_tmp.cod_sec_contable := v_cod_sec_contable; 
                    r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                    r_tmp.residente := v_residente;
                    r_tmp.cod_moneda := v_cod_moneda; 
                    r_tmp.situacion := v_situacion; 
                    r_tmp.tip_saldo := v_tip_saldo;
                    r_tmp.cod_plazo := v_cod_plazo; 
                    r_tmp.tip_operacion := v_tip_operacion; 
                    r_tmp.tip_interes := v_tip_interes;
                    r_tmp.sal_total := v_mon_pignorado; 
                    r_tmp.cod_rubro := v_cod_rubro; 
                    r_tmp.nro_cuenta := v_nro_cuenta;
                    l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
                    
                    --Contrapartida Pignoración
                    v_tip_saldo := 'T';
                    v_mon_pignorado := v_mon_pignorado * -1;
                    BEGIN
                        lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda, v_cod_sec_contable,
                                         v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'D', v_cod_rubro);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN 
                          v_cod_rubro := NULL;
                    END;
                    
                    l_tmp_insert.EXTEND;
                    r_tmp := NULL;
                    r_tmp.cod_modulo := v_cod_modulo; 
                    r_tmp.cod_modalidad := v_cod_modalidad; 
                    r_tmp.cod_oficina := v_cod_oficina;
                    r_tmp.cod_sec_contable := v_cod_sec_contable; 
                    r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                    r_tmp.residente := v_residente;
                    r_tmp.cod_moneda := v_cod_moneda; 
                    r_tmp.situacion := v_situacion; 
                    r_tmp.tip_saldo := v_tip_saldo;
                    r_tmp.cod_plazo := v_cod_plazo; 
                    r_tmp.tip_operacion := v_tip_operacion; 
                    r_tmp.tip_interes := v_tip_interes;
                    r_tmp.sal_total := v_mon_pignorado; 
                    r_tmp.cod_rubro := v_cod_rubro; 
                    r_tmp.nro_cuenta := v_nro_cuenta;
                    l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
                END IF;
                
            END LOOP;

            IF l_tmp_insert.COUNT > 0 THEN
                BEGIN
                    FORALL i IN 1 .. l_tmp_insert.COUNT SAVE EXCEPTIONS
                        INSERT INTO cb_sal_inventarios_tmp VALUES l_tmp_insert(i);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_men_error := SQLERRM;
                        raise_application_error(-20000, 'Ins.cb_sal_inventarios_tmp (ahorro plazo) ' || v_men_error);
                END;
            END IF;
            
            COMMIT;
            
        END LOOP;
        CLOSE movimien;

        IF c_inventario%ISOPEN THEN CLOSE c_inventario; END IF;
        OPEN c_inventario;
        LOOP
            FETCH c_inventario BULK COLLECT INTO reg3 LIMIT 80000;
            EXIT WHEN reg3.count = 0;
            
            FOR j IN 1 .. reg3.count LOOP
                SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                INSERT INTO cb_sal_inventarios
                   (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                    residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                    tip_interes, sal_total, cod_rubro, nro_referencia)
                VALUES
                   (reg3(j).cod_modulo, reg3(j).cod_modalidad, reg3(j).cod_oficina,reg3(j).cod_sec_contable, reg3(j).cod_tip_deudor,
                    reg3(j).residente, reg3(j).cod_moneda, reg3(j).situacion, reg3(j).tip_saldo, reg3(j).cod_plazo, reg3(j).tip_operacion,
                    reg3(j).tip_interes, reg3(j).sal_total, reg3(j).cod_rubro, v_nro_referencia);

                UPDATE cb_sal_inventarios_tmp t
                   SET nro_referencia = v_nro_referencia
                 WHERE t.cod_modulo = reg3(j).cod_modulo
                   AND t.cod_modalidad = reg3(j).cod_modalidad
                   AND t.cod_oficina = reg3(j).cod_oficina
                   AND nvl(t.cod_sec_contable,'X') = nvl(reg3(j).cod_sec_contable,'X')
                   AND t.cod_tip_deudor = reg3(j).cod_tip_deudor
                   AND nvl(t.residente,'X') = nvl(reg3(j).residente,'X')
                   AND t.cod_moneda = reg3(j).cod_moneda
                   AND t.situacion = reg3(j).situacion
                   AND t.tip_saldo = reg3(j).tip_saldo
                   AND t.cod_plazo = reg3(j).cod_plazo
                   AND nvl(t.tip_operacion,'X') = nvl(reg3(j).tip_operacion,'X')
                   AND nvl(t.tip_interes,'X') = nvl(reg3(j).tip_interes,'X')
                   AND nvl(t.cod_rubro,'X') = nvl(reg3(j).cod_rubro,'X');
            END LOOP;
            COMMIT;
        END LOOP;
        CLOSE c_inventario;

        INSERT /*+ APPEND */ INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
        SELECT a.nro_referencia, a.nro_cuenta, nvl(a.sal_total, 0), 0
        FROM cb_sal_inventarios_tmp a
        WHERE a.nro_referencia IS NOT NULL;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20000, 'ERROR EN LP_ACU_AHORRO_A_PLAZO:' || SQLERRM);
    END;
   -- fin de ahorros a plazo
   --------------------------------------------------------------------------------------------------------------------


   PROCEDURE lp_acu_cda_y_cupones IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIEN
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_situacion        cb_sal_inventarios.situacion%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_cod_plazo        NUMBER(02);
      v_fec_apertura     DATE;
      v_sal_tot_batch    NUMBER(22, 2);
      v_interes          NUMBER(22, 2);
      v_int_vencido      NUMBER(22, 2);
      v_sal_total        NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_int_a_devengar   NUMBER(22, 2);
      v_tot_interes      NUMBER(22, 2);
      v_int_devengado    NUMBER(22, 2);
      v_int_pagado       NUMBER(22, 2);
      v_tot_pago         NUMBER(22, 2);
      v_tip_saldo        VARCHAR2(01);
      v_tip_interes      VARCHAR2(01);
      v_cod_rubro        VARCHAR2(15);
      v_est_cta_batch    VARCHAR2(01);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_rowid            VARCHAR2(30);
      v_cod_transaccion  NUMBER(05);
      v_mon_pignorado    NUMBER(22, 2);
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
      CURSOR movimien IS
         SELECT
          a.cod_modulo,
          a.cod_modalidad,
          a.cod_oficina,
          a.nro_cuenta,
          c.cod_sec_contable,
          c.cod_tip_deudor,
          c.residente,
          a.cod_moneda,
          cod_plazo,
          nvl(a.fec_ult_capitalizacion, a.fec_apertura) fec_ult_capitalizacion,
          decode(a.est_batch, 'B', decode(a.est_cer_batch, 'V', 'V', 'N'),
                 decode(a.est_batch, 'P', 'V', a.est_batch)) est_batch,
          nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0)
           FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, ah_cta_certificados a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND (a.est_batch NOT IN ('C', 'T')
             or (a.est_batch = 'T' and exists (select 1 from ah_cupones cup
                                                where cup.nro_cuenta = a.nro_cuenta
                                                  and cup.estado = 'V')))
            AND can_dias = (SELECT MIN(can_dias)
                              FROM ge_plz_contables
                             WHERE can_dias >= a.fec_vencimiento - a.fec_apertura)
            AND a.cod_modalidad <> 36; --Modificado por Ana Azorero Set 2010. El cuadre para bonos subordinados se realiza en el procedimiento LP_ACU_BONOS_SUB

   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_cod_plazo,
                 v_fec_apertura,
                 v_est_cta_batch,
                 v_sal_tot_batch;
         EXIT WHEN movimien%NOTFOUND;
         v_situacion       := 'N';
         v_cod_transaccion := 602;
         v_mon_pignorado   := 0;
         SELECT nvl(SUM(v.monto), 0) monto
           INTO v_mon_pignorado
           FROM (SELECT gb.monto
                    FROM pr_gar_cash      c,
                         pr_garantias     ga,
                         ge_bloqueos      gb
                   WHERE ga.nro_garantia = c.nro_garantia
                     AND ga.estado IN ('C', 'V', 'N', 'T')
                     AND c.nro_cta_referencia = gb.nro_cuenta
                     AND gb.cod_causa = '230'
                     and exists (select 1
                                   from pr_cta_garantias g,
                                        pr_cta_prestamos pr
                                  where g.nro_cuenta = pr.nro_cuenta
                                    and c.nro_garantia = g.nro_garantia
                                    and pr.estado != 'N')
                     AND c.nro_cta_referencia = v_nro_cuenta) v;

         IF v_mon_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mon_pignorado
              FROM (SELECT gb.monto
                      FROM ge_bloqueos gb
                     WHERE gb.nro_cuenta = v_nro_cuenta
                       AND gb.cod_causa = '230'
                       AND EXISTS
                        (SELECT 1
                           FROM pr_gar_cash c,
                                pr_garantias ga
                          WHERE ga.nro_garantia = c.nro_garantia
                            AND ga.estado IN ('C', 'V', 'N', 'T')
                            AND c.nro_cta_referencia = gb.nro_cuenta)) v;
         END IF;

         IF v_mon_pignorado <= 0 THEN
            SELECT nvl(SUM(v.monto), 0) monto
              INTO v_mon_pignorado
              FROM (SELECT gb.Monto
                      FROM ge_bloqueos gb
                     WHERE gb.cod_causa = '230'
                       AND NOT EXISTS
                     (SELECT 1 FROM pr_gar_cash m WHERE m.nro_cta_referencia = gb.nro_cuenta)
                       AND gb.nro_cuenta = v_nro_cuenta) v;
         END IF;

         IF v_est_cta_batch = 'V' THEN
            v_situacion       := 'V';
            v_cod_transaccion := 604;
         END IF;
         ---------------------------------------------------------
         -- OBTIENE TOTALES DE LOS CUPONES  EMITIDOS Y VENCIDOS --
         ---------------------------------------------------------
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_int_vencido
           FROM ah_cupones
          WHERE nro_cuenta = v_nro_cuenta
            AND estado = 'V';
         --------------------------------------------
         -- OBTIENE EL TOTAL DE INTERES DEL CERTIF.--
         --------------------------------------------
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_tot_interes
           FROM ah_cupones
          WHERE nro_cuenta = v_nro_cuenta
            AND estado IN ('E', 'C')
            AND v_est_cta_batch IN ('N', 'B');
         --------------------------------------------
         -- OBTIENE EL TOTAL DE INTERES PAGADO
         --------------------------------------------
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_tot_pago
           FROM ah_cupones
          WHERE nro_cuenta = v_nro_cuenta
            AND estado = 'P';
         --------------------------------------------
         -- OBTIENE EL TOTAL DE INTERES DEVENGADO ---
         --------------------------------------------
         SELECT SUM(nvl(mto_dev_acumulado, 0))
           INTO v_int_devengado
           FROM ah_devengados
          WHERE nro_cuenta = v_nro_cuenta
            AND fec_inicio >= v_fec_apertura;
         --------------------------------------------
         -- CALCULO DEL SALDOTO Y SALDO A DEVENGAR --
         --------------------------------------------
         v_sal_total      := nvl(v_sal_tot_batch, 0) - nvl(v_int_vencido, 0);
         v_int_a_devengar := nvl(v_tot_interes, 0) - nvl(v_int_devengado, 0);
         v_interes        := nvl(v_tot_interes, 0);
         -------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) --
         -------------------------------------------------------------
         v_tip_saldo := 'C';
         -------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA) --
         -------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA) --
         --------------------------------------------------
         v_tip_operacion := 'X';
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                          v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                          'C', v_cod_rubro);
         --------------------------------
         -- ACTUALIZA SALDO DE CAPITAL --
         --------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            --
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_total
             WHERE ROWID = v_rowid;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_total
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_total, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               ------------------------------
               -- INSERTA SALDO DE CAPITAL --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_sal_total, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_total, 0);
         END;
         -------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO INTERES                        --
         -------------------------------------------------------------
         v_tip_saldo := 'I';
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 400, v_cod_moneda, v_cod_sec_contable,
                          v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
         -------------------------------------------------------
         -- ACTUALIZA SALDO DE INTERES PARA TIPO DE SALDO = D --
         -------------------------------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            --
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(v_interes, 0)
             WHERE ROWID = v_rowid;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(v_interes, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_interes, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               ------------------------------
               -- INSERTA SALDO DE INTERES --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_interes, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_interes, 0);
         END;
         -------------------------------------------------------
         -- ACTUALIZA SALDO DE INTERES PARA TIPO DE SALDO = A --
         -------------------------------------------------------
         if v_cod_modalidad <> 37 then --Ahorro Plazo Fijo Digital no tiene inventario de Interes Adelantado
       v_tip_saldo := 'A';
       --- busco la cuenta que le corresponde al saldo ----
       lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 901, v_cod_moneda, v_cod_sec_contable,
                v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
       BEGIN
        SELECT nro_referencia, ROWID
          INTO v_nro_referencia, v_rowid
          FROM cb_sal_inventarios
         WHERE cod_modulo = v_cod_modulo
           AND cod_modalidad = v_cod_modalidad
           AND cod_oficina = v_cod_oficina
           AND cod_sec_contable = v_cod_sec_contable
           AND cod_tip_deudor = v_cod_tip_deudor
           AND residente = v_residente
           AND cod_moneda = v_cod_moneda
           AND situacion = v_situacion
           AND tip_saldo = v_tip_saldo
           AND cod_plazo = v_cod_plazo
           AND tip_operacion = v_tip_operacion
           AND tip_interes = v_tip_interes
           AND cod_rubro = v_cod_rubro;
        --
        UPDATE cb_sal_inventarios
           SET sal_total = nvl(sal_total, 0) + nvl(v_int_a_devengar, 0)
         WHERE ROWID = v_rowid;
        --- genero detalle ---------------------------------
        UPDATE cb_sal_inventarios_det
           SET sal_actual = nvl(sal_actual, 0) + nvl(v_int_a_devengar, 0)
         WHERE nro_referencia = v_nro_referencia
           AND nro_cuenta = v_nro_cuenta;
        IF SQL%NOTFOUND THEN
           INSERT INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
           VALUES
            (v_nro_referencia, v_nro_cuenta, v_int_a_devengar, 0);
        END IF;
       EXCEPTION
        WHEN no_data_found THEN
           ----------------------------------------
           -- INSERTA SALDO DE INTERES A DEVENGAR--
           ----------------------------------------
           SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
           INSERT INTO cb_sal_inventarios
            (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
             residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
             tip_interes, sal_total, cod_rubro, nro_referencia)
           VALUES
            (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
             v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
             v_cod_plazo, v_tip_operacion, v_tip_interes, v_int_a_devengar, v_cod_rubro,
             v_nro_referencia);
           INSERT INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
           VALUES
            (v_nro_referencia, v_nro_cuenta, v_int_a_devengar, 0);
       END;
     End If;
         IF v_int_vencido > 0 THEN
            ------------------------------------
            -- ACTUALIZA LOS CUPONES VENCIDOS --
            ------------------------------------
            v_tip_saldo       := 'C';
            v_situacion       := 'V';
            v_cod_transaccion := 604;
            --- busco la cuenta que le corresponde al saldo ----
            lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                             v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                             'C', v_cod_rubro);
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_situacion
                  AND tip_saldo = v_tip_saldo
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_operacion
                  AND tip_interes = v_tip_interes
                  AND cod_rubro = v_cod_rubro;
               --
               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_int_vencido
                WHERE ROWID = v_rowid;
               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_int_vencido
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;
               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_int_vencido, 0);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  -------------------------------------------
                  -- INSERTA EL SALDO DE CUPONES VENCIDOS ---
                  -------------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                      v_cod_plazo, v_tip_operacion, v_tip_interes, v_int_vencido, v_cod_rubro,
                      v_nro_referencia);
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_int_vencido, 0);
            END;
         END IF;
         IF v_mon_pignorado > 0 THEN
            ------------------------------------
            -- ACTUALIZA PIGNORACION DE CDA --
            ------------------------------------
            v_tip_saldo       := 'P';
            v_situacion       := 'N';
            v_cod_transaccion := 603;
            v_cod_rubro       := NULL;
            IF v_est_cta_batch = 'V' THEN
               v_situacion       := 'V';
               v_cod_transaccion := 2605; --Corresponde al numero de asiento y no a la transaccion.
            ELSE
               v_cod_transaccion := 603;
            END IF;
            --- busco la cuenta que le corresponde al saldo ----
            lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                             v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                             'C', v_cod_rubro);

            BEGIN
               -------------------------------------------
               -- ACTUALIZA PIGNORACION DE CDA --
               -------------------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
            ------------------------------------
            -- ACTUALIZA PIGNORACION DE CDA --
            ------------------------------------
            v_tip_saldo     := 'T';
            v_mon_pignorado := v_mon_pignorado * -1;
            IF v_est_cta_batch = 'V' THEN
               v_situacion       := 'V';
               v_cod_transaccion := 2605;
            ELSE
               v_cod_transaccion := '603';
            END IF;
            --- busco la cuenta que le corresponde al saldo ----
            lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                             v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                             'D', v_cod_rubro);

            BEGIN
               -------------------------------------------
               -- ACTUALIZA PIGNORACION DE CDA --
               -------------------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_CDA_Y_CUPONES:' || SQLERRM);
   END;
   -- fin de cda y cupones
   --------------------------------------------------------------------------------------------------------------------

   -- Acumula Pr?stmamos
  PROCEDURE lp_acu_prestamos IS
      v_cod_oficina        ge_movimientos.cod_oficina%TYPE;
      v_cod_rubro          ge_movimientos.cod_rubro%TYPE;
      v_cod_modalidad      ge_movimientos.cod_modalidad%TYPE;
      v_cod_modulo         ge_movimientos.cod_modulo%TYPE;
      v_men_error          VARCHAR2(512);

      v_nro_cuenta         VARCHAR2(15);
      v_cod_sector         VARCHAR2(01);
      v_tip_deudor         NUMBER(02);
      v_residente          VARCHAR2(01);
      v_cod_moneda         VARCHAR2(03);
      v_estado             VARCHAR2(01);
      v_tip_operacion      VARCHAR2(01);
      v_cod_plazo          NUMBER(02);
      v_sal_ori_fondo      NUMBER(22, 2);
      v_tip_sal_cap        VARCHAR2(01);
      v_tip_sal_int        VARCHAR2(01);
      v_tip_sal_dev        VARCHAR2(01);
      v_tip_sal_ade        VARCHAR2(01);
      v_tip_sal_sus        VARCHAR2(01);
      v_tip_sal_iva        VARCHAR2(01);
      v_tip_sal_car        VARCHAR2(01);
      v_tip_interes        VARCHAR2(01);
      v_cat_riesgo         VARCHAR2(1);
      v_tip_renovacion     VARCHAR2(1);
      v_tip_movimiento     VARCHAR2(01);
      v_nro_referencia     cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_sec_credito    pr_cta_prestamos.cod_sec_credito%TYPE;
      v_fec_actual         DATE := pag_cal.fu_obt_fec_actual(6);
      v_redondeo           NUMBER(10);
      v_cod_tra_cargos     VARCHAR2(4000) := fug_obt_pardinamico('COD_TRA_CAR_IMPUESTO');
      v_prevision          cb_sal_inventarios.sal_total%type;
      v_mto_pre_total      cb_sal_inventarios.sal_total%type;
      v_tip_sal_prv        cb_sal_inventarios.tip_saldo%type;
      v_cod_transaccion    ge_transacciones.cod_transaccion%TYPE;
      v_iva_vencido        NUMBER(22, 2);    
      --Colección para Pre-Cargar Previsiones
      TYPE rec_prevision IS RECORD (
          monto         pr_previsiones.monto%TYPE,
          mto_pre_total pr_previsiones.mto_pre_total%TYPE
      );
      TYPE tab_previsiones IS TABLE OF rec_prevision INDEX BY VARCHAR2(20); -- Clave: nro_cuenta
      l_previsiones tab_previsiones;
      l_previsiones_vacia tab_previsiones; -- Para limpiar

      -- Colección para Pre-Cargar IVA Vencido
      TYPE tab_iva IS TABLE OF NUMBER INDEX BY VARCHAR2(20); -- Clave: nro_cuenta
      l_iva_vencido tab_iva;
      l_iva_vencido_vacia tab_iva; -- Para limpiar

      --Colección para la tabla temporal
      r_tmp cb_sal_inventarios_tmp%ROWTYPE;
      TYPE t_tmp_insert_coll IS TABLE OF cb_sal_inventarios_tmp%ROWTYPE;
      l_tmp_insert t_tmp_insert_coll := t_tmp_insert_coll();
      
      -- CURSOR PRINCIPAL
      CURSOR movimien IS
          SELECT
              a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
              c.cod_sec_contable cod_sector, c.cod_tip_deudor tip_deudor, c.residente,
              a.cod_moneda, a.est_batch estado, a.tipo tip_operacion, a.tip_renovacion,
              d.cod_plazo, a.val_int_devengar int_devengar, a.dev_acumulado,
              a.dev_no_cobrado, a.dev_suspenso, a.sal_cap_batch sal_capital,
              nvl(a.sal_int_ade_batch, 0) + nvl(a.sal_int_batch, 0) sal_interes,
              a.tip_interes, nvl(c.cat_riesgo, 1) cat_riesgo, a.cod_sec_credito,
              a.cod_ori_fondo, a.por_ori_fondo
          FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a, ge_cuentas cue
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.nro_cuenta = cue.nro_cuenta
            AND a.nro_cuenta = cue.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND a.est_batch NOT IN ('N', 'I')
            AND d.can_dias = (SELECT MIN(can_dias)
                              FROM ge_plz_contables
                              WHERE can_dias >= a.fec_vencimiento - a.fec_inicio);

      CURSOR c_seguros IS
          SELECT g.cod_transaccion, a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                 c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda, a.est_batch,
                 a.tipo, a.tip_renovacion, d.cod_plazo, g.monto, a.tip_interes, nvl(c.cat_riesgo, 1) cat_riesgo,
                 a.cod_sec_credito, a.cod_ori_fondo, a.por_ori_fondo, b.cod_persona
          FROM pr_cta_gastos g, ge_plz_contables d, ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND a.est_batch NOT IN ('N', 'I')
            AND g.nro_cuenta = a.nro_cuenta
            AND d.can_dias = (SELECT MIN(can_dias) FROM ge_plz_contables WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
            AND g.fec_ult_pago IS NULL
            AND instr(v_cod_tra_cargos,','||to_char(g.cod_transaccion)||',') > 0
            AND NOT EXISTS (select 1 from ba_tab_dat_adicionales x where x.tab_relacion = 'PR_SOLICITUDES' and x.parametro = 'PRE_IND_CUO_CAL_SEGURO' and x.referencia = a.nro_solicitud and x.val_parametro = 'S');
            
      CURSOR c_inventario IS
          select sum(sal_total) sal_total,
                 t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                 t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                 t.tip_interes, t.cod_rubro,
                 t.tip_renovacion as tip_renovacion,
                 t.cat_automatica as cat_automatica,
                 t.cod_sit_contable as cod_sit_contable
          from cb_sal_inventarios_tmp t
          group by
                 t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                 t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                 t.tip_interes, t.cod_rubro,
                 t.tip_renovacion,
                 t.cat_automatica,
                 t.cod_sit_contable;

      TYPE cursor2_type IS TABLE OF movimien%ROWTYPE;
      reg2 cursor2_type;
      TYPE cursor3_type IS TABLE OF c_inventario%ROWTYPE;
      reg3 cursor3_type;
  BEGIN
      sql_util.ejecute_dml('TRUNCATE TABLE CB_SAL_INVENTARIOS_TMP', v_msj);
      IF v_msj IS NOT NULL THEN
          raise_application_error(-20000, v_msj);
      END IF;
      
      --PRE-CARGAR DATOS EN MEMORIA
      l_previsiones := l_previsiones_vacia;
      FOR r IN (
          SELECT p.nro_cuenta, nvl(p.monto,0) as monto, nvl(p.mto_pre_total,0) as mto_pre_total
          FROM pr_previsiones p
          WHERE p.fecha = (SELECT MAX(s.fecha) FROM pr_previsiones s WHERE s.nro_cuenta = p.nro_cuenta)
            AND EXISTS (SELECT 1 FROM pr_cta_prestamos a WHERE a.nro_cuenta = p.nro_cuenta AND a.est_batch NOT IN ('N', 'I'))
      ) LOOP
          l_previsiones(r.nro_cuenta).monto := r.monto;
          l_previsiones(r.nro_cuenta).mto_pre_total := r.mto_pre_total;
      END LOOP;

      l_iva_vencido := l_iva_vencido_vacia;
      FOR r IN (
          SELECT
              a.nro_cuenta,
              SUM(round(p.mto_iva_imponible *
                       (fug_obt_val_tasa(a.cod_modulo, a.cod_modalidad, a.cod_oficina,
                                         NULL, a.cod_moneda, 0, 'N', NULL, 709,
                                         v_fec_actual) / 100),
                       fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', a.cod_modulo,
                                           a.cod_modalidad, a.cod_moneda, a.cod_oficina))) AS iva_total
          FROM pr_cuotas p
          JOIN pr_cta_prestamos a ON p.nro_cuenta = a.nro_cuenta
          WHERE p.nro_cuota > 0
            AND p.estado != 'N'
            AND nvl(p.mto_iva_imponible, 0) > 0
            AND a.est_batch NOT IN ('N', 'I')
          GROUP BY a.nro_cuenta
      ) LOOP
          l_iva_vencido(r.nro_cuenta) := r.iva_total;
      END LOOP;

      -- BUCLE DE PROCESAMIENTO
      IF movimien%ISOPEN THEN CLOSE movimien; END IF;
      OPEN movimien;
      LOOP
          FETCH movimien BULK COLLECT INTO reg2 LIMIT 80000;
          EXIT WHEN reg2.COUNT = 0;
          
          l_tmp_insert.DELETE;

          FOR i IN 1 .. reg2.count LOOP
              -- Obtenemos los valores pre-calculados de la memoria
              v_prevision := 0;
              v_mto_pre_total := 0;
              IF l_previsiones.EXISTS(reg2(i).nro_cuenta) THEN
                  v_prevision := l_previsiones(reg2(i).nro_cuenta).monto;
                  v_mto_pre_total := l_previsiones(reg2(i).nro_cuenta).mto_pre_total;
              END IF;
              
              v_iva_vencido := 0;
              IF l_iva_vencido.EXISTS(reg2(i).nro_cuenta) THEN
                  v_iva_vencido := l_iva_vencido(reg2(i).nro_cuenta);
              END IF;
              
              -- Lógica de tipos de saldo
              v_tip_sal_cap := NULL; v_tip_sal_dev := NULL; v_tip_sal_int := NULL;
              v_tip_sal_ade := NULL; v_tip_sal_sus := NULL; v_tip_sal_iva := NULL;

              IF nvl(reg2(i).sal_capital, 0) > 0 THEN v_tip_sal_cap := 'C'; END IF;
              IF nvl(reg2(i).dev_no_cobrado, 0) > 0 THEN v_tip_sal_dev := 'D'; END IF;
              IF nvl(reg2(i).sal_interes, 0) > 0 THEN v_tip_sal_int := 'I'; END IF;
              IF nvl(reg2(i).int_devengar, 0) <> 0 THEN v_tip_sal_ade := 'A'; END IF;
              IF nvl(reg2(i).dev_suspenso, 0) <> 0 THEN v_tip_sal_sus := 'S'; END IF;
              IF nvl(v_iva_vencido, 0) <> 0 THEN v_tip_sal_iva := 'Z'; END IF;

              --Saldo Capital
              IF v_tip_sal_cap = 'C' THEN
                  v_sal_ori_fondo := 0;
                  IF reg2(i).sal_capital > 0 THEN
                      IF reg2(i).cod_ori_fondo <> fug_obt_pardinamico('COD_ORI_FON_DESEMB', NULL, NULL, reg2(i).cod_moneda, NULL, NULL) AND
                         reg2(i).cod_ori_fondo <> fug_obt_pardinamico('COD_ORI_FON_DESEMB', 6, reg2(i).cod_modalidad, reg2(i).cod_moneda, NULL, NULL) THEN
                          v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, reg2(i).cod_modalidad, reg2(i).cod_moneda);
                          IF reg2(i).por_ori_fondo > 0 AND reg2(i).por_ori_fondo <= 100 THEN
                              v_sal_ori_fondo := round(reg2(i).sal_capital * reg2(i).por_ori_fondo / 100, v_redondeo);
                              reg2(i).sal_capital := reg2(i).sal_capital - v_sal_ori_fondo;
                          END IF;
                      END IF;
                  END IF;

                  IF reg2(i).sal_capital > 0 THEN
                      v_cod_transaccion := pap_pre.fu_obt_tra_concepto('CA', reg2(i).estado, reg2(i).tip_operacion, reg2(i).tip_interes, reg2(i).tip_renovacion);
                      lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), 'C', v_cod_rubro, reg2(i).estado, reg2(i).tip_renovacion, reg2(i).cat_riesgo, reg2(i).tip_interes, reg2(i).tip_operacion, NULL, reg2(i).cod_sec_credito);
                      l_tmp_insert.EXTEND;
                      r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := v_tip_sal_cap; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.cod_rubro := v_cod_rubro; r_tmp.sal_total := reg2(i).sal_capital; r_tmp.tip_renovacion := reg2(i).tip_renovacion; r_tmp.cat_automatica := reg2(i).cat_riesgo; r_tmp.cod_sit_contable := fup_obt_sec_rubro(reg2(i).cod_sec_credito); r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                      l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
                  END IF;

                  IF v_sal_ori_fondo > 0 THEN
                      v_tip_sal_cap := 'F';
                      v_cod_transaccion := fup_obt_transaccion('CA', reg2(i).estado, reg2(i).tip_operacion, reg2(i).tip_interes, reg2(i).nro_cuenta, reg2(i).cod_ori_fondo, NULL);
                      lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), 'C', v_cod_rubro, reg2(i).estado, reg2(i).tip_renovacion, reg2(i).cat_riesgo, reg2(i).tip_interes, reg2(i).tip_operacion, NULL, reg2(i).cod_sec_credito);
                      l_tmp_insert.EXTEND;
                      r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := v_tip_sal_cap; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.cod_rubro := v_cod_rubro; r_tmp.sal_total := v_sal_ori_fondo; r_tmp.tip_renovacion := reg2(i).tip_renovacion; r_tmp.cat_automatica := reg2(i).cat_riesgo; r_tmp.cod_sit_contable := fup_obt_sec_rubro(reg2(i).cod_sec_credito); r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                      l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
                  END IF;
              END IF; -- Fin Saldo Capital

              IF v_tip_sal_sus = 'S' THEN
                  v_cod_transaccion := 947;
                  lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), 'C', v_cod_rubro, reg2(i).estado, reg2(i).tip_renovacion, reg2(i).cat_riesgo, reg2(i).tip_interes, reg2(i).tip_operacion, NULL, reg2(i).cod_sec_credito);
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := v_tip_sal_sus; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.sal_total := nvl(reg2(i).dev_suspenso, 0); r_tmp.cod_rubro := v_cod_rubro; r_tmp.tip_renovacion := reg2(i).tip_renovacion; r_tmp.cat_automatica := reg2(i).cat_riesgo; r_tmp.cod_sit_contable := fup_obt_sec_rubro(reg2(i).cod_sec_credito); r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;

              IF v_tip_sal_int = 'I' THEN
                  IF reg2(i).tip_interes = 'A' THEN v_cod_transaccion := pap_pre.fu_obt_tra_concepto('IA', reg2(i).estado, reg2(i).tip_operacion, reg2(i).tip_interes, reg2(i).tip_renovacion);
                  ELSE v_cod_transaccion := pap_pre.fu_obt_tra_concepto('IN', reg2(i).estado, reg2(i).tip_operacion, reg2(i).tip_interes, reg2(i).tip_renovacion);
                  END IF;
                  lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), 'C', v_cod_rubro, reg2(i).estado, reg2(i).tip_renovacion, reg2(i).cat_riesgo, reg2(i).tip_interes, reg2(i).tip_operacion, NULL, reg2(i).cod_sec_credito);
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := v_tip_sal_int; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.sal_total := reg2(i).sal_interes; r_tmp.cod_rubro := v_cod_rubro; r_tmp.tip_renovacion := reg2(i).tip_renovacion; r_tmp.cat_automatica := reg2(i).cat_riesgo; r_tmp.cod_sit_contable := fup_obt_sec_rubro(reg2(i).cod_sec_credito); r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;

              IF v_tip_sal_ade = 'A' THEN
                  v_tip_movimiento := 'D'; v_cod_transaccion := 903;
                  lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), v_tip_movimiento, v_cod_rubro, reg2(i).estado, reg2(i).tip_renovacion, reg2(i).cat_riesgo, reg2(i).tip_interes, reg2(i).tip_operacion, NULL, reg2(i).cod_sec_credito);
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := v_tip_sal_ade; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.sal_total := nvl(reg2(i).int_devengar, 0); r_tmp.cod_rubro := v_cod_rubro; r_tmp.tip_renovacion := reg2(i).tip_renovacion; r_tmp.cat_automatica := reg2(i).cat_riesgo; r_tmp.cod_sit_contable := fup_obt_sec_rubro(reg2(i).cod_sec_credito); r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;

              IF v_tip_sal_iva = 'Z' THEN
                  v_tip_movimiento := 'C'; v_cod_transaccion := 708;
                  lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), v_tip_movimiento, v_cod_rubro, reg2(i).estado, reg2(i).tip_renovacion, reg2(i).cat_riesgo, reg2(i).tip_interes, reg2(i).tip_operacion);
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := 'Z'; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.sal_total := nvl(v_iva_vencido, 0); r_tmp.cod_rubro := v_cod_rubro; r_tmp.tip_renovacion := reg2(i).tip_renovacion; r_tmp.cat_automatica := reg2(i).cat_riesgo; r_tmp.cod_sit_contable := fup_obt_sec_rubro(reg2(i).cod_sec_credito); r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;

              IF nvl(v_mto_pre_total,0) <> 0 THEN
                  v_tip_sal_prv := 'H'; v_cod_transaccion := 9124;
                  lp_obt_cod_rubro(reg2(i).cod_modulo, reg2(i).cod_modalidad, v_cod_transaccion, reg2(i).cod_moneda, reg2(i).cod_sector, reg2(i).tip_deudor, reg2(i).residente, to_char(reg2(i).cod_plazo), 'C', v_cod_rubro, reg2(i).estado);
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL; r_tmp.cod_modulo := reg2(i).cod_modulo; r_tmp.cod_modalidad := reg2(i).cod_modalidad; r_tmp.cod_oficina := reg2(i).cod_oficina; r_tmp.cod_sec_contable := reg2(i).cod_sector; r_tmp.cod_tip_deudor := reg2(i).tip_deudor; r_tmp.residente := reg2(i).residente; r_tmp.cod_moneda := reg2(i).cod_moneda; r_tmp.situacion := reg2(i).estado; r_tmp.tip_saldo := v_tip_sal_prv; r_tmp.cod_plazo := reg2(i).cod_plazo; r_tmp.tip_operacion := reg2(i).tip_operacion; r_tmp.tip_interes := reg2(i).tip_interes; r_tmp.sal_total := NVL(v_mto_pre_total,0); r_tmp.cod_rubro := v_cod_rubro; r_tmp.nro_cuenta := reg2(i).nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;

          END LOOP;
          -- ESCRITURA MASIVA A LA TABLA cb_sal_inventarios_tmp
          IF l_tmp_insert.COUNT > 0 THEN
              BEGIN
                  FORALL i IN 1 .. l_tmp_insert.COUNT SAVE EXCEPTIONS
                      INSERT INTO cb_sal_inventarios_tmp VALUES l_tmp_insert(i);
              EXCEPTION
                  WHEN OTHERS THEN
                      v_men_error := SQLERRM;
                      raise_application_error(-20000, 'Ins.cb_sal_inventarios_tmp ' || v_men_error);
              END;
          END IF;
          
          COMMIT;
          EXIT WHEN movimien%NOTFOUND;
      END LOOP;
      CLOSE movimien;
      
      --CONSOLIDACIÓN FINAL
      IF c_inventario%ISOPEN THEN CLOSE c_inventario; END IF;
      OPEN c_inventario;
      LOOP
          FETCH c_inventario BULK COLLECT INTO reg3 LIMIT 80000;
          EXIT WHEN reg3.count = 0;
          
          FOR j IN 1 .. reg3.count LOOP
              SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
              INSERT INTO cb_sal_inventarios
                 (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                  residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                  tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                  cat_automatica, cod_sit_contable)
              VALUES
                 (reg3(j).cod_modulo, reg3(j).cod_modalidad, reg3(j).cod_oficina,reg3(j).cod_sec_contable, reg3(j).cod_tip_deudor,
                  reg3(j).residente, reg3(j).cod_moneda, reg3(j).situacion, reg3(j).tip_saldo, reg3(j).cod_plazo, reg3(j).tip_operacion,
                  reg3(j).tip_interes, reg3(j).sal_total, reg3(j).cod_rubro, v_nro_referencia, reg3(j).tip_renovacion,
                  reg3(j).cat_automatica, reg3(j).cod_sit_contable);

              UPDATE cb_sal_inventarios_tmp t
                 SET nro_referencia = v_nro_referencia
               WHERE t.cod_modulo = reg3(j).cod_modulo
                 AND t.cod_modalidad = reg3(j).cod_modalidad
                 AND t.cod_oficina = reg3(j).cod_oficina
                 AND t.cod_sec_contable = reg3(j).cod_sec_contable
                 AND t.cod_tip_deudor = reg3(j).cod_tip_deudor
                 AND t.residente = reg3(j).residente
                 AND t.cod_moneda = reg3(j).cod_moneda
                 AND t.situacion = reg3(j).situacion
                 AND t.tip_saldo = reg3(j).tip_saldo
                 AND t.cod_plazo = reg3(j).cod_plazo
                 AND t.tip_operacion = reg3(j).tip_operacion
                 AND nvl(t.tip_interes,'X') = nvl(reg3(j).tip_interes,'X')
                 AND nvl(t.cod_rubro,'X') = nvl(reg3(j).cod_rubro,'X')
                 AND nvl(t.tip_renovacion,'X') = nvl(reg3(j).tip_renovacion,'X')
                 AND nvl(t.cat_automatica,1) = nvl(reg3(j).cat_automatica,1)
                 AND nvl(t.cod_sit_contable,1) = nvl(reg3(j).cod_sit_contable,1);
          END LOOP;
          COMMIT;
      END LOOP;
      CLOSE c_inventario;
      -- INSERTAR DETALLE
      INSERT /*+ APPEND */ INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
      SELECT a.nro_referencia, a.nro_cuenta, nvl(a.sal_total, 0), 0
      FROM cb_sal_inventarios_tmp a
      WHERE a.nro_referencia IS NOT NULL;

      --MANEJO DE C_SEGUROS
      DECLARE
          v_error_seg VARCHAR2(100);
          v_nro_referencia_seg cb_sal_inventarios.nro_referencia%TYPE;
          v_rowid_seg VARCHAR2(30);
      BEGIN
          FOR reg IN c_seguros LOOP
              BEGIN
                  v_error_seg := 'En asignacion';
                  v_cod_modulo := reg.cod_modulo; 
                  v_cod_modalidad := reg.cod_modalidad; 
                  v_cod_oficina := reg.cod_oficina;
                  v_cod_sector := reg.cod_sec_contable; 
                  v_error_seg := 'En asignacion2'; 
                  v_tip_deudor := reg.cod_tip_deudor;
                  v_residente := reg.residente; 
                  v_cod_moneda := reg.cod_moneda; 
                  v_estado := reg.est_batch;
                  v_error_seg := 'En asignacion3'; 
                  v_tip_sal_car := 'G'; 
                  v_cod_plazo := reg.cod_plazo;
                  v_tip_operacion := reg.tipo; 
                  v_tip_renovacion := reg.tip_renovacion; 
                  v_cat_riesgo := reg.cat_riesgo;
                  v_nro_cuenta := reg.nro_cuenta; 
                  v_error_seg := 'En asignacion4'; 
                  v_cod_transaccion := reg.cod_transaccion;
                  v_cod_sec_credito := reg.cod_sec_credito;
                  v_error_seg := 'Obt. rubro';
                  v_cod_rubro := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda, reg.cod_persona, to_char(v_cod_plazo), 'C', v_estado, v_tip_renovacion, v_cat_riesgo, v_tip_interes, v_tip_operacion, NULL, v_cod_sec_credito);   
                  v_error_seg := 'En referencia';
                  BEGIN
                      SELECT nro_referencia, ROWID INTO v_nro_referencia_seg, v_rowid_seg
                      FROM cb_sal_inventarios
                      WHERE cod_modulo = v_cod_modulo AND cod_modalidad = v_cod_modalidad AND cod_oficina = v_cod_oficina
                        AND cod_sec_contable = v_cod_sector AND cod_tip_deudor = v_tip_deudor AND residente = v_residente
                        AND cod_moneda = v_cod_moneda AND situacion = v_estado AND tip_saldo IN (v_tip_sal_car)
                        AND cod_plazo IN (v_cod_plazo, 0) AND tip_operacion IN (v_tip_operacion, 'X')
                        AND tip_interes IN (v_tip_interes, 'X') AND tip_renovacion = v_tip_renovacion
                        AND cat_automatica = v_cat_riesgo AND cod_rubro = v_cod_rubro
                        AND cod_sit_contable = fup_obt_sec_rubro(v_cod_sec_credito);
                        
                      UPDATE cb_sal_inventarios SET sal_total = nvl(sal_total, 0) + nvl(reg.monto, 0) WHERE ROWID = v_rowid_seg;
                      
                      v_error_seg := 'Upd. sal inv.';
                      UPDATE cb_sal_inventarios_det SET sal_actual = nvl(sal_actual, 0) + nvl(reg.monto, 0)
                      WHERE nro_referencia = v_nro_referencia_seg AND nro_cuenta = v_nro_cuenta;
                      
                      IF SQL%NOTFOUND THEN
                          v_error_seg := 'Ins. sal inv.';
                          INSERT INTO cb_sal_inventarios_det (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                          VALUES (v_nro_referencia_seg, v_nro_cuenta, nvl(reg.monto, 0), 0);
                      END IF;
                  EXCEPTION
                      WHEN no_data_found THEN
                          v_error_seg := 'Ins. sal inv.2.';
                          SELECT s_nro_referencia.nextval INTO v_nro_referencia_seg FROM dual;
                          INSERT INTO cb_sal_inventarios
                             (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                              residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                              tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                              cat_automatica, cod_sit_contable)
                          VALUES
                             (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                              v_residente, v_cod_moneda, v_estado, v_tip_sal_car, v_cod_plazo,
                              v_tip_operacion, v_tip_interes, nvl(reg.monto, 0), v_cod_rubro,
                              v_nro_referencia_seg, v_tip_renovacion, v_cat_riesgo,
                              fup_obt_sec_rubro(v_cod_sec_credito));
                              
                          INSERT INTO cb_sal_inventarios_det
                             (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                          VALUES
                             (v_nro_referencia_seg, v_nro_cuenta, nvl(reg.monto, 0), 0);
                  END;
              END;
          END LOOP;
      EXCEPTION
          WHEN OTHERS THEN
              raise_application_error(-20000, 'ERROR CARGOS: ' || v_error_seg || ' ' || SQLERRM);
      END;
      COMMIT;
  EXCEPTION
      WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR EN LP_ACU_PRESTAMOS:' || SQLERRM);
  END;

   -- fin de prestamoss---
   --------------------------------------------------------------------------------------------------------------------
  PROCEDURE lp_acu_tarjetas IS
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_cod_plazo        NUMBER(02);
      v_sal_tot_batch    cb_sal_inventarios.sal_total%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_tip_sal_prv      cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_transaccion2 ge_transacciones.cod_transaccion%TYPE;
      v_prevision        cb_sal_inventarios.sal_total%TYPE;
      v_prv_contingencia cb_sal_inventarios.sal_total%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_fecha            DATE;
      v_estado           ge_cuentas.estado%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_men_error        VARCHAR2(512);

      CURSOR movimien IS
          SELECT
             a.cod_modulo,
             a.cod_modalidad,
             a.cod_oficina,
             c.cod_sec_contable,
             c.cod_tip_deudor,
             c.residente,
             a.cod_moneda,
             1 AS cod_plazo,
             nvl(a.sal_facturar,0) + nvl(a.sal_facturado,0)+ nvl(a.sal_financiado,0) + nvl(a.sal_cuo_pendientes,0) AS sal_tot_batch,
             a.nro_cuenta,
             a.fec_apertura AS fecha,
             nvl(ta_previsiones.monto, 0) AS prevision,
             abs(nvl(ta_previsiones.tot_prv_contingencia, 0)) AS prv_contingencia,
             decode(a.cat_automatica, '1', 'C', '2', 'V', '3', 'G', '4', 'G', 'M') AS estado,
             nvl(c.cat_riesgo, 1) AS cat_riesgo
          FROM ge_clientes c,
               ge_cta_clientes b,
               ta_cta_tarjetas a,
               (SELECT (nvl(monto, 0)) monto,
                       a.tot_prv_contingencia,
                       nro_cuenta
                  FROM ta_previsiones a
                 WHERE a.fecha =
                       (SELECT MAX(b.fecha) FROM ta_previsiones b WHERE a.nro_cuenta = b.nro_cuenta)) ta_previsiones
          WHERE c.cod_persona = b.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND ta_previsiones.nro_cuenta(+) = a.nro_cuenta
            AND b.relacion = 'P'
            AND a.estado <> 'C'
            AND not exists (SELECT 1
                              FROM ov_cta_vencidas v
                             WHERE v.nro_cta_origen = a.nro_cuenta
                               AND v.estado <> 'C')
            AND LENGTH(c.cod_persona) > 0
            AND LENGTH(c.residente) > 0
            AND LENGTH(a.nro_cuenta) > 0;
            
      TYPE t_movimientos_coll IS TABLE OF movimien%ROWTYPE;
      l_movimientos t_movimientos_coll;
      v_limit CONSTANT PLS_INTEGER := 100000;
      -- COLECCIÓN PARA INSERTAR EN TABLA TEMPORAL
      r_tmp cb_sal_inventarios_tmp%ROWTYPE;
      TYPE t_tmp_insert_coll IS TABLE OF cb_sal_inventarios_tmp%ROWTYPE;
      l_tmp_insert t_tmp_insert_coll := t_tmp_insert_coll();
      
      CURSOR c_inventario IS
          select sum(sal_total) sal_total,
                 t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                 t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                 t.tip_interes, t.cod_rubro
          from cb_sal_inventarios_tmp t
          group by
                 t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                 t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                 t.tip_interes, t.cod_rubro;
                 
      TYPE cursor3_type IS TABLE OF c_inventario%ROWTYPE;
      reg3 cursor3_type;

  BEGIN
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_inventarios_tmp', v_msj);
      IF v_msj IS NOT NULL THEN
          raise_application_error(-20000, v_msj);
      END IF;

      IF movimien%ISOPEN THEN
          CLOSE movimien;
      END IF;

      OPEN movimien;
      LOOP
          FETCH movimien BULK COLLECT INTO l_movimientos LIMIT v_limit;
          EXIT WHEN l_movimientos.COUNT = 0;
          
          l_tmp_insert.DELETE;

          FOR i IN 1 .. l_movimientos.COUNT LOOP
              v_cod_modulo       := l_movimientos(i).cod_modulo;
              v_cod_modalidad    := l_movimientos(i).cod_modalidad;
              v_cod_oficina      := l_movimientos(i).cod_oficina;
              v_cod_sec_contable := l_movimientos(i).cod_sec_contable;
              v_cod_tip_deudor   := l_movimientos(i).cod_tip_deudor;
              v_residente        := l_movimientos(i).residente;
              v_cod_moneda       := l_movimientos(i).cod_moneda;
              v_cod_plazo        := l_movimientos(i).cod_plazo;
              v_sal_tot_batch    := l_movimientos(i).sal_tot_batch;
              v_nro_cuenta       := l_movimientos(i).nro_cuenta;
              v_fecha            := l_movimientos(i).fecha;
              v_prevision        := l_movimientos(i).prevision;
              v_prv_contingencia := l_movimientos(i).prv_contingencia;
              v_estado           := l_movimientos(i).estado;
              
              -- Saldo Capital
              v_tip_saldo := 'C';
              v_tip_movimiento := 'D';
              if nvl(v_sal_tot_batch,0) < 0
                 and NVL(Instr(Fug_Obt_Pardinamico('TAR_PRE_PAGAS'), ','||v_cod_modalidad||','),0) = 0 then
                  v_cod_transaccion := 5924;
                  v_tip_movimiento  := 'C';
                  v_sal_tot_batch := (v_sal_tot_batch)*(-1);
              else
                  IF (v_estado = 'V') THEN v_cod_transaccion := 923; END IF;
                  IF (v_estado = 'G') THEN v_cod_transaccion := 921; END IF;
                  IF (v_estado = 'M') THEN v_cod_transaccion := 922; END IF;
                  IF (v_estado = 'C') then
                     if v_cod_modalidad = 55 THEN v_cod_transaccion := 1507;
                     else v_cod_transaccion := 1506;
                     end if;
                  END IF;
              end if;

              v_tip_interes := 'X';
              v_tip_operacion := 'X';
              
             lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                              v_cod_sec_contable, v_cod_tip_deudor, v_residente,
                              to_char(v_cod_plazo), v_tip_movimiento/*'D'*/, v_cod_rubro, v_estado);
                                                 
              l_tmp_insert.EXTEND;
              r_tmp := NULL;
              r_tmp.cod_modulo := v_cod_modulo; 
              r_tmp.cod_modalidad := v_cod_modalidad; 
              r_tmp.cod_oficina := v_cod_oficina;
              r_tmp.cod_sec_contable := v_cod_sec_contable; 
              r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
              r_tmp.residente := v_residente;
              r_tmp.cod_moneda := v_cod_moneda; 
              r_tmp.situacion := v_estado; 
              r_tmp.tip_saldo := v_tip_saldo;
              r_tmp.cod_plazo := v_cod_plazo; 
              r_tmp.tip_operacion := v_tip_operacion; 
              r_tmp.tip_interes := v_tip_interes;
              r_tmp.sal_total := v_sal_tot_batch; 
              r_tmp.cod_rubro := v_cod_rubro;
              r_tmp.nro_cuenta := v_nro_cuenta;
              l_tmp_insert(l_tmp_insert.LAST) := r_tmp;

              -- Previsión
              IF v_prevision <> 0 THEN
                  v_tip_sal_prv   := 'V';
                  v_cod_transaccion := 730;
                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   'C', v_cod_rubro, v_estado);
                                   
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL;
                  r_tmp.cod_modulo := v_cod_modulo; 
                  r_tmp.cod_modalidad := v_cod_modalidad; 
                  r_tmp.cod_oficina := v_cod_oficina;
                  r_tmp.cod_sec_contable := v_cod_sec_contable; 
                  r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                  r_tmp.residente := v_residente;
                  r_tmp.cod_moneda := v_cod_moneda; 
                  r_tmp.situacion := v_estado; 
                  r_tmp.tip_saldo := v_tip_sal_prv;
                  r_tmp.cod_plazo := v_cod_plazo; 
                  r_tmp.tip_operacion := v_tip_operacion; 
                  r_tmp.tip_interes := v_tip_interes;
                  r_tmp.sal_total := nvl(v_prevision, 0); 
                  r_tmp.cod_rubro := v_cod_rubro;
                  r_tmp.nro_cuenta := v_nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;         
              -- Contingencia
              IF v_prv_contingencia <> 0 THEN
                  v_tip_sal_prv   := 'T';
                  v_cod_transaccion2 := 7730;
                  --- busco la cuenta que le corresponde al saldo ----
                    lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion2, v_cod_moneda,
                                     v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                                     'C', v_cod_rubro, v_estado);
                                   
                  l_tmp_insert.EXTEND;
                  r_tmp := NULL;
                  r_tmp.cod_modulo := v_cod_modulo; 
                  r_tmp.cod_modalidad := v_cod_modalidad; 
                  r_tmp.cod_oficina := v_cod_oficina;
                  r_tmp.cod_sec_contable := v_cod_sec_contable; 
                  r_tmp.cod_tip_deudor := v_cod_tip_deudor; 
                  r_tmp.residente := v_residente;
                  r_tmp.cod_moneda := v_cod_moneda; 
                  r_tmp.situacion := v_estado; 
                  r_tmp.tip_saldo := v_tip_sal_prv;
                  r_tmp.cod_plazo := v_cod_plazo; 
                  r_tmp.tip_operacion := v_tip_operacion; 
                  r_tmp.tip_interes := v_tip_interes;
                  r_tmp.sal_total := nvl(v_prv_contingencia, 0); 
                  r_tmp.cod_rubro := v_cod_rubro;
                  r_tmp.nro_cuenta := v_nro_cuenta;
                  l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
              END IF;

          END LOOP;
          IF l_tmp_insert.COUNT > 0 THEN
              BEGIN
                  FORALL i IN 1 .. l_tmp_insert.COUNT SAVE EXCEPTIONS
                      INSERT INTO cb_sal_inventarios_tmp VALUES l_tmp_insert(i);
              EXCEPTION
                  WHEN OTHERS THEN
                      v_men_error := SQLERRM;
                      raise_application_error(-20000, 'Ins.cb_sal_inventarios_tmp ' || v_men_error);
              END;
          END IF;
          
          COMMIT;
          
      END LOOP;
      CLOSE movimien;
      IF c_inventario%ISOPEN THEN CLOSE c_inventario; END IF;
      OPEN c_inventario;
      LOOP
          FETCH c_inventario BULK COLLECT INTO reg3 LIMIT 100000;
          EXIT WHEN reg3.count = 0;
          
          FOR j IN 1 .. reg3.count LOOP
              SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
              INSERT INTO cb_sal_inventarios
                 (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                  residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                  tip_interes, sal_total, cod_rubro, nro_referencia)
              VALUES
                 (reg3(j).cod_modulo, reg3(j).cod_modalidad, reg3(j).cod_oficina,reg3(j).cod_sec_contable, reg3(j).cod_tip_deudor,
                  reg3(j).residente, reg3(j).cod_moneda, reg3(j).situacion, reg3(j).tip_saldo, reg3(j).cod_plazo, reg3(j).tip_operacion,
                  reg3(j).tip_interes, reg3(j).sal_total, reg3(j).cod_rubro, v_nro_referencia);

              UPDATE cb_sal_inventarios_tmp t
                 SET nro_referencia = v_nro_referencia
               WHERE t.cod_modulo = reg3(j).cod_modulo --
                 AND t.cod_modalidad = reg3(j).cod_modalidad --
                 AND t.cod_oficina = reg3(j).cod_oficina --
                 AND t.cod_sec_contable = reg3(j).cod_sec_contable --
                 AND t.cod_tip_deudor = reg3(j).cod_tip_deudor --
                 AND t.residente = reg3(j).residente --
                 AND t.cod_moneda = reg3(j).cod_moneda--
                 AND t.situacion = reg3(j).situacion --
                 AND t.tip_saldo = reg3(j).tip_saldo --
                 AND t.cod_plazo = reg3(j).cod_plazo --
                 AND t.tip_operacion = reg3(j).tip_operacion --
                 AND nvl(t.tip_interes,'X') = nvl(reg3(j).tip_interes,'X') --
                 AND nvl(t.cod_rubro,'X') = nvl(reg3(j).cod_rubro,'X');
          END LOOP;
          COMMIT;
      END LOOP;
      CLOSE c_inventario;

     INSERT /*+ APPEND */ INTO cb_sal_inventarios_det
          (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
      SELECT a.nro_referencia, a.nro_cuenta, nvl(a.sal_total, 0), 0
      FROM cb_sal_inventarios_tmp a
      WHERE a.nro_referencia IS NOT NULL;

      COMMIT;

  EXCEPTION
      WHEN OTHERS THEN
          raise_application_error(-20000, 'ERROR LP_ACU_TARJETAS:' || SQLERRM );
  END lp_acu_tarjetas;

   -- fin de tarjetas

   --------------------------------------------------------------------------------------------------------------------
   -- comex
   PROCEDURE lp_acu_com_exterior IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIEN
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE := 8;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_situacion        cb_sal_inventarios.situacion%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_cod_plazo        NUMBER(02) := 1;
      v_sal_tot_batch    NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_dev_no_cobrado   NUMBER(16, 2);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_persona      VARCHAR2(20);
      v_rowid            VARCHAR2(30);
      v_fecha            DATE;
      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
      --cci utilizadas con saldo
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U') rubro,
                --nvl(x.sal_utilizado, 0) importe,
                case
                  when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)>=nvl(a.mto_prepago,0) then
                    nvl(x.mto_utilizado,0)-nvl(a.mto_prepago,0)
                  when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<nvl(a.mto_prepago,0) then
                    0
                  else
                    nvl(x.sal_utilizado, 0)
                end importe, -- CNFCCYAI-1 -- CN: 08/2015
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'U' situacion
           FROM ge_clientes c,
                cx_cta_importaciones a,
                ge_cta_clientes b,
                ( SELECT nro_cuenta cuenta, /*fec_vencimiento,*/ -- DYDMR-2455 -- CN:09/2015 - No se utiliza y ocasiona duplicacion de registros
                         SUM(saldo) sal_utilizado,
                         SUM(mto_utilizado) mto_utilizado  -- CNFCCYAI-1 -- CN: 08/2015
                    FROM cx_embarques
                   GROUP BY nro_cuenta /*, fec_vencimiento*/ ) x
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND x.cuenta(+) = a.nro_cuenta
            AND b.cod_persona = c.cod_persona
            AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
            AND fux_obt_sal_mto_utilizado(a.nro_cuenta) > 0 --s?lo si tiene saldo utilizado pendiente de cobro
            and ( case
                    when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)>=nvl(a.mto_prepago,0) then
                      nvl(x.mto_utilizado,0)-nvl(a.mto_prepago,0)
                    when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<nvl(a.mto_prepago,0) then
                      0
                    else
                      nvl(x.sal_utilizado, 0)
                  end ) > 0  -- CNFCCYAI-1 -- CN: 08/2015
         UNION ALL
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A') rubro,
                --(saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) importe,
                case
                  when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<=nvl(a.mto_prepago,0) then
                    nvl(a.monto,0)-nvl(a.mto_prepago,0)
                  else
                    (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))
                end importe, -- CNFCCYAI-1 - CN: 08/2015
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A' situacion
           FROM ge_clientes c, cx_cta_importaciones a, ge_cta_clientes b,
                ( SELECT nro_cuenta cuenta, /*fec_vencimiento,*/ -- DYDMR-2455 -- CN:09/2015 - No se utiliza y ocasiona duplicacion de registros
                         SUM(saldo) sal_utilizado,
                         SUM(mto_utilizado) mto_utilizado  -- CNFCCYAI-1 -- CN: 08/2015
                    FROM cx_embarques
                   GROUP BY nro_cuenta /*, fec_vencimiento*/ ) x
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND x.cuenta(+) = a.nro_cuenta
            AND b.cod_persona = c.cod_persona
            AND a.estado NOT IN ('C', 'S') -- cancelada y solicitada
            AND (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --s?lo si tiene saldo no utilizado
            and ( case
                    when nvl(a.mto_prepago,0)>0 and nvl(x.mto_utilizado,0)<=nvl(a.mto_prepago,0) then
                      nvl(a.monto,0)-nvl(a.mto_prepago,0)
                    else
                      (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta))
                  end ) > 0  -- CNFCCYAI-1 -- CN: 08/2015
         UNION ALL
         --cce s?lo confirmadas
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A') rubro,
                (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A' situacion
           FROM ge_clientes c, cx_cta_exportaciones a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND (saldo - fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --s?lo si tiene saldo no utilizado
               --and confirmado = 'S'
            AND b.cod_persona = c.cod_persona
         UNION ALL
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'U') rubro,
                nvl(x.sal_utilizado, 0) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'U'
           FROM ge_clientes c,
                cx_cta_exportaciones a,
                ge_cta_clientes b,
                (SELECT nro_cuenta cuenta, fec_vencimiento, SUM(saldo) sal_utilizado
                   FROM cx_embarques
                  GROUP BY nro_cuenta, fec_vencimiento) x
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND x.cuenta = a.nro_cuenta
               --and a.confirmado = 'S'
            AND b.cod_persona = c.cod_persona
            AND (fux_obt_sal_mto_utilizado(a.nro_cuenta)) > 0 --s?lo si tiene saldo no utilizado
         UNION ALL
         --cobranzas de importaci?n avaladas
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A') rubro,
                nvl(saldo, 0) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A'
           FROM ge_clientes c, cx_cta_cobranzas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modalidad IN (83, 84)
               --and a.avalada = 'S'
            AND a.estado = 'A'
            AND b.cod_persona = c.cod_persona
            AND saldo > 0 --s?lo si tiene saldo
         UNION ALL
         --fianzas emitidas
         SELECT a.nro_cuenta nro_cuenta,
                a.cod_modalidad,
                a.cod_oficina sucursal,
                b.cod_persona cliente,
                fub_obt_rub_contable(a.cod_modulo, a.nro_cuenta, 'A') rubro,
                nvl(monto, 0) importe,
                a.cod_moneda,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                'A'
           FROM ge_clientes c, cx_fianzas a, ge_cta_clientes b
          WHERE a.nro_cuenta = b.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modalidad = 88
            AND a.estado = 'A'
            AND b.cod_persona = c.cod_persona;

      /*CURSOR MOVIMIEN IS
      SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, NVL(a.cta_combinada,'N'),
             c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda, 1,
             NVL(a.sal_tot_batch,0)\*-NVL(a.sal_ret_batch,0)*\, a.nro_cuenta,
             NVL(a.fec_ult_capitalizacion,a.fec_apertura) fec_ult_capitalizacion
        FROM ge_clientes c, ge_cta_clientes b, ah_cta_vistas a
       WHERE c.cod_persona = b.cod_persona
         AND b.nro_cuenta = a.nro_cuenta
         AND b.relacion = 'P'
         AND a.est_batch <> 'C';*/
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_nro_cuenta,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_persona,
                 v_cod_rubro,
                 v_sal_tot_batch,
                 v_cod_moneda,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_situacion;
         EXIT WHEN movimien%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'S'; -- Saldo
         --------------------------------------------------------------
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_operacion := 'X';
         --------------------------------------------------------------
         -- ACTUALIZA SALDO DE CAPITAL --
         --------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_tot_batch
             WHERE ROWID = v_rowid;
            --------------Genero detalle----------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_tot_batch
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               /* no hace falta porque ya trae en el cursor el rubro contable
               --- busco la cuenta que le corresponde al saldo ----
               LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
                                v_cod_moneda,v_cod_sec_contable,v_cod_tip_deudor,
                                v_residente,TO_CHAR(v_cod_plazo),
                                'C',v_cod_rubro);
               */
               ------------------------------
               -- INSERTA SALDO DE CAPITAL --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_sal_tot_batch, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
         END;
         -------------------------------------------------------
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR LP_ACU_COM_EXTERIOR :' || SQLERRM);
   END;
   -- fin de comex
   --------------------------------------------------------------------------------------------------------------------

   -- Acumula Mesa de Dinero
   PROCEDURE lp_acu_mes_dinero IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIEN
      ------------------------------------------------------------------------
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_oficina     cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_cod_sector      cb_sal_inventarios.cod_sec_contable%TYPE;
      v_tip_deudor      cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente       cb_sal_inventarios.residente%TYPE;
      v_cod_moneda      cb_sal_inventarios.cod_moneda%TYPE;
      v_estado          md_cta_documentos.estado%TYPE;
      v_tip_operacion   cb_sal_inventarios.tip_operacion%TYPE;

      v_cod_plazo                  ge_plz_contables.cod_plazo%TYPE;
      v_cod_plazo_repo             ge_plz_contables.cod_plazo%TYPE;
      v_sal_capital                md_cta_documentos.sal_capital%TYPE;
      v_sal_interes                md_cta_documentos.sal_interes%TYPE;
      v_sal_no_doc                 md_cta_documentos.dev_acumulado%TYPE;
      v_int_devengar               md_cta_documentos.val_int_devengar%TYPE;
      v_tip_sal_cap                VARCHAR2(01);
      v_tip_sal_int                VARCHAR2(01);
      v_tip_sal_dev                VARCHAR2(01);
      v_tip_sal_ade                VARCHAR2(01);
      v_tip_sal_int_no_documentado VARCHAR2(01);
      v_tip_sal_doc_rep_otorgado   VARCHAR2(01);
      v_tip_interes                cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro                  cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rub_no_doc_c           cb_sal_inventarios.cod_rubro%TYPE; --corresponde a los rubros de tipo credito para los intereses no documentados
      v_cod_rub_no_doc_d           cb_sal_inventarios.cod_rubro%TYPE; --corresponde a los rubros de tipo debito para los intereses no documentados
      v_cat_riesgo                 cb_sal_inventarios.cat_automatica%TYPE;
      v_tip_renovacion             cb_sal_inventarios.tip_renovacion%TYPE;
      v_tip_movimiento             VARCHAR2(01);
      v_nro_referencia             cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_sit_contable           md_cta_documentos.cod_sit_contable%TYPE;
      v_rowid                      VARCHAR2(30);
      v_fec_ven_repo               md_cta_documentos.fec_ven_repo%TYPE;
      v_cod_persona                ba_personas.cod_persona%TYPE;

      v_val_presente   md_cta_documentos.val_presente%TYPE;
      v_monto          md_cta_documentos.monto%TYPE;
      v_tip_calculo    md_cta_documentos.tip_calculo%TYPE;
      v_mer_secundario md_cta_documentos.mer_secundario%TYPE;
      v_int_devengado  md_cta_documentos.val_int_devengar%TYPE;
      v_capital        md_cta_documentos.val_presente%TYPE;
      v_dev_acumulado  md_cta_documentos.dev_acumulado%TYPE;
      v_sal_total      cb_sal_inventarios.sal_total%TYPE;
      v_sal_negativo   NUMBER;
      v_mto_devengar   md_cta_documentos.val_int_devengar%TYPE;
      v_sal_disponible md_cta_documentos.sal_disponible%Type;
      v_cuota          md_cuo_instrumentos.nro_cuota%Type;
      v_dias           NUMBER;

      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
        SELECT
            a.cod_modulo,
            a.cod_modalidad,
            a.cod_oficina,
            a.nro_cuenta,
            c.cod_sec_contable,
            c.cod_tip_deudor,
            c.residente,
            a.cod_moneda,
            o.estado,
            cod_plazo,
            a.val_int_devengar,
            a.dev_acumulado,
            a.val_presente,
            o.mto_cuota monto,
            a.sal_capital,
            nvl(a.sal_interes, 0) sal_interes,
            o.nro_cuota,
            a.fec_ven_repo,
            b.cod_persona,
            a.tip_calculo,
            a.mer_secundario,
            (SELECT cod_plazo
               FROM ge_plz_contables
              WHERE can_dias >= nvl(a.fec_ven_repo - a.fec_ini_repo, NULL)
                AND rownum = 1) v_cod_plazo_repo,
            (nvl(a.mto_interes, 0) - nvl(a.dev_acumulado, 0)) sal_no_doc, --Saldo no documentado
            NVL(a.sal_disponible,0) sal_disponible
       FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, md_cta_documentos a, md_cuo_instrumentos o
      WHERE b.nro_cuenta = a.nro_cuenta
        AND a.nro_cuenta = o.nro_cuenta
        AND b.relacion = 'P'
        AND c.cod_persona = b.cod_persona
        AND o.estado NOT IN ('N', 'S')  -- REPO-CNF-RBARRIOS
        AND can_dias = (SELECT MIN(can_dias)
                          FROM ge_plz_contables
                         WHERE can_dias >= a.fec_vencimiento - a.fec_inicio);

---------------------------------------------------------------------------------------------------------------
    ---Procedimiento Interno para calcular los distintos montos que representa cada cuota del documento
    ---El porcentaje recuperado deber? utilizarse para calcular los distintos montos a inventariar

    procedure lp_obt_mto_inventario(p_nro_cuenta         in md_cuo_instrumentos.nro_cuenta%type,
                                    p_est_cuota          in md_cuo_instrumentos.estado%type,
                                    p_nro_cuota          in md_cuo_instrumentos.nro_cuota%type,
                                    p_sal_disponible     in md_cta_documentos.sal_disponible%type,
                                    p_monto              in out md_cta_documentos.monto%type,
                                    p_val_int_devengar   in out md_cta_documentos.val_int_devengar%type,
                                    p_sal_interes        in out md_cta_documentos.sal_interes%type,
                                    p_val_presente       in out md_cta_documentos.val_presente%type,
                                    p_sal_no_doc         in out md_cta_documentos.mto_interes%type,
                                    p_dev_acumulado      in out md_cta_documentos.dev_acumulado%type,
                                    p_sal_capital        in out md_cta_documentos.sal_capital%type)
                                    is

    v_porcentaje     number;
    v_redondeo       number;
    v_mto_documento  md_cta_documentos.monto%type;
    v_mto_cuota      md_cuo_instrumentos.mto_cuota%type;
    v_cod_modulo     md_cta_documentos.cod_modulo%type;
    v_cod_modalidad   md_cta_documentos.cod_modalidad%type;
    v_cod_moneda     md_cta_documentos.cod_moneda%type;
    v_cod_oficina     md_cta_documentos.cod_oficina%type;

    begin

      select d.monto,d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.cod_oficina, sum(c.mto_cuota)
        into v_mto_documento, v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_mto_cuota
        from md_cta_documentos d, md_cuo_instrumentos c
       where d.nro_cuenta = c.nro_cuenta
         and d.nro_cuenta = p_nro_cuenta
         and c.estado = p_est_cuota
       group by d.monto,d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.cod_oficina;


       If FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'N' And p_est_cuota = 'C' And p_nro_cuota = 1 Then
            v_mto_cuota := p_sal_disponible;
       End If;

       v_porcentaje := (v_mto_cuota * 100 / v_mto_documento);

       v_redondeo   := fug_obt_pardinamico( 'VAL_RED_MON_EXTRANJERA',
                                             v_cod_modulo,
                                             v_cod_modalidad,
                                             v_cod_moneda,
                                             v_cod_oficina );

      If v_porcentaje is not null then
        v_porcentaje := v_porcentaje / 100;

        p_monto               :=   round((p_monto * v_porcentaje),v_redondeo);
        p_val_int_devengar    :=   round(p_val_int_devengar * v_porcentaje,v_redondeo);
        p_sal_interes         :=   round(p_sal_interes * v_porcentaje,v_redondeo);
        p_val_presente        :=   round(p_val_presente * v_porcentaje,v_redondeo);
        p_sal_no_doc          :=   round(p_sal_no_doc * v_porcentaje,v_redondeo);
        p_dev_acumulado       :=   round(p_dev_acumulado * v_porcentaje,v_redondeo);
        p_sal_capital         :=   round(p_sal_capital * v_porcentaje,v_redondeo);

      End if;

    exception
      when no_data_found then
        null;
    end;


   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sector,
                 v_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_estado,
                 v_cod_plazo,
                 v_int_devengar,
                 v_dev_acumulado,
                 v_val_presente,
                 v_monto,
                 v_sal_capital,
                 v_sal_interes,
                 v_cuota,
                 v_fec_ven_repo,
                 v_cod_persona,
                 v_tip_calculo,
                 v_mer_secundario,
                 v_cod_plazo_repo,
                 v_sal_no_doc,
                 v_sal_disponible;
         EXIT WHEN movimien%NOTFOUND;

         ---------------------------------------------------------------------------

        ---Se invoca al proceso que realice el calculo de los montos por porcentaje
        lp_obt_mto_inventario(v_nro_cuenta,
                              v_estado,
                              v_cuota,
                              v_sal_disponible,
                              v_monto,
                              v_int_devengar,
                              v_sal_interes,
                              v_val_presente,
                              v_sal_no_doc,
                              v_dev_acumulado,
                              v_sal_capital);
         --------------------------------------------------------------------------

         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_sal_cap                := NULL;
         v_tip_sal_int                := NULL;
         v_tip_sal_ade                := NULL;
         v_tip_sal_dev                := NULL;
         v_tip_sal_int_no_documentado := NULL;
         v_tip_sal_doc_rep_otorgado   := NULL;

         --saldo de capital
         IF nvl(v_val_presente, 0) > 0 OR nvl(v_monto, 0) > 0 OR nvl(v_sal_capital, 0) > 0 THEN
            v_tip_sal_cap := 'C';
         END IF;

         --saldo interes documentado
         IF v_cod_modalidad IN (117,150,155,109, 118, 126, 145, 110, 116,146) OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' THEN  -- CNFREINT-1 -- Repo Recibido --
            v_tip_sal_int := NULL; --no se contabiliza el interes total, solo el devengado
         ELSIF nvl(v_sal_interes, 0) > 0 AND  v_cod_modalidad not in (117,150,155,118) THEN
            v_tip_sal_int := 'I';
         END IF;

         --saldo a devengar
         IF v_cod_modalidad IN (117,150,155, 109, 118, 126, 145) THEN
            v_tip_sal_ade := NULL;
         ELSIF (nvl(v_int_devengar, 0) <> 0 AND v_cod_modalidad not in (117,150,155,118)) OR (v_cod_modalidad IN (110,112,116,146) AND v_dev_acumulado <> 0) THEN
            v_tip_sal_ade := 'A';
         END IF;

         --saldo devengado
         IF v_cod_modalidad IN (117,150,155, 109, 118, 126, 144, 145, 134) THEN --DYDMR-15258 DR
            --OBS: en prestamos AFD y prestamos recibidos se contabiliza el devengado, no el interes a devengar
            IF nvl(v_sal_interes - v_int_devengar, 0) <> 0 THEN
               v_tip_sal_dev := 'D';
               IF v_estado = 'R' THEN
                  v_int_devengado := v_dev_acumulado;
               ELSE
                  v_int_devengado := v_sal_interes - v_int_devengar;
               END IF;
            END IF;
         END IF;

         --Intereses no documentados
         IF v_cod_modalidad IN (117,150,155) THEN
            v_tip_sal_int_no_documentado := 'N';
         END IF;

         --Alta Documentos en Repo Otorgado
         IF FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' THEN
            v_tip_sal_doc_rep_otorgado := 'O';
         END IF;

         ----------------------------------------------------------------------

         IF v_tip_sal_cap = 'C' THEN
            --------------------------------
            -- ACTUALIZA SALDO DE CAPITAL --
            --------------------------------

            IF v_cod_modalidad IN (100, 101, 102, 104, 105, 106, 122) THEN
               --cartas de compromiso,bonos privados,bonos del tesoro,bonos afd
               v_capital := v_val_presente;
            ELSIF v_cod_modalidad IN (123,114, 129, 132) THEN
               --bonos del tesoro, letras de regulacion,cartas de compromiso MP
               v_capital := v_monto;
            ELSIF v_cod_modalidad IN (109, 112, 115, 117,150,155, 118, 126, 145, 134) OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S') = 'S' THEN -- CNFREINT-1 -- Repo Interbancario--
               --prestamos recibidos, pretamos afd
               v_capital := v_sal_capital;
            ELSE
               IF ((v_tip_calculo = 'A' AND v_mer_secundario = 'S') OR v_tip_calculo = 'V') THEN
                  v_capital := v_val_presente;
               ELSIF (v_tip_calculo = 'A' AND v_mer_secundario = 'N') THEN
                  v_capital := v_monto;
               ELSE
                  v_capital := 0; --confirmar!!!
               END IF;
            END IF;

            IF v_estado = 'E' THEN
               --REPO
               v_capital := v_monto;
            END IF;

            -- Asignamos el sit contable de acuerdo a la modalida y estado -- REPO-CNF-RBARRIOS-CNFREINT-104
            If FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' Then
              v_cod_sit_contable := '10000001';
            Elsif FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
              v_cod_sit_contable := '10000002';
            Elsif v_estado = 'R' Then
              v_cod_sit_contable := '10000001';
            Else
              v_cod_sit_contable := '10000000';
            END IF;

            --faltan
            --colocaciones en el exterior
            --

            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo = v_tip_sal_cap
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_operacion
                  AND tip_interes = v_tip_interes
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_capital
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_capital
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_capital, 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  IF (v_cod_modalidad IN (100, 101, 102, 105, 125, 129, 132, 123,114, 104, 124, 122) --bonos tesoro, municipalidad, cc, lrm,bonos privados
                     AND (v_estado = 'R' OR (v_estado = 'C' AND v_fec_ven_repo IS NULL))) THEN
                     v_tip_movimiento := 'D';
                     IF (v_cod_sit_contable = '10000001') THEN
                        v_cod_transaccion := 805;
                     ELSE
                       v_cod_transaccion := 711;
                     END IF;
                  ELSIF v_estado = 'E' THEN
                     v_tip_movimiento  := 'C';
                     v_cod_transaccion := 811;
                  ELSIF (v_cod_modalidad IN (117,150,155,145)) THEN
                     --prestamos afd
                     v_tip_movimiento  := 'C';
                     v_cod_transaccion := 801;
                  -- CNFREINT-1 -- Repo Otorgado --
                  ELSIF (v_cod_modalidad IN (109, 118, 112, 126, 144, 106, 110, 116, 146, 134) OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S') THEN --C.B. 07/09/2012
                     --prestamos recibidos,colocaciones, bonos afd
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 711;
                  ELSE
                     v_capital := 0;
                  END IF;

                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sector, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   v_tip_movimiento, v_cod_rubro, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  ------------------------------
                  -- INSERTA SALDO DE CAPITAL --
                  ------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_cap, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, v_capital, v_cod_rubro, v_nro_referencia,
                      v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_capital, 0);

            END;
         END IF;
         -------------------------------------------------------------------------
         v_cod_transaccion:= null; --DYDMR-15258 DR

         IF v_tip_sal_int = 'I' THEN
            ---------------------------------------------
            -- ACTUALIZA SALDO DE INTERES DOCUMENTADO  --
            ---------------------------------------------
          /*  IF v_estado = 'R' THEN
               v_sal_interes := 0;
            END IF;*/

            -- Asignamos el sit contable de acuerdo a la modalida y estado -- REPO-CNF-RBARRIOS
            If FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' Then
              v_cod_sit_contable := '10000001';
            Elsif FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
              v_cod_sit_contable := '10000002';
            Elsif v_estado = 'R' Then
              v_cod_sit_contable := '10000001';
            Else
              v_cod_sit_contable := '10000000';
            End If;

            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo IN (v_tip_sal_int)
                  AND cod_plazo IN (v_cod_plazo, 0)
                  AND tip_operacion IN (v_tip_operacion, 'X')
                  AND tip_interes IN (v_tip_interes, 'X')
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_sal_interes
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_sal_interes
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_sal_interes, 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  IF (v_cod_modalidad IN (100, 101, 102, 105, 112, 125, 129, 132, 123, 114, 122)) THEN
                     --documentos originales en estado normal
                     IF (v_estado = 'C' AND v_fec_ven_repo IS NULL) THEN
                        v_tip_movimiento := 'D';
                        IF (v_cod_sit_contable = '10000001') THEN
                           v_cod_transaccion := 813;
                        ELSE
                           v_cod_transaccion := 719;
                        END IF;
                     ELSIF (v_estado = 'R') THEN
                        --documentos originales en repo
                        v_tip_movimiento  := 'D';--'C';
                        v_cod_transaccion := 817; --719;
                     ELSE
                        v_sal_interes := 0;
                     END IF;
                  ELSIF v_estado = 'E' THEN
                        --documentos vendidos
                        v_tip_movimiento  := 'D';--'C';
                        v_cod_transaccion := 812;

                  ELSIF (v_cod_modalidad IN (104, 124) OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S') THEN
                     --bonos privados / Repo Otorgado
                     v_tip_movimiento := 'D'; --'C'; confirmar!
                     IF (v_cod_sit_contable = '10000001') THEN
                        v_cod_transaccion := 811;
                     ELSE
                        v_cod_transaccion := 719;
                     END IF;
                  ELSIF (v_cod_modalidad = 106) THEN
                     --bonos afd
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 719;
                  ELSE
                     v_sal_interes := 0;
                  END IF;

               IF  v_sal_interes <> 0 THEN --DYDMR-15258 DR
                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sector, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   v_tip_movimiento, v_cod_rubro, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);


                  --------------------------------
                  -- INSERTA INTERES DOCUMENTADO--
                  --------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_int, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, v_sal_interes, v_cod_rubro, v_nro_referencia,
                      v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_sal_interes, 0);
               END IF;
            END;
         END IF;

         -------------------------------------------------------------------
         v_cod_transaccion:= null; --DYDMR-15258 DR

         IF (v_tip_sal_ade = 'A') THEN
            /*IF v_estado = 'R' THEN
               v_int_devengar := 0;
            END IF;*/

            -- Asignamos el sit contable de acuerdo a la modalida y estado -- REPO-CNF-RBARRIOS
            If fum_obt_ope_repo(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' Then
              v_cod_sit_contable := '10000001';
            Elsif fum_obt_ope_repo(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
              v_cod_sit_contable := '10000002';
            Elsif v_estado = 'R' Then
              v_cod_sit_contable := '10000001';
            Else
              v_cod_sit_contable := '10000000';
            End If;

            -------------------------------------------
            -- ACTUALIZA SALDO DE INTERES A DEVENGAR --
            -------------------------------------------
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo IN (v_tip_sal_ade)
                  AND cod_plazo IN (v_cod_plazo, 0)
                  AND tip_operacion IN (v_tip_operacion, 'X')
                  AND tip_interes IN (v_tip_interes, 'X')
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + nvl(v_int_devengar, 0)
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + nvl(v_int_devengar, 0)
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, nvl(v_int_devengar, 0), 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  v_mto_devengar := v_int_devengar;
                  IF (v_cod_modalidad IN (100, 101, 102, 105, 125, 129, 132, 123, 114, 122)) THEN
                     --documentos originales en estado normal
                     IF (v_estado = 'C' AND v_fec_ven_repo IS NULL) THEN
                        v_tip_movimiento := 'C';
                        IF (v_cod_sit_contable = '10000001') THEN
                           v_cod_transaccion := 813;
                        ELSE
                           v_cod_transaccion := 719;
                        END IF;
                     ELSIF (v_estado = 'R') THEN
                        --documentos originales en repo
                        v_tip_movimiento  := 'C';
                        v_cod_transaccion := 802;
                     ELSE
                        v_int_devengar := 0;
                     END IF;
                  ELSIF  v_estado = 'E' THEN
                        --documentos vendidos
                        v_tip_movimiento  := 'D';
                        v_cod_transaccion := 812;
                  ELSIF (v_cod_modalidad IN (104, 124) OR FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S') Then -- CNFREINT-1 -- Repo Otorgado --
                     --bonos privados / Repo otorgado
                     v_tip_movimiento  := 'C';
                     v_cod_transaccion := 719;
                  ELSIF (v_cod_modalidad = 106) THEN
                     --bonos afd
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 901;
                  ELSIF (v_cod_modalidad = 112) THEN
                     --prestamos recibidos de bcos. locales
                     v_tip_movimiento  := 'C';
                     v_cod_transaccion := 901;
                  ELSIF (v_cod_modalidad in (110,116,146)) THEN    --C.B. 07/09/2012
                     --call money
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 901;
                     v_mto_devengar    := v_dev_acumulado;
                  ELSE
                     v_int_devengar := 0;
                     v_mto_devengar := 0;--DYDMR-7172 - Tambien se debe cerar ?sta variable, o sino se expone en
                                         --el Inventario Intereses a Devengar de Modalidades que no corresponden.-
                  END IF;

               IF  v_int_devengar <> 0 THEN --DYDMR-15258 DR
                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sector, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   v_tip_movimiento, v_cod_rubro, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  -----------------------------------------
                  -- INSERTA SALDO DE INTERES A DEVENGAR --
                  -----------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_ade, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, nvl(v_mto_devengar, 0), v_cod_rubro,
                      v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, nvl(v_mto_devengar, 0), 0);
               END IF;
            END;
         END IF;

         -------------------------------------------------------------------
         v_cod_transaccion:= null; --DYDMR-15258 DR

         IF (v_tip_sal_dev = 'D') THEN
            /*IF v_estado = 'R' THEN
               v_int_devengado := v_dev_acumulado;
               v_cod_plazo     := v_cod_plazo_repo; -- RIPEADO devenga en plazo REPO
            ELSE
               v_int_devengado := v_sal_interes - v_int_devengar;
            END IF;*/
            IF v_estado = 'R' Then
              Begin
                Select nvl(d.fec_ven_repo - d.fec_ini_repo, NULL)
                  Into v_dias
                  From md_cta_documentos d
                 Where d.nro_cuenta In (
                                        Select b.nro_cta_repo
                                          from md_cta_documentos a, md_cuo_instrumentos b
                                         Where a.nro_cuenta = b.nro_cuenta
                                           And a.nro_cuenta = v_nro_cuenta
                                           And b.estado = v_estado
                                           And b.nro_cuota = v_cuota
                                        );
               Exception
                 When Others Then
                    v_dias := 0;
               End;

               Begin
                 SELECT cod_plazo
                   INTO v_cod_plazo_repo
                   FROM ge_plz_contables
                  WHERE can_dias >= nvl(v_dias, NULL)
                    AND rownum = 1;
                Exception
                  When Others Then
                    v_cod_plazo_repo := 0;
                End;

               v_cod_plazo := v_cod_plazo_repo; -- RIPEADO devenga en plazo REPO
            END IF;

            -- Asignamos el sit contable de acuerdo a la modalida y estado -- REPO-CNF-RBARRIOS
            If FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' Then
              v_cod_sit_contable := '10000001';
            Elsif FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
              v_cod_sit_contable := '10000002';
            Elsif v_estado = 'R' Then
              v_cod_sit_contable := '10000001';
            Else
              v_cod_sit_contable := '10000000';
            End If;

            -------------------------------------------
            -- ACTUALIZA SALDO DE INTERES DEVENGADO --
            -------------------------------------------
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo IN (v_tip_sal_dev)
                  AND cod_plazo IN (v_cod_plazo, 0)
                  AND tip_operacion IN (v_tip_operacion, 'X')
                  AND tip_interes IN (v_tip_interes, 'X')
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + nvl(v_int_devengado, 0)
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + nvl(v_int_devengado, 0)
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, nvl(v_int_devengado, 0), 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  /*                  IF v_cod_modalidad IN (117, 109, 118, 112, 126) THEN
                     --prestamos afd, prestamos recibidos
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 719;
                  ELSIF v_estado = 'R' THEN
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 813;
                  END IF;*/
                  IF v_cod_modalidad IN (109, 112, 126) THEN
                     --prestamos afd, prestamos recibidos
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 719;
                  ELSIF v_cod_modalidad IN (117,150,155,118) THEN
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 1719;
                  ELSIF v_cod_modalidad in (144, 134) THEN
                     -- RABF 16/09/2011
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 901;
                  ELSIF v_estado = 'R' THEN
                     v_tip_movimiento  := 'D';
                     v_cod_transaccion := 813;
                  END IF;

                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sector, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   v_tip_movimiento, v_cod_rubro, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  -----------------------------------------
                  -- INSERTA SALDO DE INTERES DEVENGADO --
                  -----------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_dev, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, nvl(v_int_devengado, 0), v_cod_rubro,
                      v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, nvl(v_int_devengado, 0), 0);
            END;
         END IF;
         ------------------------------------------------------------------------------------
         IF v_tip_sal_int_no_documentado = 'N' THEN
            ------------------------------------------------------------------------------------
            -------------------- ACTUALIZA INTERESES NO DOCUMENTADOS ---------------------------
            ------------------------------------------------------------------------------------

            -- Asignamos el sit contable de acuerdo a la modalida y estado -- REPO-CNF-RBARRIOS
            If FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','R') = 'S' Then
              v_cod_sit_contable := '10000001';
            Elsif FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
              v_cod_sit_contable := '10000002';
            Elsif v_estado = 'R' Then
              v_cod_sit_contable := '10000001';
            Else
              v_cod_sit_contable := '10000000';
            End If;

            -- INSERTA LOS CREDITOS
            BEGIN
               SELECT nro_referencia, ROWID, sal_total
                 INTO v_nro_referencia, v_rowid, v_sal_total
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo = v_tip_sal_int_no_documentado
                  AND cod_plazo IN (v_cod_plazo, 0)
                  AND tip_operacion IN (v_tip_operacion, 'X')
                  AND tip_interes IN (v_tip_interes, 'X')
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               -- Verificamos si el valor total del inventario ya se encuentra en negativo
               IF nvl(v_sal_total, 0) > 0 THEN
                  v_sal_negativo := NULL;
               ELSE
                  v_sal_negativo := 1;
               END IF;

               UPDATE cb_sal_inventarios
                  SET sal_total =
                      (nvl(sal_total, 0) * nvl(v_sal_negativo, -1)) + (v_sal_no_doc * -1) --nvl(sal_total, 0) + v_sal_interes
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual =
                      (nvl(sal_actual, 0) * nvl(v_sal_negativo, -1)) + (v_sal_no_doc * -1) --nvl(sal_actual, 0) + v_sal_interes
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, (v_sal_no_doc * -1), 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 802, v_cod_moneda, v_cod_sector,
                                   v_tip_deudor, v_residente, to_char(v_cod_plazo), 'C',
                                   v_cod_rub_no_doc_c, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  --------------------------------------------------
                  -- INSERTA INTERES NO DOCUMENTADOS TIPO CREDITO --
                  --------------------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_int_no_documentado, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, (v_sal_no_doc * -1), v_cod_rub_no_doc_c,
                      v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, (v_sal_no_doc * -1), 0);
            END;

            -- FIN INSERTA LOS CREDITOS
            -- INSERTA LOS DEBITOS
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo = v_tip_sal_int_no_documentado
                  AND cod_plazo IN (v_cod_plazo, 0)
                  AND tip_operacion IN (v_tip_operacion, 'X')
                  AND tip_interes IN (v_tip_interes, 'X')
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_sal_no_doc
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_sal_no_doc
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_sal_no_doc, 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 802, v_cod_moneda, v_cod_sector,
                                   v_tip_deudor, v_residente, to_char(v_cod_plazo), 'D',
                                   v_cod_rub_no_doc_d, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  --------------------------------------------------
                  -- INSERTA INTERES NO DOCUMENTADOS TIPO DEBITOS --
                  --------------------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_int_no_documentado, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, v_sal_no_doc, v_cod_rub_no_doc_d,
                      v_nro_referencia, v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_sal_no_doc, 0);
            END;
         END IF;
         ------------------------------------------------------------------------------------

         IF v_tip_sal_doc_rep_otorgado = 'O' THEN
            --------------------------------
            -- Alta de documento en REPO Otorgado (Compra Doc.) --
            --------------------------------
            v_capital := v_monto;

            -- Asignamos el sit contable para el rubro 12306 -- REPO-CNF-RBARRIOS
            v_cod_sit_contable := '10000000';

            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo = v_tip_sal_cap
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_operacion
                  AND tip_interes = v_tip_interes
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_capital
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_capital
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_capital, 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  IF FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
                     -- Alta Documentos comprados en Repo Otorgado --
                     v_tip_movimiento  := 'C';
                     v_cod_transaccion := 814;
                  ELSE
                     v_capital := 0;
                  END IF;

                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sector, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   v_tip_movimiento, v_cod_rubro, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  ------------------------------
                  -- INSERTA SALDO DE CAPITAL --
                  ------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_doc_rep_otorgado, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, v_capital, v_cod_rubro, v_nro_referencia,
                      v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_capital, 0);

            END;

         -- Asignamos el sit contable para el rubro 12602 -- REPO-CNF-RBARRIOS
            v_cod_sit_contable := '10000002';

            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sector
                  AND cod_tip_deudor = v_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_estado
                  AND tip_saldo = v_tip_sal_doc_rep_otorgado
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_operacion
                  AND tip_interes = v_tip_interes
                  AND tip_renovacion = v_tip_renovacion
                  AND cat_automatica = v_cat_riesgo
                  AND cod_sit_contable = v_cod_sit_contable;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_capital
                WHERE ROWID = v_rowid;

               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_capital
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_capital, 0);
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  IF FUM_OBT_OPE_REPO(v_cod_modulo,v_cod_modalidad,'S','O') = 'S' Then
                     -- Alta Documentos comprados en Repo Otorgado --
                     v_tip_movimiento  := 'C';
                     v_cod_transaccion := 814;
                  ELSE
                     v_capital := 0;
                  END IF;

                  --- busco la cuenta que le corresponde al saldo ----
                  lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                                   v_cod_sector, v_tip_deudor, v_residente, to_char(v_cod_plazo),
                                   v_tip_movimiento, v_cod_rubro, v_estado, NULL, NULL, NULL, NULL,
                                   v_cod_sit_contable, NULL);

                  ------------------------------
                  -- INSERTA SALDO DE CAPITAL --
                  ------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sector, v_tip_deudor,
                      v_residente, v_cod_moneda, v_estado, v_tip_sal_doc_rep_otorgado, v_cod_plazo,
                      v_tip_operacion, v_tip_interes, v_capital, v_cod_rubro, v_nro_referencia,
                      v_tip_renovacion, v_cat_riesgo, v_cod_sit_contable);

                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_capital, 0);

            END;
         END IF;

      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_MES_DINERO:' || SQLERRM);
   END;
   -- fin de Mesa de Dinero ---
   --------------------------------------------------------------------------------------------------------------------
   --------------------------------------------------------------------------------------------------------------------

   -- Caja
   PROCEDURE lp_acu_caja IS
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_cod_oficina     cb_sal_inventarios.cod_oficina%TYPE;
      v_caj_ofi         VARCHAR2(15);
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_nro_refe_det    NUMBER(07);
      v_fec_actual      DATE := pag_cal.fu_obt_fec_actual(4);
      v_ref             NUMBER(10);
      v_ofi_caja        VARCHAR2(15);
      ---cursor
      CURSOR sal IS
         SELECT DISTINCT fecha, cod_oficina, nro_caja, cod_moneda, mto_apertura, mto_cierre
           FROM (SELECT c.fecha,
                        a.cod_oficina,
                        a.nro_caja,
                        c.cod_moneda,
                        SUM(c.mto_apertura) mto_apertura,
                        SUM(c.mto_cierre) mto_cierre
                   FROM cj_controles c, cj_cajas a
                  WHERE c.nro_caja = a.nro_caja
                    AND c.fecha >= v_fec_actual
                 /*and c.nro_caja < 900*/
                  GROUP BY c.fecha, a.cod_oficina, a.nro_caja, c.cod_moneda
                 UNION ALL
                 SELECT c.fecha,
                        a.cod_oficina,
                        a.nro_caja,
                        c.cod_moneda,
                        SUM(c.mto_apertura) mto_apertura,
                        SUM(c.mto_cierre) mto_cierre
                   FROM cj_controles c, cj_cajas a
                  WHERE c.nro_caja = a.nro_caja
                    AND NOT EXISTS (SELECT 1
                           FROM cj_controles t
                          WHERE t.nro_caja = c.nro_caja
                            AND c.cod_moneda = t.cod_moneda
                            AND t.fecha >= v_fec_actual)
                    AND c.fecha = (SELECT MAX(p.fecha)
                                     FROM cj_controles p
                                    WHERE p.nro_caja = c.nro_caja
                                      AND c.cod_moneda = p.cod_moneda
                                      AND p.fecha < v_fec_actual)
                    AND c.mto_cierre <> 0
                 /*and c.nro_caja < 900*/
                  GROUP BY c.fecha, a.cod_oficina, a.nro_caja, c.cod_moneda)
          WHERE nvl(mto_cierre, 0) <> 0
          ORDER BY 1, 2, 3;
   BEGIN
      v_cod_modulo    := 9;
      v_cod_modalidad := 91;
      v_cod_plazo     := 1;
      v_tip_saldo     := 'C'; --capital - efectivo.
      /*v_tip_movimiento := 'C';
      v_cod_transaccion := 590;*/

      FOR i IN sal LOOP

         IF (i.nro_caja < 900) THEN
            v_tip_movimiento  := 'C';
            v_cod_transaccion := 590;
         END IF;
         IF (i.nro_caja >= 900) THEN
            v_tip_movimiento  := 'D';
            v_cod_transaccion := 1210;
         END IF;
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda,
                          /*v_cod_sector*/ NULL, /*v_tip_deudor*/ NULL,
                          /*v_residente*/ NULL, to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro,
                          /*v_estado*/ NULL, /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_cierre
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            v_ofi_caja := to_char(i.cod_oficina) || to_char(i.nro_caja);

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_cierre
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_ofi_caja;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_ofi_caja, i.mto_cierre, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_cierre, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.mto_cierre, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  v_ofi_caja := to_char(i.cod_oficina) || to_char(i.nro_caja);
                  IF nvl(i.mto_cierre, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_ofi_caja, i.mto_cierre, 0);
                  END IF;

               END IF;

            WHEN too_many_rows THEN
               raise_application_error(-20000,
                                       'EXISTE MAS DE UN REGISTRO CON ESTE NRO DE REFERENCIA
         EN CB_SAL_INVENTARIOS con NRO REFERENCIA ' ||
                                        v_nro_referencia || ' OFI ' || i.cod_oficina || ' moneda ' ||
                                        i.cod_moneda || ' v_cod_rubro ' || v_cod_rubro || ' rowid ' ||
                                        v_rowid);
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_CAJA:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de caja

   --------------------------------------------------------------------------------------------------------------------
   --------------------------------------------------------------------------------------------------------------------

   -- Documentos pendientes de confirmacion
   PROCEDURE lp_acu_docpend IS

      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR doc IS
         SELECT t.cod_transaccion,
                r.nro_cuenta, r.cod_modulo, r.cod_modalidad, r.cod_oficina,
                r.cod_moneda, r.sal_retenido
           FROM ah_retenciones r, ge_transacciones t
          WHERE r.liberado = 'N'
            AND t.cod_modulo = r.cod_modulo
            AND t.cod_modalidad = r.cod_modalidad
            AND t.cod_retencion = r.cod_retencion;

   BEGIN

      v_cod_plazo      := 1;
      v_tip_saldo      := 'R'; --capital - efectivo.
      v_tip_movimiento := 'C';

      FOR i IN doc LOOP

         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_transaccion, i.cod_moneda,
                          /*v_cod_sector*/ NULL, /*v_tip_deudor*/ NULL,
                          /*v_residente*/ NULL, to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro,
                          /*v_estado*/ NULL, /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.sal_retenido
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.sal_retenido, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.sal_retenido, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.sal_retenido, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.sal_retenido, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_DOCPEND:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Documentos pendientes de confirmacion

   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Transferencias
   PROCEDURE lp_acu_trans IS
      v_cod_modulo     cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad  cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina    cb_sal_inventarios.cod_oficina%TYPE;
      v_caj_ofi        VARCHAR2(15);
      v_nro_cuenta     ge_cuentas.nro_cuenta%TYPE;
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;
      v_ref            NUMBER(10);
      v_refe_tip       VARCHAR2(15);
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      ---cursor
      CURSOR transf IS
         SELECT nro_referencia,
                cod_tip_referencia,
                cod_modulo,
                cod_modalidad,
                cod_moneda,
                cod_oficina,
                nvl(fec_valor, fec_operacion),
                cod_per_beneficiario,
                estado,
                SUM(saldo) saldo,
                nvl(fub_obt_rub_transaccion(CASE
                                               WHEN nvl(fec_valor, fec_operacion) <= trunc(SYSDATE) THEN
                                                7
                                               WHEN nvl(fec_valor, fec_operacion) > trunc(SYSDATE) THEN
                                                4 --- Otro
                                            END,
                                            CASE
                                                WHEN nvl(fec_valor, fec_operacion) <= trunc(SYSDATE) THEN
                                                 71
                                                WHEN nvl(fec_valor, fec_operacion) > trunc(SYSDATE) THEN
                                                 45 --- Otro
                                             END,
                                            CASE
                                                WHEN nvl(fec_valor, fec_operacion) <= trunc(SYSDATE) THEN
                                                 286
                                                WHEN nvl(fec_valor, fec_operacion) > trunc(SYSDATE) THEN
                                                 1503 --- Otro
                                             END, cod_moneda, cod_per_beneficiario, 0, 'D', estado),
                    0) rubro
           FROM lc_transferencias
          WHERE cod_modalidad IN (72, 75)
            AND cod_modulo = 7
            AND nvl(saldo, 0) <> 0
          GROUP BY nro_referencia,
                   cod_tip_referencia,
                   cod_modulo,
                   cod_modalidad,
                   cod_moneda,
                   cod_oficina,
                   nvl(fec_valor, fec_operacion),
                   cod_per_beneficiario,
                   estado
          ORDER BY 1, 2, 3;

   BEGIN
      v_cod_modulo     := 7;
      v_cod_plazo      := 1;
      v_tip_saldo      := 'C'; --capital - efectivo.
      v_tip_movimiento := 'C';

      FOR i IN transf LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_rubro = i.rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_refe_tip;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_refe_tip, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN

                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo, i.rubro, v_nro_referencia,
                      NULL, NULL, NULL);

                  v_refe_tip := to_char(i.nro_referencia) || to_char(i.cod_tip_referencia);
                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, v_refe_tip, i.saldo, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_TRANS:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de transferencia

   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Cheques certificados
   PROCEDURE lp_acu_cheqcert IS
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_nro_refe_det    NUMBER(07);

      ---cursor
      CURSOR cheq IS
         SELECT cb.cod_oficina,
                ch.nro_cuenta,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                cc.cod_moneda,
                ch.estado,
                cb.cod_rubro,
                ch.monto
           FROM cc_che_certificados ch,
                ge_cta_clientes     gc,
                ge_clientes         c,
                cc_cta_corrientes   cc,
                cc_cta_bancarias    cb
          WHERE ch.nro_cuenta = gc.nro_cuenta --cheque con cta-cliente
            AND gc.cod_persona = c.cod_persona --cta-cliente con cliente
            AND cc.nro_cuenta = ch.nro_cuenta --cta-corriente con che-certificado
            AND ch.nro_cta_certificado = cb.nro_cuenta
            AND ch.fec_pago IS NULL
            AND gc.relacion = 'P';

   BEGIN
      v_cod_modulo     := 4;
      v_cod_modalidad  := 41;
      v_cod_plazo      := 1;
      v_tip_saldo      := 'C'; --capital - efectivo.
      v_tip_movimiento := 'C';

      FOR i IN cheq LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo,
                      NULL, NULL, i.monto, i.cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_CAJA:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de cheques certificados

   --Procedimiento agregado por Ana Azorero - Set 2010
   PROCEDURE lp_acu_bonos_sub IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIEN
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_situacion        cb_sal_inventarios.situacion%TYPE;
      v_tip_operacion    cb_sal_inventarios.tip_operacion%TYPE;
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_cod_plazo        NUMBER(02);
      v_fec_apertura     DATE;
      v_sal_tot_batch    NUMBER(22, 2);
      v_interes          NUMBER(22, 2);
      v_int_vencido      NUMBER(22, 2);
      v_sal_total        NUMBER(22, 2);
      v_sal_interes      NUMBER(22, 2);
      v_int_a_devengar   NUMBER(22, 2);
      v_tot_interes      NUMBER(22, 2);
      v_int_devengado    NUMBER(22, 2);
      v_int_pagado       NUMBER(22, 2);
      v_tot_pago         NUMBER(22, 2);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_est_cta_batch    VARCHAR2(01);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_rowid            VARCHAR2(30);
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_mon_pignorado    NUMBER(18);
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                a.cod_moneda,
                cod_plazo,
                nvl(a.fec_ult_capitalizacion, a.fec_apertura) fec_ult_capitalizacion,
                decode(a.est_batch, 'B', decode(a.est_cer_batch, 'V', 'V', 'N'),
                       decode(a.est_batch, 'P', 'V', a.est_batch)) est_batch,
                nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0)
           FROM ge_plz_contables d, ge_clientes c, ge_cta_clientes b, ah_cta_certificados a
          WHERE b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND c.cod_persona = b.cod_persona
            AND a.est_batch NOT IN ('C', 'T')
            AND a.cod_modalidad = 36
            AND can_dias = (SELECT MIN(can_dias)
                              FROM ge_plz_contables
                             WHERE can_dias >= a.fec_vencimiento - a.fec_apertura);
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_cod_plazo,
                 v_fec_apertura,
                 v_est_cta_batch,
                 v_sal_tot_batch;
         EXIT WHEN movimien%NOTFOUND;
         v_situacion       := 'N';
         v_cod_transaccion := 602;
         v_mon_pignorado   := 0;
         SELECT nvl(SUM(v.monto), 0)
           INTO v_mon_pignorado
           FROM (SELECT c.monto
                  FROM pr_gar_cash c
                 WHERE c.nro_cta_referencia = v_nro_cuenta
                   AND EXISTS
                   (SELECT 1 FROM pr_cta_garantias g, pr_cta_prestamos pr, pr_garantias ga
                      WHERE g.nro_cuenta = pr.nro_cuenta
                        AND ga.nro_garantia = c.nro_garantia
                        AND pr.estado != 'N'
                        AND ga.estado = 'C'
                        AND c.nro_garantia = g.nro_garantia)) v;

         IF v_est_cta_batch = 'V' THEN
            v_situacion       := 'V';
            v_cod_transaccion := 604;
         END IF;
         ---------------------------------------------------------
         -- OBTIENE TOTALES DE LOS CUPONES  EMITIDOS Y VENCIDOS --
         ---------------------------------------------------------
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_int_vencido
           FROM ah_cupones
          WHERE nro_cuenta = v_nro_cuenta
            AND estado = 'V';
         --------------------------------------------
         -- OBTIENE EL TOTAL DE INTERES DEL CERTIF.--
         --------------------------------------------
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_tot_interes
           FROM ah_cupones
          WHERE nro_cuenta = v_nro_cuenta
            AND estado IN ('E', 'C')
            AND v_est_cta_batch IN ('N', 'B');
         --------------------------------------------
         -- OBTIENE EL TOTAL DE INTERES PAGADO
         --------------------------------------------
         SELECT SUM(nvl(mto_interes, 0))
           INTO v_tot_pago
           FROM ah_cupones
          WHERE nro_cuenta = v_nro_cuenta
            AND estado = 'P';
         --------------------------------------------
         -- OBTIENE EL TOTAL DE INTERES DEVENGADO ---
         --------------------------------------------
         SELECT SUM(nvl(mto_dev_acumulado, 0))
           INTO v_int_devengado
           FROM ah_devengados
          WHERE nro_cuenta = v_nro_cuenta
            AND fec_inicio >= v_fec_apertura;
         --------------------------------------------
         -- CALCULO DEL SALDOTO Y SALDO A DEVENGAR --
         --------------------------------------------
         v_sal_total      := nvl(v_sal_tot_batch, 0) - nvl(v_int_vencido, 0);
         v_int_a_devengar := nvl(v_tot_interes, 0) - nvl(v_int_devengado, 0);
         v_interes        := nvl(v_tot_interes, 0) + nvl(v_int_vencido, 0); --modificado para bonos subordinados Ana Azorero - Set 2010
         -------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) --
         -------------------------------------------------------------
         v_tip_saldo := 'C';
         -------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA) --
         -------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA) --
         --------------------------------------------------
         v_tip_operacion := 'X';
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                          v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                          'C', v_cod_rubro);
         --------------------------------
         -- ACTUALIZA SALDO DE CAPITAL --
         --------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            --
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_total
             WHERE ROWID = v_rowid;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_total
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_total, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               ------------------------------
               -- INSERTA SALDO DE CAPITAL --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_sal_total, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_total, 0);
         END;
         -------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO INTERES                        --
         -------------------------------------------------------------
         v_tip_saldo := 'I';
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 400, v_cod_moneda, v_cod_sec_contable,
                          v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
         -------------------------------------------------------
         -- ACTUALIZA SALDO DE INTERES PARA TIPO DE SALDO = D --
         -------------------------------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            --
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(v_interes, 0)
             WHERE ROWID = v_rowid;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(v_interes, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_interes, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               ------------------------------
               -- INSERTA SALDO DE INTERES --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_interes, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_interes, 0);
         END;
         -------------------------------------------------------
         -- ACTUALIZA SALDO DE INTERES PARA TIPO DE SALDO = A --
         -------------------------------------------------------
         v_tip_saldo := 'A';
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, 901, v_cod_moneda, v_cod_sec_contable,
                          v_cod_tip_deudor, v_residente, to_char(v_cod_plazo), 'C', v_cod_rubro);
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_situacion
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_operacion
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            --
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(v_int_a_devengar, 0)
             WHERE ROWID = v_rowid;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(v_int_a_devengar, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_int_a_devengar, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               ----------------------------------------
               -- INSERTA SALDO DE INTERES A DEVENGAR--
               ----------------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                   v_cod_plazo, v_tip_operacion, v_tip_interes, v_int_a_devengar, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_int_a_devengar, 0);
         END;

         IF v_mon_pignorado > 0 THEN
            ------------------------------------
            -- ACTUALIZA PIGNORACION DE CDA --
            ------------------------------------
            v_tip_saldo       := 'P';
            v_situacion       := 'N';
            v_cod_transaccion := 603;
            --- busco la cuenta que le corresponde al saldo ----
            lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                             v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                             'C', v_cod_rubro);
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_situacion
                  AND tip_saldo = v_tip_saldo
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_operacion
                  AND tip_interes = v_tip_interes
                  AND cod_rubro = v_cod_rubro;
               --
               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_mon_pignorado
                WHERE ROWID = v_rowid;
               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_mon_pignorado
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;
               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  -------------------------------------------
                  -- ACTUALIZA PIGNORACION DE CDA --
                  -------------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                      v_cod_plazo, v_tip_operacion, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                      v_nro_referencia);
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
            END;
            ------------------------------------
            -- ACTUALIZA PIGNORACION DE CDA --
            ------------------------------------
            v_tip_saldo       := 'T';
            v_situacion       := 'N';
            v_cod_transaccion := 603;
            v_mon_pignorado   := v_mon_pignorado * -1;
            --- busco la cuenta que le corresponde al saldo ----
            lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, v_cod_moneda,
                             v_cod_sec_contable, v_cod_tip_deudor, v_residente, to_char(v_cod_plazo),
                             'D', v_cod_rubro);
            BEGIN
               SELECT nro_referencia, ROWID
                 INTO v_nro_referencia, v_rowid
                 FROM cb_sal_inventarios
                WHERE cod_modulo = v_cod_modulo
                  AND cod_modalidad = v_cod_modalidad
                  AND cod_oficina = v_cod_oficina
                  AND cod_sec_contable = v_cod_sec_contable
                  AND cod_tip_deudor = v_cod_tip_deudor
                  AND residente = v_residente
                  AND cod_moneda = v_cod_moneda
                  AND situacion = v_situacion
                  AND tip_saldo = v_tip_saldo
                  AND cod_plazo = v_cod_plazo
                  AND tip_operacion = v_tip_operacion
                  AND tip_interes = v_tip_interes
                  AND cod_rubro = v_cod_rubro;
               --
               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_mon_pignorado
                WHERE ROWID = v_rowid;
               --- genero detalle ---------------------------------
               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_mon_pignorado
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = v_nro_cuenta;
               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  -------------------------------------------
                  -- ACTUALIZA PIGNORACION DE CDA --
                  -------------------------------------------
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                      v_cod_tip_deudor, v_residente, v_cod_moneda, v_situacion, v_tip_saldo,
                      v_cod_plazo, v_tip_operacion, v_tip_interes, v_mon_pignorado, v_cod_rubro,
                      v_nro_referencia);
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, v_nro_cuenta, v_mon_pignorado, 0);
            END;
         END IF;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_BONOS_SUB:' || SQLERRM);
   END;
   --fin de bonos subordinados
   --------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Activo fijo
   PROCEDURE lp_acu_activo IS

      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rubro2     cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;
      v_residente      cb_sal_inventarios.residente%TYPE;

      ---cursor
      CURSOR act IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_tra_alta,
                a.cod_tra_depreciacion,
                b.cod_oficina,
                b.cod_moneda,
                decode(nvl(b.rev_actual,0), 0, nvl(b.val_compra, 0), nvl(b.rev_actual,0)) revaluo,
                nvl(b.dep_acumulada,0) dep_acumulada,
                b.cod_bien
           FROM af_articulos a, af_bienes b
          WHERE a.cod_articulo = b.cod_articulo
            AND a.ind_act_fijo = 'S'
            AND b.estado = 'A'; --Modificado por Simgia S.R.L.-Nilsa Aponte - Se agrega el filtro de que estado=A

   BEGIN

      v_cod_plazo      := 1;
      v_tip_saldo      := 'C';
      v_tip_movimiento := 'D'; --deudor
      v_residente      := 'X';

      FOR i IN act LOOP
         v_tip_saldo      := 'C';
         v_tip_movimiento := 'D'; --deudor
         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_tra_alta, i.cod_moneda,
                          /*v_cod_sector*/ NULL, /*v_tip_deudor*/ NULL, v_residente /*null*/, NULL,
                          v_tip_movimiento, v_cod_rubro,
                          /*v_estado*/ NULL, /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN
            ---ACTUALIZA REVALUO ACTUAL
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.revaluo
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.revaluo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.cod_bien;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.cod_bien, i.revaluo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.revaluo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.revaluo, nvl(v_cod_rubro, 0),
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.revaluo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.cod_bien, i.revaluo, 0);
                  END IF;

               END IF;
         END;
         ---------------------------------------------------------------------------------
         ---ACTUALIZA  DEPRECIACION ACUMULADA
         v_tip_movimiento := 'C'; --acreedor
         v_tip_saldo      := 'B';

         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, i.cod_tra_depreciacion, i.cod_moneda,
                          /*v_cod_sector*/ NULL, /*v_tip_deudor*/ NULL, v_residente /*null*/,
                          to_char(v_cod_plazo), v_tip_movimiento, v_cod_rubro2,
                          /*v_estado*/ NULL, /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_rubro = v_cod_rubro2;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.dep_acumulada
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.dep_acumulada
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.cod_bien;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.cod_bien, i.dep_acumulada, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.dep_acumulada, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.dep_acumulada, v_cod_rubro2,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.dep_acumulada, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.cod_bien, i.dep_acumulada, 0);
                  END IF;

               END IF;
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_ACTIVO:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Activo fijo
   --------------------------------------------------------------------------------------------------------------------
   --------------------------------------------------------------------------------------------------------------------
   -- Cheques gerencia
   PROCEDURE lp_acu_che_geren IS
      v_cod_modulo     cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad  cb_sal_inventarios.cod_modalidad%TYPE;
      v_nro_cuenta     ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_cod_rubro      cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR geren IS
         SELECT cc.cod_oficina,
                ch.nro_cuenta,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                cc.cod_moneda,
                cc.estado,
                cc.cod_rubro,
                ch.monto
           FROM cc_che_ger_emitidos ch, ge_cta_clientes gc, ge_clientes c, cc_cta_bancarias cc
          WHERE ch.nro_cuenta = gc.nro_cuenta --cheque con cta-cliente
            AND gc.cod_persona = c.cod_persona --cta-cliente con cliente
            AND cc.nro_cuenta = ch.nro_cuenta --cta-bancaria con che_ger_emitidos
            AND ch.fec_pago IS NULL
            AND cc.cod_modulo = 4
            AND cc.cod_modalidad = 43
            AND gc.relacion = 'P'
            /* DE-1604 Ajustar el inventario para no tener en cuenta los cheques con Orden de No Pago-ALV_NOVIEMBRE 2015*/
            and not exists (select 1
                              from cc_che_ord_no_pagos o
                             where o.nro_cuenta = ch.nro_cuenta
                               and o.nro_cheque = ch.nro_cheque);

   BEGIN
      v_cod_modulo     := 4;
      v_cod_modalidad  := 43;
      v_cod_plazo      := 1;
      v_tip_saldo      := 'C'; --capital - efectivo.
      v_tip_movimiento := 'C';

      FOR i IN geren LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo,
                      NULL, NULL, i.monto, i.cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_CHE_GEREN:' || SQLERRM);
   END;
   -- fin de cheques gerencia
   ---------------------------------------------------------------------------------------------------------------------
   PROCEDURE lp_acu_atm IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIENTOS
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_cod_plazo        NUMBER(02);
      v_sal_tot_batch    NUMBER(22, 2);
      v_tip_saldo        VARCHAR2(01);
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_fila             VARCHAR2(30);
      /* Modificado por Ana Azorero Abr-10 */
      v_sal_ret_batch   NUMBER(22, 2);
      v_sal_blo_batch   NUMBER(22, 2);
      v_sal_disponible  NUMBER(22, 2);
      v_cod_transaccion NUMBER(05);
      v_cod_persona     ba_personas.cod_persona%TYPE;

      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                'N',
                1,
                nvl(sal_tot_batch, 0),
                nvl(sal_ret_batch, 0),
                nvl(sal_blo_batch, 0),
                a.nro_cuenta,
                c.cod_persona
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a
          WHERE b.cod_persona = c.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modalidad = 46
            AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR a.sal_blo_batch <> 0);

   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;

      ------------------------ LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_sal_ret_batch,
                 v_sal_blo_batch,
                 v_nro_cuenta,
                 v_cod_persona;
         EXIT WHEN movimien%NOTFOUND;

         --------------------------------------------------------------
         v_sal_disponible := v_sal_tot_batch - v_sal_ret_batch - v_sal_blo_batch;
          /*IF substr(v_cod_rubro,1,1) <> '2' then --- No sea Cuenta Pasiva MODIFICADO POR ICL 02/08/2012 dc 1286
           v_sal_disponible := v_sal_disponible * (-1);
           END IF;*/
        -- v_sal_disponible := v_sal_disponible * (-1);
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'C';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         -- ACTUALIZA SALDO DE CAPITAL --
         --------------------------------
         v_cod_transaccion := 602;
         v_cod_rubro       := fub_obt_rub_transaccion(v_cod_modulo, v_cod_modalidad,
                                                      v_cod_transaccion, v_cod_moneda, v_cod_persona,
                                                      to_char(v_cod_plazo), 'C');
         --23/07/2013 DI. SF Contingente ingresado por incidencia
         --Modificado por: Arnaldo Portillo SPI-439 Corrige los saldos de ATM
         /*IF substr(v_cod_rubro,1,1) <> '2' then --- No sea Cuenta Pasiva MODIFICADO POR ICL 02/08/2012 dc 1286
           v_sal_disponible := v_sal_disponible * (-1);
         END IF;*/

         IF v_cod_rubro IS NULL THEN
            SELECT a.cod_rubro
              INTO v_cod_rubro
              FROM ge_transacciones b, cc_cta_bancarias a
             WHERE a.nro_cuenta = v_nro_cuenta
               AND b.cod_modulo = v_cod_modulo
               AND b.cod_modalidad = v_cod_modalidad
               AND b.cod_transaccion = v_cod_transaccion;
         END IF;

         IF substr(v_cod_rubro,1,1) <> '2' then --- No sea Cuenta Pasiva MODIFICADO POR ICL 02/08/2012 dc 1286
           v_sal_disponible := v_sal_disponible * (-1);
         END IF;

         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_disponible
             WHERE ROWID = v_fila;

            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_disponible
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_disponible, 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN
               ------------------------------
               -- INSERTA SALDO DE CAPITAL --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, v_sal_disponible, v_cod_rubro,
                   v_nro_referencia);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_disponible, 0);
         END;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN ACU_ATM:' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Operaciones vencidas
   PROCEDURE lp_acu_ope_venc IS
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento   VARCHAR2(01);
      v_cod_plazo        NUMBER(03);
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid            VARCHAR2(30);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_rubro2       cb_sal_inventarios.cod_rubro%TYPE;
      v_tip_saldo_prv    VARCHAR2(01);
      v_cod_transaccion2 NUMBER(04);
      v_cod_rubro3       cb_sal_inventarios.cod_rubro%TYPE;
      v_tip_saldo_val    VARCHAR2(01);
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_cod_transaccion3 ge_transacciones.cod_transaccion%TYPE;

      ---cursor
      CURSOR venc IS
       SELECT t.cod_modulo,
                t.cod_modalidad,
                t.cod_oficina,
                t.cod_moneda,
                t.nro_cuenta,
                ge.residente,
                ge.cod_tip_deudor,
                ge.cat_riesgo /*fup_obt_categoria(ge.cat_automatica, ge.cat_subjetiva)*/ cat_riesgo,--DYDMR-5328
                t.est_batch,
                t.sal_tot_batch saldo,
                nvl(ov_previsiones.monto, 0) mto_prevision,
                nvl(ov_valuaciones.mto_valuado, 0) mto_valuado
           FROM ov_cta_vencidas t,
                ge_clientes ge,
                ge_cta_clientes gcc,
                (SELECT a.monto, a.nro_cuenta
                   FROM ov_previsiones a
                  WHERE a.fecha =
                        (SELECT MAX(b.fecha) FROM ov_previsiones b WHERE a.nro_cuenta = b.nro_cuenta)) ov_previsiones,
                (SELECT nvl(ov.tot_val_saldo, 0) -
                        nvl(ov.tot_val_prevision, 0) mto_valuado,
                        ov.nro_cuenta
                   FROM ov_valuaciones ov) ov_valuaciones
          WHERE t.nro_cuenta = gcc.nro_cuenta
            AND ge.cod_persona = gcc.cod_persona
            AND gcc.relacion = 'P'
            AND t.est_batch NOT IN ('I', 'C') --!='C'
            AND ov_previsiones.nro_cuenta(+) = t.nro_cuenta
            AND ov_valuaciones.nro_cuenta(+) = t.nro_cuenta;

   BEGIN
      v_cod_plazo      := 1;
      v_tip_movimiento := 'D';
      v_cod_moneda     := pag_gen.fu_obt_mon_local;

      FOR i IN venc LOOP
         ----cuando es incobrable
         IF (i.est_batch = 'I') THEN
            v_cod_transaccion := 959;
            v_tip_saldo       := 'I';
         END IF;
         IF (i.est_batch <> 'I') THEN
            v_cod_transaccion := 711;
            v_tip_saldo       := 'C';
         END IF;
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL,
                          i.cod_tip_deudor, NULL, NULL, v_tip_movimiento, v_cod_rubro, i.est_batch,
                          /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN
            ---Actualiza operaciones vencidas
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch;
            --       AND COD_RUBRO= v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, i.cod_tip_deudor, NULL,
                      i.cod_moneda, i.est_batch, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo,
                      v_cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.saldo, 0);
                  END IF;

               END IF;

         END;
         ---ACTUALIZA PREVISIONES
         v_tip_saldo_prv    := 'V';
         v_cod_transaccion2 := 730;

         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion2, i.cod_moneda, NULL,
                          i.cod_tip_deudor, NULL, NULL, 'C', v_cod_rubro2, i.est_batch,
                          /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo_prv
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch;
            --       AND COD_RUBRO= v_cod_rubro2;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_prevision, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------
            ---INSERTA PREVISIONES
         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_prevision, 0) <> 0 AND i.est_batch <> 'I' THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, i.cod_tip_deudor, NULL,
                      i.cod_moneda, i.est_batch, v_tip_saldo_prv, v_cod_plazo, NULL, NULL,
                      i.mto_prevision, v_cod_rubro2, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.mto_prevision, 0) <> 0 AND i.est_batch <> 'I' THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.mto_prevision, 0);
                  END IF;

               END IF;
         END;

         ---ACTUALIZA VALUACIONES
         v_tip_saldo_val    := 'L';
         v_cod_transaccion3 := 152;

         --- busco la cuenta que le corresponde al saldo ----
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion3, v_cod_moneda, NULL,
                          i.cod_tip_deudor, i.residente, NULL, 'C', v_cod_rubro3, i.est_batch,
                          /*v_tip_renovacion*/ NULL, i.cat_riesgo, /*v_tip_interes*/ NULL,
                          /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo_val
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = v_cod_moneda
               AND cod_tip_deudor = i.cod_tip_deudor
               AND residente = i.residente
               AND cat_automatica = i.cat_riesgo
               AND situacion = i.est_batch;
            --       AND COD_RUBRO= v_cod_rubro3;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_valuado
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_valuado
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_valuado, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------
            ---INSERTA VALUACIONES
         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_valuado, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, i.cod_tip_deudor,
                      i.residente, v_cod_moneda, i.est_batch, v_tip_saldo_val, v_cod_plazo, NULL,
                      NULL, i.mto_valuado, v_cod_rubro3, v_nro_referencia, NULL, i.cat_riesgo, NULL);

                  IF nvl(i.mto_valuado, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.mto_valuado, 0);
                  END IF;

               END IF;
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_OPE_VENC:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Operaciones vencidas
   ---------------------------------------------------------------------------------------------------------------------
   PROCEDURE lp_cta_embargos IS
      ------------------------------------------------------------------------
      ---- VARIABLES CURSOR MOVIMIENTOS
      ------------------------------------------------------------------------
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_cod_plazo        NUMBER(02);
      v_sal_tot_batch    NUMBER(22, 2);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_fila             VARCHAR2(30);
      /* Modificado por Ana Azorero Abr-10 */
      v_sal_ret_batch  NUMBER(22, 2);
      v_sal_blo_batch  NUMBER(22, 2);
      v_sal_disponible NUMBER(22, 2);
      v_cod_persona    ba_personas.cod_persona%TYPE;

      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                cod_moneda,
                'N',
                1,
                nvl(sal_tot_batch, 0),
                nvl(sal_ret_batch, 0),
                nvl(sal_blo_batch, 0),
                a.nro_cuenta,
                c.cod_persona,
                a.cod_rubro
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a
          WHERE b.cod_persona = c.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND b.relacion = 'P'
            AND a.cod_modalidad = 47
            --AND a.denominacion = 'CUENTA EMBARGADA'-- Comentado por ICL - 21/09/2011 porque ahora se controlaran todas las cuentas de suspenso a pedido de Hector B.
            AND (a.sal_tot_batch <> 0 OR a.sal_ret_batch <> 0 OR a.sal_blo_batch <> 0);
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;

      ------------------------ LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_sal_ret_batch,
                 v_sal_blo_batch,
                 v_nro_cuenta,
                 v_cod_persona,
                 v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;

         --------------------------------------------------------------
         v_sal_disponible := v_sal_tot_batch - v_sal_ret_batch - v_sal_blo_batch;
         if substr(v_cod_rubro,1,1) = '1' then  -- Activo cambio de signo
            v_sal_disponible := v_sal_disponible * -1;
         end if;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'C';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         -- ACTUALIZA SALDO DE CAPITAL --
         --------------------------------
         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_disponible
             WHERE ROWID = v_fila;

            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_disponible
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_disponible, 0);
            END IF;

         EXCEPTION
            WHEN no_data_found THEN
               ------------------------------
               -- INSERTA SALDO DE CAPITAL --
               ------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, v_sal_disponible, v_cod_rubro,
                   v_nro_referencia);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_disponible, 0);
         END;
      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN CTA_EMBARGOS : ' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Garantias
   PROCEDURE lp_acu_garantia IS
      v_tip_saldo      cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo      NUMBER(03);
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;

      ---cursor
      CURSOR garan IS
         SELECT t.cod_modulo,
                t.cod_modalidad,
                g.cod_oficina,
                r.cod_rubro,
                g.cod_moneda,
                g.valor monto,
                g.estado,
                c.cod_tip_deudor,
                g.nro_garantia
           FROM ge_entes         e,
                pr_gar_tipos     tg,
                ge_clientes      c,
                pr_garantias     g,
                ge_transacciones t,
                ge_tip_asientos  ta,
                cb_rubros        r
          WHERE g.cod_persona = c.cod_persona
            AND g.cod_garantia = tg.cod_garantia
            AND g.cod_ent_escribania = e.cod_ente(+)
            AND t.cod_transaccion = tg.cod_transaccion1
            AND t.cod_modalidad = 61
            AND t.cod_tip_asiento = ta.cod_tip_asiento
            AND ta.cod_moneda = g.cod_moneda
            AND g.nro_garantia NOT IN (SELECT xg.nro_garantia
                                         FROM pr_garantias xg
                                        WHERE xg.situacion = 'E'
                                          AND xg.estado = 'C')
            AND g.estado IN ('C', 'I')
            AND r.cod_rub_externo = ta.cod_rubro
            AND g.cod_garantia NOT IN (9, 21, 5)

         UNION
         SELECT t.cod_modulo,
                t.cod_modalidad,
                g.cod_oficina,
                r.cod_rubro,
                g.cod_moneda,
                g.valor monto,
                g.estado,
                c.cod_tip_deudor,
                g.nro_garantia
           FROM ge_entes         e,
                pr_gar_tipos     tg,
                ge_clientes      c,
                pr_garantias     g,
                pr_gar_avales    ga,
                ge_transacciones t,
                ge_tip_asientos  ta,
                cb_rubros        r

          WHERE g.cod_persona = c.cod_persona
            AND t.cod_transaccion = tg.cod_transaccion1
            AND t.cod_tip_asiento = ta.cod_tip_asiento
            AND ta.cod_moneda = g.cod_moneda
            AND g.cod_garantia = tg.cod_garantia
            AND g.cod_ent_escribania = e.cod_ente(+)
            AND g.nro_garantia = ga.nro_garantia
            AND t.cod_tip_asiento = ta.cod_tip_asiento
            AND g.estado = 'C' -- Confirmadas
            AND r.cod_rub_externo = ta.cod_rubro
            AND g.cod_garantia NOT IN (9, 21, 5)

         UNION

         SELECT t.cod_modulo,
                t.cod_modalidad,
                g.cod_oficina,
                r.cod_rubro      cuenta,
                g.cod_moneda,
                g.valor          monto,
                g.estado,
                c.cod_tip_deudor,
                g.nro_garantia
           FROM ge_entes         e,
                pr_gar_tipos     tg,
                ge_clientes      c,
                pr_garantias     g,
                ge_transacciones t,
                ge_tip_asientos  ta,
                cb_rubros        r

          WHERE g.cod_persona = c.cod_persona
            AND g.cod_garantia = tg.cod_garantia
            AND g.cod_ent_escribania = e.cod_ente(+)
            AND t.cod_transaccion = tg.cod_transaccion1
            AND t.cod_tip_asiento = ta.cod_tip_asiento
            AND ta.cod_moneda = g.cod_moneda
            AND g.estado = 'C' -- Confirmadas
            AND g.cod_garantia = 21
            AND r.cod_rub_externo = ta.cod_rubro
            AND g.cod_garantia NOT IN (9, 21, 5)

         UNION
         SELECT t.cod_modulo,
                t.cod_modalidad,
                g.cod_oficina,
                r.cod_rubro      cuenta,
                g.cod_moneda,
                g.valor          monto,
                g.estado,
                c.cod_tip_deudor,
                g.nro_garantia
           FROM ge_entes         e,
                pr_gar_tipos     tg,
                ge_clientes      c,
                pr_garantias     g,
                ge_transacciones t,
                ge_tip_asientos  ta,
                cb_rubros        r

          WHERE g.cod_persona = c.cod_persona
            AND g.cod_garantia = tg.cod_garantia
            AND g.cod_ent_escribania = e.cod_ente(+)
            AND t.cod_transaccion = tg.cod_transaccion1
            AND t.cod_tip_asiento = ta.cod_tip_asiento
            AND ta.cod_moneda = g.cod_moneda
            AND g.estado = 'C' -- Confirmadas
            AND g.cod_garantia = 22
            AND r.cod_rub_externo = ta.cod_rubro
            AND g.cod_garantia NOT IN (9, 21, 5);

   BEGIN
      v_cod_plazo := 1;
      v_tip_saldo := 'C';

      FOR i IN garan LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_tip_deudor = i.cod_tip_deudor
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_garantia;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_garantia, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, i.cod_tip_deudor, NULL,
                      i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL, i.monto, i.cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_garantia, i.monto, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_GARANTIA:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Garantias
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   ---PREVISIONES Y VALUACIONES DE PRESTAMOS
    PROCEDURE lp_acu_prev_prest IS
        v_cod_plazo        NUMBER(02);
        v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
        v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
        v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
        v_cod_transaccion2 ge_transacciones.cod_transaccion%TYPE;
        v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
        v_rowid            VARCHAR2(30);
        v_tip_movimiento   VARCHAR2(1);
        v_tip_saldo_v      VARCHAR2(01);
        v_cod_rubro2       VARCHAR2(15);
        v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
        v_men_error        VARCHAR2(512);

        v_limit CONSTANT PLS_INTEGER := 80000;

        r_tmp cb_sal_inventarios_tmp%ROWTYPE;
        TYPE t_tmp_insert_coll IS TABLE OF cb_sal_inventarios_tmp%ROWTYPE;
        l_tmp_insert t_tmp_insert_coll := t_tmp_insert_coll();

        CURSOR c_inventario IS
            select sum(sal_total) sal_total,
                   t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                   t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                   t.tip_interes, t.cod_rubro,
                   t.tip_renovacion as tip_renovacion,
                   t.cat_automatica as cat_automatica, 
                   t.cod_sit_contable as cod_sit_contable 
            from cb_sal_inventarios_tmp t
            group by
                   t.cod_modulo, t.cod_modalidad, t.cod_oficina, t.cod_sec_contable, t.cod_tip_deudor,
                   t.residente, t.cod_moneda, t.situacion, t.tip_saldo, t.cod_plazo, t.tip_operacion,
                   t.tip_interes, t.cod_rubro,
                   t.tip_renovacion,
                   t.cat_automatica,
                   t.cod_sit_contable;
                   
        TYPE cursor3_type IS TABLE OF c_inventario%ROWTYPE;
        reg3 cursor3_type;

        
        CURSOR prev IS
            SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                   c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda, a.est_batch,
                   cod_plazo, fup_obt_categoria(c.cat_automatica, c.cat_subjetiva) cat_riesgo,
                   nvl(pr_previsiones.monto, 0) mto_prevision
            FROM ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a, 
                 ge_plz_contables d, pr_previsiones_tmp pr_previsiones
            WHERE c.cod_persona = b.cod_persona
              AND b.nro_cuenta = a.nro_cuenta
              AND pr_previsiones.nro_cuenta(+) = a.nro_cuenta
              AND b.relacion = 'P'
              AND a.est_batch NOT IN ('N', 'I')
              AND can_dias = (SELECT MIN(can_dias) FROM ge_plz_contables 
                              WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
              AND (nvl(pr_previsiones.monto, 0)) <> 0
              AND (a.cod_modulo, a.cod_modalidad) not in
                  (select p.cod_modulo, p.cod_modalidad
                     from ge_par_dinamicos p
                    where p.parametro = 'PRE_MAD_EXCEPCION'
                      and p.val_parametro = 'S');
        
        TYPE t_prev_coll IS TABLE OF prev%ROWTYPE;
        l_prev t_prev_coll;

        CURSOR val IS
            SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                   c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda, a.est_batch,
                   pr_valuaciones.estado, cod_plazo, c.cat_riesgo AS cat_riesgo,
                   nvl(pr_valuaciones.tot_val_capital, 0) + nvl(pr_valuaciones.tot_val_interes, 0) +
                   nvl(pr_valuaciones.tot_val_int_ade, 0) - nvl(pr_valuaciones.tot_val_int_devengar, 0) -
                   nvl(pr_valuaciones.tot_val_prevision, 0) - nvl(pr_valuaciones.tot_val_suspenso, 0) tot_val
            FROM ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a, ge_plz_contables d,
                 (SELECT pr.estado, pr.tot_val_capital, pr.tot_val_interes, pr.tot_val_int_ade,
                         pr.tot_val_int_devengar, pr.tot_val_prevision, pr.tot_val_suspenso, 
                         pr.nro_cuenta, pr.cat_automatica
                    FROM pr_valuaciones pr
                   WHERE (pr.estado NOT IN ('N') or (pr.estado = 'C' and pr.cat_automatica > 2))
                 ) pr_valuaciones
            WHERE c.cod_persona = b.cod_persona
              AND b.nro_cuenta = a.nro_cuenta
              AND pr_valuaciones.nro_cuenta(+) = a.nro_cuenta
              AND b.relacion = 'P'
              AND (pr_valuaciones.estado NOT IN ('N', 'I'))
              AND can_dias = (SELECT MIN(can_dias) FROM ge_plz_contables 
                              WHERE can_dias >= a.fec_vencimiento - a.fec_inicio);

        TYPE t_val_coll IS TABLE OF val%ROWTYPE;
        l_val t_val_coll;

        CURSOR prev_cov IS
            SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta,
                   c.cod_sec_contable, c.cod_tip_deudor, c.residente, a.cod_moneda, a.est_batch,
                   cod_plazo, fup_obt_categoria(c.cat_automatica, c.cat_subjetiva) cat_riesgo,
                   nvl(pr_previsiones.mto_pre_total, 0) mto_prevision
            FROM ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a, ge_plz_contables d, 
                 ge_par_dinamicos p, pr_previsiones_tmp pr_previsiones
            WHERE c.cod_persona = b.cod_persona
              AND b.nro_cuenta = a.nro_cuenta
              AND pr_previsiones.nro_cuenta(+) = a.nro_cuenta
              AND b.relacion = 'P'
              AND a.est_batch NOT IN ('N', 'I')
              AND can_dias = (SELECT MIN(can_dias) FROM ge_plz_contables WHERE can_dias >= a.fec_vencimiento - a.fec_inicio)
              AND (nvl(pr_previsiones.monto, 0)) <> 0
              AND p.parametro = 'PRE_MAD_EXCEPCION'
              AND p.val_parametro = 'S'
              AND p.cod_modulo = a.cod_modulo
              AND p.cod_modalidad = a.cod_modalidad;

        TYPE t_prev_cov_coll IS TABLE OF prev_cov%ROWTYPE;
        l_prev_cov t_prev_cov_coll;

       procedure pr_ins_previsiones_tmp is
        begin
           delete pr_previsiones_tmp;
           insert into pr_previsiones_tmp
           select a.nro_cuenta, a.monto , (nvl(a.monto,0) + nvl(a.mto_pre_total,0) ) mto_pre_total
             from pr_previsiones a
            where a.fecha = (select max(b.fecha)
                               from pr_previsiones b
                          where b.nro_cuenta = a.nro_cuenta);
        end;

    BEGIN
        pr_ins_previsiones_tmp;
        
        sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_inventarios_tmp', v_msj);
        IF v_msj IS NOT NULL THEN
            raise_application_error(-20000, v_msj);
        END IF;

        v_tip_movimiento  := 'C';
        v_tip_saldo       := 'V';
        v_cod_transaccion := 730;
        
        IF prev%ISOPEN THEN CLOSE prev; END IF;
        OPEN prev;
        LOOP
            FETCH prev BULK COLLECT INTO l_prev LIMIT v_limit;
            EXIT WHEN l_prev.COUNT = 0;
            
            l_tmp_insert.DELETE;

            FOR i IN 1 .. l_prev.COUNT LOOP
                lp_obt_cod_rubro(l_prev(i).cod_modulo, l_prev(i).cod_modalidad, v_cod_transaccion, l_prev(i).cod_moneda,
                                 l_prev(i).cod_sec_contable, l_prev(i).cod_tip_deudor, l_prev(i).residente, 
                                 l_prev(i).cod_plazo,v_tip_movimiento, v_cod_rubro, l_prev(i).est_batch);

                l_tmp_insert.EXTEND;
                r_tmp := NULL;
                r_tmp.cod_modulo := l_prev(i).cod_modulo; 
                r_tmp.cod_modalidad := l_prev(i).cod_modalidad; 
                r_tmp.cod_oficina := l_prev(i).cod_oficina;
                r_tmp.cod_tip_deudor := l_prev(i).cod_tip_deudor; 
                r_tmp.cod_moneda := l_prev(i).cod_moneda; 
                r_tmp.situacion := l_prev(i).est_batch;
                r_tmp.tip_saldo := v_tip_saldo; 
                r_tmp.cod_plazo := l_prev(i).cod_plazo; 
                r_tmp.sal_total := l_prev(i).mto_prevision;
                r_tmp.cod_rubro := v_cod_rubro; 
                r_tmp.nro_cuenta := l_prev(i).nro_cuenta;
                r_tmp.tip_renovacion := NULL; 
                r_tmp.cat_automatica := NULL; 
                r_tmp.cod_sit_contable := NULL;
                l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
            END LOOP;
            
            IF l_tmp_insert.COUNT > 0 THEN
                BEGIN
                    FORALL i IN 1 .. l_tmp_insert.COUNT SAVE EXCEPTIONS
                        INSERT INTO cb_sal_inventarios_tmp VALUES l_tmp_insert(i);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_men_error := SQLERRM;
                        raise_application_error(-20000, 'Ins.cb_sal_inventarios_tmp (prev) ' || v_men_error);
                END;
            END IF;
            COMMIT;
            
        END LOOP;
        CLOSE prev;

        v_cod_transaccion2 := 152;
        v_tip_saldo_v      := 'L';
        v_cod_moneda       := pag_gen.fu_obt_mon_local;
        
        IF val%ISOPEN THEN CLOSE val; END IF;
        OPEN val;
        LOOP
            FETCH val BULK COLLECT INTO l_val LIMIT v_limit;
            EXIT WHEN l_val.COUNT = 0;
            
            l_tmp_insert.DELETE;

            FOR x IN 1 .. l_val.COUNT LOOP
                lp_obt_cod_rubro(l_val(x).cod_modulo, l_val(x).cod_modalidad, v_cod_transaccion2, v_cod_moneda,
                                 l_val(x).cod_sec_contable, l_val(x).cod_tip_deudor, l_val(x).residente, 
                                 l_val(x).cod_plazo, 'C', v_cod_rubro2, l_val(x).estado, NULL, l_val(x).cat_riesgo);

               if nvl(l_val(x).tot_val, 0) <> 0 then
                l_tmp_insert.EXTEND;
                r_tmp := NULL;
                r_tmp.cod_modulo := l_val(x).cod_modulo; 
                r_tmp.cod_modalidad := l_val(x).cod_modalidad; 
                r_tmp.cod_oficina := l_val(x).cod_oficina;
                r_tmp.cod_sec_contable := l_val(x).cod_sec_contable; 
                r_tmp.cod_tip_deudor := l_val(x).cod_tip_deudor; 
                r_tmp.residente := l_val(x).residente;
                r_tmp.cod_moneda := v_cod_moneda; 
                r_tmp.situacion := l_val(x).est_batch; 
                r_tmp.tip_saldo := v_tip_saldo_v;
                r_tmp.cod_plazo := l_val(x).cod_plazo; 
                r_tmp.sal_total := l_val(x).tot_val; 
                r_tmp.cod_rubro := v_cod_rubro2;
                r_tmp.cat_automatica := l_val(x).cat_riesgo; 
                r_tmp.nro_cuenta := l_val(x).nro_cuenta;
                r_tmp.tip_renovacion := NULL; 
                r_tmp.cod_sit_contable := NULL;
                l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
               end if;
            END LOOP;
            
            IF l_tmp_insert.COUNT > 0 THEN
                BEGIN
                    FORALL i IN 1 .. l_tmp_insert.COUNT SAVE EXCEPTIONS
                        INSERT INTO cb_sal_inventarios_tmp VALUES l_tmp_insert(i);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_men_error := SQLERRM;
                        raise_application_error(-20000, 'Ins.cb_sal_inventarios_tmp (val) ' || v_men_error);
                END;
            END IF;
            COMMIT;
            
        END LOOP;
        CLOSE val;
        
        v_tip_movimiento  := 'C';
        v_tip_saldo       := 'V';
        v_cod_transaccion := 9730;

        IF prev_cov%ISOPEN THEN CLOSE prev_cov; END IF;
        OPEN prev_cov;
        LOOP
            FETCH prev_cov BULK COLLECT INTO l_prev_cov LIMIT v_limit;
            EXIT WHEN l_prev_cov.COUNT = 0;
            
            l_tmp_insert.DELETE;
            
            FOR i IN 1 .. l_prev_cov.COUNT LOOP
                lp_obt_cod_rubro(l_prev_cov(i).cod_modulo, l_prev_cov(i).cod_modalidad, v_cod_transaccion, l_prev_cov(i).cod_moneda,
                                 l_prev_cov(i).cod_sec_contable, l_prev_cov(i).cod_tip_deudor, l_prev_cov(i).residente, 
                                 l_prev_cov(i).cod_plazo, v_tip_movimiento, v_cod_rubro, l_prev_cov(i).est_batch);
                                 
                l_tmp_insert.EXTEND;
                r_tmp := NULL;
                r_tmp.cod_modulo := l_prev_cov(i).cod_modulo; 
                r_tmp.cod_modalidad := l_prev_cov(i).cod_modalidad; 
                r_tmp.cod_oficina := l_prev_cov(i).cod_oficina;
                r_tmp.cod_moneda := l_prev_cov(i).cod_moneda; 
                r_tmp.cod_tip_deudor := l_prev_cov(i).cod_tip_deudor;
                r_tmp.situacion := l_prev_cov(i).est_batch; 
                r_tmp.tip_saldo := v_tip_saldo; 
                r_tmp.cod_plazo := l_prev_cov(i).cod_plazo;
                r_tmp.sal_total := l_prev_cov(i).mto_prevision; 
                r_tmp.cod_rubro := v_cod_rubro; 
                r_tmp.nro_cuenta := l_prev_cov(i).nro_cuenta;
                r_tmp.tip_renovacion := NULL; 
                r_tmp.cat_automatica := NULL; 
                r_tmp.cod_sit_contable := NULL;
                l_tmp_insert(l_tmp_insert.LAST) := r_tmp;
            END LOOP;
            
            IF l_tmp_insert.COUNT > 0 THEN
                BEGIN
                    FORALL i IN 1 .. l_tmp_insert.COUNT SAVE EXCEPTIONS
                        INSERT INTO cb_sal_inventarios_tmp VALUES l_tmp_insert(i);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_men_error := SQLERRM;
                        raise_application_error(-20000, 'Ins.cb_sal_inventarios_tmp (prev_cov) ' || v_men_error);
                END;
            END IF;
            COMMIT;
            
        END LOOP;
        CLOSE prev_cov;
        
        IF c_inventario%ISOPEN THEN CLOSE c_inventario; END IF;
        OPEN c_inventario;
        LOOP
            FETCH c_inventario BULK COLLECT INTO reg3 LIMIT 80000;
            EXIT WHEN reg3.count = 0;
            
            FOR j IN 1 .. reg3.count LOOP
                SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                INSERT INTO cb_sal_inventarios
                   (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                    residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                    tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                    cat_automatica, cod_sit_contable)
                VALUES
                   (reg3(j).cod_modulo, reg3(j).cod_modalidad, reg3(j).cod_oficina,reg3(j).cod_sec_contable, reg3(j).cod_tip_deudor,
                    reg3(j).residente, reg3(j).cod_moneda, reg3(j).situacion, reg3(j).tip_saldo, reg3(j).cod_plazo, reg3(j).tip_operacion,
                    reg3(j).tip_interes, reg3(j).sal_total, reg3(j).cod_rubro, v_nro_referencia, reg3(j).tip_renovacion,
                    reg3(j).cat_automatica, reg3(j).cod_sit_contable);

                UPDATE cb_sal_inventarios_tmp t
                   SET nro_referencia = v_nro_referencia
                 WHERE t.cod_modulo = reg3(j).cod_modulo
                   AND t.cod_modalidad = reg3(j).cod_modalidad
                   AND t.cod_oficina = reg3(j).cod_oficina
                   AND nvl(t.cod_sec_contable,'X') = nvl(reg3(j).cod_sec_contable,'X')
                   AND t.cod_tip_deudor = reg3(j).cod_tip_deudor
                   AND nvl(t.residente,'X') = nvl(reg3(j).residente,'X')
                   AND t.cod_moneda = reg3(j).cod_moneda
                   AND t.situacion = reg3(j).situacion
                   AND t.tip_saldo = reg3(j).tip_saldo
                   AND t.cod_plazo = reg3(j).cod_plazo
                   AND nvl(t.tip_operacion,'X') = nvl(reg3(j).tip_operacion,'X')
                   AND nvl(t.tip_interes,'X') = nvl(reg3(j).tip_interes,'X')
                   AND nvl(t.cod_rubro,'X') = nvl(reg3(j).cod_rubro,'X')
                   AND nvl(t.tip_renovacion,'X') = nvl(reg3(j).tip_renovacion,'X')
                   AND nvl(t.cat_automatica,'1') = nvl(reg3(j).cat_automatica,'1')
                   AND nvl(t.cod_sit_contable,'1') = nvl(reg3(j).cod_sit_contable,'1');
            END LOOP;
            COMMIT;
        END LOOP;
        CLOSE c_inventario;
        INSERT /*+ APPEND */ INTO cb_sal_inventarios_det
            (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
        SELECT a.nro_referencia, a.nro_cuenta, nvl(a.sal_total, 0), 0
        FROM cb_sal_inventarios_tmp a
        WHERE a.nro_referencia IS NOT NULL;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20000, 'ERROR EN LP_ACU_PREV_PREST:' || SQLERRM);
    END;
   ----------------------------------------------------------------------------------------------------------------------
   --fin de previsiones y valuaciones de prestamos
   ----------------------------------------------------------------------------------------------------------------------
   ----------------------------------------------------------------------------------------------------------------------
   -- Valuacion de sobregiros
   PROCEDURE lp_acu_val_sobr IS
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_con_transacciones.cod_transaccion%TYPE;
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_moneda      cb_sal_inventarios.cod_moneda%TYPE;

      ---cursor
      CURSOR val IS
      SELECT c.cod_modulo,
                c.cod_modalidad,
                c.cod_oficina,
                c.nro_cuenta,
                ge.cod_sec_contable,
                ge.cod_tip_deudor,
                ge.residente,
                ge.cat_riesgo /*fup_obt_categoria(ge.cat_automatica, ge.cat_subjetiva)*/ cat_riesgo,--DYDMR-5328
                c.cod_moneda,
                c.est_batch,
                v.situacion,
                (nvl(v.tot_valuacion, 0)-nvl(v.tot_val_prevision,0)) mto_valuado
           FROM cc_valuaciones v, cc_cta_corrientes c, ge_clientes ge, ge_cta_clientes gc
          WHERE c.nro_cuenta = v.nro_cuenta
            AND ge.cod_persona = gc.cod_persona
            AND gc.nro_cuenta = c.nro_cuenta
            AND gc.relacion = 'P'
            AND (nvl(v.estado,v.situacion) not in ('N','I') or (nvl(v.estado,v.situacion) = 'S' and v.cat_automatica >2))
            and (nvl(v.tot_valuacion, 0)-nvl(v.tot_val_prevision,0))<>0;

   BEGIN
      v_tip_saldo       := 'L'; --valuacion.
      v_tip_movimiento  := 'C';
      v_cod_transaccion := 152;
      v_cod_plazo       := 1;
      v_cod_moneda      := pag_gen.fu_obt_mon_local;

      FOR i IN val LOOP
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, v_cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, 1, v_tip_movimiento,
                          v_cod_rubro, i.situacion, /*v_tip_renovacion*/ NULL, i.cat_riesgo,
                          /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = v_cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch
               AND cat_automatica = i.cat_riesgo
               AND residente = i.residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_valuado
             WHERE nro_referencia = v_nro_referencia;
            --and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_valuado
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_valuado, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_valuado, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                      i.cod_tip_deudor, i.residente, v_cod_moneda, i.est_batch, v_tip_saldo,
                      v_cod_plazo, NULL, NULL, i.mto_valuado, nvl(v_cod_rubro, 0), v_nro_referencia,
                      NULL, i.cat_riesgo, NULL);

                  IF nvl(i.mto_valuado, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.mto_valuado, 0);
                  END IF;

               END IF;
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_VAL_SOBR:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de valuaciones de sobregiros
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Previsi?n de sobregiros
    PROCEDURE lp_acu_prev_sobr IS
      v_cod_modulo      cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad   cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento  VARCHAR2(01);
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_tra_contingente ge_transacciones.cod_transaccion%TYPE;
      v_cod_rub_contingente cb_sal_inventarios.cod_rubro%TYPE;

      ---cursor
      CURSOR prev IS
         SELECT c.cod_modulo,
                c.cod_modalidad,
                c.cod_oficina,
                c.nro_cuenta,
                ge.cod_sec_contable,
                ge.cod_tip_deudor,
                ge.residente,
                fup_obt_categoria(ge.cat_automatica, ge.cat_subjetiva) cat_riesgo,
                v.fecha,
                c.cod_moneda,
                nvl(r.sit_deuda, 'N') est_batch, --DYDMR-2839 - 25.05.2016
                nvl(v.monto, 0)-nvl(v.tot_prv_contingencia,0) mto_prevision,
                nvl(v.tot_prv_contingencia,0) tot_prv_contingencia
           FROM cc_previsiones    v,
                cc_cta_corrientes c,
                ge_clientes       ge,
                ge_cta_clientes   gc,
                cc_sobregiros_res r
          WHERE c.nro_cuenta = v.nro_cuenta
            AND ge.cod_persona = gc.cod_persona
            AND gc.nro_cuenta = c.nro_cuenta
            AND gc.relacion = 'P'
            AND c.est_batch != 'C' --cancelado
            AND v.fecha =
                (SELECT MAX(b.fecha) FROM cc_previsiones b WHERE c.nro_cuenta = b.nro_cuenta)
            AND r.nro_cuenta(+) = c.nro_cuenta;

   BEGIN
      v_tip_saldo       := 'V'; --prevision.
      v_tip_movimiento  := 'C';
      v_cod_transaccion := 730;
      v_cod_plazo       := 1;

      FOR i IN prev LOOP
         lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_transaccion, i.cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, 1, v_tip_movimiento,
                          v_cod_rubro, i.est_batch, /*v_tip_renovacion*/ NULL, i.cat_riesgo,
                          /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch
               AND cat_automatica = i.cat_riesgo
               AND residente = i.residente
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_prevision, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN

               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion, cat_automatica,
                   cod_sit_contable)
               VALUES
                  (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                   i.cod_tip_deudor, i.residente, i.cod_moneda, i.est_batch, v_tip_saldo,
                   v_cod_plazo, NULL, NULL, i.mto_prevision, v_cod_rubro, v_nro_referencia, NULL,
                   i.cat_riesgo, NULL);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.mto_prevision, 0);

         END;

         ---Inventario Previsiones contingentes
         v_cod_tra_contingente := 756;
          lp_obt_cod_rubro(i.cod_modulo, i.cod_modalidad, v_cod_tra_contingente, i.cod_moneda,
                          i.cod_sec_contable, i.cod_tip_deudor, i.residente, 1, v_tip_movimiento,
                          v_cod_rub_contingente, i.est_batch, /*v_tip_renovacion*/ NULL, i.cat_riesgo,
                          /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sec_contable = i.cod_sec_contable
               AND cod_tip_deudor = i.cod_tip_deudor
               AND situacion = i.est_batch
               AND cat_automatica = i.cat_riesgo
               AND residente = i.residente
               AND cod_rubro = v_cod_rub_contingente;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.tot_prv_contingencia
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.tot_prv_contingencia
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.tot_prv_contingencia, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN

               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion, cat_automatica,
                   cod_sit_contable)
               VALUES
                  (i.cod_modulo, i.cod_modalidad, i.cod_oficina, i.cod_sec_contable,
                   i.cod_tip_deudor, i.residente, i.cod_moneda, i.est_batch, v_tip_saldo,
                   v_cod_plazo, NULL, NULL, i.tot_prv_contingencia, v_cod_rub_contingente, v_nro_referencia, NULL,
                   i.cat_riesgo, NULL);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.tot_prv_contingencia, 0);

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_PREV_SOBR:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de previsiones de sobregiros
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Garantias Computables y no computables
   PROCEDURE lp_acu_gara_comp IS
      v_tip_saldo      VARCHAR2(01);
      v_tip_saldo2     VARCHAR2(01);
      v_cod_plazo      NUMBER(03);
      v_rowid          VARCHAR2(30);
      v_nro_referencia cb_sal_inventarios.nro_referencia%TYPE;
      v_fec_actual     DATE := pag_cal.fu_obt_fec_actual(6);

      ---CURSOR PARA GARANTIAS COMPUTABLES
      CURSOR comp IS
         SELECT m.cod_modulo,
                m.cod_modalidad,
                m.cod_oficina,
                a.cod_rubro,
                m.cod_moneda,
                NULL            estado,
                NULL            cod_tip_deudor,
                m.nro_documento nro_garantia,
                g.cod_garantia,
                m.monto         mto_computable
           FROM ge_movimientos m, pr_gar_tipos g, ge_transacciones t, ge_tip_asientos a
          WHERE m.fecha = v_fec_actual
            AND m.cod_modulo = g.cod_modulo
            AND m.cod_modalidad = g.cod_modalidad
            AND m.cod_transaccion = g.cod_transaccion1
            AND m.referencia = g.cod_garantia
            AND m.cod_tra_padre = 200 --- Calculo de Garantias
            AND m.monto > 0
            AND m.reversado = 'N'
            AND g.cod_modulo = t.cod_modulo
            AND g.cod_modalidad = t.cod_modalidad
            AND g.cod_transaccion1 = t.cod_transaccion
            AND m.cod_moneda = a.cod_moneda
            AND ((t.cod_tip_asiento = a.cod_tip_asiento OR t.cod_tip_asiento2 = a.cod_tip_asiento) AND
                a.tip_movimiento = 'D');

      CURSOR comp_cre IS
         SELECT m.cod_modulo,
                m.cod_modalidad,
                m.cod_oficina,
                a.cod_rubro,
                m.cod_moneda,
                NULL estado,
                NULL cod_tip_deudor,
                m.nro_documento nro_garantia,
                g.cod_garantia,
                (m.monto * -1) mto_computable
           FROM ge_movimientos m, pr_gar_tipos g, ge_transacciones t, ge_tip_asientos a
          WHERE m.fecha = v_fec_actual
            AND m.cod_modulo = g.cod_modulo
            AND m.cod_modalidad = g.cod_modalidad
            AND m.cod_transaccion = g.cod_transaccion1
            AND m.referencia = g.cod_garantia
            AND m.cod_tra_padre = 200 --- Calculo de Garantias
            AND m.monto > 0
            AND m.reversado = 'N'
            AND g.cod_modulo = t.cod_modulo
            AND g.cod_modalidad = t.cod_modalidad
            AND g.cod_transaccion1 = t.cod_transaccion
            AND m.cod_moneda = a.cod_moneda
            AND ((t.cod_tip_asiento = a.cod_tip_asiento OR t.cod_tip_asiento2 = a.cod_tip_asiento) AND
                a.tip_movimiento = 'C');
      --CURSOR PARA GARANTIAS NO COMPUTABLES
      ---cursor
      CURSOR nocom IS
         SELECT m.cod_modulo,
                m.cod_modalidad,
                m.cod_oficina,
                a.cod_rubro,
                m.cod_moneda,
                NULL            estado,
                NULL            cod_tip_deudor,
                m.nro_documento nro_garantia,
                g.cod_garantia,
                m.monto         mto_no_compu
           FROM ge_movimientos m, pr_gar_tipos g, ge_transacciones t, ge_tip_asientos a
          WHERE m.fecha = v_fec_actual
            AND m.cod_modulo = g.cod_modulo
            AND m.cod_modalidad = g.cod_modalidad
            AND m.cod_transaccion = g.cod_transaccion2
            AND m.referencia = g.cod_garantia
            AND m.cod_tra_padre = 200 --- Calculo de Garantias
            AND m.monto > 0
            AND m.reversado = 'N'
            AND g.cod_modulo = t.cod_modulo
            AND g.cod_modalidad = t.cod_modalidad
            AND g.cod_transaccion2 = t.cod_transaccion
            AND m.cod_moneda = a.cod_moneda
            AND ((t.cod_tip_asiento = a.cod_tip_asiento OR t.cod_tip_asiento2 = a.cod_tip_asiento) AND
                a.tip_movimiento = 'D');
      CURSOR nocom_cre IS
         SELECT m.cod_modulo,
                m.cod_modalidad,
                m.cod_oficina,
                a.cod_rubro,
                m.cod_moneda,
                NULL estado,
                NULL cod_tip_deudor,
                m.nro_documento nro_garantia,
                g.cod_garantia,
                (m.monto * -1) mto_no_compu
           FROM ge_movimientos m, pr_gar_tipos g, ge_transacciones t, ge_tip_asientos a
          WHERE m.fecha = v_fec_actual
            AND m.cod_modulo = g.cod_modulo
            AND m.cod_modalidad = g.cod_modalidad
            AND m.cod_transaccion = g.cod_transaccion2
            AND m.referencia = g.cod_garantia
            AND m.cod_tra_padre = 200 --- Calculo de Garantias
            AND m.monto > 0
            AND m.reversado = 'N'
            AND g.cod_modulo = t.cod_modulo
            AND g.cod_modalidad = t.cod_modalidad
            AND g.cod_transaccion2 = t.cod_transaccion
            AND m.cod_moneda = a.cod_moneda
            AND ((t.cod_tip_asiento = a.cod_tip_asiento OR t.cod_tip_asiento2 = a.cod_tip_asiento) AND
                a.tip_movimiento = 'C');

   BEGIN
      v_cod_plazo := 1;
      v_tip_saldo := 'E'; -- Garantias Computables

      FOR i IN comp LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sit_contable = i.cod_garantia
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(i.mto_computable, 0)
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(i.mto_computable, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_garantia;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_garantia, i.mto_computable, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_computable, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL /*i.cod_tip_deudor*/,
                      NULL, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL,
                      i.mto_computable, i.cod_rubro, v_nro_referencia, NULL, NULL, i.cod_garantia);

                  IF nvl(i.mto_computable, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_garantia, i.mto_computable, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

      FOR i IN comp_cre LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_sit_contable = i.cod_garantia
               AND cod_rubro = i.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + nvl(i.mto_computable, 0)
             WHERE nro_referencia = v_nro_referencia;
            --       and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + nvl(i.mto_computable, 0)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_garantia;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_garantia, i.mto_computable, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_computable, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL /*i.cod_tip_deudor*/,
                      NULL, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo, NULL, NULL,
                      i.mto_computable, i.cod_rubro, v_nro_referencia, NULL, NULL, i.cod_garantia);

                  IF nvl(i.mto_computable, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_garantia, i.mto_computable, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

      --GARANTIAS NO COMPUTABLES

      v_cod_plazo  := 1;
      v_tip_saldo2 := 'J'; --- Garantias No computables

      FOR j IN nocom LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = j.cod_modulo
               AND cod_modalidad = j.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo2
               AND cod_oficina = j.cod_oficina
               AND cod_moneda = j.cod_moneda
               AND cod_sit_contable = j.cod_garantia
               AND cod_rubro = j.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + j.mto_no_compu
             WHERE nro_referencia = v_nro_referencia;
            --and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + j.mto_no_compu
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = j.nro_garantia;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, j.nro_garantia, j.mto_no_compu, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(j.mto_no_compu, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (j.cod_modulo, j.cod_modalidad, j.cod_oficina, NULL, NULL /*j.cod_tip_deudor*/,
                      NULL, j.cod_moneda, NULL, v_tip_saldo2, v_cod_plazo, NULL, NULL,
                      j.mto_no_compu, j.cod_rubro, v_nro_referencia, NULL, NULL, j.cod_garantia);

                  IF nvl(j.mto_no_compu, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, j.nro_garantia, j.mto_no_compu, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

      FOR j IN nocom_cre LOOP

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = j.cod_modulo
               AND cod_modalidad = j.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo2
               AND cod_oficina = j.cod_oficina
               AND cod_moneda = j.cod_moneda
               AND cod_sit_contable = j.cod_garantia
               AND cod_rubro = j.cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + j.mto_no_compu
             WHERE nro_referencia = v_nro_referencia;
            --and rowid= v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + j.mto_no_compu
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = j.nro_garantia;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, j.nro_garantia, j.mto_no_compu, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(j.mto_no_compu, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (j.cod_modulo, j.cod_modalidad, j.cod_oficina, NULL, NULL /*j.cod_tip_deudor*/,
                      NULL, j.cod_moneda, NULL, v_tip_saldo2, v_cod_plazo, NULL, NULL,
                      j.mto_no_compu, j.cod_rubro, v_nro_referencia, NULL, NULL, j.cod_garantia);

                  IF nvl(j.mto_no_compu, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, j.nro_garantia, j.mto_no_compu, 0);
                  END IF;

               END IF;

         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_GARA_COMP:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Garantias Computables y no computables
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Bienes Adjudicados
   PROCEDURE lp_acu_bie_adju IS
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_transaccion2 ge_transacciones.cod_transaccion%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento   VARCHAR2(01);
      v_cod_plazo        NUMBER(03);
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rubro2       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid            VARCHAR2(30);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_tip_prev         VARCHAR2(01);
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;

      ---cursor
      CURSOR adju IS
         SELECT b.cod_bien,
                b.cod_oficina,
                b.cod_moneda,
                b.estado,
                nvl(b.val_tasacion, 0) saldo,
                nvl(b.mto_prevision, 0) mto_prevision
           FROM bu_bienes b
          WHERE b.estado = 'C'; ---Se agrega el filtro de estado='C'---Nilsa Aponte - Simgia S.R.L. Julio 2011;

   BEGIN
      v_cod_plazo       := 1;
      v_tip_movimiento  := 'D';
      v_cod_transaccion := 2602;
      v_tip_saldo       := 'C';
      v_cod_modulo      := 26;
      v_cod_modalidad   := 261;

      FOR i IN adju LOOP
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion, i.cod_moneda, NULL
                          /*i.cod_sec_contable*/, /*i.cod_tip_deudor*/ NULL, NULL /*i.residente*/,
                          NULL, v_tip_movimiento, v_cod_rubro, NULL /*i.estado*/,
                          /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);

         BEGIN

            SELECT nro_referencia
              INTO v_nro_referencia
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_saldo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND situacion = i.estado
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.saldo
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.cod_bien;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.cod_bien, i.saldo, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.saldo, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_oficina, NULL, NULL, NULL, i.cod_moneda,
                      i.estado, v_tip_saldo, v_cod_plazo, NULL, NULL, i.saldo, v_cod_rubro,
                      v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.saldo, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.cod_bien, i.saldo, 0);
                  END IF;
               END IF;
         END;

         ---Actualiza monto previsi?n
         v_tip_prev         := 'V';
         v_cod_transaccion2 := 730;
         lp_obt_cod_rubro(v_cod_modulo, v_cod_modalidad, v_cod_transaccion2, i.cod_moneda, NULL
                          /*i.cod_sec_contable*/, /*i.cod_tip_deudor*/ NULL, NULL /*i.residente*/,
                          NULL, 'C', v_cod_rubro2, NULL /*i.estado*/, /*v_tip_renovacion*/ NULL,
                          /*v_cat_riesgo*/ NULL, /*v_tip_interes*/ NULL, /*v_tip_operacion*/ NULL,
                          /*v_cod_sit_contable*/ NULL);
         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND tip_saldo = v_tip_prev
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND situacion = i.estado
               AND cod_rubro = v_cod_rubro2;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.mto_prevision
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.cod_bien;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.cod_bien, i.mto_prevision, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.mto_prevision, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (v_cod_modulo, v_cod_modalidad, i.cod_oficina, NULL /*i.cod_sec_contable*/,
                      NULL, NULL /*i.residente*/, i.cod_moneda, i.estado, v_tip_prev, v_cod_plazo,
                      NULL, NULL, i.mto_prevision, v_cod_rubro2, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.mto_prevision, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.cod_bien, i.mto_prevision, 0);
                  END IF;
               END IF;
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_BIE_ADJU:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Bienes Ajdudicados
   ---------------------------------------------------------------------------------------------------------------------
   -- Forward
   PROCEDURE lp_acu_forward IS
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_transaccion2 ge_transacciones.cod_transaccion%TYPE;
      v_cod_transaccion3 ge_transacciones.cod_transaccion%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rubro2       cb_sal_inventarios.cod_rubro%TYPE;
      v_cod_rubro3       cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_tip_sal_ade      cb_sal_inventarios.tip_saldo%TYPE;
      v_mto_devengado    lc_ope_futuras.monto%TYPE;

      v_redondeo         NUMBER(03) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_cod_moneda, NULL);
      v_fec_pri_mes      date;
      v_fec_ult_mes      date;
      v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;

      ---cursor
      CURSOR forw IS
      -- VV Ajuste de cursor segun analisis tecnico del AP 1880
         SELECT b.nro_cuenta,
                b.nro_operacion,
                b.cod_modulo,
                b.cod_mad_transaccion,
                b.cod_oficina,
                b.cod_moneda,
                b.estado,
                c.cod_sec_contable,
                c.cod_tip_deudor,
                c.residente,
                round(nvl(b.monto, 0) * nvl(b.cot_vencimiento, 0), v_redondeo) saldo_fut,
                nvl(b.monto, 0) saldo_ext,
                (nvl(deve.mto_dev, 0)) mto_dev_acu,
                fug_obt_plz_contable(b.fec_vencimiento - b.fec_operacion) plazo,
                /* DYDMR-1953 FM 25/06/2015
                round(nvl(b.monto, 0) * pag_gen.fu_obt_cotizacion(b.cod_moneda, b.fec_operacion),
                      v_redondeo) mto_equ_base,*/
                round(nvl(b.monto, 0) * nvl(b.cotizacion, 0), v_redondeo) mto_equ_base,
                b.cot_vencimiento
           FROM lc_ope_futuras b,
                ge_clientes c,
                (SELECT d.nro_cuenta, d.nro_operacion, SUM(d.mto_dev_acumulado) mto_dev
                   FROM lc_devengados d
                  GROUP BY d.nro_cuenta, d.nro_operacion) deve
          WHERE b.estado IN ('N', 'L')
            AND c.cod_persona = b.cod_persona
            AND b.nro_operacion = deve.nro_operacion(+)
            -- DYDMR-5087 Se ajusta para que no considere las op futura ya liquidadas
            AND ( b.fec_liquidacion IS NULL OR
                ( b.fec_liquidacion BETWEEN v_fec_pri_mes and v_fec_ult_mes) )
            and ((v_ind_dev_val_economico = 'N') or
                 (v_ind_dev_val_economico = 'S' and
                  exists (select 1
                            from ba_cod_referencias x
                           where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                             and x.val_minimo = b.nro_cuenta||'#'||b.nro_operacion)));

   BEGIN
      v_tip_saldo   := 'C';
      v_tip_sal_ade := 'A';
      --- DYDMR-5087 29/09/16
      Begin PAG_CAL.PR_OBT_DAT_CALENDAR(7);End;
      v_fec_pri_mes := pag_cal.g_pri_dia_mes;
      v_fec_ult_mes := pag_cal.g_ult_dia_mes;
      v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
      ---
      FOR i IN forw LOOP
         IF i.estado = 'N' THEN
            v_cod_transaccion := 357;
            IF i.cod_mad_transaccion = 71 THEN
               v_tip_movimiento  := 'C';
            ELSE
               v_tip_movimiento  := 'D';
            END IF;
            lp_obt_cod_rubro(i.cod_modulo, i.cod_mad_transaccion, v_cod_transaccion, v_cod_moneda,
                             i.cod_sec_contable, i.cod_tip_deudor, i.residente, i.plazo,
                             v_tip_movimiento, v_cod_rubro, NULL, NULL, NULL, NULL, NULL, NULL);

            BEGIN
               ---Actualiza capital en moneda LOCAL
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = i.cod_modulo
                  AND cod_modalidad = i.cod_mad_transaccion
                  AND cod_plazo = i.plazo
                  AND tip_saldo = v_tip_saldo
                  AND cod_oficina = i.cod_oficina
                  AND cod_moneda = v_cod_moneda
                  AND situacion = i.estado
                  AND cod_sec_contable = i.cod_sec_contable
                  AND residente = i.residente
                  AND cod_rubro = v_cod_rubro;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + i.saldo_fut
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + i.saldo_fut
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_operacion; -- JIRA-1712

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_operacion, i.saldo_fut, 0);
               END IF;

               ------------------------------------------------------------------------------------------------------------------

            EXCEPTION
               WHEN no_data_found THEN
                  IF nvl(i.saldo_fut, 0) <> 0 THEN
                     SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (i.cod_modulo, i.cod_mad_transaccion, i.cod_oficina, i.cod_sec_contable,
                         i.cod_tip_deudor, i.residente, v_cod_moneda, i.estado, v_tip_saldo, i.plazo,
                         NULL, NULL, i.saldo_fut, v_cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                     IF nvl(i.saldo_ext, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_operacion, i.saldo_fut, 0);
                     END IF;
                  END IF;
            END;
            v_cod_transaccion2 := 356;
            IF i.cod_mad_transaccion = 71 THEN
               v_tip_movimiento  := 'D';
            ELSE
               v_tip_movimiento  := 'C';
            END IF;
            lp_obt_cod_rubro(i.cod_modulo, i.cod_mad_transaccion, v_cod_transaccion2, i.cod_moneda,
                             i.cod_sec_contable, i.cod_tip_deudor, i.residente, i.plazo,
                             v_tip_movimiento, v_cod_rubro2, NULL , NULL, NULL, NULL,  NULL, NULL);

            BEGIN
               ---Actualiza capital en moneda EXTRANJERA
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = i.cod_modulo
                  AND cod_modalidad = i.cod_mad_transaccion
                  AND cod_plazo = i.plazo
                  AND tip_saldo = v_tip_saldo
                  AND cod_oficina = i.cod_oficina
                  AND cod_moneda = i.cod_moneda
                  AND situacion = i.estado
                  AND cod_sec_contable = i.cod_sec_contable
                  AND residente = i.residente
                  AND cod_rubro = v_cod_rubro2;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + i.saldo_ext
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + i.saldo_ext
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_operacion;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_operacion, i.saldo_ext, 0);
               END IF;

               ------------------------------------------------------------------------------------------------------------------

            EXCEPTION
               WHEN no_data_found THEN
                  IF nvl(i.saldo_ext, 0) <> 0 THEN
                     SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (i.cod_modulo, i.cod_mad_transaccion, i.cod_oficina, i.cod_sec_contable,
                         i.cod_tip_deudor, i.residente, i.cod_moneda, i.estado, v_tip_saldo, i.plazo,
                         NULL, NULL, i.saldo_ext, v_cod_rubro2, v_nro_referencia, NULL, NULL, NULL);

                     IF nvl(i.saldo_ext, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_operacion, i.saldo_ext, 0);
                     END IF;
                  END IF;
            END;
         END IF;

         IF i.cod_mad_transaccion = 71 THEN
            IF nvl(i.mto_equ_base, 0) >= nvl(i.saldo_fut, 0) THEN
               v_mto_devengado := nvl(i.mto_equ_base, 0) - nvl(i.saldo_fut, 0) - nvl(i.mto_dev_acu, 0);
            ELSE
               v_mto_devengado := nvl(i.mto_equ_base, 0) - nvl(i.saldo_fut, 0) + nvl(i.mto_dev_acu, 0);
            END IF;
         ELSE
            IF nvl(i.saldo_fut, 0) >= nvl(i.mto_equ_base, 0) THEN
               v_mto_devengado := nvl(i.saldo_fut, 0) - nvl(i.mto_equ_base, 0) - nvl(i.mto_dev_acu, 0);
            ELSE
               v_mto_devengado := nvl(i.saldo_fut, 0) - nvl(i.mto_equ_base, 0) + nvl(i.mto_dev_acu, 0);
            END IF;
         END IF;

         IF v_mto_devengado > 0 THEN
            v_cod_transaccion3 := 358;
            v_tip_movimiento   := 'C';
         ELSE
            v_cod_transaccion3 := 359;
            v_tip_movimiento   := 'D';
            v_mto_devengado    := abs(v_mto_devengado);
         END IF;

         IF nvl(v_mto_devengado, 0) > 0 THEN
            lp_obt_cod_rubro(i.cod_modulo, i.cod_mad_transaccion, v_cod_transaccion3, v_cod_moneda,
                             i.cod_sec_contable, i.cod_tip_deudor, i.residente, i.plazo,
                             v_tip_movimiento, v_cod_rubro3, NULL, NULL, NULL, NULL, NULL, NULL);

            BEGIN
               ---Actualiza Prima a devengar
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = i.cod_modulo
                  AND cod_modalidad = i.cod_mad_transaccion
                  AND cod_plazo = i.plazo
                  AND tip_saldo = v_tip_sal_ade
                  AND cod_oficina = i.cod_oficina
                  AND cod_moneda = v_cod_moneda
                  AND situacion = i.estado
                  AND cod_rubro = v_cod_rubro3;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_mto_devengado
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_mto_devengado
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_operacion;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_operacion, v_mto_devengado, 0);
               END IF;

               ------------------------------------------------------------------------------------------------------------------

            EXCEPTION
               WHEN no_data_found THEN
                  IF nvl(v_mto_devengado, 0) <> 0 THEN
                     SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (i.cod_modulo, i.cod_mad_transaccion, i.cod_oficina, i.cod_sec_contable,
                         i.cod_tip_deudor, i.residente, v_cod_moneda, i.estado, v_tip_sal_ade,
                         i.plazo, NULL, NULL, v_mto_devengado, v_cod_rubro3,
                         v_nro_referencia, NULL, NULL, NULL);

                     IF nvl(v_mto_devengado, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_operacion, v_mto_devengado, 0);
                     END IF;
                  END IF;
            END;
         END IF;
      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_FORWARD:' || SQLERRM);
   END;

   PROCEDURE lp_acu_for_valeco IS
    --Variables--
    v_cod_transaccion2 ge_transacciones.cod_transaccion%TYPE;
    v_cod_transaccion3 ge_transacciones.cod_transaccion%TYPE;
    v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
    v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
    v_cod_rubro2       cb_sal_inventarios.cod_rubro%TYPE;
    v_cod_rubro3       cb_sal_inventarios.cod_rubro%TYPE;
    v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
    v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_tip_sal_ade      cb_sal_inventarios.tip_saldo%TYPE;
    v_mto_devengado    lc_ope_futuras.monto%TYPE;
    v_fec_ult_valeco   date;
    v_indice number(1);
    v_ind_dev_val_economico ge_par_dinamicos.val_parametro%type;

    ---Cursor Principal--
    CURSOR c_ope_futuras IS
       SELECT b.nro_cuenta,
              b.nro_operacion,
              b.cod_modulo,
              b.cod_mad_transaccion,
              b.cod_oficina,
              b.cod_moneda,
              b.estado,
              c.cod_sec_contable,
              c.cod_tip_deudor,
              c.residente,
              nvl(b.monto, 0) sal_mto_me,
              fug_obt_plz_contable(b.fec_vencimiento - b.fec_operacion) plazo,
              nvl(deve.val_economico, 0) mto_val_econ,
              b.cot_vencimiento
         FROM lc_ope_futuras b, ge_clientes c, lc_for_dat_val_economico deve
        WHERE ((b.estado = 'N' and b.fec_liquidacion is null))
          AND c.cod_persona = b.cod_persona
          AND b.nro_operacion = deve.nro_operacion
          AND deve.fec_calculo = v_fec_ult_valeco
          and v_ind_dev_val_economico = 'S'
          and not exists (select 1
                            from ba_cod_referencias x
                           where x.dominio = 'OPE_FUT_DEV_ANTERIOR'
                             and x.val_minimo = b.nro_cuenta||'#'||b.nro_operacion);

   BEGIN
      v_tip_saldo   := 'C';  --Capital / Monto de la Operacion--
      v_tip_sal_ade := 'L';  --Valuacion / Valor Economico actual--

      Begin PAG_CAL.PR_OBT_DAT_CALENDAR(7);End;

      v_ind_dev_val_economico := nvl(fug_obt_pardinamico('IND_DEV_VAL_ECONOMICO'),'N');
      --Buscar fecha de ultimo valor Economico Calculado--
      select max(x.fec_calculo)
        into v_fec_ult_valeco
        from lc_for_dat_val_economico x;

      FOR i IN c_ope_futuras LOOP
            --Tipo: Monto en moneda EXTRANJERA--
            v_cod_transaccion2 := 2356;
            for v_indice in 1..2 loop
                if v_indice = 1 then
                  IF i.cod_mad_transaccion = 71 THEN
                     v_tip_movimiento  := 'D';
                  ELSE
                     v_tip_movimiento  := 'C';
                  END IF;
                else
                  IF i.cod_mad_transaccion = 71 THEN
                     v_tip_movimiento  := 'C';
                  ELSE
                     v_tip_movimiento  := 'D';
                  END IF;
                end if;
                lp_obt_cod_rubro(i.cod_modulo, i.cod_mad_transaccion, v_cod_transaccion2, i.cod_moneda,
                                 i.cod_sec_contable, i.cod_tip_deudor, i.residente, i.plazo,
                                 v_tip_movimiento, v_cod_rubro2, NULL , NULL, NULL, NULL,  NULL, NULL);

                BEGIN
                   ---Actualiza Monto en moneda EXTRANJERA
                   SELECT nro_referencia
                     INTO v_nro_referencia
                     FROM cb_sal_inventarios
                    WHERE cod_modulo = i.cod_modulo
                      AND cod_modalidad = i.cod_mad_transaccion
                      AND cod_plazo = i.plazo
                      AND tip_saldo = v_tip_saldo
                      AND cod_oficina = i.cod_oficina
                      AND cod_moneda = i.cod_moneda
                      AND situacion = i.estado
                      AND cod_sec_contable = i.cod_sec_contable
                      AND residente = i.residente
                      AND cod_rubro = v_cod_rubro2;

                   UPDATE cb_sal_inventarios
                      SET sal_total = nvl(sal_total, 0) + i.sal_mto_me
                    WHERE nro_referencia = v_nro_referencia;

                   UPDATE cb_sal_inventarios_det
                      SET sal_actual = nvl(sal_actual, 0) + i.sal_mto_me
                    WHERE nro_referencia = v_nro_referencia
                      AND nro_cuenta = i.nro_operacion;

                   IF SQL%NOTFOUND THEN
                      INSERT INTO cb_sal_inventarios_det
                         (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                      VALUES
                         (v_nro_referencia, i.nro_operacion, i.sal_mto_me, 0);
                   END IF;

                   ------------------------------------------------------------------------------------------------------------------

                EXCEPTION
                   WHEN no_data_found THEN
                      IF nvl(i.sal_mto_me, 0) <> 0 THEN
                         SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                         INSERT INTO cb_sal_inventarios
                            (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                             residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                             tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                             cat_automatica, cod_sit_contable)
                         VALUES
                            (i.cod_modulo, i.cod_mad_transaccion, i.cod_oficina, i.cod_sec_contable,
                             i.cod_tip_deudor, i.residente, i.cod_moneda, i.estado, v_tip_saldo, i.plazo,
                             NULL, NULL, i.sal_mto_me, v_cod_rubro2, v_nro_referencia, NULL, NULL, NULL);

                         IF nvl(i.sal_mto_me, 0) <> 0 THEN
                            INSERT INTO cb_sal_inventarios_det
                               (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                            VALUES
                               (v_nro_referencia, i.nro_operacion, i.sal_mto_me, 0);
                         END IF;
                      END IF;
                END;
         end loop;

         --Tipo: Valor Economico en Mon. Local--
         IF i.cod_mad_transaccion = 71 THEN --Es Compra--
            IF nvl(i.mto_val_econ, 0) >= 0 THEN --Esta en el Activo--
               v_mto_devengado := nvl(i.mto_val_econ, 0);
               v_cod_transaccion3 := 3902;
               v_tip_movimiento   := 'D';
            ELSE --Esta en el Pasivo--
               v_mto_devengado := abs(nvl(i.mto_val_econ, 0));
               v_cod_transaccion3 := 3906;
               v_tip_movimiento   := 'C';
            END IF;
         ELSE --Es Venta--
            IF nvl(i.mto_val_econ, 0) <= 0 THEN --Esta en el Activo--
               v_mto_devengado := abs(nvl(i.mto_val_econ, 0));
               v_cod_transaccion3 := 3906;
               v_tip_movimiento   := 'C';
            ELSE --Esta en el Pasivo--
               v_mto_devengado := nvl(i.mto_val_econ, 0);
               v_cod_transaccion3 := 3902;
               v_tip_movimiento   := 'D';
            END IF;
         END IF;

         IF nvl(v_mto_devengado, 0) > 0 THEN
            lp_obt_cod_rubro(i.cod_modulo, i.cod_mad_transaccion, v_cod_transaccion3, v_cod_moneda,
                             i.cod_sec_contable, i.cod_tip_deudor, i.residente, i.plazo,
                             v_tip_movimiento, v_cod_rubro3, NULL, NULL, NULL, NULL, NULL, NULL);
            BEGIN
               ---Actualiza Valor Economico en Mon. Local--
               SELECT nro_referencia
                 INTO v_nro_referencia
                 FROM cb_sal_inventarios
                WHERE cod_modulo = i.cod_modulo
                  AND cod_modalidad = i.cod_mad_transaccion
                  AND cod_plazo = i.plazo
                  AND tip_saldo = v_tip_sal_ade
                  AND cod_oficina = i.cod_oficina
                  AND cod_moneda = v_cod_moneda
                  AND situacion = i.estado
                  AND cod_rubro = v_cod_rubro3;

               UPDATE cb_sal_inventarios
                  SET sal_total = nvl(sal_total, 0) + v_mto_devengado
                WHERE nro_referencia = v_nro_referencia;

               UPDATE cb_sal_inventarios_det
                  SET sal_actual = nvl(sal_actual, 0) + v_mto_devengado
                WHERE nro_referencia = v_nro_referencia
                  AND nro_cuenta = i.nro_operacion;

               IF SQL%NOTFOUND THEN
                  INSERT INTO cb_sal_inventarios_det
                     (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                  VALUES
                     (v_nro_referencia, i.nro_operacion, v_mto_devengado, 0);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  IF nvl(v_mto_devengado, 0) <> 0 THEN
                     SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                     INSERT INTO cb_sal_inventarios
                        (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                         residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                         tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                         cat_automatica, cod_sit_contable)
                     VALUES
                        (i.cod_modulo, i.cod_mad_transaccion, i.cod_oficina, i.cod_sec_contable,
                         i.cod_tip_deudor, i.residente, v_cod_moneda, i.estado, v_tip_sal_ade,
                         i.plazo, NULL, NULL, v_mto_devengado, v_cod_rubro3,
                         v_nro_referencia, NULL, NULL, NULL);

                     IF nvl(v_mto_devengado, 0) <> 0 THEN
                        INSERT INTO cb_sal_inventarios_det
                           (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                        VALUES
                           (v_nro_referencia, i.nro_operacion, v_mto_devengado, 0);
                     END IF;
                  END IF;
            END;
         END IF;
      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_FOR_VALECO:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Forward
   ---------------------------------------------------------------------------------------------------------------------
   ---------------------------------------------------------------------------------------------------------------------
   -- Dep?sitos Overnight
   ---------------------------------------------------------------------------------------------------------------------
   PROCEDURE lp_acu_dep_overnight IS
      v_tip_saldo       cb_sal_inventarios.tip_saldo%TYPE;
      v_cod_plazo       NUMBER(03);
      v_cod_rubro       cb_sal_inventarios.cod_rubro%TYPE;
      v_rowid           VARCHAR2(30);
      v_nro_referencia  cb_sal_inventarios.nro_referencia%TYPE;
      rg_cale           ge_calendarios%ROWTYPE := pag_cal.fu_obt_reg_cal(1);
      v_fec_proceso  CONSTANT DATE := rg_cale.fec_anterior;

      ---cursor
      CURSOR c_depositos IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                a.cod_moneda,
                nvl(d.monto, 0) monto,
                b.cod_persona,
                nvl(a.cod_rubro, 0)
           FROM ge_clientes c, ge_cta_clientes b, cc_cta_bancarias a, xv_dep_overnight d
          WHERE c.cod_persona = b.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND a.nro_cuenta = d.nro_cuenta
            AND relacion = 'P'
            --WA:08/08/2014 Se incluye modalidad 49 para Financieras Pais
            AND a.cod_modalidad IN (42, 45, 442,49)
            AND d.fecha = v_fec_proceso;

   BEGIN
      v_cod_plazo       := 1;
      v_tip_saldo       := 'C';

      FOR i IN c_depositos LOOP
         ---Actualiza rubro de la Cta. Bancaria
         v_cod_rubro := fug_obt_paradicional(i.nro_cuenta, 'COD_RUB_DEP_OVERNIGHT');
         IF v_cod_rubro IS NULL THEN
            BEGIN
               SELECT a.cod_rubro
                 INTO v_cod_rubro
                 FROM cc_cta_bancarias a
                WHERE a.nro_cuenta = i.nro_cuenta
                  AND a.cod_modulo = i.cod_modulo
                  AND a.cod_modalidad = i.cod_modalidad;
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20000,
                                          'ERROR. No se encontro Rubro Dep.Overnight:' ||
                                           i.nro_cuenta);
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'ERROR:Obt.Rubro Dep.Overnight:' || SQLERRM);
            END;
         END IF;

         BEGIN

            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_rowid
              FROM cb_sal_inventarios
             WHERE cod_modulo = i.cod_modulo
               AND cod_modalidad = i.cod_modalidad
               AND cod_plazo = v_cod_plazo
               AND cod_oficina = i.cod_oficina
               AND cod_moneda = i.cod_moneda
               AND cod_rubro = v_cod_rubro;

            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND ROWID = v_rowid;

            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + i.monto
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = i.nro_cuenta;

            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, i.nro_cuenta, i.monto, 0);
            END IF;

            ------------------------------------------------------------------------------------------------------------------

         EXCEPTION
            WHEN no_data_found THEN
               IF nvl(i.monto, 0) <> 0 THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

                  INSERT INTO cb_sal_inventarios
                     (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                      residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                      tip_interes, sal_total, cod_rubro, nro_referencia, tip_renovacion,
                      cat_automatica, cod_sit_contable)
                  VALUES
                     (i.cod_modulo, i.cod_modalidad, i.cod_oficina, NULL, NULL,
                      NULL, i.cod_moneda, NULL, v_tip_saldo, v_cod_plazo,
                      NULL, NULL, i.monto, v_cod_rubro, v_nro_referencia, NULL, NULL, NULL);

                  IF nvl(i.monto, 0) <> 0 THEN
                     INSERT INTO cb_sal_inventarios_det
                        (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                     VALUES
                        (v_nro_referencia, i.nro_cuenta, i.monto, 0);
                  END IF;
               END IF;
         END;

      END LOOP;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR EN LP_ACU_DEP_OVERNIGHT:' || SQLERRM);
   END;
   ---------------------------------------------------------------------------------------------------------------------
   -- fin de Dep?sitos Overnight
   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

   ------------------------------------------------------------------------
   ---- Sobregiros por Depositos Overnight
   ------------------------------------------------------------------------
   PROCEDURE lp_acu_dep_ove_sobregiro IS
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_cod_plazo        cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_transaccion  NUMBER(05);
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_sal_tot_batch    NUMBER(22, 2);
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_cod_persona      ba_personas.cod_persona%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_fila             VARCHAR2(30);
      rg_cale            ge_calendarios%ROWTYPE := pag_cal.fu_obt_reg_cal(1);
      v_fec_proceso  CONSTANT DATE := rg_cale.fec_anterior;
      v_fec_anterior CONSTANT DATE := pag_cal.fu_obt_fec_ant_hab(rg_cale.fec_actual,
                                                                 fun_obt_ofi_matriz, 2);
      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT a.cod_modulo,
                a.cod_modalidad,
                a.cod_oficina,
                a.nro_cuenta,
                cod_sec_contable,
                cod_tip_deudor,
                residente,
                a.cod_moneda,
                NULL,
                1,
                nvl((case when nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(d.monto, 0) >= 0 then
                           nvl(d.monto,0)
                      when nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(d.monto, 0) < 0 then
                           nvl(d.monto,0) + (nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(d.monto, 0))
                      else 0
                end),0) monto,
                b.cod_persona --, nvl(a.cod_rubro,0)
           FROM ge_clientes      c,
                ge_cta_clientes  b,
                cc_cta_bancarias a,
                xv_dep_overnight d
          WHERE c.cod_persona = b.cod_persona
            AND b.nro_cuenta = a.nro_cuenta
            AND a.nro_cuenta = d.nro_cuenta
            AND relacion = 'P'
            --WA:08/08/2014 Se incluye modalidad 49 para Financieras Pais
            AND a.cod_modalidad IN (42, 45, 442,49)
            AND d.fecha = v_fec_proceso
            AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) > 0;
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_cod_persona; --,v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;
         --- Busco la transaccion y el estado del sobregiro -----------
         /*LP_SIT_DEL_SOBREGIRO(v_cod_modulo,v_cod_modalidad,v_cod_oficina,v_nro_cuenta,
         v_cod_transaccion,v_sit_saldo,v_cod_tra_utilizacion);*/

         v_cod_transaccion := fug_obt_pardinamico('COD_TRA_SOB_DEP_OVERNIGHT'); -- 6744;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'B';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------
         --- busco la cuenta que le corresponde al saldo ----
         /*LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
         v_cod_moneda,V_cod_sec_contable,v_cod_tip_deudor,
         v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*/

         -- Rubro de Sobregiros de Cuentas Bancarias
         v_cod_rubro := fug_obt_paradicional(v_nro_cuenta, 'COD_RUB_SOB_DEP_OVER');
         IF v_cod_rubro IS NULL THEN
            BEGIN
               SELECT a.cod_rubro
                 INTO v_cod_rubro
                 FROM cc_cta_bancarias a
                WHERE a.nro_cuenta = v_nro_cuenta
                  AND a.cod_modulo = v_cod_modulo
                  AND a.cod_modalidad = v_cod_modalidad;
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20000,
                                          'ERROR. No se encontro Rubro Sob.Overnight:' ||
                                           v_nro_cuenta);
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'ERROR:Obt.Rubro Sob.Overnight:' || SQLERRM);
            END;
         END IF;

         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_tot_batch
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_tot_batch
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               ---
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                   residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                   tip_interes, sal_total, cod_rubro, nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                   v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                   v_cod_plazo, v_tip_credito, v_tip_interes, v_sal_tot_batch, v_cod_rubro,
                   v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
         END;

      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en ACU_DEP_OVE_SOBREGIRO ' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------
   -- Fin Sobregiros Depositos Overnight ---
   ---------------------------------------------------------------------------------------------------------------------
   ------------------------------------------------------------------------
   ---- GASTOS DIFERIDOS
   ------------------------------------------------------------------------
   PROCEDURE lp_acu_gas_diferidos IS
      v_cod_plazo        cb_sal_inventarios.cod_plazo%TYPE;
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_sal_tot_batch    NUMBER(22, 2);
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_tip_credito      VARCHAR2(01);
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_fila             VARCHAR2(30);
      v_fec_actual CONSTANT DATE := pag_cal.fu_obt_fec_actual(1);
      ------------------------- DEFINE MOVIMIEN -----------------------------
      CURSOR movimien IS
         SELECT t.cod_modulo,
                t.cod_modalidad,
                t.cod_oficina,
                g.cod_cargo,
                'X',
                'X',
                pag_gen.fu_obt_mon_local cod_moneda,
                1,
                d.mto_mon_local,
                d.cod_rubro
           FROM cb_asi_futuros t, cb_gas_diferidos g, cb_asi_futuros_det d
          WHERE t.cod_cargo = g.cod_cargo
            AND t.fecha = d.fecha
            AND t.cod_oficina = d.cod_oficina
            AND t.nro_asiento = d.nro_asiento
            AND t.nro_asi_real IS NULL
            AND substr(d.cod_rubro, 1, 1) NOT IN ('6', '7')
            AND t.fecha > v_fec_actual;
   BEGIN
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         ------------------------------------------------------
         -- EL CODIGO DEL CARGO SE INSERTA EN EL DETALLE    ---
         -- EN EL CAMPO CORRESPONDIENTE AL NUMERO DE CUENTA ---
         ------------------------------------------------------
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_nro_cuenta,
                 v_cod_sec_contable,
                 v_residente,
                 v_cod_moneda,
                 v_cod_plazo,
                 v_sal_tot_batch,
                 v_cod_rubro;
         EXIT WHEN movimien%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'A';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------

         BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + v_sal_tot_batch
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + v_sal_tot_batch
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
               ---
               INSERT INTO cb_sal_inventarios
                  (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, residente, cod_moneda,
                   tip_saldo, cod_plazo, tip_operacion, tip_interes, sal_total, cod_rubro,
                   nro_referencia)
               VALUES
                  (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable, v_residente,
                   v_cod_moneda, v_tip_saldo, v_cod_plazo, v_tip_credito, v_tip_interes,
                   v_sal_tot_batch, v_cod_rubro, v_nro_referencia);
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, v_sal_tot_batch, 0);
         END;

      END LOOP;
      CLOSE movimien;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en ACU_GAS_DIFERIDOS ' || SQLERRM);
   END;
   --------------------------------------------------------------------------------------------------------------------
   -- Fin Gastos Diferidos ---

   ---------------------------------------------------------------------------------------------------------------------

   procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
   is pragma autonomous_transaction;
   begin
     insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
     values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PRB_GEN_SAL_INVENTARIOS',p_cod_proceso, p_hor_ini, p_hor_fin);
     commit;
   exception
     when others then null;
   end;

   --Resolucion 4 ganancia y devengado paralelo
  PROCEDURE lp_acu_sal_dev_re4 IS
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_fila             VARCHAR2(30);
      v_cod_persona      ba_personas.cod_persona%TYPE;
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_plazo        NUMBER(2);
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_tot_interes      NUMBER(16, 2);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_retencion    NUMBER(3);
      v_monto_retencion  NUMBER(22, 2);
      v_cod_transaccion  NUMBER(05);
      v_cod_mon_local    varchar2(50):= pag_gen.FU_OBT_MON_LOCAL;
      v_fec_sistema      date:= pag_cal.FU_OBT_FEC_ACTUAL(6);
      --Rubros pasivos a utilizar
       v_cod_rubro_cob_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_COB_RE4',null,null,'GS', null,null);
       v_cod_rubro_cob_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_COB_RE4',null,null,'USD', null,null);
       v_cod_rubro_int_sus_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_SUS_RE4',null,null,'GS', null,null);
       v_cod_rubro_int_sus_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_SUS_RE4',null,null,'USD', null,null);
       v_cod_rubro_int_mor_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_MOR_RE4',null,null,'GS', null,null);
       v_cod_rubro_int_mor_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_MOR_RE4',null,null,'USD', null,null);
       v_cod_rubro_int_pun_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_PUN_RE4',null,null,'GS', null,null);
       v_cod_rubro_int_pun_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_PUN_RE4',null,null,'USD', null,null);
      --Rubros devengado paralelo
      v_cod_rubro_int_dev_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_DEV_RE4',null,null,'GS', null,null);
      v_cod_rubro_int_dev_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_INT_DEV_RE4',null,null,'USD', null,null);

      --Rubros de Interes sobregiro
      v_cod_rubro_int_sob_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_SOB_RE4',null,null,'GS', null,null);
      v_cod_rubro_int_sob_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_CAN_SOB_RE4',null,null,'USD', null,null);
      --Rubros de Interes valuacion en suspesno
      v_cod_rubro_int_val_sus_gs  varchar2(100):=fug_obt_pardinamico('COD_RUB_VAL_SUS_RE4',null,null,'GS', null,null);
      v_cod_rubro_int_val_sus_usd varchar2(100):=fug_obt_pardinamico('COD_RUB_VAL_SUS_RE4',null,null,'USD', null,null);



      --Saldos
      v_sal_interes     NUMBER(22, 2);
      v_sal_int_moratorio     NUMBER(22, 2);
      v_sal_int_punitorio     NUMBER(22, 2);
      v_sal_cobranza     NUMBER(22, 2);
      v_sal_sobregiro     NUMBER(22, 2);
      v_sal_val_suspenso     NUMBER(22, 2);
      v_sal_dev_par     NUMBER(22, 2);
      v_tip_tabla       varchar2(100);
      v_nro_cuo_max_dev number(10):=0;
      v_max_fec_insercion date;
      v_sal_dev_acumulado     NUMBER(22, 2);
    v_nro_orden   number(4);
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
      CURSOR movimien IS
         SELECT d.cod_modulo,
                    d.cod_modalidad,
                    d.cod_oficina,
                    cod_sec_contable,
                    cod_tip_deudor,
                    residente,
                    d.cod_moneda,
                    'N' sit_saldo,
                    1 cod_plazo,
                    a.sal_inv_interes,
                    a.sal_inv_int_moratorio,
                    a.sal_inv_int_punitorio,
                    a.sal_inv_ges_cobranza,
                    a.nro_cuenta,
                    c.cod_persona
                    ,null as cod_rubro--nvl(a.cod_rubro, 0)
                    ,'UNO' as tip_tabla,
                    a.sal_inv_sobregiro,
                    a.sal_inv_val_suspenso
               FROM ge_clientes c, ge_cta_clientes b, PR_CTA_PRE_REF_RES4 a, pr_cta_prestamos d
              WHERE c.cod_persona = b.cod_persona
                --AND a.nro_cta_nueva = b.nro_cuenta
                --and a.nro_cta_nueva= d.nro_cuenta
                AND a.nro_cuenta = b.nro_cuenta
                and a.nro_cuenta= d.nro_cuenta
                --and a.reversado='N'
                and nvl(a.inventariar,'N')='S'
                and b.relacion='P'
         UNION ALL
           SELECT d.cod_modulo,
                    d.cod_modalidad,
                    d.cod_oficina,
                    cod_sec_contable,
                    cod_tip_deudor,
                    residente,
                    d.cod_moneda,
                    'N' sit_saldo,
                    1 cod_plazo,
                    a.sal_inv_interes,
                    a.sal_inv_int_moratorio,
                    a.sal_inv_int_punitorio,
                    a.sal_inv_ges_cobranza,
                    a.nro_cuenta,
                    c.cod_persona
                    ,null as cod_rubro--nvl(a.cod_rubro, 0)
                    ,'MASIVO' as tip_tabla,
                    a.sal_inv_sobregiro,
                    a.sal_inv_val_suspenso
               FROM ge_clientes c, ge_cta_clientes b, PR_CTA_PRE_CAN_RES4 a, pr_cta_prestamos d
              WHERE c.cod_persona = b.cod_persona
                AND a.nro_cuenta = b.nro_cuenta
                and a.nro_cuenta= d.nro_cuenta
                --and a.reversado='N'
                and nvl(a.inventariar,'N')='S'
                and b.relacion='P'
        UNION ALL
            SELECT d.cod_modulo,
                        d.cod_modalidad,
                        d.cod_oficina,
                        cod_sec_contable,
                        cod_tip_deudor,
                        residente,
                        d.cod_moneda,
                        'N' sit_saldo,
                        1 cod_plazo,
                        a.sal_inv_interes,
                        a.sal_inv_int_moratorio,
                        a.sal_inv_int_punitorio,
                        a.sal_inv_ges_cobranza,
                        a.nro_cuenta,
                        c.cod_persona
                        ,null as cod_rubro--nvl(a.cod_rubro, 0)
                        ,'MASIVO' as tip_tabla,
                        a.sal_inv_sobregiro,
                        a.sal_inv_val_suspenso
                   FROM ge_clientes c, ge_cta_clientes b, PR_CTA_PRE_REF_RES4 a, cc_cta_corrientes d
                  WHERE c.cod_persona = b.cod_persona
                    AND a.nro_cuenta = b.nro_cuenta
                    and a.nro_cuenta= d.nro_cuenta
                    --and a.reversado='N'
                    and nvl(a.inventariar,'N')='S'
                    and b.relacion='P';

        --Para devengado paralelo
        CURSOR movimien1 IS
        SELECT d.cod_modulo,
                    d.cod_modalidad,
                    d.cod_oficina,
                    cod_sec_contable,
                    cod_tip_deudor,
                    residente,
                    d.cod_moneda,
                    'N' sit_saldo,
                    1 cod_plazo,
                    d.nro_cuenta,
                    c.cod_persona
                    ,null as cod_rubro
                    ,'DEV' as tip_tabla,
                    d.mto_dev_acumulado,
                    d.nro_orden
               FROM ge_clientes c, ge_cta_clientes b, GE_DEV_RES4 d
              WHERE c.cod_persona = b.cod_persona
               AND d.nro_cuenta = b.nro_cuenta
                and nvl(d.devengar,'N')='S'
                and b.relacion='P';


   /****************INICIO DE PROCESO PRINCIPAL*********************+*/
   BEGIN
      /***************PARA SALDOS DE INTERESES*******************************/
      IF movimien%ISOPEN THEN
         CLOSE movimien;
      END IF;
      v_sal_interes:=0;
      v_sal_int_moratorio:=0;
      v_sal_int_punitorio:=0;
      v_sal_cobranza:=0;
      v_tip_tabla:=null;
      ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien;
      LOOP
         FETCH movimien
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_sal_interes,
                 v_sal_int_moratorio,
                 v_sal_int_punitorio,
                 v_sal_cobranza,
                 v_nro_cuenta,
                 v_cod_persona,
                 v_cod_rubro,
                 v_tip_tabla,
                 v_sal_sobregiro,
                 v_sal_val_suspenso
                 ;
         EXIT WHEN movimien%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'I'/*'B'*/;  --Ponemos Interes
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------

         --- busco la cuenta que le corresponde al saldo ----
         /* v_cod_transaccion := 602;
         LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
                          v_cod_moneda,V_cod_sec_contable,v_cod_tip_deudor,
                          v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*/
      --Para interes en Suspenso
      v_cod_rubro:=null;
      if nvl(v_sal_interes,0) > 0 then
        if v_cod_moneda =  v_cod_mon_local then
          v_cod_rubro:=v_cod_rubro_int_sus_gs;
        else
          v_cod_rubro:= v_cod_rubro_int_sus_usd;
        end if;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_interes)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + abs(v_sal_interes)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_interes), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN

                 SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                   ---
                   INSERT INTO cb_sal_inventarios
                      (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                       residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                       tip_interes, sal_total, cod_rubro, nro_referencia)
                   VALUES
                      (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                       v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                       v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_interes), v_cod_rubro,
                       v_nro_referencia);
                   ---
                   INSERT INTO cb_sal_inventarios_det
                      (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                   VALUES
                      (v_nro_referencia, v_nro_cuenta, abs(v_sal_interes), 0);

         END;
       end if;

      --Para Gestion de Cobranza
      v_cod_rubro:=null;
      if nvl(v_sal_cobranza,0) > 0 then
        if v_cod_moneda =  v_cod_mon_local then
          v_cod_rubro:=v_cod_rubro_cob_gs;
        else
          v_cod_rubro:= v_cod_rubro_cob_usd;
        end if;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_cobranza)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual =nvl(sal_actual, 0) + abs(v_sal_cobranza)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_cobranza), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
              SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                 INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_cobranza), v_cod_rubro,
                     v_nro_referencia);

                 ---
                 INSERT INTO cb_sal_inventarios_det
                    (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                 VALUES
                    (v_nro_referencia, v_nro_cuenta, abs(v_sal_cobranza), 0);

         END;
       end if;


       --Para Interes Moratorio (Solo el masivo)
      v_cod_rubro:=null;
      if nvl(v_sal_int_moratorio,0) > 0 /*and v_tip_tabla='MASIVO'*/ then
        if v_cod_moneda =  v_cod_mon_local then
          v_cod_rubro:=v_cod_rubro_int_mor_gs;
        else
          v_cod_rubro:= v_cod_rubro_int_mor_USD;
        end if;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_int_moratorio)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + abs(v_sal_int_moratorio)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_int_moratorio), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
                  SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                   ---
                   INSERT INTO cb_sal_inventarios
                      (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                       residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                       tip_interes, sal_total, cod_rubro, nro_referencia)
                   VALUES
                      (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                       v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                       v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_int_moratorio), v_cod_rubro,
                       v_nro_referencia);
                   ---
                   INSERT INTO cb_sal_inventarios_det
                      (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                   VALUES
                      (v_nro_referencia, v_nro_cuenta, abs(v_sal_int_moratorio), 0);
         END;
       end if;

        --Para Interes punitorio (Solo el masivo)
      v_cod_rubro:=null;
      if nvl(v_sal_int_punitorio,0) > 0 /*and v_tip_tabla='MASIVO'*/ then
        if v_cod_moneda =  v_cod_mon_local then
          v_cod_rubro:=v_cod_rubro_int_pun_gs;
        else
          v_cod_rubro:= v_cod_rubro_int_pun_USD;
        end if;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_int_punitorio)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + abs(v_sal_int_punitorio)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_int_punitorio), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
                 SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                 ---
                 INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_int_punitorio), v_cod_rubro,
                     v_nro_referencia);
                 ---
                 INSERT INTO cb_sal_inventarios_det
                    (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                 VALUES
                    (v_nro_referencia, v_nro_cuenta, abs(v_sal_int_punitorio), 0);
         END;
       end if;


      --Para Sobregiro
      v_cod_rubro:=null;
      if nvl(v_sal_sobregiro,0) > 0 then
        if v_cod_moneda =  v_cod_mon_local then
          v_cod_rubro:=v_cod_rubro_int_sob_gs;
        else
          v_cod_rubro:= v_cod_rubro_int_sob_usd;
        end if;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_sobregiro)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual =nvl(sal_actual, 0) + abs(v_sal_sobregiro)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_sobregiro), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
              SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                 INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_sobregiro), v_cod_rubro,
                     v_nro_referencia);

                 ---
                 INSERT INTO cb_sal_inventarios_det
                    (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                 VALUES
                    (v_nro_referencia, v_nro_cuenta, abs(v_sal_sobregiro), 0);

         END;
       end if;


      --Para valuaciones en suspenso
      v_cod_rubro:=null;
      if nvl(v_sal_val_suspenso,0) > 0 then
         --09/11 para valuaciones en suspenso
         v_tip_interes := 'L';
         v_cod_moneda:=v_cod_mon_local;
         v_cod_rubro:=v_cod_rubro_int_val_sus_gs;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_val_suspenso)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual =nvl(sal_actual, 0) + abs(v_sal_val_suspenso)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_val_suspenso), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
              SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                 INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_val_suspenso), v_cod_rubro,
                     v_nro_referencia);

                 ---
                 INSERT INTO cb_sal_inventarios_det
                    (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                 VALUES
                    (v_nro_referencia, v_nro_cuenta, abs(v_sal_val_suspenso), 0);

         END;
       end if;


      END LOOP;
      CLOSE movimien;

      /***************DEVENGADO PARALELO*******************************/
       ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien1;
      LOOP
         FETCH movimien1
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_nro_cuenta,
                 v_cod_persona,
                 v_cod_rubro,
                 v_tip_tabla,
                 v_sal_dev_acumulado,
                 v_nro_orden;
         EXIT WHEN movimien1%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'D'/*'B'*/;  --Ponemos Interes
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------

         --- busco la cuenta que le corresponde al saldo ----
         /* v_cod_transaccion := 602;
         LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
                          v_cod_moneda,V_cod_sec_contable,v_cod_tip_deudor,
                          v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*/
      --Para Devengado paralelo
      --04/11/2020 Obtenemos el saldo del Detalle para igualar con saldo contable
      begin
         select sum(nvl(s.mto_interes,0)- nvl(s.mto_dev_acumulado,0))
           into v_sal_dev_acumulado
          from ge_dev_res4_det s
            where s.nro_cuenta=v_nro_cuenta
              and s.nro_orden= v_nro_orden
              and s.estado IN ('DE','AD');
    exception
        when others then
           null;
      end;

      --Fin de ajuste
      v_sal_dev_par:=0;
      v_nro_cuo_max_dev:=0;
      v_cod_rubro:=null;
      v_max_fec_insercion:=null;
      v_sal_dev_par:= v_sal_dev_acumulado;
      if nvl(v_sal_dev_par,0) >= 0 then
        if v_cod_moneda =  v_cod_mon_local then
          v_cod_rubro:=v_cod_rubro_int_dev_gs;
        else
          v_cod_rubro:= v_cod_rubro_int_dev_usd;
        end if;

        BEGIN
            SELECT nro_referencia, ROWID
              INTO v_nro_referencia, v_fila
              FROM cb_sal_inventarios
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_oficina = v_cod_oficina
               AND cod_sec_contable = v_cod_sec_contable
               AND cod_tip_deudor = v_cod_tip_deudor
               AND residente = v_residente
               AND cod_moneda = v_cod_moneda
               AND situacion = v_sit_saldo
               AND tip_saldo = v_tip_saldo
               AND cod_plazo = v_cod_plazo
               AND tip_operacion = v_tip_credito
               AND tip_interes = v_tip_interes
               AND cod_rubro = v_cod_rubro;
            ---
            UPDATE cb_sal_inventarios
               SET sal_total = nvl(sal_total, 0) + abs(v_sal_dev_par)
             WHERE ROWID = v_fila;
            --- genero detalle ---------------------------------
            UPDATE cb_sal_inventarios_det
               SET sal_actual = nvl(sal_actual, 0) + abs(v_sal_dev_par)
             WHERE nro_referencia = v_nro_referencia
               AND nro_cuenta = v_nro_cuenta;
            IF SQL%NOTFOUND THEN
               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_dev_par), 0);
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
              if nvl(v_sal_dev_par,0) > 0 then
                 SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;
                 ---
                 INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_dev_par), v_cod_rubro,
                     v_nro_referencia);
                 ---
                 INSERT INTO cb_sal_inventarios_det
                    (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
                 VALUES
                    (v_nro_referencia, v_nro_cuenta, abs(v_sal_dev_par), 0);
              end if;
         END;
       end if;


      END LOOP;
      CLOSE movimien1;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en acu_sal_dev_re4 ' || SQLERRM);
   END;

   --Dep. Dat. Ctas. Pend. de Cancelacion
   PROCEDURE lp_can_cta_pen_can IS
      v_cod_sec_contable cb_sal_inventarios.cod_sec_contable%TYPE;
      v_residente        cb_sal_inventarios.residente%TYPE;
      v_cod_moneda       cb_sal_inventarios.cod_moneda%TYPE;
      v_sit_saldo        VARCHAR2(01);
      v_tip_credito      VARCHAR2(01);
      v_categoria        cb_sal_inventarios.cat_automatica%TYPE;
      v_tip_saldo        cb_sal_inventarios.tip_saldo%TYPE;
      v_tip_interes      cb_sal_inventarios.tip_interes%TYPE;
      v_cod_rubro        cb_sal_inventarios.cod_rubro%TYPE;
      v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
      v_fila             VARCHAR2(30);
      v_cod_persona      ba_personas.cod_persona%TYPE;
      v_cod_modulo       cb_sal_inventarios.cod_modulo%TYPE;
      v_cod_modalidad    cb_sal_inventarios.cod_modalidad%TYPE;
      v_cod_oficina      cb_sal_inventarios.cod_oficina%TYPE;
      v_cod_plazo        NUMBER(2);
      v_cod_tip_deudor   cb_sal_inventarios.cod_tip_deudor%TYPE;
      v_tot_interes      NUMBER(16, 2);
      v_nro_referencia   cb_sal_inventarios.nro_referencia%TYPE;
      v_cod_retencion    NUMBER(3);
      v_monto_retencion  NUMBER(22, 2);
      v_cod_transaccion  NUMBER(05);
      v_cod_mon_local    varchar2(50):= pag_gen.FU_OBT_MON_LOCAL;
      v_fec_sistema      date:= pag_cal.FU_OBT_FEC_ACTUAL(6);
      --Rubros a utilizar
       v_COD_RUB_CAN_CTA_DEU  varchar2(100);
       v_COD_RUB_CAN_CTA_ACR varchar2(100);

      --Saldos
      v_sal_interes     NUMBER(22, 2);
      v_sal_int_moratorio     NUMBER(22, 2);
      v_sal_int_punitorio     NUMBER(22, 2);
      v_sal_cobranza     NUMBER(22, 2);
      v_sal_sobregiro     NUMBER(22, 2);
      v_sal_val_suspenso     NUMBER(22, 2);
      v_sal_cta_tot     NUMBER(22, 2);
      v_tip_tabla       varchar2(100);
      v_nro_cuo_max_dev number(10):=0;
      v_max_fec_insercion date;
      v_sal_cuenta    NUMBER(22, 2);
      v_nro_orden   number(4);
      ------------------------- DEFINE MOVIMIENTOS -----------------------------
     CURSOR movimien1 IS
        SELECT d.cod_modulo,
                    d.cod_modalidad,
                    d.cod_oficina,
                    cod_sec_contable,
                    cod_tip_deudor,
                    residente,
                    d.cod_moneda,
                    'N' sit_saldo,
                    1 cod_plazo,
                    d.nro_cuenta,
                    c.cod_persona
                    ,null as cod_rubro
                    ,'CAN' as tip_tabla,
                    d.Sal_Contable,
                    1 as nro_orden
               FROM ge_clientes c, ge_cta_clientes b, GE_DAT_CANCELACION d
              WHERE c.cod_persona = b.cod_persona
               AND d.nro_cuenta = b.nro_cuenta
                and nvl(d.Procesado,'N')='S'
                and b.relacion='P';


   /****************INICIO DE PROCESO PRINCIPAL*********************+*/
   BEGIN


       ------------------------- LEER MOVIMIEN ------------------------------
      OPEN movimien1;
      LOOP
         FETCH movimien1
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_sec_contable,
                 v_cod_tip_deudor,
                 v_residente,
                 v_cod_moneda,
                 v_sit_saldo,
                 v_cod_plazo,
                 v_nro_cuenta,
                 v_cod_persona,
                 v_cod_rubro,
                 v_tip_tabla,
                 v_sal_cuenta,
                 v_nro_orden;
         EXIT WHEN movimien1%NOTFOUND;
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE SALDO (CAPITAL, INTERES O DEVENGADO) ---
         --------------------------------------------------------------
         v_tip_saldo := 'M'/*'B'*/;  --Ponemos Interes
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE INTERES (X = NO IMPORTA)              --
         --------------------------------------------------------------
         v_tip_interes := 'X';
         --------------------------------------------------------------
         -- OBTIENE EL TIPO DE PRESTAMO (X = NO IMPORTA)             --
         --------------------------------------------------------------
         v_tip_credito := 'X';
         --------------------------------------------------------------

         --- busco la cuenta que le corresponde al saldo ----
         /* v_cod_transaccion := 602;
         LP_OBT_COD_RUBRO(v_cod_modulo,v_cod_modalidad,v_cod_transaccion,
                          v_cod_moneda,V_cod_sec_contable,v_cod_tip_deudor,
                          v_residente,TO_CHAR(v_cod_plazo),'C',v_cod_rubro);*/
      v_sal_cta_tot:=0;
      v_nro_cuo_max_dev:=0;
      v_cod_rubro:=null;
      v_max_fec_insercion:=null;
      v_sal_cta_tot:= v_sal_cuenta;
      if nvl(v_sal_cta_tot,0) >= 0 then
        --Tipo de Movimiento para el credito

            v_cod_rubro       := NULL;
            v_cod_rubro:=fug_obt_pardinamico('COD_RUB_CAN_CTA_ACRE',null,null,v_cod_moneda, null,null);
            BEGIN

               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

               INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_cta_tot), v_cod_rubro,
                     v_nro_referencia);

               INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_cta_tot), 0);

            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
            -----------------------------------------------------
            -- Debito --

            v_cod_rubro       := NULL;
            v_cod_rubro:=fug_obt_pardinamico('COD_RUB_CAN_CTA_DEU',null,null,v_cod_moneda, null,null);

            BEGIN
               ----------------------------------------
               SELECT s_nro_referencia.nextval INTO v_nro_referencia FROM dual;

              INSERT INTO cb_sal_inventarios
                    (cod_modulo, cod_modalidad, cod_oficina, cod_sec_contable, cod_tip_deudor,
                     residente, cod_moneda, situacion, tip_saldo, cod_plazo, tip_operacion,
                     tip_interes, sal_total, cod_rubro, nro_referencia)
                 VALUES
                    (v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_sec_contable,
                     v_cod_tip_deudor, v_residente, v_cod_moneda, v_sit_saldo, v_tip_saldo,
                     v_cod_plazo, v_tip_credito, v_tip_interes, abs(v_sal_cta_tot), v_cod_rubro,
                     v_nro_referencia);

              INSERT INTO cb_sal_inventarios_det
                  (nro_referencia, nro_cuenta, sal_actual, sal_anterior)
               VALUES
                  (v_nro_referencia, v_nro_cuenta, abs(v_sal_cta_tot), 0);

            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
        end if;


      END LOOP;
      CLOSE movimien1;

   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'ERROR en lp_can_cta_pen_can ' || SQLERRM);
   END;


   -- PROCESO PRINCIPAL ---
BEGIN
   begin delete ge_log_procesos where cod_programa = 'PRB_GEN_SAL_INVENTARIOS'; end;
   --- cero los saldos de inventario(total y detalle) ----------
   --- Modificado por ICL 07/08/2010 porque hace full y enlentece el proceso.
   sql_util.ejecute_dml('TRUNCATE TABLE CB_SAL_INVENTARIOS', v_msj);

   IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
   END IF;
   sql_util.ejecute_dml('TRUNCATE TABLE CB_SAL_INVENTARIOS_DET', v_msj);
   IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
   END IF;
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Ahorro a la Vista.
   lp_acu_ahorro_a_la_vista;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_AHORRO_A_LA_VISTA',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Ahorros a Plazo
   lp_acu_ahorro_a_plazo;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_AHORRO_A_PLAZO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Cda y Cupones.
   lp_acu_cda_y_cupones;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CDA_Y_CUPONES',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Prestamos.
   lp_acu_prestamos;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_PRESTAMOS',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Cuentas Corrientes.
   lp_acu_ctacte_normal;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CTACTE_NORMAL',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   lp_acu_ctacte_sobregiro;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CTACTE_SOBREGIRO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Cuentas Bancarias.
   lp_acu_ctaban_normal;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CTABAN_NORMAL',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   lp_acu_ctaban_sobregiro;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CTABAN_SOBREGIRO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Tarjetas de Credito.
   lp_acu_tarjetas;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_TARJETAS',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Comercio Exterior.
   lp_acu_com_exterior;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_COM_EXTERIOR',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Mesa de dinero.
   lp_acu_mes_dinero;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_MES_DINERO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');


   --Caja.
   lp_acu_caja; --Procedimiento agreagado por Carolina (Simgia)
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CAJA',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Documentos Pendientes de Confirmacion(Retenido)
   --LP_ACU_DOCPEND;  --SIEMPRE COMENTADO

   --Transferencias Recibidas.
   --LP_ACU_TRANS;     --SIEMPRE COMENTADO

   --Cheques Certificados.
   lp_acu_cheqcert;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CHEQCERT',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Bonos Subordinados
   lp_acu_bonos_sub; --Procedimiento agregado por Ana Azorero - Set 2010
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_BONOS_SUB',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Bienes del Activo Fijo
   lp_acu_activo;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_ACTIVO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Cheque Gerencia
   lp_acu_che_geren;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_CHE_GEREN',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --ATM
   lp_acu_atm;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_ATM',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   ---Operaciones vencidas
   lp_acu_ope_venc;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_OPE_VENC',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Cuentas embargadas
   lp_cta_embargos;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_CTA_EMBARGOS',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Garantias
   --LP_ACU_GARANTIA;    SIEMPRE COMENTADO
   --Deshabilitado por implementacion de Garantias en ITGF

   --Previsiones y valuaciones de prestamos
   lp_acu_prev_prest;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_PREV_PREST',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Valuaciones de sobregiros
   lp_acu_val_sobr;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_VAL_SOBR',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Previsiones de sobregiros
   lp_acu_prev_sobr;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_PREV_SOBR',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Garantias computables y no computables
   lp_acu_gara_comp;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_GARA_COMP',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Bienes Adjudicados
   lp_acu_bie_adju;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_BIE_ADJU',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   ---Forward
   lp_acu_forward;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_FORWARD',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   lp_acu_for_valeco;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_FOR_VALECO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Dep?sitos Overnight
   lp_acu_dep_overnight;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_DEP_OVERNIGHT',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   lp_acu_dep_ove_sobregiro;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_DEP_OVE_SOBREGIRO',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Gastos Diferidos
   lp_acu_gas_diferidos;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss') ;
   lp_logeo('LP_ACU_GAS_DIFERIDOS',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   -- Saldos y devengado re4
   lp_acu_sal_dev_re4;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_ACU_SAL_DEV_RE4',v_hor_ini,v_hor_fin);
   v_hor_ini := to_char(sysdate,'hh24:mi:ss');

   --Dep.Dat. Ctas. Pend. de Cancel.
   lp_can_cta_pen_can;
   v_hor_fin := to_char(sysdate,'hh24:mi:ss');
   lp_logeo('LP_CAN_CTA_PEN_CAN',v_hor_ini,v_hor_fin);
   COMMIT;
END PRB_GEN_SAL_INVENTARIOS;
/
