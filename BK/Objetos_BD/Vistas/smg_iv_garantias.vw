create or replace force view it.smg_iv_garantias as
select to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMYY') NOVTIPO,--lpad(' ',4,' ') NOVTIPO,
       g.cod_persona CLIEN,
       --
       CASE WHEN g.cod_garantia = 3 then
            -- 1 HIP-PYG -> 3 HIPOTECAS (GS) -- 6 HIP-USD -> 3 HIPOTECAS (USD)
              decode(g.cod_moneda,'GS',1,'USD',6)
            WHEN g.cod_garantia = 4 then
            -- 2 PRE-PYG -> 4 PRENDAS (GS) -- 5 PRE-USD -> 4 PRENDAS (USD)
              decode(g.cod_moneda,'GS',2,'USD',5)
            WHEN g.cod_garantia in (6,7,10,12,14,16,18,19,20,22,23) then
            -- 11 --> (6)WARRANTS (FIBRAS) / (7)CAUCION DE DOCUMENTOS / (10)WARRANTS (OTROS PRODUCTOS) / (12)WARRANTS (GRANOS) / (14)SEGURO DE VIDA / (16)VALORES EN GARANTIA
            -- (18)CONTRA GARANTIA RECIBIDA / (19)AVALES Y FIANZAS / (20)AVALES Y FIANZAS - CONFORT LETTER / (22)SEGURO DE INCENDIO / (23)SEGURO DE AUTO
               11
            ELSE
             --10 PIGN.E/EL EXT.-> 9 PIGNORACION - DEP. EN EL EXTERIOR
             --9 PIGN. .. -> (21)PIGNORACION - PRENDA PLAZA LOCAL / (5)PIGNORACION
             decode(g.cod_garantia,9,10, 21,9,5,9)
       END MODAL,
       --
       g.nro_garantia NRO,
       g.cod_oficina SUC,
       --ta.cod_rubro CUENTA,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0) CUENTA,
       to_char(g.fec_inicio,'ddmmyy') FCHCONT,
       to_char(g.fec_vencimiento,'yyyymmdd') FCHVCONT,
       --
       decode(g.cod_moneda,'GS',0,'SEK',2,'BRL',3,'USD',5,
                         'CHF',7,'GBP',10,'JPY',14,'ARS',15,
                         'EUR',17,'UYU',20,'CAD',28,99) DIVI,
       --
       g.valor MONTO,
       g.val_tasacion TASACION,
       0 EXCESO,
       --nvl( g.valor,0) - FUB_OBT_MTO_COMPUTABLE(g.cod_moneda, g.nro_garantia) EXCESO,
       'ITGF' OPERADOR,
       to_char(g.fec_ult_tasacion,'ddmmyy') FCHTASAC,
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
       END NROESCRI,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')) ESCRIBANO,
       tg.descripcion DESCRIP,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado) desc_estado
       -- , '1' consulta
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
   --and nvl(tg.nom_tab_anexa,'xx') <> 'PR_GAR_AVALES'
   and tg.cod_garantia not in (21,22)
   and g.estado in ('C','V') -- Confirmadas;
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.situacion IN ('D','L','E','R') and xg.estado IN ('C','V'))
   and g.nro_garantia not in (select xg.nro_garantia from pr_garantias xg where xg.cod_garantia IN (10, 12, 19, 20 ) and xg.estado = 'V')
   -- 2011-01-31 se filtran situacion 'D','L','E' y Estado V con cod 10,12,19 y 20 a Pedido del sr Marcelo Prono;



