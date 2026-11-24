CREATE OR REPLACE PROCEDURE IT.PRP_REN_PRE_TAS_VARIABLE(
P_NRO_CUENTA pr_cta_prestamos.nro_cuenta%type default null,
p_automatico varchar2 default null)
--Si se recibo Nro cuenta se llama de la pantalla para re-calcular
IS
 --Variables

  WW_FRANCES          NUMBER;
  WW_TASADIV          NUMBER;
  WW_VLSALAN          NUMBER(18,2);
  WW_TTCUOTA          NUMBER(18,2) := NULL;
  WW_DFCUOTA          NUMBER(18,2);
  WW_TTCAPIT          NUMBER(18,2) := 0;
  WW_TTREFUE          NUMBER(18,2) := 0;
  WW_REFREAL          NUMBER(18,2) := 0;
  WW_CTREFUE          NUMBER(6)  := 0;
  WW_NRO              NUMBER(6)  := 0;
  ww_redondeo         number(2) := 0;   -- redondeo a cero para moneda local
  ww_limite           number  := 10;  -- limite superior para ajustes de cuotas iguales en moneda local
  ww_neto             number;
  v_val_interes       number;
  v_sal_cap_anterior  number;
  v_vAL_INT_ORIGINAL  number;
  v_MTO_CAPITAL       number;
  v_per_interes       pr_sol_tasas.per_vencimiento%type;
  v_cuo_inicial       number;
  v_dias              number;
  v_val_cuota         NUMBER(18,2) := 0;
  v_can_cuotas        number;
  v_ult_cuota         number;
  v_tot_prestamo      number;
  v_fec_pri_vto       date;
  WW_ANT_VEN_FIJO     VARCHAR2(1) := 'S';
  r_pcpre             pr_cta_prestamos%rowtype;
  v_nro_solicitud     pr_solicitudes.nro_solicitud%type;
  v_plazo            pr_solicitudes.dia_plazo%type;
  v_estado           pr_cta_prestamos.estado%type;
  v_tipo             pr_cta_prestamos.tipo%type;
  v_tip_interes      pr_cta_prestamos.tip_interes%type;
  v_tip_renovacion   pr_cta_prestamos.tip_renovacion%type;
  v_tae              number(10);
  v_tan              number(10);
  v_piz_tasa_min     cr_piz_plazos.tas_minima%type;
  v_piz_tasa_max     cr_piz_plazos.tas_maxima%type;
  v_piz_tasa_actual  cr_piz_plazos.tas_interes%type;
  v_piz_tasa_tae     cr_piz_plazos.tas_efectiva%type;
  v_sal_cap_ori      pr_cuotas.sal_capital%type;
  v_sal_capital      pr_cuotas.sal_capital%type;
  v_sal_int_ori      pr_cuotas.sal_interes%type;
  v_sal_interes      pr_cuotas.sal_interes%type;
  v_dif_sal_int      pr_cuotas.sal_interes%type;
  v_sal_intautor     pr_cuotas.sal_interes%type;
  v_cal_dias         NUMBER; -- -- DYDMR-4098 Jun/2016
  ---
  v_val_tasa_nva     number(18,4);
  v_val_spread       number(18,4);
  v_val_tas_variable number(18,4);
  v_cod_persona      ba_personas.cod_persona%type;
  v_cod_periodo      pr_tas_variables.cod_periodo%type;
  v_lugar            varchar2(3000);
  v_cod_tasa_fondo   number(20);
  v_nro_cuenta       ge_cuentas.nro_cuenta%type;
  v_mto_capital_tas  pr_cta_prestamos.mto_capital%type;
  v_fec_actual       date:=pag_cal.FU_OBT_FEC_ACTUAL(6);
  v_rec_afd          ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('REC_AFD_TASA_VARIABLE'),'N');
  v_fec_afd       date;
  v_cod_sub_modalidad varchar2(10);
  v_nro_sol varchar2(100);
  v_nro_cta varchar2(100);
  v_exi_sol_cuotas      varchar2(1);
  v_cod_tas_variable VARCHAR2(20);
  WW_DIA_CALCULO     NUMBER;
  v_val_tas_piso pr_solicitudes.tas_piso%type;
  v_valor number(18,4);
  v_valor1 number(18,4);
  v_per_act_tasa varchar2(10);
  v_procesar varchar2(1):='N';
  v_fec_act_tasa date;
  v_fec_max_neg_tasa date;
  v_tas_actual number(18,4);
  v_tas_actual_v varchar2(30);

  v_prox_fec_ren date;
  v_nro_cuo_afd number(18);
  v_pri_vez    number(15);

/*Para prestamos que no son AFD*/
Cursor g_principal IS
   select a.nro_cuota,b.cod_modulo,b.cod_modalidad,b.cod_moneda,
       b.nro_solicitud, c.nro_cuenta, b.cod_persona
       from pr_tas_variables_det a, pr_tas_variables b, pr_cta_prestamos c, pr_tip_operaciones d
         where a.fec_vencimiento <= v_fec_actual
          and a.renegociacion='S'
          and a.nro_solicitud=b.nro_solicitud
          and a.nro_solicitud=c.nro_solicitud
          and a.fec_renegociacion is null
          --
          and b.cod_modulo= d.cod_modulo
          and b.cod_modalidad= d.cod_modalidad
          and b.cod_sub_modalidad= d.cod_sub_modalidad
          and d.re_calcular='S'
          and b.nro_cuenta=p_nro_cuenta
          --
          and b.nro_cuenta is not null; --Ya tiene una cuenta de prestamos

/*Para AFD*/
Cursor g_afd IS
     select  distinct c.nro_cuenta,b.cod_persona, a.nro_solicitud
       from pr_tas_variables_det a, pr_tas_variables b, pr_cta_prestamos c, pr_tip_operaciones d
        where a.fec_vencimiento <= v_fec_afd --Afd es al primero de Enero del A¿o Actual el re-calculo
          and a.nro_solicitud=b.nro_solicitud
          and a.nro_solicitud=c.nro_solicitud
          and b.cod_modulo= d.cod_modulo
          and b.cod_modalidad= d.cod_modalidad
          and b.cod_sub_modalidad= d.cod_sub_modalidad
          and d.re_calcular='N'
          and b.nro_cuenta=p_nro_cuenta
          and b.nro_cuenta is not null; --Ya tiene una cuenta de prestamos;

/*Para prestamos que no son AFD y se re-cacalcula manual*/
Cursor g_principal_nro_cta IS
    select a.nro_cuota,b.cod_modulo,b.cod_modalidad,b.cod_moneda,
       b.nro_solicitud, c.nro_cuenta, b.cod_persona
       from pr_tas_variables_det a, pr_tas_variables b, pr_cta_prestamos c, pr_tip_operaciones d
         where a.fec_vencimiento <= v_fec_actual
          and a.renegociacion='S'
          and a.nro_solicitud=b.nro_solicitud
          and a.nro_solicitud=c.nro_solicitud
          --
          and b.cod_modulo= d.cod_modulo
          and b.cod_modalidad= d.cod_modalidad
          and b.cod_sub_modalidad= d.cod_sub_modalidad
          and d.re_calcular='S'
          --
          and b.nro_cuenta = P_NRO_CUENTA
          and b.nro_cuenta is not null; --Ya tiene una cuenta de prestamos

 /*Para AFD que se re-calcula manual*/
Cursor g_afd_nro_cta IS
    select  distinct c.nro_cuenta,b.cod_persona, a.nro_solicitud
       from pr_tas_variables_det a, pr_tas_variables b, pr_cta_prestamos c, pr_tip_operaciones d
        where a.fec_vencimiento <= v_fec_afd --Afd es al primero de Enero del A¿o Actual el re-calculo
          and a.nro_solicitud=b.nro_solicitud
          and a.nro_solicitud=c.nro_solicitud
          and b.cod_modulo= d.cod_modulo
          and b.cod_modalidad= d.cod_modalidad
          and b.cod_sub_modalidad= d.cod_sub_modalidad
          and d.re_calcular='N'
          --
          and b.nro_cuenta = P_NRO_CUENTA
          and b.nro_cuenta is not null; --Ya tiene una cuenta de prestamos;

   /*Recupera la cuota a modificar*/
   PROCEDURE LP_OBT_CUOTA (p_nro_cuenta  in  VARCHAR2,
                           p_nro_cuota   in  NUMBER,
                           r_cuota       out pr_cuotas%rowtype);
   /*Inserta Log de Error*/
   PROCEDURE LP_INS_LOG_ERROR(p_fec_reproceso    in date default null,
                           p_nro_solicitud     in  varchar2 default null,
                           p_nro_cuenta        in  varchar2 default null,
                           p_lugar             in  varchar2 default null,
                           p_det_error         in  varchar2 default null
                           );
  --- Variables auxiliares
   v_vez                 number(01) := 0;
   v_redondeo            number(2);
   v_sal_cap_cuota       pr_cuotas.sal_capital%type;
   v_fec_inicio          pr_cta_prestamos.fec_inicio%type;
   v_interes             pr_cuotas.mto_interes%type;
   v_tot_dif_int         pr_cuotas.mto_interes%type;
   v_diferencia          pr_cuotas.mto_interes%type;
   v_sum_mto_cap         pr_cuotas.mto_capital%type;
   v_cod_modalidad       pr_cta_prestamos.cod_modalidad%type;
   v_cod_moneda          pr_cta_prestamos.cod_moneda%type;
   v_cod_oficina         pr_cta_prestamos.cod_oficina%type;
   v_tip_amortizacion    pr_solicitudes.tip_amortizacion%type;
   v_val_tasa_vieja      pr_cta_prestamos.val_tasa%type;
   v_val_tas_iva         pr_cta_prestamos.val_tasa%type;
   v_iva                 number;
   v_hora                ge_movimientos.hora%type;
   r_gmovi               ge_movimientos%rowtype;
   r_cuota               pr_cuotas%rowtype;
   v_secuencia           ge_movimientos.nro_secuencia%type := 1 ;
    --- Cursor de cuotas de prestamos restantes a remodificar
   cursor c_cuotas is
   select nro_cuota, o.mto_capital, o.mto_interes, o.sal_capital, o.sal_interes,
          p.sal_capital sal_cap_pre, p.sal_interes sal_int_pre, o.fec_vencimiento,
          p.cod_modalidad, p.cod_oficina, p.cod_moneda
     from pr_cuotas o, pr_cta_prestamos p
    where o.nro_cuenta = v_nro_cuenta
      --and o.fec_vencimiento >= v_fec_actual
      and o.fec_vencimiento > v_fec_actual
      and p.nro_cuenta = O.nro_cuenta
      --and o.estado = 'C'
      and o.estado <> 'N' --DYDMR-7316 y DYDMR-7300
      and o.sal_interes <> 0
    order by o.nro_cuota;

