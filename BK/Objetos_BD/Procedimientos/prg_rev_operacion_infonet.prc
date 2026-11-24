CREATE OR REPLACE PROCEDURE IT.PRG_REV_OPERACION_INFONET
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE
 ,P_COD_MOD_PADRE IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE
 ,P_COD_MAD_PADRE IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE
 ,P_COD_TRA_PADRE IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE
 ,P_COD_USU_REVERSION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE default user
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE default to_char(sysdate,'HH24:MI:SS')
 ,P_ES_NOCTURNO IN VARCHAR2 default 'N'
 ,P_CONCEPTO    IN VARCHAR2 default null
 ,P_NRO_DOCUMENTO  IN GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE
 )
 IS
R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
V_ES_NOCTURNO VARCHAR2(1);
V_EST_MODULO BA_MODULOS.ESTADO%TYPE;
V_FEC_ACTUAL GE_CALENDARIOS.FEC_ACTUAL%TYPE;
V_OPE_PENDIENTE VARCHAR2(1) := 'N';
V_OPE_AHORROS VARCHAR2(1) := 'N';
v_cod_gru_iva ge_gru_transacciones.cod_gru_transaccion%type := fug_obt_pardinamico('COD_GRU_TRA_IVA');
v_fec_ini_dev  ah_devengados.fec_inicio%type;
--v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
v_cod_usu_lib  ta_cobros.cod_usuario%type; --usuario registrado en ta_cobros
v_hora_insercion ge_movimientos.hora%type; --fecha de insercion de ge_mov a ta_cob
v_est_envio    ta_cobros.est_envio%type;
--v_mto_aplicado pr_cta_garantias.mto_aplicado%type;
--v_nro_garantia pr_cta_garantias.nro_garantia%type;
--v_mens_error   varchar2(100);
v_transferencia varchar2(1);
v_afe_libranza varchar2(1);
v_mto_apl_reversar number(18,2) := 0;
v_con_pro_garantia number(5) := 0;
v_fec_envio      date;
v_devengo        Varchar2(1) := 'N';
v_ope_cambios    ge_movimientos.cod_tip_ope_cambio%type;
v_nro_transf     lc_transferencias.nro_operacion%type;
v_mad_hijo       ge_modalidades.cod_modalidad%type;
--v_mto_cuo_ant    cs_contratos.mto_cuota%type;
r_ah_retenciones ah_retenciones%rowtype;
-- Transaccion 346
v_ord_pago ge_pag_proveedores.nro_orden%type;
v_cod_ente   ge_entes.cod_ente%type;
-- solo para conexion con la as/400
--v_ok     varchar2(1);
---
/*type vector is table of varchar2(300) index by
                              binary_integer;*/
--- Vectores
--v_pedido vector;
v_can_pedidos number(3) := 0;
--v_pedido varchar2(400) := null;
--v_respuesta varchar2(4000);
--v_nro_operacion varchar2(10);
--v_cta_enviada varchar2(20);
--------------------------------------
/* Busca en los historicos los movimientos a reversar. */
PROCEDURE LP_BUS_DAT_HISTO
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE
 ,P_COD_MOD_PADRE IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE
 ,P_COD_USU_REVERSION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE
 );
/* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
PROCEDURE LP_INS_MOVIMIENTOS
 (RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE
 ,P_COD_USU_REVERSION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE
 ,P_ES_NOCTURNO IN VARCHAR2 := 'X'
 );

/* obtiene datos de garantia de operaciones vencidas */
function lf_obt_mto_apl_reversar(p_nro_cuenta     in varchar2,
                                  p_cod_garantia  in number,
                                  p_nro_garantia  in number,
                                  p_fecha         in date,
                                  p_hora          in varchar2,
                                  p_cod_usuario   in varchar2)  return number;

/* Validar que no permita reversar operaciones de IVA */
PROCEDURE LP_VAL_IVA
 (RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE);

/* Actualiza los movimientos historicos a reversado. */
PROCEDURE LP_ACT_DAT_HISTO
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE
 ,P_NRO_SECUENCIA IN GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_COD_USU_INSERCION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE
 ,P_COD_MODULO IN GE_MOVIMIENTOS.COD_MODULO%TYPE
 );
CURSOR CUR_GMOVI IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO,REFERENCIA, COD_PERSONA, COD_SIT_CONTABLE,
           NRO_CONCILIACION
    FROM GE_MOVIMIENTOS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO
    ORDER BY NRO_SECUENCIA DESC;
    --
CURSOR CUR_GMONO IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO,REFERENCIA, COD_PERSONA, COD_SIT_CONTABLE,
           NRO_CONCILIACION
    FROM GE_MOVIMIENTOS_NOC
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO
    ORDER BY NRO_SECUENCIA DESC;
    --

    cursor garantias(v_nro_cuenta varchar2) is
    Select t.mto_aplicado,t.nro_garantia,t.cod_garantia
      from pr_cta_garantias_nov t
     where t.fecha       = P_FECHA
       and t.hora        = P_HORA
       and t.cod_usuario = P_COD_USUARIO
       and t.nro_cuenta  = v_nro_cuenta;

   -- cursor de garantias de operaciones vencidas
   cursor garantias_ov(v_nro_cuenta varchar2) is
    Select t.mto_aplicado,t.nro_garantia,t.cod_garantia
      from ov_cta_garantias_nov t
     where t.fecha       = P_FECHA
       and t.hora        = P_HORA
       and t.cod_usuario = P_COD_USUARIO
       and t.nro_cuenta  = v_nro_cuenta;

--Traer datos de la retencion
procedure lp_obt_retencion(p_nro_cuenta ah_retenciones.nro_cuenta%type,
                           p_nro_documento ah_retenciones.nro_documento%type,
                           p_cod_retencion ah_retenciones.cod_retencion%type,
                           p_fec_inicio ah_retenciones.fec_inicio%type,
                           rp_ah_retenciones in out ah_retenciones%rowtype);

/* Busca en los historicos los movimientos a reversar. */
PROCEDURE LP_BUS_DAT_HISTO
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE
 ,P_COD_MOD_PADRE IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE
 ,P_COD_USU_REVERSION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE
 )
 IS

CURSOR CUR_MODULOS IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO, REFERENCIA, COD_PERSONA, COD_SIT_CONTABLE, NRO_CONCILIACION
    FROM GV_MOVIMIENTOS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO

    ORDER BY NRO_SECUENCIA DESC;
BEGIN
  FOR c1 in cur_modulos LOOP
    --- Procesar reversion
    LP_INS_MOVIMIENTOS(C1,P_COD_USU_REVERSION,P_HOR_REVERSION,'N');
    --- Actualizar Historicos
    --AHORRO
    IF c1.COD_MODULO = 3 THEN
        UPDATE AH_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
    -- CUENTA CORRIENTE
    ELSIF c1.COD_MODULO = 4 THEN
        UPDATE CC_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
    -- TARJETA
    ELSIF c1.COD_MODULO = 5 THEN --NO EXISTE
        UPDATE TA_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
        hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
    END IF;
  END LOOP;
END;
/* Validar que no permita reversar operaciones de IVA */
PROCEDURE LP_VAL_IVA
 (RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE)
IS
   v_existe varchar2(01) := 'N';
BEGIN
   select 'S' into v_existe
     from ge_transacciones t, ge_gru_transacciones_det g
    where g.cod_gru_transaccion = v_cod_gru_iva
      and t.cod_modulo = g.cod_modulo
      and t.cod_modalidad = g.cod_modalidad
      and t.cod_transaccion = g.cod_transaccion
      and t.cod_modulo = rp_gmovi.cod_modulo
      and t.cod_modalidad = rp_gmovi.cod_modalidad
      and t.cod_transaccion = rp_gmovi.cod_transaccion;
   if v_existe = 'S' then
      raise_application_error(-20000,'No puede reversar operaciones con IVA de fechas pasadas');
   end if;
   exception
      when no_data_found then null;
      when too_many_rows then
         raise_application_error(-20000,'No puede reversar operaciones con IVA de fechas pasadas');
