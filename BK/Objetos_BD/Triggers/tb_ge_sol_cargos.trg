CREATE OR REPLACE TRIGGER IT.TB_GE_SOL_CARGOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_SOL_CARGOS
 FOR EACH ROW


DECLARE

   v_tip_ente ge_entes.tipo%type;
BEGIN
   if inserting or updating then
      if :new.cod_ent_seguro is not null then
         --- Verificar tipo de ente
         v_tip_ente := fug_obt_tip_ente(:new.cod_ent_seguro);
         if v_tip_ente not in ('SE','ES') then
            raise_application_error(-20000,
            'Ente '||:new.cod_ent_seguro||' no corresponde a seguro/escribanía');
         end if;
      end if;
   end if;
END;
/

