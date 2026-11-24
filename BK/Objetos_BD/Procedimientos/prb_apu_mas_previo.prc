CREATE OR REPLACE PROCEDURE IT.PRB_APU_MAS_PREVIO
IS
-- Simgia - Nicolas Andrusky
-- Elimina registros cargados por el usuario actual en la tabla cb_apu_masivos_tmp
BEGIN
   DELETE FROM CB_APU_MASIVOS_TMP WHERE COD_USUARIO = USER;        
END;
/