END;
/* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
PROCEDURE LP_INS_MOVIMIENTOS
 (RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE
 ,P_COD_USU_REVERSION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE
 ,P_ES_NOCTURNO IN VARCHAR2 := 'X'
 )
 IS

R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
v_est_anterior varchar2(1) := null;
v_fec_cam_est_ant date := null;
v_fec_ult_mov_ant date := null;
v_hor_ult_mov_ant varchar2(8) := null;
-- DATOS DE LA REVERSION DE LA CUENTA
v_afecta varchar2(1) := 'N';
v_afe_sal_total      number := 0;
v_afe_sal_retenido   number := 0;
v_afe_sal_bloqueado  number := 0;
v_act_ult_movimiento varchar2(1) := 'N';
v_tip_movimiento     varchar2(1);
r_docu              md_cta_documentos%rowtype;
--- PRESTAMOS
--- Variables para reversion de préstamos
v_capital           pr_cuotas.sal_capital%type;
v_interes           pr_cuotas.sal_interes%type;
v_int_adelantado    pr_cuotas.sal_int_documentado%type;
v_devengado         pr_cta_prestamos.dev_acumulado%type;
v_dev_no_cobrado    pr_cta_prestamos.dev_no_cobrado%type;
v_dev_suspenso      pr_cta_prestamos.dev_no_cobrado%type;

v_cu_dev_acumulado  pr_cta_prestamos.dev_acumulado%type;
v_mto_dev_actual    pr_cta_prestamos.dev_acumulado%type;
v_cu_dev_no_cobrado pr_cta_prestamos.dev_no_cobrado%type;
v_cu_dev_suspenso   pr_cta_prestamos.dev_no_cobrado%type;

v_val_recargo       pr_cuotas.val_recargo%type;
v_sal_recargo       pr_cuotas.val_recargo%type;
v_int_descontado    pr_cuotas.mto_int_descontado%type;
v_cap_adelantado    pr_cuotas.mto_cap_adelantado%type;
v_fec_ult_pago      pr_cuotas.fec_ult_pago%type;
v_estado            pr_cuotas.estado%type;
v_est_cuenta        pr_cta_prestamos.estado%type;
r_pcpre             pr_cta_prestamos%rowtype;
v_nro_cuo_desde     pr_cuotas.nro_cuota%type;
v_nro_cuo_hasta     pr_cuotas.nro_cuota%type;
v_fec_ult_devengado pr_cta_prestamos.fec_ult_devengado%type;
v_nro_solicitud     pr_cta_prestamos.nro_solicitud%type;
v_categoria         ge_clientes.cat_automatica%type;
v_tip_devengado     varchar2(01);
--v_fec_fin_dev       pr_devengados.fec_inicio%type;
v_capital_deven     pr_devengados.capital%type;
v_mto_cap_cuota     pr_cuotas.mto_capital%type;
v_mto_int_docum     pr_cuotas.mto_int_documentado%type;
--- Variables para reversar cheques
v_msj_cheque        varchar2(1000);
--- Variables para reversar gastos varios
v_mto_gastos        number(18,2);
v_mto_gas_original  number(18,2);
v_nro_linea         pr_cta_prestamos.nro_linea%type;
v_nro_cta_cliente   varchar2(30);
--variables para reversar servicios: cobro y remisión
v_remision          varchar2(1) := null;
v_pri_vez           varchar2(1) := 'S';
v_proveedor         ge_entes.cod_ente%type;
v_fec_proceso       date;
v_tipo              ge_entes.tipo%type;
--comex
--v_nro_cuo_cci       number(4);
v_nro_sol_cci       pr_solicitudes.nro_solicitud%type;
v_nro_cta_cci       pr_cta_prestamos.nro_cuenta%type;
v_est_solicitud     pr_solicitudes.estado%type;
v_ult_embarque      number;
v_pagado            varchar2(1) := null;
-- variables para reversar operaciones vencidas
r_vcven             ov_cta_vencidas%rowtype;
v_con_garantia_ven  number(5) := 0;
--- Cursor de cuotas a re-estructurar
cursor c_cobros is
select *
  from pr_cobros
 where nro_cuenta = rp_gmovi.nro_cuenta
   and nro_cuota >= v_nro_cuo_desde
   and nro_cuota <= v_nro_cuo_hasta
 order by nro_cuota;
 --Cursor de documentos relacionados
cursor documentos is
  select *
    from md_cta_documentos
    where nro_cta_padre = rp_gmovi.nro_cuenta;

/* obtiene datos de la transaccion */
PROCEDURE PR_OBT_TIP_TRANSACCION
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,p_tipo out varchar2
 ,p_afecta out varchar2
 )
 IS
BEGIN
   SELECT tipo, afecta
    INTO p_tipo, p_afecta
     FROM GE_TRANSACCIONES
    WHERE cod_modulo = p_cod_modulo
      and cod_modalidad = p_cod_modalidad
      and cod_transaccion = p_cod_transaccion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
     RAISE_APPLICATION_ERROR(-20004,'Transaccion inexistente '||
                    to_char(nvl(p_cod_modulo,0))||'-'||
                    to_char(nvl(p_cod_modalidad,0))||'-'||
                    to_char(p_cod_transaccion));
   WHEN OTHERS THEN
     RAISE_APPLICATION_ERROR(-20005,sqlerrm);
END;
--- Obtiene el rubro de reversion
FUNCTION fl_obt_rub_reversion(p_cod_rubro in varchar2)
return varchar2 is
  v_rub CB_RUBROS.COD_RUBRO%TYPE;
BEGIN
  BEGIN
  select cod_rub_reversion
    into v_rub
    from cb_rub_reversiones
   where cod_rubro = p_cod_rubro;
  EXCEPTION
    when others then
      v_rub := NULL;
  END;
  return v_rub;
