CREATE OR REPLACE TRIGGER IT.ta_ba_rol_programas
   after insert or update
   on ba_rol_programas
   referencing old as old new as new
   for each row
declare
   v_tip_programa    ba_tip_programas.cod_tip_programa%type := null;
   v_des_tipo        ba_tip_programas.descripcion%type;
   v_accesos         varchar2 (100) := null;
   rg_tip_programa   ba_tip_programas%rowtype;
begin
   --busco el tipo de programa
   select a.cod_tip_programa, b.descripcion
     into v_tip_programa, v_des_tipo
     from ba_programas a, ba_tip_programas b
    where a.cod_tip_programa = b.cod_tip_programa
      and a.cod_programa = :new.cod_programa;
   --busco los tipos de accesos
   select a.inserta,
          a.actualiza,
          a.elimina,
          a.consulta,
          a.imprime
     into rg_tip_programa.inserta,
          rg_tip_programa.actualiza,
          rg_tip_programa.elimina,
          rg_tip_programa.consulta,
          rg_tip_programa.imprime
     from ba_tip_programas a
    where a.cod_tip_programa = v_tip_programa;
   --inserta
   if :new.inserta <> nvl (:old.inserta, 'x') then
      if :new.inserta = 'S' and :new.inserta <> rg_tip_programa.inserta then
         if v_accesos is null then
            v_accesos := 'Inserta,';
         else
            v_accesos := v_accesos || ' Inserta,';
         end if;
      end if;
   end if;
   --actualiza
   if :new.actualiza <> nvl (:old.actualiza, 'x') then
      if :new.actualiza = 'S' and :new.actualiza <> rg_tip_programa.actualiza then
         if v_accesos is null then
            v_accesos := 'Actualiza,';
         else
            v_accesos := v_accesos || ' Actualiza,';
         end if;
      end if;
   end if;
   --elimina
   if :new.elimina <> nvl (:old.elimina, 'x') then
      if :new.elimina = 'S' and :new.elimina <> rg_tip_programa.elimina then
         if v_accesos is null then
            v_accesos := 'Elimina,';
         else
            v_accesos := v_accesos || ' Elimina,';
         end if;
      end if;
   end if;
   --consulta
   if :new.consulta <> nvl (:old.consulta, 'x') then
      if :new.consulta = 'S' and :new.consulta <> rg_tip_programa.consulta then
         if v_accesos is null then
            v_accesos := 'Consulta,';
         else
            v_accesos := v_accesos || ' Consulta,';
         end if;
      end if;
   end if;
   --imprime
   if :new.imprime <> nvl (:old.imprime, 'x') then
      if :new.imprime = 'S' and :new.imprime <> rg_tip_programa.imprime then
         if v_accesos is null then
            v_accesos := 'Imprime,';
         else
            v_accesos := v_accesos || ' Imprime,';
         end if;
      end if;
   end if;
   --si la variable está cargada se emite mensaje de error
   if v_accesos is not null then
      v_accesos := '(' || substr (v_accesos, 1, length (v_accesos) - 1) || ')'; --v_accesos
      raise_application_error (-20000, 'No se admiten los Permisos: '|| v_accesos ||' para el Tipo de Programa: '|| v_des_tipo|| '.');
   end if;
exception
   when others then
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error (-20000, 'en TA_BA_ROL_PROGRAMAS ' || sqlerrm);
      end if;
end;
/

