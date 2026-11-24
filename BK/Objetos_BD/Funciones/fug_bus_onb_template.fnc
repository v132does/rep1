create or replace function it.fug_bus_onb_template(p_tip_producto in number,p_ini_vigencia in date,p_fin_vigencia in date,p_rowid in varchar2) return varchar2 is
  v_existe varchar2(1);
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  begin
    select 'S'
    into v_existe
    from it.ge_mai_onb_templates t
    where t.tip_producto = p_tip_producto
    and ((t.ini_vigencia between p_ini_vigencia and p_fin_vigencia
    OR t.fin_vigencia between p_ini_vigencia and p_fin_vigencia)
    OR (( p_ini_vigencia between  t.ini_vigencia and  t.fin_vigencia)
    OR (p_fin_vigencia between  t.ini_vigencia and  t.fin_vigencia)))
    and (t.rowid != p_rowid or p_rowid is null);
     exception
    when no_data_found then
      v_existe:='N';
    when too_many_rows then
       v_existe:='S';
  end;
  return(v_existe);
end fug_bus_onb_template;
/

