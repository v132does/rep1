CREATE OR REPLACE TRIGGER IT.TB_GE_CTA_DEF_ADICIONALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_CTA_DEF_ADICIONALES
 FOR EACH ROW

DECLARE
   v_gparam  ge_parametros%rowtype;
BEGIN
   if inserting or updating then
      prg_obt_ge_parametro(:new.parametro, v_gparam);
      --- Verificar que el parámetro corresponda a la tabla de entes
      if v_gparam.tab_relacion <> 'GE_CTA_DEF_ADICIONALES' then
         raise_application_error(-20000,
         'El parámetro '||:new.parametro||' no corresponde a esta tabla');
      end if;
   end if;
END;
/

