-- =============================================================================
-- Script  : rollback_0002_insert_tipo_zona_barrio.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Revierte: 0002_insert_tipo_zona_barrio.sql
-- =============================================================================

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  DELETE FROM IT.BA_COD_REFERENCIAS WHERE DOMINIO = 'TIPO_ZONA_BARRIO';
  DBMS_OUTPUT.PUT_LINE('BA_COD_REFERENCIAS eliminadas: ' || SQL%ROWCOUNT || ' filas (esperado: 3)');

  COMMIT;
END;
/

-- Verificacion: debe retornar 0
SELECT COUNT(*) AS remanente
FROM   IT.BA_COD_REFERENCIAS
WHERE  DOMINIO = 'TIPO_ZONA_BARRIO';
