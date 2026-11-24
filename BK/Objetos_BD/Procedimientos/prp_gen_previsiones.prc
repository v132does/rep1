CREATE OR REPLACE PROCEDURE IT.prp_gen_previsiones(p_nro_cuenta pr_cta_prestamos.nro_cuenta%TYPE DEFAULT NULL) IS

   /* Obtener garantia computable. */
   FUNCTION lf_obt_gar_com
   (
      p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_cod_moneda    IN ba_monedas.cod_moneda%TYPE,
      p_cod_mon_local IN ba_monedas.cod_moneda%TYPE,
      p_tot_deuda     IN pr_cta_prestamos.sal_capital%TYPE
   ) RETURN NUMBER;
   
     /* obtiene si el cliente tiene garantia fogapy*/
  function lf_obt_gar_fogapy(p_nro_cuenta in pr_cta_garantias.nro_cuenta%type)
    return varchar2;

    FUNCTION fu_obt_cod_entidad RETURN NUMBER;
   /* Obtener garantia cash. */
   FUNCTION lf_obt_gar_cash(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE) RETURN NUMBER;
   /* Obtener prevision anterior. */
   FUNCTION lf_obt_prv_ant
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER;
   /* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE) RETURN NUMBER;
   /* Insertar registros en la tabla de previsiones de prestamos. */
   
   FUNCTION lf_obt_gar_com_viv(p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type)
   RETURN NUMBER;
   /*Obtener  la garantia de vivienda */
   PROCEDURE lp_ins_prevision(rp_pprev IN pr_previsiones%ROWTYPE);
   
   /*RETORNA PARAMETRO DINAMICO*/
   FUNCTION LF_OBT_PARDINAMICO
    (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
    ,P_CACHED_DATA     IN it.typ_ge_par_dinamicos_tab
    ,P_COD_MODULO IN NUMBER DEFAULT NULL
    ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
    ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
    ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
    ,P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2;
   /* Proceso de previsiones: Consideraciones a tener en cuenta con el analisis:
   - Debe tomar las operaciones que tienen algo previsionado o pueden previsionar en el sistema, es decir, desde el inicio y aun despues de ser canceladas y aun tener prevision aplicada.
   - La prevision actual debe calcularse luego de la categorizacion, ya que se ve influido por este.
   - La prevision debe poder ajustar la prevision contable, esto afectar o desafectar previsiones de acuerdo a lo ya previsionado por la operacion.
   - Debe mantenerse una tabla independiente de prevision para saber cuando se afecto o desafecto a una fecha dada.
   Secuencia de Procesos
   - Cambio de Estado
   - Devengado
   - Categorizacion
   - Prevision */
   v_fec_actual    ge_calendarios.fec_actual%TYPE;
   v_cod_mon_local ba_monedas.cod_moneda%TYPE;
   -- NGRANCE - Resolución N°37
   v_riesgo1a pr_parametros.por_riesgo_1a%TYPE;
   v_riesgo1b pr_parametros.por_riesgo_1b%TYPE;
   --

   v_riesgo2           pr_parametros.por_riesgo_2%TYPE;
   v_riesgo3           pr_parametros.por_riesgo_3%TYPE;
   v_riesgo4           pr_parametros.por_riesgo_4%TYPE;
   v_riesgo5           pr_parametros.por_riesgo_5%TYPE;
   v_riesgo6           pr_parametros.por_riesgo_6%TYPE;
   v_garantia          pr_cta_garantias.mto_apl_computable%TYPE;
   v_prevision         pr_previsiones.monto%TYPE;
   v_prv_anterior      pr_previsiones.monto%TYPE;
   v_diferencia        pr_previsiones.monto%TYPE;
   r_pprev             pr_previsiones%ROWTYPE;
   r_gmovi             ge_movimientos%ROWTYPE;
   v_nro_secuencia     ge_movimientos.nro_secuencia%TYPE;
   v_hora              ge_movimientos.hora%TYPE;
   v_cat_prev          ge_cla_operaciones.cat_automatica%TYPE;
   --v_cat_gru_economico ge_clientes.cat_gru_economico%TYPE;
   v_cat_subjetiva     ge_clientes.cat_subjetiva%TYPE;
   v_por_prev_clie     NUMBER(5, 2);
   v_mto_pre_total     pr_previsiones.mto_pre_total%TYPE;
   --- Variables nuevas
   v_pri_prevision      NUMBER(18, 2);
   v_dias_cat           NUMBER(10);
   v_por_prevision      NUMBER(18, 2);
   v_por_prev_cheq      NUMBER(18, 2);
   v_redondeo           NUMBER(2);
   --v_por_capital        NUMBER(3);
   v_neto               ge_cla_operaciones.tot_deu_real%TYPE;
   v_tip_implementacion ge_par_generales.tip_implementacion%TYPE;
   v_cau_insufondos     ge_causales.cod_causa%TYPE;
   v_cat_cli_prevision  ge_cla_operaciones.cat_automatica%TYPE; -- NGRANCE - Resolución N°37
   v_seg_prevision      pr_previsiones.tot_pri_prevision%TYPE;
   v_tot_rie_no_cubierto    pr_previsiones.tot_pri_prevision%TYPE;
   v_cap_pri_prevision  pr_previsiones.tot_pri_prevision%TYPE;
   v_int_pri_prevision  pr_previsiones.tot_pri_prevision%TYPE;
   v_cap_seg_prevision  pr_previsiones.tot_pri_prevision%TYPE;
   v_int_seg_prevision  pr_previsiones.tot_pri_prevision%TYPE;
   v_sal_capital        pr_previsiones.tot_pri_prevision%TYPE;
   v_gar_cash           pr_cta_garantias.mto_apl_computable%TYPE := 0;
   v_cod_entidad        ge_par_generales.cod_entidad%TYPE := fu_obt_cod_entidad;
   v_calculo            pr_previsiones.monto%TYPE;
   v_pre_pla_mipymes    ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_PLA_MIPYMES');
   --v_pre_pla_prev_rrr   ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_PLA_PREV_RRR'); --3años.
   v_meses_ope          ge_par_dinamicos.val_parametro%TYPE := to_number(nvl(fug_obt_pardinamico('PRP_PRE_OPE_MEDIDA'), 0)); --3años.
   v_cod_rub_eco_vivienda ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_RUB_ECO_VIVIENDA');
   v_nro_cuenta         ge_cuentas.nro_cuenta%type;
   v_ban_fogapy        varchar2(1); --bandera1
   v_gar_fogapy         pr_cta_garantias.mto_con_computable%TYPE;
   v_pre_mad_fogapy     varchar2(1) := 'N';
   v_usu_mig_excluir    varchar2(30);
   v_cod_mad_che_devuelto ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CHEQUES DEVUELTOS', 6);
   v_cod_mad_che_diferido ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CHEQUES DIFERIDOS', 6);
   v_cod_mon_base     ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   
   -- Declaración de tipos y variables
   TYPE t_cla_fila_tab IS TABLE OF ROWID;  -- Para ROWID de GE_CLA_OPERACIONES
   TYPE t_nro_cta_tab IS TABLE OF GE_CLA_OPERACIONES.Nro_Cuenta%TYPE;
   TYPE t_prev_tab IS TABLE OF GE_CLA_OPERACIONES.tot_prevision%TYPE;
   TYPE t_mto_prev_tab IS TABLE OF GE_CLA_OPERACIONES.mto_pre_total%TYPE;
   TYPE t_pri_prev_tab IS TABLE OF GE_CLA_OPERACIONES.tot_pri_prevision%TYPE;
   TYPE t_seg_prev_tab IS TABLE OF GE_CLA_OPERACIONES.tot_seg_prevision%TYPE;
   TYPE t_gar_apli_tab IS TABLE OF GE_CLA_OPERACIONES.tot_gar_aplicada%TYPE;
   TYPE t_rie_no_tab IS TABLE OF GE_CLA_OPERACIONES.tot_rie_no_cubierto%TYPE;
   TYPE t_cap_pri_tab IS TABLE OF GE_CLA_OPERACIONES.tot_cap_pri_prevision%TYPE;
   TYPE t_cap_seg_tab IS TABLE OF GE_CLA_OPERACIONES.tot_cap_seg_prevision%TYPE;
   TYPE t_int_pri_tab IS TABLE OF GE_CLA_OPERACIONES.tot_int_pri_prevision%TYPE;
   TYPE t_int_seg_tab IS TABLE OF GE_CLA_OPERACIONES.tot_int_seg_prevision%TYPE;
   TYPE t_cat_prev_tab IS TABLE OF GE_CLA_OPERACIONES.cat_prevision%TYPE;
   TYPE t_pr_previsiones IS TABLE OF pr_previsiones%ROWTYPE;

   --Inicializar y limpiar las variables
   v_cla_fila_tab t_cla_fila_tab := t_cla_fila_tab();
   v_nro_cta_tab t_nro_cta_tab := t_nro_cta_tab(); 
   v_prev_tab t_prev_tab := t_prev_tab();
   v_mto_prev_tab t_mto_prev_tab := t_mto_prev_tab();
   v_pri_prev_tab t_pri_prev_tab := t_pri_prev_tab();
   v_seg_prev_tab t_seg_prev_tab := t_seg_prev_tab();
   v_gar_apli_tab t_gar_apli_tab := t_gar_apli_tab();
   v_rie_no_tab t_rie_no_tab := t_rie_no_tab();
   v_cap_pri_tab t_cap_pri_tab := t_cap_pri_tab();
   v_cap_seg_tab t_cap_seg_tab := t_cap_seg_tab();
   v_int_pri_tab t_int_pri_tab := t_int_pri_tab();  
   v_int_seg_tab t_int_seg_tab := t_int_seg_tab();
   v_cat_prev_tab t_cat_prev_tab := t_cat_prev_tab();
   v_pr_previsiones t_pr_previsiones := t_pr_previsiones();
   
   /*Para parametros dinamicos*/
   v_ge_par_dinamicos it.typ_ge_par_dinamicos_tab;
   
   --- Cursor de prestamos a calcularr
   CURSOR c_prestamos IS
      SELECT p.nro_cuenta,
             p.sal_capital,
             p.sal_interes,
             p.cod_moneda,
             c.cod_persona,
             c.cat_riesgo,
             c.cat_subjetiva,
             p.cod_modalidad,
             o.cat_automatica,
             p.cod_oficina,
             p.fec_cancelacion,
             p.mto_capital,
             nvl(p.dev_no_cobrado, 0) dev_no_cobrado,
             p.cod_modulo,
             nvl(p.sal_int_adelantado, 0) sal_int_adelantado,
             c.cod_gru_economico,
             c.cat_gru_economico,
             p.estado,
             p.est_batch,
             p.cod_causa,
             nvl(p.dia_atraso, 0) dia_atraso,
             nvl(p.dia_atr_3r, 0) dia_atr_3r,
             p.cat_pre_diferida,
             p.cat_renovaciones,
             p.tip_renovacion, --ope rrr.
             o.cat_ren_anterior,
             o.lib_prevision,
             p.sal_capital + nvl(p.dev_no_cobrado, 0) oc_ttdeuda,
             c.fec_ult_clasif,
             v_fec_actual - p.fec_inicio dias_transcurridos,
             round(months_between(v_fec_actual, p.fec_inicio)) meses_transcurridos,
             trunc((p.fec_vencimiento - p.fec_inicio) / 30, 0) plazo,
             (p.fec_vencimiento - p.fec_inicio) plazo_dias,
             o.cod_rub_economico,
             o.rowid id
        FROM ge_clientes c, ge_cta_clientes cc, pr_cta_prestamos p, ge_cla_operaciones o
       WHERE p.nro_cuenta = cc.nro_cuenta
         AND o.nro_cuenta(+) = p.nro_cuenta
         AND cc.relacion = 'P'         
         AND cc.cod_persona = c.cod_persona
         AND NOT EXISTS (select 1 from it.ge_cta_dat_fusion t where t.cod_modulo=p.cod_modulo
                                                              AND   t.nro_cuenta=p.nro_cuenta)
         AND (p.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)
         AND p.estado <> 'I' --- No procesar los incobrables
         AND (p.estado <> 'N' OR p.fec_cancelacion = v_fec_actual OR
             --GB. 26/08/2010 Se modifico para que tome los prestamos cuya fecha de cancelacion es distinta al del cierre
             (p.estado = 'N' AND trunc(p.fec_modificacion) = v_fec_actual))
            --No incluir cuentas canceladas por venta de cartera
         AND NOT EXISTS
       (SELECT 1
                FROM ge_cta_dat_adicionales b
               WHERE p.nro_cuenta = b.nro_cuenta
                 AND parametro = 'ENT_ADM_CARTERA')
         AND ((/*nvl(fug_obt_pardinamico('PRE_MAD_EXCEPCION', p.cod_modulo, p.cod_modalidad, NULL, NULL),
                  'N') = 'N'*/
                not exists(select 1
                             from ge_par_dinamicos a
                            where a.cod_modulo = p.cod_modulo
                              and a.cod_modalidad = p.cod_modalidad
                              and a.parametro = 'PRE_MAD_EXCEPCION'
                              and a.val_parametro = 'S')) AND NOT EXISTS
         (SELECT 1 
            FROM ge_cta_dat_adicionales aa
           WHERE aa.parametro IN ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
             AND aa.nro_cuenta = p.nro_cuenta));
             
   /* Obtener garantia computable. */
   FUNCTION lf_obt_gar_com
   (
      p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_cod_moneda    IN ba_monedas.cod_moneda%TYPE,
      p_cod_mon_local IN ba_monedas.cod_moneda%TYPE,
      p_tot_deuda     IN pr_cta_prestamos.sal_capital%TYPE
   ) RETURN NUMBER IS
      v_gar_compu pr_cta_garantias.mto_apl_computable%TYPE := 0;
      v_tot_gara  pr_cta_garantias.mto_apl_computable%TYPE := 0;
      v_cot_aux   ge_cotizaciones.val_conversion%TYPE;
      CURSOR c_garantias IS
         SELECT g.mto_apl_computable, t.cod_garantia
           FROM pr_cta_garantias g, pr_gar_tipos t, pr_garantias b
          WHERE g.nro_cuenta = p_nro_cuenta
            AND g.cod_garantia = t.cod_garantia
            AND g.nro_garantia = b.nro_garantia
            AND t.computable = 'S'
            AND b.estado <> 'V'
            --AND nvl(t.pre_especial, 'N') = 'N'
            AND nvl(g.mto_apl_computable, 0) > 0;
   BEGIN
      v_tot_gara := 0;
      FOR reg IN c_garantias LOOP
         v_cot_aux   := NULL;
         v_gar_compu := nvl(reg.mto_apl_computable, 0);
         --- totalizar garantias computables en moneda de la cuenta ---------
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
      END LOOP;
      RETURN v_tot_gara;
   END;
   
    /* obtener si la persona tiene garantia fogapy*/
  function lf_obt_gar_fogapy(p_nro_cuenta in pr_cta_garantias.nro_cuenta%type)
    return varchar2 is
    v_existe varchar2(1);
    -- recupera si la cuenta tiene garantia fogapy
  begin
    select 'S'
      into v_existe
      from pr_cta_garantias s, pr_gar_tipos ss
     where s.cod_garantia = ss.cod_garantia
       and nro_cuenta = p_nro_cuenta
       and ss.computable = 'S'
       AND nvl(s.mto_apl_computable, 0) > 0
       AND s.cod_garantia in (select t.val_minimo from ba_cod_referencias t where dominio = 'COD_GAR_FOGAPY' );
  
    return(v_existe);
  
  exception
    when others then
      return('N');
  end;
  
   FUNCTION fu_obt_cod_entidad RETURN NUMBER IS
      result ge_par_generales.cod_entidad%TYPE;
   BEGIN
      -- Obtiene el Código de Entidad
      SELECT cod_entidad
        INTO result
        FROM ge_par_generales
       WHERE rownum = 1;

      RETURN(result);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'FUG OBT COD ENTIDAD ' || SQLERRM);
   END;

   /* Obtener garantia cash. */
   FUNCTION lf_obt_gar_cash(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE) RETURN NUMBER IS
      v_gar_compu pr_cta_garantias.mto_apl_computable%TYPE := 0;
      v_tot_gara  pr_cta_garantias.mto_apl_computable%TYPE := 0;
      v_cot_aux   ge_cotizaciones.val_conversion%TYPE;
      CURSOR c_garantias IS
         SELECT g.mto_apl_computable, t.cod_garantia
           FROM pr_cta_garantias g, pr_gar_tipos t
          WHERE g.nro_cuenta = p_nro_cuenta
            AND g.cod_garantia = t.cod_garantia
            AND t.computable = 'S'
            AND t.cod_garantia in (select t.val_minimo from ba_cod_referencias t where dominio = 'COD_GAR_CASH')
            AND nvl(g.mto_apl_computable, 0) > 0;
   BEGIN
      v_tot_gara := 0;
      FOR reg IN c_garantias LOOP
         v_cot_aux   := NULL;
         v_gar_compu := nvl(reg.mto_apl_computable, 0);
         --- totalizar garantias computables en moneda de la cuenta ---------
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
      END LOOP;
      RETURN v_tot_gara;
   END;

   /* Obtener prevision anterior. */
   FUNCTION lf_obt_prv_ant
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER IS
      v_monto pr_previsiones.monto%TYPE;
   BEGIN
      SELECT SUM(monto)
        INTO v_monto
        FROM pr_previsiones
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha = (SELECT fecha
                        FROM (SELECT fecha
                                FROM pr_previsiones
                               WHERE nro_cuenta = p_nro_cuenta
                                 AND fecha <= p_fec_actual
                               ORDER BY fecha DESC)
                       WHERE rownum = 1);

      RETURN v_monto;
   END;
   /* Obtener la categoría de previsión de clientes para categoría 1(Uno). Resolución N°37*/
   FUNCTION lf_obt_cat_prevision(p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE) RETURN NUMBER AS
      v_categoria ge_cla_operaciones.cat_automatica%TYPE;
   BEGIN
      --Verifico las operaciones que posee el cliente.
      SELECT nvl(MAX(g.cat_automatica), 1)
        INTO v_categoria
        FROM ge_cla_operaciones g
       WHERE g.cod_persona = p_cod_persona
         --AND fup_inc_ope_medida(a.cod_persona, a.nro_cuenta) = 'S';
         AND ((EXISTS (SELECT 1
                     FROM ge_par_dinamicos p
                    WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                      AND p.cod_modalidad = g.cod_modalidad
                      AND p.cod_modulo = g.cod_modulo
                      AND nvl(p.val_parametro, 'N') = 'S') AND NOT EXISTS
           (SELECT 1 -- todos los miembros tienen solo ope de ME.
              FROM ge_cla_operaciones s
             WHERE s.cod_persona = g.cod_persona
               AND NOT EXISTS (SELECT 1
                      FROM ge_par_dinamicos p
                     WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                       AND p.cod_modalidad = s.cod_modalidad
                       AND p.cod_modulo = s.cod_modulo
                       AND nvl(p.val_parametro, 'N') = 'S'))) OR --no es de medida transitoria
           --2
           (NOT EXISTS (SELECT 1
                         FROM ge_par_dinamicos p
                        WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          AND p.cod_modalidad = g.cod_modalidad
                          AND p.cod_modulo = g.cod_modulo
                          AND nvl(p.val_parametro, 'N') = 'S')
                 AND NOT EXISTS (SELECT 1
                                   FROM ge_cta_dat_adicionales a 
                                  WHERE a.parametro IN ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                    AND a.nro_cuenta = g.nro_cuenta)) OR 
           --3
           (NOT EXISTS (SELECT 1
                         FROM ge_par_dinamicos p
                        WHERE p.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                          AND p.cod_modalidad = g.cod_modalidad
                          AND p.cod_modulo = g.cod_modulo
                          AND nvl(p.val_parametro, 'N') = 'S') 
                       AND EXISTS (select 1
                                 from ge_cta_dat_adicionales a 
                                where a.parametro in ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
                                  and a.nro_cuenta = g.nro_cuenta)
                       AND NOT EXISTS (SELECT 1 -- todos los miembros tienen solo ope de ME.
                               FROM ge_cla_operaciones xx
                              WHERE xx.cod_persona = g.cod_persona
                                 AND xx.nro_cuenta <> g.nro_cuenta
                                 AND 'N' = (SELECT nvl(max(pp.val_parametro), 'N')
                                            FROM ge_par_dinamicos pp
                                           WHERE pp.parametro IN ('PRE_MAD_EXC_PYMES', 'PRE_MAD_EXCEPCION')
                                             AND pp.cod_modalidad = xx.cod_modalidad
                                             AND pp.cod_modulo = xx.cod_modulo))) 
            );
      RETURN v_categoria;
   EXCEPTION
      WHEN OTHERS THEN
         v_categoria := 1;
         RETURN v_categoria;
   END;
   FUNCTION lf_obt_gar_com_viv(p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type)
    return number is
     v_gar_compu pr_cta_garantias.mto_apl_computable%type := 0;
     v_tot_gara  pr_cta_garantias.mto_apl_computable%type := 0;

   cursor c_garantias is
    select h.val_vta_rapida
      from pr_cta_garantias g, pr_gar_hipotecarias h, pr_gar_tipos t
     where g.nro_cuenta = p_nro_cuenta
       and g.cod_garantia = t.cod_garantia
       and g.nro_garantia = h.nro_garantia
       and t.computable = 'S';
    begin
       v_tot_gara := 0;
      for reg in c_garantias loop
       -- v_cot_aux   := null;
       v_gar_compu := nvl(reg.val_vta_rapida, 0);
       --- totalizar garantias computables en moneda de la cuenta ---------
       v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
      end loop;
      return v_tot_gara;
    end;
   
   /* Insertar registros en la tabla de previsiones de prestamos. */
   PROCEDURE lp_ins_prevision(rp_pprev IN pr_previsiones%ROWTYPE) IS
   BEGIN
      INSERT INTO pr_previsiones
         (fecha, nro_cuenta, monto, sal_capital, dev_no_cobrado, porcentaje, tot_gar_computables,
          tot_pri_prevision, tot_cap_pri_prevision, tot_cap_seg_prevision, tot_int_pri_prevision,
          tot_int_seg_prevision, mto_pre_total)
      VALUES
         (rp_pprev.fecha, rp_pprev.nro_cuenta, rp_pprev.monto, rp_pprev.sal_capital,
          rp_pprev.dev_no_cobrado, rp_pprev.porcentaje, rp_pprev.tot_gar_computables,
          rp_pprev.tot_pri_prevision, rp_pprev.tot_cap_pri_prevision, rp_pprev.tot_cap_seg_prevision,
          rp_pprev.tot_int_pri_prevision, rp_pprev.tot_int_seg_prevision,rp_pprev.mto_pre_total);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Ins.Prev. ' || SQLERRM);
   END;
   
   FUNCTION LF_OBT_PARDINAMICO(
        P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE,
        P_CACHED_DATA IN it.typ_ge_par_dinamicos_tab,
        P_COD_MODULO IN NUMBER DEFAULT NULL,
        P_COD_MODALIDAD IN NUMBER DEFAULT NULL,
        P_COD_MONEDA IN VARCHAR2 DEFAULT NULL,
        P_COD_OFICINA IN NUMBER DEFAULT NULL,
        P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL
    )
     RETURN VARCHAR2
     IS
    v_val_parametro ge_par_dinamicos.val_parametro%type;
    begin 
      FOR i IN 1 .. P_CACHED_DATA.COUNT LOOP
                IF P_CACHED_DATA(i).parametro = P_PARAMETRO 
                  AND NVL(P_CACHED_DATA(i).COD_MODULO,NVL(P_COD_MODULO,-1)) = NVL(P_COD_MODULO,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_MODALIDAD,NVL(P_COD_MODALIDAD,-1)) = NVL(P_COD_MODALIDAD,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_SUB_MODALIDAD,NVL(P_COD_SUB_MODALIDAD,-1)) = NVL(P_COD_SUB_MODALIDAD,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_OFICINA,NVL(P_COD_OFICINA,-1)) = NVL(P_COD_OFICINA,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_MONEDA,NVL(P_COD_MONEDA,'x')) = NVL(P_COD_MONEDA,'x') THEN
                    v_val_parametro := P_CACHED_DATA(i).val_parametro;
                    RETURN v_val_parametro;
                    exit;
                END IF;
            END LOOP;
            if v_val_parametro is null then
             return null;
            end if;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'Error al buscar en ge_par_dinamicos '||SQLERRM);
    END;