END;
------------------------------------------------------------------------------
BEGIN
    -- Traspaso los datos del registro leido en el nuevo
    r_gmovi := rp_gmovi;
    --
    r_gmovi.fecha             := v_fec_actual;
    r_gmovi.fec_valor         := p_fecha;
    r_gmovi.hora              := p_hor_reversion;
    r_gmovi.hor_reversion     := rp_gmovi.hora;
    r_gmovi.cod_usuario       := p_cod_usu_reversion;
    r_gmovi.monto             := rp_gmovi.monto * -1;
    r_gmovi.reversado         := 'S';
    r_gmovi.cod_usu_reversion := rp_gmovi.cod_usuario;
    r_gmovi.mto_equ_local     := rp_gmovi.mto_equ_local * -1;
    r_gmovi.concepto          := substr(p_concepto,1,35);
    --- Reversion de IVA Facturado
    -- Verificar si el movimiento original fue facturado
    if pab_iva.fu_mov_facturado(rp_gmovi.fecha, rp_gmovi.hora, rp_gmovi.cod_usuario) then
       declare
         v_rub_rev     cb_rubros.cod_rubro%type;
         v_tip_mov_rub ge_movimientos.tip_mov_rubro%type;
       begin
         v_tip_mov_rub := r_gmovi.tip_mov_rubro;
         v_rub_rev := fl_obt_rub_reversion(nvl(r_gmovi.cod_rubro,
                                               fub_obt_rub_transaccion(r_gmovi.cod_modulo, r_gmovi.cod_modalidad, r_gmovi.cod_transaccion,
                                                                       r_gmovi.cod_moneda, null, null, v_tip_mov_rub))
                                          );
         if v_rub_rev is not null then
           r_gmovi.cod_rubro := v_rub_rev;
           r_gmovi.tip_mov_rubro := v_tip_mov_rub;
           r_gmovi.cod_transaccion := null;
         end if;
      end;
    end if;
    --
    if r_gmovi.cod_tra_padre not in (101,102,358,359,360,362,364,139) then  --- 358 desemb.prest. y pase a op.venc., 139 cobros de op.v.
       PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,V_ES_NOCTURNO);
    end if;

    -- retorno el monto del saldo de la cuenta
    if rp_gmovi.nro_cuenta is not null and
       (rp_gmovi.estado = 'N' or --- Los movimientos 'J' no actualizan la cuenta
        (RP_GMOVI.Estado = 'P' and RP_GMOVI.Cod_Transaccion = 610) ) and --Para casos de DNA con CHQ
       rp_gmovi.monto <> 0 and
       r_gmovi.cod_modulo in (3,4,6) then /* Se agrego el modulo 6, por cheques custodia*/
       v_ope_ahorros := 'S';
       if v_fec_ult_mov_ant is not null then
          v_act_ult_movimiento := 'S'; -- debe actualizar la fecha y hora
       end if;
       -- obtengo el tipo d/c y a que saldo afecto
       if r_gmovi.cod_modulo <> 6 then
          pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                                rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad,
                                v_tip_movimiento, v_afecta);
       end if;
        IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad,rp_gmovi.nro_cuenta) = 'N' AND
          r_gmovi.cod_modulo <> 6 THEN --solo para 3 y 4 por el momento
          -- cuenta llaveada
          raise_application_error(-20000,'Cuenta '||rp_gmovi.nro_cuenta||' llaveada ');
       end if;
       if r_gmovi.cod_modulo = 6 then
          v_afecta := null;
       end if;
       if v_afecta = 'R' then -- afecta al saldo retenido
          if v_tip_movimiento = 'C' then
             v_afe_sal_total     := r_gmovi.monto;
             v_afe_sal_retenido  := r_gmovi.monto;
             v_afe_sal_bloqueado := 0;
          elsif v_tip_movimiento = 'D' then
             v_afe_sal_total     := 0;
             v_afe_sal_retenido  := r_gmovi.monto;
             v_afe_sal_bloqueado := 0;
          end if;
       elsif v_afecta in ('C','I','S') then  -- afecta al saldo total,capital o interes
          v_afe_sal_total     := r_gmovi.monto;
          v_afe_sal_retenido  := 0;
          v_afe_sal_bloqueado := 0;
       elsif v_afecta = 'B' then -- afecta al saldo bloqueado
          v_afe_sal_total     := 0;
          v_afe_sal_retenido  := 0;
          v_afe_sal_bloqueado := r_gmovi.monto;
       end if;
       if nvl(v_afe_sal_total,0) <> 0 or
          nvl(v_afe_sal_retenido,0) <> 0 or
          nvl(v_afe_sal_bloqueado,0) <> 0 then
          pag_cta.pr_obt_cuenta(rp_gmovi.nro_cuenta);
          /* CONTROL ANULADO PARA INTERFAZ DE LA AS/400. LEVANTAR CUANDO SE ANULA LA INTERFAZ CON AS/400
          if rp_gmovi.cod_modulo = 3 and v_tip_movimiento = 'C' and (v_afe_sal_total*-1) > pag_cta.G_CTAS.SAL_TOTAL then
             -- ya no hay saldo para reversar
              raise_application_error(-20000,'Cuenta ya no tiene saldo suficiente');
          end if;
          */
          -- retorno el monto al saldo
           pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta,
                               rp_gmovi.cod_modalidad,
                                v_tip_movimiento,
                               v_fec_ult_mov_ant,
                               v_hor_ult_mov_ant,
                               v_afe_sal_total,
                               v_afe_sal_retenido,
                               v_afe_sal_bloqueado,
                               null, /* autorizacion pendiente */
                               v_act_ult_movimiento);

       end if;
       if (rp_gmovi.cod_modalidad = 43 and fug_obt_tip_implementacion <> 1 ) or--- Reversar cheque emitido
          (rp_gmovi.cod_transaccion = 603  and fug_obt_tip_implementacion = 1) Then
          v_msj_cheque := pac_che.FU_ELI_CHE_GER_EMI(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento);
          if v_msj_cheque is not null then
             raise_application_error(-20000,'Reversion del Cheq. Gerencia '||v_msj_cheque);
          end if;
       end if;
    end if;

    if rp_gmovi.nro_cuenta is not null and
       rp_gmovi.estado in ('P','X','J') and --- Los movimientos 'J' no actualizan la cuenta
       rp_gmovi.monto <> 0 and
       r_gmovi.cod_modulo in (3,4) and
       r_gmovi.cod_mod_padre in (3,4,5,9) then /* solo reversa ahorros por ahora */
       if v_fec_ult_mov_ant is not null then
          v_act_ult_movimiento := 'S'; -- debe actualizar la fecha y hora
       end if;
       -- obtengo el tipo d/c y a que saldo afecto
       pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                             rp_gmovi.cod_modulo,
                             rp_gmovi.cod_modalidad,
                             v_tip_movimiento, v_afecta);
       if v_tip_movimiento = 'D' then -- si es un debito
          -- retorno el monto al saldo
          pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta,
                                 rp_gmovi.cod_modalidad,
                                 'D',
                                 rp_gmovi.fecha,
                                 rp_gmovi.hora,
                                 0,
                                 0,
                                 rp_gmovi.monto,-- el saldo bloqueado
                                null, /* autorizacion pendiente */
                                v_act_ult_movimiento);
          If rp_gmovi.estado = 'X' and rp_gmovi.cod_tra_padre = 354 then
             update ge_aut_pedidos
                set respuesta = 'R',
                    estado    = 'A',
                    observacion = p_concepto
              where fecha = rp_gmovi.fecha
                and hora  = rp_gmovi.hora
                and cod_usuario = rp_gmovi.cod_usuario
                and respuesta <> 'R';
          End if;
       end if;
    end if;
    --operaciones de cambios, sólo las q debitan ctas se reversan porque los movimientos
    --se generan en estado J y no se reversan x el proceso normal, el resto sique el circuito normal
    if rp_gmovi.nro_cuenta is not null and
      rp_gmovi.monto <> 0 and
      rp_gmovi.cod_modulo = 5 then
      -- verifica si la reversion es de un deposito en efectivo o una
      -- liberacion de retencion para borrar el cobro
      -- AGREGAGO EL BORRADO DE LA 607 PORQUE CHEQUES SE ENVIA
      -- A LA PROCESADORA COMO EFECTIVO
      if rp_gmovi.cod_transaccion in (606, 607, 690, 515, 978) then
         delete from ta_cobros
         where fec_proceso = rp_gmovi.fecha
           and hora = p_hora
           and cod_usuario = p_cod_usuario
           and nro_cuenta = rp_gmovi.nro_cuenta
           and monto = rp_gmovi.monto
           and estado in ('P','C');
         --Si no encuentro el registro veo si la liberacion cargo ta_cobros
         if sql%notfound then
            begin
            select e.cod_usuario,to_char(e.fec_insercion,'hh24:mi:ss')
              into v_cod_usu_lib,v_hora_insercion
              from ge_movimientos e
             where e.nro_cuenta = rp_gmovi.nro_cuenta
               and e.nro_documento = rp_gmovi.nro_documento
               and e.fecha = rp_gmovi.fecha
               and e.monto = rp_gmovi.monto
               and e.cod_transaccion in (515,565,560);
            exception
               when others then
                   v_cod_usu_lib := null;
                   v_hora_insercion := null;
            end;
            --busco si se envio o no el registro de TA_COBROS
            BEGIN
            select est_envio
              into v_est_envio
              from ta_cobros
             where fec_proceso = rp_gmovi.fecha
               and nro_cuenta = rp_gmovi.nro_cuenta
               and monto = rp_gmovi.monto
               and estado in ('P','C')
               and usu_insercion = v_cod_usu_lib
               and to_char(fec_insercion,'hh24:mi:ss') = v_hora_insercion;
            exception
              when no_data_found then
                 v_est_envio := 'N'; --No buscar en ta_cobros
              when too_many_rows then
                 raise_application_error(-20001,'Mas de un registro para' ||
                      ' Cuenta:'||rp_gmovi.nro_cuenta||' Monto:'||rp_gmovi.monto||
                      ' Usu_insercion: '||v_cod_usu_lib||' Hora_insercion: '||v_hora_insercion);
              when others then
                 raise_application_error(-20001,sqlerrm||
                      ' Cuenta:'||rp_gmovi.nro_cuenta||' Monto:'||rp_gmovi.monto||
                      ' Usu_insercion: '||v_cod_usu_lib||' Hora_insercion: '||v_hora_insercion);
            END;
            if v_est_envio = 'P' then --P=Pendiente, se  puede borrar
               delete from ta_cobros
                where fec_proceso = rp_gmovi.fecha
                  and nro_cuenta = rp_gmovi.nro_cuenta
                  and monto = rp_gmovi.monto
                  and estado in ('P','C')
                  and usu_insercion = v_cod_usu_lib
                  and to_char(fec_insercion,'hh24:mi:ss') = v_hora_insercion;
            elsif v_est_envio = 'E' then --Enviado dar error
                 raise_application_error(-20002,'Cobro ya enviado a la procesadora '||
                      ' Cuenta:'||rp_gmovi.nro_cuenta||' Monto:'||rp_gmovi.monto||
                      ' Usu_insercion: '||v_cod_usu_lib||' Hora_insercion: '||v_hora_insercion);
            end if;
         end if;
      end if;
      if rp_gmovi.cod_retencion is not null then
          -- afecto la retencion, trato de borrar la retencion
            delete ah_retenciones
             where nro_cuenta = rp_gmovi.nro_cuenta
               and nro_documento = rp_gmovi.nro_documento
               and cod_retencion = rp_gmovi.cod_retencion
               and fec_inicio = rp_gmovi.fecha
               and liberado = 'N';
            --Si ya fue liberado busco el registro y ademas borro de ge_movimientos
            if sql%notfound then
               delete ah_retenciones
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_documento = rp_gmovi.nro_documento
                  and cod_retencion = rp_gmovi.cod_retencion
                  and fec_inicio = rp_gmovi.fecha
                  and liberado = 'S';
                -- borro el movimiento de la liberacion para que no actualice el saldo batch
                delete from ge_movimientos
                 where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_documento = rp_gmovi.nro_documento
                  and cod_retencion = rp_gmovi.cod_retencion
                  and fecha = rp_gmovi.fecha
                  and monto = rp_gmovi.monto
                  and cod_transaccion in (515,565,560);
            end if;
      end if;
   End if;

   if rp_gmovi.nro_cuenta  is not null and
       rp_gmovi.monto      <> 0        and
       rp_gmovi.cod_modulo = 6         and
       v_ope_pendiente     = 'N'       and
       rp_gmovi.cod_tra_padre in (142,360,359,362,364) then
       -- Recuperar datos del prestamo
       pap_pre.PR_OBT_DAT_PRESTAMO(rp_gmovi.nro_cuenta, r_pcpre);
       -- obtengo el tipo d/c y a que saldo afecto
       pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                             rp_gmovi.cod_modulo,
                             rp_gmovi.cod_modalidad,
                             v_tip_movimiento, v_afecta);
       --- Inicializar errores de pag_cta
       pag_cta.G_MSJ_ERROR := null;
       pag_cta.G_COD_ERROR := 0;
       --- Inicializar variables de descuento
       v_estado            := null;
       v_est_cuenta        := null;
       v_est_anterior      := null;
       v_capital           := 0;
       v_interes           := 0;
       v_int_adelantado    := 0;
       v_val_recargo       := 0;
       v_int_descontado    := 0;
       v_cap_adelantado    := 0;
       v_devengado         := 0;
       v_dev_no_cobrado    := 0;
       v_dev_suspenso      := 0;
       v_capital_deven     := 0;
       v_mto_cap_cuota     := 0;
       v_mto_int_docum     := 0;
       v_cu_dev_acumulado  := 0;
       v_cu_dev_no_cobrado := 0;
       v_cu_dev_suspenso   := 0;

       --- Recuperar fecha de ultimo pago y estado anterior de pr_cobros
       begin
          select fec_ult_pago, estado, fec_ult_devengado, estado,
                 dev_acumulado, dev_suspenso, dev_no_cobrado,
                 mto_int_descontado, decode(rp_gmovi.cod_tra_padre, 362, mto_capital, 0)
            into v_fec_ult_pago, v_estado, v_fec_ult_devengado, v_est_cuenta,
                 v_cu_dev_acumulado, v_cu_dev_suspenso, v_cu_dev_no_cobrado,
                 v_int_descontado, v_cap_adelantado
            from pr_cobros
           where nro_cuenta = rp_gmovi.nro_cuenta
             and nro_cuota  = rp_gmovi.NRO_DOCUMENTO
             and fecha      = rp_gmovi.fecha
             and hora       = rp_gmovi.hora;
          -- verifico sino hay otros cobros, en caso de intereses vencidos
          IF nvl(fup_obt_tip_descuento(rp_gmovi.cod_modalidad),'x') not in ('F','C','D') then
            DECLARE
              v_can_cuotas number := 0;
            BEGIN
               select count(*)
                 into v_can_cuotas
                 from pr_cobros
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and ((fecha > rp_gmovi.fecha) or
                       (fecha = rp_gmovi.fecha and hora > rp_gmovi.hora))
                  and rownum = 1;
               IF v_can_cuotas > 0 then
                 raise_application_error(-20000,'La cuenta '||rp_gmovi.nro_cuenta||
                    ' tiene cobros posteriores que deben ser reversados previamente.');
               end if;
            END;
          ELSE --Para los casos de descuentos
            DECLARE
               v_can_cuotas number := 0;
            BEGIN
               select count(*)
                 into v_can_cuotas
                 from pr_cobros
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_cuota = RP_GMOVI.NRO_DOCUMENTO
                  and ((fecha > rp_gmovi.fecha) or
                       (fecha = rp_gmovi.fecha and hora > rp_gmovi.hora))
                  and rownum = 1;
               IF nvl(v_can_cuotas,0) > 0 then
                  raise_application_error(-20001,'La cuenta '||rp_gmovi.nro_cuenta||
                     ' tiene mov. posteriores de la misma cuota nro.'||RP_GMOVI.NRO_DOCUMENTO||
                     ' Primero rev.esos movimientos.');
               end if;
            END;
          END IF;
          IF P_FECHA = V_FEC_ACTUAL then
             --- Solo cuando se reversa cobros del mismo dia se reversa el devengado
             --- en caso contrario el devengamiento se realizará por diferencia en el cierre
             --- Recuperar datos de devengados actuales de la cuota
             select nvl(v_cu_dev_acumulado,0) - nvl(dev_acumulado,0),
                    nvl(v_cu_dev_no_cobrado,0) - nvl(dev_no_cobrado,0),
                    nvl(v_cu_dev_suspenso,0) - nvl(dev_suspenso,0),
                    nvl(mto_capital,0), nvl(mto_int_documentado,0)
               into v_devengado, v_dev_no_cobrado, v_dev_suspenso,
                    v_mto_cap_cuota, v_mto_int_docum
               from pr_cuotas
              where nro_cuenta = rp_gmovi.nro_cuenta
                and nro_cuota  = rp_gmovi.NRO_DOCUMENTO;
             --- Actualizar la cuota
             update pr_cuotas
                set dev_acumulado  = v_cu_dev_acumulado,
                    dev_suspenso   = v_cu_dev_suspenso,
                    dev_no_cobrado = v_cu_dev_no_cobrado
              where nro_cuenta = rp_gmovi.nro_cuenta
                and nro_cuota  = rp_gmovi.NRO_DOCUMENTO;
             --- Actualizar el prestamo en el devengado ya la primera vez
             update pr_cta_prestamos
                set dev_acumulado     = nvl(dev_acumulado,0) + nvl(v_devengado,0),
                    dev_no_cobrado    = nvl(dev_no_cobrado,0) + nvl(v_dev_no_cobrado,0),
                    dev_suspenso      = nvl(dev_suspenso,0) + nvl(v_dev_suspenso,0),
                    val_int_devengar  = nvl(val_int_devengar,0) - nvl(v_devengado,0) + nvl(v_int_descontado,0)
              where nro_cuenta = rp_gmovi.nro_cuenta;
          END IF;
          --- La primera vez que pasa por la cuota ya actualiza fecha de pago y estado,
          --- porque luego se borra este registro
          update pr_cuotas
             set fec_ult_pago       = v_fec_ult_pago,
                 estado             = v_estado,
                 mto_int_descontado = nvl(mto_int_descontado,0) - nvl(v_int_descontado,0),
                 mto_cap_adelantado = nvl(mto_cap_adelantado,0) - nvl(v_cap_adelantado,0)
           where nro_cuenta = rp_gmovi.nro_cuenta
             and nro_cuota  = rp_gmovi.NRO_DOCUMENTO;
          --- Actualizar el devengado de la cuota en pr_devengados
          --- Solo si devengo, si se cambio los suspendidos o cobros nada mas no tocar
          if nvl(v_devengado,0) <> 0 then
             --- Recuperar categoria del cliente
             Begin
                select fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria
                  into v_categoria
                  from ge_clientes c, ge_cta_clientes b
                 where b.nro_cuenta  = RP_GMOVI.nro_cuenta
                   and b.cod_persona = c.cod_persona
                   and b.relacion    = 'P';
             exception
                when no_data_found then
                   raise_application_error(-20000,
                   'Cliente Principal no registrado para cuenta '||RP_GMOVI.nro_cuenta);
             End;
             --- Recuperar tipo de devengado en el momento del cobro
             IF v_est_cuenta IN ('A','C') AND v_categoria IN (1,2) THEN /* solo los est 'A' y 'C' y categ 1 y 2*/
                v_tip_devengado := 'C'; --'N'
             else
                v_tip_devengado := 'S';
             end if;
             --- Recuperar fecha de inicio del devengado
             if r_pcpre.tip_interes = 'V' then
                --- Para prestamos vencidos recorrer cuotas cuya fecha de
                --- inicio de devengado ha transcurrido
                v_fec_ini_dev := nvl(pap_dev.FU_OBT_FEC_INI_CUOTA(rp_gmovi.nro_cuenta, rp_gmovi.NRO_DOCUMENTO),r_pcpre.fec_inicio);
             else
                v_fec_ini_dev := r_pcpre.fec_inicio;
             end if;
             --- Recuperar capital segun el tipo de prestamo
             if r_pcpre.tip_interes = 'A' then
                v_capital_deven := nvl(v_mto_cap_cuota,0) + nvl(v_mto_int_docum,0);
             else
                v_capital_deven := PAP_INT.FU_OBT_CAPITAL_ACUMU(v_fec_ini_dev, rp_gmovi.nro_cuenta);
             end if;
             --- Recuperar capital de la cuota
             --- Solo se reversa si devengo el dia del cobro por esa fecha o adelantado
             if v_fec_ult_devengado is null then
               --se elimina pr_devengados
               delete pr_devengados
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_cuota  = rp_gmovi.NRO_DOCUMENTO
                  and fec_inicio = v_fec_ini_dev
                  and val_tasa   = r_pcpre.val_tasa
                  and categoria  = v_categoria
                  and estado     = v_est_cuenta
                  and cod_moneda = r_pcpre.cod_moneda
                  and capital    = v_capital_deven
                  and tipo       = v_tip_devengado;
             else
               update pr_devengados
                  set fecha = v_fec_ult_devengado,
                      mto_dev_acumulado = mto_dev_acumulado - mto_dev_actual,
                      can_dia_interes   = nvl(can_dia_anterior,0),
                      mto_dev_actual    = nvl(mto_dev_anterior,0),
                      mto_ajuste        = null,
                      fec_ult_devengado = v_fec_ult_devengado
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_cuota  = rp_gmovi.NRO_DOCUMENTO
                  and fec_inicio = v_fec_ini_dev
                  and val_tasa   = r_pcpre.val_tasa
                  and categoria  = v_categoria
                  and estado     = v_est_cuenta
                  and cod_moneda = r_pcpre.cod_moneda
                  and capital    = v_capital_deven
                  and tipo       = v_tip_devengado;
             End if;
          end if;
          --- Actualizar el prestamo en el devengado ya la primera vez
          update pr_cta_prestamos
             set fec_ult_devengado = v_fec_ult_devengado,
                 estado            = nvl(v_est_cuenta,estado)
           where nro_cuenta = rp_gmovi.nro_cuenta;
          --- Actualizar ge_che_custodia
          --if r_pcpre.cod_modalidad in (608, 630) then --- Descuento de Cheques
          If FUP_OBT_TIP_DESCUENTO(r_pcpre.cod_modalidad) = 'C' then
             update ge_che_custodias
                set estado = 'C'
              where nro_referencia = rp_gmovi.nro_cuenta
                and nro_cuota = rp_gmovi.NRO_DOCUMENTO
                and estado = 'D';
          end if;
          exception
             when no_data_found then
                v_fec_ult_pago := null;    v_estado := null;
       end;
       --- Verificar como afecta al prestamo la transaccion
       if v_afecta = 'C' then
          --- Reversar capital
          v_capital := rp_gmovi.monto;
       elsif v_afecta = 'I' then
          --- Reversar interés vencido
          v_interes := rp_gmovi.monto;
       elsif v_afecta = 'A' then
          --- Reversar interés adelantado
          v_int_adelantado := rp_gmovi.monto;
       elsif v_afecta = 'E' then
          --- Reversar recargos
          v_val_recargo := rp_gmovi.monto;
       end if;