UNION
--PIGNORACION - PRENDA  PLAZA LOCAL
      select to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMYY') NOVTIPO,--lpad(' ',4,' ') NOVTIPO,
       g.cod_persona CLIEN,
       --
       CASE WHEN g.cod_garantia = 3 then
            -- 1 HIP-PYG -> 3 HIPOTECAS (GS) -- 6 HIP-USD -> 3 HIPOTECAS (USD)
              decode(g.cod_moneda,'GS',1,'USD',6)
            WHEN g.cod_garantia = 4 then
            -- 2 PRE-PYG -> 4 PRENDAS (GS) -- 5 PRE-USD -> 4 PRENDAS (USD)
              decode(g.cod_moneda,'GS',2,'USD',5)
            WHEN g.cod_garantia in (6,7,10,12,14,16,18,19,20,22,23) then
            -- 11 --> (6)WARRANTS (FIBRAS) / (7)CAUCION DE DOCUMENTOS / (10)WARRANTS (OTROS PRODUCTOS) / (12)WARRANTS (GRANOS) / (14)SEGURO DE VIDA / (16)VALORES EN GARANTIA
            -- (18)CONTRA GARANTIA RECIBIDA / (19)AVALES Y FIANZAS / (20)AVALES Y FIANZAS - CONFORT LETTER / (22)SEGURO DE INCENDIO / (23)SEGURO DE AUTO
               11
            ELSE
             --10 PIGN.E/EL EXT.-> 9 PIGNORACION - DEP. EN EL EXTERIOR
             --9 PIGN. .. -> (21)PIGNORACION - PRENDA PLAZA LOCAL / (5)PIGNORACION
             decode(g.cod_garantia,9,10, 21,9,5,9)
       END MODAL,
       --
       g.nro_garantia NRO,
       g.cod_oficina SUC,
       --ta.cod_rubro CUENTA,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0) CUENTA,
       to_char(g.fec_inicio,'ddmmyy') FCHCONT,
       to_char(g.fec_vencimiento,'yyyymmdd') FCHVCONT,
       --
       decode(g.cod_moneda,'GS',0,'SEK',2,'BRL',3,'USD',5,
                         'CHF',7,'GBP',10,'JPY',14,'ARS',15,
                         'EUR',17,'UYU',20,'CAD',28,99) DIVI,
       --
       g.valor MONTO,
       g.val_tasacion TASACION,
       0 EXCESO,
       -- nvl( g.valor,0) - FUB_OBT_MTO_COMPUTABLE(g.cod_moneda, g.nro_garantia) EXCESO,
       'ITGF' OPERADOR,
       to_char(g.fec_ult_tasacion,'ddmmyy') FCHTASAC,
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
       END NROESCRI,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')) ESCRIBANO,
       tg.descripcion DESCRIP,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado) desc_estado
      -- ,'3' consulta
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

       select to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMYY') NOVTIPO,--lpad(' ',4,' ') NOVTIPO,
       g.cod_persona CLIEN,
       --
       CASE WHEN g.cod_garantia = 3 then
            -- 1 HIP-PYG -> 3 HIPOTECAS (GS) -- 6 HIP-USD -> 3 HIPOTECAS (USD)
              decode(g.cod_moneda,'GS',1,'USD',6)
            WHEN g.cod_garantia = 4 then
            -- 2 PRE-PYG -> 4 PRENDAS (GS) -- 5 PRE-USD -> 4 PRENDAS (USD)
              decode(g.cod_moneda,'GS',2,'USD',5)
            WHEN g.cod_garantia in (6,7,10,12,14,16,18,19,20,22,23) then
            -- 11 --> (6)WARRANTS (FIBRAS) / (7)CAUCION DE DOCUMENTOS / (10)WARRANTS (OTROS PRODUCTOS) / (12)WARRANTS (GRANOS) / (14)SEGURO DE VIDA / (16)VALORES EN GARANTIA
            -- (18)CONTRA GARANTIA RECIBIDA / (19)AVALES Y FIANZAS / (20)AVALES Y FIANZAS - CONFORT LETTER / (22)SEGURO DE INCENDIO / (23)SEGURO DE AUTO
               11
            ELSE
             --10 PIGN.E/EL EXT.-> 9 PIGNORACION - DEP. EN EL EXTERIOR
             --9 PIGN. .. -> (21)PIGNORACION - PRENDA PLAZA LOCAL / (5)PIGNORACION
             decode(g.cod_garantia,9,10, 21,9,5,9)
       END MODAL,
       --
       g.nro_garantia NRO,
       g.cod_oficina SUC,
       --ta.cod_rubro CUENTA,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0) CUENTA,
       to_char(g.fec_inicio,'ddmmyy') FCHCONT,
       to_char(g.fec_vencimiento,'yyyymmdd') FCHVCONT,
       --
       decode(g.cod_moneda,'GS',0,'SEK',2,'BRL',3,'USD',5,
                         'CHF',7,'GBP',10,'JPY',14,'ARS',15,
                         'EUR',17,'UYU',20,'CAD',28,99) DIVI,
       --
       g.valor MONTO,
       g.val_tasacion TASACION,
       0 EXCESO,
        --nvl( g.valor,0) - FUB_OBT_MTO_COMPUTABLE(g.cod_moneda, g.nro_garantia) EXCESO,
       'ITGF' OPERADOR,
       to_char(g.fec_ult_tasacion,'ddmmyy') FCHTASAC,
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
       END NROESCRI,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')) ESCRIBANO,
       tg.descripcion DESCRIP,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado) desc_estado
      -- ,'4' consulta
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

   select to_char(pag_cal.fu_obt_fec_actual(1), 'DDMMYY') NOVTIPO,
       g.cod_persona CLIEN,
       --
       CASE WHEN g.cod_garantia = 3 then
            -- 1 HIP-PYG -> 3 HIPOTECAS (GS) -- 6 HIP-USD -> 3 HIPOTECAS (USD)
              decode(g.cod_moneda,'GS',1,'USD',6)
            WHEN g.cod_garantia = 4 then
            -- 2 PRE-PYG -> 4 PRENDAS (GS) -- 5 PRE-USD -> 4 PRENDAS (USD)
              decode(g.cod_moneda,'GS',2,'USD',5)
            WHEN g.cod_garantia in (6,7,10,12,14,16,18,19,20,22,23) then
            -- 11 --> (6)WARRANTS (FIBRAS) / (7)CAUCION DE DOCUMENTOS / (10)WARRANTS (OTROS PRODUCTOS) / (12)WARRANTS (GRANOS) / (14)SEGURO DE VIDA / (16)VALORES EN GARANTIA
            -- (18)CONTRA GARANTIA RECIBIDA / (19)AVALES Y FIANZAS / (20)AVALES Y FIANZAS - CONFORT LETTER / (22)SEGURO DE INCENDIO / (23)SEGURO DE AUTO
               11
            ELSE
             --10 PIGN.E/EL EXT.-> 9 PIGNORACION - DEP. EN EL EXTERIOR
             --9 PIGN. .. -> (21)PIGNORACION - PRENDA PLAZA LOCAL / (5)PIGNORACION
             decode(g.cod_garantia,9,10, 21,9,5,9)
       END MODAL,
       --
       g.nro_garantia NRO,
       g.cod_oficina SUC,

       --ta.cod_rubro CUENTA,
       nvl(PAI_INT.fu_obt_cta_contable(ta.cod_rubro),0) CUENTA,
       to_char(g.fec_inicio,'ddmmyy') FCHCONT,
       to_char(g.fec_vencimiento,'yyyymmdd') FCHVCONT,
       --
       decode(g.cod_moneda,'GS',0,'SEK',2,'BRL',3,'USD',5,
                         'CHF',7,'GBP',10,'JPY',14,'ARS',15,
                         'EUR',17,'UYU',20,'CAD',28,99) DIVI,
       --
       g.valor MONTO,
       g.val_tasacion TASACION,
       0 EXCESO,
       -- 0/*nvl( g.valor,0) - FUB_OBT_MTO_COMPUTABLE(g.cod_moneda, g.nro_garantia)*/ EXCESO,
       'ITGF' OPERADOR,
       to_char(g.fec_ult_tasacion,'ddmmyy') FCHTASAC,
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
       END NROESCRI,
       --
       nvl(substr(e.descripcion,1,50), lpad(' ',50,' ')) ESCRIBANO,
       tg.descripcion DESCRIP,
       g.estado,
       fue_obt_des_refcodes('EST_GARANTIA', g.estado) desc_estado
      -- ,'2' consulta
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

