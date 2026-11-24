create or replace function it.
fue_obt_sig_secuencia(p_nom_secuencia in varchar2)
return number is
  v_siguiente number;
  v_ref_cursor sql_util.t_cursor_tab;
  v_filas number;
  v_error varchar2(4000);
begin
  -- ejecuta el select dinamicamente
  sql_util.ejecute_consulta('SELECT '||trim(p_nom_secuencia)||'.nextval from dual',
                            1,
                            v_filas,
                            v_ref_cursor,
                            v_error);
  if v_error is null then                          
     return (v_ref_cursor(1).columna1);    
  else
     raise_application_error(-20000,'Error en Secuencia '||p_nom_secuencia||' - '||replace(v_error,'SQL_UTIL.EJECUTE_CONSULTA',''));  
  end if;      
exception
  when others then
    if sqlcode <= -20000 then
       raise;
    else   
       raise_application_error(-20000,'Error en Secuencia '||sqlerrm);  
    end if;   
end;
/

