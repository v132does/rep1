create or replace function it.xx_busca_en_consulta(p_consulta in varchar2, p_palabra in varchar2)
  return varchar2 is
  cursor consultas
   is select cod_consulta, det_sql data_default
   from ba_consultas
   where cod_consulta = nvl(p_consulta,cod_consulta);
v_det_sql varchar2(4000);
v_respuesta varchar2(4000) := null;
begin
   for cc in consultas loop
       v_det_sql := REPLACE(substr(upper(cc.data_default),1,4000),' ',' ');
       if instr(v_det_sql, upper(p_palabra)) > 0 then
          v_respuesta := v_respuesta||chr(10)||cc.cod_consulta;
       end if;
   end loop;

   return v_respuesta;
end;
/

