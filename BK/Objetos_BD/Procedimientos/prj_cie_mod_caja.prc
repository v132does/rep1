CREATE OR REPLACE PROCEDURE IT.PRJ_CIE_MOD_CAJA
IS
BEGIN
   --- Actualizar estado del módulo
   update ba_modulos
   set estado = 4
   where cod_modulo = 9;
   --- Transferir movimientos
   insert into cj_movimientos_his
   select * from cj_movimientos;
  --- CROGEFIT-3  Formularios F.I.T
  insert into cj_acu_imp_transacciones_his
  select *from cj_acu_imp_transacciones;
END;
/

