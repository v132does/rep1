-- Grant BA_ENV_CORREOS_HIS
CREATE OR REPLACE public SYNONYM ba_env_correos_his FOR IT.ba_env_correos_his;

-- Crear un sinónimo para el procedimiento
CREATE OR REPLACE public SYNONYM prg_ins_ba_env_correos_his FOR IT.prg_ins_ba_env_correos_his;

-- GRANT IT_TEMPORAL
GRANT EXECUTE ON IT.prg_ins_ba_env_correos_his TO IT_TEMPORAL;