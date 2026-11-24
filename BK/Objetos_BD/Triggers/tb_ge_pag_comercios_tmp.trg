CREATE OR REPLACE TRIGGER IT.TB_GE_PAG_COMERCIOS_TMP
BEFORE INSERT ON GE_PAG_COMERCIOS_TMP
FOR EACH ROW

DECLARE

BEGIN
  
  --Si no se levanta la fecha de proceso asigna la fecha Actual
  if :new.fec_proceso is null then
     :new.fec_proceso      := pag_cal.fu_obt_fec_actual(4);
     :new.fec_proceso_real := pag_cal.fu_obt_fec_actual(4);
  end if;   
  
  --Si no se levanta la fecha de envio asigna la fecha habil anterior
  if :new.fec_envio is null then
    :new.fec_envio := pag_cal.fu_obt_fec_ant_hab(pag_cal.fu_obt_fec_actual(4),1);
  end if;
  
exception
   when others then
     if sqlcode < -20000  then
     	  raise;
     else
        raise_application_error(-20000,'Error en Trigger TB_GE_PAG_COMERCIOS_TMP : ' || sqlerrm);
     end if;
END;
/

