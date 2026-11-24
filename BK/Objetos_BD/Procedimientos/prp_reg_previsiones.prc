CREATE OR REPLACE PROCEDURE IT.prp_reg_previsiones IS

/* Obtener garantia computable.  */
FUNCTION LF_OBT_GAR_COM
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_LOCAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TOT_DEUDA IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_TOT_CASH OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE -- me indica si tiene un importe correspondiente a cash collateral para aplicar 100%.
 )
 RETURN NUMBER;
/* Obtener prevision anterior. */
FUNCTION LF_OBT_PRV_ANT
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE
 ,p_ind_pri_sem_cat6 out pr_previsiones.ind_pri_sem_cat6%type
 )
 RETURN NUMBER;
/* Obtener prevision de año anterior */
FUNCTION LF_OBT_PRV_PER_ANT
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE
 )
 RETURN NUMBER;
/* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
FUNCTION LF_OBT_CAT_PREVISION (P_COD_PERSONA IN GE_CLA_OPERACIONES.COD_PERSONA%TYPE)
 RETURN NUMBER;
/* Insertar registros en la tabla de previsiones de prestamos. */
PROCEDURE LP_INS_PREVISION
 (RP_PPREV IN PR_PREVISIONES%ROWTYPE
 );
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
   v_redondeo             NUMBER(2) := 2;
   v_fec_actual           ge_calendarios.fec_actual%type;
   v_cod_mon_local        ba_monedas.cod_moneda%type;
   v_riesgo1a             pr_parametros.por_riesgo_1a%type;
   v_riesgo1b             pr_parametros.por_riesgo_1b%type;
   v_riesgo2              pr_parametros.por_riesgo_2%type;
   v_riesgo3              pr_parametros.por_riesgo_3%type;
   v_riesgo4              pr_parametros.por_riesgo_4%type;
   v_riesgo5              pr_parametros.por_riesgo_5%type;
   v_riesgo6              pr_parametros.por_riesgo_6%type;
   v_garantia             pr_cta_garantias.mto_apl_computable%type;
   v_prevision            pr_previsiones.monto%type;
   v_prv_anterior         pr_previsiones.monto%type;
   v_diferencia           pr_previsiones.monto%type;
   v_prv_per_anterior     pr_previsiones.monto%type;
   v_dif_prevision        pr_previsiones.monto%type;
   r_pprev                pr_previsiones%rowtype;
   r_gmovi                ge_movimientos%rowtype;
   v_nro_secuencia        ge_movimientos.nro_secuencia%type;
   v_hora                 ge_movimientos.hora%type;
   v_neto                 GE_CLA_OPERACIONES.tot_deu_real%type;
   v_cat_prev             ge_clientes.cat_automatica%type;
   v_tip_implementacion   ge_par_generales.tip_implementacion%type;
   v_cau_insufondos       ge_causales.cod_causa%type;
   v_tot_cash             pr_cta_garantias.mto_apl_computable%type;   -- total de garantias tipo cash collateral
   v_tot_apl              pr_cta_garantias.mto_con_computable%type; -- saldo de riesgo a previsionar
   v_por_prev_clie        number(5, 2);
   v_pri_prevision        number(18,2);
   v_dias_cat             number(10);
   v_por_prevision        number(18,2);
   v_por_prev_cheq        number(18,2);
   v_cat_cli_prevision    ge_cla_operaciones.cat_automatica%type;
   v_seg_prevision        pr_previsiones.monto%TYPE;
   v_cap_pri_prevision    pr_previsiones.monto%TYPE;
   v_int_pri_prevision    pr_previsiones.monto%TYPE;
   v_cap_seg_prevision    pr_previsiones.monto%TYPE;
   v_int_seg_prevision    pr_previsiones.monto%TYPE;
   v_sal_capital          pr_previsiones.monto%TYPE;
   v_ajuste               pr_previsiones.monto%TYPE;
   -- Variables utilizadas para actualizar la tabla ge_cla_operaciones.
   v_pre_mon_local          pr_previsiones.monto%TYPE := 0;
   v_pri_pre_mon_local      pr_previsiones.monto%TYPE := 0;
   v_cap_pri_pre_mon_local  pr_previsiones.monto%TYPE := 0;
   v_cap_seg_pre_mon_local  pr_previsiones.monto%TYPE := 0;
   v_int_pri_pre_mon_local  pr_previsiones.monto%TYPE := 0;
   v_int_seg_prev_mon_local pr_previsiones.monto%TYPE := 0;
   v_sal_neto pr_previsiones.monto%TYPE := 0;
   v_por_previsionado pr_previsiones.porcentaje%type;
   v_por_pri_semestre pr_previsiones.porcentaje%type;
   v_por_seg_semestre pr_previsiones.porcentaje%type;
   v_por_calculado pr_previsiones.porcentaje%type;
   v_ind_pri_sem_cat6 pr_previsiones.ind_pri_sem_cat6%type;
   v_ind_pri_sem_cat6_ant pr_previsiones.ind_pri_sem_cat6%type;
   v_val_parametro ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('NRO_CTA_PREVISION');--CTA/S A EXCLUIR EN CASO DE ERROR EN EL CIERRE --DYDMR-12051
   v_cod_tra_constitucion  ge_transacciones.cod_transaccion%type;
   v_can_mes_diferimiento  pr_re4_dif_previsiones.can_mes_diferimiento%type;
   v_cat_rie_1a                   ge_cla_operaciones.cat_automatica%type;
   v_fec_anterior         ge_calendarios.fec_anterior%type;
   --- Cursor de prestamos a calcular
   cursor c_prestamos is
   select dat_cli.cod_persona,
          dat_cta.nro_cuenta,
          dat_cta.cod_moneda,
          dat_cta.cat_renovaciones cat_riesgo,
          dat_cta.cat_renovaciones cat_automatica,
          round((nvl(dat_his.tot_deu_real,0) - nvl(dat_his.dev_no_cobrado,0))
           / decode(dat_cta.cod_moneda, 'GS', 1,
           fug_obt_cotizacion(dat_cta.cod_moneda,v_fec_actual)),v_redondeo) sal_capital,
          dat_cta.cod_modulo,
          dat_cta.cod_modalidad,
          dat_cta.cod_oficina,
          dat_cta.fec_inicio,
          dat_cta.fec_cancelacion,
          round(nvl(dat_his.dev_no_cobrado,0)/
          decode(dat_cta.cod_moneda, 'GS', 1,
          fug_obt_cotizacion(dat_cta.cod_moneda,v_fec_actual)),v_redondeo) dev_no_cobrado,
          dat_cli.cod_gru_economico,
          dat_cta.estado estado,
          dat_cta.est_batch,
          dat_cta.cod_causa,
          dat_cta.dia_atraso,
          dat_cta.cat_renovaciones,
          dat_cta.cat_renovaciones cat_ren_anterior,
          dat_his.lib_prevision,
          round(nvl(dat_his.tot_deu_real,0)/
          decode(dat_cta.cod_moneda, 'GS', 1,
          fug_obt_cotizacion(dat_cta.cod_moneda,v_fec_actual)),v_redondeo) OC_TTDEUDA,
          dat_cli.fec_ult_clasif
     from ge_clientes dat_cli,
          ge_cta_clientes rel_cli,
          pr_cta_prestamos dat_cta,
          ge_cla_operaciones_his dat_his,
          ge_par_dinamicos par
    where dat_cta.nro_cuenta = rel_cli.nro_cuenta
      and dat_cta.nro_cuenta =  dat_his.nro_cuenta
      and dat_cta.estado not in ('I','N')
      and rel_cli.relacion = 'P'
      and rel_cli.cod_persona = dat_cli.cod_persona
      and par.parametro = 'COD_MAD_RESOLUCION04'
      and par.val_parametro = 'S'
      and par.cod_modulo = dat_cta.cod_modulo
      and par.cod_modalidad = dat_cta.cod_modalidad
      and nvl(par.cod_sub_modalidad,nvl(dat_cta.cod_sub_modalidad,-1)) = nvl(dat_cta.cod_sub_modalidad,-1)
      and dat_cta.nro_cuenta = dat_his.nro_cuenta
      and dat_his.fecha =  dat_cta.fec_inicio;

