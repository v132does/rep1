CREATE OR REPLACE TRIGGER IT.TA_GE_EMBARGOS
  after DELETE OR INSERT OR UPDATE 
  on GE_EMBARGOS  
  for each row
declare
  v_dir_cor_varios varchar2(200);
  cursor  usuarios is
    select cli.cod_usu_oficial, ofi.cod_usu_encargado
      from ba_oficinas ofi, 
           ge_clientes cli
     where cli.cod_persona = :new.cod_persona
       and ofi.cod_oficina = cli.cod_oficina;
begin
  If inserting then
    -- envio mail al oficial y al encargado de la sucursal
     for i in usuarios loop
        v_dir_cor_varios := null;
        if i.cod_usu_oficial is not null then
           v_dir_cor_varios := fug_obt_dir_mail_usu(i.cod_usu_oficial);
        end if;
        if i.cod_usu_encargado is not null then
           if v_dir_cor_varios is not null then
              v_dir_cor_varios := v_dir_cor_varios || ';'; -- separador
           end if;   
           v_dir_cor_varios := v_dir_cor_varios||fug_obt_dir_mail_usu(i.cod_usu_encargado);
        end if;   
        if v_dir_cor_varios is not null then
           -- hay direccion de envio, por lo que envio el mail
           it_mail.mail(fug_obt_dir_correo,
                        v_dir_cor_varios,
                        'Embargo de Cuentas',
                        'Se ha solicitado el embargo de cuentas del Cliente: '||
                        :new.cod_persona||' '||fue_obt_nom_persona(:new.cod_persona)||', Nro. oficio: '||
                        :new.nro_oficio||' - Usuario: '||:new.usu_insercion||'.'||
                        chr(10)||'Atentamente.');
        end if;    
     end loop;
  End if;
end;
/

