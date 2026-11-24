CREATE OR REPLACE PROCEDURE IT.PRT_TAR_ADELANTO (p_cod_persona         in ge_cta_clientes.cod_persona%type,
                                             p_nro_cuenta          in ge_movimientos.nro_cuenta%type,
                                             p_cod_moneda          in ge_movimientos.cod_moneda%type,
                                             p_nro_tarjeta         in ta_tarjetas.nro_tarjeta%type,
                                             p_cod_modalidad       in ge_movimientos.cod_modalidad%type,
                                             p_cod_oficina         in ge_movimientos.cod_oficina%type,
                                             p_monto               in ge_movimientos.monto%type,
                                             p_nro_autorizacion    in ge_movimientos.nro_documento%type,
                                             p_nro_cta_credito     in ge_movimientos.nro_cuenta%type,
                                             p_cod_mon_cta_credito in ge_movimientos.cod_moneda%type,
                                             p_usuario             in ge_movimientos.cod_usuario%type,
                                             p_plazo               in number,
                                             p_cargos              in varchar2,
                                             p_nro_caja            in ge_movimientos.nro_caja%type default null) IS
  /* --Parámetros-- 
  p_cod_persona :     Código de persona.
  p_nro_cuenta :      Número de cuenta.
  p_cod_moneda :      Código de moneda de la cuenta.
  p_nro_tarjeta :     Número de tarjeta.
  p_cod_modalidad :   Código de la modalidad de la tarjeta.
  p_cod_oficina :     Código de la oficina.
  p_monto :           Monto a ser acreditado.
  p_nro_autorizacion :Número de Autorización.
  p_nro_cta_credito : Número de Cuenta en la cual será realizado el crédito.
  p_cod_mon_cta_credito : Código de la moneda correspondiente a la cuenta para el crédito.
  p_plazo :           Plazo del crédito.
  p_cargos :          Será aplicado o no cargos. Generar 'S':Sí, 'N':No.
  */
  v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
  v_val_tas_cargo    ge_movimientos.val_tasa%type;
  v_val_cargo        ge_movimientos.val_tasa%type;
  v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
  v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
  v_val_tas_impuesto ge_movimientos.val_tasa%type;
  v_val_impuesto     ge_movimientos.val_tasa%type;
  v_cod_ofi_origen   ge_movimientos.cod_ofi_origen%type;
  v_cargo            number;
  v_total            number;
  v_nro_secuencia    number(3) := 0;
  v_cod_transaccion  ge_movimientos.cod_transaccion%type;
  v_hor_actual       varchar2(08) := to_char(sysdate, 'HH24:MI:SS');
  v_fcdehoy          ge_movimientos.fecha%type;
  r_gmovi            ge_movimientos%rowtype;

  v_horario       varchar2(1) := 'D'; -- Dia normal
  v_es_mov_noc    varchar2(1) := 'N'; -- Graba S/N mov nocturnos
  v_es_cta_noc    varchar2(1) := 'N'; -- Graba S/N ctas noctunas
  v_fec_actual    date := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
  v_ult_cierre    date;
  v_fec_valor     date := v_fec_actual;
  v_cod_respuesta varchar2(03) := '000'; -- respuesta

  -- devuelve el indicador del horario de
  procedure lp_ver_horario is
    v_est_modulo ba_modulos.estado%type;
  begin
    v_horario    := 'D'; -- Dia normal
    v_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
    v_es_cta_noc := 'N';
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);
  
    If v_est_modulo in (6) Then
      -- En cierre.
      v_cod_respuesta := paw_bce.v_cod_sis_cierre;
    elsif v_est_modulo = 2 Then
      -- El modulo esta abierto
      -- Verifica la hora --
      if sysdate > v_ult_cierre and trunc(v_ult_cierre) = v_fec_actual then
        v_horario    := 'T'; -- Tarde
        v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual + 1,1, v_cod_ofi_origen);
        v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      end if;
    else
      v_horario := 'N'; -- Noche
      if v_est_modulo <> 1 then
        v_fec_actual := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual + 1, 1, v_cod_ofi_origen);
      end if;
      v_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
      v_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
    end if;
    v_fec_valor       := trunc(sysdate); --v_fec_actual;
    pag_cta.g_horario := v_horario;
  end lp_ver_horario;

