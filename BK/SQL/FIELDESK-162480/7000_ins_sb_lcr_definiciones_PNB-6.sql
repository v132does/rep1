Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
/

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (1, null, 1, 1, 'ACTIVOS LÍQUIDOS DE ALTA CALIDAD ', 'ACTIVOS LÍQUIDOS DE ALTA CALIDAD ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (2, null, 2, 1, 'SALIDA DE EFECTIVO', 'SALIDA DE EFECTIVO', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (3, null, 3, 1, 'ENTRADAS DE EFECTIVO', 'ENTRADAS DE EFECTIVO', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (4, 1, 1, 1, 'Activos de Nivel 1', 'Activos de Nivel 1', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (5, 1, 1, 2, 'Nivel 2 "A" (no podrá superar el 40% del total del Fondo ALAC)', 'Nivel 2 "A" (no podrá superar el 40% del total del Fondo ALAC)', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (6, 1, 1, 3, 'Nivel 2 "B" (no podrá superar el 15% del total del Fondo ALAC)', 'Nivel 2 "B" (no podrá superar el 15% del total del Fondo ALAC)', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (7, 2, 2, 1, 'Depósitos  Minoristas', 'Depósitos  Minoristas', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (8, 2, 2, 2, 'Depósitos Mayoristas', 'Depósitos Mayoristas', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (9, 2, 2, 3, 'Financiación Mayorista Garantizada', 'Financiación Mayorista Garantizada', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (10, 2, 2, 4, 'Financiación Mayorista no Garantizada', 'Financiación Mayorista no Garantizada', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (11, 2, 2, 5, 'Salidas de efectivo contingentes', 'Salidas de efectivo contingentes', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (12, 2, 2, 6, 'Salidas de efectivo procedentes de operaciones con derivados', 'Salidas de efectivo procedentes de operaciones con derivados', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (13, 2, 2, 7, 'Otras salidas no contempladas', 'Otras salidas no contempladas', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (14, 3, 3, 1, 'Entradas relacionadas con créditos garantizados, incluidos repos a la inversa', 'Entradas relacionadas con créditos garantizados, incluidos repos a la inversa', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (15, 3, 3, 2, 'Entradas relacionadas con créditos no garantizados', 'Entradas relacionadas con créditos no garantizados', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (16, 3, 3, 3, 'Depósitos operativos mantenidos en otras instituciones financieras tanto locales como del exterior', 'Depósitos operativos mantenidos en otras instituciones financieras tanto locales como del exterior', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (17, 3, 3, 4, 'Entradas relacionadas con valores representativos de deuda ', 'Entradas relacionadas con valores representativos de deuda ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (18, 3, 3, 5, 'Facilidades de crédito o de liquidez concedidas al banco declarante', 'Facilidades de crédito o de liquidez concedidas al banco declarante', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (19, 3, 3, 6, 'Entradas de efectivo procedentes de operaciones con derivados ', 'Entradas de efectivo procedentes de operaciones con derivados ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (20, 3, 3, 7, 'Otras entradas no contempladas ', 'Otras entradas no contempladas ', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (21, 4, 1, 1, 'Caja ', 'Caja ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (22, 4, 1, 2, 'Cuentas corrientes en BCP', 'Cuentas corrientes en BCP', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (23, 4, 1, 3, 'Encaje legal', 'Encaje legal', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (24, 4, 1, 4, 'Depósitos por Operación Monetaria ', 'Depósitos por Operación Monetaria ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (25, 4, 1, 5, 'Valores Públicos nacionales en ML emitidos por el BCP y valores públicos nacionales en ML', 'Valores Públicos nacionales en moneda nacional emitidos por el BCP y valores públicos nacionales en moneda nacional y extranjera emitidos por el Gobierno Nacional Paraguayo', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (26, 4, 1, 6, 'Valores representativos de deuda en ME emitidos por gobiernos nacionales y entidades financieras', 'Valores representativos de deuda en moneda extranjera emitidos por gobiernos nacionales y entidades financieras del exterior calificados en una categoría igual o superior a AA- o equivalente.', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (27, 4, 1, 7, 'Valores representativos de deuda en ML y ME emitidos por organismos multilaterales de crédito', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por organismos multilaterales de crédito calificados en una categoría igual o superior a AA- o equivalente.', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (28, 5, 1, 1, 'Valores representativos de deuda en ME emitidos por gobiernos nacionales y entidades financieras', 'Valores representativos de deuda en moneda extranjera emitidos por gobiernos nacionales y entidades financieras del exterior calificados en una categoría entre A+ y A- o equivalente. ', 85.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (29, 5, 1, 2, 'Valores representativos de deuda en ML y extranjera emitidos por organismos multilaterales de crédit', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por organismos multilaterales de crédito calificados en una categoría entre A+ y A- o equivalente. ', 85.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (30, 6, 1, 1, 'Valores representativos de deuda en ML y extranjera emitidos por entidades del sector público', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por entidades del sector público nacional no financiero; ', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (31, 6, 1, 2, 'Valores representativos de deuda en ME emitidos por gobiernos nacionales y entidades financieras', 'Valores representativos de deuda en moneda extranjera emitidos por gobiernos nacionales y entidades financieras del exterior calificados en una categoría entre BBB+ y BBB- o equivalente.', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (32, 6, 1, 3, 'Valores representativos de deuda en ML y extranjera emitidos por organismos multilaterales de crédit', 'Valores representativos de deuda en moneda nacional y extranjera emitidos por organismos multilaterales de crédito calificados en una categoría entre BBB+ y BBB- o equivalente.', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (33, 6, 1, 4, 'Valores representativos de deuda en ML emitidos por empresas del sector no financiero', 'Valores representativos de deuda en moneda nacional emitidos por empresas del sector no financiero, calificados en una categoría igual o superior a BBB- o equivalente. ', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (34, 7, 2, 1, 'Estables ', 'Estables ', 5.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (35, 7, 2, 2, 'Menos Estables', 'Menos Estables', 10.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (36, 7, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (37, 8, 2, 1, 'Menores a 500 Salarios mínimos mensuales ', 'Menores a 500 Salarios mínimos mensuales ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (38, 8, 2, 2, 'Iguales o mayores  a 500 Salarios mínimos mensuales ', 'Iguales o mayores  a 500 Salarios mínimos mensuales ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (39, 8, 2, 3, 'Otras', 'Otras', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (40, 9, 2, 1, 'Con un Banco Central o respaldada por activos de Nivel 1 con cualquier contraparte ', 'Con un Banco Central o respaldada por activos de Nivel 1 con cualquier contraparte ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (41, 9, 2, 2, 'Con ALAC de nivel 2A', 'Con ALAC de nivel 2A', 15.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (42, 9, 2, 3, 'Con ALAC de nivel 2B', 'Con ALAC de nivel 2B', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (43, 9, 2, 4, 'Por otro colateral', 'Por otro colateral', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (44, 10, 2, 1, 'Bancos Multilaterales', 'Bancos Multilaterales', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (45, 10, 2, 2, 'Instituciones del sector financiero, tanto locales como no residentes', 'Instituciones del sector financiero, tanto locales como no residentes', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (46, 10, 2, 3, 'Bonos emitidos', 'Bonos emitidos', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (47, 10, 2, 4, 'Acreedores ', 'Acreedores ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (48, 11, 2, 1, 'Importe no utilizado de las facilidades de crédito (líneas de crédito)', ' Importe no utilizado de las facilidades de crédito (líneas de crédito) y liquidez acordadas incondicionalmente revocables y cancelables incondicionalmente por la institución', 2.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (49, 11, 2, 2, 'Saldos correspondientes a documentos descontados en instituciones financieras', 'Saldos correspondientes a documentos descontados en instituciones financieras, aceptaciones bancarias, garantías otorgadas y apertura y confirmación de créditos documentarios', 5.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (50, 11, 2, 3, 'Otras operaciones contingentes no contenidas en e.1 y e.2', 'Otras operaciones contingentes no contenidas en e.1 y e.2', 2.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (51, 14, 2, 1, 'ALAC Nivel 1A ', 'ALAC Nivel 1A ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (52, 14, 2, 2, 'ALAC Nivel 2A ', 'ALAC Nivel 2A ', 15.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (53, 14, 2, 3, 'ALAC Nivel 2B', 'ALAC Nivel 2B', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (54, 14, 2, 4, 'Cash Collateral ', 'Cash Collateral ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (55, 15, 2, 1, 'Créditos vigentes ', 'Créditos vigentes ', 50.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (56, 15, 2, 2, 'Créditos vigentes con una institución que pertenezca al sistema financiero (SF)', 'Créditos vigentes con una institución que pertenezca al sistema financiero (SF)', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (57, 17, 2, 1, 'Valores que no pudieron ser calificados como ALAC en ninguna de las categorías establecidas.', 'Valores que no pudieron ser calificados como ALAC en ninguna de las categorías establecidas.', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (58, 17, 2, 2, 'Activos de Nivel 1 y Nivel 2 que no sean admisibles como HQLA por requisitos operativos.', 'Activos de Nivel 1 y Nivel 2 que no sean admisibles como HQLA por requisitos operativos.', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (59, 17, 2, 3, 'Valores clasificados como ALAC de Nivel 2, por el porcentaje no computado.', 'Valores clasificados como ALAC de Nivel 2, por el porcentaje no computado.', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (60, 20, 2, 1, 'CDAs con IFI´s ', 'CDAs con IFI´s ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (61, 20, 2, 2, 'Otras', 'Otras', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (62, 34, 2, 1, 'Vista', 'Vista', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (63, 34, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días', 'Depósitos con un plazo residual menor o igual a 30 días', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (64, 35, 2, 1, 'Vista', 'Vista', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (65, 35, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días', 'Depósitos con un plazo residual menor o igual a 30 días', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (66, 37, 2, 1, 'Estables ', 'Estables ', 5.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (67, 37, 2, 2, 'Menos Estables', 'Menos Estables', 10.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (68, 37, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (69, 38, 2, 1, 'Depósitos operativos ', 'Depósitos operativos ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (70, 38, 2, 2, 'Depósitos  no operativos ', 'Depósitos  no operativos ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (71, 39, 2, 1, 'Entidades públicas residentes del sector no financiero (SNF)', 'Entidades públicas residentes del sector no financiero (SNF)', 40.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (72, 39, 2, 2, 'Entidades públicas y privadas no residentes del SNF', 'Entidades públicas y privadas no residentes del SNF', 40.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (73, 39, 2, 3, 'Organismos Multilaterales', 'Organismos Multilaterales', 40.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (74, 39, 2, 4, 'Instituciones del sector financiero, tanto locales como no residentes', 'Instituciones del sector financiero, tanto locales como no residentes', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (75, 39, 2, 5, 'Seguridad Social ', 'Seguridad Social ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (76, 39, 2, 6, 'Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)', 'Sociedades de Valores (Casas de Bolsas, Fondos de Inversión)', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (77, 39, 2, 7, 'Compañías de Seguros ', 'Compañías de Seguros ', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (78, 39, 2, 8, 'Agentes Fiduciarios', 'Agentes Fiduciarios', 100.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (79, 66, 2, 1, 'Vista ', 'Vista ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (80, 66, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (81, 67, 2, 1, 'Vista ', 'Vista ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (82, 67, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (83, 69, 2, 1, 'Estables ', 'Estables ', 5.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (84, 69, 2, 2, 'Menos estables ', 'Menos estables ', 25.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (85, 69, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (86, 70, 2, 1, 'Estables ', 'Estables ', 20.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (87, 70, 2, 2, 'Menos Estables ', 'Menos Estables ', 40.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (88, 70, 2, 3, 'Depósitos a plazo con vencimiento residual superior a 30 días ', 'Depósitos a plazo con vencimiento residual superior a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (89, 83, 2, 1, 'Vista ', 'Vista ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (90, 84, 2, 1, 'Vista ', 'Vista ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (91, 86, 2, 1, 'Vista ', 'Vista ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (92, 86, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (93, 87, 2, 1, 'Vista ', 'Vista ', 0.00, null, null, null, null, null);

insert into IT.SB_LCR_DEFINICIONES (NRO_ITEM, ID_PADRE, NRO_AGRUPADOR, NRO_ORDEN, DESCRIPCION, DESC_INFORME, PORC_PONDERACION, SQL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (94, 87, 2, 2, 'Depósitos con un plazo residual menor o igual a 30 días ', 'Depósitos con un plazo residual menor o igual a 30 días ', 0.00, null, null, null, null, null);

COMMIT;