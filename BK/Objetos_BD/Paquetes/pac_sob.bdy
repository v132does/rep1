CREATE OR REPLACE PACKAGE BODY IT.PAC_SOB IS
/* Debita la cantidad de dias que estuvo excedido en la linea de su acu. */
  g_fre_proceso VARCHAR2(1) := fug_obt_fre_proceso('PRC_LIQ_CAR_SOBREGIROS');
  g_db_prod     VARCHAR2(1) := fug_ind_produccion;
FUNCTION FU_PRO_EXE_LINEA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER
 IS
  v_fcdehoy date;
  v_fcfinal date;
---
-- Obtiene todas las cuentas corrientes que se encuentren en estado distintos a
-- Cancelada
-- Pendiente de Cancelacion
-- Abierta Falta Depositar
-- Totalmente Bloqueada
-- Bloqueo de Debito
--
-- Y que no corresponda a las bancas: Corporativa, UR, Mercado Capitales, Funcionarios,
-- Privada, e Institucional.
-- Si se envia nulo el numero de cuenta, hace para todas las cuentas que cumplen con la condicion.
--
  CURSOR cte IS
    select *
      from cc_cta_corrientes cc
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.cod_ente is null -- solo para los que no son PLAN SUELDOS
       and cc.fec_apertura <= v_fcdehoy
       and exists
           (select 'S'
              from cc_sobregiros ccs
         where ccs.nro_cuenta = cc.nro_cuenta
         and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
         and trunc(v_fcdehoy))
    for update of cc.estado;
  r_cte cte%rowtype;
--
  v_nrsecue ge_movimientos.nro_secuencia%type;
  v_hrmovim ge_movimientos.hora%type;
  v_imdebit ge_movimientos.monto%type :=  0;
  v_esproce ba_modulos.estado%type;
  r_gmovi   GE_MOVIMIENTOS%ROWTYPE;

  v_cod_tra_cargo number(4) := 784;--Transaccion para el cobro de cargos
  v_cod_tas_cargo number(4);
  v_val_tas_cargo number(18,4);
  v_val_cargo     number(18,2);
  v_cod_tra_impuesto number(4);
  v_cod_tas_impuesto number(4);
  v_val_tas_impuesto number(18,4);
  v_val_impuesto number(18,2);
  v_can_dias number(8) := 0;
BEGIN
  -- RI : 28/01/2010 : Se devuelve cero el valor de esta funcion porque
  -- este cargo no esta en el tarifario del BANCO. Y es llamado
  -- desde algunos forms.


  -- Verifica el estado del modulo para acumular o no
  v_esproce := pae_cnf.fu_obt_est_modulo(4);
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  v_hrmovim := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_nrsecue := 0;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;
    -- cuento los dias que el cliente excedio su linea
    Begin
        Select nvl(count(*),0) --cantidad de dias
          into v_can_dias
          from cc_sobregiros ccs
         where ccs.nro_cuenta          = r_cte.nro_cuenta
           and ccs.fecha between TO_DATE('01'||to_char(v_fcdehoy, 'MMYYYY'),'DDMMYYYY')
           and trunc(v_fcdehoy)
           and saldo > ccs.mto_linea;
    Exception
       When others then
         v_can_dias := 0;
    End;
    -- Cero los valores para asegurar
    v_imdebit := 0;
    v_val_cargo := 0;
    v_val_impuesto := 0;
    -- obtengo el cargo y el impuesto
    prg_obt_cargos(r_cte.cod_oficina,
               r_cte.nro_cuenta,
               r_cte.cod_moneda,
               NULL,
               r_cte.cod_modulo,
               r_cte.cod_modalidad,
               v_cod_tra_cargo,--Transaccion para el cobro de cargos
               v_cod_tas_cargo,
               v_val_tas_cargo,
               v_val_cargo,
               v_cod_tra_impuesto,
               v_cod_tas_impuesto,
               v_val_tas_impuesto,
               v_val_impuesto);
     if v_nrsecue > 990 then
        v_hrmovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_hrmovim);
        v_nrsecue := 0;
     end if;
    -- Calcula el monto a debitar de la cuenta
     if nvl(v_can_dias,0) > 0 then
       v_val_cargo := nvl(v_val_cargo,0); -- * v_can_dias;
       v_val_impuesto := nvl(v_val_impuesto,0);-- * v_can_dias;
       v_imdebit := v_val_cargo + v_val_impuesto;
     else
       v_val_cargo :=0;
       v_val_impuesto :=0;
       v_imdebit := 0;
     end if;
     IF p_procesa = 'S' then
       IF v_val_impuesto > 0 and p_procesa = 'S' THEN
         -- movimiento de debito del Cargo
         -----------------------
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
         --
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
       END IF;
       IF v_val_impuesto > 0 THEN
          -- movimiento de debito por iva
          ----------------------------------
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
          --
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
       END IF;
       -- actualizar el maestro de cuentas corrientes
       update cc_cta_corrientes
          set sal_total          = nvl(sal_total,0) - nvl(v_imdebit,0) ,
              fec_ult_movimiento = v_fcdehoy,
              hor_ult_movimiento = v_hrmovim
       where  current of cte;
       -- actualiza el acumulado de saldos mensuales si el estado del modulo != 2
       If v_esproce != 2 Then
          PAG_CTA.PR_ACT_SAL_MENSUAL (r_cte.nro_cuenta,v_imdebit);
       End If;
     end if;
     <<fin_mientras>> NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  -- Retorna el monto del debito
  Return v_imdebit;
EXCEPTION
  when no_data_found then
     raise_application_error(-20000,'No existen datos');
End;

/* Cuenta los dias de sobregiro que exceden los 30 dias en este mes */
FUNCTION FU_DIA_SOB_INI_MES
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FCTRANS IN DATE
 )
 RETURN NUMBER
 IS
V_DIASMOR NUMBER(6) := 0;
v_fcactua date;
CURSOR C_DIAS IS
  SELECT FECHA
    FROM CC_SOBREGIROS
   WHERE NRO_CUENTA = P_NRO_CUENTA
     AND FECHA <= P_FCTRANS
ORDER BY FECHA desc;
Begin
    v_fcactua := p_fctrans;
    -- Lee el sobregiros  ordenado para atras
     For dia in c_dias Loop
         exit when v_fcactua - dia.fecha > 1 or v_diasmor >= 30;  -- se corto o es mas de 30 dias
         v_fcactua := dia.fecha;
         v_diasmor := v_diasmor + 1;
     End Loop;
     Return nvl(v_diasmor,0);
End;

/* Trae la situacion del sobregiro en Cc_sobregiros_res*/
FUNCTION FU_SIT_SOBREGIRO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
v_situacion varchar2(1);
Begin
    Select sit_deuda
      into v_situacion
      from cc_sobregiros_res
     where nro_cuenta = p_nro_cuenta;
    Return v_situacion;
Exception
 when others then
   return null;
End;
FUNCTION FU_OBT_HOR_DISPONIBLE(p_fecha       in date,
                               p_hora        in varchar2,
                               p_cod_usuario in varchar2,
                               p_es_nocturno in varchar2)
return varchar2 is
  -- funcion para obtener la hora que no esté utilizado en movimientos
  v_existe varchar2(1);
  v_hora   varchar2(8) := p_hora;
  v_can_bus_hora number := 0;
  v_hor_agotada varchar2(1) := 'N';
  v_can_bus_por_hora number;
begin
  --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
  if p_es_nocturno = 'N' then
    loop
      v_can_bus_hora := v_can_bus_hora + 1;
      begin
        select 'S'
          into v_existe
          from ge_movimientos
         where fecha = p_fecha
           and hora = v_hora
           and cod_usuario = p_cod_usuario
           and rownum <= 1;
      exception
        when no_data_found then
          v_existe := 'N';
      end;
      exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      if v_can_bus_hora >= 85000 then
         v_hor_agotada := 'S';
      end if;
    end loop;
  else -- es nocturno
    loop
      v_can_bus_hora := v_can_bus_hora + 1;
      begin
        select 'S'
          into v_existe
          from ge_movimientos_noc
         where fecha = p_fecha
           and hora = v_hora
           and cod_usuario = p_cod_usuario
           and rownum <= 1;
      exception
        when no_data_found then
          v_existe := 'N';
      end;
      exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      if v_can_bus_hora >= 85000 then
         v_hor_agotada := 'S';
      end if;
    end loop;
  end if;
  if v_hor_agotada = 'S' then
    raise_application_error(-20000,'Error de Hora. No existe segundo disponible para el usuario');
  end if;
  return v_hora;
end;
/* Debita los excesos de plazo, los que superan 30 dias de sobregiro */
FUNCTION FU_PRO_EXE_PLAZO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER
 IS
  v_fcdehoy ge_calendarios.fec_actual%type;
  v_fcproxi ge_calendarios.fec_proxima%type;
  RV_GCALE  GE_CALENDARIOS%ROWTYPE;

  -- v_fcfinal date;
---
-- Obtiene todas las cuentas corrientes que se encuentren en estado distintos a
-- Cancelada
-- Pendiente de Cancelacion
-- Abierta Falta Depositar
-- Totalmente Bloqueada
-- Bloqueo de Debito
--
-- Y que no corresponda a las bancas: Corporativa, UR, Mercado Capitales, Funcionarios,
-- Privada, e Institucional.
-- Si se envia nulo el numero de cuenta, hace para todas las cuentas que cumplen con la condicion.
--
-- RI: 19/10/09 : Los clientes de Nómina, mientras perciban sus nominas tienen exonerado
-- la comision por sobregiro de mas de 30 días.
  CURSOR cte IS
    select cc.*
      from cc_cta_corrientes cc,cc_sobregiros_res r
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.nro_cuenta = r.nro_cuenta(+)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.fec_apertura <= v_fcdehoy
       and r.can_dias < nvl((select a.val_parametro
                               from ge_par_dinamicos a
                              where a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                                and a.cod_modulo = cc.cod_modulo
                                and a.cod_modalidad = cc.cod_modalidad
                                and a.cod_moneda = cc.cod_moneda
                                and a.cod_oficina = cc.cod_oficina),9999)
       and exists
           (select 'S'
              from cc_sobregiros ccs
              where ccs.nro_cuenta = cc.nro_cuenta
               and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
               and trunc(v_fcdehoy))
       and ((cc.cod_ente is not null  -- cuenta de nomina
       and not exists  --  para que no tome las cuentas de nomina vigentes
            (select 'S' from gv_movimientos h
              where h.nro_cuenta = cc.nro_cuenta
                and h.cod_transaccion = 602  --Credito en cuenta
                and h.fecha between to_Date('01'||to_char(add_months(v_fcdehoy,-1),'mmyyyy'),'ddmmyyyy')
                and trunc(v_fcdehoy)
                and h.concepto like 'Pago de Sueldo%'))
        or cc.cod_ente is null)
    for update of cc.estado;
  r_cte cte%rowtype;
--
  v_nrsecue ge_movimientos.nro_secuencia%type;
  v_hrmovim ge_movimientos.hora%type;
  v_imdebit ge_movimientos.monto%type :=  0;
  v_esproce ba_modulos.estado%type;
  r_gmovi   GE_MOVIMIENTOS%ROWTYPE;

  v_cod_modulo      ge_transacciones.cod_modulo%type;
  v_cod_modalidad   ge_transacciones.cod_modalidad%type;
  v_cod_transaccion ge_transacciones.cod_transaccion%type;
  v_cod_tra_cargo number(4);
  v_cod_tas_cargo number(4);
  v_val_tas_cargo number(18,4);
  v_val_cargo number(18,2);
  v_cod_tra_impuesto number(4);
  v_cod_tas_impuesto number(4);
  v_val_tas_impuesto number(18,4);
  v_val_impuesto number(18,2);
  v_cant   number := 0;
  v_rowcount PLS_INTEGER := 0;
  v_mensaje varchar2(3000);
  v_cant_registros PLS_INTEGER := 0;
  -- v_tot_dias_sobregiros number(8);
  -- v_dia_sob_inicial number := 0;
  -- v_fecha date;
  -- v_fec_inicio date;
BEGIN
  -- Verifica el estado del modulo para acumular o no
  v_esproce := pae_cnf.fu_obt_est_modulo(4);
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_FCPROXI := rv_gcale.fec_proxima;
  -- v_fec_inicio := TO_DATE('01'||to_char(v_fcdehoy, 'MMYYYY'),'DDMMYYYY');
  v_hrmovim := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_hrmovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_hrmovim);
  v_hrmovim := fu_obt_hor_disponible(v_fcdehoy,v_hrmovim,user,'N');
  v_nrsecue := 0;
  DBMS_APPLICATION_INFO.SET_ACTION('PRC_LIQ_CAR_SOBREGIROS');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRC_LIQ_CAR_SOBREGIROS ejecutando PAC_SOB.FU_PRO_EXE_PLAZO');
  --Recupero la cantidad total de los registros a procesar
  BEGIN
    select count(0)
      into v_cant_registros
      from cc_cta_corrientes cc,cc_sobregiros_res r
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.nro_cuenta = r.nro_cuenta(+)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.fec_apertura <= v_fcdehoy
       and r.can_dias < nvl((select a.val_parametro
                               from ge_par_dinamicos a
                              where a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                                and a.cod_modulo = cc.cod_modulo
                                and a.cod_modalidad = cc.cod_modalidad
                                and a.cod_moneda = cc.cod_moneda
                                and a.cod_oficina = cc.cod_oficina),9999)
       and exists
           (select 'S'
              from cc_sobregiros ccs
              where ccs.nro_cuenta = cc.nro_cuenta
               and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
               and trunc(v_fcdehoy))
       and ((cc.cod_ente is not null  -- cuenta de nomina
       and not exists  --  para que no tome las cuentas de nomina vigentes
            (select 'S' from gv_movimientos h
              where h.nro_cuenta = cc.nro_cuenta
                and h.cod_transaccion = 602  --Credito en cuenta
                and h.fecha between to_Date('01'||to_char(add_months(v_fcdehoy,-1),'mmyyyy'),'ddmmyyyy')
                and trunc(v_fcdehoy)
                and h.concepto like 'Pago de Sueldo%'))
        or cc.cod_ente is null);
  EXCEPTION
    WHEN OTHERS THEN
      v_cant_registros := 0;
  END;

  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;
    -- v_dia_sob_inicial := FU_DIA_SOB_INI_MES(r_cte.nro_cuenta, last_day(add_months(v_fcdehoy,-1)));
    -- cuento los dias que el cliente excedio su linea
    -- v_fec_inicio := TO_DATE('01'||to_char(v_fcdehoy, 'MMYYYY'),'DDMMYYYY') - 1;
    -- v_can_dias := 0;
    v_rowcount := v_rowcount + 1;
    -- Solo entra aquí cada 10,000 registros
    IF MOD(v_rowcount, 10000) = 0 THEN
      v_mensaje := v_rowcount||' cuentas procesadas de '||v_cant_registros;
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
    END IF;
    -- busco la cantidad de dias en exceso
    Begin
      select count(*)
        into v_cant
        from cc_sobregiros ccs
       where ccs.nro_cuenta = r_cte.nro_cuenta
         and ccs.fecha between TO_DATE('01' || to_char(v_fcdehoy, 'MMYYYY'), 'DDMMYYYY') AND trunc(v_fcdehoy)
         and (ccs.mto_linea = 0 and can_dias > 30)
         and ccs.liquidado = 'N'; -- Sobregiros sin linea y sobregiros mayores a 30 dias
    exception
      when no_data_found then
        v_cant := 0;
    end;
    -- Cero los valores para asegurar
    v_imdebit := 0;
    v_val_cargo := 0;
    v_val_impuesto := 0;
    If v_cant > 0 then   -- si encontro algun registro
      -- RI :19/10/09: Si es cuenta de nomina y no esta percibiendo su nomina entonces se cobra la comision
      -- diferenciada sobre el mayor saldo deudor
      If r_cte.cod_ente is not null then -- es cuenta de nomina
        -- Verifico el estado del sobregiro, si esta en gestion se genera el movimiento
        -- con otra transaccion
        IF p_procesa = 'S' then
          if FU_SIT_SOBREGIRO(r_cte.nro_cuenta) not in('S','V') then  -- En gestion, mayor a 60 dias
             --Obtener los parametros del cargo, modulo,modalidad,transaccion
             PAG_CAR.FU_OBT_PAR_CARGO(11,v_cod_modulo,v_cod_modalidad,v_cod_transaccion);
             -- Generar cargo
             PAG_CAR.PR_DEB_CRE_BATCH(11,r_cte.nro_cuenta);
             If nvl(pag_car.g_mto_cargo,0) > 0 then
              -- Insertar en sobregiro en suspenso
              insert into cc_sob_suspenso
              (nro_cuenta,fecha,cod_modulo,cod_modalidad,cod_transaccion,monto)
              values
              (r_cte.nro_cuenta,v_fcdehoy,v_cod_modulo,v_cod_modalidad,v_cod_Transaccion,nvl(pag_car.g_mto_cargo,0));
              -- Actualizar el monto en suspenso en Cta.Cte.
              Update cc_sobregiros_res
                 set mto_sob_suspenso = nvl(mto_sob_suspenso,0)+nvl(pag_car.g_mto_cargo,0)
               where nro_cuenta = r_cte.nro_cuenta;
             End if;
          else   -- si no esta en gestion
             PAG_CAR.PR_DEB_CRE_BATCH(10,r_cte.nro_cuenta);
          end if;
          v_imdebit := pag_car.g_monto;
        else
          v_imdebit := null;
        End if;
    else
      -- Verifico el estado del sobregiro, si esta en gestion se genera el movimiento
      -- con otra transaccion
      if FU_SIT_SOBREGIRO(r_cte.nro_cuenta) not in('S','V') then  -- En gestion, mayor a 60 dias
        v_cod_tra_cargo := 981;  --Transaccion para sobregiros en gestion
      else
        v_cod_tra_cargo := 788;  --Transaccion para el cobro de cargos
      end if;
      -- obtengo el cargo y el impuesto
      prg_obt_cargos(r_cte.cod_oficina,
               r_cte.nro_cuenta,
               r_cte.cod_moneda,
               NULL,
               r_cte.cod_modulo,
               r_cte.cod_modalidad,
               v_cod_tra_cargo,--Transaccion para el cobro de cargos
               v_cod_tas_cargo,
               v_val_tas_cargo,
               v_val_cargo,
               v_cod_tra_impuesto,
               v_cod_tas_impuesto,
               v_val_tas_impuesto,
               v_val_impuesto);
      if v_nrsecue > 990 then
         v_hrmovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_hrmovim);
         v_hrmovim := fu_obt_hor_disponible(v_fcdehoy,v_hrmovim,user,'N');
         v_nrsecue := 0;
      end if;
     -- Calcula el monto a debitar de la cuenta
     /* -- RI-08/10/09 : Se aplica el valor que está definida en la tasa,
     no se multiplica por los dias
     v_val_cargo := v_val_cargo * v_can_dias;
     v_val_impuesto := v_val_impuesto * v_can_dias; */
     v_imdebit := v_val_cargo + v_val_impuesto;
     IF p_procesa = 'S' then
       IF v_val_impuesto > 0 and p_procesa = 'S' THEN
         -- movimiento de debito del Cargo
         -----------------------
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
         --
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
       END IF;
       IF v_val_impuesto > 0 THEN
          -- movimiento de debito por iva
          ----------------------------------
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
          --
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
       END IF;
       -- actualizar el maestro de cuentas corrientes
       update cc_cta_corrientes
          set sal_total          = nvl(sal_total,0) - nvl(v_imdebit,0) ,
              fec_ult_movimiento = v_fcdehoy,
              hor_ult_movimiento = v_hrmovim
       where  current of cte;
       -- actualiza el acumulado de saldos mensuales si el estado del modulo != 2
       If v_esproce != 2
       and to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fcdehoy,'mmyyyy') then
          PAG_CTA.PR_ACT_SAL_MENSUAL (r_cte.nro_cuenta,v_imdebit);
       End If;

       -- RI-14/10/09 : Si el sobregiro está en gestion se graba con transaccion
       -- diferenciada (981) y se inserta en la tabla de cargos en suspenso
       If v_cod_tra_cargo = 981 then --en gestion
         -- Insertar en sobregiro en suspenso
         insert into cc_sob_suspenso
         (nro_cuenta,fecha,cod_modulo,cod_modalidad,cod_transaccion,monto)
         values
         (r_cte.nro_cuenta,v_fcdehoy,r_cte.cod_modulo,r_cte.cod_modalidad,
          v_cod_tra_cargo,nvl(v_val_cargo,0));
          --- Actualizar el monto en suspenso en Cta.Cte.
          Update cc_sobregiros_res
             set mto_sob_suspenso = nvl(mto_sob_suspenso,0)+nvl(v_val_cargo,0)
           where nro_cuenta = r_cte.nro_cuenta;
       end if;

     end if;
   End if;
  End if;
     <<fin_mientras>>
     NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  DBMS_APPLICATION_INFO.SET_ACTION(NULL);
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
  -- Retorna el monto del debito
  Return v_imdebit;
