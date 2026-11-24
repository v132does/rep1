create or replace procedure it.prg_ins_log_pag_int_salario (
   p_cod_intencion   it.ge_log_pag_int_salario.cod_intencion%type,
   p_cod_nomina      it.ge_log_pag_int_salario.cod_nomina%type,
   p_cod_empleado    it.ge_log_pag_int_salario.cod_empleado%type,
   p_det_error       it.ge_log_pag_int_salario.det_error%type
) is
   pragma autonomous_transaction;
begin
   begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   end;
   insert into it.ge_log_pag_int_salario (
      cod_intencion,
      cod_nomina,
      cod_empleado,
      det_error
   ) values ( p_cod_intencion,
              p_cod_nomina,
              p_cod_empleado,
              p_det_error );
   commit;
exception
   when others then
      rollback;
end;
/