/*       declare
          v_can_cambios number(8); -- para contar cambios o mov posteriores
       Begin
          -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
          select count(*)
            into v_can_cambios
            from movimientos_fabiola--gv_movimientos
           where nro_cuenta = rp_gmovi.nro_cuenta
             and ((fec_valor > rp_gmovi.fec_valor) or
                 (fec_valor = rp_gmovi.fec_valor and hora > rp_gmovi.hora))
--             and fec_insercion > rp_gmovi.fec_insercion
             and reversado = 'N'
             and ((est_cuenta is not null and nvl(cod_tip_movimiento,'x')='E') or v_est_anterior is not null) -- si hubo otro cambio de estado posterior
             and rownum = 1;
          if nvl(v_can_cambios,0) > 0 then
             raise_application_error(-20000,'La cuenta '||rp_gmovi.nro_cuenta||
             ' tiene movimientos posteriores que deben ser reversados previamente.');
          end if;
          if v_fec_ult_mov_ant is not null then
             -- verifico sino hubo movimientos posteriores de la cuenta
             select count(*)
               into v_can_cambios
               from movimientos_fabiola--gv_movimientos
              where nro_cuenta = rp_gmovi.nro_cuenta
                and ((fecha > rp_gmovi.fecha) or
                     (fecha = rp_gmovi.fecha and hora > rp_gmovi.hora))
                and reversado = 'N'
                and monto > 0 -- si hubo un mov posterior
                and rownum = 1;
             if nvl(v_can_cambios,0) > 0 then
                -- en este caso nada mas no se actualiza los datos del ultimo mov
                v_fec_ult_mov_ant := null;
                v_hor_ult_mov_ant := null;
             end if;
          end if;
       exception
          when no_data_found then
             v_fec_ult_mov_ant := null;
             v_hor_ult_mov_ant := null;
          when others then
             raise_application_error(-20000,sqlerrm||' Buscando ge_cuentas_nov ');
       end;*/
       --- Actualizar cuota
       update pr_cuotas
          set fec_ult_pago = nvl(v_fec_ult_pago,fec_ult_pago),
              estado       = nvl(v_estado,estado),
              sal_capital  = nvl(sal_capital,0) + nvl(v_capital,0),
              sal_interes  = nvl(sal_interes,0) + nvl(v_interes,0),
              val_recargo  = nvl(val_recargo,0) - nvl(v_val_recargo,0),
              sal_int_documentado = nvl(sal_int_documentado,0) + nvl(v_int_adelantado,0)
        where nro_cuenta = rp_gmovi.nro_cuenta
          and nro_cuota  = rp_gmovi.NRO_DOCUMENTO;
       --- Actualizar maestro de prestamos
       update pr_cta_prestamos
          set sal_capital        = nvl(sal_capital,0) + nvl(v_capital,0),
              sal_interes        = nvl(sal_interes,0) + nvl(v_interes,0),
              sal_int_adelantado = nvl(sal_int_adelantado,0) + nvl(v_int_adelantado,0),
              fec_cancelacion    = null,
              can_cuo_pagadas    = nvl(can_cuo_pagadas,0) - 1
        where nro_cuenta = rp_gmovi.nro_cuenta;
       --- Actualizar cuotas restantes
       if v_est_cuenta is not null then
          update pr_cuotas
             set estado = v_est_cuenta
           where nro_cuenta = rp_gmovi.nro_cuenta
             and estado <> 'N'
             and nro_cuota > rp_gmovi.NRO_DOCUMENTO;
       end if;
       /* RAMG: que quede utilizada porque no funciona bien
       if rp_gmovi.cod_autorizacion is not null then

          update ge_autorizaciones
             set cod_usu_utilizador = null,
                 fec_utilizacion    = null,
                 hor_utilizacion    = null
           where cod_autorizacion   = rp_gmovi.cod_autorizacion;
       end if;
       */

       --- actualizar pr_cta_gastos (gastos varios)
       IF nvl( v_mto_gastos, 0 ) > 0 THEN
        BEGIN
          select sum( nvl( monto, 0 ) )
            into v_mto_gas_original
            from pr_cta_gastos
           where nro_cuenta = rp_gmovi.nro_cuenta
             and fec_ult_pago = rp_gmovi.fecha
             and hor_ult_pago = rp_gmovi.hora;
        EXCEPTION
          when no_data_found then
            v_mto_gas_original := 0;
        END;
        DECLARE
          CURSOR gastos
              IS select nro_cuenta, monto, rowid
                   from pr_cta_gastos
                  where nro_cuenta = rp_gmovi.nro_cuenta
                  and fec_ult_pago = rp_gmovi.fecha
                  and hor_ult_pago = rp_gmovi.hora
                  order by nro_cuenta, cod_modalidad, cod_transaccion, fec_ingreso;
          v_cargo_tmp NUMBER;
        BEGIN
          v_cargo_tmp := nvl( v_mto_gas_original, 0 );
          FOR g IN gastos LOOP
            -- Si el gasto es mayor o igual al monto, actualizo la tabla pr_cta_gastos como NO cobrado
            IF nvl( v_cargo_tmp, 0 ) >= nvl( g.monto, 0 ) THEN
              BEGIN
                update pr_cta_gastos
                   set fec_ult_pago = null,
                       hor_ult_pago = null
                 where nro_cuenta = rp_gmovi.nro_cuenta
                   and rowid = g.rowid;
              EXCEPTION
                when others then
                  NULL;
              END;
              v_cargo_tmp := nvl( v_cargo_tmp, 0 ) - nvl( g.monto, 0 );
            END IF;
          END LOOP;
        END;
       END IF;

       --Obs: Controlar para que se ejecute solo una vez--
       --la actualizacion de garantias--
       v_con_pro_garantia := nvl(v_con_pro_garantia,0) + 1;
       if nvl(v_con_pro_garantia,0) = 1 then
       --Actualizar mto. aplicado de la garantia
           for i in garantias(rp_gmovi.nro_cuenta) loop
             v_mto_apl_reversar := fup_obt_mto_apl_reversar
                                   (rp_gmovi.nro_cuenta,
                                    i.cod_garantia,
                                    i.nro_garantia,
                                    p_fecha,
                                    p_hora,
                                    p_cod_usuario);
             If i.cod_garantia = 1 then
               update pr_cta_garantias x
                  set x.mto_aplicado = nvl(x.mto_aplicado,0) + v_mto_apl_reversar
                where x.nro_cuenta  = rp_gmovi.nro_cuenta
                  and x.cod_garantia = i.cod_garantia;
             else
               update pr_cta_garantias x
                  set x.mto_aplicado = nvl(x.mto_aplicado,0) + v_mto_apl_reversar
                where x.nro_cuenta  = rp_gmovi.nro_cuenta
                  and x.cod_garantia = i.cod_garantia
                  and x.nro_garantia = i.nro_garantia;
             end if;
           End loop;
       end if;
       -- Recalcular línea
       if r_pcpre.nro_linea is not null then
          prp_rec_apl_limite(r_pcpre.nro_linea);
       end if;

       --Elimiar la novedad de la garantia
       delete pr_cta_garantias_nov
          where fecha       = P_FECHA
            and hora        = P_HORA
            and cod_usuario = P_COD_USUARIO
            and nro_cuenta  = rp_gmovi.nro_cuenta;

       --- Eliminar pr_cobros
       delete pr_cobros
        where nro_cuenta = rp_gmovi.nro_cuenta
          and nro_cuota  = rp_gmovi.NRO_DOCUMENTO
          and fecha      = rp_gmovi.fecha
          and hora       = rp_gmovi.hora;
       --- Solo si existe cancelacion parcial
       if rp_gmovi.cod_tra_padre = 359 and rp_gmovi.cod_transaccion = 747 then
          --- Recorrer
          v_nro_cuo_desde := rp_gmovi.nro_documento;
          v_nro_cuo_hasta := rp_gmovi.NRO_DOCUMENTO;
          for cob in c_cobros loop
             update pr_cuotas
                set mto_interes         = cob.mto_interes,
                    sal_interes         = cob.sal_interes_cuo,
                    mto_int_documentado = cob.mto_int_documentado,
                    sal_int_documentado = cob.sal_int_documentado,
                    dev_acumulado       = cob.dev_acumulado,
                    dev_no_cobrado      = cob.dev_no_cobrado,
                    dev_suspenso        = cob.dev_suspenso,
                    nro_documento       = cob.nro_documento
              where nro_cuenta = cob.nro_cuenta
                and nro_cuota  = cob.nro_cuota;
             if sql%notfound then
                insert into pr_cuotas(
                   nro_cuenta, nro_cuota, fec_vencimiento,
                   mto_capital, mto_interes, estado,
                   sal_capital, sal_interes, prioridad,
                   fec_ult_pago, mto_int_documentado,
                   nro_documento, sal_int_documentado,
                   dev_acumulado, dev_no_cobrado, dev_suspenso
                   )
                values (
                   cob.nro_cuenta, cob.nro_cuota, cob.fec_vencimiento,
                   cob.mto_capital, cob.mto_interes, cob.estado,
                   cob.sal_capital_cuo, cob.sal_interes_cuo, 'I',
                   cob.fec_ult_pago, cob.mto_int_documentado,
                   cob.nro_documento, cob.sal_int_documentado,
                   cob.dev_acumulado, cob.dev_no_cobrado, cob.dev_suspenso);
             end if;
          end loop;
       end if;
    ELSif rp_gmovi.nro_cuenta is not null and
       rp_gmovi.monto      <> 0        and
       rp_gmovi.cod_modulo = 6         and
       v_ope_pendiente     = 'N'       and
       rp_gmovi.cod_tra_padre in (358) then --DESEMBOLSO
       -- obtengo el tipo d/c y a que saldo afecto
       pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                             rp_gmovi.cod_modulo,
                             rp_gmovi.cod_modalidad,
                             v_tip_movimiento, v_afecta);
       --- Inicializar errores de pag_cta
       pag_cta.G_MSJ_ERROR := null;
       pag_cta.G_COD_ERROR := 0;
       -- Recuperar datos de la propuesta
       v_nro_solicitud := null;
       begin
          select nro_solicitud, nro_linea
            into v_nro_solicitud, v_nro_linea
            from pr_cta_prestamos
           where nro_cuenta = rp_gmovi.nro_cuenta;
          exception
             when no_data_found then
               v_nro_solicitud := null;
       end;
       --If rp_gmovi.cod_modalidad in (608, 630)
       If FUP_OBT_TIP_DESCUENTO(rp_gmovi.cod_modalidad) = 'C'
       and v_nro_solicitud is not null then
           --- Actualizo los cheques que corresponden a la solicitud
           update ge_che_custodias
              set estado = 'I', nro_referencia = v_nro_solicitud
            where nro_referencia = rp_gmovi.nro_cuenta
              and estado <> 'D'
              and tip_servicio in ('D', 'G');
       end if;
       --- Actualizo los documentos que corresponden a la solicitud
       --If rp_gmovi.cod_modalidad in (62, 620)
       If FUP_OBT_TIP_DESCUENTO(rp_gmovi.cod_modalidad) in ('D','F')
          and v_nro_solicitud is not null then
           update pr_documentos
              set nro_referencia = v_nro_solicitud
            where nro_referencia = rp_gmovi.nro_cuenta
              and estado = 'C' ;
       end if;
       -- Actualizar solicitudes
       if v_nro_solicitud is not null then
          update pr_solicitudes
             set estado = 'L',
                 --cod_ori_fondo = null, NO DEBE NULAR
                 fec_aprobacion = null
           where nro_solicitud = v_nro_solicitud;
          /* En caso de Prestamos en Etapas hay que actualizar la cantidad de desembolsos faltantes
             de la solicitud original - Buscar la solicitud original
          */
           Declare
            v_tip_renovacion varchar2(1);
            v_can_desembolsos number;
            v_nro_sol_original number;
           Begin
              Select tip_renovacion, can_desembolsos, nro_sol_original
               into v_tip_Renovacion, v_can_Desembolsos, v_nro_sol_original
                from pr_solicitudes
               where nro_solicitud = v_nro_solicitud;
              --
              If v_tip_renovacion = 'A' and nvl(v_can_desembolsos,0) > 1 then -- es el original
                v_nro_sol_original := v_nro_solicitud;
              End if;
              -- Si el tip_renovacion no es 'A' entonces en v_nro_sol_original viene la original,
              -- si no es en etapas viene nulo
              Update pr_solicitudes
                set can_des_faltantes = can_des_faltantes + 1
              where nro_solicitud = v_nro_sol_original;
          Exception
           when others then
             null;
          End;
          --- Verificar como afecta al prestamo la transaccion
          if v_afecta = 'C' then
             --- Reversar capital
             v_capital := rp_gmovi.monto;
          elsif v_afecta = 'I' then
             --- Reversar interés vencido
             v_interes := rp_gmovi.monto;
          elsif v_afecta = 'A' then
             --- Reversar interés adelantado
             v_int_adelantado := rp_gmovi.monto;
          elsif v_afecta = 'E' then
             --- Reversar recargos
             v_val_recargo := rp_gmovi.monto;
          end if;
          update pr_cuotas
             set estado = 'N',
                 sal_interes = 0,
                 sal_capital = 0,
                 sal_int_documentado = 0,
                 fec_ult_pago = rp_gmovi.fecha
           where nro_cuenta = rp_gmovi.nro_cuenta;
          update pr_cta_prestamos
             set sal_capital        = 0,
                 sal_interes        = 0,
                 sal_int_adelantado = 0,
                 fec_cancelacion    = rp_gmovi.fecha,
                 estado             = 'N',
                 nro_solicitud      = null
           where nro_cuenta = rp_gmovi.nro_cuenta;
       end if;
       --- Eliminar garantias
       delete from pr_cta_garantias
       where nro_cuenta = rp_gmovi.nro_cuenta;
     -- Recalcular línea
       if v_nro_linea is not null then
          prp_rec_apl_limite(v_nro_linea);
       end if;
    --- Reversión de Pase Operaciones vencidas ---
    Elsif rp_gmovi.nro_cuenta is not null and
       rp_gmovi.monto      <> 0           and
       rp_gmovi.cod_modulo = 15           and
       v_ope_pendiente     = 'N'          and
       rp_gmovi.cod_tra_padre in (358)    then -- pase a operaciones vencidas

          update ov_cta_vencidas
             set sal_total          = 0,
                 sal_tot_batch      = 0,
                 fec_ult_movimiento = rp_gmovi.fecha,
                 estado             = 'N'
           where nro_cuenta = rp_gmovi.nro_cuenta;
       --- Eliminar garantias de op. vencidas
       delete from ov_cta_garantias
       where nro_cuenta = rp_gmovi.nro_cuenta;

    --- Reversión de Cobros de Operaciones vencidas ---
   Elsif rp_gmovi.nro_cuenta  is not null and
       rp_gmovi.monto      <> 0        and
       rp_gmovi.cod_modulo = 15        and
       v_ope_pendiente     = 'N'       and
       rp_gmovi.cod_tra_padre in (139) then
       -- Recuperar datos de la operación vencida
       pav_ove.PR_OBT_DAT_OPE_VENCIDA(rp_gmovi.nro_cuenta, r_vcven);
       -- obtengo el tipo d/c y a que saldo afecto
       pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                             rp_gmovi.cod_modulo,
                             rp_gmovi.cod_modalidad,
                             v_tip_movimiento, v_afecta);
       --- Inicializar errores de pag_cta
       pag_cta.G_MSJ_ERROR := null;
       pag_cta.G_COD_ERROR := 0;
       --- Inicializar variables de descuento
       v_estado            := null;
       v_est_cuenta        := null;
       v_est_anterior      := null;
       v_capital           := 0;
       v_val_recargo       := 0;

       --- Recuperar fecha de ultimo pago y estado anterior de ov_cobros
       begin
          select fec_ult_pago, estado, estado into v_fec_ult_pago, v_estado, v_est_cuenta
            from ov_cobros
           where nro_cuenta = rp_gmovi.nro_cuenta
             and fecha      = rp_gmovi.fecha
             and hora       = rp_gmovi.hora;
          --- Actualizar el estado de la operación vencida
          update ov_cta_vencidas
             set estado = nvl(v_est_cuenta,estado),
                 fec_ult_movimiento = v_fec_ult_pago
           where nro_cuenta = rp_gmovi.nro_cuenta;
          exception
             when no_data_found then
                v_fec_ult_pago := null;
                v_estado := null;
       end;
       --- Verificar como afecta a la operación vencida la transaccion
       if v_afecta = 'S' then
          --- Reversar saldo
          v_capital := rp_gmovi.monto;
       elsif v_afecta = 'E' then
          --- Reversar recargos
          v_val_recargo := rp_gmovi.monto;
       end if;