EXCEPTION
  when no_data_found then
     raise_application_error(-20000,'No existen datos');
End;
/* Proceso de liquidacion de sobregiros */
PROCEDURE PR_PRO_LIQ_SOB
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_PROCESAR IN VARCHAR2
 ,P_IMPUESTO OUT NUMBER
 ,P_INTERES OUT NUMBER
 ,P_MANUAL IN VARCHAR2 default null)
 IS
RV_GCALE GE_CALENDARIOS%ROWTYPE;
V_COD_MODULO GE_CUENTAS.COD_MODULO%TYPE;
V_COD_MODALIDAD GE_CUENTAS.COD_MODALIDAD%TYPE;
V_COD_MONEDA GE_CUENTAS.COD_MONEDA%TYPE;
V_COD_OFICINA GE_CUENTAS.COD_OFICINA%TYPE;
V_TAS_PERSONALIZADA GE_CUENTAS.TAS_PERSONALIZADA%TYPE;
V_ESTADO CC_CTA_CORRIENTES.ESTADO%TYPE;
V_TRA_PROHIBIDA CC_CTA_CORRIENTES.TRA_PROHIBIDA%TYPE;
V_IMTRANS NUMBER(18,2);
V_VLTASA GE_MOVIMIENTOS.VAL_TASA%TYPE;
V_CDTASAS GE_MOVIMIENTOS.COD_TASA%TYPE;
V_VLTASCA GE_MOVIMIENTOS.VAL_TASA%TYPE;
V_CDTASCA GE_MOVIMIENTOS.COD_TASA%TYPE;
V_FEC_VIGENCIA DATE;
V_CDTRANS GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_CDTRANC GE_TRANSACCIONES.COD_TRANSACCION%TYPE;
V_USUARIO ba_usuarios.cod_usuario%type;
V_SALDO NUMBER(18, 2);
V_FECHA DATE;
V_CDERROR VARCHAR2(50);
V_CTA_COMBINADA CC_CTA_CORRIENTES.CTA_COMBINADA%TYPE;
V_CAN_USER NUMBER;
V_NRO_CUENTA GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_TOTAL NUMBER(18,2);
V_TIPO_COM VARCHAR2(1);
V_NRSECUEN NUMBER(8);
V_IMPUESTO NUMBER(18,2);
V_ESMOVIM VARCHAR2(1);
V_TPVLPOR GE_TASAS.TIP_VALOR%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_FCDEHOY DATE;
V_INTERES NUMBER(18,2);
V_GENERA NUMBER(8);
V_PROCESA NUMBER(8);
V_MAYOR30 VARCHAR2(1);
V_INTERES_CONACU NUMBER(18,2);
V_INTERES_SINACU NUMBER(18,2);
V_TT_SLDEUDO NUMBER(18,2);
V_NRDOCUM GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE;
V_NO_CORTE NUMBER(8);
V_CORTE NUMBER(8);
V_SLDEUDO NUMBER(18,2);
V_FCPROXI GE_CALENDARIOS.FEC_PROXIMA%TYPE;
V_ULTDIAM GE_CALENDARIOS.ULT_DIA_MES%TYPE;
v_manual varchar2(1):='N';
v_cod_ente CC_CTA_CORRIENTES.COD_ENTE%TYPE;
v_tot_linea number(18,2);
v_mto_lin_transitoria number(18,2);
v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
CURSOR SALDO_DEU IS
      SELECT ccs.nro_cuenta,
             ccs.fecha,
             ccs.saldo,
             ccs.mto_linea,
             ccs.mto_lin_transitoria,
             ge.cod_modulo,
             ge.cod_modalidad,
             ge.cod_oficina,
             ge.cod_moneda,
             ge.tas_personalizada,
             cc.cod_ente,
             cc.estado,
             cc.tra_prohibida,
             cc.cta_combinada,
             ge.cod_sub_modalidad
        FROM cc_sobregiros ccs
        JOIN ge_cuentas ge ON ccs.nro_cuenta = ge.nro_cuenta
        JOIN cc_cta_corrientes cc ON ccs.nro_cuenta = cc.nro_cuenta
       WHERE ccs.nro_cuenta = P_NRO_CUENTA
         AND ccs.liquidado = 'N'
         AND ccs.fecha <= v_ultdiam
         AND NVL(ccs.can_dias, 0) < nvl((select a.val_parametro
                                           from ge_par_dinamicos a
                                          where a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                                            and a.cod_modulo = ge.cod_modulo
                                            and a.cod_modalidad = ge.cod_modalidad
                                            and a.cod_moneda = ge.cod_moneda
                                            and a.cod_oficina = ge.cod_oficina),9999)
       ORDER BY ccs.nro_cuenta, ccs.fecha;
     TYPE saldo_deu_rec IS RECORD (
        nro_cuenta           cc_sobregiros.nro_cuenta%TYPE,
        fecha                DATE,
        saldo                NUMBER,
        mto_linea            NUMBER,
        mto_lin_transitoria  NUMBER,
        cod_modulo           ge_cuentas.cod_modulo%type,
        cod_modalidad        ge_cuentas.cod_modalidad%type,
        cod_oficina          ge_cuentas.cod_oficina%type,
        cod_moneda           ge_cuentas.cod_moneda%type,
        tas_personalizada    ge_cuentas.tas_personalizada%type,
        cod_ente             cc_cta_corrientes.cod_ente%type,
        estado               cc_cta_corrientes.estado%type,
        tra_prohibida        cc_cta_corrientes.tra_prohibida%type,
        cta_combinada        cc_cta_corrientes.cta_combinada%type,
        cod_sub_modalidad    ge_cuentas.cod_sub_modalidad%type);

    TYPE saldo_deu_tab IS TABLE OF saldo_deu_rec;
    saldo_deu_data saldo_deu_tab;
VLACUER       NUMBER(18,2) := 0;
VLTASA        NUMBER(18,2) := 0;
v_IMPUESTOS   NUMBER(18,2) := 0;--DYDMR-6401 Error Simulación Cierre fin de mes PRC_LIQ_SOBREGIROS
v_OK          VARCHAR2(01)     := 'S';
v_PRIMERA     VARCHAR2(1)      := 'S';
v_PROCESAR    VARCHAR2(1)      := 'S';
v_nro_cta_ant ge_cuentas.nro_cuenta%type;
v_cod_sub_modalidad ge_cuentas.cod_sub_modalidad%type;
PROCEDURE LP_OBT_VAL_TASA(P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
                         ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
                         ,P_COD_OFICINA IN BA_OFICINAS.COD_OFICINA%TYPE
                         ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
                         ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
                         ,P_MTO_TRANSACCION IN NUMBER default 0
                         ,P_TAS_PERSONALIZADA IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE
                         ,P_COD_TASA IN OUT GE_TASAS.COD_TASA%TYPE
                         ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
                         ,P_FEC_FINAL IN DATE
                         ,P_VAL_TASA OUT GE_TAS_FECHAS.VAL_TASA%TYPE
                         ,P_COD_SUB_MODALIDAD IN NUMBER) IS

v_encontro VARCHAR2(1):= 'N';
BEGIN
  --Si la transaccion es para calcular interes (550), se valida si tiene tasa personalizada
  IF P_COD_TRANSACCION = '550' THEN
    IF v_tas_personalizada = 'N' then--No tiene tasa personalizada
      BEGIN
        select T.VAL_TASA, t.cod_tasa
          into P_VAL_TASA, P_COD_TASA
          from ge_tas_fechas t, ge_transacciones c
         WHERE nvl(t.cod_modulo, p_cod_modulo) = p_cod_modulo
           AND nvl(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
           AND nvl(t.cod_sub_modalidad, nvl(P_COD_SUB_MODALIDAD, -1)) = nvl(P_COD_SUB_MODALIDAD, -1)
           AND nvl(cod_oficina, p_cod_oficina) = p_cod_oficina
           AND nvl(cod_ente, nvl(v_cod_ente, -1)) = nvl(v_cod_ente, -1)
           AND nvl(cod_moneda,p_cod_moneda) = p_cod_moneda
           AND nro_cuenta is null
           AND c.cod_tasa = t.cod_tasa
           and c.cod_transaccion = P_COD_TRANSACCION
           AND nvl(c.cod_modulo, p_cod_modulo) = p_cod_modulo
           AND nvl(c.cod_modalidad, p_cod_modalidad) = p_cod_modalidad;
        v_encontro := 'S';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_encontro := 'N';
        WHEN TOO_MANY_ROWS THEN
          v_encontro := 'N';
      END;
    ELSE
      BEGIN
        --Tasas personalizadas
        select T.VAL_TASA, t.cod_tasa
          into P_VAL_TASA, P_COD_TASA
          from ge_tas_fechas t, ge_transacciones c
         WHERE nvl(t.cod_modulo, p_cod_modulo) = p_cod_modulo
           AND nvl(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
           AND nvl(t.cod_sub_modalidad, nvl(P_COD_SUB_MODALIDAD, -1)) = nvl(P_COD_SUB_MODALIDAD, -1)
           AND nvl(cod_oficina, p_cod_oficina) = p_cod_oficina
           AND nvl(cod_ente, nvl(v_cod_ente, -1)) = nvl(v_cod_ente, -1)
           AND nvl(cod_moneda,p_cod_moneda) = p_cod_moneda
           AND nro_cuenta = P_NRO_CUENTA
           AND c.cod_tasa = t.cod_tasa
           and c.cod_transaccion = P_COD_TRANSACCION
           AND nvl(c.cod_modulo, p_cod_modulo) = p_cod_modulo
           AND nvl(c.cod_modalidad, p_cod_modalidad) = p_cod_modalidad;
        v_encontro := 'S';
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_encontro := 'N';
        WHEN TOO_MANY_ROWS THEN
          v_encontro := 'N';
      END;
    END IF;
  ELSE--Caso contrario, se busca el valor de la tasa de interes
    BEGIN
       SELECT cod_tasa
         INTO p_cod_tasa
         FROM ge_transacciones
        WHERE cod_modulo      = p_cod_modulo
          AND cod_modalidad   = p_cod_modalidad
          AND cod_transaccion = p_cod_transaccion;
    EXCEPTION
          WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20001,'No existe tasa para la transaccion '||to_char(p_cod_transaccion)||'. '||SQLERRM);
    END;
    SELECT nvl(val_tasa,0)
       INTO P_VAL_TASA
       FROM ge_tas_fechas
      WHERE nvl(cod_modulo,p_cod_modulo)                       = p_cod_modulo
        AND nvl(cod_modalidad,p_cod_modalidad)                 = p_cod_modalidad
        AND nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
        AND nvl(cod_oficina,p_cod_oficina)                     = p_cod_oficina
        AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
        AND nvl(cod_moneda,p_cod_moneda)                       = p_cod_moneda
        AND cod_tasa                                           = p_cod_tasa
        AND nro_cuenta  IS NULL
        and cod_persona IS NULL
        and fec_vigencia                                      <= P_FEC_FINAL
    ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
            DECODE(COD_MODALIDAD, NULL, 0, 1) +
            DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;
  END IF;

  IF V_ENCONTRO = 'N' THEN
    DECLARE CURSOR fijas IS
       SELECT nvl(val_tasa,0)
         FROM ge_tas_fechas
        WHERE nvl(cod_modulo,p_cod_modulo)                       = p_cod_modulo
          AND nvl(cod_modalidad,p_cod_modalidad)                 = p_cod_modalidad
          AND nvl(cod_sub_modalidad,nvl(v_cod_sub_modalidad,-1)) = nvl(v_cod_sub_modalidad,-1)
          AND nvl(cod_oficina,p_cod_oficina)                     = p_cod_oficina
          AND nvl(cod_ente,nvl(v_cod_ente,-1))                   = nvl(v_cod_ente,-1)
          AND nvl(cod_moneda,p_cod_moneda)                       = p_cod_moneda
          AND cod_tasa                                           = p_cod_tasa
          AND nro_cuenta  IS NULL
          and cod_persona IS NULL
          and fec_vigencia                                      <= p_fec_final
     ORDER BY DECODE(COD_MODULO, NULL, 0, 1) +
              DECODE(COD_MODALIDAD, NULL, 0, 1) +
              DECODE(COD_SUB_MODALIDAD, NULL, 0, 1) DESC, fec_vigencia DESC;
      BEGIN
         IF fijas%isopen THEN
            CLOSE fijas;
         END IF;
         OPEN fijas;
            FETCH fijas INTO P_VAL_TASA;
         IF FIJAS%NOTFOUND THEN
            --No es un error propiamente, por eso se omite el SQLERRM (ORA-0000, Normal succesful completion)
            RAISE_APPLICATION_ERROR(-20006,'No se han recuperado datos para la Tasa '||TO_CHAR(p_cod_tasa)
                                            ||'- para '||p_cod_moneda);
         END IF;
         CLOSE FIJAS;
     END;
  END IF;
END LP_OBT_VAL_TASA;
FUNCTION LF_OBT_HOR_DISPONIBLE(p_fecha       in date,
                               p_hora        in varchar2,
                               p_cod_usuario in varchar2,
                               p_es_nocturno in varchar2)
return varchar2 is
  -- funcion para obtener la hora que no esté utilizado en movimientos
  v_existe varchar2(1);
  v_hora   varchar2(8) := p_hora;
  v_can_bus_hora number := 0;
  v_hor_agotada varchar2(1) := 'N';
  v_can_bus_por_hora number;
begin

  if p_es_nocturno = 'N' then
    loop
      v_can_bus_hora := v_can_bus_hora + 1;
      begin
        select 'S'
          into v_existe
          from ge_movimientos
         where fecha = p_fecha
           and hora = v_hora
           and cod_usuario = p_cod_usuario
           and rownum <= 1;
      exception
        when no_data_found then
          v_existe := 'N';
      end;
      exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      if v_can_bus_hora >= 85000 then
         v_hor_agotada := 'S';
      end if;
    end loop;
  else -- es nocturno
    loop
      v_can_bus_hora := v_can_bus_hora + 1;
      begin
        select 'S'
          into v_existe
          from ge_movimientos_noc
         where fecha = p_fecha
           and hora = v_hora
           and cod_usuario = p_cod_usuario
           and rownum <= 1;
      exception
        when no_data_found then
          v_existe := 'N';
      end;
      exit when ((v_existe = 'N') or (v_hor_agotada = 'S'));
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      if v_can_bus_hora >= 85000 then
         v_hor_agotada := 'S';
      end if;
    end loop;
  end if;
  if v_hor_agotada = 'S' then
    raise_application_error(-20000,'Error de Hora. No existe segundo disponible para el usuario');
  end if;
  return v_hora;
end;
FUNCTION LF_OBT_PARDINAMICO
 (P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE
 ,P_COD_MODULO IN NUMBER DEFAULT NULL
 ,P_COD_MODALIDAD IN NUMBER DEFAULT NULL
 ,P_COD_MONEDA IN VARCHAR2 DEFAULT NULL
 ,P_COD_OFICINA IN NUMBER  DEFAULT NULL
 ,P_COD_SUB_MODALIDAD IN varchar2 DEFAULT NULL
 )
 RETURN VARCHAR2
 IS
v_val_parametro ge_par_dinamicos.val_parametro%type;
cursor param is
   select /*+ RULE */ val_parametro
     from ge_par_dinamicos
    where nvl(cod_modulo,nvl(p_cod_modulo,-1)) = nvl(p_cod_modulo,-1)
      and nvl(cod_modalidad,nvl(p_cod_modalidad,-1)) = nvl(p_cod_modalidad,-1)
      and nvl(cod_sub_modalidad,nvl(p_cod_sub_modalidad,-1)) = nvl(p_cod_sub_modalidad,-1)
      and nvl(cod_oficina,nvl(p_cod_oficina,-1)) = nvl(p_cod_oficina,-1)
      and nvl(cod_moneda,nvl(p_cod_moneda,'x')) = nvl(p_cod_moneda,'x')
      and parametro = p_parametro
    order by decode(cod_modulo,null,0,1) +
             decode(cod_modalidad,null,0,1) +
             decode(cod_sub_modalidad,null,0,1) +
             decode(cod_oficina,null,0,1) +
             decode(cod_moneda,null,0,1) desc;  -- esto es para tomar en orden de importancia
BEGIN
   open param;
   fetch param into v_val_parametro;
   if param%notfound then
      close param;
      raise no_data_found;
   else
      close param;
   end if;
   return v_val_parametro;
   exception
      when no_data_found then
         return null;
/*         raise_application_error(-20000,
         'No existe valor p/parametro '||p_parametro);*/
END;
PROCEDURE LP_CAL_IMPUESTO
  (INTERES   IN     NUMBER,
   IMPUESTOS IN OUT NUMBER) IS
   v_val_exo_impuesto ge_movimientos.val_tasa%type;
BEGIN
  --v_IMTRANS  := TO_NUMBER(V_TT_SLDEUDO) + INTERES;
  v_imtrans := interes; -- solamente se calcula 5% sobre el interes
  v_VLTASA   := NULL;
  v_CDTASAS  := NULL;
  v_TPVLPOR  := NULL;
  LP_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                  v_nro_cuenta,v_cod_moneda,v_IMTRANS,v_tas_personalizada,
                  v_CDTASAS,523,v_fcdehoy,
                  -- OUT
                  v_VLTASA,V_COD_SUB_MODALIDAD);
  IF v_CDTASAS IS NOT NULL AND TO_NUMBER(v_CDTASAS) <> 0 AND TO_NUMBER(v_VLTASA) <> 0 THEN
     IF v_TPVLPOR = 'V' THEN
        RAISE_APPLICATION_ERROR(-20000,'ERROR. Tasa de impuestos de sobregiro no puede ser valor');
     ELSE
        IMPUESTOS := round((NVL(v_IMTRANS,0)* NVL(v_VLTASA,0))/ 100,v_redondeo);

        --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
        IMPUESTOS := pag_gen.FU_OBT_VAL_FINAL(IMPUESTOS);
     END IF;
  ELSE
     IMPUESTOS := 0;
  END IF;
  /*
  || PCC-Exoneración y Extorno de Comisiones y Tasas
  || Se ejecuta si el proceso no es mensual
  || o la base de datos no es producción
  */
  IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
     -- busco el valor de la tasa
     begin
        v_val_exo_impuesto := fug_obt_val_tasa(v_cod_modulo,
                                               v_cod_modalidad,
                                               v_cod_oficina,
                                               null,
                                               v_cod_moneda,
                                               0, 'N', NULL,
                                               523,
                                               V_FCDEHOY);
     exception
        when others then
           raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
     end;
     v_val_exo_impuesto := round((NVL(v_IMTRANS,0)* NVL(v_VLTASA,0))/ 100,v_redondeo);
     v_val_exo_impuesto := pag_gen.FU_OBT_VAL_FINAL(v_val_exo_impuesto);
     if pag_cta.fu_ver_tra_prohibida(v_nro_cuenta,
                                     523,
                                     v_cod_modulo,
                                     v_cod_modalidad) = 'S' then
        prg_ins_exoneracion(523, v_cod_modulo,
                            v_cod_modalidad, v_cod_moneda,
                            v_nro_cuenta, null, v_CDTASAS,
                            nvl(v_val_exo_impuesto, 0),
                            nvl(v_val_exo_impuesto, 0), null,
                            nvl(v_val_exo_impuesto, 0));
     elsif (nvl(IMPUESTOS, 0) <> nvl(v_val_exo_impuesto, 0)) or
           (nvl(IMPUESTOS, 0) = 0 and nvl(v_val_exo_impuesto, 0) <> 0) then
        prg_ins_exoneracion(523, v_cod_modulo,
                            v_cod_modalidad, v_cod_moneda,
                            v_nro_cuenta, null, v_CDTASAS,
                            (nvl(v_val_exo_impuesto, 0) - nvl(IMPUESTOS, 0)),
                             v_val_exo_impuesto, null,
                            (nvl(v_val_exo_impuesto, 0) - nvl(IMPUESTOS, 0)));
     end if;
  end if;
  ---
