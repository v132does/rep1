CREATE OR REPLACE TYPE IT."TYP_REGSOFTOKENKEY"                                          IS OBJECT
(
    error                VARCHAR2(1),
    nombreRespuesta      VARCHAR2(15),
    descripcionRespuesta VARCHAR2(200),
    CONSTRUCTOR FUNCTION TYP_REGSOFTOKENKEY
        RETURN SELF AS RESULT
)
/

