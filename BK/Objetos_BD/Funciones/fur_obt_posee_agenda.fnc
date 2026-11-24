CREATE OR REPLACE FUNCTION IT.FUR_OBT_POSEE_AGENDA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
v_existe varchar2(1) := 'N';
begin
  Select 'S'
    into v_existe
    from cr_agendas b
   where cod_persona = p_cod_persona
     --- Solo las agendas pendientes ---
     and exists (Select '1'
                   from cr_age_est_actividades e
                  where e.cod_actividad = b.cod_actividad
                    and e.cod_estado = b.cod_estado
                    and grupo = 'P');
  Raise TOO_MANY_ROWS;
Exception
  When NO_DATA_FOUND Then
     Return 'N';
  When TOO_MANY_ROWS Then
     Return 'S';
end;
/

