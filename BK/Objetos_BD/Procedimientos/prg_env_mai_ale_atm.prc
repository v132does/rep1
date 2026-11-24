CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAI_ALE_ATM(p_texto in varchar2,
                                                p_cod_usuario in varchar2,
                                                p_fecha in date) IS
  v_para       VARCHAR2(4000);
  -- Variables para mail
  v_asunto     VARCHAR2(2000);
  v_texto LONG;
  v_hin_mail ge_ra_log_mail.hor_inicio%type;
  v_hfi_mail ge_ra_log_mail.hor_fin%type;
  v_det_error ge_ra_log_mail.det_error%type;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
     v_asunto := p_texto;
     v_texto := p_texto;
     BEGIN
        insert into ge_log_err_hor_usu_atm (fecha, hora, cod_usuario, det_error)
        values
        (p_fecha, to_char(sysdate, 'hh24:mi:ss'), p_cod_usuario, v_texto);
        commit;
      EXCEPTION
         when others then null;
      END;

      BEGIN
         v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
         v_para := fug_obt_pardinamico('ENV_EMA_ERR_ATM');
         it_mail.mail(fug_obt_dir_correo, v_para, v_asunto, v_texto);
         v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
      EXCEPTION
         when others then
            v_det_error := substr(sqlerrm, 1, 4000);
            INSERT INTO ge_ra_log_mail (fec_envio, nom_archivo, dir_correo, mensaje,
                                        det_error, hor_inicio, hor_fin)
                                VALUES (SYSDATE, null, v_para, v_asunto,
                                        v_det_error, v_hin_mail, v_hfi_mail);
     END;
     commit;
EXCEPTION
  WHEN OTHERS THEN
       raise_application_error(-20000,'Error en Envio de Emails ATM :'||SQLERRM);
END prg_env_mai_ale_atm;
/

