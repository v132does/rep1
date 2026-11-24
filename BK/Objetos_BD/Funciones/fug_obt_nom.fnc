CREATE OR REPLACE FUNCTION IT.FUG_OBT_NOM(p_tipo varchar2)
 RETURN VARCHAR2
 IS
--- p_tipo -> 'C' Corto/ 'L' Largo
--'L1' linea 1 de Nombre Largo/'L2' linea 2 de Nombre Largo
v_nom_entidad ge_par_dinamicos.val_parametro%type;
BEGIN
   
   if upper(p_tipo) ='C' then
       v_nom_entidad:= NVL(fug_obt_pardinamico('NOM_CORTO'),'Nombre corto no parametrizado');
   elsif  upper(p_tipo) ='L' then
     v_nom_entidad:= NVL(fug_obt_pardinamico('NOM_LARGO'),'Nombre largo no parametrizado');   
   elsif  upper(p_tipo) ='L1' then
     v_nom_entidad:= NVL(fug_obt_pardinamico('NOM_LINEA1'),'Nombre linea 1 no parametrizado');
   elsif  upper(p_tipo) ='L2' then
     v_nom_entidad:= NVL(fug_obt_pardinamico('NOM_LINEA2'),'Nombre linea 2 no parametrizado');
   else
     v_nom_entidad:= 'Tipo no enviado o definido' ;
   end if;  
   return v_nom_entidad;
END;
/

