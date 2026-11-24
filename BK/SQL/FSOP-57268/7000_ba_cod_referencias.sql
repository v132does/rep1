EXEC Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

insert into ba_cod_referencias
(DOMINIO,
 SIGNIFICADO,
 VAL_MINIMO,
 VAL_MAXIMO,
 ABREVIATURA,
 ACTIVO)
values
('SNP_SOL_REPORTES',
 'Reporte detallado de estado (STAT)',
 '10',
 'MT985',
 'MT985/STAT',
 'S');
commit;

