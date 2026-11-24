CREATE OR REPLACE TRIGGER IT.tb_cj_dep_chq_atm_reg_ins
  BEFORE INSERT ON IT.CJ_DEP_CHQ_ATM_REG
  FOR EACH ROW
BEGIN
  SELECT s_id_dep_cheque.nextval
  INTO :new.id_dep_cheque
  FROM dual;
END;
/

