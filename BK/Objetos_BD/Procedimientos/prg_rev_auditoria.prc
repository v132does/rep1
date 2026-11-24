create or replace procedure it.prg_rev_auditoria
(p_nom_tabla   in varchar2,
 p_fec_sistema in date,
 p_cod_usuario in varchar2,
 p_clave in varchar2 default null) is 
cursor c_datos is
   select clave,det_original detalle,tipo
     from gv_auditorias
    where tabla = p_nom_tabla
      and fec_real = p_fec_sistema
      and usuario = p_cod_usuario
      and tipo in ('Modificación')
      and (clave like p_clave||'%' or p_clave is null);
  v_plsql varchar2(4000); 
  v_msj_error varchar2(4000);   
  v_pos number;
  v_campo varchar2(300);
  v_valor varchar2(300);
  v_val_clave    varchar2(300);
  v_cla_primaria varchar2(300);
  p_cla_primaria varchar2(300) := fue_obt_cla_primaria(p_nom_tabla);
  v_where varchar2(1000) := null;
  --
  FUNCTION LF_OBT_DET_CAMPOS
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
         if v_detalle is not null then
            v_detalle := v_detalle||',';
         end if;    
         v_detalle   := v_detalle||(replace(substr(p_novedad, v_pos_inicial, v_lon_campo),'_','_'))||' = ';
  
         -- Toma el detalle de la novedad --
         v_pos_ini_nov := instr(p_novedad, '<i:', v_pos_inicial) + 3;
         v_pos_fin_nov := instr(p_novedad, ':f>', v_pos_inicial) - 1;
         v_lon_noved   := v_pos_fin_nov - v_pos_ini_nov + 1;
         --
         v_valor := replace(substr(p_novedad, v_pos_ini_nov, v_lon_noved),',','');
         if length(v_valor) = 10 and instr(v_valor,'/',1,1) = 3 and instr(v_valor,'/',1,2) = 6 then
            -- es una fecha
            v_valor := 'to_date('''||v_valor||''',''DD/MM/YYYY'')';
         elsif length(v_valor) = 21 and instr(v_valor,'/',1,1) = 3 and instr(v_valor,'/',1,2) = 6 and instr(v_valor,':') > 6 then   
            -- fecha y hora
             v_valor := 'to_date('''||v_valor||''',''DD/MM/YYYY HH24:MI:SS'')';
         else
            v_valor := ''''||v_valor||'''';
         end if;      
         v_detalle   := v_detalle||v_valor;
         /*
         if p_tpnoved = 'M' Then -- es una modificacion del dato
            -- Es una modificacion debe buscar los datos modificados
            v_pos_ini_nov := instr(p_novedad, '<i:', v_pos_ini_nov + 2) + 3;
            v_pos_fin_nov := instr(p_novedad, ':f>', v_pos_fin_nov + 2) - 1;
            v_lon_noved   := v_pos_fin_nov - v_pos_ini_nov + 1;
            --
            v_detalle     := v_detalle||' => '||substr(p_novedad, v_pos_ini_nov, v_lon_noved)||' ';
         end if;
         */
         v_detalle := v_detalle ||chr(10);
      end if;
   end loop;
   --
   return(v_detalle);
  exception
    when others then
       --raise_application_error(-20000,'FUE_OBT_NOVEDAD '||' -> '||sqlerrm||v_detalle);
       return (v_detalle);
  end;  
  --
begin
  ---
  pre_cam_for_numerico('.,');
  --- 
  for dt in c_datos loop
  	-- agrego el where de los datos a consultar
    v_where := '';
    v_campo := '';
    v_valor := '';
    
  	v_cla_primaria := p_cla_primaria;
  	v_val_clave    := dt.clave;
    loop
       v_pos := instr(v_cla_primaria,'#'); 
            if v_pos > 0 then
       	  --
       	  v_campo := substr(v_cla_primaria,1,v_pos-1);
    
       	  v_cla_primaria := substr(v_cla_primaria,v_pos+1);
       	  
       	  -- busco el valor de la clave
       	  v_pos := instr(v_val_clave,'#');
       	  if v_pos > 0 then
       	     v_valor := substr(v_val_clave,1,v_pos-1);
    
       	     v_val_clave := substr(v_val_clave,v_pos+1);
       	  end if;   
       else
          v_campo := v_cla_primaria;
    
          v_valor := v_val_clave;
    
          v_cla_primaria := null;
       end if;
       -- ya tengo el nombre del campo y su valor, ahora armo el where
       
       if v_valor  is null then
          v_where := v_where || ' and a.'||v_campo||' is null';
       else
       	  v_where := v_where || ' and a.'||v_campo||' = '''||v_valor||'''';
       end if;
  	   exit when v_cla_primaria is null;
  
    end loop;	
    if v_where is not null then
       v_where := substr(v_where,5);
    end if; 
    v_plsql := '';
    if dt.tipo = 'Borrado' then
       -- borrado de registro
       null;
    else
       -- modificacion de registros
       v_plsql := 'update '||p_nom_tabla||' a set '||
                  LF_OBT_DET_CAMPOS('M',dt.detalle)||
                  ' where '||v_where;                    
                    
    end if;
    if v_plsql is not null then
      -- hay algo para ejecutar
      sql_util.ejecute_dml(v_plsql,v_msj_error);
      if v_msj_error is not null then
         raise_application_error(-20000,'SQL: '||v_plsql||' Error:'||v_msj_error);
      end if;
    end if;     
  end loop;
  ---
end;
/

