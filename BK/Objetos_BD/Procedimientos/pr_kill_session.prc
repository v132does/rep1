create or replace procedure it.pr_kill_session is


begin
    declare
    str VARCHAR2(2000);
    begin
    for x in (select * from v$session) loop
      IF x.username = 'XPY8512' then
        str := ' alter system kill session ''' || x.sid || ',' || x.serial#||'''                                                                             immediate';
        execute immediate str;
      End if;
    END LOOP;
    end;
end;
/