END;
PROCEDURE LP_GEN_MOV_INTERES IS
v_cdtranp number(5) := 319;
v_cnmovim varchar2(25) := 'Liq.Sobregiro. Interés';

BEGIN
 if v_cod_ente is not null then
    v_cdtranp := 327;
    v_cnmovim := 'Liq. de Anticipo.';
 end if;
--
 insert into ge_movimientos
 (cod_usuario, hora, nro_secuencia,
  cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
  cod_moneda, cod_tra_padre, cod_transaccion, fecha,
  fec_valor, monto, estado, cod_ofi_origen,
  cod_tasa, val_tasa, reversado, ge_movimientos.emi_aviso,
  protegido, cod_mod_padre, cod_mad_padre, nro_documento, cod_error,
  concepto)
 VALUES
 (v_usuario,  v_HORA,  v_NRSECUEN,
  4,  41, v_cod_oficina, p_nro_cuenta,
  v_cod_moneda,  v_CDTRANS,  v_CDTRANS,  v_fcdehoy,
  v_fcdehoy,TO_NUMBER(v_INTERES),v_ESMOVIM,
  v_cod_oficina, v_CDTASCA,  v_VLTASCA, 'N',  'N',
  'N'  , 4 , 41, v_NRDOCUM, v_CDERROR,
   v_cnmovim);

  -- RI-14/10/09 : Si el sobregiro está en gestion se graba con transaccion diferenciada (980)
  -- y se inserta en la tabla de cargos en suspenso
  If  v_cdtrans in (980,3980) then --en gestion
     -- Insertar en sobregiro en suspenso
    insert into cc_sob_suspenso
    (nro_cuenta,fecha,cod_modulo,cod_modalidad,cod_transaccion,monto)
    values
    (p_nro_cuenta,v_fcdehoy,4,41,v_cdtrans,to_number(v_interes));
    --- Actualizar en Cta.Cte. el monto en suspenso
    Update cc_sobregiros_res
       set mto_sob_suspenso = nvl(mto_sob_suspenso,0) + nvl(to_number(v_interes),0)
     where nro_cuenta = p_nro_cuenta;
  end if;

END;
PROCEDURE LP_LIM_VARIABLES IS
  BEGIN
   V_INTERES   := NULL;
   V_IMPUESTO  := NULL;
   V_IMTRANS   := 0;
END;
PROCEDURE LP_GEN_MOV_IMPUESTO IS
v_cdtranp number(5) := 319;
v_cnmovim varchar2(25) := 'Liq.Sobregiro. Impuesto';
BEGIN
if v_cod_ente is not null then
   v_cdtranp := 523;
   v_cnmovim := 'Liq. de IVA s/ Anticipo';
end if;
    insert into ge_movimientos
     (cod_usuario, hora, nro_secuencia,
      cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
      cod_moneda, cod_tra_padre, cod_transaccion, fecha,
      fec_valor, monto, estado, cod_ofi_origen,
      cod_tasa, val_tasa, reversado, ge_movimientos.emi_aviso,
      protegido, cod_mod_padre, cod_mad_padre, nro_documento, cod_error,
      concepto)
    VALUES
     (v_usuario,  v_HORA,  v_NRSECUEN,
      4,  41, v_cod_oficina, p_nro_cuenta,
      v_cod_moneda,  v_cdtranp,  523,  v_fcdehoy,
      v_fcdehoy,TO_NUMBER(v_impuesto),v_ESMOVIM,
      v_cod_oficina, v_cdtasas,  v_vltasa, 'N',  'N',
      'N'  , 4 , 41, v_NRDOCUM, v_CDERROR,
      v_cnmovim);
END;
PROCEDURE LP_ACT_SAL_MENSUALES(V_TOTAL IN NUMBER) IS
    DIAS NUMBER(2,0);
    wminpa NUMBER(18,2);
    wacsaldi NUMBER(18,2);
    wctdiast NUMBER(7);
    wsalinic NUMBER(18,2);
BEGIN
     IF v_cta_combinada = 'S' THEN
          BEGIN
           SELECT sal_minimo
             INTO wminpa
             FROM cc_cta_combinadas
            WHERE nro_cta_cte = p_nro_cuenta;
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
              RAISE_APPLICATION_ERROR(-20000,'No existe cta comb. ' || p_nro_cuenta);
          END;
          BEGIN
           SELECT sal_acu_diario, can_dia_acumulado, sal_ini_mes
             INTO wacsaldi, wctdiast, wsalinic
             FROM CC_SAL_MENSUALES
            WHERE cod_modulo    = v_cod_modulo
              AND cod_modalidad = v_cod_modalidad
              AND cod_oficina   = v_cod_oficina
              AND nro_cuenta    = p_nro_cuenta
              AND ano           = to_char(v_fcproxi,'YYYY')
              AND mes           = to_char(v_fcproxi,'MM');
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
              RAISE_APPLICATION_ERROR(-20000,'No existe en CC_SAL_MENSUALES ' ||p_nro_cuenta);
           END;
      END IF;
      -----------------------
     IF v_cta_combinada = 'N' OR
        (v_cta_combinada = 'S' AND nvl(wsalinic,0) < nvl(wminpa,0)) THEN
        UPDATE cc_sal_mensuales SET
              sal_ini_mes = nvl(sal_ini_mes,0) - nvl(v_total,0)
        WHERE cod_modulo    = 4
          AND cod_modalidad = 41
          AND cod_oficina   = v_cod_oficina
          AND nro_cuenta    = p_nro_cuenta
          AND ano           = to_char(v_fcproxi,'YYYY')
          AND mes           = to_char(v_fcproxi,'MM');
     END IF;
    ----------------------------------------------------------------------
     IF v_fcdehoy+1 <> v_FCPROXI and to_char(v_fcdehoy,'MM') <> to_char(v_fcproxi,'MM') THEN
      select decode(wctdiast,null,1,0,1,wctdiast) into wctdiast
      from dual;
      IF v_cta_combinada = 'N' OR (v_cta_combinada = 'S' AND
         nvl(wacsaldi,0)/wctdiast < nvl(wminpa,0)) THEN
        DIAS := TO_NUMBER(TO_CHAR(v_FCPROXI,'DD'))-1;
        -- ACTUALIZA VALORES SALDO ACUMULADO DEL MES --
        UPDATE cc_sal_mensuales
          SET sal_acu_diario = NVL(sal_acu_diario,0) - DIAS* NVL(V_TOTAL,0)
              ---------------------------------------------------------
              -- sacado por J.M el 02-03-94, porque mas arriba ya se --
              -- descontaba                                          --
              -- ,SM_SALINIC  = NVL(SM_SALINIC,0) - NVL(WTOTAL,0)    --
              ---------------------------------------------------------
        WHERE cod_modulo    = 4
          AND cod_modalidad = 41
          AND cod_oficina   = v_cod_oficina
          AND nro_cuenta    = p_nro_cuenta
          AND ano           = to_char(v_fcproxi,'YYYY')
          AND mes           = to_char(v_fcproxi,'MM');
    --
        IF SQL%NOTFOUND THEN
           RAISE_APPLICATION_ERROR(-20000,'No se encontro reg. de mes prox.en CC_SAL_MENSUALES 1 p/'||p_nro_cuenta);
        END IF;
        -- SALDOS DEUDORES --
        ------------------------------------------------------------
        UPDATE cc_sal_mensuales
          SET sal_acu_deudor = NVL(sal_acu_deudor,0) + DIAS* NVL(v_TOTAL,0)
        WHERE cod_modulo    = 4
          AND cod_modalidad = 41
          AND cod_oficina   = v_cod_oficina
          AND nro_cuenta    = p_nro_cuenta
          AND ano           = to_char(v_fcproxi,'YYYY')
          AND mes           = to_char(v_fcproxi,'MM')
          AND NVL(sal_acu_deudor,0) <> 0;
        ------------------------------------------------------------
        -- el bloque de 'saldos acreedores (<0)' paso antes que   --
        -- 'saldos acreedores (>0)' el 02-03-94 por J.M.
        -- SALDOS ACREEDORES -- menor a cero
        ------------------------------------------------------------
        UPDATE cc_sal_mensuales
          SET sal_acu_acreedor = 0,
              sal_acu_deudor = NVL(sal_acu_acreedor,0) - DIAS* NVL(V_TOTAL,0)
        WHERE cod_modulo    = 4
          AND cod_modalidad = 41
          AND cod_oficina   = v_cod_oficina
          AND nro_cuenta    = p_nro_cuenta
          AND ano           = to_char(v_fcproxi,'YYYY')
          AND mes           = to_char(v_fcproxi,'MM')
          AND NVL(sal_acu_acreedor,0) <> 0
          AND NVL(sal_acu_acreedor,0) - dias * nvl(v_total,0) < 0;
    --
        -- SALDOS ACREEDORES -- mayor a cero
        ------------------------------------------------------------
        UPDATE cc_sal_mensuales
          SET sal_acu_acreedor = NVL(sal_acu_acreedor,0) - DIAS* NVL(V_TOTAL,0)
        WHERE cod_modulo    = 4
          AND cod_modalidad = 41
          AND cod_oficina   = v_cod_oficina
          AND nro_cuenta    = p_nro_cuenta
          AND ano           = to_char(v_fcproxi,'YYYY')
          AND mes           = to_char(v_fcproxi,'MM')
          AND NVL(sal_acu_acreedor,0) <> 0
          AND NVL(sal_acu_acreedor,0) - dias * nvl(v_total,0) >= 0;
      END IF;
    END IF;
END;
PROCEDURE LP_GEN_MOVIMIENTO IS
BEGIN
    -- Redondear valores
    v_INTERES := ROUND(v_INTERES, v_redondeo);
    v_IMPUESTO := ROUND(v_IMPUESTO, v_redondeo);

    -- Incrementar número de documento
    v_nrdocum := TO_NUMBER(v_nrdocum) + 1;

    -- Inicializar secuencia
    v_NRSECUEN := NVL(pae_cnf.G_NRO_SECUENCIA, 0);

    -- Manejo de secuencia si excede el límite
    IF v_NRSECUEN + 3 > 999 THEN
        v_NRSECUEN := 0;
        pae_cnf.PR_SET_VARIABLES(v_hora, v_NRSECUEN);
    END IF;

    -- Actualización de cuentas corrientes
    IF v_ESMOVIM = 'N' AND v_MAYOR30 = 'N' THEN
        UPDATE cc_cta_corrientes
           SET sal_total = NVL(sal_total, 0) - NVL(v_INTERES, 0) - NVL(v_IMPUESTO, 0),
               fec_ult_movimiento = v_fcdehoy,
               hor_ult_movimiento = v_hora
         WHERE cod_modulo = 4
           AND cod_modalidad = 41
           AND cod_oficina = TO_NUMBER(v_cod_oficina)
           AND nro_cuenta = v_nro_cuenta;
    END IF;

    -- Generación de movimientos si es menor a 30 días
    IF v_MAYOR30 = 'N' THEN
        v_NRSECUEN := v_NRSECUEN + 1;
        v_usuario  := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
        v_hora     := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');

        -- Determinar tipo de transacción según estado del sobregiro
        IF FU_SIT_SOBREGIRO(v_nro_cuenta) NOT IN ('S', 'V') THEN
            v_CDTRANS := CASE WHEN v_cod_ente IS NOT NULL THEN 3980 ELSE 980 END;
        ELSE
            v_CDTRANS := CASE WHEN v_cod_ente IS NOT NULL THEN 3550 ELSE 550 END;
        END IF;

        -- Generar movimientos de interés e impuesto
        LP_GEN_MOV_INTERES;
        v_INTERES_CONACU := 0;
        v_INTERES_SINACU := 0;

        IF v_IMPUESTO > 0 THEN
            v_NRSECUEN := v_NRSECUEN + 1;
            LP_GEN_MOV_IMPUESTO;
        END IF;

        -- Actualizar saldos mensuales si corresponde
        v_TOTAL := v_INTERES + v_IMPUESTO;

        IF v_ESMOVIM = 'N' AND v_manual = 'N' THEN
            LP_ACT_SAL_MENSUALES(v_TOTAL);
        END IF;
    ELSE
        -- Inserción de gastos para casos mayores a 30 días
        INSERT INTO CC_SOB_GASTOS(cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre, cod_transaccion, monto, fecha)
             VALUES(v_cod_modulo, v_cod_modalidad, v_nro_cuenta, 319, 550, v_INTERES, v_fcdehoy);

        INSERT INTO CC_SOB_GASTOS(cod_modulo, cod_modalidad, nro_cuenta, cod_tra_padre, cod_transaccion, monto, fecha)
             VALUES(v_cod_modulo, v_cod_modalidad, v_nro_cuenta, 319, 523, v_IMPUESTO, v_fcdehoy);
    END IF;

    -- Actualizar variables de secuencia
    pae_cnf.PR_SET_VARIABLES(pae_cnf.g_hora, v_NRSECUEN);
END;
PROCEDURE LP_ACT_SOBREGIROS IS
  DIAS NUMBER (2,0);
  I NUMBER;
  acuerdo    number(1);
  importe    number(16,2);
  v_sal_total number(18,2);
  v_sal_retenido number(18,2);
BEGIN
    -- redondea el impuesto y el interes --
    ---------------------------------------
    IF V_ESMOVIM = 'N' THEN
      --bbvades-3200
      UPDATE cc_sobregiros
         SET generado = 'S'
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha <= v_ULTDIAM
         AND generado = 'N';
      select sal_total, sal_retenido
        into v_sal_total, v_sal_retenido
        from cc_cta_corrientes
       where nro_cuenta = p_nro_cuenta;
      IF (NVL(v_sal_total,0) - NVL(v_sal_retenido,0)) -
         (TO_NUMBER(v_IMPUESTO)+TO_NUMBER(v_INTERES))<0 THEN
       -- quiere decir que esta en sobregiro
       ----------------------------------------------------
        IF v_fcdehoy+1 <> v_FCPROXI AND
           TO_CHAR(v_fcdehoy,'MM') <> TO_CHAR(v_FCPROXI,'MM') THEN
        --- voy a actualizar los saldos desde 1 del mes sgte. -----
          DIAS := (TO_NUMBER(TO_CHAR(v_FCPROXI,'DD'))) -1;
          IF  DIAS > 30 THEN
            v_MAYOR30 := 'S';
          ELSE
          v_MAYOR30 := 'N';
        END IF;
        IF NVL(v_sal_total,0) - NVL(v_sal_retenido,0) < 0 THEN
           FOR I IN 1..DIAS LOOP
              UPDATE cc_sobregiros SET saldo = NVL(saldo,0) +
                                               TO_NUMBER(v_IMPUESTO) +
                                               TO_NUMBER(v_INTERES)
              WHERE NRO_CUENTA = P_NRO_CUENTA
                AND FECHA = (V_ULTDIAM + I);
           END LOOP;
        ELSE
           FOR I IN 1..DIAS LOOP
              INSERT INTO cc_sobregiros
               (nro_cuenta,fecha,saldo,liquidado)
              VALUES
               (p_nro_cuenta,(v_ULTDIAM + I),
                 (NVL(v_sal_total,0) - NVL(v_sal_retenido,0) -
                 (TO_NUMBER(v_IMPUESTO)+
                  TO_NUMBER(v_INTERES)))*-1,'N');
           END LOOP;
        END IF;
      END IF;
    END IF;
  END IF;     -- fin de si estado movimiento normal
