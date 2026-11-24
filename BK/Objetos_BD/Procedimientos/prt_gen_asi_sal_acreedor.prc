create or replace procedure it.prt_gen_asi_sal_acreedor(p_tip_proceso in varchar2 default 'T') is
--Tipos de Procesos--
--C=Contabilizacion--
--R=Reversion de Contabilizacion--
--T=Contabilizacion y Reversion--
   --- Genera asientos por la Contingencia de Tarjetas de Credito y por el Saldo Acreedor (deuda)--
   r_gmovi          ge_movimientos%rowtype;
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_fec_anterior   ge_calendarios.fec_anterior%type ;
   v_hora           ge_movimientos.hora%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   v_cod_tra_padre        number(3) := 223;
   v_cod_transaccion      number(3) := 225; --deuda
   v_concepto ge_movimientos.concepto%type := 'CONTAB.SAL.ACREEDOR';
   v_cod_tra_contingencia      number(3) := 224; --contingencia, línea de crédito
   v_concepto_contingencia ge_movimientos.concepto%type := 'CONTAB.CONTINGENCIA';
   v_nro_cta        ge_movimientos.nro_cuenta%type;
   v_lugar          varchar2(500);

   --Definicion de Cursores--
   cursor c_lin_contingencia is
   SELECT t.cod_oficina,
          t.cod_modulo,
          t.cod_modalidad,
          t.cod_moneda,
          SUM((CASE WHEN t.estado != 'B' THEN
                         (CASE WHEN NVL(t.sal_procesadora, 0) > (NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0)) THEN 0
                               WHEN NVL(t.sal_procesadora, 0) <= 0 THEN (NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0))
                               ELSE ((NVL(t.lin_credito, 0) + NVL(t.lin_cuotas, 0)) - NVL(t.sal_procesadora, 0))
                         END)
                    ELSE 0
               END))mto_contingencia
     FROM ge_cta_clientes,
          ta_cta_tarjetas t
    WHERE  t.nro_cuenta = ge_cta_clientes.nro_cuenta
      AND ge_cta_clientes.relacion = 'P'
      AND t.estado <> 'C'
      AND t.cod_modalidad not in (55)
   GROUP BY t.cod_oficina, t.cod_modulo, t.cod_modalidad, t.cod_moneda;

 cursor c_can_ant_contingencia is
   select a.*
     from ta_movimientos_his a
    where a.fecha = v_fec_anterior
      and a.cod_tra_padre = v_cod_tra_padre
      and a.cod_transaccion = v_cod_tra_contingencia
      and a.reversado = 'N'
      and a.concepto = v_concepto_contingencia;


begin
   v_fec_actual    := pag_cal.FU_OBT_FEC_ACTUAL(5);
   v_fec_anterior  := pag_cal.FU_OBT_FEC_ANT_HAB(v_fec_actual,1) ;
   v_hora          := fug_ini_hora(sysdate,'HH24:MI:SS');
     --wa:para pk
   v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   v_nro_secuencia := 0;

   if p_tip_proceso in ('T','C') then
       --si es C genera la contingencia, desde el cierre de día siempre
         for pre in c_lin_contingencia loop
             v_lugar := 'c_lin_contingencia ' || pre.cod_modalidad ;
     --Inserta Transacciones por Lineas Actuales--
           if v_nro_secuencia + 1 > 997 then
              v_nro_secuencia := 0;
              v_hora          := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
              v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           end if;
           --- Cabecera del movimiento ---
           r_gmovi.fecha          := v_fec_actual;
           r_gmovi.hora           := v_hora;
           r_gmovi.cod_usuario    := USER;
           r_gmovi.fec_valor      := v_fec_actual;
           --r_gmovi.nro_cuenta     := pre.nro_cuenta;
           r_gmovi.cod_moneda     := pre.cod_moneda;
           r_gmovi.cod_oficina    := pre.cod_oficina;
           r_gmovi.cod_ofi_origen := pre.cod_oficina;
           r_gmovi.estado         := 'N';
           r_gmovi.reversado      := 'N';
           r_gmovi.emi_aviso      := 'N';
           r_gmovi.cod_mod_padre  := pre.cod_modulo;
           r_gmovi.cod_mad_padre  := pre.cod_modalidad;
           r_gmovi.cod_tra_padre  := v_cod_tra_padre;
           r_gmovi.cod_modulo     := pre.cod_modulo;
           r_gmovi.cod_modalidad  := pre.cod_modalidad;
           r_gmovi.protegido      := 'N';
           r_gmovi.nro_documento  := pre.cod_modalidad;
           ---Generar por Contingencia--
           if nvl(pre.mto_contingencia,0) <> 0 then
              r_gmovi.cod_transaccion := v_cod_tra_contingencia;
              r_gmovi.concepto       := v_concepto_contingencia;
              v_nro_secuencia        := v_nro_secuencia + 1;
              r_gmovi.nro_secuencia  := v_nro_secuencia;
              r_gmovi.monto          := pre.mto_contingencia;
              pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
           end if;
         end loop;

         --Cancelacion de Contab. Contingencia Anterior--
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
         v_nro_secuencia := 0;

         for can in c_can_ant_contingencia loop
              v_lugar := 'c_can_ant_contingencia ' || can.cod_modalidad ;
              v_nro_cta := can.nro_cuenta;
             if v_nro_secuencia + 1 > 997 then
                v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
                v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
                v_nro_secuencia := 0;
             end if;
             --- Cabecera del movimiento ---
             r_gmovi.fecha          := v_fec_actual;
             r_gmovi.hora           := v_hora;
             r_gmovi.cod_usuario    := USER;
             r_gmovi.fec_valor      := v_fec_actual;
             r_gmovi.cod_moneda     := can.cod_moneda;
             r_gmovi.cod_oficina    := can.cod_oficina;
             r_gmovi.cod_ofi_origen := can.cod_oficina;
             r_gmovi.estado         := 'N';
             r_gmovi.reversado      := 'N';
             r_gmovi.emi_aviso      := 'N';
             r_gmovi.cod_mod_padre  := can.cod_mod_padre;
             r_gmovi.cod_mad_padre  := can.cod_mad_padre;
             r_gmovi.cod_tra_padre  := v_cod_tra_padre;
             r_gmovi.cod_modulo     := can.cod_modulo;
             r_gmovi.cod_modalidad  := can.cod_modalidad;
             r_gmovi.protegido      := 'N';
             r_gmovi.nro_documento  := can.nro_documento;
             r_gmovi.nro_documento2 := can.nro_documento2;
             r_gmovi.concepto       := 'CANCEL.'||can.concepto;
             r_gmovi.cod_transaccion := can.cod_transaccion;
             v_nro_secuencia        := v_nro_secuencia + 1;
             r_gmovi.nro_secuencia  := v_nro_secuencia;
             r_gmovi.monto          := nvl(can.monto,0)*-1;
             pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi,'N');
         end loop;
   end if;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Error en prt_gen_asi_sal_acreedor : '||'-'|| v_lugar||'-'||sqlerrm);
end prt_gen_asi_sal_acreedor;
/

