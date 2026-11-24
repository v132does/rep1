CREATE OR REPLACE TRIGGER IT.TB_CB_ASIENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CB_ASIENTOS
 FOR EACH ROW
declare
v_blo_gra_asientos varchar2(1);
BEGIN
   if (deleting or inserting or updating) then
       --Parametro seteado para no grabar asientos despues de generar Asientos Automaticos--
       v_blo_gra_asientos := fug_obt_pardinamico('BLO_GRA_ASIENTOS');
       if v_blo_gra_asientos = 'S' then
          raise_application_error(-20000,'No se permite grabar/modificar/eliminar Asientos'||chr(10)||'Despues de Generar Asientos Automaticos');
       end if;
   end if;
END;
/

