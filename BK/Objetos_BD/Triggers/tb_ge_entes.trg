CREATE OR REPLACE TRIGGER IT.TB_GE_ENTES
 BEFORE INSERT
 ON GE_ENTES
 FOR EACH ROW

BEGIN
   -- Asignar el siguiente valor de la secuencia al código de ente
      SELECT IT.S_COD_ENTE.NEXTVAL 
      INTO :new.cod_ente 
      FROM DUAL;
END;
/
