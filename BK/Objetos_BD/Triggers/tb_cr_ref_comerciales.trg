CREATE OR REPLACE TRIGGER IT.TB_CR_REF_COMERCIALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON CR_REF_COMERCIALES
 FOR EACH ROW


BEGIN
   if inserting then
      --- Validar formato del teléfono
      /* No debe validar porque pueden escribir algo mas..
      pre_ver_fmt_telefono(:new.telefono);
      */
			if :new.est_verificacion is null then
				 :new.est_verificacion:= 'N';
			end if;
			
      if :new.est_verificacion in ('S','V') then
         :new.fec_verificacion    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
         :new.cod_usu_verificador := user;
      end if;
   end if;
   if updating then
      /* No debe validar porque pueden escribir algo mas..
      if :new.telefono <> :old.telefono then
         --- Validar formato del teléfono
         pre_ver_fmt_telefono(:new.telefono);
      end if;
      */
      if :new.est_verificacion in ('S','V') and
         :new.est_verificacion <> :old.est_verificacion then
         :new.fec_verificacion    := pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
         :new.cod_usu_verificador := user;
      end if;
   end if;
END;
/

