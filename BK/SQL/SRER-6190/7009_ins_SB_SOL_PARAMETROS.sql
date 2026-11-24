begin
  DBMS_SESSION.SET_IDENTIFIER('SRER-6190');
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
end;
/
INSERT INTO IT.SB_SOL_PARAMETROS (nombre, valor)
VALUES ('HEADER_ARCHIVO',
'BANCO CENTRAL DEL PARAGUAY
SUPERINTENDENCIA DE BANCOS				
Intendencia de Análisis Financiero y Normas				
Supervisión Extra Situ				
				
ENTIDAD : ueno bank S.A.				
 POSICIÓN AL :');
 
 commit;