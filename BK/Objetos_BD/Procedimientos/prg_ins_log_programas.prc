CREATE OR REPLACE PROCEDURE IT.PRG_INS_LOG_PROGRAMAS ( p_cod_programa ge_log_errores.cod_programa%type,
                                                    p_det_error  ge_log_errores.det_error%type,
                                                    p_cod_persona ge_log_errores.cod_persona%type default null ,
                                                    p_nro_cuenta ge_log_errores.nro_cuenta%type default null
                                                    ) IS
  pragma AUTONOMOUS_TRANSACTION;
BEGIN
  insert into ge_log_errores( fecha,
                              cod_programa,
                              det_error,
                              cod_persona,
                              nro_cuenta)
                      values( sysdate,
                              p_cod_programa,
                              p_det_error,
                              p_cod_persona,
                              p_nro_cuenta);
   COMMIT;
EXCEPTION
  when others then
    NULL;
END;
/

