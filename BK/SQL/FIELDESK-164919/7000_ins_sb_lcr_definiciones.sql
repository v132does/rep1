begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

truncate table it.sb_lcr_definiciones;

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (23, 4, 1, 3, 'Encaje legal', 'Encaje legal', 100.00, 'select ''Encaje Legal'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''110201050200000'',''110201050400000'',''110201050600000'',''110201052400000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Encaje Legal'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro  in (''110201050200000'',''110201050400000'',''110201050600000'',''110201052400000'')
  and sc.fecha = '||'&'||'FECHA', 293, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (93, 87, 2, 1, 'Vista ', 'Vista ', 40.00, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-MENOS ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 7', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-MENOS ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 7', 338, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (94, 87, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 40.00, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-MENOS ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 7', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-MENOS ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 7', 339, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (88, 70, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 6', 340, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (72, 39, 2, 2, 'Entidades públicas y privadas no residentes del SNF', 'Entidades públicas y privadas no residentes del SNF', 40.00, null, null, null, null, null, null, 343, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (68, 37, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 6', 325, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (1, 95, 1, 1, 'ACTIVOS LÍQUIDOS DE ALTA CALIDAD ', 'ACTIVOS LÍQUIDOS DE ALTA CALIDAD ', 0.00, null, null, null, null, null, null, 288, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (2, null, 2, 1, 'SALIDA DE EFECTIVO', 'SALIDA DE EFECTIVO', 0.00, null, null, null, null, null, null, 307, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (3, null, 3, 1, 'ENTRADAS DE EFECTIVO', 'ENTRADAS DE EFECTIVO', 0.00, null, null, null, null, null, null, 367, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (4, 1, 1, 1, 'Activos de Nivel 1', 'Activos de Nivel 1', 0.00, null, null, null, null, null, null, 299, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (5, 1, 1, 2, 'Nivel 2 "A" (no podrá superar el 40% del total del Fondo ALAC)', 'Nivel 2 "A" (no podrá superar el 40% del total del Fondo ALAC)', 0.00, null, null, null, null, null, null, 298, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (6, 1, 1, 3, 'Nivel 2 "B" (no podrá superar el 15% del total del Fondo ALAC)', 'Nivel 2 "B" (no podrá superar el 15% del total del Fondo ALAC)', 0.00, null, null, null, null, null, null, 302, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (7, 2, 2, 2, 'Depósitos  Minoristas', 'Depósitos  Minoristas', 0.00, null, null, null, null, null, null, 309, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (8, 2, 2, 3, 'Depósitos Mayoristas', 'Depósitos Mayoristas', 0.00, null, null, null, null, null, null, 317, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (9, 2, 2, 5, 'Financiación Mayorista Garantizada', 'Financiación Mayorista Garantizada', 0.00, null, null, null, null, null, null, 351, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (10, 2, 2, 6, 'Financiación Mayorista no Garantizada', 'Financiación Mayorista no Garantizada', 0.00, null, null, null, null, null, null, 356, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (11, 2, 2, 7, 'Salidas de efectivo contingentes', 'Salidas de efectivo contingentes', 0.00, null, null, null, null, null, null, 361, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (14, 3, 3, 1, 'Entradas relacionadas con créditos garantizados, incluidos repos a la inversa', 'Entradas relacionadas con créditos garantizados, incluidos repos a la inversa', 0.00, null, null, null, null, null, null, 368, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (15, 3, 3, 2, 'Entradas relacionadas con créditos no garantizados', 'Entradas relacionadas con créditos no garantizados', 0.00, null, null, null, null, null, null, 373, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (17, 3, 3, 4, 'Entradas relacionadas con valores representativos de deuda ', 'Entradas relacionadas con valores representativos de deuda ', 100.00, null, null, null, null, null, null, 377, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (18, 3, 3, 5, 'Facilidades de crédito o de liquidez concedidas al banco declarante', 'Facilidades de crédito o de liquidez concedidas al banco declarante', 0.00, null, null, null, null, null, null, 381, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (20, 3, 3, 7, 'Otras entradas no contempladas ', 'Otras entradas no contempladas ', 50.00, null, null, null, null, null, null, 383, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (26, 4, 1, 6, 'Valores representativos de deuda en ME emitidos por gobiernos nacionales y entidades financieras', 'Valores representativos de deuda en moneda extranjera emitidos por gobiernos nacionales y entidades financieras del exterior calificados en una categoría igual o superior a AA- o equivalente.', 100.00, null, null, null, null, null, null, 296, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (27, 4, 1, 7, 'Valores representativos de deuda en ML y ME emitidos por organismos multilaterales de crédito', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por organismos multilaterales de crédito calificados en una categoría igual o superior a AA- o equivalente.', 100.00, null, null, null, null, null, null, 297, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (28, 5, 1, 1, 'Valores representativos de deuda en ME emitidos por gobiernos nacionales y entidades financieras', 'Valores representativos de deuda en moneda extranjera emitidos por gobiernos nacionales y entidades financieras del exterior calificados en una categoría entre A+ y A- o equivalente. ', 85.00, null, null, null, null, null, null, 300, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (29, 5, 1, 2, 'Valores representativos de deuda en ML y extranjera emitidos por organismos multilaterales de crédit', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por organismos multilaterales de crédito calificados en una categoría entre A+ y A- o equivalente. ', 85.00, null, null, null, null, null, null, 301, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (30, 6, 1, 1, 'Valores representativos de deuda en ML y extranjera emitidos por entidades del sector público', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por entidades del sector público nacional no financiero', 50.00, null, null, null, null, null, null, 303, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (31, 6, 1, 2, 'Valores representativos de deuda en ME emitidos por gobiernos nacionales y entidades financieras', 'Valores representativos de deuda en moneda extranjera emitidos por gobiernos nacionales y entidades financieras del exterior calificados en una categoría entre BBB+ y BBB- o equivalente.', 50.00, null, null, null, null, null, null, 304, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (32, 6, 1, 3, 'Valores representativos de deuda en ML y extranjera emitidos por organismos multilaterales de crédit', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por organismos multilaterales de crédito calificados en una categoría entre BBB+ y BBB- o equivalente.', 50.00, null, null, null, null, null, null, 305, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (33, 6, 1, 4, 'Valores representativos de deuda en ML emitidos por empresas del sector no financiero', 'Valores representativos de deuda en moneda nacional emitidos por empresas del sector no financiero, calificados en una categoría igual o superior a BBB- o equivalente', 50.00, null, null, null, null, null, null, 306, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (34, 7, 2, 1, 'Estables ', 'Estables ', 5.00, null, null, null, null, null, null, 316, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (35, 7, 2, 2, 'Menos Estables', 'Menos Estables', 10.00, null, null, null, null, null, null, 312, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (36, 7, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, 'select ''SAL. EFE. - MINORISTA - DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE. - MINORISTA - DEPOSITOS PLAZO R. SUPERIOR A 30 DIAS'' concepto, sum(r.sal_res_gs) sal_mon_loc, sum(r.sal_res_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 6', 315, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (37, 8, 2, 1, 'Menores a 500 Salarios mínimos mensuales ', 'Menores a 500 Salarios mínimos mensuales ', 0.00, null, null, null, null, null, null, 318, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (38, 8, 2, 2, 'Iguales o mayores  a 500 Salarios mínimos mensuales ', 'Iguales o mayores  a 500 Salarios mínimos mensuales ', 0.00, null, null, null, null, null, null, 326, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (39, 8, 2, 3, 'Otras', 'Otras', 0.00, null, null, null, null, null, null, 341, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (41, 9, 2, 2, 'Con ALAC de nivel 2A', 'Con ALAC de nivel 2A', 15.00, null, null, null, null, null, null, 353, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (42, 9, 2, 3, 'Con ALAC de nivel 2B', 'Con ALAC de nivel 2B', 50.00, null, null, null, null, null, null, 354, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (43, 9, 2, 4, 'Por otro colateral', 'Por otro colateral', 100.00, null, null, null, null, null, null, 355, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (44, 10, 2, 1, 'Bancos Multilaterales', 'Bancos Multilaterales', 100.00, null, null, null, null, null, null, 357, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (46, 10, 2, 3, 'Bonos emitidos', 'Bonos emitidos', 100.00, 'select ''Bonos emitidos'' concepto, sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
             sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
             sum(case when l.moneda = 6100 then l.monto * '||'&'||'VAL_COTIZACION else 0 end ) sal_mon_ext
      from it.sb_lcr_liq_inv_tmp l
      where l.cod_rubro in (''2206021801'',''2206026601'')
        and l.plazo     <= 30
      group by substr(l.cod_rubro,1,10), l.moneda, l.plazo) con', null, null, null, null, 'select ''Bonos emitidos'' concepto,
       abs(sum(case when d.cod_moneda = 6900 then d.importe else 0 end)) sal_mon_loc,
       abs(sum(case when d.cod_moneda = 6100 then (d.importe * '||'&'||'VAL_COTIZACION) else 0 end )) sal_mon_ext
from sb_liq_diarios d
where d.cod_cuenta in (''2206021801'',''2206026601'')
  and d.fecha      = '||'&'||'FECHA
  and d.plazo      <= 30', 359, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (50, 11, 2, 3, 'Otras operaciones contingentes no contenidas en e.1 y e.2', 'Otras operaciones contingentes no contenidas en e.1 y e.2', 2.00, null, null, null, null, null, null, 364, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (52, 14, 2, 2, 'ALAC Nivel 2A ', 'ALAC Nivel 2A ', 15.00, null, null, null, null, null, null, 370, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (53, 14, 2, 3, 'ALAC Nivel 2B', 'ALAC Nivel 2B', 50.00, null, null, null, null, null, null, 371, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (54, 14, 2, 4, 'Cash Collateral ', 'Cash Collateral ', 100.00, null, null, null, null, null, null, 372, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (57, 17, 2, 1, 'Valores que no pudieron ser calificados como ALAC en ninguna de las categorías establecidas.', 'Valores que no pudieron ser calificados como ALAC en ninguna de las categorías establecidas.', 0.00, null, null, null, null, null, null, 378, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (80, 66, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 5.00, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 6', 321, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (81, 67, 2, 1, 'Vista ', 'Vista ', 10.00, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-MENOS ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 7', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-MENOS ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 7', 323, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (82, 67, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 10.00, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-MENOS ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 7', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-MENOS ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 7', 324, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (83, 69, 2, 1, 'Estables ', 'Estables ', 5.00, null, null, null, null, null, null, 328, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (84, 69, 2, 2, 'Menos estables ', 'Menos estables ', 25.00, null, null, null, null, null, null, 330, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (85, 69, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 25.00, null, null, null, null, null, null, 332, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (86, 70, 2, 1, 'Estables ', 'Estables ', 20.00, null, null, null, null, null, null, 334, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (87, 70, 2, 2, 'Menos Estables ', 'Menos Estables ', 40.00, null, null, null, null, null, null, 337, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (89, 83, 2, 1, 'Vista ', 'Vista ', 5.00, null, null, null, null, null, null, 329, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (90, 84, 2, 1, 'Vista ', 'Vista ', 25.00, null, null, null, null, null, null, 331, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (92, 86, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 20.00, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-ESTABLE-DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 6', 336, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (47, 10, 2, 4, 'Acreedores ', 'Acreedores ', 100.00, 'select ''Acreedores'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  = ''240400000000000''
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Acreedores'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro = ''240400000000000''
  and sc.fecha = '||'&'||'FECHA', 360, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (58, 17, 2, 2, 'Activos de Nivel 1 y Nivel 2 que no sean admisibles como HQLA por requisitos operativos.', 'Activos de Nivel 1 y Nivel 2 que no sean admisibles como HQLA por requisitos operativos.', 0.00, null, null, null, null, null, null, 379, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (59, 17, 2, 3, 'Valores clasificados como ALAC de Nivel 2, por el porcentaje no computado.', 'Valores clasificados como ALAC de Nivel 2, por el porcentaje no computado.', 0.00, null, null, null, null, null, null, 380, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (60, 20, 2, 1, 'CDAs con IFIs', 'CDAs con IFIs', 50.00, 'select ''CDAs con IFIs'' concepto, sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
             sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
             sum(case when l.moneda = 6100 then l.monto * '||'&'||'VAL_COTIZACION else 0 end ) sal_mon_ext
      from it.sb_lcr_liq_inv_tmp l
      where (l.cod_rubro like ''1301013104%'' or l.cod_rubro like ''1301013102%'' or l.cod_rubro like ''1301013106%'' or l.cod_rubro like ''1308%'')
        and l.plazo     <= 30
      group by substr(l.cod_rubro,1,10), l.moneda, l.plazo) con', null, null, null, null, 'select ''CDAs con IFIs'' concepto,
       abs(sum(case when d.cod_moneda = 6900 then d.importe else 0 end)) sal_mon_loc,
       abs(sum(case when d.cod_moneda = 6100 then (d.importe * '||'&'||'VAL_COTIZACION) else 0 end )) sal_mon_ext
from sb_liq_diarios d
where d.cod_cuenta in (''1301013104'',''1301013102'',''1301013106'',''1308000000'')
  and d.fecha      = '||'&'||'FECHA
  and d.plazo      <= 30', 384, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (16, 3, 3, 3, 'Depósitos operativos mantenidos en otras instituciones financieras tanto locales como del exterior', 'Depósitos operativos mantenidos en otras instituciones financieras tanto locales como del exterior', 0.00, 'select ''Dep. operativos mantenidos en otras instit. finan. loc. como del ext.'' concepto,
       abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
       round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
from cb_sim_sal_consolidados sc
where sc.cod_rubro  = ''110201090000000''
  and sc.ano = '||'&'||'ANIO
  and sc.mes = '||'&'||'MES', null, null, null, null, 'select ''Dep. operativos mantenidos en otras instit. finan. loc. como del ext.'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro = ''110201090000000''
  and sc.fecha = '||'&'||'FECHA', 376, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (55, 15, 2, 1, 'Créditos vigentes ', 'Créditos vigentes ', 50.00, 'select ''Créditos vigentes'' concepto, sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
             sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
             sum(case when l.moneda = 6100 then l.monto * '||'&'||'VAL_COTIZACION else 0 end ) sal_mon_ext
      from it.sb_lcr_liq_inv_tmp l
      where (l.cod_rubro like ''14010169%'' or l.cod_rubro like ''14010173%'' or l.cod_rubro like ''14010183%'' or l.cod_rubro like ''14010205%'' or
             l.cod_rubro like ''14010209%'' or l.cod_rubro like ''14010351%'' or l.cod_rubro like ''14010405%'' or l.cod_rubro like ''14010433%'' or
             l.cod_rubro like ''14010443%'' or l.cod_rubro like ''14010449%'' or l.cod_rubro like ''14010187%'' or l.cod_rubro like ''14010189%'' or
             l.cod_rubro like ''14040215%'' or l.cod_rubro like ''14080225%'' or l.cod_rubro like ''14080447%'' or l.cod_rubro like ''14080451%'' or
             l.cod_rubro like ''14080229%'')
        and l.plazo     <= 30
      group by substr(l.cod_rubro,1,10), l.moneda, l.plazo) con', null, null, null, null, 'select ''Créditos vigentes'' concepto,
       abs(sum(case when d.cod_moneda = 6900 then d.importe else 0 end)) sal_mon_loc,
       abs(sum(case when d.cod_moneda = 6100 then (d.importe * '||'&'||'VAL_COTIZACION) else 0 end )) sal_mon_ext
from sb_liq_diarios d
where d.cod_cuenta in (''1401016900'',''1401017300'',''1401018300'',''1401020500'',''1401020900'',''1401035100'',
                       ''1401040500'',''1401043300'',''1401044300'',''1401044900'',''1401018700'',''1401018900'',
                       ''1404021500'',''1408022500'',''1408044700'',''1408045100'',''1408022900'')
  and d.fecha      = '||'&'||'FECHA
  and d.plazo      <= 30', 374, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (62, 34, 2, 1, 'Vista', 'Vista', 5.00, 'select ''SAL. EFE. - MINORISTA - ESTABLE - VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE. - MINORISTA - ESTABLE - VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 6', 310, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (63, 34, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días', 'Depósitos con un plazo residual menor o igual a 30 días', 5.00, 'select ''SAL. EFE. - MINORISTA - ESTABLE - DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE. - MINORISTA - ESTABLE - DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 6', 311, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (64, 35, 2, 1, 'Vista', 'Vista', 10.00, 'select ''SAL. EFE. - MINORISTA - MENOS ESTABLE - VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 7', null, null, null, null, 'select ''SAL. EFE. - MINORISTA - MENOS ESTABLE - VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 7', 313, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (65, 35, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días', 'Depósitos con un plazo residual menor o igual a 30 días', 10.00, 'select ''SAL. EFE. - MINORISTA - MENOS ESTABLE - DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 7', null, null, null, null, 'select ''SAL. EFE. - MINORISTA - MENOS ESTABLE - DEPOSITOS PLAZO R. MENOR O IGUAL A 30 DIAS'' concepto, sum(sal_plazo_gs) sal_mon_loc, sum(sal_plazo_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 1
  and r.categoria = 3
  and r.grupo     = 7', 314, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (66, 37, 2, 1, 'Estables ', 'Estables ', 5.00, null, null, null, null, null, null, 319, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (69, 38, 2, 1, 'Depósitos operativos ', 'Depósitos operativos ', 0.00, null, null, null, null, null, null, 327, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (70, 38, 2, 2, 'Depósitos  no operativos ', 'Depósitos  no operativos ', 0.00, null, null, null, null, null, null, 333, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (79, 66, 2, 1, 'Vista ', 'Vista ', 5.00, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- <500 SAL.MINIMO-ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 4
  and r.grupo     = 6', 320, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (75, 39, 2, 5, 'Seguridad Social ', 'Seguridad Social ', 100.00, 'select ''Seguridad Social'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''210101021800000'',''210101961800000'',''210102841800000'',''220402920600000'',''220402380600000'',''220402900600000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Seguridad Social'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''210101021800000'',''210101961800000'',''210102841800000'',''220402920600000'',''220402380600000'',''220402900600000'')
  and sc.fecha = '||'&'||'FECHA', 346, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (78, 39, 2, 8, 'Agentes Fiduciarios', 'Agentes Fiduciarios', 100.00, 'select ''Agentes Fiduciarios'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  = ''230103020010000''
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Agentes Fiduciarios'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro = ''230103020010000''
  and sc.fecha = '||'&'||'FECHA', 349, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (48, 11, 2, 1, 'Importe no utilizado de las facilidades de crédito (líneas de crédito)', 'Importe no utilizado de las facilidades de crédito (líneas de crédito) y liquidez acordadas incondicionalmente revocables y cancelables incondicionalmente por la institución', 2.00, 'select ''Imp. no util. de las facilidades de créd. y liquidez'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''420106160000000'',''420106140000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Imp. no util. de las facilidades de créd. y liquidez'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''420106160000000'',''420106140000000'')
  and sc.fecha = '||'&'||'FECHA', 362, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (21, 4, 1, 1, 'Caja ', 'Caja ', 100.00, 'select ''Caja'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
                     round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  = ''110100000000000''
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES)x', null, null, null, null, 'select ''Caja'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro  = ''110100000000000''
  and sc.fecha = '||'&'||'FECHA', 289, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (77, 39, 2, 7, 'Compañías de Seguros ', 'Compañías de Seguros ', 100.00, 'select ''Compañías de Seguros'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''210101022000000'',''210101962000000'',''210102842000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Compañías de Seguros'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''210101022000000'',''210101962000000'',''210102842000000'')
  and sc.fecha = '||'&'||'FECHA', 348, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (76, 39, 2, 6, 'Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)', 'Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)', 100.00, 'select ''Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)'' concepto,
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
  and cu.estado        <> ''T''', null, null, null, null, 'select ''Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)'' concepto,
       sum(case when c.cod_moneda = ''GS'' THEN d.sal_actual else 0 end) sal_gs,
       sum(case when c.cod_moneda <> ''GS'' THEN round((d.sal_actual * '||'&'||'VAL_COTIZACION),0) else 0 end) sal_ext
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
  and cu.estado        <> ''T''', 347, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (13, 2, 2, 9, 'Otras salidas no contempladas', 'Otras salidas no contempladas', 100.00, 'select ''Otras salidas no contempladas'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''240102460000000'',''240102440100000'',''240202520106099'',''240202520107099'',''220101460000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Otras salidas no contempladas'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''240102460000000'',''240102440100000'',''240202520106099'',''240202520107099'',''220101460000000'')
  and sc.fecha = '||'&'||'FECHA', 366, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (22, 4, 1, 2, 'Cuentas corrientes en BCP', 'Cuentas corrientes en BCP', 100.00, 'select ''Cuentas Corrientes'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''110201051000000'',''111201051800001'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Cuentas Corrientes'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro  in (''110201051000000'',''111201051800001'')
  and sc.fecha = '||'&'||'FECHA', 292, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (24, 4, 1, 4, 'Depósitos por Operación Monetaria ', 'Depósitos por Operación Monetaria ', 100.00, 'select ''Depósitos por Oper.'' tip_activo, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  = ''110201053400000''
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Depósitos por Oper.'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro  = ''110201053400000''
  and sc.fecha = '||'&'||'FECHA', 294, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (25, 4, 1, 5, 'Valores Públicos nacionales en ML emitidos por el BCP y valores públicos nacionales en ML', 'Valores Públicos nacionales en moneda nacional emitidos por el BCP y valores públicos nacionales en moneda nacional y extranjera emitidos por el Gobierno Nacional Paraguayo', 100.00, 'select ''Val. Públicos Nac. moneda nac. - BCP y val. públicos nac. mon. nac. y ext. - Gob. Nac. Pyo.'' concepto,
       sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''120101230200000'',''120101230600000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Val. Públicos Nac. moneda nac. - BCP y val. públicos nac. mon. nac. y ext. - Gob. Nac. Pyo.'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''120101230200000'',''120101230600000'')
  and sc.fecha = '||'&'||'FECHA', 295, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (91, 86, 2, 1, 'Vista ', 'Vista ', 20.00, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 6', null, null, null, null, 'select ''SAL. EFE.-MAYORISTA- >=500 SAL.MINIMO-ESTABLE-VISTA'' concepto, sum(sal_vista_gs) sal_mon_loc, sum(sal_vista_ext) sal_mon_ext
from it.sv_salida_de_efectivo_res r
where r.fecha     = '||'&'||'FECHA
  and r.deposito  = 2
  and r.categoria = 5
  and r.grupo     = 6', 335, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (95, null, 1, 1, 'COMPONENTES DEL RATIO DE COBERTURA DE LIQUIDEZ', 'COMPONENTES DEL RATIO DE COBERTURA DE LIQUIDEZ', 0.00, null, null, null, null, null, null, 287, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (96, 95, 1, 2, 'TOTAL FONDO ALAC', 'TOTAL FONDO ALAC', 0.00, null, null, null, null, null, null, 389, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (97, 2, 2, 1, 'DEPÓSITOS', 'DEPÓSITOS', 0.00, null, null, null, null, null, null, 308, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (98, 2, 2, 4, 'FINANCIACIÓN', 'FINANCIACIÓN', 0.00, null, null, null, null, null, null, 350, 'N');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (99, 2, 2, 10, 'TOTAL SALIDA DE EFECTIVO', 'TOTAL SALIDA DE EFECTIVO', 0.00, null, null, null, null, null, null, 390, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (100, 3, 3, 8, 'TOTAL ENTRADA DE EFECTIVO', 'TOTAL ENTRADA DE EFECTIVO', 0.00, null, null, null, null, null, null, 391, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (101, null, 4, 1, 'FONDO ALAC (I)', 'FONDO ALAC (I)', 0.00, null, null, null, null, null, null, 386, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (102, null, 5, 1, 'Salidas de efectivo netas', 'Salidas de efectivo netas', 0.00, null, null, null, null, null, null, 387, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (103, null, 6, 1, 'LCR', 'LCR', 0.00, null, null, null, null, null, null, 388, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (67, 37, 2, 2, 'Menos Estables', 'Menos Estables', 10.00, null, null, null, null, null, null, 322, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (49, 11, 2, 2, 'Saldos correspondientes a documentos descontados en instituciones financieras', 'Saldos correspondientes a documentos descontados en instituciones financieras, aceptaciones bancarias, garantías otorgadas y apertura y confirmación de créditos documentarios', 5.00, 'select ''Saldos correspondientes a doc. descontados en instituciones financ.'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''420106060000000'',''420106080000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Saldos correspondientes a doc. descontados en instituciones financ.'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''420106060000000'',''420106080000000'')
  and sc.fecha = '||'&'||'FECHA', 363, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (40, 9, 2, 1, 'Con un Banco Central o respaldada por activos de Nivel 1 con cualquier contraparte ', 'Con un Banco Central o respaldada por activos de Nivel 1 con cualquier contraparte ', 0.00, 'select ''Con un Banco Central o respaldada por activos de Nivel 1 con cualquier contraparte'' tip_activo,
       sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
                     round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  = ''210300000000000''
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES)x', null, null, null, null, 'select ''Con un Banco Central o respaldada por activos de Nivel 1 con cualquier contraparte'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro  = ''210300000000000''
  and sc.fecha = '||'&'||'FECHA', 352, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (12, 2, 2, 8, 'Salidas de efectivo procedentes de operaciones con derivados', 'Salidas de efectivo procedentes de operaciones con derivados', 100.00, null, null, null, null, null, null, 365, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (19, 3, 3, 6, 'Entradas de efectivo procedentes de operaciones con derivados ', 'Entradas de efectivo procedentes de operaciones con derivados ', 100.00, 'select ''Entradas de efectivo procedentes de operaciones con derivados'' tip_activo,
       abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
       round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
from cb_sim_sal_consolidados sc
where sc.cod_rubro  = ''510406950000000''
  and sc.ano = '||'&'||'ANIO
  and sc.mes = '||'&'||'MES', null, null, null, null, 'select ''Entradas de efectivo procedentes de operaciones con derivados'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro = ''510406950000000''
  and sc.fecha = '||'&'||'FECHA', 382, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (56, 15, 2, 2, 'Créditos vigentes con una institución que pertenezca al sistema financiero (SF)', 'Créditos vigentes con una institución que pertenezca al sistema financiero (SF)', 100.00, 'select ''Créditos vigentes con una instit. que pertenezca al sist. finan.(SF)'' concepto,
       sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
             sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
             sum(case when l.moneda = 6100 then l.monto * '||'&'||'VAL_COTIZACION else 0 end ) sal_mon_ext
      from it.sb_lcr_liq_inv_tmp l
      where (l.cod_rubro like ''13010419%'' or l.cod_rubro like ''13010141%'' or l.cod_rubro like ''13010417%'' or l.cod_rubro like ''1301013112%'' or
             l.cod_rubro like ''1301013120%'' or l.cod_rubro like ''1301013126'' or l.cod_rubro like ''13030397%'')
        and l.plazo     <= 30
      group by substr(l.cod_rubro,1,10), l.moneda, l.plazo) con', null, null, null, null, 'select ''Créditos vigentes con una instit. que pertenezca al sist. finan.(SF)'' concepto,
       abs(sum(case when d.cod_moneda = 6900 then d.importe else 0 end)) sal_mon_loc,
       abs(sum(case when d.cod_moneda = 6100 then (d.importe * '||'&'||'VAL_COTIZACION) else 0 end )) sal_mon_ext
from sb_liq_diarios d
where d.cod_cuenta in (''1301041900'',''1301014100'',''1301041700'',
                       ''1301013112'',''1301013120'',''1301013126'',
                       ''1303039700'')
  and d.fecha      = '||'&'||'FECHA
  and d.plazo      <= 30', 375, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (61, 20, 2, 2, 'Otras', 'Otras', 50.00, 'select ''Otras entradas no contempladas'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''110201110000000'',''110201130000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Otras entradas no contempladas'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''110201110000000'',''110201130000000'')
  and sc.fecha = '||'&'||'FECHA', 385, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (51, 14, 2, 1, 'ALAC Nivel 1A ', 'ALAC Nivel 1A ', 0.00, 'select ''ALAC Nivel 1A'' tip_activo,
       sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
                     round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  = ''130200000000000''
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES)x', null, null, null, null, 'select ''ALAC Nivel 1A'' tip_activo,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro  = ''130200000000000''
  and sc.fecha = '||'&'||'FECHA', 369, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (45, 10, 2, 2, 'Instituciones del sector financiero, tanto locales como no residentes', 'Instituciones del sector financiero, tanto locales como no residentes', 100.00, null, null, null, null, null, null, 358, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (73, 39, 2, 3, 'Organismos Multilaterales', 'Organismos Multilaterales', 40.00, 'select ''Organismos Multilaterales'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0)  sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''210101000060000'',''210101000080000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Organismos Multilaterales'' concepto,
       nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                   (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
       nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
from it.cb_sal_consolidados_dia sc
where sc.cod_rubro in (''210101000060000'',''210101000080000'')
  and sc.fecha = '||'&'||'FECHA', 344, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (74, 39, 2, 4, 'Instituciones del sector financiero, tanto locales como no residentes', 'Instituciones del sector financiero, tanto locales como no residentes', 100.00, 'select ''Instituciones del sector financiero, tanto locales como no residentes'' concepto,
       sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
from (
      select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
             sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
             sum(case when l.moneda = 6100 then l.monto * '||'&'||'VAL_COTIZACION else 0 end ) sal_mon_ext
      from it.sb_lcr_liq_inv_tmp l
      where (l.cod_rubro like ''21010102%'' or l.cod_rubro like ''21010196%'' or l.cod_rubro like ''21010284%'' or l.cod_rubro like ''21010306%'' or 
             l.cod_rubro like ''21010304%'' or l.cod_rubro like ''21040390%'' or l.cod_rubro like ''21080134%'')
        and l.plazo     <= 30
      group by substr(l.cod_rubro,1,10), l.moneda, l.plazo) con', null, null, null, null, 'select ''Instituciones del sector financiero, tanto locales como no residentes'' concepto,
       abs(sum(case when d.cod_moneda = 6900 then d.importe else 0 end)) sal_mon_loc,
       abs(sum(case when d.cod_moneda = 6100 then (d.importe * '||'&'||'VAL_COTIZACION) else 0 end )) sal_mon_ext
from sb_liq_diarios d
where d.fecha = '||'&'||'FECHA
  and d.cod_cuenta in (''2101010200'',''2101019600'',''2101028400'',
                       ''2101030600'',''2101030400'',
                       ''2104039000'',''2108013400'')
  and d.plazo <= 30', 345, 'S');

insert into sb_lcr_definiciones (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, SQL_BAL_CERRADO, ID_BCP, REPORTA)
values (71, 39, 2, 1, 'Entidades públicas residentes del sector no financiero (SNF)', 'Entidades públicas residentes del sector no financiero (SNF)', 40.00, 'select ''Ent. públ. resid. del sector no fin.(SNF)'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from (select abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) sal_mon_loc,
           round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION ,0) sal_mon_ext
      from cb_sim_sal_consolidados sc
      where sc.cod_rubro  in (''220402380000000'',''220402900000000'',''220402920000000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES
      union all
      select sum(abs(con.sal_mon_loc)) sal_mon_loc, sum(abs(con.sal_mon_ext)) sal_mon_ext
      from (select substr(l.cod_rubro,1,10) cuenta, l.moneda, l.plazo,
                   sum(case when l.moneda = 6900 then l.monto else 0 end) sal_mon_loc,
                   sum(case when l.moneda = 6100 then l.monto * '||'&'||'VAL_COTIZACION else 0 end ) sal_mon_ext
            from it.sb_lcr_liq_inv_tmp l
            where (l.cod_rubro like ''22040298%'' or l.cod_rubro like ''22080224%'' or l.cod_rubro like ''22080230%'' or l.cod_rubro like ''22080234%'')
              and l.plazo     <= 30
            group by substr(l.cod_rubro,1,10), l.moneda, l.plazo) con
      union
      -- Resta Seguridad Social GS
      select (abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                     (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))) * -1) sal_mon_loc,
           (round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0) * -1)  sal_mon_ext
      from cb_sim_sal_consolidados sc
    where sc.cod_rubro  in (''220402920600000'',''220402380600000'',''220402900600000'')
        and sc.ano = '||'&'||'ANIO
        and sc.mes = '||'&'||'MES) x', null, null, null, null, 'select ''Ent. públ. resid. del sector no fin.(SNF)'' concepto, sum(nvl(x.sal_mon_loc,0)) sal_mon_loc, sum(nvl(x.sal_mon_ext,0)) sal_mon_ext
from ( select nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                           (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) sal_mon_loc,
               nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) sal_mon_ext
        from it.cb_sal_consolidados_dia sc
        where sc.cod_rubro in (''220402380000000'',''220402900000000'',''220402920000000'')
          and sc.fecha = '||'&'||'FECHA
        union all
        select nvl(abs(sum(case when d.cod_moneda = 6900 then d.importe else 0 end)),0) sal_mon_loc,
               nvl(abs(sum(case when d.cod_moneda = 6100 then (d.importe * '||'&'||'VAL_COTIZACION) else 0 end )),0) sal_mon_ext
        from sb_liq_diarios d
        where d.cod_cuenta in (''2204029800'',''2208022400'',''2208023000'',''2208023400'')
          and d.fecha      = '||'&'||'FECHA
          and d.plazo      <= 30
        union all
        -- Resta Seguridad Social --
        select (nvl(abs(SUM((nvl(sc.sal_mon_loc_ant, 0) + nvl(sc.deb_mon_local, 0) - nvl(sc.cre_mon_local, 0)) -
                            (nvl(sc.sal_equ_loc_ant, 0) + nvl(sc.deb_equ_local, 0) - nvl(sc.cre_equ_local, 0)))),0) * -1) sal_mon_loc,
               (nvl(round(abs(SUM(nvl(sc.sal_mon_rub_ant + sc.deb_mon_rubro - sc.cre_mon_rubro, 0))) * '||'&'||'VAL_COTIZACION,0),0) * -1) sal_mon_ext
        from it.cb_sal_consolidados_dia sc
        where sc.cod_rubro in (''220402920600000'',''220402380600000'',''220402900600000'')
          and sc.fecha = '||'&'||'FECHA ) x', 342, 'S');

commit;
