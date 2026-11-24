CREATE OR REPLACE PROCEDURE IT.PRG_REV_OPERACION_ATM
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
 ,P_NRO_DOCUMENTO3  IN GE_MOVIMIENTOS.NRO_DOCUMENTO3%TYPE
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
v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
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
r_ah_retenciones ah_retenciones%rowtype;
-- Transaccion 346
v_ord_pago ge_pag_proveedores.nro_orden%type;
v_cod_ente   ge_entes.cod_ente%type;
-- solo para conexion con la as/400
v_ok     varchar2(1);
---
type vector is table of varchar2(300) index by
                              binary_integer;
--- Vectores
v_pedido vector;
v_can_pedidos number(3) := 0;
--v_pedido varchar2(400) := null;
v_respuesta varchar2(4000);
v_nro_operacion varchar2(10);
v_cta_enviada varchar2(20);
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
    AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3
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
    AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3
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

--R_GMOVI GE_MOVIMIENTOS%ROWTYPE;
/*
CURSOR CUR_AHORRO IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO--,REFERENCIA
    FROM AH_MOVIMIENTOS_HIS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    ORDER BY NRO_SECUENCIA DESC;
    --
CURSOR CUR_CTACTE IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO--,REFERENCIA
    FROM CC_MOVIMIENTOS_HIS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    ORDER BY NRO_SECUENCIA DESC;
    --
  CURSOR CUR_TARJETA IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO,REFERENCIA
    FROM TA_MOVIMIENTOS_HIS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    ORDER BY NRO_SECUENCIA DESC;
    --
CURSOR CUR_PRESTAMO IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO--,REFERENCIA
    FROM PR_MOVIMIENTOS_HIS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    ORDER BY NRO_SECUENCIA DESC;
    --
CURSOR CUR_CAMBIO IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO--,REFERENCIA
    FROM LC_MOVIMIENTOS_HIS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    ORDER BY NRO_SECUENCIA DESC;
    --
 CURSOR CUR_COMERCIO IS
    SELECT FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,FEC_VALOR,MONTO,NRO_CUENTA,COD_MONEDA,
           COD_OFICINA,COD_ERROR,COD_RETENCION,FEC_FIN_RETENCION,EST_CUENTA,ESTADO,COD_CAUSA,
           COD_BANCO,COD_OFI_ORIGEN,CONCEPTO,COD_TASA,VAL_TASA,COD_RUBRO,COD_REF_CAMBIO,REVERSADO,
           COD_USU_REVERSION,HOR_REVERSION,EMI_AVISO,COD_TRA_PADRE,COD_MOD_PADRE,COD_MAD_PADRE,
           COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,MTO_EQU_LOCAL,NRO_CAJA,COTIZACION,COD_BCO_CENTRAL,
           NRO_DOCUMENTO,NRO_DOCUMENTO2,NRO_DOCUMENTO3,NRO_DOCUMENTO4,PROTEGIDO,COD_AUTORIZACION,
           COD_USU_AUTORIZADOR,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,
           TIP_MOV_RUBRO,COD_TIP_OPE_CAMBIO,REFERENCIA
    FROM CE_MOVIMIENTOS_HIS
    WHERE       FECHA = P_FECHA
    AND          HORA = P_HORA
    AND   COD_USUARIO = P_COD_USUARIO
    AND REVERSADO     = 'N'
    ORDER BY NRO_SECUENCIA DESC; */
    --
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
    AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3
    ORDER BY NRO_SECUENCIA DESC;
BEGIN
  FOR c1 in cur_modulos LOOP
    --- Validaciones previas
    --- Solicitado por BR: No permitir reversar movimientos con IVA en fechas pasadas
    /*
    if v_tip_implementacion = 1 and
         c1.fecha < to_date('01' || to_char(v_fec_actual, 'mmyyyy'),'ddmmyyyy') then
       lp_val_iva(c1);
    end if;
    */
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
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    -- PRESTAMO
    ELSIF c1.COD_MODULO = 6 THEN
        UPDATE PR_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    --  CAMBIOS
    ELSIF c1.COD_MODULO = 7 THEN
        UPDATE LC_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    -- COMERCIO EXTERIOR
    ELSIF c1.COD_MODULO = 8 THEN
        UPDATE CX_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
     -- MESA DE DINERO
    ELSIF c1.COD_MODULO = 10 THEN
        UPDATE MD_MOVIMIENTOS_HIS
           SET reversado = 'S',
               cod_usu_reversion = p_cod_usu_reversion,
               hor_reversion = p_hor_reversion
         Where fecha = p_fecha
           AND hora = p_hora
           AND cod_usuario = p_cod_usuario
           AND reversado = 'N'
           AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    ELSIF c1.COD_MODULO = 13 THEN
        UPDATE AF_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
v_nro_cuo_cci       number(4);
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
    else --- Préstamos y operaciones vencidas
       if r_gmovi.cod_mod_padre <> 9 then
          if  r_gmovi.estado = 'N'
          and r_gmovi.nro_caja is not null --- Existen operaciones de cobros automaticos de cheques custodia
          and r_gmovi.cod_transaccion in (840,740,607,610,632,606) then
             --- Reversion de operacion de cheque o efectivo que no se
             --- inicio en caja
             --- Esto funciona porque la ultima secuencia corresponde a la
             --- forma de pago pendiente de pasar por caja
             update ge_movimientos
                set estado = 'J', NRO_CAJA = NULL, cod_oficina = cod_ofi_origen
              where fecha         = rp_gmovi.fecha
                and hora          = rp_gmovi.hora
                and nro_secuencia = rp_gmovi.nro_secuencia
                and cod_usuario   = rp_gmovi.cod_usuario;
          end if;
          if v_ope_pendiente = 'N' then
             PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,V_ES_NOCTURNO);
            -- AAP- Si tiene pr_cta_gastos, debo dejar
            -- disponible para un nuevo cobro.
            update pr_cta_gastos cg
                 set cg.fec_ult_pago = Null,
                     cg.hor_ult_pago = Null
            where cg.fec_ult_pago = rp_gmovi.fecha
            and  cg.hor_ult_pago = rp_gmovi.hora;
          end if;
       else
          --- Reversion de una operacion que se inicio y cerro en caja
          PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi,V_ES_NOCTURNO);
       end if;
    end if;
    -- Veo si hubo cambio de estado o fecha de movimiento
    declare
       v_can_cambios number(8); -- para contar cambios o mov posteriores
    Begin
       Select t.est_anterior, t.fec_cam_est_ant,
              t.fec_ult_mov_ant, t.hor_ult_mov_ant
         into v_est_anterior, v_fec_cam_est_ant,
              v_fec_ult_mov_ant, v_hor_ult_mov_ant
         from ge_cuentas_nov t
        where t.fecha = rp_gmovi.fecha
          and t.hora = rp_gmovi.hora
          and t.cod_usuario = rp_gmovi.cod_usuario
          and t.nro_cuenta = rp_gmovi.nro_cuenta;
        -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
        select count(*)
          into v_can_cambios
          from gv_movimientos
         where nro_cuenta = rp_gmovi.nro_cuenta
           and ((fec_valor > rp_gmovi.fec_valor) or
                (fec_valor = rp_gmovi.fec_valor and hora > rp_gmovi.hora))
           --and fec_insercion > rp_gmovi.fec_insercion
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
            from gv_movimientos
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
              v_est_anterior := null;
              v_fec_cam_est_ant := null;
              v_fec_ult_mov_ant := null;
              v_hor_ult_mov_ant := null;
        when others then
             raise_application_error(-20000,sqlerrm||' Buscando ge_cuentas_nov ');
    end;
    --restauro el estado de la cuenta de préstamos x reversión de incobrables
    if rp_gmovi.cod_tra_padre = 945 and
       rp_gmovi.cod_transaccion = 438 and --pase a incobrable
       rp_gmovi.cod_modulo = 6 and
       rp_gmovi.nro_cuenta is not null and
       v_est_anterior is not null then
       --actualizar las cuotas y el préstamo
       pap_mes.PR_ACT_EST_CUOTAS(rp_gmovi.nro_cuenta, v_est_anterior);--actualiza estado de cuotas
       pap_mes.PR_ACT_EST_PRESTAMO(rp_gmovi.nro_cuenta, v_est_anterior);--actualiza estado de prestamo
    end if;

    --restauro el estado de la cuenta de operaciones vencidas x reversión de incobrables
    if rp_gmovi.cod_tra_padre = 945 and
       rp_gmovi.cod_transaccion = 438 and --pase a incobrable
       rp_gmovi.cod_modulo = 15 and       -- operaciones vencidas
       rp_gmovi.nro_cuenta is not null and
       v_est_anterior is not null then
       --actualizar estado de la cuenta de operaciones vencidas
       begin
       update ov_cta_vencidas set
           estado         = est_anterior,
           fec_cam_estado = rp_gmovi.fecha
       where nro_cuenta = rp_gmovi.nro_cuenta;
       exception
          when others then
             RAISE_APPLICATION_ERROR( -20090, 'Al actualizar estado op. vencida' || sqlerrm);
       end;
    end if;

    -- restauro el estado de la cuenta --
    if rp_gmovi.nro_cuenta is not null and
       rp_gmovi.est_cuenta is not null and
       v_est_anterior is not null     and
       r_gmovi.cod_modulo in (3,4,7,8) then--and /* solo reversa ahorros por ahora */