function LF_OBT_COTIZACION
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE)
 RETURN NUMBER
 IS

V_VAL_CONVERSION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   SELECT  val_conversion
   INTO  v_val_conversion
   FROM  ge_cotizaciones a
   WHERE  fecha  = (SELECT max(fecha)
                          FROM ge_cotizaciones
                         WHERE cod_moneda = p_cod_moneda
                           AND fecha <= v_fec_actual)
   AND  cod_moneda = p_cod_moneda;
   Return v_val_conversion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_conversion := NULL;
      Return v_val_conversion;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Cotización ');
END;

/* Convertir un monto de una moneda a otra */
FUNCTION LF_CON_MON_A_MONEDA
   (P_COD_MON_ORIGEN  IN BA_MONEDAS.COD_MONEDA%TYPE
   ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
   ,P_MTO_MON_ORIGEN  IN NUMBER
   ,P_COTIZACION      IN NUMBER 
   ,P_FECHA           IN DATE 
   ,P_COT_MON_DESTINO IN NUMBER 
 )
 RETURN NUMBER
  IS
   v_mto_mon_destino  NUMBER;
   v_cot_mon_destino  number := p_cot_mon_destino;
   v_cot_mon_origen   number := p_cotizacion;
   v_lugar            varchar2(4000);
   v_redondeo         number(5);
