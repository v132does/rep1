CREATE OR REPLACE TYPE IT."TYP_DETALLETASASADELANTO"                                          IS OBJECT(
   valminimo    VARCHAR2(30), --Valor mínimo 
   valmaximo   VARCHAR2(60), -- Valor máximo
   abreviatura   VARCHAR2(60), -- Porcentaje de la tasa 
   CONSTRUCTOR FUNCTION typ_detalleTasasAdelanto RETURN SELF AS result)
/

