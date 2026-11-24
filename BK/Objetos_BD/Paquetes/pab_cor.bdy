CREATE OR REPLACE PACKAGE BODY IT.PAB_COR is
/*
Paquete de conciliacion de rubros contables transitorios
Codificado por Simgia SRL - Agosto 2011
*/

-- Contador de conciliaciones, se incrementa en cada proceso por rubro
v_cuadre          number(10) := 0;
---DYDMR-6805 - Incidencia SAU - ITGF - Sistema Conciliaciones
/*v_fec_actual      varchar2(10)\*:= to_char(pag_cal.FU_OBT_FEC_ACTUAL(2),'dd/mm/yyyy')*\;
v_fec_actual2     varchar2(10);*/
v_fec_actual      ge_calendarios.fec_actual%type;
v_fec_actual2     ge_calendarios.fec_actual%type;
v_fec             varchar2(10);
v_fec_datos       ge_calendarios.fec_actual%type;
v_fec_proceso     varchar2(10);
v_cod_mon_local   ba_monedas.cod_moneda%type;
v_fec_ult_con     cb_cor_rub_det.fecha%type;
v_can_dia_reg_log number := to_number(fug_obt_pardinamico('CAN_DIA_REG_LOG'));
v_fec_sistema     ge_calendarios.fec_actual%type;
v_fec_control     cb_cor_rubros.fec_proceso%type;

-- Inserta Notificacion para Gestor, JGO, Grupo Juridico
PROCEDURE PR_INS_NOT_CONCILIACIONES( p_asunto      in varchar2, 
-- DYDMR-12263 - ITGF - ATENCION Cierre Contable 24/12/19 NAF 2019/DIC
                               p_mensaje     in varchar2,
                               p_proceso     in varchar2 default 'PAB_COR') is
v_destinos  varchar2(800);
begin
   v_destinos := pa_rep_aut.FU_OBT_VALOR_PAR('RA','REPORTES','IVA');
   prg_ins_notificacion( trunc(sysdate), 
                         fug_obt_dir_correo, 
                         v_destinos, 
                         p_asunto,
                         p_mensaje,
                         p_proceso);
end;  
  
-- Control y Eliminacion de Partidas Duplicadas
PROCEDURE LP_CON_DUPLICADOS(p_cod_rubro IN cb_rubros.cod_rubro%type default null) IS
-- DYDMR-12263 - ITGF - ATENCION Cierre Contable 24/12/19 NAF 2019/DIC
   v_mensaje     varchar2(4000);
   v_contador    number(10) := 1;
   v_asunto      varchar2(500);
   cursor c_duplicados is 
   select 'FECHA,HORA,COD_USUARIO,NRO_SECUENCIA,NRO_CUENTA,MONTO,COD_MONEDA,MTO_EQU_LOCAL,COTIZACION,COD_OFICINA,COD_OFI_ORIGEN,CONCEPTO,NRO_DOCUMENTO,COD_TRANSACCION,COD_MODULO,COD_MODALIDAD,NRO_DOCUMENTO4,NRO_ASIENTO,NRO_LINEA,DESCRIPCION,REVERSADO,COD_RUBRO,TIP_MOV,FEC_PROCESO,MOV_CUADRE,OBSERVACION,GRUPO,EXCEPCION,MODIFICADO,FEC_VALOR' columnas,
           FECHA||','||HORA||','||COD_USUARIO||','||NRO_SECUENCIA||','||NRO_CUENTA||','||MONTO||','||COD_MONEDA||','||MTO_EQU_LOCAL||','||COTIZACION||','||COD_OFICINA||','||COD_OFI_ORIGEN||','||CONCEPTO||','||NRO_DOCUMENTO||','||COD_TRANSACCION||','||COD_MODULO||','||COD_MODALIDAD||','||NRO_DOCUMENTO4||','||NRO_ASIENTO||','||NRO_LINEA||','||DESCRIPCION||','||REVERSADO||','||COD_RUBRO||','||TIP_MOV||','||FEC_PROCESO||','||MOV_CUADRE||','||OBSERVACION||','||GRUPO||','||EXCEPCION||','||MODIFICADO||','||FEC_VALOR datos,
           t.FECHA, t.COD_OFICINA, t.NRO_ASIENTO, t.NRO_LINEA, nvl(to_char(t.fecha, 'dd/mm/yyyy'), 0)|| nvl(t.hora, 0)|| nvl(t.cod_usuario, 0)|| nvl(t.nro_secuencia, 0) PK_MOVIMIENTO
   from cb_cor_rub_det t
   where  t.cod_rubro = p_cod_rubro
          and t.mov_cuadre is not null
          and exists( select 1 from CB_COR_RUB_DET_HIS h
                      where h.FECHA = t.FECHA and h.COD_OFICINA = t.COD_OFICINA
                            and h.NRO_ASIENTO = t.NRO_ASIENTO and h.NRO_LINEA = t.NRO_LINEA
                            and h.PK_MOVIMIENTO = nvl(to_char(t.fecha, 'dd/mm/yyyy'), 0)|| nvl(t.hora, 0)|| nvl(t.cod_usuario, 0)|| nvl(t.nro_secuencia, 0));
BEGIN
   v_asunto := 'Conciliacion Rubro '|| p_cod_rubro ||' - Partidas ya existentes en CB_COR_RUB_DET_HIS';
   for linea in c_duplicados loop
       if LENGTH(v_mensaje) > 3000 then
         -- envia email
         PR_INS_NOT_CONCILIACIONES( v_asunto || ' - ' || v_contador, 
                                    v_mensaje,
                                    'PAB_COR.LP_CON_DUPLICADOS');
         -- incrementa contador
         v_contador := v_contador+1;
         v_mensaje := null;
       end if;
       if v_mensaje is null then
          v_mensaje := 'Se encontraron las sgtes lineas, ya conciliadas anteriormente. Verifique:'||chr(13)||chr(10);
          v_mensaje :=  v_mensaje || chr(13)||chr(10);
          v_mensaje :=  v_mensaje || linea.columnas ||chr(13)||chr(10);
       end if;
       v_mensaje :=  v_mensaje || linea.datos ||chr(13)||chr(10);
   end loop;
   if v_mensaje is not null then
       -- envia email
       PR_INS_NOT_CONCILIACIONES( v_asunto || ' - ' || v_contador, 
                                  v_mensaje,
                                  'PAB_COR.LP_CON_DUPLICADOS');       
       -- elimina partidas duplicadas
       delete from cb_cor_rub_det t
       where t.cod_rubro = p_cod_rubro
              and t.mov_cuadre is not null
              and exists(select 1
              from cb_cor_rub_det_his h
              where h.FECHA = t.FECHA 
                    and h.COD_OFICINA = t.COD_OFICINA
                    and h.NRO_ASIENTO = t.NRO_ASIENTO
                    and h.NRO_LINEA = t.NRO_LINEA
                    and h.PK_MOVIMIENTO = nvl(to_char(t.fecha, 'dd/mm/yyyy'), 0)|| nvl(t.hora, 0)|| nvl(t.cod_usuario, 0)|| nvl(t.nro_secuencia, 0));
   end if;
EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN LP_CON_DUPLICADOS: '||sqlerrm);
END;


-- Trunca Tablas Temporales
PROCEDURE LP_TRU_DAT_TEMPORALES IS
-- BSEVOCORE-303 Mejoras de tiempo de procesamiento PAB_COR NAF 2019/NOV
BEGIN
    if nvl(v_fec_control, v_fec_ult_con) < v_fec_sistema then
      execute immediate 'truncate table cb_cor_asientos_det_tmp';
      execute immediate 'truncate table cb_cor_asientos_tmp';
      execute immediate 'truncate table cb_cor_movimientos_tmp';
    end if;
EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN LP_TRU_DAT_TEMPORALES: '||sqlerrm);
END;

-- Inserta movimientos desde movimientos del dia anterior
PROCEDURE LP_INS_MOV_ANTERIOR IS
-- DYDMR-12041 Lentitud en Reproceso de Contabilidad Cierre 25/11/19 NAF 2019/DIC
-- En caso de ser posible se utiliza ge_movimientos_ant para obtener movimientos
v_fec_fin             varchar2(10);
BEGIN
    v_fec_fin    := v_fec;
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_ANTERIOR', 'GE_MOVIMIENTOS_ANT INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);

    --Movimientos Fecha Anterior
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         NULL NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         MO.NRO_CONCILIACION NRO_CONCILIACION
    FROM GE_MOVIMIENTOS_ANT MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina  
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE nvl(MO.Cod_Modulo,MO.Cod_Mod_Padre) != 14 --se filtra RRHH
        and MO.Fecha = v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_ANTERIOR', 'GE_MOVIMIENTOS_ANT FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN LP_INS_MOV_ANTERIOR: '||sqlerrm);

end;

