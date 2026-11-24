create or replace force view it.bv_gar_computables as
select pag_cal.fu_obt_fec_actual(1) fecha,
       g.cod_persona cod_persona,
       --
       g.cod_garantia cod_garantia,
       --
       g.nro_garantia nro_garantia,
       g.cod_oficina cod_oficina,
       g.nro_referencia,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0) cod_rubro,
       g.fec_inicio fec_inicio,
       g.fec_vencimiento fec_vencimiento,
       --
       g.cod_moneda cod_moneda,
       --
       nvl(g.valor,0) MONTO,
       g.val_tasacion TASACION,
       'ITGF' OPERADOR,
       g.fec_ult_tasacion fec_ult_tasacion,
       -- Envía NRO_ESCRITURA cuando se trata de hipotecas o prendas.
       -- Si se trata de Warrants aquí tiene que ir el tipo de Warrant en donde 1 --> Otros.. 2 --> Granos
       -- 0 sino tiene nada
       CASE WHEN g.cod_garantia in (3,4) then -- 3 HIPOTECAS, 4 PRENDAS
              nvl(g.nro_escritura,0)
            WHEN g.cod_garantia in (6,10) then -- 6 WARRANTS (FIBRAS), 10 WARRANTS (OTROS PRODUCTOS)
              1
            WHEN g.cod_garantia = 12 then -- 12 WARRANTS (GRANOS)
              2
            ELSE
              0
       END NRO_ESCRITURA,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')) ESCRIBANO,
       tg.descripcion descripcion,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado) desc_estado,
       tg.cod_modulo,
       tg.cod_modalidad,
       tg.cod_transaccion1 tra_computable,
       tg.cod_transaccion2 tra_no_computable,
       tg.computable,
       tg.pri_aplicacion
  from ge_entes e,
       pr_gar_tipos tg,
       ge_clientes c,
       pr_garantias g,
       ge_transacciones t,
       ge_tip_asientos ta

 where g.cod_persona = c.cod_persona
   and g.cod_garantia = tg.cod_garantia
   and g.cod_ent_escribania = e.cod_ente(+)
   and t.cod_transaccion = tg.cod_transaccion1
   and t.cod_modalidad = 61
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and ta.cod_moneda = g.cod_moneda
   and ta.tip_movimiento = 'D'
   and tg.cod_garantia not in (21,22)
   and g.estado in ('C','V') -- Confirmadas;
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.situacion IN ('D','L','E','R') and xg.estado IN ('C','V'))
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.cod_garantia IN (10, 12, 19, 20 ) and xg.estado = 'V')
   -- 2011-01-31 se filtran situacion 'D','L','E' y Estado V con cod 10,12,19 y 20 a Pedido del sr Marcelo Prono;



UNION
--PIGNORACION - PRENDA  PLAZA LOCAL
      select pag_cal.fu_obt_fec_actual(1),
       g.cod_persona,
       --
       g.cod_garantia,
       g.nro_garantia,
       g.cod_oficina,
       g.nro_referencia,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0),
       g.fec_inicio,
       g.fec_vencimiento,
       --
       g.cod_moneda,
       --
       nvl(g.valor,0),
       g.val_tasacion,
       'ITGF' OPERADOR,
       g.fec_ult_tasacion,
       -- Envía NRO_ESCRITURA cuando se trata de hipotecas o prendas.
       -- Si se trata de Warrants aquí tiene que ir el tipo de Warrant en donde 1 --> Otros.. 2 --> Granos
       -- 0 sino tiene nada
       CASE WHEN g.cod_garantia in (3,4) then -- 3 HIPOTECAS, 4 PRENDAS
              nvl(g.nro_escritura,0)
            WHEN g.cod_garantia in (6,10) then -- 6 WARRANTS (FIBRAS), 10 WARRANTS (OTROS PRODUCTOS)
              1
            WHEN g.cod_garantia = 12 then -- 12 WARRANTS (GRANOS)
              2
            ELSE
              0
       END,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')),
       tg.descripcion,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado),
       tg.cod_modulo,
       tg.cod_modalidad,
       tg.cod_transaccion1 tra_computable,
       tg.cod_transaccion2 tra_no_computable,
       tg.computable,
       tg.pri_aplicacion
  from ge_entes e,
       pr_gar_tipos tg,
       ge_clientes c,
       pr_garantias g,
       ge_transacciones t,
       ge_tip_asientos ta

 where g.cod_persona = c.cod_persona
   and g.cod_garantia = tg.cod_garantia
   and g.cod_ent_escribania = e.cod_ente(+)
   and t.cod_transaccion = tg.cod_transaccion1
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and ta.cod_moneda = g.cod_moneda
   and g.estado in ('C','V') -- Confirmadas;
   and g.cod_garantia = 21 --PIGNORACION - PRENDA  PLAZA LOCAL
   and ta.tip_movimiento = 'D'
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.situacion IN ('D','L','E','R') and xg.estado IN ('C','V'))
   -- 2011-01-31 se filtran situacion 'D','L','E' y Estado V con cod 10,12,19 y 20 a Pedido del sr Marcelo Prono;

