CREATE OR REPLACE PROCEDURE IT.PRC_GEN_PREVISIONES /* Previsión de Cuentas en Sobregiro */
 IS
   /* Obtener garantia computable.  */
   FUNCTION lf_obt_gar_com
   (
      p_nro_cuenta IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_tot_deuda  IN pr_cta_prestamos.sal_capital%TYPE,
      p_tot_cash   OUT pr_cta_prestamos.sal_capital%TYPE -- me indica si tiene un importe correspondiente a cash collateral para aplicar 100%.
   ) RETURN NUMBER;

   /* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
   FUNCTION lf_obt_cat_prevision
   (
      p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE
   ) RETURN NUMBER;

   /* Insertar registros en la tabla de previsiones de sobregiros. */
   PROCEDURE lp_ins_prevision(rp_cprev IN cc_previsiones%ROWTYPE);

   /* AP 2875-Obtener previsión y contingencia día anterior. */
   PROCEDURE lp_obt_prv_dia_anterior
   (
      p_nro_cuenta       IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_fec_actual       IN DATE,
      p_mto_prevision    OUT cc_previsiones.monto%TYPE,
      p_mto_contingencia OUT cc_previsiones.monto%TYPE,
      p_ind_pri_sem_cat6 OUT cc_previsiones.ind_pri_sem_cat6%type
   );

   /* AP 2875-Obtener previsión y contingencia año anterior */
   PROCEDURE lp_obt_prv_per_anterior
   (
      p_nro_cuenta       IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_fec_actual       IN DATE,
      p_mto_prevision    OUT cc_previsiones.monto%TYPE,
      p_mto_contingencia OUT cc_previsiones.monto%TYPE
   );

   /* Proceso de previsiones: Consideraciones a tener en cuenta con el analisis:
   - Debe tomar las operaciones que tienen algo previsionado o pueden previsionar en el sistema, es decir, desde el inicio y aun despues de ser canceladas y aun tener previsión aplicada.
   - La previsión actual debe calcularse luego de la categorizacion, ya que se ve influido por este.
   - La previsión debe poder ajustar la previsión contable, esto afectar o desafectar previsiones de acuerdo a lo ya previsionado por la operacion.
   - Debe mantenerse una tabla independiente de previsión para saber cuando se afecto o desafecto a una fecha dada.
   Secuencia de Procesos
   - Cambio de Estado
   - Categorizacion
   - Previsión */
   v_fec_actual           ge_calendarios.fec_actual%TYPE;
   v_cod_mon_local        ba_monedas.cod_moneda%TYPE;
   v_por_riesgo_1a        pr_parametros.por_riesgo_1a%TYPE;
   v_por_riesgo_1b        pr_parametros.por_riesgo_1b%TYPE;
   v_por_riesgo_2         pr_parametros.por_riesgo_2%TYPE;
   v_por_riesgo_3         pr_parametros.por_riesgo_3%TYPE;
   v_por_riesgo_4         pr_parametros.por_riesgo_4%TYPE;
   v_por_riesgo_5         pr_parametros.por_riesgo_5%TYPE;
   v_por_riesgo_6         pr_parametros.por_riesgo_6%TYPE;
   v_porcentaje           NUMBER(6, 2);
   v_capital              cc_cta_corrientes.sal_total%TYPE;
   --AP 2875
   v_gar_cartera          pr_cta_garantias.mto_apl_computable%TYPE;
   v_gar_contingencia     pr_cta_garantias.mto_apl_computable%TYPE;
   v_prv_contingencia     cc_previsiones.monto%TYPE;
   v_prv_con_anterior     cc_previsiones.monto%TYPE;
   v_prv_con_per_anterior pr_previsiones.monto%TYPE;
   v_dif_contingencia     cc_previsiones.monto%TYPE;
   v_dif_prv_contingencia pr_previsiones.monto%TYPE;
   v_redondeo             NUMBER(2);
   --
   v_contingencia         cc_cta_corrientes.sal_total%TYPE;
   v_garantia             cc_cta_garantias.mto_apl_computable%TYPE;
   v_prevision            cc_previsiones.monto%TYPE;
   v_prv_anterior         cc_previsiones.monto%TYPE;
   v_diferencia           cc_previsiones.monto%TYPE;
   r_cprev                cc_previsiones%ROWTYPE;
   r_gmovi                ge_movimientos%ROWTYPE;
   v_nro_secuencia        ge_movimientos.nro_secuencia%TYPE;
   v_hora                 ge_movimientos.hora%TYPE;
   v_categoria            ge_clientes.cat_automatica%TYPE;
   v_cot_auxiliar         ge_cotizaciones.val_conversion%TYPE;
   --- Variables para Res 1
   v_pri_prevision        NUMBER(18, 2);
   v_neto                 ge_cla_operaciones.tot_deu_real%TYPE;
   v_dias_cat             NUMBER(10);
   v_tot_cash             pr_cta_garantias.mto_apl_computable%TYPE; -- total de garantias tipo cash collateral
   v_tot_apl              pr_cta_garantias.mto_con_computable%TYPE; -- saldo de riesgo a previsionar
   v_prv_per_anterior     pr_previsiones.monto%TYPE;
   v_dif_prevision        pr_previsiones.monto%TYPE;
   v_cat_cli_prevision    ge_cla_operaciones.cat_automatica%TYPE;
   v_cta_registro         cc_cta_corrientes.nro_cuenta%type;
   v_lugar                varchar(250);
   v_por_previsionado pr_previsiones.porcentaje%type;
   v_por_pri_semestre pr_previsiones.porcentaje%type;
   v_por_calculado pr_previsiones.porcentaje%type;
   v_por_cal_contingencia pr_previsiones.porcentaje%type;
   v_ind_pri_sem_cat6 pr_previsiones.ind_pri_sem_cat6%type;
   v_ind_pri_sem_cat6_ant pr_previsiones.ind_pri_sem_cat6%type;
   v_usu_mig_excluir varchar2(30);
   v_usuario ba_usuarios.cod_usuario%type;
   v_can_user number;
   -- coleccion para manejar nro_secuencia por cod_usuario de manera mas equitativa 
   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;
   
   TYPE t_usu_hor IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora t_usu_hor;
   --- Cursor de sobregiros a calcular
   CURSOR c_cta_corrientes IS
      SELECT p.nro_cuenta, p.cod_moneda, c.cod_persona, c.cat_riesgo cat_automatica,
             c.cat_automatica situacion, p.estado, p.cod_modalidad, p.cod_oficina,
             (nvl(p.sal_total, 0) - nvl(p.sal_bloqueado, 0) - nvl(p.sal_retenido, 0)) saldo,
             decode(nvl(p.cod_ente, -1), -1, 0, nvl(g.linea, 0)) linea_de_credito, -- ICL 22/03/2012 Mail HB: Solo se considera contingencia Plan Nomina
             p.cod_modulo, c.cod_gru_economico, nvl(o.dia_atraso, 0) dia_atraso, c.fec_ult_clasif,
             nvl(f.sit_deuda, p.estado) sit_deuda,
             c.cat_gru_economico								
        FROM ge_clientes        c,
             ge_cta_clientes    cc,
             cc_cta_corrientes  p,
             ge_cla_operaciones o,
             (SELECT SUM(monto) linea, c.nro_cuenta
                FROM cc_lin_sobregiros c
               WHERE c.estado = 'A' --- ICL 26/03/2012
               GROUP BY c.nro_cuenta) g,
             (SELECT can_dias dias_sobregiro, d.nro_cuenta, d.sit_deuda
                FROM cc_sobregiros_res d) f
       WHERE p.nro_cuenta    = cc.nro_cuenta
         AND o.nro_cuenta(+) = p.nro_cuenta
         AND g.nro_cuenta(+) = p.nro_cuenta
         AND f.nro_cuenta(+) = p.nro_cuenta
         --Agregado para no insertar ctas que ya inserto previamente en el dia--
         AND not exists (select 1
                           from cc_previsiones x
                          where x.fecha = v_fec_actual
                            and x.nro_cuenta = p.nro_cuenta)
         AND cc.relacion     = 'P'
         AND cc.cod_persona  = c.cod_persona
         and (v_usu_mig_excluir is null or p.usu_insercion <> v_usu_mig_excluir)
         AND (p.estado       NOT IN (/*'I',*/ 'C') OR  --DYDMR-3569 Se incluyen las cuentas inactivas que poseen atraso - ALV 2016
             (p.estado       = 'C' AND trunc(p.fec_cam_estado) = v_fec_actual));
   /* Obtener garantia computable. */
   FUNCTION lf_obt_gar_com
   (
      p_nro_cuenta IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_tot_deuda  IN pr_cta_prestamos.sal_capital%TYPE,
      p_tot_cash   OUT pr_cta_prestamos.sal_capital%TYPE -- me indica si tiene un importe correspondiente a cash collateral para aplicar 100%.
   ) RETURN NUMBER IS
      v_gar_compu cc_cta_garantias.mto_apl_computable%TYPE := 0;
      v_gar_cash  pr_cta_garantias.mto_con_computable%TYPE := 0;
      v_tot_gara  cc_cta_garantias.mto_apl_computable%TYPE := 0;
      v_cot_aux   ge_cotizaciones.val_conversion%TYPE;
      CURSOR c_garantias IS
         SELECT g.mto_apl_computable, t.cod_garantia
           FROM cc_cta_garantias g,
                pr_gar_tipos     t
          WHERE g.nro_cuenta   = p_nro_cuenta
            AND g.cod_garantia = t.cod_garantia
            AND t.computable   = 'S'
            AND nvl(g.mto_apl_computable, 0) > 0;
   BEGIN
      v_tot_gara := 0;
      FOR reg IN c_garantias LOOP
         v_cot_aux   := NULL;
         v_gar_compu := nvl(reg.mto_apl_computable, 0);
         --- totalizar garantias computables en moneda de la cuenta ---------
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
         IF reg.cod_garantia IN (5, 19, 21) THEN
            v_gar_cash := v_gar_cash + nvl(v_gar_compu, 0);
         END IF;
         p_tot_cash := v_gar_cash;
      END LOOP;
      RETURN v_tot_gara;
   END;

   /* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE)
   RETURN NUMBER AS
      v_categoria ge_cla_operaciones.cat_automatica%TYPE;
   BEGIN
      --Verifico las operaciones que posee el cliente.
      SELECT nvl(MAX(a.cat_automatica), 1)
        INTO v_categoria
        FROM ge_cla_operaciones a
       WHERE a.cod_persona = p_cod_persona;
      RETURN v_categoria;
   EXCEPTION
      WHEN OTHERS THEN
         v_categoria := 1;
         RETURN v_categoria;
   END;

   /* Insertar registros en la tabla de previsiones de prestamos. */
   PROCEDURE lp_ins_prevision(rp_cprev IN cc_previsiones%ROWTYPE) IS
   BEGIN
      INSERT INTO cc_previsiones
         (fecha, nro_cuenta, monto, saldo, linea,
          porcentaje, situacion, tot_gar_computable,
          tot_pri_prevision, tot_prv_contingencia,
          mto_pre_anterior, por_pre_anterior, por_calculado, ind_pri_sem_cat6) --AP 2875
      VALUES
         (rp_cprev.fecha, rp_cprev.nro_cuenta, rp_cprev.monto, rp_cprev.saldo, rp_cprev.linea,
          rp_cprev.porcentaje, rp_cprev.situacion, rp_cprev.tot_gar_computable,
          rp_cprev.tot_pri_prevision, rp_cprev.tot_prv_contingencia,
          rp_cprev.Mto_pre_anterior, rp_cprev.Por_pre_Anterior, rp_cprev.Por_Calculado, rp_cprev.ind_pri_sem_cat6); --AP 2875
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al Insertar la Previsión de la Cuenta: '||rp_cprev.nro_cuenta||' -'|| SQLERRM);
   END;
   --AP 2875
   /* Obtener previsión y contingencia dia anterior. */
   PROCEDURE lp_obt_prv_dia_anterior
   (
      p_nro_cuenta       IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_fec_actual       IN DATE,
      p_mto_prevision    OUT cc_previsiones.monto%TYPE,
      p_mto_contingencia OUT cc_previsiones.monto%TYPE,
      p_ind_pri_sem_cat6 OUT cc_previsiones.ind_pri_sem_cat6%type
   ) IS
   BEGIN
      SELECT nvl(SUM(nvl(monto, 0) - nvl(tot_prv_contingencia, 0)), 0),
             nvl(SUM(nvl(tot_prv_contingencia, 0)), 0), ind_pri_sem_cat6
        INTO p_mto_prevision, p_mto_contingencia, p_ind_pri_sem_cat6
        FROM cc_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha      = (SELECT MAX(fecha)
                             FROM cc_previsiones
                            WHERE nro_cuenta = p_nro_cuenta
                              AND fecha      <= p_fec_actual)
       group by ind_pri_sem_cat6 ;
   EXCEPTION
      WHEN OTHERS THEN
         p_mto_prevision    := 0;
         p_mto_contingencia := 0;
   END;
   --AP 2875
   /* Obtener previsión y contingencia año anterior */
   PROCEDURE lp_obt_prv_per_anterior
   (
      p_nro_cuenta       IN cc_cta_corrientes.nro_cuenta%TYPE,
      p_fec_actual       IN DATE,
      p_mto_prevision    OUT cc_previsiones.monto%TYPE,
      p_mto_contingencia OUT cc_previsiones.monto%TYPE
   ) IS
   BEGIN
      SELECT nvl(SUM(nvl(monto, 0) - nvl(tot_prv_contingencia, 0)), 0),
             nvl(SUM(tot_prv_contingencia), 0)
        INTO p_mto_prevision, p_mto_contingencia
        FROM cc_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha      = (SELECT MAX(fecha)
                             FROM cc_previsiones
                            WHERE nro_cuenta = p_nro_cuenta
                              AND fecha      <= round(p_fec_actual, 'year'))
         AND NOT EXISTS (SELECT 1
                           FROM cc_previsiones
                          WHERE nro_cuenta = p_nro_cuenta
                            AND fecha      >= round(p_fec_actual, 'year')
                            AND monto      = 0);
   EXCEPTION
      WHEN OTHERS THEN
         p_mto_prevision    := 0;
         p_mto_contingencia := 0;
   END;

