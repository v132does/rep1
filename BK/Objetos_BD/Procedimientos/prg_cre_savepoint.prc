create or replace procedure it.prg_cre_savepoint
 (p_nom_savepoint in varchar2) is
begin
   savepoint p_nom_savepoint;
end;
/

