create or replace function it.FUE_OBT_CAN_SESIONES
 (p_cod_usuario in varchar2) return varchar2 is
  Result number := 0; --sin sesiones
  -- para que esta funcion se active, se debe en la base con sysdba, se debe
  -- dar el sgte. comando: grant select on v_$session to it;
  
begin

  select nvl(count(*),0) into Result
    from gv$session
   where username = p_cod_usuario
   and status <> 'KILLED';  
  
  return(Result);
exception
  when no_data_found then
     return (0); -- sin sesion 
  when others then
     raise_application_error(-20000,'FUE_OBT_CAN_SESIONES '||sqlerrm);   
end FUE_OBT_CAN_SESIONES;
/

