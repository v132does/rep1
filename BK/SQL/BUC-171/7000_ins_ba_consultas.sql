begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_EXT_LEG', 'Extracto Detallado - Legales', 'UGENERICO', 'P', null, null, 'select nro_cuenta "Nro. Cuenta", 
       nom_completo "Titular Cta.", 
       to_char(e.FECHA,''dd/mm/yyyy'') "Fecha",
       to_char(e.FEC_VALOR,''dd/mm/yyyy'') "Fec. Valor", 
       hora Hora, 
       cod_moneda Moneda, 
       nro_documento "Nro. Transacción", 
       concepto Concepto, 
       tra_padre "Transacción Padre", 
       tra_hijo "Transacción Hijo", 
       estado Estado, 
       reversado, 
       nro_caja "Nro. Caja", 
       mto_debito Débito, 
       mto_credito Crédito, 
       transf_int "Datos de Transf. Internas"
  from gv_ext_legales e
 where (&'||'P_FILTROS)', null, '1,2', null);

commit;
