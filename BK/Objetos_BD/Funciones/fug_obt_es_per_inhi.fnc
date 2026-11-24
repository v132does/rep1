CREATE OR REPLACE FUNCTION IT.FUG_OBT_ES_PER_INHI
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
v_existe varchar2(1) := 'N';
begin
  Select 'S'
    into v_existe
    from ge_per_inhibidas b
   where cod_persona = p_cod_persona
     and estado = 'I';
  Raise TOO_MANY_ROWS;
Exception
  When NO_DATA_FOUND Then
     Return 'N';
  When TOO_MANY_ROWS Then
     Return 'S';
end;
/

