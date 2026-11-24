CREATE OR REPLACE TRIGGER IT.TB_GE_CHE_CUSTODIAS
  BEFORE DELETE OR INSERT OR UPDATE
  ON "IT"."GE_CHE_CUSTODIAS"
  for each row

DECLARE
  v_cod_oficina    ba_oficinas.cod_oficina%type;
  v_cod_ofi_camara ba_oficinas.cod_ofi_camara%type;

begin
  If inserting then
    If :new.nro_referencia is not null then
        begin
          select cod_oficina
            into v_cod_oficina
            from pr_solicitudes
           where nro_solicitud = :new.nro_referencia;
        exception
          when no_data_found then
             begin 
                  select g.cod_oficina 
                    into v_cod_oficina
                    from pr_garantias g
                   where g.nro_garantia=:new.nro_referencia;
                   exception 
                         when others then
                       raise_application_error( -20002, 'Al buscar oficina(pr_garantias): '||sqlerrm );
             end;
          when others then
            raise_application_error( -20001, 'Al buscar oficina: '||sqlerrm );
        end;
     End if;
    --se inserta la oficina origen también como oficina de cámara para su posterior envío
    if v_cod_oficina is not null then
       :new.cod_ofi_camara := v_cod_oficina;
       :new.cod_oficina    := v_cod_oficina;
    end if;
    /*If v_cod_oficina is not null then
      select cod_ofi_camara
        into v_cod_ofi_camara
        from ba_oficinas
       where cod_oficina = v_cod_oficina;
    end if;
    If v_cod_ofi_camara is not null then
      :new.cod_ofi_camara := v_cod_ofi_camara;
    end if;*/

  End if;
exception
  when others then
    raise_application_error(-20000,'Al buscar Oficina '||sqlerrm);
end TB_GE_CHE_CUSTODIAS;
/

