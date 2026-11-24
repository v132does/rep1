create or replace package body it.PAE_MAN is

  -- Function and procedure implementations
  function fu_obt_arbol(p_cod_manual in varchar2) return varchar2 is
  v_descripcion varchar2(300);
  v_cod_man_padre varchar2(20);
  begin
     select cod_man_padre, descripcion
       into v_cod_man_padre, v_descripcion
       from ba_manuales
      where cod_manual = p_cod_manual;
     if v_cod_man_padre is not null then 
        return fu_obt_arbol(v_cod_man_padre)||'=>'||v_descripcion;
     else
        return v_descripcion;   
     end if;   
  exception
     when others then
     return null;
  end;
  
  function fu_obt_padres(p_cod_manual in varchar2) return varchar2 is
  v_retorno varchar2(1000);
  v_pos number;
  begin
     v_retorno := fu_obt_arbol(p_cod_manual);
     v_pos := instr(v_retorno,'=>',-1);
     if v_pos > 0 then
        v_retorno := substr(v_retorno,1,v_pos-1);
     else
        v_retorno :=null;
     end if;
     return v_retorno;      
  end;
  
  procedure pr_vinculo(ptexto in varchar2, p_cod_manual in varchar2) is
  begin
     pag_htm.PR_COLUMNA('<a href=man_ver.php?opcion='||p_cod_manual||'>'||ptexto||'<a>',NULL,NULL,NULL,'class="itnegro"');
  end;
  
  function fu_buscar(ptexto in varchar2) return CLOB is
  --v_pagina  varchar2(4000);
  v_pos     number;
  v_pos_ini number;
  v_cantidad number := 0;
  v_detalles  CLOB;
  v_error    varchar2(1000) := null;
  cursor detalles is
        select cod_manual, nro_orden, descripcion, detalle, resultado, responsable
          from ba_man_detalles; 
  begin


    pag_htm.v_texto := null;  
    if length(ptexto) < 4 then
       v_error := 'No puede ingresar una palabra tan corta';
    end if;
    v_cantidad := 0;
    if ptexto is not null and v_error is null then
      for dt in detalles loop
         
         if instr(upper(dt.descripcion),upper(ptexto)) > 0 then
            -- existe en la descripcion
            pag_htm.PR_TEXTO('<tr><td><br></td></tr>');               
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA
            pr_vinculo('Actividad: '||fu_obt_arbol(dt.cod_manual),dt.cod_manual);
            pag_htm.PR_FILA('N'); -- cierro LA FILA   
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA
            pag_htm.PR_COLUMNA('Paso: '||dt.nro_orden||' '||dt.descripcion,NULL,NULL,NULL,'class="itazul"');
            pag_htm.PR_FILA('N'); -- cierro LA FILA   

            v_cantidad:=v_cantidad+1;
         --elsif instr(upper(dt.detalle),upper(ptexto)) > 0 then
         elsif upper(dt.detalle) like '%'||upper(ptexto)||'%' then
            -- existe en la detalle
             pag_htm.PR_TEXTO('<tr><td><br></td></tr>');             
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA          
            pr_vinculo('Actividad: '||fu_obt_arbol(dt.cod_manual),dt.cod_manual);
            pag_htm.PR_FILA('N'); -- cierro LA FILA    
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA                   
            pag_htm.PR_COLUMNA('Paso: '||dt.nro_orden||' '||dt.descripcion,NULL,NULL,NULL,'class="itazul"');
            pag_htm.PR_FILA('N'); -- cierro LA FILA   
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA                    
            v_pos    := instr(upper(dt.detalle),upper(ptexto)); 
            if v_pos > 10 then
               v_pos_ini := v_pos - 10;
            else
               v_pos_ini := 1;   
            end if;   
            pag_htm.PR_COLUMNA('Detalle: ...'||substr(dt.detalle,v_pos_ini,v_pos + length(ptexto) + 10),NULL,NULL,NULL,'class="itnegro"');
            pag_htm.PR_FILA('N'); -- cierro LA FILA 
 
            v_cantidad:=v_cantidad+1;                                      
         --elsif instr(upper(dt.resultado),upper(ptexto)) > 0 then
         elsif upper(dt.resultado) like '%'||upper(ptexto)||'%' then
            -- existe en la resultado
            pag_htm.PR_TEXTO('<tr><td><br></td></tr>');               
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA          
            pr_vinculo('Actividad: '||fu_obt_arbol(dt.cod_manual),dt.cod_manual);
            pag_htm.PR_FILA('N'); -- cierro LA FILA    
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA                   
            pag_htm.PR_COLUMNA('Paso: '||dt.nro_orden||' '||dt.descripcion,NULL,NULL,NULL,'class="itazul"');
            pag_htm.PR_FILA('N'); -- cierro LA FILA             
            v_pos    := instr(upper(dt.resultado),upper(ptexto)); 
            if v_pos > 10 then
               v_pos_ini := v_pos - 10;
            else
               v_pos_ini := 1;   
            end if;   
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA          
            pag_htm.PR_COLUMNA('Resultado: ...'||substr(dt.resultado,v_pos_ini,v_pos + length(ptexto) + 10),NULL,NULL,NULL,'class="itnegro"');
            pag_htm.PR_FILA('N'); -- cierro LA FILA    

            v_cantidad:=v_cantidad+1;                                
         --elsif instr(upper(dt.responsable),upper(ptexto)) > 0 then
         elsif upper(dt.responsable) like '%'||upper(ptexto)||'%' then       
            -- existe en la responsable
            pag_htm.PR_TEXTO('<tr><td><br></td></tr>');              
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA          
            pr_vinculo('Actividad: '||fu_obt_arbol(dt.cod_manual),dt.cod_manual);
            pag_htm.PR_FILA('N'); -- cierro LA FILA   
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA                    
            pag_htm.PR_COLUMNA('Paso: '||dt.nro_orden||' '||dt.descripcion,NULL,NULL,NULL,'class="itazul"');
            pag_htm.PR_FILA('N'); -- cierro LA FILA   
                      
            v_pos    := instr(upper(dt.responsable),upper(ptexto)); 
            if v_pos > 10 then
               v_pos_ini := v_pos - 10;
            else
               v_pos_ini := 1;   
            end if;   
            pag_htm.PR_TEXTO('<tr>'||pag_htm.v_salto); -- ABRO LA FILA          
            pag_htm.PR_COLUMNA('Responsable: ...'||substr(dt.responsable,v_pos_ini,v_pos + length(ptexto) + 10),NULL,NULL,NULL,'class="itnegro"');      
            pag_htm.PR_FILA('N'); -- cierro LA FILA   

            v_cantidad:=v_cantidad+1;                         
         end if;
         if length(pag_htm.v_texto) > 30000 then
            v_detalles := v_detalles || pag_htm.v_texto;
            pag_htm.v_texto := '';
         end if;
      end loop;
    end if;
    v_detalles := pag_htm.v_texto;

    --arma html
    pag_htm.v_texto := null;-- inicializo el texto
    pag_htm.PR_ENCABEZADO;
    pag_htm.PR_CUERPO('S'); -- ABRE EL CUERPO

    pag_htm.PR_TEXTO('<table width=100% border=0 cellspacing="0">'); -- DEFINO LA TABLA


    if v_error is not null then
      pag_htm.PR_TEXTO('<tr>');
      pag_htm.PR_TEXTO('<td class="itrojo">ERROR:&nbsp;'||v_error||'</td>');
      pag_htm.PR_TEXTO('</tr>');    
    else
      pag_htm.PR_TEXTO('<tr bgcolor="#000000">');
      pag_htm.PR_TEXTO('<td class="itboldblanco">&nbsp;&nbsp;RESULTADOS DE LA BUSQUEDA</td>');
      pag_htm.PR_TEXTO('<td align="right" class="itboldblanco">'||v_cantidad||'  Ocurrencias&nbsp;&nbsp;</td>');    
      pag_htm.PR_TEXTO('</tr>');    
    end if;
    
    pag_htm.PR_TEXTO(v_detalles); -- agrego los detalles
    
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA   
    
    pag_htm.PR_CUERPO('N'); -- cierro el body
    pag_htm.PR_PIE; -- pie del html
    
    return pag_htm.v_texto;    
    --return(v_pagina);
  end;
  
  function fu_orden(p_cod_manual in varchar2) return varchar2 is
  v_cod_manual varchar2(30) := null;
  v_pos number := 1;
  v_texto varchar2(30) := p_cod_manual;
  begin
    if p_cod_manual is null then
       return null;
    end if;   
    while v_pos > 0 loop
          v_pos := instr(v_texto,'.');
          if v_pos > 0 then
             v_cod_manual := v_cod_manual || lpad(trim(substr(v_texto,1,v_pos-1)),3,'0');
             v_texto := substr(v_texto,v_pos+1);
          else
             v_cod_manual := v_cod_manual || lpad(trim(substr(v_texto,1)),3,'0');
          end if;   
    end loop;
    return v_cod_manual;
  end;
  

end PAE_MAN;
/

