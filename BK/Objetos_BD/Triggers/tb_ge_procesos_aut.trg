CREATE OR REPLACE TRIGGER IT.TB_GE_PROCESOS_AUT
  before INSERT OR UPDATE on ge_procesos_aut
  for each row
declare
  -- local variables here
begin
  IF inserting then
    SELECT S_PROCESOS_AUT.nextval
    INTO :new.cod_pro_aut
    FROM dual;
    SELECT ORA_HASH(:new.cod_proceso || :new.frecuencia ||  :new.hor_ejecucion || :new.estado || :new.dia_ejecucion || :new.hor_fin_ejecucion || :new.recurrencia)
    INTO :new.HASH_DATO
    FROM dual;
  elsif updating then
      SELECT ORA_HASH(:new.cod_proceso || :new.frecuencia ||  :new.hor_ejecucion || :new.estado || :new.dia_ejecucion || :new.hor_fin_ejecucion || :new.recurrencia)
    INTO :new.HASH_DATO
    FROM dual;
   END IF;
end TB_GE_PROCESOS_AUT;
/

