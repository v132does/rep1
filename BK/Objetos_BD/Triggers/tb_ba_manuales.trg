CREATE OR REPLACE TRIGGER IT.TB_BA_MANUALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_MANUALES
 FOR EACH ROW
declare
v_cod_man_padre varchar2(10);
v_longitud      number(2) := nvl(length(:new.cod_manual),0);
v_existe        varchar2(01);
v_pos           number(8) := instr(:new.cod_manual,'.',-1);
begin
   if inserting or updating then
     if v_longitud < 1 then
        raise_application_error(-20000,'Código debe ser de 2 digitos como mínimo');
     end if;
     if v_pos > 0 then
        if trim(substr(:new.cod_manual,v_pos+1)) = '' then
           raise_application_error(-20000,'No se puede ingresar . al final del Código');
        end if;
        v_cod_man_padre := substr(:new.cod_manual,1,v_pos-1);
     else
        v_cod_man_padre := null;
     end if;
     if inserting then
        :new.cod_man_padre := v_cod_man_padre;
     elsif updating and nvl(:new.cod_man_padre,'x') <> v_cod_man_padre then
        :new.cod_man_padre := v_cod_man_padre;
     end if;
   end if;
   if inserting and :new.cod_man_padre is not null then
      --- Verificar que su padre no posea contenido
      begin
         select 'S' into v_existe from ba_manuales
          where cod_manual = :new.cod_man_padre
            and tipo is null;
      exception
         when no_data_found then
            raise_application_error(-20000,
            'El Manual Padre '||:new.cod_man_padre||' posee contenido, no puede tener hijos ');
      end;
   end if;
end;
/

