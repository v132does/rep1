create or replace function it.fuw_obt_ref_val_limite ( p_cod_obj_base in wf_tip_circuitos.cod_obj_base%type,
                                                    p_referencia in wf_tip_circuitos.referencia%type,
                                                    p_ref_val_limite in wf_tip_circuitos.ref_val_limite%type,
                                                    p_val_referencia in wf_circuitos.referencia%type
                                                   )
return varchar2 is
  v_ref_val_limite wf_tip_circuitos.ref_val_limite%type;
  v_sentencia varchar2(4000);
  v_error varchar2(500);
  v_ref_cursor sql_util.T_cursor_tab;
  v_filas number;
begin
  v_sentencia := 'select '||p_ref_val_limite||' from '||p_cod_obj_base||' where '||p_referencia||' = '||p_val_referencia;
  sql_util.ejecute_consulta(v_sentencia,1,v_filas,v_ref_cursor,v_error);
  if v_error is not null then
     raise_application_error(-20000,'Error al ejecutar la consulta '||v_error);
  else
     v_ref_val_limite := v_ref_cursor(1).columna1;
  end if;
  return v_ref_val_limite;
exception
  when others then
    return null;
end;
/

