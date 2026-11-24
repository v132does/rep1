CREATE OR REPLACE TRIGGER IT.TB_BA_USUARIOS
 BEFORE INSERT OR UPDATE
 ON "IT"."BA_USUARIOS"
 FOR EACH ROW
DECLARE
  v_existe varchar2(1);
  v_dir_correo ge_par_generales.dir_correo%type;
  v_posicion   number(2);
  v_dominio varchar2(50);
  v_servidor varchar2(50);
  v_cod_unidad ba_usuarios.cod_unidad%type;
  /* DYDMR-1623 - EP SC 13684 - N.AN. 2015, verifica que cod_usuario no tenga caracteres especiales */
  PROCEDURE LP_REG_VER_CAR_ESP;
  --
  /* DYDMR-1623 - EP SC 13684 - N.AN. 2015, verifica que cod_usuario no tenga caracteres especiales */
  PROCEDURE LP_REG_VER_CAR_ESP IS
  begin
     IF nvl(LENGTH(TRANSLATE(:new.cod_usuario, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_', ' ')),0) > 0 then
     raise_application_error(-20000,
        'Código de usuario sólo puede contener valores numéricos y alfanumericos, favor verifique.');
     end if;
  end;
begin
    if :new.dir_correo is not null and nvl(:new.dir_correo,'x') <> nvl(:old.dir_correo,'z') then
        --Validar si tiene un dominio especificado
        select instr(:new.dir_correo,'@')
        into v_posicion
        from dual;

        if v_posicion = 0 then
            raise_application_error(-20000,'Debe especificar un dominio');
        else
            --Recuperar el dominio
            select substr(:new.dir_correo,instr(:new.dir_correo,'@')),
                   substr(dir_correo,instr(dir_correo,'@'))
            into v_dominio, v_servidor
            from ge_par_generales;

            --Validar que esté correcto
            if (v_dominio <> v_servidor and v_dominio <> substr(v_servidor,1,9)||substr(v_servidor,25,31))  then
                raise_application_error(-20000,'Dominio no puede ser distinto de '||v_servidor|| ' o '||substr(v_servidor,1,9)||substr(v_servidor,25,31));
            end if;
        end if;

        if updating then
            begin
                  v_existe := 'N';
                  If :new.oficial <> :old.oficial and :new.oficial = 'N' and fug_obt_tip_implementacion not in (1,7) then
                     select 'S'
                       into v_existe
                       from GE_CLIENTES gec
                      where gec.cod_usu_oficial = :new.cod_usuario
                        and rownum = 1;
                     If v_existe = 'S' then
                        raise_application_error(-20000,
                        'No se puede modificar el oficial porque esta relacionado con algun(os) cliente(s)');
                     End if;
                  End if;
              exception
                when no_data_found then null;
              end;

              begin
                    v_existe := 'N';
                    If :new.promotor <> :old.promotor and :new.promotor = 'N' then
                       select 'S'
                         into v_existe
                         from BA_PERSONAS bap
                        where bap.cod_usu_promotor = :new.cod_usuario
                          and rownum = 1;
                    End if;
                    If v_existe = 'S' then
                      raise_application_error(-20001,
                      'No se puede modificar el promotor porque esta relacionado con alguna(s) persona(s)');
                    End if;
                exception
                  when no_data_found then null;
              end;

              if :new.dir_correo <> :old.dir_correo then
                  v_dir_correo := fug_obt_dir_correo;
                  If v_dir_correo is not null then
                      begin
                        it_mail.mail(v_dir_correo,
                        :new.dir_correo,
                        'Prueba de Cambio de Correo',
                        'Prueba de Cambio de Correo');
                      exception
                        when others then
                          raise_application_error(-20000,'Fallo al tratar de enviar correo a la cuenta '||
                          :new.dir_correo||sqlerrm);
                      end;
                  End if;
              end if;

        end if;--if updating

        if inserting then
            begin
              v_dir_correo := fug_obt_dir_correo;
              If v_dir_correo is not null then
                  it_mail.mail(v_dir_correo,
                  :new.dir_correo,
                  'Prueba de Correo',
                  'Prueba de Correo');
              End if;
            exception
              when others then
              raise_application_error(-20000,'Fallo al tratar de enviar correo a la cuenta '||
              :new.dir_correo||sqlerrm);
            end;
        end if;
    end if;--:new.dir_correo is not null

    if inserting or updating then
       if :new.oficial ='S' then
          --si modifica la banca u oficina, actualizar con la unidad de negocios correspondiente
          if nvl(:new.cod_banca,-1) <> nvl(:old.cod_banca,-1) or
             nvl(:new.cod_oficina,-1) <> nvl(:old.cod_oficina,-1) or
             nvl(:new.oficial,'x') <> nvl(:old.oficial,'x') then
             --buscar la unidad que le corresponde x banca
             begin
               select cod_unidad
                 into v_cod_unidad
                 from ig_uni_negocios
                where cod_banca = :new.cod_banca;
             exception
               when no_data_found then
                  v_cod_unidad := null;
               when others then
                  raise_application_error(-20000,'Recup.Unidad para Banca '||:new.cod_oficina);
             end;
             if v_cod_unidad is null then
                --buscar la unidad que le corresponde x oficina
                begin
                 select cod_unidad
                   into v_cod_unidad
                   from ig_uni_negocios
                  where cod_oficina = :new.cod_oficina
                     or instr(','||ofi_dependientes||',' , ','||:new.cod_oficina||',') > 0;
                exception
                 when no_data_found then
                    v_cod_unidad := null;
                 when others then
                    raise_application_error(-20000,'Recup.Unidad para Oficina '||:new.cod_oficina);
                end;
             end if;
             :new.cod_unidad := v_cod_unidad;
          end if;
       else --no es oficial
          :new.cod_unidad := null;
       end if;
    end if;
    if inserting then
      LP_REG_VER_CAR_ESP; --DYDMR-1623 - EP SC 13684 - N.AN. 2015.
    end if;
end;
/

