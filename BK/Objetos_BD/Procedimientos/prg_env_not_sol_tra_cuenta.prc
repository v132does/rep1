create or replace procedure it.PRG_ENV_NOT_SOL_TRA_CUENTA(p_cod_persona  in ba_personas.cod_persona%type,
                                                          p_tip_producto in ge_mai_onb_templates.tip_producto%type,
                                                          p_parameros    in ba_env_correos.parametros%type,
                                                          p_correo       in ba_personas.dir_correo%type,
                                                          p_cod_error    out number,
                                                          p_mensaje      out varchar2) is
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  insert into it.ba_env_correos
    (cod_persona,
     tip_producto,
     estado,
     fec_registro,
     parametros,
     mai_destinatario)
  values
    (p_cod_persona, 
     p_tip_producto, 
    'P', 
    sysdate, 
    p_parameros, 
    p_correo);
  commit;
exception
  when others then
    p_cod_error := 99;
    p_mensaje   := 'Ocurrio un error al insertar en la tabla ba_env_correos ';
    prg_ins_log_programas('PRG_ENV_NOT_SOL_TRA_CUENTA',
                          substr('Correo. ' || p_correo || ' Tip_producto ' ||
                                 p_tip_producto || ' Error: ' || p_mensaje || ' ' ||
                                 DBMS_UTILITY.format_error_stack || ' - ' ||
                                 DBMS_UTILITY.format_error_backtrace,
                                 1,
                                 4000),
                          p_cod_persona,
                          null);
end PRG_ENV_NOT_SOL_TRA_CUENTA;
/