BEGIN
    v_lugar := 'obtener moneda base';
    v_redondeo := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_ge_par_dinamicos,null,null,p_cod_mon_destino);

    
    if p_cod_mon_origen = p_cod_mon_destino  then
       v_mto_mon_destino := p_mto_mon_origen;
        if p_cod_mon_origen <> v_cod_mon_base then
           if v_cot_mon_origen is null and v_cot_mon_destino is not null then
              v_cot_mon_origen := v_cot_mon_destino;
           elsif v_cot_mon_origen is null then
              v_cot_mon_origen := LF_OBT_COTIZACION(p_cod_mon_origen);
           end if;              
           v_cot_mon_destino := v_cot_mon_origen;
        else
           v_cot_mon_destino := 1;
           v_cot_mon_origen := 1;
        end if;
   else
       if  p_cod_mon_origen <> v_cod_mon_base and p_cod_mon_destino = v_cod_mon_base then
           --convertir moneda origen a base o destino
           if v_cot_mon_origen is null then
              v_cot_mon_origen := LF_OBT_COTIZACION(p_cod_mon_origen);
           end if;           
           v_cot_mon_destino := 1;
           v_mto_mon_destino := round(p_mto_mon_origen * v_cot_mon_origen,v_redondeo);
       elsif p_cod_mon_origen = v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           -- pasar moneda origen a moneda base
           if v_cot_mon_destino is null then
              v_cot_mon_destino := LF_OBT_COTIZACION(p_cod_mon_origen);
           end if;           
           v_cot_mon_origen := 1;
           v_mto_mon_destino := round(p_mto_mon_origen/v_cot_mon_destino,v_redondeo);
       elsif p_cod_mon_origen <> v_cod_mon_base and p_cod_mon_destino <> v_cod_mon_base then
           if v_cot_mon_origen is null then
              v_cot_mon_origen := LF_OBT_COTIZACION(p_cod_mon_origen);
           end if;
           v_mto_mon_destino := p_mto_mon_origen * v_cot_mon_origen;
           if v_cot_mon_destino is null then
              v_cot_mon_destino := LF_OBT_COTIZACION(p_cod_mon_origen);
           end if;       
           v_mto_mon_destino := round(v_mto_mon_destino/v_cot_mon_destino,v_redondeo);
       end if;
   end if;
   return v_mto_mon_destino;
   exception
   when others then
      raise_application_error(-20000,v_lugar || ' - ' ||sqlerrm);
