CREATE OR REPLACE PACKAGE BODY IT.PAV_OVE IS
 v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
G_COD_MON_LOCAL BA_MONEDAS.COD_MONEDA%TYPE;
/* Recuperar valor del concepto de cobro para los datos del parámetro. */
FUNCTION FU_OBT_CONCEPTO
 (P_CONCEPTO IN PR_COB_PRIORIDADES.CONCEPTO%TYPE
 ,RP_PCPRE IN OV_CTA_VENCIDAS%ROWTYPE
 ,RP_PCTMP IN OUT OV_COBROS_TMP%ROWTYPE
 ,P_FECHA IN DATE
 )
 RETURN NUMBER
 IS
  v_rutina     pr_cob_prioridades.fun_calculo%type;
  v_sentencia  varchar2(1500);
  v_error      varchar2(200);
BEGIN
   --- Inicializar variables globales
   v_fecha := p_fecha;
   pav_ove.rg_opeven := RP_PCPRE;
   pav_ove.rg_pctmp  := RP_PCTMP;
      --- Recuperar nombre del procedimiento que ejecuta la función
      begin
         select fun_calculo into v_rutina
           from pr_cob_prioridades
          where nvl(cod_modulo,nvl(rp_pcpre.cod_modulo,15)) = nvl(rp_pcpre.cod_modulo,15)
            and nvl(cod_modalidad,nvl(rp_pcpre.cod_modalidad,-1)) = nvl(rp_pcpre.cod_modalidad,-1)
            and concepto = p_concepto;
      exception
         when no_data_found then
            raise_application_error(-20000,
            'No existe rutina de calculo para concepto '||p_concepto||' Modalidad '||rp_pcpre.cod_modalidad);
         when too_many_rows then
            begin
               select fun_calculo into v_rutina
                 from pr_cob_prioridades
                where cod_modulo = nvl(rp_pcpre.cod_modulo,15)
                  and cod_modalidad = nvl(rp_pcpre.cod_modalidad,-1)
                  and concepto = p_concepto;
            exception
                when no_data_found then
                   raise_application_error(-20000,
                  'No existe rutina de calculo para concepto '||p_concepto||' Modalidad '||rp_pcpre.cod_modalidad);
            end;
      end;
   --end if;
   v_error     := null;
   v_sentencia := 'BEGIN '||v_rutina||'; END;';
   sql_util.ejecute_dml(v_sentencia, v_error);
   if v_error is not null then
      raise_application_error(-20000,'Ejecutar Concepto '||p_concepto||' '||v_error);
   end if;
   --- Actualizar parámetros de salida
   rp_pctmp := pav_ove.rg_pctmp;
   return pap_cob.g_val_retorno;
END;
/* Obtiene la autorizacion previa del concepto. */
PROCEDURE PR_OBT_AUT_PREVIA
 (P_NRO_CUENTA IN GE_AUTORIZACIONES.NRO_CUENTA%TYPE
 ,P_FECHA IN GE_AUTORIZACIONES.FEC_VENCIMIENTO%TYPE
 ,P_COD_TRA_PADRE IN GE_AUTORIZACIONES.COD_TRA_PADRE%TYPE
 ,P_COD_MOD_PADRE IN GE_AUTORIZACIONES.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_AUTORIZACIONES.COD_MAD_PADRE%TYPE
 ,P_COD_TRANSACCION IN GE_AUTORIZACIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_AUTORIZACIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_AUTORIZACIONES.COD_MODALIDAD%TYPE
 ,P_MONTO IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 ,P_EXIMIDO IN OUT GE_AUTORIZACIONES.EXIMIDO%TYPE
 ,P_COD_AUTORIZACION IN OUT GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_COD_USU_AUTORIZADOR IN OUT GE_AUTORIZACIONES.COD_USU_AUTORIZADOR%TYPE
 )
 IS
BEGIN
   -- Busco los datos de la autorizacion
   Select COD_AUTORIZACION, VALOR, EXIMIDO, COD_USU_AUTORIZADOR
     into p_cod_autorizacion, P_MONTO, P_EXIMIDO, p_cod_usu_autorizador
     from GE_AUTORIZACIONES
    where NRO_CUENTA      = p_nro_cuenta
      and COD_TRANSACCION = p_cod_transaccion
      and cod_modulo      = p_cod_modulo
      and cod_modalidad   = p_cod_modalidad
      and COD_TRA_padre   = 139
      and cod_mod_padre   = p_cod_mod_padre
      and cod_mad_padre   = p_cod_mad_padre
      and cod_usu_utilizador is null    -- que no fue utilizado por nadie
      and fec_vencimiento    >= p_fecha -- que no este vencido
      and rownum = 1;                   -- el primero que exista
EXCEPTION
   when no_data_found then
      p_cod_autorizacion := null;
      p_monto            := null;
      p_eximido          := null;
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20001, 'Error en PR_OBT_AUTORIZACION '||sqlerrm);
      end if;
END;
/* Obtener la transaccion segun el concepto en base a datos de entrada. */
FUNCTION FU_OBT_TRA_CONCEPTO
 (P_CONCEPTO IN PR_COB_PRIORIDADES.CONCEPTO%TYPE
 ,P_ESTADO IN OV_CTA_VENCIDAS.ESTADO%TYPE
 )
 RETURN NUMBER
 IS
v_cod_transaccion ge_transacciones.cod_transaccion%type := NULL;
BEGIN
   if p_concepto = 'CA' then   --- Capital
     if p_estado in ('C','A','N') then  --- Cuota Vigente o Vigente atrazada
       v_cod_transaccion := 801;
     end if;
     if p_estado in ('V') then --- Cuota Vencida
       v_cod_transaccion := 820;
     end if;
     if p_estado in ('G') then --- Cuota En Gestion
       v_cod_transaccion := 822;
     end if;
     if p_estado in ('M','I') then --- Cuota Morosa o Irrecuperable
       v_cod_transaccion := 823;
     end if;
   end if;
   if p_concepto in ('IA','IN') then   --- Interés o Interés Adelantado
     if p_estado in ('C','A','N') then
       if p_concepto = 'IA' then
         v_cod_transaccion := 806;
       elsif p_concepto = 'IN' then
         v_cod_transaccion := 802;
       end if;
     end if;
     if p_estado = 'V' then
       if p_concepto = 'IA' then
         v_cod_transaccion := 814;
       elsif p_concepto = 'IN' then
         v_cod_transaccion := 817;
       end if;
     end if;
     if p_estado = 'G' then
       if p_concepto = 'IA' then
         v_cod_transaccion := 818;
       elsif p_concepto = 'IN' then
         v_cod_transaccion := 825;
       end if;
     end if;
     if p_estado in ('M','I') then
       if p_concepto = 'IA' then
         v_cod_transaccion := 826;
       elsif p_concepto = 'IN' then
         v_cod_transaccion := 828;
       end if;
     end if;
   end if;
   if p_concepto = 'MO' then  --- Mora sobre capital
     if p_estado in ('C','A','N') then
       v_cod_transaccion := 810;
     end if;
     if p_estado = 'V' then
        v_cod_transaccion := 815;
     end if;
     if p_estado = 'G' then
        v_cod_transaccion := 819;
     end if;
     if p_estado IN ('M','I') then
        v_cod_transaccion := 827;
     end if;
   end if;
   if p_concepto = 'MI' then   --- Mora sobre interés
     if p_estado in ('C','A','N') then --- Vigente o Vigente vencida
       v_cod_transaccion := 835;
     elsif p_estado = 'V' then
       v_cod_transaccion    := 837;
     elsif p_estado = 'G' then
       v_cod_transaccion    := 838;
     elsif p_estado IN ('M','I') then
       v_cod_transaccion    := 839;
     end if;
   end if;
   if p_concepto = 'MA' then --- Mora sobre interés adelantado
     if p_estado in ('C','A','N') then --- Vigente o Vigente vencida
       v_cod_transaccion := 830;
     elsif p_estado = 'V' then
       v_cod_transaccion    := 832;
     elsif p_estado = 'G' then
       v_cod_transaccion    := 833;
     elsif p_estado IN ('M','I') then
       v_cod_transaccion    := 834;
     end if;
   end if;
   if p_concepto = 'PU' then --- Punitorio
     v_cod_transaccion    := 849;
   end if;
   if p_concepto = 'IM' then --- Impuestos
     v_cod_transaccion    := 709;
   end if;
   if p_concepto = 'CG' then --- Cargos
     v_cod_transaccion    := 712;
   end if;
   return NVL(v_cod_transaccion,-1); --- Para que de error de transaccion si no recupera nada
END;

PROCEDURE PR_OBT_MOR_CAPITAL
 IS
  v_redondeo      number(1);
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OV_CTA_VENCIDAS.FEC_ULT_MOVIMIENTO%TYPE
 )
 RETURN DATE;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_MTO_NO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 );
--- Variables auxiliares
   v_mora              ov_cta_vencidas.sal_total%type;
   v_dias              number(10);
   v_fec_ult_pag_mora  ov_cta_vencidas.fec_ult_movimiento%type;
   v_mor_no_pag        ov_cta_vencidas.sal_total%type;
   v_mor_pag           ov_cta_vencidas.sal_total%type;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil  date;
