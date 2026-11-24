-- =====================================================================================
-- Trigger de auditoría para GE_MAE_TSC
-- =====================================================================================
CREATE OR REPLACE TRIGGER IT.TRG_GE_MAE_TSC_AUD
BEFORE INSERT OR UPDATE ON IT.GE_MAE_TSC
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    :NEW.USU_ALTA    := NVL(:NEW.USU_ALTA, USER);
    :NEW.FEC_ALTA    := NVL(:NEW.FEC_ALTA, SYSDATE);
    :NEW.USU_ULT_ACT := NVL(:NEW.USU_ULT_ACT, USER);
    :NEW.FEC_ULT_ACT := NVL(:NEW.FEC_ULT_ACT, SYSDATE);
  ELSIF UPDATING THEN
    :NEW.USU_ULT_ACT := NVL(:NEW.USU_ULT_ACT, USER);
    :NEW.FEC_ULT_ACT := NVL(:NEW.FEC_ULT_ACT, SYSDATE);
  END IF;
END;
/
