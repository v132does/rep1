CREATE OR REPLACE PACKAGE BODY IT.PAP_COB IS
   v_redondeo           number(2);
/* Obtener el saldo capital a cobrar. */
PROCEDURE PR_OBT_SAL_CAPITAL
 IS
BEGIN
   pap_cob.g_val_retorno := rg_pcuot.sal_capital;
   rg_pctmp.mto_capital  := rg_pcuot.sal_capital;
END;
/* Obtener el saldo interes a cobrar. */
PROCEDURE PR_OBT_SAL_INTERES
 IS
BEGIN
   pap_cob.g_val_retorno := rg_pcuot.sal_interes;
   rg_pctmp.mto_interes  := rg_pcuot.sal_interes;
END;
/* Obtener mora de capital. */
PROCEDURE PR_OBT_MOR_CAPITAL
 IS
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
--- Variables auxiliares
   v_mora              pr_cuotas.sal_interes%type;
   v_dias              number(10);
   v_cobra_mora        varchar2(01);
   v_fec_ult_pag_mora  pr_cuotas.fec_ult_pago%type;
   v_pre_personal      varchar2(01);
   v_interes           number;  --- Se define asi porque debe utilizar todos los decimales que pueda
   v_mor_no_pag        pr_cobros.mto_int_moratorio%type;
   v_mor_pag           pr_cobros.mto_int_moratorio%type;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil date;
v_fec_actual date;
v_existe     varchar2(1) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
         --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
/*   select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.nro_documento3 = pap_cob.RG_PCUOT.nro_cuota
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
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = pap_cob.RG_PCUOT.nro_cuota;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_mor_cal,0)-(nvl(c.mto_int_moratorio,0)+nvl(c.mto_int_mor_des,0))),0),
          nvl(sum(nvl(c.mto_int_moratorio,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
         (select max(p.fecha), max(p.hora)
            from pr_cobros p
           where p.nro_cuenta = c.nro_cuenta
             and p.nro_cuota  = c.nro_cuota
             --- Si se le cobro o calculo
             and ((nvl(p.mto_int_moratorio,0)+nvl(p.mto_int_mor_des,0) <> 0)
                 or (nvl(p.mto_int_mor_cal,0) <> 0))
             and p.fecha =
                 (select max(p1.fecha)
                    from pr_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and p1.nro_cuota  = p.nro_cuota
                     --- Si se le cobro o calculo
                     and ((nvl(p1.mto_int_moratorio,0)+nvl(p1.mto_int_mor_des,0) <> 0)
                      or (nvl(p1.mto_int_mor_cal,0) <> 0))
                  )
            );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;

BEGIN
  v_pre_personal  := fug_obt_pardinamico('PRE_PERSONAL', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina);

  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);

  --- Calcular mora capital e interes
  if g_fec_calculo > rg_pcuot.fec_vencimiento then
     v_dias := g_fec_calculo - rg_pcuot.fec_vencimiento;
     --dias de gracia se obtiene del parametro dinamico
     --if v_dias < 7 then
     if v_dias > fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina) then
        --- Ver si el dia de vencimiento fue dia no habil
        v_cobra_mora := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
        if v_cobra_mora = 'N' then
           v_dias := 0;
        end if;
     v_fec_ult_pag_mora := lf_obt_ult_pag_mora(rg_pcpre.nro_cuenta, g_fec_calculo);
     if v_fec_ult_pag_mora is not null and v_fec_ult_pag_mora > rg_pcuot.fec_vencimiento then
        v_dias := g_fec_calculo - v_fec_ult_pag_mora;
     end if;

     --- Se calcula la mora por todos los dias vencidos, al final se resta lo pagado
     --- Interes moratorio diario
     if v_pre_personal = 'S' then
        v_interes := (rg_pcpre.val_tasa * 1.30) / 36500;
     else
        v_interes := rg_pcpre.val_tasa / 36500;
     end if;

     v_mora := round((rg_pcpre.sal_capital * v_interes * v_dias),v_redondeo);
     --- Recuperar montos de pagos anteriores
     lp_obt_mora_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_mor_no_pag, v_mor_pag);
     v_mora := round(nvl(v_mora,0) + nvl(v_mor_no_pag,0),v_redondeo);
    else
       v_interes      := 0;
       v_mora         := 0;
       v_dias         := 0;
    end if;
  else
     v_interes      := 0;
     v_mora         := 0;
     v_dias         := 0;
  end if;
  pap_cob.g_val_retorno      := v_mora;
  rg_pctmp.mto_int_moratorio := v_mora;
  rg_pctmp.mto_int_mor_cal   := v_mora;
END;
/* Obtener mora sobre interes vencido */
PROCEDURE PR_OBT_MOR_INTERES
 IS
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
--- Variables auxiliares
   v_mora_interes      pr_cuotas.sal_interes%type;
   v_dias              number(10);
   v_cobra_mora        varchar2(01);
   v_fec_ult_pag_mora  pr_cuotas.fec_ult_pago%type;
   v_pre_personal      varchar2(01);
   v_interes           number;  --- Se define asi porque debe utilizar todos los decimales que pueda
   v_mor_no_pag        pr_cobros.mto_int_moratorio%type;
   v_mor_pag           pr_cobros.mto_int_moratorio%type;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil date;
v_fec_actual date;
v_existe     varchar2(1) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
	     --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
/*   select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.nro_documento3 = pap_cob.RG_PCUOT.nro_cuota
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
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = pap_cob.RG_PCUOT.nro_cuota;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_mor_int_cal,0)-(nvl(c.mto_int_mor_interes,0)+nvl(c.mto_int_mor_int_des,0))),0),
          nvl(sum(nvl(c.mto_int_mor_interes,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              --- La ultima vez que se le cobro o calculo
              and ((nvl(p.mto_int_mor_interes,0)+nvl(p.mto_int_mor_int_des,0) <> 0)
                or (nvl(p.mto_int_mor_int_cal,0) <> 0))
              and p.fecha =
                  (select max(p1.fecha)
                     from pr_cobros p1
                    where p1.nro_cuenta = p.nro_cuenta
                      and p1.nro_cuota  = p.nro_cuota
                      --- La ultima vez que se le cobro o calculo
                      and ((nvl(p1.mto_int_mor_interes,0)+nvl(p1.mto_int_mor_int_des,0) <> 0)
                        or (nvl(p1.mto_int_mor_int_cal,0) <> 0)))
            );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
BEGIN
  v_pre_personal  := fug_obt_pardinamico('PRE_PERSONAL', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina);

  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  --- Calcular mora capital e interes
  if g_fec_calculo > rg_pcuot.fec_vencimiento and nvl(rg_pcuot.sal_interes,0) > 0 then
     v_dias := g_fec_calculo - rg_pcuot.fec_vencimiento;
     --dias de gracia se obtiene del parametro dinamico
     --if v_dias < 7 then
     if v_dias > fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina) then
        --- Ver si el dia de vencimiento fue dia no habil
        v_cobra_mora := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
        if v_cobra_mora = 'N' then
           v_dias := 0;
        end if;

     v_fec_ult_pag_mora := lf_obt_ult_pag_mora(rg_pcpre.nro_cuenta, g_fec_calculo);
     if v_fec_ult_pag_mora is not null and v_fec_ult_pag_mora > rg_pcuot.fec_vencimiento then
        v_dias := g_fec_calculo - v_fec_ult_pag_mora;
     end if;
     --- Se calcula el interes que debe pagar por el periodo vencido
     --- Interes moratorio diario
     if v_pre_personal = 'S' then
        v_interes := (rg_pcpre.val_tasa * 1.30) / 36500;
     else
        v_interes := rg_pcpre.val_tasa / 36500;
     end if;
     if rg_pcuot.sal_interes > 0 then
        -- calculo la mora que corresponde al interes
        v_mora_interes := round((rg_pcuot.sal_interes*v_interes*v_dias),v_redondeo);
     end if;
     --- Recuperar montos de pagos anteriores
     lp_obt_mora_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_mor_no_pag, v_mor_pag);
     v_mora_interes := round(nvl(v_mora_interes,0) + nvl(v_mor_no_pag,0),v_redondeo);
   else
     v_interes      := 0;
     v_mora_interes := 0;
     v_dias         := 0;
   end if;
  else
     v_interes      := 0;
     v_mora_interes := 0;
     v_dias         := 0;
  end if;
  pap_cob.g_val_retorno        := v_mora_interes;
  -- rg_pctmp.dia_mora            := v_dias;
  rg_pctmp.mto_int_mor_interes := v_mora_interes;
  rg_pctmp.mto_int_mor_int_cal := v_mora_interes;
END;
/* Obtener mora sobre interes adelantado */
PROCEDURE PR_OBT_MOR_INT_ADE
 IS
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
--- Variables auxiliares
   v_mora_int_ade      pr_cuotas.sal_int_documentado%type;
   v_dias              number(10);
   v_cobra_mora        varchar2(01);
   v_fec_ult_pag_mora  pr_cuotas.fec_ult_pago%type;
   v_pre_personal      varchar2(01);
   v_interes           number;  --- Se define asi porque debe utilizar todos los decimales que pueda
   v_mor_no_pag        pr_cobros.mto_int_moratorio%type;
   v_mor_pag           pr_cobros.mto_int_moratorio%type;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil date;
