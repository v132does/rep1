CREATE OR REPLACE PROCEDURE IT.PRP_GEN_VAL_REV
 IS
v_redondeo_ml number(2);
/* Obtener datos de la clasificación del prestamo. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 );
/* Obtener datos de la valuación del crédito. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT PR_VALUACIONES_REV%ROWTYPE
 ,P_FECHA IN DATE
 );
/* Actualizar o generar registro de valuación. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_PVALU IN PR_VALUACIONES_REV%ROWTYPE
 ,RP_PCPRE IN PR_CTA_PRESTAMOS%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 );
   --- Este proceso debe ejecutarse luego del:
   --- calculo de cambio de estado del prestamo
   --- clasificacion de riesgos y previsiones
   --- calculo de garantias computables
   ---
   v_cam_situacion varchar2(1);
   v_fecha         ge_movimientos.fecha%type;
   v_fec_reversion ge_movimientos.fecha%type;
   v_hora          ge_movimientos.hora%type;
   v_hor_reversion ge_movimientos.hora%type := '00:00:00';
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_cod_mon_local ba_monedas.cod_moneda%type;
   v_cotizacion    ge_cotizaciones.val_conversion%type;
   v_diferencia    pr_valuaciones.tot_val_capital%type;
   r_pvalu         pr_valuaciones_rev%rowtype;
   r_pvalu_a       pr_valuaciones_rev%rowtype;
   r_pvalc         pr_valuaciones_rev%rowtype;
   r_gcope         ge_cla_operaciones%rowtype;
   r_gmovi         ge_movimientos%rowtype;
   r_cta_p         pr_cta_prestamos%rowtype;
   v_suspenso      pr_valuaciones.tot_val_capital%type;
   --- Cancelados en el dia se procesa para reconcer la valuacion en suspenso por
   --- diferencia de cambio
   cursor c_pre_valuar is
   select p.*, c.cod_moneda, c.cod_oficina, c.cod_modulo, c.cod_modalidad
     from pr_valuaciones_his p, pr_cta_prestamos c
    where p.fecha = v_fec_reversion
      and p.nro_cuenta = c.nro_cuenta
    --  and p.nro_cuenta = '01633302393'
   union all
   select p.*, c.cod_moneda, c.cod_oficina, c.cod_modulo, c.cod_modalidad
     from pr_valuaciones p, pr_cta_prestamos c
    where p.fecha = v_fec_reversion
    --  and p.nro_cuenta = '01633302393'
      and p.nro_cuenta = c.nro_cuenta;
/*   select *
     from pr_cta_prestamos p
    where cod_moneda <> v_cod_mon_local
      and ((estado not in ('N','I'))
            or (estado = 'N' and fec_cancelacion = v_fecha));
*/
/* Obtener datos de la clasificación y prevision del prestamo. */
PROCEDURE LP_OBT_CLASIFICACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_GCOPE IN OUT GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   begin
   select *
     into rp_gcope
     from ge_cla_operaciones
    where nro_cuenta = p_nro_cuenta;
   exception
      when others then
        rp_gcope  := null;
        select cod_persona
          into rp_gcope.cod_persona
          from ge_cta_clientes
         where nro_cuenta = p_nro_cuenta
           and relacion = 'P';
   end;
   ----
   select cat_riesgo
     into rp_gcope.cat_automatica
     from ge_clientes
    where cod_persona = rp_gcope.cod_persona;
   ---- Recuperar el valor de la prevision del pr_previsiones
   select nvl(sum(p1.monto),0)
     into rp_gcope.tot_prevision
     from pr_previsiones p1
    where p1.nro_cuenta = p_nro_cuenta
      and p1.fecha = (select max(p2.fecha)
                        from pr_previsiones p2
                       where p2.nro_cuenta = p1.nro_cuenta);
exception
   when no_data_found then
      raise_application_error(-20000,
      'No existe clasificacion para cuenta '||p_nro_cuenta);
END;
/* Obtener datos de la valuación del crédito. */
PROCEDURE LP_OBT_VALUACION_ANT
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT PR_VALUACIONES_REV%ROWTYPE
 ,p_FECHA IN DATE
 )
 IS
BEGIN
-- Obtengo del respaldo como estaba antes...
   select *
     into rp_pvalu
     from pr_valuaciones_res
    where nro_cuenta = p_nro_cuenta
      and fecha = (select max(fecha)
                     from pr_valuaciones_res
                    where nro_cuenta = p_nro_cuenta
                      and fecha < p_fecha);
exception
   when no_data_found then
      rp_pvalu := null;
END;
/* Obtener datos de la valuación del crédito. */
PROCEDURE LP_OBT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,RP_PVALU IN OUT PR_VALUACIONES_REV%ROWTYPE
 ,p_FECHA IN DATE
 )
 IS
BEGIN
   select *
     into rp_pvalu
     from pr_valuaciones_rev
    where nro_cuenta = p_nro_cuenta
      and fecha = (select max(fecha)
                     from pr_valuaciones_rev
                    where nro_cuenta = p_nro_cuenta
                      and fecha < p_fecha);
exception
   when no_data_found then
      rp_pvalu := null;