v_fec_actual date;
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual then
         -- si el siguiente día habil no es hoy se le debe cobrar mora.
         return 'S';
      else
         -- No es dia habil, no corresponde cobrar mora
         return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OV_CTA_VENCIDAS.FEC_ULT_MOVIMIENTO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
   /*select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and exists
         (select 1
            from ge_gru_transacciones gru, ge_gru_transacciones_det det
           where gru.cod_gru_transaccion = fug_obt_pardinamico('COD_GRU_PAG_MORA')
             and gru.cod_gru_transaccion = det.cod_gru_transaccion
             and det.cod_modulo          = mov.cod_modulo
             and det.cod_modalidad       = mov.cod_modalidad
             and det.cod_transaccion     = mov.cod_transaccion);*/
   if v_max_fec_pago is null then
      select max(fec_ult_pago)
        into v_max_fec_pago
        from ov_cobros t
       where nro_cuenta = p_nro_cuenta;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_MTO_NO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_mor_cal,0)-(nvl(c.mto_int_moratorio,0)+nvl(c.mto_int_mor_des,0))),0),
          nvl(sum(nvl(c.mto_int_moratorio,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from ov_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from ov_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and ( (nvl(p.mto_int_moratorio,0)+nvl(p.mto_int_mor_des,0) <> 0)
                 or (nvl(p.mto_int_mor_cal,0) <> 0) )
              and p.fecha =
                 (select max(p1.fecha)
                    from ov_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and ( (nvl(p1.mto_int_moratorio,0)+nvl(p1.mto_int_mor_des,0) <> 0)
                        or (nvl(p1.mto_int_mor_cal,0) <> 0) )
                 )
          );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
BEGIN
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, rg_opeven.cod_moneda);
  --- Calcular mora capital
  if v_fecha > rg_opeven.fec_apertura then
     v_dias := v_fecha - rg_opeven.fec_apertura;
     v_fec_ult_pag_mora := lf_obt_ult_pag_mora(rg_opeven.nro_cuenta, v_fecha);
     if v_fec_ult_pag_mora is not null and v_fec_ult_pag_mora > rg_opeven.fec_apertura then
        v_dias := v_fecha - v_fec_ult_pag_mora;
     end if;
     v_mora := round((rg_opeven.sal_total * rg_opeven.val_tasa * v_dias/36500),v_redondeo);
     --- Recuperar montos de pagos anteriores
     lp_obt_mora_pag_ant(rg_opeven.nro_cuenta,  v_mor_no_pag, v_mor_pag);
     v_mora := round(nvl(v_mora,0) + nvl(v_mor_no_pag,0),v_redondeo);
  else
     v_mora         := 0;
  end if;
  pap_cob.g_val_retorno      := v_mora;
  rg_pctmp.mto_int_moratorio := v_mora;
  rg_pctmp.mto_int_mor_cal   := v_mora;
END;

/*Inicializar modulo*/
PROCEDURE PR_INI_MODULO
 IS
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;

/* Obtener interés punitorio */
PROCEDURE PR_OBT_PUNITORIO
 IS
PROCEDURE LP_OBT_PUN_PAG_ANT
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_MTO_NO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 );
   v_cargo             pr_cuotas.sal_interes%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   v_redondeo          number(02);
   v_dias              number(10);
   v_por_tasa          number(07,2);
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_pun_no_pag        pr_cobros.mto_impuesto%type;
   v_pun_pag           pr_cobros.mto_impuesto%type;
   v_fec_ult_pag_puni  pr_cuotas.fec_ult_pago%type;
   --v_cobra_mora        varchar2(01);

PROCEDURE LP_OBT_PUN_PAG_ANT
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_MTO_NO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT OV_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_pun_cal,0)-(nvl(c.mto_int_punitorio,0) + nvl(c.mto_int_pun_des,0))),0),
          nvl(sum(nvl(c.mto_int_punitorio,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from ov_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from ov_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and ( (nvl(p.mto_int_punitorio,0) + nvl(p.mto_int_pun_des,0) <> 0)
                 or (nvl(p.mto_int_pun_cal,0) <> 0) )
              and p.fecha =
                 (select max(p1.fecha)
                    from ov_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and ( (nvl(p1.mto_int_punitorio,0) + nvl(p1.mto_int_pun_des,0) <> 0)
                        or (nvl(p1.mto_int_pun_cal,0) <> 0) )
                 )
          );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil date;
v_fec_actual date;
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual then
         -- si el siguiente día habil no es hoy se le debe cobrar mora.
         return 'S';
      else
         -- No es dia habil, no corresponde cobrar mora
         return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de punitorio */
FUNCTION LF_OBT_ULT_PAG_PUNI
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OV_CTA_VENCIDAS.FEC_ULT_MOVIMIENTO%TYPE
 )
 RETURN DATE;
/* Obtener ultimo pago de punitorio */
FUNCTION LF_OBT_ULT_PAG_PUNI
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN OV_CTA_VENCIDAS.FEC_ULT_MOVIMIENTO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
  /* select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.cod_transaccion = 849; -- Transaccion de Punitorio*/
   if v_max_fec_pago is null then
      select max(fec_ult_pago)
        into v_max_fec_pago
        from ov_cobros t
       where nro_cuenta = p_nro_cuenta;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
BEGIN
  v_dias := v_fecha - rg_opeven.fec_apertura;
  v_fec_ult_pag_puni := lf_obt_ult_pag_puni(rg_opeven.nro_cuenta, v_fecha);
  if v_fec_ult_pag_puni is not null and v_fec_ult_pag_puni > rg_opeven.fec_apertura then
     v_dias := v_fecha - v_fec_ult_pag_puni;
  end if;
  --- Calcular cargos
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, rg_opeven.cod_moneda);
  if v_dias > 0 then
    if fug_obt_tip_implementacion = 1 then
       -- solo se toma el capital en el BR.
       v_mto_cuota := nvl(rg_opeven.sal_total,0);--nvl(rg_pctmp.sal_capital_cuo,0);
    else
       v_mto_cuota        :=  nvl(rg_opeven.sal_total,0);--nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_interes_cuo,0)+nvl(rg_pctmp.sal_int_documentado,0);
    end if;
    --- Recuperar porcentaje de tasa a aplicar sobre tasa original
    v_por_tasa         := fug_obt_pardinamico('POR_TAS_PUNITORIO', rg_opeven.cod_modulo, rg_opeven.cod_modalidad,
                                              rg_opeven.cod_moneda, rg_opeven.cod_oficina);
    v_val_tasa         := rg_opeven.val_tasa * v_por_tasa / 100;
    v_cargo := round(v_mto_cuota * v_val_tasa * v_dias / 36500 ,v_redondeo);
    --
  else
    v_cargo := 0;
  end if;
  --- Recuperar montos de pagos anteriores
  lp_obt_pun_pag_ant(rg_opeven.nro_cuenta, v_pun_no_pag, v_pun_pag);
  v_cargo                    := round(nvl(v_cargo,0) + nvl(v_pun_no_pag,0),v_redondeo);
  pap_cob.g_val_retorno      := v_cargo;
  rg_pctmp.mto_int_punitorio := v_cargo;
  rg_pctmp.mto_int_pun_cal   := v_cargo;
END;
/* Permite obtener los datos de la operación vencida. */
PROCEDURE PR_OBT_DAT_OPE_VENCIDA
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_GOPVEN IN OUT OV_CTA_VENCIDAS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_gopven
     from OV_CTA_VENCIDAS --x nro. de cuenta original
    where nro_cuenta = p_nro_cuenta;
exception
   when no_data_found then
      raise_application_error(-20000,'Cuenta Vencida '||p_nro_cuenta||' no registrada');
END;
/* Obtener la deuda de la operación vencida. */
PROCEDURE PR_OBT_DEU_OPE_VENCIDA
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN DATE
 ,P_MTO_COBRADO IN OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_ERROR IN OUT NUMBER
 ,P_MENSAJE IN OUT VARCHAR2
 ,P_TOT_CAPITAL IN OUT OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_TOT_MORA IN OUT OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_TOT_PUNITORIO IN OUT OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_TOT_IMPUESTO IN OUT OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_TOT_CARGO IN OUT OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_TOT_CARGO_IVA IN OUT OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_DIA_MORA IN OUT OV_CTA_VENCIDAS.DIA_ATRASO%TYPE
 ,P_COD_TRA_PADRE IN NUMBER default 139
 )
 IS

/* Insertar cobros temporales. */
PROCEDURE LP_INS_PR_COBROS_TMP
 (RP_PCTMP IN OV_COBROS_TMP%ROWTYPE
 );
/* Utilizar autorización previa */
PROCEDURE LP_UTI_AUT_PRE
 (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_EXIMIDO IN GE_AUTORIZACIONES.EXIMIDO%TYPE
 ,P_VALOR IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 ,P_MONTO IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 );
