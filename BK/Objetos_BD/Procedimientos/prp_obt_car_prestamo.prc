CREATE OR REPLACE PROCEDURE IT.PRP_OBT_CAR_PRESTAMO (P_NRO_CUENTA              IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
                                                ,P_FECHA                   IN DATE
                                                ,P_NRO_CUO_DESDE           IN PR_CUOTAS.NRO_CUOTA%TYPE
                                                ,P_NRO_CUO_HASTA           IN PR_CUOTAS.NRO_CUOTA%TYPE
                                                ,P_TRA_CARGO               IN PR_CTA_GASTOS.COD_TRANSACCION%TYPE
                                                ,P_MTO_COBRADO             IN PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
                                                ,P_ERROR                   IN OUT NUMBER
                                                ,P_MENSAJE                 IN OUT VARCHAR2
                                                ,P_TOT_CARGO               IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
                                                ,P_TOT_CARGO_IVA           IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
                                                ,P_TOT_OTR_CARGO           IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
                                                ,P_TOT_OTR_CARGO_IVA       IN OUT PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE
                                                ,P_COD_TRA_PADRE           IN NUMBER default 360
                                                ,P_CANCELA                 IN VARCHAR2 default 'N'
                                                ,P_RENUEVA                 IN VARCHAR2 default 'N'
                                                ,P_CANCEL_RRR              IN VARCHAR2 DEFAULT 'N'
                                                ) IS

   V_FEC_ULT_PAGO        PR_CUOTAS.FEC_ULT_PAGO%TYPE;
   V_CAR_ADIC            NUMBER;
   V_EXISTE              VARCHAR2(1);
   V_MTO_DEV_ACTUAL      PR_DEVENGADOS_TMP.MTO_DEV_ACTUAL%TYPE;
   r_pcpre               pr_cta_prestamos%rowtype;
   r_pctmp               pr_cobros_tmp%rowtype;
   v_min_cuo_vencida     pr_cuotas.nro_cuota%type;
   v_nro_cuo_hasta       pr_cuotas.nro_cuota%type;
   v_sal_cobrado         pr_cuotas.sal_capital%type;
   v_sal_capital         pr_cuotas.sal_capital%type;
   v_sal_interes         pr_cuotas.sal_interes%type;
   v_int_descontado      pr_cuotas.sal_interes%type;
   v_cap_adelantado      pr_cuotas.sal_capital%type;
   v_mora                pr_cuotas.sal_interes%type;
   v_mora_interes        pr_cuotas.sal_interes%type;
   v_mora_int_ade        pr_cuotas.sal_interes%type;
   v_impuesto            pr_cuotas.sal_interes%type;
   v_cargo               pr_cuotas.sal_interes%type;
   P_VAL_CARGOS          pr_cuotas.sal_interes%type;
   P_VAL_CARGOS_IVA      pr_cuotas.sal_interes%type;
   P_VAL_VARIOS          pr_cuotas.sal_interes%type;
   P_VAL_VARIOS_IVA      pr_cuotas.sal_interes%type;
   v_car_seguro          pr_cuotas.sal_interes%type;
   v_car_adicional       pr_cuotas.sal_interes%type;
   v_tra_iva             ge_transacciones.cod_transaccion%type;
   v_cargo_iva           pr_cuotas.sal_interes%type;
   v_punitorio           pr_cuotas.sal_interes%type;
   v_tot_cargo           pr_cuotas.sal_interes%type;
   v_tot_cargo_iva       pr_cuotas.sal_interes%type;
   v_tot_otr_cargo       pr_cuotas.sal_interes%type;
   v_tot_otr_cargo_iva   pr_cuotas.sal_interes%type;
   v_car_manual          pr_cuotas.sal_interes%type;
   v_car_manual_iva      pr_cuotas.sal_interes%type;
   v_car_restante        pr_cuotas.sal_interes%type;
   v_car_restante_iva    pr_cuotas.sal_interes%type;
   v_sal_int_ant         pr_cuotas.sal_interes%type;
   v_mto_ant             pr_cuotas.sal_interes%type;
   v_mto_int_mor_des     pr_cobros.mto_int_mor_des%type;
   v_mto_int_mor_int_des pr_cobros.mto_int_mor_int_des%type;
   v_mto_int_mor_ade_des pr_cobros.mto_int_mor_ade_des%type;
   v_mto_int_pun_des     pr_cobros.mto_int_pun_des%type;
   v_mto_car_des         pr_cobros.mto_car_des%type;
   v_iva                 number;
   v_redondeo            number(1);
   v_cod_tasa            ge_tasas.cod_tasa%type := null;
   v_val_tasa            ge_tas_fechas.val_tasa%type;
   v_fec_vigencia        ge_tas_fechas.fec_vigencia%type;
   v_tip_valor           ge_tasas.tip_valor%type;
   v_tipo                ge_tasas.tipo%type;
   v_exo_impuesto        pr_cta_prestamos.exo_impuestos%type;
   v_mon_tot_cargo_aux   pr_cuotas.sal_interes%type;
   v_mon_tot_cargo_iva_aux  pr_cuotas.sal_interes%type;
   v_ult_dia_calculado   number(10);
   G_FEC_CALCULO         DATE;
   G_MAX_FEC_CALCULO     DATE;
   G_MAX_FEC_CALCULO_ANT DATE;
   G_CAL_ADIC            VARCHAR2(1) := 'S';
   G_TIP_CANCELACION     VARCHAR2(1);
   G_RENUEVA             VARCHAR2(1);
   G_CAP_PAGADO          PR_CTA_PRESTAMOS.SAL_CAPITAL%TYPE;
   G_PRI_VEZ             VARCHAR2(1);
   G_COD_AUT_CARGOS      GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE;
   G_SAL_VAL_CARGOS      GE_AUTORIZACIONES.VALOR%TYPE;
   G_EXI_CARGOS          GE_AUTORIZACIONES.EXIMIDO%TYPE;
   G_COD_USU_AUT_CG      GE_AUTORIZACIONES.COD_USU_AUTORIZADOR%TYPE;
   v_fec_max_ini_vigencia DATE;
   v_max_cuota           pr_cuotas.nro_cuota%type;
   v_cod_moneda          ba_monedas.cod_moneda%type;
   v_mon_cargo           pr_cuotas.sal_interes%type;
   v_dias                number(10);
   v_tot_mon_cargo_aux   pr_cuotas.sal_interes%type;
   v_cod_persona_titular ba_personas.cod_persona%type;
   v_fec_actual          date :=PAG_CAL.FU_OBT_FEC_ACTUAL(6);

   cursor C_CUOTAS is
     select *
       from pr_cuotas
      where nro_cuenta = p_nro_cuenta
        and (nvl(sal_capital,0) <> 0 or
             nvl(sal_interes,0) <> 0 or
             nvl(sal_int_documentado,0) <> 0 )
        and ((p_nro_cuo_desde is not null and p_nro_cuo_hasta is not null
              and nro_cuota >= nvl(p_nro_cuo_desde,0)
              and nro_cuota <= nvl(v_nro_cuo_hasta,999))
             or
             (fec_vencimiento <= p_fecha
              and p_nro_cuo_desde is null
              and v_nro_cuo_hasta is null))
      order by fec_vencimiento;

  cursor c_tab_temporal is
     select x.rowid registro
        from PR_SIM_COB_COBRANZAS_TMP x
      where x.nro_cuenta = p_nro_cuenta
      for update nowait;

  FUNCTION FU_OBT_MAX_FEC_VTO (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
                              ,P_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE) RETURN DATE IS
      v_max_fec_vto   pr_cuotas.fec_vencimiento%type;
      BEGIN
         select max(fec_vencimiento)
           into v_max_fec_vto
           from pr_cuotas
          where nro_cuenta = p_nro_cuenta
            and (nvl(sal_capital,0) <> 0 or
                 nvl(sal_interes,0) <> 0 or
                 nvl(sal_int_documentado,0) <> 0 )
            and nro_cuota <= p_cuota;
         return v_max_fec_vto;
      END FU_OBT_MAX_FEC_VTO;

    FUNCTION FU_OBT_MAX_FEC_CARGO (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE) RETURN DATE IS
    v_max_fec_vto   pr_Cta_gastos.fec_ini_vigencia%type;
    BEGIN
       select max(fec_ini_vigencia)
         into v_max_fec_vto
         from pr_Cta_gastos
        where nro_cuenta = p_nro_cuenta;
       return v_max_fec_vto;
    END FU_OBT_MAX_FEC_CARGO;

