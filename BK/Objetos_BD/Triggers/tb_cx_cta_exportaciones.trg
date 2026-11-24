CREATE OR REPLACE TRIGGER IT.TB_CX_CTA_EXPORTACIONES
 BEFORE DELETE OR INSERT OR UPDATE
 ON CX_CTA_EXPORTACIONES
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE


BEGIN
   ---- Control de Utilización de Línea
   if inserting then
      :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(8);
   elsif updating then
      if :new.estado <> :old.estado then
         :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(8);
      end if;
   end if;
END;
/