v_fec_actual date;
v_existe     varchar(2) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
	     --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
/*   select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.nro_documento3 = pap_cob.RG_PCUOT.nro_cuota
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
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = pap_cob.RG_PCUOT.nro_cuota;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_mor_ade_cal,0)-(nvl(c.mto_int_mor_adelantado,0) + nvl(c.mto_int_mor_ade_des,0))),0),
          nvl(sum(nvl(c.mto_int_mor_adelantado,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              --- Si pago o se le calculo
              and ( (nvl(p.mto_int_mor_adelantado,0) + nvl(p.mto_int_mor_ade_des,0) <> 0)
                 or (nvl(p.mto_int_mor_ade_cal,0) <> 0) )
              and p.fecha =
                  (select max(p1.fecha)
                     from pr_cobros p1
                    where p1.nro_cuenta = p.nro_cuenta
                      and p1.nro_cuota  = p.nro_cuota
                      --- Si pago o se le calculo
                      and ( (nvl(p1.mto_int_mor_adelantado,0) + nvl(p1.mto_int_mor_ade_des,0) <> 0)
                         or (nvl(p1.mto_int_mor_ade_cal,0) <> 0) ))
           );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
BEGIN
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  --- Calcular mora capital e interes
  if g_fec_calculo > rg_pcuot.fec_vencimiento and nvl(rg_pcuot.sal_int_documentado,0) > 0 then
     v_dias := g_fec_calculo - rg_pcuot.fec_vencimiento;
     --dias de gracia se obtiene del parametro dinamico
     --if v_dias < 7 then
     if v_dias > fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina) then
        --- Ver si el dia de vencimiento fue dia no habil
        v_cobra_mora := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
        if v_cobra_mora = 'N' then
           v_dias := 0;
        end if;

     v_fec_ult_pag_mora := lf_obt_ult_pag_mora(rg_pcpre.nro_cuenta, g_fec_calculo);
     if v_fec_ult_pag_mora is not null and v_fec_ult_pag_mora > rg_pcuot.fec_vencimiento then
        v_dias := g_fec_calculo - v_fec_ult_pag_mora;
     end if;
     --- Interes moratorio diario
     v_interes := rg_pcpre.val_tasa / 36500;
     if rg_pcuot.sal_int_documentado > 0 then
        -- calculo la mora que corresponde al interes adelantado --------
        v_mora_int_ade := round((rg_pcuot.sal_int_documentado*v_interes*v_dias),v_redondeo);
     end if;
      --- Recuperar montos de pagos anteriores
      lp_obt_mora_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_mor_no_pag, v_mor_pag);
      v_mora_int_ade := round(nvl(v_mora_int_ade,0) + nvl(v_mor_no_pag,0),v_redondeo);
    else
     v_interes      := 0;
     v_mora_int_ade := 0;
     v_dias         := 0;
    end if;
  else
     v_interes      := 0;
     v_mora_int_ade := 0;
     v_dias         := 0;
  end if;
  pap_cob.g_val_retorno           := v_mora_int_ade;
  rg_pctmp.mto_int_mor_adelantado := v_mora_int_ade;
  rg_pctmp.mto_int_mor_ade_cal    := v_mora_int_ade;
END;
/* Obtener cargos por cobro de prestamos. */
PROCEDURE PR_OBT_CAR_COBRO
 IS
PROCEDURE LP_OBT_CARGO_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
   v_cargo             pr_cuotas.sal_interes%type;
   v_cargo_iva         pr_cuotas.sal_interes%type;
   v_seguro            pr_cuotas.sal_interes%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   v_cod_tasa          ge_tasas.cod_tasa%type;
   v_dias              number(10);
   v_pre_personal      varchar2(01);
   --- Variables de recuperacion de tasa
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_car_no_pag        pr_cobros.mto_int_moratorio%type;
   v_car_pag           pr_cobros.mto_int_moratorio%type;

PROCEDURE LP_OBT_CARGO_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_cargo_cal,0)-(nvl(c.mto_cargo,0) + nvl(c.mto_car_des,0))),0),
          nvl(sum(nvl(c.mto_cargo,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              and ( (nvl(p.mto_cargo,0) + nvl(p.mto_car_des,0) <> 0)
                 or (nvl(p.mto_cargo_cal,0) <> 0) )
              and p.fecha =
                 (select max(p1.fecha)
                    from pr_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and p1.nro_cuota  = p.nro_cuota
                     and ( (nvl(p1.mto_cargo,0) + nvl(p1.mto_car_des,0) <> 0)
                        or (nvl(p1.mto_cargo_cal,0) <> 0) ) )
          );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
BEGIN
  v_dias := rg_pctmp.dia_mora;
  v_dias := pap_cob.g_fec_calculo - nvl(rg_pcuot.fec_ult_pago, rg_pcuot.fec_vencimiento);
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  if v_dias > 0 then
    v_pre_personal  := fug_obt_pardinamico('PRE_PERSONAL', rg_pcpre.cod_modulo,
                       rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina);
    --- Calcular el monto total de la cuota
    v_mto_cuota        := nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_interes_cuo,0) +
                          nvl(rg_pctmp.mto_int_mor_cal,0) + nvl(rg_pctmp.mto_int_mor_ade_cal,0) +
                          nvl(rg_pctmp.mto_int_mor_int_cal,0);
    --- Calcular cargos


    --- Obtener el monto o porcentaje por dias atrasados
    if v_dias > 90 then
       v_cod_tasa := 622; -- Obtiene el Porcentaje
    elsif v_dias >= 0 then
       v_cod_tasa := 621; -- Obtiene el Valor a Cobrar
    end if;
    if v_pre_personal = 'S' then
       pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                               rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda, v_dias, --imp_trans
                               'N', v_cod_tasa, null, null,
                               v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
       v_cargo := v_val_tasa;
       if v_cod_tasa = 622 and nvl(v_mto_cuota,0) > 0 then
          v_cargo := round(NVL(v_mto_cuota,0) * v_val_tasa / 100, v_redondeo);
          --verificar si el monto a cobrar est� limitado x el m�nimo y m�ximo de la tasa
          v_cargo := pag_gen.FU_OBT_VAL_FINAL(v_cargo);

       end if;
    end if;
    if v_pre_personal <> 'S' then --- No se cobra cargo por prestamos no personales
       v_cargo := 0;
    end if;
  end if;

  --- Recuperar montos de pagos anteriores
  lp_obt_cargo_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_car_no_pag, v_car_pag);
  v_cargo := round(nvl(v_cargo,0) + nvl(v_car_no_pag,0),v_redondeo);
  if nvl(v_cargo,0) > 0 then
     -- Se calcula el I.V.A.   s/ el Cargo
     --v_cod_tasa := 417;
     v_cod_tasa := null;
     pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                             rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                             v_dias, 'N', v_cod_tasa, 517, --Transaccion
                             null, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
     v_cargo_iva := round(v_cargo * v_val_tasa / (100+v_val_tasa), v_redondeo);
  end if;
  pap_cob.g_val_retorno    := v_cargo;
  rg_pctmp.mto_cargo_cal   := v_cargo;
  rg_pctmp.mto_car_iva_cal := v_cargo_iva;
END;
/* Obtener el saldo capital a cobrar. */
PROCEDURE PR_OBT_SAL_INT_ADE
 IS
BEGIN
   pap_cob.g_val_retorno        := rg_pcuot.sal_int_documentado;
   rg_pctmp.mto_int_documentado := rg_pcuot.sal_int_documentado;
END;
/* Obtener impuesto Transaccion 709 */
PROCEDURE PR_OBT_IMPUESTO
 IS
 v_fec_tasa ge_tas_fechas.fec_vencimiento%type;
 -------------------------
 v_iva_divisor  number; 
 v_iva_pro_int  number;

PROCEDURE LP_OBT_IMP_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
/* Obtener ultimo pago de moras o punitorio */
FUNCTION LF_OBT_ULT_PAG_IMPU
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
   v_impuesto          pr_cuotas.sal_interes%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   v_dias              number(10);
   --- Variables de recuperacion de tasa
   v_cod_tasa          ge_tasas.cod_tasa%type;
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_fec_ult_pag_impu  pr_cuotas.fec_ult_pago%type;
   v_imp_no_pag        pr_cobros.mto_impuesto%type;
   v_imp_pag           pr_cobros.mto_impuesto%type;
   v_iva               number;