/*       declare
          v_can_cambios number(8); -- para contar cambios o mov posteriores
       Begin
          -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
          select count(*)
            into v_can_cambios
            from movimientos_fabiola--gv_movimientos
           where nro_cuenta = rp_gmovi.nro_cuenta
             and ((fec_valor > rp_gmovi.fec_valor) or
                 (fec_valor = rp_gmovi.fec_valor and hora > rp_gmovi.hora))
             and reversado = 'N'
             and ((est_cuenta is not null and nvl(cod_tip_movimiento,'x')='E') or v_est_anterior is not null) -- si hubo otro cambio de estado posterior
             and rownum = 1;
          if nvl(v_can_cambios,0) > 0 then
             raise_application_error(-20000,'La cuenta '||rp_gmovi.nro_cuenta||
             ' tiene movimientos posteriores que deben ser reversados previamente.');
          end if;
          if v_fec_ult_mov_ant is not null then
             -- verifico sino hubo movimientos posteriores de la cuenta
             select count(*)
               into v_can_cambios
               from movimientos_fabiola--gv_movimientos
              where nro_cuenta = rp_gmovi.nro_cuenta
                and ((fecha > rp_gmovi.fecha) or
                     (fecha = rp_gmovi.fecha and hora > rp_gmovi.hora))
                and reversado = 'N'
                and monto > 0 -- si hubo un mov posterior
                and rownum = 1;
             if nvl(v_can_cambios,0) > 0 then
                -- en este caso nada mas no se actualiza los datos del ultimo mov
                v_fec_ult_mov_ant := null;
                v_hor_ult_mov_ant := null;
             end if;
          end if;
       exception
          when no_data_found then
             v_fec_ult_mov_ant := null;
             v_hor_ult_mov_ant := null;
          when others then
             raise_application_error(-20000,sqlerrm||' Buscando ge_cuentas_nov ');
       end;*/
       --- Actualizar maestro de op.vencidas
       update ov_cta_vencidas
          set sal_total          = nvl(sal_total,0) + nvl(v_capital,0)
        where nro_cuenta = rp_gmovi.nro_cuenta;

       -- actualizacion de garantias--
       v_con_garantia_ven := nvl(v_con_garantia_ven,0) + 1;
       if nvl(v_con_garantia_ven,0) = 1 then
       --Actualizar mto. aplicado de la garantia
           for i in garantias_ov(rp_gmovi.nro_cuenta) loop
             v_mto_apl_reversar := lf_obt_mto_apl_reversar
                                   (rp_gmovi.nro_cuenta,
                                    i.cod_garantia,
                                    i.nro_garantia,
                                    p_fecha,
                                    p_hora,
                                    p_cod_usuario);
             If i.cod_garantia = 1 then
               update ov_cta_garantias x
                  set x.mto_aplicado = nvl(x.mto_aplicado,0) + v_mto_apl_reversar
                where x.nro_cuenta  = rp_gmovi.nro_cuenta
                  and x.cod_garantia = i.cod_garantia;
             else
               update ov_cta_garantias x
                  set x.mto_aplicado = nvl(x.mto_aplicado,0) + v_mto_apl_reversar
                where x.nro_cuenta  = rp_gmovi.nro_cuenta
                  and x.cod_garantia = i.cod_garantia
                  and x.nro_garantia = i.nro_garantia;
             end if;
           End loop;
       end if;
       --Eliminar la novedad de la garantia
       delete ov_cta_garantias_nov
          where fecha       = P_FECHA
            and hora        = P_HORA
            and cod_usuario = P_COD_USUARIO
            and nro_cuenta  = rp_gmovi.nro_cuenta;

       --- Eliminar pr_cobros
       delete ov_cobros
        where nro_cuenta = rp_gmovi.nro_cuenta
          and fecha      = rp_gmovi.fecha
          and hora       = rp_gmovi.hora;

       --- actualizar pr_cta_gastos (gastos varios)
       IF nvl( v_val_recargo, 0 ) > 0 THEN
        DECLARE
          CURSOR gastos
              IS select nro_cuenta, monto, saldo, rowid
                   from ov_cta_gastos
                  where nro_cuenta = rp_gmovi.nro_cuenta
                    and ((cod_transaccion = rp_gmovi.cod_transaccion)
                     or  (rp_gmovi.concepto like 'Iva Gasto Manual '||cod_transaccion))
                    and nvl(saldo,0) < nvl(monto,0)
                  order by nro_cuenta, cod_modalidad, cod_transaccion, fec_ingreso desc;
        BEGIN
          v_sal_recargo := v_val_recargo; -- Si existe mas de un cargo con la misma transaccion
          FOR g IN gastos LOOP
              -- Si el gasto es mayor o igual al monto, actualizo la tabla ov_cta_gastos como NO cobrado
              BEGIN
              if nvl(v_val_recargo,0) + nvl(g.saldo,0) < nvl(g.monto,0) then
                ---
                update ov_cta_gastos
                   set fec_ult_pago = null,
                       hor_ult_pago = null,
                       saldo = nvl(saldo,0) + v_val_recargo
                 where nro_cuenta = rp_gmovi.nro_cuenta
                   and rowid = g.rowid;
                v_sal_recargo := v_sal_recargo - v_val_recargo;
              else
                update ov_cta_gastos
                   set fec_ult_pago = null,
                       hor_ult_pago = null,
                       saldo = g.monto
                 where nro_cuenta = rp_gmovi.nro_cuenta
                   and rowid = g.rowid;
                v_sal_recargo := v_sal_recargo - g.monto;
              end if;
              EXCEPTION
                when others then
                  NULL;
              END;
          END LOOP;
        END;
       END IF;
    elsif rp_gmovi.nro_cuenta is not null and
       rp_gmovi.monto      <> 0        and
       rp_gmovi.cod_modulo = 10         and
       v_ope_pendiente     = 'N'       and
       rp_gmovi.cod_tra_padre in (101) then -- COMPRA DOCUMENTO

       -- Actualizar el estado del documento
       if rp_gmovi.nro_cuenta  is not null then
          update md_cta_documentos
             set estado = 'S'
           where nro_cuenta = rp_gmovi.nro_cuenta ;

          --Actualizar los documentos relacionados
          For doc In documentos Loop
            update md_cta_documentos
               set estado = 'S'
             where nro_cuenta = doc.nro_cuenta ;
          End Loop;
       End If;
    Elsif rp_gmovi.nro_cuenta  is not null and
       rp_gmovi.monto      <> 0  and
       rp_gmovi.cod_modulo = 10  and
       v_ope_pendiente     = 'N' and
       rp_gmovi.cod_tra_padre = 102 then
       -- Recuperar datos del documento
       pam_doc.pr_obt_datos(rp_gmovi.nro_cuenta, r_docu);
       -- obtengo el tipo d/c y a que saldo afecto
       pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                              rp_gmovi.cod_modulo,
                              rp_gmovi.cod_modalidad,
                              v_tip_movimiento, v_afecta);
       --- Inicializar errores de pag_cta
       pag_cta.G_MSJ_ERROR := null;
       pag_cta.G_COD_ERROR := 0;
       --- Inicializar variables de descuento
       v_estado            := null;
       v_est_cuenta        := null;
       v_est_anterior      := null;
       v_capital           := 0;
       v_interes           := 0;
       v_val_recargo       := 0;
       v_int_descontado    := 0;
       v_devengado         := 0;
       v_capital_deven     := 0;
       v_mto_cap_cuota     := 0;
       v_mto_dev_actual    := 0;
       v_cu_dev_acumulado  := 0;

       --- Verificar como afecta al prestamo la transaccion
       if v_afecta = 'C' then
          --- Reversar capital
          v_capital := rp_gmovi.monto;
       elsif v_afecta = 'I' then
          --- Reversar interes vencido
          v_interes := rp_gmovi.monto;
       end if;

       If v_devengo = 'N' Then
         v_devengo := 'S';
         --- Recuperar datos del devengado
         begin
            Begin
              select estado, mto_dev_actual,fec_inicio
                into v_est_cuenta, v_mto_dev_actual, v_fec_ini_dev
                from md_devengados
               where nro_cuenta = rp_gmovi.nro_cuenta
                 and fecha      = rp_gmovi.fecha;

              v_fec_ult_devengado := pag_cal.FU_OBT_FEC_ANT_HAB(rp_gmovi.fecha,rp_gmovi.cod_ofi_origen);

            Exception
              When no_data_found Then
                v_fec_ult_devengado := Null;
                v_est_cuenta        := Null;
                v_mto_dev_actual    := Null;
            End;

            --- Actualizar el documento en el devengado ya la primera vez
           /* update md_cta_documentos
               set dev_acumulado     = nvl(dev_acumulado,0) - nvl(v_mto_dev_actual,0),
                   val_int_devengar  = nvl(val_int_devengar,0) + nvl(v_mto_dev_actual,0),
                   fec_ult_devengado = v_fec_ult_devengado,
                   estado            = nvl(v_est_cuenta,estado)
             where nro_cuenta = rp_gmovi.nro_cuenta;
          */
            --- Actualizar el devengado de la cuota en pr_devengados
            --- Solo si devengo, si se cambio los suspendidos o cobros nada mas no tocar
            if nvl(v_mto_dev_actual,0) <> 0 then
               --v_fec_ini_dev := nvl(v_fec_ult_devengado,r_docu.fec_inicio);

               --- Recuperar capital segun el tipo de documento
               if r_docu.tip_calculo = 'A' then
                  v_capital_deven := nvl(r_docu.val_presente,0) + nvl(r_docu.mto_interes,0) ;
               else
                 If r_docu.fec_vencimiento > v_fec_ini_dev  Then
                   v_capital_deven := nvl(r_docu.val_presente,0);
                 End If;
               end if;

               --- Recuperar capital
               --- Solo se reversa si devengo el dia del cobro por esa fecha o adelantado
               if v_fec_ult_devengado is null then
                 --se elimina md_devengados
                 delete md_devengados
                  where nro_cuenta = rp_gmovi.nro_cuenta
                    /*and fec_inicio = v_fec_ini_dev
                    and val_tasa   = r_docu.val_tasa
                    and estado     = v_est_cuenta
                    and cod_moneda = r_docu.cod_moneda
                    and capital    = v_capital_deven*/;
               else
                 update md_devengados
                    set fecha = v_fec_ult_devengado,
                        mto_dev_acumulado = mto_dev_acumulado - mto_dev_actual,
                        can_dia_interes   = nvl(can_dia_anterior,0),
                        mto_dev_actual    = nvl(mto_dev_anterior,0),
                        mto_ajuste        = null,
                        fec_ult_devengado = v_fec_ult_devengado
                  where nro_cuenta = rp_gmovi.nro_cuenta
                    /*and fec_inicio = v_fec_ini_dev
                    and val_tasa   = r_docu.val_tasa
                    and estado     = v_est_cuenta
                    and cod_moneda = r_docu.cod_moneda
                    and capital    = v_capital_deven*/;
               end if;
            end if;
         end;
       End If;
       --
 /*      declare
          v_can_cambios number(8); -- para contar cambios o mov posteriores
       Begin
          -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
          select count(*)
            into v_can_cambios
            from ge_movimientos
           where nro_cuenta = rp_gmovi.nro_cuenta
             and hora > rp_gmovi.hora
             and reversado = 'N'
             and (est_cuenta is not null or v_est_anterior is not null) -- si hubo otro cambio de estado posterior
             and rownum = 1;
          if nvl(v_can_cambios,0) > 0 then
             raise_application_error(-20000,'La cuenta '||rp_gmovi.nro_cuenta||
             ' tiene movimientos posteriores que deben ser reversados previamente.');
          end if;
          if v_fec_ult_mov_ant is not null then
             -- verifico sino hubo movimientos posteriores de la cuenta
             select count(*)
               into v_can_cambios
               from ge_movimientos
              where nro_cuenta = rp_gmovi.nro_cuenta
                and hora > rp_gmovi.hora
                and reversado = 'N'
                and monto > 0 -- si hubo un mov posterior
                and rownum = 1;
             if nvl(v_can_cambios,0) > 0 then
                -- en este caso nada mas no se actualiza los datos del ultimo mov
                v_fec_ult_mov_ant := null;
                v_hor_ult_mov_ant := null;
             end if;
          end if;
       exception
          when no_data_found then
             v_fec_ult_mov_ant := null;
             v_hor_ult_mov_ant := null;
          when others then
             raise_application_error(-20000,sqlerrm||' Buscando ge_cuentas_nov ');
       end;*/
       --- Actualizar maestro del documento
       prg_rev_auditoria('MD_CTA_DOCUMENTOS',
                         rp_gmovi.fec_insercion,
                         rp_gmovi.cod_usuario,
                         rp_gmovi.nro_cuenta);
       -- Actualiza MD_DOC_DETALLES
       prg_rev_auditoria('MD_DOC_DETALLES',
                         rp_gmovi.fec_insercion,
                         rp_gmovi.cod_usuario,
                         rp_gmovi.nro_cuenta);
    Elsif rp_gmovi.nro_cuenta  is not null and
      rp_gmovi.monto      <> 0  and
      rp_gmovi.cod_modulo = 10  and
      v_ope_pendiente     = 'N' and
      rp_gmovi.cod_tra_padre = 360 then
      --
      v_capital := 0;
      v_interes := 0;
      -- Recuperar datos del documento
      pam_doc.pr_obt_datos(rp_gmovi.nro_cuenta, r_docu);
      -- obtengo el tipo d/c y a que saldo afecto
      pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
      rp_gmovi.cod_modulo,
      rp_gmovi.cod_modalidad,
      v_tip_movimiento, v_afecta);
      --- Inicializar errores de pag_cta
      pag_cta.G_MSJ_ERROR := null;
      pag_cta.G_COD_ERROR := 0;

      --- Verificar como afecta al prestamo la transaccion
      if v_afecta = 'C' then
         --- Reversar capital
         v_capital := rp_gmovi.monto;
         v_interes := 0;
      elsif v_afecta = 'I' then
         --- Reversar interes vencido
         v_interes := rp_gmovi.monto;
         v_capital := 0;
      end if;
      --
      begin
      -- reverso El documento
      prg_rev_auditoria('MD_CTA_DOCUMENTOS',
                         rp_gmovi.fec_insercion,
                         rp_gmovi.cod_usuario,
                         rp_gmovi.nro_cuenta);
      exception
         when others then
            raise_application_error(-20000,'Error al modificar MD_CTA_DOCUMENTOS. '||sqlerrm);
      end;
      --
      begin
         update md_doc_detalles
         set sal_interes = nvl(sal_interes,0) + nvl(v_interes,0),
         sal_capital = nvl(sal_capital,0) + nvl(v_capital,0),
         mto_int_descontado = 0,
         estado = 'C',
         fec_ult_pago = null
         where nro_cuenta = rp_gmovi.nro_cuenta
         and nro_cuota = rp_gmovi.NRO_DOCUMENTO;
      exception
         when others then
            raise_application_error(-20000,'Error update MD_DOC_DETALLES. '||sqlerrm);
      end;
    Elsif rp_gmovi.monto  <> 0 and
      rp_gmovi.cod_modulo = 16    and
      v_ope_pendiente     = 'N'   and
      rp_gmovi.cod_tra_padre in (369,987) Then --Cajas de Seguridad

      -- obtengo el tipo d/c y a que saldo afecto
      pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                             rp_gmovi.cod_modulo,
                             rp_gmovi.cod_modalidad,
                             v_tip_movimiento, v_afecta);
      --- Inicializar errores de pag_cta
      pag_cta.G_MSJ_ERROR := null;
      pag_cta.G_COD_ERROR := 0;
       --- Inicializar variables de descuento
      v_estado            := null;
      v_capital           := 0;
                 --- Verificar como afecta al prestamo la transaccion
      if v_afecta = 'C' or  rp_gmovi.cod_transaccion = 518 then
        --- Reversar capital
        v_capital := rp_gmovi.monto;
      end if;

