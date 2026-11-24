CREATE OR REPLACE TRIGGER IT.TA_IG_UNI_NEGOCIOS
AFTER DELETE OR INSERT OR UPDATE
     ON IG_UNI_NEGOCIOS
    FOR EACH ROW
declare
v_nuevo ig_uni_negocios.ofi_dependientes%type;
BEGIN
  IF inserting THEN
    begin
      if :new.cod_oficina is not null or :new.ofi_dependientes is not null then
         v_nuevo := :new.cod_oficina ||','|| :new.ofi_dependientes;    
         --actualizar la unidad a la oficina principal y dependientes
         update ba_usuarios
            set cod_unidad  = :new.cod_unidad
          where instr(','||v_nuevo||',' , ','||cod_oficina||',') > 0 --cod_oficina = :new.cod_oficina
            and cod_banca   is null
            and oficial     = 'S';
      elsif :new.cod_banca is not null then
     		 update ba_usuarios 
    		    set cod_unidad = :new.cod_unidad
  		    where cod_banca  = :new.cod_banca
            and oficial    = 'S';
      end if;
    exception
      when others then
       raise_application_error (-20000,'Modificar BA_USUARIOS. '||sqlerrm);
    end;

  ELSIF updating THEN

/*    if nvl(:new.cod_oficina,-1) <> nvl(:old.cod_oficina,-1) or 
       nvl(:new.cod_banca,-1)   <> nvl(:old.cod_banca,-1) or 
       nvl(:new.ofi_dependientes,-1) <> nvl(:old.ofi_dependientes,-1) then
*/       --guardar todas las oficinas juntas
       v_nuevo := :new.cod_oficina ||','|| :new.ofi_dependientes;
      begin
        -- Nula las unidades de los usuarios con la unidad vieja
     		update ba_usuarios 
    		   set cod_unidad = null
  		   where cod_unidad = :new.cod_unidad
           and oficial    = 'S';
        if v_nuevo is not null and :new.cod_banca is null then
          -- Carga la unidad a la oficina principal y dependientes
           update ba_usuarios
              set cod_unidad  = :new.cod_unidad
            where instr(','||v_nuevo||',' , ','||cod_oficina||',') > 0 --cod_oficina = :new.cod_oficina
              and nvl(cod_banca,0) <> 1
              and oficial     = 'S';
        elsif :new.cod_banca is not null and :new.cod_oficina is null then
          -- Carga la unidad a todas las bancas
           update ba_usuarios
              set cod_unidad  = :new.cod_unidad
            where cod_banca   = :new.cod_banca
              and oficial     = 'S';
        end if;
      exception
        when others then
          raise_application_error (-20001,'Modificar BA_USUARIOS. '||sqlerrm);
      end;
/*    end if;*/
  ELSIF deleting then
   		update ba_usuarios 
  		   set cod_unidad  = null
		   where cod_unidad = :old.cod_unidad;
  END IF;
END;
/