/*Recupera la cuota a modificar*/
PROCEDURE LP_OBT_CUOTA (
          p_nro_cuenta  in  VARCHAR2,
          p_nro_cuota   in  NUMBER,
          r_cuota       out pr_cuotas%rowtype)
  is
BEGIN
  select *
    into r_cuota
    from pr_cuotas p
   where p.nro_cuenta = p_nro_cuenta
     and p.nro_cuota = p_nro_cuota;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Cuota '||to_char(p_nro_cuota)||' no registrada para la cuenta '||p_nro_cuenta);
End;

/*Inserta Log de Error*/
 PROCEDURE LP_INS_LOG_ERROR(p_fec_reproceso    in date default null,
                           p_nro_solicitud     in  varchar2 default null,
                           p_nro_cuenta        in  varchar2 default null,
                           p_lugar             in  varchar2 default null,
                           p_det_error         in  varchar2 default null
                           )
  is
  PRAGMA AUTONOMOUS_TRANSACTION;
v_hora varchar2(8);
BEGIN
  v_hora:=  to_char(sysdate, 'hh24:mi:ss');
insert into pr_log_tas_variables(FECHA,nro_solicitud,nro_cuenta, lugar,
       det_error,hora,usuario,  fec_error, automatico)
values (trunc(p_fec_reproceso), p_nro_solicitud, p_nro_cuenta, p_lugar,
       p_det_error,v_hora,user,  sysdate, nvl(p_automatico,'N') );
       commit;

exception
   when others then
     null;
End;
/* Verifica si el prestamo es con Refuerzo*/
FUNCTION FU_OBT_REFUERZO RETURN VARCHAR2 IS
  v_tiene varchar2(1) := 'N';
  cursor c_sol_cuotas is
  select VAL_INT_ORIGINAL
    from PR_SOL_CUOTAS
   where NRO_CUOTA > 0
     and NRO_SOLICITUD = v_nro_solicitud
     and v_exi_sol_cuotas = 'S';
BEGIN
  FOR CUOTA IN c_sol_cuotas LOOP
    IF CUOTA.VAL_INT_ORIGINAL > 0 THEN
       v_tiene := 'S';
       EXIT;
    END IF;
  END LOOP;
  RETURN v_tiene;
END;
/* Verifica si es inhibido judicialmente*/
FUNCTION FU_ES_CLI_INHIBIDO(p_cod_persona varchar2)  RETURN VARCHAR2 IS
  v_tiene varchar2(1) := 'N';
BEGIN
  begin
   Select 'S'
     into v_tiene
       from ge_per_inhibidas b
         where  estado = 'I'
           and b.cod_persona= p_cod_persona
           and b.cod_causa=279; --279 demanda Judicial
  exception
    when no_data_found then
      v_tiene:='N';
    when too_many_rows then
      v_tiene:='S';
    when others then
      v_tiene:='N';
  end ;

  RETURN v_tiene;
END;


/* Obtiene la sumatoria de los refuerzos*/
PROCEDURE PR_SUM_REFUERZOS
  (WW_TTREFUE IN OUT NUMBER,
   WW_CTREFUE IN OUT NUMBER,
   WW_NETO IN VARCHAR2,
   WW_VEN_FIJO IN OUT VARCHAR2,
   WW_DIA_CALCULO IN OUT NUMBER
   ) IS
   WW_AJUSTE NUMBER;-- := :TOT_PRESTAMO / :PR_SOLICITUDES.MONTO;
   WW_DIA_VENCIMIENTO VARCHAR2(2);
   V_MONTO pr_solicitudes.MONTO%TYPE;
   WW_DIA_ANTERIOR    pr_cuotas.fec_vencimiento%type;
   V_CAL_DIAS         NUMBER := 0;
   V_ACU_DIAS         NUMBER := 0;
   V_CAN_CUO          NUMBER := 0;
   r_cuota               pr_cuotas%rowtype;

   CURSOR C_SOL_CUOTAS is
   select TO_CHAR(A.FEC_VTO_HABIL, 'DD') FEC_VTO_HABIL,
          VAL_INT_ORIGINAL,
          MTO_CAPITAL,
          VAL_INTERES
     from PR_SOL_CUOTAS A
    where A.NRO_SOLICITUD = V_NRO_SOLICITUD
      and v_exi_sol_cuotas = 'S'
    --Ajuste Luisa 12/2018
    union
     select TO_CHAR(c.FEC_VENCIMIENTO, 'DD') FEC_VTO_HABIL,
          0,
          MTO_CAPITAL,
          MTO_INTERES
      from pr_cuotas c
        where c.nro_cuenta = v_nro_cuenta
          and c.estado <> 'N'
         and v_exi_sol_cuotas = 'N';
 --Nuevo cursor Luisa
 CURSOR C_CUOTAS is
    select c.nro_cuenta,
           c.nro_cuota,
           c.FEC_VENCIMIENTO
      from pr_cuotas c
     where c.nro_cuenta = v_nro_cuenta
      --and c.fec_vencimiento >= p_fec_desde
      and c.fec_vencimiento > v_fec_actual
      and c.estado <> 'N'
      and c.sal_interes <> 0;


BEGIN
  BEGIN
    select NVL(TOT_PRESTAMO, 0) / NVL(monto, 1), MONTO
      INTO WW_AJUSTE, v_monto
      from pr_solicitudes
     where NRO_SOLICITUD = V_NRO_SOLICITUD;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        raise_application_error(-20000,'No existe Datos para la solicitud');
  END;
  WW_TTREFUE := 0;
  WW_CTREFUE := 0;
  -- verifico si la cantidad de cuotas esta ok ---
  BEGIN
    select TO_CHAR(A.FEC_VTO_HABIL, 'DD')
      into WW_DIA_VENCIMIENTO
      from PR_SOL_CUOTAS A
     where A.NRO_CUOTA =
           (select max(B.NRO_CUOTA)
              from PR_SOL_CUOTAS B
             where B.NRO_SOLICITUD = A.NRO_SOLICITUD)
       and A.NRO_SOLICITUD = V_NRO_SOLICITUD;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
       BEGIN
         --DYDMR-8774 Incidencia SAU - ITGF- Moficaci¿n de tasas
         select TO_CHAR(c.fec_vencimiento, 'DD')
           into WW_DIA_VENCIMIENTO
           from PR_CUOTAS c
          where c.NRO_CUOTA =
                (select max(B.NRO_CUOTA)
                   from PR_CUOTAS B
                  where B.NRO_CUENTA = c.NRO_CUENTA)
            and c.nro_cuenta = v_nro_cuenta;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000,
                                   'No existe Datos para las cuotas de la solicitud: ' ||
                                   V_NRO_SOLICITUD ||' Cuenta: '||v_nro_cuenta);
       END;
     END;
     WW_VEN_FIJO := 'S';
     FOR CUOTA IN C_SOL_CUOTAS LOOP
         IF CUOTA.VAL_INT_ORIGINAL > 0 THEN
            IF ww_neto = 'S' THEN
               CUOTA.MTO_CAPITAL := CEIL(CUOTA.MTO_CAPITAL * WW_AJUSTE);
               WW_TTREFUE := NVL(WW_TTREFUE,0) + CUOTA.MTO_CAPITAL;

            ELSE
               WW_TTREFUE := NVL(WW_TTREFUE,0) + (CUOTA.VAL_INT_ORIGINAL - NVL(CUOTA.VAL_INTERES,0));
            END IF;
            WW_CTREFUE := NVL(WW_CTREFUE,0) + 1;
         END IF;
         ---DYDMR-7700 - Incidencia SAU - ITGF - Cambio de tasas - Capital o inter¿s en negativo
         IF WW_DIA_VENCIMIENTO <> CUOTA.FEC_VTO_HABIL THEN
            WW_VEN_FIJO := 'N';
         END IF;

     END LOOP;

     ---DYDMR-7700 - Incidencia SAU - ITGF - Cambio de tasas - Capital o inter¿s en negativo
     FOR CUOTA IN C_CUOTAS LOOP
       IF WW_DIA_ANTERIOR IS NULL THEN
          LP_OBT_CUOTA(CUOTA.NRO_CUENTA, CUOTA.NRO_CUOTA - 1 , r_cuota);
          WW_DIA_ANTERIOR := r_cuota.Fec_Vencimiento;
       END IF;
          V_CAL_DIAS := (CUOTA.FEC_VENCIMIENTO - WW_DIA_ANTERIOR);
          V_ACU_DIAS := V_ACU_DIAS + V_CAL_DIAS;
          WW_DIA_ANTERIOR := CUOTA.FEC_VENCIMIENTO;
          V_CAN_CUO       := V_CAN_CUO + 1;
     END LOOP;

     WW_DIA_CALCULO := V_ACU_DIAS / V_CAN_CUO;
     IF WW_TTREFUE > V_MONTO THEN
       raise_application_error(-20000,'ERROR. El Total de Refuerzos supera al Monto del Pr¿stamo.');
     END IF;

END;


