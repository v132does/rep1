DECLARE
  v_sql VARCHAR2(1000) := q'[Select 'Si' Descripcion, 'S' Codigo from dual]';
BEGIN

    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
    

    INSERT INTO ge_filtros(COD_CAMPO, 
                       DESCRIPCION, 
                       TIP_CAMPO, 
                       LON_CAMPO, 
                       TIP_DATO, 
                       VAL_MAX_PERMITIDO, 
                       VAL_MIN_PERMITIDO, 
                       NOM_TAB_ASOCIADA, 
                       NOM_REFERENCIA, 
                       NRO_ORDEN, 
                       DET_SQL, 
                       OBSERVACION, 
                       TIPO, 
                       AFE_SEGMENTACION, 
                       AFE_PUNTUACION, 
                       AFE_REPORTES, 
                       AFE_CONSULTAS, 
                       AFE_RECLAMOS, 
                       TIP_SOL_IGUAL, 
                       PERMISO)
               VALUES ('INC_SALDOS',                                                            --COD_CAMPO, 
                       'Incluye Saldos',                                                        --DESCRIPCION, 
                       'S',                                                                     --TIP_CAMPO, 
                       3,                                                                       --LON_CAMPO, 
                       'V',                                                                     --TIP_DATO, 
                       NULL,                                                                    --VAL_MAX_PERMITIDO,
                       NULL,                                                                    --VAL_MIN_PERMITIDO,
                       NULL,                                                                    --NOM_TAB_ASOCIADA, 
                       'INC_SALDOS',                                                            --NOM_REFERENCIA, 
                       50,                                                                      --NRO_ORDEN, 
                       v_sql,                                                                   --DET_SQL, 
                       'S: Incluye saldos CA Y CC',                                             --OBSERVACION, 
                       'C',                                                                     --TIPO, 
                       NULL,                                                                    --AFE_SEGMENTACION, 
                       NULL,                                                                    --AFE_PUNTUACION, 
                       'S',                                                                     --AFE_REPORTES, 
                       NULL,                                                                    --AFE_CONSULTAS, 
                       NULL,                                                                    --AFE_RECLAMOS,
                       NULL,                                                                    --TIP_SOL_IGUAL, 
                       NULL);                                                                   --PERMISO)

    DBMS_OUTPUT.PUT_LINE('Datos actualizados.');

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al intentar actualizar.');
END;
/