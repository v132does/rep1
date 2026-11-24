create or replace procedure it.actualizar_movtos_bor_v2 is
begin

  /*update it.ah_movimientos_his set actualizado = 'N'  where
         fecha >= to_date('01/01/2010','dd/MM/yyyy') and cod_modulo = 3 and cod_modalidad = 31;

  update it_cc_movimientos_his set actualizado = 'N'  where
         fecha >= to_date('01/01/2010','dd/MM/yyyy') and cod_modulo = 4 and cod_modalidad = 41;
  commit;*/
  
  begin
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
  end;
  actualizar_movtos_ah_bor_v2;
 -- actualizar_movtos_cc_bor_v2;

end actualizar_movtos_bor_v2;
/

