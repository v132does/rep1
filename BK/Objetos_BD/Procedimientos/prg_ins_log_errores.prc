CREATE OR REPLACE PROCEDURE IT.PRG_INS_LOG_ERRORES(P_COD_PROGRAMA   in varchar2,
                                                P_DET_ERROR      in varchar2 default null,
                                                P_CAMPO1         in varchar2 default null,
                                                P_DATO1          in varchar2 default null,
                                                P_CAMPO2         in varchar2 default null,
                                                P_DATO2          in varchar2 default null,
                                                P_CAMPO3         in varchar2 default null,
                                                P_DATO3          in varchar2 default null ) IS
 PRAGMA AUTONOMOUS_TRANSACTION;
begin
  insert into ge_log_errores(cod_programa, campo1, dato1, campo2, dato2, campo3, dato3, det_error)
     values (P_COD_PROGRAMA, P_CAMPO1, P_DATO1, P_CAMPO2, P_DATO2, P_CAMPO3, P_DATO3, P_DET_ERROR);

  commit;
exception
  when others then
     NULL; -- En caso de error no debe generar alerta
end PRG_INS_LOG_ERRORES;
/