/* Insertar cobros temporales. */
PROCEDURE LP_INS_PR_COBROS_TMP (RP_PCTMP IN PR_COBROS_TMP%ROWTYPE);

/* Recuperar autorizaciones previas. */
PROCEDURE LP_REC_AUT_PREV;

/* Utilizar autorizacion previa */
PROCEDURE LP_UTI_AUT_PRE (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
                         ,P_EXIMIDO          IN GE_AUTORIZACIONES.EXIMIDO%TYPE
                         ,P_VALOR            IN OUT GE_AUTORIZACIONES.VALOR%TYPE
                         ,P_MONTO            IN OUT GE_AUTORIZACIONES.VALOR%TYPE);

/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE) RETURN VARCHAR2;


/* Insertar cobros temporales. */
PROCEDURE LP_INS_PR_COBROS_TMP (RP_PCTMP IN PR_COBROS_TMP%ROWTYPE) IS
BEGIN
   insert into pr_cobros_tmp( nro_cuenta         , nro_cuota             , fec_valor          , fec_vencimiento  ,
                              estado             , sal_capital_pre       , sal_interes_pre    , sal_capital_cuo  ,
                              sal_interes_cuo    , sal_int_documentado   , fec_ult_pago       , dia_mora	       ,
                              mto_capital        , mto_interes           , mto_int_documentado, mto_int_moratorio,
                              mto_int_mor_interes, mto_int_mor_adelantado, mto_int_punitorio  , mto_cargo        ,
                              mto_cargo_iva      , mto_impuesto          , mto_int_descontado , nro_documento    ,
                              mto_int_mor_cal    , mto_int_mor_int_cal   , mto_int_mor_ade_cal, mto_int_pun_cal  ,
                              mto_cargo_cal      , mto_car_iva_cal       , mto_impuesto_cal   , mto_int_mor_des  ,
                              mto_int_mor_int_des, mto_int_mor_ade_des   , mto_int_pun_des    , mto_car_des      ,
                              dev_acumulado      , dev_no_cobrado        , dev_suspenso)
                     values ( rp_pctmp.nro_cuenta         , rp_pctmp.nro_cuota             , rp_pctmp.fec_valor          , rp_pctmp.fec_vencimiento  ,
                              rp_pctmp.estado             , rp_pctmp.sal_capital_pre       , rp_pctmp.sal_interes_pre    , rp_pctmp.sal_capital_cuo  ,
                              rp_pctmp.sal_interes_cuo    , rp_pctmp.sal_int_documentado   , rp_pctmp.fec_ult_pago       , rp_pctmp.dia_mora         ,
                              rp_pctmp.mto_capital        , rp_pctmp.mto_interes           , rp_pctmp.mto_int_documentado, rp_pctmp.mto_int_moratorio,
                              rp_pctmp.mto_int_mor_interes, rp_pctmp.mto_int_mor_adelantado, rp_pctmp.mto_int_punitorio  , rp_pctmp.mto_cargo        ,
                              rp_pctmp.mto_cargo_iva      , rp_pctmp.mto_impuesto          , rp_pctmp.mto_int_descontado , rp_pctmp.nro_documento    ,
                              rp_pctmp.mto_int_mor_cal    , rp_pctmp.mto_int_mor_int_cal   , rp_pctmp.mto_int_mor_ade_cal, rp_pctmp.mto_int_pun_cal  ,
                              rp_pctmp.mto_cargo_cal      , rp_pctmp.mto_car_iva_cal       , rp_pctmp.mto_impuesto_cal   , rp_pctmp.mto_int_mor_des  ,
                              rp_pctmp.mto_int_mor_int_des, rp_pctmp.mto_int_mor_ade_des   , rp_pctmp.mto_int_pun_des    , rp_pctmp.mto_car_des      ,
                              rp_pctmp.dev_acumulado      , rp_pctmp.dev_no_cobrado        , rp_pctmp.dev_suspenso);
END;

/* Recuperar autorizaciones previas. */
PROCEDURE LP_REC_AUT_PREV IS
BEGIN
   --- Autorizacion descuento de cargos
   if g_cod_aut_cargos is null then
      pap_pre.pr_obt_aut_previa(p_nro_cuenta         ,
                                p_fecha              ,
                                p_cod_tra_padre      ,
                                r_pcpre.cod_modulo   ,
                                r_pcpre.cod_modalidad,
                                pap_pre.fu_obt_tra_concepto('CG',r_pcpre.estado,r_pcpre.tipo,r_pcpre.tip_interes, r_pcpre.tip_renovacion),
                                r_pcpre.cod_modulo   ,
                                r_pcpre.cod_modalidad,
                                g_sal_val_cargos     ,
                                g_exi_cargos         ,
                                g_cod_aut_cargos     ,
                                g_cod_usu_aut_cg     );
   end if;
END;
/* Utilizar autorizacion previa */
PROCEDURE LP_UTI_AUT_PRE (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
                         ,P_EXIMIDO          IN GE_AUTORIZACIONES.EXIMIDO%TYPE
                         ,P_VALOR            IN OUT GE_AUTORIZACIONES.VALOR%TYPE
                         ,P_MONTO            IN OUT GE_AUTORIZACIONES.VALOR%TYPE) IS
BEGIN
   if p_cod_autorizacion is not null then
      if p_eximido = 'S' and nvl(p_monto,0) > 0 then
         p_monto := 0;
      else
         if nvl(p_valor,0) >= nvl(p_monto,0) then
            p_valor := nvl(p_valor,0) - nvl(p_monto,0);
            p_monto := 0;
         else
            p_monto := nvl(p_monto,0) - nvl(p_valor,0);
            p_valor := 0;
         end if;
      end if;
   end if;
END;

/* veo si tiene IVA asociada a la transaccion */
PROCEDURE LP_OBT_TRA_IVA_ASOCIADA ( P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
                                   ,P_COD_MODULO      IN  GE_TRANSACCIONES.COD_MODULO%TYPE
                                   ,P_COD_MODALIDAD   IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE
                                   ,P_TRA_IVA         OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE) IS
BEGIN
  -- Se asume que si tiene una transaccion detallada este es de impuesto.
  select cod_tra_hijo
    into p_tra_iva
    from ge_transacciones_det
   where cod_transaccion = p_cod_transaccion
     and cod_modulo      = p_cod_modulo
     and cod_modalidad   = p_cod_modalidad;
EXCEPTION
      when no_data_found then
           p_tra_iva := null;
END;

/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE) RETURN VARCHAR2 IS
   v_exo_impuestos ge_clientes.exo_impuestos%type;
BEGIN
   select nvl(exo_impuestos,'N')
     into v_exo_impuestos
     from ge_clientes cli, ge_cta_clientes cct
    where cct.cod_persona = cli.cod_persona
      and cct.nro_cuenta  = p_nro_cuenta
      and cct.relacion    = 'P';
   return v_exo_impuestos;
END;

PROCEDURE PR_OBT_CARGO_MTO_PLZ (RG_PCPRE         IN PR_CTA_PRESTAMOS%ROWTYPE
                               ,RG_PCUOT         IN PR_CUOTAS%ROWTYPE
                               ,RG_PCTMP         IN PR_COBROS_TMP%ROWTYPE
                               ,P_FECHA          IN GE_CALENDARIOS.FEC_ACTUAL%TYPE
                               ,P_TRA_CARGO      IN PR_CTA_GASTOS.COD_TRANSACCION%TYPE
                               ,P_VAL_CARGOS     OUT PR_CTA_PRESTAMOS.Sal_Capital%type
                               ,P_VAL_CARGOS_IVA OUT PR_CTA_PRESTAMOS.Sal_Capital%type
                               ,P_VAL_VARIOS     OUT PR_CTA_PRESTAMOS.Sal_Capital%type
                               ,P_VAL_VARIOS_IVA OUT PR_CTA_PRESTAMOS.Sal_Capital%type)IS