---Verificar si existe datos en pr_sol_cuotas
FUNCTION lf_ver_cuotas RETURN VARCHAR2 IS
  v_existe varchar2(1) := 'N';

BEGIN
  begin
    select distinct 'S'
      into v_existe
      from PR_SOL_CUOTAS
     where NRO_CUOTA > 0
       and NRO_SOLICITUD = v_nro_solicitud;
  exception
    when no_data_found then
      v_existe := 'N';
    when others then
      v_existe := 'S';
  end;
  RETURN v_existe;
END;

/********************
|| Proceso Principal
*********************/
BEGIN
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   -- NLS B.D.
   PRE_CAM_FOR_NUMERICO('.,');
 if p_nro_cuenta is not null and nvl(p_automatico,'N') ='S' then
 -- **** Inicio de Proceso anterior para los que no son AFD *****
 for w in g_principal loop
   v_val_tas_piso:=0;
   ww_vlsalan  := 0;
   ww_ttcapit  := 0;
   ww_refreal  := 0;
   ww_nro      := 0;
   v_val_tas_variable:=0;
   v_val_spread:=0;
   v_val_tas_variable:=0;
   v_sal_cap_ori:=0;
   v_sal_int_ori:=0;
   v_sal_intautor:=0;
   v_can_cuotas:=0;
   v_tot_prestamo:=0;
   v_fec_pri_vto:=null;
   v_cuo_inicial:=0;
   ww_redondeo:=0;
   ww_tasadiv:=0;
   ww_limite:=0;
   v_per_interes:=0;
   v_tot_prestamo:=0;
   ww_ant_ven_fijo:= null;
   ww_ttrefue:=0;
   ww_ctrefue:=0;
   ww_neto :=0;
   ww_dia_calculo:=0;
   ww_frances:=0;
   v_dias:=0;
   --
   v_nro_sol:= w.nro_solicitud;
   v_nro_cta:= w.nro_cuenta;
     v_lugar:='Al iniciar proceso. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     v_nro_cuenta:= w.nro_cuenta;
     v_tot_dif_int := 0;
     v_dif_sal_int := 0;

     /* Obtener tipo de amortizacion */
     begin
       select s.tip_amortizacion,
              p.val_tasa,
              p.nro_solicitud,
              s.dia_plazo,
              p.estado,
              p.tipo,
              p.tip_interes,
              p.tip_renovacion,
              s.tas_piso
         into v_tip_amortizacion,
              v_val_tasa_vieja,
              v_nro_solicitud,
              v_plazo,
              v_estado,
              v_tipo,
              v_tip_interes,
              v_tip_renovacion,
              v_val_tas_piso
         from pr_cta_prestamos p, pr_solicitudes s
        where s.nro_solicitud(+) = p.nro_solicitud
             and p.nro_cuenta= w.nro_cuenta;
     exception
       when no_data_found then
         v_tip_amortizacion := null;
     end;
     --Obtenemos Valores de tasa variable
     begin
       select a.cod_modalidad,
              a.cod_moneda,
              a.cod_periodo,
              a.cod_persona
         into v_cod_modalidad,
              v_cod_moneda,
              v_cod_periodo,
              v_cod_persona
         from pr_tas_variables a
        where a.nro_solicitud = w.nro_solicitud;
     exception
       when no_data_found then
          v_cod_periodo := null;
       when others then
          v_cod_periodo := null;
     end;
     --DYDMR-8774 Incidencia SAU - ITGF- Moficaci¿n de tasas
     v_exi_sol_cuotas := lf_ver_cuotas;

    
     --**************OBTENEMOS VALORES DE TASAS A APLICAR *******
     --v_val_tasa_nva:= p_val_tasa_nva;
     v_lugar:='Obtener Tasa Variable. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     PRG_OBT_VAL_TAS_VARIABLE(W.nro_solicitud,v_fec_actual,'T',NULL,NULL,NULL,v_cod_tas_variable,v_val_tas_variable) ;
     v_lugar:='Obtener Spread. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     PRG_OBT_VAL_TAS_VARIABLE(w.nro_solicitud,v_fec_actual,'S',NULL,NULL,NULL,v_cod_tas_variable,v_val_spread) ;
     v_lugar:='Tasa Nueva. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     PRG_OBT_VAL_TAS_VARIABLE(w.nro_solicitud,v_fec_actual,'F',NULL,NULL,NULL,v_cod_tas_variable,v_val_tasa_nva);
     --*************************************************************
     --Verificamos la Tasa anterior (Con la que se negocio la ultima vez)
     --*****Buscamos del Detalle de Tasa Variable
    
     --Validar Tasa piso
     v_lugar:='Validar Tasa Piso. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     if nvl(v_val_tas_piso,0) > 0 then
       if nvl(v_cod_tas_variable,'N')= 'N' then
          if v_val_tasa_nva < v_val_tas_piso then
              v_val_tasa_nva:=v_val_tas_piso;
          end if;
       end if;
     end if;
    --************ Fin de ajuste para Tasa Variable
     --***Inicio de actualizacion previa
      v_lugar:='Al actualizar tas fondos:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     --Actualizamos la tasa anterior
     update pr_tas_fondos
       set fec_hasta = v_fec_actual
     where fec_hasta is null
       and nro_cuenta = w.nro_cuenta;
    --Insertamos la tas fondo
     v_lugar:='Al insertar tas fondos:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
    --Traer secuencia
    SELECT  S_COD_TAS_FONDO.NEXTVAL
      into  v_cod_tasa_fondo
      FROM    SYS.DUAL;
    --Insertar Tabla
    Insert into Pr_tas_fondos
    (Cod_Tas_fondo, Val_tasa, Fec_desde, Nro_cuenta)
    Values
    (v_cod_tasa_fondo, v_val_tasa_nva, v_fec_actual, w.nro_cuenta);

    v_lugar:='Act fecha de Cambio de Tasa:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
    --
     begin
      select max(a.fec_vencimiento)
       into v_prox_fec_ren
        from pr_tas_variables_det a
           where a.nro_solicitud= w.nro_solicitud
             and a.renegociacion='S'
             and a.fec_renegociacion is null
             and rownum=1;
        exception
          when no_data_found then
            v_prox_fec_ren:=null;
           when others then
            v_prox_fec_ren:=null;
        end;
     --AP 2820 24/04/2012
     v_lugar:='Llamar PAP_MES.PR_OBT_CAP_INT_PRES. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     PAP_MES.PR_OBT_CAP_INT_PRES(w.nro_cuenta,v_sal_cap_ori,v_sal_int_ori,v_sal_intautor);

     --Traer los datos del prestamo
     v_lugar:='Llamar pap_pre.pr_obt_dat_prestamo. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     pap_pre.pr_obt_dat_prestamo(w.nro_cuenta, r_pcpre);
     v_lugar:='Traer Cantidad de Cuotas. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     --Traer cantidad de cuotas
     select count(*),
            sum(sal_capital), -- Jira-1692
            min(fec_vencimiento),
            min(nro_cuota)
       into v_can_cuotas, v_tot_prestamo, v_fec_pri_vto, v_cuo_inicial
       from pr_cuotas o
      where o.nro_cuenta = w.nro_cuenta
        --Se ajusta para Tasa Variable a pedido de usuario
        and o.fec_vencimiento > v_fec_actual
        --and o.estado = 'C'
        and o.estado <> 'N' --DYDMR-7316 y DYDMR-7300
        and o.sal_interes <> 0;


     If v_tip_amortizacion = 'P' then
       v_lugar:='Tipo de Redondeo. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       -- Veo el tipo de redondeo de los calculos ------------------------------------------
       ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
       If ww_redondeo != 0 then
         ww_limite   := 0.05;
       else
         ww_limite   := 1;
       End If;
       v_lugar:='Obt tasadiv. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       ww_tasadiv := /*p_val_tasa_nva*/v_val_tasa_nva / 36500;
       --Traer periodo interes
       Begin
          select s.per_vencimiento into v_per_interes
            from pr_sol_tasas s
           where nro_solicitud = r_pcpre.nro_solicitud;
       Exception
         when others then
           v_lugar:='No encuentra datos de solicitud. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
           raise_application_error(-20000,'No encuentra datos de solicitud.');
       End;
       --
       WW_VLSALAN  := v_tot_prestamo;
       --- Verifico si existen refuerzos ------------------------------------
       v_lugar:='Llamar PR_SUM_REFUERZOS. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       PR_SUM_REFUERZOS(WW_TTREFUE,WW_CTREFUE,WW_NETO, WW_ANT_VEN_FIJO, WW_DIA_CALCULO);
       -- DYDMR-3060 se implementa l¿gica utilizada en EPPROCOR
       v_lugar:='Buscar pre_personal. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       IF fug_obt_pardinamico('PRE_PERSONAL', r_pcpre.cod_modulo,
                             r_pcpre.cod_modalidad, NULL, NULL,r_pcpre.cod_sub_modalidad) = 'S' THEN
         --- El plazo debe ser exacto...
         WW_ANT_VEN_FIJO      := 'S';
       END IF;
       v_lugar:='Definir Dias. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       v_dias := WW_DIA_CALCULO;
       --
       --- calculo del valor del metodo frances -----------------------------
       v_lugar:='Calculo del valor del metodo frances. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       IF ( power( ( 1 + ( ww_tasadiv * v_dias ) ), ( v_can_cuotas - ww_ctrefue ) ) - 1 ) > 0 THEN
         ww_frances := ( ( NVL( v_tot_prestamo, 0 ) - NVL( ww_ttrefue, 0 ) ) * ww_tasadiv * v_dias ) /
                        ( power( ( 1 + ( ww_tasadiv * v_dias ) ),( v_can_cuotas - ww_ctrefue ) ) - 1 );
       ELSE
         v_lugar:='Para los casos en que la tasa = 0 para que no de division por cero. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
         --- Para los casos en que la tasa = 0 para que no de division por cero.
         ww_frances := ( ( NVL( v_tot_prestamo, 0 ) -  NVL( ww_ttrefue, 0 )) ) /
                        ( ( v_can_cuotas- ww_ctrefue ) );
       END IF;
        v_lugar:='Para v_val_cuota. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        v_val_cuota := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (0))),ww_redondeo) +
                       ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),ww_redondeo);

            --
        --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
        ----------------------------------------------------------------------
        v_lugar:='Para cargar datos. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        v_val_INTERES := 0;
        ww_vlsalan  := v_tot_PRESTAMO;
        ww_ttcapit  := 0;
        ww_refreal  := 0;
        ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
     End if;
      update pr_cta_prestamos p
       set p.fec_ren_tas = v_fec_actual, --Fecha de Cambio de Tasa
           p.fec_ren_tas_orig = v_prox_fec_ren --Pr¿xima fecha de Renegociaci¿n
     where p.nro_cuenta = w.nro_cuenta;
     for cuo in c_cuotas loop
        /* Obtener cuota actual para pasar al hist¿rico */
        v_lugar:='Obtener cuota para pasar al historico. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        LP_OBT_CUOTA(v_nro_cuenta,cuo.nro_cuota,r_cuota);
        v_lugar:='Insertar en Historico de Cuotas. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        insert into pr_cuotas_his
          (cod_tas_fondo,
           nro_cuenta,
           nro_cuota,
           mto_capital,
           fec_vencimiento,
           mto_interes,
           val_tasa,
           estado,
           sal_capital,
           sal_interes,
           prioridad,
           fec_ult_pago,
           val_recargo,
           mto_int_documentado,
           nro_documento,
           sal_int_documentado,
           dev_no_cobrado,
           dev_suspenso,
           dev_acumulado,
           mto_int_descontado,
           mto_cap_adelantado)
        values
          (v_cod_tasa_fondo,
           r_cuota.nro_cuenta,
           r_cuota.nro_cuota,
           r_cuota.mto_capital,
           r_cuota.fec_vencimiento,
           r_cuota.mto_interes,
           v_val_tasa_vieja,
           r_cuota.estado,
           r_cuota.sal_capital,
           r_cuota.sal_interes,
           r_cuota.prioridad,
           r_cuota.fec_ult_pago,
           r_cuota.val_recargo,
           r_cuota.mto_int_documentado,
           r_cuota.nro_documento,
           r_cuota.sal_int_documentado,
           r_cuota.dev_no_cobrado,
           r_cuota.dev_suspenso,
           r_cuota.dev_acumulado,
           r_cuota.mto_int_descontado,
           r_cuota.mto_cap_adelantado);
        ---
        v_lugar:='Para v_vez. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        if v_vez = 0 then
           v_vez := 1;
           v_cod_modalidad := cuo.cod_modalidad;
           v_cod_moneda    := cuo.cod_moneda;
           v_cod_oficina   := cuo.cod_oficina;
           v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null,cuo.cod_moneda);
        end if;
        v_lugar:='Para pap_dev.FU_OBT_FEC_INI_CUOT. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        v_fec_inicio := pap_dev.FU_OBT_FEC_INI_CUOTA(v_nro_cuenta, cuo.nro_cuota);
        -- Verifica es price o no.
        If v_tip_amortizacion = 'P' then
          --RI: Insertar aca el nuevo proceso para Price
          --RABF: Calculo de Cuotas Franc¿s tomado del Form EPPROCOR
          --27/dic/2010 AP n¿ 1161
          v_lugar:='Para Calculo de Cuotas Frances tomado del Form EPPROCOR. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          v_dias := cuo.fec_vencimiento - v_fec_inicio;
          v_sal_cap_anterior := ww_vlsalan;
          v_val_interes := ROUND((ww_vlsalan * ww_tasadiv * v_dias),ww_redondeo);
          v_lugar:='Para v_vAL_INT_ORIGINAL. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          IF v_vAL_INT_ORIGINAL > 0 THEN  /* es una cuota con refuerzo */
             v_lugar:='Para v_vAL_INT_ORIGINAL mayor a cero. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
             IF ww_neto = 'S' THEN
                v_MTO_CAPITAL := cuo.MTO_CAPITAL;
             ELSE
                v_mto_CAPITAL := v_VAL_INT_ORIGINAL - v_VAL_INTERES;

             END IF;
             ww_refreal := NVL(ww_refreal,0) + NVL(v_MTO_CAPITAL,0);
          ELSE
             v_lugar:='Para v_vAL_INT_ORIGINAL menor o igual cero. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
             ww_nro := ww_nro + 1;
             v_mto_CAPITAL := v_val_cuota - v_val_INTERES;

          END IF;
          v_lugar:='Para ww_dfcuota. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          ww_dfcuota :=  NVL(ww_ttcuota,v_can_cuotas) - NVL(v_can_cuotas,0);
          -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
          v_lugar:='Para ajuste de cuotas para que sean iguales . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite)
             and nvl(WW_TASADIV,0) > 0 THEN --Solo Ajustar si tasa > 0 , 21/06/2010
             v_val_INTERES := v_val_INTERES + ww_dfcuota;
          END IF;
          v_lugar:='Para carga de variables . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          ww_vlsalan := NVL(ww_vlsalan,0) - v_mto_capital;
          ww_ttcapit := NVL(ww_ttcapit,0) + nvl(v_MTO_CAPITAL,0);
          IF NVL(v_MTO_CAPITAL,0) < 0 or NVL(v_VAL_INTERES,0) < 0 THEN
             v_lugar:='ERROR. Capital o Interes no puede quedar en negativo. Verifique . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
             raise_application_error(-20000,'ERROR. Capital o Interes no puede quedar en negativo. Verifique');
          END IF;
          v_lugar:='Update pr_cuotas . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          update pr_cuotas
             set sal_interes = nvl(v_val_interes,0),
                 mto_interes = nvl(v_val_interes,0),
                 mto_capital = nvl(v_mto_capital,0),
                 sal_capital = nvl(v_mto_capital,0),
                 mto_int_descontado = 0, -- Jira-1692
                 mto_cap_adelantado = 0
           where nro_cuenta  = v_nro_cuenta
             and nro_cuota   = cuo.nro_cuota;
           --Actualizamos detalle de Tasa Variable
             update pr_tas_variables_det a
               set  a.sal_interes = nvl(v_val_interes,0),
                    a.mto_interes = nvl(v_val_interes,0),
                    a.mto_capital = nvl(v_mto_capital,0),
                    a.sal_capital = nvl(v_mto_capital,0),
                    a.tot_cuota= nvl(v_mto_capital,0) + nvl(v_val_interes,0)
               where a.nro_solicitud  = w.nro_solicitud
                  and a.nro_cuota   = cuo.nro_cuota;
          ---
          v_ult_cuota     := cuo.nro_cuota;
        ELSE
          --- Calculo de Saldo de Inter¿s
          v_lugar:='Calculo de Saldo de Interes . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          if v_vez = 1 then
            --- Solo para la primera vez el saldo capital es igual al del prestamo
            --DYDMR-7271 - Incidencia SAU - ITGF - Repactacion de Tasa
            ---Se cambia el valor enviado de cuo.sal_cap_pre debido a que este dato es el saldo capital del prestamo
            ---y no de las cuotas en cuestion
            v_sal_cap_cuota := v_tot_prestamo; ---nvl(cuo.sal_cap_pre,0);
            v_vez := 2;
            v_lugar:='Para v_fec_actual > v_fec_inicio . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
            if v_fec_actual > v_fec_inicio then
               if v_fec_inicio >= v_fec_actual then
                  v_lugar:='Obtiene la suma del capital. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
                  --- Obtiene la suma del capital
                  --- Si la fecha es futura no se considera los no vencidos
                  select sum(sal_capital)
                  into   v_sum_mto_cap
                  from   pr_cuotas
                  where  nro_cuenta = v_nro_cuenta
                  and    nro_cuota  < cuo.nro_cuota
                  and    fec_vencimiento >= v_fec_actual;
                  ---
                  v_sal_cap_cuota := v_sal_cap_cuota - nvl(v_sum_mto_cap,0);
               end if;
            End if;
            v_lugar:='Obtiene v_interes. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
            v_interes := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, v_val_tasa_nva/*p_val_tasa_nva*/),v_redondeo);
          else
            v_lugar:='Obtiene v_interes 1. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
            v_interes := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, v_val_tasa_nva/*p_val_tasa_nva*/),v_redondeo);
          end if;
          v_lugar:='Obtiene v_diferencia. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          v_diferencia := nvl(v_interes,0) - nvl(cuo.sal_interes,0);
          ---
          v_lugar:='Update pr_cuotas 11. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;

          v_valor:=0;
          v_valor1:=0;
          v_valor:=nvl(cuo.sal_interes,0) + v_diferencia;
          v_valor1:=nvl(cuo.mto_interes,0) + v_diferencia;

          update pr_cuotas
             set mto_interes = v_valor1/*nvl(cuo.mto_interes,0) + v_diferencia*/ - nvl(mto_int_descontado,0),
                 sal_interes = v_valor/*nvl(cuo.sal_interes,0) + v_diferencia*/,
                 mto_capital = sal_capital,
                 mto_int_descontado = 0, -- Jira-1692
                 mto_cap_adelantado = 0
           where nro_cuenta  = v_nro_cuenta
             and nro_cuota   = cuo.nro_cuota;


           --Actualizamos detalle de Tasa Variable
             update pr_tas_variables_det a
               set  a.sal_interes = nvl(cuo.mto_interes,0) + v_diferencia, /*- nvl(mto_int_descontado,0),*/
                    a.mto_interes = nvl(cuo.sal_interes,0) + v_diferencia,
                    a.mto_capital = sal_capital,
                    a.tot_cuota= nvl(sal_capital,0) + nvl(cuo.mto_interes,0) + v_diferencia /*- nvl(tot_int_descontado,0)*/
               where a.nro_solicitud  = w.nro_solicitud
                  and a.nro_cuota   = cuo.nro_cuota;
          ---
          v_lugar:='Para v_sal_cap_cuota . Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
          v_sal_cap_cuota := v_sal_cap_cuota - nvl(cuo.sal_capital,0);
          v_tot_dif_int   := v_tot_dif_int + v_diferencia;
        END IF;
        ---
        v_lugar:='Update pr_cta_prestamos. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        update pr_cta_prestamos
           set sal_interes = nvl(sal_interes,0) + nvl(v_diferencia,0),
               val_tasa    = v_val_tasa_nva /*p_val_tasa_nva*/
         where nro_cuenta  = v_nro_cuenta;

        --Actualizamos Tasa Variable
        update pr_tas_variables a
            set a.tas_interes= v_val_tasa_nva
           where a.nro_solicitud= w.nro_solicitud;
        ---
     end loop;

     --Update de detalle de pr¿stamo variable
      update pr_tas_variables_det a
           set a.fec_renegociacion= v_fec_actual,
               a.spread=  v_val_spread,
               a.tas_referencia= v_val_tas_variable,
               a.tas_utilizada= v_val_tasa_nva
         where nro_solicitud  = w.nro_solicitud
           and nro_cuota   = w.nro_cuota;
     --AP 2820 - 24/04/2012
     v_lugar:='Para pap_pre.pr_obt_tas_pizarra. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     pap_pre.pr_obt_tas_pizarra(r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda,
                                v_plazo, v_tot_prestamo, null,
                                v_piz_tasa_min,
                                v_piz_tasa_max,
                                v_piz_tasa_actual,
                                v_piz_tasa_tae,
                                r_pcpre.cod_sub_modalidad); -- JIRA 1559

     If nvl(v_piz_tasa_min,0) = 0 and nvl(v_piz_tasa_max,0) = 0 and nvl(v_piz_tasa_actual,0) = 0 then
        v_lugar:='Debe definir la Pizarra para el Tipo de Pr¿stamo. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
        raise_application_error(-20000, 'Debe definir la Pizarra para el Tipo de Prestamo');
     End if;
     v_lugar:='Para PAS_BCP.PR_OBT_TAS_PRESTAMO. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     PAS_BCP.PR_OBT_TAS_PRESTAMO(null,v_nro_cuenta,v_tae,v_tan);
     IF v_tae > nvl(v_piz_tasa_tae,0) then
       v_lugar:='Cuenta fuera de Rango del TAE: '||v_tae||' contra Pizarra '||v_piz_tasa_tae|| ' Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       raise_application_error(-20000, 'Cuenta fuera de Rango del TAE: '||v_tae||' contra Pizarra '||v_piz_tasa_tae);
     End if;
     --
     -- Verificar si no existe diferencia con el total del capital
     ---
     v_lugar:='Verificar si no existe diferencia con el total del capital. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     If v_tip_amortizacion = 'P' then
        ww_dfcuota := v_tot_prestamo - ww_ttcapit;
        IF ww_dfcuota <> 0 THEN
           v_mto_capital := v_mto_capital + ww_dfcuota;
           IF NVL(v_val_interes,0) >= ww_dfcuota and abs(ww_dfcuota) <= 1  /* solo se ajusta si existe interes*/
            and nvl(WW_TASADIV,0) > 0 THEN --Solo Ajustar si tasa > 0 , 21/06/2010
              v_val_interes := v_val_interes - ww_dfcuota;
           END IF;
        END IF;
        update pr_cuotas
           set sal_interes = nvl(v_val_interes,0),
               mto_interes = nvl(v_val_interes,0),
               mto_capital = nvl(v_mto_capital,0),
               sal_capital = nvl(v_mto_capital,0)
         where nro_cuenta  = v_nro_cuenta
           and nro_cuota   = v_ult_cuota;


        --Actualizamos detalle de Tasa Variable
          update pr_tas_variables_det a
           set a.sal_interes = nvl(v_val_interes,0),
               a.mto_interes = nvl(v_val_interes,0),
               a.mto_capital = nvl(v_mto_capital,0),
               a.sal_capital = nvl(v_mto_capital,0)
         where a.nro_solicitud  = w.nro_solicitud
           and a.nro_cuota   = v_ult_cuota;
     ---
     END IF;
     v_lugar:='PAP_MES.PR_OBT_CAP_INT_PRES. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
     --AP 2820 - 24/04/2012
     PAP_MES.PR_OBT_CAP_INT_PRES(v_nro_cuenta,v_sal_capital,v_sal_interes,v_sal_intautor);
     v_dif_sal_int := v_sal_interes - v_sal_int_ori;
     ---
     update pr_cta_prestamos
        set val_int_devengar = val_int_devengar + v_dif_sal_int,
            sal_capital      = v_sal_capital,
            sal_interes      = v_sal_interes
      where nro_cuenta       = v_nro_cuenta;
      ---Update de Cabecera de Tasa Variable
       update pr_tas_variables a
        set a.tot_capital      = v_sal_capital,
            a.tot_interes      = v_sal_interes,
            a.nro_cuenta       = v_nro_cuenta
      where a.nro_solicitud    = w.nro_solicitud;
      ---
     If nvl(v_dif_sal_int, 0) <> 0 then
       v_lugar:='Genero los movimientos por el devengamiento y el interes. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       --- genero los movimientos por el devengamiento y el interes ----
       --v_hora                     := to_char(sysdate,'HH24:MI:SS');
       v_hora:= null;
       v_hora := to_char(sysdate,'HH24:MI:SS');
       v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');

       r_gmovi.nro_secuencia      := v_secuencia + 1 ;
       r_gmovi.cod_usuario        := user;
       r_gmovi.hora               := v_hora;
       r_gmovi.fecha              := pag_cal.fu_obt_fec_actual(6);
       r_gmovi.cod_modulo         := 6;
       r_gmovi.cod_modalidad      := v_cod_modalidad;
       r_gmovi.cod_oficina        := v_cod_oficina;
       r_gmovi.nro_cuenta         := v_nro_cuenta;
       r_gmovi.cod_moneda         := v_cod_moneda;
       --r_gmovi.est_cuenta         := 'C';
       r_gmovi.est_cuenta         := r_pcpre.estado;--DYDMR-7316 y DYDMR-7300
       r_gmovi.cod_tra_padre      := 300;
       r_gmovi.cod_transaccion    := 719;
       r_gmovi.concepto           := 'Interes ajustado' ;
       r_gmovi.monto              := nvl(v_dif_sal_int,0);
       r_gmovi.fec_valor          := r_gmovi.fecha;
       r_gmovi.emi_aviso          := 'S';
       r_gmovi.reversado          := 'N';
       r_gmovi.protegido          := 'N';
       r_gmovi.estado             := 'N';
       r_gmovi.cod_ofi_origen     := v_cod_oficina;
       r_gmovi.cod_mod_padre      := 6;
       r_gmovi.cod_mad_padre      := v_cod_modalidad;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
     End if;
     /*
     Si el prestamo reajustado tuvo cobro de IVA sobre intereses al momento del desembolso,
     se generar¿ el cargo del IVA sobre la diferencia de intereses, solo si la tasa aplicada
     es mayor.
     */
       v_lugar:='Se generar¿ el cargo del IVA sobre la diferencia de intereses. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
       If  v_val_tasa_nva /*p_val_tasa_nva*/ > v_val_tasa_vieja
       and v_tot_dif_int > 0 then
        -- Buscar si se cobro IVA al momento del desembolso
        Begin
          Select val_tasa into v_val_tas_iva
            from gv_movimientos
           where nro_cuenta = v_nro_cuenta
             and cod_tra_padre = 358   -- desembolso
             and cod_transaccion = 709;   -- IVA sobre intereses (ver si existen otras transacciones)
           -- Calculo el iva
           v_iva  := Round(v_tot_dif_int * v_val_Tas_iva / 100,v_redondeo);
           --- genero los movimientos por el devengamiento y el interes ----
           r_gmovi.nro_secuencia      := v_secuencia + 1;
           r_gmovi.cod_usuario        := user;
           r_gmovi.hora               := v_hora;
           r_gmovi.fecha              := pag_cal.fu_obt_fec_actual(6);
           r_gmovi.cod_modulo         := 6;
           r_gmovi.cod_modalidad      := v_cod_modalidad;
           r_gmovi.cod_oficina        := v_cod_oficina;
           r_gmovi.nro_cuenta         := v_nro_cuenta;
           r_gmovi.cod_moneda         := v_cod_moneda;
           --r_gmovi.est_cuenta         := 'C';
           r_gmovi.est_cuenta         := r_pcpre.estado;--DYDMR-7316 y DYDMR-7300
           r_gmovi.cod_tra_padre      := 300;
           r_gmovi.cod_transaccion    := 709;
           r_gmovi.concepto           := 'Iva sobre Interes ajustado' ;
           r_gmovi.monto              := nvl(v_iva,0);
           r_gmovi.fec_valor          := r_gmovi.fecha;
           r_gmovi.emi_aviso          := 'S';
           r_gmovi.reversado          := 'N';
           r_gmovi.protegido          := 'N';
           r_gmovi.estado             := 'N';
           r_gmovi.cod_ofi_origen     := v_cod_oficina;
           r_gmovi.cod_mod_padre      := 6;
           r_gmovi.cod_mad_padre      := v_cod_modalidad;
           v_lugar:='Ins.Mov: Iva sobre Interes ajustado. Nro.Sol:'||w.nro_solicitud || 'Nro.Cuenta:'|| w.nro_cuenta;
           pag_gen.pr_ins_ge_movimiento(r_gmovi);
        Exception
         when others then
          null;
        End;
     End if;

 
 end loop;

   --*** Inicio de Proceso anterior para los que son AFD (prp_cam_tasas) ***
   IF nvl(v_rec_afd,'N') ='S' then
       v_secuencia:=1;
       v_fec_afd:= to_date('01/01/'||to_char(v_fec_actual,'yyyy'),'dd/mm/yyyy');
       for x in g_afd loop
         v_nro_sol:= x.nro_solicitud;
         v_nro_cta:= x.nro_cuenta;
        if FU_ES_CLI_INHIBIDO(x.cod_persona)='N' then --Es inhibido judicialmente
         v_lugar:=' Inicio de proceso AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
         v_nro_cuenta:= x.nro_cuenta;
         v_tot_dif_int := 0;
         v_dif_sal_int := 0;
         /* Obtener tipo de amortizaci¿n */
         begin
           select s.tip_amortizacion,
                  p.val_tasa,
                  p.nro_solicitud,
                  s.dia_plazo,
                  p.estado,
                  p.tipo,
                  p.tip_interes,
                  p.tip_renovacion,
                  p.cod_modalidad,
                  p.cod_moneda,
                  p.mto_capital,
                  p.cod_sub_modalidad
             into v_tip_amortizacion,
                  v_val_tasa_vieja,
                  v_nro_solicitud,
                  v_plazo,
                  v_estado,
                  v_tipo,
                  v_tip_interes,
                  v_tip_renovacion,
                  v_cod_modalidad,
                  v_cod_moneda,
                  v_mto_capital_tas,
                  v_cod_sub_modalidad
             from pr_cta_prestamos p, pr_solicitudes s
            where p.nro_cuenta = v_nro_cuenta
              and s.nro_solicitud(+) = p.nro_solicitud;
         exception
           when no_data_found then
             v_tip_amortizacion := null;
         end;
         --DYDMR-8774 Incidencia SAU - ITGF- Moficaci¿n de tasas
         v_exi_sol_cuotas := 'N';
         v_exi_sol_cuotas := lf_ver_cuotas;
         --Ajuste para tasa variable
         v_lugar:='Obt.Tasa a aplicar AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;

         --Obtenemos la tasa actual del prestamo
          v_piz_tasa_min:=null;
          v_piz_tasa_max:=null;
          v_piz_tasa_tae:=null;
          /*begin
            pap_pre.pr_obt_tas_pizarra(6, v_cod_modalidad, v_cod_moneda,
                                      v_plazo, v_mto_capital_tas, null,
                                      v_piz_tasa_min,
                                      v_piz_tasa_max,
                                      v_val_tasa_nva,  --Tasa Nueva a ser tomada
                                      v_piz_tasa_tae,
                                      v_cod_sub_modalidad\* r_pcpre.cod_sub_modalidad*\);
          exception
            when others then
              v_lugar:='Obtener Tasa de Pizarra. AFD Nro.Sol:'||x.nro_solicitud || ' Nro.Cuenta:'|| x.nro_cuenta||' Monto:'||v_mto_capital_tas||' Plazo:'||v_plazo ;
              raise_application_error(-20000,'No encuentra tasa de Pizarra AFD-'||SQLERRM);
          end;*/
            --v_val_tasa_nva:= p_val_tasa_nva;
         --Ajuste a pedido de Usuario 10/12/2018
         v_lugar:='AFD-Obtener Tasa Variable. Nro.Sol:'||X.nro_solicitud || 'Nro.Cuenta:'|| X.nro_cuenta;
         PRG_OBT_VAL_TAS_VARIABLE(X.nro_solicitud,v_fec_actual,'T',NULL,NULL,NULL,v_cod_tas_variable,v_val_tas_variable) ;
         v_lugar:='AFD-Obtener Spread. Nro.Sol:'||X.nro_solicitud || 'Nro.Cuenta:'|| X.nro_cuenta;
         PRG_OBT_VAL_TAS_VARIABLE(X.nro_solicitud,v_fec_actual,'S',NULL,NULL,NULL,v_cod_tas_variable,v_val_spread) ;
         v_lugar:='AFD-Tasa Nueva. Nro.Sol:'||X.nro_solicitud || 'Nro.Cuenta:'|| X.nro_cuenta;
         PRG_OBT_VAL_TAS_VARIABLE(X.nro_solicitud,v_fec_actual,'F',NULL,NULL,NULL,v_cod_tas_variable,v_val_tasa_nva);

         --fIN DE AJUSTE
           --***Inicio de actualizacion previa
            v_lugar:='Al actualizar tas fondos:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
               --Actualizamos la tasa anterior
               update pr_tas_fondos
                 set fec_hasta = v_fec_actual
               where fec_hasta is null
                 and nro_cuenta = x.nro_cuenta;
              --Insertamos la tas fondo
               v_lugar:='Al insertar tas fondos:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
              --Traer secuencia
              SELECT  S_COD_TAS_FONDO.NEXTVAL
                into  v_cod_tasa_fondo
                FROM    SYS.DUAL;
              --Insertar Tabla
              Insert into Pr_tas_fondos
              (Cod_Tas_fondo, Val_tasa, Fec_desde, Nro_cuenta)
              Values
              (v_cod_tasa_fondo, v_val_tasa_nva, v_fec_actual, x.nro_cuenta);

              v_lugar:='Act fecha de Cambiod e Tasa:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
               begin
          select max(a.fec_vencimiento)
           into v_prox_fec_ren
            from pr_tas_variables_det a
               where a.nro_solicitud= x.nro_solicitud
                 and a.renegociacion='S'
                 and a.fec_renegociacion is null
                 and rownum=1;
            exception
              when no_data_found then
                v_prox_fec_ren:=null;
               when others then
                v_prox_fec_ren:=null;
            end;
        --
        update pr_cta_prestamos p
           set p.fec_ren_tas = v_fec_actual, --Fecha de Cambio de Tasa
               p.fec_ren_tas_orig = v_prox_fec_ren --Pr¿xima fecha de Renegociaci¿n
         where p.nro_cuenta =x.nro_cuenta;
              --***FIN de actualizacion previa

         --AP 2820 24/04/2012
         v_lugar:=' Llamar pap_mes.pr_obt_cap_int_pres AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
         PAP_MES.PR_OBT_CAP_INT_PRES(v_nro_cuenta,v_sal_cap_ori,v_sal_int_ori,v_sal_intautor);

         --Traer los datos del prestamo
         v_lugar:=' Llamar a  pap_pre.pr_obt_dat_prestamo AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
         pap_pre.pr_obt_dat_prestamo(v_nro_cuenta, r_pcpre);

         --Traer cantidad de cuotas
         select count(*),
                sum(sal_capital), -- Jira-1692
                min(fec_vencimiento),
                min(nro_cuota)
           into v_can_cuotas, v_tot_prestamo, v_fec_pri_vto, v_cuo_inicial
           from pr_cuotas o
          where o.nro_cuenta = v_nro_cuenta
            --and o.fec_vencimiento >= v_fec_actual
            and o.fec_vencimiento > v_fec_actual
            --and o.estado = 'C'
            and o.estado <> 'N' --DYDMR-7316 y DYDMR-7300
            and o.sal_interes <> 0;

         If v_tip_amortizacion = 'P' then
           -- Veo el tipo de redondeo de los calculos ------------------------------------------
           v_lugar:=' Redondeo tip_amort=P AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
           ww_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda, r_pcpre.cod_oficina);
           If ww_redondeo != 0 then
             ww_limite   := 0.05;
           else
             ww_limite   := 1;
           End If;
           ww_tasadiv := v_val_tasa_nva / 36500;
           --Traer periodo interes
           Begin
              select s.per_vencimiento into v_per_interes
                from pr_sol_tasas s
               where nro_solicitud = r_pcpre.nro_solicitud;
           Exception
             when others then
                 v_lugar:='No encuentra datos de solicitud. AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
                 raise_application_error(-20000,'No encuentra datos de solicitud.');
           End;
           --
           WW_VLSALAN  := v_tot_prestamo;
           --- Verifico si existen refuerzos ------------------------------------
           v_lugar:='Sum refuerzos. AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
           PR_SUM_REFUERZOS(WW_TTREFUE,WW_CTREFUE,WW_NETO, WW_ANT_VEN_FIJO, WW_DIA_CALCULO);
           -- DYDMR-3060 se implementa l¿gica utilizada en EPPROCOR

           IF fug_obt_pardinamico('PRE_PERSONAL', r_pcpre.cod_modulo,
                                 r_pcpre.cod_modalidad, NULL, NULL,r_pcpre.cod_sub_modalidad) = 'S' THEN
             --- El plazo debe ser exacto...
             WW_ANT_VEN_FIJO      := 'S';
           END IF;
           v_lugar:='Per interes 30. AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
           --
           /*if v_per_interes = 30 and WW_ANT_VEN_FIJO = 'S' then
              v_dias := 30.416666666666666666666666666667;
           else
              v_dias := v_per_interes;
           end if;¿*/
           v_dias := WW_DIA_CALCULO;
           --
           --- calculo del valor del metodo frances -----------------------------
           v_lugar:=' calculo del valor del metodo frances. AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
           IF ( power( ( 1 + ( ww_tasadiv * v_dias ) ), ( v_can_cuotas - ww_ctrefue ) ) - 1 ) > 0 THEN
             ww_frances := ( ( NVL( v_tot_prestamo, 0 ) - NVL( ww_ttrefue, 0 ) ) * ww_tasadiv * v_dias ) /
                            ( power( ( 1 + ( ww_tasadiv * v_dias ) ),( v_can_cuotas - ww_ctrefue ) ) - 1 );
           ELSE
             --- Para los casos en que la tasa = 0 para que no de division por cero.
             ww_frances := ( ( NVL( v_tot_prestamo, 0 ) -  NVL( ww_ttrefue, 0 )) ) /
                            ( ( v_can_cuotas- ww_ctrefue ) );
           END IF;
            v_val_cuota := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (0))),ww_redondeo) +
                           ROUND((ww_vlsalan * ww_tasadiv * (v_dias)),ww_redondeo);
           --DYDMR-7700 - Incidencia SAU - ITGF - Cambio de tasas - Capital o inter¿s en negativo
            /*if v_per_interes = 30 \*and WW_ANT_VEN_FIJO = 'S'*\  then
               -- DYDMR-4098 Jun/2016
               if WW_ANT_VEN_FIJO = 'S' then
                  v_cal_dias := NULL;
               else
                  v_cal_dias := v_dias;
               end if;
               v_lugar:=' fup_obt_val_cuota. AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
               v_val_cuota := fup_obt_val_cuota(r_pcpre.cod_modalidad,
                                         r_pcpre.cod_moneda,
                                         v_tot_prestamo,
                                         v_can_cuotas,
                                         v_val_tasa_nva,
                                         v_fec_actual,
                                         v_fec_pri_vto,
                                         v_cal_dias); -- DYDMR-4098 Jun/2016

            end if;*/
            --
            --- Veo el monto fijo de cuota si es de tipo Prestamos flexibles -----
            ----------------------------------------------------------------------
            v_val_INTERES := 0;
            ww_vlsalan  := v_tot_PRESTAMO;
            ww_ttcapit  := 0;
            ww_refreal  := 0;
            ww_nro      := 0;  /* acumulador de cuotas calculadas automaticamente, sin refuerzo */
         End if;
         v_pri_vez:=0;
         for cuo in c_cuotas loop
           v_pri_vez:= nvl(v_pri_vez,0)+1;
            /* Obtener cuota actual para pasar al hist¿rico */
           v_lugar:=' Obtener cuota actual para pasar al hist¿rico- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
           LP_OBT_CUOTA(v_nro_cuenta,cuo.nro_cuota,r_cuota);
            insert into pr_cuotas_his
              (cod_tas_fondo,
               nro_cuenta,
               nro_cuota,
               mto_capital,
               fec_vencimiento,
               mto_interes,
               val_tasa,
               estado,
               sal_capital,
               sal_interes,
               prioridad,
               fec_ult_pago,
               val_recargo,
               mto_int_documentado,
               nro_documento,
               sal_int_documentado,
               dev_no_cobrado,
               dev_suspenso,
               dev_acumulado,
               mto_int_descontado,
               mto_cap_adelantado)
            values
              (v_cod_tasa_fondo,
               r_cuota.nro_cuenta,
               r_cuota.nro_cuota,
               r_cuota.mto_capital,
               r_cuota.fec_vencimiento,
               r_cuota.mto_interes,
               v_val_tasa_vieja,
               r_cuota.estado,
               r_cuota.sal_capital,
               r_cuota.sal_interes,
               r_cuota.prioridad,
               r_cuota.fec_ult_pago,
               r_cuota.val_recargo,
               r_cuota.mto_int_documentado,
               r_cuota.nro_documento,
               r_cuota.sal_int_documentado,
               r_cuota.dev_no_cobrado,
               r_cuota.dev_suspenso,
               r_cuota.dev_acumulado,
               r_cuota.mto_int_descontado,
               r_cuota.mto_cap_adelantado);
            ---
            if v_vez = 0 then
               v_vez := 1;
               v_cod_modalidad := cuo.cod_modalidad;
               v_cod_moneda    := cuo.cod_moneda;
               v_cod_oficina   := cuo.cod_oficina;
               v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,null,cuo.cod_moneda);
            end if;
            v_fec_inicio := pap_dev.FU_OBT_FEC_INI_CUOTA(v_nro_cuenta, cuo.nro_cuota);
            --Actualizamos Tasa Variable
            update pr_tas_variables a
                set a.tas_interes= v_val_tasa_nva
               where a.nro_solicitud= x.nro_solicitud;
            -- Verifica es price o no.
            If v_tip_amortizacion = 'P' then
              --RI: Insertar aca el nuevo proceso para Price
              --RABF: Calculo de Cuotas Franc¿s tomado del Form EPPROCOR
              --27/dic/2010 AP n¿ 1161
              v_lugar:='Calculo de Cuotas Franc¿s tomado del Form EPPROCOR- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
              v_dias := cuo.fec_vencimiento - v_fec_inicio;
              v_sal_cap_anterior := ww_vlsalan;
              v_val_interes := ROUND((ww_vlsalan * ww_tasadiv * v_dias),ww_redondeo);
              IF v_vAL_INT_ORIGINAL > 0 THEN  /* es una cuota con refuerzo */
                 IF ww_neto = 'S' THEN
                    v_MTO_CAPITAL := cuo.MTO_CAPITAL;
                 ELSE
                    v_mto_CAPITAL := v_VAL_INT_ORIGINAL - v_VAL_INTERES;

                 END IF;
                 ww_refreal := NVL(ww_refreal,0) + NVL(v_MTO_CAPITAL,0);
              ELSE
                 ww_nro := ww_nro + 1;
                 v_mto_CAPITAL := v_val_cuota - v_val_INTERES;
                 --Ajuste Luisa 12/2018 Se comenta inferior, se agrega superior
                 /*
                 IF cuo.nro_CUOTA = v_cuo_inicial AND ABS(v_PER_INTERES - (v_fec_PRI_vto - v_fec_inicio)) > 2 THEN
                    v_mto_CAPITAL := ROUND((ww_frances * power((1 + (ww_tasadiv * v_dias)), (ww_nro - 1))),ww_redondeo);
                 ELSE
                    -- BBVASOP-1207. CB 09/07/2012
                    v_var := 0;
                    WHILE v_val_interes > v_val_cuota LOOP
                       v_var := v_var + 1;
                       v_val_interes := ROUND((ww_vlsalan * ww_tasadiv * (v_dias - v_var)),ww_redondeo);
                    END LOOP;
                    v_mto_CAPITAL := v_val_cuota - v_val_INTERES;
                 END IF;*/

              END IF;

              ww_dfcuota :=  NVL(ww_ttcuota,v_can_cuotas) - NVL(v_can_cuotas,0);
              v_lugar:='ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite- AFD Nro.Sol:'||x.nro_solicitud || ' Nro.Cuenta:'|| x.nro_cuenta;

              -- ajuste de cuotas para que sean iguales solo se hace si esta dentro del limite
              IF (ABS(ww_dfcuota) BETWEEN 0.001 AND ww_limite)
                 and nvl(WW_TASADIV,0) > 0 THEN --Solo Ajustar si tasa > 0 , 21/06/2010
                 v_val_INTERES := v_val_INTERES + ww_dfcuota;
              END IF;
              ww_vlsalan := NVL(ww_vlsalan,0) - v_mto_capital;
              ww_ttcapit := NVL(ww_ttcapit,0) + nvl(v_MTO_CAPITAL,0);
              IF NVL(v_MTO_CAPITAL,0) < 0 or NVL(v_VAL_INTERES,0) < 0 THEN
                 raise_application_error(-20000,'ERROR. Capital o Interes no puede quedar en negativo. Verifique');
                 v_lugar:='ERROR. Capital o Interes no puede quedar en negativo. Verifique- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;

              END IF;

              update pr_cuotas
                 set sal_interes = nvl(v_val_interes,0),
                     mto_interes = nvl(v_val_interes,0),
                     mto_capital = nvl(v_mto_capital,0),
                     sal_capital = nvl(v_mto_capital,0),
                     mto_int_descontado = 0, -- Jira-1692
                     mto_cap_adelantado = 0
               where nro_cuenta  = v_nro_cuenta
                 and nro_cuota   = cuo.nro_cuota;

              ---
               --Actualizamos detalle de Tasa Variable
                 update pr_tas_variables_det a
                   set  a.sal_interes = nvl(v_val_interes,0),
                        a.mto_interes = nvl(v_val_interes,0),
                        a.mto_capital = nvl(v_mto_capital,0),
                        a.sal_capital = nvl(v_mto_capital,0),
                        a.tot_cuota= nvl(v_mto_capital,0) + nvl(v_val_interes,0)
                   where a.nro_solicitud  = X.nro_solicitud
                      and a.nro_cuota   = cuo.nro_cuota;
              v_ult_cuota     := cuo.nro_cuota;
            ELSE
              --- Calculo de Saldo de Inter¿s
              if v_vez = 1 then
                --- Solo para la primera vez el saldo capital es igual al del prestamo
                --DYDMR-7271 - Incidencia SAU - ITGF - Repactacion de Tasa
                ---Se cambia el valor enviado de cuo.sal_cap_pre debido a que este dato es el saldo capital del prestamo
                ---y no de las cuotas en cuestion
                v_sal_cap_cuota := v_tot_prestamo; ---nvl(cuo.sal_cap_pre,0);
                v_vez := 2;
                v_lugar:='Solo para la primera vez el saldo capital es igual al del prestamo- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
                if v_fec_actual > v_fec_inicio then
                   if v_fec_inicio >= v_fec_actual then
                      --- Obtiene la suma del capital
                      --- Si la fecha es futura no se considera los no vencidos
                      select sum(sal_capital)
                      into   v_sum_mto_cap
                      from   pr_cuotas
                      where  nro_cuenta = v_nro_cuenta
                      and    nro_cuota  < cuo.nro_cuota
                      and    fec_vencimiento >= v_fec_actual;
                      ---
                      v_sal_cap_cuota := v_sal_cap_cuota - nvl(v_sum_mto_cap,0);
                   end if;
                End if;
                   v_interes := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, v_val_tasa_nva),v_redondeo);
              else
                v_interes := ROUND(pap_int.FU_CAL_INTERES(v_fec_inicio, cuo.fec_vencimiento-1, v_sal_cap_cuota, null, v_val_tasa_nva),v_redondeo);
              end if;
              v_diferencia := nvl(v_interes,0) - nvl(cuo.sal_interes,0);
              ---
              update pr_cuotas
                 set mto_interes = nvl(cuo.mto_interes,0) + v_diferencia - nvl(mto_int_descontado,0),
                     sal_interes = nvl(cuo.sal_interes,0) + v_diferencia,
                     mto_capital = sal_capital,
                     mto_int_descontado = 0, -- Jira-1692
                     mto_cap_adelantado = 0
               where nro_cuenta  = v_nro_cuenta
                 and nro_cuota   = cuo.nro_cuota;
              ---
               --Actualizamos detalle de Tasa Variable
                 update pr_tas_variables_det a
                   set  a.sal_interes = nvl(cuo.mto_interes,0) + v_diferencia, /*- nvl(mto_int_descontado,0),*/
                        a.mto_interes = nvl(cuo.sal_interes,0) + v_diferencia,
                        a.mto_capital = sal_capital,
                        --a.mto_int_descontado = 0, -- Jira-1692
                        --a.mto_cap_adelantado = 0,
                        a.tot_cuota= nvl(sal_capital,0) + nvl(cuo.mto_interes,0) + v_diferencia /*- nvl(tot_int_descontado,0)*/
                   where a.nro_solicitud  = X.nro_solicitud
                      and a.nro_cuota   = cuo.nro_cuota;

              v_sal_cap_cuota := v_sal_cap_cuota - nvl(cuo.sal_capital,0);
              v_tot_dif_int   := v_tot_dif_int + v_diferencia;
            END IF;
            ---
            update pr_cta_prestamos
               set sal_interes = nvl(sal_interes,0) + nvl(v_diferencia,0),
                   val_tasa    = v_val_tasa_nva
             where nro_cuenta  = v_nro_cuenta;
            ---
             --Actualizamos AFD solo una vez
              if v_pri_vez = 1 then
                 --Actualizamos los datos de la cuota que se renegocio para AFD
                   update pr_tas_variables_det a
                     set a.fec_renegociacion= v_fec_actual,
                         a.spread=  v_val_spread,
                         a.tas_referencia= v_val_tas_variable,
                         a.tas_utilizada= v_val_tasa_nva
                   where nro_solicitud  = x.nro_solicitud
                     and nro_cuota   = cuo.nro_cuota;
              end if;

         end loop;


         --AP 2820 - 24/04/2012
         v_lugar:='ERROR. pap_pre.pr_obt_tas_pizarra- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
         pap_pre.pr_obt_tas_pizarra(r_pcpre.cod_modulo, r_pcpre.cod_modalidad, r_pcpre.cod_moneda,
                                    v_plazo, v_tot_prestamo, null,
                                    v_piz_tasa_min,
                                    v_piz_tasa_max,
                                    v_piz_tasa_actual,
                                    v_piz_tasa_tae,
                                    r_pcpre.cod_sub_modalidad); -- JIRA 1559

         If nvl(v_piz_tasa_min,0) = 0 and nvl(v_piz_tasa_max,0) = 0 and nvl(v_piz_tasa_actual,0) = 0 then
            raise_application_error(-20000, 'Debe definir la Pizarra para el Tipo de Pr¿stamo');
         End if;
         v_lugar:='PAS_BCP.PR_OBT_TAS_PRESTAMO- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;

         PAS_BCP.PR_OBT_TAS_PRESTAMO(null,v_nro_cuenta,v_tae,v_tan);
         IF v_tae > nvl(v_piz_tasa_tae,0) then
           v_lugar:='Cuenta fuera de Rango del TAE- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
           raise_application_error(-20000, 'Cuenta fuera de Rango del TAE: '||v_tae||' contra Pizarra '||v_piz_tasa_tae);
         End if;
         --
         -- Verificar si no existe diferencia con el total del capital
         ---
         If v_tip_amortizacion = 'P' then
            ww_dfcuota := v_tot_prestamo - ww_ttcapit;
            IF ww_dfcuota <> 0 THEN
               v_mto_capital := v_mto_capital + ww_dfcuota;
               IF NVL(v_val_interes,0) >= ww_dfcuota and abs(ww_dfcuota) <= 1  /* solo se ajusta si existe interes*/
                and nvl(WW_TASADIV,0) > 0 THEN --Solo Ajustar si tasa > 0 , 21/06/2010
                  v_val_interes := v_val_interes - ww_dfcuota;
               END IF;
            END IF;
            update pr_cuotas
               set sal_interes = nvl(v_val_interes,0),
                   mto_interes = nvl(v_val_interes,0),
                   mto_capital = nvl(v_mto_capital,0),
                   sal_capital = nvl(v_mto_capital,0)
             where nro_cuenta  = v_nro_cuenta
               and nro_cuota   = v_ult_cuota;

              --Actualizamos detalle de Tasa Variable
              update pr_tas_variables_det a
               set a.sal_interes = nvl(v_val_interes,0),
                   a.mto_interes = nvl(v_val_interes,0),
                   a.mto_capital = nvl(v_mto_capital,0),
                   a.sal_capital = nvl(v_mto_capital,0)
             where a.nro_solicitud  = x.nro_solicitud
               and a.nro_cuota   = v_ult_cuota;
         ---
         END IF;
         --AP 2820 - 24/04/2012
         v_lugar:='PAP_MES.PR_OBT_CAP_INT_PRES- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
         PAP_MES.PR_OBT_CAP_INT_PRES(v_nro_cuenta,v_sal_capital,v_sal_interes,v_sal_intautor);
         v_dif_sal_int := v_sal_interes - v_sal_int_ori;
         ---
         update pr_cta_prestamos
            set val_int_devengar = val_int_devengar + v_dif_sal_int,
                sal_capital      = v_sal_capital,
                sal_interes      = v_sal_interes
          where nro_cuenta       = v_nro_cuenta;
          ---
         If nvl(v_dif_sal_int, 0) <> 0 then
           --- genero los movimientos por el devengamiento y el interes ----
           v_hora:= null;
           v_hora := to_char(sysdate,'HH24:MI:SS');
           v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
           r_gmovi.nro_secuencia      := v_secuencia + 1 ;
           r_gmovi.cod_usuario        := user;
           r_gmovi.hora               := v_hora;
           r_gmovi.fecha              := pag_cal.fu_obt_fec_actual(6);
           r_gmovi.cod_modulo         := 6;
           r_gmovi.cod_modalidad      := v_cod_modalidad;
           r_gmovi.cod_oficina        := v_cod_oficina;
           r_gmovi.nro_cuenta         := v_nro_cuenta;
           r_gmovi.cod_moneda         := v_cod_moneda;
           --r_gmovi.est_cuenta         := 'C';
           r_gmovi.est_cuenta         := r_pcpre.estado;--DYDMR-7316 y DYDMR-7300
           r_gmovi.cod_tra_padre      := 300;
           r_gmovi.cod_transaccion    := 719;
           r_gmovi.concepto           := 'Interes ajustado' ;
           r_gmovi.monto              := nvl(v_dif_sal_int,0);
           r_gmovi.fec_valor          := r_gmovi.fecha;
           r_gmovi.emi_aviso          := 'S';
           r_gmovi.reversado          := 'N';
           r_gmovi.protegido          := 'N';
           r_gmovi.estado             := 'N';
           r_gmovi.cod_ofi_origen     := v_cod_oficina;
           r_gmovi.cod_mod_padre      := 6;
           r_gmovi.cod_mad_padre      := v_cod_modalidad;
          v_lugar:='Ins ge_movimiento- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
         End if;
         /*
         Si el prestamo reajustado tuvo cobro de IVA sobre intereses al momento del desembolso,
         se generar¿ el cargo del IVA sobre la diferencia de intereses, solo si la tasa aplicada
         es mayor.
         */
           If  v_val_tasa_nva > v_val_tasa_vieja
           and v_tot_dif_int > 0 then
            -- Buscar si se cobro IVA al momento del desembolso
            Begin
              Select val_tasa into v_val_tas_iva
                from gv_movimientos
               where nro_cuenta = v_nro_cuenta
                 and cod_tra_padre = 358   -- desembolso
                 and cod_transaccion = 709;   -- IVA sobre intereses (ver si existen otras transacciones)
               -- Calculo el iva
               v_iva  := Round(v_tot_dif_int * v_val_Tas_iva / 100,v_redondeo);
               --- genero los movimientos por el devengamiento y el interes ----
               r_gmovi.nro_secuencia      := v_secuencia + 1;
               r_gmovi.cod_usuario        := user;
               r_gmovi.hora               := v_hora;
               r_gmovi.fecha              := pag_cal.fu_obt_fec_actual(6);
               r_gmovi.cod_modulo         := 6;
               r_gmovi.cod_modalidad      := v_cod_modalidad;
               r_gmovi.cod_oficina        := v_cod_oficina;
               r_gmovi.nro_cuenta         := v_nro_cuenta;
               r_gmovi.cod_moneda         := v_cod_moneda;
               --r_gmovi.est_cuenta         := 'C';
               r_gmovi.est_cuenta         := r_pcpre.estado;--DYDMR-7316 y DYDMR-7300
               r_gmovi.cod_tra_padre      := 300;
               r_gmovi.cod_transaccion    := 709;
               r_gmovi.concepto           := 'Iva sobre Interes ajustado' ;
               r_gmovi.monto              := nvl(v_iva,0);
               r_gmovi.fec_valor          := r_gmovi.fecha;
               r_gmovi.emi_aviso          := 'S';
               r_gmovi.reversado          := 'N';
               r_gmovi.protegido          := 'N';
               r_gmovi.estado             := 'N';
               r_gmovi.cod_ofi_origen     := v_cod_oficina;
               r_gmovi.cod_mod_padre      := 6;
               r_gmovi.cod_mad_padre      := v_cod_modalidad;
               v_lugar:='Ins ge_movimiento 2- AFD Nro.Sol:'||x.nro_solicitud || 'Nro.Cuenta:'|| x.nro_cuenta;
               pag_gen.pr_ins_ge_movimiento(r_gmovi);
            Exception
             when others then
              null;
            End;
         End if;

       end if;
       END LOOP;

    end if;
    --****FIN DE AFD ****************************************
 end if;



EXCEPTION
  WHEN OTHERS THEN
    if P_NRO_CUENTA is not null and nvl(p_automatico,'N')='S' then
      LP_INS_LOG_ERROR(sysdate,v_nro_sol,v_nro_cta,v_lugar,sqlerrm);
    end if;

END;
/