PROCEDURE LP_OBT_IMP_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_impuesto_cal,0)-nvl(c.mto_impuesto,0)),0),
          nvl(sum(nvl(c.mto_impuesto,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              and p.fecha =
                 (select max(p1.fecha)
                    from pr_cobros p1
                   where p.nro_cuenta = p1.nro_cuenta
                     and p.nro_cuota  = p1.nro_cuota)

           );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
/* Obtener ultimo pago de moras o punitorio */
FUNCTION LF_OBT_ULT_PAG_IMPU
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
   select fecha
     into v_max_fec_pago
     from pr_cobros cob
    where cob.nro_cuenta = p_nro_cuenta
      and cob.nro_cuota = pap_cob.rg_pcuot.nro_cuota
      and (cob.fecha, cob.hora) =
         (select max(mor.fecha), max(mor.hora)
            from pr_cobros mor
           where mor.nro_cuenta = cob.nro_cuenta
             and mor.nro_cuota  = cob.nro_cuota
             --- Que halla cancelado todos los cargos a esa fecha
             and   (nvl(mor.mto_int_moratorio,0)+nvl(mor.mto_int_mor_des,0) = nvl(mor.mto_int_mor_cal,0))
               and (nvl(mor.mto_int_mor_interes,0)+nvl(mor.mto_int_mor_int_des,0) = nvl(mor.mto_int_mor_int_cal,0))
               and (nvl(mor.mto_int_mor_adelantado,0)+nvl(mor.mto_int_mor_ade_des,0) = nvl(mor.mto_int_mor_ade_cal,0))
               and (nvl(mor.mto_int_punitorio,0)+nvl(mor.mto_int_pun_des,0) = nvl(mor.mto_int_pun_cal,0))
             and mor.fecha =
                (select max(mor1.fecha)
                   from pr_cobros mor1
                  where mor1.nro_cuenta = mor.nro_cuenta
                    and mor1.nro_cuota  = mor.nro_cuota
                    --- Que halla cancelado todos los cargos a esa fecha
                    and   (nvl(mor1.mto_int_moratorio,0)+nvl(mor1.mto_int_mor_des,0) = nvl(mor1.mto_int_mor_cal,0))
                      and (nvl(mor1.mto_int_mor_interes,0)+nvl(mor1.mto_int_mor_int_des,0) = nvl(mor1.mto_int_mor_int_cal,0))
                      and (nvl(mor1.mto_int_mor_adelantado,0)+nvl(mor1.mto_int_mor_ade_des,0) = nvl(mor1.mto_int_mor_ade_cal,0))
                      and (nvl(mor1.mto_int_punitorio,0)+nvl(mor1.mto_int_pun_des,0) = nvl(mor1.mto_int_pun_cal,0))
                )
          );
   return v_max_fec_pago;
exception
   when no_data_found then
      return pap_cob.rg_pcuot.fec_vencimiento;
   when others then
       raise_application_error(-20000,
       'Rec.Fec.Impuesto '||p_nro_cuenta||' Cuota '||pap_cob.rg_pcuot.nro_cuota);
END;

BEGIN
  v_dias := rg_pctmp.dia_mora;
  v_fec_ult_pag_impu := lf_obt_ult_pag_impu(rg_pcpre.nro_cuenta, g_fec_calculo);
  pap_cob.g_iva_interes := 0;
  if v_fec_ult_pag_impu is not null and v_fec_ult_pag_impu > rg_pcuot.fec_vencimiento then
     v_dias := g_fec_calculo - v_fec_ult_pag_impu;
  end if;
  --- Calcular el monto total de la cuota
  v_mto_cuota        := --- nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_interes_cuo,0) + Ya no debe generar sobre capital e interes.
                        nvl(rg_pctmp.mto_int_mor_cal,0) + nvl(rg_pctmp.mto_int_mor_ade_cal,0) +
                        nvl(rg_pctmp.mto_int_mor_int_cal,0) + nvl(rg_pctmp.mto_int_punitorio,0);
  --- Calcular cargos
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  --
  v_iva_divisor := to_number(nvl(fug_obt_pardinamico('PRE_CHE_ROG_VAL_DIVISOR',rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,null, null,null),'1'),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.'''); 
  v_iva_pro_int := to_number(nvl(fug_obt_pardinamico('PRE_CHE_ROG_POR_IVA_CAL',rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,null, null,null),'1'),'999G999D999999', 'NLS_NUMERIC_CHARACTERS='',.''');                  
      

  --- Obtener tasa de impuestos
  pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                          rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                          v_dias, 'N', v_cod_tasa, 709, --Transaccion
                          pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
  --- Obtener el monto o porcentaje por dias atrasados
  if v_dias > 0 then
     --if v_dias > 365 then
     --   v_dias := 365;
     --end if;
     --- v_impuesto := round(v_mto_cuota * v_val_tasa * v_dias / 36500, v_redondeo);

     v_impuesto := round(nvl(rg_pctmp.mto_int_mor_cal,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(rg_pctmp.mto_int_mor_ade_cal,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(rg_pctmp.mto_int_mor_int_cal,0) * (v_val_tasa / 100), v_redondeo) +
                   round(nvl(rg_pctmp.mto_int_punitorio,0) * (v_val_tasa / 100), v_redondeo);
  end if;
  ---RI : 28/05/2010 : Verificar si se cobro iva
  Select count(*) into v_iva
    from pr_sol_cargos
   where nro_solicitud = rg_pcpre.nro_solicitud
     and cod_Transaccion = 709;

  ---RI : 28/05/2010 aqui le suma el impuesto sobre el interes si el mismo
  -- no fue cobrado en el desembolso.
  If nvl(v_iva,0) = 0 then
    --RI : 15/06/2010: si la cuota esta vencida guardar el monto
    --del iva en campo auxiliar para generar despues una transaccion
    --diferenciada por ese monto
    If rg_pcuot.fec_vencimiento < pap_cob.g_fec_calculo then
       v_fec_tasa := rg_pcuot.fec_vencimiento;

       pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                          rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                          v_dias, 'N', v_cod_tasa, 709, --Transaccion
                          v_fec_tasa, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
       pap_cob.g_iva_interes := round(nvl(rg_pctmp.mto_interes,0) * (v_val_tasa / 100), v_redondeo);
    else
      pap_cob.g_iva_interes := 0;
    end if;
    
    -- IF rg_pcpre.cod_modalidad = 668 THEN
  if   nvl(fug_obt_pardinamico('COD_MOD_CHE_ROGA', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad),'N') = 'S' THEN
       --v_cal_iva := round(((nvl(v_sal_interes,0) / v_iva_divisor * v_iva_pro_int/100) * v_val_tasa /100),v_redondeo);
       v_impuesto := nvl(v_impuesto,0)+
                  round(((nvl(rg_pctmp.mto_interes,0) / v_iva_divisor * v_iva_pro_int/100) * (v_val_tasa / 100)), v_redondeo);
    ELSE                  
       v_impuesto := nvl(v_impuesto,0)+
                  round(nvl(rg_pctmp.mto_interes,0) * (v_val_tasa / 100), v_redondeo);
    END IF;

   -- v_impuesto := nvl(v_impuesto,0)+
   --               round(nvl(rg_pctmp.mto_interes,0) * (v_val_tasa / 100), v_redondeo);
  end if;
  --- Se debe retornar los dias de mora desde el ultimo pago en que se
  --- pago impuestos por algun cargo
  rg_pctmp.dia_mora         := v_dias;
  pap_cob.g_val_retorno     := v_impuesto;
  rg_pctmp.mto_impuesto     := v_impuesto;
  rg_pctmp.mto_impuesto_cal := v_impuesto;
END;
/* Obtener interes punitorio */
PROCEDURE PR_OBT_PUNITORIO
 IS

PROCEDURE LP_OBT_PUN_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
   v_cargo             pr_cuotas.sal_interes%type;
   v_mto_cuota         pr_cuotas.sal_capital%type;
   v_dias              number(10);
   v_por_tasa          number(07,2);
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_pun_no_pag        pr_cobros.mto_impuesto%type;
   v_pun_pag           pr_cobros.mto_impuesto%type;
   v_fec_ult_pag_puni  pr_cuotas.fec_ult_pago%type;
   v_cobra_mora        varchar2(01);

PROCEDURE LP_OBT_PUN_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_pun_cal,0)-(nvl(c.mto_int_punitorio,0) + nvl(c.mto_int_pun_des,0))),0),
          nvl(sum(nvl(c.mto_int_punitorio,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              and ( (nvl(p.mto_int_punitorio,0) + nvl(p.mto_int_pun_des,0) <> 0)
                 or (nvl(p.mto_int_pun_cal,0) <> 0) )
              and p.fecha =
                 (select max(p1.fecha)
                    from pr_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and p1.nro_cuota  = p.nro_cuota
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
v_existe     varchar2(2) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
	     --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de punitorio */
FUNCTION LF_OBT_ULT_PAG_PUNI
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
/* Obtener ultimo pago de punitorio */
FUNCTION LF_OBT_ULT_PAG_PUNI
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
/*   select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.nro_documento3 = pap_cob.RG_PCUOT.nro_cuota
      and mov.cod_transaccion = 849; -- Transaccion de Punitorio*/
   if v_max_fec_pago is null then
      select max(fec_ult_pago)
        into v_max_fec_pago
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = pap_cob.RG_PCUOT.nro_cuota;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
BEGIN
  v_dias := pap_cob.g_fec_calculo - rg_pcuot.fec_vencimiento;
  v_fec_ult_pag_puni := lf_obt_ult_pag_puni(rg_pcpre.nro_cuenta, g_fec_calculo);
  if v_fec_ult_pag_puni is not null and v_fec_ult_pag_puni > rg_pcuot.fec_vencimiento then
     v_dias := g_fec_calculo - v_fec_ult_pag_puni;
  end if;
  --- Calcular cargos
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  if v_dias > 0 then
    --- Calcular el monto original de la cuota
    if v_dias > fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina) then
        --- Ver si el dia de vencimiento fue dia no habil
        v_cobra_mora := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
        if v_cobra_mora = 'N' then
           v_dias := 0;
        end if;
    else
        v_dias := 0;
    end if;
  end if;
  if v_dias > 0 then
    --RI: 03/08/2010: En BBVA se toma capital + interes
    --if fug_obt_tip_implementacion in (1,7) then
    --   -- solo se toma el capital en el BR.
    --   v_mto_cuota := nvl(rg_pctmp.sal_capital_cuo,0);
    --else
       v_mto_cuota        := nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_interes_cuo,0)+nvl(rg_pctmp.sal_int_documentado,0);
    --end if;
    --- Recuperar porcentaje de tasa a aplicar sobre tasa original
    v_por_tasa         := fug_obt_pardinamico('POR_TAS_PUNITORIO', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                                              rg_pcpre.cod_moneda, rg_pcpre.cod_oficina);
    v_val_tasa         := rg_pcpre.val_tasa * v_por_tasa / 100;
    v_cargo := round(v_mto_cuota * v_val_tasa * v_dias / 36500 ,v_redondeo);
    --
  else
    v_cargo := 0;
  end if;
  --- Recuperar montos de pagos anteriores
  lp_obt_pun_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_pun_no_pag, v_pun_pag);
  v_cargo                    := round(nvl(v_cargo,0) + nvl(v_pun_no_pag,0),v_redondeo);
  pap_cob.g_val_retorno      := v_cargo;
  rg_pctmp.mto_int_punitorio := v_cargo;
  rg_pctmp.mto_int_pun_cal   := v_cargo;
END;
/* Obtener mora de capital. */
PROCEDURE PR_OBT_MOR_CAP_CUOTA
 IS
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
--- Variables auxiliares
   v_mora              pr_cuotas.sal_interes%type;
   v_dias              number(10);
   v_cobra_mora        varchar2(01);
   v_fec_ult_pag_mora  pr_cuotas.fec_ult_pago%type;
   v_interes           number;  --- Se define asi porque debe utilizar todos los decimales que pueda
   v_mor_no_pag        pr_cobros.mto_int_moratorio%type;
   v_mor_pag           pr_cobros.mto_int_moratorio%type;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil  date;
v_fec_actual date;
v_existe     varchar2(1) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
	     --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
/*   select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.NRO_DOCUMENTO3 = pap_cob.RG_PCUOT.nro_cuota
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
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = pap_cob.rg_pcuot.nro_cuota;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_mor_cal,0)-(nvl(c.mto_int_moratorio,0)+nvl(c.mto_int_mor_des,0))),0),
          nvl(sum(nvl(c.mto_int_moratorio,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              and ( (nvl(p.mto_int_moratorio,0)+nvl(p.mto_int_mor_des,0) <> 0)
                 or (nvl(p.mto_int_mor_cal,0) <> 0) )
              and p.fecha =
                 (select max(p1.fecha)
                    from pr_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and p1.nro_cuota  = p.nro_cuota
                     and ( (nvl(p1.mto_int_moratorio,0)+nvl(p1.mto_int_mor_des,0) <> 0)
                        or (nvl(p1.mto_int_mor_cal,0) <> 0) )
                 )
          );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
BEGIN
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  --- Calcular mora capital e interes
  if pap_cob.g_fec_calculo > rg_pcuot.fec_vencimiento then
     v_dias := g_fec_calculo - rg_pcuot.fec_vencimiento;
     --dias de gracia se obtiene del parametro dinamico
     --if v_dias < 7 then
     if v_dias > fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina) then
        --- Ver si el dia de vencimiento fue dia no habil
        v_cobra_mora := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
        if v_cobra_mora = 'N' then
           v_dias := 0;
        end if;

       v_fec_ult_pag_mora := lf_obt_ult_pag_mora(rg_pcpre.nro_cuenta, g_fec_calculo);
       if v_fec_ult_pag_mora is not null and v_fec_ult_pag_mora > rg_pcuot.fec_vencimiento then
          v_dias := g_fec_calculo - v_fec_ult_pag_mora;
       end if;
       v_mora := round((rg_pcuot.sal_capital * rg_pcpre.val_tasa * v_dias/36500),v_redondeo);
       --- Recuperar montos de pagos anteriores
       lp_obt_mora_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_mor_no_pag, v_mor_pag);
       v_mora := round(nvl(v_mora,0) + nvl(v_mor_no_pag,0),v_redondeo);
    else
     v_interes      := 0;
     v_mora         := 0;
     v_dias         := 0;
    end if;
  else
     v_interes      := 0;
     v_mora         := 0;
     v_dias         := 0;
  end if;
  pap_cob.g_val_retorno      := v_mora;
  rg_pctmp.mto_int_moratorio := v_mora;
  rg_pctmp.mto_int_mor_cal   := v_mora;
END;
/* Obtener mora sobre interes vencido */
PROCEDURE PR_OBT_MOR_INT_CUOTA
 IS
/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 );
--- Variables auxiliares
   v_mora_interes      pr_cuotas.sal_interes%type;
   v_dias              number(10);
   v_cobra_mora        varchar2(01);
   v_fec_ult_pag_mora  pr_cuotas.fec_ult_pago%type;
   v_interes           number;  --- Se define asi porque debe utilizar todos los decimales que pueda
   v_mor_no_pag        pr_cobros.mto_int_moratorio%type;
   v_mor_pag           pr_cobros.mto_int_moratorio%type;