END;
PROCEDURE LP_VAL_CUENTA(p_CUENTA  IN OUT varchar2   ) IS
v_DUMMY VARCHAR2(15);
BEGIN
    BEGIN
       SELECT nro_cuenta
         INTO v_DUMMY
         FROM cc_cta_corrientes
        WHERE  cod_oficina = v_cod_oficina
          AND nro_cuenta = P_CUENTA;
       IF v_estado IN ('D', 'T', 'C') THEN
         v_ESMOVIM := 'E';
         v_CDERROR := 'CTA.INOP.';
       ELSE
          v_CDERROR := NULL;
          v_ESMOVIM := 'N';
       END IF;
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          RAISE_APPLICATION_ERROR(-20000,'Cuenta '||rtrim(p_cuenta)||' no existe en Cuentas Corrientes');
       WHEN TOO_MANY_ROWS THEN
          RAISE_APPLICATION_ERROR(-20000,'Varios registro para la cuenta '||rtrim(p_CUENTA)||' en Cuentas Corrientes');
    END;
END;
PROCEDURE LP_VAL_TRA_PROHIBIDA(procesa IN OUT VARCHAR2) IS
  V_OK VARCHAR2(01):='S';
  EXIMIR VARCHAR2(01):='S';
BEGIN
    IF v_tra_prohibida = 'S' THEN
       v_ok := PAG_CTA.FU_VER_TRA_PROHIBIDA(p_nro_cuenta, 550);
       IF V_OK = 'S' THEN--TIENE TRANSACCION PROHIBIDA, NO SE PROCESA
          procesa:='N';
       END IF;
    END IF;
END;
FUNCTION lf_DIAS_PREFERENCIALES (p_fecha IN DATE, p_diaspref IN NUMBER)
RETURN VARCHAR2 IS
W_SINO VARCHAR2(01) := 'N';
W_DIASSOB NUMBER(9) := 0;
BEGIN
     SELECT COUNT(*) INTO W_DIASSOB
       FROM cc_sobregiros
      WHERE nro_cuenta = p_nro_cuenta
        AND fecha <= p_fecha
        AND fecha >= p_fecha - p_diaspref;
     IF p_diaspref >= W_DIASSOB THEN
        W_SINO := 'S';
     ELSE
        W_SINO := 'N';
     END IF;
     RETURN W_SINO;
EXCEPTION
 WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. En dias_prefenciales '||sqlerrm);
    RETURN ('N');
END;
PROCEDURE LP_CAL_INTERES (P_CDTASAS IN NUMBER, P_IMPORTE IN NUMBER, P_INTERES IN OUT NUMBER) IS
   --WOK VARCHAR2(1);
   ---
   v_val_exo_cargo    ge_movimientos.val_tasa%type;
BEGIN
  V_VLTASA  := NULL;
  V_CDTASAS  := P_CDTASAS;
  V_TPVLPOR  := NULL;
  LP_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                  p_nro_cuenta,v_cod_moneda,p_importe,v_tas_personalizada,
                  v_CDTASAS,550,v_fcdehoy,
                  -- OUT
                  v_VLTASA,V_COD_SUB_MODALIDAD);
  IF v_CDTASAS IS NOT NULL AND TO_NUMBER(v_CDTASAS) <> 0
     AND TO_NUMBER(V_VLTASA) <> 0 THEN
     IF v_TPVLPOR = 'V' THEN
        P_INTERES := NVL(V_VLTASA,0);
     ELSE
        P_INTERES := round((NVL(p_importe,0)*
                      NVL(V_VLTASA,0))/36500,v_redondeo);

        --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
        P_INTERES := pag_gen.FU_OBT_VAL_FINAL(P_INTERES);
     END IF;
     V_CDTASCA := V_CDTASAS;
     V_CDTRANC := V_CDTRANS;
     V_VLTASCA := V_VLTASA;
  ELSE
     P_INTERES := 0;
  END IF;
  -----
  -- Transaccion es de moneda local
--  IF v_cod_moneda = v_monloc THEN
  P_INTERES   := ROUND(NVL(P_INTERES,0),v_redondeo);
  /*
  || PCC-Exoneración y Extorno de Comisiones y Tasas
  || Se ejecuta si el proceso no es mensual
  || o la base de datos no es producción
  */
  IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
     -- busco el valor de la tasa
     begin
        v_val_exo_cargo := fug_obt_val_tasa(v_cod_modulo,
                                            v_cod_modalidad,
                                            v_cod_oficina,
                                            null,
                                            v_cod_moneda,
                                            0, 'N', NULL,
                                            550,
                                            V_FCDEHOY);
     exception
        when others then
           raise_application_error(-20000,'Al Obt.Val.Tasa:'||sqlerrm);
     end;
     IF v_TPVLPOR = 'V' THEN
        v_val_exo_cargo := NVL(V_VLTASA,0);
     ELSE
        v_val_exo_cargo := round((NVL(p_importe,0)*
                          NVL(V_VLTASA,0))/36500,v_redondeo);
        --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
        v_val_exo_cargo := pag_gen.FU_OBT_VAL_FINAL(v_val_exo_cargo);
     END IF;
     if pag_cta.fu_ver_tra_prohibida(p_nro_cuenta,
                                     550,
                                     v_cod_modulo,
                                     v_cod_modalidad) = 'S' then
        prg_ins_exoneracion(550, v_cod_modulo,
                            v_cod_modalidad, v_cod_moneda,
                            p_nro_cuenta, null, v_CDTASAS,
                            nvl(v_val_exo_cargo, 0),
                            nvl(v_val_exo_cargo, 0), null,
                            nvl(v_val_exo_cargo, 0));
     elsif (nvl(P_INTERES, 0) <> nvl(v_val_exo_cargo, 0)) or
           (nvl(P_INTERES, 0) = 0 and nvl(v_val_exo_cargo, 0) <> 0)then
        prg_ins_exoneracion(550, v_cod_modulo,
                            v_cod_modalidad, v_cod_moneda,
                            p_nro_cuenta, null, v_CDTASAS,
                            (nvl(v_val_exo_cargo, 0) - nvl(P_INTERES, 0)),
                             v_val_exo_cargo, null,
                            (nvl(v_val_exo_cargo, 0) - nvl(P_INTERES, 0)));
     end if;
  end if;
  ---
 /* ELSE
     P_INTERES  := NVL(P_INTERES,0);
  END IF;*/
END;
PROCEDURE LP_PRO_ACU_SOB(p_fecha IN DATE,
                         p_saldo IN NUMBER,
                         p_tot_linea in number,
                         p_lin_transitoria in number) IS
--cursor de línea de sobregiro para ver si tiene tasa para la liquidación, valor de tasa,
--tasa preferencial, YA NO SE USA
CURSOR ACUERDO_SG IS
    SELECT cod_tasa, val_tas_interes,monto,
            NVL(dia_tasa,0) dia_tasa, nvl(tas_preferencial,0) tas_preferencial ,tipo
      FROM cc_lin_sobregiros
     WHERE nro_cuenta = p_nro_cuenta
       AND fec_inicio <= p_fecha
       AND fec_vencimiento >= p_fecha
       and estado = 'A'
     ORDER BY tipo, fec_inicio;
    VLACUER     NUMBER(18,2) :=0;
    VLTASA      NUMBER(18,2) :=0;
    SUM_VLACUER NUMBER(18,2) :=0;
    SAL_GRAL    NUMBER(18,2) :=0;
    SAL_ACUE    NUMBER(18,2) :=0;
    WSALDO      NUMBER(18,2) :=0;
    INTER_CALC  NUMBER       :=0;
    WINTE_GRAL  NUMBER(18,2) :=0;
    DIASGPR     NUMBER(9)    :=0;
    TASSGPR     NUMBER(8,2)  :=0;
    TPACUER     VARCHAR2(01) := NULL;
    v_ant_sueldo NUMBER(18,2) := 0;
    v_ant_aguinaldo NUMBER(18,2) := 0;
    v_int_ant_sueldo NUMBER(18,2) := 0;
    v_int_ant_aguinaldo NUMBER(18,2) := 0;
BEGIN
    v_SLDEUDO := 0;
    --- busca el total de acuerdo de sobregiro de la cuenta EN LAS LINEAS---
   /* SELECT SUM(monto) INTO SUM_VLACUER
      FROM cc_lin_sobregiros
     WHERE nro_cuenta = p_nro_cuenta
       AND fec_inicio <= p_fecha
       AND fec_vencimiento >= p_fecha
       AND estado = 'A';
    -----------------------------------------------------------
    IF NVL(SUM_VLACUER,0)= 0 THEN*/
    SAL_GRAL := p_saldo;
   /*    SAL_ACUE := 0;
    ELSIF SUM_VLACUER < p_saldo THEN
       SAL_GRAL := p_saldo - SUM_VLACUER; -- calculo a tasas generales
       SAL_ACUE := SUM_VLACUER;           -- calculo a tasas de acuerdo
    ELSE
       SAL_GRAL := 0;
       SAL_ACUE := p_saldo;
    END IF;
    v_SLDEUDO := p_saldo;
    WSALDO := SAL_ACUE;
    IF ACUERDO_SG%ISOPEN THEN
       CLOSE ACUERDO_SG;
    END IF;
    OPEN ACUERDO_SG;
    LOOP
      FETCH ACUERDO_SG  INTO v_CDTASCA,v_VLTASCA, VLACUER,
                             DIASGPR, TASSGPR, TPACUER;
      EXIT WHEN ACUERDO_SG%NOTFOUND;
      If DIASGPR = 0 then
        DIASGPR := fug_obt_pardinamico('DIA_TASA', v_cod_modulo,v_cod_modalidad, v_cod_moneda,
                                         v_cod_oficina);
      End if;
      If TASSGPR = 0 then
        TASSGPR := fug_obt_pardinamico('TAS_PREFERENCIAL',v_cod_modulo,v_cod_modalidad,
                                        v_cod_moneda,v_cod_oficina);
      End if;
      VLTASA := v_VLTASCA;
      IF TPACUER = 'P' THEN \* lineas permanentes de sobregiro *\
        -- Verifico si tiene tasa peferencial por dias en sobregiro ---
        IF lf_DIAS_PREFERENCIALES(p_fecha,DIASGPR) = 'S' THEN
           VLTASA := TASSGPR;
        END IF;
        ---------------------------------------------------------------
      END IF;
      IF WSALDO > VLACUER THEN
         INTER_CALC := NVL(VLACUER,0) * NVL(VLTASA,0)/36500;
         v_INTERES_CONACU := TO_NUMBER(V_INTERES_CONACU) +
                                   NVL(INTER_CALC,0);
         WSALDO := WSALDO - VLACUER;
      ELSE
         INTER_CALC := (NVL(WSALDO,0) * NVL(VLTASA,0))/36500;
         v_INTERES_CONACU := TO_NUMBER(V_INTERES_CONACU) +
                                   NVL(INTER_CALC,0);
         EXIT;
      END IF;
    END LOOP;
    CLOSE ACUERDO_SG;*/
    IF v_cod_ente is not null then
       v_ant_sueldo := 0;
       v_ant_aguinaldo := 0;
       v_int_ant_sueldo := 0;
       v_int_ant_aguinaldo := 0;
       -- es plan sueldo
       if sal_gral >= p_lin_transitoria then
          -- utilizo su linea transiroria o de sueldos
          v_ant_sueldo := p_lin_transitoria;
          sal_gral := sal_gral - nvl(p_lin_transitoria,0);
       else
         v_ant_sueldo := sal_gral;
         sal_gral     := 0;
       end if;
       if sal_gral >= nvl(p_tot_linea,0) - nvl(p_lin_transitoria,0) then
          v_ant_aguinaldo := nvl(p_tot_linea,0) - nvl(p_lin_transitoria,0);
          sal_gral := sal_gral - nvl(p_tot_linea,0) - nvl(p_lin_transitoria,0);
       else
          v_ant_aguinaldo := sal_gral;
          v_ant_aguinaldo := 0;
       end if;
       if nvl(v_ant_sueldo,0)>= 0 then
          v_cdtasas := fug_obt_parentes(v_cod_ente,'TAS_ANT_SUELDO');
          LP_CAL_INTERES(v_cdtasas, v_ant_sueldo, v_int_ant_sueldo);
       end if;
       if nvl(v_ant_aguinaldo,0)>= 0 then
          v_cdtasas := fug_obt_parentes(v_cod_ente,'TAS_ANT_AGUINALDO');
          LP_CAL_INTERES(v_cdtasas, v_ant_aguinaldo, v_int_ant_aguinaldo);
       end if;
       v_INTERES_SINACU := TO_NUMBER(v_INTERES_SINACU) + nvl(v_int_ant_sueldo,0) + nvl(v_int_ant_aguinaldo,0);
       v_tot_int_ant_sueldo :=  nvl(v_tot_int_ant_sueldo,0) + nvl(v_int_ant_sueldo,0);
       v_tot_int_ant_aguinaldo := nvl(v_tot_int_ant_aguinaldo,0) + nvl(v_int_ant_aguinaldo,0);

    end if;
    IF NVL(SAL_GRAL,0) > 0 THEN
       LP_CAL_INTERES(null,SAL_GRAL,WINTE_GRAL); -- calculo tasa gral.
       v_INTERES_SINACU := TO_NUMBER(v_INTERES_SINACU) +
                                 NVL(WINTE_GRAL,0);
    END IF;
END;
BEGIN
    -- Inicialización de parámetros y configuración
    BEGIN
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
    END;

    -- Configuración manual
    IF p_manual IS NOT NULL THEN
       v_manual := 'S';
    END IF;

   -- Cantidad de usuarios
   BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
       WHERE dominio     = 'USU_MOV_CIERRE'
         AND abreviatura = 'MOVCIERRE';
     EXCEPTION
       WHEN OTHERS THEN
         NULL;
   END;

    -- Inicialización de variables de fecha y usuario
    rv_gcale  := pag_cal.fu_obt_reg_cal(4);
    v_fcdehoy := rv_gcale.fec_actual;
    v_FCPROXI := rv_gcale.fec_proxima;
    v_ULTDIAM := rv_gcale.ult_dia_mes;
    v_usuario := SUBSTR(UPPER(USER), 1, 10);

    -- Inicialización de otras variables
    v_cod_ente := NULL;
    v_nrdocum  := 0;
    v_no_corte := 0;
    v_corte := 0;
    v_genera := 0;
    v_procesa := 0;
    v_mayor30 := 'N';
    v_interes_conacu := 0;
    v_interes_sinacu := 0;
    v_tt_sldeudo := 0;
    v_tot_int_ant_sueldo := 0;
    v_tot_int_ant_aguinaldo := 0;
    v_nro_cta_ant := NULL;
    LP_LIM_VARIABLES;
    -- Cargar datos en la colección en bulk
    OPEN SALDO_DEU;
    FETCH SALDO_DEU BULK COLLECT INTO saldo_deu_data;
    CLOSE SALDO_DEU;
    -- Procesamiento de cada registro cargado en la colección
    FOR i IN saldo_deu_data.FIRST .. saldo_deu_data.LAST LOOP
        -- Asignación de valores de la colección a variables locales
        v_nro_cuenta := saldo_deu_data(i).nro_cuenta;
        v_fecha := saldo_deu_data(i).fecha;
        v_saldo := saldo_deu_data(i).saldo;
        v_tot_linea := saldo_deu_data(i).mto_linea;
        v_mto_lin_transitoria := saldo_deu_data(i).mto_lin_transitoria;
        v_cod_modulo := saldo_deu_data(i).cod_modulo;
        v_cod_modalidad := saldo_deu_data(i).cod_modalidad;
        v_cod_oficina := saldo_deu_data(i).cod_oficina;
        v_cod_moneda := saldo_deu_data(i).cod_moneda;
        v_tas_personalizada := saldo_deu_data(i).tas_personalizada;
        v_cod_ente := saldo_deu_data(i).cod_ente;
        v_estado := saldo_deu_data(i).estado;
        v_tra_prohibida := saldo_deu_data(i).tra_prohibida;
        v_cta_combinada := saldo_deu_data(i).cta_combinada;
        v_cod_sub_modalidad := saldo_deu_data(i).cod_sub_modalidad;
        if v_cod_moneda = v_cod_mon_local then
          v_redondeo := 0;
        else
          v_redondeo := lf_obt_pardinamico('VAL_RED_MON_EXTRANJERA',V_cod_modulo,V_cod_modalidad,V_COD_MONEDA);
        end if;
        -- Corte de control al cambiar el número de cuenta
        IF v_nro_cuenta <> v_nro_cta_ant OR v_nro_cta_ant IS NULL THEN
            IF v_PRIMERA = 'N' THEN
                IF v_PROCESAR = 'S' THEN
                    v_INTERES := NVL(TO_NUMBER(v_INTERES_CONACU) + TO_NUMBER(v_INTERES_SINACU), 0);
                    v_INTERES := fuc_obt_val_max_tae(v_nro_cuenta, v_cod_modulo, v_cod_modalidad, 550, v_INTERES);

                    LP_CAL_IMPUESTO(v_INTERES, v_IMPUESTOS);
                    v_IMPUESTO := v_IMPUESTOS;

                    IF p_procesar = 'S' AND v_INTERES > 0 THEN
                        LP_ACT_SOBREGIROS;
                        LP_GEN_MOVIMIENTO;
                    END IF;
                    -- Realizar UPDATE solo si se requiere generar el registro
                    IF p_procesar = 'S' THEN
                      UPDATE cc_sobregiros
                         SET generado = 'S'
                       WHERE nro_cuenta = v_nro_cuenta
                         AND fecha <= v_ULTDIAM
                         AND generado = 'N';
                    END IF;
                END IF;
            END IF;
            -- Reiniciar variables para el siguiente ciclo
            v_PRIMERA := 'N';
            v_PROCESAR := 'S';
            v_nro_cta_ant := v_nro_cuenta;
            LP_LIM_VARIABLES;
            LP_VAL_CUENTA(v_nro_cuenta);
            LP_VAL_TRA_PROHIBIDA(v_PROCESAR);
        ELSE
            v_no_corte := v_no_corte + 1;
        END IF;
        -- Procesamiento de acumulación de sobregiros
        IF v_PROCESAR = 'S' THEN
            v_procesa := v_procesa + 1;
            LP_PRO_ACU_SOB(v_fecha, v_saldo, v_tot_linea, v_mto_lin_transitoria);
            v_TT_SLDEUDO := v_TT_SLDEUDO + v_saldo;
        ELSE
            v_interes := 0;
            v_impuesto := 0;
            v_tot_int_ant_sueldo := 0;
            v_tot_int_ant_aguinaldo := 0;
        END IF;
        -- Lógica para procesar el último registro
        IF i = saldo_deu_data.LAST THEN
            IF v_PROCESAR = 'S' THEN
                v_INTERES := NVL(TO_NUMBER(v_INTERES_CONACU) + TO_NUMBER(v_INTERES_SINACU), 0);
                v_INTERES := fuc_obt_val_max_tae(v_nro_cuenta, v_cod_modulo, v_cod_modalidad, 550, v_INTERES);
                LP_CAL_IMPUESTO(v_INTERES, v_IMPUESTOS);
                v_IMPUESTO := v_IMPUESTOS;
                IF p_procesar = 'S' AND v_INTERES > 0 THEN
                    LP_ACT_SOBREGIROS;
                    LP_GEN_MOVIMIENTO;
                END IF;

                -- Realizar el UPDATE para el último registro
                IF p_procesar = 'S' THEN
                  UPDATE cc_sobregiros
                     SET generado = 'S'
                   WHERE nro_cuenta = v_nro_cuenta
                     AND fecha <= v_ULTDIAM
                     AND generado = 'N';
                END IF;
            END IF;
        END IF;
    END LOOP;
    -- Asignación de resultados a las variables de salida
    p_interes := v_interes;
    p_impuesto := v_impuesto;