PROCEDURE LP_OBT_CARGO_PAG_ANT (P_NRO_CUENTA  IN PR_CUOTAS.NRO_CUENTA%TYPE
                               ,P_NRO_CUOTA   IN PR_CUOTAS.NRO_CUOTA%TYPE
                               ,P_MTO_NO_PAG  IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
                               ,P_MTO_PAG     IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE);

FUNCTION LF_OBT_ULT_PAG_CARGO (P_NRO_CUENTA  IN PR_CUOTAS.NRO_CUENTA%TYPE)
 RETURN DATE;
   v_cargo             pr_cuotas.sal_interes%type;
   v_cargo_iva         pr_cuotas.sal_interes%type;
   v_car_varios        pr_cuotas.sal_interes%type;
   v_car_varios_iva    pr_cuotas.sal_interes%type;
   v_car_manual        pr_cuotas.sal_interes%type;
   v_car_manual_iva    pr_cuotas.sal_interes%type;
   v_cod_transaccion   ge_transacciones.cod_transaccion%type;
   v_tra_iva           ge_transacciones.cod_transaccion%type;
   v_cod_tasa          ge_tasas.cod_tasa%type;
   v_dias              number(10);
   v_car_cancelacion   number(18,2);
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_car_no_pag        pr_cobros.mto_int_moratorio%type;
   v_car_pag           pr_cobros.mto_int_moratorio%type;
   v_fec_ult_pag_cargo pr_cobros.fecha%type;
   g_fec_calculo       ge_calendarios.fec_actual%type;

   -- Cursor de Cargos Solicitados
   cursor gasto_solicitado is
         select monto, cod_transaccion, fec_ini_vigencia
          from pr_cta_gastos
         where nro_cuenta    = rg_pcpre.nro_cuenta
           and cod_modalidad = rg_pcpre.cod_modalidad
           and cod_transaccion = nvl(P_TRA_CARGO,cod_transaccion)
           and (fec_ini_vigencia is not null and fec_ini_vigencia = G_MAX_FEC_CALCULO)
           /*and (((fec_ini_vigencia <= G_MAX_FEC_CALCULO or fec_ini_vigencia is null )
           and  (fec_ini_vigencia >  G_MAX_FEC_CALCULO_ANT or G_MAX_FEC_CALCULO_ANT is null  or fec_ini_vigencia is null)
           and   nro_solicitud is not null)
            or  ((fec_vencimiento  >= G_MAX_FEC_CALCULO or fec_vencimiento is null) and nro_solicitud is null and g_cal_adic = 'S'))*/
           and fec_ult_pago is null;

   -- Cursor de Otros Cargos
   cursor gastos_varios is
        select sum(monto) monto, cod_transaccion, fec_ini_vigencia
          from pr_cta_gastos
         where nro_cuenta    = rg_pcpre.nro_cuenta
           and cod_modalidad = rg_pcpre.cod_modalidad
           and (P_TRA_CARGO is null or cod_transaccion <> P_TRA_CARGO)
           and (fec_ini_vigencia is not null and fec_ini_vigencia = G_MAX_FEC_CALCULO)
           /*and (((fec_ini_vigencia <= G_MAX_FEC_CALCULO or fec_ini_vigencia is null )
           and  (fec_ini_vigencia >  G_MAX_FEC_CALCULO_ANT or G_MAX_FEC_CALCULO_ANT is null  or fec_ini_vigencia is null)
           and   nro_solicitud is not null)
            or  ((fec_vencimiento  >= G_MAX_FEC_CALCULO or fec_vencimiento is null) and nro_solicitud is null and g_cal_adic = 'S'))*/
           and fec_ult_pago is null
           group by fec_ini_vigencia,cod_transaccion;

PROCEDURE LP_OBT_CARGO_PAG_ANT (P_NRO_CUENTA  IN PR_CUOTAS.NRO_CUENTA%TYPE
                               ,P_NRO_CUOTA   IN PR_CUOTAS.NRO_CUOTA%TYPE
                               ,P_MTO_NO_PAG  IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
                               ,P_MTO_PAG     IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE) IS
