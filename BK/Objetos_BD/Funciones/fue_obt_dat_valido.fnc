CREATE OR REPLACE FUNCTION IT.FUE_OBT_DAT_VALIDO(P_DATO IN VARCHAR2)
RETURN VARCHAR2 IS
V_RETORNO VARCHAR2(1000) := UPPER(P_DATO);
BEGIN
   V_RETORNO := TRANSLATE(V_RETORNO,'ºª!@#$%^&*()_+{}´¨[]-:"''<>,./?~`;\|','                               ');
   V_RETORNO := REPLACE((
                 REPLACE((
                   REPLACE((
                    REPLACE((
                     REPLACE(UPPER(V_RETORNO),'Á','A'))
                                             ,'É','E'))
                                             ,'Í','I'))
                                             ,'Ó','O'))
                                             ,'Ú','U');
   V_RETORNO := REPLACE((
                 REPLACE((
                   REPLACE((
                    REPLACE((
                     REPLACE(UPPER(V_RETORNO),'Ä','A'))
                                             ,'Ë','E'))
                                             ,'Ï','I'))
                                             ,'Ö','O'))
                                             ,'Ü','U');
  V_RETORNO := REPLACE((
                 REPLACE((
                   REPLACE((
                    REPLACE((
                     REPLACE(UPPER(V_RETORNO),'À','A'))
                                             ,'È','E'))
                                             ,'Ì','I'))
                                             ,'Ò','O'))
                                             ,'Ù','U');
   RETURN V_RETORNO;
END;
/