/* Recuperar autorizaciones previas. */
PROCEDURE LP_REC_AUT_PREV;
/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
   r_opeven           OV_CTA_VENCIDAS%rowtype;
   r_pctmp            ov_cobros_tmp%rowtype;

   --- Variables auxiliares
   v_sal_cobrado       pr_cuotas.sal_capital%type;
   v_sal_capital       pr_cuotas.sal_capital%type;
   v_sal_interes       pr_cuotas.sal_interes%type;
   v_sal_int_documentado pr_cuotas.sal_int_documentado%type;
   v_int_descontado    pr_cuotas.sal_interes%type;
   v_cap_adelantado    pr_cuotas.sal_capital%type;
   v_mora              pr_cuotas.sal_interes%type;
   v_mora_interes      pr_cuotas.sal_interes%type;
   v_mora_int_ade      pr_cuotas.sal_interes%type;
   v_impuesto          pr_cuotas.sal_interes%type;
   v_cargo             pr_cuotas.sal_interes%type;
   --v_gastos            pr_cuotas.sal_interes%type;
   --v_tot_gastos        pr_cuotas.sal_interes%type;
   v_cargo_iva         pr_cuotas.sal_interes%type;
   v_punitorio         pr_cuotas.sal_interes%type;
   v_tot_capital       pr_cuotas.sal_capital%type;
   v_tot_mora          pr_cuotas.sal_interes%type;
   v_tot_impuesto      pr_cuotas.sal_interes%type;
   v_tot_cargo         pr_cuotas.sal_interes%type;
   v_tot_cargo_iva     pr_cuotas.sal_interes%type;
   v_tot_punitorio     pr_cuotas.sal_interes%type;
   v_cod_mon_local     ba_monedas.cod_moneda%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   --- Variables auxiliares para utilizacion de interés
   v_sal_int_ant       pr_cuotas.sal_interes%type;
   v_mto_int_mor_des   pr_cobros.mto_int_mor_des%type;
   v_mto_int_mor_int_des pr_cobros.mto_int_mor_int_des%type;
   v_mto_int_mor_ade_des pr_cobros.mto_int_mor_ade_des%type;
   v_mto_int_pun_des   pr_cobros.mto_int_pun_des%type;
   v_mto_car_des       pr_cobros.mto_car_des%type;
   ---
   v_cal_ley           number;
   v_cal_dia           number(10);
   v_cal_fac           number;
   v_cal_fac_iva       number;
   v_mto_ant           ov_cta_vencidas.sal_total%type;
   v_redondeo          number(1);
   v_cod_tasa          ge_tasas.cod_tasa%type := null;
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_val_tas_iva       ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_exo_impuesto      ge_clientes.exo_impuestos%type;

   cursor datos is
   select *
     from OV_CTA_VENCIDAS
    where nro_cuenta = p_nro_cuenta
      and nvl(sal_total,0) <> 0 ;

    --- Recuperar prioridad de cobro
    cursor c_prioridades is
    select *
      from pr_cob_prioridades
     where nvl(cod_modulo,nvl(r_opeven.cod_modulo,15)) = nvl(r_opeven.cod_modulo,15)
       and nvl(cod_modalidad,nvl(r_opeven.cod_modalidad,-1)) = nvl(r_opeven.cod_modalidad,-1)
     order by secuencia;

/* Insertar cobros temporales. */
PROCEDURE LP_INS_PR_COBROS_TMP
 (RP_PCTMP IN OV_COBROS_TMP%ROWTYPE
 )
 IS
BEGIN
   insert into ov_cobros_tmp(nro_cuenta, fec_valor,estado, sal_total,
      fec_ult_pago,dia_mora, mto_total,mto_int_moratorio, mto_int_punitorio,
      mto_cargo, mto_cargo_iva, mto_impuesto,nro_documento, mto_int_mor_cal,
      mto_int_pun_cal, mto_cargo_cal, mto_car_iva_cal,
      mto_impuesto_cal,mto_int_mor_des, mto_int_pun_des, mto_car_des)
   values (
      rp_pctmp.nro_cuenta,  rp_pctmp.fec_valor,rp_pctmp.estado, rp_pctmp.sal_total,
      rp_pctmp.fec_ult_pago, rp_pctmp.dia_mora, rp_pctmp.mto_total,rp_pctmp.mto_int_moratorio,
      rp_pctmp.mto_int_punitorio,rp_pctmp.mto_cargo, rp_pctmp.mto_cargo_iva, rp_pctmp.mto_impuesto,
      rp_pctmp.nro_documento, rp_pctmp.mto_int_mor_cal,
      rp_pctmp.mto_int_pun_cal, rp_pctmp.mto_cargo_cal,
      rp_pctmp.mto_car_iva_cal,rp_pctmp.mto_impuesto_cal, rp_pctmp.mto_int_mor_des,
      rp_pctmp.mto_int_pun_des, rp_pctmp.mto_car_des);
END;

/* Recuperar autorizaciones previas. */
PROCEDURE LP_REC_AUT_PREV
 IS
BEGIN
   --- Autorizacion descuento de mora capital
   if pap_cob.g_cod_aut_mor_cap is null then
      pav_ove.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                fu_obt_tra_concepto('MO',r_opeven.estado),
                                r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                pap_cob.g_sal_val_mor_cap, pap_cob.g_exi_mor_cap, pap_cob.g_cod_aut_mor_cap, pap_cob.g_cod_usu_aut_mo);
   end if;
   --- Autorizacion descuento de punitorio
   if pap_cob.g_cod_aut_punitorio is null then
      pav_ove.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                fu_obt_tra_concepto('PU',r_opeven.estado),
                                r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                pap_cob.g_sal_val_punitorio, pap_cob.g_exi_punitorio, pap_cob.g_cod_aut_punitorio, pap_cob.g_cod_usu_aut_pu);
   end if;
   --- Autorizacion descuento de impuestos
   if pap_cob.g_cod_aut_impuesto is null then
      pav_ove.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                fu_obt_tra_concepto('IM',r_opeven.estado),
                                r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                pap_cob.g_sal_val_impuesto, pap_cob.g_exi_impuesto, pap_cob.g_cod_aut_impuesto, pap_cob.g_cod_usu_aut_im);
   end if;
   --- Autorizacion descuento de cargos
   if pap_cob.g_cod_aut_cargos is null then
      pav_ove.pr_obt_aut_previa(p_nro_cuenta, p_fecha, p_cod_tra_padre, r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                fu_obt_tra_concepto('CG',r_opeven.estado),
                                r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                pap_cob.g_sal_val_cargos, pap_cob.g_exi_cargos, pap_cob.g_cod_aut_cargos, pap_cob.g_cod_usu_aut_cg);
   end if;
END;
/* Utilizar autorización previa */
PROCEDURE LP_UTI_AUT_PRE
 (P_COD_AUTORIZACION IN GE_AUTORIZACIONES.COD_AUTORIZACION%TYPE
 ,P_EXIMIDO IN GE_AUTORIZACIONES.EXIMIDO%TYPE
 ,P_VALOR IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 ,P_MONTO IN OUT GE_AUTORIZACIONES.VALOR%TYPE
 )
 IS
BEGIN
   if p_cod_autorizacion is not null then
      if p_eximido = 'S' and nvl(p_monto,0) > 0 then
         p_monto := 0;
      else
         if nvl(p_valor,0) >= nvl(p_monto,0) then
            p_valor := nvl(p_valor,0) - nvl(p_monto,0);
            p_monto := 0;
         else    --- Solo por lo que sobra de la autorizacion
            p_monto := nvl(p_monto,0) - nvl(p_valor,0);
            p_valor := 0;
         end if;
      end if;
   end if;
