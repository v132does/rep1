CREATE OR REPLACE TRIGGER IT.TB_BU_BIENES
 BEFORE DELETE OR INSERT OR UPDATE
 ON BU_BIENES
 FOR EACH ROW
BEGIN
   if not deleting and :new.estado <> :old.estado then
      :new.fec_estado := pae_cnf.fu_obt_fec_actual(26);
      if (:new.estado = 'C' and :old.estado = 'I') or
         (:old.estado = 'C' and :new.estado = 'I') then
         begin
            update bu_bie_grupos
               set estado = :new.estado
             where cod_grupo = :new.cod_grupo;
         exception
            when others then
               raise_application_error(-20000,
                                       'Error al modificar el estado del grupo.' ||
                                        sqlerrm);
         end;
      end if;
   end if;
END;
/