/* Obtener garantia computable. */
FUNCTION LF_OBT_GAR_COM
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_COD_MON_LOCAL IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_TOT_DEUDA IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
 ,P_TOT_CASH OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE -- me indica si tiene un importe correspondiente a cash collateral para aplicar 100%.
 )
 RETURN NUMBER
 IS
   v_gar_compu  pr_cta_garantias.mto_apl_computable%type := 0;
   v_gar_cash   pr_cta_garantias.mto_con_computable%type := 0;
   v_tot_gara   pr_cta_garantias.mto_apl_computable%type := 0;
   v_cot_aux ge_cotizaciones.val_conversion%type;
   CURSOR c_garantias IS
   SELECT g.mto_apl_computable, t.cod_garantia
     FROM pr_cta_garantias g, pr_gar_tipos t
    WHERE g.nro_cuenta = p_nro_cuenta
      and g.cod_garantia = t.cod_garantia
      and t.computable = 'S'
      AND nvl(g.mto_apl_computable,0) > 0;
BEGIN
   v_tot_gara := 0;
   FOR reg IN c_garantias LOOP
      v_cot_aux := null;
      v_gar_compu := nvl(reg.mto_apl_computable,0);
      --- totalizar garantias computables en moneda de la cuenta ---------
      v_tot_gara := NVL(v_tot_gara,0) + NVL(v_gar_compu,0);
      if reg.cod_garantia in (5,19,21) then
        v_gar_cash := v_gar_cash + nvl(v_gar_compu,0);
      end if;
      P_TOT_CASH := v_gar_cash;
   END LOOP;
   RETURN v_tot_gara;
END;
/* Obtener prevision anterior. */
FUNCTION LF_OBT_PRV_ANT
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE
 ,p_ind_pri_sem_cat6   OUT pr_previsiones.ind_pri_sem_cat6%TYPE
 )
 RETURN NUMBER
 IS
v_monto pr_previsiones.monto%type;
BEGIN
   select sum(nvl(monto,0)), ind_pri_sem_cat6
     into v_monto,p_ind_pri_sem_cat6
     from pr_previsiones
    where nro_cuenta = p_nro_cuenta
      and fecha = p_fec_actual
     group by ind_pri_sem_cat6 ;
   return v_monto;
exception
  when no_data_found then
    return 0;
END;

/* Obtener prevision año anterior */
FUNCTION LF_OBT_PRV_PER_ANT
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FEC_ACTUAL IN DATE
 )
 RETURN NUMBER
 IS
v_monto pr_previsiones.monto%type;
BEGIN
    select nvl(sum(monto),0)
     into v_monto
     from pr_previsiones
    where nro_cuenta = p_nro_cuenta
      and fecha = (select max(fecha)
                     from pr_previsiones
                    where nro_cuenta = p_nro_cuenta
                      and fecha <= round(p_fec_actual,'year'))
      and not exists (select 1
                        from pr_previsiones
                       where nro_cuenta = p_nro_cuenta
                         and fecha >= round(p_fec_actual,'year')
                         and monto = 0);
      return v_monto;
EXCEPTION
   when others then
      v_monto := 0;
      return v_monto;
END;

function lf_obt_cat_individual(p_cod_persona ge_cla_operaciones_his.cod_persona%type,
                               p_fecha       ge_cla_operaciones_his.fecha%type) return number is

 v_categoria   ge_cla_operaciones.cat_automatica%type;

begin
   --Verifico las operaciones que posee el cliente.
   --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04
   SELECT nvl(MAX(c.cat_automatica),1)
     INTO v_categoria
     FROM ge_cla_operaciones_his c
    WHERE c.cod_persona = P_COD_PERSONA
      and c.fecha = p_fecha
      and not exists (select 1
                        from ge_par_dinamicos g
                       where g.parametro = 'COD_MAD_RESOLUCION04'
                         and g.val_parametro = 'S'
                         and g.cod_modulo = c.cod_modulo
                         and g.cod_modalidad = c.cod_modalidad);
      RETURN v_categoria;
EXCEPTION
   WHEN OTHERS THEN
      v_categoria := 1;
      RETURN v_categoria;
end;

/* Obtener la categoría de previsión de clientes para categoría 1(Uno)*/
FUNCTION LF_OBT_CAT_PREVISION(P_COD_PERSONA IN GE_CLA_OPERACIONES.COD_PERSONA%TYPE)
RETURN NUMBER
AS
v_categoria   ge_cla_operaciones.cat_automatica%type;
BEGIN
   --Verifico las operaciones que posee el cliente.
   SELECT nvl(MAX(a.cat_automatica),1)
     INTO v_categoria
     FROM ge_cla_operaciones a, ge_cuentas c, ge_par_dinamicos g
    WHERE a.cod_persona = P_COD_PERSONA
      and a.nro_cuenta = c.nro_cuenta
      and a.cod_modulo = c.cod_modulo
      and a.cod_modalidad = c.cod_modalidad
      and g.parametro = 'COD_MAD_RESOLUCION04'
      and g.val_parametro = 'S'
      and g.cod_modulo = c.cod_modulo
      and g.cod_modalidad = c.cod_modalidad
      and nvl(g.cod_sub_modalidad,nvl(c.cod_sub_modalidad,-1)) = nvl(c.cod_sub_modalidad,-1);

   RETURN v_categoria;
EXCEPTION
   WHEN OTHERS THEN
      v_categoria := 1;
      RETURN v_categoria;
END;
/* Obtener la categoría de renovación */
FUNCTION LF_OBT_CAT_COVID(p_nro_cuenta in ge_cla_operaciones.nro_cuenta%type)
RETURN NUMBER
AS
v_cat_renovaciones   pr_cta_pre_can_res4.cat_ren_cta_nueva%type;

BEGIN
  --- Resolución 4 - Nueva Cta debe heredar en Categoria de renovaciones
  --- la categoria riesgo del cliente y en caso de que cat riesgo sea 1
  -- se asigna a la cuenta sub cat individual

   BEGIN
     SELECT r.cat_ren_cta_nueva
       INTO v_cat_renovaciones
       FROM pr_cta_pre_can_res4 r
      WHERE r.nro_cta_nueva = p_nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         BEGIN
           SELECT r.cat_ren_cta_nueva
             INTO v_cat_renovaciones
             FROM pr_cta_pre_ref_res4 r
            WHERE r.nro_cta_nueva = p_nro_cuenta;
         EXCEPTION
           WHEN NO_DATA_FOUND THEN
               BEGIN
                 SELECT p.cat_renovaciones
                   INTO v_cat_renovaciones
                   FROM pr_cta_prestamos p
                  WHERE p.nro_cuenta = p_nro_cuenta;
               EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                   v_cat_renovaciones := 1;
               END;
         END;
    END;

   RETURN v_cat_renovaciones;
EXCEPTION
   WHEN OTHERS THEN
      v_cat_renovaciones := 1;
      RETURN v_cat_renovaciones;
END;
/* Insertar registros en la tabla de previsiones de prestamos. */
/* Insertar registros en la tabla de previsiones de prestamos. */
PROCEDURE LP_INS_PREVISION
 (RP_PPREV IN PR_PREVISIONES%ROWTYPE
 )
 IS
BEGIN
  update pr_previsiones p
     set monto = rp_pprev.monto,
         sal_capital= rp_pprev.sal_capital,
         dev_no_cobrado =  rp_pprev.dev_no_cobrado,
         porcentaje     = rp_pprev.porcentaje,
         tot_gar_computables = rp_pprev.tot_gar_computables,
         tot_pri_prevision = rp_pprev.tot_pri_prevision,
         tot_cap_pri_prevision = rp_pprev.tot_cap_pri_prevision,
         tot_cap_seg_prevision = rp_pprev.tot_cap_seg_prevision,
         tot_int_pri_prevision = rp_pprev.tot_int_pri_prevision,
         tot_int_seg_prevision = rp_pprev.tot_int_seg_prevision,
         mto_pre_anterior = RP_PPREV.Mto_pre_anterior,
         por_pre_anterior = RP_PPREV.Por_pre_Anterior,
         por_calculado = RP_PPREV.Por_Calculado,
         ind_pri_sem_cat6 = RP_PPREV.ind_pri_sem_cat6
   where p.nro_cuenta =  rp_pprev.nro_cuenta
     and p.fecha = rp_pprev.fecha;


  IF SQL%NOTFOUND THEN

   INSERT INTO pr_previsiones
         (fecha, nro_cuenta, monto, sal_capital, dev_no_cobrado, porcentaje, tot_gar_computables,
          tot_pri_prevision, tot_cap_pri_prevision, tot_cap_seg_prevision, tot_int_pri_prevision,
          tot_int_seg_prevision, mto_pre_anterior, por_pre_anterior, por_calculado, ind_pri_sem_cat6)
      VALUES
         (rp_pprev.fecha, rp_pprev.nro_cuenta, rp_pprev.monto, rp_pprev.sal_capital,
          rp_pprev.dev_no_cobrado, rp_pprev.porcentaje, rp_pprev.tot_gar_computables,
          rp_pprev.tot_pri_prevision, rp_pprev.tot_cap_pri_prevision, rp_pprev.tot_cap_seg_prevision,
          rp_pprev.tot_int_pri_prevision, rp_pprev.tot_int_seg_prevision,
          RP_PPREV.Mto_pre_anterior, RP_PPREV.Por_pre_Anterior, RP_PPREV.Por_Calculado, RP_PPREV.ind_pri_sem_cat6);
  end if;