END;
/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2 IS
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
BEGIN
   -- Inicializar variables. 23/10/2014 EGC
   pav_ove.pr_ini_autorizacion;
   --- Recuperar datos de la operacion
   pav_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_opeven);

   v_cod_mon_local          := pag_gen.fu_obt_mon_local;
   pap_cob.g_cod_mon_local  := v_cod_mon_local;
   v_exo_impuesto           := FU_OBT_EXO_IMPUESTO(p_nro_cuenta);
   ---
   v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, r_opeven.cod_moneda);
   --- Inicializar totales
   v_tot_capital      := 0;
   v_tot_mora         := 0;
   v_tot_impuesto     := 0;
   v_tot_cargo        := 0;
   v_tot_cargo_iva    := 0;
   v_tot_punitorio    := 0;
   --- Monto cobrado --- Si se ingresa el monto cobrado calcular en base al mismo
   v_sal_cobrado := p_mto_cobrado;
   --- Eliminar tabla de cobro temporal
   delete ov_cobros_tmp where nro_cuenta = p_nro_cuenta;
   --- Recuperar autorizaciones previas
   lp_rec_aut_prev;

   for i in datos loop
      --- Inicializar variables
      v_sal_capital           := 0;
      v_mora                  := 0;
      v_cargo                 := 0;
      v_cargo_iva             := 0;
      v_cap_adelantado        := 0;
      v_mto_int_mor_des       := 0;
      v_mto_int_mor_int_des   := 0;
      v_mto_int_mor_ade_des   := 0;
      v_mto_int_pun_des       := 0;
      v_mto_car_des           := 0;
      r_pctmp.nro_cuenta      := p_nro_cuenta;
      r_pctmp.estado          := i.estado;
      r_pctmp.fec_valor       := p_fecha;
      if p_fecha > i.fec_apertura then
         r_pctmp.dia_mora := p_fecha - i.fec_apertura;
      else
         r_pctmp.dia_mora := 0;
      end if;
      --- Recuperar saldo capital
      v_sal_capital := i.sal_total;
      --- Inicializar temporal
      r_pctmp.sal_total := r_opeven.sal_total;

      --- Calcular mora capital e interes
      v_mora         := pav_ove.fu_obt_concepto('MO',r_opeven,r_pctmp, p_fecha);
      --- Inicializar auxiliar
      r_pctmp.fec_ult_pago        := p_fecha;--i.fec_ult_movimiento;
      r_pctmp.mto_int_mor_cal     := v_mora;
      --- Calcular interes punitorio
      v_punitorio              := pav_ove.fu_obt_concepto('PU',r_opeven, r_pctmp, p_fecha);
      r_pctmp.mto_int_pun_cal  := v_punitorio;
      -- Calcula el impuesto calculado
      v_impuesto := 0;
      r_pctmp.mto_impuesto_cal := v_impuesto;
      --- Calcular cargos
      v_cargo           := pav_ove.fu_obt_concepto('CG',r_opeven, r_pctmp, p_fecha);
      IF v_exo_impuesto = 'N' Then
         v_cargo_iva              := r_pctmp.mto_car_iva_cal;
      End if;
      r_pctmp.mto_cargo_cal    := v_cargo;
      r_pctmp.mto_car_iva_cal  := v_cargo_iva;

      --- Calcular el monto total de la cuota
      v_mto_cuota        := nvl(v_sal_capital,0) + nvl(v_sal_interes,0) +
                            nvl(v_mora,0) + nvl(v_mora_int_ade,0) + nvl(v_mora_interes,0);

      --- Utilizar autorizaciones si es que existen
      v_mto_ant := v_mora;
      lp_uti_aut_pre(pap_cob.g_cod_aut_mor_cap, pap_cob.g_exi_mor_cap, pap_cob.g_sal_val_mor_cap, v_mora);
      If nvl(v_mora,0) != nvl(v_mto_ant,0) Then
         v_mto_int_mor_des := nvl(v_mto_int_mor_des,0) + (nvl(v_mto_ant,0) - nvl(v_mora,0));
      End if;
      v_mto_ant := v_punitorio;
      lp_uti_aut_pre(pap_cob.g_cod_aut_punitorio, pap_cob.g_exi_punitorio, pap_cob.g_sal_val_punitorio, v_punitorio);
      If nvl(v_punitorio,0) != nvl(v_mto_ant,0) Then
         v_mto_int_pun_des := nvl(v_mto_int_pun_des,0) + (nvl(v_mto_ant,0) - nvl(v_punitorio,0));
      End if;
      -- Sobre impuesto no se descuenta!!!
      ---lp_uti_aut_pre(pap_cob.g_cod_aut_impuesto, pap_cob.g_exi_impuesto, pap_cob.g_sal_val_impuesto, v_impuesto);
      --
      v_mto_ant := v_cargo;
      lp_uti_aut_pre(pap_cob.g_cod_aut_cargos, pap_cob.g_exi_cargos, pap_cob.g_sal_val_cargos, v_cargo);
      If nvl(v_cargo,0) != nvl(v_mto_ant,0) Then
         v_mto_car_des := nvl(v_mto_car_des,0) + (nvl(v_mto_ant,0) - nvl(v_cargo,0));
      End if;
      -- Solo debe calcular el impuesto si no está exento
      --if r_pctmp.dia_mora > 0 then
         P_DIA_MORA := r_pctmp.dia_mora;
      --end if;
      if v_exo_impuesto = 'N' then
         v_cod_tasa := null;
         pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                         r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                         r_pctmp.dia_mora, 'N', v_cod_tasa, 517, --Transaccion
                         p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);
         v_cal_fac_iva := 100 / (100 + v_val_tas_iva);
         --- Calcular cuanto corresponde al impuesto, esto es sólo para cargos
         v_mto_ant    := nvl(v_cargo,0);
         v_cargo      := round(v_mto_ant * nvl(v_cal_fac_iva,0),v_redondeo);
         -----
         v_cargo_iva  := nvl(v_mto_ant,0) - nvl(v_cargo,0);
         v_cargo      := nvl(v_cargo,0) + nvl(v_cargo_iva,0);
      end if;
      --- Calcular montos a pagar en base a saldos
      r_pctmp.mto_total            := v_sal_capital;
      r_pctmp.mto_int_moratorio    := v_mora;
      r_pctmp.mto_int_punitorio    := v_punitorio;

      -- Recien acá debe calcular el impuesto porque recién acá tiene los descuentos.
      -- Calcular impuesto ley 125/91
      --
      IF v_exo_impuesto = 'N' Then
         v_cod_tasa := null;

         pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                 r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                                 r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                 p_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
         v_cal_dia := r_pctmp.dia_mora;
         if v_cal_dia > 365 then
            v_cal_dia := 365;
         end if;
         v_impuesto := 0;
         if nvl(r_pctmp.mto_int_moratorio,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0 then

           v_impuesto := round(nvl(r_pctmp.mto_int_moratorio,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(r_pctmp.mto_int_punitorio,0) * (v_val_tasa / 100), v_redondeo);
         end if;
      End if;

      r_pctmp.mto_cargo           := v_cargo;
      r_pctmp.mto_cargo_iva       := v_cargo_iva;
      r_pctmp.mto_impuesto        := v_impuesto;
      r_pctmp.mto_impuesto_cal    := v_impuesto;
      --
      r_pctmp.mto_int_mor_des     := v_mto_int_mor_des;
      r_pctmp.mto_int_pun_des     := v_mto_int_pun_des;
      r_pctmp.mto_car_des         := v_mto_car_des;

      --RI : 28/07/2010 : El monto a pagar debe cubrir por lo menos los cargos
      if v_sal_cobrado < v_cargo then
        p_error   := 21;
        p_mensaje := 'El monto a pagar debe cubrir por lo menos los cargos.';
        return;
      End if;
      if  v_sal_cobrado is not null and v_sal_cobrado <
         (nvl(r_pctmp.mto_total,0)+
          nvl(r_pctmp.mto_int_moratorio,0)+nvl(r_pctmp.mto_int_punitorio,0)+
          nvl(r_pctmp.mto_cargo,0)+nvl(r_pctmp.mto_impuesto,0))  then
         --- Inicializar variables de cobro
         r_pctmp.mto_total            := 0;
         r_pctmp.mto_int_moratorio      := 0;
         r_pctmp.mto_cargo              := 0;
         r_pctmp.mto_cargo_iva          := 0;
         r_pctmp.mto_impuesto           := 0;
         r_pctmp.mto_int_punitorio      := 0;
         ---
         v_impuesto := 0;
         --- Recorrer prioridades de cobro
         --- Obtener tasa de impuestos , ojo 709 es para moratorio y punitorio
         v_cal_dia := 0;
         If v_exo_impuesto = 'N' Then
             v_cod_tasa := null;
             pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                                     r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                                     r_pctmp.dia_mora, 'N', v_cod_tasa, 709, --Transaccion
                                     p_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
             v_cal_dia := r_pctmp.dia_mora;
             if r_pctmp.dia_mora > 365 then
                v_cal_dia := 365;
             end if;
             v_cod_tasa := null;
             pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                             r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                             r_pctmp.dia_mora, 'N', v_cod_tasa, 517, --Transaccion
                             p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);
             v_cal_fac_iva := 100 / (100 + v_val_tas_iva);
         End if;
         for pri in c_prioridades loop
            v_cal_ley := 0;
            v_cal_fac := 0;
            if pri.concepto = 'CA' and nvl(v_sal_capital,0) > 0 then --- capital
               -- debe controlar sumando el monto de la ley 125
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N'  and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then --- OBS: Falta confirmar
                    v_cal_ley := 0;
               End if;
               ---
              if v_sal_cobrado > v_sal_capital+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_sal_capital + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N'
                 and (nvl(r_pctmp.mto_int_moratorio,0)  + nvl(r_pctmp.mto_int_punitorio,0) > 0)  Then
                   v_sal_capital := v_sal_cobrado;
                 else
                   v_sal_capital := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_total  := v_sal_capital;
              r_pctmp.mto_impuesto := v_impuesto;
            elsif pri.concepto = 'IN' and nvl(v_sal_interes,0) > 0 then --- interes
               -- debe controlar sumando el monto de la ley 125
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N'
               and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then --- OBS: Falta confirmar
                    v_cal_ley := 0;
               End if;
               ---
              if v_sal_cobrado > v_sal_interes+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_sal_interes + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N'
                 and (nvl(r_pctmp.mto_int_moratorio,0) + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then
                   v_sal_interes := v_sal_cobrado;
                 else
                   v_sal_interes := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              --r_pctmp.mto_interes  := v_sal_interes;
              r_pctmp.mto_impuesto := v_impuesto;
            elsif pri.concepto = 'IA' and nvl(v_sal_int_documentado,0) > 0 then --- interes adelantado
               -- debe controlar sumando el monto de la ley 125
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N'
               and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then --- OBS: Falta confirmar
                     v_cal_ley := 0;
               End if;
               ---
              if v_sal_cobrado > v_sal_int_documentado+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_sal_int_documentado + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N'  and (nvl(r_pctmp.mto_int_moratorio,0)      + nvl(r_pctmp.mto_int_punitorio,0) > 0) Then
                   v_sal_int_documentado := v_sal_cobrado;
                 else
                   v_sal_int_documentado := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              --r_pctmp.mto_int_documentado := v_sal_int_documentado;
              r_pctmp.mto_impuesto := v_impuesto;
            elsif pri.concepto = 'MO' and nvl(v_mora,0) > 0 then --- mora s/capital
               --
               v_cal_ley := 0;
               v_cal_fac := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                  v_cal_ley := round(v_mora * (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_mora+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_mora + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   v_cal_fac     := (v_val_tasa / 100) + 1;
                   v_mora        := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado := v_sal_cobrado - v_mora;
                   v_impuesto    := v_impuesto + v_sal_cobrado;
                 else
                   v_mora := v_sal_cobrado;
                 end if;
                 v_sal_cobrado := 0;
              end if;
              r_pctmp.mto_int_moratorio   := v_mora;
              r_pctmp.mto_impuesto        := v_impuesto;
            elsif pri.concepto = 'MI' and nvl(v_mora_interes,0) > 0 then --- mora s/interés
               v_cal_ley := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                  v_cal_ley := round(v_mora_interes * (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_mora_interes+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_mora_interes + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   v_cal_fac      := (v_val_tasa / 100) + 1;
                   v_mora_interes := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado  := v_sal_cobrado - v_mora_interes;
                   v_impuesto     := v_impuesto + v_sal_cobrado;
                 else
                   v_mora_interes := v_sal_cobrado;
                 end if;
                 v_sal_cobrado  := 0;
              end if;
              r_pctmp.mto_impuesto        := v_impuesto;
            elsif pri.concepto = 'MA' and nvl(v_mora_int_ade,0) > 0 then --- mora s/int.adelantado
               v_cal_ley := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                  v_cal_ley := round(v_mora_int_ade * (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_mora_int_ade+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_mora_int_ade + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   v_cal_fac      := (v_val_tasa / 100) + 1;
                   v_mora_int_ade := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado  := v_sal_cobrado - v_mora_int_ade;
                   v_impuesto     := v_impuesto + v_sal_cobrado;
                 Else
                   v_mora_int_ade := v_sal_cobrado;
                 End if;
                 v_sal_cobrado  := 0;
              end if;
--              r_pctmp.mto_int_mor_adelantado := v_mora_int_ade;
              r_pctmp.mto_impuesto        := v_impuesto;
            elsif pri.concepto = 'CG' and nvl(v_cargo,0) > 0 then --- cargos
              -- Calcular el iva y controlar antes de cobrar algo.
              if v_sal_cobrado > v_cargo then
                 v_sal_cobrado := v_sal_cobrado - v_cargo;
              else
                 --- Calcular cuanto corresponde a impuesto
                 v_cargo      := round(v_sal_cobrado * v_cal_fac_iva,v_redondeo);
                 -----
                 v_cargo_iva  := v_sal_cobrado - v_cargo;
                 v_cargo      := v_cargo + v_cargo_iva;
                 v_sal_cobrado := 0;

              end if;
              r_pctmp.mto_cargo           := v_cargo;
              r_pctmp.mto_cargo_iva       := v_cargo_iva;

            elsif pri.concepto = 'PU' and nvl(v_punitorio,0) > 0 then --- punitorio
               v_cal_ley := 0;
               --- Obtener tasa de impuestos
               If v_exo_impuesto = 'N' Then
                   v_cal_ley := round(v_punitorio *  (v_val_tasa / 100), v_redondeo);
               End if;
               ---
              if v_sal_cobrado > v_punitorio+v_cal_ley then
                 v_sal_cobrado := v_sal_cobrado - (v_punitorio + v_cal_ley);
                 v_impuesto    := v_impuesto + v_cal_ley;
              else
                 -- Si no alcanza debo calcular cuanto es lo que se puede cobrar de mora y ley
                 If v_exo_impuesto = 'N' Then
                   v_cal_fac      := (v_val_tasa / 100) + 1;
                   v_punitorio := round((v_sal_cobrado/v_cal_fac), v_redondeo);
                   v_sal_cobrado  := v_sal_cobrado - v_punitorio;
                   v_impuesto     := v_impuesto + v_sal_cobrado;
                 Else
                   v_punitorio := v_sal_cobrado;
                 End if;
                 v_sal_cobrado  := 0;
              end if;
              r_pctmp.mto_int_punitorio   := v_punitorio;
              r_pctmp.mto_impuesto        := v_impuesto;
            end if;
            if v_sal_cobrado = 0 then
               exit; --- Salir del ciclo si no queda saldo a pagar por el cliente
            end if;
         end loop;
      elsif v_sal_cobrado is not null then
         v_sal_cobrado := v_sal_cobrado - (nvl(r_pctmp.mto_total,0)+
                          nvl(r_pctmp.mto_int_moratorio,0)+nvl(r_pctmp.mto_int_punitorio,0)+
                          nvl(r_pctmp.mto_cargo,0)+nvl(r_pctmp.mto_impuesto,0));
      end if;
      --- Insertar tabla de cobro temporal

      lp_ins_pr_cobros_tmp(r_pctmp);
      --- Ajustar saldos del prestamo, esto es cuando se procesa mas de una cuota
      --- puede afectar a los calculos de intereses descontados
      r_opeven.sal_total:= nvl(r_opeven.sal_total,0) - nvl(r_pctmp.mto_total,0);

      --- Totalizar importes
      v_tot_capital      := nvl(v_tot_capital,0) + nvl(r_pctmp.mto_total,0);
      v_tot_mora         := nvl(v_tot_mora,0) + nvl(r_pctmp.mto_int_moratorio,0);
      v_tot_cargo        := nvl(v_tot_cargo,0) + nvl(r_pctmp.mto_cargo,0);
      v_tot_cargo_iva    := nvl(v_tot_cargo_iva,0) + nvl(r_pctmp.mto_cargo_iva,0);
      v_tot_impuesto     := nvl(v_tot_impuesto,0) + nvl(r_pctmp.mto_impuesto,0);
      v_tot_punitorio    := nvl(v_tot_punitorio,0) + nvl(r_pctmp.mto_int_punitorio,0);
      if v_sal_cobrado is not null and v_sal_cobrado = 0 then
         exit; --- Salir del ciclo si no queda saldo a pagar por el cliente
      end if;
   end loop;
   --- Cargar parametros de salida
   p_tot_capital      := v_tot_capital;
   p_tot_mora         := v_tot_mora;
   p_tot_cargo        := v_tot_cargo;
   p_tot_cargo_iva    := v_tot_cargo_iva;
   p_tot_impuesto      := v_tot_impuesto;
   p_tot_punitorio     := v_tot_punitorio;
exception
  when others then
    p_error   := 20002;
    p_mensaje := sqlerrm;
END;
/* Realizar el cobro */
PROCEDURE PR_COB_OPE_VENCIDA
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_MTO_COBRADO IN OV_CTA_VENCIDAS.SAL_TOTAL%TYPE
 ,P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN OUT GE_MOVIMIENTOS.HORA%TYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_COD_TRA_PADRE IN NUMBER default 139
 ,P_COD_MOD_PADRE IN NUMBER
 ,P_COD_MAD_PADRE IN NUMBER
 ,P_NRO_OPERACION IN NUMBER
 ,P_ESTADO IN VARCHAR DEFAULT 'N' -- C.D.Fase 4
 ,P_COD_USUARIO   IN VARCHAR2 DEFAULT USER)
 IS

/* Insertar cobro de préstamo. */
PROCEDURE LP_INS_PR_COBROS
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 );
/* Utilizar autorizacion */
PROCEDURE LP_UTI_AUTORIZACION
 (P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 );
--- Datos del registros de cuentas
   r_opeven        ov_cta_vencidas%rowtype;
   r_gmovi         ge_movimientos%rowtype;
   v_sal_cobrado   pr_cuotas.sal_capital%type;
   v_sal_capital   pr_cuotas.sal_capital%type;
   v_mora          pr_cuotas.sal_interes%type;
   v_impuesto      pr_cuotas.sal_interes%type;
   v_cargo         pr_cuotas.sal_interes%type;
   v_cargo_iva     pr_cuotas.sal_interes%type;
   v_punitorio     pr_cuotas.sal_interes%type;
   v_int_descontado pr_cuotas.sal_interes%type;
   v_mto_cuota     pr_cuotas.sal_capital%type;
   v_redondeo      number(2);
   v_cancela       varchar2(01);
   v_error         number(05);
   v_mensaje       varchar2(1000);
   v_tot_pag_cap   OV_CTA_VENCIDAS.sal_total%type;
   v_pre_sal_cap   OV_CTA_VENCIDAS.sal_total%type;
   v_cal_dev_nocob varchar2(01);
   v_est_cuota     pr_cuotas.estado%type;
   v_can_prestamo  varchar2(01);
   v_dia_mora      number(05);
   --- Variables de movimientos
   v_fecha         ge_movimientos.fecha%type;
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_hora          ge_movimientos.hora%type;
   v_est_movim     ge_movimientos.estado%type;
   v_cotizacion    ge_movimientos.cotizacion%type;
   --- variables para ver gastos varios
   v_cta_gastos    OV_CTA_VENCIDAS.sal_total%type;
   v_cargo_iva_tmp OV_CTA_VENCIDAS.sal_total%type;
   v_cargo_tmp     OV_CTA_VENCIDAS.sal_total%type;
   v_cargo_iva_gas OV_CTA_VENCIDAS.sal_total%type;
   v_cargo_gas     OV_CTA_VENCIDAS.sal_total%type;
   v_cal_fac_iva   number;
   v_mto_ant       OV_CTA_VENCIDAS.sal_total%type;
   --tasas
   v_val_tas_impuesto ge_movimientos.val_tasa%type;
   v_val_tas_iva      ge_movimientos.val_tasa%type;
   v_fec_vigencia     ge_tas_fechas.fec_vigencia%type;
   v_tip_valor        ge_tasas.tip_valor%type;
   v_tipo             ge_tasas.tipo%type;
   v_cod_tasa         ge_tasas.cod_tasa%type;
   --Variables para actualizar mto.aplicado de las garantias
   v_tot_sal_cap    pr_cuotas.sal_capital%type;
   v_tot_sal_int    pr_cuotas.sal_interes%type;
   v_tot_desaplicar pr_cta_garantias.mto_aplicado%type;
   v_mens_error     varchar2(100);
   v_cod_usu_ori    ba_usuarios.cod_usuario%type;
   v_boleteo        varchar2(1);
   v_concepto       ge_movimientos.concepto%type;
    --Cursor de garantias
    cursor garantias is
    select cod_garantia,nro_garantia,mto_aplicado
     from ov_cta_garantias
     where nro_cuenta = p_nro_cuenta;

   cursor c_datos is
      select *
     from OV_CTA_VENCIDAS
    where nro_cuenta = p_nro_cuenta
      and nvl(sal_total,0) <> 0 ;

/* Insertar cobro de préstamo. */
PROCEDURE LP_INS_PR_COBROS
 (P_NRO_CUENTA IN OV_CTA_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 )
 IS
BEGIN
   insert into ov_cobros
     (nro_cuenta,fecha, hora, estado,sal_total,fec_ult_pago, dia_mora,
      mto_total, mto_int_moratorio,mto_int_punitorio,mto_cargo,
      mto_cargo_iva, mto_impuesto,nro_documento,mto_int_mor_cal,mto_int_pun_cal,
      mto_cargo_cal,mto_car_iva_cal, mto_impuesto_cal,
      mto_int_mor_des, mto_int_pun_des, mto_car_des
     )
   select nro_cuenta, p_fecha, p_hora, estado, sal_total, fec_ult_pago, dia_mora,
      mto_total,mto_int_moratorio,mto_int_punitorio,mto_cargo, mto_cargo_iva,
      mto_impuesto,nro_documento, mto_int_mor_cal,mto_int_pun_cal, mto_cargo_cal,
      mto_car_iva_cal, mto_impuesto_cal,
      mto_int_mor_des, mto_int_pun_des, mto_car_des
     from ov_cobros_tmp
    where nro_cuenta = p_nro_cuenta;
END;
/* Utilizar autorizacion */
PROCEDURE LP_UTI_AUTORIZACION
 (P_FECHA IN DATE
 ,P_HORA IN VARCHAR2
 )
 IS
BEGIN
   --- Autorizacion descuento de interes
   if pap_cob.g_cod_aut_interes is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_interes;
   end if;
   --- Autorizacion descuento de interés adelantado
   if pap_cob.g_cod_aut_int_ade is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_int_ade;
   end if;
   --- Autorizacion descuento de mora capital
   if pap_cob.g_cod_aut_mor_cap is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_mor_cap;
   end if;
   --- Autorizacion descuento de mora interes
   if pap_cob.g_cod_aut_mor_int is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_mor_int;
   end if;
   --- Autorizacion descuento de mora interes adelantado
   if pap_cob.g_cod_aut_mor_ade is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_mor_ade;
   end if;
   --- Autorizacion descuento de punitorio
   if pap_cob.g_cod_aut_punitorio is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_punitorio;
   end if;
   --- Autorizacion descuento de impuestos
   if pap_cob.g_cod_aut_impuesto is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_impuesto;
   end if;
   --- Autorizacion descuento de cargos
   if pap_cob.g_cod_aut_cargos is not null then
      update ge_autorizaciones
         set cod_usu_utilizador = nvl(p_cod_usuario,user),
             fec_utilizacion    = p_fecha,
             hor_utilizacion    = p_hora
       where cod_autorizacion   = pap_cob.g_cod_aut_cargos;
   end if;
END;

BEGIN
   --Determinar si tiene boleteo--
   v_boleteo := 'N';
   v_concepto := p_concepto;
   if P_CONCEPTO LIKE '%(Boleteo)%' then
      v_boleteo := 'S';
      v_concepto := null;
   end if;
   --- Recuperar datos de la cuenta de prestamos
   pav_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_opeven);
   v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, r_opeven.cod_moneda);

   --- Inicializar datos del movimiento
   v_cod_usu_ori := nvl(P_COD_USUARIO,user);
   v_fecha         := p_fecha;
   v_hora          := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));
   v_nro_secuencia := nvl(p_nro_secuencia,0);
   --- Recuperar datos de la cuota
   v_sal_cobrado := p_mto_cobrado;
   v_tot_pag_cap := 0;
   --- Inicializar variables de autorizaciones
   pav_ove.pr_ini_autorizacion;
   v_tot_sal_cap := 0;
   for i in c_datos loop
      --- Recuperar datos
      pav_ove.pr_obt_deu_ope_vencida(p_nro_cuenta, p_fecha,v_sal_cobrado,
                                     v_error, v_mensaje,v_sal_capital,
                                     v_mora,v_punitorio, v_impuesto,v_cargo, v_cargo_iva,
                                     v_dia_mora, p_cod_tra_padre);
      if v_error <> 0 then
         raise_application_error(-20000, v_mensaje);
      end if;

      --verificar si se cobra algo
      if p_mto_cobrado > 0 then
        if (nvl(v_sal_capital,0) + nvl(v_mora,0) + nvl(v_punitorio,0) +
            nvl(v_impuesto,0) + nvl(v_cargo,0) + nvl(v_cargo_iva,0)) <= 0 then
          raise_application_error(-20000,'Mtos. a cobrar no corresponden.');
        end if;
      else
        raise_application_error(-20000,'Mto. cobrado debe ser mayor a cero. '||p_mto_cobrado);
      end if;
      --verificar si se cobra algo
      if p_mto_cobrado < nvl(v_cargo,0) then
        raise_application_error(-20000,'Mto. cobrado debe cubrir por lo menos los cargos.');
      end if;
      --- Insertar registro de cobro
      -- Se inserta el cobro si no existe un Pedido de autorización -- C.D.Fase 4
     if p_estado <> 'P' then -- C.D.Fase 4
       lp_ins_pr_cobros(p_nro_cuenta, v_fecha, v_hora);
     end if;

      --- Hallar el saldo de la operacion vencida
      v_pre_sal_cap := nvl(r_opeven.sal_total,0) - nvl(v_tot_pag_cap,0);
      v_tot_pag_cap := nvl(v_tot_pag_cap,0) + nvl(v_sal_capital,0);

      IF v_pre_sal_cap - nvl(v_sal_capital,0) > 0 THEN
         v_can_prestamo := 'N';
      else
         v_can_prestamo := 'S';
      end if;

      --- Actualizar maestro de Operacion Vencida
      --- Se actualiza el estado de la cuenta Vencida si no se genera el pedido de autorización -- C.D.Fase 4
      if p_estado <> 'P' then
        update ov_cta_vencidas
           set sal_total = nvl(sal_total,0) - nvl(v_sal_capital,0),
               estado             = decode(v_can_prestamo,'S','C',estado),
               fec_ult_movimiento = p_fecha,
               hor_ult_movimiento = p_hora,
               fec_cam_estado     = p_fecha
         where nro_cuenta = p_nro_cuenta;
      end if;

      v_tot_sal_cap := nvl(v_tot_sal_cap,0) + nvl(v_sal_capital,0);

      --- GENERAR MOVIMIENTOS
      r_gmovi.cod_usuario    := nvl(p_cod_usuario,user);
      r_gmovi.hora           := v_hora;
      r_gmovi.fecha          := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
      r_gmovi.cod_modulo     := r_opeven.cod_modulo;
      r_gmovi.cod_modalidad  := r_opeven.cod_modalidad;
      r_gmovi.cod_oficina    := r_opeven.cod_oficina;
      r_gmovi.nro_cuenta     := p_nro_cuenta;
      r_gmovi.cod_moneda     := r_opeven.cod_moneda;
      r_gmovi.est_cuenta     := r_opeven.estado;
      r_gmovi.cod_tra_padre  := nvl(p_cod_tra_padre, 139);
      r_gmovi.cod_mod_padre  := p_cod_mod_padre;
      r_gmovi.cod_mad_padre  := p_cod_mad_padre;
      r_gmovi.fec_valor      := p_fecha;
      r_gmovi.reversado      := 'N';
      r_gmovi.protegido      := 'N';
      ----------------------------------------------
       -- C.D.Fase 4
     -- r_gmovi.estado         := 'N';
      r_gmovi.estado         := nvl(p_estado,'N');
      ----------------------------------------------
      r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
      r_gmovi.nro_documento  := p_NRO_OPERACION;
      r_gmovi.concepto       := nvl(v_concepto,'Cobro de Ope.Vencida');
      v_cotizacion           := null;
      if v_boleteo = 'S' then
         if r_opeven.cod_moneda <> pag_gen.fu_obt_mon_local then
            v_cotizacion := pag_gen.fu_obt_cotizacion(r_opeven.cod_moneda, r_gmovi.fecha);
         end if;
      end if;
      IF v_sal_Capital > 0 THEN -- Amortizo capital
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.emi_aviso          := 'S';
         r_gmovi.cod_transaccion    := pav_ove.fu_obt_tra_concepto('CA', r_opeven.estado);
         r_gmovi.monto              := v_sal_capital;
         r_gmovi.cotizacion         := v_cotizacion;
         r_gmovi.mto_equ_local      := round(r_gmovi.monto * v_cotizacion,0);
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
      ---se generan datos de cobro de mora -----------
      --- generar movimiento por el interes descontado
      if nvl(v_int_descontado,0) <> 0 then
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.estado              := p_estado;-- C.D.Fase 4
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := 803;
         r_gmovi.monto               := v_int_descontado;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_INT;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_INTERES;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;
      -- inserta monto interes moratorio -----------------------------
      if nvl(v_mora,0) > 0 then
         r_gmovi.fecha               := v_fecha;
         r_gmovi.cod_usuario         := nvl(v_cod_usu_ori,user);
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.estado              := p_estado;-- C.D.Fase 4
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := pav_ove.fu_obt_tra_concepto('MO', r_opeven.estado);
         r_gmovi.monto               := v_mora;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_MO;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_MOR_CAP;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;
      --- Genera movimiento por el punitorio
      if nvl(v_punitorio,0) > 0 then
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.estado              := p_estado;-- C.D.Fase 4
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := pav_ove.fu_obt_tra_concepto('PU', r_opeven.estado);
         r_gmovi.monto               := v_punitorio;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_PU;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_PUNITORIO;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;
      ----------------------------------------------------------------------
      --- Genera movimiento por el impuesto
      if nvl(v_impuesto,0) > 0 then
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.estado              := p_estado;-- C.D.Fase 4
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := pav_ove.fu_obt_tra_concepto('IM', r_opeven.estado);
         r_gmovi.monto               := v_impuesto;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_IM;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_IMPUESTO;
         --recuperar tasa
         v_cod_tasa := null;
         pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                         r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                         r_gmovi.monto, 'N', v_cod_tasa, r_gmovi.cod_transaccion, --Transaccion
                         p_fecha, v_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo);

         r_gmovi.val_tasa           := v_val_tas_impuesto;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;
      --- Actualizo Ov_Cta_gastos
      IF nvl( v_cargo, 0 ) > 0 THEN
        DECLARE
          CURSOR gastos
              IS select nro_cuenta, saldo monto, cod_transaccion, rowid
                   from ov_cta_gastos
                  where nro_cuenta = p_nro_cuenta
                    and ( fec_vencimiento >= v_fecha or fec_vencimiento IS NULL )
                    and fec_ult_pago IS NULL
                  order by nro_cuenta, cod_modalidad, cod_transaccion, fec_ingreso;
       BEGIN
          v_cargo_tmp := nvl( v_cargo, 0 );
          v_cargo_iva_tmp := nvl(v_cargo_iva,0);
          FOR g IN gastos LOOP
              IF nvl( v_cargo_tmp, 0 ) >= nvl( g.monto, 0 ) THEN
                BEGIN
                  update ov_cta_gastos
                     set fec_ult_pago = p_fecha,
                         hor_ult_pago = v_hora,
                         saldo = 0
                   where nro_cuenta = g.nro_cuenta
                     and rowid = g.rowid;
                EXCEPTION
                  when others then
                    NULL;
                END;
                v_cargo_gas := g.monto;
              else
                BEGIN
                  update ov_cta_gastos
                     set fec_ult_pago = p_fecha,
                         hor_ult_pago = v_hora,
                         saldo = saldo - v_cargo_tmp
                   where nro_cuenta = g.nro_cuenta
                     and rowid = g.rowid;
                EXCEPTION
                  when others then
                    NULL;
                END;
                v_cargo_gas := v_cargo_tmp;
              End if;
              v_cod_tasa := null;
              pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                               r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                               g.monto, 'N', v_cod_tasa, 517, --Transaccion
                               p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);

              -- SPCOGACO-1. Ajustes varios para que genere correctamente los registros
              --- Genero el movimiento por el cargo
               v_nro_secuencia             := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia       := v_nro_secuencia;
               r_gmovi.emi_aviso           := 'S';
               r_gmovi.cod_transaccion     := g.cod_transaccion;
               r_gmovi.monto               := v_cargo_gas; -- Sin iva
               r_gmovi.cotizacion          := v_cotizacion;
               r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
               r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_CG;
               r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_CARGOS;
               r_gmovi.val_tasa            := null;--r_gmovi.monto;
               r_gmovi.referencia          := null;
               r_gmovi.concepto            := 'Gasto Manual '||g.cod_transaccion;
               pag_gen.pr_ins_ge_movimiento(r_gmovi);

               --- Impuesto sobre cargo
               v_nro_secuencia             := v_nro_secuencia + 1;
               r_gmovi.concepto            := 'Iva Gasto Manual '||g.cod_transaccion;
               r_gmovi.nro_secuencia       := v_nro_secuencia;
               r_gmovi.emi_aviso           := 'S';
               r_gmovi.cod_transaccion     := 517;
               r_gmovi.monto               := v_cargo_iva_tmp;
               r_gmovi.cotizacion          := v_cotizacion;
               r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
               --recuperar tasa
               v_cod_tasa                  := null;
               r_gmovi.val_tasa            := v_val_tas_iva;
               pag_gen.pr_ins_ge_movimiento(r_gmovi);
               --- Descuento Saldos
               v_cargo_tmp := nvl( v_cargo_tmp, 0 ) - nvl( v_cargo_gas, 0 );
               v_cargo_iva_tmp := nvl(v_cargo_iva_tmp,0) - nvl(v_cargo_iva_gas,0);
            --END IF;
          END LOOP;
          v_cargo     := v_cargo_tmp;
          v_cargo_iva := v_cargo_iva_tmp;
        END;
      END IF;
      r_gmovi.concepto       := nvl(v_concepto,'Cobro de Ope.Vencida');
      -- SPCOGACO-1. Se comenta, el impuesto ya se genera dentro del cursor
      --- Genera movimiento por el cargo si no viene por gastos detallados
      if nvl(v_cargo,0) > 0 then --- Cambiado para que haga por cada cargo cobrado
         v_nro_secuencia             := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia       := v_nro_secuencia;
         r_gmovi.emi_aviso           := 'S';
         r_gmovi.cod_transaccion     := pav_ove.fu_obt_tra_concepto('CG', r_opeven.estado);
         r_gmovi.monto               := v_cargo - nvl(v_cargo_iva,0); -- Sin iva
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
         r_gmovi.cod_usu_autorizador := pap_cob.G_COD_USU_AUT_CG;
         r_gmovi.cod_autorizacion    := pap_cob.G_COD_AUT_CARGOS;
         r_gmovi.val_tasa           := r_gmovi.monto;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
         --- Impuesto sobre cargo
         v_nro_secuencia            := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia      := v_nro_secuencia;
         r_gmovi.emi_aviso          := 'S';
         r_gmovi.cod_transaccion    := 517;
         r_gmovi.monto              := v_cargo_iva;
         r_gmovi.cotizacion          := v_cotizacion;
         r_gmovi.mto_equ_local       := round(r_gmovi.monto * v_cotizacion,0);
         --recuperar tasa
         v_cod_tasa := null;
         pag_gen.pr_obt_val_tasa(r_opeven.cod_modulo, r_opeven.cod_modalidad,
                               r_opeven.cod_oficina, r_opeven.nro_cuenta, r_opeven.cod_moneda,
                               r_gmovi.monto, 'N', v_cod_tasa, 517, --Transaccion
                               p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);

         r_gmovi.val_tasa           := v_val_tas_iva;
         pag_gen.pr_ins_ge_movimiento(r_gmovi);
      end if;

      r_gmovi.val_tasa := null;

      v_sal_cobrado := v_sal_cobrado;
      if nvl(v_sal_cobrado,0) <= 0 then
         exit;
      end if;
   end loop;

   --- Generar movimiento del cambio de estado a cancelado
   if v_can_prestamo = 'S' then
      v_nro_secuencia             := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia       := v_nro_secuencia;
      r_gmovi.emi_aviso           := 'N';
      r_gmovi.cod_transaccion     := 429;
      r_gmovi.est_cuenta          := 'C';
      r_gmovi.monto               := null;
      r_gmovi.cotizacion          := null;
      r_gmovi.mto_equ_local       := null;
      r_gmovi.cod_usu_autorizador := null;
      r_gmovi.cod_autorizacion    := null;
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   end if;
   --- Actualizar autorizaciones utilizadas
   lp_uti_autorizacion(p_fecha,v_hora);
   pav_ove.pr_ini_autorizacion;
   p_nro_secuencia := v_nro_secuencia;

   --- garantias
   --Generar novedades de la garantia para poder reversar
   for i in garantias loop
     insert into ov_cta_garantias_nov(fecha,hora,cod_usuario,
                                      nro_cuenta,nro_garantia,
                                      cod_garantia,mto_aplicado)
     values(PAG_CAL.FU_OBT_FEC_ACTUAL(15),v_hora,nvl(p_cod_usuario,user),p_nro_cuenta,
            i.nro_garantia,i.cod_garantia,i.mto_aplicado);
   end loop;
   --- Desaplicar mto. aplicado de la garantia
   if fug_obt_pardinamico('INC_INT_GARANTIA',r_opeven.cod_modulo,
                                             r_opeven.cod_modalidad,
                                             r_opeven.cod_moneda,
                                             r_opeven.cod_oficina) ='S' then
     v_tot_desaplicar := nvl(v_tot_sal_cap,0) + nvl(v_tot_sal_int,0);
   else
     v_tot_desaplicar := nvl(v_tot_sal_cap,0);
   End if;
   pap_gar.pr_act_apl_garantia(p_nro_cuenta,v_tot_desaplicar,'D',v_mens_error);
 ---
