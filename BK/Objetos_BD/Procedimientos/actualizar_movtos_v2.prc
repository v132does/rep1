create or replace procedure it.actualizar_movtos_v2 is
begin
  
  /*update ah_movimientos_his_docum_v2 set actualizado = 'N' where cod_usuario = 'MIGRA';
  update cc_movimientos_his_docum_v2 set actualizado = 'N' where cod_usuario = 'MIGRA';
  commit;*/
  begin
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
  end;
    
 /* actualizar_movimientos_his_v2;
  actualizar_movtos_his_cc_v2;*/
  
end actualizar_movtos_v2;
/