END;
/* Actualizar o generar registro de valuación. */
PROCEDURE LP_ACT_VALUACION
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 ,P_FECHA IN PR_VALUACIONES.FECHA%TYPE
 ,P_COTIZACION IN NUMBER
 ,RP_PVALU IN PR_VALUACIONES_REV%ROWTYPE
 ,RP_PCPRE IN PR_CTA_PRESTAMOS%ROWTYPE
 ,RP_GCOPE IN GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
   update pr_valuaciones_rev
      set fecha                = p_fecha,
          estado               = rp_pcpre.estado,
          tipo                 = rp_pcpre.tipo,
          tip_interes          = rp_pcpre.tip_interes,
          tip_renovacion       = rp_pcpre.tip_renovacion,
          tip_documento        = rp_pcpre.tip_documento,
          sal_capital          = nvl(rp_pcpre.sal_capital,0),
          sal_interes          = nvl(rp_pcpre.sal_interes,0),
          sal_int_adelantado   = nvl(rp_pcpre.sal_int_adelantado,0),
          dev_no_cobrado       = nvl(rp_pcpre.dev_no_cobrado,0),
          dev_suspenso         = nvl(rp_pcpre.dev_suspenso,0),
          val_int_devengar     = nvl(rp_pcpre.val_int_devengar,0),
          tot_gar_computables  = nvl(rp_gcope.tot_gar_computables,0),
          tot_prevision        = nvl(rp_gcope.tot_prevision,0),
          cat_automatica       = rp_gcope.cat_automatica,
          cot_anterior         = rp_pvalu.cot_anterior,
          cotizacion           = p_cotizacion,
          tot_val_capital      = nvl(rp_pvalu.tot_val_capital,0),
          tot_val_interes      = nvl(rp_pvalu.tot_val_interes,0),
          tot_val_int_ade      = nvl(rp_pvalu.tot_val_int_ade,0),
          tot_val_devengado    = nvl(rp_pvalu.tot_val_devengado,0),
          tot_val_int_devengar = nvl(rp_pvalu.tot_val_int_devengar,0),
          tot_val_suspenso     = nvl(rp_pvalu.tot_val_suspenso,0),
          tot_val_garantia     = nvl(rp_pvalu.tot_val_garantia,0),
          tot_val_prevision    = nvl(rp_pvalu.tot_val_prevision,0)
    where nro_cuenta = p_nro_cuenta
      and fecha = p_fecha;
   if sql%notfound then
      insert into pr_valuaciones_rev
         (nro_cuenta, fecha, estado, tipo, tip_interes, tip_renovacion, tip_documento,
          sal_capital, sal_interes, sal_int_adelantado, dev_no_cobrado,
          val_int_devengar, dev_suspenso,
          tot_gar_computables, tot_prevision, cat_automatica, cotizacion,
          tot_val_capital, tot_val_interes, tot_val_int_ade,
          tot_val_devengado, tot_val_int_devengar, tot_val_suspenso,
          tot_val_garantia, tot_val_prevision)
      values
          (p_nro_cuenta, p_fecha, rp_pcpre.estado, rp_pcpre.tipo, rp_pcpre.tip_interes,
           rp_pcpre.tip_renovacion, rp_pcpre.tip_documento, nvl(rp_pcpre.sal_capital,0),
           nvl(rp_pcpre.sal_interes,0), nvl(rp_pcpre.sal_int_adelantado,0), nvl(rp_pcpre.dev_no_cobrado,0),
           nvl(rp_pcpre.val_int_devengar,0), nvl(rp_pcpre.dev_suspenso,0),
           nvl(rp_gcope.tot_gar_computables,0), nvl(rp_gcope.tot_prevision,0), rp_gcope.cat_automatica, p_cotizacion,
           nvl(rp_pvalu.tot_val_capital,0), nvl(rp_pvalu.tot_val_interes,0), nvl(rp_pvalu.tot_val_int_ade,0),
           nvl(rp_pvalu.tot_val_devengado,0), nvl(rp_pvalu.tot_val_int_devengar,0), nvl(rp_pvalu.tot_val_suspenso,0),
           nvl(rp_pvalu.tot_val_garantia,0), nvl(rp_pvalu.tot_val_prevision,0));
   end if;
END;
PROCEDURE LP_REV_OPERACION(
   P_NRO_CUENTA in PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
   P_CONCEPTO in GE_MOVIMIENTOS.CONCEPTO%TYPE,
   P_FECHA in PR_CTA_PRESTAMOS.FEC_INICIO%TYPE)
 IS
   r_gmovi ge_movimientos%rowtype;
   cursor c_reversar is
   select * from pr_movimientos_his
    where fecha = P_FECHA
      and nro_cuenta = p_nro_cuenta
      and concepto like P_concepto;
begin
   If substr(v_hor_reversion,-2,2)+1 = 60 then
     If substr(v_hor_reversion,-5,2)+1 = 60 then
        v_hor_reversion := trim(to_char(substr(v_hor_reversion,1,2)+1, '00'))||':00:00';
     else
        v_hor_reversion := substr(v_hor_reversion,1,3)||trim(to_char(substr(v_hor_reversion,-5,2)+1, '00'))||':00';
     end if;
   else
      v_hor_reversion := substr(v_hor_reversion,1,6)||trim(to_char(substr(v_hor_reversion,-2,2)+1, '00'));
   End if;
   --v_hor_reversion := to_char(pag_gen.fu_obt_sig_segundo(v_hor_reversion);
   for rev in c_reversar loop
      r_gmovi.fecha := v_fecha;
      r_gmovi.hora  := v_hor_reversion;
      r_gmovi.cod_usuario := user;
      r_gmovi.nro_secuencia := rev.nro_secuencia;
      r_gmovi.fec_valor := rev.fecha;
      r_gmovi.cod_moneda := rev.cod_moneda;
      r_gmovi.nro_cuenta := rev.nro_cuenta;
      r_gmovi.cod_oficina := rev.cod_oficina;
      r_gmovi.cod_modulo := rev.cod_modulo;
      r_gmovi.cod_modalidad := rev.cod_modalidad;
      r_gmovi.cod_mod_padre := rev.cod_mod_padre;
      r_gmovi.cod_mad_padre := rev.cod_mad_padre;
      r_gmovi.cod_tra_padre := rev.cod_tra_padre;
      r_gmovi.cod_ofi_origen := rev.cod_ofi_origen;
      r_gmovi.nro_documento2 := rev.nro_documento2;
      r_gmovi.est_cuenta := rev.est_cuenta;
      r_gmovi.estado := rev.estado;
      r_gmovi.reversado := 'N';
      r_gmovi.concepto := rev.concepto;
      if rev.cod_transaccion = 152 and
         rev.est_cuenta in ('A','C') and
         rev.nro_documento2 in (1,2) then
         r_gmovi.cod_transaccion := 153;
         r_gmovi.monto := rev.monto;
         r_gmovi.mto_equ_local := rev.mto_equ_local;
      elsif rev.cod_transaccion = 153 then
         r_gmovi.cod_transaccion := 152;
         -- Para que envie a Ganancia directo.
         r_gmovi.nro_documento2 := 1;
         r_gmovi.est_cuenta := 'C';
         -- hasta acá
         r_gmovi.monto := rev.monto;
         r_gmovi.mto_equ_local := rev.mto_equ_local;
      else
         r_gmovi.cod_transaccion := rev.cod_transaccion;
         r_gmovi.monto := rev.monto*-1;
         r_gmovi.mto_equ_local := rev.mto_equ_local * -1;
      end if;
      pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
      ---update pr_movimientos_his a reversado!!!
   end loop;
end;

BEGIN
---
   BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
   pag_cal.pr_obt_dat_calendar(6);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null,v_cod_mon_local);
   v_fecha         := pag_cal.G_FEC_ACTUAL;
   v_hora          := to_char(sysdate,'hh24:mi:ss');
   v_nro_secuencia := 0;
   v_fec_reversion := to_date('09032006','ddmmyyyy');
   --- Paso al historico las valuaciones actuales