END;
PROCEDURE PR_INI_AUTORIZACION
 IS
BEGIN
   pap_cob.g_cod_aut_interes   := null;
   pap_cob.g_cod_aut_int_ade   := null;
   pap_cob.g_cod_aut_mor_cap   := null;
   pap_cob.g_cod_aut_mor_int   := null;
   pap_cob.g_cod_aut_mor_ade   := null;
   pap_cob.g_cod_aut_punitorio := null;
   pap_cob.g_cod_aut_impuesto  := null;
   pap_cob.g_cod_aut_cargos    := null;
   pap_cob.g_sal_val_interes   := null;
   pap_cob.g_sal_val_int_ade   := null;
   pap_cob.g_sal_val_mor_cap   := null;
   pap_cob.g_sal_val_mor_int   := null;
   pap_cob.g_sal_val_mor_ade   := null;
   pap_cob.g_sal_val_punitorio := null;
   pap_cob.g_sal_val_impuesto  := null;
   pap_cob.g_sal_val_cargos    := null;
   pap_cob.g_exi_interes       := null;
   pap_cob.g_exi_int_ade       := null;
   pap_cob.g_exi_mor_cap       := null;
   pap_cob.g_exi_mor_int       := null;
   pap_cob.g_exi_mor_ade       := null;
   pap_cob.g_exi_punitorio     := null;
   pap_cob.g_exi_impuesto      := null;
   pap_cob.g_exi_cargos        := null;
   pap_cob.g_uti_gastos        := 'N';
