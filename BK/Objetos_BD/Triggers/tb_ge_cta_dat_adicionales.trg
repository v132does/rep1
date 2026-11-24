CREATE OR REPLACE TRIGGER IT.TB_GE_CTA_DAT_ADICIONALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_CTA_DAT_ADICIONALES
 FOR EACH ROW


DECLARE
v_sentencia           varchar2(500);
v_error               varchar2(500):= null;
v_nom_procedimiento   varchar2(30);
BEGIN
   If inserting or updating then
    begin
      SELECT UPPER(rtrim(pro_verificacion))
        INTO v_nom_procedimiento
        FROM GE_PARAMETROS
       WHERE TAB_RELACION = 'GE_CTA_DEF_ADICIONALES'
         AND PARAMETRO    = rtrim(:new.parametro);
    exception
      when no_data_found then
        v_nom_procedimiento := null;
    end;

      If v_nom_procedimiento is not null then
         v_sentencia := 'BEGIN '||v_nom_procedimiento||'('||
                       ''''||:new.val_parametro||''''||'); END;';
         sql_util.ejecute_dml(v_sentencia, v_error);
         If v_error is not null then
            v_error := 'Valor incorrecto. Verifique valores posibles.';
            raise_application_error(-20000,v_error);
         End if;
      End if;
   End if;
END;
/
