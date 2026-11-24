CREATE OR REPLACE TRIGGER IT.TB_GE_DNA_LOG
  before insert on GE_DNA_LOG
 for each row
begin

  if :new.usuario = 'HBANK' then
     :new.usuario := 'HOMEBANK';
  end if;
end TB_GE_DNA_LOG;
/

