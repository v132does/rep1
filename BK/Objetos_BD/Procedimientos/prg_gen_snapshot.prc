create or replace procedure it.prg_gen_snapshot is
  v_snap number;
begin
--  v_snap := sys.dbms_workload_repository.create_snapshot;
   v_snap:=null;
exception
  when others then
       null;
end;
/

