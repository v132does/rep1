CREATE OR REPLACE FUNCTION IT.FUG_UPD_CARACTERES (P_DATOS     CLOB,
                                               P_OLD_VALUE VARCHAR2,
                                               P_NEW_VALUE VARCHAR2) RETURN CLOB IS
       /*
          * Utilizado para reemplazar caracteres especiales en una cadena de texto CLOB
          * El tamaño de la variable V_POS_FINAL debe ser multiplo de 48
       */
       V_POS_INICIAL  INTEGER := 1;
       V_POS_FINAL    INTEGER := 576;
       V_TAM_ARCHIVO  INTEGER;
       V_LEER         VARCHAR(4000);
       V_OUT_CLOB     CLOB;
BEGIN
       V_TAM_ARCHIVO := LENGTH(P_DATOS);
       WHILE (V_POS_INICIAL <= V_TAM_ARCHIVO)
       LOOP
              V_LEER        := replace(SUBSTR(P_DATOS, V_POS_INICIAL, V_POS_FINAL),P_OLD_VALUE,P_NEW_VALUE);
              V_OUT_CLOB    := V_OUT_CLOB || UTL_RAW.CAST_TO_VARCHAR2(UTL_RAW.CAST_TO_RAW(V_LEER));
              V_POS_INICIAL := V_POS_INICIAL + V_POS_FINAL;
       END LOOP;
       RETURN V_OUT_CLOB;
END;
/

