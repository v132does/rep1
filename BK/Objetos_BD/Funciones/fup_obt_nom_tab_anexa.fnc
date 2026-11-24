create or replace function it.fup_obt_nom_tab_anexa(p_cod_garantia number) return varchar2 is
  v_nom_tab_anexa pr_gar_tipos.nom_tab_anexa%type;
begin
 If p_cod_garantia is not null then
    Select nvl(nom_tab_anexa,'x')
      into v_nom_tab_anexa
      from pr_gar_tipos
     where cod_garantia = p_cod_garantia;
 End If;
 return(v_nom_tab_anexa);
Exception
  When NO_DATA_FOUND then
       raise_application_error(-20000, 'Tipo de Garantía Inexistente');
  When TOO_MANY_ROWS then
       raise_application_error(-20001, 'Más de una Garantía con el mismo código');
  when OTHERS Then
       raise_application_error(-20002, 'Error: '||sqlerrm);
end fup_obt_nom_tab_anexa;
/

