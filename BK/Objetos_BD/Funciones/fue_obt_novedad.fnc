CREATE OR REPLACE FUNCTION IT.FUE_OBT_NOVEDAD
 (P_TPNOVED VARCHAR2
 ,P_NOVEDAD VARCHAR2
 )
 RETURN VARCHAR2
 IS
-- posicion inicial y final del campo
  v_pos_inicial number(8) := 1;
  v_pos_final   number(8) := 0;
  v_pos_ini_nov number(8) := 0;
  v_pos_fin_nov number(8) := 0;
  v_lon_campo   number(8) := 0;
  v_lon_noved   number(8) := 0;
  ---
  v_detalle varchar2(2000);
begin
 -- Se carga el tipo de Novedad --
 if p_tpnoved = 'E' Then
    v_detalle := '';
 elsif p_tpnoved = 'M' Then
    v_detalle := '';
 else
    v_detalle := '';
 end if;
 -- Se busca el detalle de la novedad --
 loop
   v_pos_inicial := instr(p_novedad, '~', v_pos_inicial);
   exit when v_pos_inicial = 0;
   if instr(substr(p_novedad, v_pos_inicial,35),':') = 0 then
       -- no es un campo, se debe volver a buscar otra posicion
       v_pos_inicial := v_pos_inicial + 1;
   else
       -- esta bien el dato
       v_pos_inicial := v_pos_inicial + 1;

       v_pos_final   := instr(p_novedad, ':',   v_pos_inicial) - 1;
       v_lon_campo   := v_pos_final   - v_pos_inicial + 1;
       -- Identifica el nombre del campo --
       v_detalle   := v_detalle||initcap(replace(substr(p_novedad, v_pos_inicial, v_lon_campo),'_','. '))||':';

       -- Toma el detalle de la novedad --
       v_pos_ini_nov := instr(p_novedad, '<i:', v_pos_inicial) + 3;
       v_pos_fin_nov := instr(p_novedad, ':f>', v_pos_inicial) - 1;
       v_lon_noved   := v_pos_fin_nov - v_pos_ini_nov + 1;
       --
       v_detalle   := v_detalle||' '||substr(p_novedad, v_pos_ini_nov, v_lon_noved);
       if p_tpnoved = 'M' Then -- es una modificacion del dato
          -- Es una modificacion debe buscar los datos modificados
          v_pos_ini_nov := instr(p_novedad, '<i:', v_pos_ini_nov + 2) + 3;
          v_pos_fin_nov := instr(p_novedad, ':f>', v_pos_fin_nov + 2) - 1;
          v_lon_noved   := v_pos_fin_nov - v_pos_ini_nov + 1;
          --
          v_detalle     := v_detalle||' => '||substr(p_novedad, v_pos_ini_nov, v_lon_noved)||' ';
       end if;
       v_detalle := v_detalle ||chr(10);
    end if;
 end loop;
 --
 return(v_detalle);
exception
  when others then
     --raise_application_error(-20000,'FUE_OBT_NOVEDAD '||' -> '||sqlerrm||v_detalle);
     return (v_detalle);
end FUE_OBT_NOVEDAD;
/

