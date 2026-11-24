CREATE OR REPLACE TRIGGER IT.TA_GE_SPI_LOG_MX
  before insert on ge_spi_log_mx  
  for each row
declare
  -- local variables here--
begin
  IF :NEW.ID_LOG IS NULL THEN
    SELECT s_id_log_mx_spi.nextval INTO :NEW.ID_LOG FROM DUAL;
  END IF;
end TA_GE_SPI_LOG_MX;
/

