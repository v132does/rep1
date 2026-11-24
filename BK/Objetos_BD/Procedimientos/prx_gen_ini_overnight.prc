create or replace procedure it.PRX_GEN_INI_OVERNIGHT
is

procedure lp_rev_dep_overnight is
   --Fecha de Proceso - asume del módulo de Comex
   r_gcale            ge_calendarios%rowtype :=pag_cal.FU_OBT_REG_CAL(8);--Obtenemos la Fecha Actual de Comex
   v_fec_proceso      CONSTANT DATE := r_gcale.fec_anterior;-- Fecha del dia anterior del módulo de Comex
   v_fecha            CONSTANT DATE := r_gcale.fec_actual;-- Fecha del dia actual del módulo de Comex
   v_cod_transaccion  ge_movimientos.cod_transaccion%type := fug_obt_pardinamico('COD_TRA_DEP_OVERNIGHT');
   v_cod_tra_padre    ge_movimientos.cod_transaccion%type := fug_obt_pardinamico('COD_REV_TRA_DEP_OVERNIGHT');
   ---
   cursor c_depositos is
   select distinct c.nro_cuenta, c.cod_moneda, c.cod_oficina,
          c.cod_modulo, c.cod_modalidad, c.monto monto
   from   cc_movimientos_his c
   where  c.cod_tra_padre = v_cod_transaccion
   and    c.fecha = v_fec_proceso;
  
   r_gmovi            ge_movimientos%rowtype;
   v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_cod_rubro        cb_rubros.cod_rubro%type;
   v_cod_rub_bco      cb_rubros.cod_rubro%type;
   v_nvo_estado       varchar2(1);
   v_sal_disponible   number;
   v_procesa          varchar2(1);
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   
   if v_cod_transaccion is null then
      raise_application_error(-20000, 'ERROR. No se encontro transacción para Sobregiro.'
                        ||'Verifique parámetro dinámico COD_TRA_DEP_OVERNIGHT');
   end if;
   if v_cod_tra_padre is null then
      raise_application_error(-20000, 'ERROR. No se encontro transacción para Sobregiro.'
                        ||'Verifique parámetro dinámico COD_REV_TRA_DEP_OVERNIGHT');
   end if;
   
   for i in c_depositos loop
      begin
          select a.cod_rubro
            into v_cod_rub_bco
            from cc_cta_bancarias a
           where a.nro_cuenta = i.nro_cuenta
             and a.cod_modulo = i.cod_modulo
             and a.cod_modalidad = i.cod_modalidad;
      exception
          when no_data_found then
            raise_application_error(-20000, 'ERROR. No se encontro Rubro de Depósito Overnight para Cta '
                                  ||i.nro_cuenta);
          when others then
            raise_application_error(-20000, 'ERROR:Obt.Rubro Dep.Overnight:'||sqlerrm);
      end;
      v_cod_rubro := fug_obt_paradicional(i.nro_cuenta,'COD_RUB_DEP_OVERNIGHT');
      if v_cod_rubro is null then
         v_cod_rubro := v_cod_rub_bco;
      end if;
      if v_nro_secuencia + 1 > 990 then
         v_nro_secuencia := 0;
         v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end if;
      if i.monto <> 0 then
         pag_cta.G_COD_ERROR := 0;
         pag_cta.PR_OBT_CUENTA(i.nro_cuenta);
         -- verifico si puedo o no cobrar
         pag_cta.PR_VER_OPERACION(i.nro_cuenta,
                                  v_cod_tra_padre, -- padre
                                  i.cod_modulo,
                                  i.cod_modalidad,
                                  'D', -- TIPO Debito
                                  i.cod_moneda,
                                  i.monto,
                                  i.cod_oficina,
                                  pag_cta.G_CTAS.COD_MODULO,
                                  pag_cta.G_CTAS.COD_MODALIDAD,
                                  v_nvo_estado,
                                  v_sal_disponible,
                                  v_procesa,
                                  503);
                                  
         if pag_cta.G_COD_ERROR <> 0 then
            raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error());
         End if; 
                                             
         if v_procesa = 'S' then
            v_nro_secuencia := v_nro_secuencia + 1;
            pag_cta.pr_act_operacion(i.nro_cuenta,
                                     v_hora,
                                     'D', -- Debito a la cuenta del cliente
                                     i.cod_moneda,
                                     i.monto,
                                     v_cod_tra_padre,
                                     503, -- trans. hijo
                                     i.nro_cuenta,
                                     null, -- cotizacion
                                     i.cod_oficina,
                                     i.cod_modulo,
                                     i.cod_modalidad,
                                     null, -- tasa
                                     null, -- valor de tasa
                                     'Dep.Overnight Cta.'||i.nro_cuenta, --concepto
                                     'N', -- emitir aviso
                                     v_nro_secuencia, -- nro de secuencia
                                     v_fecha);
                                     
            if pag_cta.G_COD_ERROR <> 0 then
               raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error());
            else
               -- Acredito en el rubro del Depósito Overnight
               r_gmovi.cod_usuario     := user;
               r_gmovi.hora            := v_hora;
               r_gmovi.fecha           := v_fecha;
               -- Aumento la secuencia
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               --
               r_gmovi.cod_modulo      := i.cod_modulo;
               r_gmovi.cod_modalidad   := i.cod_modalidad;
               r_gmovi.nro_cuenta      := i.nro_cuenta;
               r_gmovi.cod_moneda      := i.cod_moneda;
               r_gmovi.fec_valor       := v_fecha;
               r_gmovi.cod_tra_padre   := v_cod_tra_padre;
               r_gmovi.cod_mod_padre   := i.cod_modulo;
               r_gmovi.cod_mad_padre   := i.cod_modalidad;
               r_gmovi.cod_oficina     := i.cod_oficina;
               r_gmovi.cod_transaccion := null;
               r_gmovi.monto           := i.monto;
               r_gmovi.nro_documento   := i.nro_cuenta;
               r_gmovi.nro_documento2  := null;
               r_gmovi.cod_ofi_origen  := i.cod_oficina;
               r_gmovi.emi_aviso       := 'N';
               r_gmovi.concepto        := 'Dep.Overnight Cta.'||i.nro_cuenta;
               r_gmovi.estado          := 'N';
               r_gmovi.reversado       := 'N';
               r_gmovi.cod_rubro       := v_cod_rubro;
               r_gmovi.cod_tasa        := null;
               r_gmovi.val_tasa        := null;
               r_gmovi.tip_mov_rubro   := 'C';
               r_gmovi.cod_persona     := null;
               r_gmovi.referencia      := i.nro_cuenta;
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
            end if;
         end if;
      end if;
   end loop;
   
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20000, 'ERROR. en Reversión Depósito Overnight '||SQLERRM);
   