/* Verifica si corresponde o no cobrar mora para la fecha, */
FUNCTION LF_VER_COB_MORA
 (P_FECHA IN DATE
 ,P_COD_OFICINA IN PR_MOVIMIENTOS_HIS.COD_OFI_ORIGEN%TYPE
 )
 RETURN VARCHAR2
 IS
v_fec_habil date;
v_fec_actual date;
v_existe     varchar2(1) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
	     --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
      end if;
   end if;
END;
/* Obtener ultimo pago de mora. */
FUNCTION LF_OBT_ULT_PAG_MORA
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_CUOTAS.FEC_ULT_PAGO%TYPE
 )
 RETURN DATE
 IS
v_max_fec_pago  ge_movimientos.fec_valor%type;
BEGIN
/*   select max(fec_valor)
     into v_max_fec_pago
     from gv_movimientos mov
    where mov.nro_cuenta = p_nro_cuenta
      and mov.reversado = 'N'
      and mov.nro_documento3 = pap_cob.RG_PCUOT.nro_cuota
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
        from pr_cuotas
       where nro_cuenta = p_nro_cuenta
         and nro_cuota = pap_cob.RG_PCUOT.nro_cuota;
   end if;
   return v_max_fec_pago;
exception
   when others then return null;
END;
PROCEDURE LP_OBT_MORA_PAG_ANT
 (P_NRO_CUENTA IN PR_CUOTAS.NRO_CUENTA%TYPE
 ,P_NRO_CUOTA IN PR_CUOTAS.NRO_CUOTA%TYPE
 ,P_MTO_NO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 ,P_MTO_PAG IN OUT PR_COBROS.MTO_INT_MORATORIO%TYPE
 )
 IS
BEGIN
   select nvl(sum(nvl(c.mto_int_mor_int_cal,0)-(nvl(c.mto_int_mor_interes,0)+nvl(c.mto_int_mor_int_des,0))),0),
          nvl(sum(nvl(c.mto_int_mor_interes,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and (c.fecha, c.hora) =
          (select max(p.fecha), max(p.hora)
             from pr_cobros p
            where p.nro_cuenta = c.nro_cuenta
              and p.nro_cuota  = c.nro_cuota
              --- La ultima vez que pago o se le calculo
              and ( (nvl(p.mto_int_mor_interes,0) + nvl(p.mto_int_mor_int_des,0) <> 0)
                 or (nvl(p.mto_int_mor_int_cal,0) <> 0) )
              and p.fecha =
                 (select max(p1.fecha)
                    from pr_cobros p1
                   where p1.nro_cuenta = p.nro_cuenta
                     and p1.nro_cuota  = p.nro_cuota
                     --- La ultima vez que pago o se le calculo
                     and ( (nvl(p1.mto_int_mor_interes,0) + nvl(p1.mto_int_mor_int_des,0) <> 0)
                        or (nvl(p1.mto_int_mor_int_cal,0) <> 0) )
                 )
          );
  if p_mto_no_pag < 0 then
     p_mto_no_pag := 0;
  end if;
END;
BEGIN
  v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
  --- Calcular mora capital e interes
  if pap_cob.g_fec_calculo > rg_pcuot.fec_vencimiento and nvl(rg_pcuot.sal_interes,0) > 0 then
     v_dias := g_fec_calculo - rg_pcuot.fec_vencimiento;
     --dias de gracia se obtiene del parametro dinamico
     --if v_dias < 7 then
     if v_dias > fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo,
                     rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina) then
        --- Ver si el dia de vencimiento fue dia no habil
        v_cobra_mora := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
        if v_cobra_mora = 'N' then
           v_dias := 0;
        end if;

     v_fec_ult_pag_mora := lf_obt_ult_pag_mora(rg_pcpre.nro_cuenta, g_fec_calculo);
     if v_fec_ult_pag_mora is not null and v_fec_ult_pag_mora > rg_pcuot.fec_vencimiento then
        v_dias := g_fec_calculo - v_fec_ult_pag_mora;
     end if;
     --- Interes moratorio diario
     v_interes := rg_pcpre.val_tasa / 36500;
     if rg_pcuot.sal_interes > 0 then
        -- calculo la mora que corresponde al interes
        v_mora_interes := round((rg_pcuot.sal_interes*v_interes*v_dias),v_redondeo);
     end if;
     --- Recuperar montos de pagos anteriores
     lp_obt_mora_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_mor_no_pag, v_mor_pag);
     v_mora_interes := round(nvl(v_mora_interes,0) + nvl(v_mor_no_pag,0),v_redondeo);

    else
     v_interes      := 0;
     v_mora_interes := 0;
     v_dias         := 0;
    end if;
  else
     v_interes      := 0;
     v_mora_interes := 0;
     v_dias         := 0;
  end if;
  pap_cob.g_val_retorno        := v_mora_interes;
  rg_pctmp.mto_int_mor_interes := v_mora_interes;
  rg_pctmp.mto_int_mor_int_cal := v_mora_interes;
END;
/* Obtener cargos por montos y plazos. */
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
   v_cod_transaccion   ge_transacciones.cod_transaccion%type;
   v_tra_iva           ge_transacciones.cod_transaccion%type;
   v_cod_tasa          ge_tasas.cod_tasa%type;
   v_cod_tasa_plazo    ge_tas_fechas.val_tasa%type;
   v_dias              number(10);
   v_pre_personal      varchar2(01);
   --- Variables de recuperacion de tasa
   v_car_cancelacion   number(18,2);
   v_aplicar           ge_tasas.aplicar%type;
   v_val_tasa          ge_tas_fechas.val_tasa%type;
   v_fec_vigencia      ge_tas_fechas.fec_vigencia%type;
   v_tip_valor         ge_tasas.tip_valor%type;
   v_tipo              ge_tasas.tipo%type;
   v_car_no_pag        pr_cobros.mto_int_moratorio%type;
   v_car_pag           pr_cobros.mto_int_moratorio%type;
   v_fec_ult_pag_cargo pr_cobros.fecha%type;
   v_cob_cargos        varchar2(1);
   v_mto_min_permitido number;
   v_mto_max_permitido number;
   -- Cursor de Cargos
   cursor gastos_varios is
        select monto, cod_transaccion
          from pr_cta_gastos
         where nro_cuenta    = rg_pcpre.nro_cuenta
           and cod_modalidad = rg_pcpre.cod_modalidad
           and (((fec_ini_vigencia <= pap_cob.g_max_fec_calculo or fec_ini_vigencia is null )
           and  (fec_ini_vigencia >  pap_cob.g_max_fec_calculo_ant or pap_cob.g_max_fec_calculo_ant is null  or fec_ini_vigencia is null)
           and   nro_solicitud is not null)
            or  ((fec_vencimiento  >= pap_cob.g_fec_calculo or fec_vencimiento is null) and nro_solicitud is null and pap_cob.g_cal_adic = 'S'))
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
          nvl(sum(nvl(c.mto_cargo,0)-nvl(c.mto_cargo_iva,0)),0)
     into p_mto_no_pag, P_MTO_PAG
     from pr_cobros c
    where c.nro_cuenta = p_nro_cuenta
      and c.nro_cuota  = p_nro_cuota
      and c.fecha      > v_fec_ult_pag_cargo;
