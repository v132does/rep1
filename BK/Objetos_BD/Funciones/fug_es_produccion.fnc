CREATE OR REPLACE FUNCTION IT.FUG_ES_PRODUCCION
 RETURN VARCHAR2
 IS
 v_db_name varchar2(100);
 v_nom_bas_produccion varchar2(100);
BEGIN
 -- nombre de la base de datos conectada
 select UPPER(SYS_CONTEXT('USERENV', 'DB_NAME'))
   into v_db_name
   from dual;
 -- nombre de la bd de produccion por parametroç
 select upper(nom_bas_produccion)
   into v_nom_bas_produccion
   from ge_par_generales;
 -- si son iguales, es la bd de produccion la conectada actualmente
 if v_db_name = v_nom_bas_produccion then
    return 'S';
 else
    return 'N';
 end if;
Exception
  when others then
     raise_application_error(-20000,'FUG_OBT_DBNAME  '||sqlerrm);
END;
/

