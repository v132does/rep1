CREATE OR REPLACE TRIGGER IT.TA_BA_USU_ROLES
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_USU_ROLES
 FOR EACH ROW

DECLARE

  v_lugar          varchar2(500);
  v_msj_titulo     varchar2(80)  := 'Modificaciones en Rol de Usuario';
  v_mje_mail       LONG;
  v_conn           utl_smtp.connection;
  v_texto          varchar2(5000);
  v_texto_detalle  varchar2(32000) := null;
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := fug_gen_template('P');

  PROCEDURE LP_ENV_MAIL_ROLES(v_situacion in  varchar2, v_cod_rol ba_usu_roles.cod_rol%type,
                               v_cod_usuario ba_usu_roles.cod_usuario%type) IS
  begin
             v_texto := '<br><br>
                         <br><br>
                         <br><br>
                           Le informamos que se realizaron modificaciones en los roles ' ||
                                   upper(v_cod_rol) || '.
                         <br><br>
                           Cod. Usuario: '||v_cod_usuario||'
                         <br><br>
                           Nombre Usuario: '|| fue_obt_nom_usuario(v_cod_usuario)||'
                         <br><br>
                           Oficina: '||fug_obt_ofi_usuario(v_cod_usuario)||'
                         <br><br>
                           Situacion: '||v_situacion||'
                         <br><br>
                           Atentamente.
                         <br><br>
                         <p align="center"><i><b>'|| fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                         <br><br>
                         <br><br>';
              v_mje_mail := v_membrete||v_texto||V_FIN||V_PIE;
             BEGIN
               v_conn     := it_mail.begin_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'),
                                                 FUG_OBT_PARDINAMICO('MAI_COD_ROL'),
                                                 v_msj_titulo,
                                                 IT_MAIL.MULTIPART_MIME_TYPE);
                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                it_mail.write_text(v_conn, v_texto_detalle);
                it_mail.end_mail(v_conn);
              EXCEPTION
                 when others then
                      v_texto := SQLERRM;
                      insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                      values (fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), FUG_OBT_PARDINAMICO('MAI_COD_ROL'), v_msj_titulo, v_texto, sysdate, user)  ;
              end;

  end;

BEGIN

  If FUG_OBT_PARDINAMICO('NOT_COD_ROL') = :NEW.COD_ROL OR  
     FUG_OBT_PARDINAMICO('NOT_COD_ROL') = :OLD.COD_ROL Then
     
   if inserting then
      v_lugar := 'Insertando Nuevo Registro';
      LP_ENV_MAIL_ROLES('ALTA', :new.COD_ROL, :new.COD_USUARIO);
   elsif updating then
      v_lugar := 'Actualizando Registro';
      LP_ENV_MAIL_ROLES('MODIFICACION', :new.COD_ROL, :new.COD_USUARIO);
   elsif deleting then
      v_lugar := 'Borrando Registro';
      LP_ENV_MAIL_ROLES('BAJA', :OLD.COD_ROL, :OLD.COD_USUARIO);
   end if;
 END IF;

EXCEPTION
    When Others Then
         PRG_INS_LOG_ERRORES('TA_BA_USU_ROLES',v_lugar||' : '||SQLERRM);
END;
/

