CREATE OR REPLACE PROCEDURE IT.PRP_CAM_TAS_VARIABLES( p_nro_cuenta    VARCHAR2,
                                                   p_fec_desde     date,
                                                   p_val_tasa_nva  NUMBER,
                                                   p_cod_tas_fondo number ,
                                                   p_secuencia     number)
 IS
   /*Recupera la cuota a modificar*/
   PROCEDURE LP_OBT_CUOTA (p_nro_cuenta  in  VARCHAR2,
                 p_nro_cuota   in  NUMBER,
                 r_cuota       out pr_cuotas%rowtype);
   --- Variables auxiliares
   v_vez number(01) := 0;
   v_redondeo         number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6);
   v_sal_cap_cuota pr_cuotas.sal_capital%type;
   v_fec_inicio pr_cta_prestamos.fec_inicio%type;
   v_fec_actual date:=pag_cal.FU_OBT_FEC_ACTUAL(6);
   v_interes pr_cuotas.mto_interes%type;
   v_tot_dif_int pr_cuotas.mto_interes%type;
   v_diferencia pr_cuotas.mto_interes%type;
   v_int_cuota_partida pr_cuotas.mto_interes%type;
   v_mto_cuota pr_cuotas.mto_capital%type;
   v_sum_mto_cap pr_cuotas.mto_capital%type;
   v_cod_modalidad pr_cta_prestamos.cod_modalidad%type;
   v_cod_moneda pr_cta_prestamos.cod_moneda%type;
   v_cod_oficina pr_cta_prestamos.cod_oficina%type;
   v_tip_amortizacion pr_solicitudes.tip_amortizacion%type;
   v_plazo_cuota_partida PR_SOLICITUDES.DIA_PLAZO%TYPE;
   V_PLAZO_INTERES number;
   v_val_tasa_vieja pr_cta_prestamos.val_tasa%type;
   r_gmovi ge_movimientos%rowtype;
   r_cuota pr_cuotas%rowtype;
   --- Cursor de cuotas de prestamos restantes a remodificar
   cursor c_cuotas is
   select nro_cuota, o.mto_capital, o.mto_interes, o.sal_capital, o.sal_interes,
          p.sal_capital sal_cap_pre, p.sal_interes sal_int_pre, o.fec_vencimiento,
          p.cod_modalidad, p.cod_oficina, p.cod_moneda
     from pr_cuotas o, pr_cta_prestamos p
    where o.nro_cuenta = p_nro_cuenta
      and o.fec_vencimiento >= p_fec_desde
      and p.nro_cuenta = O.nro_cuenta
      and p.estado = 'C'
      and o.estado <> 'N'
      and o.sal_interes > 0
    order by o.nro_cuota;
/*Recupera la cuota a modificar*/
PROCEDURE LP_OBT_CUOTA (
          p_nro_cuenta  in  VARCHAR2,
          p_nro_cuota   in  NUMBER,
          r_cuota       out pr_cuotas%rowtype)
  is
BEGIN
  select *
  into   r_cuota
  from   pr_cuotas p
  where  p.nro_cuenta = p_nro_cuenta
  and    p.nro_cuota  = p_nro_cuota;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Cuota '||to_char(p_nro_cuota)||' no registrada para la cuenta '||p_nro_cuenta);
