create or replace procedure it.prb_gen_cos_sucursales is
v_fecha date := pag_cal.FU_OBT_FEC_ACTUAL(2);
v_fec_inicial date := to_date('01'||to_char(v_fecha,'/mm/yyyy'),'dd/mm/yyyy');
v_fec_final date := last_day(v_fecha);
v_mes number(2) := to_number(to_char(v_fecha,'mm'));
v_ano number(4) := to_number(to_char(v_fecha,'yyyy'));
v_val_tasa ge_tas_rangos.val_tasa%type;
v_fec_vigencia date;
v_tip_valor ge_tasas.tip_valor%type;
v_tipo ge_tasas.tipo%type;
v_cod_tas_cos_sucursal number(3) := to_number(fug_obt_pardinamico('COD_TAS_COS_SUCURSALES'));
v_mto_interes number(18,2);
v_cod_mon_local varchar2(3) :=  pag_gen.FU_OBT_MON_LOCAL;
v_cod_ofi_mes_dinero number(3) := to_number(fug_obt_pardinamico('COD_OFI_MES_DINERO'));
v_can_dias number(6);
v_redondeo number(2);
--cursor de sucursales--
cursor c_costo is
select a.*, decode(a.cod_plazo,1,90,2,360,3,9999,0) dias, a.rowid registro
  from cb_cos_sucursales a
where a.ano = v_ano
  and a.mes = v_mes;
begin

  --Eliminar registros del mes del detalle--
  DELETE FROM CB_COS_SUCURSALES_DET A
   WHERE A.ANO = V_ANO
     AND A.MES = V_MES;

  --Insertar los Registros correspondientes--
  insert into CB_COS_SUCURSALES_DET
  (ano, mes, cod_oficina, cod_rubro, cod_moneda,
   cod_plazo, tipo, mto_acu_saldo, can_dias, mto_promedio)
  select v_ano, v_mes, t.cod_oficina, x.cod_rubro,
       decode(x.cod_moneda,'GS',x.cod_moneda,'USD') cod_moneda,
  CASE
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) in
       ('1110','1120')
       THEN 1
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) not in
       ('1110','1120','1510','1610','1620','1630','1710','1750','1810','1820','1910','1920') and
  substr(x.cod_rubro,3,1) in ('0','1','2','3','4') THEN 1
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) not in
       ('1110','1120','1510','1610','1620','1630','1710','1750','1810','1820','1910','1920') and
  substr(x.cod_rubro,3,1) in ('5','6') THEN 2
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) not in
       ('1110','1120') and  ((to_number(substr(x.cod_rubro,3,1)) >= 7) or
                             (to_number(substr(x.cod_rubro,3,1)) = 0)) THEN 3
  END cod_plazo,
  decode(substr(x.cod_rubro,1,1),'3','2',substr(x.cod_rubro,1,1)) tipo,
  --sum(decode(x.cod_moneda,'GS',t.sal_mon_loc_actual,t.sal_mon_fue_actual)) mto_acu_saldo,
  sum(nvl(t.sal_mon_loc_actual,0)) mto_acu_saldo,
  nvl(count(*),0) can_dias,
  --round(sum(decode(x.cod_moneda,'GS',t.sal_mon_loc_actual,t.sal_mon_fue_actual))/nvl(count(*),0),2) mto_promedio
  round(sum(nvl(sal_mon_loc_actual,0))/nvl(count(*),0),2) mto_promedio

  from cb_sal_promedios_det t, cb_rubros x
  where t.fecha between v_fec_inicial and v_fec_final
    and x.cod_rubro = t.cod_rubro
    and x.imputable = 'S'
         and substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) in
         --Activo--
         ('1310','1320','1330','1410','1440','1110',
          '1120','1510','1610','1620','1630','1710',
          '1750','1810','1820','1910','1920',
          --Pasivo y Patrimonio--
          '2110','2120','2140','2210','2240')
         and substr(x.cod_rubro,1,10) not like '1501025704%' --Se excluye Rubro de Suc. y Agencias.
         and t.cod_oficina <> v_cod_ofi_mes_dinero
  group by t.cod_oficina, x.cod_rubro,
           decode(x.cod_moneda,'GS',x.cod_moneda,'USD'),
  CASE
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) in
       ('1110','1120')
       THEN 1
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) not in
       ('1110','1120','1510','1610','1620','1630','1710','1750','1810','1820','1910','1920') and
  substr(x.cod_rubro,3,1) in ('0','1','2','3','4') THEN 1
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) not in
       ('1110','1120','1510','1610','1620','1630','1710','1750','1810','1820','1910','1920') and
  substr(x.cod_rubro,3,1) in ('5','6') THEN 2
  WHEN substr(x.cod_rubro,1,2)||substr(x.cod_rubro,4,2) not in
       ('1110','1120') and  ((to_number(substr(x.cod_rubro,3,1)) >= 7) or
                             (to_number(substr(x.cod_rubro,3,1)) = 0)) THEN 3
  END,
  decode(substr(x.cod_rubro,1,1),'3','2',substr(x.cod_rubro,1,1));

  --Insertar la table cb_cos_sucursales--
  DELETE FROM CB_COS_SUCURSALES A
   WHERE A.ANO = V_ANO
     AND A.MES = V_MES;

  --Insertar los Registros correspondientes--
  insert into cb_cos_sucursales
  (ano, mes, cod_oficina, cod_moneda, cod_plazo, mto_pro_activo,
   mto_pro_pasivo, mto_dif_promedio)
   select a.ano, a.mes, a.cod_oficina, a.cod_moneda, a.cod_plazo,
          sum(decode(substr(a.cod_rubro,1,1),'1',nvl(a.mto_promedio,0),0)),
          sum(decode(substr(a.cod_rubro,1,1),'1',0,nvl(a.mto_promedio,0))),
          (sum(decode(substr(a.cod_rubro,1,1),'1',nvl(a.mto_promedio,0),0))) +
          (sum(decode(substr(a.cod_rubro,1,1),'1',0,nvl(a.mto_promedio,0))))
   from cb_cos_sucursales_det a
   where a.ano = v_ano
     and a.mes = v_mes
   group by a.ano, a.mes, a.cod_oficina, a.cod_moneda, a.cod_plazo;

   --Traer la cantidad de días de Promedio--
   select a.can_dias
     into v_can_dias
     from cb_cos_sucursales_det a
    where a.ano = v_ano
      and a.mes = v_mes
      and rownum < 2;

   --Ciclo de Calculo y Actualizacion--
   for cos in c_costo loop
       --Traer la tasa correspondiente--
       PAG_GEN.PR_OBT_VAL_TASA(2, 21, cos.cod_oficina, null, cos.cod_moneda, cos.dias,
                               null, v_cod_tas_cos_sucursal, null, v_fecha, v_val_tasa,
                               v_fec_vigencia, v_tip_valor, v_tipo);
      
       v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',2,21,cos.cod_moneda);

       --Interes Simple Anual--
       v_val_tasa := v_val_tasa * 100;
       v_mto_interes := round((cos.mto_dif_promedio * v_can_dias *  v_val_tasa / 36500),v_redondeo);

       --Actualizacion de Datos--
       update cb_cos_sucursales x
          set x.mto_interes = v_mto_interes,
              x.val_tasa = v_val_tasa
        where x.rowid = cos.registro;

   end loop;

exception
  when others then
       raise_application_error(-20000,' ERROR en : prb_gen_cos_sucursales '||sqlerrm);
end prb_gen_cos_sucursales;
/

