create or replace function it.fup_obt_des_tip_garantia(p_cod_garantia number) return varchar2 is
  v_descripcion pr_gar_tipos.descripcion%type;
begin
 If p_cod_garantia is not null then
    Select descripcion
      into v_descripcion
      from pr_gar_tipos
     where cod_garantia = p_cod_garantia;
 End If;
 return(v_descripcion);
Exception
  When NO_DATA_FOUND then
       raise_application_error(-20000, 'Tipo de Garantía Inexistente');
  When TOO_MANY_ROWS then
       raise_application_error(-20001, 'Más de una Garantía con el mismo código');
  when OTHERS Then
       raise_application_error(-20002, 'Error: '||sqlerrm);
end fup_obt_des_tip_garantia;
/

