CREATE OR REPLACE TRIGGER IT.TB_PV_COMPRAS
 BEFORE DELETE OR INSERT OR UPDATE
     ON PV_COMPRAS
    FOR EACH ROW

BEGIN
   IF inserting then
      :new.fec_cam_estado := pag_cal.FU_OBT_FEC_ACTUAL(28);
   elsif updating then
      if :new.estado <> :old.estado then
         :new.fec_cam_estado := pag_cal.FU_OBT_FEC_ACTUAL(28);
      end if;
   end if;
END;
/

