BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
END;
/

INSERT INTO ba_programas(COD_PROGRAMA, 
                         DESCRIPCION,       
                         COD_TIP_PROGRAMA,       
                         COD_MODULO,       
                         UBI_EJECUTABLE,       
                         UBI_FISICO,       
                         DES_DETALLADA,       
                         COD_HERRAMIENTA,       
                         OBSERVACION,             
                         OPE_MOD_CERRADO,       
                         COD_PRO_EQUIVALENTE,       
                         DOCUMENTO,       
                         UBI_MENU,       
                         INA_CIERRE)      
                  VALUES('REPENCLEG',                                               --COD_PROGRAMA, 
                         'Envío Encaje Legal MT998',                                --DESCRIPCION,       
                         '1',                                                       --COD_TIP_PROGRAMA,   
                         '2',                                                       --COD_MODULO,       
                         'Z:\GF10G\EXE',                                            --UBI_EJECUTABLE,     
                         'Z:\GF10G\EXE',                                            --UBI_FISICO,       
                         'Envío Encaje Legal MT998',                                --DES_DETALLADA,      
                         NULL,                                                      --COD_HERRAMIENTA,    
                         NULL,                                                      --OBSERVACION,         
                         'S',                                                       --OPE_MOD_CERRADO,    
                         NULL,                                                      --COD_PRO_EQUIVALENTE,
                         NULL,                                                      --DOCUMENTO,       
                         'Contabilidad -> Operaciones -> Envío Encaje Legal MT998', --UBI_MENU,       
                         'N');                                                      --INA_CIERRE)      
COMMIT;

