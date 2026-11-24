create or replace procedure it.PRB_INS_CB_BAL_IMPOSITIVO is
cursor activo is
select COD_RUBRO,
decode(substr(cod_rubro,3,3),'000', upper(descripcion),fue_obt_titulo(DESCRIPCION)) descripcion,
DECODE(COD_RUBRO, '100000000000000',1,
'110000000000000',2,
'110100000000000',3,
'110201050000000',4,
'110200000000000',5,
'110800000000000',6,
'110900000000000',7,
'120000000000000',8,
'130000000000000',9,
'130100000000000',10,
'130800000000000',11,
'140000000000000',12,
'140100000000000',13,
'140800000000000',14,
'140700000000000',15,
'140900000000000',16,
'150000000000000',17,
'160000000000000',18,
'160100000000000',19,
'160800000000000',20,
'160700000000000',21,
'160900000000000',22,
'170000000000000',23,
'170200000000000',24,
'170100000000000',25,
'170900000000000',26,
'180000000000000',27,
'180100000000000',28,
'190000000000000',29) nro_orden,
decode(substr(cod_rubro,3,3),'000',1,0) resaltar, 'A' tipo
from cb_rubros
where COD_RUBRO IN ('100000000000000','110000000000000','110100000000000',
                    '110201050000000','110200000000000','110800000000000',
                    '110900000000000','120000000000000','130000000000000',
                    '130100000000000','130800000000000','140000000000000',
                    '140100000000000','140800000000000','140700000000000',
                    '140900000000000','150000000000000','160000000000000',
                    '160100000000000','160800000000000','160700000000000',
                    '160900000000000','170000000000000','170200000000000',
                    '170100000000000','170900000000000','180000000000000',
                    '180100000000000','190000000000000')
                    -- ACTIVO

--OR (DESCRIPCION LIKE '%CARGOS%' AND COD_RUBRO LIKE '1%')
ORDER BY nro_orden;
--begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
-- PASIVO
cursor pasivo is
select COD_RUBRO,
decode(substr(cod_rubro,3,3),'000', upper(descripcion),
fue_obt_titulo(DESCRIPCION)) descripcion,
DECODE(COD_RUBRO, '200000000000000',30,
                  '210000000000000',31,
                  '210101000000000',32,
                  '210100000000000',33,
                  '210800000000000',34,
                  '220000000000000',35,
                  '220100000000000',36,
                  '220600000000000',37,
                  '220200000000000',38,
                  '220800000000000',39,
                  '240000000000000',40,
                  '240100000000000',41,
                  '240200000000000',42,
                  '240400000000000',43,
                  '250100000000000',44,
                  '250200000000000',45) nro_orden,
decode(substr(cod_rubro,3,3),'000',1,0) resaltar,'P' tipo
from cb_rubros
where COD_RUBRO IN ('200000000000000','210000000000000','210101000000000','210100000000000','210800000000000',
                    '220000000000000','220100000000000','220600000000000','220200000000000','220800000000000',
                    '240000000000000','240100000000000','240200000000000','240400000000000','250100000000000',
                    '250200000000000')
--OR (DESCRIPCION LIKE '%CARGOS%' AND COD_RUBRO LIKE '1%')
ORDER BY nro_orden;
-- PATRIMONIO
cursor patrimonio is
select COD_RUBRO,
decode(substr(cod_rubro,3,3),'000', upper(descripcion),
fue_obt_titulo(DESCRIPCION)) descripcion,
DECODE(COD_RUBRO, '300000000000000',46,
                  '310100000000000',47,
                  '310200000000000',48,
                  '310300000000000',49,
                  '310400000000000',50,
                  '310500000000000',51,
                  '310600000000000',52) nro_orden,
decode(substr(cod_rubro,3,3),'000',1,0) resaltar, 'PA' tipo
from cb_rubros
where COD_RUBRO IN ('300000000000000',
                    '310100000000000',
                    '310200000000000',
                    '310300000000000',
                    '310400000000000',
                    '310500000000000',
                    '310600000000000')
