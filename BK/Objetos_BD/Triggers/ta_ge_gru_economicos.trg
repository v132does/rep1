CREATE OR REPLACE TRIGGER IT.TA_GE_GRU_ECONOMICOS
 AFTER INSERT
 ON GE_GRU_ECONOMICOS
 FOR EACH ROW

DECLARE
v_dir_cor_varios       VARCHAR2(100):='joviedo@itbank.com.py;'
                                       ||'rrojas@itbank.com.py';
BEGIN
  it_mail.mail('itgf@itbank.com.py',
  v_dir_cor_varios,
  'Alta de Nuevo Grupo Economico.',
  'Fué ingresado un nuevo grupo economico con los siguientes datos'||CHR(10)||
  'Codigo: '||:new.cod_gru_economico||CHR(10)||
  'Nombre: '||:new.descripcion);
END;
/

