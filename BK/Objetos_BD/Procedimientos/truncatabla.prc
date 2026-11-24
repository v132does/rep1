create or replace procedure it.TRUNCATABLA(tabla in varchar2 )
as
begin
 execute immediate 'TRUNCATE TABLE ' || tabla;
end;
/