END;

PROCEDURE PR_OBT_CARGO_MTO_PLZ
 IS
v_cobra_mora varchar2(1) := 'N';
PROCEDURE LP_OBT_CARGO_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
FUNCTION LF_OBT_ULT_PAG_CARGO
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
   v_cargo             pr_cuotas.sal_interes%type;
   v_cargo_iva         pr_cuotas.sal_interes%type;
   v_car_manual        pr_cuotas.sal_interes%type;
   v_seguro            pr_cuotas.sal_interes%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   v_redondeo          number(02);
   v_cod_transaccion   ge_transacciones.cod_transaccion%type;
   v_tra_iva           ge_transacciones.cod_transaccion%type;
   v_cod_tasa          ge_tasas.cod_tasa%type;
   v_car_cancelacion   number(18,2);
   v_cod_tasa_plazo    ge_tas_fechas.val_tasa%type;
   v_dias              number(10);
   v_pre_personal      varchar2(01);
   --- Variables de recuperacion de tasa
   v_aplicar           ge_tasas.aplicar%type;
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_car_no_pag        pr_cobros.mto_int_moratorio%type;
   v_car_pag           pr_cobros.mto_int_moratorio%type;
   v_fec_ult_pag_cargo pr_cobros.fecha%type;
   -- Cursor de Cargos
   cursor gastos_varios is
      select saldo, cod_transaccion, fec_ult_pago
        from ov_cta_gastos
       where nro_cuenta    = rg_opeven.nro_cuenta
         and cod_modalidad = rg_opeven.cod_modalidad
         and (fec_vencimiento >= v_fecha or fec_vencimiento is null) --para gasto vigente debe ser mayor o igual a fecha de cobro
         and fec_ult_pago is null;
   --
