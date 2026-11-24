CREATE OR REPLACE PROCEDURE IT."PRB_INF_QUI_CIDESA" is

--Desarrollado por Simgia Septiembre 2011
--Genera informe para cidesa en forma quincenal
-- 2013-09-17 Modificaciones para ctas bancarias CITI - PRONET. N.AN..
v_cod_mon_local   ba_monedas.cod_moneda%type;
v_fecha_ini           date;
v_fecha_fin           date;
v_fecha               date;
--v_fec                 date;
v_fec_ant_mes         DATE;

begin
v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
v_fecha :=pag_cal.FU_OBT_FEC_ACTUAL(1);
--v_fec:=null;
v_fec_ant_mes:=NULL;
v_fecha_fin:=pag_cal.FU_OBT_FEC_ANTERIOR(2);--trae la ultima fecha del balance
 begin
    execute immediate 'truncate table cb_inf_cid_tmp';
    exception when others then null;
  end;

 select to_date('01/'||to_char(v_fecha,'mm/yyyy'),'dd/mm/yyyy') into v_fecha_ini from dual;
 --select to_date('16/'||to_char(v_fecha,'mm/yyyy'),'dd/mm/yyyy') into v_fec from dual;
 --select pag_cal.FU_OBT_FEC_ANT_HAB (v_fec,31,1) into v_fecha_fin from dual;
 select pag_cal.FU_OBT_FEC_ANT_HAB (v_fecha_ini,31,1) into v_fec_ant_mes from dual;
  ---cuando es mensual
  --tipo 1
  -- Se reemplaza ge_bancos por gv_ent_cidesa, se quita el filtro de banco activo que ya está incluído en la vista 
  -- y se considera que cc_cta_bancarias esté relacionado a un cod_banco o cod_ente --CN 11/08/2014-- SNP-82 
  execute immediate 'insert into cb_inf_cid_tmp
      select ''I''||'',''||''1007''||'',''||lpad(g.cod_bco_central,4,0)
          ||'',''||
          lpad(decode(nvl(c.saldo_ant,0),0,''+'',decode(abs(c.saldo_ant),c.saldo_ant,''-'',''+''))
          ||
          TRUNC(nvl(abs(c.saldo_ant),0)),13,CHR(32))||''.''||
          substr(rpad(nvl(abs(c.saldo_ant),0) - trunc(nvl(abs(c.saldo_ant),0)),3,0),-2)
          ||'',''||
          lpad(decode(nvl(c.saldo_act,0),0,''+'', decode(abs(c.saldo_act),c.saldo_act,''-'',''+''))
          ||
          TRUNC(nvl(abs(c.saldo_act),0)),13,CHR(32))
          ||''.''||
          substr(rpad(nvl(abs(c.saldo_act),0) - trunc(nvl(abs(c.saldo_act),0)),3,0),-2)
          
          ||'',''||'''||to_char(v_fecha_ini,'ddmmyyyy')||'''
          ||'',''||'''||to_char(v_fecha_fin,'ddmmyyyy')||'''
          ||'',''||decode(cc.cod_moneda,'''||v_cod_mon_local||''',''6900'',''USD'',''6100'',''EUR'',''6300'')
           cidesa, g.cod_bco_central,cc.cod_moneda,cc.cod_modalidad,''I'',''Q'',to_date('''||to_char(v_fecha_ini,'dd/mm/yyyy')||''',''dd/mm/yyyy'')
          from  --ge_bancos g, 
            gv_ent_cidesa g, cc_cta_bancarias cc,
          (select --cc.cod_banco,
                 nvl(cc.cod_banco,cc.cod_ente) cod_banco, cc.nro_cuenta, sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,to_date('''||to_char(v_fecha_fin,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0) +
                 nvl(FUB_OBT_SAL_CONTABLE(fug_obt_paradicional(cc.nro_cuenta,''COD_RUB_SOB_CTA_BAN''),to_date('''||to_char(v_fecha_fin,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0)))saldo_act,
                 sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,to_date('''||to_char(v_fec_ant_mes,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0) +
                 nvl(FUB_OBT_SAL_CONTABLE(fug_obt_paradicional(cc.nro_cuenta,''COD_RUB_SOB_CTA_BAN''),to_date('''||to_char(v_fec_ant_mes,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0)))saldo_ant
                 from cc_cta_bancarias cc
                 group by --cc.cod_banco,
                 nvl(cc.cod_banco,cc.cod_ente), cc.nro_cuenta
                 )c
          where --g.estado=''A'' and 
          g.cod_bco_central is not null
          and g.cod_bco_central not in(1007,1001)
          --and g.cod_banco=cc.cod_banco
          and g.cod_banco=nvl(cc.cod_banco,cc.cod_ente)
          and g.cod_banco=c.cod_banco
          --and c.cod_banco=cc.cod_banco
          and c.cod_banco=nvl(cc.cod_banco,cc.cod_ente)
          and c.nro_cuenta=cc.nro_cuenta';
          
          
        --Cabecera SIPAP
        execute immediate 'insert into cb_inf_cid_tmp
        select distinct ''I''||'',''||''1007''||'',''||lpad(7,4,0)
        ||'',''||
        lpad(decode(nvl(c.saldo_ant,0),0,''+'',decode(abs(c.saldo_ant),c.saldo_ant,''-'',''+''))
        ||
        TRUNC(nvl(abs(c.saldo_ant),0)),13,CHR(32))||''.''||
        substr(rpad(nvl(abs(c.saldo_ant),0) - trunc(nvl(abs(c.saldo_ant),0)),3,0),-2)
        ||'',''||
        lpad(decode(nvl(c.saldo_act,0),0,''+'', decode(abs(c.saldo_act),c.saldo_act,''-'',''+''))
        ||
        TRUNC(nvl(abs(c.saldo_act),0)),13,CHR(32))
        ||''.''||
        substr(rpad(nvl(abs(c.saldo_act),0) - trunc(nvl(abs(c.saldo_act),0)),3,0),-2)
        ||'',''||'''||to_char(v_fecha_ini,'ddmmyyyy')||'''
        ||'',''||'''||to_char(v_fecha_fin,'ddmmyyyy')||'''
        ||'',''||decode(cc.cod_moneda,'''||v_cod_mon_local||''',''6900'',''USD'',''6100'',''EUR'',''6300'')
         cidesa, 7 cod_bco_central,cc.cod_moneda,cc.cod_modalidad,''I'',''Q'',to_date('''||to_char(v_fecha_ini,'dd/mm/yyyy')||''',''dd/mm/yyyy'')
        from ge_bancos g, cc_cta_bancarias cc,
        (select cc.cod_banco,cc.nro_cuenta, sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,to_date('''||to_char(v_fecha_fin,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0) +
               nvl(FUB_OBT_SAL_CONTABLE(fug_obt_paradicional(cc.nro_cuenta,''COD_RUB_SOB_CTA_BAN''),to_date('''||to_char(v_fecha_fin,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0)))saldo_act,
               sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,to_date('''||to_char(v_fec_ant_mes,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0) +
               nvl(FUB_OBT_SAL_CONTABLE(fug_obt_paradicional(cc.nro_cuenta,''COD_RUB_SOB_CTA_BAN''),to_date('''||to_char(v_fec_ant_mes,'dd/mm/yyyy')||''',''dd/mm/yyyy''),cc.cod_moneda),0)))saldo_ant
               from cc_cta_bancarias cc
               where cc.cod_modalidad=455
               group by cc.cod_banco,cc.nro_cuenta
               )c
        where
        c.nro_cuenta=cc.nro_cuenta
        and cc.cod_modalidad=''455''
        ';

  --tipo 2
  -- Se reemplaza ge_bancos por gv_ent_cidesa, se quita el filtro de banco activo que ya está incluído en la vista 
  -- y se considera que cc_cta_bancarias esté relacionado a un cod_banco o cod_ente --CN 11/08/2014-- SNP-82 
  execute immediate 'insert into cb_inf_cid_tmp
          --activos
          select c.tip_movimiento
          ||'',''
          ||to_char(c.fecha,''ddmmyyyy'')
          ||'',''
          ||to_char(c.fecha,''ddmmyyyy'')
          ||'',''
          ||lpad(substr(NVL(c.descripcion,CHR(32)),1,20),20,CHR(32))
          ||'',''
          ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
          ||'',''
          ||lpad(TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
          ||''.''
          ||substr(rpad(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
          ,g.cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,''Q'',c.fecha
          from  --ge_bancos g, 
          gv_ent_cidesa g, 
          cb_asientos_det_his c,cc_cta_bancarias cc,cc_movimientos_his m
          where --cc.cod_banco=g.cod_banco
          nvl(cc.cod_banco,cc.cod_ente)=g.cod_banco
          and c.fecha=m.FECHA(+)
          and c.ref_movimiento=m.NRO_DOCUMENTO4(+)
          and cc.cod_rubro=c.cod_rubro
          and g.cod_bco_central is not null
          and g.cod_bco_central not in(1007,1001)
          and c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
          and ((cc.cod_moneda <> '''||v_cod_mon_local||''' and c.mto_mon_rubro <> 0) or
              (cc.cod_moneda = '''||v_cod_mon_local||''' and c.mto_mon_rubro = 0))
          and c.cod_rubro NOT IN (''111201090400699'',''111201090450099'',''211101020400699'',''211101020414499'') -- N.AN. filtramos rubros CITI
          ---los pasivos
          union
          select c.tip_movimiento
          ||'',''
          ||to_char(c.fecha,''ddmmyyyy'')
          ||'',''
          ||to_char(c.fecha,''ddmmyyyy'')
          ||'',''
          ||lpad(substr(NVL(c.descripcion,CHR(32)),1,20),20,CHR(32))
          ||'',''
          ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
          ||'',''
          ||lpad(TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
          ||''.''
          ||substr(rpad(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
          ,g.cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,''Q'',c.fecha
          from  --ge_bancos g, 
          gv_ent_cidesa g, cb_asientos_det_his c,cc_cta_bancarias cc,cc_movimientos_his m,ge_cta_dat_adicionales dx
          where --cc.cod_banco=g.cod_banco
          nvl(cc.cod_banco,cc.cod_ente)=g.cod_banco
          and c.fecha=m.FECHA(+)
          and c.ref_movimiento=m.NRO_DOCUMENTO4(+)
          and c.cod_rubro=dx.val_parametro
          and dx.nro_cuenta=cc.nro_cuenta
          and dx.parametro  = ''COD_RUB_SOB_CTA_BAN''
          and g.cod_bco_central is not null
          and g.cod_bco_central not in(1007,1001)
          and c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
          and ((cc.cod_moneda <> '''||v_cod_mon_local||''' and c.mto_mon_rubro <> 0) or
              (cc.cod_moneda = '''||v_cod_mon_local||''' and c.mto_mon_rubro = 0))
           and c.cod_rubro NOT IN (''111201090400699'',''111201090450099'',''211101020400699'',''211101020414499'') -- N.AN. filtramos rubros CITI
          ---rubros CITI
          union all
          select g.tip_movimiento
          ||'',''
          ||to_char(g.fecha,''ddmmyyyy'')
          ||'',''
          ||to_char(g.fecha,''ddmmyyyy'')
          ||'',''
          ||lpad(substr(NVL(g.descripcion,CHR(32)),1,20),20,CHR(32))
          ||'',''
          ||lpad(substr(NVL(decode(nvl(g.NRO_DOCUMENTO3,0),0,g.NRO_DOCUMENTO,g.NRO_DOCUMENTO3),0),1,15),15,0)
          ||'',''
          ||lpad(TRUNC(decode(g.cod_moneda,'''||v_cod_mon_local||''',g.mto_mon_local,g.mto_mon_rubro)),13,0)
          ||''.''
          ||substr(rpad(decode(g.cod_moneda,'''||v_cod_mon_local||''',g.mto_mon_local,g.mto_mon_rubro)-TRUNC(decode(g.cod_moneda,'''||v_cod_mon_local||''',g.mto_mon_local,g.mto_mon_rubro)),3,0),-2)
          ,1006 cod_bco_central,g.cod_moneda,
          decode( cod_rubro,''111201090450099'', 47,
          ''211101020414499'', 47, 42) cod_modalidad,
          g.tip_movimiento,''Q'',g.fecha
          from
          (
                select d.cod_rubro, d.fecha, d.cod_oficina ,c.cod_modalidad, c.cod_modulo,
                d.nro_asiento asiento, d.nro_linea lin, d.ref_movimiento ref, d.descripcion,
                d.tip_movimiento,d.mto_mon_local,d.mto_mon_rubro,c.cod_usuario,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3, d.referencia, r.cod_moneda
                from cb_asientos_det_his d, cb_rubros r,cb_asientos_his c, cc_movimientos_his m
                where r.cod_rubro=d.cod_rubro
                and c.fecha= d.fecha
                and c.cod_oficina=d.cod_oficina
                and c.nro_asiento=d.nro_asiento
                and d.fecha=m.FECHA(+)
                and d.ref_movimiento=m.NRO_DOCUMENTO4(+)
                and d.cod_rubro IN (''111201090400699'',''111201090450099'',''211101020400699'',''211101020414499'')
                and c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
            ) G';


            --30/10/2013 se incluye  SIPAP
            execute immediate 'insert into cb_inf_cid_tmp
                select c.tip_movimiento
                ||'',''
                ||to_char(c.fecha,''ddmmyyyy'')
                ||'',''
                ||to_char(c.fecha,''ddmmyyyy'')
                ||'',''
                ||lpad(substr(NVL(decode(c.tip_movimiento,''D'',c.descripcion, trim(d.nom_solicitante)),CHR(32)),1,20),20,CHR(32))
                ||'',''
                ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
                ||'',''
                ||lpad(TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
                ||''.''
                ||substr(rpad(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),
                ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
                ,nvl(g.cod_banco,''7'') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,''Q'',c.fecha
                from  cc_cta_bancarias cc,cb_asientos_det_his c,cc_movimientos_his m, ge_snp_transferencias d,
                ge_bancos g
                where c.fecha=m.FECHA
                and c.ref_movimiento=m.NRO_DOCUMENTO4
                and cc.cod_rubro=c.cod_rubro
                and m.cod_modalidad=455
                and d.estado <> ''C''  
                and c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
                and ((m.cod_moneda <> '''||v_cod_mon_local||''' and nvl(c.mto_mon_rubro,0) <> 0) or
                  (m.cod_moneda = '''||v_cod_mon_local||''' and nvl(c.mto_mon_rubro,0) = 0))
                and cc.cod_banco=g.cod_banco(+)
                and m.nro_documento=d.nro_referencia
                and c.cod_rubro IN (''111201051001199'',''111201051801105'',''111201051801117'')
                union all
                select c.tip_movimiento
                ||'',''
                ||to_char(c.fecha,''ddmmyyyy'')
                ||'',''
                ||to_char(c.fecha,''ddmmyyyy'')
                ||'',''
                ||lpad(substr(NVL(decode(c.tip_movimiento,''D'',m.concepto, trim(m.concepto)),CHR(32)),1,20),20,CHR(32))
                ||'',''
                ||lpad(substr(NVL(decode(nvl(m.NRO_DOCUMENTO3,0),0,m.NRO_DOCUMENTO,m.NRO_DOCUMENTO3),0),1,15),15,0)
                ||'',''
                ||lpad(TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),13,0)
                ||''.''
                ||substr(rpad(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),
                ABS(c.mto_mon_rubro)))-TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(m.monto),ABS(c.mto_mon_local)),nvl(ABS(m.monto),ABS(c.mto_mon_rubro)))),3,0),-2)
                ,nvl(g.cod_banco,''7'') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,''Q'',c.fecha
                from  cc_cta_bancarias cc,cb_asientos_det_his c,cc_movimientos_his m, 
                ge_bancos g
                where c.fecha=m.FECHA
                and c.ref_movimiento=m.NRO_DOCUMENTO4
                and cc.cod_rubro=c.cod_rubro
                and m.cod_modalidad=455
                and c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
                and ((m.cod_moneda <> '''||v_cod_mon_local||''' and nvl(c.mto_mon_rubro,0) <> 0) or
                  (m.cod_moneda = '''||v_cod_mon_local||''' and nvl(c.mto_mon_rubro,0) = 0))
                and cc.cod_banco=g.cod_banco(+)
                and m.nro_documento not in (select z.nro_referencia from ge_snp_transferencias z
                        where z.nro_referencia= m.nro_documento)
                and c.cod_rubro IN (''111201051001199'',''111201051801105'',''111201051801117'')
                union all    
                select c.tip_movimiento
                ||'',''
                ||to_char(c.fecha,''ddmmyyyy'')
                ||'',''
                ||to_char(c.fecha,''ddmmyyyy'')
                ||'',''
                ||lpad(substr(NVL(trim(c.descripcion),CHR(32)),1,20),20,CHR(32))
                ||'',''
                ||lpad(substr(NVL(c.nro_asiento,0) ,1,15),15,0)
                ||'',''
                ||lpad(TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',ABS(c.mto_mon_local),ABS(c.mto_mon_rubro))),13,0)
                ||''.''
                ||substr(rpad(decode(cc.cod_moneda,'''||v_cod_mon_local||''',NVL(ABS(c.mto_mon_local),0),NVL(ABS(c.Mto_Mon_Rubro),0))-TRUNC(decode(cc.cod_moneda,'''||v_cod_mon_local||''',NVL(ABS(c.mto_mon_local),0),NVL(ABS(c.mto_mon_rubro),0))),3,0),-2)
                ,nvl(g.cod_banco,''7'') cod_bco_central,cc.cod_moneda,cc.cod_modalidad,c.tip_movimiento,''Q'',c.fecha
                from  cc_cta_bancarias cc,cb_asientos_det_his c,ge_bancos g
                where cc.cod_rubro=c.cod_rubro
                and c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
                and cc.cod_banco=g.cod_banco(+)
                and ((cc.cod_moneda <> '''||v_cod_mon_local||''' and nvl(c.mto_mon_rubro,0) <> 0) or
               (cc.cod_moneda = '''||v_cod_mon_local||''' and nvl(c.mto_mon_rubro,0) = 0))
                and c.ref_movimiento is null
                and c.cod_rubro IN (''111201051001199'',''111201051801105'',''111201051801117'')	             
                ';


end prb_inf_qui_cidesa;
/