-- Inserta movimientos desde tablas historicas
PROCEDURE LP_INS_MOV_HISTORICOS IS
-- DYDMR-12041 Lentitud en Reproceso de Contabilidad Cierre 25/11/19 NAF 2019/DIC
-- Movimientos historicos se copian por separado cada tabla historica para evitar uso de union
-- Se agrega log por tabla para identificar tabla con lentitud
v_fec_inicio          date;--varchar2(10);
v_fec_fin             date;--varchar2(10);
BEGIN
    v_fec_inicio := /*to_char((*/v_fec_ult_con+1/*),'dd/mm/yyyy')*/;
    v_fec_fin    := to_date(v_fec,'dd/mm/yyyy');
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'AH_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Ahorros
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         MO.NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         MO.NRO_CONCILIACION NRO_CONCILIACION
    FROM AH_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina  
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'AH_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'CC_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Cuentas corrientes
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
       MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
       MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
       MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
       MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
       MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
       MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
       MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
       MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
       MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
       MO.NRO_FOLIO, MO.REFERENCIA,
       TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
       TH.DESCRIPCION DES_TRANSACCION,
       DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
       DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
       UA.NOMBRE NOM_USU_AUTORIZADOR,
       UR.NOMBRE NOM_USU_REVERSION,
       UM.NOMBRE NOM_USUARIO,
       EC.DESCRIPCION DES_EST_CUENTA,
       BA.DESCRIPCION DES_BANCO,
       CA.DESCRIPCION DES_CAUSA,
       RU.DESCRIPCION DES_RUBRO,
       BO.DESCRIPCION DES_OFI_ORIGEN,
       'H' TIPO,
       'HISTORICO' DES_TIPO,
       CU.DENOMINACION DENOMINACION,
       MO.COD_PERSONA COD_PERSONA,
       MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
       MO.NRO_CONCILIACION NRO_CONCILIACION
    FROM CC_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'CC_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'PR_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Prestamos
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
       MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
       MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
       MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
       MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
       MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
       MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
       MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
       MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
       MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
       TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
       TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
       TH.DESCRIPCION DES_TRANSACCION,
       DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
       DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
       UA.NOMBRE NOM_USU_AUTORIZADOR,
       UR.NOMBRE NOM_USU_REVERSION,
       UM.NOMBRE NOM_USUARIO,
       EC.DESCRIPCION DES_EST_CUENTA,
       BA.DESCRIPCION DES_BANCO,
       CA.DESCRIPCION DES_CAUSA,
       RU.DESCRIPCION DES_RUBRO,
       BO.DESCRIPCION DES_OFI_ORIGEN,
       'H' TIPO,
       'HISTORICO' DES_TIPO,
       CU.DENOMINACION DENOMINACION,
       MO.COD_PERSONA COD_PERSONA,
       MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
       NULL NRO_CONCILIACION
    FROM PR_MOVIMIENTOS_HIS MO
        -- Mejora en tiempos de ejecucion NAF ABRIL/2020
        /*join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina*/
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'PR_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'TA_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);        
    --Tarjetas
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM TA_MOVIMIENTOS_HIS MO
       -- Mejora en tiempos de ejecucion NAF ABRIL/2020
       /* join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina*/
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'TA_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'LC_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Transferencias
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
       MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
       MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
       MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
       MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
       MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
       MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
       MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
       MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
       MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
       TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
       TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
       TH.DESCRIPCION DES_TRANSACCION,
       DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
       DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
       UA.NOMBRE NOM_USU_AUTORIZADOR,
       UR.NOMBRE NOM_USU_REVERSION,
       UM.NOMBRE NOM_USUARIO,
       EC.DESCRIPCION DES_EST_CUENTA,
       BA.DESCRIPCION DES_BANCO,
       CA.DESCRIPCION DES_CAUSA,
       RU.DESCRIPCION DES_RUBRO,
       BO.DESCRIPCION DES_OFI_ORIGEN,
       'H' TIPO,
       'HISTORICO' DES_TIPO,
       CU.DENOMINACION DENOMINACION,
       MO.COD_PERSONA COD_PERSONA,
       MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
       NULL NRO_CONCILIACION
    FROM LC_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'LC_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'CX_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);         
    --Comex          
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM CX_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'CX_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);

    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'GE_MOVIMIENTOS_NOC INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Nocturnos
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM GE_MOVIMIENTOS_NOC MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'GE_MOVIMIENTOS_NOC FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);

    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'MD_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Mesa de Dinero
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM MD_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'MD_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);

    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'OV_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --Operación Vencida
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
       MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
       MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
       MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
       MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
       MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
       MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
       MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
       MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
       MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
       TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
       TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
       TH.DESCRIPCION DES_TRANSACCION,
       DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
       DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
       UA.NOMBRE NOM_USU_AUTORIZADOR,
       UR.NOMBRE NOM_USU_REVERSION,
       UM.NOMBRE NOM_USUARIO,
       EC.DESCRIPCION DES_EST_CUENTA,
       BA.DESCRIPCION DES_BANCO,
       CA.DESCRIPCION DES_CAUSA,
       RU.DESCRIPCION DES_RUBRO,
       BO.DESCRIPCION DES_OFI_ORIGEN,
       'H' TIPO,
       'HISTORICO' DES_TIPO,
       CU.DENOMINACION DENOMINACION,
       MO.COD_PERSONA COD_PERSONA,
       MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
       NULL NRO_CONCILIACION
    FROM OV_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'OV_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);

    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'AF_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);        
    --Activo Fijo
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         MO.COD_PERSONA COD_PERSONA,
         MO.COD_SIT_CONTABLE COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM AF_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
        ---agregados formato gv
        left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
        left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
        left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
        left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
        left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
             and MO.EST_CUENTA = EC.ESTADO
        left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
        left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
        left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
        left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
          and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
        left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
          and MO.COD_TRANSACCION = TH.COD_TRANSACCION
        left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'AF_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);

    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'BU_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);    
    --Bienes de Uso
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         NULL COD_PERSONA,
         NULL COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM BU_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
      ---agregados formato gv
      left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
      left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
      left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
      left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
      left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
           and MO.EST_CUENTA = EC.ESTADO
      left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
      left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
      left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
      left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
        and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
      left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
        and MO.COD_TRANSACCION = TH.COD_TRANSACCION
      left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'BU_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);        

    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'GE_MOVIMIENTOS_HIS INICIO', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
    --General
    insert into cb_cor_movimientos_tmp     
    select distinct MO.FECHA, MO.HORA, MO.COD_USUARIO, MO.NRO_SECUENCIA, MO.FEC_VALOR,
         MO.MONTO, MO.NRO_CUENTA, MO.COD_MONEDA, MO.COD_OFICINA, MO.COD_ERROR,
         MO.COD_RETENCION, MO.FEC_FIN_RETENCION, MO.EST_CUENTA, MO.ESTADO,
         MO.COD_CAUSA, MO.COD_BANCO, MO.COD_OFI_ORIGEN, MO.CONCEPTO, MO.COD_TASA,
         MO.VAL_TASA, MO.COD_RUBRO, MO.COD_REF_CAMBIO, MO.REVERSADO, MO.COD_USU_REVERSION,
         MO.HOR_REVERSION, MO.EMI_AVISO, MO.COD_TRA_PADRE, MO.COD_MOD_PADRE, MO.COD_MAD_PADRE,
         MO.COD_TRANSACCION, MO.COD_MODULO, MO.COD_MODALIDAD, MO.MTO_EQU_LOCAL, MO.NRO_CAJA,
         MO.COTIZACION, MO.COD_BCO_CENTRAL, MO.NRO_DOCUMENTO, MO.NRO_DOCUMENTO2, MO.NRO_DOCUMENTO3,
         MO.NRO_DOCUMENTO4, MO.PROTEGIDO, MO.TIP_MOV_RUBRO, MO.COD_AUTORIZACION, MO.COD_USU_AUTORIZADOR,
         MO.USU_INSERCION, MO.FEC_INSERCION, MO.USU_MODIFICACION, MO.FEC_MODIFICACION, MO.COD_TIP_OPE_CAMBIO,
         TO_NUMBER(NULL) NRO_FOLIO, MO.REFERENCIA,
         TP.DESCRIPCION DES_TRA_PADRE, TP.ABREVIATURA ABR_TRA_PADRE,
         TH.DESCRIPCION DES_TRANSACCION,
         DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO) COD_TIP_MOIMIENTO,
         DECODE(DECODE(MO.COD_TRANSACCION,515,'C',560,'C',TH.TIPO), 'C', 'Credito', 'D', 'Debito', 'E', 'Cambio Estado') TIP_MOIMIENTO,
         UA.NOMBRE NOM_USU_AUTORIZADOR,
         UR.NOMBRE NOM_USU_REVERSION,
         UM.NOMBRE NOM_USUARIO,
         EC.DESCRIPCION DES_EST_CUENTA,
         BA.DESCRIPCION DES_BANCO,
         CA.DESCRIPCION DES_CAUSA,
         RU.DESCRIPCION DES_RUBRO,
         BO.DESCRIPCION DES_OFI_ORIGEN,
         'H' TIPO,
         'HISTORICO' DES_TIPO,
         CU.DENOMINACION DENOMINACION,
         NULL COD_PERSONA,
         NULL COD_SIT_CONTABLE,
         NULL NRO_CONCILIACION
    FROM GE_MOVIMIENTOS_HIS MO
        join cb_cor_asientos_det_tmp h on h.ref_movimiento = MO.Nro_Documento4
             and h.fecha = MO.Fecha
        join cb_cor_rubros r on r.cod_rubro = h.cod_rubro and r.estado = 'A'
        join cb_cor_asientos_tmp c on h.nro_asiento = c.nro_asiento and h.fecha = c.fecha
             and h.cod_oficina = c.cod_oficina
      ---agregados formato gv
      left join CB_RUBROS RU on MO.COD_RUBRO= RU.COD_RUBRO
      left join GE_CAUSALES CA on MO.COD_CAUSA = CA.COD_CAUSA
      left join GE_BANCOS BA on MO.COD_BANCO = BA.COD_BANCO
      left join BA_OFICINAS BO on MO.COD_OFI_ORIGEN = BO.COD_OFICINA
      left join GE_EST_CUENTAS EC on MO.COD_MODULO = EC.COD_MODULO and MO.COD_MODALIDAD = EC.COD_MODALIDAD 
           and MO.EST_CUENTA = EC.ESTADO
      left join BA_USUARIOS UA on MO.COD_USU_AUTORIZADOR = UA.COD_USUARIO
      left join BA_USUARIOS UR on MO.COD_USU_REVERSION = UR.COD_USUARIO
      left join BA_USUARIOS UM on MO.COD_USUARIO = UM.COD_USUARIO
      left join GE_TRANSACCIONES TP on MO.COD_MOD_PADRE = TP.COD_MODULO and MO.COD_MAD_PADRE = TP.COD_MODALIDAD
        and MO.COD_TRA_PADRE = TP.COD_TRANSACCION
      left join GE_TRANSACCIONES TH on MO.COD_MODULO = TH.COD_MODULO and MO.COD_MODALIDAD = TH.COD_MODALIDAD
        and MO.COD_TRANSACCION = TH.COD_TRANSACCION
      left join GE_CUENTAS CU on MO.NRO_CUENTA = CU.NRO_CUENTA
    WHERE MO.Fecha between v_fec_inicio and  v_fec_fin;
    commit;      
    prb_act_log_procesos(trunc(sysdate),'PAB_COR.LP_INS_MOV_HISTORICOS', 'GE_MOVIMIENTOS_HIS FIN', null, to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), null);
EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN LP_INS_MOV_HISTORICOS: '||sqlerrm);
END;

-- Carga Tablas Temporales
PROCEDURE LP_INS_DAT_TEMPORALES IS
-- BSEVOCORE-303 Mejoras de tiempo de procesamiento PAB_COR NAF 2019/NOV
v_fec_inicio          date;--varchar2(10);
v_fec_fin             date;--varchar2(10);
v_es_fec_anterior     varchar2(1);
BEGIN
    v_fec_inicio      := /*to_char((*/v_fec_ult_con+1/*),'dd/mm/yyyy')*/;
    v_fec_fin         := to_date(v_fec,'dd/mm/yyyy');
    v_es_fec_anterior := 'N';    
    
    if nvl(v_fec_control, v_fec_ult_con) < v_fec_sistema then
      -- inserta cabecera de asientos
      insert into cb_cor_asientos_tmp
      select distinct b.*
      from cb_asientos_det_his a
           join cb_cor_rubros c on a.cod_rubro = c.cod_rubro
                and c.estado = 'A'
           join cb_asientos_his b on a.nro_asiento = b.nro_asiento
                   and a.fecha = b.fecha and a.cod_oficina = b.cod_oficina       
      where a.fecha between v_fec_inicio and  v_fec_fin;       
      commit;
      BEGIN dbms_stats.gather_table_stats('IT','cb_cor_asientos_tmp');END;
      
      -- inserta detalle de asientos
      insert into cb_cor_asientos_det_tmp
      select distinct a.*
      from cb_asientos_det_his a
           join cb_cor_rubros c on a.cod_rubro = c.cod_rubro
                and c.estado = 'A'
           join cb_asientos_his b on a.nro_asiento = b.nro_asiento
                   and a.fecha = b.fecha and a.cod_oficina = b.cod_oficina       
      where a.fecha between v_fec_inicio and  v_fec_fin;  
      commit;
      BEGIN dbms_stats.gather_table_stats('IT','cb_cor_asientos_det_tmp');END;
       
      -- inserta movimientos
      -- DYDMR-12041 Lentitud en Reproceso de Contabilidad Cierre 25/11/19 NAF 2019/DIC
      -- verifica si es se puede utilizar ge_movimientos_ant
      IF v_fec_inicio = v_fec_fin THEN
        --si no es un rango de fechas se verifica fecha anterior
        begin
          --NAF FEB/2020
          select distinct 'S'
          into v_es_fec_anterior
          from ge_movimientos_ant a
             join (select fecha, count(1) can_reg from ge_movimientos_ant t group by fecha) b on b.fecha = a.fecha
             join (select max(can_reg) max_reg
                  from(select fecha, count(1) can_reg from ge_movimientos_ant t group by fecha)) c on b.can_reg = c.max_reg
          where a.fecha = v_fec_fin;
        exception
            when others then
                null;
        end;
      END IF;
      -- inserta movimientos
      IF v_es_fec_anterior = 'S' THEN
         LP_INS_MOV_ANTERIOR;
      ELSE
         LP_INS_MOV_HISTORICOS;
      END IF;      
      BEGIN dbms_stats.gather_table_stats('IT','cb_cor_movimientos_tmp');END;
    end if;
EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN LP_INS_DAT_TEMPORALES: '||sqlerrm);
END;

-- Actualiza hora de Inicio o Fin por Rubro
PROCEDURE LP_ACT_PRO_RUBRO(p_cod_rubro IN cb_rubros.cod_rubro%type default null,
                           p_tipo      varchar2 default 'I') is
-- BSEVOCORE-303 NAF 2019/NOV actualiza fecha de ultima conciliacion
BEGIN
    --Actualiza hora inicio
    if p_tipo = 'I' then
       update cb_cor_rubros 
       set inicio = to_char(sysdate,'HH24:mi:ss')
       where cod_rubro = p_cod_rubro;
    -- Actualiza hora fin
    elsif p_tipo = 'F' then
       update cb_cor_rubros 
       set fin = to_char(sysdate,'HH24:mi:ss'),           
           fec_ult_proceso = v_fec_sistema
       where cod_rubro = p_cod_rubro;
       
    end if;
END;

--Inicializa hora de Inicio y Fin antes de procesar
PROCEDURE PR_INI_PRO_RUBRO is
-- BSEVOCORE-303 NAF 2019/NOV actualiza fecha de ultima conciliacion
v_fec_ini_recu        cb_cor_rubros.fec_proceso%type;
v_fec_fin_recu        cb_cor_rubros.fec_ult_proceso%type;
BEGIN 
    if nvl(v_fec_control, v_fec_ult_con) < v_fec_sistema then
      --inicializa los campos
      update cb_cor_rubros 
      set inicio = null,
          fin = null, 
          fec_proceso = v_fec_sistema
      where estado = 'A';
      --Almacena rango de fechas para reproceso
      --Utiliza rubro 100000000000000 estado X para almacenar estos datos
      update cb_cor_rubros t
      set t.fec_proceso = v_fec_ult_con,
          t.fec_ult_proceso = to_date(v_fec,'dd/mm/yyyy')
      where estado = 'X'
      and cod_rubro = '100000000000000';
      IF SQL%NOTFOUND THEN
         Insert Into cb_cor_rubros(cod_rubro,estado,fec_proceso,fec_ult_proceso)
         values ('100000000000000','X',v_fec_ult_con,to_date(v_fec,'dd/mm/yyyy'));
      END IF;
    else
      -- recupera fechas para continuar con el procesamiento
      begin
        select fec_proceso, fec_ult_proceso
            into v_fec_ini_recu, v_fec_fin_recu
        from cb_cor_rubros
        where estado = 'X'
            and cod_rubro = '100000000000000';
        v_fec_ult_con := v_fec_ini_recu;
        v_fec         := v_fec_fin_recu;
      exception
          when others then
             null;
      end;
    end if;    
END;

-- Inactiva rubro especificado en el parametro
PROCEDURE PR_INA_RUBRO(p_cod_rubro IN varchar2 default null) is
-- BSEVOCORE-303 NAF 2019/NOV actualiza fecha de ultima conciliacion
v_cod_rubros varchar2(500) := null;
cursor c_rubros(v_rubros varchar2) is
  select regexp_substr(v_rubros,'[^,]+', 1, level) cod_rubro 
  from dual
  connect by regexp_substr(v_rubros, '[^,]+', 1, level) is not null;
BEGIN
       if p_cod_rubro is null then
         v_cod_rubros := fug_obt_pardinamico('PAB_COR_CAM_EST_RUBRO');
       else
         v_cod_rubros := p_cod_rubro;
       end if;
       if v_cod_rubros is not null then
         for r in c_rubros(replace(v_cod_rubros, ';', ',')) loop
           update cb_cor_rubros 
           set estado = 'I'
           where cod_rubro = r.cod_rubro;
         end loop;
       end if;
END;

-- Activa rubro especificado en el parametro
PROCEDURE PR_ACT_RUBRO(p_cod_rubro IN varchar2 default null) is
-- BSEVOCORE-303 NAF 2019/NOV actualiza fecha de ultima conciliacion
v_cod_rubros varchar2(500) := null;
cursor c_rubros(v_rubros varchar2) is
  select regexp_substr(v_rubros,'[^,]+', 1, level) cod_rubro 
  from dual
  connect by regexp_substr(v_rubros, '[^,]+', 1, level) is not null;
BEGIN
       if p_cod_rubro is null then
         v_cod_rubros := fug_obt_pardinamico('PAB_COR_CAM_EST_RUBRO');
       else
         v_cod_rubros := p_cod_rubro;
       end if;
       if v_cod_rubros is not null then
         for r in c_rubros(replace(v_cod_rubros, ';', ',')) loop
           update cb_cor_rubros 
           set estado = 'A'
           where cod_rubro = r.cod_rubro;
         end loop;
       end if;
END;

