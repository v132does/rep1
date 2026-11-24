create or replace procedure it.kill_session (pn_sid IN number,pn_serial IN number,p_inst IN number) as
     lv_user varchar2(30);

    begin
    select username into lv_user from gv$session where sid = pn_sid and serial# = pn_serial;

            if lv_user is not null and lv_user not in ('SYS','SYSTEM') then

                execute immediate 'alter system kill session '''||pn_sid||','||pn_serial||',@'||p_inst||'''';

            else
            raise_application_error(-20000,'Attempt to kill protected system session has been blocked.');
            end if;
    end;
/

