CREATE OR REPLACE TRIGGER IT.TB_GE_ENV_PAG_REC_TMP
 BEFORE INSERT 
 ON GE_ENV_PAG_RECAUDACIONES_TMP
 FOR EACH ROW

DECLARE
     v_codigo number(18) := 0;
BEGIN
   if inserting then
      select max(a.codigo)
        into v_codigo
        from ge_env_pag_recaudaciones_tmp a;
      :new.codigo := nvl(v_codigo,0) + 1;
   end if;
END;
/

