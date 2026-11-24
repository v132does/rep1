create or replace function it.fue_obt_des_val_filtros
(p_cod_campo in varchar2,
 p_val_campo in varchar2) 
 return varchar2 is 
v_tip_dato     varchar2(01); -- M-Multiple R-Rango V-Valor
v_det_sql      varchar2(2000);
v_val_posibles varchar2(4000);
v_retorno      varchar2(300) := null;
v_pos_ini      number(6);
v_pos_fin      number(6);
begin
  select a.tip_dato, a.det_sql
    into v_tip_dato, v_det_sql
    from ge_filtros a
   where cod_campo = p_cod_campo;
  if v_tip_dato = 'R' then -- rango
     v_retorno := NULL;
  elsif v_tip_dato = 'V' then
     v_val_posibles := fuj_pro_val_posibles(v_det_sql,'N')||'#';
     v_pos_fin  := instr(v_val_posibles,'#'||p_val_campo||'#');
     if v_pos_fin > 0 then
        v_val_posibles := substr(v_val_posibles,1,v_pos_fin-1);
        v_pos_ini := instr(v_val_posibles,'#',-1);
        if v_pos_ini > 0 then
           v_retorno := substr(v_val_posibles,v_pos_ini+1,v_pos_fin-v_pos_ini);
        end if;   
    end if;    
  elsif v_tip_dato = 'M' then
     v_val_posibles := fuj_pro_val_posibles(v_det_sql,'N')||'#';  
     v_pos_fin  := instr(v_val_posibles,'#'||p_val_campo||'#');
     if v_pos_fin > 0 then
        v_val_posibles := substr(v_val_posibles,1,v_pos_fin-1);
        v_pos_ini := instr(v_val_posibles,'#',-1);
        if v_pos_ini > 0 then
           v_retorno := substr(v_val_posibles,v_pos_ini+1,v_pos_fin-v_pos_ini);
        end if;   
    end if;   
    v_retorno := v_retorno||'-'||p_val_campo;     
  end if;
  return v_retorno;
end;
/

