Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL)
values ('CD_COBROS', 'CONSULTA COBROS DE PRESTAMOS', NULL, 'P', 'FIELCO_AUDITORIA-AUDITORIA INTERNA ó UENO_AUDITINT-AUDITORIA INTERNA ó UENO_JEFERIESGOFMP-JEFE RIESGO FINAN. MERC. PORT.', 
'Consulta Cobros de Préstamos por Fecha.', 
'SELECT DISTINCT pr_cobros.fecha fecha,
                pr_cta_prestamos.cod_oficina || '' - '' ||ba_oficinas.descripcion oficina,
                ge_modalidades.cod_modalidad modalidad,
                pr_cobros.nro_cuenta nro_cuenta,
                ba_personas.nro_documento nro_documento,
                ba_personas.nom_completo nombre,
                pr_cobros.nro_cuota nro_cuota,
                pr_cobros.fec_vencimiento fec_vencimiento,
                pr_cobros.dia_mora atraso,
                (nvl(pr_cobros.mto_capital, 0) +
                nvl(pr_cobros.mto_interes, 0) +
                nvl(pr_cobros.mto_int_documentado, 0) +
                (nvl(pr_cobros.mto_int_moratorio, 0) +
                nvl(pr_cobros.mto_int_mor_interes, 0) +
                nvl(pr_cobros.mto_int_mor_adelantado, 0)) +
                nvl(pr_cobros.mto_int_punitorio, 0) +
                nvl(pr_cobros.mto_impuesto, 0) +
                (nvl(pr_cobros.mto_cargo, 0))) mto_cobro,
                nvl(pr_cobros.mto_capital, 0) mto_capital,
                nvl(pr_cobros.mto_interes, 0) +
                nvl(pr_cobros.mto_int_documentado, 0) mto_interes,
                (nvl(pr_cobros.mto_int_moratorio, 0) +
                nvl(pr_cobros.mto_int_mor_interes, 0) +
                nvl(pr_cobros.mto_int_mor_adelantado, 0)) mto_moratorio,
                nvl(pr_cobros.mto_int_punitorio, 0) mto_punitario,
                nvl(pr_cobros.mto_impuesto, 0) mto_ley,
                nvl(pr_cobros.mto_cargo_iva, 0) iva,
                (nvl(pr_cobros.mto_cargo, 0)) mto_gastos,
                pr_cobros.usu_insercion usu_insercion,
                pr_cobros.hora hora
  FROM ba_monedas,
       ba_oficinas,
       ge_modalidades,
       ge_cta_clientes,
       ba_personas,
       pr_cta_prestamos,
       pr_cobros
 WHERE ba_monedas.cod_moneda = pr_cta_prestamos.cod_moneda
   AND ba_oficinas.cod_oficina = pr_cta_prestamos.cod_oficina
   AND ge_modalidades.cod_modalidad = pr_cta_prestamos.cod_modalidad
   AND ge_modalidades.cod_modulo = pr_cta_prestamos.cod_modulo
   AND ge_cta_clientes.relacion = ''P''
   AND pr_cta_prestamos.nro_cuenta = ge_cta_clientes.nro_cuenta
   AND ge_cta_clientes.cod_persona = ba_personas.cod_persona
   AND pr_cta_prestamos.nro_cuenta = pr_cobros.nro_cuenta
   AND &'||'P_FILTROS
 ORDER BY 1, 4, 6, 7');
 
commit;
