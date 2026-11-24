CREATE OR REPLACE FUNCTION IT.fue_obt_des_referencia(p_dominio in varchar2,
                                                     p_valor   in varchar2)
  return varchar2 is
  v_referencia ba_cod_referencias.significado%type;
begin
  select significado
    into v_referencia
    from ba_cod_referencias
   where dominio = p_dominio
     and val_minimo = p_valor;
  return v_referencia;
exception
  when no_data_found then
    return('Referencia  no registrada en el Sistema');
end;
/

