BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
END;
/

UPDATE wf_tip_cir_tareas 
SET det_sql = 'BEGIN
    IF '||''''||chr(38)||'TIP_ACCION'||''''||' = '||''''||'A'||''''||' THEN
        PRB_AJU_ENC_LEGAL('||chr(38)||'REFERENCIA,'||chr(38)||'FECHA);
    ELSIF '||''''||chr(38)||'TIP_ACCION'||''''||' = '||''''||'R'||''''||' THEN
        PRB_AJU_ENC_LEGAL('||chr(38)||'REFERENCIA, '||chr(38)||'FECHA,'||''''||'R'||''''||');
    ELSE
        PRB_AJU_ENC_LEGAL('||chr(38)||'REFERENCIA,'||chr(38)||'FECHA,'||''''||'C'||''''||');
    END IF;
END;'
WHERE cod_tip_circuito = 998
AND cod_tip_tarea = 1;
    
COMMIT;
    
