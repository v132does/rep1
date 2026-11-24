CREATE OR REPLACE TRIGGER IT.TB_CC_CHEQUERAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CHEQUERAS
 FOR EACH ROW


BEGIN
   if inserting then
      :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(4);
      --- Generar estados de cheques iguales a los estados de la chequera
      :new.est_cheques := lpad(:new.estado,:new.can_cheques,:new.estado);
      --for i in 1..:new.can_cheques loop
      --   :new.est_cheques := :new.est_cheques||:new.estado;
      --end loop;
   elsif updating then
      if :new.estado <> :old.estado and :new.fec_cam_estado = :old.fec_cam_estado then
         --- Actualizar fecha de cambio de estado si no lo hizo el programa principal
         :new.fec_cam_estado := pag_cal.fu_obt_fec_actual(4);
      end if;
   end if;
END;
/