/*      declare
        v_can_cambios number(8); -- para contar cambios o mov posteriores
      Begin
        -- verifico sino hubo un mov. posterior
        select count(*)
          into v_can_cambios
          from movimientos_fabiola--gv_movimientos
         where nro_documento = rp_gmovi.nro_documento
           and ((fec_valor > rp_gmovi.fec_valor) or
               (fec_valor = rp_gmovi.fec_valor and hora > rp_gmovi.hora))
           and reversado = 'N'
           and cod_mod_padre = 16
           and rownum = 1;
        if nvl(v_can_cambios,0) > 0 then
           raise_application_error(-20000,'El Contrato '||rp_gmovi.nro_documento||
          ' tiene movimientos posteriores que deben ser reversados previamente.');
        end if;
      exception
        when others then
          raise_application_error(-20000,sqlerrm||' Buscando datos del contrato ');
      end;*/
      If nvl(rp_gmovi.monto,0) > 0 Then
         begin
         prg_rev_auditoria('CS_CONTRATOS',
                     rp_gmovi.fec_insercion,
                     rp_gmovi.cod_usuario,
                     rp_gmovi.nro_documento) ;
         exception
         when others then
         raise_application_error(-20000,sqlerrm||' Al actualizar el contrato ');
         end;
         begin
         prg_rev_auditoria('CS_CON_CUOTAS',
                     rp_gmovi.fec_insercion,
                     rp_gmovi.cod_usuario,
                     rp_gmovi.nro_documento) ;
         exception
         when others then
         raise_application_error(-20000,sqlerrm||' Al actualizar cuotas del contrato ');
         end;

        --- Actualizar la cuota afectada
      /*  update cs_con_cuotas
           set fec_pago    = Null,
               fec_pag_ant = fec_pag_ant,
               estado      = 'C',
               monto       = nvl(rp_gmovi.monto,0),
               saldo       = nvl(saldo,0) + nvl(rp_gmovi.monto,0)
         where nro_contrato = rp_gmovi.nro_documento
           and nro_cuota    = rp_gmovi.NRO_DOCUMENTO;
         -- Obtener el monto de la cuota anterior
         Select Sum(saldo)
           into v_mto_cuo_ant
           From cs_con_cuotas
          Where nro_contrato = rp_gmovi.nro_documento
            And estado = 'C'
            And nvl(saldo,0) > 0
            And nro_cuota = (rp_gmovi.NRO_DOCUMENTO);
         -- Actualizar contrato
        Update cs_contratos
           Set fec_sig_pago = fec_ult_pago,
               mto_adeudado = mto_adeudado + ( nvl(rp_gmovi.monto,0) ),
               mto_cuota = nvl(v_mto_cuo_ant,0)
         Where nro_contrato = rp_gmovi.nro_documento;*/
      End If;
    End if;