END;
/* Debita por el uso de x dias de linea de sobregiro */
FUNCTION FU_UTI_LINEA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER
 IS
  v_fcdehoy ge_calendarios.fec_actual%type;
  v_fcfinal ge_calendarios.fec_actual%type;
  v_fcproxi ge_calendarios.fec_proxima%type;
  RV_GCALE GE_CALENDARIOS%ROWTYPE;
  v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;


---
-- Obtiene todas las cuentas corrientes que se encuentren en estado distintos a
-- Cancelada
-- Pendiente de Cancelacion
-- Abierta Falta Depositar
-- Totalmente Bloqueada
-- Bloqueo de Debito
--
-- ##Y que no corresponda a las bancas: Corporativa, UR, Mercado Capitales, Funcionarios,
-- ##Privada, e Institucional.
-- RI 20/10/09 : Se cambia la condicion, ahora solo se procesara este cargo para las
-- cuentas de Nomina (Plan sueldo)
-- Si se envia nulo el numero de cuenta, hace para todas las cuentas que cumplen con la condicion.
--
  CURSOR cte IS
    select cc.*
      from cc_cta_corrientes cc,cc_sobregiros_res s
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.nro_cuenta = s.nro_cuenta(+)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.cod_ente is not null -- solo para los que son PLAN SUELDOS
       and s.can_dias < nvl((select a.val_parametro
                               from ge_par_dinamicos a
                              where a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                                and a.cod_modulo = cc.cod_modulo
                                and a.cod_modalidad = cc.cod_modalidad
                                and a.cod_moneda = cc.cod_moneda
                                and a.cod_oficina = cc.cod_oficina),9999)
       and cc.fec_apertura <= v_fcdehoy
       and exists
           (select 'S'
              from cc_sobregiros ccs
         where ccs.nro_cuenta = cc.nro_cuenta
         and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
         and trunc(v_fcdehoy)
         and nvl(ccs.mto_linea,0) <> 0
         and liquidado = 'N' )
    for update of cc.estado;
  r_cte cte%rowtype;
--
  v_nrsecue ge_movimientos.nro_secuencia%type;
  v_hrmovim ge_movimientos.hora%type;
  v_imdebit ge_movimientos.monto%type :=  0;
  v_esproce ba_modulos.estado%type;
  r_gmovi   GE_MOVIMIENTOS%ROWTYPE;

  v_cod_tra_cargo number(4);--Transaccion para el cobro de cargos
  v_cod_tas_cargo number(4);
  v_val_tas_cargo number(18,4);
  v_val_cargo number(18,2);
  v_val_max_tae   number;
  v_cod_tra_impuesto number(4);
  v_cod_tas_impuesto number(4);
  v_val_tas_impuesto number(18,4);
  v_val_impuesto number(18,2);
  v_can_decimales number; --Para el redondeo, recalculo impuesto TAE
  v_rowcount PLS_INTEGER := 0;
  v_mensaje varchar2(3000);
  v_cant_registros PLS_INTEGER := 0;
BEGIN
  -- Verifica el estado del modulo para acumular o no
  v_esproce := pae_cnf.fu_obt_est_modulo(4);
  --v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_fcdehoy := rv_gcale.fec_actual;
  v_FCPROXI := rv_gcale.fec_proxima;
  v_hrmovim := to_char(sysdate,'HH24:MI:SS');
  v_hrmovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_hrmovim);
  v_hrmovim := fu_obt_hor_disponible(v_fcdehoy,v_hrmovim,user,'N');
  --v_hrmovim := fug_ini_hora(sysdate,'HH24:MI:SS');
  DBMS_APPLICATION_INFO.SET_ACTION('PRC_LIQ_CAR_SOBREGIROS');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PRC_LIQ_CAR_SOBREGIROS ejecutando PAC_SOB.FU_UTI_LINEA');
  --Recuperamos la cantidad total
  BEGIN
    select count(0)
      into v_cant_registros
      from cc_cta_corrientes cc,cc_sobregiros_res s
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.nro_cuenta = s.nro_cuenta(+)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.cod_ente is not null -- solo para los que son PLAN SUELDOS
       and s.can_dias < nvl((select a.val_parametro
                               from ge_par_dinamicos a
                              where a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                                and a.cod_modulo = cc.cod_modulo
                                and a.cod_modalidad = cc.cod_modalidad
                                and a.cod_moneda = cc.cod_moneda
                                and a.cod_oficina = cc.cod_oficina),9999)
       and cc.fec_apertura <= v_fcdehoy
       and exists
           (select 'S'
              from cc_sobregiros ccs
         where ccs.nro_cuenta = cc.nro_cuenta
         and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
         and trunc(v_fcdehoy)
         and nvl(ccs.mto_linea,0) <> 0
         and liquidado = 'N' );
  EXCEPTION
    WHEN OTHERS THEN
      v_cant_registros := 0;
  END;
  v_nrsecue := 0;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;
/* RI : 20/10/09 : Se modifica para el BANCO, solo se cobrar este cargo para las cuentas
 de Nomina que hayan utilizado linea
    -- se ve si la cuenta algun dia del mes se sobregiro sin linea, si es asi se le cobra
    -- un monto y sino otro monto
    Begin
        Select 787 -- sobregiro sin autorizacion
          into v_cod_tra_cargo
          from cc_sobregiros ccs
         where ccs.nro_cuenta          = r_cte.nro_cuenta
           and ccs.fecha between TO_DATE('01'||to_char(v_fcdehoy, 'MMYYYY'),'DDMMYYYY')
           and trunc(v_fcdehoy)
           and ccs.mto_linea = 0
           and rownum = 1;
    Exception
       When NO_DATA_FOUND Then
            v_cod_tra_cargo := 786; -- autorizado
       When TOO_MANY_ROWS Then
            v_cod_tra_cargo := 787; -- sin linea
    End;*/
    v_rowcount := v_rowcount + 1;
    -- Solo entra aquí cada 10,000 registros
    IF MOD(v_rowcount, 10000) = 0 THEN
      v_mensaje := v_rowcount||' cuentas procesadas de '||v_cant_registros;
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO(v_mensaje);
    END IF;

    if FU_SIT_SOBREGIRO(r_cte.nro_cuenta) not in('S','V') then  -- En gestion, mayor a 60 dias
      v_cod_tra_cargo := 787;  -- para los que estan en gestion
    else
      v_cod_tra_cargo := 786;  -- si no esta en gestion
    End if;
    -- Cero los valores para asegurar
    v_imdebit := 0;
    v_val_cargo := 0;
    v_val_impuesto := 0;
    -- obtengo el cargo y el impuesto
    prg_obt_cargos(r_cte.cod_oficina,
               r_cte.nro_cuenta,
               r_cte.cod_moneda,
               NULL,
               r_cte.cod_modulo,
               r_cte.cod_modalidad,
               v_cod_tra_cargo,--Transaccion para el cobro de cargos
               v_cod_tas_cargo,
               v_val_tas_cargo,
               v_val_cargo,
               v_cod_tra_impuesto,
               v_cod_tas_impuesto,
               v_val_tas_impuesto,
               v_val_impuesto);
     if v_nrsecue > 990 then
        --v_hrmovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_hrmovim);
        v_hrmovim := fu_obt_hor_disponible(v_fcdehoy,v_hrmovim ,user,'N');
        v_nrsecue := 0;
     end if;

     --Verificar si excede el límite s/ TAE para Sobregiro
     if r_cte.cod_moneda = v_cod_mon_local then
       v_can_decimales := 0;
     else
       v_can_decimales:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda);
     end if;

     if r_cte.cod_modulo = 4 and r_cte.cod_modalidad = 41 then
        v_val_max_tae := fuc_obt_val_max_tae(r_cte.nro_cuenta,
                                           r_cte.cod_modulo,
                                           r_cte.cod_modalidad,
                                           v_cod_tra_cargo,
                                           v_val_cargo);
       if v_val_cargo > v_val_max_tae then
          v_val_cargo := v_Val_max_tae; --fuc_obt_val_max_tae(r_cte.nro_cuenta,
                                          --   r_cte.cod_modulo,
                                          --   r_cte.cod_modalidad,
                                          --   v_cod_tra_cargo,
                                          --   v_val_cargo);
           --Volver a Calcular el IVA
           v_val_impuesto := round(nvl(v_val_cargo,0)*nvl(v_val_tas_impuesto,0)/(100),v_can_decimales);
       end if;
     end if;
     --

     -- Calcula el monto a debitar de la cuenta
     v_imdebit := v_val_cargo + v_val_impuesto;
     IF p_procesa = 'S' then
       IF v_val_cargo > 0 and p_procesa = 'S' THEN
         -- movimiento de debito del Cargo
         -----------------------
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
         --
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
         r_gmovi.concepto        := 'Debito Cargo Sobregiro';
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
       END IF;
       IF v_val_impuesto > 0 THEN
          -- movimiento de debito por iva
          ----------------------------------
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
          --
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
          r_gmovi.concepto        := 'Debito Iva-Cargo por Sobregiro';
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
       END IF;
       -- actualizar el maestro de cuentas corrientes
       update cc_cta_corrientes
          set sal_total          = nvl(sal_total,0) - nvl(v_imdebit,0) ,
              fec_ult_movimiento = v_fcdehoy,
              hor_ult_movimiento = v_hrmovim
       where  current of cte;
       If v_cod_tra_cargo = 787 then  -- en gestion, actualiza la tabla en suspenso
         -- Insertar en sobregiro en suspenso
         insert into cc_sob_suspenso
         (nro_cuenta,fecha,cod_modulo,cod_modalidad,cod_transaccion,monto)
         values
         (r_cte.nro_cuenta,v_fcdehoy,r_cte.cod_modulo,r_cte.cod_modalidad,v_cod_Tra_cargo,nvl(v_val_cargo,0));
         -- Actualizar el monto en suspenso en Cta.Cte.
         Update cc_sobregiros_res
            set mto_sob_suspenso = nvl(mto_sob_suspenso,0)+nvl(v_val_cargo,0)
          where nro_cuenta = r_cte.nro_cuenta;
        End if;
     -- actualiza el acumulado de saldos mensuales si el estado del modulo != 2
     If v_esproce != 2
      and to_char(v_fcdehoy,'mmyyyy') <> to_char(V_FCPROXI,'mmyyyy')  Then
        PAG_CTA.PR_ACT_SAL_MENSUAL (r_cte.nro_cuenta,v_imdebit);
     End If;
    end if;
     <<fin_mientras>> NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  DBMS_APPLICATION_INFO.SET_ACTION(NULL);
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
  -- Retorna el monto del debito
  Return v_imdebit;
EXCEPTION
  when no_data_found then
     raise_application_error(-20000,'No existen datos');
End;



-- procedimiento que devuelve la utilizacion de lineas permanente y transitoria
procedure pr_obt_mto_uti_lineas
    (p_nro_cuenta              in varchar2,
     p_mto_uti_lin_permanente  out number,
     p_mto_uti_lin_transitoria out number,
     p_mto_uti_sin_linea       out number) is
v_tot_lin_permanente  number(18,2);
v_tot_lin_transitoria number(18,2);
v_sal_sobregiro       number(18,2) := 0;
begin
   p_mto_uti_lin_permanente  := 0;
   p_mto_uti_lin_transitoria := 0;
   p_mto_uti_sin_linea       := 0;
   -- obtengo el monto del sobregiro de la cuenta
   select nvl(sal_total,0) - nvl(sal_retenido,0)
     into v_sal_sobregiro
     from cc_cta_corrientes
    where nro_cuenta = p_nro_cuenta;
   if v_sal_sobregiro < 0 then
      v_sal_sobregiro := abs(v_sal_sobregiro);
   else
      v_sal_sobregiro := 0;
   end if;
   -- obtengo el total de linea permanente de la cuenta
   select nvl(sum(monto),0)
     into v_tot_lin_permanente
     from cc_lin_sobregiros
    where nro_cuenta = p_nro_cuenta
      and estado = 'A'
      and tipo = 'P';
   -- Obtengo el total de lineas transitorias de la cuenta
   select nvl(sum(monto),0)
     into v_tot_lin_transitoria
     from cc_lin_sobregiros
    where nro_cuenta = p_nro_cuenta
      and estado = 'A'
      and tipo = 'T';
   if v_sal_sobregiro <= v_tot_lin_permanente then
      p_mto_uti_lin_permanente   := v_sal_sobregiro;
      p_mto_uti_lin_transitoria  := 0;
      p_mto_uti_sin_linea        := 0;
   else
      p_mto_uti_lin_permanente  := v_tot_lin_permanente;
      if  v_sal_sobregiro - v_tot_lin_permanente > v_tot_lin_transitoria then
           p_mto_uti_lin_transitoria := v_tot_lin_transitoria;
           p_mto_uti_sin_linea  := v_sal_sobregiro - v_tot_lin_permanente -
                                   v_tot_lin_transitoria;
      else
           p_mto_uti_lin_transitoria := v_sal_sobregiro - v_tot_lin_permanente;
           p_mto_uti_sin_linea       := 0;
      end if;
   end if;

end;
-- funcion que devuelve la utilizacion de lineas por tipo
FUNCTION fu_obt_mto_uti_lineas
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_TIPO IN VARCHAR2
 )
 RETURN NUMBER
 IS
  v_tot_lin_permanente  number(18,2);
  v_tot_lin_transitoria number(18,2);
  v_sal_sobregiro       number(18,2) := 0;
begin
  pac_sob.pr_obt_mto_uti_lineas(p_nro_cuenta,
                                v_tot_lin_permanente,
                                v_tot_lin_transitoria,
                                v_sal_sobregiro);
  If p_tipo = 'T' then
    return v_tot_lin_transitoria;
  elsif p_tipo = 'P' then
    return v_tot_lin_permanente;
  end if;
end;
-- procedimiento para el cobro de cargo particular por el uso de anticipo de sueldo o aguinado
-- solo valido para plan sueldo
FUNCTION FU_UTI_ANTICIPOS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL
 ,P_PROCESA IN VARCHAR2 DEFAULT 'S'
 ,P_TIPO IN VARCHAR2 DEFAULT 'S'
 )
 RETURN NUMBER
 IS
  v_fcdehoy date;
  v_fcfinal date;
  v_fcproxi date;
  RV_GCALE GE_CALENDARIOS%ROWTYPE;
---
-- Obtiene todas las cuentas corrientes que se encuentren en estado distintos a
-- Cancelada
-- Pendiente de Cancelacion
-- Abierta Falta Depositar
-- Totalmente Bloqueada
-- Bloqueo de Debito
--
-- Y que no corresponda a las bancas: Corporativa, UR, Mercado Capitales, Funcionarios,
-- Privada, e Institucional.
-- Si se envia nulo el numero de cuenta, hace para todas las cuentas que cumplen con la condicion.
--
  CURSOR cte IS
    select *
      from cc_cta_corrientes cc
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.cod_ente is not null -- solo para los que son PLAN SUELDOS
       and cc.fec_apertura <= v_fcdehoy
       and exists (select 'S'
                     from cc_liq_sobregiros ccs
                    where ccs.nro_cuenta = cc.nro_cuenta
                      and ccs.fec_liquidacion = v_fcdehoy)
    for update of cc.estado;
  ---
  CURSOR anticipos(x_nro_cuenta in varchar2) IS
     select sum(monto) monto
       from ge_pag_sue_anticipos
      where nro_cuenta = x_nro_cuenta
        and liquidado = 'N'
        and tipo = p_tipo
      order by fecha;
  r_cte cte%rowtype;
--
  v_nrsecue ge_movimientos.nro_secuencia%type;
  v_hrmovim ge_movimientos.hora%type;
  v_imdebit ge_movimientos.monto%type :=  0;
  v_esproce ba_modulos.estado%type;
  r_gmovi   GE_MOVIMIENTOS%ROWTYPE;

  v_cod_tra_cargo number(4);--Transaccion para el cobro de cargos
  v_cod_tas_cargo number(4);
  v_val_tas_cargo number(18,4);
  v_val_cargo number(18,2);
  v_cod_tra_impuesto number(4);
  v_cod_tas_impuesto number(4);
  v_val_tas_impuesto number(18,4);
  v_val_impuesto number(18,2);
  v_tip_cargo varchar2(100);