BEGIN
   select nvl(sum((nvl(c.mto_cargo_cal,0)- ((nvl(c.mto_cargo,0)+nvl(c.mto_car_des,0))))),0),
          nvl(sum(nvl(c.mto_cargo,0)-nvl(c.mto_cargo_iva,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and c.fecha      > v_fec_ult_pag_cargo;
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA (P_FECHA IN DATE
                         ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE) RETURN VARCHAR2 IS
  v_fec_habil  date;
  v_fec_actual date;
  v_existe     varchar2(1) := 'N';
BEGIN
   v_fec_habil  := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         return 'S';
      else
         Begin
            Select distinct('S')
              into v_existe
              from pr_cob_cuo_otr_bco a
             where a.nro_cuenta = rg_pcpre.nro_cuenta
               and a.nro_cuota  = rg_pcuot.nro_cuota
               and a.estado     = 'C'
               and a.fec_cobro  = v_fec_actual
               and a.fec_proceso <= p_fecha;
         Exception
             When no_data_found Then
                  v_existe := 'N';
             When others Then
                  v_existe := 'N';
         End;
         return v_existe;
      end if;
   end if;
END;
FUNCTION LF_OBT_ULT_PAG_CARGO (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE) RETURN DATE IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
   select fecha
     into v_max_fec_pago
     from pr_cobros cob
    where cob.nro_cuenta = p_nro_cuenta
      and cob.nro_cuota = rg_pcuot.nro_cuota
      and (cob.fecha, cob.hora) =
         (select max(mor.fecha), max(mor.hora)
            from pr_cobros mor
           where mor.nro_cuenta = cob.nro_cuenta
             and mor.nro_cuota  = cob.nro_cuota
             and   (nvl(mor.mto_int_moratorio,0)+nvl(mor.mto_int_mor_des,0) = nvl(mor.mto_int_mor_cal,0))
               and (nvl(mor.mto_int_mor_interes,0)+nvl(mor.mto_int_mor_int_des,0) = nvl(mor.mto_int_mor_int_cal,0))
               and (nvl(mor.mto_int_mor_adelantado,0)+nvl(mor.mto_int_mor_ade_des,0) = nvl(mor.mto_int_mor_ade_cal,0))
               and (nvl(mor.mto_int_punitorio,0)+nvl(mor.mto_int_pun_des,0) = nvl(mor.mto_int_pun_cal,0))
               and (nvl(mor.mto_cargo,0)+nvl(mor.mto_car_des,0) = nvl(mor.mto_cargo_cal,0))
             and mor.fecha =
                (select max(mor1.fecha)
                   from pr_cobros mor1
                  where mor1.nro_cuenta = mor.nro_cuenta
                    and mor1.nro_cuota  = mor.nro_cuota
                    and   (nvl(mor1.mto_int_moratorio,0)+nvl(mor1.mto_int_mor_des,0) = nvl(mor1.mto_int_mor_cal,0))
                      and (nvl(mor1.mto_int_mor_interes,0)+nvl(mor1.mto_int_mor_int_des,0) = nvl(mor1.mto_int_mor_int_cal,0))
                      and (nvl(mor1.mto_int_mor_adelantado,0)+nvl(mor1.mto_int_mor_ade_des,0) = nvl(mor1.mto_int_mor_ade_cal,0))
                      and (nvl(mor1.mto_int_punitorio,0)+nvl(mor1.mto_int_pun_des,0) = nvl(mor1.mto_int_pun_cal,0))
                      and (nvl(mor1.mto_cargo,0)+nvl(mor1.mto_car_des,0) = nvl(mor1.mto_cargo_cal,0))
                 )
          );
   if v_max_fec_pago < rg_pcuot.fec_vencimiento then
      v_max_fec_pago := rg_pcuot.fec_vencimiento;
   end if;
   return v_max_fec_pago;
exception
   when no_data_found then
      return rg_pcuot.fec_vencimiento;
   when others then
       raise_application_error(-20000,'Rec.Fec.Cargo '||p_nro_cuenta||' Cuota '||rg_pcuot.nro_cuota);
END;

/* veo si tiene IVA asociada a la transaccion */
PROCEDURE LP_OBT_TRA_IVA_ASOCIADA ( P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
                                   ,P_COD_MODULO      IN  GE_TRANSACCIONES.COD_MODULO%TYPE
                                   ,P_COD_MODALIDAD   IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE
                                   ,P_TRA_IVA         OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE) IS
BEGIN
  select cod_tra_hijo
    into p_tra_iva
    from ge_transacciones_det
   where cod_transaccion = p_cod_transaccion
     and cod_modulo      = p_cod_modulo
     and cod_modalidad   = p_cod_modalidad;
EXCEPTION
      when no_data_found then
           p_tra_iva := null;
END;

BEGIN
   v_redondeo          := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
   v_fec_ult_pag_cargo := lf_obt_ult_pag_cargo(p_nro_cuenta);
   v_dias              := g_fec_calculo - v_fec_ult_pag_cargo;
   v_cargo             := 0;
   v_car_varios        := 0;
   -- Recuperar montos de pagos anteriores
   lp_obt_cargo_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_car_no_pag, v_car_pag);
   v_cargo := round(nvl(v_cargo,0) - nvl(v_car_pag,0),v_redondeo);
   if nvl(g_tip_cancelacion,'N') = 'T' then
     if nvl(g_renueva,'N') = 'N' then
       v_cargo := nvl(v_cargo,0) + round((nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_int_documentado,0)) *
               nvl(fug_obt_pardinamico('POR_CAR_CANCELACION', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina),0)  / 100, v_redondeo);
     End if;
   elsif nvl(g_tip_cancelacion,'N') = 'P' and  nvl(g_pri_vez,0) = 0 and g_cap_pagado > 0 then
      v_car_cancelacion  :=  round((nvl(g_cap_pagado,0)) *
                            nvl(fug_obt_pardinamico('POR_CAR_CANCELACION', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina),0) / 100 , v_redondeo);
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo   ,
                              rg_pcpre.cod_modalidad,
                              rg_pcpre.cod_oficina  ,
                              rg_pcpre.nro_cuenta   ,
                              rg_pcpre.cod_moneda   ,
                              v_car_cancelacion     ,
                              'N'                   ,
                              v_cod_tasa            ,
                              517                   ,
                              g_fec_calculo         ,
                              v_val_tasa            ,
                              v_fec_vigencia        ,
                              v_tip_valor           ,
                              v_tipo                );

      v_car_cancelacion := nvl(v_car_cancelacion,0) + round((v_car_cancelacion * v_val_tasa / 100), v_redondeo);
      v_car_cancelacion := nvl(g_cap_pagado,0) - (nvl(g_cap_pagado,0) * 100 / (100 + (v_car_cancelacion * 100/ nvl(g_cap_pagado,0))));
      v_cargo := nvl(v_cargo,0) + round((100 * v_car_cancelacion/ (100 + v_val_tasa)),v_redondeo);
   end if;
   if nvl(v_cargo,0) > 0 then
     v_cod_transaccion := 712;
     lp_obt_tra_iva_asociada(v_cod_transaccion,rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,v_tra_iva);
     if v_tra_iva is not null then
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo   ,
                              rg_pcpre.cod_modalidad,
                              rg_pcpre.cod_oficina  ,
                              rg_pcpre.nro_cuenta   ,
                              rg_pcpre.cod_moneda   ,
                              v_dias                ,
                              'N'                   ,
                              v_cod_tasa            ,
                              517                   ,
                              g_fec_calculo         ,
                              v_val_tasa            ,
                              v_fec_vigencia        ,
                              v_tip_valor           ,
                              v_tipo                );
      v_cargo_iva := round((v_cargo * v_val_tasa / 100), v_redondeo);
     end if;
   else
      v_cargo := 0;
   end if;
   if P_TRA_CARGO is not null Then
       For reg in gasto_solicitado Loop
         v_tra_iva    := null;
         v_car_manual := reg.monto;
         lp_obt_tra_iva_asociada(reg.cod_transaccion,rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,v_tra_iva);
         v_dias := p_fecha - reg.fec_ini_vigencia;
         if nvl(v_car_manual,0) > 0 and v_tra_iva is not null then
          v_cod_tasa  := null;
          pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo   ,
                                  rg_pcpre.cod_modalidad,
                                  rg_pcpre.cod_oficina  ,
                                  rg_pcpre.nro_cuenta   ,
                                  rg_pcpre.cod_moneda   ,
                                  0                     ,
                                  'N'                   ,
                                  v_cod_tasa            ,
                                  v_tra_iva             ,
                                  g_fec_calculo         ,
                                  v_val_tasa            ,
                                  v_fec_vigencia        ,
                                  v_tip_valor           ,
                                  v_tipo                );
          v_car_manual_iva := round((v_car_manual * v_val_tasa / 100),v_redondeo);
          v_cargo_iva := nvl(v_cargo_iva,0)+ round((v_car_manual * v_val_tasa / 100),v_redondeo);
          -- Actualizar Cobros tmp
         end if;
         v_Cargo := nvl(v_cargo,0) + nvl(v_car_manual,0);
         
       End Loop;
       P_VAL_CARGOS     := v_cargo + nvl(v_cargo_iva,0);
       P_VAL_CARGOS_IVA := nvl(v_cargo_iva,0);
       -- Cursor para retornar el monto de los cargos no solicitados.
       For reg in gastos_varios Loop
         v_tra_iva         := null;
         v_car_manual      := reg.monto;
         lp_obt_tra_iva_asociada(reg.cod_transaccion,rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,v_tra_iva);
         if nvl(v_car_manual,0) > 0 and v_tra_iva is not null then
          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo   ,
                                  rg_pcpre.cod_modalidad,
                                  rg_pcpre.cod_oficina  ,
                                  rg_pcpre.nro_cuenta   ,
                                  rg_pcpre.cod_moneda   ,
                                  0                     ,
                                  'N'                   ,
                                  v_cod_tasa            ,
                                  v_tra_iva             ,
                                  g_fec_calculo         ,
                                  v_val_tasa            ,
                                  v_fec_vigencia        ,
                                  v_tip_valor           ,
                                  v_tipo                );
          v_car_varios_iva := nvl(v_car_varios_iva,0)+ round((v_car_manual * v_val_tasa / 100),v_redondeo);
         end if;
         v_car_varios := nvl(v_car_varios,0) + nvl(v_car_manual,0);
         -- tmp
         /*begin
             update pr_cobros_tmp
             set mto_cargo = v_car_manual
             where nro_cuenta = rg_pcpre.nro_cuenta
               and trunc(fec_vencimiento) = reg.fec_ini_vigencia;
          exception
             when others then
                null;
          end;
          commit;*/
       End Loop;
       P_VAL_VARIOS     := v_car_varios + nvl(v_car_varios_iva,0);
       P_VAL_VARIOS_IVA := nvl(v_car_varios_iva,0);
   Else
       For reg in gastos_varios Loop
         v_tra_iva    := null;
         v_car_manual := reg.monto;
         lp_obt_tra_iva_asociada(reg.cod_transaccion,rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,v_tra_iva);
         if nvl(v_car_manual,0) > 0 and v_tra_iva is not null then
          v_cod_tasa := null;
          pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo   ,
                                  rg_pcpre.cod_modalidad,
                                  rg_pcpre.cod_oficina  ,
                                  rg_pcpre.nro_cuenta   ,
                                  rg_pcpre.cod_moneda   ,
                                  0                     ,
                                  'N'                   ,
                                  v_cod_tasa            ,
                                  v_tra_iva             ,
                                  g_fec_calculo         ,
                                  v_val_tasa            ,
                                  v_fec_vigencia        ,
                                  v_tip_valor           ,
                                  v_tipo                );
          v_cargo_iva := nvl(v_cargo_iva,0)+ round((v_car_manual * v_val_tasa / 100),v_redondeo);
         end if;
         v_Cargo := nvl(v_cargo,0) + nvl(v_car_manual,0);
       End Loop;
       P_VAL_CARGOS     := v_cargo + nvl(v_cargo_iva,0);
       P_VAL_CARGOS_IVA := nvl(v_cargo_iva,0);
   End If;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20222,'Cuenta '||rg_pcpre.nro_cuenta||'. '||sqlerrm);
