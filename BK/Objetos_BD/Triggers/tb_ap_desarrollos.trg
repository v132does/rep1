CREATE OR REPLACE TRIGGER IT.TB_AP_DESARROLLOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_DESARROLLOS
 FOR EACH ROW

DECLARE
v_categoria ba_usuarios.categoria%type;
BEGIN
   if updating then
      -- Verificar si el usuario es Supervisor de Tecnologia
      v_categoria := fuy_obt_cat_usuario(user);
      if v_categoria <> 'ST' and :new.estado <> 'NV' then
         raise_application_error(-20000,
         'Debe ser Supervisor de Tecnología para Modificar');
      end if;
      /*Referencias: TR- Transferido, VE - Verificado, NV - No Verificado*/
      if :new.estado <> :old.estado then
         if (:old.estado <> 'VE' and :new.estado = 'TR') and
            :new.transferir = 'N' then
            raise_application_error(-20001,
            'Debe estar Verificado para Transferir');
         end if;
         if :new.estado = 'NV' and :old.estado <> 'NV' then
              raise_application_error(-20001,
            'No se puede modificar el Estado una vez Verificado o Transferido');
         end if;
         --Fija el Usuario y Fecha de Verificación
         if (:old.estado = 'NV' and  :new.estado = 'VE') and
            (:new.transferir = 'N' or :new.transferir = 'S') then
            :new.cod_usu_verifica := substr(user,1,10);
            :new.fec_verificado := sysdate;
         end if;
         --Fija el Usuario y Fecha de Transferencia
         if (:old.estado = 'VE'  and :new.estado = 'TR') and
             :new.transferir = 'S' then
               :new.cod_usu_transfiere := substr(user,1,10);
               :new.fec_transferido := sysdate;
         end if;
      end if;
      if (:new.transferir <> :old.transferir) then
         if (:new.transferir = 'S' and :new.estado = 'NV') then
            raise_application_error(-20001,
            'Debe estar Verificado para Transferir');
         elsif (:new.transferir = 'N' and :new.estado = 'TR') then
            raise_application_error(-20001,
            'Transferir debe estar chequedo si Estado es Transferido');
         elsif :new.transferir = 'S' and
              (:new.estado = 'NV' and :old.estado <> 'NV') then
            raise_application_error(-20001,
            'No se puede modificar el Estado una vez Verificado o Transferido');
         end if;
      end if;
      --- No puede modificarse datos de desarrollos verificados o transferidos
      if   :new.estado in ('VE','TR')
      and (:new.cod_usu_responsable <> :old.cod_usu_responsable
       or  :new.cod_programa <> :old.cod_programa
       or  :new.descripcion <> :old.descripcion
       or  :new.ubi_ejecutable <> :old.ubi_ejecutable
       or  :new.ubi_fisica <> :old.ubi_fisica
       or  nvl(:new.fec_inicio,trunc(sysdate)) <> nvl(:old.fec_inicio,trunc(sysdate))
       or  nvl(:new.fec_fin,trunc(sysdate)) <> nvl(:old.fec_fin,trunc(sysdate))
       or  nvl(:new.observacion,'x') <> nvl(:old.observacion,'x')) then
          raise_application_error(-20002,'Datos verificados no pueden modificarse');
      end if;
      if  :new.estado = 'TR'
      and (:new.cod_usu_verifica <> :old.cod_usu_verifica
       or  :new.fec_verificado <> :old.fec_verificado) then
          raise_application_error(-20002, 'Datos de verificación no pueden modificarse');
      end if;
  elsif deleting then
     if :old.estado = 'VE' or
        :old.estado = 'TR' then
        raise_application_error(-20001,
        'No se puede Eliminar el registro una vez Verificado o Transferido');
     end if;

  end if;

END;
/

