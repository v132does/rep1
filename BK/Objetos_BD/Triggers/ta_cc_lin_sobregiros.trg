CREATE OR REPLACE TRIGGER IT.TA_CC_LIN_SOBREGIROS
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_LIN_SOBREGIROS
 FOR EACH ROW
Declare
 v_cod_usuario ge_clientes.cod_usu_oficial%type;
 v_dir_correo  ba_usuarios.dir_correo%type;
Begin
  If updating and :new.estado != :old.estado and :new.estado = 'R' and :new.nro_cuenta is null then
     -- Es la secuencia padre
     Select cod_usu_oficial into v_cod_usuario
       from ge_clientes
      where cod_persona = :new.cod_persona;
      if v_cod_usuario is not null then
        v_dir_correo := fug_obt_dir_mail_usu(v_cod_usuario);
        --- Enviar mail al oficial
        if v_dir_correo is not null then
          it_mail.mail(fug_obt_dir_correo,
             v_dir_correo,
             'Rechazo de Linea de Sobregiro',
             'El usuario '||:new.cod_usu_autoriza||' rechazó la Linea de Sobregiro: '||:new.nro_secuencia||
             ' del Cliente: '||:new.cod_persona||' - '||fue_obt_nom_persona(:new.cod_persona)||'.');
        end if;
      End if;
  End if;
End;
/

