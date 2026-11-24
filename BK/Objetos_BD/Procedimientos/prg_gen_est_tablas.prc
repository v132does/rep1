CREATE OR REPLACE PROCEDURE IT.PRG_GEN_EST_TABLAS(P_DOMINIO IN VARCHAR2) is
  -- Procedimiento que genera estadísticas de tablas en case al dominio que recibe como parámetro
  cursor c_tablas is
    select val_minimo
      from ba_cod_referencias r
     where r.dominio = P_DOMINIO;
begin 
  for c in  c_tablas loop
    begin
      dbms_stats.gather_table_stats('IT',c.val_minimo);
    end;
  end loop;
end PRG_GEN_EST_TABLAS;
/