end;

procedure lp_rev_sob_dep_overnight is
   --Fecha de Proceso - asume del módulo de Comex
   r_gcale            ge_calendarios%rowtype :=pag_cal.FU_OBT_REG_CAL(8);--Obtenemos la Fecha Actual de Comex
   v_fec_proceso      CONSTANT DATE := r_gcale.fec_anterior;-- Fecha del dia anterior del módulo de Comex
   v_fecha            CONSTANT DATE := r_gcale.fec_actual;-- Fecha del dia actual del módulo de Comex
   v_cod_transaccion  ge_movimientos.cod_tra_padre%type := fug_obt_pardinamico('COD_TRA_SOB_DEP_OVERNIGHT'); 
   v_cod_tra_padre    ge_movimientos.cod_tra_padre%type := fug_obt_pardinamico('COD_REV_TRA_SOB_DEP_OVERNIGHT');
   ---
   cursor c_sobregiros is
   select distinct c.nro_cuenta, c.cod_moneda, c.cod_oficina,
          c.cod_modulo, c.cod_modalidad, c.monto monto
   from   cc_movimientos_his c
   where  c.cod_tra_padre = v_cod_transaccion
   and    c.fecha = v_fec_proceso;
  
   r_gmovi            ge_movimientos%rowtype;
   v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_cod_rubro        cb_rubros.cod_rubro%type;
   v_cod_rub_bco      cb_rubros.cod_rubro%type;
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   
   if v_cod_transaccion is null then
      raise_application_error(-20000, 'ERROR. No se encontro transacción para Sobregiro.'
                        ||'Verifique parámetro dinámico COD_TRA_SOB_DEP_OVERNIGHT');
   end if;
   if v_cod_tra_padre is null then
      raise_application_error(-20000, 'ERROR. No se encontro transacción para Sobregiro.'
                        ||'Verifique parámetro dinámico COD_REV_TRA_SOB_DEP_OVERNIGHT');
   end if;
   
   for i in c_sobregiros loop
      begin
          select a.cod_rubro
            into v_cod_rub_bco
            from cc_cta_bancarias a
           where a.nro_cuenta = i.nro_cuenta
             and a.cod_modulo = i.cod_modulo
             and a.cod_modalidad = i.cod_modalidad;
      exception
          when no_data_found then
            raise_application_error(-20000, 'ERROR. No se encontro Rubro de Sobregiros '
                                      ||'por Depósito Overnight para Cta '||i.nro_cuenta);
          when others then
            raise_application_error(-20000, 'ERROR:Obt.Rub.Sob.'
                                   ||'Dep.Overnight:'||sqlerrm);
      end;
      v_cod_rubro := fug_obt_paradicional(i.nro_cuenta,'COD_RUB_SOB_DEP_OVER');
      if v_cod_rubro is null then
         v_cod_rubro := v_cod_rub_bco;
      end if;
      if i.monto <> 0 then
         -- Acredito en la Cta.Bancaria
         r_gmovi.cod_usuario     := user;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fecha;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := i.cod_modulo;
         r_gmovi.cod_modalidad   := i.cod_modalidad;
         r_gmovi.nro_cuenta      := i.nro_cuenta;
         r_gmovi.cod_moneda      := i.cod_moneda;
         r_gmovi.fec_valor       := v_fecha;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := i.cod_modulo;
         r_gmovi.cod_mad_padre   := i.cod_modalidad;
         r_gmovi.cod_oficina     := i.cod_oficina;
         r_gmovi.cod_transaccion := null;
         r_gmovi.monto           := i.monto;
         r_gmovi.nro_documento   := i.nro_cuenta;
         r_gmovi.nro_documento2  := null;
         r_gmovi.cod_ofi_origen  := i.cod_oficina;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'Sob.Dep.Over.Cta.'||i.nro_cuenta;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := v_cod_rub_bco;
         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         r_gmovi.tip_mov_rubro   := 'C';
         r_gmovi.cod_persona     := null;
         r_gmovi.referencia      := i.nro_cuenta;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
         --
         -- Debito del rubro del Sobregiro por el Depósito Overnight
         --
         r_gmovi.cod_usuario     := user;
         r_gmovi.hora            := v_hora;
         r_gmovi.fecha           := v_fecha;
         -- Aumento la secuencia
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         --
         r_gmovi.cod_modulo      := i.cod_modulo;
         r_gmovi.cod_modalidad   := i.cod_modalidad;
         r_gmovi.nro_cuenta      := i.nro_cuenta;
         r_gmovi.cod_moneda      := i.cod_moneda;
         r_gmovi.fec_valor       := v_fecha;
         r_gmovi.cod_tra_padre   := v_cod_tra_padre;
         r_gmovi.cod_mod_padre   := i.cod_modulo;
         r_gmovi.cod_mad_padre   := i.cod_modalidad;
         r_gmovi.cod_oficina     := i.cod_oficina;
         r_gmovi.cod_transaccion := null;
         r_gmovi.monto           := i.monto;
         r_gmovi.nro_documento   := i.nro_cuenta;
         r_gmovi.nro_documento2  := null;
         r_gmovi.cod_ofi_origen  := i.cod_oficina;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'Sob.Dep.Over.Cta.'||i.nro_cuenta;
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         r_gmovi.cod_rubro       := v_cod_rubro;
         r_gmovi.cod_tasa        := null;
         r_gmovi.val_tasa        := null;
         r_gmovi.tip_mov_rubro   := 'D';
         r_gmovi.cod_persona     := null;
         r_gmovi.referencia      := i.nro_cuenta;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
   end loop;
   
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20000, 'ERROR. en Reversión Sobregiro Dep.Overnight '||SQLERRM);
   
end;

-- PROCESO PRINCIPAL
begin
   lp_rev_dep_overnight;
   lp_rev_sob_dep_overnight;
end;
/

