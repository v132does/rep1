CREATE OR REPLACE TRIGGER IT.TB_BA_PER_FISICAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_PER_FISICAS
 FOR EACH ROW

begin
   --sólo si no viene de recepción de tarjetas
   if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'TPRECTAR' then
     if inserting then
        if :new.fec_nacimiento is not null then
           if :new.FEC_NACIMIENTO < (SYSDATE - 36500) OR
              :new.FEC_NACIMIENTO > SYSDATE THEN
  	        raise_application_error(-20000,'Debe ingresar una fecha de nacimiento valida.');
           end if;
        end if;
     elsif updating then
        if :old.fec_nacimiento <> :new.fec_nacimiento or
           (:old.fec_nacimiento is null and :new.fec_nacimiento is not null) then
           if :new.FEC_NACIMIENTO < (SYSDATE - 36500) OR
              :new.FEC_NACIMIENTO > SYSDATE THEN
  	        raise_application_error(-20000,'Debe ingresar una fecha de nacimiento valida.');
           end if;
        end if;
     end if;
  end if;
     --DYDMR-2480 ITGF - Nombre de Clientes con caracteres especiales - SC 21234
   if inserting or updating then
      if :new.pri_nombre <> :old.pri_nombre or  :new.seg_nombre <> :old.seg_nombre or
         :new.pri_apellido <> :old.pri_apellido or :new.seg_apellido <> :old.seg_apellido then
         :new.pri_nombre := replace(replace(:new.pri_nombre, chr(10), ''), chr(13), '');
         :new.seg_nombre := replace(replace(:new.seg_nombre, chr(10), ''), chr(13), '');
         :new.pri_apellido := replace(replace(:new.pri_apellido, chr(10), ''), chr(13), '');
         :new.seg_apellido := replace(replace(:new.seg_apellido, chr(10), ''), chr(13), '');
         
      end if;
   end if;
end;
/

