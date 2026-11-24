CREATE OR REPLACE FUNCTION IT."FUG_OBT_NVA_LINEA"
  (P_COD_PERSONA IN VARCHAR2)     --- Persona
  return number is
  Result number;
begin
  select nvl(VAL_PARAMETRO,0)
    into Result
    from ba_per_dat_adicionales
   where parametro='NVA_LINEA'
     and cod_persona = p_cod_persona;

  return(to_char(Result));
exception
  when no_data_found then
    return 0;
  when too_many_rows then
    return 0;
  when others then
     return 0;
end FUG_OBT_NVA_LINEA;
/

