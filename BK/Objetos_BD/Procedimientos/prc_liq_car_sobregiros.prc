CREATE OR REPLACE PROCEDURE IT."PRC_LIQ_CAR_SOBREGIROS"
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null)
is
  v_valor           number;
  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
  v_fcdehoy         date := pag_cal.fu_obt_fec_actual(4);
  v_lugar           varchar2(1000);
  v_rowcount        pls_integer := 0;
  v_mensaje         varchar2(3000);
  v_dia_inact       ge_par_dinamicos.val_parametro%type;
  v_dia_inact_global ge_par_dinamicos.val_parametro%type;
  v_cant_lote       pls_integer;
  v_indice_error    pls_integer;
  e_errores_lote    exception;
  pragma exception_init(e_errores_lote, -24381);

  type t_par_dinamico is record (
    cod_modulo    ge_par_dinamicos.cod_modulo%type,
    cod_modalidad ge_par_dinamicos.cod_modalidad%type,
    cod_moneda    ge_par_dinamicos.cod_moneda%type,
    cod_oficina   ge_par_dinamicos.cod_oficina%type,
    val_parametro ge_par_dinamicos.val_parametro%type
  );
  type t_tab_par_dinamico is table of t_par_dinamico;
  v_tab_par_dinamico t_tab_par_dinamico;

  type t_nro_cuenta is table of cc_sob_suspenso.nro_cuenta%type index by pls_integer;
  type t_monto is table of cc_sob_suspenso.monto%type index by pls_integer;
  v_nro_cuenta_lote t_nro_cuenta;
  v_mto_cargo_lote  t_monto;

 ---Cursor de cuentas con el mayor sobregiro en gestion
 CURSOR c_sob_gestion is
 SELECT S.NRO_CUENTA, C.COD_MONEDA, MAX(S.SALDO) monto,
        C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, R.CAN_DIAS
   FROM GE_CUENTAS C , CC_SOBREGIROS_RES r, CC_SOBREGIROS S
  WHERE S.LIQUIDADO = 'N'
    AND s.fecha between to_Date('01'||to_char(pag_cal.fu_obt_fec_actual(4),'mmyyyy'),'ddmmyyyy')
    AND last_day(pag_cal.fu_obt_fec_actual(4))
    AND (s.nro_cuenta = p_nro_cuenta or p_nro_cuenta IS NULL)
    AND r.nro_cuenta = s.nro_cuenta
    AND r.sit_deuda not in('S', 'V')
    AND C.NRO_CUENTA = S.NRO_CUENTA
    AND r.can_dias < nvl(CASE 
                     WHEN v_dia_inact_global IS NOT NULL THEN v_dia_inact_global
                     ELSE (SELECT a.val_parametro FROM ge_par_dinamicos a
                           WHERE a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                             AND a.cod_modulo = c.cod_modulo
                             AND a.cod_modalidad = c.cod_modalidad
                             AND a.cod_moneda = c.cod_moneda
                             AND a.cod_oficina = c.cod_oficina)
                    END, 9999)
    and c.estado not in ('C','P','A','T','D','X')
 GROUP BY S.NRO_CUENTA, C.COD_MONEDA, C.COD_MODULO, C.COD_MODALIDAD, C.COD_OFICINA, R.CAN_DIAS;

  type cursor1_type is table of c_sob_gestion%rowtype;
  reg cursor1_type;

