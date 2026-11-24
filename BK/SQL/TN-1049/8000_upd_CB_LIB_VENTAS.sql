BEGIN   PRE_INI_APLICACION;   PAE_CNF.G_COD_MODULO := 1; END;
/
update cb_lib_ventas
set estado = null
where fecha = '29/05/2026'
and estado = 'X';
COMMIT;