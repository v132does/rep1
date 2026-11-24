create or replace procedure it.pre_mat_sesion(pid in number, pserial in number) is
v_error varchar2(4000);
v_sql   varchar2(200);
begin
   v_sql := 'alter system kill session '''||pid||','||pserial||'''';
   sql_util.ejecute_dml(v_sql, v_error);
   if v_error is not null then
      raise no_data_found;
   end if;
exception
   when others then
       raise_application_error(-20000,v_error);
end;
/