BEGIN
   V_LUGAR := 'Inicio';
   v_fec_actual    := pag_cal.fu_obt_fec_actual(6);
   v_hora          := to_char(SYSDATE, 'HH24:MI:SS');
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   V_LUGAR         := 'pr_parametros';
   v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   --
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
   --
   BEGIN
      SELECT por_riesgo_1a, por_riesgo_1b, por_riesgo_2, por_riesgo_3, por_riesgo_4,
             por_riesgo_5, por_riesgo_6
        INTO v_por_riesgo_1a, v_por_riesgo_1b, v_por_riesgo_2, v_por_riesgo_3, v_por_riesgo_4,
             v_por_riesgo_5, v_por_riesgo_6
        FROM pr_parametros
       WHERE rownum = 1;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Parametros de riesgos no definidos');
   END;
   V_LUGAR := 'antes del loop';
   v_nro_secuencia := 0;
   FOR reg IN c_cta_corrientes LOOP
      v_cta_registro := reg.nro_cuenta;
      --- Convertir el monto de la cuenta corriente a la moneda local
      v_cot_auxiliar := NULL;
      v_capital := (CASE
                    WHEN nvl(reg.saldo, 0) > 0 THEN
                       0
                    ELSE
                       abs(nvl(reg.saldo, 0))
                    END);
      --- ICL 23/03/2012 Mail Julio Rey
      v_contingencia     := 0;
      --AP 2875
      v_gar_cartera      := 0;
      v_gar_contingencia := 0;
      v_prv_contingencia := 0;

      V_LUGAR := 'antes del lf_obt_gar_com '|| reg.nro_cuenta;

      --AP 2875
      v_garantia         := lf_obt_gar_com(reg.nro_cuenta, v_capital + v_contingencia, v_tot_cash); --no se usa /*v_capital + v_contingencia,*/

      --Determino la garantia correspondiente a cartera y contigencia.
      IF v_garantia <= v_capital THEN
         v_gar_cartera      := v_garantia;
         v_gar_contingencia := 0;
      ELSE
         v_gar_cartera      := v_capital;
         v_gar_contingencia := v_garantia - v_capital;
      END IF;

      IF nvl(reg.saldo, 0) > 0 THEN
         v_contingencia := nvl(reg.linea_de_credito, 0);
      ELSIF abs(nvl(reg.saldo, 0)) > nvl(reg.linea_de_credito, 0) THEN
         v_contingencia := 0;
      ELSE
         v_contingencia := nvl(reg.linea_de_credito, 0) - abs(nvl(reg.saldo, 0));
      END IF;
      ---
      v_categoria     := trunc(reg.cat_automatica);
      v_prevision     := 0;
      v_pri_prevision := 0;
      v_tot_cash      := 0;
      ---
      IF v_categoria = 1 THEN
         v_cat_cli_prevision := lf_obt_cat_prevision(reg.cod_persona);
         IF v_cat_cli_prevision < 2 THEN -- Solo Cat 1, 1a, 1b
		 
		   /*FIELDESK-160732: Evaluar si la categoría del grupo económico es mayor*/
			IF reg.cat_gru_economico > v_cat_cli_prevision THEN
			    v_cat_cli_prevision := reg.cat_gru_economico;
			END IF;
			
            v_porcentaje := (CASE WHEN reg.dia_atraso > 0 AND v_cat_cli_prevision = 1.1 THEN
                                     v_por_riesgo_1a
                                  WHEN reg.dia_atraso > 0 AND v_cat_cli_prevision > 1.1 THEN
                                     v_por_riesgo_1b
                                  ELSE 0
                             END);
         ELSE --Cat 2..6
            v_porcentaje := v_por_riesgo_1b;
         END IF;
      ELSIF v_categoria = 2 THEN
         v_porcentaje := v_por_riesgo_2;
      ELSIF v_categoria = 3 THEN
         v_porcentaje := v_por_riesgo_3;
      ELSIF v_categoria = 4 THEN
         v_porcentaje := v_por_riesgo_4;
      ELSIF v_categoria = 5 THEN
         v_porcentaje := v_por_riesgo_5;
      ELSIF v_categoria = 6 THEN
         v_porcentaje := v_por_riesgo_6;
      ELSE
         v_porcentaje := 0;
      END IF;

      V_LUGAR := 'REALIZAR PRIMERA PREVISIÓN '|| reg.nro_cuenta;

      --- REALIZAR PRIMERA PREVISIÓN
      --- Aplicar el 50% de la previsión obtenida al neto de la deuda
      v_porcentaje := v_porcentaje / 2;
      v_tot_apl    := nvl(v_capital, 0);
      IF v_tot_cash > 0 THEN -- si tiene garantia cash
         IF v_tot_cash >= v_tot_apl THEN -- el cash es mayor que la deuda, cubre todo
            v_tot_apl  := 0;
            v_garantia := v_garantia - v_tot_apl; -- restar lo utilizado
         ELSE -- la deuda es mayor que el cash
            v_tot_apl  := v_tot_apl - v_tot_cash;
            v_garantia := v_garantia - v_tot_cash; -- restar el cash de la garantia total
         END IF;
      END IF; -- si no tiene cash, el total aplicar es la deuda total

      --AP 2875 agregar redondeo
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo, reg.cod_modalidad, reg.cod_moneda);
      --
      -- hallar primera previsión s/ el saldo a aplicar
      IF v_cod_mon_local = reg.cod_moneda THEN
         v_prevision := round(nvl(v_tot_apl, 0) * v_porcentaje / 100, v_redondeo);
      ELSE
         v_prevision := round(nvl(v_tot_apl, 0) * v_porcentaje / 100, v_redondeo);
      END IF;

      V_LUGAR := 'HALLAR VALOR COMPUTABLE DE LA GARANTIA  ' || reg.nro_cuenta;

      --- HALLAR VALOR COMPUTABLE DE LA GARANTIA
      IF nvl(v_gar_cartera, 0) = 0 AND nvl(v_tot_cash, 0) = 0 THEN --AP 2875
         --- Segun modificacion a Res. 8 IX. Regimenes de previsiones Inc. 29.
         --- Esta metodologia de calculo no se aplicara cuando los prestamos carezcan de garantia
         --- en cuyo caso el % de previsión se aplicara sobre el saldo total de la deuda
         v_prevision  := 0;
         v_porcentaje := v_porcentaje * 2;
      ELSE
         IF v_categoria = 6 THEN
            v_porcentaje := v_porcentaje * 2;
         END IF;
      END IF;

      v_pri_prevision := v_prevision;
      --- REALIZAR SEGUNDA PREVISIÓNro
      v_neto := nvl(v_capital, 0) - nvl(v_gar_cartera, 0) - nvl(v_tot_cash, 0) - v_prevision; --AP 2875
      IF v_neto < 0 THEN
         v_neto := 0;
      END IF;

      --- Calcular cantidad de dias desde la ultima clasificacion
      lp_obt_prv_dia_anterior(reg.nro_cuenta, v_fec_actual, v_prv_anterior, v_prv_con_anterior, v_ind_pri_sem_cat6_ant);
      v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
      IF reg.cat_automatica = 6 AND v_gar_cartera > 0 AND v_dias_cat >= 545 THEN --AP 2875 725= 365 días (que está en la categoría 6) + 360 días (2 semestres de 180 días cada 1)
         --- Previsiones Genericas - Solo si tiene garantia
         v_por_previsionado := 0;
         v_ind_pri_sem_cat6 := v_ind_pri_sem_cat6_ant;
         v_por_previsionado := round(nvl(v_prv_anterior, 0)/v_capital * 100,2);

         if v_dias_cat >= 725 then -- 725= 365 días (que está en la categoría 6) + 360 días (2 semestres de 180 días cada 1)
            --- Se debe previsionar el 100% de la deuda
            v_prevision  := v_capital;
            v_porcentaje := 100;
            v_por_calculado := 100;
         --545 = 365 días (que está en la categoría 6) + 180 días (1 semestre)
         elsif v_dias_cat >= 545 and nvl(v_ind_pri_sem_cat6, 'N') = 'N' then
           v_por_pri_semestre := 100 - v_por_previsionado;
           if v_por_pri_semestre > 25 then
              v_por_pri_semestre := v_por_pri_semestre -25;
           end if;

           v_por_calculado := nvl(v_por_previsionado, 0) + nvl(v_por_pri_semestre, 0);

           if v_por_calculado = 100 then
               v_prevision := v_capital;
           else
               v_prevision := round(v_prv_anterior + (nvl(v_capital,0)* v_por_pri_semestre/100),v_redondeo);
           end if;

           v_porcentaje := 100;
           v_neto          := v_capital;
           v_ind_pri_sem_cat6 := 'S';
         END IF;
      ELSE
         v_por_previsionado := null;
         v_por_calculado := null;
         v_ind_pri_sem_cat6 := null;

         IF v_cod_mon_local = reg.cod_moneda THEN
            v_prevision := v_prevision + round(nvl(v_neto, 0) * v_porcentaje / 100, v_redondeo);
         ELSE
            v_prevision := v_prevision + round(nvl(v_neto, 0) * v_porcentaje / 100, v_redondeo);
         END IF;
      END IF;

      V_LUGAR := 'REALIZAR PRIMERA PREVISIÓN CONTIGENCIA  ' || reg.nro_cuenta;

      --- REALIZAR PRIMERA PREVISIÓN CONTIGENCIA
      --- Aplicar el 50% de la previsión obtenida al neto de la deuda
      --- A excepcion de las categorias 1 y 2 en las cuales se aplicaria el 100%
      --AP 2875
      IF v_contingencia > 0 THEN
         --Determino el porcentaje de previsión.
         IF v_categoria = 1 THEN
         IF v_cat_cli_prevision < 2 THEN -- Solo Cat 1, 1a, 1b
            v_porcentaje := (CASE WHEN reg.dia_atraso > 0 AND v_cat_cli_prevision = 1.1 THEN
                                     v_por_riesgo_1a
                                  WHEN reg.dia_atraso > 0 AND v_cat_cli_prevision > 1.1 THEN
                                     v_por_riesgo_1b
                                  ELSE 0
                             END);
         ELSE --Cat 2..6
            v_porcentaje := v_por_riesgo_1b;
         END IF;
         ELSIF v_categoria = 2 THEN
            v_porcentaje := v_por_riesgo_2;
         ELSIF v_categoria = 3 THEN
            v_porcentaje := v_por_riesgo_3;
         ELSIF v_categoria = 4 THEN
            v_porcentaje := v_por_riesgo_4;
         ELSIF v_categoria = 5 THEN
            v_porcentaje := v_por_riesgo_5;
         ELSIF v_categoria = 6 THEN
            v_porcentaje := v_por_riesgo_6;
         ELSE
            v_porcentaje := 0;
         END IF;

         v_porcentaje := v_porcentaje / 2;
         IF v_cod_mon_local = reg.cod_moneda THEN
            v_prv_contingencia := round(nvl(v_contingencia, 0) * v_porcentaje / 100, v_redondeo);
         ELSE
            v_prv_contingencia := round(nvl(v_contingencia, 0) * v_porcentaje / 100, v_redondeo);
         END IF;

         --- HALLAR VALOR COMPUTABLE DE LA GARANTIA
         IF nvl(v_gar_contingencia, 0) = 0 THEN
            --- Segun modificacion a Res. 8 IX. Regimenes de previsiones Inc. 29.
            --- Esta metodologia de calculo no se aplicara cuando los prestamos carezcan de garantia
            --- en cuyo caso el % de previsión se aplicara sobre el saldo total de la deuda
            v_prv_contingencia := 0;
            v_porcentaje       := v_porcentaje * 2;
         END IF;

         v_pri_prevision := nvl(v_pri_prevision, 0) + nvl(v_prv_contingencia, 0);
         --- REALIZAR SEGUNDA PREVISIÓN
         v_neto := nvl(v_contingencia, 0) - nvl(v_gar_contingencia, 0) - v_prv_contingencia;
         IF v_neto < 0 THEN
            v_neto := 0;
         END IF;

         --- Calcular cantidad de dias desde la ultima clasificacion
         v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
         IF reg.cat_automatica = 6 AND v_gar_contingencia > 0 AND v_dias_cat >= 545 THEN
            v_por_previsionado := 0;
            v_ind_pri_sem_cat6 := v_ind_pri_sem_cat6_ant;
            v_por_previsionado := round(nvl(v_prv_con_anterior, 0)/ v_contingencia * 100,2);

            if v_dias_cat >= 725 then -- 725= 365 días (que está en la categoría 6) + 360 días (2 semestres de 180 días cada 1)
              -- al a?o tengo que previsionar el 100% de la deuda
              --- Se debe previsionar el 100% de la deuda
              v_prv_contingencia := v_contingencia;
              v_porcentaje       := 100;
              v_por_cal_contingencia := 100;
            --545 = 365 días (que está en la categoría 6) + 180 días (1 semestre)
            elsif v_dias_cat >= 545 and nvl(v_ind_pri_sem_cat6_ant, 'N') = 'N' then
              v_por_pri_semestre := 100 - v_por_previsionado;
              if v_por_pri_semestre > 25 then
                 v_por_pri_semestre := v_por_pri_semestre -25;
              end if;

              v_por_cal_contingencia := nvl(v_por_previsionado, 0) + nvl(v_por_pri_semestre, 0);

              if v_por_cal_contingencia = 100 then
                 v_prv_contingencia := v_contingencia;
              else
                 v_prv_contingencia := round(v_prv_con_anterior + (nvl(v_contingencia,0)* v_por_pri_semestre/100),v_redondeo);
              end if;
               -- a los 6 primeros meses tengo que previsionar 25% mas es decir 75% de la deuda
               v_ind_pri_sem_cat6 := 'S';
               v_porcentaje := 100;
             END IF;
         ELSE
            IF v_cod_mon_local = reg.cod_moneda THEN
               v_prv_contingencia := v_prv_contingencia + round(nvl(v_neto, 0) * v_porcentaje / 100, v_redondeo);
            ELSE
               v_prv_contingencia := v_prv_contingencia + round(nvl(v_neto, 0) * v_porcentaje / 100, v_redondeo);
            END IF;
         END IF;
      END IF;

      V_LUGAR := 'Recuperar previsión anterior si la tuviere  ' || reg.nro_cuenta;
      --- Recuperar previsión anterior si la tuviere     
      lp_obt_prv_per_anterior(reg.nro_cuenta, v_fec_actual, v_prv_per_anterior, v_prv_con_per_anterior);
      --
      v_diferencia           := 0;
      v_dif_prevision        := 0;
      v_dif_prv_contingencia := 0; --AP 2875

      --- Inicializar datos cabecera del movimiento
      r_gmovi.fecha          := v_fec_actual;
      r_gmovi.fec_valor      := v_fec_actual;
      r_gmovi.cod_mod_padre  := reg.cod_modulo;
      r_gmovi.cod_mad_padre  := reg.cod_modalidad;
      r_gmovi.cod_modulo     := reg.cod_modulo;
      r_gmovi.cod_modalidad  := reg.cod_modalidad;
      r_gmovi.cod_oficina    := reg.cod_oficina;
      r_gmovi.cod_ofi_origen := reg.cod_oficina;
      r_gmovi.cod_moneda     := reg.cod_moneda;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.protegido      := 'N';
      r_gmovi.nro_cuenta     := reg.nro_cuenta;

      --Determino el estado de la cuenta.
      IF reg.sit_deuda = 'S' THEN
         r_gmovi.est_cuenta := 'N';
      ELSE
         r_gmovi.est_cuenta := reg.sit_deuda;
      END IF;
     
      IF reg.estado = 'C' THEN
         IF nvl(v_prv_anterior, 0) > 0 THEN
            IF v_prv_anterior >= v_prv_per_anterior THEN
               --- Reversar la previsión por cancelacion de sobregiro  
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 4731;
               r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES';
               r_gmovi.monto           := nvl(v_prv_per_anterior, 0);

               IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;

               --- Desafectar la previsión por cancelacion de sobregiro
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 731;
               r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
               r_gmovi.monto           := (nvl(v_prv_anterior, 0) - nvl(v_prv_per_anterior, 0));

               IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;

            ELSE             
               --- Reversar la previsión por cancelacion de sobregiro
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 731;
               r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';
               r_gmovi.monto           := v_prv_anterior;

               IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);                  
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;
            END IF;
         END IF;

         -->AP 2875
         IF nvl(v_prv_con_anterior, 0) > 0 THEN
            IF v_prv_con_anterior >= v_prv_con_per_anterior THEN
               --- Reversar la previsión de la contingencia por cancelación de sobregiro              
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 7757;
               r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES DE CONTINGENCIA';
               r_gmovi.monto           := v_prv_con_per_anterior;

               IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;
                               
               --- Desafectar la previsión de la contingencia por cancelación de sobregiro
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 757;
               r_gmovi.concepto        := 'EXTORNO DE PREVISIONES DE CONTINGENCIA';
               r_gmovi.monto           := (nvl(v_prv_con_anterior, 0) - nvl(v_prv_con_per_anterior, 0));

               IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;
            ELSE             
               --- Reversar la previsión de la contingencia por cancelacion de sobregiro  
               r_gmovi.cod_tra_padre   := 731;
               r_gmovi.cod_transaccion := 757;
               r_gmovi.concepto        := 'EXTORNO DE PREVISIONES DE CONTINGENCIA';
               r_gmovi.monto           := v_prv_con_anterior;

               IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               END IF;

            END IF;
         END IF;
 
         V_LUGAR := 'Insertar previsión ' || reg.nro_cuenta;

         -- AP 2875
         --- Insertar previsión
         r_cprev.nro_cuenta           := reg.nro_cuenta;
         r_cprev.fecha                := v_fec_actual;
         r_cprev.monto                := 0;
         r_cprev.saldo                := nvl(reg.saldo, 0);
         r_cprev.linea                := nvl(reg.linea_de_credito, 0);
         r_cprev.porcentaje           := nvl(v_porcentaje, 0);
         r_cprev.situacion            := reg.situacion;
         r_cprev.tot_gar_computable   := nvl(v_garantia, 0);
         r_cprev.tot_pri_prevision    := 0;
         r_cprev.tot_prv_contingencia := 0;
         r_cprev.mto_pre_anterior := nvl(v_prv_anterior,0);
         r_cprev.por_pre_anterior := nvl(v_por_previsionado,0);
         r_cprev.por_calculado := nvl(v_por_calculado,0);
         r_cprev.ind_pri_sem_cat6 := v_ind_pri_sem_cat6;

         lp_ins_prevision(r_cprev);

         --<
      ELSE
         v_diferencia       := nvl(v_prevision, 0) - nvl(v_prv_anterior, 0);
         v_dif_contingencia := nvl(v_prv_contingencia, 0) - nvl(v_prv_con_anterior, 0); -->AP 2875

         IF nvl(v_prevision, 0) > nvl(v_prv_per_anterior, 0) THEN
            v_dif_prevision := nvl(v_prevision, 0) - nvl(v_prv_per_anterior, 0);
         ELSE
            v_dif_prevision := nvl(v_prv_anterior, 0) - nvl(v_prv_per_anterior, 0);
         END IF;

         -->AP 2875
         IF nvl(v_prv_contingencia, 0) > nvl(v_prv_con_per_anterior, 0) THEN
            v_dif_prv_contingencia := nvl(v_prv_contingencia, 0) - nvl(v_prv_con_per_anterior, 0);
         ELSE
            v_dif_prv_contingencia := nvl(v_prv_con_anterior, 0) - nvl(v_prv_con_per_anterior, 0);
         END IF;
         --<

         if reg.cat_automatica = 6 and v_dias_cat between 545 and 724 and (v_gar_cartera > 0 or v_gar_contingencia < 0)
            and nvl(v_ind_pri_sem_cat6, 'N') = 'S' and nvl(v_ind_pri_sem_cat6_ant, 'N') = nvl(v_ind_pri_sem_cat6, 'N') then
              v_diferencia := 0;
              v_dif_contingencia := 0;
         end if;

         r_gmovi.monto := nvl(v_diferencia, 0);

         IF v_diferencia <> 0 THEN
            IF v_diferencia < 0 THEN
               IF abs(v_diferencia) > abs(v_dif_prevision) THEN
                  --- Reversar previsiones
                  r_gmovi.monto           := nvl(abs(v_dif_prevision), 0);
                  r_gmovi.cod_tra_padre   := 731;
                  r_gmovi.cod_transaccion := 731;
                  r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';

                  IF r_gmovi.monto != 0 THEN
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
                  r_gmovi.cod_usuario    := v_usuario;
                  r_gmovi.hora           := v_usu_hora(v_usuario);
                  r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
                 
                  --- Desafectar previsiones  
                  r_gmovi.monto           := (nvl(v_diferencia * -1, 0) - nvl(abs(v_dif_prevision), 0));
                  r_gmovi.cod_tra_padre   := 731;
                  r_gmovi.cod_transaccion := 4731;
                  r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
               ELSIF abs(v_diferencia) = abs(v_dif_prevision) THEN
                  --- Desafectar previsiones
                  r_gmovi.monto           := nvl(abs(v_dif_prevision), 0);
                  r_gmovi.cod_tra_padre   := 731;
                  r_gmovi.cod_transaccion := 4731;
                  r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
               ELSE
                  --- Reversar previsiones                  
                  r_gmovi.monto           := nvl(v_diferencia * -1, 0);
                  r_gmovi.cod_tra_padre   := 731;
                  r_gmovi.cod_transaccion := 731;
                  r_gmovi.concepto        := 'EXTORNO DE PREVISIONES';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
               END IF;
            ELSIF v_diferencia > 0 THEN
               --- Constituir previsiones               
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
               r_gmovi.cod_usuario    := v_usuario;
               r_gmovi.hora           := v_usu_hora(v_usuario);
               r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
               r_gmovi.cod_tra_padre   := 730;
               r_gmovi.cod_transaccion := 730;
               r_gmovi.concepto        := 'PREVISIONES A LA FECHA';
               pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            END IF;
         END IF;

         -->ap2875  ver codigos de transacciones
         r_gmovi.monto := nvl(v_dif_contingencia, 0);
         IF v_dif_contingencia <> 0 THEN
            IF v_dif_contingencia < 0 THEN
               IF abs(v_dif_contingencia) > abs(v_dif_prv_contingencia) THEN
                  --- Reversar previsiones                                  
                  r_gmovi.monto           := nvl(abs(v_dif_prv_contingencia), 0);
                  r_gmovi.cod_tra_padre   := 757;
                  r_gmovi.cod_transaccion := 757;
                  r_gmovi.concepto        := 'EXTORNO DE PREVISIONES DE CONTINGENCIA';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;                 
                  --- Desafectar previsiones de contingencia
                  r_gmovi.monto           := (nvl(v_dif_contingencia * -1, 0) - nvl(abs(v_dif_prv_contingencia), 0));
                  r_gmovi.cod_tra_padre   := 757;
                  r_gmovi.cod_transaccion := 7757;
                  r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES DE CONTINGENCIA';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
               ELSIF abs(v_dif_contingencia) = abs(v_dif_prv_contingencia) THEN
                  --- Desafectar previsiones de contingencia                     
                  r_gmovi.monto           := nvl(abs(v_dif_prv_contingencia), 0);
                  r_gmovi.cod_tra_padre   := 757;
                  r_gmovi.cod_transaccion := 7757;
                  r_gmovi.concepto        := 'DESAFECTACION DE PREVISIONES DE CONTINGENCIA';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
               ELSE                 
                  --- Reversar previsiones de contingencia                     
                  r_gmovi.monto           := nvl(v_dif_contingencia * -1, 0);
                  r_gmovi.cod_tra_padre   := 757;
                  r_gmovi.cod_transaccion := 757;
                  r_gmovi.concepto        := 'EXTORNO DE PREVISIONES DE CONTINGENCIA';

                  IF r_gmovi.monto != 0 THEN
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
                     r_gmovi.cod_usuario    := v_usuario;
                     r_gmovi.hora           := v_usu_hora(v_usuario);
                     r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;

               END IF;
            ELSIF v_dif_contingencia > 0 THEN
               --- Constituir previsiones   
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
               r_gmovi.cod_usuario    := v_usuario;
               r_gmovi.hora           := v_usu_hora(v_usuario);
               r_gmovi.nro_secuencia  := v_usu_secuencia(v_usuario);
               r_gmovi.cod_tra_padre   := 756;
               r_gmovi.cod_transaccion := 756;
               r_gmovi.concepto        := 'PREVISIONES DE LA CONTINGENCIA A LA FECHA';               
               pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            END IF;
         END IF;
                 
         --No deberia generar previsiones negativas, si genera es por error de calculos
         IF ((nvl(v_prevision, 0) + nvl(v_prv_contingencia, 0)) != 0) OR
            v_diferencia < 0 OR
            v_dif_contingencia < 0 THEN
            --AP 2857
            --- Insertar previsión
            r_cprev.nro_cuenta           := reg.nro_cuenta;
            r_cprev.fecha                := v_fec_actual;
            r_cprev.monto                := nvl(v_prevision, 0) + nvl(v_prv_contingencia, 0);
            r_cprev.saldo                := nvl(reg.saldo, 0);
            r_cprev.linea                := nvl(reg.linea_de_credito, 0);
            r_cprev.porcentaje           := nvl(v_porcentaje, 0);
            r_cprev.situacion            := reg.situacion;
            r_cprev.tot_gar_computable   := nvl(v_garantia, 0);
            r_cprev.tot_pri_prevision    := nvl(v_pri_prevision, 0);
            r_cprev.tot_prv_contingencia := nvl(v_prv_contingencia, 0);
            r_cprev.mto_pre_anterior := nvl(v_prv_anterior,0);
            r_cprev.por_pre_anterior := nvl(v_por_previsionado,0);
            r_cprev.por_calculado := nvl(v_por_calculado,0);
            r_cprev.ind_pri_sem_cat6 := v_ind_pri_sem_cat6;

            lp_ins_prevision(r_cprev);
         END IF;
         BEGIN
            UPDATE ge_cla_operaciones
               SET tot_prevision     = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, (nvl(v_prevision, 0) + nvl(v_prv_contingencia, 0))),
                   tot_pri_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, nvl(v_pri_prevision, 0)),
                   tot_cap_pri_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, nvl(v_pri_prevision, 0)),
                   tot_cap_seg_prevision = pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, (nvl(v_prevision, 0) + nvl(v_prv_contingencia, 0))) - pag_gen.fu_con_mon_a_moneda(cod_moneda, v_cod_mon_local, nvl(v_pri_prevision, 0)),
                   tot_int_pri_prevision = 0,
                   tot_int_seg_prevision = 0
             WHERE nro_cuenta = reg.nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20005 ,V_LUGAR ||' - '|| v_cta_registro  || ' - ' || SQLERRM);
END;
