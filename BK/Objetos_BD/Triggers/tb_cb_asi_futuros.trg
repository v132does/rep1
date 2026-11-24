CREATE OR REPLACE TRIGGER IT.TB_CB_ASI_FUTUROS
 BEFORE UPDATE or delete
 ON CB_ASI_FUTUROS
 FOR EACH ROW

BEGIN
   if updating and nvl(PAE_CNF.G_PROGRAMA,'x') = ('BMASIFUT') then
      --Parametro seteado para no grabar asientos despues de generar Asientos Automaticos--
      if :new.cod_cargo is not null then
         raise_application_error(-20000,'No se permite realizar modificaciones de Asientos generados por Cargos-Gastos Diferidos. '||PAE_CNF.G_PROGRAMA);
      end if;
   end if;
   if updating or deleting then
      if :new.nro_asi_real is not null and :old.nro_asi_real is not null then
         raise_application_error(-20000,'Asiento n° '||:new.nro_asiento||' ya fue procesado.');
      end if;
      if nvl(:new.actualizado,'N') = 'S' then
         raise_application_error(-20000,'Asiento n° '||:new.nro_asiento||' ya fue actualizado.');
      end if;
   end if;
END;
/

