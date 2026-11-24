create or replace procedure it.prg_par_cta_dat_adicional(p_nro_cuenta    varchar2,
                                                         p_parametro     varchar2,
                                                         p_val_parametro varchar2) is
/** AIU-1073
 Procedimiento para configurar el parametro de la cuenta
**/
begin
  insert into ge_cta_dat_adicionales(nro_cuenta, parametro, val_parametro)
       values (p_nro_cuenta, p_parametro, p_val_parametro);
exception
  when others then
    -- no se hace nada para no cortar el proceso
    NULL;
end;
/
