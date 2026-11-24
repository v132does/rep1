CREATE OR REPLACE TRIGGER IT.TB_GE_REC_DEPOSITANTES BEFORE DELETE ON GE_REC_DEPOSITANTES FOR EACH ROW
DECLARE
  v_existe varchar2(1) default 'N';
BEGIN
  BEGIN
    SELECT DISTINCT 'S'
      INTO v_existe
      FROM GE_REC_MOVIMIENTOS a
     WHERE a.cod_ente = :old.cod_ente
       AND a.depositante = :old.cod_depositante;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
    v_existe := 'N';
    WHEN OTHERS THEN
    v_existe := 'N';
  END;
  --
  IF v_existe = 'S' THEN
    raise_application_error(-20000,'No se puede Eliminar el Depositante por Movimientos ya Registrados.');
  END IF;
END;
/

