CREATE OR REPLACE FUNCTION IT.FUG_TIE_DEM_JUDICIAL(p_cod_persona ba_personas.cod_persona%TYPE)
RETURN VARCHAR2 IS
  v_tiene varchar2(1) := 'N';
BEGIN
  begin
   Select 'S'
     into v_tiene
       from ge_per_inhibidas b
         where  estado = 'I'
           and b.cod_persona= p_cod_persona
           and b.cod_causa=279; --279 demanda Judicial
  exception
    when no_data_found then
      v_tiene:='N';
    when too_many_rows then
      v_tiene:='S';
    when others then
      v_tiene:='N';
  end ;

  RETURN v_tiene;
END;
/

