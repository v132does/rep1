CREATE OR REPLACE PROCEDURE IT.prg_ins_log_ted(p_mensaje       cj_log_ted.mensaje%type,
                                               p_nro_telefono  cj_log_ted.nro_telefono%type,
                                               p_mail          cj_log_ted.mail%type,
                                               p_otp           cj_log_ted.otp%type,
                                               p_canal         cj_log_ted.canal%type,
                                               p_cuerpo        cj_log_ted.cuerpo%type,
                                               p_cod_respuesta out number,
                                               p_msj_respuesta out varchar2) IS
  v_cod_error   number:= 0;
  v_msj_error   varchar2(200);
  v_log_mensaje varchar2(4000);

BEGIN
  BEGIN
    INSERT INTO it.cj_log_ted
      (hora, fecha, mensaje, nro_telefono, mail, otp, canal, cuerpo)
    VALUES
      (TO_CHAR(Sysdate, 'HH24:MI:SS'),
       TO_CHAR(Sysdate, 'DD-MM-YYYY'),
       p_mensaje,
       p_nro_telefono,
       p_mail,
       p_otp,
       p_canal,
       p_cuerpo);
  
  EXCEPTION
    WHEN OTHERS THEN
      v_cod_error   := 1;
      v_msj_error   := 'Error al realizar el insert. ';
      v_log_mensaje := substr('Error al realizar el insert. ' ||
                       DBMS_UTILITY.format_error_stack || ' - ' ||
                       DBMS_UTILITY.format_error_backtrace, 1, 4000);
      prg_ins_log_programas('PRG_INS_LOG_TED', v_log_mensaje, null, null);
    
  END;

  if nvl(v_cod_error, 0) != 0 then
    p_cod_respuesta := v_cod_error;
    p_msj_respuesta := v_msj_error;
  else
    p_cod_respuesta := 0;
    p_msj_respuesta := 'OK';
  end if;

EXCEPTION
  when others then
    p_cod_respuesta := 2;
    p_msj_respuesta := 'Ocurrio un error en el proceso';
    v_log_mensaje   := substr('Ocurrio un error en el proceso. ' ||
                       DBMS_UTILITY.format_error_stack || ' - ' ||
                       DBMS_UTILITY.format_error_backtrace, 1, 4000);
    prg_ins_log_programas('PRG_INS_LOG_TED', v_log_mensaje, null, null);
END;
/