-- Procedimiento principal de Conciliaciones,
-- llama al procesos de conciliacion de cada rubro cargado con estado activo
PROCEDURE PR_GEN_CON_RUB IS
  cursor c_rubros is
   SELECT distinct a.cod_rubro
        from  cb_cor_rubros a
        where a.estado='A'
          and a.fec_proceso = v_fec_sistema
          and a.fin is null;
 BEGIN
   -- Proyecto: CNFIFPCO-1  / RABP_CNF_06-2016 --
    v_fec_actual  := null;
    v_fec_actual2 := null;
    v_fec         := null;
    v_fec_proceso := null;
    v_fec_datos   := null;
    v_fec_sistema := pae_cnf.fu_obt_fec_actual(2); -- fecha modulo contable

    ---DYDMR-6805 - Incidencia SAU - ITGF - Sistema Conciliaciones
    select max(c.fecha) into v_fec_actual from cb_asientos_his c;
    select max(a.fecha) into v_fec_actual2 from cb_sal_oficinas_dia a;
    if v_fec_actual = v_fec_actual2 then
       v_fec_datos := v_fec_actual;
    else
       if v_fec_actual < v_fec_actual2 then
          v_fec_datos := v_fec_actual;
        else
          v_fec_datos := v_fec_actual2;
        end if;
    end if;

    v_fec :=  to_char(v_fec_datos,'dd/mm/yyyy');
    --v_fec:='24/08/2011';

    select to_char(sysdate,'dd/mm/yyyy') into v_fec_proceso from dual;
    -----------------------------------------------------------------------------

    ---busca la ultima fecha de proceso en cb_con_det y trae los movimientos con fecha mayor a esta
    begin
      select max(d.fecha) into v_fec_ult_con ---fecha
      from
      (select max(a.fecha) fecha from cb_cor_rub_det a
           left join (select cod_rubro from cb_cor_rubros 
                      where fec_proceso = v_fec_sistema
                      and estado = 'A'
                      and fin is not null) b on a.cod_rubro = b.cod_rubro
       where b.cod_rubro is null
       union
       select max(a.fecha) fecha from cb_cor_rub_det_his a
           left join (select cod_rubro from cb_cor_rubros 
                      where fec_proceso = v_fec_sistema
                      and estado = 'A'
                      and fin is not null) b on a.cod_rubro = b.cod_rubro
       where b.cod_rubro is null) d;
    exception
       when others then
            v_fec_ult_con := null;
    end;
    if v_fec_ult_con is null then
      select max(d.fecha) into v_fec_ult_con ---fecha
      from
      (select max(a.fecha) fecha from cb_cor_rub_det a
      union all
      select max(b.fecha) fecha from cb_cor_rub_det_his b
      ) d;
    end if;
    
    -- DYDMR-12116 control para reprocesos
    select max(fec_proceso) into v_fec_control from cb_cor_rubros where estado = 'A';
     
    -- BSEVOCORE-303 Mejoras de tiempo de procesamiento PAB_COR NAF 2019/NOV
    --Trunca tablas temporales - BSEVOCORE-303 NAF 2019/NOV
    LP_TRU_DAT_TEMPORALES;
    --Inserta datos en tablas temporales - BSEVOCORE-303 NAF 2019/NOV
    LP_INS_DAT_TEMPORALES;
    --Actualiza vista materializada datos infonet
    PRT_ACT_MOV_INFONET;
    --Inicializa fec_proceso, hora inicio y fin de rubros
    PR_INI_PRO_RUBRO; -- DYDMR-12116 cambio de orden evita inconsist. si se corta el procesamiento x DBA
    
    for rub in c_rubros loop
        LP_ACT_PRO_RUBRO(rub.cod_rubro);
        PR_GEN_RUB_CONC(rub.cod_rubro);
        LP_ACT_PRO_RUBRO(rub.cod_rubro,'F');
        commit;
    end loop;

     --DYDMR-6535 - Incidencia SAU - ITGF - Diferencia Cuenta Contable - Seguro en Transito MAPFRE
     delete from cb_log_procesos g
     where g.fecha <= (v_fec_ult_con - v_can_dia_reg_log);

 EXCEPTION
     WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_GEN_CON_RUB: '||sqlerrm);
 END;

--Genera conciliacion de un rubro dado, ejecutando los procesos configurados para cada rubro
PROCEDURE PR_GEN_RUB_CONC(v_cod_rubro varchar2) is
  v_proceso varchar2(50);
  v_pro_orden number;
  v_str_parametros long;
  v_parametro long;
  v_procesar long;
  v_hor_inicio      varchar2(8);
  v_hor_fin         varchar2(8);

  --cursor de procesos
  cursor c_procesos is
   SELECT c.orden,b.cod_proceso,b.nom_proceso
        from  cb_cor_rubros a, cb_cor_procesos b, cb_cor_rub_procesos c
        where a.cod_rubro=v_cod_rubro
        and a.cod_rubro=c.cod_rubro
        and b.cod_proceso=c.cod_proceso
        order by c.orden asc;
  --cursor de parametros
  cursor c_parametros is
    SELECT b.cod_proceso,c.orden pro_orden,e.cod_parametro, d.orden par_orden, e.valor,d.tipo
       from  cb_cor_rubros a, cb_cor_procesos b, cb_cor_rub_procesos c, cb_cor_parametros d, cb_cor_pro_parametros e
        where a.cod_rubro=v_cod_rubro
        and a.cod_rubro=c.cod_rubro
        and a.cod_rubro=e.cod_rubro
        and b.cod_proceso=c.cod_proceso
        and d.cod_proceso = c.cod_proceso
        and d.cod_parametro = e.cod_parametro
        and e.orden = c.orden
        order by c.orden asc, d.orden;

  BEGIN
    v_cuadre:=1; --inicializa nro secuencial de conciliación para cada rubro
    for proc in c_procesos loop
        v_proceso := proc.nom_proceso;
        v_pro_orden := proc.orden;
        v_str_parametros := null;
        v_parametro := null;

        -- se arma string de parametros
        for para in c_parametros loop
            if proc.cod_proceso=para.cod_proceso and proc.orden=para.pro_orden then
               if v_str_parametros is not null then
                  v_str_parametros := v_str_parametros || CHR(44);
               end if;
               if para.tipo = 'NUMBER' then
                  v_parametro := para.valor;
               else
                  v_parametro := replace(para.valor,CHR(39),CHR(39)||CHR(39));
                  v_parametro := '''' || v_parametro || '''';
               end if;
               v_str_parametros := v_str_parametros || v_parametro;
               --dbms_output.put_line(para.valor);
            end if;
         end loop;
         v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
         --se ejecuta el proceso
         v_procesar := 'BEGIN ' || v_proceso || ' (' || v_str_parametros || '); END;';
         --dbms_output.put_line(v_procesar);

         --DYDMR-6535 - Incidencia SAU - ITGF - Diferencia Cuenta Contable - Seguro en Transito MAPFRE
         v_hor_fin := to_char(sysdate,'hh24:mi:ss');
         prb_act_log_procesos(trunc(sysdate),'PAB_COR.PR_GEN_RUB_CONC', v_proceso, v_cod_rubro, v_hor_inicio, v_hor_fin, v_str_parametros);

         execute immediate (v_procesar) ;

    end loop;
  EXCEPTION
     WHEN OTHERS THEN
       --DYDMR-6535 - Incidencia SAU - ITGF - Diferencia Cuenta Contable - Seguro en Transito MAPFRE
       v_hor_fin := to_char(sysdate,'hh24:mi:ss');
       prb_act_log_procesos(trunc(sysdate),'PAB_COR.PR_GEN_RUB_CONC', 'Error_'||v_proceso, v_cod_rubro, v_hor_inicio, v_hor_fin, sqlerrm||'-'||v_str_parametros);

       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_GEN_RUB_CONC: '||sqlerrm);
  END;
---FIN DE PR_GEN_RUB_CONCILIACION