END;
/* Actualiza los movimientos historicos a reversado. */
PROCEDURE LP_ACT_DAT_HISTO
 (P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN GE_MOVIMIENTOS.HORA%TYPE
 ,P_COD_USUARIO IN GE_MOVIMIENTOS.COD_USUARIO%TYPE
 ,P_NRO_SECUENCIA IN GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_COD_USU_INSERCION IN GE_MOVIMIENTOS.COD_USU_REVERSION%TYPE
 ,P_HOR_REVERSION IN GE_MOVIMIENTOS.HOR_REVERSION%TYPE
 ,P_COD_MODULO IN GE_MOVIMIENTOS.COD_MODULO%TYPE
 )
 IS
BEGIN
    -- AHORRO
    IF P_COD_MODULO = 3 THEN
        UPDATE AH_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N'
        AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
    -- CUENTA CORRIENTE
    ELSIF P_COD_MODULO = 4 THEN
        UPDATE CC_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N'
        AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
    -- TARJETA
    ELSIF P_COD_MODULO = 5 THEN --NO EXISTE
        UPDATE TA_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
        hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N';
    END IF;
END;
---------------- función garantias de operaciones vencidas
function lf_obt_mto_apl_reversar(p_nro_cuenta   in varchar2,
                                 p_cod_garantia in number,
                                 p_nro_garantia in number,
                                 p_fecha        in date,
                                 p_hora         in varchar2,
                                 p_cod_usuario  in varchar2)  return number is
 --Obtiene el monto a reversar de la garantia--
 --segun sus registros de novedades--
