CREATE OR REPLACE PROCEDURE IT.PRE_ACT_BA_PERSONAS
 (P_COD_PERSONA IN VARCHAR2
 ,P_NOMBRE IN VARCHAR2
 )
 IS
BEGIN
  UPDATE ba_personas
  SET ba_personas.nom_completo = replace(replace(P_NOMBRE,'   ',' '),'  ',' ')
  WHERE ba_personas.cod_persona = P_COD_PERSONA;
END;
/

