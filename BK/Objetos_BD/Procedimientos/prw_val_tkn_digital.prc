create or replace procedure it.prw_val_tkn_digital(p_cod_pesona in varchar2,
                                           p_cod_per_vinculo in varchar2,
                                           p_celular out varchar2, 
                                           p_mensaje out varchar2) is
begin
  p_mensaje := null;
  begin
    select telefono 
    into   p_celular
    from   BW_TD_CONFIGURACIONES t
    where  cod_persona =  p_cod_pesona
    and    cod_per_vinculo = p_cod_per_vinculo
    and    rownum = 1;
  exception
    when others then
      p_mensaje := 'El operador seleccionado no posee token digital activo';
  end;
  if p_mensaje is null then
     if p_celular is null then
        p_mensaje := 'El operador seleccionado no tiene un numero de teléfono configurado en token digital';
     else   
        p_mensaje := 'OK' ;
     end if;   
  end if;     
end prw_val_tkn_digital;
/

