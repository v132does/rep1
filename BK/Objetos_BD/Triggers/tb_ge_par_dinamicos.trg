CREATE OR REPLACE TRIGGER IT.TB_GE_PAR_DINAMICOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_PAR_DINAMICOS
 FOR EACH ROW

DECLARE
   v_gparam              ge_parametros%rowtype;
   v_sentencia           varchar2(500);
   v_error               varchar2(500):= null;
   v_nom_procedimiento   varchar2(30);
BEGIN
   if inserting or updating then
      prg_obt_ge_parametro(:new.parametro, v_gparam);
      --- Verificar que el parámetro corresponda a la tabla dinámica
      if v_gparam.tab_relacion <> 'GE_PAR_DINAMICOS' then
         raise_application_error(-20000,
         'El parámetro '||:new.parametro||' no corresponde a esta tabla');
      end if;
   end if;
   If inserting or updating then
      SELECT UPPER(rtrim(pro_verificacion))
        INTO v_nom_procedimiento
        FROM GE_PARAMETROS
       WHERE TAB_RELACION = 'GE_PAR_DINAMICOS'
         AND PARAMETRO    = :new.parametro;

      If v_nom_procedimiento is not null then
         v_sentencia := 'BEGIN '||v_nom_procedimiento||'('||
                       ''''||:new.val_parametro||''''||'); END;';
         sql_util.ejecute_dml(v_sentencia, v_error);
         If v_error is not null then
            v_error := substr(v_error,instr(v_error,':')+1);
            if v_error is null then 
               v_error := 'Valor incorrecto. Verifique!';
            end if;   
            raise_application_error(-20000, v_error);
         End if;
      End if;
   End if;
END;
/

