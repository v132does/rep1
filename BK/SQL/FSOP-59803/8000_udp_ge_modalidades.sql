BEGIN

    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;

	UPDATE ge_modalidades SET descripcion = 'CDA MERCADO SECUNDARIO' WHERE cod_modalidad = 114;
	UPDATE ge_modalidades SET descripcion = 'CDA MERCADO PRIMARIO' WHERE cod_modalidad = 100;
	UPDATE ge_modalidades SET descripcion = 'LRM MERCADO SECUNDARIO' WHERE cod_modalidad = 101;
	UPDATE ge_modalidades SET descripcion = 'BOTES PRIMARIO', TIPO = 'A' WHERE cod_modalidad = 105;
	UPDATE ge_modalidades SET descripcion = 'BOTES SECUNDARIO' WHERE cod_modalidad = 123;
	UPDATE ge_modalidades SET descripcion = 'BONOS AFD SECUNDARIO' WHERE cod_modalidad = 124;
	UPDATE ge_modalidades SET descripcion = 'BONOS AFD PRIMARIO' WHERE cod_modalidad = 122;
	UPDATE ge_modalidades SET descripcion = 'BONOS PRIVADOS SECUNDARIO' WHERE cod_modalidad = 106;
	UPDATE ge_modalidades SET descripcion = 'BONOS PRIVADOS PRIMARIO' WHERE cod_modalidad = 125;
	UPDATE ge_modalidades SET descripcion = 'Overnight Ext' WHERE cod_modalidad = 134;
	UPDATE ge_modalidades SET descripcion = 'FPL a PLAZO' WHERE cod_modalidad = 147;
	UPDATE ge_modalidades SET descripcion = 'PRESTMO DEL EXT GS' WHERE cod_modalidad = 119;
	UPDATE ge_modalidades SET descripcion = 'LRM MERCADO PRIMARIO  - INACTIVO' WHERE cod_modalidad = 130;
	UPDATE ge_modalidades SET descripcion = 'BONOS DEL TESORO - INACTIVO' WHERE cod_modalidad = 104;
	UPDATE ge_modalidades SET descripcion = 'BONOS MUNICI MCDO PRIMARI-INACTIVO' WHERE cod_modalidad = 142;

    DBMS_OUTPUT.PUT_LINE('Datos actualizados.');

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al intentar actualizar.');
END;
/