exception
   when others then

      --raise_application_error(-20000,'Ins.Prev. Cta:'||rp_pprev.nro_cuenta||'- '||sqlerrm);
      raise_application_error(-20001, 'Error al Insertar Prevision.'||chr(13)||
                                      'Cargar la Cta Nro: '||rp_pprev.nro_cuenta||' en el par_dinamico "NUMERO DE CTA DE PREVISION A EXCLUIR"'||
                                       chr(13)||sqlerrm);

END;

procedure lp_act_prev_diferidos is


-- Proposito: Generar Movimientos por diferimiento de Previsiones de Productos relacionados a RESOLUCION-4
-- Proceso diseñado para ejecutarse mensualmente - solo fin de mes

v_fec_actual           ge_calendarios.fec_actual%type;
v_fec_anterior         ge_calendarios.fec_anterior%type;
v_ult_dia_mes_habil    ge_calendarios.ult_dia_mes_habil%type;
r_gmovi                ge_movimientos%rowtype;
v_nro_secuencia        ge_movimientos.nro_secuencia%type;
v_hora                 ge_movimientos.hora%type;
v_redondeo             number(2) := 2;
v_redondeo_ori         number(2);
v_redondeo_nva         number(2);
v_mto_pre_dif_actual   pr_re4_dif_previsiones.mto_pre_diferido%type;
v_mto_can_pre_diferido pr_re4_dif_previsiones.mto_pre_diferido%type;
v_cod_mon_local        ba_monedas.cod_moneda%type;
v_cotizacion           ge_cotizaciones.val_conversion%type;
v_cot_mon_local        ge_cotizaciones.val_conversion%type := 1;
rg_prdif               pr_re4_dif_previsiones%rowtype;
v_red_mon_local        number(2) := 0;
v_mes_a_diferir        pr_re4_dif_previsiones.can_mes_diferido%type;
v_can_mes_diferir      pr_re4_dif_previsiones.can_mes_diferido%type;
v_riesgo1a             pr_parametros.por_riesgo_1a%type;
v_riesgo1b             pr_parametros.por_riesgo_1b%type;
v_riesgo2              pr_parametros.por_riesgo_2%type;
v_riesgo3              pr_parametros.por_riesgo_3%type;
v_riesgo4              pr_parametros.por_riesgo_4%type;
v_riesgo5              pr_parametros.por_riesgo_5%type;
v_riesgo6              pr_parametros.por_riesgo_6%type;

cursor c_datos_nuevos is

select dat_cli.cod_persona            cod_cliente,
       dat_cli.cat_riesgo             cat_rie_cliente,
       dat_cli.fecha                  fec_dat_cliente,
       dat_cta.nro_cuenta              nro_cta_Nueva,
       dat_cta.fec_inicio              fec_ini_cta_hijo,
       dat_cta.cod_moneda              cod_mon_cta_hijo,
       dat_his.tot_deu_real            tot_deu_cta_hijo,
       (dat_his.tot_deu_real - dat_his.dev_no_cobrado) sal_capital,
       dat_his.dev_no_cobrado          dev_no_cobrado,
       round(nvl(mov.monto,0) * decode(dat_cta.cod_moneda, 'GS', 1,
           fug_obt_cotizacion(dat_cta.cod_moneda,v_fec_actual)),0) mto_prevision,
       mov.monto                        mto_pre_mon_original,
       prev.porcentaje                  por_pre_cta_hijo,
       dat_cta.cat_renovaciones         cat_ren_cta_hijo
  from pr_cta_prestamos dat_cta,
       ge_par_dinamicos gpar,
       ge_cta_clientes  gcta,
       ge_clientes_his  dat_cli,
       ge_cla_operaciones_his dat_his,
       ge_movimientos   mov,
       pr_previsiones   prev
 where dat_cta.nro_cuenta = gcta.nro_cuenta
   and gcta.cod_persona = dat_cli.cod_persona
   and gcta.relacion = 'P'
   and gpar.parametro = 'COD_MAD_RESOLUCION04'
   and dat_cta.cod_modulo = gpar.cod_modulo
   and dat_cta.cod_modalidad = gpar.cod_modalidad
   and dat_cta.estado not in ('N', 'I')
   and dat_cta.nro_cuenta = dat_his.nro_cuenta
   and dat_his.fecha = dat_cta.fec_inicio
   and dat_cli.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (dat_cta.fec_inicio,31,1)
   and dat_cta.nro_cuenta = mov.nro_cuenta
   and mov.cod_transaccion = 9730
   and dat_cta.nro_cuenta = prev.nro_cuenta
   and prev.fecha = mov.fecha
   and mov.fecha = v_fec_actual
   and not exists (select 1
                     from pr_re4_dif_previsiones i
                    where i.nro_cuenta = dat_cta.nro_cuenta);


cursor c_actualizacion is
select resol4.cod_persona,
       resol4.nro_cuenta nro_cta_original,
       resol4.nro_cta_nueva nro_cta_nueva,
       resol4.fec_ini_cta_nueva,
       i.cod_mon_cta_hijo,
       i.cod_mon_cta_madre
 from pr_cta_pre_can_res4  resol4, pr_re4_dif_previsiones i
where nvl(resol4.reversado,'N') = 'N'
  and nvl(resol4.nro_cta_nueva,'X') = i.nro_cuenta
union all
select resol4.cod_persona,
       resol4.nro_cuenta nro_cta_original,
       resol4.nro_cta_nueva nro_cta_nueva,
       resol4.fec_ini_cta_nueva,
       i.cod_mon_cta_hijo,
       i.cod_mon_cta_madre
 from pr_cta_pre_ref_res4  resol4, pr_re4_dif_previsiones i
where nvl(resol4.reversado,'N') = 'N'
  and nvl(resol4.nro_cta_nueva,'X') = i.nro_cuenta
union all
select i.cod_persona,
       null nro_cta_original,
       i.nro_cuenta nro_cta_nueva,
       i.fec_ini_cta_nueva fec_ini_cta_nueva,
       i.cod_mon_cta_hijo,
       i.cod_mon_cta_madre
 from pr_re4_dif_previsiones i
 where not exists (select 1
                     from pr_cta_pre_can_res4 c
                    where c.nro_cta_nueva = i.nro_cuenta
                    union
                    select 1
                     from pr_cta_pre_ref_res4 c
                    where c.nro_cta_nueva = i.nro_cuenta);

----CURSOR PARA DIFERIMIENTO MENSUAL
Cursor c_dif_previsiones is
       select r.cod_persona,
              r.nro_cuenta,
              r.fec_actualizacion,
              r.mto_prevision,
              round((r.mto_prevision / r.can_mes_diferimiento)) mto_pre_diferido,
              r.mto_pre_dif_acumulado,
              r.can_mes_diferimiento,
              r.can_mes_diferido,
              p.cod_modulo,
              p.cod_modalidad,
              p.cod_oficina,
              p.cod_moneda,
              p.estado,
              p.fec_inicio
         from pr_re4_dif_previsiones r, pr_cta_prestamos p
        where r.nro_cuenta = p.nro_cuenta
          and p.estado not in ('I', 'N')
          and r.can_mes_diferimiento > nvl(r.can_mes_diferido,0)
          and nvl(r.mto_pre_mon_original,0) > 0;

/* Obtener la categoría de renovación */
FUNCTION LF_OBT_CAT_COVID(p_cod_persona in ge_cla_operaciones.cod_persona%type,
                          p_nro_cuenta  in ge_cla_operaciones.nro_cuenta%type)
