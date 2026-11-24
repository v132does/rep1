create or replace procedure it.pre_cam_for_numerico(p_formato in varchar2) is
begin
  execute immediate 'alter session set NLS_NUMERIC_CHARACTERS='''||p_formato||'''';
 -- execute immediate 'alter session set NLS_LANG=Spanish_Spain.WE8ISO8859P1';
end;
/

