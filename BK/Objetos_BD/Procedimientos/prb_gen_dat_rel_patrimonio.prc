create or replace procedure it.prb_gen_dat_rel_patrimonio(p_fecha in date) is
v_redondeo_ml number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',2,21,pag_gen.fu_obt_mon_local);
begin

--Eliminar Datos Anteriores--
delete from cb_rel_patrimonio a
 where a.fecha = p_fecha;

--01-Capital--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 1, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (38,39,40);
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 1, a.cod_gru_rubro, 0, 2
  from cb_gru_rubros a
 where a.cod_gru_rubro in (38,39,40);


--02-Reservas--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 2, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (41,42,43,44,45);
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 2, a.cod_gru_rubro, 0, 2
  from cb_gru_rubros a
 where a.cod_gru_rubro in (41,42,43,44,45);


--03-Bonos Subordinados--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 3, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (46);
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 3, a.cod_gru_rubro, 0, 2
  from cb_gru_rubros a
 where a.cod_gru_rubro in (46);

--04-Resultados Acumulados--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 4, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (47);
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 4, a.cod_gru_rubro, 0, 2
  from cb_gru_rubros a
 where a.cod_gru_rubro in (47);

--05-Resultados del Ejercicio--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 5, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (48);
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 5, a.cod_gru_rubro, 0, 2
  from cb_gru_rubros a
 where a.cod_gru_rubro in (48);

--06-Menos--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 6, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (49,50,51);
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 6, a.cod_gru_rubro, 0, 2
  from cb_gru_rubros a
 where a.cod_gru_rubro in (49,50,51);

--08-Total del Activo--
--a-) Rubros Contables--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 8, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (53,54,55,56);
--b-) Detalle de Saldos de Bancos--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 nro_cuenta, cod_moneda, sal_mon_local, nivel, referencia, sal_mon_loc_original)
select p_fecha, 8, decode(z.val_parametro,'2',54,'4',56),
       y.nro_cuenta, y.cod_moneda,
       abs(round(nvl(x.sal_mon_local,0)/1000000,v_redondeo_ml)), 3, y.denominacion,
       nvl(x.sal_mon_local,0)
    from ge_sal_diarios x, cc_cta_bancarias y, ge_cta_dat_adicionales z
   where x.fecha = p_fecha
     and y.nro_cuenta = x.nro_cuenta
     and y.cod_modalidad = 45 --Corresponsales--
     and z.parametro = 'CAT_CORRESPONSAL'
     and z.nro_cuenta = x.nro_cuenta
     and z.val_parametro in ('2','4');  --Categoria 2,4--
--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel, ponderacion)
select p_fecha, 8, a.cod_gru_rubro, 0, 2,
       decode(a.cod_gru_rubro,53,0,54,20,55,50,56,100)
  from cb_gru_rubros a
 where a.cod_gru_rubro in (53,54,55,56);

--10-Total de Contingencias--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 cod_rubro, sal_mon_local, nivel)
select p_fecha, 10, a.cod_gru_rubro, a.cod_rubro, 0, 3
  from cb_gru_rubros_det a
 where a.cod_gru_rubro in (58,59,60,61);

--Resumen Nivel 2--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel, ponderacion)
select p_fecha, 10, a.cod_gru_rubro, 0, 2,
       decode(a.cod_gru_rubro,58,0,59,20,60,50,61,100)
  from cb_gru_rubros a
 where a.cod_gru_rubro in (58,59,60,61);

--Actualizacion de Saldos / Nivel 3--
update cb_rel_patrimonio x
   set (x.sal_mon_local,x.sal_mon_loc_original) = 
                              (select round((nvl(y.sal_mon_loc_ant,0)+
                                             nvl(y.deb_mon_local,0)-
                                             nvl(y.cre_mon_local,0))/1000000,v_redondeo_ml),
                                      (nvl(y.sal_mon_loc_ant,0)+
                                       nvl(y.deb_mon_local,0)-
                                       nvl(y.cre_mon_local,0))
                            from cb_sal_consolidados_dia y
                           where y.fecha = p_fecha
                             and y.cod_rubro = x.cod_rubro)
where x.fecha = p_fecha
  and x.nivel = 3
  and exists (select 1
                from cb_sal_consolidados_dia y
               where y.fecha = p_fecha
                 and y.cod_rubro = x.cod_rubro);

--Actulizacion de Ctas que restan--
update cb_rel_patrimonio x
   set x.sal_mon_local = x.sal_mon_local*-1
 where x.nivel = 3
   and ((x.cod_gru_rubro = 56
         and x.cod_rubro in ('130101410700000','510106510800201',
                             '510106510800299','510106510400401',
                             '510106510400201','510106510400101',
                             '510106510400499','510106510400299',
                             '510106510400199'))
       or
        (x.cod_gru_rubro = 61
         and x.cod_rubro in ('510106510400699')));

--Controlar Resultado del Ejercicio--
update cb_rel_patrimonio x
   set x.sal_mon_local = DECODE(fug_obt_pardinamico('IND_RES_DEL_EJERCICIO'),'N',0,x.sal_mon_local)
 where x.cod_rubro = '310600000000000'; --Resultado del Ejercicio--