/*   insert into pr_valuaciones_his
   select * from pr_valuaciones v
    where fecha = pag_cal.G_FEC_ANTERIOR;
*/   --- OBS: Se hace toda a las transacciones 152 y 153 para asentar solo el neto
   --- previsiones, a devengar y suspenso son contrarios a capital e interes por
   --- eso se pone la inversa las ganancias y perdidas
 loop
   for cta in c_pre_valuar loop
      r_cta_p.nro_cuenta         := cta.nro_cuenta;
      r_cta_p.estado             := cta.estado;
      r_cta_p.tipo               := cta.tipo;
      r_cta_p.tip_interes        := cta.tip_interes;
      r_cta_p.tip_renovacion     := cta.tip_renovacion;
      r_cta_p.tip_documento      := cta.tip_documento;
      r_cta_p.sal_capital        := cta.sal_capital;
      r_cta_p.sal_interes        := cta.sal_interes;
      r_cta_p.sal_int_adelantado := cta.sal_int_adelantado;
      r_cta_p.dev_no_cobrado     := cta.dev_no_cobrado;
      r_cta_p.val_int_devengar   := cta.val_int_devengar;
      r_cta_p.dev_suspenso       := cta.dev_suspenso;
      --- Recuperar datos de la clasificación
      --lp_obt_clasificacion(cta.nro_cuenta, r_gcope);
      r_gcope.cat_automatica     := cta.cat_automatica;
      r_gcope.tot_prevision      := cta.tot_prevision;
      --- Recuperar datos de la valuacion
      r_pvalc      := null;
      lp_obt_valuacion(cta.nro_cuenta, r_pvalu, v_fec_reversion);
      lp_obt_valuacion_ant(cta.nro_cuenta, r_pvalu_a, v_fec_reversion);
      --- Recuperar cotizacion de la moneda
      v_cotizacion := cta.cotizacion;
      ---pag_gen.fu_obt_cotizacion(cta.cod_moneda, v_fecha);
      --- Verificar si corresponde valuar
      if nvl(cta.sal_capital,-1)             <> nvl(r_pvalu.sal_capital,-1)
      or nvl(cta.sal_interes,-1)             <> nvl(r_pvalu.sal_interes,-1)
      or nvl(cta.sal_int_adelantado,-1)      <> nvl(r_pvalu.sal_int_adelantado,-1)
      or nvl(cta.dev_suspenso,-1)            <> nvl(r_pvalu.dev_suspenso,-1)
      or nvl(cta.val_int_devengar,-1)        <> nvl(r_pvalu.val_int_devengar,-1)
      or nvl(r_gcope.tot_prevision,-1)       <> nvl(r_pvalu.tot_prevision,-1)
      or cta.estado                          <> r_pvalu.estado
      or r_gcope.cat_automatica              <> r_pvalu.cat_automatica
         --- Si nunca proceso la cotización es igual a la contabilizada no es necesario hacer
         --- Ejemplo desembolsos
      or nvl(v_cotizacion,-1)                <> nvl(r_pvalu.cotizacion,v_cotizacion) then
         --- Existe cambio de valores
         --- Cargar datos por defecto de movimientos
         r_gmovi.fecha          := v_fecha;
         r_gmovi.hora           := v_hora;
         r_gmovi.cod_usuario    := user;
         r_gmovi.nro_cuenta     := cta.nro_cuenta;
         r_gmovi.fec_valor      := v_fec_reversion;
         r_gmovi.cod_oficina    := cta.cod_oficina;
         r_gmovi.cod_ofi_origen := cta.cod_oficina;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.cod_tra_padre  := 150;
         r_gmovi.cod_mod_padre  := cta.cod_modulo;
         r_gmovi.cod_mad_padre  := cta.cod_modalidad;
         r_gmovi.cod_modulo     := cta.cod_modulo;
         r_gmovi.cod_modalidad  := cta.cod_modalidad;
         --- Procesar CAPITAL (151,152,153)
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) and
            (round((nvl(cta.sal_capital,0)*v_cotizacion) - (nvl(r_pvalu.sal_capital,cta.sal_capital)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml) = 0) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' and v_cam_situacion = 'N' then
            v_diferencia := round((nvl(cta.sal_capital,0)*v_cotizacion) - (nvl(r_pvalu.sal_capital,cta.sal_capital)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            --- Las cuentas canceladas deben reconocer el saldo valuado como utilidad
            --- no se hace por diferencia porque existen datos migrados
            v_diferencia := nvl(r_pvalu.tot_val_capital,0);
         end if;
      --- VERIFICO SI DEBE REVERSAR!!!
      if nvl(r_pvalu.tot_val_capital,0) + nvl(v_diferencia,0) < 0 or
         (nvl(cta.estado,'A') in ('A','C') and
          nvl(r_gcope.cat_automatica,1) in (1,2)) or
          cta.estado = 'N' then
         --- No es necesario acumular el saldo cuando va todo a perdida o
         --- son cuentas que generan directamente ganancia o perdida
         v_suspenso := 0;
      else
         --- Acumular saldos solo para cuentas a valuar en suspenso
         v_suspenso := nvl(r_pvalu.tot_val_capital,0) + nvl(v_diferencia,0);
      end if;
      if v_suspenso <> cta.tot_val_capital or
         nvl(r_pvalu.tot_val_capital,0) != nvl(r_pvalu_a.tot_val_capital,0) OR
         ( v_fec_reversion = to_date('13/02/2006', 'dd/mm/yyyy') and
             (cta.tot_val_capital > 0 or
              cta.tot_val_devengado > 0 or
              cta.tot_val_garantia > 0 or
              cta.tot_val_interes > 0 or
              cta.tot_val_int_ade > 0 or
              cta.tot_val_int_devengar > 0 or
              cta.tot_val_prevision > 0 or
              cta.tot_val_suspenso > 0) ) then

         if v_diferencia <> 0 then
            if v_diferencia + nvl(r_pvalu.tot_val_capital,0) >= 0 then
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --- Desafectación o Ganancia
               if v_diferencia < 0 or v_cam_situacion = 'S' or cta.estado = 'N' then
                  --- Desafectación
                  r_gmovi.concepto        := 'Desafectación ganancia - Cap';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                     or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                     or v_cam_situacion = 'S' then
                     r_gmovi.monto           := abs(v_diferencia) * -1;
                     r_gmovi.mto_equ_local   := null; -- v_diferencia;
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := v_diferencia*-1;
                     r_gmovi.mto_equ_local   := null; --v_diferencia*-1;
                     r_gmovi.cod_transaccion := 153;
                  end if;
               else
                  --- Ganancia
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Cap';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_diferencia;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --v_diferencia;
                  r_gmovi.cod_transaccion := 152;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
               --- Perdida
               if  v_diferencia < nvl(r_pvalu.tot_val_capital,0)
               and nvl(r_pvalu.tot_val_capital,0) > 0 then
                  --- Desafectar ganancia y el resto va a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Desafectación ganancia - Cap';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := (nvl(r_pvalu.tot_val_capital,0)*-1);
                     r_gmovi.mto_equ_local   := null; -- (nvl(r_pvalu.tot_val_capital,0)*-1);
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_capital,0) * -1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_capital,0);
                     r_gmovi.cod_transaccion := 152;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  ----
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Cap';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(nvl(v_diferencia,0)) - abs(nvl(r_pvalu.tot_val_capital,0));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153;  --- Perdida
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Cap';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_diferencia);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            end if;
            if nvl(r_pvalu.tot_val_capital,0) + nvl(v_diferencia,0) < 0 or
               (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2)) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_capital := 0;
            else
               --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_capital := nvl(r_pvalu.tot_val_capital,0) + nvl(v_diferencia,0);
            end if;
            --- Generar movimiento por la cartera
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := 0;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.mto_equ_local   := v_diferencia;
            r_gmovi.concepto        := 'Act. por dif. de cambio - Cap';
            r_gmovi.est_cuenta      := cta.estado;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            If cta.estado <> 'N' and v_cam_situacion = 'N' Then
               r_gmovi.cod_transaccion := 151; -- Cartera
            Else
               r_gmovi.cod_transaccion := 152; -- Cartera
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.monto           := v_diferencia;
               r_gmovi.mto_equ_local   := null;
            End If;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         else
            r_pvalc.tot_val_capital := nvl(r_pvalu.tot_val_capital,0);
         end if;
         --- Reversar movimientos anteriores
         lp_rev_operacion(cta.nro_cuenta, '% - Cap', v_fec_reversion);
      else
         r_pvalc.tot_val_capital := nvl(v_suspenso,0);
      END IF;
         --- Procesar INTERES (154,155,156)
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) and
            (round((nvl(cta.sal_interes,0)*v_cotizacion) - (nvl(r_pvalu.sal_interes,cta.sal_interes)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml) = 0) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' and v_cam_situacion = 'N' then
            v_diferencia := round((nvl(cta.sal_interes,0)*v_cotizacion) - (nvl(r_pvalu.sal_interes,cta.sal_interes)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            --- Las cuentas canceladas deben reconocer el saldo valuado como utilidad
            --- no se hace por diferencia porque existen datos migrados
            v_diferencia := nvl(r_pvalu.tot_val_interes,0);
         end if;
      --- VERIFICO SI DEBE REVERSAR!!!
      if nvl(r_pvalu.tot_val_interes,0) + nvl(v_diferencia,0) < 0 or
         (nvl(cta.estado,'A') in ('A','C') and
          nvl(r_gcope.cat_automatica,1) in (1,2)) or
          cta.estado = 'N' then
         --- No es necesario acumular el saldo cuando va todo a perdida o
         --- son cuentas que generan directamente ganancia o perdida
         v_suspenso := 0;
      else
         --- Acumular saldos solo para cuentas a valuar en suspenso
         v_suspenso := nvl(r_pvalu.tot_val_interes,0) + nvl(v_diferencia,0);
      end if;
      if v_suspenso <> cta.tot_val_interes or
         nvl(r_pvalu.tot_val_interes,0) != nvl(r_pvalu_a.tot_val_interes,0)  or
           ( v_fec_reversion = to_date('13/02/2006', 'dd/mm/yyyy') and
             (cta.tot_val_capital > 0 or
              cta.tot_val_devengado > 0 or
              cta.tot_val_garantia > 0 or
              cta.tot_val_interes > 0 or
              cta.tot_val_int_ade > 0 or
              cta.tot_val_int_devengar > 0 or
              cta.tot_val_prevision > 0 or
              cta.tot_val_suspenso > 0) ) then

         if v_diferencia <> 0 then
            if v_diferencia + nvl(r_pvalu.tot_val_interes,0) >= 0 then
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --- Desafectación o Ganancia
               if v_diferencia < 0 or v_cam_situacion = 'S' or cta.estado = 'N' then
                  --- Desafectación
                  r_gmovi.concepto        := 'Desafectación ganancia - Int';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := abs(v_diferencia) * -1;
                     r_gmovi.mto_equ_local   := null; -- v_diferencia;
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := v_diferencia*-1;
                     r_gmovi.mto_equ_local   := null; --v_diferencia*-1;
                     r_gmovi.cod_transaccion := 153;
                  end if;
               else
                  --- Ganancia
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Int';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_diferencia;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 152; ---155;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
               --- Perdida
               if  v_diferencia < nvl(r_pvalu.tot_val_interes,0)
               and nvl(r_pvalu.tot_val_interes,0) > 0 then
                  --- Desafectar ganancia y el resto va a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Desafectación ganancia - Int';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := (nvl(r_pvalu.tot_val_interes,0)*-1);
                     r_gmovi.mto_equ_local   := null; --(nvl(r_pvalu.tot_val_interes,0)*-1);
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_interes,0)*-1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_interes,0);
                     r_gmovi.cod_transaccion := 152;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  ----
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Int';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(nvl(v_diferencia,0)) - abs(nvl(r_pvalu.tot_val_interes,0));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---156;  --- Perdida
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Int';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_diferencia);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---156;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            end if;
            if nvl(r_pvalu.tot_val_interes,0) + nvl(v_diferencia,0) < 0 or
               (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2)) or
                cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_interes := 0;
            else
               --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_interes := nvl(r_pvalu.tot_val_interes,0) + nvl(v_diferencia,0);
            end if;
            --- Generar movimiento por la cartera
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := 0;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.mto_equ_local   := v_diferencia;
            r_gmovi.concepto        := 'Act. por dif. de cambio - Int';
            r_gmovi.est_cuenta      := cta.estado;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            If cta.estado <> 'N' and v_cam_situacion = 'N' Then
               r_gmovi.cod_transaccion := 154; -- Cartera
            Else
               r_gmovi.cod_transaccion := 152;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.monto           := v_diferencia;
               r_gmovi.mto_equ_local   := null;
            End if;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         else
            r_pvalc.tot_val_interes := nvl(r_pvalu.tot_val_interes,0);
         end if;
         --- Reversar movimientos anteriores
         lp_rev_operacion(cta.nro_cuenta, '% - Int', v_fec_reversion);
      else
         r_pvalc.tot_val_interes := nvl(v_suspenso,0);
      END IF;
         --- Procesar INTERES ADELANTADO (157,158,159)
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) and
            (round((nvl(cta.sal_int_adelantado,0)*v_cotizacion) - (nvl(r_pvalu.sal_int_adelantado,cta.sal_int_adelantado)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml) = 0) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' and v_cam_situacion = 'N' then
            v_diferencia := round((nvl(cta.sal_int_adelantado,0)*v_cotizacion) - (nvl(r_pvalu.sal_int_adelantado,cta.sal_int_adelantado)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            --- Las cuentas canceladas deben reconocer el saldo valuado como utilidad
            --- no se hace por diferencia porque existen datos migrados
            v_diferencia := nvl(r_pvalu.tot_val_int_ade,0);
         end if;

      --- VERIFICO SI DEBE REVERSAR!!!
      if nvl(r_pvalu.tot_val_int_ade,0) + nvl(v_diferencia,0) < 0 or
         (nvl(cta.estado,'A') in ('A','C') and
          nvl(r_gcope.cat_automatica,1) in (1,2)) or
          cta.estado = 'N' then
         --- No es necesario acumular el saldo cuando va todo a perdida o
         --- son cuentas que generan directamente ganancia o perdida
         v_suspenso := 0;
      else
         --- Acumular saldos solo para cuentas a valuar en suspenso
         v_suspenso := nvl(r_pvalu.tot_val_int_ade,0) + nvl(v_diferencia,0);
      end if;
      if v_suspenso <> cta.tot_val_int_ade or
         nvl(r_pvalu.tot_val_int_ade,0) != nvl(r_pvalu_a.tot_val_int_ade,0) or
           ( v_fec_reversion = to_date('13/02/2006', 'dd/mm/yyyy') and
             (cta.tot_val_capital > 0 or
              cta.tot_val_devengado > 0 or
              cta.tot_val_garantia > 0 or
              cta.tot_val_interes > 0 or
              cta.tot_val_int_ade > 0 or
              cta.tot_val_int_devengar > 0 or
              cta.tot_val_prevision > 0 or
              cta.tot_val_suspenso > 0) ) then

         if v_diferencia <> 0 then
            if v_diferencia + nvl(r_pvalu.tot_val_int_ade,0) >= 0 then
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --- Desafectación o Ganancia
               if v_diferencia < 0 or v_cam_situacion = 'S' or cta.estado = 'N' then
                  --- Desafectación
                  r_gmovi.concepto        := 'Desafectación ganancia - IAd';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := abs(v_diferencia) * -1;
                     r_gmovi.mto_equ_local   := null; --v_diferencia;
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := v_diferencia*-1;
                     r_gmovi.mto_equ_local   := null; --v_diferencia*-1;
                     r_gmovi.cod_transaccion := 153;
                  end if;
               else
                  --- Ganancia
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - IAd';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_diferencia;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 152; ---158;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
               --- Perdida
               if  v_diferencia < nvl(r_pvalu.tot_val_int_ade,0)
               and nvl(r_pvalu.tot_val_int_ade,0) > 0 then
                  --- Desafectar ganancia y el resto va a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Desafectación ganancia - IAd';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := (nvl(r_pvalu.tot_val_int_ade,0)*-1);
                     r_gmovi.mto_equ_local   := null; --(nvl(r_pvalu.tot_val_int_ade,0)*-1);
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_int_ade,0) * -1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_int_ade,0);
                     r_gmovi.cod_transaccion := 152;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  ----
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - IAd';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(nvl(v_diferencia,0)) - abs(nvl(r_pvalu.tot_val_int_ade,0));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---159;  --- Perdida
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - IAd';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_diferencia);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; -- r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---159;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            end if;
            if nvl(r_pvalu.tot_val_int_ade,0) + nvl(v_diferencia,0) < 0 or
               (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2)) or
               cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_int_ade := 0;
            else
               --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_int_ade := nvl(r_pvalu.tot_val_int_ade,0) + nvl(v_diferencia,0);
            end if;
            --- Generar movimiento por la cartera
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := 0;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.mto_equ_local   := v_diferencia;
            r_gmovi.concepto        := 'Act. por dif. de cambio - IAd';
            r_gmovi.est_cuenta      := cta.estado;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            If cta.estado <> 'N' and v_cam_situacion = 'N' Then
               r_gmovi.cod_transaccion := 157; -- Cartera
            Else
               r_gmovi.cod_transaccion := 152;
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.monto           := v_diferencia;
               r_gmovi.mto_equ_local   := null;
            End if;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         else
            r_pvalc.tot_val_int_ade := nvl(r_pvalu.tot_val_int_ade,0);
         end if;
         --- Reversar movimientos anteriores
         lp_rev_operacion(cta.nro_cuenta, '% - IAd', v_fec_reversion);
      else
         r_pvalc.tot_val_int_ade := nvl(v_suspenso,0);
      END IF;
         --- Procesar INTERES A DEVENGAR (160,161,162)
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) and
            (round((nvl(cta.val_int_devengar,0)*v_cotizacion) - (nvl(r_pvalu.val_int_devengar,cta.val_int_devengar)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml) = 0) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' and v_cam_situacion = 'N' then
            v_diferencia := round((nvl(cta.val_int_devengar,0)*v_cotizacion) - (nvl(r_pvalu.val_int_devengar,cta.val_int_devengar)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            --- Las cuentas canceladas deben reconocer el saldo valuado como utilidad
            --- no se hace por diferencia porque existen datos migrados
            v_diferencia := nvl(r_pvalu.tot_val_int_devengar,0);
         end if;
         v_diferencia := v_diferencia * -1;

      --- VERIFICO SI DEBE REVERSAR!!!
      if nvl(r_pvalu.tot_val_int_devengar,0) + nvl(v_diferencia,0) < 0 or
         (nvl(cta.estado,'A') in ('A','C') and
          nvl(r_gcope.cat_automatica,1) in (1,2)) or
          cta.estado = 'N' then
         --- No es necesario acumular el saldo cuando va todo a perdida o
         --- son cuentas que generan directamente ganancia o perdida
         v_suspenso := 0;
      else
         --- Acumular saldos solo para cuentas a valuar en suspenso
         v_suspenso := nvl(r_pvalu.tot_val_int_devengar,0) + nvl(v_diferencia,0);
      end if;
      if v_suspenso <> cta.tot_val_int_devengar or
         nvl(r_pvalu.tot_val_int_devengar,0) != nvl(r_pvalu_a.tot_val_int_devengar,0) or
           ( v_fec_reversion = to_date('13/02/2006', 'dd/mm/yyyy') and
             (cta.tot_val_capital > 0 or
              cta.tot_val_devengado > 0 or
              cta.tot_val_garantia > 0 or
              cta.tot_val_interes > 0 or
              cta.tot_val_int_ade > 0 or
              cta.tot_val_int_devengar > 0 or
              cta.tot_val_prevision > 0 or
              cta.tot_val_suspenso > 0) ) then

         if v_diferencia <> 0 then
            if v_diferencia + nvl(r_pvalu.tot_val_int_devengar,0) >= 0 then
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --- Desafectación o Ganancia
               if v_diferencia < 0 then
                  --- Desafectación
                  r_gmovi.concepto        := 'Desafectación ganancia - ADe';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := v_diferencia;
                     r_gmovi.mto_equ_local   := null; --v_diferencia*-1;
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := v_diferencia;
                     r_gmovi.mto_equ_local   := null; --v_diferencia;
                     r_gmovi.cod_transaccion := 152;
                  end if;
               else
                  --- Ganancia
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - ADe';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_diferencia;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 152; ---161;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
               --- Perdida
               if  v_diferencia < nvl(r_pvalu.tot_val_int_devengar,0)
               and nvl(r_pvalu.tot_val_int_devengar,0) > 0 then
                  --- Desafectar ganancia y el resto va a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Desafectación ganancia - ADe';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_int_devengar,0)*-1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_int_devengar,0);
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_int_devengar,0)*-1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_int_devengar,0)*-1;
                     r_gmovi.cod_transaccion := 152;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  ----
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - ADe';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := (abs(nvl(v_diferencia,0)) - abs(nvl(r_pvalu.tot_val_int_devengar,0)));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---162;  --- Perdida
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a Perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - ADe';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_diferencia);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---162;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            end if;
            if nvl(r_pvalu.tot_val_int_devengar,0) + nvl(v_diferencia,0) < 0 or
               (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2)) or
               cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_int_devengar := 0;
            else
               --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_int_devengar := nvl(r_pvalu.tot_val_int_devengar,0) + nvl(v_diferencia,0);
            end if;
            --- Generar movimiento por la cartera
            v_diferencia := v_diferencia * -1;
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := 0;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.mto_equ_local   := v_diferencia;
            r_gmovi.concepto        := 'Act. por dif. de cambio - ADe';
            r_gmovi.est_cuenta      := cta.estado;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            If cta.estado <> 'N' and v_cam_situacion = 'N' Then
               r_gmovi.cod_transaccion := 160; -- Cartera
            Else
               r_gmovi.cod_transaccion := 152; -- Cartera
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.monto           := v_diferencia;
               r_gmovi.mto_equ_local   := null;
            End if;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         else
            r_pvalc.tot_val_int_devengar := nvl(r_pvalu.tot_val_int_devengar,0);
         end if;
         --- Reversar movimientos anteriores
         lp_rev_operacion(cta.nro_cuenta, '% - ADe', v_fec_reversion);
      else
         r_pvalc.tot_val_int_devengar := nvl(v_suspenso,0);
      END IF;
         --- Procesar PREVISIONES (166,167,168)
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) and
            (round((nvl(r_gcope.tot_prevision,0)*v_cotizacion) - (nvl(r_pvalu.tot_prevision,r_gcope.tot_prevision)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml) = 0) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' and v_cam_situacion = 'N' then
            v_diferencia := round((nvl(r_gcope.tot_prevision,0)*v_cotizacion) - (nvl(r_pvalu.tot_prevision,r_gcope.tot_prevision)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            --- Las cuentas canceladas deben reconocer el saldo valuado como utilidad
            --- no se hace por diferencia porque existen datos migrados
            v_diferencia := nvl(r_pvalu.tot_val_prevision,0);
         end if;
         v_diferencia := v_diferencia * -1;

      --- VERIFICO SI DEBE REVERSAR!!!
      if nvl(r_pvalu.tot_val_prevision,0) + nvl(v_diferencia,0) < 0 or
         (nvl(cta.estado,'A') in ('A','C') and
          nvl(r_gcope.cat_automatica,1) in (1,2)) or
          cta.estado = 'N' then
         --- No es necesario acumular el saldo cuando va todo a perdida o
         --- son cuentas que generan directamente ganancia o perdida
         v_suspenso := 0;
      else
         --- Acumular saldos solo para cuentas a valuar en suspenso
         v_suspenso := nvl(r_pvalu.tot_val_prevision,0) + nvl(v_diferencia,0);
      end if;
      if v_suspenso <> cta.tot_val_prevision or
         nvl(r_pvalu.tot_val_prevision,0) != nvl(r_pvalu_a.tot_val_prevision,0) or
           ( v_fec_reversion = to_date('13/02/2006', 'dd/mm/yyyy') and
             (cta.tot_val_capital > 0 or
              cta.tot_val_devengado > 0 or
              cta.tot_val_garantia > 0 or
              cta.tot_val_interes > 0 or
              cta.tot_val_int_ade > 0 or
              cta.tot_val_int_devengar > 0 or
              cta.tot_val_prevision > 0 or
              cta.tot_val_suspenso > 0) ) then

         if v_diferencia <> 0 then
            if v_diferencia + nvl(r_pvalu.tot_val_prevision,0) >= 0 then
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --- Desafectación o Ganancia
               if v_diferencia < 0 then
                  --- Desafectación
                  r_gmovi.concepto        := 'Desafectación ganancia - Pre';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := v_diferencia;
                     r_gmovi.mto_equ_local   := null; --v_diferencia*-1;
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := v_diferencia;
                     r_gmovi.mto_equ_local   := null; --v_diferencia;
                     r_gmovi.cod_transaccion := 152;
                  end if;
               else
                  --- Ganancia
                  r_gmovi.concepto        := 'Ganancia por dif. de cambio - Pre';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_diferencia;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 152; ---167;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
               --- Perdida
               if  v_diferencia < nvl(r_pvalu.tot_val_prevision,0)
               and nvl(r_pvalu.tot_val_prevision,0) > 0 then
                  --- Desafectar ganancia y el resto va a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.concepto        := 'Desafectación ganancia - Pre';
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A')       not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_prevision,0) * -1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_prevision,0);
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_prevision,0)*-1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_prevision,0)*-1;
                     r_gmovi.cod_transaccion := 152;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  ----
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := (abs(nvl(v_diferencia,0)) - abs(nvl(r_pvalu.tot_val_prevision,0)));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---168;  --- Perdida
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a Perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - Pre';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_diferencia);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---168;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            end if;
            if nvl(r_pvalu.tot_val_prevision,0) + nvl(v_diferencia,0) < 0 or
               (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2)) or
               cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_prevision := 0;
            else
               --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_prevision := nvl(r_pvalu.tot_val_prevision,0) + nvl(v_diferencia,0);
            end if;
            --- Generar movimiento por la cartera
            v_diferencia := v_diferencia * -1;
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := 0;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.mto_equ_local   := v_diferencia;
            r_gmovi.concepto        := 'Act. por dif. de cambio - Pre';
            r_gmovi.est_cuenta      := cta.estado;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            If cta.estado <> 'N' and v_cam_situacion = 'N' Then
               r_gmovi.cod_transaccion := 166; -- Cartera
            Else
               r_gmovi.cod_transaccion := 152; -- Cartera
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.monto           := v_diferencia;
               r_gmovi.mto_equ_local   := null;
            End if;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         else
            r_pvalc.tot_val_prevision := nvl(r_pvalu.tot_val_prevision,0);
         end if;
         --- Reversar movimientos anteriores
         lp_rev_operacion(cta.nro_cuenta, '% - Pre', v_fec_reversion);
      else
         r_pvalc.tot_val_prevision := nvl(v_suspenso,0);
      END IF;
         --- Procesar DEVENGADO EN SUSPENSO (169,170,171)
         v_cam_situacion := 'N';
         If (nvl(r_pvalu.estado,'A') not in ('A','C') or nvl(r_pvalu.cat_automatica,1) not in (1,2)) and
            (nvl(cta.estado,'A') in ('A','C') and nvl(r_gcope.cat_automatica,1) in (1,2)) and
            (round((nvl(cta.dev_suspenso,0)*v_cotizacion) - (nvl(r_pvalu.dev_suspenso,cta.dev_suspenso)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml) = 0) then
            v_cam_situacion := 'S';
         End if;
         ---
         if cta.estado <> 'N' and v_cam_situacion = 'N' then
            v_diferencia := round((nvl(cta.dev_suspenso,0)*v_cotizacion) - (nvl(r_pvalu.dev_suspenso,cta.dev_suspenso)*nvl(r_pvalu.cotizacion,v_cotizacion)),v_redondeo_ml);
         else
            --- Las cuentas canceladas deben reconocer el saldo valuado como utilidad
            --- no se hace por diferencia porque existen datos migrados
            v_diferencia := nvl(r_pvalu.tot_val_suspenso,0);
         end if;
         v_diferencia := v_diferencia * -1;

      --- VERIFICO SI DEBE REVERSAR!!!
      if nvl(r_pvalu.tot_val_suspenso,0) + nvl(v_diferencia,0) < 0 or
         (nvl(cta.estado,'A') in ('A','C') and
          nvl(r_gcope.cat_automatica,1) in (1,2)) or
          cta.estado = 'N' then
         --- No es necesario acumular el saldo cuando va todo a perdida o
         --- son cuentas que generan directamente ganancia o perdida
         v_suspenso := 0;
      else
         --- Acumular saldos solo para cuentas a valuar en suspenso
         v_suspenso := nvl(r_pvalu.tot_val_suspenso,0) + nvl(v_diferencia,0);
      end if;
      if v_suspenso <> cta.tot_val_suspenso or
         nvl(r_pvalu.tot_val_suspenso,0) != nvl(r_pvalu_a.tot_val_suspenso,0) or
           ( v_fec_reversion = to_date('13/02/2006', 'dd/mm/yyyy') and
             (cta.tot_val_capital > 0 or
              cta.tot_val_devengado > 0 or
              cta.tot_val_garantia > 0 or
              cta.tot_val_interes > 0 or
              cta.tot_val_int_ade > 0 or
              cta.tot_val_int_devengar > 0 or
              cta.tot_val_prevision > 0 or
              cta.tot_val_suspenso > 0) )  then

         if v_diferencia <> 0 then
            if v_diferencia + nvl(r_pvalu.tot_val_suspenso,0) >= 0 then
               v_nro_secuencia       := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia := v_nro_secuencia;
               --- Desafectación o Ganancia
               if v_diferencia < 0 then
                  --- Desafectación
                  r_gmovi.concepto        := 'Desafectación ganancia - DSu';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := v_diferencia;
                     r_gmovi.mto_equ_local   := null; --v_diferencia*-1;
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := v_diferencia;
                     r_gmovi.mto_equ_local   := null; --v_diferencia;
                     r_gmovi.cod_transaccion := 152;
                  end if;
               else
                  --- Perdida
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - DSu';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := v_diferencia;
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 152; ---171;
               end if;
               pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            else
               --- Perdida
               if  v_diferencia < nvl(r_pvalu.tot_val_suspenso,0)
               and nvl(r_pvalu.tot_val_suspenso,0) > 0 then
                  --- Desafectar ganancia y el resto va a perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Desafectación ganancia - DSu';
                  r_gmovi.est_cuenta      := nvl(r_pvalu.estado,cta.estado);
                  r_gmovi.nro_documento2  := nvl(r_pvalu.cat_automatica,r_gcope.cat_automatica);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  if nvl(r_pvalu.estado,'A') not in ('A','C')
                    or nvl(r_pvalu.cat_automatica,1) not in (1,2)
                    or v_cam_situacion = 'S' then
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_suspenso,0)*-1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_suspenso,0);
                     r_gmovi.cod_transaccion := 152;
                  else
                     --- Si valuo en ganancia anteriormente igual debe ir a perdida
                     r_gmovi.monto           := nvl(r_pvalu.tot_val_suspenso,0)*-1;
                     r_gmovi.mto_equ_local   := null; --nvl(r_pvalu.tot_val_suspenso,0)*-1;
                     r_gmovi.cod_transaccion := 152;
                  end if;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
                  ----
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - DSu';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := (abs(nvl(v_diferencia,0)) - abs(nvl(r_pvalu.tot_val_suspenso,0)));
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---169;  --- Perdida
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               else --- Todo a Perdida
                  v_nro_secuencia         := v_nro_secuencia + 1;
                  r_gmovi.nro_secuencia   := v_nro_secuencia;
                  r_gmovi.concepto        := 'Perdida por dif. de cambio - DSu';
                  r_gmovi.est_cuenta      := cta.estado;
                  r_gmovi.nro_documento2  := r_gcope.cat_automatica;
                  r_gmovi.monto           := abs(v_diferencia);
                  r_gmovi.cod_moneda      := v_cod_mon_local;
                  r_gmovi.mto_equ_local   := null; --r_gmovi.monto;
                  r_gmovi.cod_transaccion := 153; ---169;
                  pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
               end if;
            end if;
            if nvl(r_pvalu.tot_val_suspenso,0) + nvl(v_diferencia,0) <= 0 or
               (nvl(cta.estado,'A') in ('A','C') and
                nvl(r_gcope.cat_automatica,1) in (1,2)) or
               cta.estado = 'N' then
               --- No es necesario acumular el saldo cuando va todo a perdida o
               --- son cuentas que generan directamente ganancia o perdida
               r_pvalc.tot_val_suspenso := 0;
            else
               --- Acumular saldos solo para cuentas a valuar en suspenso
               r_pvalc.tot_val_suspenso := nvl(r_pvalu.tot_val_suspenso,0) + nvl(v_diferencia,0);
            end if;
            --- Generar movimiento por la cartera
            v_diferencia := v_diferencia * -1;
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := 0;
            r_gmovi.cod_moneda      := cta.cod_moneda;
            r_gmovi.mto_equ_local   := v_diferencia;
            r_gmovi.concepto        := 'Act. por dif. de cambio - DSu';
            r_gmovi.est_cuenta      := cta.estado;
            r_gmovi.nro_documento2  := r_gcope.cat_automatica;
            If cta.estado <> 'N' and v_cam_situacion = 'N' Then
               r_gmovi.cod_transaccion := 170; -- Cartera
            Else
               r_gmovi.cod_transaccion := 152; -- Cartera
               r_gmovi.cod_moneda      := v_cod_mon_local;
               r_gmovi.monto           := v_diferencia;
               r_gmovi.mto_equ_local   := null;
            End If;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
         else
            r_pvalc.tot_val_suspenso := nvl(r_pvalu.tot_val_suspenso,0);
         end if;
         --- Reversar movimientos anteriores
         lp_rev_operacion(cta.nro_cuenta, '% - DSu', v_fec_reversion);
      else
         r_pvalc.tot_val_suspenso := nvl(v_suspenso,0);
      END IF;
         --- Actualizar valuaciones
         r_pvalc.cot_anterior := r_pvalu.cotizacion;
         lp_act_valuacion(cta.nro_cuenta, v_fec_reversion, v_cotizacion, r_pvalc, r_cta_p, r_gcope);
         if v_nro_secuencia + 18 > 999 then
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := 0;
         end if;
      end if;
   end loop;
   exit when v_fec_reversion = v_fecha;
   v_fec_reversion := pag_cal.FU_OBT_FEC_SIG_HAB(v_fec_reversion,1,1);
   v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
 end loop;
END;
/