--       r_gmovi.cod_modalidad <> 82 then -- Comex CCE se hace aparte
       pag_cta.pr_act_est_cta(rp_gmovi.nro_cuenta,
                              rp_gmovi.cod_modalidad,
                              v_est_anterior,
                              v_fec_cam_est_ant);
    end if;
    -- restauro el estado del cupon   -- POR AHORA SOLO POR CANCELACION
    if rp_gmovi.cod_transaccion in (407,423) -- Cambio estado del cupon
    and rp_gmovi.cod_tra_padre  = 301        -- Cancelacion
    and rp_gmovi.cod_modulo    in (3,4)
    and rp_gmovi.est_cuenta     = 'P' then
       update ah_cupones
          set estado = decode(rp_gmovi.cod_transaccion,407,'E','V'),
              fec_pago = null
        where nro_cuenta = rp_gmovi.nro_cuenta
          and nro_cupon  = rp_gmovi.nro_documento;
    end if;
    -- verificar si es cobro de servicios
    IF rp_gmovi.nro_cuenta IS NOT NULL AND
       rp_gmovi.cod_modalidad IN( 31, 41 ) AND
       (fug_es_servicio(rp_gmovi.nro_cuenta, rp_gmovi.cod_tra_padre) = 'S' or --transaccion o tra_comision
        fug_es_servicio(rp_gmovi.nro_cuenta, rp_gmovi.cod_tra_padre, rp_gmovi.cod_tra_padre) = 'S') THEN
      --ver si es la remisión o el cobro lo que se reversa
      if rp_gmovi.nro_documento2 is not null then --si corresponde al servicio
         begin
            select 'x'
              into v_remision
              from ge_cob_ser_parametros
             where cod_servicio = rp_gmovi.nro_documento2;
         exception
            when others then
               raise_application_error(-20060,'Recup.Servicio '||rp_gmovi.nro_documento2||'.'||sqlerrm);
         end;
      end if;
      if v_remision is null then --es un cobro
         -- borrar el registro de cobro de servicios
         declare
           v_nro_remision ge_cob_servicios.nro_remision%type;
           v_fec_remision ge_cob_servicios.fec_remision%type;
         BEGIN
           select nro_remision, fec_remision
             into v_nro_remision, v_fec_remision
            from ge_cob_servicios s
            where s.fecha = p_fecha
              and s.hora = p_hora
              and s.cod_usuario = p_cod_usuario;
           if v_nro_remision is not null or v_fec_remision is not null then
               raise_application_error(-20059,'El cobro ya fue remitido. Rem.Nro. '||v_nro_remision);
           end if;
         exception
             when no_data_found then
                --porque esto hace x mov., y una sola vez encuentra y luego borra
                null;
         end;
         --actualizar las cuotas si corresponde
         begin
            update ge_cob_ser_cuotas
               set estado = 'I',
                   fec_cobro = null
             where estado ='P'
               and fec_cobro = p_fecha
               and (cod_servicio, nro_cuenta, referencia, nro_cuota)
                   in (select cod_servicio, nro_cuenta, referencia1, nro_cuota
                         from ge_cob_servicios s
                        where s.fecha = p_fecha
                          and s.hora = p_hora
                          and s.cod_usuario = p_cod_usuario
                          and s.nro_remision is null
                          and s.fec_remision is null
                          and s.tip_cobro in ('P', 'M') --proceso o manual (si el proceso no pudo cobrar)
                          and exists (select '*'
                                     from ge_cob_ser_parametros x -- esto funciona porque uno de los mov
                                     where nro_cuenta = rp_gmovi.nro_cuenta --es el crédito a la cta del serv
                                     and nvl(cod_transaccion,215) = rp_gmovi.cod_tra_padre
                                     and s.cod_servicio = x.cod_servicio));
         exception
             when others then
                RAISE_APPLICATION_ERROR( -20055, 'Act.Cuotas.Srv. ' || sqlerrm);
         end;
         begin
           delete ge_cob_servicios s
            where s.fecha = p_fecha
              and s.hora = p_hora
              and s.cod_usuario = p_cod_usuario
              and s.nro_remision is null
              and s.fec_remision is null
              and exists (select '*'
                         from ge_cob_ser_parametros x -- esto funciona porque uno de los mov
                         where nro_cuenta = rp_gmovi.nro_cuenta --es el crédito a la cta del serv
                         and nvl(cod_transaccion,215) = rp_gmovi.cod_tra_padre
                         and s.cod_servicio = x.cod_servicio);
         EXCEPTION
            when others then
              RAISE_APPLICATION_ERROR( -20055, 'Al eliminar el servicio ' || sqlerrm);
         END;
      else --es una remisión
         --ver que sea la última remisión realizada, no se puede reversar en cualquier orden
         if v_pri_vez = 'S' then --sólo una vez, luego se borra el resumen
            v_pri_vez := 'N';
            declare
               v_ult_remision ge_cob_servicios_res.nro_remision%type;
            begin
               select nvl(max(nro_remision),0)
                 into v_ult_remision
                 from ge_cob_servicios_res
                where cod_servicio = rp_gmovi.nro_documento2
                  and fec_remision = p_fecha;
               if v_ult_remision > rp_gmovi.nro_documento then
                  raise_application_error(-20062,'Existen remisiones posteriores del servicio que deben ser reversardas previamente.' );
               end if;
            end;
         end if;
         --los débitos se reversan normalmente x la cuenta
         --actualizar los cobros a no remitidos
         Update GE_COB_SERVICIOS
            set NRO_REMISION = null,
                FEC_REMISION = null
          where FEC_REMISION = p_fecha
            and NRO_REMISION = rp_gmovi.nro_documento
            and COD_SERVICIO = rp_gmovi.nro_documento2;
         --eliminar resumen de remisión
         delete ge_cob_servicios_res
          where cod_servicio = rp_gmovi.nro_documento2
            and fec_remision = p_fecha
            and nro_remision = rp_gmovi.nro_documento;
         -----ACTUALIZAR LA TABLA GE_COB_SER_PARAMETROS----
         declare
            v_fec_rem_ant ge_cob_servicios_res.fec_remision%type;
            v_nro_rem_Ant ge_cob_servicios_res.nro_remision%type;
         begin
            begin
            select fec_remision, nro_remision
              into v_fec_rem_ant, v_nro_rem_ant
              from ge_cob_servicios_res
             where cod_servicio = rp_gmovi.nro_documento2
               and nro_remision = (select max(nro_remision)--x si hubiera mas de una remisión x fecha
                                     from ge_cob_servicios_res
                                    where cod_servicio = rp_gmovi.nro_documento2);
            exception
               when no_data_found then
                  v_fec_rem_ant := null;
                  v_nro_rem_ant := null;
            end;
            update GE_COB_SER_PARAMETROS
               set FEC_ULT_REMISION = v_fec_rem_ant,
                   SIG_NRO_REMISION = nvl(v_nro_rem_ant,0) + 1
             where COD_SERVICIO = rp_gmovi.nro_documento2;
          exception
             when others then
                raise_application_error(-20061,'Act.Ser.Param. '||rp_gmovi.nro_documento2||' - '||sqlerrm);
          end;
      end if;
    END IF;
    -- fin cobro de servicios
    -- pago a proveedores
    if rp_gmovi.nro_documento3 is not null then
       --recuperar datos del ente
       begin
         select tipo
           into v_tipo
           from ge_entes
          where cod_ente = RP_GMOVI.nro_documento3;
       exception
          when no_data_found then
             null;
       end;
       if v_tipo = 'PR' then
          --reversión del pago
          if rp_gmovi.nro_documento is not null and rp_gmovi.nro_documento2 is not null then
              --verificar si hay orden de pago en proveedores por ese nro.
              begin
                select cod_ente, fec_proceso
                  into v_proveedor, v_fec_proceso
                  from ge_pag_proveedores
                 where nro_orden  = rp_gmovi.nro_documento2
                   and nro_recibo = rp_gmovi.nro_documento
                   and cod_ente   = rp_gmovi.nro_documento3
                   and estado = 'N'; --pagado
              exception
                when no_data_found then
                     null;
              end;
              --actualizar proveedores
              if v_proveedor is not null then
                --sólo si no se debitó la comisión
                if v_fec_proceso is not null then
                   raise_application_error(-20554,'No puede reversar el pago. Ya se realizó el débito a la empresa.');
                end if;
                begin
                  update ge_pag_proveedores
                     set estado = 'C',
                         nro_recibo = null,
                         nro_cheque = null
                   where cod_ente = v_proveedor
                    and nro_orden = rp_gmovi.nro_documento2
                    and nro_recibo = rp_gmovi.nro_documento;
                exception
                   when others then
                      raise_application_error(-20555,'Act. ge_pag_proveedores '||v_proveedor);
                end;
              end if;
           end if;
           --reversión del cobro de comisión
           if rp_gmovi.nro_documento3 is not null and rp_gmovi.cod_tra_padre in(372,373) then -- comision y cargo deja los registros pendientes
              --actualizar proveedores
              begin
                update ge_pag_proveedores
                   set fec_proceso = null,
                       hora = null
                 where cod_ente = rp_gmovi.nro_documento3
                   and fec_proceso is not null
                   and hora = p_hora
                   and estado = 'N';
                  if sql%notfound then
                      raise_application_error(-20556,'No encontró débito por comisión pago a proveedor '||rp_gmovi.nro_documento3);
                  end if;
              exception
                 when others then
                    if sqlcode <= -20000 then
                       raise;
                    else
                       raise_application_error(-20556,'Act. fec_proceso ge_pag_proveedores '||v_proveedor);
                    end if;
              end;
           end if;
       end if;--proveedor
    end if;
    -- fin pago a proveedores
    -- restauro el estado del certificado -- POR AHORA SOLO POR CANCELACION
    if rp_gmovi.cod_transaccion = 422 -- Cambio estado del certificado
    and rp_gmovi.cod_tra_padre  = 301 -- Cancelacion
    and rp_gmovi.cod_modulo    in (3,4)
    and rp_gmovi.est_cuenta     = 'V' then
       update ah_cta_certificados
          set est_certificado = 'E'
        where nro_cuenta = rp_gmovi.nro_cuenta;
    end if;
    if rp_gmovi.cod_transaccion = 903 --- Reversion de ajuste del devengado
    and rp_gmovi.cod_tra_padre  = 301
    and rp_gmovi.cod_modulo    in (3,4) then
      UPDATE AH_DEVENGADOS
         SET MTO_INTERES = round((val_tasa*sal_acumulado/36500),0), --- Devengado de un dia
             MTO_DEV_ACUMULADO = NVL(MTO_DEV_ACUMULADO,0) + (NVL(rp_gmovi.monto,0)*-1)
       WHERE NRO_CUENTA = rp_gmovi.nro_cuenta
         AND FECHA      = rp_gmovi.fecha;
       --- Reversar historico de devengado
      UPDATE AH_DEVENGADOS_HIS SET
             MTO_INTERES = mto_interes + (rp_gmovi.monto*-1)
       WHERE COD_MODULO = rp_gmovi.cod_modulo
         AND COD_MODALIDAD = rp_gmovi.cod_modalidad
         AND COD_OFICINA = rp_gmovi.cod_oficina
         AND NRO_CUENTA = rp_gmovi.nro_cuenta
         AND ANO = TO_NUMBER(TO_CHAR(rp_gmovi.fecha,'YYYY'))
         AND MES = TO_NUMBER(TO_CHAR(rp_gmovi.fecha,'MM'));
    end if;
    if rp_gmovi.cod_transaccion = 522
    and rp_gmovi.cod_tra_padre = 321
    and rp_gmovi.cod_modulo in (3,4) then --Reversion de cheques devueltos
      UPDATE GE_CHEQUES_DET
         SET ESTADO = 'I'
       WHERE NRO_CUENTA = rp_gmovi.nro_cuenta
         AND NRO_CHEQUE = to_number(rp_gmovi.nro_documento)
         AND MONTO = rp_gmovi.monto;
    End if;
    if rp_gmovi.cod_tra_padre = 229 and rp_gmovi.cod_modulo in (3,4)
    and (rp_gmovi.nro_cuenta is not null or rp_gmovi.cod_rubro is not null) then -- giros emitidos
      declare
        v_cod_estado varchar2(1);
      begin
        select cod_estado
          into v_cod_estado
          from ge_giros
         where nro_operacion = rp_gmovi.nro_documento
           and nro_cta_debito = nvl(rp_gmovi.nro_cuenta, rp_gmovi.cod_rubro)
           and monto = rp_gmovi.monto;
        if v_cod_estado = '3' then -- pagado
          raise_application_error(-20000,'El giro ya fue pagado.');
        elsif v_cod_estado <> '2' then -- cobrado
          raise_application_error(-20000,'Estado del giro no permite reversion.');
        end if;
        -- actualiza el estado del giro
        update ge_giros
           set cod_estado = '4' -- anulado
         where nro_operacion = rp_gmovi.nro_documento;
      exception
        when no_data_found then
          raise_application_error(-20000,'No se encontró la operacion de giro emitido. ' || rp_gmovi.nro_documento);
        when others then
          raise_application_error(-20000,'Problema al obtener datos de giro emitido. ' || sqlerrm);
      end;
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
       if rp_gmovi.cod_tra_padre in (138,132,322) and rp_gmovi.nro_cuenta is not null and rp_gmovi.cod_modulo = 4 then -- cheques devueltos
          -- reversion de cheques devueltos nuestro banco
          if rp_gmovi.cod_tra_padre = 322 then
             update cc_che_recibidos
               set est_cheque = 'P',
                   cod_cau_devolucion =null
             where nro_cheque  = rp_gmovi.nro_documento
               and fec_proceso = (select max(fec_proceso)
                                        from cc_che_recibidos
                                        where nro_cheque = rp_gmovi.nro_documento
                                                 and monto = rp_gmovi.monto
                                                 and est_cheque = 'R')
               and est_cheque = 'R';
          end if;
          delete from cc_che_dev_firmantes
           where nro_cuenta = rp_gmovi.nro_cuenta
             and nro_cheque = rp_gmovi.nro_documento
             and trunc(fec_insercion) = (select trunc(max(fec_insercion))
                                               from cc_che_dev_firmantes
                                               where nro_cuenta = rp_gmovi.nro_cuenta
                                         and nro_cheque = rp_gmovi.nro_documento);

          --- pongo regularizado el cheque anterior
          update cc_che_devueltos
             set regularizado = 'S',
                 fec_modificacion = fec_modificacion
           where nro_cuenta = rp_gmovi.nro_cuenta
             and nro_cheque = rp_gmovi.nro_documento
             and fecha < (select max(fecha)
                         from cc_che_devueltos
                         where nro_cuenta = rp_gmovi.nro_cuenta
                         and nro_cheque = rp_gmovi.nro_documento);
          ---
          delete from cc_che_devueltos
            where nro_cuenta = rp_gmovi.nro_cuenta
             and nro_cheque = rp_gmovi.nro_documento
             and fecha = (select max(fecha)
                         from cc_che_devueltos
                         where nro_cuenta = rp_gmovi.nro_cuenta
                         and nro_cheque = rp_gmovi.nro_documento);

          --actualizar el estado del cheque, volver a 'P'agado
          if rp_gmovi.cod_tra_padre in (132,322) then
            -- actualizar cc_che_pagados
            update cc_che_pagados
               set cod_cau_devolucion = null
             where nro_cheque  = rp_gmovi.nro_documento
               and monto = rp_gmovi.monto
               and fecha = (select max(fecha) from cc_che_pagados b
                             where b.nro_cheque = rp_gmovi.nro_documento
                             and b.monto = rp_gmovi.monto);
            begin
               select nro_cuenta
                 into v_nro_cta_cliente
                 from cc_che_certificados a
                where a.nro_cta_certificado = rp_gmovi.nro_cuenta
                  and a.nro_cheque = rp_gmovi.nro_documento;
            exception
               when others then
                   v_nro_cta_cliente := rp_gmovi.nro_cuenta;
            end;
            if rp_gmovi.cod_transaccion in (602,608,668,631,630) then
                update cc_chequeras
                   set est_cheques = substr(est_cheques,1,(rp_gmovi.nro_documento - nro_che_inicial+1)-1) || 'P'
                        || substr(est_cheques,(rp_gmovi.nro_documento - nro_che_inicial+1)+1)
                 where nro_cuenta = v_nro_cta_cliente
                and rp_gmovi.nro_documento >= nro_che_inicial
                and rp_gmovi.nro_documento < nro_che_inicial + can_cheques
                and rp_gmovi.nro_documento between nro_che_inicial and nro_che_final;
                if sql%notfound then
                     raise_application_error(-20333,'No encuentra Cheque '||rp_gmovi.nro_documento);
                end if;
             end if;
          end if;
       elsif rp_gmovi.cod_tra_padre = 321 then
          -- reversion de cheques devueltos otros bancos
          update cc_che_remitidos
             set cod_cau_devolucion = null
           where cod_banco = rp_gmovi.cod_banco
             and nro_cheque = rp_gmovi.nro_documento
             and monto = rp_gmovi.monto
             and cod_cau_devolucion is not null;
             --and fecha = rp_gmovi.fecha;
          update cc_che_enviados
             set cod_cau_devolucion = null,
                 estado = 'E'
           where cod_banco = rp_gmovi.cod_banco
             and nro_cheque = rp_gmovi.nro_documento
             and estado = 'D';
          update ge_che_custodias
             set cod_cau_devolucion = null,
                 estado = 'A'
           where cod_banco = rp_gmovi.cod_banco
             and nro_cheque = rp_gmovi.nro_documento
             and estado = 'B';
           update ge_che_exterior
              set cod_cau_devolucion = null,
                  estado ='E'
            where cod_bCO_CORRESPONSAL = rp_gmovi.cod_banco
              and nro_cheque = rp_gmovi.nro_documento
              and estado = 'D';
       end if;
       if rp_gmovi.cod_retencion is not null
          and RP_GMOVI.Cod_Transaccion not in (515,565,560) then
          -- afecto la retencion, trato de borrar la retencion
            delete ah_retenciones
             where nro_cuenta = rp_gmovi.nro_cuenta
               and nro_documento = rp_gmovi.nro_documento
               and cod_retencion = rp_gmovi.cod_retencion
               and fec_inicio = rp_gmovi.fecha
               and liberado = 'N';
            if sql%notfound then
               v_afecta := 'S'; -- se cambia  ya que no debe reversar el retenido, solo el saldo
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
       elsif rp_gmovi.cod_retencion is not null
             and RP_GMOVI.Cod_Transaccion in (515,565,560) then

         --Modif. para reversar liberaciones x Cheque
         update ah_retenciones
            set liberado = 'N',
                sal_retenido = nvl(sal_retenido,0) + rp_gmovi.Monto,
                lib_posterior = 'N'
          where nro_cuenta = rp_gmovi.nro_cuenta
            and nro_documento = rp_gmovi.nro_documento
            and cod_retencion = rp_gmovi.cod_retencion
            --and fec_inicio = rp_gmovi.fecha
            and fec_inicio = rp_gmovi.Fec_Valor
            --and liberado = 'S'
            ;

         --Obtener Datos de la retención
         lp_obt_retencion(rp_gmovi.nro_cuenta,
                          rp_gmovi.nro_documento,
                          rp_gmovi.cod_retencion,
                          rp_gmovi.fec_valor,
                          r_ah_retenciones);

         --Fue una liberación por cheque, se debe actualizar el estado del cheque
         if rp_gmovi.nro_documento2 is not null then
            if rp_gmovi.cod_transaccion in (515,565) then --Plaza Local
               update cc_che_enviados z
                  set z.liberado='N',
                      z.lib_posterior='N'
                where z.nro_boleta = rp_gmovi.nro_documento
                  and z.nro_cuenta = rp_gmovi.nro_cuenta
                  and z.cod_retencion = rp_gmovi.cod_retencion
                  and z.cod_banco = rp_gmovi.cod_banco
                  and z.nro_cheque = rp_gmovi.nro_documento2
                  and z.liberado = 'S';
            else --560, Plaza Extranjera
               update ge_che_exterior d
                  set d.liberado='N',
                      d.lib_posterior='N'
                where d.nro_boleta = rp_gmovi.nro_documento
                  and d.nro_cuenta = rp_gmovi.nro_cuenta
                  and d.cod_retencion = rp_gmovi.cod_retencion
                  and d.cod_banco = rp_gmovi.cod_banco
                  and d.nro_cheque = rp_gmovi.nro_documento2
                  and d.liberado = 'S';
            end if;
          else --Liberación por el Saldo de la Boleta, actualizar los cheques que no fueron liberados individualmente (LIB_POSTERIOR=N)
            if rp_gmovi.cod_transaccion in (515,565) then --Plaza Local
               update cc_che_enviados z
                  set z.liberado='N'
                where z.nro_boleta = rp_gmovi.nro_documento
                  and z.nro_cuenta = rp_gmovi.nro_cuenta
                  and z.cod_retencion = rp_gmovi.cod_retencion
                  and z.liberado = 'S'
                  and z.lib_posterior = 'N'
                  and z.fec_final = r_ah_retenciones.fec_final ;
            else --560, Plaza Extranjera
               update ge_che_exterior d
                  set d.liberado='N'
                where d.nro_boleta = rp_gmovi.nro_documento
                  and d.nro_cuenta = rp_gmovi.nro_cuenta
                  and d.cod_retencion = rp_gmovi.cod_retencion
                  and d.cod_banco = rp_gmovi.cod_banco
                  and d.liberado = 'S'
                  and d.lib_posterior = 'N'
                  and d.fec_final = r_ah_retenciones.fec_final;
            end if;
          end if;
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

          -- agregado para actualizar la as/400
          if rp_gmovi.cod_modalidad in (31,41) /*and
             rp_gmovi.cod_tra_padre in (101,102,136,150,210,250,251,253,254,255,261,264,265,276,288,301,
                                        305,307,309,311,317,329,330,351,352,354,368,384,452,515,517,
                                        580,598,602,769,849,2602)*/ then
            -- agregado para actualizar la as/400
            v_cta_enviada := lpad(rp_gmovi.COD_OFICINA,2,'0');
            if rp_gmovi.cod_modalidad = 41 and rp_gmovi.cod_moneda = 'GS' then
                v_cta_enviada := v_cta_enviada||'210100';
            elsif rp_gmovi.cod_modalidad = 31 and rp_gmovi.cod_moneda = 'GS' then
                 v_cta_enviada := v_cta_enviada||'210500';
            elsif rp_gmovi.cod_modalidad = 41 and rp_gmovi.cod_moneda <> 'GS' then
                 v_cta_enviada := v_cta_enviada||'215000';
            elsif rp_gmovi.cod_modalidad = 31 and rp_gmovi.cod_moneda <> 'GS' then
                 v_cta_enviada := v_cta_enviada||'215500';
            end if;
            v_cta_enviada := v_Cta_enviada||substr(rp_gmovi.nro_cuenta,-6);

            v_nro_operacion  := '0000'||to_char(sysdate,'HH24MISS');
            v_can_pedidos := nvl(v_can_pedidos,0) + 1;
            v_pedido(v_can_pedidos) := v_nro_operacion||   -- NRO OPERACION
                    'C' || -- FIJO PARA INDICAR LA CONFIRMACION
                    TRIM(TO_CHAR(rp_gmovi.COD_MAD_PADRE,'000'))||SUBSTR(TRIM(TO_CHAR(rp_gmovi.cod_tra_padre,'0000')),2,3)||
                    RPAD(NVL(P_COD_USU_REVERSION,USER),10,' ')|| -- USUARIO
                    -- Se agrega el Nro. de Secuencia
                    P_HOR_REVERSION||TRIM(TO_CHAR(rp_gmovi.nro_secuencia,'000'))||
                    TRIM(TO_CHAR(rp_gmovi.COD_OFI_ORIGEN,'000'))||
                    RPAD(v_cta_enviada,20,' ')||
                    v_tip_movimiento||
                    LPAD(nvl(rp_gmovi.NRO_DOCUMENTO,0),20,'0')||
                    LPAD(rp_gmovi.COD_MONEDA,3,' ')||