--Actualizacion de Datos / Nivel 2 - Saldos Contables--
update cb_rel_patrimonio x
   set x.sal_mon_local = (select sum(nvl(a.sal_mon_local,0))
                            from cb_rel_patrimonio a
                           where a.fecha = p_fecha
                             and a.nivel = 3
                             and a.cod_gru_patrimonio = x.cod_gru_patrimonio
                             and a.cod_gru_rubro = x.cod_gru_rubro)
where x.nivel = 2
  and exists (select 1
                from cb_rel_patrimonio a
               where a.fecha = p_fecha
                 and a.nivel = 3
                 and a.cod_gru_patrimonio = x.cod_gru_patrimonio
                 and a.cod_gru_rubro = x.cod_gru_rubro);

--Actualizacion de Datos / Nivel 2 - Ponderaciones--
update cb_rel_patrimonio x
   set x.mto_ponderado = round(x.sal_mon_local * x.ponderacion / 100,2)
 where x.nivel = 2
   and x.ponderacion is not null;

--07-Patrimonio--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha, 7, a.cod_gru_rubro, xx_saldo, 2
  from cb_gru_rubros a,
(
select sum(nvl(
               decode(x.cod_gru_rubro,
               49,x.sal_mon_local*-1,
               50,x.sal_mon_local*-1,
               51,x.sal_mon_local*-1,
               x.sal_mon_local)
               ,0)) xx_saldo
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio between 1 and 6
)
 where a.cod_gru_rubro = 52; --Patrimonio--

--09 y 11 -Activos y Contingentes Ponderados--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro,
 sal_mon_local, nivel)
select p_fecha,
       decode(a.cod_gru_rubro,57,9,62,11),
       a.cod_gru_rubro,
       xx_saldo, 2
  from cb_gru_rubros a,
(
select x.cod_gru_patrimonio,
       decode(x.cod_gru_patrimonio,8,57,10,62) xx_cod_gru_rubro,
       sum(nvl(x.mto_ponderado,0)) xx_saldo,
       sum(nvl(x.sal_mon_local,0)) xx_sal_mon_local
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio in (8,10)
group by x.cod_gru_patrimonio,
         decode(x.cod_gru_patrimonio,8,57,10,62)
)
 where a.cod_gru_rubro in (57,62)
   and xx_cod_gru_rubro = a.cod_gru_rubro;

--Activos y Contingentes Ponderados - Sumatoria--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro, sal_mon_local, nivel)
select p_fecha, 12, a.cod_gru_rubro, xx_sal_mon_local, 2
  from cb_gru_rubros a,
(
select sum(nvl(x.sal_mon_local,0)) xx_sal_mon_local
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio in (9,11)
)
 where a.cod_gru_rubro = 63;

--Patrimonio Exigido--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro, sal_mon_local, nivel)
select p_fecha, 13, a.cod_gru_rubro, xx_saldo, 2
  from cb_gru_rubros a,
(
select round(sum(nvl(x.sal_mon_local,0))*10/100,v_redondeo_ml) xx_saldo
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio = 12
)
 where a.cod_gru_rubro = 64;

--Posicion Superavit--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro, sal_mon_local, nivel)
select p_fecha, 14, a.cod_gru_rubro,
       case
       when xx_saldo > 0 then xx_saldo
       when xx_saldo <= 0 then 0
       end case
       , 2
  from cb_gru_rubros a,
(
select sum(nvl(decode(x.cod_gru_patrimonio,7,abs(x.sal_mon_local),
                                          13,x.sal_mon_local*-1),0)) xx_saldo
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio in (7,13)
)
 where a.cod_gru_rubro = 65;

--Posicion Deficit--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro, sal_mon_local, nivel)
select p_fecha, 14, a.cod_gru_rubro,
       case
       when xx_saldo >= 0 then 0
       when xx_saldo < 0 then abs(xx_saldo)
       end case
       , 2
  from cb_gru_rubros a,
(
select sum(nvl(decode(x.cod_gru_patrimonio,7,abs(x.sal_mon_local),
                                          13,x.sal_mon_local*-1),0)) xx_saldo
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio in (7,13)
)
 where a.cod_gru_rubro = 66;

--Patrimonio Efectivo / Activos y Contigentes Ponderados--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, cod_gru_rubro, sal_mon_local, nivel)
select p_fecha, 15, a.cod_gru_rubro, round(xx_saldo1/xx_saldo2*100,2), 2
  from cb_gru_rubros a,
(
select abs(sum(nvl(decode(x.cod_gru_patrimonio,7,x.sal_mon_local,0),0))) xx_saldo1,
       abs(sum(nvl(decode(x.cod_gru_patrimonio,12,x.sal_mon_local,0),0))) xx_saldo2
from cb_rel_patrimonio x
where x.fecha = p_fecha
  and x.nivel = 2
  and x.cod_gru_patrimonio in (7,12)
)
 where a.cod_gru_rubro = 67;

--Insercion de Datos / Nivel 1--
insert into cb_rel_patrimonio
(fecha, cod_gru_patrimonio, nivel, sal_mon_local)
select a.fecha, a.cod_gru_patrimonio, 1,
       sum(nvl(a.sal_mon_local,0))
  from cb_rel_patrimonio a
where a.fecha = p_fecha
  and nivel = 2
group by a.fecha, a.cod_gru_patrimonio;

exception
when others then
     raise_application_error(-20000,'Error en prb_gen_dat_rel_patrimonio : '||SQLERRM);
end prb_gen_dat_rel_patrimonio;
/