END;

/* Convertir un monto de una moneda a otra */
FUNCTION LF_CON_MON_A_MONEDA
 (P_COD_MON_ORIGINAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_DESTINO IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_MTO_MON_ORIGINAL IN NUMBER
 ,P_COT_MON_ORIGINAL IN NUMBER default null
 )
 RETURN NUMBER
  IS
   --v_fec_actual date := PAG_CAL.FU_OBT_FEC_ACTUAL(1); 
BEGIN
   RETURN (LF_CON_MON_A_MONEDA(
                              P_COD_MON_ORIGINAL,
                              P_COD_MON_DESTINO,
                              P_MTO_MON_ORIGINAL,
                              P_COT_MON_ORIGINAL,
                              v_fec_actual,
                              NULL));
                  
END;

BEGIN
   v_fec_actual         := pag_cal.fu_obt_fec_actual(6);
   v_hora               := fug_ini_hora(SYSDATE);
   v_hora               := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
   v_hora               := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   v_cod_mon_local      := pag_gen.fu_obt_mon_local;
   v_tip_implementacion := fug_obt_tip_implementacion;
   v_usu_mig_excluir    := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   -- código de causa por insuficiencia de fondos
   v_cau_insufondos := fug_obt_pardinamico('CAU_INSUFI_FONDOS', NULL, NULL, NULL, NULL);
   
   SELECT typ_ge_par_dinamicos(
             parametro,
             cod_modulo,
             cod_modalidad,
             cod_moneda,
             cod_oficina,
             cod_sub_modalidad,
             val_parametro
          )
    BULK COLLECT INTO v_ge_par_dinamicos
    FROM ge_par_dinamicos
    WHERE parametro IN ('PRE_MAD_EXC_PYMES',
                        'PRE_MAD_SIN_DIFERIR',
                        'VAL_RED_MON_EXTRANJERA')
    ORDER BY decode(cod_modulo, NULL, 0, 1) +
             decode(cod_modalidad, NULL, 0, 1) +
             decode(cod_sub_modalidad, NULL, 0, 1) +
             decode(cod_oficina, NULL, 0, 1) +
             decode(cod_moneda, NULL, 0, 1) DESC;
             
   BEGIN
      -- NGRANCE - Resolución N°37
      SELECT por_riesgo_1a,
             por_riesgo_1b,
             por_riesgo_2,
             por_riesgo_3,
             por_riesgo_4,
             por_riesgo_5,
             por_riesgo_6
        INTO v_riesgo1a, v_riesgo1b, v_riesgo2, v_riesgo3, v_riesgo4, v_riesgo5, v_riesgo6
        FROM pr_parametros
       WHERE rownum = 1;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000, 'Parametros de riesgos no definidos');
   END;
   v_nro_secuencia := 0;
   FOR reg IN c_prestamos LOOP
      v_cat_prev      := reg.cat_riesgo;
      v_cat_subjetiva := reg.cat_subjetiva;
      v_prevision     := 0;
      v_pri_prevision := 0;
      v_por_prev_cheq := 0;
      v_por_prev_clie := 0;
      v_tot_rie_no_cubierto :=0;
      v_mto_pre_total := 0;
      v_nro_cuenta := reg.nro_cuenta;
      v_gar_fogapy          :=0; 
      v_ban_fogapy          :='N'; 
      v_int_seg_prevision := 0;
      
      v_pre_mad_fogapy := nvl(lf_obt_gar_fogapy(reg.nro_cuenta),'N');
      --para mypimes.
      IF nvl(LF_OBT_PARDINAMICO('PRE_MAD_EXC_PYMES', v_ge_par_dinamicos, reg.cod_modulo, reg.cod_modalidad), 'N') = 'S' AND
         trunc(reg.meses_transcurridos) <= v_meses_ope  THEN
         NULL; -- No previsiona.
      ELSE
         IF v_tip_implementacion <> 1 THEN
            v_garantia := lf_obt_gar_com(reg.nro_cuenta, reg.cod_moneda, v_cod_mon_local,
                                         reg.oc_ttdeuda);
         ELSE
           IF instr(v_cod_rub_eco_vivienda,','||reg.cod_rub_economico||',') > 0 then
             -- Resol 12 fieldesk-19605
             v_garantia := lf_obt_gar_com_viv(reg.nro_cuenta);
           ELSE  
             -- FA
             v_garantia := lf_obt_gar_com(reg.nro_cuenta, reg.cod_moneda, v_cod_mon_local,
                                         reg.sal_capital);
             --Cash
             v_gar_cash := lf_obt_gar_cash(reg.nro_cuenta);
           END IF; 
         END IF;
         IF v_tip_implementacion <> 2 THEN
            IF reg.cod_modalidad IN
               (v_cod_mad_che_devuelto,
                v_cod_mad_che_diferido) THEN
               --- Previsionar por días de atraso
               IF reg.dia_atraso < 31 THEN
                  v_por_prev_cheq := 0;
               ELSIF reg.dia_atraso >= 31 AND reg.dia_atraso < 60 THEN
                  v_por_prev_cheq := 20;
               ELSIF reg.dia_atraso >= 60 AND reg.dia_atraso < 90 THEN
                  v_por_prev_cheq := 50;
               ELSIF reg.dia_atraso >= 90 AND reg.dia_atraso < 120 THEN
                  v_por_prev_cheq := 75;
               ELSIF reg.dia_atraso >= 120 THEN
                  v_por_prev_cheq := 100;
               ELSE
                  v_por_prev_cheq := 0;
               END IF;
            END IF;
         ELSE
            -- hacer prevision especial solamente para cheques devueltos
            IF reg.cod_modalidad = v_cod_mad_che_devuelto THEN
               -- verificar si la devolución fue por insuficiencia de fondos
               BEGIN
                  SELECT 0
                    INTO v_por_prev_cheq
                    FROM pr_cta_prestamos a, pr_solicitudes b, cc_che_enviados c
                   WHERE a.cod_modalidad = reg.cod_modalidad
                     AND a.estado <> 'N'
                     AND a.nro_solicitud = b.nro_solicitud
                     AND c.nro_cheque =
                         substr(b.descripcion, 5, instr(b.descripcion, 'CTA:', 4) - 6)
                     AND c.nro_cuenta = substr(b.descripcion, instr(b.descripcion, 'CTA:', 4) + 4,
                                               length(b.descripcion))
                     AND c.cod_cau_devolucion = v_cau_insufondos
                     AND a.nro_cuenta = reg.nro_cuenta;

                  --- Previsionar por días de atraso si es por insuficiencia de fondos la devolucion
                  IF reg.dia_atraso < 31 THEN
                     v_por_prev_cheq := 0;
                  ELSIF reg.dia_atraso >= 31 AND reg.dia_atraso < 60 THEN
                     v_por_prev_cheq := 20;
                  ELSIF reg.dia_atraso >= 60 AND reg.dia_atraso < 90 THEN
                     v_por_prev_cheq := 50;
                  ELSIF reg.dia_atraso >= 90 AND reg.dia_atraso < 120 THEN
                     v_por_prev_cheq := 75;
                  ELSIF reg.dia_atraso >= 120 THEN
                     v_por_prev_cheq := 100;
                  ELSE
                     v_por_prev_cheq := 0;
                  END IF;
               EXCEPTION
                  WHEN no_data_found THEN
                     -- si no es por ese motivo, entonces no hace nada y sigue el proceso normal
                     NULL;
               END;
            END IF;
         END IF;
         --- Verificar si debe o no retener la previsión
         IF reg.cat_renovaciones IS NOT NULL THEN
            IF reg.cat_renovaciones > reg.cat_ren_anterior AND reg.lib_prevision = 'N' THEN
               --- Para que calcule la previsión a la categoría
               --- anterior porque aún no pago lo suficiente como
               --- para liberar la previsión, pero si mejoró su categoría
               v_cat_prev := reg.cat_ren_anterior;
            END IF;
         END IF;
         -- NGRANCE - Resolución N°37
         v_cat_cli_prevision := v_cat_prev;
        -- IF v_cat_prev = 1 THEN
           -- se agrega validacion para que no previsiones RUBROS DE VIVIENDA en cat < 2
	         IF v_cat_prev = 1 and instr(v_cod_rub_eco_vivienda,','||reg.cod_rub_economico||',') = 0 THEN
               v_cat_cli_prevision := lf_obt_cat_prevision(reg.cod_persona);
            IF v_cat_cli_prevision < 2 THEN
			
			   /*FIELDESK-160732: Evaluar si la categoría del grupo económico es mayor*/
               IF reg.cat_gru_economico > v_cat_cli_prevision THEN
				  v_cat_cli_prevision := reg.cat_gru_economico;
			   END IF;
			   
               -- Solo Cat 1, 1a, 1b
               v_por_prev_clie := (CASE
                                     WHEN (reg.dia_atraso > 0 or reg.dia_atr_3r > 0) AND v_cat_cli_prevision = 1.1 THEN
                                      v_riesgo1a
                                     WHEN (reg.dia_atraso > 0  or reg.dia_atr_3r > 0) AND v_cat_cli_prevision > 1.1 THEN
                                      v_riesgo1b
                                     ELSE
                                      0
                                  END);
            ELSE
               v_cat_cli_prevision := 1.2;
               --Cat 2..6
               v_por_prev_clie := v_riesgo1b;
            END IF;
            --
         ELSIF v_cat_prev = 2 THEN
            v_por_prev_clie := v_riesgo2;
         ELSIF v_cat_prev = 3 THEN
            v_por_prev_clie := v_riesgo3;
         ELSIF v_cat_prev = 4 THEN
            v_por_prev_clie := v_riesgo4;
         ELSIF v_cat_prev = 5 THEN
            v_por_prev_clie := v_riesgo5;
         ELSIF v_cat_prev = 6 THEN
            v_por_prev_clie := v_riesgo6;
         ELSE
            v_por_prev_clie := 0;
         END IF;
         --- Tomar la mayor previsión como porcentaje
         v_por_prevision := v_por_prev_clie;
         IF v_por_prev_cheq > v_por_prev_clie THEN
            v_por_prevision := v_por_prev_cheq;
            -----SOLO PARA EXPOSICIÓN DE CAT_PREVISION.
            IF reg.cod_modalidad IN
                  (v_cod_mad_che_devuelto,
                   v_cod_mad_che_diferido) THEN
                IF reg.dia_atraso < 31 THEN
                   v_cat_cli_prevision := 1;
                ELSIF reg.dia_atraso >= 31 AND reg.dia_atraso < 60 THEN
                   v_cat_cli_prevision := 2;
                ELSIF reg.dia_atraso >= 60 AND reg.dia_atraso < 90 THEN
                   v_cat_cli_prevision := 3;
                ELSIF reg.dia_atraso >= 90 AND reg.dia_atraso < 120 THEN
                   v_cat_cli_prevision := 4;
                ELSIF reg.dia_atraso >= 120 THEN
                   v_cat_cli_prevision := 5;
                ELSE
                   v_cat_cli_prevision := 6;
                END IF;
            END IF;
         END IF;

         --- REALIZAR PRIMERA PREVISION
         --- Aplicar el 50% de la previsión obtenida al neto de la deuda
         v_por_prevision := v_por_prevision / 2;
         
         IF v_pre_mad_fogapy = 'S' THEN
          v_gar_fogapy := v_garantia;
         END IF;
         
         IF v_tip_implementacion <> 1 THEN
            IF v_cod_mon_local = reg.cod_moneda THEN
               v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100, 0);
            ELSE
               v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100, 2);
            END IF;
         ELSE
            -- FA
            v_redondeo := LF_OBT_PARDINAMICO('VAL_RED_MON_EXTRANJERA', v_ge_par_dinamicos, 6, NULL, reg.cod_moneda);

            IF v_cat_prev <> 1 OR (v_cat_prev = 1 AND nvl(v_garantia, 0) = 0) THEN

               IF nvl(v_gar_cash, 0) > 0 THEN 

                  IF (nvl(reg.sal_capital, 0) - nvl(v_gar_cash, 0)) > 0 THEN
                     v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_cash, 0)) *
                                          v_por_prevision / 100, v_redondeo);
                  END IF;
                  --fogapy
               ELSIF nvl(v_gar_fogapy, 0) > 0 THEN
	       	           v_ban_fogapy := 'S';
                  IF (nvl(reg.sal_capital, 0) - nvl(v_gar_fogapy, 0)) > 0 THEN
                   v_por_prevision := v_por_prevision * 2; -- Definido por Riesgo
                   v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_fogapy, 0)) * v_por_prevision / 100,
                                    v_redondeo);
                   v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0);                    
                     v_ban_fogapy := 'S';
                  END IF;
            
               ELSE
                 IF (v_cat_prev NOT IN (1,2) OR (v_cat_prev = 2 AND reg.dia_atraso > 60)) THEN
                    v_prevision := round(nvl(reg.sal_capital, 0) * v_por_prevision / 100, v_redondeo);
                 -- IF v_cat_prev = 2 AND reg.dia_atraso = 0 THEN

                   --  v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100, v_redondeo);
                 ELSE
                   --  v_prevision := round(nvl(reg.sal_capital, 0) * v_por_prevision / 100,
                   --                       v_redondeo);
                   v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100, v_redondeo);
                 END IF;
               END IF;
            ELSIF v_cat_prev = 1 AND nvl(v_garantia, 0) <> 0 THEN

               IF nvl(v_gar_cash, 0) > 0 THEN
                  IF (nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_cash, 0)) > 0 THEN
                     v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_cash, 0)) *
                                          v_por_prevision / 100, v_redondeo);
                  END IF;
               ELSIF nvl(v_gar_fogapy, 0) > 0 THEN
	       	           v_ban_fogapy := 'S';
                  IF (nvl(reg.sal_capital, 0) - nvl(v_gar_fogapy, 0)) > 0 THEN
                   v_por_prevision := v_por_prevision * 2; -- Definido por Riesgo
                   v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_fogapy, 0)) * v_por_prevision / 100,
                                    v_redondeo);
                   v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0);                    
                     v_ban_fogapy := 'S';
                  END IF;
               ELSE

                  v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100, v_redondeo);
               END IF;
            END IF;

            /*IF v_cat_subjetiva = 2 then
               v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100,
                             v_redondeo);
            end if;*/
         END IF;
         --- HALLAR VALOR COMPUTABLE DE LA GARANTIA
         IF v_garantia = 0 THEN
            --- Esta metodologia de cálculo no se aplicará cuando los préstamos carezcan de garantía
            --- en cuyo caso el % de prevision se aplicara sobre el saldo total de la deuda
            v_prevision     := 0;
            v_por_prevision := v_por_prevision * 2;
         END IF;
         v_pri_prevision := v_prevision;
         --- REALIZAR SEGUNDA PREVISION
         IF v_tip_implementacion <> 1  or v_cod_entidad = 2036 THEN
            IF (v_cat_prev > 2 OR (v_cat_cli_prevision = 2 and reg.dia_atraso < 60) OR (v_cat_cli_prevision = 2 and reg.dia_atraso >= 60) ) AND v_garantia = 0 THEN
                v_neto := nvl(reg.sal_capital, 0) - nvl(v_garantia, 0) - v_prevision;
            ELSE
               v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
            END IF;
            IF v_cat_subjetiva = 2 THEN
               v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
            ELSIF v_cat_subjetiva > 2 THEN
               v_neto := nvl(reg.sal_capital, 0) - nvl(v_garantia, 0) - v_prevision;
            END IF;
         ELSE
            -- FA
            --if v_cat_prev <> 1 then
          --  IF (reg.dia_atraso > 60 OR v_cat_prev > 2)
            IF v_cat_prev NOT IN (1,2) OR (v_cat_prev = 2 AND reg.dia_atraso > 60) THEN
           -- or ((reg.cat_pre_diferida = 2 or reg.cat_renovaciones = 2) and reg.dia_atraso < 60 )*/ THEN
               v_neto := nvl(reg.sal_capital, 0) - nvl(v_garantia, 0) - v_prevision;
            ELSE
               v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
            END IF;

            IF v_cat_subjetiva = 2 AND reg.dia_atraso > 60 THEN
               v_neto := nvl(reg.sal_capital, 0) - nvl(v_garantia, 0) - v_prevision;
            ELSIF v_cat_subjetiva = 2 AND reg.dia_atraso < 60 THEN
               IF nvl(v_garantia, 0) <> 0 THEN
                  v_int_seg_prevision := round(nvl(reg.dev_no_cobrado, 0) * v_por_prevision / 100,
                                               v_redondeo);
                  v_neto              := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision -
                                         v_int_seg_prevision;
               ELSE
                  v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
               END IF;
            ELSIF v_cat_subjetiva > 2 THEN
               v_neto := nvl(reg.sal_capital, 0) - nvl(v_garantia, 0) - v_prevision;
            END IF;
         END IF;

         IF v_neto < 0 THEN
            v_neto := 0;
         END IF;
         IF v_garantia <> 0 THEN
            v_tot_rie_no_cubierto :=  nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
         END IF;
         --- Calcular cantidad de dias desde la ultima clasificacion
         v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
         IF reg.cat_riesgo = 6 AND v_garantia > 0 AND v_dias_cat > 365 THEN
            --- Previsiones Genericas - Solo si tiene garantia
            IF v_dias_cat > 365 THEN
               IF v_tip_implementacion <> 1 THEN
                  v_neto := nvl(reg.oc_ttdeuda, 0);
               ELSE
                  v_neto := nvl(reg.sal_capital, 0);
               END IF;
               -- Si permenezco mas de un año en esa categoria
               IF v_dias_cat >= 365 + 360 THEN
                  -- al año tengo que previsionar el 100% de la deuda
                  --- Se debe previsionar el 100% de la deuda
                  v_prevision     := v_neto;
                  v_por_prevision := 100;
                  v_neto          := nvl(reg.sal_capital, 0);
               ELSIF v_dias_cat >= 365 + 180 THEN
                  -- a los 6 primeros meses tengo que previsionar 25% mas es decir 75% de la deuda
                  IF v_cod_mon_local = reg.cod_moneda THEN
                     v_prevision := round(nvl(v_neto, 0) * 75 / 100, 0);
                  ELSE
                     v_prevision := round(nvl(v_neto, 0) * 75 / 100, 2);
                  END IF;
                  v_por_prevision := 75;
                  v_neto          := nvl(reg.sal_capital, 0);
               END IF;
            END IF;
         ELSE
           if nvl(v_ban_fogapy,'N') <> 'S' then  --para fogapy no calcula 2da prevision
            IF v_cod_mon_local = reg.cod_moneda THEN
               v_prevision := v_prevision + round(nvl(v_neto, 0) * v_por_prevision / 100, 0);
               IF v_neto = 0 THEN
                  v_cap_seg_prevision := 0;
               ELSE
                  v_cap_seg_prevision := v_prevision;
               END IF;
            ELSE
               v_prevision := v_prevision + round(nvl(v_neto, 0) * v_por_prevision / 100, 2);
               IF v_neto = 0 THEN
                  v_cap_seg_prevision := 0;
               ELSE
                  v_cap_seg_prevision := v_prevision;
               END IF;
            END IF;
           end if;
         END IF;
         --
         IF v_tip_implementacion IN (3, 1) and nvl(v_ban_fogapy,'N') <> 'S' THEN -- para fogapy no debe calcular 2 veces
            -- FA
            -- if (v_cat_prev <> 1 and v_cat_subjetiva is null) or (v_cat_prev <> 1 and v_cat_subjetiva > 2  and reg.dia_atraso > 60) then
          --  IF (reg.dia_atraso > 60 OR v_cat_prev > 2) THEN
            if (v_cat_prev not in (1,2) OR (v_cat_prev = 2 AND reg.dia_atraso > 60)) then
               v_prevision         := v_prevision + nvl(reg.dev_no_cobrado, 0);
               v_int_seg_prevision := nvl(reg.dev_no_cobrado, 0);
            END IF;