--                    TRIM(TO_CHAR((rp_gmovi.MONTO * -1),'0000000000000.00'))||
                    TRIM(TO_CHAR((rp_gmovi.MONTO * -1),'000000000000.00'))||
                     rpad(NVL(trim(to_char(rp_gmovi.cotizacion,'00000000000.0000')),' '),16,' ')||
                    rpad(NVL(TRIM(TO_CHAR(rp_gmovi.MTO_EQU_LOCAL,'0000000000000000')),' '),16,' ')||
                    rpad(nvl(p_concepto,' '),60,' ')||
                    rpad((rpad(nvl(rp_gmovi.cod_usuario,user),10,' ')||nvl(p_hora,to_char(sysdate,'HH24:MI:SS'))||TRIM(TO_CHAR(rp_gmovi.nro_secuencia,'000'))),40,' ');
            v_pedido(v_can_pedidos) := rpad(v_pedido(v_can_pedidos),300,' ');

          end if;
           -- agregado por as/400



          -- veo si es cda, y si se pago interes o capital
          if rp_gmovi.cod_modalidad in (33,34,35,36)   then
             if v_tip_movimiento = 'D' then
               if v_afecta = 'I' Then  -- cupon de interes
                  update ah_cupones
                   set fec_pago = null,
                       estado = 'V' -- vuelvo el cupon a vencido
                 where nro_cuenta = rp_gmovi.nro_cuenta
                   and nro_cupon =  rp_gmovi.nro_documento;
                 if sql%notfound then
                    raise_application_error(-20000,'Cupon no existe ');
                 end if;
               elsif v_afecta = 'C' then  -- capital
                 update ah_cta_certificados
                    set est_certificado = 'V', -- vuelvo el cda a vencido
                        fec_pago = null
                  where nro_cuenta = rp_gmovi.nro_cuenta;
                 if sql%notfound then
                    raise_application_error(-20000,'Certificado no existe ');
                 end if;
               end if;
             end if;
          end if;
       end if;
       if (rp_gmovi.cod_modalidad = 43 and fug_obt_tip_implementacion <> 1 ) or--- Reversar cheque emitido
          (rp_gmovi.cod_transaccion = 603  and fug_obt_tip_implementacion = 1) Then
          v_msj_cheque := pac_che.FU_ELI_CHE_GER_EMI(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento);
          if v_msj_cheque is not null then
             raise_application_error(-20000,'Reversion del Cheq. Gerencia '||v_msj_cheque);
          end if;
       end if;
       if rp_gmovi.cod_tra_padre = 323 and rp_gmovi.cod_transaccion = 503 and rp_gmovi.cod_tasa is null then
          -- emision de cheque certificado
            declare
               v_cta_certificado varchar2(20);
            begin
              if nvl(pac_che.fu_act_cam_est_che(rp_gmovi.nro_cuenta,
                                         rp_gmovi.nro_documento,
                                         'E', -- vuelve a emitido
                                         v_msj_cheque,
                                         v_cta_certificado),'x') <> 'C' then
                 raise_application_error(-20000,'Reversion de Certificacion '||v_msj_cheque);
              end if;
            end;
            if v_msj_cheque is not null then
              raise_application_error(-20000,'Reversion de Certificacion '||v_msj_cheque);
            end if;
       end if;
       --Si es cheque pagado por camara, debe reversar el pago
       if rp_gmovi.cod_tra_padre = 320 and --CHEQUE PAGADO P/ CAMARA
          rp_gmovi.cod_modulo = 4 and
          v_tip_movimiento = 'D' then
         -- Rerversion del estado del cheque
         v_msj_cheque := pac_che.fu_rev_pag_cheque(rp_gmovi.nro_cuenta,
                                                      rp_gmovi.nro_documento,
                                                      rp_gmovi.monto,
                                                      rp_gmovi.fecha,
                                                      rp_gmovi.hora);
         if v_msj_cheque is not null then
           raise_application_error(-20000,'Reversion del estado del cheque '||v_msj_cheque);
         end if;
         --Borrar de cheques recibidos
         delete cc_che_recibidos
          where /*nro_cuenta  = rp_gmovi.nro_cuenta
            and */nro_cheque  = rp_gmovi.nro_documento
            and fec_proceso = r_gmovi.fec_valor
            and cod_usuario = rp_gmovi.cod_usuario
            and est_cheque = 'P';
         IF sql%notfound then
            raise_application_error(-20000,'Cheque recibido de Camara ya no puede ser reversado');
         end if;
         --Actualizar el resumen de cheques recibidos de camara
         update cc_che_recibidos_res
            set tot_cheques = nvl(tot_cheques,0) - nvl(rp_gmovi.monto,0),
                can_cheques = can_cheques - 1
          where cod_oficina = rp_gmovi.cod_ofi_origen
            and cod_banco  =  rp_gmovi.cod_banco
            and cod_moneda =  rp_gmovi.cod_moneda;
         --Actualizar los montos
         update cc_sal_camara
            set sis_che_recibidos = nvl(sis_che_recibidos,0) - nvl(rp_gmovi.monto,0)
         where cod_ofi_camara = rp_gmovi.cod_ofi_origen
           and cod_moneda     = rp_gmovi.cod_moneda
           and fecha          = rp_gmovi.fec_valor;

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
    if rp_gmovi.cod_mod_padre = 7 then
      if rp_gmovi.fecha < v_fec_actual then
         raise_application_error(-20000,'No se pueden reversar movimientos históricos de Cambios');
      end if;
      if rp_gmovi.monto <> 0 and
       rp_gmovi.cod_transaccion IN (503, 190) and --sólo débito de ctas.
       rp_gmovi.cod_modulo in (3,4) then
        if rp_gmovi.estado in ('J','P','X') then
          --actualizar saldo bloqueado
          IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad,rp_gmovi.nro_cuenta) = 'N' THEN
            -- cuenta llaveada
            raise_application_error(-20000,'Cuenta '||rp_gmovi.nro_cuenta||' llaveada ');
          end if;
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
        end if;
      end if;
      If rp_gmovi.estado = 'X' then
         update ge_aut_pedidos
            set respuesta = 'R',
                estado    = 'A',
                observacion = p_concepto
          where fecha = rp_gmovi.fecha
            and hora  = rp_gmovi.hora
            and cod_usuario = rp_gmovi.cod_usuario
            and respuesta <> 'R';
      End if;
      --reversar la posición de cambios, solo el estado Normal actualiza posición
      if rp_gmovi.monto <> 0 and
       (rp_gmovi.nro_secuencia = 1 or --el mov. principal
       (rp_gmovi.nro_secuencia = 2 and rp_gmovi.cod_mad_padre in (73,74))) and --cualquiera de canje o arb
       rp_gmovi.estado ='N' then
         pal_cam.pr_act_posiciones(rp_gmovi.cod_tip_ope_cambio,
                                 rp_gmovi.cod_moneda,
                                 pal_cam.fu_obt_ofi_cambio(rp_gmovi.cod_ofi_origen),
                                 r_gmovi.monto,
                                 r_gmovi.mto_equ_local,
                                 rp_gmovi.cod_bco_central);
      end if;
      --eliminar operaciones pendientes,no importa el estado N,J,X
      --ya no se elimina, se actualiza. 13/09/05
      if rp_gmovi.monto <> 0 and
       (rp_gmovi.nro_secuencia = 1 or --el mov. principal
       (rp_gmovi.nro_secuencia = 2 and rp_gmovi.cod_mad_padre in (73,74))) then --cualquiera de canje o arb
         if rp_gmovi.nro_secuencia = 1 then --el mov. principal
           --delete lc_ope_pendientes
           update lc_ope_pendientes
              set liquidado ='N',
                  cod_usu_liquidacion = null,
                  fec_liquidacion = null
            where nro_operacion = rp_gmovi.nro_documento;
         end if;
         --si es compra o venta de transferencia,eliminar la misma
         v_transferencia := null;
         v_afe_libranza := null;
         v_mad_hijo := null;
         begin
           select afe_transferencia, afe_libranza, cod_mad_hijo
             into v_transferencia, v_afe_libranza, v_mad_hijo
             from lc_tip_ope_oficinas b, lc_tip_operaciones a
            where b.cod_tip_operacion = a.cod_tip_operacion
              and a.cod_tip_operacion = rp_gmovi.cod_tip_ope_cambio
              and nivel = 1
              and b.cod_oficina = rp_gmovi.cod_ofi_origen --rp_gmovi.cod_oficina
              and b.cod_moneda  = rp_gmovi.cod_moneda;
           if v_transferencia = 'S' then
              if v_mad_hijo = 72 then --vta,arb,cje
                --if r_gmovi.estado = 'N' then
                  --si es venta de transferencia sólo actualizar por ahora
                  --update lc_transferencias
                   --  set estado = nvl(est_anterior, estado)
                   delete from lc_transferencias
                   where nro_operacion = to_number(r_gmovi.nro_documento)
                     and cod_modalidad = 72
                   returning fec_envio into v_fec_envio;
                   if v_fec_envio is not null then
                      raise_application_error(-20000,'No puede reversar. La Transferencia ha sido enviada.');
                   else
                      --cargar variables para envío de mail
                      v_ope_cambios := r_gmovi.cod_tip_ope_cambio;
                      v_nro_transf  := to_number(r_gmovi.nro_documento);
                   end if;
                --end if;
              else--compra
                --eliminar la transferencia
                delete lc_transferencias
                 where cod_tip_referencia= rp_gmovi.cod_ref_cambio
                   and nro_referencia    = rp_gmovi.nro_documento2;
              end if;
           end if;
           --actualizar la libranza, sólo si no fue enviada aún
           if v_afe_libranza = 'S' /*or rp_gmovi.cod_tip_ope_cambio in (15,59,89)*/ then
              declare
                 v_enviada varchar2(1);
              begin
                 select enviada
                   into v_enviada
                   from lc_transferencias
                  where cod_tip_referencia= rp_gmovi.cod_ref_cambio
                    and nro_referencia    = rp_gmovi.nro_documento2;
                 if nvl(v_enviada, 'N') = 'S' then
                    raise_application_error(-20000,'No puede reversar. Ya se realizó el envío de mail de transferencias confirmadas.');
                 else -- actualizar
                    update lc_transferencias
                       set saldo = nvl(saldo,0) + rp_gmovi.monto,
                           estado = nvl(est_anterior, estado),
                           nro_operacion = null,
                           est_anterior = null
                     where cod_tip_referencia= rp_gmovi.cod_ref_cambio
                       and nro_referencia    = rp_gmovi.nro_documento2;
                 end if;
              exception
                 when no_data_found then
                    raise_application_error(-20000,'No existe Transf. a Reversar '||rp_gmovi.cod_ref_cambio||'-'||rp_gmovi.nro_documento2);
                 when others then
                    if sqlcode <= -20000 then
                       raise;
                    else
                       raise_application_error(-20000,'Recup. Transf. a Reversar '||rp_gmovi.cod_ref_cambio||'-'||rp_gmovi.nro_documento2||'.'||sqlerrm);
                    end if;
              end;
           end if;
           --si afecta a corresponsal, actualizar estado
           /*if v_tip_aplicacion = 'A' then
             update lc_transferencias
                set estado =''--saldo = nvl(saldo,0) + rp_gmovi.monto
              where cod_tip_referencia= rp_gmovi.cod_ref_cambio
                and nro_referencia    = rp_gmovi.nro_documento2
           end if;*/
         exception
           when others then
              if sqlcode <= -20000 then
                 raise;
              else
                 null;
              end if;
         end;
      end if;
      -- eliminar la retención, reversar el límite de la cta de cambios
      if rp_gmovi.monto <> 0 and
       rp_gmovi.cod_transaccion = 760 then --afectación de límite
        --eliminar retención
        delete lc_retenciones
         where nro_cuenta = rp_gmovi.nro_cuenta
           and liberado ='N'
           and nro_boleta = rp_gmovi.nro_documento;
        --actualizar cta
        begin
         update lc_cta_cambios
            set mto_utilizado = nvl(mto_utilizado,0)+ r_gmovi.monto
          where nro_cuenta = rp_gmovi.nro_cuenta;
        exception
          when others then
            raise_application_error(-20000,'Actualiza Límite Cuenta '||rp_gmovi.nro_cuenta);
        end;
      end if;
      -- Modifica Estado Operaciones Futuras
      if rp_gmovi.cod_ref_cambio = 76 and rp_gmovi.nro_secuencia = 1 then
        begin
          update lc_ope_futuras c
             set c.fec_liquidacion = null,
                 c.mto_utilizado = 0,
                 c.estado = 'N'
           where c.nro_operacion = rp_gmovi.nro_documento2;
        exception
          when others then
            raise_application_error(-20002,'Actualiza Operación Futura '||rp_gmovi.nro_documento2);
        end;
      end if;
    end if;--hasta aquí oper. cambios
    ----comex, cci y cobranzas
    if rp_gmovi.cod_mod_padre = 8 then
       /*if rp_gmovi.cod_mad_padre = 81 then
         --si hubo movimiento de cambio de estado por pago total y se reversa, volver a afectar la garantía si tuviera
         --la reversión del estado se hace por la novedad de la cuenta ge_cuentas_nov
         if rp_gmovi.cod_transaccion = 401 and rp_gmovi.est_cuenta = 'G' then --pagada
            declare
               --busca las garantías cash de la cc
               CURSOR cash is
                select nro_garantia, mto_aplicado
                  from cx_cta_garantias
                 where cod_garantia =5
                   and nro_cuenta = rp_gmovi.nro_cuenta;
            BEGIN
              --verificar si posee garantias cash
              for reg in cash loop
                 if reg.nro_garantia is not null then --volver a aplicar, acá xq en el trigger da mutating
                    pap_gar.PR_PRO_GAR_CASH(reg.nro_garantia, rp_gmovi.nro_cuenta, null, null, rp_gmovi.cod_modulo,
                                 rp_gmovi.cod_modalidad, rp_gmovi.cod_oficina, rp_gmovi.cod_moneda, reg.mto_aplicado);
                 end if;
              end loop;
            END;
         end if;*/
         --verificar que sea el último movimiento para reversar en orden
         /*if rp_gmovi.cod_tra_padre = 368 then
            if rp_gmovi.nro_documento3 is not null then
               select max(nro_cuota) --máxima cuota pagada
                 into v_nro_cuo_cci
                 from cx_cuotas
                where estado = 'P'
                  and nro_cuenta = rp_gmovi.referencia;
               if rp_gmovi.nro_documento3 < nvl(v_nro_cuo_cci,0) then
                  raise_application_error(-20005,'Existen pagos posteriores de la CCI que deben ser reversados previamente.');
               end if;
            end if;
         end if;*/
       --end if; --cci
       --utilización
       if rp_gmovi.cod_tra_padre = 890 and rp_gmovi.cod_mad_padre in (81,82) and rp_gmovi.nro_secuencia = 1 then --utilización
          --sólo se puede deshacer la última utilización, en orden
          begin
            select nvl(max(nro_embarque),0)
              into v_ult_embarque
              from cx_embarques
             where nro_cuenta = rp_gmovi.nro_cuenta;
            if rp_gmovi.nro_documento2 < v_ult_embarque then
               raise_application_error(-20000,'Existen Embarques posteriores que deben ser reversados previamente.');
            end if;
          end;
          --sólo si ninguna cuota fue pagada
          begin
             select '*'
               into v_pagado
               from cx_embarques
              where mto_utilizado <> nvl(saldo,0) --no fue pagada ninguna porción
                and nro_embarque = rp_gmovi.nro_documento2
                and nro_cuenta = rp_gmovi.nro_cuenta;
             if v_pagado is not null then
               raise_application_error(-20000,'El Embarque '||rp_gmovi.nro_documento2 ||' posee pagos/cobros parciales. No se puede reversar .');
             end if;
          exception
             when no_data_found then
                null;
          end;
          --deshacer el embarque y las cuotas
          delete cx_cuotas
           where nro_embarque = rp_gmovi.nro_documento2
             and nro_cuenta = rp_gmovi.nro_cuenta;
          delete cx_embarques
           where nro_embarque = rp_gmovi.nro_documento2
             and nro_cuenta = rp_gmovi.nro_cuenta;
          --actualizar el mto_utilizado
          if rp_gmovi.cod_mad_padre = 81 then
             update cx_cta_importaciones
                set mto_utilizado = nvl(mto_utilizado,0) - rp_gmovi.monto
              where nro_cuenta = rp_gmovi.nro_cuenta;
          else
             update cx_cta_exportaciones
                set mto_utilizado = nvl(mto_utilizado,0) - rp_gmovi.monto
              where nro_cuenta = rp_gmovi.nro_cuenta;
          end if;
       end if;
       if rp_gmovi.cod_tra_padre IN (368, 384) and rp_gmovi.nro_secuencia = 1 then --cobro y pago (cci,cobranza,cce)
         if rp_gmovi.monto <> 0 then
            --actualizar carta de crédito, SALDO
            if /*rp_gmovi.cod_mad_padre = 81 and*/ rp_gmovi.nro_documento3 is not null then --tiene cuotas, sólo cci y cce
              --sólo se puede deshacer el último embarque, en orden
              begin
                select nvl(max(nro_embarque),0)--, nvl(max(nro_cuota),0)
                  into v_ult_embarque--, v_nro_cuo_cci
                  from cx_cuotas
                 where monto <> nvl(saldo,0) --algo pagado
                   and nro_cuenta = rp_gmovi.nro_cuenta;
                if rp_gmovi.nro_documento2 < v_ult_embarque then
                   raise_application_error(-20000,'Existen Embarques posteriores que deben ser reversados previamente.');
                end if;
              end;
              if rp_gmovi.cod_mad_padre = 81 then
                --actualiza saldo de la cci
                 update cx_cta_importaciones
                    set saldo  = nvl(saldo,0) + rp_gmovi.monto
                  where nro_cuenta = rp_gmovi.nro_cuenta;
              elsif rp_gmovi.cod_mad_padre = 82 then
                --actualiza saldo de la cce
                 update cx_cta_exportaciones
                    set saldo  = nvl(saldo,0) + rp_gmovi.monto
                        --,nro_cta_prestamo = null -- ver esto, es lo q tenía antes
                  where nro_cuenta = rp_gmovi.nro_cuenta;
              end if;
               --deshacer la cuota
               update cx_cuotas
                  set saldo  = nvl(saldo,0) + rp_gmovi.monto,
                      estado = decode(monto, saldo, estado, 'N') --vuelve a pendiente, con la primera porción q reversa
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_cuota  = rp_gmovi.nro_documento3;
               --deshacer el embarque
               update cx_embarques
                  set saldo  = nvl(saldo,0) + rp_gmovi.monto,
                      estado = decode(mto_utilizado, saldo, estado, 'N') --vuelve a pendiente, con la primera porción q reversa
                where nro_cuenta = rp_gmovi.nro_cuenta
                  and nro_embarque  = rp_gmovi.nro_documento2;

            elsif rp_gmovi.cod_mad_padre in (83, 84) then
               --actualiza saldo de la cobranza
               update cx_cta_cobranzas
                  set saldo  = nvl(saldo,0) + rp_gmovi.monto
                where nro_cuenta = rp_gmovi.nro_cuenta;
            end if;
            if rp_gmovi.cod_mad_padre = 81 then
              ----si tiene límite recalcular, sólo cci
              declare
                 v_linea cx_cta_importaciones.nro_linea%type;
              begin
                 select nro_linea
                   into v_linea
                   from cx_cta_importaciones
                  where nro_cuenta = rp_gmovi.nro_cuenta;
                  if v_linea is not null then
                     prp_rec_apl_limite(v_linea);
                  end if;
              exception
                 when others then
                    null;
              end;
            end if;
         end if;
      end if;
      --cancelación, actualizar el saldo, cci, cce, cobranzas
      --if rp_gmovi.cod_transaccion = 379 then
      if rp_gmovi.cod_tra_padre = 380 then
         if rp_gmovi.monto <> 0 then
            if rp_gmovi.cod_mad_padre = 81 and rp_gmovi.cod_transaccion in (378, 379)then
               --actualizar el saldo, el estado se hace x novedad
               update cx_cta_importaciones
                  set saldo = nvl(saldo,0) + rp_gmovi.monto
                where nro_cuenta = rp_gmovi.nro_cuenta;
            elsif rp_gmovi.cod_mad_padre in (83, 84) and rp_gmovi.cod_transaccion in (378,379) then
               --actualizar el saldo, el estado se hace x novedad
               update cx_cta_cobranzas
                  set saldo = nvl(saldo,0) + rp_gmovi.monto
                where nro_cuenta = rp_gmovi.nro_cuenta;
            elsif rp_gmovi.cod_mad_padre = 82 and rp_gmovi.cod_transaccion in (376, 377, 378, 379)then
               --actualizar el saldo, el estado se hace x novedad
               update cx_cta_exportaciones
                  set saldo = nvl(saldo,0) + rp_gmovi.monto
                where nro_cuenta = rp_gmovi.nro_cuenta;
            end if;
            --
            -- reverso las cuotas y embarques en forma dinamica
            prg_rev_auditoria('CX_EMBARQUES',
                               rp_gmovi.fec_insercion,
                               rp_gmovi.cod_usuario,
                               rp_gmovi.nro_cuenta);
            prg_rev_auditoria('CX_CUOTAS',
                               rp_gmovi.fec_insercion,
                               rp_gmovi.cod_usuario,
                               rp_gmovi.nro_cuenta) ;
            --
         end if;
      end if;
      -- Cuotas de Comision de Fianzas Recibidas y Emitidas
       if rp_gmovi.cod_mad_padre in ( 88, 89) and rp_gmovi.cod_tra_padre = 580 then
          update cx_fia_comisiones x
             set x.saldo = nvl(x.saldo,0) + RP_GMOVI.Monto,
                 x.estado = 'A'
           where x.cod_fianza = rp_gmovi.nro_documento
             and x.nro_cuota  = RP_GMOVI.Nro_Documento2;
       end if;
      --cancelación fianzas
      /*if rp_gmovi.cod_mad_padre in (87, 88, 89) and rp_gmovi.cod_transaccion = 379  then
         if rp_gmovi.monto <> 0 then
            update cx_fianzas
               set saldo = nvl(saldo,0) + rp_gmovi.monto
                where nro_cuenta = rp_gmovi.nro_cuenta;
         end if;
      end if;*/
      if rp_gmovi.cod_transaccion = 845 and rp_gmovi.cod_mad_padre = 81 then --contra préstamo
         if rp_gmovi.monto <> 0 then
            --recupera los datos del préstamo relacionado
            prx_obt_pre_cci(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento3, 'S', v_nro_sol_cci, v_nro_cta_cci);
            if v_nro_sol_cci is not null then
               begin
                  select estado
                    into v_est_solicitud
                    from pr_solicitudes
                   where nro_solicitud = v_nro_sol_cci;
                   if v_est_solicitud in ('L','S') then --sólo si no se desembolsó aún
                      --desasociar de la cci y cuota
                      begin
                        --actualizar cci con la máxima cuota pagada en préstamo anterior a la q se reversa
                        update cx_cta_importaciones
                           set nro_sol_prestamo = (select a.nro_sol_prestamo
                                                     from cx_cuotas a
                                                    where a.nro_cuenta = rp_gmovi.nro_cuenta
                                                      and a.nro_cuota = (select max(b.nro_cuota)
                                                                           from cx_cuotas b
                                                                          where b.nro_cuenta = a.nro_cuenta
                                                                            and estado = 'P'
                                                                            and nro_sol_prestamo is not null
                                                                            and nro_cuota < rp_gmovi.nro_documento3))
                         where nro_sol_prestamo = v_nro_sol_cci
                           and nro_cuenta = rp_gmovi.nro_cuenta;
                        --actualizar la cuota
                        update cx_cuotas
                           set nro_sol_prestamo = null
                         where nro_sol_prestamo = v_nro_sol_cci
                           and nro_cuenta = rp_gmovi.nro_cuenta;
                        --
                        if sql%notfound then --actualizar la cci
                           update cx_cta_importaciones
                              set nro_sol_prestamo = null
                            where nro_sol_prestamo = v_nro_sol_cci
                              and nro_cuenta = rp_gmovi.nro_cuenta;
                        end if;
                      end;
                      /*update pr_solicitudes ***
                         set estado = 'N' --cancelada
                       where nro_solicitud = v_nro_sol_cci
                         and estado in ('L','S'); --sólo si está pendiente de desembolso
                      if sql%notfound then
                         raise_application_error(-20300,'Solicitud relacionada '||v_nro_sol_cci||' no está pendiente de desembolsar. No se puede reversar.');
                      end if; *** hasta aquí debe marcarse*/
                   elsif v_est_solicitud = 'A' then--desembolsada
                      raise_application_error(-20301,'Solicitud relacionada '||v_nro_sol_cci||' ya fue desembolsada. No se puede reversar.');
                   else
                      raise_application_error(-20301,'Estado de la Solicitud relacionada '||v_nro_sol_cci||' no permite reversar.');
                   end if;
               exception
                  when no_Data_found then
                     null;--raise_application_error(-20302,'No existe solicitud de prést. relacionada '||v_nro_sol_cci);
                  when others then
                     if sqlcode <= -20000 then
                        raise;
                     else
                        raise_application_error(-20303,'No se pudo actualizar solicitud prést. relacionada '||v_nro_sol_cci);
                     end if;
               end;
            end if;
         end if;
      end if;
    end if;
    ----hasta aquí comex --cce está más abajo
     --- COMERCIO EXTERIOR, SÓLO CCE
    /*if rp_gmovi.cod_modulo = 8 and rp_gmovi.cod_mad_padre = 82
    and rp_gmovi.nro_cuenta is not null then
       if V_OPE_PENDIENTE = 'N' then -- Si no debe quedar pendiente de pasar por caja
          -- obtengo el tipo d/c y a que saldo afecto
          pr_obt_tip_transaccion(rp_gmovi.cod_transaccion,
                                 rp_gmovi.cod_modulo,
                                 rp_gmovi.cod_modalidad,
                                 v_tip_movimiento, v_afecta);
         if v_afecta = 'S' and v_tip_movimiento in ('D','C') then --- Afecta saldo
            if v_tip_movimiento = 'D' then
              v_afe_sal_total := nvl(rp_gmovi.monto,0) * -1;
            else
              v_afe_sal_total := nvl(rp_gmovi.monto,0);
            end if;
            update cx_cta_exportaciones
               set saldo = nvl(saldo,0) + v_afe_sal_total
             where nro_cuenta = rp_gmovi.nro_cuenta;
         end if;
         if v_tip_movimiento = 'E' then --- Afecta estado
            update cx_cta_exportaciones
               set cod_cau_cancelacion = decode(estado,'C',null,'R',null,cod_cau_cancelacion),
                   fec_cancelacion = decode(estado,'C',null,'R',null,fec_cancelacion),
                   estado = v_est_anterior
             where nro_cuenta = rp_gmovi.nro_cuenta;
          end if;
          if rp_gmovi.cod_tra_padre = 384 then ---- Si se reversa el pago
             update cx_cta_exportaciones
                set nro_cta_prestamo = null  --- Reversar el desembolso del prestamo
              where nro_cuenta = rp_gmovi.nro_cuenta;
          end if;
       end if;
    end if;*/
    --hasta aquí cce
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
             and nro_cuota  = rp_gmovi.nro_documento3
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
                  and nro_cuota = RP_GMOVI.NRO_DOCUMENTO3
                  and ((fecha > rp_gmovi.fecha) or
                       (fecha = rp_gmovi.fecha and hora > rp_gmovi.hora))
                  and rownum = 1;
               IF nvl(v_can_cuotas,0) > 0 then
                  raise_application_error(-20001,'La cuenta '||rp_gmovi.nro_cuenta||
                     ' tiene mov. posteriores de la misma cuota nro.'||RP_GMOVI.NRO_DOCUMENTO3||
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
                and nro_cuota  = rp_gmovi.nro_documento3;
             --- Actualizar la cuota
             update pr_cuotas
                set dev_acumulado  = v_cu_dev_acumulado,
                    dev_suspenso   = v_cu_dev_suspenso,
                    dev_no_cobrado = v_cu_dev_no_cobrado
              where nro_cuenta = rp_gmovi.nro_cuenta
                and nro_cuota  = rp_gmovi.nro_documento3;
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
             and nro_cuota  = rp_gmovi.nro_documento3;
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
                v_fec_ini_dev := nvl(pap_dev.FU_OBT_FEC_INI_CUOTA(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento3),r_pcpre.fec_inicio);
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
                  and nro_cuota  = rp_gmovi.nro_documento3
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
                  and nro_cuota  = rp_gmovi.nro_documento3
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
                and nro_cuota = rp_gmovi.nro_documento3
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
       declare
          v_can_cambios number(8); -- para contar cambios o mov posteriores
       Begin
          -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
          select count(*)
            into v_can_cambios
            from gv_movimientos
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
               from gv_movimientos
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
       end;
       --- Actualizar cuota
       update pr_cuotas
          set fec_ult_pago = nvl(v_fec_ult_pago,fec_ult_pago),
              estado       = nvl(v_estado,estado),
              sal_capital  = nvl(sal_capital,0) + nvl(v_capital,0),
              sal_interes  = nvl(sal_interes,0) + nvl(v_interes,0),
              val_recargo  = nvl(val_recargo,0) - nvl(v_val_recargo,0),
              sal_int_documentado = nvl(sal_int_documentado,0) + nvl(v_int_adelantado,0)
        where nro_cuenta = rp_gmovi.nro_cuenta
          and nro_cuota  = rp_gmovi.nro_documento3;
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
             and nro_cuota > rp_gmovi.nro_documento3;
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
          and nro_cuota  = rp_gmovi.nro_documento3
          and fecha      = rp_gmovi.fecha
          and hora       = rp_gmovi.hora;
       --- Solo si existe cancelacion parcial
       if rp_gmovi.cod_tra_padre = 359 and rp_gmovi.cod_transaccion = 747 then
          --- Recorrer
          v_nro_cuo_desde := rp_gmovi.nro_documento;
          v_nro_cuo_hasta := rp_gmovi.nro_documento3;
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
       declare
          v_can_cambios number(8); -- para contar cambios o mov posteriores
       Begin
          -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
          select count(*)
            into v_can_cambios
            from gv_movimientos
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
               from gv_movimientos
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
       end;
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
       declare
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
       end;
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
         and nro_cuota = rp_gmovi.nro_documento3;
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

      declare
        v_can_cambios number(8); -- para contar cambios o mov posteriores
      Begin
        -- verifico sino hubo un mov. posterior
        select count(*)
          into v_can_cambios
          from gv_movimientos
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
      end;
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
           and nro_cuota    = rp_gmovi.nro_documento3;
         -- Obtener el monto de la cuota anterior
         Select Sum(saldo)
           into v_mto_cuo_ant
           From cs_con_cuotas
          Where nro_contrato = rp_gmovi.nro_documento
            And estado = 'C'
            And nvl(saldo,0) > 0
            And nro_cuota = (rp_gmovi.nro_documento3);
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
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    -- TARJETA
    /*ELSIF P_COD_MODULO = 5 THEN --NO EXISTE
        UPDATE TA_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
        hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N';*/
    -- PRESTAMO
    ELSIF P_COD_MODULO = 6 THEN
        UPDATE PR_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    --  CAMBIOS
    ELSIF P_COD_MODULO = 7 THEN
        UPDATE LC_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
    -- COMERCIO EXTERIOR
    ELSIF P_COD_MODULO = 8 THEN
        UPDATE CX_MOVIMIENTOS_HIS
        SET     reversado = 'S',
        cod_usu_reversion = p_cod_usu_reversion,
            hor_reversion = p_hor_reversion
        WHERE       fecha = p_fecha
        AND          hora = p_hora
        AND   cod_usuario = p_cod_usuario
        AND nro_secuencia = p_nro_secuencia
        AND     reversado = 'N'
        AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
              AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
           AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3;
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
          AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3
          and reversado    = 'N'
          and cod_modulo  in (3,4)
          and cod_modalidad <> 43
          and monto is not null;
       --- Eliminar movimientos de cambios de estado
       delete ge_movimientos
        where cod_usuario = p_cod_usuario
          and fecha       = p_fecha
          and hora        = p_hora
          AND NRO_DOCUMENTO3 = P_NRO_DOCUMENTO3
          and cod_modulo  in (3,4)
          and reversado    = 'N'
          and cod_modalidad <> 43
          and monto is null;
    END IF;
    --envío de mail si todo fue ok.
    if P_COD_MOD_PADRE = 7 then
       if v_ope_cambios is not null and v_nro_transf is not null then
          begin
            it_mail.mail(fug_obt_dir_correo,
                         fug_obt_dir_mail_usu(FUG_OBT_PARDINAMICO('COD_USU_ENC_COMEX')),
                         'Reversión de Transferencia',
                         'La Operación Nro. '||v_nro_transf||' que involucra a una Transferencia Emitida '||
                         'ha sido reversada.');
          exception
             when others then
                null;
          end;
       end if;
    end if;
   --Cuando se reversa pagos a proveedores debe dejar la orden pendiente de pago
   if p_cod_tra_padre = 346 then
     begin
        --Obtener nro_orden
        select nro_documento2 orden_pago, nro_documento cod_ente
          into v_ord_pago, v_cod_ente
         from ge_movimientos
        where cod_tra_padre = p_cod_tra_padre
          and fecha = p_fecha
          and hora = p_hora
          and cod_usuario = p_cod_usuario
          and nro_secuencia = 1;
     exception
        when others then
          v_ord_pago := 0;
          v_cod_ente := 0;
     end;
     --Dejar la orden en estado Cargado para poder pagar
     if v_ord_pago <> 0 then
         update ge_pag_proveedores
            set estado     = 'C',
                fec_pago = null,
                cod_oficina = null
          where nro_orden = v_ord_pago
            and cod_ente  = v_cod_ente;
     end if;
   end if;
    -- as/400
    /*
    for i in 1..v_can_pedidos
    loop
        if trim(v_pedido(i)) is not null then
            --v_pedido := '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890   ';
            v_ok := fue_env_tcp_mensajes('167.100.1.3',20300,10, v_pedido(i), v_respuesta);

            if v_ok = 'S' and substr(v_respuesta,11,3) = '000' then
               null;  -- no hay problemas, se actualiza
               ---
            else

               if substr(v_respuesta,1,10) = v_nro_operacion then
                  raise_application_error(-20000,'AS/400 '||substr(v_respuesta,31));
               else
                   raise_application_error(-20000,'AS/400 '||v_respuesta);

               end if;
            end if;

        end if;
    end loop;
    */

EXCEPTION
    WHEN OTHERS THEN
       raise_application_error(-20000,sqlerrm||' Fecha: '||p_fecha||' hora: '||p_hora||
                               ' Cod. usuario: '||p_cod_usuario||
                               ' Cod. Mod. Padre: '||p_cod_mod_padre);
END;
/