/*      and (c.fecha, c.hora) = (select max(p.fecha), max(p.hora)
                       from pr_cobros p
                      where p.nro_cuenta = c.nro_cuenta
                        and p.nro_cuota= c.nro_cuota
                        and ( ((nvl(c.mto_cargo,0)+nvl(c.mto_car_des,0))-nvl(c.mto_cargo_iva,0) <> 0)
                            or (nvl(c.mto_cargo_cal,0) <> 0) ) );*/
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
v_existe     varchar2(1) := 'N';
BEGIN
   -- Verificar si la fecha es un dia habil
   v_fec_habil := pag_cal.FU_OBT_FEC_HABIL(p_fecha,1,p_cod_oficina);
   v_fec_actual := pag_cal.fu_obt_fec_actual(6);
   if p_fecha = v_fec_habil then
      -- El vencimiento de la cuota es un dia habil, debe cobrarse mora
      return 'S';
   else
      if v_fec_habil != v_fec_actual or
         g_fec_calculo != v_fec_actual then
         -- si el siguiente dia habil no es hoy se le debe cobrar mora.
         return 'S';
      else
	     --DYDMR-2615-CRO-12/01/2015: Para que cobre mora cuando el cliente paga con cheque cargo otros bancos.
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
         -- No es dia habil, no corresponde cobrar mora
         --return 'N';
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
   select fecha
     into v_max_fec_pago
     from pr_cobros cob
    where cob.nro_cuenta = p_nro_cuenta
      and cob.nro_cuota = pap_cob.rg_pcuot.nro_cuota
      and (cob.fecha, cob.hora) =
         (select max(mor.fecha), max(mor.hora)
            from pr_cobros mor
           where mor.nro_cuenta = cob.nro_cuenta
             and mor.nro_cuota  = cob.nro_cuota
             --- Que halla cancelado todos los cargos a esa fecha
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
                    --- Que halla cancelado todos los cargos a esa fecha
                    and   (nvl(mor1.mto_int_moratorio,0)+nvl(mor1.mto_int_mor_des,0) = nvl(mor1.mto_int_mor_cal,0))
                      and (nvl(mor1.mto_int_mor_interes,0)+nvl(mor1.mto_int_mor_int_des,0) = nvl(mor1.mto_int_mor_int_cal,0))
                      and (nvl(mor1.mto_int_mor_adelantado,0)+nvl(mor1.mto_int_mor_ade_des,0) = nvl(mor1.mto_int_mor_ade_cal,0))
                      and (nvl(mor1.mto_int_punitorio,0)+nvl(mor1.mto_int_pun_des,0) = nvl(mor1.mto_int_pun_cal,0))
                      and (nvl(mor1.mto_cargo,0)+nvl(mor1.mto_car_des,0) = nvl(mor1.mto_cargo_cal,0))
                 )
          );
   if v_max_fec_pago < pap_cob.rg_pcuot.fec_vencimiento then
      v_max_fec_pago := pap_cob.rg_pcuot.fec_vencimiento;
   end if;
   return v_max_fec_pago;
