CREATE OR REPLACE TRIGGER IT.TB_GE_RET_PROVEEDORES
 BEFORE INSERT OR UPDATE
 ON GE_RET_PROVEEDORES
 FOR EACH ROW
BEGIN
   If inserting or updating then
     If :new.estado <> :old.estado  then
       :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(28);  
     End if;
   End if;
END;
/

