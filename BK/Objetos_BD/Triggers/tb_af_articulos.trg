CREATE OR REPLACE TRIGGER IT.TB_AF_ARTICULOS
 BEFORE UPDATE OR DELETE OR INSERT OR UPDATE
     ON AF_ARTICULOS
    FOR EACH ROW
DECLARE

BEGIN
   ---
   if inserting then
     if :new.ano_dep_acelerado is null then
        :new.ano_dep_acelerado := :new.ano_depreciacion;
     end if;
     ---
   end if;
   ---
END;
/

