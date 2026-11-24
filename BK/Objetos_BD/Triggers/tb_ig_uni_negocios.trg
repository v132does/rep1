CREATE OR REPLACE TRIGGER IT.TB_IG_UNI_NEGOCIOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON IG_UNI_NEGOCIOS
    FOR EACH ROW
DECLARE
  v_cod_unidad ig_uni_negocios.cod_unidad%type;
BEGIN
   	if inserting then --updating da mutating
      --validar oficinas dependientes
  		if :new.ofi_dependientes is not null then
        if :new.cod_banca is not null or :new.cod_oficina is null then
           raise_application_error(-20000,'Sólo puede definir Oficina Dependiente si la Unidad está asociada a una Oficina');
        end if;
  			--verficar q la oficina dependiente no esté como principal
        begin
  				select cod_unidad
  				  into v_cod_unidad
  				  from ig_uni_negocios
  				 where cod_oficina is not null
  				   and instr(','||:new.ofi_dependientes||',' , ','||cod_oficina||',') > 0 
  				   and rownum = 1;
  				 raise_application_error(-20000,'La Oficina Dependiente ya existe como Oficina Principal de la unidad '||v_cod_unidad);
  			exception
  				when no_data_found then
  				   null;
  				when others then
  				   raise_application_error(-20000,'Recup.unidad '||sqlerrm);
  			end;
  			--verficar q la oficina principal no esté como dependiente
  			begin
  				select cod_unidad
  				  into v_cod_unidad
  				  from ig_uni_negocios
  				 where ofi_dependientes is not null
  				   and instr(','||ofi_dependientes||',' , ','||:new.cod_oficina||',') > 0 
  				   and rownum = 1;
  				 raise_application_error(-20000,'La Oficina ya existe como Oficina Dependiente de la unidad '||v_cod_unidad);
  			exception
  				when no_data_found then
  				   null;
  				when others then
  				   raise_application_error(-20000,'Recup.unidad. '||sqlerrm);
  			end;
  		  --verificar si ya existe la dependiente como dependiente de otra unidad
  		  v_cod_unidad := fui_ver_dependiente(:new.ofi_dependientes);
  		  if nvl(v_cod_unidad,0) > 0 then
  			  raise_application_error(-20000,'La Oficina Dependiente ya existe como Dependiente de la unidad '||v_cod_unidad);
  		  end if;	 	 
  		end if;
    end if;
END;
/

