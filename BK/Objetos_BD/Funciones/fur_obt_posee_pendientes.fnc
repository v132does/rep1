CREATE OR REPLACE FUNCTION IT.FUR_OBT_POSEE_PENDIENTES
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
v_existe varchar2(1) := 'N';
begin
  Select 'S'
    into v_existe
    from wf_circuitos b
   where b.cod_persona = p_cod_persona
     and b.estado = 'E'; -- solo workflow pendientes
  Raise TOO_MANY_ROWS;
Exception
  When NO_DATA_FOUND Then
     Return 'N';
  When TOO_MANY_ROWS Then
     Return 'S';
end;
/