END PR_OBT_CARGO_MTO_PLZ;

/*
Para c?lculo cargos futuro
*/
PROCEDURE PR_OBT_CARGO_COBRANZAS(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
                                 ,P_FEC_VENCIMIENTO IN DATE
                                 ,P_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
                                 ,P_VAL_CARGOS     OUT PR_CTA_PRESTAMOS.Sal_Capital%type
                                 ,P_VAL_CARGOS_IVA OUT PR_CTA_PRESTAMOS.Sal_Capital%type
                                 )
IS
   v_tra_iva_cargos    ge_transacciones.cod_transaccion%type;
   v_cod_tasa_cargos   ge_tasas.cod_tasa%type;
   v_iva_cargos        pr_cuotas.sal_interes%type;
   v_val_minimo        ba_cod_referencias.val_minimo%type;
   v_val_maximo        ba_cod_referencias.val_maximo%type;
   v_cotizacion        ge_movimientos.cotizacion%type;
   v_cod_mon_local     ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;

   CURSOR c_cuo_futuro IS
      SELECT b.cod_oficina, a.nro_cuenta, a.nro_cuota, 7712, a.fec_vencimiento fec_ini_vigencia,a.fec_ult_pago, a.estado,
             b.cod_modulo, b.cod_modalidad, b.cod_moneda, b.nro_solicitud,
             (a.mto_capital+a.mto_interes) Monto_cuota,
             (a.sal_capital+a.sal_interes) Saldo_Cuota
      FROM pr_cuotas a, pr_cta_prestamos b
      WHERE a.nro_cuenta = b.nro_cuenta
        AND a.nro_cuenta = P_NRO_CUENTA
        AND (nvl(a.sal_capital,0) <> 0 or
             nvl(a.sal_interes,0) <> 0 or
             nvl(a.sal_int_documentado,0) <> 0)
        AND (
               a.nro_cuota = p_cuota
               AND TRUNC(a.fec_vencimiento) < (p_fecha)
            );
BEGIN
   begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
   v_cod_moneda := 'X';
   v_tot_mon_cargo_aux :=0;
   --- Monto tope minimo y maximo de cargos por gestion de cobranzas
   BEGIN
       SELECT val_minimo, val_maximo 
       into v_val_minimo, v_val_maximo
       FROM ba_cod_referencias 
       WHERE dominio = 'VAL_MTO_COM_COBRANZAS';
   EXCEPTION 
       WHEN OTHERS THEN
          v_val_minimo := 0;
          v_val_maximo := 0;
   END; 
        
   ------------------------------------------------------
   --------------------- PRESTAMOS ----------------------
   ------------------------------------------------------
   IF nvl(fug_obt_pardinamico('COS_REAL_IND_ACTIVO',6), 'N') = 'S' THEN
      FOR rg_cuo_futuro IN c_cuo_futuro LOOP
         IF v_cod_moneda <> rg_cuo_futuro.cod_moneda THEN
              v_cod_moneda := rg_cuo_futuro.cod_moneda;
              v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                             rg_cuo_futuro.cod_modulo,rg_cuo_futuro.cod_modalidad,rg_cuo_futuro.cod_moneda);
              
              if  v_cod_mon_local <> rg_cuo_futuro.cod_moneda then
                    v_cotizacion := pag_gen.fu_obt_cotizacion(rg_cuo_futuro.cod_moneda, v_fec_actual);                    
                    v_val_minimo := round(trunc(v_val_minimo,2)/v_cotizacion,v_redondeo);
                    v_val_maximo := round(trunc(v_val_maximo,2)/v_cotizacion,v_redondeo);                                   
              end if;
         END IF;

         v_mon_cargo := 0;
         --IF rg_cuo_futuro.Fec_Ult_Pago IS NOT NULL THEN
           -- v_dias := p_fecha - rg_cuo_futuro.fec_ult_pago;
         --ELSE
            v_dias := p_fecha - rg_cuo_futuro.fec_ini_vigencia;
         --END IF;
         v_cod_tasa := null;

         pag_gen.pr_obt_val_tasa(rg_cuo_futuro.cod_modulo   ,
                                  rg_cuo_futuro.cod_modalidad,
                                  rg_cuo_futuro.cod_oficina  ,
                                  rg_cuo_futuro.nro_cuenta   ,
                                  rg_cuo_futuro.cod_moneda   ,
                                  v_dias                ,
                                  'N'                   ,
                                  v_cod_tasa            ,
                                  7712                  ,
                                  g_fec_calculo         ,
                                  v_val_tasa            ,
                                  v_fec_vigencia        ,
                                  v_tip_valor           ,
                                  v_tipo                );

         v_mon_cargo := round((rg_cuo_futuro.saldo_cuota * v_val_tasa/100),v_redondeo);                          
         -- Recuperar los parametros de fecha tope minimo y máximo
                                   
         if v_mon_cargo < to_number(v_val_minimo) then
             v_mon_cargo := v_val_minimo;
         else 
           if v_mon_cargo > to_number(v_val_maximo) then
             v_mon_cargo :=v_val_maximo;
           end if;
         end if;
         v_tot_mon_cargo_aux := v_tot_mon_cargo_aux + v_mon_cargo;

         -- Para Calcular el IVA del Monto del Cargo de Cobranza
         if nvl(v_mon_cargo,0) > 0 then
               v_tra_iva_cargos    := null;
               lp_obt_tra_iva_asociada(7712,rg_cuo_futuro.cod_modulo,rg_cuo_futuro.cod_modalidad,v_tra_iva_cargos);
               if v_tra_iva_cargos is not null then
                   v_cod_tasa_cargos := null;
                   pag_gen.pr_obt_val_tasa(rg_cuo_futuro.cod_modulo   ,
                                        rg_cuo_futuro.cod_modalidad,
                                        rg_cuo_futuro.cod_oficina  ,
                                        rg_cuo_futuro.nro_cuenta   ,
                                        rg_cuo_futuro.cod_moneda   ,
                                        0                     ,
                                        'N'                   ,
                                        v_cod_tasa_cargos     ,
                                        v_tra_iva_cargos      ,
                                        g_fec_calculo         ,
                                        v_val_tasa            ,
                                        v_fec_vigencia        ,
                                        v_tip_valor           ,
                                        v_tipo                );
                   v_iva_cargos := round((v_mon_cargo * v_val_tasa / 100),v_redondeo);
                   v_tot_mon_cargo_aux := v_tot_mon_cargo_aux + v_iva_cargos;
              end if;
            end if;

            -- Inserto un registro correspondiente a la cuota con los datos del cargo y su iva
            BEGIN
               insert into PR_SIM_COB_COBRANZAS_TMP( nro_cuenta, nro_cuota, fec_valor, fec_vencimiento  ,
                              estado             , sal_capital_pre       , sal_interes_pre    , sal_capital_cuo  ,
                              sal_interes_cuo    , sal_int_documentado   , fec_ult_pago       , dia_mora	       ,
                              mto_capital        , mto_interes           , mto_int_documentado, mto_int_moratorio,
                              mto_int_mor_interes, mto_int_mor_adelantado, mto_int_punitorio  , mto_cargo        ,
                              mto_cargo_iva      , mto_impuesto          , mto_int_descontado , nro_documento    ,
                              mto_int_mor_cal    , mto_int_mor_int_cal   , mto_int_mor_ade_cal, mto_int_pun_cal  ,
                              mto_cargo_cal      , mto_car_iva_cal       , mto_impuesto_cal   , mto_int_mor_des  ,
                              mto_int_mor_int_des, mto_int_mor_ade_des   , mto_int_pun_des    , mto_car_des      ,
                              dev_acumulado      , dev_no_cobrado        , dev_suspenso, usu_insercion,
                              fec_insercion, usu_modificacion, fec_modificacion)
                     values ( rg_cuo_futuro.nro_cuenta, p_cuota, p_fecha , rg_cuo_futuro.fec_ini_vigencia,
                              rg_cuo_futuro.estado, 0, 0, 0,
                              0  , 0, null, v_dias,
                              0  , 0, 0, 0,
                              0  , 0, 0, v_mon_cargo,
                              v_iva_cargos  , 0, 0, 1,
                              0  , 0, 0, 0,
                              0  , 0, 0, 0,
                              0  , 0, 0, 0,
                              0  , 0, 0,
                              user, sysdate, user, sysdate);
            EXCEPTION
               WHEN OTHERS THEN
                 NULL;
            END;
            P_VAL_CARGOS := v_mon_cargo + v_iva_cargos;
            P_VAL_CARGOS_IVA := v_iva_cargos;
      END LOOP;
      
      commit;
   END IF;