exception
   when no_data_found then
      return pap_cob.rg_pcuot.fec_vencimiento;
   when others then
       raise_application_error(-20000,
       'Rec.Fec.Cargo '||p_nro_cuenta||' Cuota '||pap_cob.rg_pcuot.nro_cuota);
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
   v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
   v_fec_ult_pag_cargo := lf_obt_ult_pag_cargo(rg_pcpre.nro_cuenta, g_fec_calculo);
   v_dias := pap_cob.g_fec_calculo - v_fec_ult_pag_cargo;
   
   if v_dias > 0 then
     v_cob_cargos := lf_ver_cob_mora(rg_pcuot.fec_vencimiento, g_cod_ofi_origen);
     if v_cob_cargos = 'N' then
       v_dias := 0;
     end if;
   end if;

   if v_dias > nvl(fug_obt_pardinamico('DIA_GRA_COBRO', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad),0) THEN
      --- Calcular el monto de la cuota
      v_mto_cuota        := nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_interes_cuo,0) + nvl(rg_pctmp.sal_int_documentado,0);
      -- Calcular cargos
      -- Obtener codigo de tasa segun el monto capital
      v_cod_transaccion := 712;
      pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                             rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                             v_mto_cuota, --imp_trans
                             'N', v_cod_tasa, v_cod_transaccion, pap_cob.g_fec_calculo,
                             v_cod_tasa_plazo, v_fec_vigencia, v_tip_valor, v_tipo);
      -- Recuperar forma de aplicar de la tasa
      begin
        select aplicar into v_aplicar
          from ge_tasas where cod_tasa = v_cod_tasa;
      end;
      if v_aplicar = 'CP' then
        pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                             rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                             v_dias, 'N', v_cod_tasa_plazo, null, --Transaccion
                             pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
      else
        v_val_tasa := v_cod_tasa_plazo;
      end if;
      if v_tip_valor = 'P' then --- Porcentaje
        v_cargo := round(v_mto_cuota * v_val_tasa/100, v_redondeo);
        v_mto_min_permitido := nvl(fug_obt_pardinamico('MTO_MIN_GES_COBRANZA',rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,rg_pcpre.cod_moneda),0);
        v_mto_max_permitido := nvl(fug_obt_pardinamico('MTO_MAX_GES_COBRANZA',rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,rg_pcpre.cod_moneda),0);
        if nvl(v_mto_max_permitido,0) > 0 then
          pag_gen.pr_ini_variables(nvl(v_mto_min_permitido,0), v_mto_max_permitido);
        end if;
        --verificar si el monto a cobrar est� limitado x el m�nimo y m�ximo de la tasa
        v_cargo := pag_gen.FU_OBT_VAL_FINAL(v_cargo);
      else --- Valor
        v_cargo := v_val_tasa;
      end if;

   else
      v_cargo := 0;
   end if;

   --- Recuperar montos de pagos anteriores
   lp_obt_cargo_pag_ant(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota, v_car_no_pag, v_car_pag);
   v_cargo := round(nvl(v_cargo,0) - nvl(v_car_pag,0),v_redondeo);
   if nvl(pap_cob.g_tip_cancelacion,'N') = 'T' then
      /*   RI: 28/Ago/09 : Si el prestamo se esta renovando/reestructurando/refinanciando/desemb.en etapas
         no debe calcular cargo por cancelaci�n anticipada.*/
     if nvl(pap_cob.g_renueva,'N') = 'N' then
      -- calculo el cargo por la cancelacion anticipada
      /* RI: 17/08/2010: A pedido del banco, el cargo x cancelacion
         es el porcentaje aplicado sobre el capital pagado. */
      /*v_cargo := nvl(v_cargo,0) +
             round((nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_int_documentado,0)) *
               rg_pcpre.val_tasa * nvl(fug_obt_pardinamico('POR_CAR_CANCELACION', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina),0)  / 36500, v_redondeo);*/
       --
       v_cargo := nvl(v_cargo,0) +
            round((nvl(rg_pctmp.sal_capital_cuo,0) + nvl(rg_pctmp.sal_int_documentado,0)) *
              nvl(fug_obt_pardinamico('POR_CAR_CANCELACION', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina),0)  / 100, v_redondeo);
     End if;
   elsif nvl(pap_cob.g_tip_cancelacion,'N') = 'P' and  nvl(pap_cob.g_pri_vez,0) = 0 and pap_cob.g_cap_pagado > 0 then
      -- calculo por unica vez sobre la cuota 1
      /* RI: 17/08/2010: A pedido del banco, el cargo x cancelacion
         es el porcentaje aplicado sobre el capital pagado. */
      --
      /*v_car_cancelacion :=  round((nvl(pap_cob.g_cap_pagado,0)) *
                            rg_pcpre.val_tasa * nvl(fug_obt_pardinamico('POR_CAR_CANCELACION', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina),0)   / 36500, v_redondeo);*/
      --
      v_car_cancelacion  :=  round((nvl(pap_cob.g_cap_pagado,0)) *
                            nvl(fug_obt_pardinamico('POR_CAR_CANCELACION', rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda, rg_pcpre.cod_oficina),0) / 100 , v_redondeo);
      --
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                              rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                              v_car_cancelacion, 'N', v_cod_tasa, 517, --Transaccion iva
                              pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);

      v_car_cancelacion := nvl(v_car_cancelacion,0) +
                           round((v_car_cancelacion * v_val_tasa / 100), v_redondeo);

      v_car_cancelacion := nvl(pap_cob.g_cap_pagado,0) - (
                           nvl(pap_cob.g_cap_pagado,0) * 100 / (
                           100 + (v_car_cancelacion * 100/ nvl(pap_cob.g_cap_pagado,0))
                           ));

      v_cargo := nvl(v_cargo,0) + round((100 * v_car_cancelacion/ (100 + v_val_tasa)),v_redondeo);
   end if;
   if nvl(v_cargo,0) > 0 then
      -- Se calcula el I.V.A.   s/ el Cargo si es que esta asociado a la transaccion (712)
      --v_cod_tasa := 417;
     v_cod_transaccion := 712;
     lp_obt_tra_iva_asociada(v_cod_transaccion,rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,v_tra_iva);
     if v_tra_iva is not null then
        -- Se calcula el I.V.A. s/ el Cargo
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                              rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                              v_dias, 'N', v_cod_tasa, 517, --Transaccion
                              pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
      v_cargo_iva := round((v_cargo * v_val_tasa / 100), v_redondeo);
     end if;
   else
      v_cargo := 0;
   end if;
--   If nvl(pap_cob.g_uti_gastos,'N') = 'N' then
--     pap_cob.g_uti_gastos := 'S';
     --- Recorre el Cursor de Cargos Adicionales.
     for reg in gastos_varios loop
       v_tra_iva   := null;
       v_car_manual := reg.monto;
       --- Veo si tiene IVA asociada la transaccion del cargo
       lp_obt_tra_iva_asociada(reg.cod_transaccion,rg_pcpre.cod_modulo,rg_pcpre.cod_modalidad,v_tra_iva);
       if nvl(v_car_manual,0) > 0 and v_tra_iva is not null then
        -- Se calcula el I.V.A. s/ el Cargo
        v_cod_tasa := null;
        pag_gen.pr_obt_val_tasa(rg_pcpre.cod_modulo, rg_pcpre.cod_modalidad,
                                rg_pcpre.cod_oficina, rg_pcpre.nro_cuenta, rg_pcpre.cod_moneda,
                                0, 'N', v_cod_tasa, v_tra_iva, --Transaccion
                                pap_cob.g_fec_calculo, v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);
        --
        -- es un porcentaje
        v_cargo_iva := nvl(v_cargo_iva,0)+ round((v_car_manual * v_val_tasa / 100),v_redondeo);
       end if;
       v_Cargo := nvl(v_cargo,0) + nvl(v_car_manual,0);
     end loop;
--   End if;
   --- OBS: El cargo siempre se devuelve mas el iva.
   pap_cob.g_val_retorno    := v_cargo+nvl(v_cargo_iva,0);
   rg_pctmp.mto_cargo_cal   := v_cargo+nvl(v_cargo_iva,0);
   rg_pctmp.mto_car_iva_cal := v_cargo_iva;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20222,'Cuenta '||rg_pcpre.nro_cuenta||'. '||sqlerrm);
END;
/* Obtiene interes descontado. */
PROCEDURE PR_OBT_INTDE
 IS
   v_int_descontado    pr_cta_prestamos.val_int_devengar%type;
   v_val_int_devengar  pr_cta_prestamos.val_int_devengar%type;
   v_sal_interes       pr_cta_prestamos.sal_interes%type;
   v_sal_cuotas        pr_cuotas.sal_interes%type;
BEGIN
   --- Se descuenta hasta el 50% del interes a devengar fijo
   --- Obs: El interes a devengar se obtiene del valor original del prestamos
   --- el saldo del prestamo se debe obtener de lo actual
   --x tipo de implementacion se descuenta
   v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
   if fug_obt_tip_implementacion in (1,7) then
     --no se descuenta nada ---
     v_val_int_devengar :=  0; --- round(nvl(rg_pcpre.val_int_devengar,0),0);
     v_val_int_devengar := round(nvl(rg_pcpre.val_int_devengar,0), v_redondeo); 
   else
     --se descuenta el 50%
     v_val_int_devengar := round(nvl(rg_pcpre.val_int_devengar,0) * 50 /100, v_redondeo);
   end if;
   begin
      select sal_interes
        into v_sal_interes
        from pr_cta_prestamos
       where nro_cuenta = rg_pcpre.nro_cuenta;
   end;
   if nvl(v_sal_interes,0) = nvl(pap_cob.RG_PCPRE.sal_interes,0) then
      --- Se esta llamando desde una consulta
      --- descontar los intereses de cuotas pendientes anteriores
      select sum(sal_interes)
        into v_sal_cuotas
        from pr_cuotas
       where nro_cuenta = rg_pcpre.nro_cuenta
         and nro_cuota < rg_pcuot.nro_cuota;
      v_sal_interes := nvl(v_sal_interes,0) - nvl(v_sal_cuotas,0);
   end if;
   if pap_cob.g_tip_cancelacion = 'T' then
      --- Verificar si le corresponde descontar a la cuota
      if nvl(v_sal_interes,0) - nvl(pap_cob.rg_pcuot.sal_interes,0) >
         nvl(v_val_int_devengar,0) then
         --- No correspende descontar
         v_int_descontado := 0;
      else
         if nvl(v_sal_interes,0) > nvl(v_val_int_devengar,0) then
            v_int_descontado := nvl(pap_cob.rg_pcuot.sal_interes,0) -
                               (nvl(v_sal_interes,0) - nvl(v_val_int_devengar,0));                                                
         else
            v_int_descontado := pap_cob.rg_pcuot.sal_interes;
         end if;  
      end if;
   else
      v_int_descontado := 0;
   end if;
   pap_cob.g_val_retorno        := v_int_descontado;
   pap_cob.rg_pctmp.mto_interes := pap_cob.rg_pctmp.mto_interes - nvl(v_int_descontado,0);
END;
/* Obtener el saldo capital luego del pago adelantado */
PROCEDURE PR_OBT_CAP_ADELANTADO
 IS
   v_dias               pr_cobros.dia_mora%type;
   v_cap_adelantado     pr_cta_prestamos.sal_capital%type := 0;
   v_int_nuevo          pr_cuotas.sal_interes%type := 0;
   v_sal_anterior       pr_cta_prestamos.sal_capital%type := 0;
   v_fec_ven_anterior   date;
   v_tot_int_descontado number(18,2) := 0;
   v_int_pagado         number(18,2);
   v_int_amortizado     number(18,2) := nvl(pap_cob.g_tot_int_pag,0);
   function fl_min_cuo_vig return number
   is
     v_cuota pr_cuotas.nro_cuota%type;
   begin
      select min(nro_cuota)
        into v_cuota
        from pr_cuotas
       where nro_cuota > 0
         and estado <> 'N'
         and fec_vencimiento >= rg_pctmp.fec_valor
         and nro_cuenta = rg_pcuot.nro_cuenta;
      return v_cuota;
   end;
