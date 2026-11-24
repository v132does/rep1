CREATE OR REPLACE TRIGGER IT.TB_AP_REQ_CAMBIOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_REQ_CAMBIOS
 FOR EACH ROW


BEGIN
DECLARE
   v_categoria      ba_usuarios.categoria%type;
BEGIN
   if inserting then
      if :new.descripcion is not null then
         :new.cod_usuario := substr(user,1,10);
      end if;
      v_categoria := fuy_obt_cat_usuario(substr(user,1,10));
      if fuy_es_gerente_ti(substr(user,1,10)) = 'S' and
         v_categoria = 'ST' then
         :new.cod_usu_supervisor := substr(user,1,10);
      end if;
   elsif updating then
      if (:new.estado = 'A' or :new.estado = 'C')and
         :old.estado <> 'P' and
         fuy_es_gerente_ti(substr(user,1,10)) = 'S' then
         :new.cod_usu_supervisor := substr(user,1,10);
      end if;
      if fuy_es_gerente_ti(substr(user,1,10)) = 'N' then
         if :new.estado <> 'A' and
            :new.cod_usuario <> user and
           (:new.descripcion <> :old.descripcion or
            :new.des_jus_cambio <> :old.des_jus_cambio) then
            raise_application_error(-20000,
            'Solo el que realizó el cambio puede modificar');
         end if;
      end if;
      if :new.estado = 'A' and
         :new.descripcion <> :old.descripcion then
          raise_application_error(-20001,
          'El Cambio del Requerimiento no se puede modificar una vez Aprobado');
      end if;
      if :new.estado = 'P' and
        (:old.estado = 'A' or :old.estado = 'C') then
          raise_application_error(-20002,
          'No se puede modificar el Estado una vez Aprobado o Cancelado');
      end if;


   end if;

END;
END;
/

