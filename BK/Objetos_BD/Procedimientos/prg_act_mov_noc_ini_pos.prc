CREATE OR REPLACE PROCEDURE IT.PRG_ACT_MOV_NOC_INI_POS
 IS
   v_lugar varchar2(300);
   v_error varchar2(300);
   /*Proceso creado específicamente para correr posterior al
     proceso PRG_ACT_MOV_NOC_INI */
BEGIN
   -- truncando las tablas
   v_lugar := 'Truncando tabla ge_movimientos_noc';
   sql_util.ejecute_dml('truncate table ge_movimientos_noc', v_error);
   if v_error is not null then
      raise_application_error(-20000,v_lugar||' '||v_error);
   end if;

   v_lugar := 'Truncando tabla cj_movimientos_noc';
   sql_util.ejecute_dml('truncate table cj_movimientos_noc', v_error);
   if v_error is not null then
      raise_application_error(-20000,v_lugar||' '||v_error);
   end if;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, v_lugar||' '||sqlerrm);
END;
/

