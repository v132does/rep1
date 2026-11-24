BEGIN

    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;

    INSERT INTO ba_par_reportes(COD_PROGRAMA, 
                                COD_CAMPO, 
                                ALIAS, VAL_DEFECTO, 
                                TIPO,
                                NRO_ORDEN, 
                                TIP_VAL_DEFECTO, 
                                MODIFICABLE, 
                                OBLIGATORIO)
                         VALUES('GLREFBAN',                                  --COD_PROGRAMA, 
                                'INC_SALDOS',                                --COD_CAMPO, 
                                NULL,                                        --ALIAS,
                                NULL,                                        --VAL_DEFECTO,
                                'F',                                         --TIPO, 
                                '50',                                        --NRO_ORDEN, 
                                'V',                                         --TIP_VAL_DEFECTO, 
                                'S',                                         --MODIFICABLE, 
                                'N');                                        --OBLIGATORIO
                                
    INSERT INTO ba_par_reportes(COD_PROGRAMA, 
                                COD_CAMPO, 
                                ALIAS, VAL_DEFECTO, 
                                TIPO,  
                                NRO_ORDEN, 
                                TIP_VAL_DEFECTO, 
                                MODIFICABLE, 
                                OBLIGATORIO)
                         VALUES('GLREFBAN',                                  --COD_PROGRAMA, 
                                'FECHA',                                     --COD_CAMPO, 
                                'T',                                         --ALIAS,
                                NULL,                                        --VAL_DEFECTO,
                                'F',                                         --TIPO, 
                                '60',                                        --NRO_ORDEN, 
                                'V',                                         --TIP_VAL_DEFECTO, 
                                'S',                                         --MODIFICABLE, 
                                'N');                                        --OBLIGATORIO                                
                            
                            
    DBMS_OUTPUT.PUT_LINE('Datos actualizados.');

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al intentar actualizar.'||SQLERRM);
END;
/