UNION
---SEGURO DE INCENDIO

       select pag_cal.fu_obt_fec_actual(1),
       g.cod_persona,
       --
       g.cod_garantia,
       --
       g.nro_garantia,
       g.cod_oficina,
       g.nro_referencia,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0),
       g.fec_inicio,
       g.fec_vencimiento,
       --
       g.cod_moneda,
       --
       nvl(g.valor,0),
       g.val_tasacion,
       'ITGF' OPERADOR,
       g.fec_ult_tasacion,
       -- Envía NRO_ESCRITURA cuando se trata de hipotecas o prendas.
       -- Si se trata de Warrants aquí tiene que ir el tipo de Warrant en donde 1 --> Otros.. 2 --> Granos
       -- 0 sino tiene nada
       CASE WHEN g.cod_garantia in (3,4) then -- 3 HIPOTECAS, 4 PRENDAS
              nvl(g.nro_escritura,0)
            WHEN g.cod_garantia in (6,10) then -- 6 WARRANTS (FIBRAS), 10 WARRANTS (OTROS PRODUCTOS)
              1
            WHEN g.cod_garantia = 12 then -- 12 WARRANTS (GRANOS)
              2
            ELSE
              0
       END,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')),
       tg.descripcion,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado),
       tg.cod_modulo,
       tg.cod_modalidad,
       tg.cod_transaccion1 tra_computable,
       tg.cod_transaccion2 tra_no_computable,
       tg.computable,
       tg.pri_aplicacion
  from ge_entes e,
       pr_gar_tipos tg,
       ge_clientes c,
       pr_garantias g,
       ge_transacciones t,
       ge_tip_asientos ta

 where g.cod_persona = c.cod_persona
   and g.cod_garantia = tg.cod_garantia
   and g.cod_ent_escribania = e.cod_ente(+)
   and t.cod_transaccion = tg.cod_transaccion1
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and ta.cod_moneda = g.cod_moneda
   and g.estado in ('C','V') -- Confirmadas;
   and g.cod_garantia = 22 --SEGURO DE INCENDIO
   and ta.tip_movimiento = 'D'
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.situacion IN ('D','L','E','R') and xg.estado IN ('C','V'))
   -- 2011-01-31 se filtran situacion 'D','L','E' y Estado V con cod 10,12,19 y 20 a Pedido del sr Marcelo Prono;

UNION

   select pag_cal.fu_obt_fec_actual(1),
       g.cod_persona ,
       --
       g.cod_garantia,
       --
       g.nro_garantia,
       g.cod_oficina,
       g.nro_referencia,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0),
       g.fec_inicio,
       g.fec_vencimiento,
       --
       g.cod_moneda,
       --
       nvl(g.valor,0),
       g.val_tasacion,
       'ITGF',
       g.fec_ult_tasacion,
       -- Envía NRO_ESCRITURA cuando se trata de hipotecas o prendas.
       -- Si se trata de Warrants aquí tiene que ir el tipo de Warrant en donde 1 --> Otros.. 2 --> Granos
       -- 0 sino tiene nada
       CASE WHEN g.cod_garantia in (3,4) then -- 3 HIPOTECAS, 4 PRENDAS
              nvl(g.nro_escritura,0)
            WHEN g.cod_garantia in (6,10) then -- 6 WARRANTS (FIBRAS), 10 WARRANTS (OTROS PRODUCTOS)
              1
            WHEN g.cod_garantia = 12 then -- 12 WARRANTS (GRANOS)
              2
            ELSE
              0
       END,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')),
       tg.descripcion,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado),
       tg.cod_modulo,
       tg.cod_modalidad,
       tg.cod_transaccion1 tra_computable,
       tg.cod_transaccion2 tra_no_computable,
       tg.computable,
       tg.pri_aplicacion
  from ge_entes e,
       pr_gar_tipos tg,
       ge_clientes c,
       pr_garantias g,
       ge_transacciones t,
       ge_tip_asientos ta

 where g.cod_persona = c.cod_persona
 and t.cod_transaccion = tg.cod_transaccion2
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and ta.cod_moneda = g.cod_moneda
   and g.cod_garantia = tg.cod_garantia
   and g.cod_ent_escribania = e.cod_ente(+)
   and t.cod_tip_asiento = ta.cod_tip_asiento
   and t.cod_modalidad = 61
   and g.estado in('C','V') -- Confirmadas
   and ta.tip_movimiento = 'D'
   and tg.cod_transaccion1 is null
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.situacion IN ('D','L','E','R') and xg.estado IN ('C','V'))
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.cod_garantia IN (10, 12, 19, 20 ) and xg.estado = 'V')
   -- 2011-01-31 se filtran situacion 'D','L','E' y Estado V con cod 10,12,19 y 20 a Pedido del sr Marcelo Prono
;

