CREATE OR REPLACE PROCEDURE IT.PRH_CIE_LIQUIDACION
 (P_COD_EPR_DESDE IN RH_PAR_EMPRESAS.COD_EMPRESA%TYPE
 ,P_COD_EPR_HASTA IN RH_PAR_EMPRESAS.COD_EMPRESA%TYPE
 ,P_FEC_CIERRE IN DATE
 )
 IS

   r_emr   rh_par_empresas%rowtype;
   -- defino por defecto el modulo y modalidad a utilizar
   v_cod_modulo        number(3)    := 14;          -- RRHH
   v_cod_modalidad     number(3)    := 141;         -- RRHH
   v_cod_usuario       varchar2(10) := upper(user); -- usuario
   v_cod_transaccion   ge_movimientos.cod_transaccion%type;
   v_cod_tra_fondo     ge_movimientos.cod_transaccion%type;
   v_cod_tra_snpp      ge_movimientos.cod_transaccion%type;
   v_mto_transaccion   ge_movimientos.monto%type;
   -- Datos para generar el movimiento
   v_fec_actual        date         := pag_cal.fu_obt_fec_actual(v_cod_modulo); -- fecha de hoy
   v_hor_actual        varchar2(08) := to_char(sysdate,'HH24:MI:SS');           -- Hora actual
   v_cod_moneda        varchar2(3)  := pag_gen.fu_obt_mon_local;                -- moneda de la cuenta
   v_cod_persona       rh_liq_sueldos.cod_persona%type;
   v_nro_sobre         rh_liq_sueldos.nro_sobre%type;
   v_nro_secuencia     number(3) := 0;  -- secuencia del mov.
   r_gmovi             ge_movimientos%rowtype;
   v_cod_tip_movto     char(1);
   r_tip_ing           rh_tip_ingresos%rowtype;
   r_tip_des           rh_tip_descuentos%rowtype;
   v_concepto          ge_movimientos.concepto%type;
   ---
   v_cod_empresa rh_par_empresas.cod_empresa%type;
   --- Cursor de Empresas a cerrar
   cursor c_empresa is
   select *
   from   rh_par_empresas
   where  cod_empresa >= p_cod_epr_desde
   and    cod_empresa <= p_cod_epr_hasta
   order  by cod_empresa;
   --- Cursor de IPS a informa
   CURSOR c_empleados IS
   select s.cod_persona, s.nro_sobre,e.cod_oficina,e.nro_ips,e.nro_caja
   from   rh_empleados e, rh_sobres s
   where  s.cod_persona     = e.cod_persona
   and    s.fec_calculo     = P_FEC_CIERRE
   and    e.cod_per_empresa = v_cod_empresa;
 --cursor movimientos de empleados
   cursor c_mov is
   select *
   from   rh_liq_sueldos l
   where  l.cod_persona = v_cod_persona
   and    l.nro_sobre   = v_nro_sobre;
 --cursor de provisiones de empleados
   cursor c_prov is
   select *
   from   rh_provisiones
   where  fecha = P_FEC_CIERRE
   and    cod_persona = v_cod_persona;
   ---
   r_tip_prov            rh_tip_provisiones%rowtype;
   v_monto_aporte        rh_liq_sueldos.monto%type;
   v_monto_fondo         rh_liq_sueldos.monto%type;
   v_monto_snpp          rh_liq_sueldos.monto%type;
   v_tot_devengado       rh_liq_sueldos.monto%type;
   ---
