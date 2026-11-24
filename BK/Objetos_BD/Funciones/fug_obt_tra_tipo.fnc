create or replace function it.fug_obt_tra_tipo(p_transaccion number,
                          p_tipo varchar2, 
                          p_afecta varchar2)
return varchar2
is
  vreturn varchar2(1) default null;
begin
  if p_transaccion in (515,560) then
    if p_tipo = 'C' then
      vreturn := 'D';
    elsif p_tipo = 'D' then
      vreturn := 'C';
    end if;
  else
    if nvl(p_afecta,'XX') = 'B' then
      if p_tipo = 'C' then
        vreturn := 'D';
      elsif p_tipo = 'D' then
        vreturn := 'C';
      else
        vreturn := p_tipo;
      end if;
    else
      vreturn := p_tipo;
    end if;
  end if;
  return vreturn;
end;
/

