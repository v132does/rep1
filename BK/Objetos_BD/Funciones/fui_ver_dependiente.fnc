CREATE OR REPLACE FUNCTION IT.fui_ver_dependiente (p_ofi_dependientes in varchar2)
RETURN number IS
v_todas ig_uni_negocios.ofi_dependientes%type := p_ofi_dependientes;
v_oficina ig_uni_negocios.ofi_dependientes%type := null;
v_existe number;
v_pos number;
BEGIN
   loop --para ir separando las oficinas
			v_pos := instr(v_todas,',');
			if v_pos > 0 then
			  v_oficina := substr(v_todas,1,v_pos-1);
			  v_todas   := substr(v_todas,v_pos+1);
			else
			  v_oficina := v_todas;
			  v_todas  :=null;
			end if;
			--verificar si ya existe la oficina entre las dependientes
			begin
				select cod_unidad
				  into v_existe
				  from ig_uni_negocios
				 where instr(','||ofi_dependientes||',' , ','||v_oficina||',') > 0;
			exception
				when others then
				   v_existe := null;
		  end;
			exit when v_todas is null or v_existe is not null;
	 end loop;
	 return v_existe;
END;
/