BEGIN
   -- no pueden existir cuotas vencidas
/*   if rg_pctmp.fec_vencimiento <= rg_pctmp.fec_valor then
      raise_application_error(-20000, 'El prestamo '||rg_pctmp.nro_cuenta||' tiene la cuota '||rg_pcuot.nro_cuota||' ya vencida al '||rg_pctmp.fec_valor||'. No se puede cancelar');
   end if;
*/   -- no puede tener interes adelantado
   if rg_pctmp.mto_int_documentado > 0 then
      raise_application_error(-20000, 'El prestamo '||rg_pctmp.nro_cuenta||' tiene interes adelantado. No se puede cancelar');
   end if;

   if nvl(pap_cob.g_cap_pagado,0) <> 0 then
      if rg_pcuot.nro_cuota = fl_min_cuo_vig then
         v_fec_ven_anterior     := rg_pctmp.fec_valor;
         v_sal_anterior         := nvl(pap_cob.g_sal_capital_pre,0) - nvl(pap_cob.g_cap_pagado,0);
         pap_cob.g_sal_anterior := v_sal_anterior;
      else
         v_fec_ven_anterior     := pap_dev.fu_obt_fec_ini_cuota(rg_pcpre.nro_cuenta, rg_pcuot.nro_cuota);
         v_sal_anterior     := nvl(pap_cob.g_sal_anterior,0);
      end if;
      v_redondeo:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, rg_pcpre.cod_modalidad, rg_pcpre.cod_moneda);
      v_dias := rg_pcuot.fec_vencimiento - v_fec_ven_anterior;
      if rg_pcuot.nro_cuota = rg_pcpre.can_cuotas then
         -- es la ultima cuota, se aplica el saldo
         v_cap_adelantado := pap_cob.g_cap_pagado - nvl(pap_cob.g_tot_cap_ade,0);
      else
         v_cap_adelantado := round(rg_pcuot.sal_capital * (pap_cob.g_cap_pagado / pap_cob.g_sal_capital_pre),v_redondeo);
      end if;
      v_int_nuevo      := round(v_sal_anterior * rg_pcpre.val_tasa * v_dias / 36500,v_redondeo);
      if v_int_amortizado > rg_pcuot.sal_interes then
         v_int_pagado     := rg_pcuot.sal_interes;
         v_int_amortizado := v_int_amortizado - v_int_pagado;
      else
         v_int_pagado     := v_int_amortizado;
         v_int_amortizado := 0;
      end if;
      rg_pctmp.mto_int_descontado := rg_pcuot.sal_interes - nvl(v_int_pagado,0) - nvl(v_int_nuevo,0);
      if rg_pctmp.mto_int_descontado < 0 then
         rg_pctmp.mto_int_descontado := 0;
      end if;
   end if;
   --- Totalizar y guardar variables auxiliares
   pap_cob.g_sal_anterior := nvl(pap_cob.g_sal_anterior,0) - (nvl(rg_pcuot.sal_capital,0) - nvl(v_cap_adelantado,0));

   pap_cob.g_val_retorno  := v_cap_adelantado;
   rg_pctmp.mto_capital   := v_cap_adelantado;
   rg_pctmp.mto_interes   := 0; -- No amortiza interes
   pap_cob.g_tot_cap_ade  := nvl(pap_cob.g_tot_cap_ade,0) + v_cap_adelantado;
   pap_cob.g_tot_int_pag  := v_int_amortizado;
END;
/* Simular devengados de cuotas */
PROCEDURE PR_PRO_DEV_CUOTAS
 (P_FECHA IN DATE,
  P_NRO_CUENTA IN VARCHAR2
 )
 IS
   r_deven           pr_devengados%rowtype;
   v_proceso         varchar2(01);
   V_ESTADO          PR_CTA_PRESTAMOS.ESTADO%TYPE;
   V_MONEDA          BA_MONEDAS.COD_MONEDA%TYPE;
   V_MONE_LOCAL      BA_MONEDAS.COD_MONEDA%TYPE;
   V_MONE_FUERTE     BA_MONEDAS.COD_MONEDA%TYPE;
   V_COTIZACION      GE_COTIZACIONES.VAL_CONVERSION%TYPE;
   V_INTERES         PR_CUOTAS.MTO_INTERES%TYPE;
   V_CAPITAL         PR_CUOTAS.MTO_CAPITAL%TYPE;
   V_TASA            NUMBER;
   V_FEC_INI         DATE;
   V_FEC_FIN         DATE;
   V_FEC_ULT_DEV     DATE;
   V_NRO_CUENTA      PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE;
   v_categoria       ge_clientes.cat_automatica%type;
   ulthabm           date;
   ultdiam           date;
   fcproxi           date;
   prihabm           date;
   pridiam           date;
   v_cotiz_fuerte    ge_cotizaciones.val_venta%type;
   ---
   v_dev_suspenso    pr_cuotas.dev_suspenso%type;
   v_dev_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_tot_suspenso    pr_cuotas.dev_suspenso%type;
   v_tot_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_mto_ajuste      pr_devengados.mto_ajuste%type;
   v_fec_ini_dev     pr_devengados.fec_inicio%type;
   v_fec_fin_dev     pr_devengados.fec_inicio%type;
   v_devengo         varchar2(1);
   --- Definicion del cursor de prestamos vigentes a procesar
   cursor c_prestamos IS
   SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, nro_solicitud,
     	  val_int_devengar, val_tasa, fec_inicio, fec_vencimiento, a.tipo, a.estado,
		  sal_interes, cod_moneda, NVL(fec_ult_devengado, NULL) fec_ult_dev,
          c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
          dev_no_cobrado, tip_interes
     FROM ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a
    WHERE c.cod_persona = b.cod_persona
      AND b.nro_cuenta  = a.nro_cuenta
      and a.nro_cuenta  = p_nro_cuenta
      and a.cod_modalidad not in (670,671) --- No debe devengarse VENTA DE BIENES ADJUDICADOS
      and b.relacion    = 'P'
      AND a.estado not in ('N','I')  --- No incluir Canceladas ni Irrecuperables
      --- Que no tome cuentas vencidas aunque no halla devengado todo
      and a.fec_vencimiento > decode(p_fecha,v_fec_fin,p_fecha,(v_fec_fin - 1))
      --- No debe devengar las cuentas canceladas por adelantado
      and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
      AND a.fec_inicio <= p_fecha;
   --- Definicion del cursor de cuotas a procesar por prestamo
   cursor c_cuotas is
   SELECT a.*, a.rowid registro
     FROM pr_cuotas a
    WHERE a.nro_cuenta = v_nro_cuenta
      and a.nro_cuota > 0
      AND a.estado <> 'N'
      and nvl(a.sal_interes,0) + nvl(a.sal_int_documentado,0) > 0
      --- Cuando devenga de mas tambien debe incluir
      AND nvl(dev_acumulado,0) <> (nvl(mto_interes,0) + nvl(mto_int_documentado,0) - nvl(mto_int_descontado,0))
      and a.fec_vencimiento > v_fec_ult_dev
    ORDER BY a.nro_cuota;

PROCEDURE PR_INS_PR_DEVENGADOS
 IS
v_rowid varchar2(100);
BEGIN
   select rowid into v_rowid
     from  pr_devengados_tmp
    where nro_cuenta = r_deven.nro_cuenta
      and nro_cuota  = r_deven.nro_cuota
      and tipo       = r_deven.tipo
      and cod_moneda = r_deven.cod_moneda
      and estado     = r_deven.estado
      and categoria  = nvl(r_deven.categoria,1)
      and capital    = r_deven.capital
      and val_tasa   = r_deven.val_tasa;
   --- Actualizar el registro existente.
   update pr_devengados_tmp
      set can_dia_anterior  = nvl(can_dia_interes,0),
          mto_dev_anterior  = nvl(mto_dev_actual,0),
          can_dia_interes   = nvl(can_dia_interes,0) + r_deven.can_dia_interes,
          mto_dev_actual    = nvl(r_deven.mto_dev_actual,0),
          mto_ajuste        = nvl(r_deven.mto_ajuste,0),
          mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
          fecha             = r_deven.fecha,
          fec_ult_devengado = r_deven.fec_ult_devengado
    where nro_cuenta = r_deven.nro_cuenta
      and nro_cuota  = r_deven.nro_cuota
      and tipo       = r_deven.tipo
      and cod_moneda = r_deven.cod_moneda
      and estado     = r_deven.estado
      and categoria  = nvl(r_deven.categoria,1)
      and capital    = r_deven.capital
      and val_tasa   = r_deven.val_tasa;