RETURN NUMBER
AS
v_cat_renovaciones   pr_cta_pre_can_res4.cat_ren_cta_nueva%type;
v_fec_inicio         pr_cta_prestamos.fec_inicio%type;
v_fec_anterior       ge_calendarios.fec_anterior%type;
v_fec_actual         ge_calendarios.fec_actual%type;

BEGIN

   v_fec_actual         := pag_cal.fu_obt_fec_actual(6);
  --- Resolución 4 - Nueva Cta debe heredar en Categoria de renovaciones
  --- la categoria automatica de la cuenta origen
  begin
    select r.fec_inicio
      into v_fec_inicio
      from pr_cta_prestamos r
      where r.nro_cuenta = p_nro_cuenta;
  exception
    when others then
      v_fec_inicio := v_fec_actual;
  end;

   BEGIN
     SELECT r.cat_ren_cta_nueva
       INTO v_cat_renovaciones
       FROM pr_cta_pre_can_res4 r
      WHERE r.nro_cta_nueva = p_nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         BEGIN
           SELECT r.cat_ren_cta_nueva
             INTO v_cat_renovaciones
             FROM pr_cta_pre_ref_res4 r
            WHERE r.nro_cta_nueva = p_nro_cuenta;
         EXCEPTION
           WHEN NO_DATA_FOUND THEN
               BEGIN
                 SELECT p.cat_renovaciones
                   INTO v_cat_renovaciones
                   FROM pr_cta_prestamos p
                  WHERE p.nro_cuenta = p_nro_cuenta
                    AND p.cat_renovaciones >= 2;
               EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                   BEGIN
                     --Verifico las operaciones que posee el cliente.
                     --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04
                     v_fec_anterior := pag_cal.FU_OBT_FEC_ANT_HAB (v_fec_inicio,31,1);
                     SELECT nvl(MAX(c.cat_automatica),1)
                       INTO v_cat_renovaciones
                       FROM ge_cla_operaciones_his c
                      WHERE c.cod_persona = P_COD_PERSONA
                        and c.fecha = v_fec_anterior
                        and not exists (select 1
                                          from ge_par_dinamicos g
                                         where g.parametro = 'COD_MAD_RESOLUCION04'
                                           and g.val_parametro = 'S'
                                           and g.cod_modulo = c.cod_modulo
                                           and g.cod_modalidad = c.cod_modalidad);
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                          BEGIN
                             SELECT p.cat_renovaciones
                               INTO v_cat_renovaciones
                               FROM pr_cta_prestamos p
                              WHERE p.nro_cuenta = p_nro_cuenta;
                           EXCEPTION
                             WHEN NO_DATA_FOUND THEN
                               v_cat_renovaciones := 1;
                          END;
                     END;
               END;
         END;
    END;

   RETURN v_cat_renovaciones;
EXCEPTION
   WHEN OTHERS THEN
      v_cat_renovaciones := 1;
      RETURN v_cat_renovaciones;
END;

