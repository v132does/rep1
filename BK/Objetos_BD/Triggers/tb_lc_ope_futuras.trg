CREATE OR REPLACE TRIGGER IT.TB_LC_OPE_FUTURAS
 BEFORE UPDATE
 ON LC_OPE_FUTURAS
 FOR EACH ROW
BEGIN
   if updating then
     -- Si cambia de Ingresado o Pendiente a Estado Normal
     if :new.estado = 'N' and :old.estado in ('I','X')then
       :new.fec_est_activo := pae_cnf.fu_obt_fec_actual(7);
     end if;
   end if;
END;
/

