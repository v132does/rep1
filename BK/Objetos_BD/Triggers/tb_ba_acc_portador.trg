CREATE OR REPLACE TRIGGER IT.tb_ba_acc_portador
 BEFORE DELETE
 ON BA_ACC_PORTADOR
 FOR EACH ROW

DECLARE
   fec_actual    ge_calendarios.fec_actual%type:= pag_cal.fu_obt_fec_actual(1);

BEGIN
   if deleting then
      --- Eliminar historico de estados
      insert into sb_bcp_acc_eliminadas(fecha,cod_persona)
      values (fec_actual,:old.cod_persona);
   end if;
   EXCEPTION
      when others then
      
      RAISE_APPLICATION_ERROR(-20002,'No se pudo eliminar'||' '||SQLERRM);
END;
/