begin
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

   pag_cal.pr_obt_dat_calendar(6);
   v_fec_actual        := pag_cal.G_FEC_ACTUAL;
   v_fec_anterior      := pag_cal.FU_OBT_FEC_ANTERIOR(6);
   v_ult_dia_mes_habil := pag_cal.G_ULT_DIA_MES_HABIL;
   v_hora              := to_char(sysdate,'HH24:MI:SS');
   v_hora              := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   v_nro_secuencia     := 0;
   v_cod_mon_local     := pag_gen.fu_obt_mon_local;
   v_redondeo          := 0;

 --INSERCION DE PRODUCTOS COVID
 for c_ins in c_datos_nuevos loop
   if c_ins.cod_mon_cta_hijo = v_cod_mon_local then
      v_cotizacion := v_cot_mon_local;
   else
      v_cotizacion := pag_gen.fu_obt_cotizacion(c_ins.cod_mon_cta_hijo, c_ins.fec_ini_cta_hijo);
   end if;


   begin
    select g.val_parametro
      into v_can_mes_diferimiento
      from pr_cta_prestamos  cta_nueva, ge_par_dinamicos g
     where cta_nueva.nro_cuenta = c_ins.nro_cta_nueva
       and g.parametro = 'CAN_MES_DIF_PRE_RESOLUCION04'
       and cta_nueva.cod_modulo = g.cod_modulo
       and cta_nueva.cod_modalidad = g.cod_modalidad;
    exception
      when no_data_found then
        null;
     end;


   begin

      insert into pr_re4_dif_previsiones r
              (cod_persona, nro_cuenta, fec_ini_cta_nueva,
               mto_prevision, mto_pre_mon_original, can_mes_diferimiento,
               mto_deu_real, mto_capital, mto_dev_no_cobrado,
               cotizacion,  cat_rie_cliente, fec_dat_rie_cliente,
               COD_MON_CTA_HIJO, POR_PRE_CTA_HIJO, cat_ren_cta_hijo)
        values(c_ins.cod_cliente, c_ins.nro_cta_nueva, c_ins.fec_ini_cta_hijo,
               c_ins.mto_prevision, c_ins.mto_pre_mon_original, v_can_mes_diferimiento,
               c_ins.tot_deu_cta_hijo, c_ins.sal_capital, c_ins.dev_no_cobrado,
               v_cotizacion, c_ins.cat_rie_cliente, c_ins.fec_dat_cliente,
               c_ins.cod_mon_cta_hijo, c_ins.por_pre_cta_hijo, c_ins.cat_ren_cta_hijo);
    exception
      when others then
        raise_application_error(-20005, 'Error al insertar Previsiones Diferidas-'||sqlerrm);
     end;

 end loop;




  for c_act in c_actualizacion loop

   rg_prdif := null;
   rg_prdif.cod_mon_cta_hijo := c_act.cod_mon_cta_hijo;
   rg_prdif.cod_mon_cta_madre := c_act.cod_mon_cta_madre;

   rg_prdif.cat_ren_cta_hijo := lf_obt_cat_covid(c_act.cod_persona, c_act.nro_cta_nueva);

     begin
      select cta_nva.tot_deu_real
        into rg_prdif.mto_capital
        from ge_cla_operaciones_his cta_nva
       where cta_nva.nro_cuenta = c_act.nro_cta_nueva
         and cta_nva.fecha = c_act.fec_ini_cta_nueva;
      exception
        when no_data_found then
              begin
                select cta_nva.tot_deu_real
                  into rg_prdif.mto_capital
                  from ge_cla_operaciones cta_nva
                 where cta_nva.nro_cuenta = c_act.nro_cta_nueva;
              exception
                when no_data_found then
                  null;
              end;
       end;


      begin
      select cta_ori.dia_atraso,
             cta_ori.cat_automatica,
             cta_ori.cat_renovaciones,
             cta_ori.cod_moneda,
             cta_ori.tot_deu_real
        into rg_prdif.dia_atraso,
             rg_prdif.cat_aut_cta_madre,
             rg_prdif.cat_ren_cta_madre,
             rg_prdif.cod_mon_cta_madre,
             rg_prdif.mto_tot_deu_cta_madre
        from ge_cla_operaciones_his cta_ori
       where cta_ori.nro_cuenta = c_act.nro_cta_original
         and cta_ori.fecha = pag_cal.FU_OBT_FEC_ANT_HAB (c_act.fec_ini_cta_nueva,31,1);
      exception
        when no_data_found then
              begin
                select cta_nva.tot_deu_real
                  into rg_prdif.mto_capital
                  from ge_cla_operaciones cta_nva
                 where cta_nva.nro_cuenta = c_act.nro_cta_nueva;
              exception
                when no_data_found then
                  null;
              end;
       end;



  begin
    select prv_cta_ori.porcentaje,
           prv_cta_ori.monto,
           prv_cta_ori.fecha ,
           prv_cta_ori.porcentaje
      into rg_prdif.por_pre_cta_madre,
           rg_prdif.Mto_Prev_Cta_Madre,
           rg_prdif.Fec_Pre_Cta_Madre,
           rg_prdif.por_pre_cta_hijo
      from pr_previsiones prv_cta_ori
     where prv_cta_ori.nro_cuenta = c_act.nro_cta_original
       and prv_cta_ori.fecha in (select max(x.fecha)
                                   from pr_previsiones x
                                  where x.nro_cuenta = prv_cta_ori.nro_cuenta
                                    and x.fecha < c_act.fec_ini_cta_nueva);
    exception
      when no_data_found then
        begin
          select prv_cta_ori.porcentaje,
                 prv_cta_ori.monto,
                 prv_cta_ori.fecha
            into rg_prdif.por_pre_cta_madre,
                 rg_prdif.Mto_Prev_Cta_Madre,
                 rg_prdif.Fec_Pre_Cta_Madre
            from ov_previsiones prv_cta_ori
           where prv_cta_ori.nro_cuenta = c_act.nro_cta_original
             and prv_cta_ori.fecha in (select max(x.fecha)
                                         from ov_previsiones x
                                        where x.nro_cuenta = prv_cta_ori.nro_cuenta
                                          and x.fecha < c_act.fec_ini_cta_nueva);
          exception
            when no_data_found then
              null;
           end;
     end;

    begin
      select prv_cta_ori_ini.monto ,
             prv_cta_ori_ini.fecha
        into rg_prdif.Mto_Pre_Cta_Mad_Fec_Ini,
             rg_prdif.Fec_Pre_Ini_Cta_Ori
        from pr_previsiones  prv_cta_ori_ini
       where prv_cta_ori_ini.nro_cuenta = c_act.nro_cta_original
         and prv_cta_ori_ini.fecha = c_act.fec_ini_cta_nueva;
    exception
      when no_data_found then
        begin
          select prv_cta_ori_ini.monto ,
                 prv_cta_ori_ini.fecha
            into rg_prdif.Mto_Pre_Cta_Mad_Fec_Ini,
                 rg_prdif.Fec_Pre_Ini_Cta_Ori
            from ov_previsiones  prv_cta_ori_ini
           where prv_cta_ori_ini.nro_cuenta = c_act.nro_cta_original
             and prv_cta_ori_ini.fecha = c_act.fec_ini_cta_nueva;
        exception
          when no_data_found then
            null;
         end;
     end;

     begin
       select prv_cta_nva.porcentaje,
              prv_cta_nva.monto,
              prv_cta_nva.fecha
         into rg_prdif.por_cta_hij_fec_ini,
              rg_prdif.mto_pre_cta_hij_fec_ini,
              rg_prdif.fec_pre_cta_hijo
         from pr_previsiones prv_cta_nva
        where prv_cta_nva.nro_cuenta =  c_act.nro_cta_nueva
          and prv_cta_nva.fecha = c_act.fec_ini_cta_nueva;
      exception
       when no_data_found then
         null;
      end;


   v_redondeo_ori := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6, null, rg_prdif.cod_mon_cta_madre );
   v_redondeo_nva := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6, null, rg_prdif.cod_mon_cta_hijo);


      update pr_re4_dif_previsiones p
         set p.por_pre_cta_madre        = nvl(rg_prdif.por_pre_cta_madre,p.por_pre_cta_madre),
             p.fec_pre_ini_cta_ori      = nvl(rg_prdif.fec_pre_ini_cta_ori, p.fec_pre_ini_cta_ori),
             p.fec_pre_cta_madre        = nvl(rg_prdif.fec_pre_cta_madre, p.fec_pre_cta_madre),
             p.fec_pre_cta_hijo         = nvl(rg_prdif.fec_pre_cta_hijo, p.fec_pre_cta_hijo),
             p.mto_prev_cta_madre       = nvl(round(rg_prdif.mto_prev_cta_madre/
                                          decode(rg_prdif.cod_mon_cta_madre,'GS', v_cot_mon_local,
                                          fug_obt_cotizacion(rg_prdif.cod_mon_cta_madre,c_act.fec_ini_cta_nueva))
                                          ,v_redondeo_ori), p.mto_prev_cta_madre),
             p.por_cta_mad_fec_ini      = nvl(rg_prdif.por_cta_mad_fec_ini,p.por_cta_mad_fec_ini),
             p.mto_pre_cta_mad_fec_ini  = nvl(round(rg_prdif.mto_pre_cta_mad_fec_ini/
                                          decode(rg_prdif.cod_mon_cta_madre,'GS', v_cot_mon_local,
                                          fug_obt_cotizacion(rg_prdif.cod_mon_cta_madre,c_act.fec_ini_cta_nueva))
                                          ,v_redondeo_ori),p.mto_pre_cta_mad_fec_ini),
             p.por_cta_hij_fec_ini      = nvl(rg_prdif.por_cta_hij_fec_ini, p.por_cta_hij_fec_ini),
             p.mto_pre_cta_hij_fec_ini  = nvl(round(rg_prdif.mto_pre_cta_hij_fec_ini/
                                          decode(rg_prdif.cod_mon_cta_hijo,'GS', v_cot_mon_local,
                                          fug_obt_cotizacion(rg_prdif.cod_mon_cta_hijo,c_act.fec_ini_cta_nueva))
                                          ,v_redondeo_nva),p.mto_pre_cta_hij_fec_ini),
             p.dia_atraso               = rg_prdif.dia_atraso,
             p.cat_aut_cta_madre        = rg_prdif.cat_aut_cta_madre,
             p.cat_ren_cta_madre        = rg_prdif.cat_ren_cta_madre,
             p.cod_mon_cta_madre        = rg_prdif.cod_mon_cta_madre,
             p.mto_tot_deu_cta_madre    = rg_prdif.mto_tot_deu_cta_madre,
             p.cat_ren_cta_hijo         = rg_prdif.cat_ren_cta_hijo
       where p.cod_persona = c_act.cod_persona
         and p.nro_cuenta = c_act.Nro_Cta_Nueva;


 end loop;

   --Procesar solo fin de mes: DIFERIMIENTO DE PREVISIONES - PRODUCTOS COVID-19
     for diprev in c_dif_previsiones loop


          v_mes_a_diferir := round(((v_fec_actual-diprev.fec_inicio)/30));

          v_mto_pre_dif_actual := round(diprev.mto_pre_diferido,v_red_mon_local) * v_mes_a_diferir;


       if v_mto_pre_dif_actual > 0 then

          --insertar movimiento:
          r_gmovi.cod_usuario    := user;
          r_gmovi.hora           := v_hora;
          r_gmovi.fecha          := v_fec_actual;
          r_gmovi.fec_valor      := v_fec_actual;
          r_gmovi.cod_mod_padre  := diprev.cod_modulo;
          r_gmovi.cod_mad_padre  := diprev.cod_modalidad;
          r_gmovi.cod_modulo     := diprev.cod_modulo;
          r_gmovi.cod_modalidad  := diprev.cod_modalidad;
          r_gmovi.cod_oficina    := diprev.cod_oficina;
          r_gmovi.cod_ofi_origen := diprev.cod_oficina;
          --r_gmovi.cod_moneda     := diprev.cod_moneda;
          r_gmovi.cod_moneda     := v_cod_mon_local;
          r_gmovi.estado         := 'N';
          r_gmovi.reversado      := 'N';
          r_gmovi.emi_aviso      := 'N';
          r_gmovi.protegido      := 'N';
          --r_gmovi.nro_cuenta     := diprev.nro_cuenta;
          r_gmovi.referencia     := diprev.nro_cuenta;
          r_gmovi.est_cuenta     := diprev.estado;
          if v_nro_secuencia + 2 > 999 then
             v_nro_secuencia := 0;
             v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
             r_gmovi.hora           := v_hora;
          end if;
            --- Constituir previsiones
           v_nro_secuencia         := v_nro_secuencia + 1;
           r_gmovi.nro_secuencia   := v_nro_secuencia;
           r_gmovi.cod_tra_padre   := 9124;
           r_gmovi.cod_transaccion := 9124;
           r_gmovi.monto           := v_mto_pre_dif_actual;
           r_gmovi.concepto        := diprev.nro_cuenta||' '||'DIFERIMIENTO PREVISION - RESOL.04';
           pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

         update pr_re4_dif_previsiones x
            set x.can_mes_diferido = nvl(x.can_mes_diferido,0) + v_mes_a_diferir,
                x.mto_pre_diferido = v_mto_pre_dif_actual,
                x.mto_pre_dif_acumulado = nvl(x.mto_pre_dif_acumulado,0) + v_mto_pre_dif_actual,
                x.fec_actualizacion = v_fec_actual
          where x.nro_cuenta = diprev.nro_cuenta;
        end if;
      end loop;

end;


