CREATE OR REPLACE PROCEDURE IT.PRP_GEN_PRE_EXCEPCION(p_nro_cuenta pr_cta_prestamos.nro_cuenta%TYPE DEFAULT NULL) IS
   --- PROCESO DE GENERACION DE PREVISIONES RES 4 BCP 18/03/2020 PARA OPERACIONES DE 3R.

   TYPE typ_usu_secuencia IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
   v_usu_secuencia typ_usu_secuencia;

   TYPE typ_usu_hora IS TABLE OF VARCHAR2(8) INDEX BY VARCHAR2(15);
   v_usu_hora typ_usu_hora;
   
   TYPE typ_usu_cuenta IS TABLE OF VARCHAR2(50) INDEX BY VARCHAR2(50); 
   v_usu_cuenta typ_usu_cuenta;
   
   TYPE typ_usu_mov_gen IS TABLE OF VARCHAR2(1) INDEX BY VARCHAR2(50); -- 'S' si la hora ya fue usada
   v_usu_mov_gen typ_usu_mov_gen;
   
   /* Obtener garantia computable. */--
   FUNCTION lf_obt_gar_com
   (
      p_nro_cuenta    IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_cod_moneda    IN ba_monedas.cod_moneda%TYPE,
      p_cod_mon_local IN ba_monedas.cod_moneda%TYPE,
      p_tot_deuda     IN pr_cta_prestamos.sal_capital%TYPE
   ) RETURN NUMBER;
   
    FUNCTION fu_obt_cod_entidad RETURN NUMBER;
   /* Obtener garantia cash. */
   FUNCTION lf_obt_gar_cash(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE) RETURN NUMBER;
   /* Obtener prevision anterior. */
   FUNCTION lf_obt_prv_ant
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER;
   /* Obtener prevision anterior. */
   FUNCTION lf_obt_prv_ant_acum
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER;
   /* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
   FUNCTION lf_obt_cat_prevision
   (
      p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE,
      p_nro_cuenta  IN ge_cla_operaciones.nro_cuenta%TYPE,
      p_tip_cliente IN ge_clientes.tipo%TYPE
   ) RETURN NUMBER;
   /* obtiene si la cat_automatica del cliente es distinta entre sus cuentas MT*/
  function lf_obt_cat_distintas(p_cod_persona in ge_cla_operaciones.cod_persona%type)
    return varchar2;
  /* obtiene si el cliente tiene garantia fogapy*/
  function lf_obt_gar_fogapy(p_nro_cuenta in pr_cta_garantias.nro_cuenta%type)
    return varchar2;

  function lf_obt_cat_promedio(p_cod_persona IN ge_cla_operaciones.cod_persona%type)
    return number;
  
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
    
   /*Para generar previsiones
   préstamo con marca
   menos de 30 días de mora --> previsiono 1/v_PRE_PLA_RRR_RES4 el monto de previsión mínimo del 5% todos los días desde
   el primer día hasta el día 30,
   día 2 monto de previsión / v_PRE_PLA_RRR_RES4,
   luego al cumplirse el día 31, debe ser por 35 y así sucesivamente
   más de 30 días de mora -->
   previsiono de acuerdo a la categoría del cliente, mismo diferido en v_PRE_PLA_RRR_RES4
   */

   /*Secuencia de Procesos
   - Cambio de Estado
   - Devengado
   - Categorizacion
   - Prevision Normal
   - Prrevision Corona */
   v_fec_actual            ge_calendarios.fec_actual%TYPE;
   v_fec_inicio            pr_cta_prestamos.fec_inicio%TYPE;
   v_cod_mon_local         ba_monedas.cod_moneda%TYPE;
   v_riesgo1a              pr_parametros.por_riesgo_1a%TYPE;
   v_riesgo1b              pr_parametros.por_riesgo_1b%TYPE;
   v_riesgo2               pr_parametros.por_riesgo_2%TYPE;
   v_riesgo3               pr_parametros.por_riesgo_3%TYPE;
   v_riesgo4               pr_parametros.por_riesgo_4%TYPE;
   v_riesgo5               pr_parametros.por_riesgo_5%TYPE;
   v_riesgo6               pr_parametros.por_riesgo_6%TYPE;
   v_garantia              pr_cta_garantias.mto_apl_computable%TYPE;
   v_prevision             pr_previsiones.monto%TYPE;
   v_prev_total        	   pr_previsiones.monto%TYPE;
   v_prv_anterior          pr_previsiones.monto%TYPE;
   v_prv_ant_acum          pr_previsiones.monto%TYPE;
   v_diferencia            pr_previsiones.monto%TYPE;
   v_calculo               pr_previsiones.monto%TYPE;
   v_calculo_696           pr_previsiones.monto%TYPE;   
   r_gmovi                 ge_movimientos%ROWTYPE;
   v_cat_prev              ge_cla_operaciones.cat_automatica%TYPE;
   v_cat_subjetiva         ge_clientes.cat_subjetiva%TYPE;
   v_por_prev_clie         NUMBER(5, 2);
   v_prev_acum_ant         pr_previsiones.monto%TYPE;
   v_dif_prev_acum         pr_previsiones.monto%TYPE;
   --- Variables nuevas
   v_ban_fogapy            varchar2(1); --bandera1
   v_pri_prevision         NUMBER(18, 2);
   v_dias_cat              NUMBER(10);
   v_dia_atraso            NUMBER(5);
   v_por_prevision         NUMBER(18, 2);
   v_por_prev_cheq         NUMBER(18, 2);
   v_redondeo              NUMBER(2);
   v_neto                  ge_cla_operaciones.tot_deu_real%TYPE;
   v_tip_implementacion    ge_par_generales.tip_implementacion%TYPE;
   v_cau_insufondos        ge_causales.cod_causa%TYPE;
   v_cat_cli_prevision     ge_cla_operaciones.cat_automatica%TYPE;
   v_cat_distintas         varchar2(1);
   v_seg_prevision         pr_previsiones.tot_pri_prevision%TYPE;
   v_tot_rie_no_cubierto   pr_previsiones.tot_pri_prevision%TYPE;
   v_cap_pri_prevision     pr_previsiones.tot_pri_prevision%TYPE;
   v_int_pri_prevision     pr_previsiones.tot_pri_prevision%TYPE;
   v_cap_seg_prevision     pr_previsiones.tot_pri_prevision%TYPE;
   v_int_seg_prevision     pr_previsiones.tot_pri_prevision%TYPE;
   v_sal_capital           pr_previsiones.tot_pri_prevision%TYPE;
   v_gar_cash              pr_cta_garantias.mto_apl_computable%TYPE := 0;
   v_cod_entidad           ge_par_generales.cod_entidad%TYPE := fu_obt_cod_entidad;
   v_pre_req_pla_res4      ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_REQ_PLA_RES4');
   v_pre_pla_rrr_res4      ge_par_dinamicos.val_parametro%TYPE;
   v_pre_pla_res4_2020     ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_PLA_RRR_RES4');
   v_pre_pla_res4_2021     ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_PLA_RES4_2021');
   v_60_meses              ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_PLA_60_MESES');
   v_18_meses              ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_PLA_18_MESES');
   v_pre_cat_riesgo        ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PRE_CAT_RIESGO');
   v_mto_pre_total         pr_previsiones.mto_pre_total%TYPE;
   v_pre_mad_fogapy        varchar2(1) := 'N';
   v_gar_fogapy            pr_cta_garantias.mto_con_computable%TYPE;
   v_usu_mig_excluir       varchar2(30);
   v_cod_mad_che_devuelto  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CHEQUES DEVUELTOS', 6);
   v_cod_mad_che_diferido  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CHEQUES DIFERIDOS', 6);
   v_cod_mon_base     	   ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   v_tot_pri_prevision     ge_cla_operaciones.tot_pri_prevision%type;
   v_tot_cap_pri_prevision ge_cla_operaciones.tot_cap_pri_prevision%type;
   v_tot_cap_seg_prevision ge_cla_operaciones.tot_cap_seg_prevision%type;
   v_tot_int_pri_prevision ge_cla_operaciones.tot_int_pri_prevision%type;
   v_tot_int_seg_prevision ge_cla_operaciones.tot_int_seg_prevision%type;
   v_usuario 			   ba_usuarios.cod_usuario%type;
   v_can_user 			   number;      
   ex_bulk_errors EXCEPTION;
   PRAGMA EXCEPTION_INIT(ex_bulk_errors, -24381);
   v_indice       NUMBER;
   v_codigo       NUMBER;
   v_mensaje      VARCHAR2(4000);
   v_cuenta_error pr_cta_prestamos.nro_cuenta%TYPE;
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
   TYPE type_pr_previsiones IS TABLE OF pr_previsiones%ROWTYPE;
   
   --Inicializar y limpiar las variables
   v_cla_fila_tab t_cla_fila_tab          := t_cla_fila_tab();
   v_nro_cta_tab t_nro_cta_tab            := t_nro_cta_tab(); 
   v_prev_tab t_prev_tab                  := t_prev_tab();
   v_mto_prev_tab t_mto_prev_tab          := t_mto_prev_tab();
   v_pri_prev_tab t_pri_prev_tab          := t_pri_prev_tab();
   v_seg_prev_tab t_seg_prev_tab          := t_seg_prev_tab();
   v_gar_apli_tab t_gar_apli_tab          := t_gar_apli_tab();
   v_rie_no_tab t_rie_no_tab              := t_rie_no_tab();
   v_cap_pri_tab t_cap_pri_tab            := t_cap_pri_tab();
   v_cap_seg_tab t_cap_seg_tab            := t_cap_seg_tab();
   v_int_pri_tab t_int_pri_tab            := t_int_pri_tab();  
   v_int_seg_tab t_int_seg_tab            := t_int_seg_tab();
   v_cat_prev_tab t_cat_prev_tab          := t_cat_prev_tab();
   reg_pr_previsiones type_pr_previsiones := type_pr_previsiones();
   /*Para parametros dinamicos*/
   v_ge_par_dinamicos it.typ_ge_par_dinamicos_tab;
   
   --- Cursor de prestamos a calcular
   CURSOR c_prestamos IS
   --- Tomar los préstamos que tengan la marca que sean los registrados en el día
   --- Serían los préstamos desembolsados en la fecha
      SELECT p.nro_cuenta,
             nvl(p.sal_capital, 0) sal_capital,
             nvl(p.sal_interes, 0) sal_interes,
             p.cod_moneda,
             c.cod_persona,
             (case when nvl(o.cat_automatica, 1) > nvl(p.cat_pre_diferida,1) then
                nvl(to_number(o.cat_automatica),1)
              else
                nvl(p.cat_pre_diferida, nvl(o.cat_automatica, 1)) 
             end
             )              
             cat_riesgo, --- de acuerdo a la categoría de riesgo se debe generar la previsión
             c.cat_subjetiva,
             o.cat_automatica,
             p.cod_modalidad,
             p.nro_solicitud,
             p.cod_oficina,
             p.fec_cancelacion,
             nvl(p.dev_no_cobrado, 0) dev_no_cobrado,
             p.cod_modulo,
             nvl(p.sal_int_adelantado, 0) sal_int_adelantado,
             nvl(trim(c.tipo), a.tipo) tip_cliente,
             p.estado,
             p.est_batch,
             p.cod_causa,
             p.cat_pre_diferida,
             nvl(a.cat_riesgo, 1) cat_rie_actual,
             o.tot_prevision,
             nvl(p.dia_atraso, 0) dia_atraso,
             p.cat_renovaciones,
             o.cat_ren_anterior,
             o.lib_prevision,
             nvl(p.sal_capital, 0) + nvl(p.dev_no_cobrado, 0) oc_ttdeuda,
             nvl(c.fec_ult_clasif, v_fec_actual) fec_ult_clasif,
             v_fec_actual - p.fec_inicio dias_transcurridos,
             p.fec_inicio,
             trunc((p.fec_vencimiento - p.fec_inicio) / 30, 0) plazo,
             o.rowid id
        FROM ge_clientes    c,
             ge_cta_clientes    cc,
             pr_cta_prestamos   p,
             ge_cla_operaciones o,
             ge_clientes        a
       WHERE p.nro_cuenta = cc.nro_cuenta
         AND o.nro_cuenta(+) = p.nro_cuenta
         AND cc.relacion = 'P'
         AND a.cod_persona = cc.cod_persona
         AND cc.cod_persona = c.cod_persona
         AND (p.nro_cuenta = p_nro_cuenta OR p_nro_cuenta IS NULL)         
         AND (exists(select 1
                             from ge_par_dinamicos a
                            where a.cod_modulo = p.cod_modulo
                              and a.cod_modalidad = p.cod_modalidad
                              and a.parametro = 'PRE_MAD_EXCEPCION'
                              and a.val_parametro = 'S')
           OR EXISTS (SELECT 1 
            FROM ge_cta_dat_adicionales aa
           WHERE aa.parametro IN ('PRE_RRR_CTA_MBT','PRE_RRR_CTA_MBT1','PRE_RRR_CTA_MBT2')
             AND aa.nro_cuenta = p.nro_cuenta))
         AND NOT EXISTS (select 1 from it.ge_cta_dat_fusion t where t.cod_modulo=p.cod_modulo 
                                                               and   t.nro_cuenta=p.nro_cuenta) ;

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
      CURSOR c_garantias IS
         SELECT g.mto_apl_computable, t.cod_garantia
           FROM pr_cta_garantias g, pr_gar_tipos t, pr_garantias ss
          WHERE g.nro_cuenta = p_nro_cuenta
            AND g.cod_garantia = t.cod_garantia
            AND t.computable = 'S'
            AND nvl(g.mto_apl_computable, 0) > 0
            AND g.nro_garantia = ss.nro_garantia
            AND g.cod_garantia = ss.cod_garantia
            AND nvl(ss.estado,'X') = 'C'; -- la garantia debe estar confirmada FIELDESK-6225
   BEGIN
      v_tot_gara := 0;
      FOR reg IN c_garantias LOOP
         v_gar_compu := nvl(reg.mto_apl_computable, 0);
         --- totalizar garantias computables en moneda de la cuenta ---------
         v_tot_gara := nvl(v_tot_gara, 0) + nvl(v_gar_compu, 0);
      END LOOP;
      RETURN v_tot_gara;
   END;
   
   /* obtener si la persona tiene cat_automaticas distintas entre sus  mt  */
  function lf_obt_cat_distintas(p_cod_persona in ge_cla_operaciones.cod_persona%type)
    return varchar2 is
    v_persona ge_cla_operaciones.cod_persona%type;
    valor     varchar2(1);
    -- recupera si la cuenta tiene cat_automatica distinta entre sus mt
  begin
    select cod_persona,
           case
             when count(*) in (2, 3, 4) and
                  count(distinct cat_automatica) = 2 then
              'S'
             else
              'N'
           end as Xx
      into v_persona, valor
      from (select *
              from ge_cla_operaciones a
             where cat_automatica in
                   (select cat_automatica
                      from ge_cla_operaciones aa
                     where aa.cod_persona = a.cod_persona)
               and (exists(select 1
                             from ge_par_dinamicos p
                            where p.cod_modulo = a.cod_modulo
                              and p.cod_modalidad = a.cod_modalidad
                              and p.parametro = 'PRE_MAD_EXCEPCION'
                              and p.val_parametro = 'S'))) b
     where cod_persona = p_cod_persona
     group by cod_persona;
  
    return(valor);
  
  exception
    when others then
      return('N');
  end;
  
  /* obtener si la persona tiene garantia fogapy*/
  function lf_obt_gar_fogapy(p_nro_cuenta in pr_cta_garantias.nro_cuenta%type)
    return varchar2 is
    v_existe varchar2(1);
    -- recupera si la cuenta tiene garantia fogapy
  begin
    select 'S'
      into v_existe
      from pr_cta_garantias s, pr_gar_tipos ss, pr_garantias se
     where s.cod_garantia = ss.cod_garantia
       and nro_cuenta = p_nro_cuenta
       and ss.computable = 'S'
       AND nvl(s.mto_apl_computable, 0) > 0
       AND s.cod_garantia in (select t.val_minimo from ba_cod_referencias t where dominio = 'COD_GAR_FOGAPY' )
       AND s.nro_garantia = se.nro_garantia
       AND s.cod_garantia = se.cod_garantia
       AND nvl(se.estado,'X') = 'C'; -- la garantia debe estar confirmada FIELDESK-6225
  
    return(v_existe);
  
  exception
    when others then
      return('N');
  end;

  /*Obtiene la cat_automatica promedio si el cliente tiene cat_automatica distintas*/
  function lf_obt_cat_promedio(p_cod_persona IN ge_cla_operaciones.cod_persona%type)
    return number is
    p_persona ge_cla_operaciones.cod_persona%type;
    valor     ge_cla_operaciones.cat_automatica%type;
  
    -- Recupera el promedio de la cat_automatica de las mt
  begin
    select cod_persona, round(sum(cat_pon), 2) cat_final 
      into p_persona, valor
      from (select cod_persona,
                   round(((sal_capital / deuda_total) * cat_automatica), 2) cat_pon
              from (select cod_persona,
                           nro_cuenta,
                           cat_automatica,
                           nvl(tot_deu_real, 0) - nvl(dev_no_cobrado, 0) sal_capital,
                           (select sum(nvl(tot_deu_real, 0) -
                                       nvl(dev_no_cobrado, 0))
                              from ge_cla_operaciones s
                             where s.cod_persona = a.cod_persona
                               and ((exists(select 1
                                              from ge_par_dinamicos a
                                             where a.cod_modulo = s.cod_modulo
                                               and a.cod_modalidad = s.cod_modalidad
                                               and a.parametro = 'PRE_MAD_EXCEPCION'
                                               and a.val_parametro = 'S') or
                                   exists
                                    (select 1
                                        from ge_cta_dat_adicionales aa
                                       where aa.parametro in
                                             ('PRE_RRR_CTA_MBT',
                                              'PRE_RRR_CTA_MBT1',
                                              'PRE_RRR_CTA_MBT2')
                                         and aa.nro_cuenta = s.nro_cuenta)))
                             group by cod_persona) deuda_total
                      FROM ge_cla_operaciones a
                     where ((exists(select 1
                                      from ge_par_dinamicos g
                                     where g.cod_modulo = a.cod_modulo
                                       and g.cod_modalidad = a.cod_modalidad
                                       and g.parametro = 'PRE_MAD_EXCEPCION'
                                       and g.val_parametro = 'S') or exists
                            (select 1
                                from ge_cta_dat_adicionales aa
                               where aa.parametro in
                                     ('PRE_RRR_CTA_MBT',
                                      'PRE_RRR_CTA_MBT1',
                                      'PRE_RRR_CTA_MBT2')
                                 and aa.nro_cuenta = a.nro_cuenta)))
                       and cod_persona = p_cod_persona) b) c
     group by cod_persona;
  
    return(valor);
  
  exception
    when others then
      return('1');      
  end;

   /* Obtener garantia cash. */
   FUNCTION lf_obt_gar_cash(p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE) RETURN NUMBER IS
      v_gar_compu pr_cta_garantias.mto_apl_computable%TYPE := 0;
      v_tot_gara  pr_cta_garantias.mto_apl_computable%TYPE := 0;
      v_cot_aux   ge_cotizaciones.val_conversion%TYPE;
      CURSOR c_garantias IS
         SELECT g.mto_apl_computable, t.cod_garantia
           FROM pr_cta_garantias g, pr_gar_tipos t, pr_garantias ss
          WHERE g.nro_cuenta = p_nro_cuenta
            AND g.cod_garantia = t.cod_garantia
            AND t.computable = 'S'
            AND t.cod_garantia in (select t.val_minimo from ba_cod_referencias t where dominio = 'COD_GAR_CASH' )
            AND nvl(g.mto_apl_computable, 0) > 0
            AND g.nro_garantia = ss.nro_garantia
            AND g.cod_garantia = ss.cod_garantia
            AND nvl(ss.estado,'X') = 'C'; -- la garantia debe estar confirmada FIELDESK-6225
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

   /* Obtener prevision anterior. */
   FUNCTION lf_obt_prv_ant
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER IS
      v_monto pr_previsiones.monto%TYPE;
   BEGIN
      SELECT SUM(nvl(monto, 0))
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

   /* Obtener prevision anterior. */
   FUNCTION lf_obt_prv_ant_acum
   (
      p_nro_cuenta IN pr_cta_prestamos.nro_cuenta%TYPE,
      p_fec_actual IN DATE
   ) RETURN NUMBER IS
      v_monto pr_previsiones.mto_pre_total%TYPE;
   BEGIN
      SELECT SUM(nvl(mto_pre_total, 0))
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
   FUNCTION lf_obt_cat_prevision
   (
      p_cod_persona IN ge_cla_operaciones.cod_persona%TYPE,
      p_nro_cuenta  IN ge_cla_operaciones.nro_cuenta%TYPE,
      p_tip_cliente IN ge_clientes.tipo%TYPE
   ) RETURN NUMBER AS
      v_categoria ge_cla_operaciones.cat_automatica%TYPE;
   BEGIN  
    select nvl(max(b.cat_automatica), 1), nvl(max(b.dia_atraso), 0)
      into v_categoria, v_dia_atraso
      from pr_cta_prestamos a, ge_cla_operaciones_his b
     where a.nro_cuenta = b.nro_cuenta
       and nro_cta_renovada = p_nro_cuenta
       and b.fecha =
           (select max(fecha)
              from ge_cla_operaciones_his
             where nro_cuenta in
                   (select aa.nro_cuenta
                      from ge_cta_dat_adicionales aa
                     where aa.parametro in
                           ('PRE_RRR_CTA_MBT',
                            'PRE_RRR_CTA_MBT1',
                            'PRE_RRR_CTA_MBT2')
                       and aa.nro_cuenta = p_nro_cuenta));
                                                    
        if v_dia_atraso = 0 then-- puede ser 3r migrada.
           BEGIN
              --Verifico las operaciones que posee el cliente.
              SELECT nvl(MAX(a.cat_automatica), 1), nvl(MAX(a.dia_atraso), 0)
                INTO v_categoria, v_dia_atraso
                FROM ge_cla_operaciones a
               WHERE a.cod_persona = p_cod_persona;
              RETURN v_categoria;
           EXCEPTION
              WHEN OTHERS THEN
                 v_categoria := 1;
                 RETURN v_categoria;
           END;
        end if;
      --- Verificar el tipo de renovacion del nuevo prestamo
      IF p_tip_cliente IN ('G', 'R', 'M') THEN
         -- comerciales mayores
         --- tipo de cliente comercial ----

         IF v_dia_atraso <= 30 THEN
            v_categoria := 1.1; --- riesgo normal    ---
         ELSIF v_dia_atraso <= 60 THEN
            v_categoria := 1.2; --- riesgo normal    ---
            --
         ELSIF v_dia_atraso <= 90 THEN
            v_categoria := 2; --- riesgo potencial ---
         ELSIF v_dia_atraso <= 150 THEN
            v_categoria := 3; --- riesgo real      ---
         ELSIF v_dia_atraso <= 180 THEN
            v_categoria := 4; --- alto riesgo      ---
         ELSIF v_dia_atraso <= 270 THEN
            v_categoria := 5; --- alto riesgo      ---
         ELSE
            v_categoria := 6; --- irrecuperable    ---
         END IF;
      ELSIF p_tip_cliente IN ('N', 'C', 'P', 'V') THEN
         --- tipo de cliente personal, y comercial menor
         IF v_dia_atraso <= 30 THEN
            v_categoria := 1.1; --- riesgo normal    ---
         ELSIF v_dia_atraso <= 60 THEN
            v_categoria := 1.2; --- riesgo normal    ---
            --
         ELSIF v_dia_atraso <= 90 THEN
            v_categoria := 2; --- riesgo potencial ---
         ELSIF v_dia_atraso <= 150 THEN
            v_categoria := 3; --- riesgo real      ---
         ELSIF v_dia_atraso <= 180 THEN
            v_categoria := 4; --- alto riesgo      ---
         ELSIF v_dia_atraso <= 270 THEN
            v_categoria := 5; --- alto riesgo      ---
         ELSE
            v_categoria := 6; --- irrecuperable    ---
         END IF;
      ELSIF p_tip_cliente = 'T' THEN
         IF v_dia_atraso <= 30 THEN
            v_categoria := 1.1;
         ELSIF v_dia_atraso <= 60 THEN
            v_categoria := 1.2;
            --
         ELSIF v_dia_atraso <= 90 THEN
            v_categoria := 2;
         ELSIF v_dia_atraso <= 120 THEN
            v_categoria := 3;
         ELSIF v_dia_atraso <= 150 THEN
            v_categoria := 4;
         ELSIF v_dia_atraso <= 180 THEN
            v_categoria := 5;
         ELSE
            v_categoria := 6;
         END IF;
      END IF;
      ---usar la categoría por mora de la operacion
      RETURN v_categoria;
   EXCEPTION
      WHEN OTHERS THEN
         v_categoria := 1;
         RETURN v_categoria;
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
   v_cod_mon_local      := pag_gen.fu_obt_mon_local;
   v_tip_implementacion := fug_obt_tip_implementacion;
   -- código de causa por insuficiencia de fondos
   v_cau_insufondos     := fug_obt_pardinamico('CAU_INSUFI_FONDOS', NULL, NULL, NULL, NULL);
   v_usu_mig_excluir    := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   BEGIN
      SELECT DECODE(COUNT(*),0,1,COUNT(*))
        INTO v_can_user 
      FROM ba_cod_referencias
        WHERE dominio = 'USU_MOV_CIERRE' 
         AND abreviatura = 'MOVCIERRE';   
   END;
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
   
   v_pre_pla_rrr_res4 :=0; 
   
   FOR reg IN c_prestamos LOOP
      IF v_pre_req_pla_res4 = 'S' THEN
         v_pre_pla_rrr_res4 := reg.plazo;
      END IF;
      if reg.fec_inicio < '01/01/2021' then
         v_pre_pla_rrr_res4 := v_pre_pla_res4_2020;
      else
         v_pre_pla_rrr_res4 := v_pre_pla_res4_2021;
      end if;
     
      v_tot_pri_prevision := 0;
      v_tot_cap_pri_prevision := 0;
      v_tot_cap_seg_prevision := 0;
      v_tot_int_pri_prevision := 0;
      v_tot_int_seg_prevision := 0;
      v_fec_inicio            := reg.fec_inicio;
      v_cat_prev              := reg.cat_riesgo;
      v_cat_subjetiva         := reg.cat_subjetiva;
      v_prevision             := 0;
      v_prev_total            := 0;
      v_mto_pre_total         := 0;
      v_pri_prevision         := 0;
      v_por_prev_cheq         := 0;
      v_por_prev_clie         := 0;
      v_por_prevision         := 0;
      v_seg_prevision         :=  0;
      v_cap_seg_prevision     :=0;
      v_tot_rie_no_cubierto   :=0;
      v_gar_fogapy            :=0; 
      v_gar_cash              :=0; 
      v_garantia              :=0;  
      v_ban_fogapy            :='N'; 
      v_garantia              := lf_obt_gar_com(reg.nro_cuenta, reg.cod_moneda, v_cod_mon_local,
                                        reg.sal_capital);
      --Cash
      v_gar_cash              := lf_obt_gar_cash(reg.nro_cuenta);
      v_pre_mad_fogapy        := nvl(lf_obt_gar_fogapy(reg.nro_cuenta),'N'); 
      IF reg.cod_modalidad IN
         (v_cod_mad_che_devuelto, v_cod_mad_che_diferido) THEN
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
      -- Carga variable
    v_cat_distintas := lf_obt_cat_distintas(reg.cod_persona);
    if v_cat_distintas = 'S' then    
      v_cat_prev          := lf_obt_cat_promedio(reg.cod_persona); --aca debe hacer la formula rara
      v_cat_cli_prevision := v_cat_prev;
      v_cat_prev          := round(v_cat_prev,0); -- si es catpre_diferida 1.1 o 1.2    
    else
      if reg.cat_pre_diferida is null then   -- si es la primera vez que previsiona y notiene este dato.
         v_cat_cli_prevision := lf_obt_cat_prevision(reg.cod_persona, reg.nro_cuenta, reg.tip_cliente);
      else
         v_cat_cli_prevision := v_cat_prev;
         v_cat_prev := trunc(v_cat_prev); -- si es catpre_diferida 1.1 o 1.2
      end if;
    end if;
    -- Ultima validacion. Se calcula en base a la mas rigurosa
    if nvl(reg.cat_subjetiva,0) > v_cat_prev then
      v_cat_prev := reg.cat_subjetiva;
    end if;
      
      IF v_cat_prev < 2 THEN
         -- Solo Cat 1, 1a, 1b
         v_por_prev_clie := (CASE
                               WHEN v_cat_cli_prevision = 1.1 THEN
                                v_riesgo1a
                               WHEN v_cat_cli_prevision > 1.1 THEN
                               v_riesgo1b
                               ELSE
                                0
                            END);
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
      --- Tomar la mayor previsión como porcentaje
      v_por_prevision := v_por_prev_clie;
      IF v_por_prev_cheq > v_por_prev_clie THEN
         v_por_prevision := v_por_prev_cheq;
      END IF;
      --- REALIZAR PRIMERA REVISION
      --- Aplicar el 50% de la previsión obtenida al neto de la deuda
      v_por_prevision := v_por_prevision / 2;
      v_redondeo      := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_ge_par_dinamicos, 6, NULL, reg.cod_moneda);
      IF v_pre_mad_fogapy = 'S' THEN
         v_gar_fogapy := v_garantia;
      END IF;
      IF v_cat_prev <> 1 OR (v_cat_prev = 1 AND nvl(v_garantia, 0) = 0) THEN
         IF nvl(v_gar_cash, 0) > 0 THEN

            IF (nvl(reg.sal_capital, 0) - nvl(v_gar_cash, 0)) > 0 THEN
               v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_cash, 0)) * v_por_prevision / 100,
                                    v_redondeo);
            END IF;
         ELSIF nvl(v_gar_fogapy, 0) > 0 THEN
           v_ban_fogapy := 'S'; -- se debe asignar, de lo contrario ingresara en la 2da prevision
            IF (nvl(reg.sal_capital, 0) - nvl(v_gar_fogapy, 0)) > 0 THEN
               v_por_prevision := v_por_prevision * 2; -- Definido por Riesgo
               v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_fogapy, 0)) * v_por_prevision / 100,
                                    v_redondeo);
               v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0);                    
               v_ban_fogapy := 'S';
            END IF;
         ELSE
            IF (v_cat_prev <= 2 AND reg.dia_atraso <= 60) THEN 
               v_prevision := round(nvl(reg.oc_ttdeuda, 0) * v_por_prevision / 100, v_redondeo);
            ELSE
               v_prevision := round(nvl(reg.sal_capital, 0) * v_por_prevision / 100, v_redondeo);
            END IF;
         END IF;
      ELSIF v_cat_prev = 1 AND nvl(v_garantia, 0) <> 0 THEN
         IF nvl(v_gar_cash, 0) > 0 THEN
            IF (nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_cash, 0)) > 0 THEN
               v_prevision := round((nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_cash, 0)) * v_por_prevision / 100,
                                    v_redondeo);
            END IF;
         ELSIF nvl(v_gar_fogapy, 0) > 0 THEN
             v_ban_fogapy := 'S'; -- se debe asignar, de lo contrario ingresara en la 2da prevision
            IF (nvl(reg.oc_ttdeuda, 0) - nvl(v_gar_fogapy, 0)) > 0 THEN
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

      --- HALLAR VALOR COMPUTABLE DE LA GARANTIA
      IF v_garantia = 0 THEN
         --- Esta metodologia de cálculo no se aplicará cuando los préstamos carezcan de garantía
         --- en cuyo caso el % de prevision se aplicara sobre el saldo total de la deuda
         v_prevision     := 0;
         v_por_prevision := v_por_prevision * 2;
      END IF;
      v_pri_prevision := v_prevision;
      --- REALIZAR SEGUNDA PREVISION
      IF v_cod_entidad = 2036 THEN
         IF (v_cat_prev > 2 OR (reg.cat_pre_diferida = 2 and reg.dia_atraso < 60) OR (reg.cat_pre_diferida = 2 and reg.dia_atraso >= 60)) AND v_garantia = 0 THEN
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
         if nvl(v_ban_fogapy,'N') <> 'S' then --calcula el neto con la prevision
          IF (reg.dia_atraso > 60 OR v_cat_prev > 2) THEN
             v_neto := nvl(reg.sal_capital, 0) - nvl(v_garantia, 0) - v_prevision;
          ELSE          
             v_neto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
          END IF;
          END IF;
          IF nvl(v_cat_prev,1) <= nvl(v_cat_subjetiva,1) THEN 
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
      END IF;
      IF v_neto < 0 THEN
         v_neto := 0;
      END IF;
         IF v_garantia <> 0 THEN
            v_tot_rie_no_cubierto := nvl(reg.oc_ttdeuda, 0) - nvl(v_garantia, 0) - v_prevision;
         END IF;
      --- Calcular cantidad de dias desde la ultima clasificacion
      v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
      IF v_cat_prev = 6 AND v_garantia > 0 AND v_dias_cat > 365 THEN
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
           if v_cat_prev <= 2 and reg.dia_atraso <= 60 and v_garantia > 0 then
              v_prevision := v_pri_prevision + round(nvl(v_tot_rie_no_cubierto, 0) * v_por_prevision / 100, 0); -- se modifico con su if
           else
              v_prevision := v_prevision + round(nvl(v_neto, 0) * v_por_prevision / 100, 0);
            IF v_neto = 0 THEN
               v_cap_seg_prevision := 0;
            ELSE
               v_cap_seg_prevision := v_prevision;
            END IF;
           END IF; 
         ELSE
            v_prevision := v_prevision + round(nvl(v_neto, 0) * v_por_prevision / 100, 2);
            IF v_neto = 0 THEN
               v_cap_seg_prevision := 0;
            ELSE
               v_cap_seg_prevision := v_prevision;
            END IF;
         END IF;
        END IF;
      END IF;  
      --
      IF ((reg.dia_atraso > 60 OR v_cat_prev > 2)) then 
         if nvl(v_ban_fogapy,'N') <> 'S' then  --para fogapy no suma interes en ningun caso
         v_prevision         := v_prevision + nvl(reg.dev_no_cobrado, 0);
         v_int_seg_prevision := nvl(reg.dev_no_cobrado, 0);
         else
         v_int_seg_prevision := nvl(reg.dev_no_cobrado, 0);
         end if;
      END IF;
      --- Calcular la Primera Prevision y Segunda Prevision Capital e Interes
      --- Obtener el Capital de Primera Previsión a partir del Total Aplicado para generar la Primera Previsión

      IF v_cat_prev > 2 and reg.dia_atraso > 60 then 
         v_sal_capital := nvl(reg.sal_capital, 0);
      ELSE
         v_sal_capital := nvl(reg.oc_ttdeuda, 0);
      END IF;

      IF v_sal_capital <= 0 THEN
         v_sal_capital := 1;
      END IF;
      v_cap_pri_prevision := round(nvl(reg.sal_capital, 0) / (nvl(v_sal_capital, 0)) *
                                   v_pri_prevision, v_redondeo);
      --- Obtener el Interés de Primera Previsión a partir del Capital y Primera Previsión
      v_int_pri_prevision := round(nvl(v_pri_prevision, 0) - nvl(v_cap_pri_prevision, 0), v_redondeo);
      --- Obtener la Segunda Previsión Capital a partir del Total de Previsión y Primera Previsión
      v_seg_prevision := round(nvl(v_prevision, 0) - nvl(v_pri_prevision, 0), v_redondeo);
      IF v_neto <= 0 THEN
         v_neto := 1;
      END IF;
      --- Obtener el Capital de Segunda Previsión a partir del Neto utilizado para el Total de Previsión
      IF v_neto < reg.sal_capital AND v_garantia > 0 AND v_prevision > 0 AND
         v_cat_prev <> 6 THEN
         v_neto := v_neto + v_garantia + v_prevision;
      END IF;
      IF v_cat_prev = 1 THEN
         v_cap_seg_prevision := round((nvl(v_sal_capital, 0) / nvl(v_neto, 0)) *
                                      nvl(v_seg_prevision, 0), v_redondeo);
         --- Obtener el Interés de Segunda Previsión a Partir del Capital y Segunda Previsión
         v_int_seg_prevision := round(nvl(v_seg_prevision, 0) - nvl(v_cap_seg_prevision, 0),
                                      v_redondeo);
      END IF;
      IF v_cat_subjetiva = 2 AND reg.dia_atraso <= 60 AND nvl(v_garantia, 0) <> 0 THEN
         IF v_cod_mon_local = reg.cod_moneda THEN
            v_int_seg_prevision := round(nvl(reg.dev_no_cobrado, 0) * v_por_prevision / 100, 0);
         ELSE
            v_int_seg_prevision := round(nvl(reg.dev_no_cobrado, 0) * v_por_prevision / 100, 2);
         END IF;
         v_prevision := nvl(v_prevision, 0) + nvl(v_int_seg_prevision, 0);
      END IF;
      --- Recuperar prevision anterior si la tuviere
      v_prv_anterior  := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual);
      v_prv_ant_acum  := lf_obt_prv_ant_acum(reg.nro_cuenta, v_fec_actual);
      v_diferencia    := 0;
      v_calculo       := 0;
      v_calculo_696   := 0;
      v_calculo       := nvl(reg.dias_transcurridos, 1);
      IF v_calculo = 0 THEN
         v_calculo := 1;
      END IF;

      v_usuario      := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE', 'USU_MOV_CIERRE', V_CAN_USER, 'S_USU_MOVCIERRE');
      r_gmovi.hora   := TO_CHAR(SYSDATE, 'HH24:MI:SS');
      IF NOT v_usu_secuencia.EXISTS(v_usuario) THEN
         v_usu_secuencia(v_usuario) := 0;
         v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE', 'E');
         v_usu_mov_gen(v_usuario)   := 'N';
         v_usu_cuenta(v_usuario)    := reg.nro_cuenta;
      ELSIF (v_usu_secuencia(v_usuario) >= 995)
                                      OR (v_usu_hora(v_usuario) != r_gmovi.hora)
                                      OR (v_usu_cuenta(v_usuario) <> reg.nro_cuenta) THEN
         -- solo rotar hora si el slot anterior fue efectivamente usado
         IF nvl(v_usu_mov_gen(v_usuario), 'N') = 'S' THEN
            v_usu_secuencia(v_usuario) := 0;
            v_usu_hora(v_usuario)      := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE', 'E');
            v_usu_mov_gen(v_usuario)   := 'N';
         END IF;
      END IF;
	  
      v_usu_cuenta(v_usuario) := reg.nro_cuenta;  
      --- Inicializar datos cabecera del movimiento      
      r_gmovi.hora           := v_usu_hora(v_usuario);                
      r_gmovi.cod_usuario    := v_usuario;
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
     
      IF reg.fec_cancelacion IS NOT NULL THEN

         IF nvl(v_prv_anterior, 0) > 0 THEN
            --- Desafectar la prevision por cancelacion de prestamos
            v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
            r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
            r_gmovi.cod_tra_padre      := 724;
            r_gmovi.cod_transaccion    := 724;
            r_gmovi.concepto           := 'EXTORNO DE PREVISION';
            r_gmovi.monto              := v_prv_anterior;
            r_gmovi.est_cuenta         := reg.est_batch;
            v_usu_mov_gen(v_usuario)   := 'S';
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            
            v_tot_pri_prevision      :=  nvl(v_pri_prevision, 0) ;
            v_tot_cap_pri_prevision  :=  nvl(v_cap_pri_prevision, 0);
            v_tot_cap_seg_prevision  :=  nvl(v_cap_seg_prevision, 0);
            v_tot_int_pri_prevision  :=  nvl(v_int_pri_prevision, 0);
            v_tot_int_seg_prevision  :=  nvl(v_int_seg_prevision, 0);
            reg_pr_previsiones.extend(); 
            reg_pr_previsiones(reg_pr_previsiones.count).nro_cuenta          := reg.nro_cuenta;
            reg_pr_previsiones(reg_pr_previsiones.count).fecha               := v_fec_actual;
            reg_pr_previsiones(reg_pr_previsiones.count).monto               := nvl(v_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).sal_capital         := nvl(reg.sal_capital, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).dev_no_cobrado      := nvl(reg.dev_no_cobrado, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).porcentaje          := nvl(v_por_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_pri_prevision   := nvl(v_pri_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_gar_computables := nvl(v_garantia, 0);

            ---diferir en la cantidad de cuotas de acuerdo al parámetro o al plazo
            reg_pr_previsiones(reg_pr_previsiones.count).tot_cap_pri_prevision := nvl(v_cap_pri_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_cap_seg_prevision := nvl(v_cap_seg_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_int_pri_prevision := nvl(v_int_pri_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_int_seg_prevision := nvl(v_int_seg_prevision, 0);           
         END IF;
      ELSE
         --1) total de la previsión v_prev_total
         v_prev_total := v_prevision;
         -- 2) diferido
         IF NVL(v_calculo,0) > NVL(v_pre_pla_rrr_res4,0) THEN
            v_calculo := v_pre_pla_rrr_res4;
         END IF;
        
         if reg.cod_modalidad ='968' then --Equivalencia de Modalidad ITGF/BANKITTI          
            v_calculo_696 := trunc(to_date(v_fec_actual,'dd-mm-yyyy hh24:mi:ss') - (to_date(v_fec_inicio,'dd-mm-yyyy hh24:mi:ss') + v_18_meses));
            v_prevision := trunc(v_prevision / nvl(v_60_meses,0), v_redondeo) * v_calculo_696;
         else
           if nvl(lf_obt_pardinamico('PRE_MAD_SIN_DIFERIR', v_ge_par_dinamicos, reg.cod_modulo, reg.cod_modalidad), 'N') <> 'S' then -- La modalidad 641 no debe diferir
            v_prevision := trunc(v_prevision / v_pre_pla_rrr_res4, v_redondeo) * v_calculo;
           end if;
          end if;
         -- 3) diferencia de la diferida.
         v_diferencia    := nvl(v_prevision, 0) - nvl(v_prv_anterior, 0);
         r_gmovi.monto   := nvl(v_diferencia, 0);
          --4) diferencia de la acumulada
         v_mto_pre_total := v_prev_total - abs(v_prevision);
         v_prev_acum_ant := v_prv_anterior + v_prv_ant_acum; --#01 agregado para obtener prevision acumulada anterior
         v_dif_prev_acum := v_prev_total - v_prev_acum_ant;  --#01 encuentra diferencia entre prevision acumulada actual -anterior

         IF v_diferencia <> 0 THEN
            v_tot_pri_prevision     :=  nvl(v_pri_prevision, 0) ;
            v_tot_cap_pri_prevision := trunc(nvl(v_cap_pri_prevision, 0) / v_pre_pla_rrr_res4, 0) * v_calculo;
            v_tot_cap_seg_prevision := trunc(nvl(v_cap_seg_prevision, 0) / v_pre_pla_rrr_res4, 0) * v_calculo;
            v_tot_int_pri_prevision := trunc(nvl(v_int_pri_prevision, 0) / v_pre_pla_rrr_res4, 0) * v_calculo;
            v_tot_int_seg_prevision := trunc(nvl(v_int_seg_prevision, 0) / v_pre_pla_rrr_res4, 0) * v_calculo;
                                                   
            reg_pr_previsiones.extend();
            reg_pr_previsiones(reg_pr_previsiones.count).nro_cuenta            := reg.nro_cuenta;
            reg_pr_previsiones(reg_pr_previsiones.count).fecha                 := v_fec_actual;
            reg_pr_previsiones(reg_pr_previsiones.count).monto                 := nvl(v_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).sal_capital           := nvl(reg.sal_capital, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).dev_no_cobrado        := nvl(reg.dev_no_cobrado, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).porcentaje            := nvl(v_por_prevision, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_gar_computables   := nvl(v_garantia, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).mto_pre_total         := nvl(v_mto_pre_total, 0);
            reg_pr_previsiones(reg_pr_previsiones.count).tot_pri_prevision     :=  nvl(v_pri_prevision, 0) ;
            reg_pr_previsiones(reg_pr_previsiones.count).tot_cap_pri_prevision := v_tot_cap_pri_prevision;
            reg_pr_previsiones(reg_pr_previsiones.count).tot_cap_seg_prevision := v_tot_cap_seg_prevision;
            reg_pr_previsiones(reg_pr_previsiones.count).tot_int_pri_prevision := v_tot_int_pri_prevision;
            reg_pr_previsiones(reg_pr_previsiones.count).tot_int_seg_prevision := v_tot_int_seg_prevision;

            If v_dif_prev_acum < 0 Then  --#01 - Se ajusta para determinar desafectar previsiones cuando la prev actual es menor a la prev anterior y cuando afectar previsiones
                   --- Desafectar previsiones
                   v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                   r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
                   r_gmovi.monto              := abs(nvl(v_diferencia , 0));
                   r_gmovi.cod_tra_padre      := 724;
                   r_gmovi.cod_transaccion    := 724;
                   r_gmovi.concepto           := 'EXTORNO DE PREVISION ESPECIAL';
                   v_usu_mov_gen(v_usuario)   := 'S';
                   pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

                   --- Desafectar previsiones
                   v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                   r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
                   r_gmovi.monto              := abs(nvl(v_dif_prev_acum  , 0)); 
                   r_gmovi.cod_tra_padre      := 727;
                   r_gmovi.cod_transaccion    := 727;
                   r_gmovi.concepto           := 'EXTORNO DE PREVISION ESPECIAL 100%';
                   v_usu_mov_gen(v_usuario)   := 'S';
                   pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

               End If;
  
               If v_dif_prev_acum > 0 then --#01 - Constituye previsiones cuando prev actual es mayor a prev anterior
                     --- Constituir previsiones
                     v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                     r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
                     r_gmovi.cod_tra_padre      := 725;
                     r_gmovi.cod_transaccion    := 725;
                     r_gmovi.concepto           := 'CONSTITUCION DE PREVISION ESPECIAL';
                     v_usu_mov_gen(v_usuario)   := 'S';
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

                     v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                     r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
                     r_gmovi.monto              := abs(nvl(v_dif_prev_acum  , 0)); 
                     r_gmovi.cod_tra_padre      := 723;
                     r_gmovi.cod_transaccion    := 723;
                     r_gmovi.concepto           := 'CONSTITUCION DE PREVISION ESPECIAL 100%';
                     v_usu_mov_gen(v_usuario)   := 'S';
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               End If;
            END IF;

            If v_dif_prev_acum = 0 Then  --#01 - Si prevision acumulada no vario se verifica si varia la porcion de diferimiento EN 25-03-2021
               If v_diferencia > 0 Then --#01 - Constituye porcion de prevision diferida en cuentas de resultado EN 25-03-2021
                     v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                     r_gmovi.nro_secuencia      := v_usu_secuencia(v_usuario);
                     r_gmovi.cod_tra_padre      := 725;
                     r_gmovi.cod_transaccion    := 725;
                     r_gmovi.concepto           := 'CONSTITUCION DE PREVISION ESPECIAL';
                     v_usu_mov_gen(v_usuario)   := 'S';
                     pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
               Else
                  If v_diferencia < 0 Then --#01 - desafecta porcion de prevision diferida en cuentas de resultado
                    --- Desafectar previsiones
                   v_usu_secuencia(v_usuario) := v_usu_secuencia(v_usuario) + 1;
                   r_gmovi.nro_secuencia  	  := v_usu_secuencia(v_usuario);
                   r_gmovi.monto              := abs(nvl(v_diferencia , 0));
                   r_gmovi.cod_tra_padre      := 724;
                   r_gmovi.cod_transaccion    := 724;
                   r_gmovi.concepto           := 'EXTORNO DE PREVISION ESPECIAL';
                   v_usu_mov_gen(v_usuario)   := 'S';
                   pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
                  End If;
               End If;
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
          v_mto_prev_tab(v_mto_prev_tab.COUNT) :=LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_mto_pre_total, 0));
          v_pri_prev_tab(v_pri_prev_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_pri_prevision, 0));
          v_seg_prev_tab(v_seg_prev_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_seg_prevision, 0));
          v_gar_apli_tab(v_gar_apli_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_garantia, 0)); 
          v_rie_no_tab(v_rie_no_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_rie_no_cubierto, 0));
          v_cap_pri_tab(v_cap_pri_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_cap_pri_prevision, 0));
          v_cap_seg_tab(v_cap_seg_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_cap_seg_prevision, 0));
          v_int_pri_tab(v_int_pri_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_int_pri_prevision,0)); 
          v_int_seg_tab(v_int_seg_tab.COUNT) := LF_CON_MON_A_MONEDA(reg.cod_moneda, v_cod_mon_local, nvl(v_tot_int_seg_prevision,0));
          v_cat_prev_tab(v_cat_prev_tab.COUNT) := v_cat_cli_prevision;
      END IF;
   END LOOP;
   
   FORALL i IN 1.. reg_pr_previsiones.COUNT
       insert into pr_previsiones
          (nro_cuenta,
           fecha,
           monto,
           sal_capital,
           dev_no_cobrado,
           porcentaje,
           tot_pri_prevision,
           tot_gar_computables,
           mto_pre_total,
       tot_cap_pri_prevision,
           tot_cap_seg_prevision,
           tot_int_pri_prevision,
           tot_int_seg_prevision)
       values
           (reg_pr_previsiones(i).nro_cuenta,
            reg_pr_previsiones(i).fecha,
            reg_pr_previsiones(i).monto,
            reg_pr_previsiones(i).sal_capital,
            reg_pr_previsiones(i).dev_no_cobrado,
            reg_pr_previsiones(i).porcentaje,
            reg_pr_previsiones(i).tot_pri_prevision,
            reg_pr_previsiones(i).tot_gar_computables,
            reg_pr_previsiones(i).mto_pre_total,
            reg_pr_previsiones(i).tot_cap_pri_prevision,
            reg_pr_previsiones(i).tot_cap_seg_prevision,
            reg_pr_previsiones(i).tot_int_pri_prevision,
            reg_pr_previsiones(i).tot_int_seg_prevision);
   
  BEGIN
      -- Usar FORALL para el UPDATE en GE_CLA_OPERACIONES
      FORALL i IN 1..v_cla_fila_tab.COUNT SAVE EXCEPTIONS
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
          WHERE rowid = v_cla_fila_tab(i);
   EXCEPTION
      WHEN ex_bulk_errors THEN
         -- Iterar sobre todos los errores capturados durante el FORALL
         FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
            v_indice  := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
            v_codigo  := SQL%BULK_EXCEPTIONS(j).ERROR_CODE;
            v_mensaje := SQLERRM(-v_codigo);            
            v_cuenta_error := v_nro_cta_tab(v_indice); 
            PAG_CIE.PR_AT_INS_LOG (
               11, 
               344, 
               'PRP_GEN_PRE_EXCEPCION',
               'Error actualizando previsiones. Cuenta: ' || v_cuenta_error || 
               ' | Codigo: ORA-' || v_codigo || 
               ' | Detalle: ' || v_mensaje,4, 
               'SECUENCIAL', 
               SYSDATE
            );
         END LOOP;
   END;
END;

