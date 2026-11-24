create or replace function it.f_es_residente(p_tipdeudor   in number,
                                          p_seccon      in varchar2)
  return varchar2 is
  Result varchar2(1) := 'N';
begin
  begin
    select td.ind_residente
      into result
      from it.ge_tip_deudores td
     where td.cod_tip_deudor = p_tipdeudor
       and td.cod_sec_contable = p_seccon;
  exception
     when others then
        result := 'N';
  end;
  return(Result);
end f_es_residente;
/