--Proceso para insercion de movimientos del rubro
PROCEDURE PR_CON_CAR_DATOS
( v_cod_rubro varchar2,
  v_consulta long,
  v_fec_inicio varchar2 default null) IS
  v_fecha           varchar2(10) := null;
  --v_fec_proceso     varchar2(10);
  v_consulta2       long;
  --v_con_fecha       varchar(10);


  BEGIN

    -- Se comenta y se lleva lo mismo al proceso principal para que se --
    -- ejecute una sola vez, ya que no tiene en cuenta el rubro para hallar las fechas. --
    -- Proyecto: CNFIFPCO-1  / RABP_CNF_06-2016 --
    /*
    v_fecha := null;
    v_fec_proceso := null;

    select to_char(max(c.fecha),'dd/mm/yyyy') into v_fec_actual from cb_asientos_his c;
    select to_char(max(a.fecha),'dd/mm/yyyy') into v_fec_actual2 from cb_sal_oficinas_dia a;
    if v_fec_actual=v_fec_actual2 then
       v_fec:=v_fec_actual;
    else
       if v_fec_actual <v_fec_actual2 then
        v_fec:=v_fec_actual;
        else
        v_fec:=v_fec_actual2;
        end if;
    end if;
    --v_fec:='24/08/2011';

    select to_char(sysdate,'dd/mm/yyyy') into v_fec_proceso from dual;
*/
     /*---busca la ultima fecha de proceso en cb_con_det y trae los movimientos con fecha mayor a esta
     select to_char(max(d.fecha),'dd/mm/yyyy') into v_fecha---fecha
     from
     (select a.fecha from cb_cor_rub_det a
     where a.cod_rubro=v_cod_rubro
     union all
     select b.fecha from cb_cor_rub_det_his b
     where b.cod_rubro=v_cod_rubro) d;*/

     -- Proyecto: CNFIFPCO-1  / RABP_CNF_06-2016 --
     -- Objeto: Sumar a la ultima fecha de conciliacion un día más debido a que se modifica el filtro del select V_CONSULTA2,
     --         fecha > [p_fecha] modificado a between [p_fecha] and [p_fec_actual]
     v_fecha := to_char((v_fec_ult_con+1),'dd/mm/yyyy');

     IF v_fecha is null then
        if v_fec_inicio is not null then
           v_fecha := to_char((to_date(v_fec_inicio,'dd/mm/yyyy')+1),'dd/mm/yyyy');
           --v_fecha:=v_fec_inicio;
        else
          select to_char((min(d.fecha)+1),'dd/mm/yyyy') into v_fecha from
          cb_asientos_det_his d
          where d.cod_rubro=v_cod_rubro;

          IF v_fecha is null then
            v_fecha:='01/01/1900';
          end if;
        end if;
     end if;

     v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;

     --inserta las partidas a conciliar
     v_consulta2 := replace(v_consulta,'[p_mon_local]','"' ||v_cod_mon_local|| '"');
     v_consulta2 := replace(v_consulta2,'[p_fecha]',' to_date("' ||v_fecha|| '","DD/MM/YYYY")');
     v_consulta2 := replace(v_consulta2,'[p_fec_proceso]',' to_date("' ||v_fec_proceso|| '","DD/MM/YYYY")');
     v_consulta2 := replace(v_consulta2,'[p_fec_actual]',' to_date("' ||v_fec|| '","DD/MM/YYYY")');
     v_consulta2 := replace(v_consulta2,'"','''');
     
     -- BSEVOCORE-303 NAF 2019/NOV reemplaza tablas historicas por tablas tmp
     v_consulta2 := replace(v_consulta2,'gv_movimientos','cb_cor_movimientos_tmp');
     v_consulta2 := replace(v_consulta2,'cb_asientos_his','cb_cor_asientos_tmp');
     v_consulta2 := replace(v_consulta2,'cb_asientos_det_his','cb_cor_asientos_det_tmp');
     
     --dbms_output.put_line(v_consulta2);
     execute immediate v_consulta2;

     update cb_cor_rub_det
        set mov_cuadre = null
      where mov_cuadre is not null
        and mov_cuadre not in (9999999997,9999999998,9999999999)
        and cod_rubro = v_cod_rubro;

  EXCEPTION
     WHEN OTHERS THEN
       --DYDMR-6535 - Incidencia SAU - ITGF - Diferencia Cuenta Contable - Seguro en Transito MAPFRE
       prb_act_log_procesos(trunc(sysdate),'PAB_COR.PR_CON_CAR_DATOS', 'ERROR_PR_CON_CAR_DATOS', v_cod_rubro,
                           to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'), sqlerrm||'-'||v_consulta2);

       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_CAR_DATOS: '||sqlerrm);
  END;
--- fin del PR_CON_CARGA------------------------------------


--Proceso que concilia todas las partidas del rubro en caso de que el saldo actual=0
PROCEDURE PR_CER_SALDO
(v_cod_rubro varchar2)
is

 v_mon_local number:=0;
 v_mon_ext   number:=0;

 cursor c_cua_datos is
 select sum(abs(nvl(t.monto,0))) monto, t.cod_oficina
  from cb_cor_rub_det t
  where t.mov_cuadre is null
  and t.cod_rubro=v_cod_rubro
  group by t.cod_oficina;

Begin
 for reg in c_cua_datos loop
  Begin
   select sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
    sum((nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) mon_ext
    into v_mon_local,v_mon_ext
    from cb_sal_oficinas_dia a
    where a.cod_rubro= v_cod_rubro
    and a.fecha=to_date(v_fec,'dd/mm/yyyy')
    and a.cod_oficina=reg.cod_oficina-- debe ser por oficina relevado con Victor Palomar
    group by a.cod_rubro;
    exception
         when others then
           v_mon_local:=0;
           v_mon_ext:=0;
      end;

 --verifica si tiene saldo sino tiene concilia todas las partidas con misma oficina
  if v_mon_local=0 and v_mon_ext=0 then
    update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where cod_rubro=v_cod_rubro
         and mov_cuadre is null
         and cod_oficina=reg.cod_oficina;
      --- Actualizar mov_cuadre del debito
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where cod_rubro=v_cod_rubro
        and mov_cuadre is null
        and cod_oficina=reg.cod_oficina;
      v_cuadre := v_cuadre + 1;

  end if;
  end loop;

 EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CER_SALDO: '||sqlerrm);
end;
--fin

---Proceso de conciliacion básica según la AS400
PROCEDURE PR_CON_BASICO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
)
 is
  v_monto         cb_cor_rub_det.monto%type;
  v_nro_documento cb_cor_rub_det.nro_documento%type;
  v_cod_oficina   cb_cor_rub_det.cod_oficina%type;
  v_cantidad      number:=0;

---cursor
cursor c_cua_basico is
 select t.nro_documento, (nvl(t.monto,0)) monto, t.cod_oficina
  from cb_cor_rub_det t
  where t.mov_cuadre is null
  and t.tip_mov=v_mov_inicial
   and t.cod_rubro=v_cod_rubro
  and t.nro_documento is not null;


   --- Cuadro directo por nro_documento, monto, fecha
   BEGIN
   for reg in c_cua_basico loop
      --- Buscar movimiento que le corresponda
      begin
         select (nvl(x.monto,0)), x.nro_documento, x.cod_oficina
           into v_monto,v_nro_documento, v_cod_oficina
           from cb_cor_rub_det x
          where tip_mov=v_mov_final
            and monto= reg.monto
            and mov_cuadre is null
           and cod_rubro=v_cod_rubro
            and nro_documento=reg.nro_documento
            and cod_oficina=reg.cod_oficina
            /*group by x.nro_documento, x.cod_oficina*/;

      --- Si existe movimiento, actualizar mov_cuadre
      select count(1) into v_cantidad
       from cb_cor_rub_det d
       where d.tip_mov=v_mov_inicial
       and d.monto=v_monto
       and d.nro_documento=reg.nro_documento
       and d.cod_oficina=reg.cod_oficina;
      if v_cantidad =1 then
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where monto = v_monto
         and tip_mov=v_mov_final
         and cod_rubro=v_cod_rubro
         and nro_documento=v_nro_documento
         and cod_oficina=v_cod_oficina
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del debito
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where abs(monto)=v_monto
         and tip_mov=v_mov_inicial
         and cod_rubro=v_cod_rubro
         and nro_documento=v_nro_documento
         and cod_oficina=v_cod_oficina
         and mov_cuadre is null;
      v_cuadre := v_cuadre + 1;
      end if;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_BASICO: '||sqlerrm);
END;
--Fin Proceso de conciliacion por montos iguales

---Proceso de conciliacion básica según la AS400 teniendo en cuenta el mismo concepto
PROCEDURE PR_CON_CONCEPTO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
)
 is
  v_monto         cb_cor_rub_det.monto%type;
  v_nro_documento cb_cor_rub_det.nro_documento%type;
  v_cod_oficina   cb_cor_rub_det.cod_oficina%type;
  v_cantidad      number:=0;

---cursor
cursor c_cua_basico is
 select abs(nvl(t.monto,0)) monto, t.concepto,t.cod_oficina
  from cb_cor_rub_det t
  where t.mov_cuadre is null
  and t.tip_mov=v_mov_inicial
  and t.cod_rubro=v_cod_rubro
  and t.concepto is not null;


   --- Cuadro directo por nro_documento, monto, fecha
   BEGIN
   for reg in c_cua_basico loop
      --- Buscar movimiento que le corresponda
      begin
         select abs(nvl(x.monto,0)), x.nro_documento, x.cod_oficina
           into v_monto,v_nro_documento, v_cod_oficina
           from cb_cor_rub_det x
          where x.tip_mov=v_mov_final
            and abs(monto)= reg.monto
            and x.mov_cuadre is null
            and x.cod_rubro=v_cod_rubro
            and x.concepto=reg.concepto
            and x.cod_oficina=reg.cod_oficina
            /*group by x.nro_documento, x.cod_oficina*/;

      select count(1) into v_cantidad
       from cb_cor_rub_det d
       where d.tip_mov=v_mov_inicial
       and d.monto=v_monto and d.concepto=reg.concepto
       and d.cod_oficina=reg.cod_oficina;
      --- Si existe movimiento, actualizar mov_cuadre
      if v_cantidad =1 then
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where monto = v_monto
         and tip_mov=v_mov_final
         and cod_rubro=v_cod_rubro
         and concepto=reg.concepto
         and cod_oficina=v_cod_oficina
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del debito
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where monto=v_monto
         and tip_mov=v_mov_inicial
         and cod_rubro=v_cod_rubro
         and concepto=reg.concepto
         and cod_oficina=v_cod_oficina
         and mov_cuadre is null;
      v_cuadre := v_cuadre + 1;
      end if;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_CONCEPTO: '||sqlerrm);
END;
--Fin Proceso de conciliacion por montos iguales
---Proceso de conciliacion por montos iguales y oficina
PROCEDURE PR_CON_TOT_MONTO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2
)
 is
  v_monto       cb_cor_rub_det.monto%type;

---cursor
cursor c_cua_monto is
   select t.monto,t.cod_oficina
   from cb_cor_rub_det t
   where t.mov_cuadre is null
   and t.tip_mov=v_mov_inicial
   and t.cod_rubro=v_cod_rubro;

   --- Cuadro directo por monto
   BEGIN
     for reg in c_cua_monto loop
        --- Buscar movimiento de credito que le corresponda
        begin
           select x.monto
             into v_monto
             from cb_cor_rub_det x
            where x.tip_mov=v_mov_final
              and x.monto= reg.monto
              and x.cod_oficina=reg.cod_oficina
              and mov_cuadre is null
              and x.cod_rubro=v_cod_rubro
              and rownum=1;

        --- Si existe movimiento, actualizar mov_cuadre del credito
        update cb_cor_rub_det
           set mov_cuadre = v_cuadre
         where monto = reg.monto
           and tip_mov=v_mov_final
           and rownum=1
           and cod_rubro=v_cod_rubro
           and cod_oficina=reg.cod_oficina
           and mov_cuadre is null;
        --- Actualizar mov_cuadre del debito
        update cb_cor_rub_det
           set mov_cuadre = v_cuadre
         where monto=reg.monto
           and tip_mov=v_mov_inicial
           and rownum=1
           and cod_oficina=reg.cod_oficina
           and cod_rubro=v_cod_rubro
           and mov_cuadre is null;
           v_cuadre := v_cuadre + 1;
        exception
           when no_data_found then null;
           when too_many_rows then null;
        end;
     end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TOT_MONTO: '||sqlerrm);
END;
--Fin Proceso de conciliacion por montos iguales
--Proceso de conciliacion por total de montos de una fecha dada contra total de montos de otra fecha
PROCEDURE PR_CON_TOT_FEC_MONTO
(v_cod_rubro varchar2,
v_mov_inicial varchar2,
v_mov_final varchar2,
v_dias number)
 is
  v_tot_monto       cb_cor_rub_det.monto%type;
  v_fecha           date;
  v_cod_moneda      cb_cor_rub_det.cod_moneda%type;
  v_oficina         cb_cor_rub_det.cod_oficina%type;

  ---cursor
cursor c_cua_deb is
   select t.fecha, t.cod_moneda,t.cod_oficina, sum(t.monto) monto
   from cb_cor_rub_det t
   where t.mov_cuadre is null
   and t.cod_rubro=v_cod_rubro
   and t.tip_mov=v_mov_inicial
   group by t.fecha, t.cod_moneda,t.cod_oficina
   order by t.fecha;

 --- Cuadro directo por total monto
   BEGIN
   for reg in c_cua_deb loop

     --- Buscar movimiento de credito que le corresponda
      begin
         select c.fecha, c.cod_moneda, c.monto,c.cod_oficina
         into v_fecha, v_cod_moneda, v_tot_monto,v_oficina
         from (select x.fecha, x.cod_moneda,x.cod_rubro,x.cod_oficina,sum(x.monto) monto
           from cb_cor_rub_det x
           where tip_mov=v_mov_final
           and mov_cuadre is null
           and x.cod_rubro=v_cod_rubro
           and x.cod_oficina=reg.cod_oficina
           group by x.fecha, x.cod_moneda,x.cod_rubro,x.cod_oficina)c
         where c.monto = reg.monto
         and c.fecha= pag_cal.fu_obt_fec_habil(reg.fecha+v_dias,1,7);

      --- Si existe movimiento, actualizar mov_cuadre del credito
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where v_fecha    = fecha
         and cod_moneda = reg.cod_moneda
         and tip_mov    = v_mov_final
         and cod_oficina= reg.cod_oficina
         and mov_cuadre is null
         and cod_rubro  =  v_cod_rubro;
      --- Actualizar mov_cuadre del debito
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where reg.fecha = fecha
         and cod_moneda= reg.cod_moneda
         and tip_mov=v_mov_inicial
         and cod_oficina=reg.cod_oficina
         and mov_cuadre is null
         and cod_rubro=v_cod_rubro;
      v_cuadre := v_cuadre + 1;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TOT_FEC_MONTO: '||sqlerrm);
END;
---Fin PR_CON_TOT_FEC_MONTO

--Proceso de pase a historico de conciliados
PROCEDURE PR_CON_PAS_HIS_RUB
(v_cod_rubro varchar2) is
--v_fecha date;
BEGIN
  --select pag_cal.FU_OBT_FEC_ACTUAL(1) into v_fecha from dual;
   --inserta en el historico las partidas conciliadas
/*   insert into cb_cor_rub_det_his(fecha,cod_oficina,nro_asiento,nro_linea,pk_movimiento,cod_rubro,fecha_mov,hora_mov,cod_usuario_mov,nro_secuencia_mov, ref_movimiento,fec_conciliacion,mov_cuadre,con_forma,cod_usu_con)
   select fecha,cod_oficina,nro_asiento,nro_linea,nvl(to_char(t.fecha,'dd/mm/yyyy'),0)||nvl(t.hora,0)||nvl(t.cod_usuario,0)||nvl(t.nro_secuencia,0),cod_rubro,t.fecha,t.hora,t.cod_usuario,t.nro_secuencia, nro_documento4,trunc(sysdate),mov_cuadre,'automatico',null from cb_cor_rub_det t
   where t.mov_cuadre is not null and t.cod_rubro=v_cod_rubro;*/

 -- DYDMR-12263 - ITGF - ATENCION Cierre Contable 24/12/19 NAF 2019/DIC
 -- Controla Partidas ya existentes en el Historico
 -- Envia email de aviso y elimina para evitar errtores en el cierre
 LP_CON_DUPLICADOS(v_cod_rubro);
 
 -- DYDMR-6846 - Incidencia SAU - ITGF - Rubros seguros
 insert into cb_cor_rub_det_his (
 fecha, hora_mov, cod_usuario_mov, nro_secuencia_mov, nro_cuenta, monto, cod_moneda, mto_equ_local, cotizacion,
 cod_oficina, cod_ofi_origen,concepto, nro_documento, cod_transaccion, cod_modulo, cod_modalidad, ref_movimiento,
 nro_asiento, nro_documento4, nro_linea, descripcion, reversado, cod_rubro, tip_mov, fec_proceso, mov_cuadre,
 observacion, grupo, excepcion, modificado, fec_valor, fecha_mov,
 pk_movimiento, fec_conciliacion, con_forma, cod_usu_con)
 select t.fecha, t.hora, t.cod_usuario, t.nro_secuencia, t.nro_cuenta, t.monto, t.cod_moneda, t.mto_equ_local, t.cotizacion,
         t.cod_oficina, t.cod_ofi_origen, t.concepto, t.nro_documento, t.cod_transaccion, t.cod_modulo, t.cod_modalidad, t.nro_documento4,
         nvl(t.nro_asiento,0), t.nro_documento4, t.nro_linea, t.descripcion, t.reversado, t.cod_rubro, t.tip_mov, t.fec_proceso, t.mov_cuadre,
         t.observacion, t.grupo, t.excepcion, t.modificado, t.fec_valor, t.fecha,
         nvl(to_char(t.fecha, 'dd/mm/yyyy'), 0)|| nvl(t.hora, 0)|| nvl(t.cod_usuario, 0)|| nvl(t.nro_secuencia, 0),
         trunc(sysdate),'automatico', null
    from cb_cor_rub_det t
   where t.mov_cuadre is not null
     and t.cod_rubro = v_cod_rubro;

   --elimina la spartidas conciliadas de cb_cor_rub_det, dejando solo las pendientes
   execute immediate 'delete cb_cor_rub_det where mov_cuadre is not null and cod_rubro=''' || v_cod_rubro || '''';
EXCEPTION
    WHEN OTHERS THEN --DYDMR-1682 - EGC - ERROR INICIO CONTABLE 2015-03-18 SC 14483 - Mostrar cod_rubro.
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_PAS_HIS_RUB - rubro '||v_cod_rubro||': '||sqlerrm);
END;
---------------------------------------------------------------------------------------------------------------------
-- fin de PR_CON_PAS_HIS
/* Procedimiento para Tarjeta
  Obs importante: Para el caso del rubro:
  150102570206099 - Liquidación tarjetas bcos país
  se utiliza el nro de boleta, valor que corresponde al
  campo nro_documento3, que se puede obtener de la vista
  gv_movimientos,

  El valor de nro_documento3 debe ser guardado como nro_documento en
  cb_cor_rub_det y no se debe tocar nro_documento4 dado que éste último
  se usa para enlazar con los asientos.
  --importe por importe y Nro de boleta..
*/
PROCEDURE PR_CON_NRO_BOLETA
(   v_cod_rubro varchar2,
   v_mov_inicial char,
   v_mov_final   char
) is
v_existe number :=0;

cursor c_rubros_ini is
  select   nvl(t.monto,0) monto, t.cod_rubro,t.nro_documento
  from   cb_cor_rub_det t
  where   t.mov_cuadre is null
  and   t.tip_mov=v_mov_inicial -- Se recuperan créditos 'C'
  and   t.cod_rubro=v_cod_rubro
  and   t.nro_documento is not null;
BEGIN
  for reg in c_rubros_ini loop
  v_existe:=0;
  begin
    select  count(1) as cant
    into  v_existe
    from  cb_cor_rub_det crd
    where  crd.tip_mov   =   v_mov_final --Se buscan déditos 'D'
    and    crd.cod_rubro   =  v_cod_rubro
    and    crd.monto     =   reg.monto
    and    crd.nro_documento=  reg.nro_documento
    and    crd.mov_cuadre is null;

    if nvl(v_existe,0) = 1 then
      -- marcar como conciliado el crédito
       update cb_cor_rub_det crd
       set    mov_cuadre        = v_cuadre
       where   crd.tip_mov        = v_mov_inicial
       and     crd.cod_rubro      = v_cod_rubro
       and     crd.monto          = reg.monto
       and     crd.nro_documento = reg.nro_documento
       and     crd.mov_cuadre     is null;
       -- marcar como conciliado el débito
       update cb_cor_rub_det    crd
       set    mov_cuadre        = v_cuadre
       where   crd.tip_mov        = v_mov_final
        and     crd.cod_rubro      = v_cod_rubro
        and     crd.monto          = reg.monto
        and     crd.nro_documento = reg.nro_documento
        and     crd.mov_cuadre    is null;
        v_cuadre := v_cuadre + 1;
    end if;
     exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
  end loop;
  EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_NRO_BOLETA: '||sqlerrm);
END;
  -- fin PR_CON_NRO_BOLETA

  --Procedimiento para
/*
  Obs importante: Para el caso del rubro:
  240402600206099- Liquidación tarjetas bcos país
  se utiliza el nro de cuenta operativa, valor que corresponde al
  campo ???, que se puede obtener de la vista
  gv_movimientos,

  El valor de ??? debe ser guardado como nro_documento en
  cb_cor_rub_det y no se debe tocar nro_documento4 dado que éste último
  se usa para enlazar con los asientos.
*/
PROCEDURE PR_CON_CTA_OPER
(  v_cod_rubro varchar2,
   v_mov_inicial char, --Debito
   v_mov_final   char --Credito
) is
v_tot_credito number(18,2);
v_nro_cuenta varchar2(100);
v_fecha_cre date;
v_fecha_deb date;
v_rowid varchar2(1000);
v_conciliado varchar2(1):='N';
v_acu_monto number(18,2):=0;

cursor c_rubros_ini is
  select sum(nvl(c.monto,0)) monto, c.cod_rubro,c.nro_cuenta, c.fecha
  from   cb_cor_rub_det c
  where c.mov_cuadre is null
  and   c.tip_mov    =  v_mov_inicial
  and   c.cod_rubro  =  v_cod_rubro
  and   c.nro_cuenta is not null
  group by c.cod_rubro,c.nro_cuenta, c.fecha
  order by c.cod_rubro,c.nro_cuenta,c.fecha desc;

cursor c_rubros_cre is
  --Sumatoria de Créditos por Fecha
  select sum(nvl(c.monto,0)) monto, c.fecha
   from   cb_cor_rub_det c
     where c.mov_cuadre is null
        and   c.tip_mov    =  v_mov_final
        and   c.cod_rubro  =  v_cod_rubro
        and   c.nro_cuenta is not null
        and c.nro_cuenta=v_nro_cuenta
        and c.fecha<= v_fecha_deb
     group by c.fecha
     order by c.fecha desc;

cursor c_rubros_cre_fec is
  --Créditos por Fecha
  select nvl(c.monto,0) monto, c.fecha
   from   cb_cor_rub_det c
     where c.mov_cuadre is null
        and   c.tip_mov    =  v_mov_final
        and   c.cod_rubro  =  v_cod_rubro
        and   c.nro_cuenta is not null
        and c.nro_cuenta=v_nro_cuenta
        and c.fecha<= v_fecha_deb
    order by c.fecha desc;

cursor c_rubros_res is
  select sum(nvl(c.monto,0)) monto,c.nro_cuenta
  from   cb_cor_rub_det c
  where c.mov_cuadre is null
  and   c.tip_mov    =  v_mov_inicial
  and   c.cod_rubro  =  v_cod_rubro
  and   c.nro_cuenta is not null
  group by c.nro_cuenta
  order by c.nro_cuenta;

cursor c_rubros_cta is
  --Sumatoria de Créditos por cuenta
  select sum(nvl(c.monto,0)) monto, c.nro_cuenta
   from   cb_cor_rub_det c
     where c.mov_cuadre is null
        and   c.tip_mov    =  v_mov_final
        and   c.cod_rubro  =  v_cod_rubro
        and   c.nro_cuenta is not null
        and c.nro_cuenta=v_nro_cuenta
     group by  c.nro_cuenta
     order by c.nro_cuenta desc;

BEGIN

 for reg in c_rubros_ini loop
   begin
     /*Buscamos si tiene su misma contrapartida */
     begin
       select max(c.fecha), C.ROWID,c.monto
        into v_fecha_cre,v_rowid,v_tot_credito
        from   cb_cor_rub_det c
         where c.tip_mov    =  v_mov_final
            and c.cod_rubro  =  v_cod_rubro
            and c.mov_cuadre is null
            and c.nro_cuenta= reg.nro_cuenta
            and c.fecha <= reg.fecha
            and c.monto= reg.monto
            GROUP BY C.ROWID,c.monto;
     exception
        when no_data_found then
            v_tot_credito:=0;
         when too_many_rows then
            --Significa que hay mas de un registro para esa cuenta, ese dia
              select max(c.fecha), C.ROWID,c.monto
                into v_fecha_cre,v_rowid,v_tot_credito
                from   cb_cor_rub_det c
                 where c.tip_mov    =  v_mov_final
                    and c.cod_rubro  =  v_cod_rubro
                    and c.mov_cuadre is null
                    and c.nro_cuenta= reg.nro_cuenta
                    and c.fecha <= reg.fecha
                    and c.monto= reg.monto
                    and rownum=1
                    GROUP BY C.ROWID,c.monto;
        when others then
            v_tot_credito:=0;
     end;
   --Si el monto es el mismo, se guarda el cuadre
   if nvl(v_tot_credito,0) = nvl(reg.monto,0) then
            -- marcar como conciliado el débito
        update   cb_cor_rub_det crd
        set      mov_cuadre = v_cuadre
        where    crd.tip_mov     =  v_mov_inicial
        and      crd.cod_rubro     =  v_cod_rubro
        and      crd.nro_cuenta    =  reg.nro_cuenta
        and      crd.fecha         = reg.fecha
        and      crd.mov_cuadre     is null;
        -- marcar como conciliado el crédito
        update   cb_cor_rub_det crd
          set      mov_cuadre      = v_cuadre
          where    crd.rowid     = v_rowid;
        v_cuadre := v_cuadre + 1;
   else
     --Entra cuando es parcelado
     v_nro_cuenta:=null;
     v_fecha_deb:= null;
     v_nro_cuenta:=reg.nro_cuenta;
     v_fecha_deb:= reg.fecha;
     v_conciliado:='N';
     v_acu_monto:=0;
     for reg1 in c_rubros_cre loop
        if nvl(reg1.monto,0)= nvl(reg.monto,0) and nvl(v_conciliado,'N')='N' then
              --Si el monto es igual para una determinada Fecha
              --Para Debito
              update   cb_cor_rub_det crd
              set      mov_cuadre = v_cuadre
              where    crd.tip_mov     =  v_mov_inicial
              and      crd.cod_rubro     =  v_cod_rubro
              and      crd.nro_cuenta    =  reg.nro_cuenta
              and      crd.fecha         = reg.fecha
              and      crd.mov_cuadre     is null;
              -- marcar como conciliado el crédito
              update   cb_cor_rub_det crd
              set      mov_cuadre      = v_cuadre
              where    crd.tip_mov     = v_mov_final
              and      crd.cod_rubro   =  v_cod_rubro
              and      crd.nro_cuenta  =  v_nro_cuenta
              and      crd.fecha = reg1.fecha
              and      crd.mov_cuadre   is null;
              v_cuadre := v_cuadre + 1;
              v_conciliado:='S';
          end if;
     end loop;
   end if;

   exception
         when no_data_found then null;
         when too_many_rows then null;
   end;
 end loop;

  --Para cuando es por Cta- Ultimo cruce
 v_acu_monto:=0;
 v_nro_cuenta:=null;
 for reg3 in c_rubros_res loop
    v_nro_cuenta:=null;
    v_nro_cuenta:=reg3.nro_cuenta;
    begin
     for reg2 in c_rubros_cta loop
       if  nvl(reg2.monto,0) = nvl(reg3.monto,0)  then
                    --Para Debito por Cta
                    update   cb_cor_rub_det crd
                    set      mov_cuadre = v_cuadre
                    where    crd.tip_mov     =  v_mov_inicial
                    and      crd.cod_rubro     =  v_cod_rubro
                    and      crd.nro_cuenta    =  reg3.nro_cuenta
                    and      crd.mov_cuadre     is null;
                    -- marcar como conciliado el crédito por Cta
                    update   cb_cor_rub_det crd
                    set      mov_cuadre      = v_cuadre
                    where    crd.tip_mov     = v_mov_final
                    and      crd.cod_rubro   =  v_cod_rubro
                    and      crd.nro_cuenta  =  v_nro_cuenta
                    and      crd.mov_cuadre   is null;
                    v_cuadre := v_cuadre + 1;
         end if;
      end loop;
     exception
         when no_data_found then null;
         when too_many_rows then null;
     end;

 end loop;

EXCEPTION
  WHEN OTHERS THEN
       RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_RUB_TAR_CTA: '||sqlerrm);
END;
-- FIN PR_CON_CTA_OPER

PROCEDURE PR_CON_BASICO_ATM
(v_cod_rubro varchar2,
v_mov_inicial char,
v_mov_final char
)
 is
  v_monto         cb_cor_rub_det.monto%type;
  v_nro_documento cb_cor_rub_det.nro_documento%type;
  v_cod_oficina   cb_cor_rub_det.cod_oficina%type;
  v_cantidad      number:=0;
  v_cont          number :=0;
  v_fec_ini       date;
  v_fec_fin       date;


---cursor
/*   se crea un cursor, para recorrer fila por fila
  las coincidencias  encontradas en cb_cor_rub_det
  donde el rubro sea v_rubro y v_movimiento inicial (ambos pasados cómo parámetro)
*/
cursor c_cua_basico is

  select (nvl(t.monto,0)) monto, nvl(t.nro_documento,'0') nro_documento, t.fecha, t.fec_valor
  from   cb_cor_rub_det t
  where  t.mov_cuadre is null
  and    t.tip_mov=v_mov_inicial
  and    t.cod_rubro=v_cod_rubro;

   --- Cuadro directo por monto, fecha
   BEGIN
   for reg in c_cua_basico loop
      --- Buscar movimiento que le corresponda
      begin
         --v_fec_ini := to_timestamp(to_char(reg.fecha-2,'ddmmyyyy')||'14:59:59','ddmmyyyy HH24:mi:ss');
         --v_fec_fin := to_timestamp(to_char(v_fec_ini-1,'ddmmyyyy')||'15:00:00','ddmmyyyy HH24:mi:ss');
         select (nvl(x.monto,0)), nvl(x.nro_documento,'0'), x.cod_oficina
         into   v_monto,v_nro_documento, v_cod_oficina
         from   cb_cor_rub_det x
         where  tip_mov        = v_mov_final
         and    cod_rubro      = v_cod_rubro
         and    nro_documento  = reg.nro_documento
         and    monto          = reg.monto
         and    mov_cuadre is null
         and    hora       is not null
         and     to_timestamp(to_char(fecha,'dd/mm/yyyy') || hora, 'dd/mm/yyyy HH24:mi:ss')
         --between v_fec_ini and v_fec_fin;
         between to_timestamp(to_char(pag_cal.FU_OBT_FEC_ANT_HAB(reg.fecha,7,3),'dd/mm/yyyy') || '15:00:00', 'dd/mm/yyyy HH24:mi:ss')
         and     to_timestamp(to_char(reg.fecha,'dd/mm/yyyy') || '14:59:59', 'dd/mm/yyyy HH24:mi:ss');

      --- Si existe movimiento, actualizar mov_cuadre
      select count(1) into v_cantidad
      from  cb_cor_rub_det d
      where d.tip_mov      =v_mov_final
      and   d.monto        =v_monto
      and   d.nro_documento  =reg.nro_documento;

      if v_cantidad =1 then

        update cb_cor_rub_det
        set    mov_cuadre   = v_cuadre
        where  monto        = v_monto
        and    tip_mov      = v_mov_final
        and    cod_rubro    = v_cod_rubro
        and    nro_documento= v_nro_documento
        and    mov_cuadre is null;


        --- Actualizar mov_cuadre del debito
        update cb_cor_rub_det
        set    mov_cuadre =       v_cuadre
        where  abs(monto)=        v_monto
        and    tip_mov=           v_mov_inicial
        and    cod_rubro=         v_cod_rubro
        and    nro_documento=     v_nro_documento
        and    mov_cuadre is null;

        v_cuadre := v_cuadre + 1;
      end if;
      exception
        when no_data_found then null;
        when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_BASICO_ATM: '||sqlerrm);
END;
-- fin PR_CON_BASICO_ATM

PROCEDURE PR_CON_CONCEPTO_ATM
(v_cod_rubro varchar2,
v_mov_inicial char,
v_mov_final char
)
 is
  v_monto         cb_cor_rub_det.monto%type;
  v_nro_documento cb_cor_rub_det.nro_documento%type;
  v_cod_oficina   cb_cor_rub_det.cod_oficina%type;
  v_cantidad      number:=0;
  v_fec_ini       date;
  v_fec_fin       date;

---cursor
cursor c_cua_basico is
 -- select abs(nvl(t.monto,0)) monto, t.concepto, t.cod_oficina, t.fecha
  select abs(nvl(t.monto,0)) monto, t.concepto, t.fecha, t.fec_valor
  from   cb_cor_rub_det t
  where  t.mov_cuadre is null
  and    t.tip_mov=v_mov_inicial
  and    t.cod_rubro=v_cod_rubro
  and    t.concepto is not null;


   --- Cuadro directo por nro_documento, monto, fecha
   BEGIN
   for reg in c_cua_basico loop
      --- Buscar movimiento que le corresponda
      begin
        -- v_fec_ini := to_timestamp(to_char(reg.fecha-2,'ddmmyyyy')||'14:59:59','ddmmyyyy HH24:mi:ss');
       --  v_fec_fin := to_timestamp(to_char(v_fec_ini-1,'ddmmyyyy')||'15:00:00','ddmmyyyy HH24:mi:ss');
         select abs(nvl(x.monto,0)), x.nro_documento, x.cod_oficina
           into v_monto,v_nro_documento, v_cod_oficina
           from cb_cor_rub_det x
          where x.tip_mov=v_mov_final
            and abs(monto)= reg.monto
            and x.mov_cuadre is null
            and x.cod_rubro=v_cod_rubro
            and x.concepto=reg.concepto
            --and x.cod_oficina=reg.cod_oficina
            and hora is not null
            and to_timestamp(to_char(fecha,'dd/mm/yyyy') || hora, 'dd/mm/yyyy HH24:mi:ss')
           --between v_fec_ini and v_fec_fin;
           between to_timestamp(to_char(pag_cal.FU_OBT_FEC_ANT_HAB(reg.fecha,7,3),'dd/mm/yyyy') || '15:00:00', 'dd/mm/yyyy HH24:mi:ss')
           and to_timestamp(to_char(reg.fecha,'dd/mm/yyyy') || '14:59:59', 'dd/mm/yyyy HH24:mi:ss');

      select count(1) into v_cantidad
       from  cb_cor_rub_det d
       where d.tip_mov=v_mov_final
       and   d.monto=v_monto
       and d.concepto=reg.concepto;
       --and d.cod_oficina=reg.cod_oficina;
      --- Si existe movimiento, actualizar mov_cuadre
      if v_cantidad =1 then
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where monto = v_monto
         and tip_mov=v_mov_final
         and cod_rubro=v_cod_rubro
         and concepto=reg.concepto
         --and cod_oficina=v_cod_oficina
         and mov_cuadre is null;
      --- Actualizar mov_cuadre del debito
      update cb_cor_rub_det
         set mov_cuadre = v_cuadre
       where monto=v_monto
         and tip_mov=v_mov_inicial
         and cod_rubro=v_cod_rubro
         and concepto=reg.concepto
        -- and cod_oficina=v_cod_oficina
         and mov_cuadre is null;
      v_cuadre := v_cuadre + 1;
      end if;
      exception
         when no_data_found then null;
         when too_many_rows then null;
      end;
   end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_CONCEPTO_ATM: '||sqlerrm);
END;
-- Fin PR_CON_CONCEPTO_ATM

PROCEDURE PR_CON_TOTALES_ATM
(v_cod_rubro varchar2,
v_mov_inicial char,
v_mov_final char)
is
       v_fec_ini timestamp;
       v_fec_fin timestamp;
       v_monto      cb_cor_rub_det.monto%type;

       cursor c_mov_inicial is
       SELECT   c.fecha,c.hora, c.tip_mov, nvl(monto,0) monto, nro_documento, concepto
       FROM     cb_cor_rub_det c
       WHERE    cod_rubro = v_cod_rubro
       AND      tip_mov   = v_mov_inicial
       AND      mov_cuadre is null;


BEGIN
       for reg in c_mov_inicial loop
          --calcular la fecha inicial y final del rango de busqueda.
          v_fec_fin:= to_timestamp(to_char(pag_cal.FU_OBT_FEC_HABIL(reg.fecha-2,-2,7),'ddmmyyyy')||'14:59:59','ddmmyyyy HH24:mi:ss');
          v_fec_ini := to_timestamp(to_char(pag_cal.FU_OBT_FEC_HABIL(v_fec_fin-1,-1,7),'ddmmyyyy')||'15:00:00','ddmmyyyy HH24:mi:ss');

           begin
              SELECT  sum(nvl(monto,0)) monto
              INTO    v_monto
              FROM    cb_cor_rub_det cb
              WHERE   cb.cod_rubro = v_cod_rubro
              AND     cb.tip_mov   = v_mov_final
              AND     to_timestamp(to_char(cb.fec_valor,'ddmmyyyy')||cb.hora,'ddmmyyyy HH24:mi:ss')
              BETWEEN v_fec_ini and v_fec_fin
              AND     cb.mov_cuadre is null;
              EXCEPTION
                  when others then
                  v_monto:=0;
           end;

           if reg.monto = v_monto then
             begin
                update cb_cor_rub_det
                set    mov_cuadre    = v_cuadre
                where  cod_rubro     = v_cod_rubro
                and    tip_mov       = v_mov_inicial
                and    monto         = reg.monto
                and    fecha         = reg.fecha
               --and    nro_documento = reg.nro_documento
                and    mov_cuadre is null;

                update  cb_cor_rub_det cb
                set     mov_cuadre    = v_cuadre
                where   cod_rubro     = v_cod_rubro
                and     tip_mov       = v_mov_final
                and     to_timestamp(to_char(cb.fec_valor,'ddmmyyyy')||cb.hora,'ddmmyyyy HH24:mi:ss')
                between v_fec_ini and v_fec_fin
                and     mov_cuadre is null;
                v_cuadre := v_cuadre + 1;
              exception
               when no_data_found then null;
                   when too_many_rows then null;
              end;
          end if;

       end loop;
EXCEPTION
    WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20000,'ERROR EN PR_CON_TOTALES_ATM: '||sqlerrm);
END;
end PAB_COR;
/

