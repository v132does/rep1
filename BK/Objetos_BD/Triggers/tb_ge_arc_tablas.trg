CREATE OR REPLACE TRIGGER IT.TB_GE_ARC_TABLAS
 BEFORE UPDATE
 ON GE_ARC_TABLAS
 FOR EACH ROW
DECLARE
 v_nom_usuario ba_usuarios.nombre%type;
BEGIN
  if updating then
     if :new.referencia in ('PAG_SUELDOS','PAG_SUE_HACIENDA') and :new.borrar = 'S' then
        --Asigno el valor correcto
        :new.borrar := 'N';
        --Obtengo el nombre del usuario
        Begin
          select a.nombre
             into v_nom_usuario
           from ba_usuarios a
           where a.cod_usuario = substr(user,1,10);
        exception
          when others then
             v_nom_usuario := null;
        end;
        --Envio e-mail.
        Begin
          it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                       fug_obt_pardinamico('CAM_MAR_DIR_EP'),
                       'Configuración Pago de Sueldos HomeBanking',
                       'Se ha intentado actualizar el campo de borrado que afectará el Pago de Sueldos por HomeBanking. '||chr(10)||
                       'Usuario: ' ||substr(user,1,10)||' '||trim(v_nom_usuario)||chr(10)||
                       'IP: ' ||sys_context('USERENV','IP_ADDRESS'));                       
        exception
          when others then
             null;
        end;
     end if;
  end if;
end;
/

