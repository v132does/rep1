CREATE OR REPLACE TRIGGER IT.TB_GE_DET_SEGUROS
  BEFORE DELETE OR INSERT OR UPDATE 
  ON GE_DET_SEGUROS
  FOR EACH ROW
DECLARE
  -- local variables here
BEGIN
  if inserting then
     if :new.secuencia is null then
        begin
          select nvl(max(secuencia),0) + 1
          into :new.secuencia
          from ge_det_seguros a
          where a.cod_tipo = :new.cod_tipo;
        exception
          when no_data_found then
          :new.secuencia :=1;
        end;
     end if;
  end if;
END ge_det_seguros;
/