---
  procedure pr_reg_error_lote(
    p_nro_cuenta in ge_cuentas.nro_cuenta%type,
    p_mensaje    in varchar2
  ) is
  begin
    pag_cie.pr_ins_log(
      'PRC_LIQ_CAR_SOBREGIROS cuenta ' || p_nro_cuenta || ': ' || p_mensaje,
      pag_cie.c_log_error,
      'AUTONOMOUS_TRANSACTION'
    );
  end;

   -- Copia de PAC_SOB.FU_PRO_EXE_LINEA (CIE-1247); mantener alineada con la version del paquete.
   function fu_pro_exe_linea(
      p_nro_cuenta in ge_cuentas.nro_cuenta%type
   ) return number is
      v_fcdehoy          date;
      v_nrsecue          ge_movimientos.nro_secuencia%type;
      v_hrmovim          ge_movimientos.hora%type;
      v_imdebit          ge_movimientos.monto%type := 0;
      v_esproce          ba_modulos.estado%type;
      r_gmovi            ge_movimientos%rowtype;
      v_cod_tra_cargo    number(4) := 784;
      v_cod_tas_cargo    number(4);
      v_val_tas_cargo    number(18,4);
      v_val_cargo        number(18,2);
      v_cod_tra_impuesto number(4);
      v_cod_tas_impuesto number(4);
      v_val_tas_impuesto number(18,4);
      v_val_impuesto     number(18,2);
      v_can_dias         number(8) := 0;

      cursor cte is
         select *
           from cc_cta_corrientes cc
          where cc.nro_cuenta = nvl(p_nro_cuenta, cc.nro_cuenta)
            and cc.estado not in ('C','P','A','T','D','X')
            and cc.cod_modalidad = 41
            and cc.cod_ente is null
            and cc.fec_apertura <= v_fcdehoy
            and exists
                (select 'S'
                   from cc_sobregiros ccs
                  where ccs.nro_cuenta = cc.nro_cuenta
                    and fecha between to_date('01' || to_char(v_fcdehoy, 'mmyyyy'), 'ddmmyyyy')
                                  and trunc(v_fcdehoy))
            for update of cc.estado;
      r_cte cte%rowtype;
   begin
      v_esproce := pae_cnf.fu_obt_est_modulo(4);
      v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
      v_hrmovim := fug_ini_hora(sysdate, 'HH24:MI:SS');
      v_nrsecue := 0;
      open cte;
      loop
         fetch cte into r_cte;
         exit when cte%notfound;
         begin
            select nvl(count(*), 0)
              into v_can_dias
              from cc_sobregiros ccs
             where ccs.nro_cuenta = r_cte.nro_cuenta
               and ccs.fecha between to_date('01' || to_char(v_fcdehoy, 'MMYYYY'), 'DDMMYYYY')
                                 and trunc(v_fcdehoy)
               and saldo > ccs.mto_linea;
         exception
            when others then
               v_can_dias := 0;
         end;
         v_imdebit      := 0;
         v_val_cargo    := 0;
         v_val_impuesto := 0;
         -- Sin dias de exceso el cargo calculado se descarta; PRG_OBT_CARGOS no tiene efectos.
         if nvl(v_can_dias, 0) > 0 then
            prg_obt_cargos(r_cte.cod_oficina,
                           r_cte.nro_cuenta,
                           r_cte.cod_moneda,
                           null,
                           r_cte.cod_modulo,
                           r_cte.cod_modalidad,
                           v_cod_tra_cargo,
                           v_cod_tas_cargo,
                           v_val_tas_cargo,
                           v_val_cargo,
                           v_cod_tra_impuesto,
                           v_cod_tas_impuesto,
                           v_val_tas_impuesto,
                           v_val_impuesto);
         end if;
         if v_nrsecue > 990 then
            v_hrmovim := pag_gen.fu_obt_sig_segundo(v_hrmovim);
            v_nrsecue := 0;
         end if;
         if nvl(v_can_dias, 0) > 0 then
            v_val_cargo    := nvl(v_val_cargo, 0);
            v_val_impuesto := nvl(v_val_impuesto, 0);
            v_imdebit      := v_val_cargo + v_val_impuesto;
         else
            v_val_cargo    := 0;
            v_val_impuesto := 0;
            v_imdebit      := 0;
         end if;
         -- La version original genera el cargo solo cuando el impuesto es mayor a cero.
         if v_val_impuesto > 0 then
            v_nrsecue := v_nrsecue + 1;
            r_gmovi.cod_modulo      := r_cte.cod_modulo;
            r_gmovi.cod_modalidad   := r_cte.cod_modalidad;
            r_gmovi.cod_oficina     := r_cte.cod_oficina;
            r_gmovi.nro_cuenta      := r_cte.nro_cuenta;
            r_gmovi.cod_moneda      := r_cte.cod_moneda;
            r_gmovi.cod_usuario     := substr(upper(user), 1, 10);
            r_gmovi.hora            := v_hrmovim;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nrsecue;
            r_gmovi.fec_valor       := v_fcdehoy;
            r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
            r_gmovi.cod_mod_padre   := r_cte.cod_modulo;
            r_gmovi.cod_mad_padre   := r_cte.cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_tra_cargo;
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.nro_documento   := null;
            r_gmovi.nro_documento2  := null;
            r_gmovi.nro_documento3  := null;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_tas_cargo;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := r_cte.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Debito Cargo Exceso Linea';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

            v_nrsecue := v_nrsecue + 1;
            r_gmovi.cod_modulo      := r_cte.cod_modulo;
            r_gmovi.cod_modalidad   := r_cte.cod_modalidad;
            r_gmovi.cod_oficina     := r_cte.cod_oficina;
            r_gmovi.nro_cuenta      := r_cte.nro_cuenta;
            r_gmovi.cod_moneda      := r_cte.cod_moneda;
            r_gmovi.cod_usuario     := substr(upper(user), 1, 10);
            r_gmovi.hora            := v_hrmovim;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nrsecue;
            r_gmovi.fec_valor       := v_fcdehoy;
            r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
            r_gmovi.cod_mod_padre   := r_cte.cod_modulo;
            r_gmovi.cod_mad_padre   := r_cte.cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_tra_impuesto;
            r_gmovi.monto           := v_val_impuesto;
            r_gmovi.nro_documento   := null;
            r_gmovi.nro_documento2  := null;
            r_gmovi.nro_documento3  := null;
            r_gmovi.cod_tasa        := v_cod_tas_impuesto;
            r_gmovi.val_tasa        := v_val_tas_impuesto;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := r_cte.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Debito Iva-Exceso de Linea';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
         end if;
         update cc_cta_corrientes
            set sal_total          = nvl(sal_total, 0) - nvl(v_imdebit, 0),
                fec_ult_movimiento = v_fcdehoy,
                hor_ult_movimiento = v_hrmovim
          where current of cte;
         if v_esproce != 2 then
            pag_cta.pr_act_sal_mensual(r_cte.nro_cuenta, v_imdebit);
         end if;
      end loop;
      close cte;
      return v_imdebit;
   exception
      when no_data_found then
         raise_application_error(-20000, 'No existen datos');
   end fu_pro_exe_linea;

  -- Copia de PAC_SOB.FU_PRO_EXE_PLAZO (CIE-1247); mantener alineada con la version del paquete.
  function fu_pro_exe_plazo(
    p_nro_cuenta in ge_cuentas.nro_cuenta%type,
    p_procesa    in varchar2 default 'S'
  ) return number is
    v_fcdehoy          ge_calendarios.fec_actual%type;
    v_fcproxi          ge_calendarios.fec_proxima%type;
    rv_gcale           ge_calendarios%rowtype;
    v_nrsecue          ge_movimientos.nro_secuencia%type;
    v_hrmovim          ge_movimientos.hora%type;
    v_imdebit          ge_movimientos.monto%type := 0;
    v_esproce          ba_modulos.estado%type;
    r_gmovi            ge_movimientos%rowtype;
    v_cod_tra_cargo    number(4);
    v_cod_tas_cargo    number(4);
    v_val_tas_cargo    number(18,4);
    v_val_cargo        number(18,2);
    v_cod_tra_impuesto number(4);
    v_cod_tas_impuesto number(4);
    v_val_tas_impuesto number(18,4);
    v_val_impuesto     number(18,2);
    v_cant             number := 0;
    v_can_dias         number;
    v_dia_inact_local  ge_par_dinamicos.val_parametro%type;
    v_existe           varchar2(1);
    v_hor_agotada      varchar2(1);
    v_can_bus_hora     number;

    cursor cte is
      select cc.*
        from cc_cta_corrientes cc, cc_sobregiros_res r
       where cc.nro_cuenta = nvl(p_nro_cuenta, cc.nro_cuenta)
        and cc.nro_cuenta = r.nro_cuenta(+)
        and cc.estado not in ('C','P','A','T','D','X')
        and cc.cod_modalidad = 41
        and cc.fec_apertura <= v_fcdehoy
        and exists
           (select 'S' from cc_sobregiros ccs
            where ccs.nro_cuenta = cc.nro_cuenta
              and ccs.fecha between to_date('01' || to_char(v_fcdehoy, 'mmyyyy'), 'ddmmyyyy')
                          and trunc(v_fcdehoy))
        and ((cc.cod_ente is not null and not exists
            (select 'S' from gv_movimientos h
              where h.nro_cuenta = cc.nro_cuenta
               and h.cod_transaccion = 602
               and h.fecha between to_date('01' || to_char(add_months(v_fcdehoy, -1), 'mmyyyy'), 'ddmmyyyy')
                          and trunc(v_fcdehoy)
               and h.concepto like 'Pago de Sueldo%'))
            or cc.cod_ente is null)
      for update of cc.estado;
    r_cte cte%rowtype;

    function fu_obt_hor_disponible(
      p_fecha       in date,
      p_hora        in varchar2,
      p_cod_usuario in varchar2,
      p_es_nocturno in varchar2
    ) return varchar2 is
      v_hora varchar2(8) := p_hora;
    begin
      v_hor_agotada  := 'N';
      v_can_bus_hora := 0;
      if p_es_nocturno = 'N' then
        loop
          v_can_bus_hora := v_can_bus_hora + 1;
          begin
            select 'S' into v_existe
              from ge_movimientos
             where fecha = p_fecha and hora = v_hora
              and cod_usuario = p_cod_usuario and rownum <= 1;
          exception
            when no_data_found then v_existe := 'N';
          end;
          exit when v_existe = 'N' or v_hor_agotada = 'S';
          v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
          if v_can_bus_hora >= 85000 then v_hor_agotada := 'S'; end if;
        end loop;
      else
        loop
          v_can_bus_hora := v_can_bus_hora + 1;
          begin
            select 'S' into v_existe
              from ge_movimientos_noc
             where fecha = p_fecha and hora = v_hora
              and cod_usuario = p_cod_usuario and rownum <= 1;
          exception
            when no_data_found then v_existe := 'N';
          end;
          exit when v_existe = 'N' or v_hor_agotada = 'S';
          v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
          if v_can_bus_hora >= 85000 then v_hor_agotada := 'S'; end if;
        end loop;
      end if;
      if v_hor_agotada = 'S' then
        raise_application_error(-20000, 'Error de Hora. No existe segundo disponible para el usuario');
      end if;
      return v_hora;
    end fu_obt_hor_disponible;

  begin
    v_esproce := pae_cnf.fu_obt_est_modulo(4);
    v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
    rv_gcale  := pag_cal.fu_obt_reg_cal(4);
    v_fcproxi := rv_gcale.fec_proxima;
    v_hrmovim := fug_ini_hora(sysdate, 'HH24:MI:SS');
    v_hrmovim := pag_gen.fu_obt_sig_segundo(v_hrmovim);
    v_hrmovim := fu_obt_hor_disponible(v_fcdehoy, v_hrmovim, user, 'N');
    v_nrsecue := 0;
    dbms_application_info.set_action('PRC_LIQ_CAR_SOBREGIROS');
    dbms_application_info.set_client_info('PRC_LIQ_CAR_SOBREGIROS ejecutando FU_PRO_EXE_PLAZO interna');

    open cte;
    loop
      fetch cte into r_cte;
      exit when cte%notfound;

      v_dia_inact_local := '9999';
      for p in 1 .. v_tab_par_dinamico.count loop
        if nvl(v_tab_par_dinamico(p).cod_modulo, nvl(r_cte.cod_modulo, -1)) = nvl(r_cte.cod_modulo, -1)
          and nvl(v_tab_par_dinamico(p).cod_modalidad, nvl(r_cte.cod_modalidad, -1)) = nvl(r_cte.cod_modalidad, -1)
          and nvl(v_tab_par_dinamico(p).cod_moneda, nvl(r_cte.cod_moneda, 'x')) = nvl(r_cte.cod_moneda, 'x')
          and nvl(v_tab_par_dinamico(p).cod_oficina, nvl(r_cte.cod_oficina, -1)) = nvl(r_cte.cod_oficina, -1) then
          v_dia_inact_local := v_tab_par_dinamico(p).val_parametro;
          exit;
        end if;
      end loop;

      begin
        select r.can_dias into v_can_dias
          from cc_sobregiros_res r
         where r.nro_cuenta = r_cte.nro_cuenta;
      exception
        when no_data_found then v_can_dias := null;
      end;
      if v_can_dias < nvl(to_number(v_dia_inact_local), 9999) then
        begin
          select count(*) into v_cant
            from cc_sobregiros ccs
           where ccs.nro_cuenta = r_cte.nro_cuenta
            and ccs.fecha between to_date('01' || to_char(v_fcdehoy, 'MMYYYY'), 'DDMMYYYY') and trunc(v_fcdehoy)
            and ccs.mto_linea = 0 and ccs.can_dias > 30 and ccs.liquidado = 'N';
        exception
          when no_data_found then v_cant := 0;
        end;
      else
        v_cant := 0;
      end if;

      v_imdebit      := 0;
      v_val_cargo    := 0;
      v_val_impuesto := 0;
      if v_cant > 0 then
        if r_cte.cod_ente is not null then
          if p_procesa = 'S' then
            if pac_sob.fu_sit_sobregiro(r_cte.nro_cuenta) not in ('S', 'V') then
              pag_car.fu_obt_par_cargo(11, v_cod_modulo, v_cod_modalidad, v_cod_transaccion);
              pag_car.pr_deb_cre_batch(11, r_cte.nro_cuenta);
              if nvl(pag_car.g_mto_cargo, 0) > 0 then
                insert into cc_sob_suspenso
                  (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_transaccion, monto)
                values
                  (r_cte.nro_cuenta, v_fcdehoy, v_cod_modulo, v_cod_modalidad,
                   v_cod_transaccion, nvl(pag_car.g_mto_cargo, 0));
                update cc_sobregiros_res
                  set mto_sob_suspenso = nvl(mto_sob_suspenso, 0) + nvl(pag_car.g_mto_cargo, 0)
                 where nro_cuenta = r_cte.nro_cuenta;
              end if;
            else
              pag_car.pr_deb_cre_batch(10, r_cte.nro_cuenta);
            end if;
            v_imdebit := pag_car.g_monto;
          else
            v_imdebit := null;
          end if;
        else
          if pac_sob.fu_sit_sobregiro(r_cte.nro_cuenta) not in ('S', 'V') then
            v_cod_tra_cargo := 981;
          else
            v_cod_tra_cargo := 788;
          end if;
          prg_obt_cargos(r_cte.cod_oficina, r_cte.nro_cuenta, r_cte.cod_moneda, null,
                    r_cte.cod_modulo, r_cte.cod_modalidad, v_cod_tra_cargo,
                    v_cod_tas_cargo, v_val_tas_cargo, v_val_cargo,
                    v_cod_tra_impuesto, v_cod_tas_impuesto, v_val_tas_impuesto,
                    v_val_impuesto);
          if v_nrsecue > 990 then
            v_hrmovim := pag_gen.fu_obt_sig_segundo(v_hrmovim);
            v_hrmovim := fu_obt_hor_disponible(v_fcdehoy, v_hrmovim, user, 'N');
            v_nrsecue := 0;
          end if;
          v_imdebit := v_val_cargo + v_val_impuesto;
          if p_procesa = 'S' then
            if v_val_impuesto > 0 then
              v_nrsecue := v_nrsecue + 1;
              r_gmovi.cod_modulo := r_cte.cod_modulo;
              r_gmovi.cod_modalidad := r_cte.cod_modalidad;
              r_gmovi.cod_oficina := r_cte.cod_oficina;
              r_gmovi.nro_cuenta := r_cte.nro_cuenta;
              r_gmovi.cod_moneda := r_cte.cod_moneda;
              r_gmovi.cod_usuario := substr(upper(user), 1, 10);
              r_gmovi.hora := v_hrmovim;
              r_gmovi.fecha := v_fcdehoy;
              r_gmovi.nro_secuencia := v_nrsecue;
              r_gmovi.fec_valor := v_fcdehoy;
              r_gmovi.cod_mod_padre := r_cte.cod_modulo;
              r_gmovi.cod_mad_padre := r_cte.cod_modalidad;
              r_gmovi.nro_documento := null;
              r_gmovi.nro_documento2 := null;
              r_gmovi.nro_documento3 := null;
              r_gmovi.cotizacion := null;
              r_gmovi.cod_ofi_origen := r_cte.cod_oficina;
              r_gmovi.emi_aviso := 'N';
              r_gmovi.estado := 'N';
              r_gmovi.reversado := 'N';
              r_gmovi.cod_tra_padre := v_cod_tra_cargo;
              r_gmovi.cod_transaccion := v_cod_tra_cargo;
              r_gmovi.monto := v_val_cargo;
              r_gmovi.cod_tasa := v_cod_tas_cargo;
              r_gmovi.val_tasa := v_val_tas_cargo;
              r_gmovi.concepto := 'Debito Cargo Exceso Linea';
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
              v_nrsecue := v_nrsecue + 1;
              r_gmovi.cod_tra_padre := v_cod_tra_impuesto;
              r_gmovi.cod_transaccion := v_cod_tra_impuesto;
              r_gmovi.monto := v_val_impuesto;
              r_gmovi.cod_tasa := v_cod_tas_impuesto;
              r_gmovi.val_tasa := v_val_tas_impuesto;
              r_gmovi.concepto := 'Debito Iva-Exceso de Linea';
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
            end if;
            update cc_cta_corrientes
              set sal_total = nvl(sal_total, 0) - nvl(v_imdebit, 0),
                 fec_ult_movimiento = v_fcdehoy,
                 hor_ult_movimiento = v_hrmovim
             where current of cte;
            if v_esproce != 2 and to_char(v_fcproxi, 'MMYYYY') <> to_char(v_fcdehoy, 'MMYYYY') then
              pag_cta.pr_act_sal_mensual(r_cte.nro_cuenta, v_imdebit);
            end if;
            if v_cod_tra_cargo = 981 then
              insert into cc_sob_suspenso
                (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_transaccion, monto)
              values
                (r_cte.nro_cuenta, v_fcdehoy, r_cte.cod_modulo, r_cte.cod_modalidad,
                 v_cod_tra_cargo, nvl(v_val_cargo, 0));
              update cc_sobregiros_res
                set mto_sob_suspenso = nvl(mto_sob_suspenso, 0) + nvl(v_val_cargo, 0)
               where nro_cuenta = r_cte.nro_cuenta;
            end if;
          end if;
        end if;
      end if;
    end loop;
    close cte;
    dbms_application_info.set_action(null);
    dbms_application_info.set_client_info(null);
    return v_imdebit;
  exception
    when no_data_found then
      raise_application_error(-20000, 'No existen datos');
  end fu_pro_exe_plazo;

