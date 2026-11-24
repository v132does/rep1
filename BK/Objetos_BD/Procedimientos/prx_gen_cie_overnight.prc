create or replace procedure it.prx_gen_cie_overnight
is

procedure lp_dep_overnight is
   --Fecha de Proceso - asume del módulo de Comex
   r_gcale            ge_calendarios%rowtype :=pag_cal.FU_OBT_REG_CAL(8);--Obtenemos la Fecha Actual de Comex
   v_fec_proceso      CONSTANT DATE := r_gcale.fec_anterior;-- Fecha del dia anterior del módulo de Comex
   v_fecha            CONSTANT DATE := r_gcale.fec_actual;-- Fecha del dia actual del módulo de Comex
   ---
   cursor c_depositos is
   select c.nro_cuenta, c.cod_moneda, c.cod_oficina,
          a.cod_modulo, a.cod_modalidad, c.monto
   from   cc_cta_bancarias a, ge_bancos b, cx_dep_overnight c
   where  a.cod_banco = b.cod_banco
   and    a.nro_cuenta = c.nro_cuenta
   and    fecha = v_fec_proceso;

   v_cod_tra_padre    ge_movimientos.cod_tra_padre%type := fug_obt_pardinamico('COD_TRA_DEP_OVERNIGHT'); -- 6743;
   r_gmovi            ge_movimientos%rowtype;
   v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_cod_rubro        cb_rubros.cod_rubro%type;
   v_cod_rub_bco      cb_rubros.cod_rubro%type;
   v_nvo_estado       varchar2(1);
   v_sal_disponible   number;
   v_procesa          varchar2(1);
begin
   -- Se vuelve a inicializar la hora
   v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
   
   if v_cod_tra_padre is null then
      raise_application_error(-20000, 'ERROR. No se encontro transacción para Sobregiro.'
                        ||'Verifique parámetro dinámico COD_TRA_DEP_OVERNIGHT');
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
                                  'C', -- TIPO Credito
                                  i.cod_moneda,
                                  i.monto,
                                  i.cod_oficina,
                                  pag_cta.G_CTAS.COD_MODULO,
                                  pag_cta.G_CTAS.COD_MODALIDAD,
                                  v_nvo_estado,
                                  v_sal_disponible,
                                  v_procesa,
                                  602);

         if pag_cta.G_COD_ERROR <> 0 then
            raise_application_error(-20000,pag_cta.fu_obt_cod_error()||' - '|| pag_cta.fu_obt_msj_error());
         End if;

         if v_procesa = 'S' then
            v_nro_secuencia := v_nro_secuencia + 1;
            pag_cta.pr_act_operacion(i.nro_cuenta,
                                     v_hora,
                                     'C', -- credito a la cuenta del cliente
                                     i.cod_moneda,
                                     i.monto,
                                     v_cod_tra_padre,
                                     602, -- trans. hijo
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
               --
               -- Debito del rubro del Depósito Overnight
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
               r_gmovi.concepto        := 'Dep.Overnight Cta.'||i.nro_cuenta;
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
         end if;
      end if;
   end loop;
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20000, 'ERROR. en Deposito Overnight '||SQLERRM);

end;

procedure lp_sob_dep_overnight is
   --Fecha de Proceso - asume del módulo de Comex
   r_gcale            ge_calendarios%rowtype :=pag_cal.FU_OBT_REG_CAL(8);--Obtenemos la Fecha Actual de Comex
   v_fec_proceso      CONSTANT DATE := r_gcale.fec_anterior;-- Fecha del dia anterior del módulo de Comex
   v_fecha            CONSTANT DATE := r_gcale.fec_actual;-- Fecha del dia actual del módulo de Comex
   v_monto            cc_cta_bancarias.sal_total%type := 0;
   ---
   cursor c_sobregiros is
   select c.nro_cuenta, c.cod_moneda, c.cod_oficina,
          a.cod_modulo, a.cod_modalidad,  abs(nvl(sal_total,0) - nvl(sal_retenido,0)) monto
   from   cc_cta_bancarias a, ge_bancos b, cx_dep_overnight c
   where  a.cod_banco = b.cod_banco
   and    a.nro_cuenta = c.nro_cuenta
   and    nvl(sal_total,0) - nvl(sal_retenido,0) > 0
   and    fecha = v_fec_proceso;

   v_cod_tra_padre    ge_movimientos.cod_tra_padre%type := fug_obt_pardinamico('COD_TRA_SOB_DEP_OVERNIGHT'); -- 6744;
   r_gmovi            ge_movimientos%rowtype;
   v_hora             ge_movimientos.hora%type := fug_ini_hora(sysdate,'hh24:mi:ss');
   v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;
   v_cod_rubro        cb_rubros.cod_rubro%type;
   v_cod_rub_bco      cb_rubros.cod_rubro%type;
begin
   if v_cod_tra_padre is null then
      raise_application_error(-20000, 'ERROR. No se encontro transacción para Sobregiro.'
                        ||'Verifique parámetro dinámico COD_TRA_SOB_DEP_OVERNIGHT');
   end if;

   for i in c_sobregiros loop

      --Resto el importe por sobregiro normal Bco. del Pais.
      v_monto := 0;
      Begin

        select nvl(max(monto),0)
           into v_monto
          from ge_movimientos
         where cod_modulo = 4
           and cod_modalidad in (42,45,48,442)
           and cod_tra_padre = 902 --Sobregiro Vigente--
           and monto > 0
           and nro_cuenta = i.nro_cuenta;

        v_monto := nvl(i.monto,0) - nvl(v_monto,0);
      exception
        when others then
           v_monto := i.monto;
      end;

      --Obtengo el rubro contable asignado a la cuenta operativa.
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
      if v_nro_secuencia + 1 > 990 then
         v_nro_secuencia := 0;
         v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      end if;
      if i.monto <> 0 then
         -- Acredito en el rubro del Sobregiro por el Depósito Overnight
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
         r_gmovi.monto           := v_monto;
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
         r_gmovi.tip_mov_rubro   := 'C';
         r_gmovi.cod_persona     := null;
         r_gmovi.referencia      := i.nro_cuenta;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
         --
         -- Debito de la Cta.Bancaria
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
         r_gmovi.monto           := v_monto;
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
         r_gmovi.tip_mov_rubro   := 'D';
         r_gmovi.cod_persona     := null;
         r_gmovi.referencia      := i.nro_cuenta;
         PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
      end if;
   end loop;
EXCEPTION
WHEN OTHERS THEN
   raise_application_error(-20000, 'ERROR. en Sobregiro Overnight '||SQLERRM);

end;

-- PROCESO PRINCIPAL
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;

   lp_dep_overnight;
   lp_sob_dep_overnight;
end;
/

