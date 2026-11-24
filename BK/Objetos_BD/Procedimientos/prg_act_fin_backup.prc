CREATE OR REPLACE PROCEDURE IT.PRG_ACT_FIN_BACKUP IS
BEGIN
  -- Actualiza el estado del backup a 2 (realizado)
  UPDATE tm_backup
     SET estado = 2,
         fecha  = SYSDATE;
END;
/