End;
BEGIN
   v_tot_dif_int := 0;
   /* Obtener tipo de amortización */
   begin
     select s.tip_amortizacion, p.val_tasa
     into   v_tip_amortizacion, v_val_tasa_vieja
     from   pr_cta_prestamos p, pr_solicitudes s
     where  p.nro_cuenta = p_nro_cuenta
     and    s.nro_solicitud (+) = p.nro_solicitud;
   exception
     when no_data_found then
       v_tip_amortizacion := null;
   end;

   for cuo in c_cuotas loop
      /* Obtener cuota actual para pasar al histórico */
      LP_OBT_CUOTA(p_nro_cuenta,cuo.nro_cuota,r_cuota);
      insert into pr_cuotas_his(        cod_tas_fondo,
      nro_cuenta,         nro_cuota,    mto_capital,
      fec_vencimiento,    mto_interes,  val_tasa,
      estado,             sal_capital,  sal_interes,
      prioridad,          fec_ult_pago, val_recargo,
      mto_int_documentado,nro_documento,sal_int_documentado,
      dev_no_cobrado,     dev_suspenso, dev_acumulado,
      mto_int_descontado, mto_cap_adelantado)
      values(                     p_cod_tas_fondo,
      r_cuota.nro_cuenta,         r_cuota.nro_cuota,    r_cuota.mto_capital,
      r_cuota.fec_vencimiento,    r_cuota.mto_interes,  v_val_tasa_vieja,
      r_cuota.estado,             r_cuota.sal_capital,  r_cuota.sal_interes,
      r_cuota.prioridad,          r_cuota.fec_ult_pago, r_cuota.val_recargo,
      r_cuota.mto_int_documentado,r_cuota.nro_documento,r_cuota.sal_int_documentado,
      r_cuota.dev_no_cobrado,     r_cuota.dev_suspenso, r_cuota.dev_acumulado,
      r_cuota.mto_int_descontado, r_cuota.mto_cap_adelantado);
      ---
      if v_vez = 0 then
         v_vez := 1;
         v_cod_modalidad := cuo.cod_modalidad;
         v_cod_moneda    := cuo.cod_moneda;
         v_cod_oficina   := cuo.cod_oficina;
         if cuo.cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
            v_redondeo := 0;
         end if;
      end if;
      v_fec_inicio := pap_dev.FU_OBT_FEC_INI_CUOTA(p_nro_cuenta, cuo.nro_cuota);
      -- Verifica es price o no.
      If v_tip_amortizacion = 'P' then
        if v_vez = 1 then
          v_vez := 2;
          /*************************************
          *** CALCULO EL MONTO DE LAS CUOTAS ***
          *************************************/
          --- Cuando es Price se toma el saldo capital de la cuota
          v_sal_cap_cuota := nvl(cuo.mto_capital,0);
          ---
          v_plazo_interes := (cuo.mto_interes  * 36500) / (v_sal_cap_cuota * v_val_tasa_vieja);
          v_interes       := round(v_plazo_interes * v_sal_cap_cuota * p_val_tasa_nva/36500,v_redondeo);
          v_mto_cuota     := nvl(v_sal_cap_cuota,0) + nvl(v_interes,0);
          ---
          /*************************************************************************************
          *** Calculo de 1era. cuota cuando la cuota es afectada por 2 tasas (Cuota partida) ***
          *************************************************************************************/
          ---
          --- Pueden haber pagos parciales
          select sum(o.sal_capital)
          into   v_sal_cap_cuota
          from   pr_cuotas o
          where  o.nro_cuenta = p_nro_cuenta
          and    o.fec_vencimiento >= p_fec_desde;
          ---
          --- Calculo el Interés por la tasa vieja
          if p_fec_desde > v_fec_inicio then
             v_plazo_cuota_partida := trunc(p_fec_desde) - trunc(v_fec_inicio);
             v_int_cuota_partida   := round(v_plazo_cuota_partida * v_sal_cap_cuota * v_val_tasa_vieja/36500,v_redondeo);
          else
             v_plazo_cuota_partida := 0;
             v_int_cuota_partida   := 0;
          end if;
          --- Obtengo el interés para la primera cuota
          v_plazo_interes := trunc(cuo.fec_vencimiento) - trunc(p_fec_desde);
          v_interes       := round(v_plazo_interes * v_sal_cap_cuota * p_val_tasa_nva/36500,v_redondeo);
          v_interes       := nvl(v_interes,0) + nvl(v_int_cuota_partida,0);
        else
          --- Obtengo el saldo del capital para la siguiente cuota
          v_sal_cap_cuota := nvl(cuo.sal_capital,0);
          ---
          v_interes := nvl(v_mto_cuota,0) - nvl(v_sal_cap_cuota,0);
        end if;
        ---
        update pr_cuotas
           set sal_interes = nvl(v_interes,0),
               mto_interes = nvl(v_interes,0)
         where nro_cuenta  = p_nro_cuenta
           and nro_cuota   = cuo.nro_cuota;
        ---
        v_diferencia    := nvl(v_interes,0) - nvl(cuo.mto_interes,0);
        v_tot_dif_int   := v_tot_dif_int + v_diferencia;
      ELSE
        --- Calculo de Saldo de Interés
        if v_vez = 1 then
          --- Solo para la primera vez el saldo capital es igual al del prestamo
          v_sal_cap_cuota := nvl(cuo.sal_cap_pre,0);
          v_vez := 2;
          if p_fec_desde > v_fec_inicio then
             if v_fec_inicio >= v_fec_actual then
                --- Obtiene la suma del capital
                --- Si la fecha es futura no se considera los no vencidos
                select sum(sal_capital)
                into   v_sum_mto_cap
                from   pr_cuotas
                where  nro_cuenta = p_nro_cuenta
                and    nro_cuota  < cuo.nro_cuota
                and    fec_vencimiento >= v_fec_actual;
                ---
                v_sal_cap_cuota := v_sal_cap_cuota - nvl(v_sum_mto_cap,0);
             end if;
             --- Pueden haber pagos parciales
             v_sal_cap_cuota := v_sal_cap_cuota - (nvl(cuo.mto_capital,0) - nvl(cuo.sal_capital,0));
             ---
             v_int_cuota_partida := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, p_fec_desde-1, v_sal_cap_cuota, null, v_val_tasa_vieja),v_redondeo);
             v_interes := ROUND(pap_int.FU_CAL_INTERES(p_fec_desde, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, p_val_tasa_nva),v_redondeo);
             v_interes := nvl(v_interes,0) + nvl(v_int_cuota_partida,0);
          else
             v_interes := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, p_val_tasa_nva),v_redondeo);
          end if;
        else
          v_interes := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, p_val_tasa_nva),v_redondeo);
        end if;
        v_diferencia := nvl(v_interes,0) - nvl(cuo.mto_interes,0);
        ---
        update pr_cuotas
           set mto_interes = nvl(cuo.mto_interes,0) + v_diferencia,
               sal_interes = nvl(cuo.sal_interes,0) + v_diferencia
         where nro_cuenta  = p_nro_cuenta
           and nro_cuota   = cuo.nro_cuota;
        ---
        v_sal_cap_cuota := v_sal_cap_cuota - nvl(cuo.sal_capital,0);
        v_tot_dif_int   := v_tot_dif_int + v_diferencia;
      end if;
      ---
      update pr_cta_prestamos
         set sal_interes = nvl(cuo.sal_interes,0) + v_diferencia,
             val_tasa    = p_val_tasa_nva
       where nro_cuenta  = p_nro_cuenta;
      ---
   end loop;
   ---
   update pr_cta_prestamos
      set val_int_devengar = val_int_devengar + v_tot_dif_int
    where nro_cuenta       = p_nro_cuenta;
    ---
   --- genero los movimientos por el devengamiento y el interes ----
   r_gmovi.nro_secuencia      := p_secuencia;
   r_gmovi.cod_usuario        := user;
   r_gmovi.hora               := to_char(sysdate,'HH24:MI:SS');
   r_gmovi.fecha              := pag_cal.fu_obt_fec_actual(6);
   r_gmovi.cod_modulo         := 6;
   r_gmovi.cod_modalidad      := v_cod_modalidad;
   r_gmovi.cod_oficina        := v_cod_oficina;
   r_gmovi.nro_cuenta         := p_nro_cuenta;
   r_gmovi.cod_moneda         := v_cod_moneda;
   r_gmovi.est_cuenta         := 'C';
   r_gmovi.cod_tra_padre      := 300;
   r_gmovi.cod_transaccion    := 719;
   r_gmovi.concepto           := 'Interes ajustado' ;
   r_gmovi.monto              := nvl(v_tot_dif_int,0);
   r_gmovi.fec_valor          := r_gmovi.fecha;
   r_gmovi.emi_aviso          := 'S';
   r_gmovi.reversado          := 'N';
   r_gmovi.protegido          := 'N';
   r_gmovi.estado             := 'N';
   r_gmovi.cod_ofi_origen     := v_cod_oficina;
   r_gmovi.cod_mod_padre      := 6;
   r_gmovi.cod_mad_padre      := v_cod_modalidad;
   pag_gen.pr_ins_ge_movimiento(r_gmovi);
END;
/