BEGIN
  -- Verifica el estado del modulo para acumular o no
  v_esproce := pae_cnf.fu_obt_est_modulo(4);
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_FCPROXI := rv_gcale.fec_proxima;
  v_hrmovim := NVL(pae_cnf.G_HORA, fug_ini_hora(sysdate,'HH24:MI:SS'));--TO_CHAR(SYSDATE, 'HH24:MI:SS');
  v_nrsecue := nvl(pae_cnf.G_NRO_SECUENCIA,0);
  if NVL(P_TIPO,'S') = 'S' then
     v_tip_cargo := 'TRA_CAR_ANT_SUELDO';
  else
     v_tip_cargo := 'TRA_CAR_ANT_AGUINALDO';
  end if;

  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;
    -- obtengo el cargo que debo cobrar, si es sueldo o aguinaldo
    v_cod_tra_cargo := fug_obt_parentes(r_cte.cod_ente,v_tip_cargo);
    for an in anticipos(r_cte.nro_cuenta) loop
        -- Cero los valores para asegurar
        v_imdebit := 0;
        v_val_cargo := 0;
        v_val_impuesto := 0;
        -- obtengo el cargo y el impuesto
        prg_obt_cargos(r_cte.cod_oficina,
                   r_cte.nro_cuenta,
                   r_cte.cod_moneda,
                   an.monto,
                   r_cte.cod_modulo,
                   r_cte.cod_modalidad,
                   v_cod_tra_cargo,--Transaccion para el cobro de cargos
                   v_cod_tas_cargo,
                   v_val_tas_cargo,
                   v_val_cargo,
                   v_cod_tra_impuesto,
                   v_cod_tas_impuesto,
                   v_val_tas_impuesto,
                   v_val_impuesto);
         if v_nrsecue > 990 then
            v_hrmovim := pag_gen.FU_OBT_SIG_SEGUNDO(v_hrmovim);
            v_nrsecue := 0;
         end if;
         -- Calcula el monto a debitar de la cuenta
         v_imdebit := v_val_cargo + v_val_impuesto;
         IF p_procesa = 'S' then
           IF v_val_impuesto > 0 and p_procesa = 'S' THEN
             -- movimiento de debito del Cargo
             -----------------------
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
             --
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
             r_gmovi.concepto        := 'Debito Cargo x Uso Anticipo';
             r_gmovi.estado          := 'N';
             r_gmovi.reversado       := 'N';
             pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
           END IF;
           IF v_val_impuesto > 0 THEN
              -- movimiento de debito por iva
              ----------------------------------
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
              --
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
              r_gmovi.concepto        := 'Debito Iva-Cargo por Anticipo';
              r_gmovi.estado          := 'N';
              r_gmovi.reversado       := 'N';
              pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');
           END IF;
           -- actualizar el maestro de cuentas corrientes
           update cc_cta_corrientes
              set sal_total          = nvl(sal_total,0) - nvl(v_imdebit,0) ,
                  fec_ult_movimiento = v_fcdehoy,
                  hor_ult_movimiento = v_hrmovim
           where  current of cte;
           -- actualizo a liquidado
            update ge_pag_sue_anticipos
               set liquidado = 'S'
            where nro_cuenta = r_cte.nro_cuenta
              and liquidado = 'N'
              and tipo = p_tipo;
           -- actualiza el acumulado de saldos mensuales si el estado del modulo != 2
           If v_esproce != 2
           and to_char(v_fcproxi,'mmyyyy') <> to_char(v_Fcdehoy,'mmyyyy') then
              PAG_CTA.PR_ACT_SAL_MENSUAL (r_cte.nro_cuenta,v_imdebit);
           End If;
         end if;
     end loop;
     <<fin_mientras>> NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  pae_cnf.PR_SET_VARIABLES(v_hrmovim,v_nrsecue);
  -- Retorna el monto del debito
  Return v_imdebit;
EXCEPTION
  when no_data_found then
     raise_application_error(-20000,'No existen datos');
End;
--bbvades-3200
PROCEDURE PR_ACT_LIQ_SOB(P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE default null) IS
v_pac_sob_modo    ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PAC_SOB_PARALLEL'), 'NORMAL');
v_tam_fragmento  ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PAC_SOB_TAM_FRAG'), '25000');
v_job_cant       ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PAC_SOB_JOB_CANT'), '6');
v_tarea          VARCHAR2(128) := 'PAC_SOB_PARALELO';
Begin
  --Si no viene del cierre P_NRO_CUENTA no está nulo
  if P_NRO_CUENTA is not null then
    Update cc_sobregiros
       Set liquidado = 'S'
     Where generado = 'S'
       And liquidado = 'N'
       And nro_cuenta = p_nro_cuenta;
  else
    --Si esta nulo, viene del cierre
    IF 'PARALLEL_EXECUTE' = v_pac_sob_modo THEN--Verificar si está activo el paralelismo
      BEGIN
         -- Eliminar la tarea y los fragmentos relacionados
         DBMS_PARALLEL_EXECUTE.DROP_TASK(v_tarea);
      EXCEPTION
         WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
            NULL;
      END;
      -- Crear la tarea
      DBMS_PARALLEL_EXECUTE.create_task(v_tarea);

      -- Dividir la tabla por ROWID en intervalos
      DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(v_tarea, 'IT', 'CC_SOBREGIROS', true, TO_NUMBER(v_tam_fragmento));

      -- Ejecutar el DML en paralelo
      DBMS_PARALLEL_EXECUTE.run_task(task_name      => v_tarea,
                                      sql_stmt       =>
'DECLARE
   v_info  VARCHAR2(512);
   v_cant  PLS_INTEGER;
BEGIN
   Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; pae_cnf.G_PROGRAMA := ''GPPROFIN''; end;

   Update cc_sobregiros
       Set liquidado = ''S''
     Where generado = ''S''
       And liquidado = ''N''
       AND ROWID BETWEEN :start_id AND :end_id;

   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
      RAISE;
END;',
                                     language_flag  => DBMS_SQL.NATIVE,
                                     parallel_level => TO_NUMBER(v_job_cant));

      --Verificar el estatus de la ejecucion
      IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
         raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || v_tarea);
      END IF;
    ELSE
      Update cc_sobregiros
       Set liquidado = 'S'
     Where generado = 'S'
       And liquidado = 'N'
       And nro_cuenta = nvl(p_nro_cuenta, nro_cuenta);
    END IF;
  end if;
Exception
    When Others Then
       If sqlcode <= -20000 Then
         Raise;
       Else
         raise_application_error(-20000, 'en pr_act_liq_sob - '||sqlerrm);
       End If;
