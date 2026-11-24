CREATE OR REPLACE PROCEDURE IT.PRP_DEV_PRE_FIN
 IS
BEGIN
   PAP_DEV.PR_PRO_DEV_CUOTAS('F');
   /* el procedimiento de actualización de saldos mensuales se invocará en el inicio de día para mejorar los tiempos del cierre */
   /* PRG_ACT_DEV_DIARIO; */
END;

 
/
