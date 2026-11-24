CREATE OR REPLACE PROCEDURE IT.PRB_INF_ESP_CIDESA is
  --DESOPIMI-66 basado en PRB_INF_DIA_CIDESA--
  vg_cod_mon_local      ba_monedas.cod_moneda%type;
  vg_fec_contable       date;
  vg_fec_con_anterior   date;
  vg_fec_actual         date;
  vg_lugar              varchar2(200);
  vg_hor_inicio         varchar2(8);
  vg_hor_fin            varchar2(8);
  vg_cod_programa       ge_log_procesos.cod_programa%type; 
  vg_tra_regitros      varchar2(1);
  vg_bas_datos         varchar2(50);
  vg_usu_base          ba_usuarios.cod_usuario%type;
  
  --Carca Inicial de Variables del Proceso--
  PROCEDURE LP_CAR_VAR_PROCESO IS
  BEGIN
    vg_lugar   := 'LP_CAR_VAR_PROCESO';
    vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');    
    vg_tra_regitros := nvl(fug_obt_pardinamico('IND_ACT_INS_INF_CIDESA'),'N');
    vg_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
    vg_fec_actual := pag_cal.fu_obt_fec_actual(1);  
    --Busca la fecha actual del balance cerrado--
    select max(fecha) into vg_fec_contable from GE_CON_ESP_CIDESA d where d.ref_origen = 'SAL_OFICINAS';
    select pag_cal.FU_OBT_FEC_ANT_HAB (vg_fec_contable,31,1) into vg_fec_con_anterior from dual;
    vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
    prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  exception
    when others then
         raise_application_error(-20000,'Error en LP_CAR_VAR_PROCESO-'||sqlerrm);
  END LP_CAR_VAR_PROCESO;
  
  --Trunca tabla definitiva CC_SOBREGIROS_RES--
  PROCEDURE LP_TRU_TAB_INFORME is
     v_msj     VARCHAR2(200);
  BEGIN
     vg_lugar   := 'Trunca tabla definitiva';
     vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
     sql_util.ejecute_dml('TRUNCATE TABLE CB_INF_CID_TMP', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
     END IF;
    vg_hor_fin := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  END LP_TRU_TAB_INFORME;
  
  --Transfiere a tablas reales registros generados--
  PROCEDURE LP_INS_INF_GENERADO is 
  BEGIN
    vg_lugar := 'Inserta en CB_INF_CID_TMP';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    insert into CB_INF_CID_TMP
    (select CIDESA,COD_BCO_CENTRAL,COD_MONEDA,COD_MODALIDAD,TIPO,FRECUENCIA,FECHA from CB_INF_CID_AUX_TMP);
    vg_hor_fin := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  END LP_INS_INF_GENERADO;
  
  --Verificar Base y Usuario--
  PROCEDURE LP_VER_USU_BAS_DATOS IS
  V_BAS_PROD GE_PAR_DINAMICOS.VAL_PARAMETRO%TYPE;
  BEGIN
    vg_lugar := 'LP_VER_USU_BAS_DATOS';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    v_bas_prod := fug_obt_pardinamico('BD_PROD');
    SELECT upper(sys_context('USERENV', 'DB_NAME'))
      INTO vg_bas_datos
      FROM dual;
    IF vg_bas_datos = V_BAS_PROD then
       vg_usu_base := 'IT';
    else
       vg_usu_base := 'DYDTEST';
    end if;
    vg_hor_fin := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  EXCEPTION
      WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR(-20001, 'Error en LP_VER_USU_BAS_DATOS - '||sqlerrm);
  END LP_VER_USU_BAS_DATOS;
  
  --Calcular Estadisticas de la Tabla--
  procedure LP_GEN_EST_TABLAS(p_tabla in varchar2) is
  begin
      BEGIN dbms_stats.gather_table_stats(vg_usu_base,p_tabla); END;
  end LP_GEN_EST_TABLAS;
  
  --Prepara tablas temporales--
  procedure LP_PRE_TAB_TEMPORALES is
  begin
    vg_lugar := 'LP_PRE_TAB_TEMPORALES';
    vg_hor_inicio := TO_CHAR(SYSDATE,'HH24:MI:SS');
    --trunca tabla temporal del informe--
    execute immediate 'truncate table CB_INF_CID_AUX_TMP';
    --carga tablas temporales con datos a procesar--
    execute immediate 'truncate table GE_CON_ESP_CIDESA_TMP';
    --corre estadisticas de la tabla Origen--
    LP_GEN_EST_TABLAS('GE_CON_ESP_CIDESA');
    --inserta todos los datos del día--
    insert into GE_CON_ESP_CIDESA_TMP select * from GE_CON_ESP_CIDESA where fecha = vg_fec_contable;
    --inserta saldos de ayer--
    insert into GE_CON_ESP_CIDESA_TMP select * from GE_CON_ESP_CIDESA where fecha = vg_fec_con_anterior and ref_origen = 'SAL_OFICINAS';
    --corre estadisticas de la tabla TMP--
    LP_GEN_EST_TABLAS('GE_CON_ESP_CIDESA_TMP');
    vg_hor_fin := TO_CHAR(SYSDATE,'HH24:MI:SS');
    PRG_ACT_LOG_PROCESOS(vg_cod_programa, vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_PRE_TAB_TEMPORALES;
  --Inserta datos tipo 1--
  procedure LP_GEN_DAT_TIP_1 is
   begin
      vg_lugar   := 'Consulta tipo 1';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      --tipo 1 
      -- Se reemplaza ge_bancos por gv_ent_cidesa, se quita el filtro de banco activo que ya está incluído en la vista 
      -- y se considera que cc_cta_bancarias esté relacionado a un cod_banco o cod_ente --CN 11/08/2014-- SNP-82 
      insert into CB_INF_CID_AUX_TMP
      select 'I'||','||'1007'||','||lpad(t.cod_bco_central,4,0)
      ||','||
      lpad(decode(nvl(t.saldo_ant,0),0,'+',decode(abs(t.saldo_ant),t.saldo_ant,'-','+'))
      ||
      TRUNC(nvl(abs(t.saldo_ant),0)),13,CHR(32))||'.'||
      substr(rpad(nvl(abs(t.saldo_ant),0) - trunc(nvl(abs(t.saldo_ant),0)),3,0),-2)
      ||','||
      lpad(decode(nvl(t.saldo_act,0),0,'+', decode(abs(t.saldo_act),t.saldo_act,'-','+'))
      ||
      TRUNC(nvl(abs(t.saldo_act),0)),13,CHR(32))
      ||'.'||
      substr(rpad(nvl(abs(t.saldo_act),0) - trunc(nvl(abs(t.saldo_act),0)),3,0),-2)
      ||','|| to_char(vg_fec_contable,'ddmmyyyy')
      ||','|| to_char(vg_fec_contable,'ddmmyyyy')
      ||','||decode(t.cod_moneda,'GS','6900','USD','6100','EUR','6300')
       cidesa, t.cod_bco_central,t.cod_moneda,t.cod_modalidad,'I','D',vg_fec_contable,
       'TIPO 1' 
      from (
           select cc.cod_banco, cc.nro_cuenta, cc.cod_moneda, cc.cod_modalidad,cc.cod_bco_central,                              
             sum(decode(ss.fecha, vg_fec_contable, 
             decode(cc.cod_moneda, 'GS', sal_mon_loc,sal_mon_rub ), 0) ) saldo_act,            
             sum(decode(ss.fecha, vg_fec_con_anterior,
             decode(cc.cod_moneda, 'GS', sal_mon_loc,sal_mon_rub ), 0) ) saldo_ant
             from GE_CON_ESP_CIDESA_TMP cc
             left join (select s.fecha, s.cod_rubro, 
                              sum(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) sal_mon_loc,
                              sum(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) sal_mon_rub
                          from GE_CON_ESP_CIDESA_TMP s
                          where s.fecha IN (vg_fec_con_anterior,vg_fec_contable)
                          and s.ref_origen = 'SAL_OFICINAS'
                          group by s.fecha, s.cod_rubro) ss on ss.cod_rubro IN (cc.cod_rubro,cc.cod_rub_sobregiro)
             where cc.cod_bco_central is not null
               and cc.cod_bco_central not in (1007,1001)
               and cc.ref_origen = 'CTA_BAN_TMP'
               and cc.fecha = vg_fec_contable
             group by cc.cod_banco, cc.nro_cuenta, cc.cod_moneda, cc.cod_modalidad,cc.cod_bco_central
             ) t;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_1;
  --Inserta datos Cabecera SIPAP--
  procedure LP_GEN_DAT_CABECERA_SIPAP is
   begin
      vg_lugar   := 'Consulta Cabecera SIPAP';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      --Cabecera SIPAP
      insert into CB_INF_CID_AUX_TMP
      select distinct 'I'||','||'1007'||','||lpad(7,4,0)
      ||','||
      lpad(decode(nvl(t.saldo_ant,0),0,'+',decode(abs(t.saldo_ant),t.saldo_ant,'-','+'))
      ||
      TRUNC(nvl(abs(t.saldo_ant),0)),13,CHR(32))||'.'||
      substr(rpad(nvl(abs(t.saldo_ant),0) - trunc(nvl(abs(t.saldo_ant),0)),3,0),-2)
      ||','||
      lpad(decode(nvl(t.saldo_act,0),0,'+', decode(abs(t.saldo_act),t.saldo_act,'-','+'))
      ||
      TRUNC(nvl(abs(t.saldo_act),0)),13,CHR(32))
      ||'.'||
      substr(rpad(nvl(abs(t.saldo_act),0) - trunc(nvl(abs(t.saldo_act),0)),3,0),-2)
      ||','|| to_char(vg_fec_contable,'ddmmyyyy')
      ||','|| to_char(vg_fec_contable,'ddmmyyyy')
      ||','||decode(t.cod_moneda,'GS','6900','USD','6100','EUR','6300')
      cidesa, 7 cod_bco_central,t.cod_moneda,t.cod_modalidad,'I','D',vg_fec_contable,
      'CABECERA SIPAP'
      from ( select cc.cod_banco, cc.nro_cuenta, cc.cod_moneda, cc.cod_modalidad,cc.cod_bco_central,                              
           sum(decode(ss.fecha,vg_fec_contable, 
           decode(cc.cod_moneda, 'GS', sal_mon_loc,sal_mon_rub ), 0) ) saldo_act,            
           sum(decode(ss.fecha, vg_fec_con_anterior,
           decode(cc.cod_moneda, 'GS', sal_mon_loc,sal_mon_rub ), 0) ) saldo_ant
           from GE_CON_ESP_CIDESA_TMP cc
           left join (select s.fecha, s.cod_rubro, 
                            sum(nvl(s.sal_mon_loc_ant,0)+nvl(s.deb_mon_local,0)-nvl(s.cre_mon_local,0)) sal_mon_loc,
                            sum(nvl(s.sal_mon_rub_ant,0)+nvl(s.deb_mon_rubro,0)-nvl(s.cre_mon_rubro,0)) sal_mon_rub
                        from GE_CON_ESP_CIDESA_TMP s
                        where s.fecha IN (vg_fec_con_anterior, vg_fec_contable)
                        and s.ref_origen = 'SAL_OFICINAS'
                        group by s.fecha, s.cod_rubro) ss on ss.cod_rubro IN (cc.cod_rubro,cc.cod_rub_sobregiro)
           where cc.cod_modalidad=455
           and cc.ref_origen = 'CTA_BAN_TMP'
           and cc.fecha = vg_fec_contable
           group by cc.cod_banco, cc.nro_cuenta, cc.cod_moneda, cc.cod_modalidad,cc.cod_bco_central
      ) t;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_CABECERA_SIPAP;
  --Inserta datos tipo 2 activos--
  procedure LP_GEN_DAT_TIP_2_ACTIVOS is
   begin
      vg_lugar   := 'Consulta tipo 2 A';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      --tipo 2 activos
      -- Se reemplaza ge_bancos por gv_ent_cidesa, se quita el filtro de banco activo que ya está incluído en la vista 
      -- y se considera que cc_cta_bancarias esté relacionado a un cod_banco o cod_ente --CN 11/08/2014-- SNP-82 
      insert into CB_INF_CID_AUX_TMP
      select c.tip_movimiento
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(c.descripcion,CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
      ||'.'
      ||substr(rpad(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
      ,cc.cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,'D',c.fecha,
      'TIPO 2 ACTIVOS'
      from GE_CON_ESP_CIDESA_TMP c,
           GE_CON_ESP_CIDESA_TMP cc,
           GE_CON_ESP_CIDESA_TMP m
        where c.fecha = m.FECHA
          and c.ref_movimiento = m.NRO_DOCUMENTO4
          and cc.cod_rubro = c.cod_rubro
          and cc.cod_bco_central is not null
          and cc.cod_bco_central not in(1007,1001)
          and c.fecha = vg_fec_contable
          and c.ref_origen = 'ASIENTOS_DET'
          and c.fecha = vg_fec_contable
          and cc.ref_origen = 'CTA_BAN_TMP'
          and cc.fecha = vg_fec_contable
          and m.ref_origen = 'MOV_DIARIOS'
          and m.fecha = vg_fec_contable
          and ((m.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
              (m.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
          and c.cod_rubro NOT IN ('111201090400699','111201090450099','211101020400699','211101020414499'); -- N.AN. filtramos rubros CITI
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_ACTIVOS;
  --Inserta datos tipo 2 pasivos--
  procedure LP_GEN_DAT_TIP_2_PASIVOS is
    begin
      vg_lugar   := 'Consulta tipo 2 B';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      ---los pasivos    
      insert into CB_INF_CID_AUX_TMP
      select c.tip_movimiento
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(c.descripcion,CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
      ||'.'
      ||substr(rpad(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
      ,cc.cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,'D',c.fecha,
      'TIPO 2 PASIVOS'
      from GE_CON_ESP_CIDESA_TMP c,
           GE_CON_ESP_CIDESA_TMP cc, 
           GE_CON_ESP_CIDESA_TMP m
        where c.fecha=m.FECHA
          and c.ref_movimiento=m.NRO_DOCUMENTO4
          and c.cod_rubro=cc.cod_rub_sobregiro
          and cc.cod_bco_central is not null
          and cc.cod_bco_central not in(1007,1001)
          and c.fecha = vg_fec_contable
          and c.ref_origen = 'ASIENTOS_DET'
          and c.fecha = vg_fec_contable
          and cc.ref_origen = 'CTA_BAN_TMP'
          and cc.fecha = vg_fec_contable
          and m.ref_origen = 'MOV_DIARIOS'
          and m.fecha = vg_fec_contable
          and ((m.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
              (m.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
          and c.cod_rubro NOT IN ('111201090400699','111201090450099','211101020400699','211101020414499'); -- N.AN. filtramos rubros CITI
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_PASIVOS;
  --Inserta datos tipo rubros CITI--
  procedure LP_GEN_DAT_TIP_2_RUB_CITI is
    begin
      vg_lugar   := 'Consulta tipo 2 C';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      ---rubros CITI
      insert into CB_INF_CID_AUX_TMP
      select g.tip_movimiento
      ||','
      ||to_char(g.fecha,'ddmmyyyy')
      ||','
      ||to_char(g.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(g.descripcion,CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(decode(nvl(g.NRO_DOCUMENTO3,0),0,g.NRO_DOCUMENTO,g.NRO_DOCUMENTO3),0),1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(g.cod_moneda,vg_cod_mon_local,g.mto_mon_local,g.mto_mon_rubro)),13,0)
      ||'.'
      ||substr(rpad(decode(g.cod_moneda,vg_cod_mon_local,g.mto_mon_local,g.mto_mon_rubro)-TRUNC(decode(g.cod_moneda,vg_cod_mon_local,g.mto_mon_local,g.mto_mon_rubro)),3,0),-2)
      ,1006 cod_bco_central,g.cod_moneda,
      decode( cod_rubro,'111201090450099', 47,
      '211101020414499', 47, 42) cod_modalidad,
      g.tip_movimiento,'D',g.fecha,
      'TIPO 2 RUBROS CITI'
      from
      (
        select d.cod_rubro, d.fecha, d.cod_oficina ,c.cod_modalidad, c.cod_modulo,
        d.nro_asiento asiento, d.nro_linea lin, d.ref_movimiento ref, d.descripcion,
        d.tip_movimiento,d.mto_mon_local,d.mto_mon_rubro,c.cod_usuario,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3, d.referencia, r.cod_moneda
        from GE_CON_ESP_CIDESA_TMP d,
             CB_RUBROS r, 
             GE_CON_ESP_CIDESA_TMP c, 
             GE_CON_ESP_CIDESA_TMP m
          where r.cod_rubro=d.cod_rubro
            and c.fecha= d.fecha
            and c.cod_oficina=d.cod_oficina
            and c.nro_asiento=d.nro_asiento
            and d.fecha=m.FECHA(+)
            and d.ref_movimiento=m.NRO_DOCUMENTO4(+)
            and d.cod_rubro IN ('111201090400699','111201090450099','211101020400699','211101020414499')
            and d.fecha = vg_fec_contable
            and d.ref_origen = 'ASIENTOS_DET'
            and d.fecha = vg_fec_contable
            and c.ref_origen = 'ASIENTOS'
            and c.fecha = vg_fec_contable
            and m.ref_origen = 'MOV_DIARIOS'
            and m.fecha = vg_fec_contable
      ) G;
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_RUB_CITI;
  --Inserta datos tipo 2 Sipap A--
  procedure LP_GEN_DAT_TIP_2_SIPAP_A is
    begin
      vg_lugar   := 'Consulta SIPAP A';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      --30/10/2013 se incluye  SIPAP
      insert into CB_INF_CID_AUX_TMP
      select c.tip_movimiento
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(NVL(decode(c.tip_movimiento,'D',TRIM(D.NOM_BENEFICIARIO),trim(d.nom_solicitante)),TRIM(C.DESCRIPCION)),CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
      ||'.'
      ||substr(rpad(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),
      ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
      ,nvl(g.cod_banco,'7') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,'D',c.fecha,
      'SIPAP A'
      from GE_CON_ESP_CIDESA_TMP cc,
           GE_CON_ESP_CIDESA_TMP c, 
           GE_CON_ESP_CIDESA_TMP m, 
           GE_CON_ESP_CIDESA_TMP d,
           GE_BANCOS g
        where c.fecha=m.FECHA
          and (m.reversado = 'N' or (m.reversado = 'S' AND m.fecha = m.fec_valor)) -- DYDMR-6853
          and c.ref_movimiento=m.NRO_DOCUMENTO4
          and cc.cod_rubro=c.cod_rubro
          and m.cod_modalidad=455
          and D.ESTADO <> 'C'               
          and c.fecha= vg_fec_contable
          and ((m.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
          (m.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
          and cc.cod_banco=g.cod_banco(+)
          and m.nro_documento=d.nro_referencia
          and cc.ref_origen = 'CTA_BAN_TMP'
          and cc.fecha = vg_fec_contable
          and c.ref_origen = 'ASIENTOS_DET'
          and c.fecha = vg_fec_contable
          and d.ref_origen = 'SNP_TRANSFERENCIAS'
          and d.fecha = vg_fec_contable
          and m.ref_origen = 'MOV_DIARIOS'
          and m.fecha = vg_fec_contable
          and c.cod_rubro IN ('111201051001199','111201051801105','111201051801117');
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_SIPAP_A;
  --Inserta datos tipo 2 Sipap B--
  procedure LP_GEN_DAT_TIP_2_SIPAP_B is
    begin
      vg_lugar   := 'Consulta SIPAP B';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      insert into CB_INF_CID_AUX_TMP
      select c.tip_movimiento
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(NVL(decode(c.tip_movimiento,'D',TRIM(m.concepto),trim(m.concepto)),TRIM(m.concepto)),CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
      ||'.'
      ||substr(rpad(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),
      ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'GS',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
      ,nvl(g.cod_banco,'7') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,'D',c.fecha,
      'SIPAP B'
      from GE_CON_ESP_CIDESA_TMP cc,
           GE_CON_ESP_CIDESA_TMP c,
           GE_CON_ESP_CIDESA_TMP m,
           GE_BANCOS g
        where c.fecha=m.FECHA
          and c.ref_movimiento=m.NRO_DOCUMENTO4
          and cc.cod_rubro=c.cod_rubro
          and m.cod_modalidad=455
          and c.fecha= vg_fec_contable
          and ((m.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
          (m.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
          and cc.cod_banco=g.cod_banco(+)
          and cc.ref_origen = 'CTA_BAN_TMP'
          and cc.fecha = vg_fec_contable
          and c.ref_origen = 'ASIENTOS_DET'
          and c.fecha = vg_fec_contable
          and m.ref_origen = 'MOV_DIARIOS'
          and m.fecha = vg_fec_contable
          and m.nro_documento not in (select z.nro_referencia 
                                      from GE_CON_ESP_CIDESA_TMP z
                                      where z.nro_referencia = m.nro_documento
                                      and z.ref_origen = 'SNP_TRANSFERENCIAS'
                                      and z.fecha = vg_fec_contable)
          and c.cod_rubro IN ('111201051001199','111201051801105','111201051801117');
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_SIPAP_B;
  --Inserta datos tipo 2 C--
  procedure LP_GEN_DAT_TIP_2_C is
    begin
      vg_lugar   := 'Consulta Tipo 2 C';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      insert into CB_INF_CID_AUX_TMP    
      select c.tip_movimiento
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(trim(c.descripcion),CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(c.nro_asiento,0) ,1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(cc.cod_moneda,'GS',ABS(c.mto_mon_local),ABS(c.mto_mon_rubro))),13,0)
      ||'.'          ||substr(rpad(decode(cc.cod_moneda,'GS',NVL(ABS(c.mto_mon_local),0),NVL(ABS(c.Mto_Mon_Rubro),0))-TRUNC(decode(cc.cod_moneda,'GS',NVL(ABS(c.mto_mon_local),0),NVL(ABS(c.mto_mon_rubro),0))),3,0),-2)
      ,nvl(g.cod_banco,'7') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,'D',c.fecha,
      'TIPO 2 C'
      from GE_CON_ESP_CIDESA_TMP cc,
           GE_CON_ESP_CIDESA_TMP c,
           GE_BANCOS g
        where cc.cod_rubro=c.cod_rubro
          and c.fecha= vg_fec_contable
          and cc.cod_banco=g.cod_banco(+)
          and ((cc.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
          (cc.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
          and c.ref_movimiento is null
          and cc.ref_origen = 'CTA_BAN_TMP'
          and cc.fecha = vg_fec_contable
          and c.ref_origen = 'ASIENTOS_DET'
          and c.fecha = vg_fec_contable
          and c.cod_rubro IN ('111201051001199','111201051801105','111201051801117');
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_C;
  --Inserta datos tipo 2 Reversados--
  procedure LP_GEN_DAT_TIP_2_REVERSADOS is
    begin
      vg_lugar   := 'Consulta Tipo 2 Reversados';
      vg_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      --28/05/2014 se incluyen los mov reversados automáticamente
      insert into CB_INF_CID_AUX_TMP
      select c.tip_movimiento
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||to_char(c.fecha,'ddmmyyyy')
      ||','
      ||lpad(substr(NVL(trim(c.descripcion),CHR(32)),1,20),20,CHR(32))
      ||','
      ||lpad(substr(NVL(c.nro_asiento,0) ,1,15),15,0)
      ||','
      ||lpad(TRUNC(decode(cc.cod_moneda,'GS',ABS(c.mto_mon_local),ABS(c.mto_mon_rubro))),13,0)
      ||'.'          ||substr(rpad(decode(cc.cod_moneda,'GS',NVL(ABS(c.mto_mon_local),0),NVL(ABS(c.Mto_Mon_Rubro),0))-TRUNC(decode(cc.cod_moneda,'GS',NVL(ABS(c.mto_mon_local),0),NVL(ABS(c.mto_mon_rubro),0))),3,0),-2)
      ,nvl(g.cod_banco,'7') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,'D',c.fecha,
      'TIPO 2 REVERSADOS'
      from GE_CON_ESP_CIDESA_TMP cc, 
           GE_CON_ESP_CIDESA_TMP c,
           GE_BANCOS g, 
           GE_CON_ESP_CIDESA_TMP m
        where cc.cod_rubro = c.cod_rubro
          and c.fecha = vg_fec_contable
          and (m.reversado = 'S' AND m.fecha <> m.fec_valor)
          and cc.cod_banco=g.cod_banco(+)
          and ((cc.cod_moneda <> 'GS' and nvl(c.mto_mon_rubro,0) <> 0) or
          (cc.cod_moneda = 'GS' and nvl(c.mto_mon_rubro,0) = 0))
          and m.cod_modalidad=455
          and c.fecha=m.FECHA
          and c.ref_movimiento=m.NRO_DOCUMENTO4
          and cc.ref_origen = 'CTA_BAN_TMP'
          and cc.fecha = vg_fec_contable
          and c.ref_origen = 'ASIENTOS_DET'
          and c.fecha = vg_fec_contable
          and m.ref_origen = 'MOV_DIARIOS'
          and m.fecha = vg_fec_contable
          and c.cod_rubro IN ('111201051001199','111201051801105','111201051801117');
      vg_hor_fin := to_char(sysdate,'hh24:mi:ss');
      prg_act_log_procesos(vg_cod_programa,vg_lugar, vg_fec_actual, vg_hor_inicio, vg_hor_fin);
  end LP_GEN_DAT_TIP_2_REVERSADOS;
begin
  vg_cod_programa := 'PRB_INF_ESP_CIDESA';
  
  --Carga Variables del Proceso--
  LP_CAR_VAR_PROCESO;
  
  --Verificar usuario base de datos--
  LP_VER_USU_BAS_DATOS;  
  
  --Prepara tablas temporales--
  LP_PRE_TAB_TEMPORALES;
  
  --Inserta datos en tabla de informes--
  
  --TIPO 1--
  LP_GEN_DAT_TIP_1;                       
 
  --CABECERA SIPAP--
  LP_GEN_DAT_CABECERA_SIPAP;         
 
  --TIPO 2-- 
  --ACTIVOS--
  LP_GEN_DAT_TIP_2_ACTIVOS;          

  --PASIVOS--
  LP_GEN_DAT_TIP_2_PASIVOS;

  ---RUBROS CITI--
  LP_GEN_DAT_TIP_2_RUB_CITI;
 
  --30/10/2013 se incluye  SIPAP-- 
  --SIPAP A--
  LP_GEN_DAT_TIP_2_SIPAP_A;
  
  --SIPAP B--
  LP_GEN_DAT_TIP_2_SIPAP_B;
  
  --TIPO 2 C--
  LP_GEN_DAT_TIP_2_C;    

  --TIPO 2 REVERSADOS--
  LP_GEN_DAT_TIP_2_REVERSADOS;
  
  --Copia a tablas definitivas--
  IF vg_tra_regitros = 'S' THEN
    -- trunca tabla definitiva--
    LP_TRU_TAB_INFORME;
    
    -- copia registros generados--
    LP_INS_INF_GENERADO;
  END IF;
end PRB_INF_ESP_CIDESA;
/

