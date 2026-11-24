CREATE OR REPLACE TRIGGER IT.TA_BA_COD_REFERENCIAS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_COD_REFERENCIAS
 FOR EACH ROW
BEGIN
   if inserting then
      --actualizar cg_ref_codes, si no existe recién insertar
      update cg_ref_codes
         set rv_high_value = :new.val_maximo,
             rv_abbreviation = :new.abreviatura,
             rv_meaning = :new.significado      
       where rv_domain = :new.dominio
         and rv_low_value = :new.val_minimo;
      if sql%notfound then
        insert into cg_ref_codes
           (rv_domain, rv_low_value, rv_high_value,
            rv_abbreviation, rv_meaning)
        values
           (:new.dominio,:new.val_minimo,
            :new.val_maximo,:new.abreviatura,:new.significado);
      end if;
   elsif updating then
      delete cg_ref_codes
        where rv_domain = :old.dominio
          and rv_low_value = :old.val_minimo;
      insert into cg_ref_codes
         (rv_domain, rv_low_value, rv_high_value,
          rv_abbreviation, rv_meaning)
      values
         (:new.dominio,:new.val_minimo,
          :new.val_maximo,:new.abreviatura,:new.significado);
   elsif deleting then
       delete cg_ref_codes
        where rv_domain = :old.dominio
          and rv_low_value = :old.val_minimo;
   end if;
end;
/

