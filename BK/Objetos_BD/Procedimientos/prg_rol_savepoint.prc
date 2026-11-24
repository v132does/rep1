create or replace procedure it.prg_rol_savepoint
 (p_nom_savepoint in varchar2) is
begin
   rollback to savepoint p_nom_savepoint;
exception
  when others then null;
end prg_rol_savepoint;
/