BEGIN
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;
  --
  lp_ver_horario;
  --
  v_cod_ofi_origen := fug_obt_ofi_usuario(p_usuario);
  v_fcdehoy        := v_fec_actual;--pae_cnf.fu_obt_fec_actual(5);
  --
  if p_monto is null or p_monto <= 0 then
    raise_application_error(-20000, 'Ingrese el Monto del Adelanto.');
  end if;
  --
  if p_plazo is null or p_plazo <= 0 then
    raise_application_error(-20001, 'Ingrese la Cantidad de Cuotas.');
  end if;
  --
  if p_nro_autorizacion is null then
    raise_application_error(-20002, 'Ingrese el Número de Autorización de la Procesadora.');
  end if;
  --
  if p_nro_cta_credito is null then
    raise_application_error(-20003, 'Ingrese la Cuenta para acreditar el Adelanto.');
  end if;

  begin
    -- Si se encuentra marcado debe generar el cargo --
    If p_cargos = 'S' then
      v_cod_transaccion := fug_obt_pardinamico('TCR_TRA_CAR_ADE_EFECTIVO', 5, null);
      if v_cod_transaccion is null then
        raise_application_error(-20004, 'No está definida la Transacción para el Cobro de Cargos.');
      else
        prg_obt_cargos(v_cod_ofi_origen,
                       p_nro_cuenta,
                       p_cod_moneda,
                       p_monto,
                       5, -- Módulo Tarjeta
                       p_cod_modalidad, -- Modalidad Tarjeta
                       v_cod_transaccion, -- Transaccion para el cobro de cargos por extraccion
                       v_cod_tas_cargo,
                       v_val_tas_cargo,
                       v_val_cargo,
                       v_cod_tra_impuesto,
                       v_cod_tas_impuesto,
                       v_val_tas_impuesto,
                       v_val_impuesto);
        --
        v_cargo := nvl(V_VAL_CARGO, 0) + nvl(V_VAL_IMPUESTO, 0);
        v_total := p_monto - nvl(v_cargo, 0);
      end if;
    end if;
  end;

  -- Movimiento Débito a la TC
  -- pag_cta.pr_set_est_movimiento('P'); -- siempre queda en estado pendiente de aprobación

  if p_monto > 0 then
    if p_plazo > 1 and nvl(v_val_cargo, 0) <> 0 then
      -- Movimiento por Cargo.
      v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
      r_gmovi.cod_usuario     := p_usuario;
      r_gmovi.hora            := v_hor_actual;
      r_gmovi.fecha           := v_fcdehoy;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_modulo      := 5;
      r_gmovi.cod_modalidad   := p_cod_modalidad;
      r_gmovi.cod_oficina     := p_cod_oficina;
      r_gmovi.cod_moneda      := p_cod_moneda;
      r_gmovi.fec_valor       := v_fcdehoy;
      r_gmovi.cod_tra_padre   := 5160;
      r_gmovi.cod_mod_padre   := 5;
      r_gmovi.cod_mad_padre   := p_cod_modalidad;
      r_gmovi.cod_transaccion := v_cod_transaccion; -- Transacción Cargo
      r_gmovi.monto           := v_val_cargo;
      r_gmovi.nro_documento   := p_nro_autorizacion;
      r_gmovi.nro_documento3  := p_plazo;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.concepto        := 'Cargo por Solución cuotas 24x7 en Cta.TC:' || p_nro_tarjeta;
      r_gmovi.referencia      := p_nro_tarjeta;
      r_gmovi.cod_persona     := p_cod_persona;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
      r_gmovi.cod_rubro       := NULL;
      r_gmovi.nro_cuenta      := p_nro_cuenta;
      r_gmovi.tip_mov_rubro   := NULL;
      r_gmovi.cod_tasa        := v_cod_tas_cargo;
      r_gmovi.val_tasa        := v_val_cargo;
      r_gmovi.nro_caja        := p_nro_caja;
      --
      PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
      --
      if nvl(v_val_impuesto, 0) <> 0 then
        -- Movimiento por Impuesto.
        v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
        r_gmovi.cod_usuario     := p_usuario;
        r_gmovi.hora            := v_hor_actual;
        r_gmovi.fecha           := v_fcdehoy;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_modulo      := 5;
        r_gmovi.cod_modalidad   := p_cod_modalidad; --v_tip_cuenta;
        r_gmovi.cod_oficina     := p_cod_oficina;
        r_gmovi.cod_moneda      := p_cod_moneda;
        r_gmovi.fec_valor       := v_fcdehoy;
        r_gmovi.cod_tra_padre   := 5160;
        r_gmovi.cod_mod_padre   := 5;
        r_gmovi.cod_mad_padre   := p_cod_modalidad;
        r_gmovi.cod_transaccion := v_cod_tra_impuesto;
        r_gmovi.monto           := v_val_impuesto;
        r_gmovi.nro_documento   := p_nro_autorizacion;
        r_gmovi.nro_documento3  := p_plazo;
        r_gmovi.emi_aviso       := 'P';
        r_gmovi.concepto        := 'Impuesto por Solución cuotas 24x7 en Cta.TC:' || p_nro_tarjeta;
        r_gmovi.referencia      := p_nro_tarjeta;
        r_gmovi.cod_persona     := p_cod_persona;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
        r_gmovi.cod_rubro       := NULL;
        r_gmovi.nro_cuenta      := p_nro_cuenta;
        r_gmovi.tip_mov_rubro   := NULL;
        r_gmovi.cod_tasa        := v_cod_tas_impuesto;
        r_gmovi.val_tasa        := v_val_tas_impuesto;
        r_gmovi.nro_caja        := p_nro_caja;
        --
        PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
      end if;
    end if;
  
    v_total := nvl(p_monto, 0) + nvl(v_cargo, 0);
  
    -- Movimiento por Total.
    v_nro_secuencia         := nvl(v_nro_secuencia, 0) + 1;
    r_gmovi.cod_usuario     := p_usuario;
    r_gmovi.hora            := v_hor_actual;
    r_gmovi.fecha           := v_fcdehoy;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_modulo      := 5;
    r_gmovi.cod_modalidad   := p_cod_modalidad;
    r_gmovi.cod_oficina     := p_cod_oficina;
    r_gmovi.cod_moneda      := p_cod_moneda;
    r_gmovi.fec_valor       := v_fcdehoy;
    r_gmovi.cod_tra_padre   := 5160;
    r_gmovi.cod_mod_padre   := 5;
    r_gmovi.cod_mad_padre   := p_cod_modalidad;
    r_gmovi.cod_transaccion := 5154; -- Deudores x Tarjeta de Crédito
    r_gmovi.monto           := v_total;
    r_gmovi.nro_documento   := p_nro_autorizacion;
    r_gmovi.nro_documento3  := p_plazo;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.concepto        := 'Total por Solución cuotas 24x7 TC: ' || p_nro_tarjeta;
    r_gmovi.referencia      := p_nro_tarjeta;
    r_gmovi.cod_persona     := p_cod_persona;
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
    r_gmovi.cod_rubro       := null;
    r_gmovi.nro_cuenta      := p_nro_cuenta;
    r_gmovi.tip_mov_rubro   := null;
    r_gmovi.cod_tasa        := null;
    r_gmovi.val_tasa        := null;
    r_gmovi.nro_caja        := p_nro_caja;
    --
    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_mov_noc);
  end if;

  -- Movimiento de Crédito en Cuenta.
  pag_cta.pr_set_referencia(p_cod_persona); -- asigna a referencia el código de persona.
  v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
  
  --DYDMR-1700 - ITGF - Error Cierre 24/03/2015 SC 14654 - EGC 24-03-2015
  --Cargar nulo en cod_rubro y tipo para carga correcta-- 
  pag_cta.pr_set_cod_rubro(null,null);
  
  pag_cta.pr_act_operacion(p_nro_cta_credito,
                           v_hor_actual,
                           'C',
                           p_cod_mon_cta_credito,
                           p_monto,
                           5160, -- 253
                           602,
                           p_nro_autorizacion,
                           NULL,
                           v_cod_ofi_origen,
                           5,
                           p_cod_modalidad,
                           null,
                           null,
                           'Solución cuotas 24x7',
                           'N',
                           v_nro_secuencia,
                           v_fcdehoy);
  if pag_cta.fu_obt_cod_error() <> 0 then
    raise_application_error(-20005, pag_cta.fu_obt_cod_error() || ' - ' || pag_cta.fu_obt_msj_error());
  end if;

  --'Adelanto de Tarjetas - Realizado'
  pag_cta.pr_set_est_movimiento('N');

exception
  when others then
    raise_application_error(-20006, 'Ade:' || sqlerrm);
END;
/