PROCEDURE LP_OBT_CARGO_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum((nvl(c.mto_cargo_cal,0)-
                  ((nvl(c.mto_cargo,0)+nvl(c.mto_car_des,0))))),0),
          nvl(sum(nvl(c.mto_cargo,0)/*- nvl(c.mto_cargo_iva,0)*/),0)
     into p_mto_no_pag, p_mto_pag
     from ov_cobros c
    where c.nro_cuenta = p_nro_cuenta
      --and c.fecha      >= v_fec_ult_pag_cargo;
      and (c.fecha, c.hora) = (select max(p.fecha), max(p.hora)
                                 from ov_cobros p
                                where p.nro_cuenta = c.nro_cuenta
                                  and ( ((nvl(p.mto_cargo,0)+nvl(p.mto_car_des,0))-nvl(p.mto_cargo_iva,0) <> 0)
                                   or (nvl(p.mto_cargo_cal,0) <> 0) ) );

 /*MSCL - SI ME INTERESA LO QUE NO SE PAGO POR CARGO Y QUE NO SE DESCONTÓ
   YA QUE LA PROXIMA VEZ QUE VENGA SE LO VOY A COBRAR.*/
 /*
 if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
 */

END;
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil date;
v_fec_actual date;
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(1);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual then
         -- si el siguiente día habil no es hoy se le debe cobrar mora.
         return 'S';
      else
         -- No es dia habil, no corresponde cobrar mora
         return 'N';
      end if;
   end if;
