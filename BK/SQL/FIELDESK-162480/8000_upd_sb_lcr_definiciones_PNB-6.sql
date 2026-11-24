begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

update sb_lcr_definiciones d
  set d.sql = 'select ''Caja'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  = ''110100000000000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  = ''110100000000000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 21;

update sb_lcr_definiciones d
  set d.sql = 'select ''Cuentas Corrientes'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  = ''110201051000000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  = ''111201051800001''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 22;

update sb_lcr_definiciones d
  set d.sql = 'select ''Encaje Legal'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''110201050200000'',''110201050400000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''110201050600000'',''110201052400000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 23;

update sb_lcr_definiciones d
  set d.sql = 'select ''Depósitos por Oper.'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  = ''110201053400000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  = ''110201053400000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 24;

update sb_lcr_definiciones d
  set d.sql = 'select ''Val. Públicos Nac. moneda nac. - BCP y val. públicos nac. mon. nac. y ext. - Gob. Nac. Pyo.'' concepto, 
       sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''120101230200000'',''120101230200301'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''120101230200000'',''120101230200301'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 25;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE. - MINORISTA - ESTABLE - VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1 
  and r.categoria = 3 
  and r.grupo     = 6'
where d.nro_item = 62;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE. - MINORISTA - ESTABLE - DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1 
  and r.categoria = 3 
  and r.grupo     = 6'
where d.nro_item = 63;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE. - MINORISTA - MENOS ESTABLE - VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1 
  and r.categoria = 3 
  and r.grupo     = 7'
where d.nro_item = 64;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE. - MINORISTA - MENOS ESTABLE - DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1 
  and r.categoria = 3 
  and r.grupo     = 7'
where d.nro_item = 65;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE. - MINORISTA - DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1 
  and r.categoria = 3 
  and r.grupo     = 6'
where d.nro_item = 36;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 4 
  and r.grupo     = 6'
where d.nro_item = 79;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 4 
  and r.grupo     = 6'
where d.nro_item = 80;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-MENOS ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 4 
  and r.grupo     = 7'
where d.nro_item = 81;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-MENOS ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 4 
  and r.grupo     = 7'
where d.nro_item = 82;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 4 
  and r.grupo     = 6'
where d.nro_item = 68;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 5 
  and r.grupo     = 6'
where d.nro_item = 91;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 5 
  and r.grupo     = 6'
where d.nro_item = 92;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-MENOS ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 5 
  and r.grupo     = 7'
where d.nro_item = 93;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-MENOS ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 5 
  and r.grupo     = 7'
where d.nro_item = 94;

update sb_lcr_definiciones d
  set d.sql = 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r 
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2 
  and r.categoria = 5 
  and r.grupo     = 6'
where d.nro_item = 88;

update sb_lcr_definiciones d
  set d.sql = 'select ''Ent. públ. resid. del sector no fin.(SNF)'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''220402380000000'',''220402900000000'',''220402920000000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      -- Resta Seguridad Social GS
      select (abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) * -1) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''210101021800000'',''210101961800000'',''210102841800000'',''220402920600000'',''220402380600000'',''220402900600000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''220402380000000'',''220402900000000'',''220402920000000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      -- Resta Seguridad Social Mon Ext
      select 0 sal_mon_loc,
             (round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0) * -1)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''210101021800000'',''210101961800000'',''210102841800000'',''220402920600000'',''220402380600000'',''220402900600000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 71;

update sb_lcr_definiciones d
  set d.sql = 'select ''Entidades públicas y privadas no residentes del SNF'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''220101360300000'',''220101380300000'',''220101520300000'',''220101560300000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''220101360300000'',''220101380300000'',''220101520300000'',''220101560300000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 72;

update sb_lcr_definiciones d
  set d.sql = 'select ''Organismos Multilaterales'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''210101000060000'',''210101000080000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''210101000060000'',''210101000080000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 73;

update sb_lcr_definiciones d
  set d.sql = 'select ''Instituciones del sector financiero, tanto locales como no residentes'' concepto, sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''21010102%''
  and l.plazo     <= 30
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo ) con'
where d.nro_item = 74;

