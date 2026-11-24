create or replace function it.FUE_VER_SESION
 (p_cod_usuario in varchar2) return varchar2 is
  Result varchar2(1) := 'I'; --inactivo
  -- para que esta funcion se active, se debe en la base con sysdba, se debe
  -- dar el sgte. comando: grant select on v_$session to it;
  
begin

  select 'A' into Result
    from v$session
   where username = p_cod_usuario
     and status <> 'KILLED';  
    
  return(Result);
exception
  when too_many_rows then
     return ('A'); -- activo  
  when no_data_found then
     return ('I'); -- inactivo   
  when others then
     raise_application_error(-20000,'FUE_VER_SESSION '||sqlerrm);   
end FUE_VER_SESION;
/

