CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PAR_CIERRE
 IS
BEGIN
   --- Actualizar parametro de nro referencia
   prg_act_par_dinamico('SIG_NRO_REFERENCIA',null,null,null,null,0);
   --- Inicializar secuencia de autorizaciones
END;
/

