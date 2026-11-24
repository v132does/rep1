CREATE OR REPLACE TRIGGER IT.TB_BA_PROGRAMAS
   BEFORE DELETE OR INSERT OR UPDATE ON BA_PROGRAMAS
   FOR EACH ROW
DECLARE
begin
   if inserting or updating then
     --if (:new.descripcion <> :old.descripcion)  then
         if fug_val_dat_descripcion(:new.descripcion) <> 'S' then
            raise_application_error(-20010,
                                    'Error al validar Descripcion ' ||
                                    sqlerrm);
         end if;
     -- end if;
     
     -- valida la descripcion detallada del programa no quede nula

        if :new.des_detallada is null then
           raise_application_error(-20010,'La descripción detallada del programa no puede quedar nula.');
        end if;
        
       if fug_val_dat_descripcion(:new.des_detallada) <> 'S' then
           raise_application_error(-20010,'Error al validar Descripcion Detallada.');
        end if; 
       
      
      -- valida la ubicacion en el menu
        if :new.ubi_menu is null  then
  	       raise_application_error(-20011,'La ubicación del programa en menu no puede quedar nula.');
  	    end if;
        
        if :new.ubi_menu <> :old.ubi_menu then
         if length(:new.ubi_menu) < 10 then
            raise_application_error(-20011,
                                    'Cadena introducida no alcanza diez Caracteres');
         end if;
      end if;
 
    end if;
exception
   when others then
      raise_application_error(-20000, sqlerrm);
end TB_BA_PROGRAMAS;
/

