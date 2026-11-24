CREATE OR REPLACE PROCEDURE IT.PRA_ACT_MI_IT_BA_PERSONAS_01
 (P_COD_PERSONA IN MI_IT_BA_PERSONAS_01.COD_PERSONA%TYPE
 ,P_COD_TIP_DOCUMENTO IN OUT MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE
 ,P_NRO_DOCUMENTO IN OUT MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE
 )
 IS

--     v_cantidad NUMBER(10);
     v_cod_tip_documento MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE;
     v_nro_documento     MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE;
BEGIN
   IF  P_NRO_DOCUMENTO IS NULL THEN
       SELECT COD_TIP_DOCUMENTO,
              NRO_DOCUMENTO
       INTO
              v_cod_tip_documento,
              v_nro_documento
        FROM BA_PERSONAS
        WHERE COD_PERSONA = P_COD_PERSONA;
        
     P_COD_TIP_DOCUMENTO := v_cod_tip_documento;
     P_NRO_DOCUMENTO := v_nro_documento; 
   ELSE
        v_cod_tip_documento := P_COD_TIP_DOCUMENTO;
        v_nro_documento     := P_NRO_DOCUMENTO;
   END IF;

     UPDATE MI_IT_BA_PERSONAS_01
        SET COD_TIP_DOCUMENTO = v_cod_tip_documento,
            NRO_DOCUMENTO     = v_nro_documento
        WHERE COD_PERSONA = P_COD_PERSONA;
    if sql%notfound  then
        INSERT INTO MI_IT_BA_PERSONAS_01(COD_PERSONA,
        COD_TIP_DOCUMENTO,NRO_DOCUMENTO)
               VALUES (P_COD_PERSONA,
                       v_cod_tip_documento,
                       v_nro_documento);
    END IF;
    
    
 EXCEPTION
   when no_data_found then
      RAISE_APPLICATION_ERROR(-20001,'La persona no existe. Verifique...');
--       WHEN OTHERS THEN
--            RAISE_APPLICATION_ERROR
--(-20000,'ERROR.PRA_ACT_MI_IT_BA_PERSONAS_01'||sqlerrm);
END;
/