END;

FUNCTION FU_INS_GAS_COB_FUTURA(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE,
                               P_FEC_INI_VIGENCIA IN DATE,
                               P_IVA IN VARCHAR,
                               p_cuota_futura IN PR_CUOTAS.NRO_CUOTA%TYPE)
RETURN VARCHAR
IS
   v_fec_min_vto_cuota DATE;
   v_tra_iva_cargos    ge_transacciones.cod_transaccion%type;
   v_cod_tasa_cargos   ge_tasas.cod_tasa%type;
   v_iva_cargos        pr_cuotas.sal_interes%type;

   CURSOR c_cuo_futuro IS
      SELECT b.cod_oficina, a.nro_cuenta, a.nro_cuota, 7712, a.fec_vencimiento fec_ini_vigencia, a.estado,
             b.cod_modulo, b.cod_modalidad, b.cod_moneda, b.nro_solicitud,
             (a.mto_capital+a.mto_interes) Monto
      FROM pr_cuotas a, pr_cta_prestamos b
      WHERE a.nro_cuenta = b.nro_cuenta
        AND a.nro_cuenta = P_NRO_CUENTA
        AND (nvl(a.sal_capital,0) <> 0 or
             nvl(a.sal_interes,0) <> 0 or
             nvl(a.sal_int_documentado,0) <> 0)
        AND (
                --TRUNC(a.fec_vencimiento) > nvl(P_FEC_INI_VIGENCIA,v_fec_min_vto_cuota)
                a.nro_cuota = p_cuota_futura
                AND TRUNC(a.fec_vencimiento) < (p_fecha)
             );
BEGIN
   begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end;
   v_cod_moneda := 'X';
   v_tot_mon_cargo_aux :=0;
   ------------------------------------------------------
   --------------------- PRESTAMOS ----------------------
   ------------------------------------------------------
   IF nvl(fug_obt_pardinamico('COS_REAL_IND_ACTIVO',6), 'N') = 'S' THEN
      FOR rg_cuo_futuro IN c_cuo_futuro LOOP
         IF v_cod_moneda <> rg_cuo_futuro.cod_moneda THEN
              v_cod_moneda := rg_cuo_futuro.cod_moneda;
              v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                             rg_cuo_futuro.cod_modulo,rg_cuo_futuro.cod_modalidad,rg_cuo_futuro.cod_moneda);
         END IF;
         --
         --IF p_iva = 'N' THEN
            v_mon_cargo := 0;
            v_dias := p_fecha - rg_cuo_futuro.fec_ini_vigencia;
            v_cod_tasa := null;

            pag_gen.pr_obt_val_tasa(rg_cuo_futuro.cod_modulo   ,
                                  rg_cuo_futuro.cod_modalidad,
                                  rg_cuo_futuro.cod_oficina  ,
                                  rg_cuo_futuro.nro_cuenta   ,
                                  rg_cuo_futuro.cod_moneda   ,
                                  v_dias                ,
                                  'N'                   ,
                                  v_cod_tasa            ,
                                  7712                  ,
                                  g_fec_calculo         ,
                                  v_val_tasa            ,
                                  v_fec_vigencia        ,
                                  v_tip_valor           ,
                                  v_tipo                );
            v_mon_cargo := round((rg_cuo_futuro.monto * v_val_tasa/100),v_redondeo);
            v_tot_mon_cargo_aux := v_tot_mon_cargo_aux + v_mon_cargo;
            --            
         --IF P_IVA = 'S' THEN
            --
            if nvl(v_mon_cargo,0) > 0 then
               v_tra_iva_cargos    := null;
               lp_obt_tra_iva_asociada(7712,rg_cuo_futuro.cod_modulo,rg_cuo_futuro.cod_modalidad,v_tra_iva_cargos);
               if v_tra_iva_cargos is not null then
                   v_cod_tasa_cargos := null;
                   pag_gen.pr_obt_val_tasa(rg_cuo_futuro.cod_modulo   ,
                                        rg_cuo_futuro.cod_modalidad,
                                        rg_cuo_futuro.cod_oficina  ,
                                        rg_cuo_futuro.nro_cuenta   ,
                                        rg_cuo_futuro.cod_moneda   ,
                                        0                     ,
                                        'N'                   ,
                                        v_cod_tasa_cargos     ,
                                        v_tra_iva_cargos      ,
                                        g_fec_calculo         ,
                                        v_val_tasa            ,
                                        v_fec_vigencia        ,
                                        v_tip_valor           ,
                                        v_tipo                );
                   v_iva_cargos := nvl(v_iva_cargos,0)+ round((v_mon_cargo * v_val_tasa / 100),v_redondeo);
                   v_tot_mon_cargo_aux := v_tot_mon_cargo_aux + v_iva_cargos;
              end if;
            end if;
            --
            BEGIN
               insert into PR_SIM_COB_COBRANZAS_TMP( nro_cuenta, nro_cuota, fec_valor, fec_vencimiento  ,
                              estado             , sal_capital_pre       , sal_interes_pre    , sal_capital_cuo  ,
                              sal_interes_cuo    , sal_int_documentado   , fec_ult_pago       , dia_mora         ,
                              mto_capital        , mto_interes           , mto_int_documentado, mto_int_moratorio,
                              mto_int_mor_interes, mto_int_mor_adelantado, mto_int_punitorio  , mto_cargo        ,
                              mto_cargo_iva      , mto_impuesto          , mto_int_descontado , nro_documento    ,
                              mto_int_mor_cal    , mto_int_mor_int_cal   , mto_int_mor_ade_cal, mto_int_pun_cal  ,
                              mto_cargo_cal      , mto_car_iva_cal       , mto_impuesto_cal   , mto_int_mor_des  ,
                              mto_int_mor_int_des, mto_int_mor_ade_des   , mto_int_pun_des    , mto_car_des      ,
                              dev_acumulado      , dev_no_cobrado        , dev_suspenso, usu_insercion,
                              fec_insercion, usu_modificacion, fec_modificacion)
                     values ( rg_cuo_futuro.nro_cuenta, p_cuota_futura, p_fecha , rg_cuo_futuro.fec_ini_vigencia,
                              rg_cuo_futuro.estado, 0, 0, 0,
                              0  , 0, null, v_dias,
                              0  , 0, 0, 0,
                              0  , 0, 0, v_mon_cargo,
                              v_iva_cargos  , 0, 0, 1,
                              0  , 0, 0, 0,
                              0  , 0, 0, 0,
                              0  , 0, 0, 0,
                              0  , 0, 0,
                              user, sysdate, user, sysdate);               
            EXCEPTION
               WHEN OTHERS THEN
                 NULL;
            END;
            --
         --END IF;
      END LOOP;
      commit;
      --IF P_IVA = 'N' THEN
          return v_tot_mon_cargo_aux;
     -- ELSE
      --    RETURN v_iva_cargos;
      --END IF;
   END IF;
