CREATE OR REPLACE TRIGGER IT.TB_CX_CTA_COBRANZAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CX_CTA_COBRANZAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

BEGIN
   if inserting then
      if :new.nro_cuenta is not null then
         :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(8);
         --el saldo es igual al total de la cobranza y va disminuyendo al pagarse/cobrarse
         :new.mto_total := :new.monto + nvl(:new.mto_comision,0);
         --:new.saldo := :new.mto_total; EN LA APROBACIÓN RECIEN
      end if;
   end if;
   if updating then
      if :new.estado <> :old.estado then
         :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(8);
      end if;
   end if;
END;
/

