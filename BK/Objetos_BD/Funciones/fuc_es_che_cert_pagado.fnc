create or replace function it.fuc_es_che_cert_pagado(p_nro_cuenta cc_che_certificados.nro_cuenta%type, p_nro_cheque cc_che_certificados.nro_cheque%type) return varchar2 is
  result varchar2(1);
begin
  begin
    select 'S'
      into result
      from cc_che_certificados c
     where c.nro_cuenta = p_nro_cuenta
       and c.nro_cheque = p_nro_cheque
       and c.fec_pago is not null;
  exception
    when too_many_rows then
      return 'S';
    when others then
      return 'N';
  end;
  return result;
exception
  when others then
     return 'N';
end;
/

