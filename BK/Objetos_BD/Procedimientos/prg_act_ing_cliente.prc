CREATE OR REPLACE PROCEDURE IT.PRG_ACT_ING_CLIENTE( P_COD_PERSONA IN GE_ING_CLIENTES.COD_PERSONA%TYPE,
                                                    P_TIP_INGRESO IN GE_ING_CLIENTES.TIP_INGRESO%TYPE,
                                                    P_MON_INGRESO IN GE_ING_CLIENTES.MON_INGRESO%TYPE,
                                                    P_RAN_INGRESO IN GE_ING_CLIENTES.RAN_INGRESO%TYPE,
                                                    P_ERROR       IN GE_ING_CLIENTES.MSG_ERROR%TYPE
                                                   ) IS
BEGIN
  UPDATE GE_ING_CLIENTES T
     SET T.TIP_INGRESO = P_TIP_INGRESO,
         T.MON_INGRESO = P_MON_INGRESO,
         T.RAN_INGRESO = P_RAN_INGRESO,
         T.MSG_ERROR   = P_ERROR,
         T.ESTADO      = 'V'
   WHERE T.COD_PERSONA = P_COD_PERSONA
    AND  T.ESTADO = 'P';

   COMMIT;

END;
/

