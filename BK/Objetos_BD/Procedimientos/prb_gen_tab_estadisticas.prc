CREATE OR REPLACE PROCEDURE IT.PRB_GEN_TAB_ESTADISTICAS
IS
BEGIN
  -- Requerimiento: CNFAPDDG-3.
  -- Fecha: 26/05/2015.
  -- Estadisticas tablas contables.  
  BEGIN dbms_stats.gather_table_stats('IT','CB_ASIENTOS'); END;
  BEGIN dbms_stats.gather_table_stats('IT','CB_ASIENTOS_DET'); END;
  
END;
/