END;
FUNCTION LF_OBT_ULT_PAG_CARGO
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
   /*select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.cod_transaccion = 712; -- Transaccion de Cargos
   */
   /*select fecha
     into v_max_fec_pago
     from ov_cobros cob
    where cob.nro_cuenta = p_nro_cuenta
      and (cob.fecha, cob.hora) =
         (select max(mor.fecha), max(mor.hora)
            from ov_cobros mor
           where mor.nro_cuenta = cob.nro_cuenta
             --- Que halla cancelado todos los cargos a esa fecha
             and   (nvl(mor.mto_int_moratorio,0)+nvl(mor.mto_int_mor_des,0) = nvl(mor.mto_int_mor_cal,0))
               and (nvl(mor.mto_int_punitorio,0)+nvl(mor.mto_int_pun_des,0) = nvl(mor.mto_int_pun_cal,0))
               and (nvl(mor.mto_cargo,0)+nvl(mor.mto_car_des,0) = nvl(mor.mto_cargo_cal,0))
             and mor.fecha =
                (select max(mor1.fecha)
                   from ov_cobros mor1
                  where mor1.nro_cuenta = mor.nro_cuenta
                    --- Que halla cancelado todos los cargos a esa fecha
                    and   (nvl(mor1.mto_int_moratorio,0)+nvl(mor1.mto_int_mor_des,0) = nvl(mor1.mto_int_mor_cal,0))
                      and (nvl(mor1.mto_int_punitorio,0)+nvl(mor1.mto_int_pun_des,0) = nvl(mor1.mto_int_pun_cal,0))
                      and (nvl(mor1.mto_cargo,0)+nvl(mor1.mto_car_des,0) = nvl(mor1.mto_cargo_cal,0))
                 )
          );*/
   if v_max_fec_pago is null then
      select max(fec_ult_pago)
        into v_max_fec_pago
        from ov_cobros t
       where nro_cuenta = p_nro_cuenta;
   end if;
   if v_max_fec_pago < rg_opeven.fec_apertura then
      v_max_fec_pago := rg_opeven.fec_apertura;
   end if;
   return v_max_fec_pago;

exception
   when no_data_found then
      return rg_opeven.fec_apertura;
   when others then
       raise_application_error(-20000,
       'Rec.Fec.Cargo '||p_nro_cuenta);/*||' Cuota '||pap_cob.rg_pcuot.nro_cuota);*/
END;
/* veo si tiene IVA asociada a la transaccion */
PROCEDURE LP_OBT_TRA_IVA_ASOCIADA
 (P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO      IN  GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD   IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_TRA_IVA         OUT GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 )
 IS
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

BEGIN
   v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, null, rg_opeven.cod_moneda);

   v_dias := v_fecha - rg_opeven.fec_apertura;
   v_fec_ult_pag_cargo := lf_obt_ult_pag_cargo(rg_opeven.nro_cuenta, v_fecha);

   --v_dias := pap_cob.g_fec_calculo - v_fec_ult_pag_cargo;
   if v_fec_ult_pag_cargo is not null and v_fec_ult_pag_cargo > rg_opeven.fec_apertura then
     v_dias := v_fecha - v_fec_ult_pag_cargo;
   End if;

   if v_dias > 0 then
      --- Calcular el monto de la cuota
      v_mto_cuota        := nvl(rg_opeven.sal_total,0);
      -- Calcular cargos
      -- Obtener codigo de tasa segun el monto capital
      v_cod_transaccion := 712;
      pag_gen.pr_obt_val_tasa(rg_opeven.cod_modulo, rg_opeven.cod_modalidad,
                              rg_opeven.cod_oficina, rg_opeven.nro_cuenta,
                              rg_opeven.cod_moneda,
                              v_mto_cuota, --imp_trans
                              'N', v_cod_tasa, v_cod_transaccion, v_fecha,
                              v_cod_tasa_plazo, v_fec_vigencia, v_tip_valor, v_tipo);
      -- Recuperar forma de aplicar de la tasa
      begin
        select aplicar
          into v_aplicar
          from ge_tasas
         where cod_tasa = v_cod_tasa;
      exception
        when others then
          v_aplicar := null;
      end;
      if v_aplicar = 'CP' then
        pag_gen.pr_obt_val_tasa(rg_opeven.cod_modulo, rg_opeven.cod_modalidad,
                                rg_opeven.cod_oficina, rg_opeven.nro_cuenta, rg_opeven.cod_moneda,
                                v_dias, 'N', v_cod_tasa_plazo, null, --Transaccion
                                v_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
      else
        v_val_tasa := v_cod_tasa_plazo;
      end if;
      if v_tip_valor = 'P' then --- Porcentaje
        v_cargo := round(v_mto_cuota * v_val_tasa/100, v_redondeo);
      else --- Valor
        v_cargo := v_val_tasa;
      end if;
   else
      v_cargo := 0;
   end if;
   --- Recuperar montos de no pagados anteriores
   lp_obt_cargo_pag_ant(rg_opeven.nro_cuenta, 1, v_car_no_pag, v_car_pag);
   v_cargo := v_cargo + v_car_no_pag;

   if nvl(v_cargo,0) > 0 then
      -- Se calcula el I.V.A.   s/ el Cargo
      --v_cod_tasa := 417;
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(rg_opeven.cod_modulo, rg_opeven.cod_modalidad,
                              rg_opeven.cod_oficina, rg_opeven.nro_cuenta, rg_opeven.cod_moneda,
                              v_dias, 'N', v_cod_tasa, 517, --Transaccion
                              v_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
  ---    v_cargo_iva := round((v_cargo * v_val_tasa / 100), v_redondeo);
      v_cargo_iva := round(v_cargo * v_val_tasa / (100+v_val_tasa), v_redondeo);
   else
      v_cargo := 0;
   end if;
   If nvl(pap_cob.g_uti_gastos,'N') = 'N' then
     pap_cob.g_uti_gastos := 'S';
     --- Recorre el Cursor de Cargos Adicionales.
     for reg in gastos_varios loop
       v_tra_iva   := null;
       v_car_manual := reg.saldo;
       --- Veo si tiene IVA asociada la transaccion del cargo
       lp_obt_tra_iva_asociada(reg.cod_transaccion,rg_opeven.cod_modulo,rg_opeven.cod_modalidad,v_tra_iva);
       if nvl(v_car_manual,0) > 0 and v_tra_iva is not null then
        -- Se calcula el I.V.A. s/ el Cargo
        v_cod_tasa := null;
        pag_gen.pr_obt_val_tasa(rg_opeven.cod_modulo, rg_opeven.cod_modalidad,
                                rg_opeven.cod_oficina, rg_opeven.nro_cuenta, rg_opeven.cod_moneda,
                                v_dias, 'N', v_cod_tasa, v_tra_iva, --Transaccion
                                v_fecha, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
        --
        v_cargo_iva := nvl(v_cargo_iva,0) + round((v_car_manual * v_val_tasa / 100), v_redondeo);
       end if;
       v_Cargo := nvl(v_cargo,0) + nvl(v_car_manual,0);
     end loop;
   End if;
--   If v_cargo > 0 then
--     v_cargo := round(nvl(v_cargo,0) - nvl(v_car_pag,0),v_redondeo);
--   End if;
   --- OBS: El cargo siempre se devuelve mas el iva.
   pap_cob.g_val_retorno    := v_cargo+nvl(v_cargo_iva,0);
   rg_pctmp.mto_cargo_cal   := v_cargo+nvl(v_cargo_iva,0);
   rg_pctmp.mto_car_iva_cal := v_cargo_iva;
END;

END PAV_OVE;
/

