create or replace procedure it.PRJ_OBT_TIT_COLUMNAS
         (p_sql in varchar2,                  -- sentencia select a analizar
          p_can_columnas in out number,      -- cantidad de columnas leidas
          p_encabezado    in out varchar2) is -- encabezado armado 
  v_can_columnas   number(4) := 1;    -- cuenta la cantidad de columnas
  v_can_parentesis   number(4) := 0;  -- control de parentesis en la sentencia
  v_encabezado varchar2(3000) := rtrim(replace(replace((substr(upper(p_sql), 1, InStr(upper(p_sql), 'FROM') - 1)),chr(10),' '),chr(13),' '))||'$';
  v_pos number(4); --CNFDEEVO-68 Se amplía la posición post. y ant. para el encabezado.
  v_ant number(4); --
  v_tit_columna varchar2(2000);
BEGIN
  -- cuento la cantidad de columnas de la consulta -------------------------------------------------		
  For i in 1..Length(v_encabezado) loop
    If Substr(v_encabezado, i, 1) = '(' Then
       v_can_parentesis := v_can_parentesis + 1;
    Else
       If substr(v_encabezado, i, 1) = ')' And v_can_parentesis > 0 Then
          v_can_parentesis := v_can_parentesis - 1;
       End If;
    End If;
    If v_can_parentesis = 0 Then
       If substr(v_encabezado, i, 1) = ',' Then
          v_encabezado := Substr(v_encabezado, 1, i - 1) || '$' || Substr(v_encabezado, i + 1);
          v_can_columnas := v_can_columnas + 1;
       End If;
    End If; 
  end loop;
  p_can_columnas := v_can_columnas; 
  v_ant := 0;
  -- Leo los nombres de las columnas -------------------------------
  p_encabezado := '';
  for i in 1..v_can_columnas loop
    v_pos := instr(substr(v_encabezado,v_ant+1),'$')+ v_ant;
    v_tit_columna := ltrim(rtrim(substr(v_encabezado,(v_ant+1),(v_pos-v_ant-1))));
    v_ant := instr(v_tit_columna,'"'); -- busco una comilla
    if v_ant = 0 then
       v_ant := instr(v_tit_columna,' ',-1);  -- busco el primer espacio antes del separador $
    end if;   
    if v_ant >  0 then
       v_tit_columna := substr(v_tit_columna,v_ant+1);  -- obtengo el titulo de la columna
    end if;
    v_tit_columna := Initcap(replace(v_tit_columna,'"','')); -- le saco las comillas
    -- encabezado
    p_encabezado := p_encabezado || '#' || v_tit_columna;
    -- guardo la posicion actual    
    v_ant := v_pos;
  end loop;    
end PRJ_OBT_TIT_COLUMNAS;
/

