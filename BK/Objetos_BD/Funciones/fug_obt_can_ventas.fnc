create or replace function it.fug_obt_can_ventas(p_cod_canal   in number,
                                              p_cod_oficina in number)
  return varchar2 is
  v_retorno ba_cod_referencias.val_maximo%type;
  v_cantidad number;
begin
  select nvl(max(a.val_maximo),'999')
    into v_retorno
    from ba_cod_referencias a
   where a.abreviatura = to_char(p_cod_oficina)
     and a.significado = to_char(p_cod_canal)
     and a.dominio = 'GEN_CANALES';
   if v_retorno = '999' then
         Select count(*)
           into v_cantidad
           from ba_cod_referencias a
          where a.significado = to_char(p_cod_canal)
            and a.dominio = 'GEN_CANALES';
            if v_cantidad = 0 then
                v_retorno := '0';
            end if;
   end if;
  return v_retorno;
exception
  when others then
    return '0';
end fug_obt_can_ventas;
/