BEGIN
   --- Recuperar datos de la Empresa
   FOR r_emr IN c_empresa LOOP
      v_cod_empresa := r_emr.cod_empresa;
      FOR r_emp IN c_empleados LOOP
         ---------------------------
         --- INSERTAR MOVIMIENTO ---
         ---------------------------
         v_cod_persona := r_emp.cod_persona;
         v_nro_sobre   := r_emp.nro_sobre;
         for r_liq in c_mov loop
            v_monto_aporte := 0;
            ---
            if nvl(r_liq.cod_tip_ingreso,0) = 0 then
               v_cod_tip_movto := 'D';
               --- Recuperar tipo de mvto del descuento
               prh_obt_tip_descuent(r_liq.cod_tip_descuento, r_tip_des);
               v_concepto := r_tip_des.descripcion;
            else
               v_cod_tip_movto := 'C';
               --- Recuperar tipo de mvto del ingreso
               prh_obt_tip_ingreso(r_liq.cod_tip_ingreso, r_tip_ing);
               v_concepto := r_tip_ing.descripcion;
            end if;
            ---
            v_cod_modulo            := r_liq.cod_modulo;
            v_cod_modalidad         := r_liq.cod_modalidad;
            v_cod_transaccion       := r_liq.cod_transaccion;
            v_mto_transaccion       := r_liq.monto;
            v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
            -- Aumento la secuencia
            if v_nro_secuencia  = 999 then
               v_nro_secuencia := 0;
            else
               v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
            end if;
            -- Genero el movimiento
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := nvl(r_emp.cod_oficina,11);
            r_gmovi.nro_cuenta      := null;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.cod_usuario     := v_cod_usuario;
            r_gmovi.hora            := v_hor_actual;
            r_gmovi.fecha           := v_fec_actual;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            --
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_tra_padre   := 1303;
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_transaccion;
            r_gmovi.monto           := v_mto_transaccion;
            r_gmovi.nro_documento   := v_cod_persona;
            r_gmovi.cod_tasa        := null;
            r_gmovi.val_tasa        := null;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := nvl(r_emp.cod_oficina,11);
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := v_concepto;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.nro_caja        := null;
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.tip_mov_rubro   := v_cod_tip_movto;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
            ---
            --------------------------------------
            --- INSERTAR APORTE DE LA PATRONAL ---
            --------------------------------------
            ---
            if r_liq.cod_tip_descuento = r_emr.cod_tip_des_ips or
               r_liq.cod_tip_descuento = r_emr.cod_tip_des_caja then
               ---
               SELECT SUM(L.MONTO)
               INTO   V_TOT_DEVENGADO
               FROM   RH_LIQ_SUELDOS L, RH_TIP_INGRESOS I
               WHERE  L.COD_TIP_INGRESO = I.COD_TIP_INGRESO
               AND    I.IND_IMPONIBLE ='S'
               AND    L.COD_PERSONA = V_COD_PERSONA
               AND    L.NRO_SOBRE = v_nro_sobre;
               ---
               if (r_emr.ind_apo_ips_caja = 'I' or
                  (r_emr.ind_apo_ips_caja = 'A' and r_emp.nro_ips is not null)) then
                  v_monto_aporte := round(nvl(v_tot_devengado,0) * nvl(r_emr.por_ips_pat,0) / 100, 0);
                  v_cod_transaccion := r_emr.cod_tip_des_pat_ips;
               elsif (r_emr.ind_apo_ips_caja = 'C' or
                     (r_emr.ind_apo_ips_caja = 'A' and r_emp.nro_caja is not null)) then
                  v_monto_aporte    := round(nvl(v_tot_devengado,0) * nvl(r_emr.por_caj_pat,0) / 100, 0);
                  v_monto_fondo     := round(nvl(v_tot_devengado,0) * nvl(r_emr.por_caj_pat_act, 0) / 100, 0);
                  v_monto_snpp      := round(nvl(v_tot_devengado,0) * nvl(r_emr.por_caj_ret_snpp, 0) / 100, 0);
               end if;
            end if;
            if v_monto_aporte <> 0 then
               v_cod_transaccion := r_emr.cod_tip_des_pat_caja;
               prh_obt_tip_descuent(v_cod_transaccion, r_tip_des);
               v_concepto := r_tip_des.descripcion;
               v_cod_transaccion := r_tip_des.cod_transaccion;
               -- Aumento la secuencia
               if v_nro_secuencia  = 999 then
                  v_nro_secuencia := 0;
               else
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               end if;
               -- Genero el movimiento
               r_gmovi.cod_modulo      := v_cod_modulo;
               r_gmovi.cod_modalidad   := v_cod_modalidad;
               r_gmovi.cod_oficina     := nvl(r_emp.cod_oficina,11);
               r_gmovi.nro_cuenta      := null;
               r_gmovi.cod_moneda      := v_cod_moneda;
               r_gmovi.cod_usuario     := v_cod_usuario;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := 1303;
               r_gmovi.cod_mod_padre   := v_cod_modulo;
               r_gmovi.cod_mad_padre   := v_cod_modalidad;
               r_gmovi.cod_transaccion := v_cod_transaccion;
               r_gmovi.monto           := v_monto_aporte;
               r_gmovi.nro_documento   := v_cod_persona;
               r_gmovi.cod_tasa        := null;
               r_gmovi.val_tasa        := null;
               r_gmovi.cotizacion      := null;
               r_gmovi.cod_ofi_origen  := nvl(r_emp.cod_oficina,11);
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := v_concepto;
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.nro_caja        := null;
               r_gmovi.cod_rubro       := NULL;
               r_gmovi.tip_mov_rubro   := v_cod_tip_movto;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
            end if;
            ---
            if v_monto_fondo <> 0 then
               v_cod_tra_fondo   := r_emr.cod_tip_des_pat_fondo;
               prh_obt_tip_descuent(v_cod_tra_fondo, r_tip_des);
               v_concepto := r_tip_des.descripcion;
               v_cod_tra_fondo := r_tip_des.cod_transaccion;
               -- Aumento la secuencia
               if v_nro_secuencia  = 999 then
                  v_nro_secuencia := 0;
               else
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               end if;
               -- Genero el movimiento
               r_gmovi.cod_modulo      := v_cod_modulo;
               r_gmovi.cod_modalidad   := v_cod_modalidad;
               r_gmovi.cod_oficina     := nvl(r_emp.cod_oficina,11);
               r_gmovi.nro_cuenta      := null;
               r_gmovi.cod_moneda      := v_cod_moneda;
               r_gmovi.cod_usuario     := v_cod_usuario;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := 1303;
               r_gmovi.cod_mod_padre   := v_cod_modulo;
               r_gmovi.cod_mad_padre   := v_cod_modalidad;
               r_gmovi.cod_transaccion := v_cod_tra_fondo;
               r_gmovi.monto           := v_monto_fondo;
               r_gmovi.nro_documento   := v_cod_persona;
               r_gmovi.cod_tasa        := null;
               r_gmovi.val_tasa        := null;
               r_gmovi.cotizacion      := null;
               r_gmovi.cod_ofi_origen  := nvl(r_emp.cod_oficina,11);
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := v_concepto;
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.nro_caja        := null;
               r_gmovi.cod_rubro       := NULL;
               r_gmovi.tip_mov_rubro   := v_cod_tip_movto;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
            end if;
            ---
            if v_monto_snpp <> 0 then
               v_cod_tra_snpp    := r_emr.cod_tip_des_pat_snpp;
               prh_obt_tip_descuent(v_cod_tra_snpp, r_tip_des);
               v_concepto := r_tip_des.descripcion;
               v_cod_tra_snpp := r_tip_des.cod_transaccion;
               -- Aumento la secuencia
               if v_nro_secuencia  = 999 then
                  v_nro_secuencia := 0;
               else
                  v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               end if;
               -- Genero el movimiento
               r_gmovi.cod_modulo      := v_cod_modulo;
               r_gmovi.cod_modalidad   := v_cod_modalidad;
               r_gmovi.cod_oficina     := nvl(r_emp.cod_oficina,11);
               r_gmovi.nro_cuenta      := null;
               r_gmovi.cod_moneda      := v_cod_moneda;
               r_gmovi.cod_usuario     := v_cod_usuario;
               r_gmovi.hora            := v_hor_actual;
               r_gmovi.fecha           := v_fec_actual;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.fec_valor       := v_fec_actual;
               r_gmovi.cod_tra_padre   := 1303;
               r_gmovi.cod_mod_padre   := v_cod_modulo;
               r_gmovi.cod_mad_padre   := v_cod_modalidad;
               r_gmovi.cod_transaccion := v_cod_tra_snpp;
               r_gmovi.monto           := v_monto_aporte;
               r_gmovi.nro_documento   := v_cod_persona;
               r_gmovi.cod_tasa        := null;
               r_gmovi.val_tasa        := null;
               r_gmovi.cotizacion      := null;
               r_gmovi.cod_ofi_origen  := nvl(r_emp.cod_oficina,11);
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := v_concepto;
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.nro_caja        := null;
               r_gmovi.cod_rubro       := NULL;
               r_gmovi.tip_mov_rubro   := v_cod_tip_movto;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno
            end if;
            ---
         end loop;
         ---
         ----------------------------
         --- INSERTAR PROVISIONES ---
         ----------------------------
         ---
         for r_prov in c_prov loop
            --- Recuperar tipo de mvto del ingreso
            prh_obt_tip_provision(r_prov.cod_tip_provision, r_tip_prov);
            v_concepto := substr(r_tip_prov.descripcion,1,35);
            v_cod_modulo            := r_tip_prov.cod_modulo;
            v_cod_modalidad         := r_tip_prov.cod_modalidad;
            v_cod_transaccion       := r_tip_prov.cod_transaccion;
            v_cod_tip_movto         := fug_obt_tip_mov_contable(v_cod_modulo,v_cod_modalidad,v_cod_transaccion);
            ---
            v_mto_transaccion       := r_prov.mto_haber;
            v_hor_actual            := pag_gen.fu_obt_sig_segundo(v_hor_actual);
            -- Aumento la secuencia
            if v_nro_secuencia  = 999 then
               v_nro_secuencia := 0;
            else
               v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
            end if;
            -- Genero el movimiento
            r_gmovi.cod_modulo      := v_cod_modulo;
            r_gmovi.cod_modalidad   := v_cod_modalidad;
            r_gmovi.cod_oficina     := nvl(r_emp.cod_oficina,11);
            r_gmovi.nro_cuenta      := null;
            r_gmovi.cod_moneda      := r_prov.cod_moneda;
            r_gmovi.cod_usuario     := v_cod_usuario;
            r_gmovi.hora            := v_hor_actual;
            r_gmovi.fecha           := v_fec_actual;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            --
            r_gmovi.fec_valor       := v_fec_actual;
            r_gmovi.cod_tra_padre   := 1303;
            r_gmovi.cod_mod_padre   := v_cod_modulo;
            r_gmovi.cod_mad_padre   := v_cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_transaccion;
            r_gmovi.monto           := v_mto_transaccion;
            r_gmovi.nro_documento   := v_cod_persona;
            r_gmovi.cod_tasa        := null;
            r_gmovi.val_tasa        := null;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := nvl(r_emp.cod_oficina,11);
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := v_concepto;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.nro_caja        := null;
            r_gmovi.cod_rubro       := NULL;
            r_gmovi.tip_mov_rubro   := v_cod_tip_movto;
            PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, 'N'); -- no es nocturno

         end loop;
      END LOOP;
      ---
      update rh_par_empresas
      set fec_ult_cierre = p_fec_cierre
      where cod_empresa = r_emr.cod_empresa;
      if sql%notfound then
         raise_application_error(-20000,
         'La empresa no fue actualizada');
      end if;
  END LOOP;
END;
/

