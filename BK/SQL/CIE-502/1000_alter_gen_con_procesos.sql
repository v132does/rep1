begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
ALTER TABLE IT.GE_CON_TRA_PROCESOS ADD (reversado VARCHAR2(1));
ALTER TABLE IT.GE_CON_TRA_PROCESOS ADD (nro_referencia NUMBER(15));
ALTER TABLE IT.GE_CON_TRA_PROCESOS ADD (monto NUMBER(18,2));
ALTER TABLE IT.GE_CON_TRA_PROCESOS ADD (mto_equ_local NUMBER(18,2));
CREATE INDEX IT.in_contraprocesos ON IT.ge_con_tra_procesos (fecha, hora, cod_usuario, nro_secuencia, procesado);
CREATE INDEX IT.in_contraprorev   ON IT.ge_con_tra_procesos (fecha, hora, cod_usuario, nro_secuencia, procesado, reversado);
CREATE INDEX IT.in_contrapfec     ON IT.ge_con_tra_procesos (fecha);
CREATE INDEX IT.in_contrafecpro   ON IT.ge_con_tra_procesos (fecha, PROCESADO);