update sb_lcr_definiciones d
  set d.sql = 'select ''Seguridad Social'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''210101021800000'',''210101961800000'',''210102841800000'',''220402920600000'',''220402380600000'',''220402900600000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''210101021800000'',''210101961800000'',''210102841800000'',''220402920600000'',''220402380600000'',''220402900600000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 75;

update sb_lcr_definiciones d
  set d.sql = 'select ''Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)'' concepto, 
       sum(case when c.cod_moneda = ''GS'' THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                                          from ge_cotizaciones cot
                                                                          where cot.cod_moneda = c.cod_moneda
                                                                            and cot.fecha = c.fecha),1)),0) else 0 end) sal_gs,

       sum(case when c.cod_moneda <> ''GS'' THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                                          from ge_cotizaciones cot
                                                                          where cot.cod_moneda = c.cod_moneda
                                                                            and cot.fecha = c.fecha),1)),0) else 0 end) sal_ext
from cb_sal_inventarios_his c, cb_sal_inventarios_det_his d, ge_cta_clientes r, ba_personas p, ge_clientes cl, ba_cod_referencias re,
     ge_cuentas cu
where c.fecha = '||'&'||'FECHA
  and c.cod_modalidad  in (31,334,41,39,33,36,37,38)
  and ((c.cod_modalidad = 41 and c.tip_saldo in (''C'',''Q'')) or (c.tip_saldo = ''C'' ))
  and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) <= 30  
  and d.fecha          = c.fecha
  and d.nro_referencia = c.nro_referencia
  and d.nro_cuenta     = r.nro_cuenta
  and r.relacion       = ''P''
  and p.cod_persona    = r.cod_persona
  and p.cod_persona    <> ''1''
  and cl.cod_persona   = p.cod_persona
  and d.sal_actual     > 0
  and re.dominio       = ''SOCIEDADES_VALORES''
  and re.val_minimo    = r.cod_persona
  and cu.nro_cuenta    = r.nro_cuenta
  and cu.estado        <> ''T'''
where d.nro_item = 76;

update sb_lcr_definiciones d
  set d.sql = 'select ''Compañías de Seguros'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''210101022000000'',''210101962000000'',''210102842000000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''210101022000000'',''210101962000000'',''210102842000000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 77;

update sb_lcr_definiciones d
  set d.sql = 'select ''Agentes Fiduciarios'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  = ''230103020010000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  = ''230103020010000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 78;

update sb_lcr_definiciones d
  set d.sql = 'select ''Instituciones del sector financiero, tanto locales como no residentes'' concepto, 
       sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''21010306%''
  and l.plazo     <= 30
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo
union
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then (l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA)) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''21040%''
  and l.plazo     <= 30
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo
union
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then (l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA)) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''21080%''
  and l.plazo     <= 30
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo ) con'
where d.nro_item = 45;

update sb_lcr_definiciones d
  set d.sql = 'select ''Acreedores'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  = ''240400000000000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  = ''240400000000000''
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 47;

update sb_lcr_definiciones d
  set d.sql = 'select ''Imp. no util. de las facilidades de créd. y liquidez'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''420106160000000'',''420106140000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''420106160000000'',''420106140000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 48;

update sb_lcr_definiciones d
  set d.sql = 'select ''Saldos correspondientes a doc. descontados en instituciones financ.'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''420106060000000'',''410106090000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''420106060000000'',''410106090000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 49;

update sb_lcr_definiciones d
  set d.sql = 'select ''Otras salidas no contempladas'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''240102460000000'',''240102440100000'',''240202520106099'',''240202520107099'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''240102460000000'',''240102440100000'',''240202520106099'',''240202520107099'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 13;

update sb_lcr_definiciones d
  set d.sql = 'select ''Créditos vigentes'' concepto, sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''14010%''
  and l.plazo     <= 30
  and exists (select *
              from (select pr.nro_cuenta, pr.dia_atraso from pr_cta_prestamos pr
                    union
                    select ta.nro_cuenta, ta.dia_mora from ta_cta_tarjetas ta
                    union
                    select cc.nro_cuenta, cc.dia_atraso from cc_cta_corrientes cc
                    union
                    select cve.nro_cuenta, cve.dia_atraso from ov_cta_vencidas cve ) con
              where con.nro_cuenta = l.nro_cuenta
                and con.dia_atraso <= 0)
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo
union
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then (l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA)) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''14080%''
  and l.plazo     <= 30
  and exists (select *
              from (select pr.nro_cuenta, pr.dia_atraso from pr_cta_prestamos pr
                    union
                    select ta.nro_cuenta, ta.dia_mora from ta_cta_tarjetas ta
                    union
                    select cc.nro_cuenta, cc.dia_atraso from cc_cta_corrientes cc
                    union
                    select cve.nro_cuenta, cve.dia_atraso from ov_cta_vencidas cve ) con
              where con.nro_cuenta = l.nro_cuenta
                and con.dia_atraso <= 0)
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo ) con'
where d.nro_item = 55;

update sb_lcr_definiciones d
  set d.sql = 'select ''Créditos vigentes'' concepto, sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''13010%''
  and l.plazo     <= 30
  and exists (select *
              from (select pr.nro_cuenta, pr.dia_atraso from pr_cta_prestamos pr
                    union
                    select ta.nro_cuenta, ta.dia_mora from ta_cta_tarjetas ta
                    union
                    select cc.nro_cuenta, cc.dia_atraso from cc_cta_corrientes cc
                    union
                    select cve.nro_cuenta, cve.dia_atraso from ov_cta_vencidas cve ) con
              where con.nro_cuenta = l.nro_cuenta
                and con.dia_atraso <= 0)
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo
union
select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
       sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
       sum(case when l.moneda = 6100 then (l.monto * FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA)) else 0 end ) sal_mon_ext
from it.sb_lcr_liq_inv_tmp l
where l.cod_rubro like ''13080%''
  and l.plazo     <= 30
  and exists (select *
              from (select pr.nro_cuenta, pr.dia_atraso from pr_cta_prestamos pr
                    union
                    select ta.nro_cuenta, ta.dia_mora from ta_cta_tarjetas ta
                    union
                    select cc.nro_cuenta, cc.dia_atraso from cc_cta_corrientes cc
                    union
                    select cve.nro_cuenta, cve.dia_atraso from ov_cta_vencidas cve ) con
              where con.nro_cuenta = l.nro_cuenta
                and con.dia_atraso <= 0)
group by substr(l.cod_rubro,1,10), l.moneda, l.plazo ) con'
where d.nro_item = 56;

update sb_lcr_definiciones d
  set d.sql = 'select ''Dep. operativos mantenidos en otras instit. finan. loc. como del ext.'' concepto,
       abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 
       round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA) ,0) sal_mon_ext
from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
where gr.cod_moneda = pag_gen.fu_obt_mon_local
  and sc.cod_rubro  = ''110201090000000''
  and gr.cod_rubro  = sc.cod_rubro
  and sc.ano = '||'&'||'ANIO
  and sc.mes = '||'&'||'MES'
where d.nro_item = 16;

update sb_lcr_definiciones d
  set d.sql = 'select ''Otras entradas no contempladas'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc, 0 sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_local
        and sc.cod_rubro  in (''110201110000000'',''110201130000000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union
      select 0 sal_mon_loc,
             round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) *
                              FUG_OBT_COTIZACION(pag_gen.fu_obt_mon_fuerte,'||'&'||'FECHA),0)  sal_mon_ext
      from cb_sim_sal_consolidados sc, cb_gru_rubros_det gr
      where gr.cod_moneda = pag_gen.fu_obt_mon_fuerte
        and sc.cod_rubro  in (''110201110000000'',''110201130000000'')
        and gr.cod_rubro  = sc.cod_rubro
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x'
where d.nro_item = 61;

commit;
