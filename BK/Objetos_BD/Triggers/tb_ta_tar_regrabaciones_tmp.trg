CREATE OR REPLACE TRIGGER IT.TB_TA_TAR_REGRABACIONES_TMP
  before insert or update or delete on TA_TAR_REGRABACIONES_TMP
  for each row
declare
  -- local variables here
begin
   if inserting then
         --- Generar codigo de movimiento
         select S_COD_REGISTRO.nextval into :new.COD_REGISTRO from dual;
   end if;   
end TB_TA_TAR_REGRABACIONES_TMP;
/