--OR (DESCRIPCION LIKE '%CARGOS%' AND COD_RUBRO LIKE '1%')
ORDER BY nro_orden;
cursor resultado is
-- RESULTADO
select COD_RUBRO,
decode(substr(cod_rubro,3,3),'000', upper(descripcion),
fue_obt_titulo(DESCRIPCION)) descripcion,
DECODE(COD_RUBRO, '610000000000000',53,
                  '610100000000000',54,
                  '610200000000000',55,
                  '610300000000000',56,
                  '610600000000000',57,
                  '710000000000000',58,
                  '710100000000000',59,
                  '710200000000000',60,
                  '710400000000000',61,
                  '710600000000000',62,
                  '710500000000000',65,
                  '610800000000000',66,
                  '620000000000000',69,
                  '720000000000000',71,
                  '630000000000000',72,
                  '630100000000000',73,
                  '630200000000000',74,
                  '630300000000000',75,
                  '630400000000000',76,
                  '730000000000000',77,
                  '730100000000000',78,
                  '730200000000000',79,
                  '640000000000000',80,
                  '740000000000000',81,
                  '600000000000000',82,
                  '700000000000000',83,
                  '730107690200000',84)  nro_orden,
decode(substr(cod_rubro,3,3),'000',1,0) RESALTAR, 'R' tipo
from cb_rubros
where COD_RUBRO IN ('610000000000000','610100000000000','610200000000000','610300000000000',
                    '610600000000000','710000000000000','710100000000000','710200000000000',
                    '710400000000000','710600000000000',
                    '710500000000000','610800000000000','620000000000000','720000000000000',
                    '630000000000000','630100000000000','630200000000000','630300000000000','630400000000000',
                    '730000000000000','730100000000000','730200000000000','640000000000000','740000000000000',
                    '600000000000000','700000000000000','730107690200000')
                    -- '600000000000000' ganancia
                    -- '700000000000000' perdida
                    -- '730107690200000' impuesto a la renta
ORDER BY nro_orden;
begin
  --Eliminar Registros Anteriores--
  delete from cb_bal_impositivo;

  --Ciclo para Insertar Datos--
  for ctas in activo loop
    insert into cb_bal_impositivo
              (cod_rubro,
               descripcion,
               nro_orden,
               resaltar,
               tipo)
        values
              (ctas.cod_rubro,
               ctas.descripcion,
               ctas.nro_orden,
               ctas.resaltar,
               ctas.tipo);
  end loop;
  for ctas in pasivo loop
    insert into cb_bal_impositivo
              (cod_rubro,
               descripcion,
               nro_orden,
               resaltar,
               tipo)
        values
              (ctas.cod_rubro,
               ctas.descripcion,
               ctas.nro_orden,
               ctas.resaltar,
               ctas.tipo);
  end loop;
  for ctas in patrimonio loop
    insert into cb_bal_impositivo
              (cod_rubro,
               descripcion,
               nro_orden,
               resaltar,
               tipo)
        values
              (ctas.cod_rubro,
               ctas.descripcion,
               ctas.nro_orden,
               ctas.resaltar,
               ctas.tipo);
  end loop;
  for ctas in resultado loop
    insert into cb_bal_impositivo
              (cod_rubro,
               descripcion,
               nro_orden,
               resaltar,
               tipo)
        values
              (ctas.cod_rubro,
               ctas.descripcion,
               ctas.nro_orden,
               ctas.resaltar,
               ctas.tipo);
  end loop;

  --Insertar los registros que faltan--
  insert into cb_bal_impositivo
   (cod_rubro, descripcion, nro_orden,
    resaltar, tipo)
    SELECT NULL, 'RESULTADO FINANCIERO ANTES DE PREVISIONES', 63 ORDEN, 1, 'R' tipo  FROM DUAL
    UNION
    SELECT NULL, 'PREVISIONES', 64 nro_orden, 1, 'R' tipo  FROM DUAL
    UNION
    SELECT NULL, 'RESULTADO FINANCIERO DESPUES DE PREVISIONES', 67 nro_orden, 1, 'R' tipo  FROM DUAL
    UNION
    SELECT NULL, 'RESULTADOS POR SERVICIOS', 68 nro_orden, 1, 'R' tipo  FROM DUAL
    UNION
    SELECT NULL, 'RESULTADOS BRUTO', 70 nro_orden, 1, 'R' tipo  FROM DUAL;
end;
/