END FU_INS_GAS_COB_FUTURA;

FUNCTION FU_OBT_MAX_FEC_INI_VIGENCIA (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
                                      , p_max_fec_vigencia IN DATE
                                      , p_max_fec_vigencia_ant IN DATE)
RETURN DATE
IS
   v_max_fec_vto   pr_cuotas.fec_vencimiento%type;
BEGIN
    select max(fec_ini_vigencia)
    into v_max_fec_vto
    from pr_cta_gastos
    where nro_cuenta    = P_NRO_CUENTA
       --and cod_modalidad = rg_pcpre.cod_modalidad
        and cod_transaccion = 7712
        and fec_ult_pago is null
        and (fec_ini_vigencia <= p_fecha or p_fecha is null );
   /*select max(fec_ini_vigencia)
   into v_max_fec_vto
   from pr_cta_gastos
   where nro_cuenta    = P_NRO_CUENTA
      --and cod_modalidad = rg_pcpre.cod_modalidad
      and cod_transaccion = 7712

      and (((fec_ini_vigencia <= p_fecha or p_fecha is null )
      and  (fec_ini_vigencia >  p_max_fec_vigencia_ant or p_max_fec_vigencia_ant is null  or fec_ini_vigencia is null)
      and   nro_solicitud is not null)
      or  ((fec_vencimiento  >= p_max_fec_vigencia or fec_vencimiento is null) and nro_solicitud is null and g_cal_adic = 'S'))
      and fec_ult_pago is null;
   */
   return v_max_fec_vto;
END FU_OBT_MAX_FEC_INI_VIGENCIA;

FUNCTION FU_OBT_MAX_CUOTA_PRESTAMO(P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
                                   , p_max_fec_vigencia IN DATE)
RETURN NUMBER
IS
   v_max_cuota pr_cuotas.nro_cuota%type;
BEGIN
   select MIN(nro_cuota)
   into v_max_cuota
       from pr_cuotas
      where nro_cuenta = p_nro_cuenta
        and (nvl(sal_capital,0) <> 0 or
             nvl(sal_interes,0) <> 0 or
             nvl(sal_int_documentado,0) <> 0 )
        and (p_nro_cuo_desde is not null and p_nro_cuo_hasta is not null
              and nro_cuota >= nvl(p_nro_cuo_desde,0)
              and nro_cuota <= nvl(v_nro_cuo_hasta,999)
              and fec_vencimiento >= p_max_fec_vigencia);
             /*or
             (fec_vencimiento > p_max_fec_vigencia
              and p_nro_cuo_desde is null
              and v_nro_cuo_hasta is null))
      order by fec_vencimiento;*/

   return v_max_cuota;
END;

/* Recupera el codigo de personas del deudor de la cuenta */
FUNCTION FU_OBT_DEUDOR (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE) 
 RETURN VARCHAR2 IS
   v_cod_persona ba_personas.cod_persona%type;
BEGIN
   select cct.cod_persona
     into v_cod_persona
     from ge_clientes cli, ge_cta_clientes cct
    where cct.cod_persona = cli.cod_persona
      and cct.nro_cuenta  = p_nro_cuenta
      and cct.relacion    = 'P';
   return v_cod_persona;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
     RETURN NULL;
   WHEN OTHERS THEN
     RETURN NULL;     
END;

FUNCTION FU_ES_SEGMENTO_EMPRESAS(P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE)
RETURN VARCHAR
IS
       v_existe VARCHAR(1) := 'N';
BEGIN
   SELECT 'S'
   INTO v_existe
  
   FROM ( SELECT nvl(b.significado,a.SGTO_VALOR_2013) SEGMENTO, 
                 nvl(c.significado,a.SGTO_ACIDO_ESTRUCTURAL) SUB_SEGMENTO, 
                 a.SGTO_INTERNO ACTIVIDAD, 
                trunc(pag_cal.fu_obt_fec_habil( to_date('01/' || 
                lpad(decode( to_char(a.FH_INFORMACION,'mm'), '12', '1', to_char(a.FH_INFORMACION,'mm') + 1  ),2,'0')|| 
                '/' ||to_char(a.FH_INFORMACION,'yyyy'),'dd/mm/yyyy')-1,-1,1)) FEC_SEGMENTO
               
          FROM dw_cli_segmentos a,
               ba_cod_referencias b,
               ba_cod_referencias c
          WHERE to_number(a.NU_CTE) = to_number(P_COD_PERSONA)
				        and a.SGTO_VALOR_2013 = b.val_minimo(+)
				        and b.dominio(+) = 'DES_SEG_ESTRUCTURAL'
				        and a.SGTO_ACIDO_ESTRUCTURAL = c.val_minimo (+)
				        and c.dominio(+) = 'DES_SUB_SEG_ESTRUCTURAL'          
				  ORDER BY FH_INFORMACION desc)
    WHERE SEGMENTO IN ('EMPRESAS','INSTITUCIONES')
    AND rownum = 1;
    
    RETURN v_existe;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN v_existe;
  WHEN OTHERS THEN
    RETURN v_existe;
END; 