BEGIN
   v_fec_actual         := pag_cal.fu_obt_fec_actual(6);
   --v_hora               := fug_ini_hora(Sysdate);
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   v_cat_rie_1a         := fug_con_numero('1.1');
   v_cod_tra_constitucion  := 9730;

   v_cod_mon_local      := pag_gen.fu_obt_mon_local;
   v_tip_implementacion := fug_obt_tip_implementacion;
   -- código de causa por insuficiencia de fondos
   v_cau_insufondos      := fug_obt_pardinamico('CAU_INSUFI_FONDOS',null,null,null,null);
   begin
      select por_riesgo_1a, por_riesgo_1b, por_riesgo_2, por_riesgo_3, por_riesgo_4, por_riesgo_5, por_riesgo_6
        into v_riesgo1a, v_riesgo1b, v_riesgo2, v_riesgo3, v_riesgo4, v_riesgo5, v_riesgo6
        from pr_parametros
       where rownum = 1;
   exception
      when no_data_found then
         raise_application_error(-20000,'Parametros de riesgos no definidos');
   end;
   v_nro_secuencia := 0;
   for reg in c_prestamos loop
      v_cat_prev      := reg.cat_riesgo;
      v_prevision     := 0;
      v_pri_prevision := 0;
      v_seg_prevision := 0;
      v_por_prev_cheq := 0;
      v_por_prev_clie := 0;
      v_tot_cash      := 0;
      v_sal_capital   := 0;
      v_cap_pri_prevision := 0;
      v_int_pri_prevision := 0;
      v_cap_seg_prevision := 0;
      v_int_seg_prevision := 0;
      v_pre_mon_local          := 0;
      v_pri_pre_mon_local      := 0;
      v_cap_pri_pre_mon_local  := 0;
      v_cap_seg_pre_mon_local  := 0;
      v_int_pri_pre_mon_local  := 0;
      v_int_seg_prev_mon_local := 0;
      v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, NULL, reg.cod_moneda); --- Redondeo
      if v_tip_implementacion <> 3 then
         v_garantia      := lf_obt_gar_com(reg.nro_cuenta, reg.cod_moneda, v_cod_mon_local, reg.oc_ttdeuda, v_tot_cash);
      else -- FA
         v_garantia      := lf_obt_gar_com(reg.nro_cuenta, reg.cod_moneda, v_cod_mon_local, reg.sal_capital, v_tot_cash);
      end if;
      if v_tip_implementacion <> 2 then
        IF reg.cod_modalidad in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
            FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6)) then
            --- Previsionar por días de atraso
            if reg.dia_atraso < 31 then
               v_por_prev_cheq := 0;
            elsif reg.dia_atraso >= 31 and reg.dia_atraso < 60 then
               v_por_prev_cheq := 20;
            elsif reg.dia_atraso >= 60 and reg.dia_atraso < 90 then
               v_por_prev_cheq := 50;
            elsif reg.dia_atraso >= 90 and reg.dia_atraso < 120 then
               v_por_prev_cheq := 75;
            elsif reg.dia_atraso >= 120 then
               v_por_prev_cheq := 100;
            else
               v_por_prev_cheq := 0;
            end if;
         end if;
       else
         -- hacer prevision especial solamente para cheques devueltos
         if reg.cod_modalidad = FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6) then
            -- verificar si la devolución fue por insuficiencia de fondos
            begin
              select 0 into v_por_prev_cheq
              from pr_cta_prestamos a, pr_solicitudes b, cc_che_enviados c
              where a.cod_modalidad = reg.cod_modalidad
                and a.estado <> 'N'
                and a.nro_solicitud = b.nro_solicitud
                and c.nro_cheque = substr(b.descripcion,5,instr(b.descripcion,'CTA:',4)-6)
                and c.nro_cuenta = substr(b.descripcion,instr(b.descripcion,'CTA:',4)+4,length(b.descripcion))
                and c.cod_cau_devolucion = v_cau_insufondos
                and a.nro_cuenta = reg.nro_cuenta;

              --- Previsionar por días de atraso si es por insuficiencia de fondos la devolucion
              if reg.dia_atraso < 31 then
                 v_por_prev_cheq := 0;
              elsif reg.dia_atraso >= 31 and reg.dia_atraso < 60 then
                 v_por_prev_cheq := 20;
              elsif reg.dia_atraso >= 60 and reg.dia_atraso < 90 then
                 v_por_prev_cheq := 50;
              elsif reg.dia_atraso >= 90 and reg.dia_atraso < 120 then
                 v_por_prev_cheq := 75;
              elsif reg.dia_atraso >= 120 then
                 v_por_prev_cheq := 100;
              else
                 v_por_prev_cheq := 0;
              end if;

            exception when no_data_found then
              -- si no es por ese motivo, entonces no hace nada y sigue el proceso normal
              null;
            end;
         end if;
      end if;
      --- Verificar si debe o no retener la previsión
      IF reg.cat_renovaciones IS NOT NULL THEN
         IF reg.cat_renovaciones > reg.cat_ren_anterior AND reg.lib_prevision = 'N' THEN
              --- Para que calcule la previsión a la categoría
              --- anterior porque aún no pago lo suficiente como
              --- para liberar la previsión, pero si mejoró su categoría
              v_cat_prev := reg.cat_ren_anterior;
          END IF;
      END IF;
      ---
       ---
      IF v_cat_prev   < 2 THEN
         v_fec_anterior := pag_cal.FU_OBT_FEC_ANT_HAB (reg.fec_inicio,31,1);
         v_cat_cli_prevision := fug_con_numero(lf_obt_cat_individual(reg.cod_persona, v_fec_anterior));
         IF v_cat_cli_prevision < 2 THEN -- Solo Cat 1, 1a, 1b
            v_por_prev_clie := (CASE WHEN v_cat_cli_prevision = v_cat_rie_1a THEN  v_riesgo1a
                                     WHEN v_cat_cli_prevision > v_cat_rie_1a THEN  v_riesgo1b
                                     ELSE 0
                                END);
         ELSE --Cat 2..6
            v_por_prev_clie := v_riesgo1b;
         END IF;
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
      if v_por_prev_cheq > v_por_prev_clie then
           v_por_prevision := v_por_prev_cheq;
      end if;

      --- REALIZAR PRIMERA PREVISION
      --- Aplicar el 50% de la previsión obtenida al neto de la deuda
      v_por_prevision := v_por_prevision/2;
      --- Obtener el importe de la deuda para la primera previsión.
      v_sal_capital := nvl(reg.sal_capital, 0);
      IF v_cat_prev > 2 OR (v_cat_prev = 2 AND reg.dia_atraso > 60) THEN
         v_tot_apl := nvl(reg.sal_capital,0);
      ELSE
         v_tot_apl := nvl(reg.oc_ttdeuda,0);
      END IF;
      --
      IF v_tot_cash > 0 THEN -- si tiene garantia cash
        IF v_tot_cash >= v_tot_apl THEN -- el cash es mayor que la deuda, cubre todo
          v_tot_apl := 0;
          v_sal_capital := 0;
          v_garantia := v_garantia - v_tot_apl; -- restar lo utilizado
        ELSE -- la deuda es mayor que el cash
          v_tot_apl := v_tot_apl - v_tot_cash;
          v_sal_capital := v_sal_capital - v_tot_cash;
          IF v_sal_capital < 0 THEN
             v_sal_capital := 0;
          END IF;
          v_garantia := v_garantia - v_tot_cash; -- restar el cash de la garantia total
        END IF;
      END IF; -- si no tiene cash, el total aplicar es la deuda total
      -- hallar primera prevision s/ el saldo a aplicar
      IF v_cod_mon_local = reg.cod_moneda THEN
        v_prevision := round(nvl(v_tot_apl,0)*v_por_prevision/100,0);
      ELSE
        v_prevision := round(nvl(v_tot_apl,0)*v_por_prevision/100,2);
      END IF;

      --- HALLAR VALOR COMPUTABLE DE LA GARANTIA
      IF nvl(v_garantia,0) = 0 AND nvl(v_tot_cash,0) = 0 THEN
          --- Según modificación a Res. 8 IX. Regimenes de previsiones Inc. 29.
          --- Esta metodologia de cálculo no se aplicará cuando los préstamos carezcan de garantía
          --- en cuyo caso el % de prevision se aplicara sobre el saldo total de la deuda
          v_prevision := 0;
          v_por_prevision := v_por_prevision*2;
      ELSE
          IF v_cat_prev = 6 THEN
             v_por_prevision := v_por_prevision*2;
          END IF;
      END IF;
      v_pri_prevision := v_prevision;
      -- Obtener el Capital, Interes de la Primera Previsión.
      IF v_cat_prev > 2  OR (v_cat_prev = 2 AND reg.dia_atraso > 60) THEN
         v_cap_pri_prevision := nvl(v_pri_prevision, 0);
         v_int_pri_prevision := 0;
      ELSE
         IF nvl(v_tot_apl, 0) > 0 THEN
            -- Obtener el Capital de la Primera Previsión.
            v_cap_pri_prevision := round((nvl(v_sal_capital, 0) / nvl(v_tot_apl, 0)) * v_pri_prevision,v_redondeo);
            -- Obtener el Interés de la Primera Previsión.
            v_int_pri_prevision := round(nvl(v_pri_prevision, 0) - nvl(v_cap_pri_prevision, 0), v_redondeo);
            -- Verifico la distribución de la primera previsión.
            IF (NVL(v_pri_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0)),v_redondeo)) <> 0 THEN
               v_cap_pri_prevision := round(v_cap_pri_prevision + (NVL(v_pri_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0)),v_redondeo)),v_redondeo);
            END IF;
         END IF;
      END IF;
      --- REALIZAR SEGUNDA PREVISION
      IF v_cat_prev > 2 OR (v_cat_prev = 2 AND reg.dia_atraso > 60) THEN
         v_neto := nvl(reg.sal_capital,0) - nvl(v_garantia,0) - nvl(v_tot_cash,0) - v_prevision;
      ELSE
         v_neto := nvl(reg.oc_ttdeuda,0) - nvl(v_garantia,0) - nvl(v_tot_cash,0) - v_prevision;
      END IF;
      ---
      IF v_neto < 0 THEN
          v_neto := 0;
      END IF;
      --- Calcular cantidad de dias desde la ultima clasificacion
      v_dias_cat := v_fec_actual - reg.fec_ult_clasif;
      if reg.cat_riesgo = 6 and v_garantia > 0 and v_dias_cat >= 545 then --545 = 365 días (que está en la categoría 6) + 180 días (1 semestre)
         --- Previsiones Genericas - Solo si tiene garantia
         v_por_previsionado := 0;
         v_prv_anterior := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual, v_ind_pri_sem_cat6_ant);
         v_ind_pri_sem_cat6 := v_ind_pri_sem_cat6_ant;
         v_por_previsionado := round((nvl(v_prv_anterior, 0) - nvl(reg.dev_no_cobrado, 0))/reg.sal_capital * 100,2);
         if v_dias_cat >= 725 then -- 725= 365 días (que está en la categoría 6) + 360 días (2 semestres de 180 días cada 1)
            --- Se debe previsionar el 100% de la deuda
            v_prevision := reg.oc_ttdeuda;
            v_neto      := reg.oc_ttdeuda;
            v_por_prevision := 100;
            v_por_calculado := 100;
            --545 = 365 días (que está en la categoría 6) + 180 días (1 semestre)
         elsif v_dias_cat >= 545 and nvl(v_ind_pri_sem_cat6, 'N') = 'N' then
            v_por_pri_semestre := 100 - v_por_previsionado;

            if v_por_pri_semestre > 25 then
               v_por_pri_semestre := v_por_pri_semestre -25;
            end if;

            v_por_calculado := nvl(v_por_previsionado, 0) + nvl(v_por_pri_semestre, 0);

            if v_por_calculado = 100 then
               v_prevision := reg.oc_ttdeuda;
            else
               v_prevision := round(v_prv_anterior + (nvl(reg.sal_capital,0)* v_por_pri_semestre/100), v_redondeo);
            end if;

            v_por_prevision := 100;
            v_neto          := reg.oc_ttdeuda;
            v_ind_pri_sem_cat6 := 'S';
         end if;
      else
          v_por_previsionado := null;
          v_por_calculado := null;
          v_ind_pri_sem_cat6 := null;

          if v_cod_mon_local = reg.cod_moneda then
             v_prevision := v_prevision + round(nvl(v_neto,0)*v_por_prevision/100,0);
             v_seg_prevision := round(nvl(v_prevision, 0) - nvl(v_pri_prevision, 0), v_redondeo);
             IF v_neto = 0 THEN
                v_cap_seg_prevision := 0;
                v_int_seg_prevision := 0;
             ELSE
                IF v_cat_prev > 2 OR (v_cat_prev = 2 AND reg.dia_atraso > 60) THEN
                   v_cap_seg_prevision := NVL(v_seg_prevision,0);
                   v_int_seg_prevision := 0;
                ELSE
                   IF nvl(v_tot_apl, 0) > 0 THEN
                      -- Obtener el Capital de la Segunda Previsión.
                      v_cap_seg_prevision := round((nvl(v_sal_capital, 0) / nvl(v_tot_apl, 0)) * NVL(v_seg_prevision,0),v_redondeo);
                      -- Obtener el Interés de la Segunda Previsión.
                      v_int_seg_prevision := round(NVL(v_seg_prevision,0) - nvl(v_cap_seg_prevision, 0), v_redondeo);
                      -- Verifico la distribución de la segunda previsión.
                      IF (NVL(v_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0) + NVL(v_cap_seg_prevision,0) + NVL(v_int_seg_prevision,0)),v_redondeo)) <> 0 THEN
                         IF (NVL(v_cap_seg_prevision,0) - (NVL(v_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0) + NVL(v_cap_seg_prevision,0) + NVL(v_int_seg_prevision,0)),v_redondeo))) >= 0 THEN
                            v_cap_seg_prevision := round(v_cap_seg_prevision + (NVL(v_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0) + NVL(v_cap_seg_prevision,0) + NVL(v_int_seg_prevision,0)),v_redondeo)),v_redondeo);
                         END IF;
                      END IF;
                   END IF;
                END IF;
             END IF;
          else
             v_prevision := v_prevision + round(nvl(v_neto,0)*v_por_prevision/100,2);
             v_seg_prevision := round(nvl(v_prevision, 0) - nvl(v_pri_prevision, 0), v_redondeo);
             IF v_neto = 0 then
                v_cap_seg_prevision := 0;
                v_int_seg_prevision := 0;
             ELSE
                IF v_cat_prev > 2 OR (v_cat_prev = 2 AND reg.dia_atraso > 60) THEN
                   v_cap_seg_prevision := NVL(v_seg_prevision,0);
                   v_int_seg_prevision := 0;
                ELSE
                   IF nvl(v_tot_apl, 0) > 0 THEN
                      -- Obtener el Capital de la Segunda Previsión.
                      v_cap_seg_prevision := round((nvl(v_sal_capital, 0) / nvl(v_tot_apl, 0)) * NVL(v_seg_prevision,0),v_redondeo);
                      -- Obtener el Interés de la Segunda Previsión.
                      v_int_seg_prevision := round(NVL(v_seg_prevision,0) - nvl(v_cap_seg_prevision, 0), v_redondeo);
                      -- Verifico la distribución de la segunda previsión.
                      IF (NVL(v_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0) + NVL(v_cap_seg_prevision,0) + NVL(v_int_seg_prevision,0)),v_redondeo)) <> 0 THEN
                         IF (NVL(v_cap_seg_prevision,0) - (NVL(v_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0) + NVL(v_cap_seg_prevision,0) + NVL(v_int_seg_prevision,0)),v_redondeo))) >= 0 THEN
                            v_cap_seg_prevision := round(v_cap_seg_prevision + (NVL(v_prevision,0) - round((NVL(v_cap_pri_prevision,0) + NVL(v_int_pri_prevision,0) + NVL(v_cap_seg_prevision,0) + NVL(v_int_seg_prevision,0)),v_redondeo)),v_redondeo);
                         END IF;
                      END IF;
                   END IF;
                END IF;
             END IF;
          end if;
          if v_cat_prev > 2 then
             v_prevision := v_prevision + nvl(reg.dev_no_cobrado,0);
             v_int_seg_prevision := nvl(v_int_seg_prevision,0) + nvl(reg.dev_no_cobrado,0);
          end if;
          if v_cat_prev = 2 and reg.dia_atraso > 60 then
             v_prevision := v_prevision + nvl(reg.dev_no_cobrado,0);
             v_int_seg_prevision := nvl(v_int_seg_prevision,0) + nvl(reg.dev_no_cobrado,0);
          end if;
      end if;
      --- Recuperar prevision anterior si la tuviere
      v_prv_anterior := lf_obt_prv_ant(reg.nro_cuenta, v_fec_actual, v_ind_pri_sem_cat6_ant);
      v_prv_per_anterior := LF_OBT_PRV_PER_ANT(reg.nro_cuenta, v_fec_actual);
      v_diferencia   := 0;
      v_dif_prevision := 0;
      If (fug_obt_tip_implementacion = 3 and reg.cod_causa is null)  or
         fug_obt_tip_implementacion <> 3 then
        --- Inicializar datos cabecera del movimiento
        r_gmovi.cod_usuario    := user;
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
        if v_nro_secuencia + 2 > 999 then
           v_nro_secuencia := 0;
           --v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           r_gmovi.hora           := v_hora;
        end if;
        if reg.fec_cancelacion is not null then
           null;
        else
           v_diferencia  := nvl(v_prevision,0) - nvl(v_prv_anterior,0);
           if nvl(v_prevision,0) > nvl(v_prv_per_anterior,0) then
              v_dif_prevision := nvl(v_prevision,0) - nvl(v_prv_per_anterior,0);
           else
              v_dif_prevision := nvl(v_prv_anterior,0) - nvl(v_prv_per_anterior,0);
           end if;

           if reg.cat_riesgo = 6 and v_dias_cat between 545 and 724 and v_garantia > 0
              and nvl(v_ind_pri_sem_cat6, 'N') = 'S' and nvl(v_ind_pri_sem_cat6_ant, 'N') = nvl(v_ind_pri_sem_cat6, 'N') then
              v_diferencia := 0;
           end if;

           r_gmovi.monto := nvl(v_diferencia,0);
           if v_diferencia <> 0 then
              --- Insertar prevision
              r_pprev.nro_cuenta     := reg.nro_cuenta;
              r_pprev.fecha          := v_fec_actual;
              r_pprev.monto          := nvl(v_prevision,0);
              r_pprev.sal_capital    := nvl(reg.sal_capital,0);
              r_pprev.dev_no_cobrado := nvl(reg.dev_no_cobrado,0);
              r_pprev.porcentaje     := nvl(v_por_prevision,0);
              r_pprev.tot_gar_computables := nvl(v_garantia,0);
              r_pprev.tot_pri_prevision   := nvl(v_pri_prevision,0);
              r_pprev.tot_cap_pri_prevision := nvl(v_cap_pri_prevision, 0);
              r_pprev.tot_cap_seg_prevision := nvl(v_cap_seg_prevision, 0);
              r_pprev.tot_int_pri_prevision := nvl(v_int_pri_prevision, 0);
              r_pprev.tot_int_seg_prevision := nvl(v_int_seg_prevision, 0);
              r_pprev.mto_pre_anterior := nvl(v_prv_anterior,0);
              r_pprev.por_pre_anterior := nvl(v_por_previsionado,0);
              r_pprev.por_calculado := nvl(v_por_calculado, 0);
              r_pprev.ind_pri_sem_cat6 := v_ind_pri_sem_cat6;

              lp_ins_prevision(r_pprev);
                 --- Constituir previsiones
                 v_nro_secuencia         := v_nro_secuencia + 1;
                 r_gmovi.nro_secuencia   := v_nro_secuencia;
                 r_gmovi.cod_tra_padre   := v_cod_tra_constitucion;
                 r_gmovi.cod_transaccion := v_cod_tra_constitucion;
                 r_gmovi.concepto        := 'CONSTITUCION DE PREVISION';
                 pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
           end if;
        end if;
        -- Convierto los montos de previsiones a moneda local.
        IF reg.cod_moneda <> v_cod_mon_local THEN
           v_pre_mon_local          := pag_gen.fu_con_mon_a_moneda(reg.cod_moneda, v_cod_mon_local, nvl(v_prevision, 0));
           v_pri_pre_mon_local      := pag_gen.fu_con_mon_a_moneda(reg.cod_moneda, v_cod_mon_local, nvl(v_pri_prevision, 0));
           v_cap_pri_pre_mon_local  := pag_gen.fu_con_mon_a_moneda(reg.cod_moneda, v_cod_mon_local, nvl(v_cap_pri_prevision, 0));
           v_cap_seg_pre_mon_local  := pag_gen.fu_con_mon_a_moneda(reg.cod_moneda, v_cod_mon_local, nvl(v_cap_seg_prevision, 0));
           v_int_pri_pre_mon_local  := pag_gen.fu_con_mon_a_moneda(reg.cod_moneda, v_cod_mon_local, nvl(v_int_pri_prevision, 0));
           v_int_seg_prev_mon_local := pag_gen.fu_con_mon_a_moneda(reg.cod_moneda, v_cod_mon_local, nvl(v_int_seg_prevision, 0));
        ELSE
           v_pre_mon_local          := nvl(v_prevision, 0);
           v_pri_pre_mon_local      := nvl(v_pri_prevision, 0);
           v_cap_pri_pre_mon_local  := nvl(v_cap_pri_prevision, 0);
           v_cap_seg_pre_mon_local  := nvl(v_cap_seg_prevision, 0);
           v_int_pri_pre_mon_local  := nvl(v_int_pri_prevision, 0);
           v_int_seg_prev_mon_local := nvl(v_int_seg_prevision, 0);
        END IF;
        -- Verifico si existe diferencia de redondeo entre el total y el detalle de previsiones.
        v_ajuste := 0;
        v_ajuste := round((nvl(v_pri_pre_mon_local,0) - (nvl(v_cap_pri_pre_mon_local,0)+nvl(v_int_pri_pre_mon_local,0))),2);
        IF ROUND((nvl(v_cap_pri_pre_mon_local,0) + NVL(v_ajuste,0)),v_redondeo) > 0 THEN
           v_cap_pri_pre_mon_local := round((nvl(v_cap_pri_pre_mon_local,0) + NVL(v_ajuste,0)),v_redondeo);
        ELSE
           v_cap_pri_pre_mon_local := nvl(v_cap_pri_pre_mon_local,0);
        END IF;
        --
        v_ajuste := 0;
        v_ajuste := round((nvl(v_pre_mon_local,0) - (nvl(v_cap_pri_pre_mon_local,0)+nvl(v_cap_seg_pre_mon_local,0)+nvl(v_int_pri_pre_mon_local,0)+nvl(v_int_seg_prev_mon_local,0))),2);
        IF ROUND((nvl(v_cap_seg_pre_mon_local,0) + NVL(v_ajuste,0)),v_redondeo) > 0 THEN
           v_cap_seg_pre_mon_local := round((nvl(v_cap_seg_pre_mon_local,0) + NVL(v_ajuste,0)),v_redondeo);
        ELSE
           v_cap_seg_pre_mon_local := nvl(v_cap_seg_pre_mon_local,0);
        END IF;
        --
        IF ROUND((nvl(v_cap_seg_pre_mon_local,0) + NVL(v_ajuste,0)),v_redondeo) < 0 THEN
           v_cap_pri_pre_mon_local := round((nvl(v_cap_pri_pre_mon_local,0) + NVL(v_ajuste,0)),v_redondeo);
        ELSE
           v_cap_pri_pre_mon_local := nvl(v_cap_pri_pre_mon_local,0);
        END IF;

        -- Actualiza la tabla.

       if reg.cat_riesgo = 6 and v_dias_cat between 545 and 724 and v_garantia > 0
          and nvl(v_ind_pri_sem_cat6, 'N') = 'S' and nvl(v_ind_pri_sem_cat6_ant, 'N') = nvl(v_ind_pri_sem_cat6, 'N') then
          null;
       else
          UPDATE ge_cla_operaciones
              SET tot_prevision         = nvl(v_pre_mon_local,0),
                  tot_pri_prevision     = nvl(v_pri_pre_mon_local,0),
                  tot_cap_pri_prevision = nvl(v_cap_pri_pre_mon_local,0),
                  tot_cap_seg_prevision = nvl(v_cap_seg_pre_mon_local,0),
                  tot_int_pri_prevision = nvl(v_int_pri_pre_mon_local,0),
                  tot_int_seg_prevision = nvl(v_int_seg_prev_mon_local,0)
            WHERE nro_cuenta = reg.nro_cuenta;
        end if;
      end if;
   end loop;
   lp_act_prev_diferidos;
END;
/

