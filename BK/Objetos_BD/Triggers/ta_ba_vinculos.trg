CREATE OR REPLACE TRIGGER IT.TA_BA_VINCULOS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_VINCULOS
 FOR EACH ROW


BEGIN
   if inserting then
   --DE-2588 - Ajuste de funcionamiento en carga de Estado Civil Union de Hecho - DYD-SDSL-3499 - DIC/2016
      if :new.tipo in ('E','C') then
         --- Insertar relacion de vinculos entre esposos de ambos lados
         BEGIN
            insert into ba_vinculos(cod_persona, cod_per_vinculo, tipo)
            values (:new.cod_per_vinculo, :new.cod_persona, :new.tipo);
         exception
            when dup_val_on_index then null;
            when others then null;
         END;
      end if;
   end if;
END;
/