BEGIN
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 6; end;
  g_cod_aut_cargos    := null;
   -- Recuperar datos del prestamo
   pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);

   if fup_obt_tip_descuento(r_pcpre.cod_modalidad) not in ('F','D','C') then
      v_min_cuo_vencida := pap_pre.fu_obt_min_cuo_ven(p_nro_cuenta, p_fecha);
      if p_nro_cuo_desde > v_min_cuo_vencida then
         p_error   := 20;
         p_mensaje := 'No se pueden cancelar cuotas posteriores a la minima pendiente '||v_min_cuo_vencida;
         return;
      end if;
   end if;

   if p_fecha < pag_cal.fu_obt_fec_actual(6) then
      select max(fec_ult_pago)
        into v_fec_ult_pago
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta;
   end if;

   --- Cargar parametros de ser necesario
   if p_nro_cuo_desde is not null and p_nro_cuo_hasta is null then
      v_nro_cuo_hasta := pap_pre.fu_obt_max_cuo_ven(p_nro_cuenta, p_fecha);
   else
      v_nro_cuo_hasta := p_nro_cuo_hasta;
   end if;

   g_max_fec_calculo_ant         := null;
   g_cal_adic                    := 'S';
   v_exo_impuesto                := FU_OBT_EXO_IMPUESTO(p_nro_cuenta);
   v_redondeo                    := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, r_pcpre.cod_modalidad, r_pcpre.cod_moneda);
   v_tot_cargo                   := 0;
   v_tot_cargo_iva               := 0;
   v_tot_otr_cargo               := 0;
   v_tot_otr_cargo_iva           := 0;

   Select count(*)
     into v_iva
    from pr_sol_cargos
   where nro_solicitud = r_pcpre.nro_solicitud
     and cod_Transaccion = 709;

   --- Monto cobrado --- Si se ingresa el monto cobrado calcular en base al mismo
   v_sal_cobrado := p_mto_cobrado;

   -- Eliminar registros en el temporal de cargos futuros
   for tem in c_tab_temporal loop
     delete PR_SIM_COB_COBRANZAS_TMP z where rowid = tem.registro;
   end loop;

   --- Recuperar autorizaciones previas
   lp_rec_aut_prev;

  -- Si el pago es en forma Parcial no debe calcular el devengado del dia del cobro
   if p_cancela != 'P' then
     if nvl(r_pcpre.fec_ult_devengado,r_pcpre.fec_inicio) < p_fecha then
         pap_cob.PR_PRO_DEV_CUOTAS(p_fecha, p_nro_cuenta);
     end if;
   End If;
   --- Recorrer cuotas
   for cuo in c_cuotas loop
      --- Inicializar variables por cuota
      v_sal_capital           := 0;
      v_sal_interes           := 0;
      v_mora                  := 0;
      v_mora_int_ade          := 0;
      v_mora_interes          := 0;
      v_cargo                 := 0;
      v_cargo_iva             := 0;
      v_car_seguro            := 0;
      v_car_adicional         := 0;
      v_car_manual            := 0;
      v_car_manual_iva        := 0;
      v_Car_restante          := 0;
      v_Car_restante_iva      := 0;
      v_int_descontado        := 0;
      v_cap_adelantado        := 0;
      v_mto_ant               := 0;
      v_mto_int_mor_des       := 0;
      v_mto_int_mor_int_des   := 0;
      v_mto_int_mor_ade_des   := 0;
      v_mto_int_pun_des       := 0;
      v_mto_car_des           := 0;
      v_sal_int_ant           := 0;
      v_mto_dev_actual        := 0;
      r_pctmp.nro_cuenta      := p_nro_cuenta;
      r_pctmp.nro_cuota       := cuo.nro_cuota;
      r_pctmp.fec_vencimiento := cuo.fec_vencimiento;
      r_pctmp.estado          := cuo.estado;
      r_pctmp.fec_valor       := p_fecha;
      if p_fecha > cuo.fec_vencimiento then
         r_pctmp.dia_mora := p_fecha - cuo.fec_vencimiento;
      else
         r_pctmp.dia_mora := 0;
      end if;
      IF p_cancel_rrr = 'S' THEN
          r_pctmp.mto_capital := 0;
          v_sal_capital := r_pctmp.mto_capital;
          IF cuo.fec_vencimiento > p_fecha
          AND cuo.fec_vencimiento > pag_cal.fu_obt_fec_actual(6) THEN
              r_pctmp.mto_interes := pap_cob.fu_obt_dev_anticipado(p_nro_cuenta, cuo.nro_cuota);
              r_pctmp.mto_interes := NVL(r_pctmp.mto_interes, 0)
                                   + NVL(cuo.dev_no_cobrado, 0)
                                   + NVL(cuo.dev_suspenso, 0);
          END IF;
      END IF;

      IF NVL(p_cancel_rrr,'N') != 'S' and NVL(P_CANCELA,'N') = 'T' THEN
          IF cuo.fec_vencimiento > pag_cal.fu_obt_fec_actual(6) THEN
              begin
                select nvl(d.mto_dev_actual,0)
                  into v_mto_dev_actual
                  from pr_devengados_tmp d
                 where nro_cuenta = p_nro_cuenta
                   and nro_cuota = cuo.nro_cuota;
              exception
                when others then
                  v_mto_dev_actual := 0;
              end;
              r_pctmp.mto_interes := r_pctmp.mto_interes + v_mto_dev_actual;
          END IF;
      END IF;
      g_renueva                   := p_renueva;
      v_sal_interes               := r_pctmp.mto_interes;
      r_pctmp.sal_capital_pre     := r_pcpre.sal_capital;
      r_pctmp.sal_interes_pre     := r_pcpre.sal_interes;
      r_pctmp.sal_capital_cuo     := cuo.sal_capital;
      r_pctmp.sal_interes_cuo     := cuo.sal_interes;
      r_pctmp.nro_documento       := cuo.nro_documento;
      r_pctmp.fec_ult_pago        := cuo.fec_ult_pago;
      r_pctmp.sal_int_documentado := cuo.sal_int_documentado;
      r_pctmp.mto_int_mor_cal     := v_mora;
      r_pctmp.mto_int_mor_int_cal := v_mora_interes;
      r_pctmp.mto_int_mor_ade_cal := v_mora_int_ade;
      r_pctmp.mto_int_pun_cal     := v_punitorio;
      v_impuesto := 0;
      IF v_exo_impuesto = 'N' Then
        v_impuesto                := pap_pre.fu_obt_concepto('IM',r_pcpre, cuo, r_pctmp, p_fecha);
      End if;
      r_pctmp.mto_impuesto_cal    := v_impuesto;
      if cuo.fec_vencimiento =  fu_obt_max_fec_vto(p_nro_cuenta, 999) then
         g_max_fec_calculo  := nvl(fu_obt_max_fec_cargo(p_nro_cuenta),fu_obt_max_fec_vto(p_nro_cuenta, 999));
      else
         g_max_fec_calculo  := cuo.fec_vencimiento;
      end if;
      if NVL(P_CANCELA,'N') not in ('T','P') then
          PR_OBT_CARGO_MTO_PLZ(r_pcpre, cuo, r_pctmp, p_fecha, P_TRA_CARGO, P_VAL_CARGOS, P_VAL_CARGOS_IVA, P_VAL_VARIOS, P_VAL_VARIOS_IVA);

      Else
          PR_OBT_CARGO_MTO_PLZ(null   , cuo, r_pctmp, p_fecha, P_TRA_CARGO, P_VAL_CARGOS, P_VAL_CARGOS_IVA, P_VAL_VARIOS, P_VAL_VARIOS_IVA);
      End If;

      -- Recalcular los cargos por cobranzas
      v_cod_persona_titular := FU_OBT_DEUDOR(p_nro_cuenta);      

      IF v_cod_persona_titular is not null THEN
          if FU_ES_SEGMENTO_EMPRESAS(v_cod_persona_titular) = 'N' THEN -- Se excluye segmento empresas
              PR_OBT_CARGO_COBRANZAS(p_nro_cuenta, cuo.fec_vencimiento, cuo.nro_cuota, P_VAL_CARGOS, P_VAL_CARGOS_IVA);
          ELSE 
              P_VAL_CARGOS := 0;
              P_VAL_CARGOS_IVA := 0;
          END IF;
      ELSE
         PR_OBT_CARGO_COBRANZAS(p_nro_cuenta, cuo.fec_vencimiento, cuo.nro_cuota, P_VAL_CARGOS, P_VAL_CARGOS_IVA);
      END IF;

      -- Actualizar pr_cobros_tmp con montos recalculados para el cargo + iva      
      BEGIN
        UPDATE PR_COBROS_TMP
          SET MTO_CARGO = P_VAL_VARIOS, MTO_CARGO_IVA = P_VAL_VARIOS_IVA
          WHERE NRO_CUENTA = P_NRO_CUENTA
            AND NRO_CUOTA = CUO.NRO_CUOTA;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;        
      END;
      
      COMMIT;
      -- Totalizadores para el formulario 
      v_tot_cargo          := nvl(v_tot_cargo,0)          + NVL(P_VAL_CARGOS,0);
      v_tot_cargo_iva      := nvl(v_tot_cargo_iva,0)      + NVL(P_VAL_CARGOS_IVA,0);
      v_tot_otr_cargo      := nvl(v_tot_otr_cargo,0)      + nvl(P_VAL_VARIOS,0);
      v_tot_otr_cargo_iva  := nvl(v_tot_otr_cargo_iva,0)  + nvl(P_VAL_VARIOS_IVA,0);
     
      Select sum(monto)
        into v_car_adic
        from pr_cta_gastos
       where nro_cuenta = r_pcpre.nro_cuenta
         and (fec_vencimiento  >= g_fec_calculo or fec_vencimiento is null)
         and fec_ult_pago is null
         and nro_solicitud is null;
      if v_car_adic > 0 then
         g_cal_adic := 'N';
      end if;
      
      g_max_fec_calculo_ant := g_max_fec_calculo;
      v_ult_dia_calculado := cuo.nro_cuota;
   end loop;
   p_tot_cargo          := v_tot_cargo;
   p_tot_cargo_iva      := v_tot_cargo_iva;
   P_TOT_OTR_CARGO      := v_tot_otr_cargo;
   P_TOT_OTR_CARGO_IVA  := v_tot_otr_cargo_iva;
   --   
END PRP_OBT_CAR_PRESTAMO;
/

