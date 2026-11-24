CREATE OR REPLACE TRIGGER IT.TB_BW_OFE_CLIENTES
 BEFORE DELETE OR INSERT OR UPDATE
 ON BW_OFE_CLIENTES
 FOR EACH ROW
DECLARE
 v_existe varchar2(1);
BEGIN
   -- el usuario equivalente sólo puede ser de 4 caracteres
   if inserting or updating then
      begin
         select 'S'
           into v_existe
           from ba_cod_referencias r
          where r.dominio = 'TIP_OFE_CLIENTE'
            and upper(r.val_minimo) = upper(:new.producto);
      exception
         when no_data_found then
            raise_application_error(-20000,'Producto no encontrado en el dominio "TIP_OFE_CLIENTE".');
      end;
   end if;
END;
/