BEGIN
  select cod_modulo,
       cod_modalidad,
       cod_moneda,
       cod_oficina,
       val_parametro
    bulk collect into v_tab_par_dinamico
    from ge_par_dinamicos
   where parametro = 'DIA_INA_CAR_SOBREGIROS'
   order by decode(cod_modulo, null, 0, 1) +
         decode(cod_modalidad, null, 0, 1) +
         decode(cod_moneda, null, 0, 1) +
         decode(cod_oficina, null, 0, 1) desc;

  if v_tab_par_dinamico.count = 0 then
    v_dia_inact_global := '9999';
  elsif v_tab_par_dinamico.count = 1
    and v_tab_par_dinamico(1).cod_modulo is null
    and v_tab_par_dinamico(1).cod_modalidad is null
    and v_tab_par_dinamico(1).cod_moneda is null
    and v_tab_par_dinamico(1).cod_oficina is null then
    v_dia_inact_global := v_tab_par_dinamico(1).val_parametro;
  else
    v_dia_inact_global := null;
  end if;

   --------------------------------------------------
   -- cargos por sobregiro por utilizacion de linea -
   --------------------------------------------------
  DBMS_APPLICATION_INFO.SET_ACTION('LIQ_PAC_FU_UTI_LINEA');
  v_lugar := p_nro_cuenta||',pac_sob.FU_UTI_LINEA';
  v_valor := pac_sob.FU_UTI_LINEA(p_nro_cuenta,'S');

   -----------------------------------------------------------------------------------------------
   -- cargos por sobregiro por exceso de linea -
   -----------------------------------------------------------------------------------------------
   -- RI : 12/10/09 Se comenta por el momento este cargo porque no esta en tarifario del banco
  DBMS_APPLICATION_INFO.SET_ACTION('LIQ_PAC_FU_PRO_EXE_LINEA');
  v_valor := fu_pro_exe_linea(p_nro_cuenta);

   -----------------------------------------------------------------------------------------------
   -- cargos por sobregiro por exceso de plazo   > 30 DIAS
   -----------------------------------------------------------------------------------------------
  DBMS_APPLICATION_INFO.SET_ACTION('LIQ_PAC_FU_PRO_EXE_PLAZO');
  v_lugar := p_nro_cuenta||'FU_PRO_EXE_PLAZO interna';
  v_valor := fu_pro_exe_plazo(p_nro_cuenta,'S');

   -----------------------------------------------------------------------------------------------
   /* Generar comision por mayor sobregiro */
   -----------------------------------------------------------------------------------------------
  DBMS_APPLICATION_INFO.SET_ACTION('LIQ_BATCH_8');
  v_lugar := p_nro_cuenta||'PAG_CAR.PR_DEB_CRE_BATCH(8)';
   PAG_CAR.PR_DEB_CRE_BATCH(8,p_nro_cuenta);

   -----------------------------------------------------------------------------------------------
   /* Generar comision por mayor sobregiro en gestion */
   -----------------------------------------------------------------------------------------------
   /* Si está en Gestion Grabar la tabla de sobregiros en suspenso y actualizar cc_cta_corrientes
      y generar las transacciones diferenciadas --> Debitos/Creditos Batch codigo 9 */
   --Obtener los parametros del cargo, modulo,modalidad y transaccion
   v_lugar := p_nro_cuenta||'PAG_CAR.FU_OBT_PAR_CARGO';
   PAG_CAR.FU_OBT_PAR_CARGO(9,v_cod_modulo,v_cod_modalidad,v_cod_transaccion);
   
   DBMS_APPLICATION_INFO.SET_ACTION('PRC_LIQ_CAR_SOBREGIROS');
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRC_LIQ_CAR_SOBREGIROS, Iniciando loop principal');
   OPEN c_sob_gestion;
     LOOP
     FETCH c_sob_gestion BULK COLLECT INTO reg LIMIT 5000;
    v_cant_lote := 0;
    v_nro_cuenta_lote.delete;
    v_mto_cargo_lote.delete;

    for i in 1 .. reg.count loop
      if v_dia_inact_global is not null then
        v_dia_inact := v_dia_inact_global;
      else
        v_dia_inact := '9999';
        for p in 1 .. v_tab_par_dinamico.count loop
          if nvl(v_tab_par_dinamico(p).cod_modulo, nvl(reg(i).cod_modulo, -1)) = nvl(reg(i).cod_modulo, -1)
            and nvl(v_tab_par_dinamico(p).cod_modalidad, nvl(reg(i).cod_modalidad, -1)) = nvl(reg(i).cod_modalidad, -1)
            and nvl(v_tab_par_dinamico(p).cod_moneda, nvl(reg(i).cod_moneda, 'x')) = nvl(reg(i).cod_moneda, 'x')
            and nvl(v_tab_par_dinamico(p).cod_oficina, nvl(reg(i).cod_oficina, -1)) = nvl(reg(i).cod_oficina, -1) then
            v_dia_inact := v_tab_par_dinamico(p).val_parametro;
            exit;
          end if;
        end loop;
      end if;

      if reg(i).can_dias < nvl(to_number(v_dia_inact), 9999) then
        begin
          DBMS_APPLICATION_INFO.SET_ACTION('LIQ_BATCH_9');
          v_lugar := reg(i).nro_cuenta || ',PAG_CAR.PR_DEB_CRE_BATCH(9)';
          pag_car.pr_deb_cre_batch(9, reg(i).nro_cuenta);
          v_cant_lote := v_cant_lote + 1;
          v_nro_cuenta_lote(v_cant_lote) := reg(i).nro_cuenta;
          v_mto_cargo_lote(v_cant_lote) := nvl(pag_car.g_mto_cargo, 0);
          v_rowcount := v_rowcount + 1;
        exception
          when others then
            pr_reg_error_lote(reg(i).nro_cuenta, sqlerrm);
        end;
      end if;
    end loop;

    if v_nro_cuenta_lote.count > 0 then
      begin
        forall i in v_nro_cuenta_lote.first .. v_nro_cuenta_lote.last save exceptions
          insert into cc_sob_suspenso
            (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_transaccion, monto)
          values
            (v_nro_cuenta_lote(i), v_fcdehoy, v_cod_modulo, v_cod_modalidad,
             v_cod_transaccion, v_mto_cargo_lote(i));
      exception
        when e_errores_lote then
          declare
            v_insert_errors PLS_INTEGER := 0;
          begin
            for i in 1 .. sql%bulk_exceptions.count loop
              v_indice_error := sql%bulk_exceptions(i).error_index;
              v_insert_errors := v_insert_errors + 1;
              pr_reg_error_lote(
                v_nro_cuenta_lote(v_indice_error),
                'cc_sob_suspenso INSERT: ' || sqlerrm(-sql%bulk_exceptions(i).error_code)
              );
            end loop;
            raise_application_error(-20096, 'PRC_LIQ_CAR_SOBREGIROS: ' || v_insert_errors || 
              ' error(es) en INSERT cc_sob_suspenso cargo batch 9 - transaccion abortada');
          end;
      end;

      if v_nro_cuenta_lote.count > 0 then
        begin
          forall i in indices of v_nro_cuenta_lote save exceptions
            update cc_sobregiros_res
              set mto_sob_suspenso = nvl(mto_sob_suspenso, 0) + v_mto_cargo_lote(i)
             where nro_cuenta = v_nro_cuenta_lote(i);
        exception
          when e_errores_lote then
            declare
              v_update_errors PLS_INTEGER := 0;
            begin
              for i in 1 .. sql%bulk_exceptions.count loop
                v_indice_error := sql%bulk_exceptions(i).error_index;
                v_update_errors := v_update_errors + 1;
                pr_reg_error_lote(
                  v_nro_cuenta_lote(v_indice_error),
                  'cc_sobregiros_res UPDATE: ' || sqlerrm(-sql%bulk_exceptions(i).error_code)
                );
              end loop;
              raise_application_error(-20097, 'PRC_LIQ_CAR_SOBREGIROS: ' || v_update_errors || 
                ' error(es) en UPDATE cc_sobregiros_res mto_sob_suspenso - transaccion abortada');
            end;
        end;
      end if;
    end if;

    if mod(v_rowcount, 10000) = 0 and v_rowcount > 0 then
      v_mensaje := v_rowcount || ' cuentas procesadas';
      dbms_application_info.set_client_info(v_mensaje);
    end if;
       EXIT WHEN c_sob_gestion%NOTFOUND;
     END LOOP;
     CLOSE c_sob_gestion;
   DBMS_APPLICATION_INFO.SET_ACTION(NULL);
   DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
   
   -----------------------------------------------------------------------------------------------
   /* Generar comision por seguro de vida sobre sobregiro */
   -----------------------------------------------------------------------------------------------
  DBMS_APPLICATION_INFO.SET_ACTION('LIQ_SEGURO');
  v_lugar := p_nro_cuenta||',prc_deb_seg_vid_sobregiro';
   prc_deb_seg_vid_sobregiro(p_nro_cuenta);

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error en Prc_liq_car_sobregiros : '||v_lugar||'-'|| sqlerrm);
end;
/
