CREATE OR REPLACE PROCEDURE IT.PRB_INS_DAT_ESP_CONTABLES is
  --DESOPIMI-66 PRB_INF_DIA_CIDESA informe diario CIDESA--
  --Realiza copia de datos luego del cierre contable, asientos y saldos diarios--
  vg_fec_actual             date;
  vg_fec_contable           date;
  vg_lugar                  varchar2(200);
  vg_hor_inicio             varchar2(8);
  vg_hor_fin                varchar2(8);
  vg_cod_programa           ge_log_procesos.cod_programa%type;
  vg_can_dia_reg_tablas     number;
  
  PROCEDURE LP_CAR_VAR_PROCESO IS
  BEGIN
    vg_lugar   := 'LP_CAR_VAR_PROCESO';
    vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
    vg_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
    vg_fec_contable := pag_cal.FU_OBT_FEC_ACTUAL(2);
    vg_can_dia_reg_tablas := to_number(nvl(fug_obt_pardinamico('CAN_DIA_REG_CON_ESP'),2)); -- se deja 2 dias por default
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_CAR_VAR_PROCESO-'||sqlerrm);
  END LP_CAR_VAR_PROCESO;

  PROCEDURE LP_ELI_TAB_REG_DIARIO IS
  begin
    vg_lugar   := 'LP_ELI_TAB_REG_DIARIO';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    delete from GE_CON_ESP_CIDESA x
     where x.fecha = vg_fec_contable
       and x.ref_origen in ('ASIENTOS', 'ASIENTOS_DET', 'SAL_OFICINAS');
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_ELI_TAB_REG_DIARIO-'||sqlerrm);
  END LP_ELI_TAB_REG_DIARIO;

  PROCEDURE LP_ELI_TAB_MANTENIMIENTO IS
  begin
    vg_lugar   := 'LP_ELI_TAB_MANTENIMIENTO';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    delete from GE_CON_ESP_CIDESA where fecha <= (vg_fec_contable-vg_can_dia_reg_tablas);
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_ELI_TAB_MANTENIMIENTO-'||sqlerrm);
  END LP_ELI_TAB_MANTENIMIENTO;
  
  PROCEDURE LP_INS_TAB_SAL_OFICINAS IS
  BEGIN
    vg_lugar   := 'LP_INS_TAB_SAL_OFICINAS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (cod_oficina, cod_rubro, fecha, sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_ini_mes_mon_local,
            sal_mon_rub_ant, deb_mon_rubro, cre_mon_rubro, sal_ini_mes_mon_rubro,
            sal_ini_mes_mon_fuerte, protegido, sal_equ_loc_ant, deb_equ_local,
            cre_equ_local, sal_ini_mes_equ_local, fec_insercion, usu_insercion, 
            fec_modificacion, usu_modificacion, ref_origen)
    SELECT a.cod_oficina,a.cod_rubro,vg_fec_contable,
      a.sal_mon_loc_ant, a.deb_mon_local, a.cre_mon_local, a.sal_ini_mes_mon_local,
      a.sal_mon_rub_ant, a.deb_mon_rubro, a.cre_mon_rubro, a.sal_ini_mes_mon_rubro,
      a.sal_ini_mes_mon_fuerte, a.protegido, a.sal_equ_loc_ant, a.deb_equ_local,
      a.cre_equ_local, a.sal_ini_mes_equ_local, a.fec_insercion, a.usu_insercion, 
      a.fec_modificacion, a.usu_modificacion, 'SAL_OFICINAS'
    from GE_CON_ESP_CIDESA t
       join CB_SAL_OFICINAS a on t.cod_rubro = a.cod_rubro
         and a.ANO = TO_CHAR(vg_fec_contable,'YYYY')
         and a.MES = TO_CHAR(vg_fec_contable,'MM')
     where t.fecha = vg_fec_contable
       and ref_origen = 'RUBROS_TMP';
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_SAL_OFICINAS-'||sqlerrm);
  END LP_INS_TAB_SAL_OFICINAS;
  
  PROCEDURE LP_INS_TAB_ASIENTOS_DET IS
  BEGIN
    -- 
    vg_lugar   := 'LP_INS_TAB_ASIENTOS 1';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (FECHA , COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO, TIP_MOVIMIENTO,
     MTO_MON_RUBRO, MTO_MON_LOCAL, DESCRIPCION, REFERENCIA,
     PROTEGIDO, ACTUALIZADO, VAL_COTIZACION, DISTRIBUIDO,
     REF_MOVIMIENTO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION,
     FEC_MODIFICACION, FEC_VALOR, REF_ORIGEN)
    select c.FECHA,c.COD_OFICINA,c.NRO_ASIENTO,c.NRO_LINEA,c.COD_RUBRO,c.TIP_MOVIMIENTO,
    c.MTO_MON_RUBRO,c.MTO_MON_LOCAL,c.DESCRIPCION,c.REFERENCIA,c.PROTEGIDO,c.ACTUALIZADO,c.VAL_COTIZACION,
    c.DISTRIBUIDO,c.REF_MOVIMIENTO,c.USU_INSERCION,c.FEC_INSERCION,c.USU_MODIFICACION,c.FEC_MODIFICACION,
    c.FEC_VALOR, 'ASIENTOS_DET'      
    from GE_CON_ESP_CIDESA cc, CB_ASIENTOS_DET c
    where cc.fecha = vg_fec_contable
      and cc.ref_origen = 'RUBROS_TMP'
      and cc.cod_rubro = c.cod_rubro
      and c.fecha = cc.fecha
      and cc.tipo = 'N'
      and c.cod_rubro IN ('111201051001199','111201051801105','111201051801117');
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
    --
    vg_lugar   := 'LP_INS_TAB_ASIENTOS 2';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (FECHA , COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO, TIP_MOVIMIENTO,
     MTO_MON_RUBRO, MTO_MON_LOCAL, DESCRIPCION, REFERENCIA,
     PROTEGIDO, ACTUALIZADO, VAL_COTIZACION, DISTRIBUIDO,
     REF_MOVIMIENTO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION,
     FEC_MODIFICACION, FEC_VALOR, REF_ORIGEN)
    select c.FECHA,c.COD_OFICINA,c.NRO_ASIENTO,c.NRO_LINEA,c.COD_RUBRO,c.TIP_MOVIMIENTO,
    c.MTO_MON_RUBRO,c.MTO_MON_LOCAL,c.DESCRIPCION,c.REFERENCIA,c.PROTEGIDO,c.ACTUALIZADO,c.VAL_COTIZACION,
    c.DISTRIBUIDO,c.REF_MOVIMIENTO,c.USU_INSERCION,c.FEC_INSERCION,c.USU_MODIFICACION,c.FEC_MODIFICACION,
    c.FEC_VALOR, 'ASIENTOS_DET'
    from GE_CON_ESP_CIDESA cc, CB_ASIENTOS_DET c
    where c.fecha = vg_fec_contable
    and cc.ref_origen = 'RUBROS_TMP'
    and cc.cod_rubro=c.cod_rubro
    and cc.cod_bco_central not in(1007,1001)
    and cc.tipo IN ('N','S')
    and cc.fecha = c.fecha;      
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);  
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_ASIENTOS_DET-'||sqlerrm);
  END LP_INS_TAB_ASIENTOS_DET;

  PROCEDURE LP_INS_TAB_ASIENTOS IS
  BEGIN
    vg_lugar   := 'LP_INS_TAB_ASIENTOS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into GE_CON_ESP_CIDESA
    (FECHA,COD_OFICINA,NRO_ASIENTO,COD_USUARIO,COD_MODULO,COD_MODALIDAD,
    TOT_CONTROL,ACTUALIZADO,REVERSADO,OFI_INTEGRADA,CONFIRMADO,COD_OFI_ORIGEN,
    USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,FEC_VALOR, REF_ORIGEN)
    select distinct a.FECHA, a.COD_OFICINA, a.NRO_ASIENTO, a.COD_USUARIO, a.COD_MODULO, a.COD_MODALIDAD,
    a.TOT_CONTROL,a.ACTUALIZADO,a.REVERSADO,a.OFI_INTEGRADA,a.CONFIRMADO,a.COD_OFI_ORIGEN,
    a.USU_INSERCION,a.FEC_INSERCION,a.USU_MODIFICACION,a.FEC_MODIFICACION,a.FEC_VALOR, 'ASIENTOS'
    from CB_ASIENTOS a, CB_ASIENTOS_DET b
    where a.fecha = b.fecha
      and a.nro_asiento = b.nro_asiento
      and a.cod_oficina = b.cod_oficina
      and b.cod_rubro IN ('111201090400699','111201090450099','211101020400699','211101020414499')
      and a.fecha = vg_fec_contable;   
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_INS_TAB_ASIENTOS-'||sqlerrm);
  END LP_INS_TAB_ASIENTOS;
  
begin
  vg_cod_programa := 'PRB_INS_DAT_ESP_CONTABLES';
  
  --Carga Variables del Proceso--
  LP_CAR_VAR_PROCESO;
  
  --Elimina registros antiguos--
  LP_ELI_TAB_MANTENIMIENTO;
  
  --Eliminar Tablas Temporales--
  LP_ELI_TAB_REG_DIARIO;
  
  --Insertar Tabla saldos diarios--
  LP_INS_TAB_SAL_OFICINAS;
  
  --Insertar Tabla de Detalle de Asientos--
  LP_INS_TAB_ASIENTOS_DET;
  
  --Insertar Tabla de Asientos--
  LP_INS_TAB_ASIENTOS;
    
end PRB_INS_DAT_ESP_CONTABLES;
/