/*          if v_cat_prev = 2 and reg.dia_atraso > 60 then
             v_prevision := v_prevision + nvl(reg.dev_no_cobrado,0);
          end if;*/
         END IF;

         --- Calcular la Primera Prevision y Segunda Prevision Capital e Interes
         --- Obtener el Capital de Primera Previsión a partir del Total Aplicado para generar la Primera Previsión

         IF v_cat_prev <> 1 THEN
            v_sal_capital := nvl(reg.sal_capital, 0);
         ELSE
            v_sal_capital := nvl(reg.oc_ttdeuda, 0);
         END IF;

         IF v_sal_capital <= 0 THEN
            v_sal_capital := 1;
         END IF;
         v_cap_pri_prevision := round(nvl(reg.sal_capital, 0) / (case when nvl(v_sal_capital, 0) = 0 then 1 else nvl(v_sal_capital, 0) end) *
                                      v_pri_prevision, v_redondeo);
         --- Obtener el Interés de Primera Previsión a partir del Capital y Primera Previsión
         v_int_pri_prevision := round(nvl(v_pri_prevision, 0) - nvl(v_cap_pri_prevision, 0),
                                      v_redondeo);
         --- Obtener la Segunda Previsión Capital a partir del Total de Previsión y Primera Previsión
         v_seg_prevision := round(nvl(v_prevision, 0) - nvl(v_pri_prevision, 0), v_redondeo);
         IF v_neto <= 0 THEN
            v_neto := 1;
         END IF;
         --- Obtener el Capital de Segunda Previsión a partir del Neto utilizado para el Total de Previsión
         IF v_neto < reg.sal_capital AND v_garantia > 0 AND v_prevision > 0 AND v_cat_prev <> 6 THEN
            v_neto := v_neto + v_garantia + v_prevision;
         END IF;
         IF reg.cat_riesgo = 1 THEN
            v_cap_seg_prevision := round((nvl(v_sal_capital, 0) / (case when nvl(v_neto, 0) = 0 then 1 else nvl(v_neto, 0) end)) *
                                         nvl(v_seg_prevision, 0), v_redondeo);
            --- Obtener el Interés de Segunda Previsión a Partir del Capital y Segunda Previsión
            v_int_seg_prevision := round(nvl(v_seg_prevision, 0) - nvl(v_cap_seg_prevision, 0),
                                         v_redondeo);
         END IF;
         IF v_cat_subjetiva = 2 AND reg.dia_atraso <= 60 AND nvl(v_garantia, 0) <> 0 and nvl(v_ban_fogapy,'N') <> 'S' THEN -- no debe entrar si es fogapy
            IF v_cod_mon_local = reg.cod_moneda THEN
               v_int_seg_prevision := round(nvl(reg.dev_no_cobrado, 0) * v_por_prevision / 100, 0);
            ELSE
               v_int_seg_prevision := round(nvl(reg.dev_no_cobrado, 0) * v_por_prevision / 100, 2);
            END IF;

            v_prevision := nvl(v_prevision, 0) + nvl(v_int_seg_prevision, 0);
         END IF;
         --- Recuperar prevision anterior si la tuviere
         v_prv_anterior := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual);
         v_diferencia   := 0;
         v_calculo      := nvl(reg.dias_transcurridos, 1);
         IF v_calculo = 0 THEN
            v_calculo := 1;
         END IF;
         -- para previsión diferida mipymes..
         IF nvl(LF_OBT_PARDINAMICO('PRE_MAD_EXC_PYMES', v_ge_par_dinamicos, reg.cod_modulo, reg.cod_modalidad), 'N') = 'S' 
           and nvl(LF_OBT_PARDINAMICO('PRE_MAD_SIN_DIFERIR', v_ge_par_dinamicos, reg.cod_modulo, reg.cod_modalidad), 'N') <> 'S' THEN -- La modalidad 641 no debe diferir
            v_mto_pre_total := v_prevision;
            ---plazo por dias 30
            v_prevision := trunc(v_prevision / v_pre_pla_mipymes, v_redondeo) * v_calculo;
         END IF;
         --------------inicio prev..
         IF (v_tip_implementacion = 3 AND reg.cod_causa IS NULL) OR
            v_tip_implementacion <> 3 THEN
            --- Inicializar datos cabecera del movimiento
            r_gmovi.cod_usuario    := USER;
            r_gmovi.hora           := v_hora;
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
            r_gmovi.est_cuenta     := reg.estado;
            IF v_nro_secuencia + 2 > 999 THEN
               v_nro_secuencia := 0;
               v_hora          := fug_ini_hora(SYSDATE); --PDSB-531
               v_hora          := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
               r_gmovi.hora    := v_hora;
            END IF;
            --v_por_capital := 100 - round((reg.sal_capital / (case when NVL(reg.mto_capital,0) = 0 then 1 else NVL(reg.mto_capital,0) end)) * 100);
            IF reg.fec_cancelacion IS NOT NULL THEN

               IF nvl(v_prv_anterior, 0) > 0 THEN
                  --- Desafectar la prevision por cancelacion de prestamos
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.cod_tra_padre   := 731;
                  r_gmovi.cod_transaccion := 731;
                  r_gmovi.concepto        := 'EXTORNO DE PREVISION';
                  r_gmovi.monto           := v_prv_anterior;
                  r_gmovi.est_cuenta      := reg.est_batch;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  --- Insertar prevision
                  /*r_pprev.nro_cuenta            := reg.nro_cuenta;
                  r_pprev.fecha                 := v_fec_actual;
                  r_pprev.monto                 := nvl(v_prevision, 0);
                  r_pprev.sal_capital           := nvl(reg.sal_capital, 0);
                  r_pprev.dev_no_cobrado        := nvl(reg.dev_no_cobrado, 0);
                  r_pprev.porcentaje            := nvl(v_por_prevision, 0);
                  r_pprev.tot_pri_prevision     := nvl(v_pri_prevision, 0);
                  r_pprev.mto_pre_total         := nvl(v_mto_pre_total, 0);
                  r_pprev.tot_gar_computables   := nvl(v_garantia, 0);
                  r_pprev.tot_cap_pri_prevision := nvl(v_cap_pri_prevision, 0);
                  r_pprev.tot_cap_seg_prevision := nvl(v_cap_seg_prevision, 0);
                  r_pprev.tot_int_pri_prevision := nvl(v_int_pri_prevision, 0);
                  r_pprev.tot_int_seg_prevision := nvl(v_int_seg_prevision, 0);
                  lp_ins_prevision(r_pprev);*/
                  v_pr_previsiones.extend();
                  v_pr_previsiones(v_pr_previsiones.count).nro_cuenta            := reg.nro_cuenta;
                  v_pr_previsiones(v_pr_previsiones.count).fecha                 := v_fec_actual;
                  v_pr_previsiones(v_pr_previsiones.count).monto                 := nvl(v_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).sal_capital           := nvl(reg.sal_capital, 0);
                  v_pr_previsiones(v_pr_previsiones.count).dev_no_cobrado        := nvl(reg.dev_no_cobrado, 0);
                  v_pr_previsiones(v_pr_previsiones.count).porcentaje            := nvl(v_por_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_pri_prevision     := nvl(v_pri_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).mto_pre_total         := nvl(v_mto_pre_total, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_gar_computables   := nvl(v_garantia, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_cap_pri_prevision := nvl(v_cap_pri_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_cap_seg_prevision := nvl(v_cap_seg_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_int_pri_prevision := nvl(v_int_pri_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_int_seg_prevision := nvl(v_int_seg_prevision, 0);
               END IF;
            ELSE
               v_diferencia  := nvl(v_prevision, 0) - nvl(v_prv_anterior, 0);
               r_gmovi.monto := nvl(v_diferencia, 0);
               IF v_diferencia <> 0 THEN
                  --- Insertar prevision
                  /*r_pprev.nro_cuenta            := reg.nro_cuenta;
                  r_pprev.fecha                 := v_fec_actual;
                  r_pprev.monto                 := nvl(v_prevision, 0);
                  r_pprev.sal_capital           := nvl(reg.sal_capital, 0);
                  r_pprev.dev_no_cobrado        := nvl(reg.dev_no_cobrado, 0);
                  r_pprev.porcentaje            := nvl(v_por_prevision, 0);
                  r_pprev.tot_gar_computables   := nvl(v_garantia, 0);
                  r_pprev.mto_pre_total         := nvl(v_mto_pre_total, 0);
                  r_pprev.tot_pri_prevision     := nvl(v_pri_prevision, 0);
                  r_pprev.tot_cap_pri_prevision := nvl(v_cap_pri_prevision, 0);
                  r_pprev.tot_cap_seg_prevision := nvl(v_cap_seg_prevision, 0);
                  r_pprev.tot_int_pri_prevision := nvl(v_int_pri_prevision, 0);
                  r_pprev.tot_int_seg_prevision := nvl(v_int_seg_prevision, 0);
                  lp_ins_prevision(r_pprev);*/
                  v_pr_previsiones.extend();
                  v_pr_previsiones(v_pr_previsiones.count).nro_cuenta            := reg.nro_cuenta;
                  v_pr_previsiones(v_pr_previsiones.count).fecha                 := v_fec_actual;
                  v_pr_previsiones(v_pr_previsiones.count).monto                 := nvl(v_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).sal_capital           := nvl(reg.sal_capital, 0);
                  v_pr_previsiones(v_pr_previsiones.count).dev_no_cobrado        := nvl(reg.dev_no_cobrado, 0);
                  v_pr_previsiones(v_pr_previsiones.count).porcentaje            := nvl(v_por_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_gar_computables   := nvl(v_garantia, 0);
                  v_pr_previsiones(v_pr_previsiones.count).mto_pre_total         := nvl(v_mto_pre_total, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_pri_prevision     := nvl(v_pri_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_cap_pri_prevision := nvl(v_cap_pri_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_cap_seg_prevision := nvl(v_cap_seg_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_int_pri_prevision := nvl(v_int_pri_prevision, 0);
                  v_pr_previsiones(v_pr_previsiones.count).tot_int_seg_prevision := nvl(v_int_seg_prevision, 0);
                  IF v_diferencia < 0 THEN
                     --- Desafectar previsiones
                     v_nro_secuencia         := v_nro_secuencia + 1;
                     r_gmovi.monto           := nvl(v_diferencia * -1, 0);
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     r_gmovi.cod_tra_padre   := 731;
                     r_gmovi.cod_transaccion := 731;
                     r_gmovi.concepto        := 'EXTORNO DE PREVISION';
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  ELSIF v_diferencia > 0 THEN
                     --- Constituir previsiones
                     v_nro_secuencia         := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia   := v_nro_secuencia;
                     r_gmovi.cod_tra_padre   := 730;
                     r_gmovi.cod_transaccion := 730;
                     r_gmovi.concepto        := 'CONSTITUCION DE PREVISION';
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  END IF;
               END IF;
            END IF;
            -- Llenar las colecciones con los ROWID y los valores asociados luego realizo update por forall
            v_cla_fila_tab.EXTEND;
            v_nro_cta_tab.EXTEND;
            v_prev_tab.EXTEND;
            v_mto_prev_tab.EXTEND;
            v_pri_prev_tab.EXTEND;
            v_seg_prev_tab.EXTEND;
            v_gar_apli_tab.EXTEND;
            v_rie_no_tab.EXTEND;
            v_cap_pri_tab.EXTEND;
            v_cap_seg_tab.EXTEND;
            v_int_pri_tab.EXTEND;
            v_int_seg_tab.EXTEND;
            v_cat_prev_tab.EXTEND;
             
            v_cla_fila_tab(v_cla_fila_tab.COUNT) := reg.id;
            v_nro_cta_tab(v_nro_cta_tab.COUNT) := reg.nro_cuenta; 
            v_prev_tab(v_prev_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_prevision, 0));
            v_mto_prev_tab(v_mto_prev_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_mto_pre_total, 0));
            v_pri_prev_tab(v_pri_prev_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_pri_prevision, 0));
            v_seg_prev_tab(v_seg_prev_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_seg_prevision, 0));
            v_gar_apli_tab(v_gar_apli_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_garantia, 0)); 
            v_rie_no_tab(v_rie_no_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_rie_no_cubierto, 0));
            v_cap_pri_tab(v_cap_pri_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_cap_pri_prevision, 0));
            v_cap_seg_tab(v_cap_seg_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_cap_seg_prevision, 0));
            v_int_pri_tab(v_int_pri_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_int_pri_prevision, 0)); 
            v_int_seg_tab(v_int_seg_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_int_seg_prevision, 0));
            v_cat_prev_tab(v_cat_prev_tab.COUNT) := v_cat_cli_prevision;
         END IF;
         --------------------fin prevv..
      END IF;
   END LOOP;
           
   -- Usar FORALL para el UPDATE en GE_CLA_OPERACIONES
   FORALL i IN 1..v_cla_fila_tab.COUNT
     UPDATE GE_CLA_OPERACIONES
      SET tot_prevision = v_prev_tab(i),
          mto_pre_total = v_mto_prev_tab(i),
          tot_pri_prevision = v_pri_prev_tab(i),
          tot_seg_prevision = v_seg_prev_tab(i),
          tot_gar_aplicada = v_gar_apli_tab(i),
          tot_rie_no_cubierto = v_rie_no_tab(i),
          tot_cap_pri_prevision = v_cap_pri_tab(i),
          tot_cap_seg_prevision = v_cap_seg_tab(i),
          tot_int_pri_prevision = v_int_pri_tab(i),
          tot_int_seg_prevision = v_int_seg_tab(i),
          cat_prevision         = v_cat_prev_tab(i)
       WHERE nro_cuenta = v_nro_cta_tab(i);
   
   FORALl i IN 1..v_pr_previsiones.COUNT
     INSERT INTO PR_PREVISIONES
     (nro_cuenta,
      fecha,
      monto,
      sal_capital,
      dev_no_cobrado,
      porcentaje,
      tot_gar_computables,
      mto_pre_total,
      tot_pri_prevision,
      tot_cap_pri_prevision,
      tot_cap_seg_prevision,
      tot_int_pri_prevision,
      tot_int_seg_prevision)
     VALUES
     (v_pr_previsiones(i).nro_cuenta,
      v_pr_previsiones(i).fecha,
      v_pr_previsiones(i).monto,
      v_pr_previsiones(i).sal_capital,
      v_pr_previsiones(i).dev_no_cobrado,
      v_pr_previsiones(i).porcentaje,
      v_pr_previsiones(i).tot_gar_computables,
      v_pr_previsiones(i).mto_pre_total,
      v_pr_previsiones(i).tot_pri_prevision,
      v_pr_previsiones(i).tot_cap_pri_prevision,
      v_pr_previsiones(i).tot_cap_seg_prevision,
      v_pr_previsiones(i).tot_int_pri_prevision,
      v_pr_previsiones(i).tot_int_seg_prevision);
         
   
EXCEPTION 
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error nro_cuenta: '||v_nro_cuenta||' - '||sqlerrm);
END;
/