v_mto_apl_reversar number(18,2) := 0;

begin
 --Obtener el monto a reversar--
 select a.mto_aplicado
   into v_mto_apl_reversar
   from ov_cta_garantias_nov a
  where a.fecha = p_fecha
    and a.hora = p_hora
    and a.cod_usuario = p_cod_usuario
    and a.nro_cuenta = p_nro_cuenta
    and a.cod_garantia = p_cod_garantia
    and nvl(a.nro_garantia,999) = nvl(p_nro_garantia,999);
  return v_mto_apl_reversar;
exception
   when others then
     raise_application_error(-20000,'Error en fl_obt_mto_apl_reversar : '||sqlerrm);
end;
---------------------------------------------------------------------------
--Traer datos de la retencion
procedure lp_obt_retencion(p_nro_cuenta ah_retenciones.nro_cuenta%type,
                           p_nro_documento ah_retenciones.nro_documento%type,
                           p_cod_retencion ah_retenciones.cod_retencion%type,
                           p_fec_inicio ah_retenciones.fec_inicio%type,
                           rp_ah_retenciones in out ah_retenciones%rowtype) is

begin

      select *
        into rp_ah_retenciones
        from ah_retenciones
       where nro_cuenta = p_nro_cuenta
         and nro_documento = p_nro_documento
         and cod_retencion = p_cod_retencion
         and fec_inicio = p_fec_inicio;
exception
   when others then
     raise_application_error(-20000,'Error en lp_obt_retencion : '||sqlerrm);

end;


/* PROCESO PRINCIPAL DEL PROCEDIMIENTO */
BEGIN
    --
    v_es_nocturno := p_es_nocturno;
    --
    --- Inicializar errores de pag_cta
    pag_cta.G_MSJ_ERROR := null;
    pag_cta.G_COD_ERROR := 0;

    IF p_es_nocturno = 'X' THEN
       -- Buscar si es nocturno o diurno
       v_est_modulo := pae_cnf.fu_obt_est_modulo(pae_cnf.g_cod_modulo);
       IF v_est_modulo = 2 THEN
          v_es_nocturno := 'N';
       ELSE
          v_es_nocturno := 'S';
       END IF;
    END IF;
    -- Verificar si existian movimientos pendientes de pasar por caja
    IF p_cod_tra_padre iN (101,102,358,359,360,362,364,139)
    or p_cod_tra_padre in (384,150) THEN --- Comercio Exterior
       --- Por el momento solo prestamos genera movimientos pendientes de pasar
       --- por caja
      begin
       select 'S' into v_ope_pendiente
         from ge_movimientos
        where cod_mod_padre <> 9
          and estado        = 'N'
          and reversado     = 'N'
          and cod_transaccion in (840,740,607,610,632,606)
          and cod_usuario   = p_cod_usuario
          and fecha         = p_fecha
          and hora          = p_hora
          and nro_caja      is not null; -- Que haya pasado por caja
       exception
        when no_data_found then
             v_ope_pendiente := 'N';
        when too_many_rows then
             v_ope_pendiente := 'S';
      end;
   END IF;
    --
    IF V_ES_NOCTURNO = 'N' THEN
        V_FEC_ACTUAL := PAG_CAL.FU_OBT_FEC_ACTUAL(p_cod_mod_padre);
        --
        IF P_FECHA < V_FEC_ACTUAL THEN  --MOV. DEL HISTORICO
            LP_BUS_DAT_HISTO(p_fecha,p_hora,p_cod_usuario,p_cod_mod_padre,
                             p_cod_usu_reversion,p_hor_reversion);
        ELSIF P_FECHA = V_FEC_ACTUAL THEN
           --
           FOR C1 IN CUR_GMOVI LOOP
              LP_INS_MOVIMIENTOS(C1,P_COD_USU_REVERSION,P_HOR_REVERSION,'N');
           END LOOP;
           IF V_OPE_PENDIENTE = 'N' THEN
              UPDATE GE_MOVIMIENTOS
              SET reversado = 'S',
              cod_usu_reversion = p_cod_usu_reversion,
                  hor_reversion = p_hor_reversion
              WHERE       fecha = p_fecha
              AND          hora = p_hora
              AND   cod_usuario = p_cod_usuario
              AND     reversado = 'N'
              AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
           END IF;
        END IF;
        --
    ELSIF V_ES_NOCTURNO = 'S' THEN
        FOR C1 IN CUR_GMONO LOOP
            LP_INS_MOVIMIENTOS(C1,P_COD_USU_REVERSION,P_HOR_REVERSION,'S');
        END LOOP;
        IF V_OPE_PENDIENTE = 'N' THEN
           UPDATE GE_MOVIMIENTOS_NOC
           SET reversado = 'S',
           cod_usu_reversion = p_cod_usu_reversion,
               hor_reversion = p_hor_reversion
           WHERE       fecha = p_fecha
           AND          hora = p_hora
           AND   cod_usuario = p_cod_usuario
           AND     reversado = 'N'
           AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO;
        END IF;
    END IF;
    --
    IF V_OPE_PENDIENTE = 'S' and V_OPE_AHORROS = 'S' then
       --- Se realizo la reversion del ahorro
       --- Modificar movimientos de importes
       update ge_movimientos
          set estado = 'J', nro_caja = null
        where cod_usuario = p_cod_usuario
          and fecha       = p_fecha
          and hora        = p_hora
          AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO
          and reversado    = 'N'
          and cod_modulo  in (3,4)
          and cod_modalidad <> 43
          and monto is not null;
       --- Eliminar movimientos de cambios de estado
       delete ge_movimientos
        where cod_usuario = p_cod_usuario
          and fecha       = p_fecha
          and hora        = p_hora
          AND NRO_DOCUMENTO+0 = P_NRO_DOCUMENTO
          and cod_modulo  in (3,4)
          and reversado    = 'N'
          and cod_modalidad <> 43
          and monto is null;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20000,sqlerrm||' Fecha: '||p_fecha||' hora: '||p_hora||
                               ' Cod. usuario: '||p_cod_usuario||
                               ' Cod. Mod. Padre: '||p_cod_mod_padre);
END;
/

