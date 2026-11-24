create or replace function it.fug_val_for_msj_swts( p_formato in ba_cod_referencias.val_minimo%type,
                                                 p_valor   in ba_cod_referencias.val_minimo%type,
                                                 p_campo   in ba_cod_referencias.val_minimo%type )
   return varchar2 is
   v_exp_regular ba_cod_referencias.val_maximo%type;
   v_descripcion ba_cod_referencias.significado%type;

begin
   select x.val_maximo, x.significado
     into v_exp_regular, v_descripcion
     from ba_cod_referencias x
    where x.dominio = 'MSJ_FORMATO'
      and x.val_minimo = p_formato;


   if v_exp_regular is not null then
      if nvl(regexp_substr(p_valor, v_exp_regular), '*') != p_valor then
         return ' Error Formato Campo :'||p_campo||': '||p_valor||
            ' Formato esperado: '||v_descripcion||
            ' ('||p_formato||')';
      end if;
   end if;
   return null;
exception
  when no_data_found then
     return null;

end fug_val_for_msj_swts;
/