End;
/* Motor de liquidacion masiva exclusivo de la cadena de cierre. */
PROCEDURE PR_LIQ_SOB_BATCH IS
  rv_gcale ge_calendarios%ROWTYPE;
  v_ult_dia ge_calendarios.ult_dia_mes%TYPE;
  v_fcdehoy ge_calendarios.ult_dia_mes%TYPE;
  v_fecproxi ge_calendarios.fec_proxima%TYPE;
  v_cant_filas PLS_INTEGER := 0;
  v_limite CONSTANT PLS_INTEGER := 5000;
  v_cuentas_calculadas PLS_INTEGER := 0;
  v_cuentas_cerradas PLS_INTEGER := 0;
  v_cuentas_liquidables PLS_INTEGER := 0;
  v_tramos_calculados PLS_INTEGER := 0;
  v_interes_total NUMBER := 0;
  v_impuesto_total NUMBER := 0;
  v_nro_cta ge_cuentas.nro_cuenta%TYPE;
  v_interes_cta NUMBER := 0;
  v_impuesto_cta NUMBER := 0;
  v_interes_acuerdo NUMBER := 0;
  v_interes_general NUMBER := 0;
  v_procesar VARCHAR2(1) := 'S';
  v_saldo_anterior NUMBER := NULL;
  v_cod_oficina_cta ge_cuentas.cod_oficina%TYPE;
  v_cod_moneda_cta ge_cuentas.cod_moneda%TYPE;
  v_cod_ente_cta cc_cta_corrientes.cod_ente%TYPE;
  v_cod_sub_modalidad_cta ge_cuentas.cod_sub_modalidad%TYPE;
  v_tas_personalizada_cta ge_cuentas.tas_personalizada%TYPE;
  v_cta_combinada_cta cc_cta_corrientes.cta_combinada%TYPE;

  CURSOR cu_sob_batch IS
    SELECT ccs.nro_cuenta,
           ccs.fecha,
           ccs.saldo,
           ccs.liquidado,
           ccs.sal_total,
           ccs.sal_retenido,
           ccs.mto_linea,
           ccs.can_dias,
           ccs.mto_lin_transitoria,
           ccs.can_dia_sobregiro,
           ccs.generado,
           ge.cod_modulo,
           ge.cod_modalidad,
           ge.cod_oficina,
           ge.cod_moneda,
           ge.tas_personalizada,
           ge.cod_sub_modalidad,
           cc.cod_ente,
           cc.estado,
           cc.tra_prohibida,
           cc.cta_combinada,
           cc.sal_total AS sal_total_cta,
           cc.sal_retenido AS sal_retenido_cta,
           cc.sal_bloqueado AS sal_bloqueado_cta
      FROM cc_sobregiros ccs
      JOIN ge_cuentas ge
        ON ge.nro_cuenta = ccs.nro_cuenta
      JOIN cc_cta_corrientes cc
        ON cc.nro_cuenta = ccs.nro_cuenta
     WHERE ccs.liquidado = 'N'
       AND ccs.fecha <= v_ult_dia
       AND NVL(ccs.can_dias, 0) < NVL((
             SELECT a.val_parametro
               FROM ge_par_dinamicos a
              WHERE a.parametro = 'DIA_INA_CAR_SOBREGIROS'
                AND a.cod_modulo = ge.cod_modulo
                AND a.cod_modalidad = ge.cod_modalidad
                AND a.cod_moneda = ge.cod_moneda
                AND a.cod_oficina = ge.cod_oficina
       ), 9999)
       AND cc.estado NOT IN ('D', 'T', 'C', 'A', 'X')
       AND NOT EXISTS (
             SELECT 1
               FROM cc_liq_sobregiros liq
              WHERE liq.nro_cuenta = ccs.nro_cuenta
                AND liq.fec_liquidacion = v_fcdehoy
       )
    ORDER BY ccs.nro_cuenta, ccs.fecha;

  TYPE t_sob_batch_tab IS TABLE OF cu_sob_batch%ROWTYPE;
  v_sob_batch t_sob_batch_tab;

  TYPE t_liq_rec IS RECORD (
    nro_cuenta cc_liq_sobregiros.nro_cuenta%TYPE,
    fecha cc_liq_sobregiros.fecha%TYPE,
    saldo cc_liq_sobregiros.saldo%TYPE,
    fec_liquidacion cc_liq_sobregiros.fec_liquidacion%TYPE,
    can_dias cc_liq_sobregiros.can_dias%TYPE);
  TYPE t_liq_tab IS TABLE OF t_liq_rec INDEX BY PLS_INTEGER;
  l_liq_buffer t_liq_tab;

  TYPE t_mov_tab IS TABLE OF ge_movimientos%ROWTYPE INDEX BY PLS_INTEGER;
  l_mov_buffer t_mov_tab;

  TYPE t_cta_nro_tab IS TABLE OF cc_cta_corrientes.nro_cuenta%TYPE INDEX BY PLS_INTEGER;
  TYPE t_cta_saldo_tab IS TABLE OF cc_cta_corrientes.sal_total%TYPE INDEX BY PLS_INTEGER;
  TYPE t_cta_fecha_tab IS TABLE OF cc_cta_corrientes.fec_ult_movimiento%TYPE INDEX BY PLS_INTEGER;
  TYPE t_cta_hora_tab IS TABLE OF cc_cta_corrientes.hor_ult_movimiento%TYPE INDEX BY PLS_INTEGER;
  l_cta_nro_buffer t_cta_nro_tab;
  l_cta_saldo_buffer t_cta_saldo_tab;
  l_cta_fecha_buffer t_cta_fecha_tab;
  l_cta_hora_buffer t_cta_hora_tab;

  TYPE t_sob_nro_tab IS TABLE OF cc_sobregiros.nro_cuenta%TYPE INDEX BY PLS_INTEGER;
  TYPE t_sob_fecha_tab IS TABLE OF cc_sobregiros.fecha%TYPE INDEX BY PLS_INTEGER;
  l_sob_nro_buffer t_sob_nro_tab;
  l_sob_fecha_buffer t_sob_fecha_tab;

  v_liq_count PLS_INTEGER := 0;
  v_mov_count PLS_INTEGER := 0;
  v_cta_count PLS_INTEGER := 0;
  v_sob_count PLS_INTEGER := 0;
  v_can_user PLS_INTEGER := 0;
  TYPE t_seq_by_user IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(30);
  TYPE t_hora_by_user IS TABLE OF ge_movimientos.hora%TYPE INDEX BY VARCHAR2(30);
  l_seq_by_user t_seq_by_user;
  l_hora_by_user t_hora_by_user;
  v_hora_mov ge_movimientos.hora%TYPE;
  v_usuario_mov ge_movimientos.cod_usuario%TYPE;
  v_liq_nro_cta ge_cuentas.nro_cuenta%TYPE;
  v_liq_fecha cc_sobregiros.fecha%TYPE;
  v_liq_saldo cc_sobregiros.saldo%TYPE;
  v_liq_dias PLS_INTEGER := 0;
  v_cod_tasa_interes_batch ge_movimientos.cod_tasa%TYPE;
  v_val_tasa_interes_batch ge_movimientos.val_tasa%TYPE;
  v_cod_tasa_impuesto_batch ge_movimientos.cod_tasa%TYPE;
  v_val_tasa_impuesto_batch ge_movimientos.val_tasa%TYPE;

  PROCEDURE LP_LIM_VARIABLES_BATCH IS
  BEGIN
    l_liq_buffer.DELETE;
    l_mov_buffer.DELETE;
    l_cta_nro_buffer.DELETE;
    l_cta_saldo_buffer.DELETE;
    l_cta_fecha_buffer.DELETE;
    l_cta_hora_buffer.DELETE;
    l_sob_nro_buffer.DELETE;
    l_sob_fecha_buffer.DELETE;
    v_cod_tasa_interes_batch := NULL;
    v_val_tasa_interes_batch := NULL;
    v_cod_tasa_impuesto_batch := NULL;
    v_val_tasa_impuesto_batch := NULL;
    v_liq_count := 0;
    v_mov_count := 0;
    v_cta_count := 0;
    v_sob_count := 0;
  END LP_LIM_VARIABLES_BATCH;

  PROCEDURE LP_OBT_MOV_USER_BATCH IS
  BEGIN
    v_usuario_mov := PAG_CIE.FU_OBT_MOV_USER(
        'MOVCIERRE', 'USU_MOV_CIERRE', v_can_user, 'S_USU_MOVCIERRE');

    IF NOT l_seq_by_user.EXISTS(v_usuario_mov) THEN
      l_seq_by_user(v_usuario_mov) := 0;
    END IF;

    IF l_seq_by_user(v_usuario_mov) >= 997 THEN
      l_seq_by_user(v_usuario_mov) := 0;
      l_hora_by_user(v_usuario_mov) := PAG_CIE.FU_OBT_HORA(
          v_usuario_mov, 'S_HOR_MOVCIERRE', 'E');
    ELSIF NOT l_hora_by_user.EXISTS(v_usuario_mov) THEN
      l_hora_by_user(v_usuario_mov) := PAG_CIE.FU_OBT_HORA(
          v_usuario_mov, 'S_HOR_MOVCIERRE', 'E');
    END IF;

    l_seq_by_user(v_usuario_mov) := l_seq_by_user(v_usuario_mov) + 1;
    v_hora_mov := l_hora_by_user(v_usuario_mov);
  END LP_OBT_MOV_USER_BATCH;

  PROCEDURE LP_APL_DML_BATCH IS
  BEGIN
    IF v_liq_count > 0 THEN
      FORALL i IN 1 .. v_liq_count
        INSERT INTO cc_liq_sobregiros
          (nro_cuenta, fecha, saldo, fec_liquidacion, usu_insercion,
           usu_modificacion, can_dias)
        VALUES
          (l_liq_buffer(i).nro_cuenta, l_liq_buffer(i).fecha,
           l_liq_buffer(i).saldo, l_liq_buffer(i).fec_liquidacion,
           SUBSTR(UPPER(USER), 1, 15),
           SUBSTR(UPPER(USER), 1, 15),
           l_liq_buffer(i).can_dias);
    END IF;

    IF v_mov_count > 0 THEN
      FORALL i IN 1 .. v_mov_count
        INSERT INTO ge_movimientos
          (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto,
           nro_cuenta, cod_moneda, cod_oficina, cod_error, estado,
           cod_ofi_origen, concepto, cod_tasa, val_tasa, reversado,
           emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
           cod_transaccion, cod_modulo, cod_modalidad, nro_documento,
           protegido)
        VALUES
          (l_mov_buffer(i).fecha, l_mov_buffer(i).hora,
           l_mov_buffer(i).cod_usuario, l_mov_buffer(i).nro_secuencia,
           l_mov_buffer(i).fec_valor, l_mov_buffer(i).monto,
           l_mov_buffer(i).nro_cuenta, l_mov_buffer(i).cod_moneda,
           l_mov_buffer(i).cod_oficina, l_mov_buffer(i).cod_error,
           l_mov_buffer(i).estado, l_mov_buffer(i).cod_ofi_origen,
           l_mov_buffer(i).concepto, l_mov_buffer(i).cod_tasa,
           l_mov_buffer(i).val_tasa, l_mov_buffer(i).reversado,
           l_mov_buffer(i).emi_aviso, l_mov_buffer(i).cod_tra_padre,
           l_mov_buffer(i).cod_mod_padre, l_mov_buffer(i).cod_mad_padre,
           l_mov_buffer(i).cod_transaccion, l_mov_buffer(i).cod_modulo,
           l_mov_buffer(i).cod_modalidad, l_mov_buffer(i).nro_documento,
           l_mov_buffer(i).protegido);
    END IF;

    IF v_cta_count > 0 THEN
      FORALL i IN 1 .. v_cta_count
        UPDATE cc_cta_corrientes
           SET sal_total = NVL(sal_total, 0) - NVL(l_cta_saldo_buffer(i), 0),
               fec_ult_movimiento = l_cta_fecha_buffer(i),
               hor_ult_movimiento = l_cta_hora_buffer(i)
         WHERE nro_cuenta = l_cta_nro_buffer(i);
    END IF;

    IF v_sob_count > 0 THEN
      FORALL i IN 1 .. v_sob_count
        UPDATE cc_sobregiros
           SET generado = 'S'
         WHERE nro_cuenta = l_sob_nro_buffer(i)
           AND fecha = l_sob_fecha_buffer(i)
           AND generado = 'N';
    END IF;
  END LP_APL_DML_BATCH;

  PROCEDURE LP_GEN_LIQ_BATCH(p_nro_cta IN ge_cuentas.nro_cuenta%TYPE,
                          p_fecha IN DATE, p_saldo IN NUMBER,
                          p_dias IN PLS_INTEGER) IS
  BEGIN
    v_liq_count := v_liq_count + 1;
    l_liq_buffer(v_liq_count).nro_cuenta := p_nro_cta;
    l_liq_buffer(v_liq_count).fecha := p_fecha;
    l_liq_buffer(v_liq_count).saldo := p_saldo;
    l_liq_buffer(v_liq_count).fec_liquidacion := v_fcdehoy;
    l_liq_buffer(v_liq_count).can_dias := p_dias;
  END LP_GEN_LIQ_BATCH;

  PROCEDURE LP_GEN_MOVIMIENTO_BATCH(p_nro_cta IN ge_cuentas.nro_cuenta%TYPE,
                          p_monto IN NUMBER, p_transaccion IN NUMBER,
                          p_tasa IN NUMBER, p_val_tasa IN NUMBER,
                          p_concepto IN VARCHAR2) IS
    l_cod_tra_padre ge_movimientos.cod_tra_padre%TYPE;
  BEGIN
    v_mov_count := v_mov_count + 1;
    LP_OBT_MOV_USER_BATCH;
    l_cod_tra_padre := CASE
      WHEN v_cod_ente_cta IS NULL AND p_transaccion = 523 THEN 319
      WHEN v_cod_ente_cta IS NOT NULL AND p_transaccion = 550 THEN 327
      ELSE p_transaccion
    END;
    l_mov_buffer(v_mov_count).fecha := v_fcdehoy;
    l_mov_buffer(v_mov_count).hora := v_hora_mov;
    l_mov_buffer(v_mov_count).cod_usuario := v_usuario_mov;
    l_mov_buffer(v_mov_count).nro_secuencia := l_seq_by_user(v_usuario_mov);
    l_mov_buffer(v_mov_count).fec_valor := v_fcdehoy;
    l_mov_buffer(v_mov_count).monto := p_monto;
    l_mov_buffer(v_mov_count).nro_cuenta := p_nro_cta;
    l_mov_buffer(v_mov_count).cod_moneda := v_cod_moneda_cta;
    l_mov_buffer(v_mov_count).cod_oficina := v_cod_oficina_cta;
    l_mov_buffer(v_mov_count).estado := 'N';
    l_mov_buffer(v_mov_count).cod_ofi_origen := v_cod_oficina_cta;
    l_mov_buffer(v_mov_count).concepto := p_concepto;
    l_mov_buffer(v_mov_count).cod_tasa := p_tasa;
    l_mov_buffer(v_mov_count).val_tasa := p_val_tasa;
    l_mov_buffer(v_mov_count).reversado := 'N';
    l_mov_buffer(v_mov_count).emi_aviso := 'N';
    l_mov_buffer(v_mov_count).cod_tra_padre := l_cod_tra_padre;
    l_mov_buffer(v_mov_count).cod_mod_padre := 4;
    l_mov_buffer(v_mov_count).cod_mad_padre := 41;
    l_mov_buffer(v_mov_count).cod_transaccion := p_transaccion;
    l_mov_buffer(v_mov_count).cod_modulo := 4;
    l_mov_buffer(v_mov_count).cod_modalidad := 41;
    l_mov_buffer(v_mov_count).protegido := 'N';

    IF p_transaccion IN (980, 3980) THEN
      INSERT INTO cc_sob_suspenso
        (nro_cuenta, fecha, cod_modulo, cod_modalidad,
         cod_transaccion, monto)
      VALUES
        (p_nro_cta, v_fcdehoy, 4, 41, p_transaccion, p_monto);

      UPDATE cc_sobregiros_res
         SET mto_sob_suspenso = NVL(mto_sob_suspenso, 0) + NVL(p_monto, 0)
      WHERE nro_cuenta = p_nro_cta;
    END IF;
  END LP_GEN_MOVIMIENTO_BATCH;

  PROCEDURE LP_CER_LIQ_BATCH IS
  BEGIN
    IF v_liq_nro_cta IS NOT NULL AND v_liq_dias > 0 THEN
      LP_GEN_LIQ_BATCH(v_liq_nro_cta, v_liq_fecha, v_liq_saldo, v_liq_dias);
      v_liq_nro_cta := NULL;
      v_liq_fecha := NULL;
      v_liq_saldo := NULL;
      v_liq_dias := 0;
    END IF;
  END LP_CER_LIQ_BATCH;

  PROCEDURE LP_OBT_VAL_TASA_BATCH(
      p_nro_cta IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_modulo IN NUMBER,
      p_cod_modalidad IN NUMBER,
      p_cod_oficina IN NUMBER,
      p_cod_moneda IN VARCHAR2,
      p_cod_ente IN cc_cta_corrientes.cod_ente%TYPE,
      p_cod_sub_modalidad IN ge_cuentas.cod_sub_modalidad%TYPE,
      p_tas_personalizada IN VARCHAR2,
      p_cod_tasa_in IN NUMBER,
      p_cod_transaccion IN NUMBER,
      p_fecha IN DATE,
      p_cod_tasa OUT NUMBER,
      p_val_tasa OUT NUMBER) IS
    v_encontro BOOLEAN := FALSE;
    v_tasa_explicita BOOLEAN := p_cod_tasa_in IS NOT NULL;
  BEGIN
    p_cod_tasa := p_cod_tasa_in;
    p_val_tasa := 0;

    IF v_tasa_explicita THEN
      BEGIN
        SELECT val_tasa, cod_tasa
          INTO p_val_tasa, p_cod_tasa
          FROM (
            SELECT NVL(t.val_tasa, 0) val_tasa, t.cod_tasa
              FROM ge_tas_fechas t
             WHERE NVL(t.cod_modulo, p_cod_modulo) = p_cod_modulo
               AND NVL(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
               AND NVL(t.cod_sub_modalidad, NVL(p_cod_sub_modalidad, -1)) = NVL(p_cod_sub_modalidad, -1)
               AND NVL(t.cod_oficina, p_cod_oficina) = p_cod_oficina
               AND NVL(t.cod_ente, NVL(p_cod_ente, -1)) = NVL(p_cod_ente, -1)
               AND NVL(t.cod_moneda, p_cod_moneda) = p_cod_moneda
               AND t.cod_tasa = p_cod_tasa_in
               AND (t.nro_cuenta = p_nro_cta OR t.nro_cuenta IS NULL)
               AND t.cod_persona IS NULL
               AND t.fec_vigencia <= p_fecha
             ORDER BY CASE WHEN t.nro_cuenta = p_nro_cta THEN 1 ELSE 0 END DESC,
                      t.fec_vigencia DESC
          )
         WHERE ROWNUM = 1;
        v_encontro := TRUE;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_encontro := FALSE;
      END;
    ELSIF p_cod_transaccion = 550 THEN
      BEGIN
        IF p_tas_personalizada = 'N' THEN
          SELECT val_tasa, cod_tasa
            INTO p_val_tasa, p_cod_tasa
            FROM (
              SELECT t.val_tasa, t.cod_tasa
                FROM ge_tas_fechas t
                JOIN ge_transacciones tr ON tr.cod_tasa = t.cod_tasa
               WHERE NVL(t.cod_modulo, p_cod_modulo) = p_cod_modulo
                 AND NVL(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
                 AND NVL(t.cod_sub_modalidad, NVL(p_cod_sub_modalidad, -1)) = NVL(p_cod_sub_modalidad, -1)
                 AND NVL(t.cod_oficina, p_cod_oficina) = p_cod_oficina
                 AND NVL(t.cod_ente, NVL(p_cod_ente, -1)) = NVL(p_cod_ente, -1)
                 AND NVL(t.cod_moneda, p_cod_moneda) = p_cod_moneda
                 AND t.nro_cuenta IS NULL
                 AND NVL(tr.cod_modulo, p_cod_modulo) = p_cod_modulo
                 AND NVL(tr.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
                 AND tr.cod_transaccion = p_cod_transaccion
                 AND t.fec_vigencia <= p_fecha
               ORDER BY DECODE(t.cod_modulo, NULL, 0, 1) +
                        DECODE(t.cod_modalidad, NULL, 0, 1) +
                        DECODE(t.cod_sub_modalidad, NULL, 0, 1) DESC,
                        t.fec_vigencia DESC
            )
           WHERE ROWNUM = 1;
        ELSE
          SELECT val_tasa, cod_tasa
            INTO p_val_tasa, p_cod_tasa
            FROM (
              SELECT t.val_tasa, t.cod_tasa
                FROM ge_tas_fechas t
                JOIN ge_transacciones tr ON tr.cod_tasa = t.cod_tasa
               WHERE NVL(t.cod_modulo, p_cod_modulo) = p_cod_modulo
                 AND NVL(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
                 AND NVL(t.cod_sub_modalidad, NVL(p_cod_sub_modalidad, -1)) = NVL(p_cod_sub_modalidad, -1)
                 AND NVL(t.cod_oficina, p_cod_oficina) = p_cod_oficina
                 AND NVL(t.cod_ente, NVL(p_cod_ente, -1)) = NVL(p_cod_ente, -1)
                 AND NVL(t.cod_moneda, p_cod_moneda) = p_cod_moneda
                 AND t.nro_cuenta = p_nro_cta
                 AND NVL(tr.cod_modulo, p_cod_modulo) = p_cod_modulo
                 AND NVL(tr.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
                 AND tr.cod_transaccion = p_cod_transaccion
                 AND t.fec_vigencia <= p_fecha
               ORDER BY t.fec_vigencia DESC
            )
           WHERE ROWNUM = 1;
        END IF;
        v_encontro := TRUE;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_encontro := FALSE;
      END;
    ELSE
      BEGIN
        SELECT cod_tasa
          INTO p_cod_tasa
          FROM ge_transacciones
         WHERE cod_modulo = p_cod_modulo
           AND cod_modalidad = p_cod_modalidad
           AND cod_transaccion = p_cod_transaccion;

        SELECT val_tasa
          INTO p_val_tasa
          FROM (
            SELECT NVL(t.val_tasa, 0) val_tasa
              FROM ge_tas_fechas t
             WHERE NVL(t.cod_modulo, p_cod_modulo) = p_cod_modulo
               AND NVL(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
               AND NVL(t.cod_sub_modalidad, NVL(p_cod_sub_modalidad, -1)) = NVL(p_cod_sub_modalidad, -1)
               AND NVL(t.cod_oficina, p_cod_oficina) = p_cod_oficina
               AND NVL(t.cod_ente, NVL(p_cod_ente, -1)) = NVL(p_cod_ente, -1)
               AND NVL(t.cod_moneda, p_cod_moneda) = p_cod_moneda
               AND t.cod_tasa = p_cod_tasa
               AND t.nro_cuenta IS NULL
               AND t.cod_persona IS NULL
               AND t.fec_vigencia <= p_fecha
             ORDER BY DECODE(t.cod_modulo, NULL, 0, 1) +
                      DECODE(t.cod_modalidad, NULL, 0, 1) +
                      DECODE(t.cod_sub_modalidad, NULL, 0, 1) DESC,
                      t.fec_vigencia DESC
          )
         WHERE ROWNUM = 1;
        v_encontro := TRUE;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_encontro := FALSE;
      END;
    END IF;

    IF NOT v_encontro AND p_cod_tasa IS NULL THEN
      BEGIN
        SELECT cod_tasa
          INTO p_cod_tasa
          FROM ge_transacciones
         WHERE NVL(cod_modulo, p_cod_modulo) = p_cod_modulo
           AND NVL(cod_modalidad, p_cod_modalidad) = p_cod_modalidad
           AND cod_transaccion = p_cod_transaccion;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          p_cod_tasa := p_cod_tasa_in;
      END;
    END IF;

    IF NOT v_encontro AND p_cod_tasa IS NOT NULL AND NOT v_tasa_explicita THEN
      SELECT val_tasa
        INTO p_val_tasa
        FROM (
          SELECT NVL(t.val_tasa, 0) val_tasa
            FROM ge_tas_fechas t
           WHERE NVL(t.cod_modulo, p_cod_modulo) = p_cod_modulo
             AND NVL(t.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
             AND NVL(t.cod_sub_modalidad, NVL(p_cod_sub_modalidad, -1)) = NVL(p_cod_sub_modalidad, -1)
             AND NVL(t.cod_oficina, p_cod_oficina) = p_cod_oficina
             AND NVL(t.cod_ente, NVL(p_cod_ente, -1)) = NVL(p_cod_ente, -1)
             AND NVL(t.cod_moneda, p_cod_moneda) = p_cod_moneda
             AND t.cod_tasa = p_cod_tasa
             AND t.nro_cuenta IS NULL
             AND t.cod_persona IS NULL
             AND t.fec_vigencia <= p_fecha
           ORDER BY t.fec_vigencia DESC
        )
       WHERE ROWNUM = 1;
      v_encontro := TRUE;
    END IF;

    IF NOT v_encontro OR p_cod_tasa IS NULL THEN
      RAISE_APPLICATION_ERROR(-20006,
        'No se han recuperado datos para la tasa ' || p_cod_transaccion || '-' || p_cod_moneda);
    END IF;
  END LP_OBT_VAL_TASA_BATCH;

  PROCEDURE LP_CAL_INTERES_BATCH(
      p_nro_cta IN ge_cuentas.nro_cuenta%TYPE,
      p_importe IN NUMBER,
      p_cod_tasa IN NUMBER,
      p_cod_modulo IN NUMBER,
      p_cod_modalidad IN NUMBER,
      p_cod_oficina IN NUMBER,
      p_cod_moneda IN VARCHAR2,
      p_cod_ente IN cc_cta_corrientes.cod_ente%TYPE,
      p_cod_sub_modalidad IN ge_cuentas.cod_sub_modalidad%TYPE,
      p_tas_personalizada IN VARCHAR2,
      p_redondeo IN NUMBER,
      p_fecha IN DATE,
      p_interes OUT NUMBER) IS
    l_cod_tasa NUMBER;
    l_val_tasa NUMBER;
  BEGIN
    LP_OBT_VAL_TASA_BATCH(p_nro_cta, p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                      p_cod_moneda, p_cod_ente, p_cod_sub_modalidad,
                      p_tas_personalizada, p_cod_tasa, 550, p_fecha,
                      l_cod_tasa, l_val_tasa);
    v_cod_tasa_interes_batch := l_cod_tasa;
    v_val_tasa_interes_batch := l_val_tasa;
    IF l_cod_tasa IS NULL OR NVL(l_val_tasa, 0) = 0 THEN
      p_interes := 0;
    ELSE
      p_interes := ROUND(NVL(p_importe, 0) * NVL(l_val_tasa, 0) / 36500, p_redondeo);
      p_interes := pag_gen.FU_OBT_VAL_FINAL(p_interes);
    END IF;
    p_interes := ROUND(NVL(p_interes, 0), p_redondeo);
  END LP_CAL_INTERES_BATCH;

  PROCEDURE LP_CAL_IMPUESTO_BATCH(
      p_nro_cta IN ge_cuentas.nro_cuenta%TYPE,
      p_interes IN NUMBER,
      p_cod_modulo IN NUMBER,
      p_cod_modalidad IN NUMBER,
      p_cod_oficina IN NUMBER,
      p_cod_moneda IN VARCHAR2,
      p_cod_ente IN NUMBER,
      p_cod_sub_modalidad IN NUMBER,
      p_tas_personalizada IN VARCHAR2,
      p_redondeo IN NUMBER,
      p_fecha IN DATE,
      p_impuesto OUT NUMBER) IS
    l_cod_tasa NUMBER;
    l_val_tasa NUMBER;
    l_val_exo_impuesto NUMBER;
  BEGIN
    LP_OBT_VAL_TASA_BATCH(p_nro_cta, p_cod_modulo, p_cod_modalidad, p_cod_oficina,
                      p_cod_moneda, p_cod_ente, p_cod_sub_modalidad,
                      p_tas_personalizada, NULL, 523, p_fecha,
                      l_cod_tasa, l_val_tasa);
    v_cod_tasa_impuesto_batch := l_cod_tasa;
    v_val_tasa_impuesto_batch := l_val_tasa;
    IF l_cod_tasa IS NOT NULL AND NVL(l_cod_tasa, 0) <> 0
       AND NVL(l_val_tasa, 0) <> 0 THEN
      p_impuesto := ROUND(NVL(p_interes, 0) * NVL(l_val_tasa, 0) / 100, p_redondeo);
      p_impuesto := pag_gen.FU_OBT_VAL_FINAL(p_impuesto);
    ELSE
      p_impuesto := 0;
    END IF;

    IF g_fre_proceso <> 'M' OR g_db_prod = 'N' THEN
      BEGIN
        l_val_exo_impuesto := fug_obt_val_tasa(
            p_cod_modulo, p_cod_modalidad, p_cod_oficina, NULL,
            p_cod_moneda, 0, 'N', NULL, 523, p_fecha);
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000, 'Al Obt.Val.Tasa:' || SQLERRM);
      END;
      l_val_exo_impuesto := ROUND(NVL(p_interes, 0) * NVL(l_val_tasa, 0) / 100,
                                  p_redondeo);
      l_val_exo_impuesto := pag_gen.FU_OBT_VAL_FINAL(l_val_exo_impuesto);
      IF pag_cta.fu_ver_tra_prohibida(p_nro_cta, 523, p_cod_modulo, p_cod_modalidad) = 'S' THEN
        prg_ins_exoneracion(523, p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                            p_nro_cta, NULL, l_cod_tasa,
                            NVL(l_val_exo_impuesto, 0),
                            NVL(l_val_exo_impuesto, 0), NULL,
                            NVL(l_val_exo_impuesto, 0));
      ELSIF NVL(p_impuesto, 0) <> NVL(l_val_exo_impuesto, 0)
         OR (NVL(p_impuesto, 0) = 0 AND NVL(l_val_exo_impuesto, 0) <> 0) THEN
        prg_ins_exoneracion(523, p_cod_modulo, p_cod_modalidad, p_cod_moneda,
                            p_nro_cta, NULL, l_cod_tasa,
                            NVL(l_val_exo_impuesto, 0) - NVL(p_impuesto, 0),
                            l_val_exo_impuesto, NULL,
                            NVL(l_val_exo_impuesto, 0) - NVL(p_impuesto, 0));
      END IF;
    END IF;
  END LP_CAL_IMPUESTO_BATCH;

  PROCEDURE LP_PRO_ACU_SOB_BATCH(p_fila IN PLS_INTEGER) IS
    v_interes_tramo NUMBER(18,2) := 0;
    v_interes_sueldo NUMBER(18,2) := 0;
    v_interes_aguinaldo NUMBER(18,2) := 0;
    v_saldo NUMBER := NVL(v_sob_batch(p_fila).saldo, 0);
    v_saldo_general NUMBER := v_saldo;
    v_mto_sueldo NUMBER := LEAST(v_saldo_general,
      NVL(v_sob_batch(p_fila).mto_lin_transitoria, 0));
    v_mto_aguinaldo NUMBER := 0;
  BEGIN
    IF v_procesar = 'N' THEN
      RETURN;
    END IF;

    IF v_sob_batch(p_fila).cod_ente IS NOT NULL THEN
      LP_CAL_INTERES_BATCH(v_nro_cta, v_mto_sueldo,
          fug_obt_parentes(v_sob_batch(p_fila).cod_ente, 'TAS_ANT_SUELDO'),
          v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
          v_sob_batch(p_fila).cod_oficina, v_sob_batch(p_fila).cod_moneda,
          v_sob_batch(p_fila).cod_ente, v_sob_batch(p_fila).cod_sub_modalidad,
          v_sob_batch(p_fila).tas_personalizada,
          CASE WHEN v_sob_batch(p_fila).cod_moneda = pag_gen.FU_OBT_MON_LOCAL THEN 0
               ELSE fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                    v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
                    v_sob_batch(p_fila).cod_moneda) END,
          v_fcdehoy, v_interes_sueldo);
        v_saldo_general := GREATEST(v_saldo_general - v_mto_sueldo, 0);
        v_mto_aguinaldo := LEAST(v_saldo_general,
          GREATEST(NVL(v_sob_batch(p_fila).mto_linea, 0) -
               NVL(v_sob_batch(p_fila).mto_lin_transitoria, 0), 0));
        LP_CAL_INTERES_BATCH(v_nro_cta, v_mto_aguinaldo,
          fug_obt_parentes(v_sob_batch(p_fila).cod_ente, 'TAS_ANT_AGUINALDO'),
          v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
          v_sob_batch(p_fila).cod_oficina, v_sob_batch(p_fila).cod_moneda,
          v_sob_batch(p_fila).cod_ente, v_sob_batch(p_fila).cod_sub_modalidad,
          v_sob_batch(p_fila).tas_personalizada,
          CASE WHEN v_sob_batch(p_fila).cod_moneda = pag_gen.FU_OBT_MON_LOCAL THEN 0
            ELSE fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
              v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
              v_sob_batch(p_fila).cod_moneda) END,
          v_fcdehoy, v_interes_aguinaldo);
          v_saldo_general := GREATEST(v_saldo_general - v_mto_aguinaldo, 0);
          LP_CAL_INTERES_BATCH(v_nro_cta, v_saldo_general, NULL,
            v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
            v_sob_batch(p_fila).cod_oficina, v_sob_batch(p_fila).cod_moneda,
            v_sob_batch(p_fila).cod_ente, v_sob_batch(p_fila).cod_sub_modalidad,
              v_sob_batch(p_fila).tas_personalizada,
              CASE WHEN v_sob_batch(p_fila).cod_moneda = pag_gen.FU_OBT_MON_LOCAL THEN 0
                ELSE fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                    v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
                    v_sob_batch(p_fila).cod_moneda) END,
                  v_fcdehoy, v_interes_tramo);
    ELSE
              LP_CAL_INTERES_BATCH(v_nro_cta, v_saldo_general, NULL,
                v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
                v_sob_batch(p_fila).cod_oficina, v_sob_batch(p_fila).cod_moneda,
                v_sob_batch(p_fila).cod_ente, v_sob_batch(p_fila).cod_sub_modalidad,
                v_sob_batch(p_fila).tas_personalizada,
                CASE WHEN v_sob_batch(p_fila).cod_moneda = pag_gen.FU_OBT_MON_LOCAL THEN 0
            ELSE fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                v_sob_batch(p_fila).cod_modulo, v_sob_batch(p_fila).cod_modalidad,
                v_sob_batch(p_fila).cod_moneda) END,
              v_fcdehoy, v_interes_tramo);
    END IF;

    v_interes_acuerdo := v_interes_acuerdo + v_interes_sueldo + v_interes_aguinaldo;
    v_interes_general := v_interes_general + v_interes_tramo;
    v_tramos_calculados := v_tramos_calculados + 1;
  END LP_PRO_ACU_SOB_BATCH;

  PROCEDURE LP_ACT_SOBREGIROS_BATCH(
      p_total_debito IN NUMBER) IS
    v_dias PLS_INTEGER;
    v_minimo cc_cta_combinadas.sal_minimo%TYPE;
    v_sal_acu_diario cc_sal_mensuales.sal_acu_diario%TYPE;
    v_dias_acumulados cc_sal_mensuales.can_dia_acumulado%TYPE;
    v_saldo_inicial cc_sal_mensuales.sal_ini_mes%TYPE;
  BEGIN
    UPDATE cc_sobregiros
       SET generado = 'S'
     WHERE nro_cuenta = v_nro_cta
       AND fecha <= v_ult_dia
       AND generado = 'N';

    IF v_cta_combinada_cta = 'S' THEN
      SELECT sal_minimo
        INTO v_minimo
        FROM cc_cta_combinadas
       WHERE nro_cta_cte = v_nro_cta;

      SELECT sal_acu_diario, can_dia_acumulado, sal_ini_mes
        INTO v_sal_acu_diario, v_dias_acumulados, v_saldo_inicial
        FROM cc_sal_mensuales
       WHERE cod_modulo = 4
         AND cod_modalidad = 41
         AND cod_oficina = v_cod_oficina_cta
         AND nro_cuenta = v_nro_cta
         AND ano = TO_CHAR(v_fecproxi, 'YYYY')
         AND mes = TO_CHAR(v_fecproxi, 'MM');
    END IF;

    IF v_cta_combinada_cta = 'N'
       OR (v_cta_combinada_cta = 'S'
           AND NVL(v_saldo_inicial, 0) < NVL(v_minimo, 0)) THEN
      UPDATE cc_sal_mensuales
         SET sal_ini_mes = NVL(sal_ini_mes, 0) - NVL(p_total_debito, 0)
       WHERE cod_modulo = 4
         AND cod_modalidad = 41
         AND cod_oficina = v_cod_oficina_cta
         AND nro_cuenta = v_nro_cta
         AND ano = TO_CHAR(v_fecproxi, 'YYYY')
         AND mes = TO_CHAR(v_fecproxi, 'MM');
    END IF;

    IF v_fcdehoy + 1 <> v_fecproxi
       AND TO_CHAR(v_fcdehoy, 'MM') <> TO_CHAR(v_fecproxi, 'MM') THEN
      v_dias := TO_NUMBER(TO_CHAR(v_fecproxi, 'DD')) - 1;

      IF v_cta_combinada_cta = 'N'
         OR (v_cta_combinada_cta = 'S'
             AND NVL(v_sal_acu_diario, 0) / GREATEST(NVL(v_dias_acumulados, 1), 1)
                 < NVL(v_minimo, 0)) THEN
        UPDATE cc_sal_mensuales
           SET sal_acu_diario = NVL(sal_acu_diario, 0) - v_dias * NVL(p_total_debito, 0)
         WHERE cod_modulo = 4
           AND cod_modalidad = 41
           AND cod_oficina = v_cod_oficina_cta
           AND nro_cuenta = v_nro_cta
           AND ano = TO_CHAR(v_fecproxi, 'YYYY')
           AND mes = TO_CHAR(v_fecproxi, 'MM');

        UPDATE cc_sal_mensuales
           SET sal_acu_deudor = NVL(sal_acu_deudor, 0) + v_dias * NVL(p_total_debito, 0)
         WHERE cod_modulo = 4
           AND cod_modalidad = 41
           AND cod_oficina = v_cod_oficina_cta
           AND nro_cuenta = v_nro_cta
           AND ano = TO_CHAR(v_fecproxi, 'YYYY')
           AND mes = TO_CHAR(v_fecproxi, 'MM')
           AND NVL(sal_acu_deudor, 0) <> 0;

        UPDATE cc_sal_mensuales
           SET sal_acu_acreedor = 0,
               sal_acu_deudor = NVL(sal_acu_acreedor, 0) - v_dias * NVL(p_total_debito, 0)
         WHERE cod_modulo = 4
           AND cod_modalidad = 41
           AND cod_oficina = v_cod_oficina_cta
           AND nro_cuenta = v_nro_cta
           AND ano = TO_CHAR(v_fecproxi, 'YYYY')
           AND mes = TO_CHAR(v_fecproxi, 'MM')
           AND NVL(sal_acu_acreedor, 0) <> 0
           AND NVL(sal_acu_acreedor, 0) - v_dias * NVL(p_total_debito, 0) < 0;

        UPDATE cc_sal_mensuales
           SET sal_acu_acreedor = NVL(sal_acu_acreedor, 0) - v_dias * NVL(p_total_debito, 0)
         WHERE cod_modulo = 4
           AND cod_modalidad = 41
           AND cod_oficina = v_cod_oficina_cta
           AND nro_cuenta = v_nro_cta
           AND ano = TO_CHAR(v_fecproxi, 'YYYY')
           AND mes = TO_CHAR(v_fecproxi, 'MM')
           AND NVL(sal_acu_acreedor, 0) <> 0
           AND NVL(sal_acu_acreedor, 0) - v_dias * NVL(p_total_debito, 0) >= 0;
      END IF;
    END IF;
  END LP_ACT_SOBREGIROS_BATCH;

  PROCEDURE LP_ACT_SOB_FUT_BATCH(
      p_total_debito IN NUMBER) IS
    v_sal_total_cta cc_cta_corrientes.sal_total%TYPE;
    v_sal_retenido_cta cc_cta_corrientes.sal_retenido%TYPE;
    v_dias_futuros PLS_INTEGER;
  BEGIN
    IF p_total_debito > 0
       AND v_fcdehoy + 1 <> v_fecproxi
       AND TO_CHAR(v_fcdehoy, 'MM') <> TO_CHAR(v_fecproxi, 'MM') THEN
      SELECT sal_total, sal_retenido
        INTO v_sal_total_cta, v_sal_retenido_cta
        FROM cc_cta_corrientes
       WHERE nro_cuenta = v_nro_cta;

      IF NVL(v_sal_total_cta, 0) - NVL(v_sal_retenido_cta, 0) - p_total_debito < 0 THEN
      v_dias_futuros := TO_NUMBER(TO_CHAR(v_fecproxi, 'DD')) - 1;

      IF NVL(v_sal_total_cta, 0) - NVL(v_sal_retenido_cta, 0) < 0 THEN
        FOR i IN 1 .. v_dias_futuros LOOP
          UPDATE cc_sobregiros
             SET saldo = NVL(saldo, 0) + p_total_debito
           WHERE nro_cuenta = v_nro_cta
             AND fecha = v_ult_dia + i;
        END LOOP;
      ELSE
        FOR i IN 1 .. v_dias_futuros LOOP
          INSERT INTO cc_sobregiros
            (nro_cuenta, fecha, saldo, liquidado)
          VALUES
            (v_nro_cta, v_ult_dia + i,
             (NVL(v_sal_total_cta, 0) - NVL(v_sal_retenido_cta, 0) - p_total_debito) * -1,
             'N');
        END LOOP;
      END IF;
    END IF;
      END IF;
  END LP_ACT_SOB_FUT_BATCH;

  PROCEDURE LP_CER_CTA_BATCH IS
    l_redondeo NUMBER := 0;
    l_total_debito NUMBER;
    l_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
  BEGIN
    IF v_nro_cta IS NULL THEN
      RETURN;
    END IF;
    IF v_procesar = 'N' THEN
      LP_CER_LIQ_BATCH;
      v_mov_count := 0;
      v_cta_count := 0;
      v_sob_count := 0;
      LP_APL_DML_BATCH;
      LP_LIM_VARIABLES_BATCH;
      v_liq_nro_cta := NULL;
      v_liq_fecha := NULL;
      v_liq_saldo := NULL;
      v_liq_dias := 0;
      RETURN;
    END IF;
    IF FU_SIT_SOBREGIRO(v_nro_cta) NOT IN ('S', 'V') THEN
      l_cod_transaccion := CASE
        WHEN v_cod_ente_cta IS NOT NULL THEN 3980
        ELSE 980
      END;
    ELSE
      l_cod_transaccion := CASE
        WHEN v_cod_ente_cta IS NOT NULL THEN 3550
        ELSE 550
      END;
    END IF;

    IF v_cod_moneda_cta = pag_gen.FU_OBT_MON_LOCAL THEN
      l_redondeo := 0;
    ELSE
      l_redondeo := fug_obt_pardinamico(
          'VAL_RED_MON_EXTRANJERA', 4, 41, v_cod_moneda_cta);
    END IF;

    v_interes_cta := ROUND(NVL(v_interes_acuerdo, 0) + NVL(v_interes_general, 0), l_redondeo);
    v_interes_cta := fuc_obt_val_max_tae(v_nro_cta, 4, 41, 550, v_interes_cta);
    LP_CAL_IMPUESTO_BATCH(v_nro_cta, v_interes_cta, 4, 41,
                v_cod_oficina_cta, v_cod_moneda_cta,
          v_cod_ente_cta, v_cod_sub_modalidad_cta,
          v_tas_personalizada_cta,
                l_redondeo, v_fcdehoy, v_impuesto_cta);
    v_interes_total := v_interes_total + NVL(v_interes_cta, 0);
    v_impuesto_total := v_impuesto_total + NVL(v_impuesto_cta, 0);
    IF NVL(v_interes_cta, 0) > 0 THEN
      v_cuentas_liquidables := v_cuentas_liquidables + 1;
    END IF;

    l_total_debito := NVL(v_interes_cta, 0) + NVL(v_impuesto_cta, 0);

    IF l_total_debito > 0 THEN
      LP_ACT_SOBREGIROS_BATCH(l_total_debito);
      LP_ACT_SOB_FUT_BATCH(l_total_debito);
      LP_GEN_MOVIMIENTO_BATCH(v_nro_cta, v_interes_cta, l_cod_transaccion,
        v_cod_tasa_interes_batch, v_val_tasa_interes_batch,
            CASE WHEN v_cod_ente_cta IS NOT NULL
              THEN 'Liq. de Anticipo.'
              ELSE 'Liq.Sobregiro. Interés'
            END);
      IF v_impuesto_cta > 0 THEN
        LP_GEN_MOVIMIENTO_BATCH(v_nro_cta, v_impuesto_cta, 523,
          v_cod_tasa_impuesto_batch, v_val_tasa_impuesto_batch,
              CASE WHEN v_cod_ente_cta IS NOT NULL
                THEN 'Liq. de IVA s/ Anticipo'
                ELSE 'Liq.Sobregiro. Impuesto'
              END);
      END IF;

      v_cta_count := v_cta_count + 1;
      l_cta_nro_buffer(v_cta_count) := v_nro_cta;
      l_cta_saldo_buffer(v_cta_count) := l_total_debito;
      l_cta_fecha_buffer(v_cta_count) := v_fcdehoy;
      l_cta_hora_buffer(v_cta_count) := v_hora_mov;

    END IF;
    LP_CER_LIQ_BATCH;
    LP_APL_DML_BATCH;
    LP_LIM_VARIABLES_BATCH;
  END LP_CER_CTA_BATCH;
BEGIN
  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  END;

  rv_gcale := pag_cal.fu_obt_reg_cal(4);
  v_ult_dia := rv_gcale.ult_dia_mes;
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  v_fecproxi := rv_gcale.fec_proxima;
  SELECT COUNT(*)
    INTO v_can_user
    FROM ba_cod_referencias
   WHERE dominio = 'USU_MOV_CIERRE'
     AND abreviatura = 'MOVCIERRE';
  DBMS_APPLICATION_INFO.SET_ACTION('PR_LIQ_SOB_BATCH');
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO('PR_LIQ_SOB_BATCH, Iniciando');

  OPEN cu_sob_batch;
  LOOP
    FETCH cu_sob_batch BULK COLLECT INTO v_sob_batch LIMIT v_limite;
    EXIT WHEN v_sob_batch.COUNT = 0;

    v_cant_filas := v_cant_filas + v_sob_batch.COUNT;
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(
      'PR_LIQ_SOB_BATCH, filas cargadas: ' || v_cant_filas ||
      ', fecha: ' || TO_CHAR(v_fcdehoy, 'YYYY-MM-DD'));

    FOR i IN 1 .. v_sob_batch.COUNT LOOP
      IF v_nro_cta IS NULL OR v_nro_cta <> v_sob_batch(i).nro_cuenta THEN
        IF v_nro_cta IS NOT NULL THEN
          BEGIN
            LP_CER_CTA_BATCH;
            v_cuentas_cerradas := v_cuentas_cerradas + 1;
            IF MOD(v_cuentas_cerradas, 200) = 0 THEN
              COMMIT;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              PAG_CIE.PR_INS_LOG(
                'PR_LIQ_SOB_BATCH cuenta ' || v_nro_cta || ': ' || SQLERRM ||
                ' BACKTRACE: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                PAG_CIE.c_log_INFO, 'AUTONOMOUS_TRANSACTION');
              LP_LIM_VARIABLES_BATCH;
              RAISE;
          END;
        END IF;
        v_nro_cta := v_sob_batch(i).nro_cuenta;
        v_interes_acuerdo := 0;
        v_interes_general := 0;
        v_interes_cta := 0;
        v_impuesto_cta := 0;
        v_procesar := CASE
             WHEN v_sob_batch(i).tra_prohibida = 'S'
           AND pag_cta.FU_VER_TRA_PROHIBIDA(v_nro_cta, 550) = 'S'
          THEN 'N' ELSE 'S' END;
        v_cod_oficina_cta := v_sob_batch(i).cod_oficina;
        v_cod_moneda_cta := v_sob_batch(i).cod_moneda;
        v_cod_ente_cta := v_sob_batch(i).cod_ente;
        v_cod_sub_modalidad_cta := v_sob_batch(i).cod_sub_modalidad;
        v_tas_personalizada_cta := v_sob_batch(i).tas_personalizada;
        v_cta_combinada_cta := v_sob_batch(i).cta_combinada;
        v_saldo_anterior := NULL;
        v_cuentas_calculadas := v_cuentas_calculadas + 1;
      END IF;

      IF v_liq_nro_cta IS NULL
        OR v_liq_nro_cta <> v_sob_batch(i).nro_cuenta
         OR NVL(v_liq_saldo, 0) <> NVL(v_sob_batch(i).saldo, 0) THEN
        LP_CER_LIQ_BATCH;
        v_liq_nro_cta := v_sob_batch(i).nro_cuenta;
        v_liq_fecha := v_sob_batch(i).fecha;
        v_liq_saldo := v_sob_batch(i).saldo;
        v_liq_dias := 1;
      ELSE
        v_liq_dias := v_liq_dias + 1;
      END IF;

      v_sob_count := v_sob_count + 1;
      l_sob_nro_buffer(v_sob_count) := v_sob_batch(i).nro_cuenta;
      l_sob_fecha_buffer(v_sob_count) := v_sob_batch(i).fecha;
      BEGIN
        LP_PRO_ACU_SOB_BATCH(i);
      EXCEPTION
        WHEN OTHERS THEN
          PAG_CIE.PR_INS_LOG(
            'PR_LIQ_SOB_BATCH cuenta ' || v_nro_cta ||
            ' tramo ' || TO_CHAR(v_sob_batch(i).fecha) || ': ' || SQLERRM ||
            ' BACKTRACE: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
            PAG_CIE.c_log_INFO, 'AUTONOMOUS_TRANSACTION');
          RAISE;
      END;
    END LOOP;
    v_sob_batch.DELETE;
  END LOOP;
  CLOSE cu_sob_batch;
  BEGIN
    LP_CER_CTA_BATCH;
  EXCEPTION
    WHEN OTHERS THEN
      PAG_CIE.PR_INS_LOG(
        'PR_LIQ_SOB_BATCH cuenta ' || v_nro_cta || ': ' || SQLERRM,
        PAG_CIE.c_log_INFO, 'AUTONOMOUS_TRANSACTION');
      LP_LIM_VARIABLES_BATCH;
      RAISE;
  END;
  COMMIT;

  DBMS_APPLICATION_INFO.SET_ACTION(NULL);
  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
EXCEPTION
  WHEN OTHERS THEN
    IF cu_sob_batch%ISOPEN THEN
      CLOSE cu_sob_batch;
    END IF;
    DBMS_APPLICATION_INFO.SET_ACTION(NULL);
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
    IF SQLCODE <= -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20000, 'PR_LIQ_SOB_BATCH. ' || SQLERRM);
    END IF;
END;
END PAC_SOB;
/
