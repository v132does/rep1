ALTER TABLE it.ge_men_env_sipap
 ADD (msj_swift_tmp  CLOB);

UPDATE it.ge_men_env_sipap SET msj_swift_tmp=msj_swift;
COMMIT;

ALTER TABLE it.ge_men_env_sipap DROP COLUMN msj_swift;

ALTER TABLE it.ge_men_env_sipap
RENAME COLUMN msj_swift_tmp TO msj_swift;