exception
   when no_data_found then
      insert into pr_devengados_tmp(
         nro_cuenta, nro_cuota, tipo, fecha,
         fec_inicio, fec_ult_devengado, cod_moneda,
         estado, categoria, capital, val_tasa,
         can_dia_interes, mto_dev_anterior, can_dia_anterior,
         mto_dev_actual, mto_ajuste, mto_dev_acumulado)
      values
        (r_deven.nro_cuenta, r_deven.nro_cuota, r_deven.tipo, r_deven.fecha,
         r_deven.fec_inicio, r_deven.fec_ult_devengado, r_deven.cod_moneda,
         r_deven.estado, nvl(r_deven.categoria,1), r_deven.capital, r_deven.val_tasa,
         r_deven.can_dia_interes, nvl(r_deven.mto_dev_anterior,0), r_deven.can_dia_anterior,
         r_deven.mto_dev_actual, r_deven.mto_ajuste,
         nvl(r_deven.mto_dev_anterior,0)+nvl(r_deven.mto_dev_acumulado,0));
   WHEN OTHERS THEN
      if sqlcode = -54 then
         raise_application_error(-20000,'Reg. de Devengado Cta. '||r_deven.nro_cuenta||' bloqueado por otro usuario');
      end if;
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM||'Actu. PR_DEVENGADOS cta '||r_deven.nro_cuenta );
      end if;
END;

BEGIN
   v_mone_local   := PAG_GEN.FU_OBT_MON_LOCAL;
   v_mone_fuerte  := PAG_GEN.FU_OBT_MON_FUERTE;
   v_cotiz_fuerte := PAG_GEN.FU_OBT_COTIZACION(v_mone_fuerte,p_fecha);
   --v_proceso      := 'F';
   v_proceso      := 'I'; -- DYDMR-2829 -- 06/2016 : para no realizar el devengado de la fecha actual 
   
   --- La primera vez se utiliza para la apertura del cursor, para saber
   --- hasta que fecha debe devengar por si existan devengados adelantados
   IF v_PROCESO = 'I' THEN --- LLAMADO DESDE UN INICIO DE DIA --o desde el simulador
      --- para devengar sabados,domingos,feriados
      v_fec_fin := p_fecha - 1;
   ELSIF v_PROCESO = 'F' THEN --- LLAMADO DESDE UN CIERRE DE DIA
      v_fec_fin := p_fecha;
   END IF;
   FOR reg in c_prestamos LOOP
      --- totales por cada prestamo situacion cartera
      v_nro_cuenta    := reg.nro_cuenta;
      v_estado        := reg.estado;
      v_moneda        := reg.cod_moneda;
      v_fec_ult_dev   := reg.fec_ult_dev;
      v_devengo       := 'N';
      IF v_PROCESO = 'I' THEN --- LLAMADO DESDE UN INICIO DE DIA --o desde el simulador
         --- para devengar sabados,domingos,feriados
         v_fec_fin := p_fecha - 1;
      ELSIF v_PROCESO = 'F' THEN --- LLAMADO DESDE UN CIERRE DE DIA
         v_fec_fin := p_fecha;
      END IF;
      v_redondeo  := 0;
      IF v_moneda != v_mone_local THEN
         if v_moneda = v_mone_fuerte then
            v_cotizacion := v_cotiz_fuerte;
         else
            v_cotizacion := PAG_GEN.FU_OBT_COTIZACION(v_moneda,p_fecha);
         end if;
      END IF;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo, reg.cod_modalidad, reg.cod_moneda, reg.cod_oficina);
      v_categoria := nvl(reg.categoria,1);
      IF reg.fec_ult_dev  IS NULL THEN
         v_fec_ini := reg.fec_inicio;
         v_fec_ult_dev := reg.fec_inicio;
      ELSIF reg.fec_ult_dev >= reg.fec_inicio THEN
         v_fec_ini := reg.fec_ult_dev + 1;
      END IF;
      IF v_fec_fin >= reg.fec_vencimiento THEN --si ya esta vencido o vence hoy el prestamo,se devenga hasta el vto
         v_fec_fin := reg.fec_vencimiento - 1;
      END IF;
      v_tasa := reg.val_tasa;
      --- Inicializar variables de calculo
      v_tot_suspenso   := 0;
      v_tot_no_cobrado := 0;
      FOR cuo in c_cuotas LOOP
         v_interes        := 0;
         v_dev_no_cobrado := 0;
         v_dev_suspenso   := 0;
         v_mto_ajuste     := 0;
         r_deven          := null;
         v_fec_fin_dev    := v_fec_fin;
         if reg.tip_interes = 'V' then
            --- Para prestamos vencidos recorrer cuotas cuya fecha de
            --- inicio de devengado ha transcurrido
            v_fec_ini_dev := nvl(pap_dev.FU_OBT_FEC_INI_CUOTA(reg.nro_cuenta, cuo.nro_cuota),reg.fec_inicio);
            if v_fec_ini_dev > v_fec_fin then
               exit;
            end if;
         else
            v_fec_ini_dev := reg.fec_inicio;
         end if;
         --- Recuperar capital segun el tipo de prestamo
         if reg.tip_interes = 'A' then
            v_capital := nvl(cuo.mto_capital,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_cap_adelantado,0);
         else
            v_capital := PAP_INT.FU_OBT_CAPITAL_ACUMU(v_fec_ini_dev, reg.nro_cuenta);
         end if;
         if cuo.fec_vencimiento < v_fec_fin_dev + 1 then
            v_fec_fin_dev := cuo.fec_vencimiento - 1; --- Hasta el vencimiento de la cuota
         end if;
         --- Calcular Interes devengado desde la fecha de inicio de devengado de la cuota
         v_interes := PAP_INT.FU_CAL_INTERES(v_fec_ini_dev, v_fec_fin_dev, v_capital,
                                             reg.nro_solicitud, v_tasa );
         v_interes := round(v_interes, v_redondeo);
         --- Calcular el devengado por diferencia del acumulado a la fecha de fin
         v_interes := nvl(v_interes,0) - nvl(cuo.dev_acumulado,0);
         --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
         if cuo.fec_vencimiento = v_fec_fin_dev + 1 then
            if nvl(v_interes,0) + nvl(cuo.dev_acumulado,0) <>
               nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)- nvl(cuo.mto_int_descontado,0) then
               v_mto_ajuste := v_interes - (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)- nvl(cuo.mto_int_descontado,0) - nvl(cuo.dev_acumulado,0));
               v_interes    := (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)- nvl(cuo.mto_int_descontado,0) - nvl(cuo.dev_acumulado,0));
            end if;
         end if;
         --- Verificar que no quede en negativo el val_int_devengar
         if (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_int_descontado,0))
            < (nvl(cuo.dev_acumulado,0) + nvl(v_interes,0)) then
            v_mto_ajuste := v_interes;
            v_interes :=  (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_int_descontado,0))
                          - nvl(cuo.dev_acumulado,0);
            v_mto_ajuste := v_mto_ajuste - v_interes;
         end if;
         --- Verificar si debe actualizar el suspenso o no cobrado
         IF v_estado IN ('A','C') AND v_categoria IN (1,2) THEN /* solo los est 'A' y 'C' y categ 1 y 2*/
            v_dev_no_cobrado := v_interes;
            v_tot_no_cobrado := v_tot_no_cobrado + v_dev_no_cobrado;
            r_deven.tipo     := 'N';
         else
            v_dev_suspenso   := v_interes;
            v_tot_suspenso   := v_tot_suspenso + v_dev_suspenso;
            r_deven.tipo     := 'S';
         end if;
         --- Insertar devengados
         r_deven.nro_cuenta        := v_nro_cuenta;
         r_deven.nro_cuota         := cuo.nro_cuota;
         r_deven.fecha             := p_fecha;
         r_deven.fec_inicio        := v_fec_ini_dev;
         r_deven.fec_ult_devengado := v_fec_fin_dev;
         r_deven.cod_moneda        := reg.cod_moneda;
         r_deven.estado            := reg.estado;
         r_deven.categoria         := reg.categoria;
         r_deven.capital           := v_capital;
         r_deven.val_tasa          := reg.val_tasa;
         r_deven.can_dia_interes   := v_fec_fin_dev - v_fec_ini + 1;
         r_deven.mto_dev_actual    := v_interes;
         r_deven.mto_ajuste        := v_mto_ajuste;
         r_deven.mto_dev_acumulado := v_interes;
         --- Para casos en que no exista el registro y sea la primera vez
         r_deven.mto_dev_anterior  := cuo.dev_acumulado;
         pr_ins_pr_devengados;
         v_devengo := 'S';
      END LOOP;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM);
      end if;
END;

-- Recuperar devengado no cobrado temporal
FUNCTION FU_OBT_DEV_ANTICIPADO(P_NRO_CUENTA IN VARCHAR2, P_NRO_CUOTA IN NUMBER)
RETURN NUMBER IS
   v_devengado pr_devengados.mto_dev_actual%type;
BEGIN
   select nvl(sum(nvl(d.mto_dev_actual,0)),0)
     into v_devengado
     from pr_devengados_tmp d
    where nro_cuenta = p_nro_cuenta
      and nro_cuota >= p_nro_cuota;
   RETURN v_devengado;
END;

END PAP_COB;
/